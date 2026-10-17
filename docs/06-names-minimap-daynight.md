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
Per-track lighting entries `00:E0A4/E024/E064` are decoded in the day/night section below.

## Minimap (session 4) — `out/minimaps.png`, `out/minimap_paths.png`, `tools/minimaps.py`, `tools/minimap_path.py`
**The track map is a separate pre-drawn graphic, not generated from the track data.** Two pieces:
1. **Bitmap** (the white outline with start-line tick): per track 1024 bytes = 64 tiles of 2bpp (8x8 tiles = 64x64 px, only the upper-left part is used), stored compressed in bank 0D: `0D:8000` = tracks 0-15, `0D:911F` = tracks 16-31
   (chosen in `0F:821D`, decompressed by `sub_0FB334` into `$7E2000`; the same LZ-style decoder as `00:EA8E/EA9B`, 2 KB ring buffer at `$044C`). Track t uses bytes `(t&15)*1024` of its block. The location ("splash") screen copies each 16-byte tile to 32 bytes (planes 2,3 = 0)
   and DMAs it to VRAM, tilemap rows via `$0EFD86[track]`. In the race the same tiles are shown by BG1 (tilemap `$C00`, rows 1-4 x cols 1-8 for player 1; tiles 0x91..0xA1, blank tile 0x90) with a 17-tile subset - same graphic, deduplicated. All 32 are rendered in `out/minimaps.png`.
2. **Marker path** (the moving dots): `$7E3E00` has **one (x,y) byte pair per 256 track units** (= `$1ED7>>8` for the player, the same index for the leading car and for player 2). It is built at track load (`00:C0F2-C15A`): start point `00:E0E4[track]` (low byte x, high byte y), then the delta stream
   at `0E:`... `00:E124[track]` (decompressed with `00:EA8E/EA9B`) is accumulated: `x += dx`, `y += dy` per step. `sub_008910` reads `$7E3E00[pos>>8]` into `$0112` (player 1), `$0114` (player 2) and `$0116` (leading car = highest progress in the car list);
   `sprite_renderer` (`01:808B..80AE` for player 1, `01:8590..85BF` for player 2; `00:8966/8A2C` are *not* executed in the race) write them as the first three OAM entries (word x|y<<8 followed by `$307F`/`$30FF`/`$327F` = tile 0x7F/0xFF, palettes) of each player's sprite buffer; player 2's view adds 0x70 to y (bottom half). So the dot moves along a 256-unit-resolution polyline (jumps every 256 units).
   Sprite coordinates map onto the bitmap with offset (8,8): bitmap pixel = (x-8, y-8) for the HUD at the top-left of the screen; overlay verified for all 32 tracks (`out/minimap_paths.png`: the polyline lies exactly on the drawn outline, starting at the start-line tick).
**Corrections of earlier statements:** the "sky gradient / palette" tables `00:E0E4`, `00:E124` and the `$7E3E00` "sky palette stream" are the map-marker start position and path, not colours. `00:DFA4[t]` (02:C849 + 0x40*t) is the 8x? tilemap of the per-track *horizon picture* (BG tilemap, VRAM $1AE0/$1EE0), graphics = compressed stream `00:DF64[t]` -> VRAM $6800 (desert dunes for Las Vegas etc.), not the minimap.
Day/night: see the section below (`00:E0A4`).
Authoring a track therefore needs: a 64x64 2bpp map bitmap, a start point and one (dx,dy) step per 256 units (or just the final `$7E3E00` table).

## Day / night (solved) — `scripts/light_log.lua`, `scripts/night_diff.lua`, `scripts/cm_probe.lua`
**It is a per-track timer in frames since the race start, not a position on the lap** (the earlier "position on the lap" wording came from flat-out laps, which take about the same time; a slower driver sees the change at an earlier position).

Init at `00:CDB6` (race load) reads `00:E0A4[track]`:
* **bit 15 set** = lighting script active. `$0102 = (E0A4 & 0x3FFF) - 1` = frames until the change (0 -> `$FFFF` = never), `$0100 = E0A4 & 0xC000`; bit 14 = starts as **night**.
  Night start: `$0100=C0DF` (the low byte `DF` encodes the darkness), fixed colour `$2132=0xED`, night palette (see below), `$0104=E064[t]`, `$66=B494`. Day start: `$0100=8000`, `$2132=0xE0`, day palette, `$0104=E024[t]`, `$66=B6B6`.
* **bit 15 clear** = no script; the 15-bit value is just a **BGR555 colour** copied to `$0398/$039A/$039C` and `$03CC..` (sky/horizon colour): Las Vegas 152F (R15 G9 B5), Rio 0D11 (R17 G8 B3), Paris 6317 (R23 G24 B24), Monaco 52B4 (R20 G21 B20, grey), Sheffield 1DD6 (R22 G14 B7).
  (So Monaco's "dusk" in the earlier brightness measurement was a grey sky, not night.) Tracks with value 0 keep the default.

Per frame (`00:BAB9..BBC0`, called once per race frame, `INC $1EAE` at 00:B960):
`$0102` counts down 1 per frame. At 0 the **fade** runs: night -> day: `$0100` is decremented `C0DF -> C001` (~222 frames), then set to `8000`; day -> night: incremented `8000 -> 80DF` (~223 frames), then `C0DF`. `$0102` becomes `$FFFF` after the change, so **it happens once per race, never again** (it does not repeat each lap) and `$0106` goes 2 -> 1 -> 2 as the step counter.
Every frame `$2132 = 0xE0 | (($0100 >> 4) & 0x1F)`: fixed colour with all three channels = darkness level (0 day, 13 at full night). PPU is in **colour-math subtract mode** (`$2131`: layers BG3 + OBJ + backdrop, mask 0x34), so those layers get darker by the fixed colour;
at the same time 16 colours (CGRAM $10..$1F) are swapped: day palette `00:8A5A + DFE4[t]`, night palette `00:8E5A + DFE4[t]` (DMA 32 bytes, 00:BAED..BB33 and BB66..BBA3). A copy of the palette goes through `$03AE/$038E/$044E` in the loader.
`$E024[t]/$E064[t]` ($84F0/$8664 default, $8826/$87D8 Hiroshima, $8400 New York) are the values loaded into `$0104`/`$0106` for the day and night script (their exact use is not decoded; they never matter for timing).

| track | E0A4 | start | change after |
|---|---|---|---|
| 2 New York (USA) | C000 | night | never (night all race) |
| 9 Hiroshima (Japan) | CA00 | night | 2560 frames (~43 s) -> day |
| 13 Cologne (Germany) | 8B00 | day | 2816 frames (~47 s) -> night |
| 14 Black Forest (Germany) | C500 | night | 1280 frames (~21 s) -> day |
| 26 Sicily (Italy) | 9800 | day | 6144 frames (~102 s) -> night |
| 27 Florence (Italy) | D400 | night | 5120 frames (~85 s) -> day |

Verified by parking the car and logging `$0100/$0102` (`scripts/light_log.lua`, MODE=park): Hiroshima C0DF -> fade at frame 2603 -> 8000 at 2825; Cologne 8000 -> C0DF at 3090 (end of fade, `$0102=FFFF`); Black Forest fade at 1325 -> day 1547; Florence 5175 -> 5398; Sicily night at 6430.
Earlier lap measurement (screenshots, brightness): New York all night; Hiroshima night -> day (~17000-18000 units); Black Forest night first ~7500 units; Florence night for the first ~36000 units; Cologne day then night from ~19000 (but measured "day again at the very end" and Sicily "dusk ~40000-43000" - the latter is the fade-in; the end-of-lap day on Cologne is not explained, possibly a tunnel/object or the lap restart).
Contradiction with the user report to check: Cologne is described as night-and-maybe-day; per the table it is day for the first ~47 s of the race and night for the rest.
