# Saving fuel: what works, what does not (measured in headless Mesen, USA ROM)

Question: tournament play, purple car (red second). Some tracks need two pit stops; is there any way, besides shifting to 5th early, to save the little fuel that removes one stop? Driving slower (about 170 km/h, ZSNES 1.42) "backfired".

Method: `scripts/fuel_lab.lua` drives the real game with a steering bot (PD controller on the lateral position `$1E8A`, throttle held, manual gearbox poked on, car/track poked) and logs every physics tick (speed, gear, fuel, position, frame delta). `tools/fuel_sum.py` summarises per lap, `tools/fuel_stops.py` turns the per-lap fuel into pit-stop counts. All numbers are Mesen (accurate timing); see the open question at the end.

## 1. Slower is not cheaper (this explains the backfire)

Per tick the burn is `((RPM*burn_byte)>>14)+1`, one tick per ~3 frames (`$1E90` = frame delta, 2.5..3.0), and the distance per tick is `speed*delta/2`. Measured fuel per distance, purple, 5th gear, Tokyo + London laps (about 30 000 ticks):

| speed | 105-160 km/h | 160-200 | 200-220 | below 100 |
|---|---|---|---|---|
| fuel per distance (relative) | 1.00 | 1.00 | 1.00 | **1.4 to 3** (the delta also drops to 2.2..2.6 when crawling, so more ticks per km, plus the constant +1 per tick) |

In 5th gear fuel per km is **flat from 150 to 220 km/h**; the constant `+1` per tick is only 5-8 % of the burn. Lifting off the throttle never helps (docs/12: burn does not depend on the throttle). A speed cap in 5th: 200 km/h or higher = same fuel, 170 = +2.5 % per lap, and 150 = +32 % **only because the bot never reached its 4th→5th shift speed and stayed in 4th**. If the car sits in 4th at 170 km/h (or the automatic box, which only upshifts into 5th at ~211 km/h) the RPM is 40 % higher, which is a likely cause of the ZSNES result. Rule: whatever the speed, be in 5th.

## 2. Things that save fuel (purple, steered bot)

| lever | effect | cost |
|---|---|---|
| **Upshift early** (`SH=20,28,36,44` or "up every tick") | first lap Tokyo 9748 vs 10121 (-3.7 %), London 3 laps 31041 vs 31620 (-1.8 %); about -370 per stint (launch and every pit exit) | about 0 to +1 s |
| **Run the tank dry and coast** | the empty car glides **5550 position units from 171 km/h = 0.14 lap = about 1400 fuel-equivalent (3 % of a tank)**; gears 2-5 are identical (+-2 %), 1st only 3800 | none, if it ends at the pit entrance or the line |
| **Nitro** (all three) | fuel-neutral: one nitro 700 frames after the start: 9752 vs 9748 fuel, **-1.9 s**; 1500 frames: 9465 (-3 %), -1.4 s | none |
| Cap the speed just under a burn step (purple 200.4 and 218.6 km/h) | 3 laps London: 30905 (cap 218) / 30966 (cap 200) vs 31041: -0.3 %, +1.4 s / +3.1 s | not worth it |
| Lift in corners (`CORNER=lift`) or brake trick | 1.5 % less fuel, +2 s per lap (the lift loses speed) | not worth it |

The burn is an integer that steps up by 1 at fixed speeds, so cost per km is a sawtooth of +-4 %: purple 5th steps at 182.2, **200.4**, **218.6**, 236.8 km/h (red 5th 180.4, 196.8, 213.0, 229.4; red 4th every 11-12 km/h). In practice the tick length (`$1E90` between 2.5 and 3.0, driven by how much the game has to draw) changes fuel per km by up to +-8 %, more than the sawtooth, so holding a speed just under a step is not measurable and costs more time than it saves.

## 3. What a pit stop costs (forced trigger on Tokyo, P1)

* No refuel (leave in the "wait for accelerate" state with fuel != 0): **5.3 s** lost.
* With a refuel: **7.5 s + 0.26 s per 1000 units** added. Refuel runs at 63.5 units per frame (`+$7F` every second frame, not every frame as docs/04 assumed): 34400 → 43007 takes 150 frames. A full stop from 34400 is 9.7 s.
* Leaving early needs *fresh* presses of accelerate during the refuel state (holding it from before does nothing), so a partial refuel is possible: refuel only what the rest of the race needs.

So saved fuel is worth only 0.26 s per 1000 units, but **a saved stop is worth 7.5 s plus the whole second refuel's overhead**: all that matters is whether you cross a stop threshold.

## 4. How many stops (idle model from `base_t<track>_c<car>.csv`, centred car, pits only at the pit entrance, refuel to full)

Run `python3 -I tools/fuel_stops.py 2` (purple) or `0` (red). Tanks needed for the whole race (1 tank = 43007), ideal / bot-realistic (+3.4 % fuel per lap as measured with the steering bot, three laps London/Tokyo):

| track | laps | purple tanks | purple stops: ideal, realistic, + early 5th, + dry-tank coast | red tanks | red stops same |
|---|---|---|---|---|---|
| 3 San Francisco | 6 | 1.00 | 0, 1, 1, **0** | 1.10 | 1,1,1,1 |
| 4 Rio | 6 | 1.38 | 1,1,1,1 | 1.55 | 1,1,1,1 |
| 6 Chichen Itza | 6 | 1.09 | 1,1,1,1 | 1.23 | 1,1,1,1 |
| 8 Tokyo | 7 | 1.53 | 1,1,1,1 | 1.70 | 1,1,1,1 |
| 9 Hiroshima | 5 | 1.03 | 1,1,1,1 | 1.17 | 1,1,1,1 |
| 11 Kyoto | 6 | 1.45 | 1,1,1,1 | 1.62 | 1,1,1,1 |
| 12 Munich | 7 | 1.43 | 1,1,1,1 | 1.62 | 1,1,1,1 |
| 14 Black Forest | 6 | 1.20 | 1,1,1,1 | 1.33 | 1,1,1,1 |
| 15 Frankfurt | 8 | 1.39 | 1,1,1,1 | 1.52 | 1,1,1,1 |
| 21 Nice | 7 | 1.32 | 1,1,1,1 | 1.46 | 1,1,1,1 |
| 22 Bordeaux | 6 | 1.21 | 1,1,1,1 | 1.34 | 1,1,1,1 |
| 25 Rome | 6 | 1.39 | 1,1,1,1 | 1.54 | 1,1,1,1 |
| 28 London | 8 | 1.86 | 1, **2, 2, 1** | 2.07 | 2,2,2,2 |

(The other tracks have no pit and 3-4 laps.) Extra consumption a 1-stop plan can absorb before it needs a second stop (ideal model): purple Tokyo +18 %, Rio +33 %, Rome +34 %, **London +1 %**; red Tokyo **+6 %**, Kyoto +17 %, Rome +20 %, Munich +20 %, Frankfurt +21 %.

So by this model the **only purple track where fuel saving removes a stop is London** (and San Francisco could go with no stop at all); red London needs two stops whatever you do. **Tokyo is one stop for purple with an 18 % margin and for red with a 6 % margin.** If Tokyo needs two stops in your game, it burns at least 18 % (purple) / 6 % (red) more than in these runs.

London purple end to end (steering bot, early upshift, forced pit trigger at the entrance pos 10752 of lap 5, fuel 0): the tank ran dry exactly at the entrance (without gliding it is 2500 position units short, with the pit at 27 % of the lap), the car entered the pit at 177 km/h with `fuel == 0` (the game handles that, 05:D75E sets `$1EB4` bit 0), refuelled 0 → 39243 in 600 frames, and had 8566 left with 0.8 lap to go (about 8500 needed). The logging ended there, so the finish itself was not observed: one stop works, but with a margin of about 1-2 %.

## 5. Open question: the emulator

Fuel per distance is proportional to `1/delta`, where delta (`$1E90`) is how many frames one main-loop pass takes. The loop is CPU bound (about 3 frames per pass on a real SNES and in Mesen, docs/15). An emulator that runs the 65816 loop faster than the hardware (ZSNES 1.42 is not cycle accurate) gets 2 frames per pass, and then **the same driving burns 50 % more fuel per km** (and the nitro/pit refuel timers, counted in frames, stay the same). If the tournament runs on hardware or an accurate core, plan with the table above; if it is ZSNES, the stop counts above are optimistic. Which emulator is the tournament on, and how many stops does Tokyo (purple) need there? That settles it; I cannot run ZSNES here.

## Reproduce

```
TRACK=28 CAR=2 LAPS=5 STEER=1 SH=20,28,36,44 TAG=L_ref tools/mesen.sh scripts/fuel_lab.lua
python3 -I tools/fuel_sum.py out/fuel/L_ref.csv
```

Env: `TRACK CAR(0 red,1 white,2 purple,3 blue) LAPS STEER(1=bot steers, 0=lateral pinned to 0) SH(shift speeds km/h 1→2,2→3,3→4,4→5) CAP/CAPU(lift above km/h / raw units) CORNER(full|lift|brake) NITRO(frame after the start to press A) PITAT/PITLAP/PITFUEL(force the pit at that pos in that lap, leave at that fuel) COASTAT/COASTG(run dry at that frame, coast gear)`. `base_t<track>_c<car>` runs: `TRACK=t CAR=c LAPS=3 TAG=base_t<t>_c<c> ... scripts/fuel_lab.lua` (default `SH=40,63,100,167`, `STEER=0`). Parallel runs need separate homes: `tools/mesen.sh`, `mesen2.sh` .. `mesen4.sh`.
