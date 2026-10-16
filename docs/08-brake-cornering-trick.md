# The accelerator + brake cornering trick (player 1 only)

Holding **accelerate (X) and brake (Y) together** lets player 1 hold a much sharper / faster corner without sliding outward.
It works because of how the steering grip limit is chosen in the player-1 update (`05:D4A6..D575`), and it exists only for player 1.

## Mechanism
Per game tick (`$1E90` = frame delta δ, 1..7):

| variable | meaning |
|---|---|
| `$1E8E` | forward distance this tick = `(speed/2)*δ` (`05:D686..D6BA`, saturating) |
| `$1E7E` | steering state; its high byte is the "steering angle" (Left/Right add `$9AC3[δ]` per tick, max `0x51FF`) |
| `$1E94` / `$1E92` | **limit on the lateral displacement the steering may produce this tick** (+ / −) |
| `$1E8A` | lateral position (0 = road centre) |

Steering displacement `D = $1E8E * hi($1E7E) / 256` (`05:D995..D9AA`). If `D` exceeds the limit (`CMP $1E94`, `05:D9AC`) it is clipped to the limit,
`$1EF5` bit 0 is set and the steering state is rolled back (`05:D9B1..D9C7`), so the steering cannot grow any further.
The curve then pushes the car outward by `P = $1E8E * c / 256` (`c = $7E4C00[pos>>5]`, `05:DA1A..DA79`), **uncapped**.

The limit is chosen from three ladders in bank 00 (index = `(δ-1)*2 + $1EE8`, `$1EE8` = car*16; 4 cars positive rows, 4 negative rows):

| situation | tables | limit |
|---|---|---|
| not accelerating (coasting) | `$97DF` / `$981F` | **640·δ** (all cars) |
| accelerating with fuel (`$1F76` mask X pressed, `05:D4B0..D4D7`) | `$985F` / `$989F` | **384·δ** (car 1 = 416·δ; the other cars 384) |
| accelerating **and braking** (`$1F78` mask Y pressed, P1 only, `05:D55F..D578`) | `$98DF` / `$991F` | **640·δ** again |

So the throttle costs 40 % of the grip, and holding brake in addition gives the full coasting grip back while the engine keeps pulling.
Player 2's brake code (`05:DDC5..DE49`, mask `$1F95`) only sets the brake-light flag and slows the car; it never loads the `$98DF/$991F` tables.
Braking sets `$0108` bit 15 (brake-light palette, `00:BC36..BC6D`). Braking itself slows the car every tick by
`(|top-speed| + (0x800 if speed>top)) * 11 / 256` (`05:D57C..D5E4`).

## Cornering condition (verified in the emulator)
With δ cancelling out, the corner can be held while the capped steering still beats the push:

`384·δ ≥ (speed·δ/2)·c/256  ⇔  speed·|c| ≤ 196608`  (accelerating)
`640·δ ...                  ⇔  speed·|c| ≤ 327680`  (accelerate+brake, or coasting)

In km/h (`km/h = speed*24/1024`): max km/h ≈ **4608/|c|** accelerating, **7680/|c|** with brake (or coasting).

| curve value c | accelerating | accelerate + brake |
|---|---|---|
| 16 | 288 km/h | 480 |
| 24 | 192 | 320 |
| 32 | 144 | 240 |
| 40 | 115 | 192 |

Measured with `scripts/brake_corner.lua` (car parked inside a constant curve, speed forced, steering held toward the corner; net outward drift crosses zero at):
c=24: X only 7900 (185 km/h), X+Y 13100 (307 km/h), coasting 12900; c=32: X only 5900 (138 km/h), X+Y 9900 (232 km/h), coasting 9900 (prediction 6144 / 10240 / 10240 units).
The user's red-car observation (about 243 km/h) therefore fits curves of c ≲ 31, and 230 km/h in 4th gear fits c ≲ 33.

Largest |c| per track (`tools/tracks.py`, curve stream): most tracks peak at 32, but 7 Rain Forest, 8 Tokyo, 12 Munich, 18 Helsinki, 28 London, 29 Sheffield and 30 Loch Ness reach 40
(only ≤192 km/h with the trick); 2 New York, 5 Machu Picchu, 14 Black Forest and 25 Rome peak at 24, 3 San Francisco, 6 Chichen Itza and 31 Stonehenge at 16.

## Gears and cars
The limit does not depend on the gear; the car only changes it through the speed it reaches (and car 1's 416 accelerate-only limit). The gear matters because holding the brake slows the car every tick
by an amount that depends on the gear's `top` (`$1EE2`): the decel is `(top-speed)*11/256` below top and `(speed-top+2048)*11/256` above it, i.e. much larger when the gear's top speed is below the
current speed. Staying in the gear whose top speed is just above the current speed (the red car's 4th gear is faster than 5th without nitro) therefore bleeds less speed. Not yet measured precisely:
in a poked-gear test (`scripts/brake_eq.lua`, flat road) the accelerate+brake speed fell to ~3600 in gear 1 and to 0 in gears 2-5 within 400 frames, so the trick is a short-term technique.

## Reproduce
`tools/mesen.sh scripts/brake_corner.lua` (writes `out/brake_corner.txt`), `scripts/brake_probe.lua` (button masks and tables), `scripts/brake_eq.lua`.
Masks: `$1F76`=0x0040 X accelerate, `$1F78`=0x4000 Y brake, `$1F7A/7C/7E` R/L/A (gear up/down/nitro), `$1F80`=0x0200 Left, `$1F82`=0x0100 Right.
