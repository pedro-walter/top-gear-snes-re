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
  menu entry 2 `COUNTRY` -> `SEED`.
* **Seed UI**: main menu shows `SEED xxxxxxxx`; Left/Right on that row rolls a new seed; A opens the keypad
  (`src/keypad.asm`, page 8 of the menus reused): **big gold glyphs**, a 6x3 grid `0 1 2 3 4 5 / 6 7 8 9 b A.. ` see below, typed code in the
  box in the big font, selection bar = the game's own sprite pill, cursor wraps inside the 18 cells (no blank cell can be
  highlighted). Keys: A = press, B/Y/X/Select = delete, START or the `END` key = accept; the `<-` key deletes. Typing nothing and
  accepting = roll a new random seed. The seed persists after the race (replay). The splash screen shows `SEED xxxxxxxx`,
  distance (pieces/lap * 15/256 km) and LAPS.
  Grid: `0 1 2 3 4 5 / 6 7 8 9 A B / C D E F <- END`; hex digit 11 is drawn as a lowercase `b` because the squared `B` of the
  font is identical to an `8`.
* **Missing digits** (`tools/bigfont.py`): the gold font (VRAM tiles 128..255, 16x16 glyphs in sprite layout, slot 0 blank, 1..26 = A..Z,
  28 = `1`, 29 = `2`, 30/31 arrows) has no 3,4,6,7,9 (0 = `O`, 5 = `S`, 8 = `B`). They are cut from rectangles of existing glyphs
  *on the console* when the keypad opens (reads the tiles back from VRAM in forced blank, writes VRAM tile 256.. by DMA): the repo
  and the IPS only contain the rectangle recipe, no game graphics.
* **Signs** (docs/07 object catalogue): the source track's chevron types (8, 9) and pit flags (13) are never copied; the generator places
  5 chevrons (every 4 slots, last one 4 slots before the curve) ahead of every curve onset - type 9 (`<`) on the right before a
  positive curve, type 8 (`>`) on the left before a negative one - and pit flags (type 13, template `$18`/`$1A`) on the two pieces
  before the pit like the original tracks do. Python reference and 65816 code are identical (`add_chevrons`).
* **No minimap**: the decompressed minimap bitmap is blanked (`0F:8232`), the three HUD marker sprites are never drawn
  (`00:8966`, `00:8A2C` return immediately), the lap-record line is moved off screen.
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
* No procedural minimap yet (box stays empty). The pit lane needs a scenery template 20 (type 3) piece: verified visually
  for several environments but not exhaustively.
* Fuel balance: 8 laps of a 46-piece track need two pit stops; the AI handles that, the player has to use the pit.
* Pitfall: **Mesen auto-applies `<rom name>.ips`** found next to the ROM. A stale `out/rando.ips` from an earlier build was applied on top
  of the new `out/rando.sfc` in the GUI (symptom: Left/Right on the SEED row crashed into RAM at `00:2020`); `build_rando.py` now rewrites
  the IPS on every build. Headless `--testRunner` ignores it, so the bug only showed in the GUI.
* 2-player mode, skill levels and the options use the original code (not individually re-tested).
* The unused lap-record table `$1FB2..$1FF1` is used as string scratch for the menu hooks.
