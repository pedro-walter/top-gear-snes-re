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



## RNG and backmarker behaviour (investigated with `scripts/bots_probe.lua`, original ROM)
* **RNG users** (`00:A89E`, only 7 callers): car colour picks on the title (`00:815E/816A`, 2 draws), **race_init** (2 draws per bot = 36: speed jitter, then lateral-speed magnitude; the sign comes from bit 0 of the same draw), and sound-variant picks in the crash/bump code (`00:B3F2`, `05:E99F`). Nothing in the race loop draws randomness: bot behaviour is fully fixed once race_init has run.
* `$1FF4` is only ever *written* by `rng` and by the attract mode (`0F:90F8`, seeded from `$1FFC`). It starts at 0 in Mesen (first draw gives `$005B = 13*7`), so after a fresh boot the first race is always the same. Later races depend on how many draws happened before. The 36 race_init draws are therefore the whole "randomness" of a race.
* **Bots exist for the whole race**: 18 bots are created at race_init and never spawn/despawn. Their speed is fixed after the start ramp (verified: constant for 17 of 18 bots over 500 frames). The player starts on the grid slot of the previous finishing position (`final_pos*18` in the car list).
* **Bots never touch each other** (the collision test in `00:A2C4` only fires when the car in front in the list has speed 0, i.e. a human car).
* **Lateral movement is only simulated near the player** (`update_bot_cars` 00:ABFC, `update_visible_cars_p2` 00:AEF3). Each frame it takes the cars from 16 units behind a human car up to 0x400 (1024 units = 32 road slots) ahead, steps `lateral += lateral_speed` and bounces on the corridor `$7E7000`. Exception: the first car at or after the window start is always updated, however far ahead it is. Everything else is frozen: no catch-up, so a car re-entering the window continues from its old lateral position and direction. Measured: inside the window the lateral changed on 32% of frames (the game ticks about every third frame), outside 0%, except the nearest car ahead (and, in 1P, the same rule around the idle player-2 car).
* The window also feeds the draw list (`$178A` depth+0x80, `$178C` side/lateral, max 20 entries); the road renderer in WRAM (`7E:2D6F`) emits a car when its depth is below the slot it is currently walking (`CMP $8E`).
* There is **no logic that keeps bots away from the player**. On track 0 (22528 units, 18 bots) the window covers about 4.5% of the lap, so with the field spread out you see 0-1 bots most of the time (0 in window on 87% of the frames of the probe run, whose driver was crude: accelerate only, no steering). Only the grid at the start fills the window (all 18 cars). Longer tracks make this sparser.
* **Player-bot contact transfers speed** (`05:E944`, `05:E970..E99E`): the bot gets its speed pushed towards the player's, and an acceleration of -(delta)/64 per tick for 64 ticks (`$0220 = 0x40`) so it eases back to its own cruising speed. Observed: a bot at 2001 jumped to 3072 and decayed by 17 per tick back to 2001 in 63 ticks.

### RNG details, bot parameters and the start grid (follow-up)
* `rng` is a 16-bit linear congruential generator: `seed = 13*seed + 91 (mod 65536)` (13 is odd-1 divisible by 4 and 91 is odd, so it has the full period of 65536). The returned byte is `hi ^ lo` of the *new* seed; with A != 0 it is scaled to `0..A` by the PPU multiplier. Every call advances the seed, so the sequence is fully determined by the seed and the call order.
* Per bot, race_init draws twice: (1) speed jitter `j = rand(0..255)`: target speed `S = template_base + 2*j + diff_offset`, then accel = `S*mult >> 8` for `ramp` ticks (mult*ramp is 256 for three of the four template groups, 240 for the id 18/2/13/17 group, so the final speed is about `S`, 0.94*S for that group); (2) lateral speed `100 + rand(0..255)` position units per tick, negative when bit 0 is set. The two draws are independent, and so are speed and lateral speed (measured correlation over the 18 bots: -0.18, not significant). The impression that fast bots weave less comes from distance: a faster car covers more road per sideways sweep.
* Start grid: race_init copies the 20 templates in order and puts the player at list slot `final_pos*18`, where `$1F00` is the 0-based rank of the previous finish (0 = won, 19 = last); slot 0 is the rearmost grid place. So the grid is reversed: winning puts you at the back, finishing last puts you in pole. `$1FF2` is 0 only until the first track load after boot, so the very first race starts at the back. The randomizer does not touch `$1F00`/`$1FF2` or race_init and behaves identically (checked with `scripts/rando_grid.lua`: previous rank 0/5/19 gives slot 0/5/19 on both ROMs; a finish in last place stored `$0013`).

### When the RNG seed changes (`scripts/rng_watch.lua`, original ROM)
* `$1FF4` sits inside the persistent area `$1F00-$1FFF`. At reset the code checks a magic value (`$1F91 + $1FAE == $7543`, `00:8101`); if it is wrong the whole area is zeroed (`00:8110`, includes the seed). Power-on RAM fails the check, so a **cold boot starts the seed at 0**; a soft reset keeps it. Logged writes: two at boot (`00:8113`, the clear), then only `rng` itself (`00:A8BA`).
* **Writers**: the boot clear, `rng`, and attract mode (`0F:90F8`, seed := `$1FFC` frame counter when the idle demo starts). No menu code writes it (static search of all indexed stores into `$1Fxx`; none reaches `$1FF4`). Choosing 1P/2P, names, gearbox, controls, car, difficulty or country does not touch the seed (the scripted walk only covered start/down/A; the rest is from the static search).
* **Draws**: `race_init` 36 per race (2 per bot); crash/bump sound variants (`00:B3F2`, `05:E99F`) a few per contact; the car colour picks at `00:815E/816A` run only in the demo path (`$1FF6` set), not in normal play.
* **Consequences**: the seed is never reset between races. The first race after a cold boot (no demo before it) always has the same bot jitter/lateral speeds/weave directions. Race n+1 starts from the seed left by race n, so it depends on the number of bump-sound draws, i.e. on how the player drove. Waiting on the title until the demo runs reseeds from the frame counter and makes the next race timing-dependent.
* **Grid reset** (not the RNG): `0F:84CB` / `0F:84E1` set the previous finishing position to 0/1 (back of the grid) when the human finished outside the qualifying places (`qualify_check_1p`) or after `advance_track` signals the end of the championship (read from the code, not traced in the GUI).
* The randomizer does not touch `$1FF4` (its seed generator is separate), so the same behaviour applies to it. Idea, not done: seed `$1FF4` from the track seed for replayable bot fields.
