# Randomizer plan (draft for review)

Goal: a patched ROM where **every race is a random track generated on the console from a hexadecimal seed**.
Seeds can be typed in (to replay or share a track) or rolled at random. Every track has a pit stop and
3–8 laps. Menus are reworked for seeds; no minimap.

Everything below is based on the decoded data formats (docs/05, 06) and the menu code read for this plan.
Items marked **(verify)** are assumptions that the first prototype must confirm.

## 1. What a "track" is in this game (why generation is feasible)

A race track is entirely *data* in WRAM, expanded at race start by `load_track_streams` (00:BF44):

| table | content | how it is built |
|---|---|---|
| `$7E4000` slope | 1 word / 32 units | per 1024-unit piece: signed byte -> template (33 slope pieces, `0C:85D3`) |
| `$7E4C00` curve | 1 word / 32 units | same with 33 curve templates (`0C:8591`) |
| `$7E5800` scenery | 1 word / 32 units | per piece: byte -> one of 38 templates (`0C:8545`), each uniformly one *road type* 0..3 (32 words) |
| `$7E6400` objects | 1 word / 32 units | roadside objects: `type<<9 | side<<8 | lateral/128`; `0x74xx` = pit entrance |
| `$0200`, `$1E56`, `$1EF0`, `$1EF2` | length, laps, pit position, pit side | descriptor, `00:DEA4`, `00:DF24` |

Findings from analysing all 32 real tracks (this session) that make *sane* random tracks easy:

* **Slope and curve templates are a tiny grammar**, not free-form data. Each template starts and ends at a *level*:
  slopes use levels 0, 50, 110, 300, 600, 700, 750, 800, 900, 1000; curves use 0, 16, 24, 32, 40. Per level there is
  *ramp-up* (0->L), *plateau* (L->L) and *ramp-down* (L->0) (slope ids 1-4, 5-7, 9-13, 14-17, 18-20, 21-23, 24-26,
  27-29, 30-32; curve ids 1-4, 5-8, 9-16 with short "single-piece bump" variants 17-32 and 13). A negative stream byte
  mirrors the template (downhill / opposite curve direction). Real tracks are exactly walks on this graph
  (`[-9, -12, -12]` then wrap to `[-11, ...]`: hills continue across the lap boundary).
* **"Start and end on the same slope/direction" is therefore a hard rule that is easy to enforce:** the level at the end
  of the last piece must equal the level at the start of the first piece (we simply make both 0 = flat/straight, or allow
  any level and rotate the stream — real tracks do both).
* Table sizes allow up to **48 pieces** (`$4000-$4BFF` etc.); real tracks use 23-46.
* Scenery templates are uniform per piece (one road type), so a "road profile" is just a sequence of types, e.g.
  `1 1 1 2 2 2 1 1 0 0 ...`. Piece 0 is always the start/finish template (5, or 22 for Scandinavia).
* **Pit stop = scenery template 20 (road type 3) or template 2 (road type 2) for one piece**, plus pit info `00:DF24`
  = `0x8000|side` + `(piece_start - 512)/2` (all 13 original pit tracks follow this), plus one object word `0x747C`
  (type 0x3A, side bit, lateral 124) in the second half of that piece. The computer car already finds the pit through
  `$1EF0/$1EF2`.
* Environment (horizon graphics, palette, road widths, day/night script, bot speed offsets) is keyed by `$1F06` through
  tables with 32 entries. **Trick: keep `$1F06` = an "environment id" (any of the 32 originals) and replace only the
  geometry.** Then lighting (e.g. night), graphics and bot difficulty keep working with no new data.

## 2. Architecture

```
seed (32 bit, 8 hex digits)
  -> PRNG (own xorshift/LCG, not the game's $1FF4, so a seed is reproducible)
  -> environment id (0..31)         -> $1F06 (all existing per-track tables keep working)
  -> piece count N (24..46 ?)       -> $0200 = N*1024
  -> laps 3..8                       -> $1E56
  -> slope walk, curve walk          -> $7E4000 / $7E4C00 (template words copied from bank 0C)
  -> road-type walk + pit piece      -> $7E5800, $1EF0, $1EF2
  -> roadside objects + pit object   -> $7E6400
```

* The generator is a **new routine in 65816** that replaces the body of `load_track_streams` (00:BF44) — no streams
  are written at all, the expanded tables are produced directly. It reads the template pointer tables from bank 0C.
* Code lives in **new ROM banks 10-1F** (ROM expanded to 1 MB: header size byte + checksum). Only ~6 KB of zero
  padding exists in the original, which is too tight. **(verify: Mesen, bsnes and common flash carts accept 1 MB LoROM
  without further changes.)**
* **Tooling:** no assembler is installed; write a small 65816 assembler in Python (`tools/asm65816.py`, the opcode
  table already exists in `tools/disasm.py`) so the build needs only Python. Output = patched ROM and a **BPS/IPS patch**
  (the repo stays free of game data; users patch their own ROM).
* **Python reference generator** (`tools/trackgen.py`) implements the same algorithm bit for bit; the 65816
  version is tested against it for thousands of seeds with a tiny test ROM harness run headless in Mesen (compare
  the WRAM tables). The Python version also renders each seed with `track_atlas` for eyeballing.

## 3. Generator rules ("sane" tracks)

1. **Length:** N pieces, e.g. 24..44; laps 3..8 (uniform). Optionally laps are biased by N so total race time stays
   reasonable (open question).
2. **Slope:** walk on the level graph. Start level = end level (default flat). Sequence of "events": flat run of 1-8
   pieces, small hill (bump templates 2, 8, 10, 13, 14), long hill = ramp-up + k plateaus + ramp-down, with sign chosen
   per event. Max level depends on a per-track "hilliness" draw (so most tracks are mild, a few are Loch Ness-like).
   Constraint: no two max-level events back to back; total up ~ total down (**verify** if the game cares; slope only
   changes speed, so not required).
3. **Curve:** same grammar with levels 16/24/32/40; chicanes (a bump followed by the mirrored bump), hairpins
   (single-piece bump 17-32), long sweepers. Start/end straight so the lap boundary is smooth. A "turn budget" keeps
   the net signed curvature near zero (a closed loop turns ~360 degrees; not needed for physics, only plausibility).
4. **Road types:** sequence of types, mostly constant with occasional narrowing/widening ramps (0<->1<->2), piece 0
   = start template. **Exactly one pit piece**, not in the first/last 3 pieces, side from the seed.
5. **Pit info:** `DF24 = 0x8000*side | ((piece*1024 - 512)/2)` equivalent; pit object `0x747C` (side bit set for left)
   in the second half of the pit piece. Pit type (2 or 3) and its road style must be wide enough in the chosen
   environment. **(verify per environment)**; environments without a usable type get their road-style word patched
   (`00:DEE4`), which is plain data.
6. **Objects:** per piece 10-20 objects (original density), alternating sides with random spacing, types drawn from the
   chosen environment's own object-type set (e.g. 27/28/9/38 for the desert), lateral from the original range
   (60..206), none inside the pit piece except the pit entrance, none in piece 0 (gantry is a group object `0x8002`
   at position 0).
7. **Environment:** drawn from all 32; New York stays night, Hiroshima night->day etc. automatically.
8. **Difficulty/bots:** unchanged (`00:DDE4[env]`).

## 4. Menus

Reading `0F:918B` (main menu), `0F:943D` (text entry), `0F:821D` (location screen) shows what must change:

| change | where | approach |
|---|---|---|
| COUNTRY -> `RANDOM` / `SEED` | main menu entry 2 (`0F:929E`, string at `0F:A6CD`) | Left/Right toggles like entries 0 and 3 do; `RANDOM` = roll `$1FFC`-based seed on PLAY GAME, `SEED` = open seed entry on A |
| seed entry screen | reuse `text_entry` (`0F:943D`) with a **hex keypad**: 16 keys + DEL + END instead of A-Z | grid strings are plain text tables at `0F:A792`.. ; only the cursor wrap/limits and key->char mapping change (the 8-character buffer `$68..$6F` is exactly an 8-digit hex seed) |
| splash/location screen | `0F:815A` flow, `0F:8A81`, `0F:8ADC` | replace city/country text by `SEED  XXXXXXXX`; STATISTICS shows laps (generated) and distance; skip the minimap upload (`0F:821D/82F0`); keep or drop the lap-record line |
| championship machinery | `0F:8733`, passwords `0F:93DC` | disabled: no country unlock, no passwords; after a race the same screen returns with the seed (replay) or a new seed |
| race HUD minimap | tile upload in the loaders + `update_map_dots` | blank the map tiles and park the three marker sprites off-screen; **optional later:** draw a procedural minimap from the curve data (heading integration) |

Proposed hex keypad (to be refined with your letter-distribution feedback; the original grid is 6 columns wide with
`END` and two glyph cells for space/delete):

```
0 1 2 3
4 5 6 7
8 9 A B
C D E F
< DEL   END
```

## 5. Milestones (each one verified automatically in headless Mesen)

1. **M0 tooling:** assembler, ROM expander/patcher with checksum fix, test harness ROM, BPS output.
2. **M1 Python generator + atlas:** generate 1000 seeds, validate rules (levels chain, start/end equal, one pit, sizes),
   render a contact sheet.
3. **M2 65816 generator + loader hook:** replace `load_track_streams`; harness proves WRAM == Python for 1000 seeds.
4. **M3 race works:** poke a seed, drive/autopilot a lap in headless Mesen (existing `trk_drive.lua` style): speed, laps,
   rank, **computer car pits, human pit trigger works**, results screen, no crash, 20 seeds x 3 environments.
5. **M4 menus:** SEED/RANDOM toggle, hex entry, splash screen, no minimap; scripted menu walk-through with screenshots.
6. **M5 polish:** balance (fuel vs length, laps), optional procedural minimap, demo/attract mode with random seeds,
   README + patch release.

## 6. Risks / unknowns

* Whether every environment has a road type wide enough for a convincing pit lane (**M1/M3**); fallback: patch style words.
* Fuel vs. race length: 8 laps of a 46-piece track is far longer than any original race; the pit stop was designed for
  ~3-8 laps of 23-46 pieces so it should roughly hold; tune in M5.
* Object type sets per environment and their collision handlers (`05:F5C3[type]`) are reused as is — low risk.
* The WRAM scratch for the generator (needs ~100 bytes) must not collide with game variables: use `$7F` bank.
* Real-hardware/flash-cart behaviour of a 1 MB LoROM image is untested (emulators fine).
* 2-player mode, demo mode (`90E6`) and the attract loop all go through `$1F06`: they must be pointed at a seed too.

## 7. Decisions (owner, 2026-10-16)

1. After a race, **return to the main menu**. No accumulated championship points: show only that race's timings and
   points. The seed stays selected (replay) until changed in the menu.
2. Seed = **8 hex digits** (32 bit).
3. Hex keypad layout (section 4) is approved.
4. **Reuse the 32 original environments**; no new environments.
5. **1 MB ROM** is fine.
6. Distribution format is deferred; focus on a working prototype first.

Status: planning only, implementation not started (waiting for the go-ahead).
