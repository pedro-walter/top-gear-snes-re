# Top Gear (USA, SNES) – reverse engineering

Notes, tools and emulator scripts documenting how the SNES game *Top Gear (USA)* works:
car physics and nitro, opponent AI, pit stops, rank, the 32 tracks (road/scenery/object streams),
passwords, minimaps and day/night. Everything was derived from the game's assembly code and
runtime inspection in the Mesen2 emulator.

**This repository contains no game data.** You need your own legally obtained ROM
(`Top Gear (USA).sfc`, 512 KB, LoROM, no header). Put it in the repo root, or point `TOPGEAR_ROM` at it.

## Randomizer (work in progress)
`python3 -I tools/build_rando.py` turns your ROM into `out/rando.sfc` (1 MB): every race is a **random track generated on the
console from an 8-hex-digit seed** (3-8 laps, always a pit stop, one of the 32 original environments). The main menu has `1 PLAYER`, `DIFFICULTY`, `<n> TRACKS`
(Left/Right: 1..99 or infinite), `SEED xxxxxxxx` (A = hex keypad, Left/Right = new random seed; only with `1 TRACK`), `SPEED KPH/MPH` and `PLAY GAME`.
One track: the results screen returns to the menu and the seed is kept for a replay. More tracks (or infinite): a new random track after every race,
championship points of all racers add up, and a podium scene closes a finite series. `python3 -I tools/make_ips.py` writes an IPS patch (our bytes only). Details and tests: docs/09, docs/10.

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
8. [Accelerator + brake cornering trick (P1 only)](docs/08-brake-cornering-trick.md)
9. [Randomizer plan and decisions](docs/09-randomizer-plan.md)
10. [Randomizer implementation status, memory map, tests](docs/10-randomizer-implementation.md)
11. [Speech balloons and messages](docs/11-speech-balloons-messages.md)
12. [Ideal gear shifts](docs/12-ideal-gear-shifts.md)
13. [Race results, championship points, qualification / game over, podium scene](docs/13-race-results-qualification-podium.md)

## Tools (`tools/`, Python 3, run from the repo root with `python3 -I`)
| tool | purpose |
|---|---|
| `disasm.py` | 65816 disassembler with M/X tracking, trace seeds (`make disasm`) |
| `tracks.py`, `objects.py` | decode slope/curve data, scenery and object streams |
| `track_atlas.py`, `objmap.py`, `minimaps.py`, `minimap_path.py`, `daynight.py` | render track maps/minimaps (need Pillow) |
| `physics.py` | exact model of the speed/gear/nitro physics |
| `names.py` | track and country names |
| `asm65816.py`, `build_rando.py`, `trackgen.py`, `make_ips.py`, `rando_test.py` | randomizer: assembler, ROM builder, Python reference generator, IPS export, generator test against the console code (headless Mesen) |

## Resuming the work: the annotated disassembly
`make disasm` builds `disasm/top_gear.asm` (needs your ROM, `out/trace_main.txt` and `out/wram_3300.bin`, produced by
`tools/mesen.sh scripts/trace.lua` and `scripts/dumpram.lua`). It is **generated and not committed** (it contains
the game's code). All hand-written knowledge lives in `disasm/annot/`:

| file | content |
|---|---|
| `symbols.txt` | routine names and doc blocks (`@BBAAAA name`, `;; text`) - shown as headers with callers and read/write/call lists |
| `ram.txt` | WRAM/direct-page variable names and meanings (shown on every operand) |
| `hwregs.txt` | PPU/CPU/DMA registers; immediate values stored to key registers are decoded |
| `comments.txt` | per-address inline comments (`BBAAAA text`) |
| `regions.txt` | typed data regions (tables) and bank descriptions |

Routines marked `(not yet analysed)` in the output still need reading; add their name/doc to `symbols.txt`
and rerun `make disasm`. `disasm/names.txt` is the older label list (still honoured).
Main game flow: `reset_vec` -> `main_restart` -> `load_track` -> `race_loop`; menus are `menu_entry` (0F:806D) called with
JSL from bank 00; the per-frame renderer runs inside the IRQ (`irq_handler_race` -> `vblank_main_work`).

## Emulator scripts (`scripts/`)
Lua scripts for [Mesen2](https://github.com/SourMesen/Mesen2/releases) (tested with 2.1.1) run headless via
`tools/mesen.sh scripts/<name>.lua`. Install Mesen2 into `tools/mesen/` first. The launcher uses an
isolated `HOME` (`tools/mesen-home`) so your own Mesen settings are untouched; scripts need
`AllowIoOsAccess` enabled in its `settings.json` (the launcher patches it if the file exists – run once,
then re-run). On some Linux setups an `LD_PRELOAD` of the system libstdc++ is needed (already in the launcher).

## Open questions
Sprite frame/DMA format, object hit thresholds,
the role of scenery blocks within a road type. See docs/07.

## License
MIT (code and docs), see `LICENSE`.
