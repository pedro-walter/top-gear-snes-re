## Open items / next steps
1. Name remaining bank 05 routines (steering, collisions, AI, lap/position logic). Use `scripts/writers.lua`
   pattern (write/read callbacks) on `$1E5A`-neighbours ($1E58-$1EFF looks like the player car struct) and on
   the opponents' structs.
2. Track data format (curves/hills): find the reader that fills the HDMA scroll tables.
3. AI (rubber-banding): inspect writes to the computer's struct.
4. Decompressor (`$00:EA8E`/`EA9B`, `EBB6`) and the graphics/music data banks (91% of ROM is not code).
5. SPC700 sound driver upload (`$07:8000` looks like it).
6. 13 unresolved indirect jumps listed at the end of the disassembly (jump tables).

---

## Addenda (verified in emulator)
* `$1E90` = frame delta (`$0C` frames elapsed + 1) – the main loop is time-based; progress and lateral movement scale with it, engine/drag/fuel are per tick (so fuel burn depends on frame rate).
* Progress per frame: bots `speed/256` units (measured exactly), player `speed/512` per speed unit => a bot value v equals a player speed of 2v (km/h = v*0.0469): bots cruise ~94..177 km/h on track 0 easy.
* **Computer-car rubber band** (05:EE19, verified): only in top gear, only if difficulty `$1F10 != 3`, and only when the computer is *ahead*: `top -= min(gap, 1024)` where
  `gap = (laps_ahead*track_len + camera_pos_diff)`; difficulty 0 doubles it (up to -2048). Never speeds it up. Difficulty 1 and 2 behave identically here, 3 has none.
* Pit test (track poke `$1F06=3` before the loader): computer with fuel 6642 entered the pit near pos 7450, refuelled to 0xA7FF, left. Tracks with a pit: 3,4,6,8,9,11,12,14,15 (`00:DF24`, FFFF = none). Laps per track `00:DEA4`: 3,3,3,6,6,4,6,3,7,5,3,6,7,3,6,8.
* Nitro measured: active 320 frames, charges 3 -> 2.
* `out/tracks.png` (tools/track_atlas.py): curve (red) and hill (blue) profiles of all 16 tracks.

## Corrections / user-confirmed (session 3 end)
- Difficulty `$1F10` is only 0..2 from the menu (amateur/professional/championship; written at 0F:940D, 0F:96C6). Value 3 in the rubber-band code (05:EE19) is just a "none" branch, no known writer. Amateur doubles the computer's slowdown; professional == championship.
- 3rd gear + nitro trick, user-confirmed by play: 3rd gear to ~250 km/h then 5th. Model (physics.py, nitro, full tank, flat) crossover where 5th >= 3rd: car table 0: 154 km/h (red, "same above ~150"), table 2: 221 (purple "~220"), tables 1/3: 248 (white/blue "~250"). Colour->index mapping inferred, to verify with $1F8F. Nitro 3rd-gear ceiling ~265-273 km/h.


