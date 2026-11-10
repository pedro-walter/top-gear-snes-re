## Car physics (bank 05) – WRAM variables (CPU view, bank 0)
| addr | meaning (confidence) |
|---|---|
| `$1E5A` | **speed** (player), 16-bit. ~3500 at HUD 85 km/h. **Confirmed by user vs HUD.** |
| `$1E5E` | **RPM** = `speed * $9767[gear]` << 1. **Confirmed.** |
| `$1E72` | **gear** index. **Confirmed.** |
| `$1EE2` | top-speed limit for current gear = `$9597[Y] + (($A7FF-$1E62)>>6)`. Observed to follow the *computer* car (shared scratch, overwritten by the AI car's update) - so the same routine runs for both cars. |
| `$1E62` | **fuel, counts DOWN** (user-confirmed; 0 = empty). Consumption per tick = `((RPM * $1EFD) >> 16)`-ish top 10 bits `+1` (code 05:D638-D67B), so it is per-frame and RPM-driven. Less fuel -> higher `$1EE2` (formula uses `$A7FF - fuel`), as the user observed. At 0: clears bit0 of `$1EB4`, sets `$1EF5` bit `$20`, zeroes RPM `$1E5E` -> no more thrust, car glides. |
| `$1EFD` (byte) | **fuel-burn factor of the player's car** = `CarStats[$1F8F]` (00:97DB: red 100, white 64, car2 90, car3 82). `$1EFE` = same for the computer's car (`$1FAC`; index 0 if `$1F04`==0). Set by 00:C69E-C6B5. User saw word 25700 (red) / 25664 (white) = `$1EFE:$1EFD` = $6464 / $6440. |
| `$1FAC` | computer-controlled (bottom screen) car index |
| `$1EEA` | computer car's table offset = `$1FAC << 4` |
| `$1EB4` | status bits; bit0 cleared on empty tank (probably 'engine on / can accelerate') |
| `$1ED7` | **track position** of the player; resets to 0 each lap. `$7E4000[pos>>4]` is therefore a per-track-position table (hill/curve term applied to acceleration). |
| `$1E6C` | **nitro active**: negative while nitro is on, 0 otherwise. (selects table half +$3A) |
| `$1EF5` | flags. bit `$20` = no thrust (set when fuel empty or RPM 0). bit `$10` = RPM-decay state (05:D30F: RPM -= $30/tick, flips `$1E66` each tick, e.g. after shift/hit - semantics unverified). |
| `$1F10` | **difficulty/skill level** (user found by memory search; referenced in 00:A5F3, 00:C062, 05:EE19, 05:EE89, 0F:83EB...; the bank-05 uses are probably AI/rubber-banding) |
| `$1F8F` | **selected car** (user: 0 red, 1 white, 2 purple, 3 blue); referenced mostly from bank 00 menu code, not bank 05 physics |
| `$1F7A` | **shift-UP button mask** (joypad-word bit mask; user: 0x0010 = R). 0 => automatic transmission. |
| `$1F7C` | **shift-DOWN button mask** (0x0020 = L). 0 in auto. |
| `$1F7E` | **nitro button mask** (0x0080 = A); stays set in auto. Read at 05:D35F. |
| `$14` (direct page) | current joypad word for the active player; the speed routine does `TRB $14` with the masks above (tests and clears the bit). Joypad word: B=8000 Y=4000 Sel=2000 Start=1000 Up=800 Down=400 Left=200 Right=100 A=80 X=40 L=20 R=10. |
| manual vs auto | there is **no separate flag**: manual <=> `$1F7A`/`$1F7C` non-zero (menu code at 0F:9828 ORs them to pick the AUTO/MANUAL graphic -> `$5A`). The 4 control layouts presumably load different masks. `$0087`/DP`$87` is unrelated scratch. |
| `$1EE8` | **player car table offset = `$1F8F << 4`** (set at 00:A714; 0 for red, 16 white, ...). Does not depend on skill level (user test). Added to gear*2 when indexing the per-car tables. |

Tables are in **bank 00** (DBR=00 during physics code), per-car blocks of 8 words (16 bytes), 5 gear entries each: 
| table (bank 00) | contents |
|---|---|
| `$9597` | top speed per gear. car0 (red): 4500, 6000, 8400, 9600, 10000. car1 (white): 4000, 5800, 7400, 8000, 8500. car2: 4200,6000,8400,8900,9200 |
| `$96F3` | acceleration factor per gear: 4, 5, 6, 9, 14 (same shape for the cars seen) |
| `$960B` | drag term per gear (car0: 24000,12500,9500,9900,11000; car1 lower from gear 3) |
| `$9767` | gear ratio for RPM: 127, 96, 58, 42, 30 |
| `$99DB` / `$9A15` | downshift / upshift speed thresholds: down 0,1150,2200,3500,4500; up 1600,3200,4000,5440,65535 |
| `$97DB` | per-car fuel-burn byte [100, 64, 90, 82] |
| `$97DF` / `$981F` | 8-entry ladders +640*n / -640*n per car, indexed by `$1E90`-1: written to `$1E94`/`$1E92` (symmetric limits, probably steering/grip) |
Speed scale: `$1E5A`/~41.7 = km/h (10000 ~ 240 km/h); upshifts at ~38, 77, 96, 130 km/h.
Full tank = `$A7FF` (set for both `$1E62` and `$1E64` at race init, 00:A700). top-speed bonus = `($A7FF-fuel)>>6` (0 on a full tank, ~671 when empty).
Speed update (`05:D2E0 car_update_speed_gear`, writes `$1E5A` at 05:D439/D486):
 accel = (`$7E4000[$1ED7>>4]` negated, scaled) x `$96F3[Y]` via PPU signed multiplier (`$211B/$211C`, result `$2135`),
 `>>4`, added to speed; clamped to `$1EE2`; then drag `$960B[Y]` pulled toward 0; clamped >= 0.
 Shift logic above it: auto mode (`$1F7A`==0) compares speed with the thresholds `$99DB`/`$9A15` (up/down); manual mode (`$1F7A`!=0) steps `$1E72` up/down (max index 4) when the `$1F7A`/`$1F7C` button bits are set in `$14`.


## Nitro
* `$1E6C` (P1) / `$1E6E` (P2): **low 2 bits = nitro charges left** (3 at race start, 00:82E2), bit15 = nitro active. HUD shows the charge count (`AND #3`, minus 1 while active: 00:D04F).
* Trigger (05:D358): requires charges != 0 and not already active (bit15 clear), `$1F7E` button mask (A) pressed => `$1E6C |= 0x8000`.
* While active the 00:B9ED state machine advances the word every frame: phase A (bit14=0): +0x200/frame for 32 frames (palette flash); phase B (bit14=1,bit13=0): +0x20/frame for 256 frames;
  phase C (bit13=1): +0x100/frame for 32 frames; then it wraps to positive and **one charge is subtracted** (DEC). Total **320 frames (5.3 s)** per nitro. It can't be restarted while active.
* Effect: the whole physics table lookup uses `Y += 0x3A` (a second set of rows in `$9597/$960B/$967F/$96F3`: top speed, drag, engine pull, accel). Nitro rows (red car): top 5300/7200/**11400**/12500/15600, pull 108/50/31/22/18.

## Speed physics (fully modelled – `tools/physics.py`, exact to the unit vs. the game for 850 ticks)
Per tick (05:D2E0.., ~2 ticks every 3 frames):
```
top   = TOP[Y] + ((0xA7FF - fuel) >> 6)                 ; $1EE2   (Y = car*16 + gear*2 (+0x3A if nitro))
speed += slope_term   ; s = $7E4000[pos>>5]; A=-s; if s>0: A>>=2 (arith); A>>=4 (12-bit sign-extend)   (downhill is 4x stronger than uphill)
speed -= (|DRAG[Y] - speed| >> 8) & 0xFF                ; drag, speed clamped >= 0
if accelerating (X button mask $1F76) and fuel>0 and finishers<10:
    diff = top - speed
    if diff < 0: speed -= (|diff|>>8)&0xFF
    else:        speed += (diff * PULL[Y]) >> 10         ; ($967F table; halved if $1EF5 bit 0x10)
else: coasting (only the over-speed bleed)
```
Equilibrium (flat, full tank, red car): g1 3829 / g2 5070 / g3 7959 / **g4 9347** / g5 8857 (219 vs 207 km/h): without nitro the red car's 4th gear is faster than 5th.
With nitro: 4655 / 6596 / 11367 / 12408 / **15488** (363 km/h). Less fuel => higher `top` (+0..670) => higher equilibrium and larger (top-speed) gap => faster acceleration (this explains the user's observation).

### The "3rd gear + nitro" trick
Best gear for *acceleration* (net speed gain per tick, flat road, nitro): 1st below ~2500, **3rd gear (index 2) from ~3000 up to ~6500 units (70..155 km/h)**,
5th above ~7000. The auto transmission (up thresholds 1600/3200/4000/5440 units) already sits in 4th/5th by 4000-5500 where the pull is only 149/131 (4th) or 134 (5th) per tick vs
**195/169/143 in 3rd** at 4000/5000/6000. So: stay in 3rd (manual), fire the nitro, and shift to 5th at ~7000 -> noticeably faster than auto. Reason: 3rd-gear nitro row has top 11400 (vs 8400 normal) and
pull 31 (vs 18 for 5th), so the gap `(top - speed)*pull` is largest there. Same for the other cars (their nitro rows are nearly identical).


