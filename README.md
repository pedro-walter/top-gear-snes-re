# Top Gear (USA, SNES) – reverse engineering

Notes, tools and emulator scripts documenting how the SNES game *Top Gear (USA)* works:
car physics and nitro, opponent AI, pit stops, rank, the 32 tracks (road/scenery/object streams),
passwords, minimaps and day/night. Everything was derived from the game's assembly code and
runtime inspection in the Mesen2 emulator.

**This repository contains no game data.** You need your own legally obtained ROM
(`Top Gear (USA).sfc`, 512 KB, LoROM, no header). Put it in the repo root, or point `TOPGEAR_ROM` at it.

## Tracks (32 = 8 countries × 4)
USA: 0 Las Vegas, 1 Los Angeles, 2 New York, 3 San Francisco · South America: 4 Rio, 5 Machu Picchu,
6 Chichen Itza, 7 Rain Forest · Japan: 8 Tokyo, 9 Hiroshima, 10 Yokohama, 11 Kyoto ·
Germany: 12 Munich, 13 Cologne, 14 Black Forest, 15 Frankfurt · Scandinavia: 16 Stockholm,
17 Copenhagen, 18 Helsinki, 19 Oslo · France: 20 Paris, 21 Nice, 22 Bordeaux, 23 Monaco ·
Italy: 24 Pisa, 25 Rome, 26 Sicily, 27 Florence · UK: 28 London, 29 Sheffield, 30 Loch Ness, 31 Stonehenge

## Documentation (`docs/`)
1. [Overview, tooling, boot, video](docs/01-overview.md)
2. [Car physics, gears, nitro, the 3rd-gear trick](docs/02-car-physics-nitro.md)
3. [Race car list, bots/AI, HUD speed, rank](docs/03-cars-ai-hud-rank.md)
4. [Pit stops](docs/04-pit-stops.md)
5. [Track data, scenery and object streams, per-track tables](docs/05-tracks-scenery-objects.md)
6. [Track names, passwords, minimaps, day/night](docs/06-names-minimap-daynight.md)
7. [Open items and corrections](docs/07-open-items-and-corrections.md)

## Tools (`tools/`, Python 3, run from the repo root with `python3 -I`)
| tool | purpose |
|---|---|
| `disasm.py` | 65816 disassembler with M/X tracking, trace seeds (`make disasm`) |
| `tracks.py`, `objects.py` | decode slope/curve data, scenery and object streams |
| `track_atlas.py`, `objmap.py`, `minimaps.py`, `minimap_path.py`, `daynight.py` | render track maps/minimaps (need Pillow) |
| `physics.py` | exact model of the speed/gear/nitro physics |
| `names.py` | track and country names |

`disasm/names.txt` has hand-verified labels. The generated disassembly (`disasm/top_gear.asm`) and
all dumps in `out/` are derived from the ROM and are not committed; `make disasm` regenerates them.

## Emulator scripts (`scripts/`)
Lua scripts for [Mesen2](https://github.com/SourMesen/Mesen2/releases) (tested with 2.1.1) run headless via
`tools/mesen.sh scripts/<name>.lua`. Install Mesen2 into `tools/mesen/` first. The launcher uses an
isolated `HOME` (`tools/mesen-home`) so your own Mesen settings are untouched; scripts need
`AllowIoOsAccess` enabled in its `settings.json` (the launcher patches it if the file exists – run once,
then re-run). On some Linux setups an `LD_PRELOAD` of the system libstdc++ is needed (already in the launcher).

## Open questions
What darkens the screen on night tracks, sprite frame/DMA format, object hit thresholds,
the role of scenery blocks within a road type. See docs/07.

## License
MIT (code and docs), see `LICENSE`.
