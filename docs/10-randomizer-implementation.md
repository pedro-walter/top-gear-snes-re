# Randomizer: implementation status and map

Build: `python3 -I tools/build_rando.py` (needs the original ROM, env `TOPGEAR_ROM`, default `Top Gear (USA).sfc`) writes
`out/rando.sfc` (1 MB, LoROM, header size byte + checksum fixed). Nothing of the original is stored in the repo: the
sources are `src/gen.asm` (generator), `src/hooks.asm` (patches of the original code + menu glue), `src/harness.asm`
(test build only), assembled by `tools/asm65816.py` (own two-pass 65816 assembler; long branches are relaxed
automatically, `$0012` = absolute, `$12` = direct page, `$123456` = long, `.l/.w/.b` suffixes force sizes).

## What works (all verified headless in Mesen)

* **Generator** (`src/gen.asm`, reference `tools/trackgen.py`): seed (32 bit) -> LFSR -> environment (one of the 32 original
  tracks, kept in `$1F06` so every per-track table keeps working), 24..46 pieces, 3..8 laps, slope and curve walks over the
  template graph (docs/09), roadside objects and road type per piece copied in runs from the environment's own track
  (so object sets, tunnels-free scenery and road widths fit the environment), exactly one pit piece (template 20 +
  pit objects, pit word like `00:DF24`), expansion into the WRAM tables `$7E4000/$4C00/$5800/$6400` identical to
  `00:BF44`. **`tools/rando_test.py` runs the 65816 generator in headless Mesen (harness ROM) and compares all four
  tables with the Python reference: 1500/1500 seeds identical.**
  * The loader expands **L+2** pieces (one wrap copy of piece 0 and one look-ahead copy of piece 1). The object scanner
    (`00:E20D`) reads up to 0x58 bytes past the lap end; uninitialised data there made a group loop run ~65 k iterations
    (game ran at 1/4 speed, garbage graphics). Fixed by generating the extra piece.
  * Bank `$7F:0000..$2800` is NOT free: the corridor table `$7E7000` (length bytes) spills into it. Scratch/state lives at
    `7F:F000..F8FF`: seed `F800`, magic `F806` (= $A55A once initialised), keypad flag `F808`, skip-title flag `F80A`,
    generator variables `F830..F87A`, stream arrays `F000..F7FF`.
* **Hooks into the game** (`src/hooks.asm`): `00:BF59` (stream expansion -> generator, sets `$1F06`, `$0200`),
  `00:BF38` (laps), `00:C162` (pit word / side), `0F:9281` (PLAY GAME: derive environment from the seed, clear the
  points table so the results/ranking show only this race), `0F:8487` (results -> back to the main menu, title skipped once),
  menu entry `COUNTRY` -> `SEED` (the whole menu was reworked later, see "Main menu and track series" below).
* **Seed UI**: main menu shows `SEED xxxxxxxx`; Left/Right on that row rolls a new seed; A opens the keypad
  (`src/keypad.asm`, page 8 of the menus reused): **big gold glyphs**, a 6x3 grid, typed code in the
  box in the big font, selection bar = the game's own sprite pill, cursor wraps inside the 18 cells (no blank cell can be
  highlighted). Keys as in the name entry: A or B = press the key (adds a character), X or Y = delete the last one, START or the `END` key = accept; the `<-` key deletes. Typing nothing and
  accepting = roll a new random seed. The seed persists after the race (replay). The splash screen shows `SEED xxxxxxxx`,
  distance (pieces/lap * 15/256 km) and LAPS.
  Grid: `0 1 2 3 4 5 / 6 7 8 9 A B / C D E F <- END`; hex digit 11 is drawn as a lowercase `b` because the squared `B` of the
  font is identical to an `8`.
* **Hex digit glyphs** (`tools/bigfont.py`): the game's gold font (VRAM tiles 128..255) has no 3,4,6,7,9 (0 = `O`, 5 = `S`, 8 = `B`), so the 16 digits are
  drawn by the script (seven-segment strokes, 3 px thick, chamfered corners, the font's gold gradient `$F..$8`, bright top/left edge, `$2` shadow; `1` has a flag and foot, hex 11 / 13 are lowercase `b` / `d` because a
  squared `B` / `D` would read as `8` / `0`) and stored in the ROM as 2 KB of 4bpp tiles (`kp_gfx`; possible since the ROM is 1 MB, and they are our own graphics, not the game's).
  The keypad copies them to VRAM tiles 256..319 (word `$2000`) in forced blank; layout = the game's sprite layout (`tile = 256 + (v>>3)*32 + (v&7)*2`, lower half +16). The arrow and `END` still use the game's glyph tiles.
  `python3 tools/bigfont.py png out.png` renders a preview.
* **Title screen** (`hooks.asm` end, `purple_title` in `tools/build_rando.py`): the sky gradient is an HDMA colour table (CGADD/CGDATA, 224 words at `0D:C7FA` and `0D:C8DA`, blue only); the build adds red in proportion to the blue and lowers green, so the sky is violet. The texts are 8x8 sprites drawn by `draw_string_list` (`0F:9ED3`) from the list at `0F:AFC6` (entries: column, row, pixel offset x, y, text, 0; list end = word 0). The list is replaced by one at `0F:FB62` (unused bank-0F padding; checked with read callbacks over title, menus and a race) with `RANDOMIZER BY PEDRO WALTER` instead of the Nintendo licence line and `POWERED BY CLAUDE` instead of the Kemco line; PRESS START is unchanged, the Gremlin copyright line is removed and the last line reads `VERSION BETA 0.1`. The text list is generated by `title_lines()` in `tools/build_rando.py` (centring, glyph count for the loop below); **change the release name only in `VERSION` there**. The list's code for `.` is `=` (sprite tile `$88`; digits are `$7B..$84`). The OAM buffer only has room for 72 text sprites (sprites 56..127) and the longer lines need 81 with spaces, so spaces no longer emit a sprite (hook at `0F:9EFB` jumps to `0F:FBD0`, which only advances the next glyph's x by 8), and the count in the tile-adjust loop at `0F:8EDC` is the number of glyphs (62 now, was 70; computed at build time).
* **Small-font red dots**: palette 7 of the small sprite font (`0E:FD66`) has red at index 5, used by a few stray pixels in B, D and 8 (visible in the original title text too); the build copies the outline colour (index 6) over it.
* **Signs** (docs/07 object catalogue): the source track's chevron types (8, 9) and pit flags (13) are never copied; the generator places
  5 chevrons (every 4 slots, last one 4 slots before the curve) ahead of every curve onset - type 9 (`<`) on the right before a
  positive curve, type 8 (`>`) on the left before a negative one - and pit flags (type 13, template `$18`/`$1A`) on the two pieces
  before the pit like the original tracks do. Python reference and 65816 code are identical (`add_chevrons`).
* **Lap counters** (`src/bar.asm`, `hook_lapctr`): `LAP lap/laps` (e.g. `LAP 3/7`) right aligned to tile column 29 (as wide as the timer) of the BG1 row under each timer (rows 5 and 19; the 7 cells of `LAP n/m` start at column 23, the cell at column 21/22 is left alone so the last letter of the wide messages such as `4 LAPS LEFT` (columns 11..21) is not blanked; the fuel gauge is column 30 from row 6 down), one per car (the bottom one is the computer in one player mode). `$1E76` / `$1E78` count completed laps (`$FFFF` while the car is still behind the line of lap 1), shown = that + 1, at least 1, at most `$1E56`. Font = the HUD's own tiles for the digits (`$35..$3E`, the timer's) and the A (`$4B`), plus BG1 tiles `$B0..$B2` (VRAM word `$0B00`) for L, P and the slash in the same style, shadow recoloured black, palette 3, generated by `tools/lapfont.py`, uploaded by `hook_bar`). The cells are rewritten every frame from a JSL at the start of `draw_hud_speed` (`00:CE61`, runs with VRAM writable; the hook ends with the replaced `LDA $1E5A` because the caller branches on its flags).
* **Main menu seed row** (`hooks.asm`, `build_seed_tiles`): the small font is 8 lines high but the selector bar is 16, so the 16 hex glyphs (copied into the ROM as `seed_glyphs`: the font is not in VRAM yet when the menu comes back from a race, which showed garbage in the GUI) are written at menu draw (forced blank) into BG1 tiles `$40..$5F` shifted down 4 lines (upper / lower half, VRAM word `$1400`) and the seed is drawn in two text rows with character codes `$80+2v` / `$81+2v` (the game draws code c as tile c-$40).
* **No minimap, lap-progress strip instead** (`src/bar.asm`): the decompressed minimap bitmap is blanked (`0F:8232`) and the lap-record line is moved
  off screen. The black bar between the two views shows the progress along the lap: a red start line (left, white border), a finish line (right), and
  three small borderless 4x2 dots in fixed lanes: player 1 on top, the leader in the middle (hidden while player 1 or 2 leads), player 2 / the
  computer car at the bottom. x = position on the lap (`$1ED7` / `$1EDA` / `$0219+slot`, scaled by the lap length `$0200` to 200 pixels, 8x8 multiply +
  16/8 divide). Colours are the car's own sprite palette, colour 9 (bright: contrast on black is fine for all palettes): players use palettes 0 / 1
  as in the original, the leader the palette of its car record (`word >> 13 & 3`; bots alternate palettes 2 and 3 by record code `$22`/`$32`).
  * The dots are the game's own marker sprites; the tile `$7F` (used only by them, VRAM byte `$4FE0`) is redrawn by `hook_bar` at the HUD build. `update_map_dots` (`00:8910`) is replaced by a JSL to `hook_mapdots`
    which writes `$0112/$0114/$0116` = x | y << 8; the sprite renderer (`01:808B..80AE`, player 1's buffer) already copies them to the sprites. The
    leader's tile/attribute word goes to `$1FB2` (patched `LDA` at `01:80A0`); the leader is found with the game's own loop (highest `$021A` key over the 20 cars) and hidden when it is the slot in `$0204` or `$0206`.
    Player 2's buffer (`01:8590/85A2/85B4`, y + $70) is parked off screen. **Correction:** the routines `00:8966/8A2C` that the earlier text called the
    marker writers are not executed in the race (exec count 0); the old parking patches on them did nothing, so the original dots had been drawn
    over the blank minimap corner. They are left in place for whatever calls them.
  * Why only a thin strip: the game forces blank on scan lines 109..114 (`INIDISP` $8F at `00:BE88`, restored at `00:BEF4`) while it DMAs the palette
    and OAM for the second view, and the second view starts at line 115, so nothing can be drawn there. The visible part of the "bar" is BG1
    tile row 13 = lines 104..108 (five lines); the strip is made opaque black (it covers the last lines of the first view), so the black bar is
    lines 104..114. The original divider (lines 108..115, blank on 109..114) and the whole first view are untouched. Nothing can be drawn on 109..114 (forced blank) and the only visible divider lines are 108 and 115, so the strip is drawn over the last three lines of the first view without a background: 4x1 dashes with black ends in lanes at lines 106 / 107 / 108, start/finish lines as a 3-line tile at lines 106..108. Contrast over a grey road is weak.
  * The start/finish lines are one 4bpp BG1 tile (`$A8`, VRAM word `$A80`; `$A9` = solid black) written with the HUD tilemap: the hook at `00:CBE2`
    (forced blank) replaces the row 13 loop and writes rows 13/14 (`$0DA0..$0DDF`) itself. BG1 uses the palette 3 colours 1 (white), 2 (black) and 3 (red)
    that the game already loads. Tiles `$82..$BF` of the BG1 character area (VRAM `$1040..$17FF`) were unused in all tracks tried.
* Smoke test (`tools/rando_smoke.sh seed...`): 40 random seeds, ~5000 frames each with an autopilot, no stalls
  (race_frames within 6% of real time; the longer tracks are slightly slower). `scripts/rando_pit.lua`: the computer car
  pits on a generated track (state FFFF..0000, fuel refilled to A7FF).
* Human pit stop (`tools/rando_pit_test.sh "seed target"`, `scripts/rando_pit_human.lua`): the player car is steered beyond the pit
  entrance object (the object's side bit set = *left* = negative lateral; targets -9300 style 41, -17500 style 45,
  +17500 style 47) and the pit sequence runs to the end with a full tank - verified on New York, Hiroshima, Rio, Rome.
* 2-player mode (`TWO=1 scripts/rando_menu.lua`) starts and renders both views.
* Full loop (`scripts/rando_loop.lua`): menu -> race -> results -> ranking -> main menu -> new race.
* Demo/attract mode (title idle) starts a demo race on whatever seed is in `7F:F800`.

## Known limitations / ideas

* Seeds are in plain hex, 8 digits; the keypad types right-aligned (`AB12` = `0000AB12`).
* No procedural minimap (replaced by the lap-progress strip above). The pit lane needs a scenery template 20 (type 3) piece: verified visually
  for several environments but not exhaustively.
* Fuel balance: 8 laps of a 46-piece track need two pit stops; the AI handles that, the player has to use the pit.
* Pitfall: **Mesen auto-applies `<rom name>.ips`** found next to the ROM. A stale `out/rando.ips` from an earlier build was applied on top
  of the new `out/rando.sfc` in the GUI (symptom: Left/Right on the SEED row crashed into RAM at `00:2020`); `build_rando.py` now rewrites
  the IPS on every build. Headless `--testRunner` ignores it, so the bug only showed in the GUI.
* 2-player mode, skill levels and the options use the original code (not individually re-tested).
* The unused lap-record table `$1FB2..$1FF1` is used as string scratch for the menu hooks.

## Review round 2 (2026-10-16)
* **Pit styles** are copies of the original combinations (template, side bit, group 41/45 = pit left, 47 = pit right, flag templates and slot,
  road style of type 3, mirror). The pit word's bit 15 is not left/right. `hook_style` (`00:C270`) overrides the per-environment road-style word
  `00:DEE4` (bits 9-11, bit 15) so the pit lane is a proper road in environments whose own type-3 style is something else.
* Flags: `13` in b0/b1 of pieces pp-2 and pp-1 on the pit's side; chevrons every 4 slots from 20 slots before a curve to its end.
  Only the very last piece before the line is empty and straight (curves may run up to it, as on the original Florence); no chevrons within 48 slots of the start gantry (graphics conflict garbled them on seed 12345678).
* **Start gantry**: the scanner `00:E20D` keeps at most 8 distinct graphic ids; extra object types from the pit/chevron pieces make the
  gantry (group `$8002`) disappear in some environments. `tools/gantry_search.py` finds per environment object types to drop from the copied
  source (table `DROP` in trackgen.py / `dropt` in gen.asm). All 32 environments show the gantry (`out/ge_sheet.png`).
* Seed roll mixes H/V counters and the old seed through 4 rounds of the RNG so every digit changes.

## Graphics pool: garbled scenery (review round 4, 2026-10-17)
User report: garbled start/finish gantry (seeds E3973884, 77675249), garbled roadside graphics near the finish / mid-lap / next to the big rocks
(3142E2A7, B09742CB, FF6E4160, 82C31DDC) and garble "all around" where many trees show (84373410).

**Cause.** The roadside scanner `00:E20D` runs every second frame and looks at the 4 slots 40..43 ahead of the camera. The graphic id of each
object type (`00:E9BA[type]`; group objects expand through `00:E888 / E89A`) is loaded by DMA into an **8 KB VRAM pool = 256 units of 32 bytes**
(size of id `i` = word at `00:E888 + 4 * i`; trees 34..184 units, chevrons 54, pit flags 58, **the start gantry 254**). Allocation is
*first fit by address* in a list of at most 8 blocks; a block is freed when the camera has passed the last object of its type. A type that fits
nowhere is skipped (`00:E3BF`, counted by `scripts/rando_pool_probe.lua`) and, since a slot is only scanned for a few calls, its objects are drawn with
whatever tiles happen to be in VRAM. Two things broke it in generated tracks: (1) the gantry needs the whole pool, so any object within ~43 slots before
or ~41 after the line (random pieces 1 and L-1 have trees) leaves it no room, or the neighbours cannot load; (2) shuffled pieces + hazards + chevrons + trees
mix many types and the pool fragments (a 142-unit tree needs a free 142-unit hole; total free space is not enough). The original tracks avoid most of it by hand
(and still glitch briefly in a few places: `tools/pool_model.py --orig`).

**Model** (`tools/pool_model.py`): camera moves one slot per step, same list / first fit / expiry rules. It reproduces the emulator: seed 3142E2A7 failed loads
at camera slots 709, 1061, 1205 in both; E3973884 at 1269 (emulator bucket 1264); original track 3 glitches at 663-667 (emulator: 656).
`garble` = objects within 40 slots of the camera whose graphics are not loaded.

**Fix** (`fit_pool` in trackgen.py, `fit_pool` / `pal_tier` in gen.asm, run last in `add_chevrons`, before the wrap copy):
1. Only the gantry within 44 slots before and 42 slots after the finish line (every other non-group object there is removed).
2. One graphics set per track that fits the pool *altogether* (all types of the lap, so nothing ever has to be evicted): first the always-needed ones
   (group objects, turn signs 8/9, pit flags 13, pit entrance 21/58; the gantry's id 10 is not counted, nothing else is near it), then the hazard type (marked in
   the `KEEP` word array by `hz_put`), then the ordinary types by how many objects use them (first appearance breaks ties) while the sum stays <= 224 units (256 minus a margin for the first fit's fragmentation: 224 left no garble in 1000 seeds of the model, 232 left some, 256 about 1 seed in 30 - always around the pit).
   Objects of unselected types are removed (about 27% of the objects, whole types of the shuffled source pieces; hazards of a type that does not fit next to chevrons and pit
   graphics are dropped rather than shown garbled).
Scratch: `KEEP` 7F:3400.., counters 7F:4000..418F, variables F89A..F8A9. Cost: about 130k CPU cycles on top of 740k for the rest of the generator.

**Result.** Model, 1000 random seeds: no garbled camera slot at all (before: 40 of 60 seeds, about 130 slots each; with 256 units instead of 224: 5 of 300 seeds, in the pit area).
Emulator (`scripts/rando_pool_probe.lua`, failed-load counter over a lap): the seven reported seeds went from 9..141 failed loads to 0, as did 7 other seeds;
the three seeds the 256-unit version still failed (BC095D63, 5A40D714, 8441E20C) are clean with 224. A first attempt, thinning objects whenever the sum of distinct types in a 79-slot window exceeded 256 units, was not enough (fragmentation) and was dropped.

## Roadside scenery fill (review round 3)
Environments whose original track is sparse got empty roadsides. After the turn signs, `add_chevrons` (both generators) fills every
8th empty slot (from slot 52, never within 48 slots of the gantry, never at the pit pieces or the last piece) with a tree/bush,
alternating sides, 60 units outside the drawn road edge. The two types come from a per-environment table (`SCENERY` / `scent`:
the env's two most common tree/bush types in the original data, minus the env's DROP type). Envs 2, 8, 9, 14 and a few others have none
(their art for other types is not loaded - tested on env 14: types 15/24/27 draw nothing), so they stay as sparse as the originals.

## Hazards and difficulty independence (review round 3)
* The object mask is now always `$E000` (objects of every difficulty): the seed decides the track, not the difficulty setting.
* Black Forest's trees (type 31) are only removed within 64 slots of the gantry (`DROPW`); every other environment still drops its DROP types everywhere (a 128-slot window was not enough for them).
* `add_hazards` (both generators, after the turn signs, before the scenery fill; `HAZARD` / `hazt` = rock type and barrier type per environment, taken from the types the environment's own original uses):
  **Frequency matched to the originals** (championship objects: 18 in-road object groups / 13 barrier groups over 32 tracks = 0.56 / 0.41 per track; the copied runs already give 0.48 / 0.32, so only a little is added: 0.60 / 0.34 in 400 seeds):
  one track in 8 gets one rock field (the pattern of the original Los Angeles start, 26 slots) at the first of: 70 slots before a sharp curve onset (|curve| >= 32), 8 slots after a steep slope ends (|slope| >= 64);
  one track in 16 gets one single-lane barrier closure (type 7 yellow barriers where the environment has them) on the first 112-slot straight after slot 300:
  right side tapers in, holds, tapers out while the left side tapers in, holds, tapers out (like Las Vegas on championship). Nothing within 96 slots of the gantry or at the pit pieces; signs/pit/group objects are never overwritten.
  Gantry visible in all 32 environments (checked with a script of the same kind as `tools/gantry_search.py`).

## Main menu and track series (2026-10-24)
`src/menu.asm` replaces the original `main_menu` (`0F:918B` is a `JML mm_run`; the patches of the old five-row menu - COUNTRY label, bar lengths,
`hook_lr`, `hook_menu_draw` - are gone). Six rows, **3 tile rows apart** (rows 6, 9 .. 21 inside the frame of page 0, so nothing has to scroll and the
planned up/down "more options" arrows were not needed; if a row is added later the pitch can go down to 3 with 7 rows before the frame is full):

| row | label | Left/Right | A / Start |
|---|---|---|---|
| 0 | `1 PLAYER` / `2 PLAYERS` | toggle | player setup (original `0F:929B`) |
| 1 | `DIFFICULTY` (the original skill menu, its title is renamed too) | - | skill menu `0F:9652` |
| 2 | `<n> TRACKS` | `<infinity> 1 2 .. 99` ring: Left from `1 TRACK` = infinite, Right from 99 = infinite | - |
| 3 | `SEED xxxxxxxx` | roll a new seed | hex keypad |
| 4 | `SPEED KPH` / `MPH` | toggle | toggle |
| 5 | `PLAY GAME` | - | start |

* Labels are the game's big font drawn by `draw_string_to_buffer` into the text buffer (`mm_text`, strings in bank `$10`); the number of tracks is built as a string
  (`1 TRACK`, `7 TRACKS`, `12 TRACKS`); the **infinity sign** is an own 16x16 glyph (`tools/bigfont.py`, `inf_gfx`, 4 tiles in VRAM tiles `$60 $61 / $70 $71`,
  uploaded in forced blank next to the seed digit tiles) written straight into the tile map. Page 0's label list was redirected (`0D:C738`, table b) to a list that only
  has the title `OPTIONS` (in the free tail of bank `$0F`, `0F:FF17`).
* **SEED is only active with `1 TRACK`.** Otherwise the label, the 8 digits and the selector are grey: tile words get palette 5 (`$1400`; BG palette 1 is the photo!),
  the grey text palette is written into the palette shadow `$050C`, the selector (sprite palette 7, shadow `$064C`) is swapped between the original and a grey one
  (`mm_selpal`); the NMI uploads the shadow when `$90 = $004C` (that frame it does nothing else, hence `mm_push_pal` waits one frame). The cursor can stop on the grey row,
  A and Left/Right do nothing there.
* The cursor returns to the row of the submenu you came from (`MCUR`); after `PLAY GAME` it starts at the top again.
* State (bank `$7F`, `MAGIC2 $5AA5` guards it, initialised by `menu_init` - separate from the seed magic because the test scripts poke the seed magic): `TRKS $FA00`
  (0 = infinite, 1 = one race = default), `DONE $FA02`, `PODIUM $FA04`, `MCUR $FA06`, `CUR $FA08`, `SELG $FA0A`, scores `TOTLO $FA20..` / `TOTHI $FA40..` (20 cars).

### Series (TRKS != 1)
* `PLAY GAME` (`hook_play`): scores cleared, **a fresh random seed** for every race (SEED is inactive), `DONE = 0`.
* After the ranking screen (`hook_afterresults`, `0F:8487`): `DONE++`; infinite or `DONE < TRKS` -> `roll_seed`, `rando_env`, the scroll/font state of the original
  "passed race" path, `JMP 0F:818E` = splash screen of the next track and the race (the original goes the same way after a passed race; the grid of the next race follows
  the places `$1F00/$1F02`, as in the championship). `TRKS == 1` -> back to the main menu as before (title skipped once).
* **Scores keep adding up, as 16 bit values** (the original has one byte per car, which wraps after 12 wins and shows two digits): `0F:8889` (the add in the results
  table) -> `hook_addpts`, the bubble sort of the world ranking (`0F:896F`) -> `hook_cmp`, `draw_points_column` (`0F:8B4E`) -> `hook_ptscol` (up to 5 digits, 0..65535, **left aligned** from
  column 17, blanks behind short numbers; `HIGH=1` in scripts/rando_series.lua forges big scores to check it). Cars 0 and 1 are the two humans (or player 1 and the COMPUTER car in 1P), 2..19 the bots; `$1F4E` is no longer used.
* **No game over.** The qualification tests (top 5 per race, top 3 per country), the point wipe and the title/KEMCO return of the original are not reachable any more
  (docs/13 lists them); nothing in the randomizer ever ends a session because of a bad place.
* **Podium** (after the last race of a finite series, `podium_start`): the scene screen of docs/13 section 5 is reused - checkered `TG` wall, one driver per human
  (celebrating if a human is in the top 3 of the standings, else the sad one) and a `PLAYER n <place>` label from `build_finish_order` (place = standing in the
  series, `$1F62`); 2P shows both players, 1P only the human (the COMPUTER car has no scene). The message is ours (`CONGRATULATIONS / YOU MADE THE PODIUM / SERIES COMPLETE`
  or `SORRY / YOU MISSED THE PODIUM / SERIES COMPLETE`, `msg_win` / `msg_lose`), hooked at `0F:8584` / `0F:8592`; the password block (`0F:85F2`) is skipped; BG1 scroll has to be
  set to `$0010` first (the ranking scrolls the layer away: black screen without it). After a key press `hook_podend` (`0F:8669`) goes to the main menu (title skipped once).
* Infinite series never reaches the podium; the world ranking after every race is the scoreboard.

Tests: `scripts/rando_series.lua` (env `TRACKS` = 0 infinite / n, `TWO=1`, `PLACES="0,3,.."`, `SHOTS`): sets the menu through the keys, forces the end of every race like
`race_end_force.lua` and prints `results_flow / har_next / podium_start / hook_podend / mm_run` with frame numbers (verified: 1 track -> menu, 2 and 8 tracks -> podium, 0 -> 9
races without podium, 2P podium with both drivers, 3-digit scores in the ranking). Scripts that navigate the menu were updated (SEED is row 3, PLAY GAME row 5;
`common.lua` adds the extra Down when `TG_ROM` contains `rando`).
