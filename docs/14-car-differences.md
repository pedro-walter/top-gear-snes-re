# What differs between the four cars (red, white, purple, blue)

The select-screen texts (MAX SPEED / 0 TO 60 / TIRE GRIP / FUEL CONSUMPTION) are static strings, one block per car
(ROM ~0x7A883, 0x7AA41, 0x7AACB, 0x7AB59). Nothing in the physics reads them.
`$1F8F` = car, `$1EE8` = car*16 (00:A714); every per-car table is 16-byte rows (5 gear words, nitro rows at +58), indexed `car*16 + 2*gear`.
δ = `$1E90` (frames since last tick + 1; 2..3 in the headless runs). Test scripts: `scripts/car_accel.lua`, `scripts/car_steer.lua`.

| | red | white | purple | blue |
|---|---|---|---|---|
| label MAX SPEED / 0-60 / GRIP / FUEL | 147 / 5.9 / LOW / HIGH | 131 / 3.5 / **HIGH** / LOW | 137 / 5.0 / LOW / MID | 137 / 4.3 / MID / MID |
| top speed `$9597` per gear 0..4 | 4500 6000 8400 9600 10000 | 4000 5800 7400 8000 8500 | 4200 6000 8400 8900 9200 | 4200 6000 8400 8900 9000 |
| thrust factor k `$967F` | 108 32 16 12 8 | 112 48 38 34 24 | 108 32 22 17 14 | 108 40 30 18 15 |
| drag centre D `$960B` | 24000 12500 9500 9900 11000 | 24000 12500 7500 8750 9000 | 24000 12500 9500 9750 10000 | 24000 12500 9500 9750 9500 |
| fuel burn `$97DB` | 100 | 64 | 90 | 82 |

## Speed update per physics tick (05:D3E1..D486, D4DB..D527), throttle on, v = speed, T = top speed (`$1EE2`)
1. `v += (T - v) * k >> 10` while v < T (k = `$967F`; halved if `$1EF5` bit 4). If v > T: `v -= (v - T) >> 8` (low byte). T = `$9597` + `(A7FF - fuel) >> 6`.
2. Hill: `v += (-slope * hillfactor[gear]) >> 4` (`$96F3`, the same for all cars: 4 5 6 9 14).
3. Drag (D453..D486): `v -= min(255, |D - v| >> 8)`. D = `$960B` entry. It is smallest when v = D, not a plain coefficient.
Neither step uses δ. Equilibrium (hill 0): `v* = (k*T - 4*D) / (k - 4)`; measured on a flat track, full throttle, auto gearbox,
speed 4120 (= 60 mph) reached after 2.1 s (red), 1.25 (white), 1.78 (purple), 1.33 (blue) frames/60; the top-gear plateau was
8850+ (red, still rising), 8375, 8840, 8730, so top speed is where thrust and drag balance, below the `$9597` value for red.
The select-screen 0-60 numbers keep the same order and about the same ratios (x2.8), except blue (x3.2).

## Steering ("grip")
* Cap on the lateral displacement per tick (`$1E94`): coasting 640*δ for every car; throttle on 384*δ, **white 416*δ** (+8.3%); throttle+brake (P1) 640*δ. Measured, identical for the other three cars.
* Steering-angle ramp per tick (net, measured, identical for all four cars): `608*δ` (x2 below speed 0x280) minus the centring pull `320*δ` (`$9B01`).
* `$9DDF` (subtracted from the ramp above speed 0x280) has a non-zero row only for blue (160..1280), but the code indexes it with X = 2*δ only (high bits left from earlier code, 0 for P1), so it reads row 0 (all zeros). Measured: blue's ramp equals the others. The row is dead for player 1 (P2/computer copy at 05:E120 uses the same pattern).
So the only physical grip difference for a human player is white's throttle cap; blue's MID has no effect on P1 steering, and red/purple/blue are equal.
