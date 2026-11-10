## Pendências / próximos passos
1. Nomear as rotinas restantes do banco 05 (direção, colisões, IA, lógica de volta/posição). Use o padrão de `scripts/writers.lua`
   (callbacks de escrita/leitura) nos vizinhos de `$1E5A` ($1E58-$1EFF parece ser a struct do carro do jogador) e nas
   structs dos oponentes.
2. Formato dos dados da pista (curvas/ladeiras): achar o leitor que preenche as tabelas de scroll de HDMA.
3. IA (rubber-banding): inspecionar as escritas na struct do computador.
4. Descompressor (`$00:EA8E`/`EA9B`, `EBB6`) e os bancos de gráficos/música (91% da ROM não é código).
5. Upload do driver de som SPC700 (`$07:8000` parece ser isso).
6. 13 saltos indiretos não resolvidos listados no fim do disassembly (tabelas de salto).

---

## Adendos (verificados no emulador)
* `$1E90` = delta de frames (`$0C` frames decorridos + 1) – o laço principal é baseado em tempo; progresso e movimento lateral escalam com ele, motor/arrasto/combustível são por tick (então o consumo de combustível depende da taxa de frames).
* Progresso por frame: bots `speed/256` unidades (medido exatamente), jogador `speed/512` por unidade de velocidade => um valor de bot v equivale a uma velocidade de jogador 2v (km/h = v*0,0469): os bots cruzam a ~94..177 km/h na pista 0 fácil.
* **Rubber band do carro do computador** (05:EE19, verificado): só na marcha mais alta, só se a dificuldade `$1F10 != 3`, e só quando o computador está *à frente*: `top -= min(gap, 1024)` onde
  `gap = (laps_ahead*track_len + camera_pos_diff)`; a dificuldade 0 dobra (até -2048). Nunca o acelera. As dificuldades 1 e 2 se comportam igual aqui, a 3 não tem nenhum.
* Teste de pit (alterar a pista `$1F06=3` antes do loader): o computador com combustível 6642 entrou no pit perto da pos 7450, reabasteceu até 0xA7FF e saiu. Pistas com pit: 3,4,6,8,9,11,12,14,15 (`00:DF24`, FFFF = nenhum). Voltas por pista `00:DEA4`: 3,3,3,6,6,4,6,3,7,5,3,6,7,3,6,8.
* Nitro medido: ativo por 320 frames, cargas 3 -> 2.
* `out/tracks.png` (tools/track_atlas.py): perfis de curva (vermelho) e ladeira (azul) das 16 pistas.

## Correções / confirmado pelo usuário (fim da sessão 3)
- A dificuldade `$1F10` só vai de 0..2 pelo menu (amateur/professional/championship; escrita em 0F:940D, 0F:96C6). O valor 3 no código do rubber-band (05:EE19) é só um ramo "nenhum", sem escritor conhecido. Amateur dobra a desaceleração do computador; professional == championship.
- Truque 3ª marcha + nitro, confirmado pelo usuário jogando: 3ª marcha até ~250 km/h e depois 5ª. Modelo (physics.py, nitro, tanque cheio, plano) cruzamento onde a 5ª >= 3ª: tabela de carro 0: 154 km/h (vermelho, "igual acima de ~150"), tabela 2: 221 (roxo "~220"), tabelas 1/3: 248 (branco/azul "~250"). Mapeamento cor->índice inferido, a verificar com $1F8F. Teto da 3ª marcha com nitro ~265-273 km/h.



## Correções encontradas ao anotar o disassembly (sessão 6)
* `$1FF6` **não** é uma flag de unidades: é o **contador regressivo do modo attract / flag de demo** da tela de título ($04B0 frames, depois `0F:90E6`
  inicia uma corrida de demo numa pista aleatória e o põe em `$8000`; qualquer botão encerra a demo). O "km/h quando
  negativo" do HUD em docs/03 significa apenas "corridas de demo mostram km/h".
* O trabalho por frame da corrida não roda no NMI: `nmi_handler_race` só lê os controles. O handler de IRQ despacha
  pelo ponteiro em `$0A` (`00:B6D1` ...) e a grande rotina de vblank é chamada por `$08` (`00:B75A`); dia/noite
  (`00:BAB9`), pontos do mapa, DMA da equipe do pit e o scanner de cenário são seções dela.
* A entrada de texto do menu (`0F:943D`) é uma grade de 6 colunas (`A..Z`, depois células de glifo `3`/`4` = espaço/apagar, `END`) que escreve até 8
  caracteres em `$68..$6F`; o menu principal (`0F:918B`) tem 5 entradas (jogadores, skill, país, mph/kph, play game).

## Descobertas ao construir o randomizer (sessão 7, docs/10)
* **Palavras de objetos laterais**: `type<<9 | side<<8 | lateral/128`, e o **bit de lado ligado significa ESQUERDA** (o código de colisão nega a lateral
  quando o bit está ligado). O gatilho da entrada do pit (`05:D75E..D7C0`, jogador 1) dispara quando uma palavra de objeto `& $FE00 == $7400` é
  ultrapassada com o carro *além* do objeto lateralmente, no lado dele (p. ex. palavra `$757C`: esquerda, 15872 -> lateral do carro abaixo de
  cerca de -16000).
* A tabela de objetos é lida **até $58 bytes além da última peça da volta** por `scan_roadside_objects` (`00:E20D`); o loader
  original expande L+2 peças (as peças extras são lidas além do fim dos streams). Lixo ali significa
  laços de objetos de grupo de até 65536 iterações.
* **O banco 7F é parcialmente usado**: a tabela de corredor (`$7E7000 + 2*(position/2)`) continua em `7F:0000..$2800`.
* A fonte dourada grande do menu não tem glifos para `0` e `5..9` (os dígitos `1`,`2` existem, `3`/`4` são os glifos de seta); a fonte pequena
  (`draw_string`, tiles 8x8 na mesma área da VRAM) tem todos os dígitos. `0F:9E1C` "upload_font" só limpa a VRAM $0000-$0FFF.
* Objetos de grupo (bit 15 da palavra: túneis, pórtico) vêm dos bytes de registro `b0..b3` com o bit 6 ligado; só as pistas 4, 20, 23, 29
  os têm (além do pórtico de largada `$8002`).
* As tabelas de página de menu `0D:C716/C738/C75A` (listas a, b, c por página) guardam 17 páginas; a página 8 é a grade de PASSWORD, a 3 a grade de nomes,
  a 15 a tela de localização. `$0F:ABE9` é a lista de textos da tela de localização, `0D:C6D6/C6F6[track]` voltas/peças para as estatísticas dela.

## Catálogo de tipos de objeto e fonte do menu (trabalho do randomizer, sessão 8)
Visto colocando um tipo por vez numa corrida em andamento (`scripts/rando_types.lua`, `tools/sheet_types.py`; os gráficos são por tipo, parte
da arte pode variar por ambiente): 5 = outdoor KEMCO, 6 = barris, 7 = barreira listrada de perigo, **8 = chevron `>` (curva à direita), 9 = chevron `<`
(curva à esquerda)**, 10 = triângulo de aviso, 11/12 = postes de luz, **13 = bandeira PITS**, 14/15 = cercas/arbustos, 21-23 = palmeiras, 24-31 = árvores/cactos/
plantas, 30 = outdoor GREMLIN, 37-47 = outdoors, 53-57 = mastros de bandeira/flâmulas, 58 = gatilho da entrada do pit. 1-4, 16-17 = outros carros.
Nos dados originais o tipo 8 fica sempre à esquerda (bit de lado 1) antes de uma curva *negativa* e o tipo 9 à direita antes de uma positiva;
a direção de um chevron é fixada pelo seu tipo, não pelo lado em que ele está.
Fonte do menu: os tiles 128..255 da VRAM guardam os glifos dourados 16x16 no layout de sprite (slot s = tile 128 + (s>>3)*32 + (s&7)*2, metade de baixo +16);
a fonte branca pequena é um bloco separado (`0F:BBA7` -> palavra de VRAM $1000); o texto desenhado por `draw_string_to_buffer` escreve palavras de tile no
buffer em `$0C6C` (passo $40 por linha de tiles; a segunda passada soma 16 aos números de tile para a metade de baixo). `draw_selection_bar` constrói a
pílula azul com **sprites da OAM** (tiles `$0EC2..$0EC8`, `$4A` = comprimento em sprites, X = offset de byte da OAM; X=8 reserva o sprite 0 para o cursor do texto).
Descompressor gráfico `0F:B306` (variante de LZ, anel de 2 KB): o bloco `0D:A44D` -> palavra de VRAM $1800 é a fonte dourada.
