TOP GEAR RANDOMIZER  -  BETA 0.2
Randomizer by Pedro Walter, powered by Claude.   Source and docs: this repository (MIT).

WHAT YOU NEED
  * Your own, legally obtained ROM:  Top Gear (USA).sfc   (512 KB, no header)
    SHA-1  f686806c676a4b087a3627babbe3555d3704e3b1
  * An IPS patcher (Floating IPS, Lunar IPS, MultiPatch, RomPatcher.js ...).
    The patch contains only our changes, no game data.

HOW TO PATCH
  Apply  top-gear-randomizer-0.2.ips  to your ROM. The result is a 1 MB ROM (the patcher extends the file);
  run it in any SNES emulator or on hardware that accepts a 1 MB LoROM image.
  Command line, as an example (Floating IPS):  flips --apply top-gear-randomizer-0.2.ips "Top Gear (USA).sfc" randomizer.sfc

WHAT IT DOES
  Every race is a new random track built on the console from an 8-digit hex seed (3-8 laps, always a pit stop,
  one of the 32 original environments).

  Main menu:  1 PLAYER / 2 PLAYERS, DIFFICULTY, X TRACKS, SEED, SPEED KPH/MPH, PLAY GAME
    X TRACKS   Left/Right: 1 .. 99 tracks, or infinity (Left from 1 TRACK).
    SEED       only with 1 TRACK: A opens a hex keypad, Left/Right rolls a new random seed. Same seed = same track.
    1 TRACK    after the race you come back to the menu; the seed is kept so you can replay the track.
    2-99       a new random track after every race, championship points of all racers add up (world ranking up to
               5 digits); after the last race a podium scene says THANK YOU FOR PLAYING! and the game returns to the title screen.
    infinity   endless series, never a podium. No qualification / game over in series.

CREDITS
  Original game: Top Gear, Kemco / Gremlin Graphics. This patch is an unofficial fan project and is not affiliated with them.
