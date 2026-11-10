# Top Gear (USA, SNES) – reverse-engineering notes

ROM: `Top Gear (USA).sfc`, 512 KB, LoROM, no copier header, checksum OK.
Header vectors (native): NMI=$0000, IRQ=$0004 -> **these are WRAM addresses** (stubs, see below).
Emulation RESET=$8000.

## Tooling (all in repo)
| what | where |
|---|---|
| Disassembler (65816, M/X flag tracking, trace seeds, WRAM image) | `tools/disasm.py` -> `disasm/top_gear.asm` (`make disasm`) |
| Hand-verified labels | `disasm/names.txt` |
| Headless Mesen2 runner | `tools/mesen.sh script.lua` (see workaround note in script) |
| Lua drivers | `scripts/` (`trace.lua` coverage trace, `dumpram.lua`, `speed.lua`, `writers.lua` = "who writes X?") |
| Contact-sheet helper | `tools/sheet.py` |

Menu input script (frame numbers, headless): Start@1300,1420 -> Options; Down x4 @1600.. ; A@1700 (PLAY GAME) -> race starts ~frame 2950.
Controls: **X = accelerate**, A = nitro, Left/Right steer. (B/Y/Up/L/R do not accelerate.)

## Boot & interrupts
* Reset code decodes a compressed block from ROM (reads via `sub_00EA8E/EA9B`) into WRAM `$7E2000`; this is
  an engine image (~5 KB of code, `7E2000-7E34AD`) that is **static after frame ~1200** (no overlays seen).
* NMI/IRQ vectors point at WRAM `$0000/$0004`, which hold `JML` stubs that the game retargets:
  menus: NMI -> `$0F:8000`; race: NMI -> `$00:EC1A`, IRQ -> `$00:EC5B`.

## Video
* Title screen: **Mode 7**. Race: **BG Mode 1 + 7 HDMA channels** (`hdmaChannels=$7F`).
  HDMA dests seen: `$2121/$2122` (per-scanline palette -> road stripes/sky gradient), `$2111` (BG scroll per line -> curves),
  `$2126` (window), plus OAM. The road is therefore a scanline-effect pseudo-3D, built by the WRAM engine code which
  writes HDMA tables around `$1834/$2805/$280A`.
* Race screen is split: top = player 1, bottom = "COMPUTER" (own HUD each).


