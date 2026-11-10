# Randomizer: status da implementação e mapa

Build: `python3 -I tools/build_rando.py` (precisa da ROM original, variável `TOPGEAR_ROM`, padrão `Top Gear (USA).sfc`) escreve
`out/rando.sfc` (1 MB, LoROM, byte de tamanho do header + checksum corrigidos). Nada do original fica guardado no repositório: as
fontes são `src/gen.asm` (gerador), `src/hooks.asm` (patches do código original + cola do menu), `src/harness.asm`
(só no build de teste), montadas por `tools/asm65816.py` (assembler de 65816 próprio, de duas passagens; desvios longos são relaxados
automaticamente, `$0012` = absoluto, `$12` = direct page, `$123456` = long, os sufixos `.l/.w/.b` forçam tamanhos).

## O que funciona (tudo verificado headless no Mesen)

* **Gerador** (`src/gen.asm`, referência `tools/trackgen.py`): seed (32 bits) -> LFSR -> ambiente (uma das 32 pistas
  originais, guardada em `$1F06` para que toda tabela por pista continue funcionando), 24..46 peças, 3..8 voltas, caminhadas de ladeira e curva sobre o
  grafo de modelos (docs/09), objetos laterais e tipo de pista por peça copiados em trechos da própria pista do ambiente
  (então os conjuntos de objetos, o cenário sem túneis e as larguras de pista combinam com o ambiente), exatamente uma peça de pit (modelo 20 +
  objetos do pit, palavra do pit como `00:DF24`), expansão para as tabelas da WRAM `$7E4000/$4C00/$5800/$6400` idêntica a
  `00:BF44`. **`tools/rando_test.py` roda o gerador 65816 no Mesen headless (ROM de teste) e compara as quatro
  tabelas com a referência Python: 1500/1500 seeds idênticas.**
  * O loader expande **L+2** peças (uma cópia de volta da peça 0 e uma cópia de antecipação da peça 1). O scanner de objetos
    (`00:E20D`) lê até 0x58 bytes além do fim da volta; dados não inicializados ali faziam um laço de grupo rodar ~65 mil iterações
    (o jogo rodava a 1/4 da velocidade, gráficos lixo). Corrigido gerando a peça extra.
  * O banco `$7F:0000..$2800` NÃO está livre: a tabela de corredor `$7E7000` (bytes de comprimento) invade esse espaço. O rascunho/estado fica em
    `7F:F000..F8FF`: seed `F800`, magic `F806` (= $A55A depois de inicializado), flag do teclado `F808`, flag de pular título `F80A`,
    variáveis do gerador `F830..F87A`, arrays de stream `F000..F7FF`.
* **Hooks no jogo** (`src/hooks.asm`): `00:BF59` (expansão de streams -> gerador, define `$1F06`, `$0200`),
  `00:BF38` (voltas), `00:C162` (palavra / lado do pit), `0F:9281` (PLAY GAME: deriva o ambiente da seed, zera a
  tabela de pontos para que resultados/ranking mostrem só esta corrida), `0F:8487` (resultados -> volta ao menu principal, título pulado uma vez),
  entrada de menu `COUNTRY` -> `SEED` (o menu inteiro foi refeito depois, veja "Menu principal e séries de pistas" abaixo).
* **Interface da seed**: o menu principal mostra `SEED xxxxxxxx`; Left/Right nessa linha sorteia uma seed nova; A abre o teclado
  (`src/keypad.asm`, página 8 dos menus reaproveitada): **glifos dourados grandes**, uma grade de 6x3, o código digitado na
  caixa com a fonte grande, barra de seleção = a pílula de sprite do próprio jogo, o cursor dá a volta dentro das 18 células (nenhuma célula vazia pode ser
  selecionada). Teclas como na entrada de nome: A ou B = apertar a tecla (adiciona um caractere), X ou Y = apagar o último, START ou a tecla `END` = aceitar; a tecla `<-` apaga. Não digitar nada e
  aceitar = sortear uma seed nova. A seed persiste depois da corrida (repetição). A tela de splash mostra `SEED xxxxxxxx`,
  distância (peças/volta * 15/256 km) e LAPS.
  Grade: `0 1 2 3 4 5 / 6 7 8 9 A B / C D E F <- END`; o dígito hex 11 é desenhado como um `b` minúsculo porque o `B` quadrado da
  fonte é idêntico a um `8`.
* **Glifos de dígitos grandes** (`tools/bigfont.py`, desenhados à mão em `font/original/*.bmp`, BMPs indexados 16x16, índice 0 transparente, 1..15 = as cores da fonte dourada): a fonte
  dourada do jogo (tiles 128..255 da VRAM) não tem 0, 3-9 (0 = `O`, 5 = `S`, 8 = `B`), então `0`-`9`, `A`, `C`, `E`, `F` são lidos dos BMPs na hora do build. Os hex 11 / 13 continuam gerados como `b` / `d` minúsculos
  (um `B` / `D` quadrado seria lido como `8` / `0`; código de sete segmentos de `bigfont.py`). O sinal de infinito são dois glifos, `infinity_left.bmp` + `infinity_right.bmp`.
  Os 18 glifos são guardados na ROM como 3 KB de tiles 4bpp (`kp_gfx`) e copiados para os tiles 256..351 da VRAM (palavra `$2000`) em forced blank por `kp_build_glyphs` (teclado e menu principal);
  layout = o layout de sprite do jogo (`tile = 256 + (j>>3)*32 + (j&7)*2`, metade de baixo +16; slot 0..15 = valor hex, 16 / 17 = metades do infinito = tiles 320 / 322). A seta e o `END` ainda usam os tiles de glifo do jogo.
  `python3 tools/bigfont.py png out.png` renderiza uma prévia (desatualizada: só dígitos gerados).
* **Tela de título** (fim de `hooks.asm`, `purple_title` em `tools/build_rando.py`): o degradê do céu é uma tabela de cores de HDMA (CGADD/CGDATA, 224 palavras em `0D:C7FA` e `0D:C8DA`, só azul); o build soma vermelho proporcionalmente ao azul e reduz o verde, então o céu fica violeta. Os textos são sprites 8x8 desenhados por `draw_string_list` (`0F:9ED3`) a partir da lista em `0F:AFC6` (entradas: coluna, linha, offset de pixel x, y, texto, 0; fim da lista = palavra 0). A lista é substituída por uma em `0F:FB62` (padding sem uso do banco 0F; verificado com callbacks de leitura no título, menus e numa corrida) com `RANDOMIZER BY PEDRO WALTER` no lugar da linha de licença da Nintendo e `POWERED BY CLAUDE` no lugar da linha da Kemco; PRESS START continua igual, a linha de copyright da Gremlin é removida e a última linha diz `VERSION BETA 0.1`. A lista de texto é gerada por `title_lines()` em `tools/build_rando.py` (centralização, contagem de glifos para o laço abaixo); **mude o nome da release só em `VERSION` ali**. O código da lista para `.` é `=` (tile de sprite `$88`; dígitos são `$7B..$84`). O buffer de OAM só tem espaço para 72 sprites de texto (sprites 56..127) e as linhas mais longas precisam de 81 com espaços, então os espaços não emitem mais um sprite (hook em `0F:9EFB` salta para `0F:FBD0`, que só avança o x do próximo glifo em 8), e a contagem no laço de ajuste de tiles em `0F:8EDC` é o número de glifos (62 agora, eram 70; calculado no build).
* **Pontos vermelhos na fonte pequena**: a paleta 7 da fonte de sprites pequena (`0E:FD66`) tem vermelho no índice 5, usado por alguns pixels soltos em B, D e 8 (visíveis também no texto original do título); o build copia a cor do contorno (índice 6) por cima.
* **Placas** (catálogo de objetos em docs/07): os tipos de chevron (8, 9) e as bandeiras do pit (13) da pista de origem nunca são copiados; o gerador coloca
  5 chevrons (a cada 4 slots, o último 4 slots antes da curva) antes do início de toda curva - tipo 9 (`<`) à direita antes de uma
  curva positiva, tipo 8 (`>`) à esquerda antes de uma negativa - e bandeiras de pit (tipo 13, modelo `$18`/`$1A`) nas duas peças
  antes do pit como as pistas originais. A referência Python e o código 65816 são idênticos (`add_chevrons`).
* **Contadores de volta** (`src/bar.asm`, `hook_lapctr`): `LAP volta/voltas` (p. ex. `LAP 3/7`) alinhado à direita na coluna de tile 29 (tão largo quanto o cronômetro) da linha do BG1 sob cada cronômetro (linhas 5 e 19; as 7 células de `LAP n/m` começam na coluna 23, a célula na coluna 21/22 é deixada em paz para que a última letra das mensagens largas como `4 LAPS LEFT` (colunas 11..21) não seja apagada; o medidor de combustível fica na coluna 30 da linha 6 para baixo), um por carro (o de baixo é o computador no modo de um jogador). `$1E76` / `$1E78` contam voltas completas (`$FFFF` enquanto o carro ainda está antes da linha da volta 1), mostrado = isso + 1, no mínimo 1, no máximo `$1E56`. Fonte = os próprios tiles do HUD para os dígitos (`$35..$3E`, os do cronômetro) e o A (`$4B`), mais os tiles `$B0..$B2` do BG1 (palavra de VRAM `$0B00`) para L, P e a barra no mesmo estilo, sombra repintada de preto, paleta 3, gerados por `tools/lapfont.py`, enviados por `hook_bar`). As células são reescritas a cada frame por um JSL no início de `draw_hud_speed` (`00:CE61`, roda com a VRAM gravável; o hook termina com o `LDA $1E5A` substituído porque quem chama desvia pelos flags dele).
* **Linha da seed no menu principal** (`hooks.asm`, `build_seed_tiles`): a fonte pequena tem 8 linhas de altura mas a barra seletora tem 16, então os 16 glifos hex (copiados para a ROM como `seed_glyphs`: a fonte ainda não está na VRAM quando o menu volta de uma corrida, o que mostrava lixo na GUI) são escritos ao desenhar o menu (forced blank) nos tiles `$40..$5F` do BG1 deslocados 4 linhas para baixo (metade de cima / de baixo, palavra de VRAM `$1400`) e a seed é desenhada em duas linhas de texto com códigos de caractere `$80+2v` / `$81+2v` (o jogo desenha o código c como o tile c-$40).
* **Sem minimapa, faixa de progresso da volta no lugar** (`src/bar.asm`): o bitmap descomprimido do minimapa é apagado (`0F:8232`) e a linha de recorde de volta é movida
  para fora da tela. A barra preta entre as duas visões mostra o progresso ao longo da volta: uma linha de largada vermelha (à esquerda, borda branca), uma linha de chegada (à direita), e
  três pontos pequenos de 4x2 sem borda em faixas fixas: jogador 1 em cima, o líder no meio (escondido enquanto o jogador 1 ou 2 lidera), jogador 2 / carro do
  computador embaixo. x = posição na volta (`$1ED7` / `$1EDA` / `$0219+slot`, escalada pelo comprimento da volta `$0200` para 200 pixels, multiplicação 8x8 +
  divisão 16/8). As cores são a paleta de sprite do próprio carro, cor 9 (clara: o contraste sobre preto é bom para todas as paletas): os jogadores usam as paletas 0 / 1
  como no original, o líder a paleta do registro do seu carro (`word >> 13 & 3`; os bots alternam as paletas 2 e 3 pelo código de registro `$22`/`$32`).
  * Os pontos são os sprites marcadores do próprio jogo; o tile `$7F` (usado só por eles, byte de VRAM `$4FE0`) é redesenhado por `hook_bar` na construção do HUD. `update_map_dots` (`00:8910`) é substituído por um JSL para `hook_mapdots`
    que escreve `$0112/$0114/$0116` = x | y << 8; o renderizador de sprites (`01:808B..80AE`, buffer do jogador 1) já os copia para os sprites. A
    palavra de tile/atributo do líder vai para `$1FB2` (`LDA` alterado em `01:80A0`); o líder é achado com o laço do próprio jogo (maior chave `$021A` entre os 20 carros) e escondido quando é o slot em `$0204` ou `$0206`.
    O buffer do jogador 2 (`01:8590/85A2/85B4`, y + $70) é estacionado fora da tela. **Correção:** as rotinas `00:8966/8A2C` que o texto anterior chamava de
    escritoras de marcadores não são executadas na corrida (contagem de execuções 0); os patches antigos de estacionamento nelas não faziam nada, então os pontos originais eram desenhados
    sobre o canto em branco do minimapa. Elas foram deixadas no lugar para o que quer que as chame.
  * Por que só uma faixa fina: o jogo força blank nas linhas de varredura 109..114 (`INIDISP` $8F em `00:BE88`, restaurado em `00:BEF4`) enquanto faz DMA da paleta
    e da OAM para a segunda visão, e a segunda visão começa na linha 115, então nada pode ser desenhado ali. A parte visível da "barra" é a linha de tiles 13 do BG1
    = linhas 104..108 (cinco linhas); a faixa é feita preta opaca (cobre as últimas linhas da primeira visão), então a barra preta são as
    linhas 104..114. O divisor original (linhas 108..115, em branco em 109..114) e toda a primeira visão ficam intocados. Nada pode ser desenhado em 109..114 (forced blank) e as únicas linhas de divisor visíveis são 108 e 115, então a faixa é desenhada sobre as três últimas linhas da primeira visão sem fundo: traços 4x1 com pontas pretas em faixas nas linhas 106 / 107 / 108, linhas de largada/chegada como um tile de 3 linhas nas linhas 106..108. O contraste sobre uma pista cinza é fraco.
  * As linhas de largada/chegada são um tile 4bpp do BG1 (`$A8`, palavra de VRAM `$A80`; `$A9` = preto sólido) escrito junto com o tilemap do HUD: o hook em `00:CBE2`
    (forced blank) substitui o laço da linha 13 e escreve as linhas 13/14 (`$0DA0..$0DDF`) ele mesmo. O BG1 usa as cores 1 (branco), 2 (preto) e 3 (vermelho) da paleta 3
    que o jogo já carrega. Os tiles `$82..$BF` da área de caracteres do BG1 (VRAM `$1040..$17FF`) estavam sem uso em todas as pistas testadas.
* Smoke test (`tools/rando_smoke.sh seed...`): 40 seeds aleatórias, ~5000 frames cada com um piloto automático, sem travamentos
  (race_frames dentro de 6% do tempo real; as pistas mais longas são um pouco mais lentas). `scripts/rando_pit.lua`: o carro do computador
  para no pit numa pista gerada (estado FFFF..0000, combustível reabastecido até A7FF).
* Pit stop humano (`tools/rando_pit_test.sh "seed alvo"`, `scripts/rando_pit_human.lua`): o carro do jogador é guiado além do objeto de
  entrada do pit (o bit de lado do objeto ligado = *esquerda* = lateral negativa; alvos -9300 estilo 41, -17500 estilo 45,
  +17500 estilo 47) e a sequência do pit roda até o fim com o tanque cheio - verificado em New York, Hiroshima, Rio, Rome.
* O modo 2 jogadores (`TWO=1 scripts/rando_menu.lua`) começa e renderiza as duas visões.
* Ciclo completo (`scripts/rando_loop.lua`): menu -> corrida -> resultados -> ranking -> menu principal -> nova corrida.
* O modo demo/attract (título ocioso) inicia uma corrida demo com a seed que estiver em `7F:F800`.

## Limitações conhecidas / ideias

* As seeds são hex simples, 8 dígitos; o teclado digita alinhado à direita (`AB12` = `0000AB12`).
* Sem minimapa procedural (substituído pela faixa de progresso da volta acima). A pit lane precisa de uma peça de modelo de cenário 20 (tipo 3): verificado visualmente
  em vários ambientes, mas não exaustivamente.
* Equilíbrio de combustível: 8 voltas de uma pista de 46 peças precisam de duas paradas; a IA cuida disso, o jogador tem que usar o pit.
* Armadilha: **o Mesen aplica automaticamente o `<nome da rom>.ips`** encontrado ao lado da ROM. Um `out/rando.ips` velho de um build anterior foi aplicado por cima
  do novo `out/rando.sfc` na GUI (sintoma: Left/Right na linha SEED caía na RAM em `00:2020`); `build_rando.py` agora reescreve
  o IPS a cada build. O `--testRunner` headless o ignora, então o bug só aparecia na GUI.
* O modo 2 jogadores, os níveis de skill e as opções usam o código original (não retestados individualmente).
* A tabela de recordes de volta sem uso `$1FB2..$1FF1` é usada como rascunho de strings pelos hooks do menu.

## Rodada de revisão 2 (2026-10-16)
* Os **estilos de pit** são cópias das combinações originais (modelo, bit de lado, grupo 41/45 = pit à esquerda, 47 = pit à direita, modelos de bandeira e slot,
  estilo de pista do tipo 3, espelhamento). O bit 15 da palavra do pit não é esquerda/direita. `hook_style` (`00:C270`) sobrescreve a palavra de estilo de pista por ambiente
  `00:DEE4` (bits 9-11, bit 15) para que a pit lane seja uma pista de verdade em ambientes cujo estilo próprio do tipo 3 é outro.
* Bandeiras: `13` em b0/b1 das peças pp-2 e pp-1 no lado do pit; chevrons a cada 4 slots de 20 slots antes de uma curva até o fim dela.
  Só a última peça antes da linha é vazia e reta (as curvas podem ir até ela, como na Florence original); sem chevrons a menos de 48 slots do pórtico de largada (um conflito de gráficos os corrompia na seed 12345678).
* **Pórtico de largada**: o scanner `00:E20D` guarda no máximo 8 ids gráficos distintos; tipos de objeto extras das peças de pit/chevron fazem o
  pórtico (grupo `$8002`) desaparecer em alguns ambientes. `tools/gantry_search.py` acha por ambiente tipos de objeto a descartar da fonte
  copiada (tabela `DROP` em trackgen.py / `dropt` em gen.asm). Os 32 ambientes mostram o pórtico (`out/ge_sheet.png`).
* O sorteio de seed mistura os contadores H/V e a seed antiga em 4 rodadas do RNG para que todo dígito mude.

## Pool de gráficos: cenário corrompido (rodada de revisão 4, 2026-10-17)
Relato do usuário: pórtico de largada/chegada corrompido (seeds E3973884, 77675249), gráficos laterais corrompidos perto da chegada / no meio da volta / ao lado das pedras grandes
(3142E2A7, B09742CB, FF6E4160, 82C31DDC) e corrupção "por toda parte" onde aparecem muitas árvores (84373410).

**Causa.** O scanner lateral `00:E20D` roda a cada dois frames e olha os 4 slots 40..43 à frente da câmera. O id gráfico de cada
tipo de objeto (`00:E9BA[type]`; objetos de grupo expandem por `00:E888 / E89A`) é carregado por DMA num **pool de VRAM de 8 KB = 256 unidades de 32 bytes**
(tamanho do id `i` = palavra em `00:E888 + 4 * i`; árvores 34..184 unidades, chevrons 54, bandeiras de pit 58, **o pórtico de largada 254**). A alocação é
*first fit por endereço* numa lista de no máximo 8 blocos; um bloco é liberado quando a câmera passa do último objeto do seu tipo. Um tipo que não cabe
em lugar nenhum é pulado (`00:E3BF`, contado por `scripts/rando_pool_probe.lua`) e, como um slot só é varrido por poucas chamadas, seus objetos são desenhados com
os tiles que por acaso estão na VRAM. Duas coisas quebravam isso nas pistas geradas: (1) o pórtico precisa do pool inteiro, então qualquer objeto a até ~43 slots antes
ou ~41 depois da linha (as peças aleatórias 1 e L-1 têm árvores) não deixa espaço para ele, ou os vizinhos não conseguem carregar; (2) peças embaralhadas + obstáculos + chevrons + árvores
misturam muitos tipos e o pool se fragmenta (uma árvore de 142 unidades precisa de um buraco livre de 142 unidades; o espaço livre total não basta). As pistas originais evitam a maior parte disso à mão
(e ainda falham brevemente em alguns lugares: `tools/pool_model.py --orig`).

**Modelo** (`tools/pool_model.py`): a câmera anda um slot por passo, mesmas regras de lista / first fit / expiração. Ele reproduz o emulador: a seed 3142E2A7 falhou nos carregamentos
nos slots de câmera 709, 1061, 1205 nos dois; E3973884 em 1269 (balde do emulador 1264); a pista original 3 falha em 663-667 (emulador: 656).
`garble` = objetos a até 40 slots da câmera cujos gráficos não estão carregados.

**Correção** (`fit_pool` em trackgen.py, `fit_pool` / `pal_tier` em gen.asm, executados por último em `add_chevrons`, antes da cópia de volta):
1. Só o pórtico a até 44 slots antes e 42 slots depois da linha de chegada (todo outro objeto que não seja de grupo ali é removido).
2. Um conjunto gráfico por pista que cabe no pool *por inteiro* (todos os tipos da volta, de modo que nada precise ser despejado): primeiro os sempre necessários
   (objetos de grupo, placas de curva 8/9, bandeiras de pit 13, entrada do pit 21/58; o id 10 do pórtico não conta, nada mais está perto dele), depois o tipo de obstáculo (marcado em
   o array de palavras `KEEP` por `hz_put`), depois os tipos comuns por quantos objetos os usam (a primeira aparição desempata) enquanto a soma fica <= 224 unidades (256 menos uma margem para a fragmentação do first fit: 224 não deixou corrupção em 1000 seeds do modelo, 232 deixou alguma, 256 cerca de 1 seed em 30 - sempre em volta do pit).
   Objetos de tipos não selecionados são removidos (cerca de 27% dos objetos, tipos inteiros das peças de origem embaralhadas; obstáculos de um tipo que não cabe ao lado de chevrons e gráficos do pit
   são descartados em vez de mostrados corrompidos).
Rascunho: `KEEP` 7F:3400.., contadores 7F:4000..418F, variáveis F89A..F8A9. Custo: cerca de 130 mil ciclos de CPU além dos 740 mil do resto do gerador.

**Resultado.** Modelo, 1000 seeds aleatórias: nenhum slot de câmera corrompido (antes: 40 de 60 seeds, cerca de 130 slots cada; com 256 unidades em vez de 224: 5 de 300 seeds, na área do pit).
Emulador (`scripts/rando_pool_probe.lua`, contador de carregamentos falhos ao longo de uma volta): as sete seeds relatadas foram de 9..141 carregamentos falhos para 0, assim como 7 outras seeds;
as três seeds que a versão de 256 unidades ainda falhava (BC095D63, 5A40D714, 8441E20C) ficam limpas com 224. Uma primeira tentativa, afinar objetos sempre que a soma de tipos distintos numa janela de 79 slots passasse de 256 unidades, não bastou (fragmentação) e foi descartada.

## Preenchimento do cenário lateral (rodada de revisão 3)
Ambientes cuja pista original é esparsa ficavam com as laterais vazias. Depois das placas de curva, `add_chevrons` (os dois geradores) preenche todo
8º slot vazio (a partir do slot 52, nunca a menos de 48 slots do pórtico, nunca nas peças do pit nem na última peça) com uma árvore/arbusto,
alternando os lados, 60 unidades para fora da borda desenhada da pista. Os dois tipos vêm de uma tabela por ambiente (`SCENERY` / `scent`:
os dois tipos de árvore/arbusto mais comuns do ambiente nos dados originais, menos o tipo DROP do ambiente). Os ambientes 2, 8, 9, 14 e alguns outros não têm nenhum
(a arte deles para outros tipos não é carregada - testado no ambiente 14: os tipos 15/24/27 não desenham nada), então continuam tão esparsos quanto os originais.

## Obstáculos e independência da dificuldade (rodada de revisão 3)
* A máscara de objetos agora é sempre `$E000` (objetos de todas as dificuldades): a seed decide a pista, não a configuração de dificuldade.
* As árvores da Black Forest (tipo 31) só são removidas a até 64 slots do pórtico (`DROPW`); todo outro ambiente ainda descarta seus tipos DROP em toda parte (uma janela de 128 slots não bastava para eles).
* `add_hazards` (os dois geradores, depois das placas de curva, antes do preenchimento de cenário; `HAZARD` / `hazt` = tipo de pedra e tipo de barreira por ambiente, tirados dos tipos que o próprio original do ambiente usa):
  **Frequência igualada à das originais** (objetos do campeonato: 18 grupos de objetos na pista / 13 grupos de barreira em 32 pistas = 0,56 / 0,41 por pista; os trechos copiados já dão 0,48 / 0,32, então só um pouco é adicionado: 0,60 / 0,34 em 400 seeds):
  uma pista em 8 ganha um campo de pedras (o padrão da largada original de Los Angeles, 26 slots) no primeiro de: 70 slots antes do início de uma curva fechada (|curve| >= 32), 8 slots depois do fim de uma ladeira íngreme (|slope| >= 64);
  uma pista em 16 ganha um fechamento de faixa única com barreiras (tipo 7, barreiras amarelas onde o ambiente as tem) na primeira reta de 112 slots depois do slot 300:
  o lado direito afunila para dentro, segura, afunila para fora enquanto o esquerdo afunila para dentro, segura, afunila para fora (como Las Vegas no campeonato). Nada a menos de 96 slots do pórtico nem nas peças do pit; placas/pit/objetos de grupo nunca são sobrescritos.
  Pórtico visível nos 32 ambientes (conferido com um script do mesmo tipo de `tools/gantry_search.py`).

## Menu principal e séries de pistas (2026-10-24)
`src/menu.asm` substitui o `main_menu` original (`0F:918B` é um `JML mm_run`; os patches do antigo menu de cinco linhas - rótulo COUNTRY, comprimentos de barra,
`hook_lr`, `hook_menu_draw` - sumiram). Seis linhas, **3 linhas de tiles de distância** (linhas 6, 9 .. 21 dentro da moldura da página 0, então nada precisa rolar e as
setas de "mais opções" para cima/baixo que se planejava não foram necessárias; se uma linha for adicionada depois o passo pode cair para 3 com 7 linhas antes de a moldura encher):

| linha | rótulo | Left/Right | A / Start |
|---|---|---|---|
| 0 | `1 PLAYER` / `2 PLAYERS` | alterna | configuração de jogadores (original `0F:929B`) |
| 1 | `DIFFICULTY` (o menu de skill original, o título também foi renomeado) | - | menu de skill `0F:9652` |
| 2 | `<n> TRACKS` | anel `<infinito> 1 2 .. 99`: Left a partir de `1 TRACK` = infinito, Right a partir de 99 = infinito | - |
| 3 | `SEED xxxxxxxx` | sorteia uma seed nova | teclado hex |
| 4 | `SPEED KPH` / `MPH` | alterna | alterna |
| 5 | `PLAY GAME` | - | começa |

* Os rótulos são a fonte grande do jogo desenhada por `draw_string_to_buffer` no buffer de texto (`mm_text`, strings no banco `$10`); o número de pistas é um campo de dois glifos na coluna de tile 5 (dígitos alinhados à direita, então ` 7`
  e `12`, `mm_dig`) escrito direto no tilemap a partir dos glifos de dígito acima, depois um espaço e `TRACKS` / `TRACK ` na coluna 11; o **sinal de infinito** (dois glifos) preenche o campo. A lista de rótulos da página 0 foi redirecionada (`0D:C738`, tabela b) para uma lista que só
  tem o título `OPTIONS` (na cauda livre do banco `$0F`, `0F:FF17`).
* **SEED só fica ativa com `1 TRACK`.** Caso contrário o rótulo, os 8 dígitos e o seletor ficam cinza: as palavras de tile recebem a paleta 5 (`$1400`; a paleta de BG 1 é a foto!),
  a paleta de texto cinza é escrita na sombra de paleta `$050C`, o seletor (paleta de sprite 7, sombra `$064C`) é trocado entre o original e um cinza
  (`mm_selpal`); o NMI envia a sombra quando `$90 = $004C` (nesse frame ele não faz mais nada, por isso `mm_push_pal` espera um frame). O cursor pode parar na linha cinza,
  A e Left/Right não fazem nada ali.
* O cursor volta à linha do submenu de onde você veio (`MCUR`); depois de `PLAY GAME` ele começa no topo de novo.
* Estado (banco `$7F`, `MAGIC2 $5AA5` o protege, inicializado por `menu_init` - separado do magic da seed porque os scripts de teste mexem no magic da seed): `TRKS $FA00`
  (0 = infinito, 1 = uma corrida = padrão), `DONE $FA02`, `PODIUM $FA04`, `MCUR $FA06`, `CUR $FA08`, `SELG $FA0A`, pontuações `TOTLO $FA20..` / `TOTHI $FA40..` (20 carros).

* **Corrida única (`1 TRACK`): sem ranking mundial.** `0F:8457` -> `hook_rank` (faz o `unpad_names` ele mesmo, pois destrói A): com `TRKS == 1` a rolagem até o ranking é pulada e a tela de resultados vai direto ao fade out (`0F:8484`) e ao menu principal; as séries ainda mostram o ranking.

### Séries (TRKS != 1)
* `PLAY GAME` (`hook_play`): pontuações zeradas, **uma seed aleatória nova** para cada corrida (SEED está inativa), `DONE = 0`.
* Depois da tela de ranking (`hook_afterresults`, `0F:8487`): `DONE++`; infinito ou `DONE < TRKS` -> `roll_seed`, `rando_env`, o estado de scroll/fonte do caminho original
  de "corrida passada", `JMP 0F:818E` = tela de splash da próxima pista e a corrida (o original segue o mesmo caminho depois de uma corrida passada; o grid da próxima corrida segue
  as colocações `$1F00/$1F02`, como no campeonato). `TRKS == 1` -> volta ao menu principal como antes (título pulado uma vez).
* **As pontuações continuam somando, como valores de 16 bits** (o original tem um byte por carro, que dá a volta depois de 12 vitórias e mostra dois dígitos): `0F:8889` (a soma na tabela
  de resultados) -> `hook_addpts`, o bubble sort do ranking mundial (`0F:896F`) -> `hook_cmp`, `draw_points_column` (`0F:8B4E`) -> `hook_ptscol` (até 5 dígitos, 0..65535, **alinhado à esquerda** a partir da
  coluna 17, espaços depois de números curtos; `HIGH=1` em scripts/rando_series.lua forja pontuações grandes para conferir). Os carros 0 e 1 são os dois humanos (ou o jogador 1 e o carro COMPUTER em 1P), 2..19 os bots; `$1F4E` não é mais usado.
* **Sem game over.** Os testes de qualificação (top 5 por corrida, top 3 por país), o apagamento de pontos e o retorno ao título/KEMCO do original não são mais alcançáveis
  (docs/13 os lista); nada no randomizer encerra uma sessão por causa de uma colocação ruim.
* **Pódio** (depois da última corrida de uma série finita, `podium_start`): a tela de cena de docs/13 seção 5 é reaproveitada - parede quadriculada `TG`, um piloto por humano
  (comemorando se um humano está no top 3 da classificação, senão o triste) e uma etiqueta `PLAYER n <place>` de `build_finish_order` (colocação = posição na
  série, `$1F62`); 2P mostra os dois jogadores, 1P só o humano (o carro COMPUTER não tem cena). A mensagem é nossa (`THANK YOU FOR PLAYING!` para os dois pilotos; a fonte não tem `!`, então `pod_bang` envia um tile 8x8 desenhado (`font/podium/exclam.bmp`, embutido em `pb_gfx` por `tools/bigfont.py`) para a palavra de VRAM `$1600` e o escreve atrás do texto), com hooks em `0F:8584` / `0F:8592`; o bloco de senha (`0F:85F2`) é pulado; o pódio toca a música da cena original "completed Top Gear" (`play_music` 6, via `t_music`, as duas cenas) e `hook_podend` chama `play_music` 0 (envia e reinicia a música do título / menu, como o original faz no caminho para o título) antes de `jml 0F:815A` - sem isso o título ficava mudo (conferido registrando a porta 0 da APU: `07` no pódio, `00`,`01` na volta); o scroll do BG1 precisa ser
  posto em `$0010` antes (o ranking rola a camada para fora: tela preta sem isso). Depois de apertar uma tecla `hook_podend` (`0F:8669`) vai ao menu principal (título pulado uma vez).
* Séries infinitas nunca chegam ao pódio; o ranking mundial depois de cada corrida é o placar.

Testes: `scripts/rando_series.lua` (variável `TRACKS` = 0 infinito / n, `TWO=1`, `PLACES="0,3,.."`, `SHOTS`): configura o menu pelas teclas, força o fim de toda corrida como
`race_end_force.lua` e imprime `results_flow / har_next / podium_start / hook_podend / mm_run` com números de frame (verificado: 1 pista -> menu, 2 e 8 pistas -> pódio, 0 -> 9
corridas sem pódio, pódio 2P com os dois pilotos, pontuações de 3 dígitos no ranking). Os scripts que navegam o menu foram atualizados (SEED é a linha 3, PLAY GAME a linha 5;
`common.lua` adiciona o Down extra quando `TG_ROM` contém `rando`).

## Sem pit em corridas curtas
O carro vermelho faz 4,75 km com um tanque na 5ª (docs/12, o carro mais sedento). Uma peça é 15/256 km, então uma corrida tem `L * laps * 15/256` km. Quando isso é menos de 90 % de 4,75 km (`L * laps <= 72`) a pista fica sem pit: sem objeto de entrada, sem bandeiras, sem peça de modelo 20, e a palavra do pit é `$7FFF` (posição `$FFFE`, nunca alcançada, então sem seta de pit e sem corredor de pit da IA). Mesmos sorteios de RNG de antes, então o resto da pista fica igual. `NOPIT_PIECES` em `tools/trackgen.py`, `pn_m` em `pit_setup` (`src/gen.asm`). Só ~1 % das seeds se qualificam (3 voltas de 24 peças é a única combinação, já que a corrida mais curta tem 4,2 km); p. ex. 000B99A1, 00150673 (verificado no smoke test, 400 seeds batem com a referência Python).

**Atualização:** o playtest mostrou o carro vermelho terminando 3 voltas de 46 peças (138 peças) com um tanque, então o alcance foi tomado como 130 peças e o limite sem pit é 90 % disso: `L * laps <= 117` (`NOPIT_PIECES`, `cmp #118`). Cerca de 16 % das seeds agora não têm pit (p. ex. 0004B66A, 0005CCD1). O valor de 72 peças acima foi substituído.

**Atualização 2:** o limite foi ajustado à mão para `L * laps <= 129` (`NOPIT_PIECES`, `cmp #130`): sem pit em corridas de 129 peças ou menos. Substitui o 117 acima.

**Marcador do pit na faixa de voltas:** `hook_bar` põe o tile `$AA` do BG1 (VRAM `$0AA0`: caixa preta com um traço branco nas três linhas da faixa) na linha 13 na coluna de tile do pit, `(24 + pit position * 200 / lap length) / 8`, usando a palavra do pit do gerador `$7FF83E` (`$1EF0` ainda não está definido quando o HUD é construído). Pistas sem pit não têm marcador. Conferido por screenshot: seed 00163BC9 (pit na coluna 17), 0004B66A (nenhum).
**Deslocamento:** o marcador é desenhado 2 peças (2048 unidades) depois da palavra do pit, isto é, na entrada e não no começo das bandeiras (seed 00163BC9: coluna 17 -> 18).

## Volta perdida numa colisão na linha de chegada (bug do jogo original, corrigido no randomizer)
Uma batida entre carros coloca o carro humano em "posição do outro carro - 8" (`05:E55C`, `E577` para o humano 1; `E73B`, `E756` para o jogador 2 / carro do computador). Se o outro carro já está além da linha (posição 0..7, byte de volta +1) e o humano está a poucas unidades antes dela, o resultado é negativo (>= `$FC00`): a verificação de volta em `05:E789` lê isso como "ainda antes da linha de largada" e tira uma volta (`$1E76`, byte de volta `+9`), e o cruzamento de verdade um instante depois só a devolve, então a volta nunca conta (na última volta: a corrida não termina). Reproduzido na ROM original e no randomizer com `scripts/finish_collide.lua` (humano em linha-3/-6, carro mais lento em 0/3/6 à frente na lista: volta 0 em vez de 1; o carro atrás na lista está bem).
Correção (`src/hooks.asm`, `hook_hit1/2` + `hit_pos` em `13:8000`): a nova posição é calculada na volta do próprio humano: a diferença de byte de volta +1 soma o comprimento da pista, -1 o subtrai, e o resultado é limitado a `0..length-1`. O estado de grid da volta 1 (posição >= `$FC00`) mantém o comportamento original. Depois da correção as mesmas configurações dão volta 1 e a corrida continua normalmente. O caso oposto (humano além da linha, outro carro não) não pode colidir: o teste de sobreposição compara posições brutas.

**Regressão encontrada na BETA 0.3 (relato de um amigo: bater num bot perto do pit jogava o carro além da linha de chegada e iniciava a próxima volta):** `hit_pos` tratava toda diferença de byte de volta de +1 como "o outro carro já cruzou a linha" e somava o comprimento da pista, então bater num bot que tinha dado uma volta no humano (mesmo ponto da pista, byte de volta +1) limitava o carro à última unidade da volta e o cruzamento da linha contava uma volta (seed 12345678, humano 7000 / bot 7004 volta+1: pos 262, volta 1; a ROM original mantém pos 7505, volta 0). Agora o ajuste só se aplica perto da linha: volta+1 quando o outro carro está na posição < `$0400` (ou negativa), volta-1 quando está a até `$0408` do fim. Os casos de linha de `finish_collide.lua` ainda dão volta 1; os casos de carro dobrado dão o resultado simples.

**Segunda regressão (BETA 0.4, relato: o P2 em single player bateu num retardatário perto da linha e foi posto na linha, uma volta atrás):** a primeira correção ainda só olhava o *outro* carro. Os dois carros antes da linha com o retardatário uma volta atrás (byte de volta -1) tomavam o ramo "humano já além, outro não", subtraíam o comprimento da pista e limitavam a 0: o carro perdia todo o seu progresso da volta. `hit_pos` (compartilhado pelo humano 1 e pelo P2/carro do computador) agora exige que o próprio carro atingido esteja do lado certo da linha: volta +1 só se nossa posição está nos últimos `$0400` ou já passou do comprimento (a virada em `05:E789` vem depois no mesmo tick, no jogo vimos `$B80C` contra comprimento `$B800`), volta -1 só se estamos nos primeiros `$0400`. Caso contrário vale o simples "outro - 8", limitado a 0 para que um carro logo depois da linha nunca seja posto atrás dela (isso também corrige o defeito original para "ele deu uma volta em nós logo depois da linha"). `scripts/hitpos_unit.lua` chama `hook_hit1/2` diretamente dentro de uma corrida (WHO=1|2, OWN, OPOS, OLAP; posições negativas são distâncias antes da linha) e imprime a posição devolvida; `scripts/finish_collide.lua` confere o humano de ponta a ponta (47100/3/+1, 47098/0/+1, 47090/6/+1: volta 1; 7000/7004/+1: simples).
