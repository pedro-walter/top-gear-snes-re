# Top Gear (USA, SNES) – engenharia reversa

[English](README.md) · **Português (BR)** · [Español](README.es.md)

Notas, ferramentas e scripts de emulador que documentam como funciona o jogo de SNES *Top Gear (USA)*:
física do carro e nitro, IA dos oponentes, pit stops, posição na corrida, as 32 pistas (streams de estrada/cenário/objetos),
senhas, minimapas e dia/noite. Tudo foi derivado do código assembly do jogo e da inspeção em tempo de execução no
emulador Mesen2.

**Este repositório não contém dados do jogo.** Você precisa da sua própria ROM obtida legalmente
(`Top Gear (USA).sfc`, 512 KB, LoROM, sem header). Coloque-a na raiz do repositório, ou aponte `TOPGEAR_ROM` para ela.

## Randomizer (BETA 0.5, patch em `release/`)
`python3 -I tools/build_rando.py` transforma a sua ROM em `out/rando.sfc` (1 MB): toda corrida é uma **pista aleatória gerada no
console a partir de uma seed de 8 dígitos hex** (3-8 voltas, sempre com pit stop, um dos 32 ambientes originais). O menu principal tem `1 PLAYER`, `DIFFICULTY`,
`<n> TRACKS` (Left/Right: 1..99 ou infinito), `SEED xxxxxxxx` (A = teclado hex, Left/Right = nova seed aleatória; só com `1 TRACK`), `SPEED KPH/MPH` e `PLAY GAME`.
Uma pista: a tela de resultados volta ao menu e a seed é mantida para repetir a pista. Mais pistas (ou infinito): uma pista aleatória nova depois de cada corrida,
os pontos de campeonato de todos os pilotos se somam, e uma cena de pódio encerra uma série finita. `python3 -I tools/make_ips.py` gera um patch IPS (só os nossos bytes).
Resumo das features e correções: [docs/pt-br/17](docs/pt-br/17-resumo-do-randomizer.md). Detalhes e testes: docs/09, docs/10.

## Pistas (32 = 8 países × 4)
EUA: 0 Las Vegas, 1 Los Angeles, 2 New York, 3 San Francisco · América do Sul: 4 Rio, 5 Machu Picchu,
6 Chichen Itza, 7 Rain Forest · Japão: 8 Tokyo, 9 Hiroshima, 10 Yokohama, 11 Kyoto ·
Alemanha: 12 Munich, 13 Cologne, 14 Black Forest, 15 Frankfurt · Escandinávia: 16 Stockholm,
17 Copenhagen, 18 Helsinki, 19 Oslo · França: 20 Paris, 21 Nice, 22 Bordeaux, 23 Monaco ·
Itália: 24 Pisa, 25 Rome, 26 Sicily, 27 Florence · Reino Unido: 28 London, 29 Sheffield, 30 Loch Ness, 31 Stonehenge

## Documentação (`docs/pt-br/`, também em inglês: [`docs/en/`](docs/en/) e espanhol: [`docs/es/`](docs/es/))
1. [Visão geral, ferramentas, boot, vídeo](docs/pt-br/01-visao-geral.md)
2. [Física do carro, marchas, nitro, o truque da 3ª marcha](docs/pt-br/02-fisica-do-carro-nitro.md)
3. [Lista de carros da corrida, bots/IA, velocidade no HUD, posição](docs/pt-br/03-carros-ia-hud-posicao.md)
4. [Pit stops](docs/pt-br/04-pit-stops.md)
5. [Dados das pistas, streams de cenário e objetos, tabelas por pista](docs/pt-br/05-pistas-cenario-objetos.md)
6. [Nomes das pistas, senhas, minimapas, dia/noite](docs/pt-br/06-nomes-minimapa-dia-noite.md)
7. [Pendências e correções](docs/pt-br/07-pendencias-e-correcoes.md)
8. [Truque acelerador + freio nas curvas (só P1)](docs/pt-br/08-truque-acelerador-freio-curva.md)
9. [Plano e decisões do randomizer](docs/pt-br/09-plano-do-randomizer.md)
10. [Status da implementação do randomizer, mapa de memória, testes](docs/pt-br/10-implementacao-do-randomizer.md)
11. [Balões de fala e mensagens](docs/pt-br/11-baloes-de-fala-mensagens.md)
12. [Trocas de marcha ideais](docs/pt-br/12-trocas-de-marcha-ideais.md)
13. [Resultados da corrida, pontos do campeonato, qualificação / game over, cena do pódio](docs/pt-br/13-resultados-qualificacao-podio.md)
14. [O que difere entre os quatro carros](docs/pt-br/14-diferencas-entre-carros.md)
15. [USA vs Europa vs Japão: as três versões](docs/pt-br/15-versoes-da-rom.md)
16. [Economizar combustível: o que funciona e o que não funciona](docs/pt-br/16-economia-de-combustivel.md)
17. [Resumo do randomizer: features e correções de bugs](docs/pt-br/17-resumo-do-randomizer.md)

## Ferramentas (`tools/`, Python 3, rode da raiz do repositório com `python3 -I`)
| ferramenta | finalidade |
|---|---|
| `disasm.py` | disassembler 65816 com rastreio de M/X e sementes de trace (`make disasm`) |
| `tracks.py`, `objects.py` | decodificam dados de ladeira/curva, cenário e streams de objetos |
| `track_atlas.py`, `objmap.py`, `minimaps.py`, `minimap_path.py`, `daynight.py` | renderizam mapas/minimapas das pistas (precisam do Pillow) |
| `physics.py` | modelo exato da física de velocidade/marcha/nitro |
| `names.py` | nomes de pistas e países |
| `asm65816.py`, `build_rando.py`, `trackgen.py`, `make_ips.py`, `rando_test.py` | randomizer: assembler, construtor da ROM, gerador de referência em Python, exportação IPS, teste do gerador contra o código do console (Mesen headless) |

## Retomando o trabalho: o disassembly anotado
`make disasm` gera `disasm/top_gear.asm` (precisa da sua ROM, de `out/trace_main.txt` e `out/wram_3300.bin`, produzidos por
`tools/mesen.sh scripts/trace.lua` e `scripts/dumpram.lua`). Ele é **gerado e não é commitado** (contém
o código do jogo). Todo o conhecimento escrito à mão fica em `disasm/annot/`:

| arquivo | conteúdo |
|---|---|
| `symbols.txt` | nomes de rotinas e blocos de documentação (`@BBAAAA name`, `;; text`) - mostrados como cabeçalhos com chamadores e listas de leitura/escrita/chamada |
| `ram.txt` | nomes e significados de variáveis da WRAM/direct page (mostrados em todo operando) |
| `hwregs.txt` | registradores de PPU/CPU/DMA; valores imediatos gravados em registradores-chave são decodificados |
| `comments.txt` | comentários por endereço (`BBAAAA text`) |
| `regions.txt` | regiões de dados tipadas (tabelas) e descrições de bancos |

As rotinas marcadas `(not yet analysed)` na saída ainda precisam ser lidas; adicione o nome/documentação em `symbols.txt`
e rode `make disasm` de novo. `disasm/names.txt` é a lista de rótulos mais antiga (ainda respeitada).
Fluxo principal do jogo: `reset_vec` -> `main_restart` -> `load_track` -> `race_loop`; os menus são `menu_entry` (0F:806D) chamado
com JSL a partir do banco 00; o renderizador por frame roda dentro do IRQ (`irq_handler_race` -> `vblank_main_work`).

## Scripts de emulador (`scripts/`)
Scripts Lua para o [Mesen2](https://github.com/SourMesen/Mesen2/releases) (testado com 2.1.1) rodados headless por
`tools/mesen.sh scripts/<nome>.lua`. Instale o Mesen2 em `tools/mesen/` primeiro. O launcher usa um
`HOME` isolado (`tools/mesen-home`) para que suas próprias configurações do Mesen não sejam tocadas; os scripts precisam de
`AllowIoOsAccess` ativado no `settings.json` dele (o launcher o altera se o arquivo existir – rode uma vez,
depois rode de novo). Em algumas configurações Linux é necessário um `LD_PRELOAD` da libstdc++ do sistema (já incluído no launcher).

## Questões em aberto
Formato de frame/DMA de sprites, limiares de acerto de objetos,
o papel dos blocos de cenário dentro de um tipo de pista. Veja docs/07.

## Licença
MIT (código e docs), veja `LICENSE`.
