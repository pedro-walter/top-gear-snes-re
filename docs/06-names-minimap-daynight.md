## Track names (session 4) — `tools/names.py`
Names come from the pointer table `0D:C77C[track]` -> location screen text in bank 0F (`0F:81AB`); country = track>>2 (USA, South America, Japan, Germany, Scandinavia, France, Italy, UK). Confirmed in the emulator: $1F06=2 shows **NEW YORK, U.S.A** on the location screen and the race is the night city race; $1F06=0 is the desert race (Las Vegas); 9 = Hiroshima (dusk start). 4 = Rio has the tunnel near the start.

```
0 Las Vegas (USA)
1 Los Angeles (USA)
2 New York (USA)
3 San Francisco (USA)
4 Rio (Brazil)
5 Machu Picchu (Peru)
6 Chichen Itza (Mexico)
7 Rain Forest (Brazil)
8 Tokyo (Japan)
9 Hiroshima (Japan)
10 Yokohama (Japan)
11 Kyoto (Japan)
12 Munich (Germany)
13 Cologne (Germany)
14 Black Forest (Germany)
15 Frankfurt (Germany)
16 Stockholm (Sweden)
17 Copenhagen (Denmark)
18 Helsinki (Finland)
19 Oslo (Norway)
20 Paris (France)
21 Nice (France)
22 Bordeaux (France)
23 Monaco (Monaco)
24 Pisa (Italy)
25 Rome (Italy)
26 Sicily (Italy)
27 Florence (Italy)
28 London (England)
29 Sheffield (England)
30 Loch Ness (Scotland)
31 Stonehenge (England)
```
Special per-track entries in 00:E024/E064 exist for tracks 2 (New York, night) and 9 (Hiroshima, day/night change) - likely the sky/lighting scripts.

## Minimap (session 4) — `out/minimaps.png`, `out/minimap_paths.png`, `tools/minimaps.py`, `tools/minimap_path.py`
**The track map is a separate pre-drawn graphic, not generated from the track data.** Two pieces:
1. **Bitmap** (the white outline with start-line tick): per track 1024 bytes = 64 tiles of 2bpp (8x8 tiles = 64x64 px, only the upper-left part is used), stored compressed in bank 0D: `0D:8000` = tracks 0-15, `0D:911F` = tracks 16-31
   (chosen in `0F:821D`, decompressed by `sub_0FB334` into `$7E2000`; the same LZ-style decoder as `00:EA8E/EA9B`, 2 KB ring buffer at `$044C`). Track t uses bytes `(t&15)*1024` of its block. The location ("splash") screen copies each 16-byte tile to 32 bytes (planes 2,3 = 0)
   and DMAs it to VRAM, tilemap rows via `$0EFD86[track]`. In the race the same tiles are shown by BG1 (tilemap `$C00`, rows 1-4 x cols 1-8 for player 1; tiles 0x91..0xA1, blank tile 0x90) with a 17-tile subset - same graphic, deduplicated. All 32 are rendered in `out/minimaps.png`.
2. **Marker path** (the moving dots): `$7E3E00` has **one (x,y) byte pair per 256 track units** (= `$1ED7>>8` for the player, the same index for the leading car and for player 2). It is built at track load (`00:C0F2-C15A`): start point `00:E0E4[track]` (low byte x, high byte y), then the delta stream
   at `0E:`... `00:E124[track]` (decompressed with `00:EA8E/EA9B`) is accumulated: `x += dx`, `y += dy` per step. `sub_008910` reads `$7E3E00[pos>>8]` into `$0112` (player 1), `$0114` (player 2) and `$0116` (leading car = highest progress in the car list);
   `sub_008966/008A2C` write them as the first three OAM entries (word x|y<<8 followed by `$307F`/`$30FF`/`$327F` = tile 0x7F/0xFF, palettes) of each player's sprite buffer; player 2's view adds 0x70 to y (bottom half). So the dot moves along a 256-unit-resolution polyline (jumps every 256 units).
   Sprite coordinates map onto the bitmap with offset (8,8): bitmap pixel = (x-8, y-8) for the HUD at the top-left of the screen; overlay verified for all 32 tracks (`out/minimap_paths.png`: the polyline lies exactly on the drawn outline, starting at the start-line tick).
**Corrections of earlier statements:** the "sky gradient / palette" tables `00:E0E4`, `00:E124` and the `$7E3E00` "sky palette stream" are the map-marker start position and path, not colours. `00:DFA4[t]` (02:C849 + 0x40*t) is the 8x? tilemap of the per-track *horizon picture* (BG tilemap, VRAM $1AE0/$1EE0), graphics = compressed stream `00:DF64[t]` -> VRAM $6800 (desert dunes for Las Vegas etc.), not the minimap.
Day/night: not from these tables (see lap brightness measurements, in progress).
Authoring a track therefore needs: a 64x64 2bpp map bitmap, a start point and one (dx,dy) step per 256 units (or just the final `$7E3E00` table).

## Day / night along the tracks (session 4) — `tools/daynight.py`, `out/daynight.png`, `out/daynight.csv`, screenshots `out/lap/`
Method: one lap per track driven in the emulator (flat-out), screenshot every 150 frames with the player position `$1ED7`; brightness = mean luminance of the player-1 view below the HUD (night < 28, dusk < 60). The time of day is a function of **position on the lap** (same each lap), not of time.
Tracks with night: **New York** (all night), **Hiroshima** (night 0-~17000, day from ~18000), **Cologne** (day 0-~18000, night ~19000-39000, day again at the very end), **Florence** (night 0-~36000, day for the last ~5000),
**Black Forest** (night 0-~7500, then day), plus dusk/darkening near the lap end on **Monaco** (dusk ~35000-42000) and **Sicily** (dusk/night ~40000-43000). All the other tracks measured as day all the way (short dark samples on Rio ~9600, Kyoto/Copenhagen near the end are tunnels/shadows, not night).
Matches the user's reports (New York night, Hiroshima night -> day, Cologne night). The mechanism that darkens the screen is not decoded yet (it is not `00:E024/E064/E0A4/E0E4/E124`; `E0A4[t]` non-zero only for tracks 0,4,9,13,14,20,23,26,29 - candidate to check).


