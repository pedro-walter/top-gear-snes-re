## Track data (loader `sub_00BF44`, called from `sub_00BF14` = load_track; tables are in bank 0C, track number `$1F06`, 16 tracks)
Track descriptor = 10 bytes at `0C:8402 + 10*t`: w0 = number of 1024-unit pieces (low 6 bits; length = pieces*1024), then 4 pointers (bank 0C):
`slope stream`, `curve stream`, `scenery stream`, `object stream`. The loader expands them into WRAM:

| WRAM | built from | meaning |
|---|---|---|
| `$7E4000` | slope stream | **hills**: one signed word per 32 position units. Signed byte per piece -> pointer table `0C:85D3`, each template = 32 words; negative byte = negated template. 0 flat; +-50..1000, ramps in and out. Positive = uphill (decelerates, factor 1/64 per tick), negative = downhill (accelerates, factor 1/16 per tick!). Verified exactly vs. memory for track 0. |
| `$7E4C00` | curve stream | **curves**: same format, pointer table `0C:8591`. Max |value| 16..40 per word. Used in 05:E9AF/F358 as `$7E4C08[pos>>4]` (8 words = 256 units ahead) x speed = centrifugal push on the lateral position. Verified exactly for track 0. |
| `$7E5800` | scenery stream | 64 bytes per piece copied from pointer table `0C:8545`; words (bit15 + index) look up road-edge shape via `00:9B3F`; used by `sub_00A8E1` to build `$7E7000` |
| `$7E6400` | object stream | roadside objects/signs/pit-entrance. 5-byte records expanded through the table at `0C:8615`: word per 32 units; top 7 bits = type (0x74xx = **pit entrance**), objects only exist at difficulties allowed by the mask from `0C:8541[$1F10]&0xE000` |
| `$7E7000` | computed (00:A8E1.. A9xx, AA09/AA6A) | road corridor: two signed bytes per 32 units = left/right limit; `$7E7002` = next entry |
| `$7E3E00` | palette stream (`0E`/`E124[t]`, decoded with 00:EA8E/EA9B) | per-track sky/background colour gradient |
Per-track constants: laps `00:DEA4[t]` (word), pit info `00:DF24[t]` (bit15 -> side, `&0x7FFF*2` -> `$1EF0` = pit-lane start position), pit-lane border tables `00:E166/E198` (indexed by distance/16 from `$1EF0`),
background palette `00:E0E4[t]`, graphics `00:DFA4[t]`, bot speed offsets `00:DDE4`.
`tools/tracks.py` re-implements the loader and verifies slope+curve tables against a WRAM dump (23/23 pieces identical for track 0). All 16 tracks are plain data in ROM (bank 0C),
so a new track = new streams + descriptor (designing tracks is feasible; the remaining unknown is the 00:A8E1 edge-shape table `00:9B3F` and the object records).


## Scenery and object streams (session 4) — `tools/objects.py`, `tools/objmap.py`, `out/objects.png`, `out/objects_all.csv`
Both loaders (00:C042–C0EF) are ported and **verified exactly against WRAM** (track 0: scenery 736/736 words, objects 736/736 at difficulty 0/1; difficulty 2 adds 20 words).
### Scenery ($7E5800, one word per 32 units)
* Stream = one byte per 1024-unit piece (element k = byte at stream+k, read as a word, only the low byte is used) -> template index `(b<<1)&0x1FF` -> pointer table `0C:8545` -> 32 words.
* Word = `0x8000 | block<<4 | phase<<1`, phase 0..7 repeats a..h through a piece, block = 0..26. Logic only uses `Y = 00:9B3F[word&0x7FFF]` = **road type 0..3** (record offset 0/4/8/12):
  blocks 0,4,7,8,12,15,18..25,27.. -> type 0; 1,6,9,13,16,28 -> 1; 2,5,14,17,29 -> 2; 3,10,11,26 -> 3. Blocks inside the same type are indistinguishable for physics/corridor (probably only graphics; the role of block 4 vs 0 is unknown).
* Road type t -> per-track word `00:DEE4[track]`: bits 0-2 = style of type 0, bits 3-5 type 1, 6-8 type 2, 9-11 type 3 (bit 15 = mirrored tile variant, `$E0`). A style (0..7) indexes tables at 00:C552 (left/right road-edge graphics, DMA 0x300 bytes each to VRAM $1000/$1400, $1180/$1580, ...),
  00:C572 (**wall limit** $017B+4t/$017D+4t = `-10229/+10229` narrow, `18636`, `26424` wide; style 7 = 13301) and 00:C592 (drawn edge $013F+4t/$0141+4t = -80/80, -138/138, -192/192; style 7 = 102). Styles 0..6 = (left width, right width) combos: left in {narrow, wider, widest} x right in {narrow, wider, widest}.
  05:D7FC clamps the player's lateral `$1E8A` to the wall limit of the road type under the car (bouncing, `sub_05F6FA`); 00:A8E1 builds the corridor `$7E7000`.
* In the map `out/objects.png` the background colours are the 4 road types per track: the **pit entrance always sits where the road type changes to a widened section** (pit lane).
### Objects ($7E6400, one word per 32 units, only the first object of a slot; 0 = empty)
* Stream record = 5 bytes per 512 units: w0 (2 B), w1 (2 B), then byte b2 at +4. w0<<1 and w1<<1 each give two 16-bit "templates" D0..D3 ($ED/$EF/$F1/$F3: low byte<<8 and high byte<<8). b2*32 selects one of 16-word patterns at `0C:8615`.
* Pattern word e: 0 = empty; bits 13-15 = difficulty mask (ANDed with `0C:8541[$1F10]&0xE000`; object only exists at those difficulties); bits 9-10 pick D0..D3; low 9 bits e&0x1FF are filled in:
  if D bit15 = 0 -> result = D | (e & 0x1FF) (ordinary object); if D bit15 = 1 -> result = (D&0xC000) | ((D&0x3E00)>>8) (a "group"/special; e's low bits ignored).
* **Ordinary object word** (bit15=0): bits 9-14 = **type** (0..63, graphics id from `00:E9BA[type*2]`, collision handler `05:F5C3[type*2]`), bit 8 = side (1 = negative lateral), bits 0-7 = lateral distance x128 in `$1E8A` units
  (wall limits 10229..26424 = 80..206). Also fed to the corridor builder (00:A8E1: objects shrink the corridor by +-0x40 around themselves) so cars cannot drive through objects and the computer car steers around them.
  Collision test 05:D6F4+ looks at the 32 slots (1024 units) before the car: lateral diff vs thresholds `05:A05F/A0DF[type]`; handlers F6B3 (REV: speed -> -min(speed/2,1600)), F6F5 (EDGE: halve speed, kick toward the road centre) and F6F1 (SIDE: halve, kick away from the object) set `$1EF5` bit 0x80 (crash sound); measured details in docs/03 "Collisions".
  Types used in the 16 tracks: 5-15, 21-24, 26-29, 31, 37, 38, 40-43, 46, 54-56, 58; the most common are 8, 9, 15 (cacti-like roadside objects), 24, 27, 31, 41. **Type 0x3A (stream word 0x74xx/0x75xx) = pit entrance** (side from bit 8, lateral e.g. 0x3C=60, 0x7C=124).
* **Group word** (bit15=1): `(w&0x3FFE)` indexes `00:E888` -> list in `00:E89A` of sprites drawn together. Only used for: id 1 (`0x8002`) at position 0 and at the end of every track = **start/finish gantry**, and in track 4 the series 0xC004..0xC00E around positions 5150-5550 (tunnel/bridge-like structure, the green lines in `out/objects.png`). Group objects collide through `sub_05ED3A` (REV behaviour).
* Sprite table: the renderer (00:E286.., E5B7..) scans 4 words ahead from `camera+0x50` for objects, builds a small cache of sprite ids (`$1BC6`..) and DMAs scaled frames; per-id data at `00:E882+4*id` (words used: sizes/counts, `$E886` = number of frames). Exact frame format not decoded.
### Authoring a track
Use descriptor `0C:8402+10t` (w0 pieces, 4 stream pointers) + `00:DEE4[t]` (road styles) + laps `00:DEA4`, pit `00:DF24`, palette/graphics tables; scenery = one template byte per piece; objects = 5-byte records. All of this is plain data (see `tools/objects.py` for the exact expansion rule).
Unknown: role of scenery blocks within a type, thresholds table semantics (05:A05F values look like 16-bit distances in `$1E8A/2` units 0x1000..), the sprite DMA frame format.

## CORRECTION (session 4): there are **32 tracks**, not 16
Descriptor table `0C:8402+10*t` is valid for t = 0..31 (entry 32 is already other data); `00:DEA4` (laps), `00:DEE4` (road styles), `00:DF24` (pit) likewise have 32 entries. Earlier statements "16 tracks" in this file refer only to tracks 0-15.
* Laps t=0..31: 3,3,3,6,6,4,6,3,7,5,3,6,7,3,6,8, 3,3,3,3,3,7,6,3,3,6,3,3,8,3,3,4.
* Tracks with a pit stop (00:DF24 != FFFF): 3,4,6,8,9,11,12,14,15,21,22,25,28 (so the earlier list "no pit: 0,1,2,5,7,10,13" is only for tracks 0-15; 16-20,23,24,26,27,29-31 also have none).
* `tools/track_atlas.py 0` -> `out/tracks.png` (tracks 0-15), `tools/track_atlas.py 1` -> `out/tracks_16_31.png`; `tools/objmap.py` now covers all 32 -> `out/objects.png`.
* Likely structure: 8 countries x 4 tracks (menu number -> `$1F06` mapping not yet decoded; track 4 = tunnel near the start, user-confirmed).
* Per-track tables indexed by track (bot offsets `00:DDE4[track*6+diff*2]`, graphics `00:DFA4`, palette `00:E0E4`, sky `E124`) presumably also have 32 entries; verify before using tracks >= 16.

## Per-track tables verified for all 32 tracks (session 4)
Method: poked `$1F06` (track) at frames 2000-2400 in the headless emulator (`scripts/dump_track.lua`, TRACK=n), dumped `$7E4000-$7E71FF` at the race start and compared with the Python loaders for tracks 16, 21, 25, 31:
slope, curve, scenery and object streams are **identical word for word** (e.g. t=16: 1216/1216, 1216/1216, 1248/1248, 1248/1248). Length `$0200`, laps `$1E56` and pit start `$1EF0` also agree with the tables (t=21: laps 7, `$1EF0`=0x7600 = 2*(0xBB00&0x7FFF)).
All tables below have 32 entries, stored back to back (64 bytes each, 00:DDE4 has 6 bytes per track):
| table | content |
|---|---|
| `00:DDE4` (6 B/track) | bot speed offsets per difficulty: tracks 0-15 e.g. t0 {0,80,160}, t1 {128,416,704}; tracks 16-31 all start at 288 (e.g. t18 {288,672,1056}, t22 {288,224,160} -> that track gets *easier* with difficulty, t20 {288,320,352}) |
| `00:DEA4` laps, `00:DEE4` road styles, `00:DF24` pit | verified, see above |
| `00:DF64` | pointer (bank 5 for t<16, bank 6 for t>=16: `ROL` of the CPX #$20 carry, 00:C20D) to a compressed stream, unpacked by 00:EA8E/EA9B into VRAM $6800 = per-track background/horizon graphics |
| `00:DFA4` | 64-byte graphics blocks (0xC849 + 0x40*t) copied to VRAM $1AE0/$1EE0 |
| `00:DFE4` | palette offset 0x20*t (CGRAM upload from 05:8A5A / 8E5A, 00:BAFB / BB6B) |
| `00:E024`, `00:E064` | per-track pointers copied to `$0106` (all 0x84F0 / 0x8664 except tracks 2 (0x8400) and 9 (0x8826/0x87D8): different sound/music/background scripts?) |
| `00:E0A4` | optional per-track colour (negative = none; used at 00:CDB0) |
| `00:E0E4` | background palette words, `00:E124` sky gradient stream offsets (0x0, 0xB0, 0x1F8, ...) |
| `0D:C6D6[t]` | laps again (bytes), `0D:C6F6[t]` = number of 1024-unit pieces (22, 41, 42, ...), both used by the menu/track-select screen |
* `$1F06 & 0x1C` = **country** (0..7; track = country*4 + 0..3); a random-track path masks `$1FFC & 0x1F`.
* **Passwords** (menu 0F:85F2): shown for countries 1..7 (the 2nd..8th), 8 characters, table `0D:C513` = 7 per difficulty x 3: amateur MOONBATH, GEARBOX, CAR PARK, ROAD HOG, EMULATOR, ANALYSER, HORIZONS; professional FOUR MEG, LEGEND, THEWORLD, LETSRACE, ALCHEMY, A LOOPER, SEASONAL; championship EDUCATED, OILCLOTH, WRECKAGE, CARACOLE, EPYLLION, GLUCAGON, KEELSON
  (index = (country-1)*8 + difficulty*0x38; country 1 = tracks 4-7 etc.; country 0 needs none).


