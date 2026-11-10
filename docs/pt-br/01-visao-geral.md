# Top Gear (USA, SNES) – notas de engenharia reversa

ROM: `Top Gear (USA).sfc`, 512 KB, LoROM, sem header de copiador, checksum OK.
Vetores do header (modo nativo): NMI=$0000, IRQ=$0004 -> **são endereços da WRAM** (stubs, veja abaixo).
RESET em modo de emulação = $8000.

## Ferramentas (todas no repositório)
| o quê | onde |
|---|---|
| Disassembler (65816, rastreio dos flags M/X, sementes de trace, imagem da WRAM) | `tools/disasm.py` -> `disasm/top_gear.asm` (`make disasm`) |
| Rótulos verificados à mão | `disasm/names.txt` |
| Executor headless do Mesen2 | `tools/mesen.sh script.lua` (veja a nota de contorno no script) |
| Scripts Lua | `scripts/` (`trace.lua` = trace de cobertura, `dumpram.lua`, `speed.lua`, `writers.lua` = "quem escreve em X?") |
| Auxiliar de folha de contato | `tools/sheet.py` |

Script de entrada do menu (números de frame, headless): Start@1300,1420 -> Options; Down x4 @1600.. ; A@1700 (PLAY GAME) -> a corrida começa por volta do frame 2950.
Controles: **X = acelerar**, A = nitro, Left/Right esterçam. (B/Y/Up/L/R não aceleram.)

## Boot e interrupções
* O código de reset descomprime um bloco da ROM (leituras via `sub_00EA8E/EA9B`) para a WRAM `$7E2000`; é
  uma imagem do motor (~5 KB de código, `7E2000-7E34AD`) que fica **estática depois do frame ~1200** (nenhum overlay observado).
* Os vetores NMI/IRQ apontam para a WRAM `$0000/$0004`, que contém stubs `JML` que o jogo redireciona:
  menus: NMI -> `$0F:8000`; corrida: NMI -> `$00:EC1A`, IRQ -> `$00:EC5B`.

## Vídeo
* Tela de título: **Mode 7**. Corrida: **BG Mode 1 + 7 canais de HDMA** (`hdmaChannels=$7F`).
  Destinos de HDMA observados: `$2121/$2122` (paleta por scanline -> listras da pista/degradê do céu), `$2111` (scroll de BG por linha -> curvas),
  `$2126` (janela), além da OAM. A pista é, portanto, um pseudo-3D de efeito por scanline, construído pelo código do motor na WRAM, que
  escreve tabelas de HDMA em torno de `$1834/$2805/$280A`.
* A tela da corrida é dividida: em cima o jogador 1, embaixo o "COMPUTER" (cada um com seu HUD).
