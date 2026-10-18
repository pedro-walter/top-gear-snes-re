# Ideal shift speeds per car (flat road, full tank)

Goal: reach the top speed as early as possible with the manual gearbox. `python3 -I tools/gear_opt.py` solves it exactly with a dynamic programme over the game's own speed model (`tools/physics.py`, which matches the game to the unit, see docs/02). The one-tick speed map is monotone in speed for every gear, so keeping the fastest speed per gear at each tick is optimal. The manual box moves one gear per tick (about 25 ms), like the real code (`05:D3B0`); a shift itself costs nothing in this routine. Gears are numbered 1st..5th (index 0..4 in the game). Speeds are km/h on the HUD (units / 41.7). Time: 2 physics ticks per 3 frames.

Assumptions: flat, full tank (fuel burn raises the top speed a little, up to +670 units when empty), no steering, collisions or off-road, throttle held. Not played in the game yet.

## Without nitro

| car (index) | 1st → 3rd (2nd is used for one tick) | 3rd → 4th | 4th → 5th | best top speed | time to 99 % |
|---|---|---|---|---|---|
| red (0) | ~80 (window 70..84) | ~127 (window 98..144) | **never** (4th is faster: 224 vs 212) | 224 | 11.2 s |
| white (1) | ~38 (up to 57) | ~92 (anywhere up to ~135) | ~166 (window 150..174) | 201 | 5.0 s |
| purple (2) | ~63 (41..73) | ~167 (150..175) | ~189 (176..195, tiny gain) | 212 | 9.3 s |
| blue (3) | ~52 (11..64) | ~186 (180..189) | ~195 (185..198, tiny gain) | 209 | 6.8 s |

The windows are the speeds for each shift alone that cost at most one tick against the optimum. The automatic gearbox loses 0.2 s (white) to 1.4 s (blue) on the way and never reaches the top speed of the red car (it upshifts into 5th at 211 km/h).

## With nitro (fired at the start; it lasts 320 frames = 5.3 s)

| car | 1st → 3rd | 3rd → 5th (4th for a single tick) | speed when the nitro ends | auto box |
|---|---|---|---|---|
| red (0) | ~57 | ~162 (window up to 227) | 360 | 359 |
| white (1) | ~68 | ~253 (234..265) | 318 | 293 |
| purple (2) | ~57 | ~229 (191..248) | 333 | 322 |
| blue (3) | ~62 | ~254 (242..262) | 293 | 258 |

So the old "3rd gear + nitro" trick (docs/02) is right, and the exact crossover is 160 / 230 / 253 / 254 km/h (red / purple / white / blue). Without a manual box the auto transmission wastes up to 35 km/h at the end of the nitro on the white and blue cars. When the nitro is fired matters little for the time to the peak: fired at launch it reaches 99 % of its peak at about 5.1 s on every car. Fired later (after reaching the plain top speed) the peak ends 2-3 % higher (red 368, white 332, purple 349, blue 305 km/h), but later.
