# Top Gear (USA, SNES) – notas de ingeniería inversa

ROM: `Top Gear (USA).sfc`, 512 KB, LoROM, sin cabecera de copiador, checksum OK.
Vectores de la cabecera (modo nativo): NMI=$0000, IRQ=$0004 -> **son direcciones de la WRAM** (stubs, ver abajo).
RESET en modo emulación = $8000.

## Herramientas (todas en el repositorio)
| qué | dónde |
|---|---|
| Desensamblador (65816, seguimiento de los flags M/X, semillas de traza, imagen de la WRAM) | `tools/disasm.py` -> `disasm/top_gear.asm` (`make disasm`) |
| Etiquetas verificadas a mano | `disasm/names.txt` |
| Ejecutor headless de Mesen2 | `tools/mesen.sh script.lua` (ver la nota de solución alternativa en el script) |
| Scripts Lua | `scripts/` (`trace.lua` = traza de cobertura, `dumpram.lua`, `speed.lua`, `writers.lua` = "¿quién escribe en X?") |
| Ayudante de hoja de contactos | `tools/sheet.py` |

Script de entrada del menú (números de frame, headless): Start@1300,1420 -> Options; Down x4 @1600.. ; A@1700 (PLAY GAME) -> la carrera empieza hacia el frame 2950.
Controles: **X = acelerar**, A = nitro, Left/Right giran. (B/Y/Up/L/R no aceleran.)

## Arranque e interrupciones
* El código de reset descomprime un bloque de la ROM (lecturas mediante `sub_00EA8E/EA9B`) a la WRAM `$7E2000`; es
  una imagen del motor (~5 KB de código, `7E2000-7E34AD`) que queda **estática después del frame ~1200** (no se vieron overlays).
* Los vectores NMI/IRQ apuntan a la WRAM `$0000/$0004`, que contiene stubs `JML` que el juego redirige:
  menús: NMI -> `$0F:8000`; carrera: NMI -> `$00:EC1A`, IRQ -> `$00:EC5B`.

## Vídeo
* Pantalla de título: **Mode 7**. Carrera: **BG Mode 1 + 7 canales de HDMA** (`hdmaChannels=$7F`).
  Destinos de HDMA observados: `$2121/$2122` (paleta por scanline -> franjas de la carretera/degradado del cielo), `$2111` (scroll de BG por línea -> curvas),
  `$2126` (ventana), además de la OAM. La carretera es, por tanto, un pseudo-3D de efecto por scanline, construido por el código del motor en la WRAM, que
  escribe tablas de HDMA alrededor de `$1834/$2805/$280A`.
* La pantalla de carrera está dividida: arriba el jugador 1, abajo el "COMPUTER" (cada uno con su HUD).
