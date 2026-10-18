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

## Fuel (05:D638..D67B)

Per tick the burn is `((RPM * burn_byte) >> 14) + 1`, with RPM = `((speed * ratio) >> 8) << 1`, ratio 127/96/58/42/30 for 1st..5th (the same for all cars, nitro rows too) and burn_byte 100/64/90/82 (red/white/purple/blue). Fuel per km is therefore almost proportional to the gear ratio: 5th burns about 30 % less than 4th at the same speed. A full tank is 43007 units. As the tank empties the top speed rises by up to 670 units (+16 km/h).

Flat road, throttle held, full tank, one 2.4 km lap from a standing start (model only, not measured in the game; km assume 40 ticks/s):

| | time | fuel |
|---|---|---|
| red, stays in 4th | 39.4 s (ends at 239 km/h) | 29857 (69 % of a tank) |
| red, 5th from ~190 km/h | 41.5 s | 22517 (52 %), -25 % |
| white / purple / blue, optimal shifts | 43.3 / 41.4 / 41.4 s | 13774 / 20045 / 18523 |
| same, every upshift at 70 % of the optimal speed | +0.05 / +0.2 / +0.3 s | -1 / -3 / -3 % |

So the shift speeds hardly matter for fuel (the acceleration phase is short); the cruising gear does. White, purple and blue already cruise in 5th, which is both the fastest and the cheapest gear. Only the red car has a real choice: 4th (+2 s per 2.4 km, +33 % fuel) or 5th. One nitro costs 2700-3800 units (6-9 % of a tank) but covers about 0.35-0.40 km in 5.3 s, so its cost per km is 0.7-1.1 times the normal one.
