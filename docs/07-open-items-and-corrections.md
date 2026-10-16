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



## Corrections found while annotating the disassembly (session 6)
* `$1FF6` is **not** a units flag: it is the title-screen **attract-mode countdown / demo flag** ($04B0 frames, then `0F:90E6`
  starts a demo race on a random track and sets it to `$8000`; any button press ends the demo). The HUD's "km/h when
  negative" in docs/03 is just "demo races show km/h".
* The per-frame race work does not run in the NMI: `nmi_handler_race` only reads the pads. The IRQ handler dispatches
  through the pointer in `$0A` (`00:B6D1` ...) and the big vblank routine is called through `$08` (`00:B75A`); day/night
  (`00:BAB9`), map dots, pit-crew DMA and the scenery scanner are sections of it.
* Menu text entry (`0F:943D`) is a 6-column grid (`A..Z`, then `3`/`4` glyph cells = space/delete, `END`) writing up to 8
  characters to `$68..$6F`; the main menu (`0F:918B`) has 5 entries (players, skill, country, mph/kph, play game).

## Findings while building the randomizer (session 7, docs/10)
* **Roadside object words**: `type<<9 | side<<8 | lateral/128`, and the **side bit set means LEFT** (the hit code negates the lateral
  when the bit is set). The pit-entrance trigger (`05:D75E..D7C0`, player 1) fires when an object word `& $FE00 == $7400` is
  passed while the car is *beyond* the object laterally on its side (e.g. word `$757C`: left, 15872 -> car lateral below
  about -16000).
* The object table is read **up to $58 bytes beyond the last lap piece** by `scan_roadside_objects` (`00:E20D`); the original
  loader expands L+2 pieces (the extra pieces are read past the end of the streams). Garbage there means group-object
  loops of up to 65536 iterations.
* **Bank 7F is partly used**: the corridor table (`$7E7000 + 2*(position/2)`) runs on into `7F:0000..$2800`.
* The big gold menu font has no glyphs for `0` and `5..9` (digits `1`,`2` exist, `3`/`4` are the arrow glyphs); the small font
  (`draw_string`, 8x8 tiles in the same VRAM area) has all digits. `0F:9E1C` "upload_font" only clears VRAM $0000-$0FFF.
* Group objects (word bit 15: tunnels, gantry) come from record bytes `b0..b3` with bit 6 set; only tracks 4, 20, 23, 29 have
  them (besides the start gantry `$8002`).
* Menu page tables `0D:C716/C738/C75A` (a, b, c lists per page) hold 17 pages; page 8 is the PASSWORD grid, page 3 the name grid,
  page 15 the location splash. `$0F:ABE9` is the splash text list, `0D:C6D6/C6F6[track]` laps/pieces for the splash statistics.

## Object type catalogue and menu font (randomizer work, session 8)
Seen by placing one type at a time in a running race (`scripts/rando_types.lua`, `tools/sheet_types.py`; graphics are per type, some
art may differ by environment): 5 = KEMCO billboard, 6 = barrels, 7 = hazard-stripe barrier, **8 = `>` chevron (right turn), 9 = `<` chevron
(left turn)**, 10 = warning triangle, 11/12 = street lamps, **13 = PITS flag**, 14/15 = fences/bushes, 21-23 = palms, 24-31 = trees/cacti/
plants, 30 = GREMLIN billboard, 37-47 = billboards, 53-57 = flag poles/pennants, 58 = pit entrance trigger. 1-4, 16-17 = other cars.
In the original data type 8 is always on the left (side bit 1) before a *negative* curve and type 9 on the right before a positive one;
a chevron's direction is fixed by its type, not by the side it stands on.
Menu font: VRAM tiles 128..255 hold the 16x16 gold glyphs in sprite layout (slot s = tile 128 + (s>>3)*32 + (s&7)*2, bottom half +16),
the small white font is a separate block (`0F:BBA7` -> VRAM word $1000); text drawn by `draw_string_to_buffer` writes tile words into the
buffer at `$0C6C` (stride $40 per tile row; the second pass adds 16 to the tile numbers for the lower half). `draw_selection_bar` builds the
blue pill from **OAM sprites** (tiles `$0EC2..$0EC8`, `$4A` = length in sprites, X = OAM byte offset; X=8 keeps sprite 0 for the text cursor).
Graphics decompressor `0F:B306` (LZ variant, 2 KB ring): block `0D:A44D` -> VRAM word $1800 is the gold font.
