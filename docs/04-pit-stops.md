## Pit stops
* Trigger (player 1, 05:D75E–D7C0; computer/player 2 mirror at 05:DFB8–E03A, 05:F0xx): while driving over a roadside object of type **0x74xx** (pit entrance; `$7E6400` word & 0xFE00 == 0x7400) on the matching lateral side
  and `$1E86` (P1) / `$1E88` (P2) state is not already negative, `$1E86 = 0xFFFF` starts the pit sequence. If fuel is 0 then `$1EB4 |= 1` (P1) / 2 (P2).
* State machine `00:90CC` (state = ~`$1E86`; each step does `DEC $1E86`): 0 pit scene set up (sets `$40 = 0xFFFF` = pit mode, `$A8 = 0x280`, gear 4, speed `$1E5A = $1700`, palette copy),
  1 wait, 2 `$E1=1`, `$14=0` (input ignored), 3 wait for accelerate (`$1F76`) with fuel != 0 -> **skip refuel**, 4 **refuel**: `fuel += 0x7F` per frame until `0xA7FF`
  (about 340 frames) – pressing accelerate (and fuel != 0) leaves early, 5 drive out until `$A8` in 0x300..0x37F, 6 restore, 7+ release: clears `$40`, clears `$1EF5` bit 0x20 (no-thrust).
  The computer car does the same with `$1E88`/`$1E64` (00:9222..9380); in 1-player mode (`$1F04 == 0`) it needs no button and leaves automatically.
* **Computer (AI) decides to pit** (05:F1AF..F1BF and `sub_05F79F`): it only considers it when its fuel `$1E64 < 0x3000` (28 % of a full tank) **and** `sub_05F79F(X=0x3D)` says it can't finish:
  `needed = (track_len/2 * (laps_total - laps_done) - position/2) * X  *2  >=  fuel`. If so it sets `$1EF2` bit0 and steers with the narrow **pit-lane corridor** tables `00:E166/E198` (left/right
  limits by distance from `$1EF0`) instead of the road corridor, so it is funnelled into the pit entrance object.
  While refuelling (05:EDC5, state `$1E88 == 0xFFFA`) it leaves as soon as `sub_05F79F(X=0x50)` says the fuel is enough to finish the race (so it does *not* always fill the tank).
  In a normal 3-lap race on track 0 it burns ~22 000 of 43 007 units and never stops.


