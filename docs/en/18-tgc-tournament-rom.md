# The TGC tournament ROM (`Top Gear TGC Rom (E) [!].smc`)

A community ROM hack made for the *Top Gear Championships* (TGC) tournaments. It lets the organiser **pick the tracks of a tournament in the
options menu**, then plays them one after another with **cumulative championship points** and no qualification rules. Everything below was found
by byte-diffing it against `Top Gear (Europe).sfc`, disassembling the new code (`tools/lindis.py`) and driving it in the emulator
(`scripts/tgc_flow.lua`). The ROM is not in the repository (copyrighted, `*.smc` is git-ignored); the screenshots in `docs/img/tgc_*.png` are
from it.

| | |
|---|---|
| file | 1 048 576 bytes, **no copier header** (despite `.smc`), LoROM |
| base | **Top Gear (Europe)**: the first 512 KB are the Europe ROM (50 Hz patch of docs/15 included) with **322 bytes changed** |
| new space | banks `10` and `12` (file `0x80000-0x97FFF`; bank `11` and everything from bank `13` up is `00`). Code and tables are in `10:8000-9526`, the splash screen (code, palette, tilemap, tiles) in `12:8000-E8F7` |
| header | title `TOP GEAR`, country `02`, but the size byte `$7FD7` is `00` (Europe: `09`) and the complement/checksum words `$7FDC-$7FDF` (`$21B2` / `$DE4D`) are not consistent with each other or with the image; emulators do not care |
| author credit | on the splash screen: *"A gift to Top Gear Championships ... © Kyle Blackthorne, launched 14/07/2019"*, facebook.com/groups/topgearchampionships |

## 1. What the player sees

1. **Splash screen** (`docs/img/tgc_splash.png`) before the game boots: TGC logo, a quote in Portuguese, the credit. It fades in with a mosaic effect and
   leaves when **any pad button** (B, Y, Select, Start, A, X, L, R; not the d-pad) is pressed, or by itself after roughly half a minute (still showing after 1 580 frames in the emulator). Then the normal Kemco / title screens follow.
2. **Options menu** (`docs/img/tgc_menu_track.png`): the fourth row, which was `SPEED KPH/MPH`, is now **`◄ TRACK ►`** and the name of the selected track is
   printed under it (`SAN FRANCISCO`), followed on the right by a **number = how many tracks are in the tournament list**. `PLAY GAME` moved one line down to make room.

   | key on the TRACK row | effect |
   |---|---|
   | Right / Left | selected track `$1F06` +1 / -1, wrapping 31 <-> 0. **All 32 tracks are reachable**, whatever the country unlock state (the COUNTRY row is overridden once a list exists) |
   | **A** | append the shown track to the list (ignored when the list has 32 entries) |
   | **B** | remove the last track of the list (ignored when empty) |
   | PLAY GAME | start (see 2.) |

   The list is **ordered**, may contain the same track several times, and has a maximum of 32 entries. The old "A toggles mph/km/h" action of that row is gone.
3. With a list of **4 to 32 tracks** the game runs a **tournament**: location screen -> race -> RESULTS (points of this race) -> **WORLD RANKING**
   (`docs/img/tgc_world_ranking.png`, accumulated points of all 20 drivers) -> location screen of the next track of the list -> race ... After the last race the
   game shows the stock *"completed Top Gear"* scene and returns to the title screen, which **erases the list and the points**.
4. With **0 to 3 tracks** nothing special happens: the game behaves like the stock Europe ROM (one race on the track shown in the TRACK row, back to the options menu
   afterwards; with 0 entries it is exactly the stock flow). So the minimum tournament is four races (the stock "country" size).

Differences from the stock championship (all verified by forcing race ends, section 5):
* **No qualification.** Finishing 10th is fine; nothing is zeroed, no "sorry you failed to qualify" message, no country/password logic, no unlocks.
* Points per place are the stock 20, 15, 12, 10, 8, 6, 4, 3, 2, 1 (table copied to `10:8010`), but are summed **without the 99 limit** over the whole list.
* The player's **grid position of the next race** still comes from the previous finish (docs/03), as in the stock game.
* At the end `$1F10` (difficulty) is left at **2 (championship)**: a side effect of the "completed" path (`10:8400` writes it). The difficulty chosen in the menu is not restored.

## 2. State kept in bank 7F (`7F:2400-25FF`, never initialised at power-on)

| address | meaning |
|---|---|
| `7F:2400` (w) | "a tournament race is armed". Set at every main-menu entry to `idx != count` (`10:8500`); cleared by the first fade-out afterwards (`10:8300`) |
| `7F:2402` (w) | `idx` = number of races already finished = index into the list of the race about to be run |
| `7F:2404`, `7F:2406` (w) | copies of `$1F00` / `$1F02` (finishing places of player 1 / 2) taken at that fade-out, written back to `$1F00/$1F02` when the next race is set up |
| `7F:2408` (w) | `count`, number of tracks in the list (0..32) |
| `7F:240A + 2*i` (w) | track number (low byte) of race `i` |
| `7F:244A` | units digit of the count while editing (the tens digit lives in `$11DC`, tiles `$1B + digit`) |
| `7F:2450 + 2*car` (w) | tile of the **hundreds digit** to print in the ranking for each car (0 = none, `$1C` = "1", `$1D` = "2" ...) |
| `7F:2490 + 2*k` (w) | 20 tilemap-buffer addresses `$1614 + $40*k`, one per ranking row (compared against the address being drawn) |
| `7F:24FE` | scratch |
| `7F:2500 + 2*car` (w) | **16-bit championship total** of every car id (stock: byte at `$1F4E + car`) |

The block is cleared (`7F:2400-25FF`) and the row table is filled by `10:82A0`, hooked into the title-screen exit (`0F:8F4C`). So a **new tournament always starts at the title
screen**, and a list built before a soft reset/title is lost. The stock byte `$1F4E` still receives `points mod 100` (the code keeps it below 100 and carries into the hundreds digit tile) so the stock drawing code keeps working.

## 3. How it works: the hooks

The hack is a set of `JML` detours from the Europe code into bank `10`; each detour re-executes the instructions it overwrote and jumps back. (Europe address -> new code.)

| where (Europe) | overwritten | detour | what it does |
|---|---|---|---|
| `00:8000` reset entry | `CLD; SEI; LDA #0` | `12:8000` | **splash**: full PPU/CPU register init, BG mode 3 (256 colours), palette `12:8400` (0x200 B), tilemap `12:8700` (0xC00 B), tiles by DMA (programmed as 0x8000 B from `12:9000` + 0x6000 B from `13:9000` = a full 8 bpp set of 896 tiles; the data really present is `12:9000-E8F7`, the rest reads as zeros); 16-step mosaic + brightness fade in; waits until `$4218 & $F0F0` (any pad button) or 255 x ~0.1 s; fade out; `JML 00:8004` |
| `00:818A` main-menu entry | `SEP #$20; LDA #0` | `10:8500` | `7F:2400 := (idx != count)`; `JML 00:818E` |
| `0F:821D` `load_minimap_graphic` (first thing the menu/location screen does) | `LDA $1F06; CMP #$10` | `10:8700` | if `count >= 4`: `$1F06 := list[idx]` (the low byte), so **every screen and the race use the list entry**; otherwise keeps `$1F06` |
| `0F:9242` menu loop, Left/Right pressed | `LDA $5A; BNE` | `10:8100` | row 0: stock 1P/2P toggle; row 3: `$0A == $0100` (Right only) -> `$1F06++` (wrap at 32), anything else -> `$1F06--` (wrap below 0); then `JML 0F:9268` (redraw row 3) |
| `0F:9258` menu loop, other button | `LDA $5A; CMP #3` | `10:8600` | row 3 only: `$0A == $0080` (A) appends `$1F06`, `$0A == $8000` (B) removes the last; updates the two-digit counter drawn at VRAM word `$02B8` through `$11DC/$11DE`; ends at `0F:925D`, whose tail was patched to `JML 0F:922F` (no more mph/km/h toggle) |
| `0F:A01C` end of `draw_string` | `STY $4C; LDA #0` | `10:8200` | when row 3 draws the string at `$A70B`: copies the **track name** (`0D:C77C[$1F06]`, +4, ASCII - `$40`) into the text buffer `$11BE` (13 words) |
| `0F:A1E4` `pos_to_tilemap_offset` | `CLC; ADC #$0C6C` | `10:8270` | pins the position of the string at `0F:A6D5` (a menu line) to buffer offset `$05CA` (not traced further) |
| data `0F:A70B` | `SPEED KPH` | `^ TRACK _` | label with the two arrow glyphs (`5E`, `5F`); `0F:A720` `16 -> 17` moves the PLAY GAME bar one line down |
| `0F:8F4C` title exit | `STX $42; SEP #$20` | `10:82A0` | zero `7F:2400-25FF`, fill `7F:2490..` ; `JML 0F:8F50` |
| `0F:9DC5` `fade_out_dma` (15 callers) | `SEP #$20; LDA #$20` | `10:8300` | if `7F:2400 != 0`: clear it, save `$1F00/$1F02` to `7F:2404/6`; with `count >= 4` fall into the normal fade (re-enters the hook, now disarmed); with `count < 4` set `idx := 0` and resume at `0F:8F50` |
| `0F:84A7` | `BCS $84CB` | `EA EA` | the "race failed" branch after `qualify_check_1p` can never be taken |
| `0F:8678` | `LDA $1F10; ASL` | `10:8800` | `SP += 2`, then the same two instructions (stack fix-up for the detours above; purpose not fully traced) |
| `0F:8733` `advance_track` | `INC $1F04; INC $1F06` | `10:8400` | `idx+1 == count` -> tournament over: `idx := 0`, `$1F06 := 0`, `$1F10 := 2`, `JML 0F:84C0` (that path returns A=3: the "completed Top Gear" scene, docs/13). Otherwise `INC $1F04`, restore `$1F00/$1F02` from `7F:2404/6`, `idx++`, `JML 0F:8739` (the original `INC $1F06` is skipped; `$1F06` is set from the list the next time `10:8700` runs) |
| `0F:8743` | `AND #3` | `LDA #1` | `advance_track` always reports "mid-country" (A=1 -> main menu / next location screen), never "country finished" |
| `0F:8885` points add | `TYX; TAY; SEP #$20` | `10:9000` | `7F:2500[car] += table[place]` (16-bit) before the stock byte add |
| `0F:8894` | `REP #$20; TYA; TXY` | `10:9080` | if the stock byte is >= 100: subtract 100 and `10:94FC` bumps the hundreds-digit tile of that car (`7F:2450`) |
| `0F:8965` standings sort | `TYA; XBA; LDA $1F63,Y` | `10:9200` | compares the 16-bit totals `7F:2500` instead of the bytes |
| `0F:9F48` `draw_string` | `LDA #0; SEP #$20` | `10:9100` | when the string being drawn sits at one of the 20 ranking-row addresses (`7F:2490`), also writes the hundreds-digit tile in front of the number |
| data `0F:8B85` | `#$3D` | `#$30` | leading tens digit of a ranking row is printed as `0` instead of the dot filler (so `105` does not read `.5`) |
| data `06:E01A..E1F1`, `06:E69C..E873` | | | two 472-byte tables of 22-byte records (`xx0c 0300 502c 622c 642c yy0c ...`): pointers moved and two tiles per record (`$2C62`, `$2C64`) blanked. Not traced (looks like tilemap/OAM records of a graphic in bank 06) |
| header `00:FFD7..FFDF` | | | size/checksum fields, see the table above |

The 65816 detours are plain; the two traps found while reading them: they are written for **A = 16 bit** at most entry points (the stock code is in `REP #$20` there), and `10:8300` is entered on **every** `fade_out_dma` call but acts only once per armed race.

## 4. The flow, step by step

```
title screen exit (0F:8F4C) .......... 10:82A0 clears 7F:2400-25FF  (count=0, idx=0, totals=0)
options menu: TRACK row ............. Left/Right pick $1F06, A appends, B removes     (count shown)
main menu entry (00:818A) ........... 7F:2400 := (idx != count)
PLAY GAME -> fade_out ............... 10:8300: armed -> disarm, save $1F00/$1F02; count<4: idx=0
location screen / race .............. 10:8700 sets $1F06 = list[idx] (count >= 4)
race end -> results_flow (0F:83DD) .. RESULTS, then WORLD RANKING: 7F:2500[car] += points[place]
qualify_check (0F:84A4) ............. cannot fail (0F:84A7 NOPed)
advance_track (0F:8733 -> 10:8400) .. idx+1 == count ? end : idx++, restore $1F00/$1F02, A=1
0F:818E main menu (-> 10:8500) ...... 7F:2400 := 1, next location screen shows list[idx]; Start/A runs the race
end: A=3 "completed Top Gear" scene ... $1F10 := 2, idx := 0, back to title -> everything cleared
```

## 5. How this was verified

`scripts/tgc_flow.lua` navigates the real menus, builds a list and forces the end of each race exactly like `scripts/race_end_force.lua` (docs/13), printing the state at each step.
Example (`list = 0, 5, 10, 15`, all races won):

```
main_menu    1F06=15 flag=0 idx=0 cnt=4 list=0,5,10,15 tot0=0
FORCE        1F06=0  flag=1 idx=0 ...                               race 1 on 0 Las Vegas (USA)
draw_points  1F06=0  flag=1 idx=0 ... tot0=20
main_menu    1F06=0  flag=0 idx=1 ... tot0=20                       -> location screen of 5 Machu Picchu (Peru)
FORCE        1F06=5  flag=1 idx=1 ...   draw_points tot0=40
FORCE        1F06=10 flag=1 idx=2 ...   draw_points tot0=60        race 3 on 10 Yokohama (Japan)
FORCE        1F06=15 flag=1 idx=3 ...   draw_points tot0=80        race 4 on 15 Frankfurt (Germany)
WIN_COUNTRY  1F06=0  flag=0 idx=0 1F10=2 -> title_screen -> cnt=0, totals 0
```

* Finishing **10th** in race 1 (`PLACES="9,"`) advances normally and scores 1 point (`tot0=1`): no qualification.
* `TRACKS=5` (one track) and `TRACKS=x` (none) return to the options menu after the race, `idx` stays 0 (stock behaviour).
* Press timing of the tests: splash skipped at frame 700, Start on the title at 1100..1700, options menu usable from frame ~2440, each action held 20 frames (the game polls the pad about every 3rd frame and ignores presses during the fades).

Reproduce:
```
TG_ROM="$PWD/Top Gear TGC Rom (E) [!].smc" TRACKS="0,5,10,15" RACES=4 MAXF=12500 TAG=tgc tools/mesen.sh scripts/tgc_flow.lua | grep -v Uninit
python3 -I tools/romcmp.py "Top Gear (Europe).sfc" "Top Gear TGC Rom (E) [!].smc"      # the 322 changed bytes
python3 -I tools/lindis.py 108100,108140,0,0 108600,1086CA,0,0                          # a hook, M/X hints per range (ROM= env selects the file)
```

## 6. Open items and notes for our work

* **Not tested:** 2-player mode with a list (`10:8400` does `INC $1F04`, the stock `DEC` later compensates only if the mid-country path is taken, which is now always), the idle attract demo with a list armed, lists with duplicate tracks in a row, a list longer than the 20-row ranking screen (it only shows the 20 cars, so no issue expected).
* The 16-bit total drives the sort; the hundreds digit is a separate tile and goes wrong above 999 points (32 races x 20 = 640 at most, so unreachable).
* The `7F:2400` block is **not** initialised at power-on; it is cleared when the title screen is left. A hack that skips the title screen would start with garbage there.
* `10:8300` with `count < 4` resumes at `0F:8F50` after a `JSR`-called fade (one return address stays on the stack per use); harmless in practice because the menu code resets the stack, but it is why that path looks odd.
* Differences with our randomizer (docs/09, 10): this hack changes **which of the 32 stock tracks** is raced and when the series ends; the randomizer generates new tracks. Both use `$1F06` as the single track selector and the stock `advance_track` / results flow, so they could be combined: the series/points part (`7F:2500` totals, `10:9000..9200`) is independent of how the track data is produced. The two hacks use different free space (here banks `10` and `12` of a 1 MB image; ours also 1 MB, see docs/10) and both patch `0F:8733` / `00:818A` region code, so a merge needs a manual check of overlapping hooks.
