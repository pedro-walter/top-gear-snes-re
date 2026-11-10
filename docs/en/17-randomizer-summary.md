# Top Gear randomizer summary (BETA 0.5)

Overview of the features and bug fixes. Technical details are in [09](09-randomizer-plan.md), [10](10-randomizer-implementation.md) and [13](13-race-results-qualification-podium.md).

## Features

**Track generation**
- Every race is a random track generated on the console itself (65816 code) from an 8-digit hexadecimal seed. The same seed always gives the same track.
- Tracks have 24 to 46 pieces and 3 to 8 laps, and use one of the 32 original environments.
- The Python and 65816 generators were compared on 1500 seeds and gave identical results.
- Turn signs (chevrons) are placed before every curve, and pit flags before the pit entrance.
- Trees and bushes fill empty roadsides, using the environment's own object types.
- Hazards: a rock field on about 1 track in 8, and a single-lane barrier closure on about 1 in 16. The frequencies were matched to the original tracks.
- The seed decides the track; the chosen difficulty does not change it.

**Pit stop**
- There is always a pit, except on short races (129 pieces or fewer in total) that the red car can finish on one tank. That is about 16% of seeds.

**Main menu (six rows)**
- `1 PLAYER` / `2 PLAYERS`, `DIFFICULTY`, `<n> TRACKS`, `SEED`, `SPEED KPH/MPH` and `PLAY GAME`.
- `TRACKS` goes from 1 to 99 or infinite.
- `SEED` is only active with 1 track. With more, the row is greyed out.
- The hex seed keypad uses big hand-drawn glyphs. A/B type, X/Y delete, Start confirms.
- Left/Right rolls a new seed.

**Track series**
- With 1 track, the results screen returns to the menu and the seed is kept so you can replay the track. No world ranking.
- With 2 to 99 tracks, or infinite, every race has a new track and the championship points of all racers add up.
- Scores are 16 bit (up to 5 digits). The original kept one byte per car, which was enough for its short championship; a series of up to 99 tracks needs more than 255 points, so the randomizer widened it.
- Finite series end with a podium scene saying "THANK YOU FOR PLAYING!", with the "completed Top Gear" tune, and return to the title screen.
- No game over and no qualification.

**Interface**
- The minimap was replaced by a lap-progress strip in the black bar between the two views. It shows the start and finish lines, dots for P1, the leader and P2/computer, and the pit marker.
- A `LAP n/m` counter sits under each timer.
- The title screen got a violet sky, the text "RANDOMIZER BY PEDRO WALTER / POWERED BY CLAUDE" and the BETA version.

**Other**
- The big digit glyphs (0–9, A, C, E, F) were drawn by hand, because the original font has no 0, 3–9.
- The header checksum is fixed, and the ROM is distributed as an IPS patch (only our bytes).

## Bug fixes

**In the generator itself**
- **Game running at 1/4 speed with garbage graphics.** The object scanner read past the end of the lap. The generator now builds an extra piece.
- **Garbled scenery** (start gantry and roadside objects). The 8 KB VRAM pool fragmented. Now each track has one graphics set that fits entirely, and the gantry shows in all 32 environments. In 1000 model seeds no garbled slot was left.
- **Gantry disappearing in some environments**, caused by extra object types. Fixed with a table of types to drop.
- **Stale IPS applied by Mesen on top of the new ROM.** The build now rewrites the IPS every time.
- **Small font:** stray red pixels in B, D and 8 were painted in the outline colour.
- **Garbage glyphs** in the menu seed after coming back from a race (the font was not in VRAM), fixed by storing the glyphs in the ROM.
- **Cut-off letter** in the lap counter (the T of "LAPS LEFT").

**Bugs of the original game**
- **Lap lost when colliding near the finish line** (fixed in 0.3). If the other car had already crossed the line, the collision pushed the human behind it and a lap was taken off. This is the only collision bug that exists in the original game.
- **Wrong fade-out** when a refuelled car was still racing after the other car finished (0.3). Fixed.
- **A car inside the pit sequence** now counts as running at the end of the race.

**Regressions of our own fix (never in the original game)**
The first version of the finish-line fix (0.3) introduced two new bugs, found by players and fixed in later versions:
- **Collision with a car that had lapped you** (found in 0.3, fixed in 0.4). The player was teleported across the line and got a lap by mistake. The adjustment now only acts near the line.
- **Backmarker near the line** (found in 0.4, fixed in 0.5). With P2 in single player the car lost all its progress of the lap. The position now always stays inside the car's own lap, and there is a unit test script (`hitpos_unit.lua`).

## Research and documentation (no game change)
The repository also documents things the randomizer does not change: ideal gear shifts ([12](12-ideal-gear-shifts.md)), what differs between the four cars ([14](14-car-differences.md)), the comparison of the USA, Europe and Japan ROMs ([15](15-rom-versions.md)), race messages and speech balloons ([11](11-speech-balloons-messages.md)), and fuel-saving experiments ([16](16-fuel-saving.md)).
