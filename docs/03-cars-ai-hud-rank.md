# Session 3 findings (unattended session) – opponents, tracks, nitro, pit stops, HUD

All of these were read from the disassembly and then cross-checked in headless Mesen runs
(`scripts/*.lua`, shared helpers in `scripts/common.lua`; analysis scripts in `tools/`).

## HUD speed (the red digital counter)
`sub_00CE61` (00:CE61) draws it: `km/h = (speed * 24) >> 10`  (`speed*3/128`, i.e. 1 km/h = 42.67 units; the earlier 41.7 estimate was a bit off).
Implemented with the PPU multiplier: `$211B` = speed (16 bit), `$211C` = **24** (km/h) or **15** (miles: 15/24 = 0.625 = 1/1.6) and the result
`$2135 >> 2`. Which unit: `$1FF6` negative => 24; else `$1FB0` (player 1) / `$1FB1` (player 2) non-zero => 24, zero => 15 (mph). The result is
split into digits with the hardware divider (`$4204/$4206` /10 twice) and the digit glyphs (4 words each) from the table at `00:D666 + digit*8` are DMA/written
to VRAM `$0C5B/$0C7B` (units), `$0C59/$0C79` (tens), `$0C57/$0C77` (hundreds); player 2 uses `$0E1B...`.
Example: SPD 5359 -> 5359*24/1024 = 125 (the user saw 124).

## Cars: the 20-entry "race list" (WRAM $0200 base, 18 bytes per car)
* `$0200` = **track length** in position units (`(w0 & 0x3F) * 1024`, 22528 for track 0).
* The list lives at `$0212 + 18*j`, j = 0..19 (20 cars = 18 bots + 2 "player" slots). The slot (X offset, 0..0x156) of the two human/computer cars is in
  `$0204` (player 1) and `$0206` (player 2 / the computer car). Code uses DP=$0200 so offsets look like `$19,X`.
* The list is kept **sorted by progress** with a bubble-sort swap per frame (`00:A1BD`, swap code A276–A2B4 swaps 8 words, the 9th word (+0x10) is per slot and is not swapped).
  Higher address = further ahead (slot 19 = leader).
* Per-car record (offsets from the entry base):

| off | meaning |
|---|---|
| +0 (word) | low 5 bits = car id 0..19; high 7 bits = sprite/palette code (0x44 / 0x64 / 0x04 / 0x20...) used by the OAM builder (`01:8000`, `00:ABFC`) |
| +2 | lateral position (signed 16, 0 = road centre; road limits are +-~0x2800) |
| +4 | lateral speed (signed). Bots keep it constant and just bounce: when the lateral position leaves the road corridor `$7E7000[pos>>4]` (two signed bytes: left, right limit, scaled x256) the sign flips (00:AC9C..ACD3) |
| +6 / +7 | 24-bit progress: byte +6 fraction, word +7 = progress in units, wraps at `$0200` (track length) |
| +9 | lap counter (byte); compared with `$1E56` (= laps in the race, `$DEA4[track]` = 3 for track 0) |
| +A | speed (word). progress += speed * `$1E90` (the multiplier, 00:A18D) each frame |
| +C | acceleration, +E timer: while timer>0, speed += accel and timer--; at 0 accel is cleared (ramp used at the start) |
| +10 | per-slot scratch (cleared each frame at 00:A1B5) |
* When a car crosses the line for the last lap (lap == `$1E56`) its id is appended to the finishing list `$1F12[$1EB0++]` and the current time `$1EAE` is stored in `$1F26[id*2]`
  (00:A1D6..A223, also 00:AB7A for the race-end sim). `$1EB0` = number of finished cars. (`$1EB0 >= 10` => results/"race over" state; the physics skips the engine force.)

### Start grid / bot parameters (race init `00:A558`)
* Template for each car is copied from ROM `00:A732 + 18*k` (k = 0 player1, 1 player2, 2..19 bots). Bots k=2..19 (start order, rear to front):
  (id 6, base 2117, mult 32, ramp 8) (id 9, base 2467, mult 32, ramp 8) (id 3, base 3527, mult 32, ramp 8) (id 7, base 2624, mult 32, ramp 8) (id 10, base 3109, mult 32, ramp 8) (id 12, base 3328, mult 32, ramp 8) (id 8, base 2979, mult 16, ramp 16) (id 5, base 3136, mult 16, ramp 16) (id 19, base 3456, mult 16, ramp 16) (id 11, base 3015, mult 16, ramp 16) (id 16, base 1920, mult 16, ramp 16) (id 18, base 2246, mult 10, ramp 24) (id 2, base 3398, mult 10, ramp 24) (id 13, base 3493, mult 10, ramp 24) (id 17, base 2114, mult 10, ramp 24) (id 15, base 2726, mult 8, ramp 32) (id 4, base 3145, mult 8, ramp 32) (id 14, base 2561, mult 8, ramp 32)
  (id = car id 0..19, base = base speed, mult/ramp = acceleration multiplier and ramp frames; ids 0/1 are the two human/computer slots).
* Initial lateral position is -7680 / 0 / +7168 in a repeating pattern (3 lanes), initial progress = `$0200 - 0x2A0 + 0x20*k` (bots start spread over 0x20 units).
* **Bot cruising speed** = `base + 2*rand(0..255) + diff_offset(track, difficulty)`, with `diff_offset = word[$DDE4 + track*6 + difficulty*2]`
  (track 0: 0 / 80 / 160, track 1: 128 / 416 / 704, track 2: 160/568/976 ...; 16 tracks x 3 words – this is why higher difficulty makes bots faster). The speed is reached
  by the ramp (accel = (that value * multiplier)>>8 for `timer` frames) and then never changes (no rubber-banding for the 18 bots).
  Observed bot speeds at race time: 2001..3769 units (47..88 km/h-equivalent progress units; note that *progress* is speed * `$1E90`).
* Bot lateral speed = +-(100 + rand(0..255)), random sign: they sweep left-right across the road at constant lateral speed and bounce on the road edges.
  That is the "weaving" – bots never look at the player.
* RNG: `00:A89E` – LCG on `$1FF4`: `seed = 13*(seed+7)`, returns `hi ^ lo` byte (optionally scaled by A+1 via the PPU multiplier). Same seed => same race.
* A bot bumping into a human car: 00:A2C4. If lateral distance < 0x800 and the bot was just overtaken/overtaking: P1 -> `sub_00A30C` halves the player's speed (`LSR $1E5A`) and
  sets `$1EF5 |= 0x80` (sound), P2 -> `sub_00A372` same for `$1E5C`/`$1EF6`.
* The human car is also *blocked* by a car ahead: `05:E9AF` (P1) / `05:F174..` (P2) shrink the allowed lateral corridor `[$1A,$1C]` around any car within 0x200 units ahead
  (corridor limits come from `$7E7002[pos>>4]`), pushing you aside instead of letting you drive through.

### Rank (1st..20th)
`sub_00AA79` computes rank for slot X: starts at 21 and decrements for every one of the 20 slots whose (lap byte, slot index) is lower than ours => rank = 1 + number of cars
strictly ahead in (lap, list order). Because the list is sorted by progress this equals the true race position. Stored as `$1E7A` (player 1, **0-based**: 0 = 1st, 19 = 20th) and `$1E7C` (player 2) (00:A233/A23C).
(`$1F00/$1F02` hold the player's final position after the finish.)


