## Dados da pista (loader `sub_00BF44`, chamado por `sub_00BF14` = load_track; as tabelas ficam no banco 0C, número da pista `$1F06`, 16 pistas)
Descritor da pista = 10 bytes em `0C:8402 + 10*t`: w0 = número de peças de 1024 unidades (6 bits baixos; comprimento = peças*1024), depois 4 ponteiros (banco 0C):
`slope stream`, `curve stream`, `scenery stream`, `object stream`. O loader os expande na WRAM:

| WRAM | construído a partir de | significado |
|---|---|---|
| `$7E4000` | slope stream | **ladeiras**: uma palavra com sinal a cada 32 unidades de posição. Byte com sinal por peça -> tabela de ponteiros `0C:85D3`, cada modelo = 32 palavras; byte negativo = modelo negado. 0 plano; +-50..1000, com rampas de entrada e saída. Positivo = subida (desacelera, fator 1/64 por tick), negativo = descida (acelera, fator 1/16 por tick!). Verificado exatamente contra a memória na pista 0. |
| `$7E4C00` | curve stream | **curvas**: mesmo formato, tabela de ponteiros `0C:8591`. |valor| máx. 16..40 por palavra. Usado em 05:E9AF/F358 como `$7E4C08[pos>>4]` (8 palavras = 256 unidades à frente) x velocidade = empurrão centrífugo na posição lateral. Verificado exatamente na pista 0. |
| `$7E5800` | scenery stream | 64 bytes por peça copiados da tabela de ponteiros `0C:8545`; palavras (bit15 + índice) consultam o formato da borda da pista via `00:9B3F`; usado por `sub_00A8E1` para construir `$7E7000` |
| `$7E6400` | object stream | objetos/placas laterais/entrada do pit. Registros de 5 bytes expandidos pela tabela em `0C:8615`: uma palavra por 32 unidades; 7 bits altos = tipo (0x74xx = **entrada do pit**); os objetos só existem nas dificuldades permitidas pela máscara de `0C:8541[$1F10]&0xE000` |
| `$7E7000` | calculado (00:A8E1.. A9xx, AA09/AA6A) | corredor da pista: dois bytes com sinal por 32 unidades = limite esquerdo/direito; `$7E7002` = próxima entrada |
| `$7E3E00` | fluxo de paleta (`0E`/`E124[t]`, decodificado com 00:EA8E/EA9B) | degradê de cor de céu/fundo por pista |
Constantes por pista: voltas `00:DEA4[t]` (word), info do pit `00:DF24[t]` (bit15 -> lado, `&0x7FFF*2` -> `$1EF0` = posição de início da pit lane), tabelas de borda da pit lane `00:E166/E198` (indexadas por distância/16 a partir de `$1EF0`),
paleta de fundo `00:E0E4[t]`, gráficos `00:DFA4[t]`, offsets de velocidade dos bots `00:DDE4`.
`tools/tracks.py` reimplementa o loader e verifica as tabelas de slope+curve contra um dump da WRAM (23/23 peças idênticas na pista 0). As 16 pistas são dados simples na ROM (banco 0C),
então uma pista nova = streams novos + descritor (projetar pistas é viável; a incógnita que resta é a tabela de formato de borda de 00:A8E1 em `00:9B3F` e os registros de objetos).


## Streams de cenário e de objetos (sessão 4) — `tools/objects.py`, `tools/objmap.py`, `out/objects.png`, `out/objects_all.csv`
Os dois loaders (00:C042–C0EF) foram portados e **verificados exatamente contra a WRAM** (pista 0: cenário 736/736 palavras, objetos 736/736 nas dificuldades 0/1; a dificuldade 2 adiciona 20 palavras).
### Cenário ($7E5800, uma palavra por 32 unidades)
* Stream = um byte por peça de 1024 unidades (elemento k = byte em stream+k, lido como word, só o byte baixo é usado) -> índice de modelo `(b<<1)&0x1FF` -> tabela de ponteiros `0C:8545` -> 32 palavras.
* Palavra = `0x8000 | block<<4 | phase<<1`, fase 0..7 repete a..h ao longo de uma peça, block = 0..26. A lógica só usa `Y = 00:9B3F[word&0x7FFF]` = **tipo de pista 0..3** (offset de registro 0/4/8/12):
  blocos 0,4,7,8,12,15,18..25,27.. -> tipo 0; 1,6,9,13,16,28 -> 1; 2,5,14,17,29 -> 2; 3,10,11,26 -> 3. Blocos do mesmo tipo são indistinguíveis para física/corredor (provavelmente só gráficos; o papel do bloco 4 vs 0 é desconhecido).
* Tipo de pista t -> palavra por pista `00:DEE4[track]`: bits 0-2 = estilo do tipo 0, bits 3-5 tipo 1, 6-8 tipo 2, 9-11 tipo 3 (bit 15 = variante de tile espelhada, `$E0`). Um estilo (0..7) indexa tabelas em 00:C552 (gráficos de borda esquerda/direita da pista, DMA de 0x300 bytes cada para a VRAM $1000/$1400, $1180/$1580, ...),
  00:C572 (**limite da parede** $017B+4t/$017D+4t = `-10229/+10229` estreita, `18636`, `26424` larga; estilo 7 = 13301) e 00:C592 (borda desenhada $013F+4t/$0141+4t = -80/80, -138/138, -192/192; estilo 7 = 102). Estilos 0..6 = combinações (largura esquerda, largura direita): esquerda em {estreita, mais larga, a mais larga} x direita em {estreita, mais larga, a mais larga}.
  05:D7FC limita a lateral do jogador `$1E8A` ao limite da parede do tipo de pista sob o carro (quicando, `sub_05F6FA`); 00:A8E1 constrói o corredor `$7E7000`.
* No mapa `out/objects.png` as cores de fundo são os 4 tipos de pista por pista: a **entrada do pit fica sempre onde o tipo de pista muda para um trecho alargado** (pit lane).
### Objetos ($7E6400, uma palavra por 32 unidades, só o primeiro objeto de um slot; 0 = vazio)
* Registro do stream = 5 bytes por 512 unidades: w0 (2 B), w1 (2 B), depois o byte b2 em +4. w0<<1 e w1<<1 dão cada um dois "modelos" de 16 bits D0..D3 ($ED/$EF/$F1/$F3: byte baixo<<8 e byte alto<<8). b2*32 seleciona um de 16 padrões de palavras em `0C:8615`.
* Palavra de padrão e: 0 = vazio; bits 13-15 = máscara de dificuldade (AND com `0C:8541[$1F10]&0xE000`; o objeto só existe nessas dificuldades); bits 9-10 escolhem D0..D3; os 9 bits baixos e&0x1FF são preenchidos:
  se o bit15 de D = 0 -> resultado = D | (e & 0x1FF) (objeto comum); se o bit15 de D = 1 -> resultado = (D&0xC000) | ((D&0x3E00)>>8) (um "grupo"/especial; os bits baixos de e são ignorados).
* **Palavra de objeto comum** (bit15=0): bits 9-14 = **tipo** (0..63, id gráfico de `00:E9BA[type*2]`, tratador de colisão `05:F5C3[type*2]`), bit 8 = lado (1 = lateral negativa), bits 0-7 = distância lateral x128 em unidades `$1E8A`
  (limites de parede 10229..26424 = 80..206). Também alimenta o construtor de corredor (00:A8E1: objetos encolhem o corredor em +-0x40 ao redor de si) para que os carros não atravessem objetos e o carro do computador desvie deles.
  O teste de colisão 05:D6F4+ olha os 32 slots (1024 unidades) antes do carro: diferença lateral vs limiares `05:A05F/A0DF[type]`; os tratadores F6B3 (REV: velocidade -> -min(speed/2,1600)), F6F5 (EDGE: metade da velocidade, chute em direção ao centro da pista) e F6F1 (SIDE: metade, chute para longe do objeto) ligam o bit 0x80 de `$1EF5` (som de batida); detalhes medidos em docs/03 "Colisões".
  Tipos usados nas 16 pistas: 5-15, 21-24, 26-29, 31, 37, 38, 40-43, 46, 54-56, 58; os mais comuns são 8, 9, 15 (objetos laterais tipo cacto), 24, 27, 31, 41. **Tipo 0x3A (palavra do stream 0x74xx/0x75xx) = entrada do pit** (lado do bit 8, lateral p. ex. 0x3C=60, 0x7C=124).
* **Palavra de grupo** (bit15=1): `(w&0x3FFE)` indexa `00:E888` -> lista em `00:E89A` de sprites desenhados juntos. Usada só para: id 1 (`0x8002`) na posição 0 e no fim de toda pista = **pórtico de largada/chegada**, e na pista 4 a série 0xC004..0xC00E em torno das posições 5150-5550 (estrutura tipo túnel/ponte, as linhas verdes em `out/objects.png`). Objetos de grupo colidem via `sub_05ED3A` (comportamento REV).
* Tabela de sprites: o renderizador (00:E286.., E5B7..) varre 4 palavras à frente a partir de `camera+0x50` em busca de objetos, monta um pequeno cache de ids de sprite (`$1BC6`..) e faz DMA de frames escalados; dados por id em `00:E882+4*id` (palavras usadas: tamanhos/contagens, `$E886` = número de frames). O formato exato do frame não foi decodificado.
### Como criar uma pista
Use o descritor `0C:8402+10t` (w0 peças, 4 ponteiros de stream) + `00:DEE4[t]` (estilos de pista) + voltas `00:DEA4`, pit `00:DF24`, tabelas de paleta/gráficos; cenário = um byte de modelo por peça; objetos = registros de 5 bytes. Tudo isso são dados simples (veja `tools/objects.py` para a regra exata de expansão).
Desconhecido: o papel dos blocos de cenário dentro de um tipo, a semântica da tabela de limiares (os valores de 05:A05F parecem distâncias de 16 bits em unidades `$1E8A/2`, 0x1000..), o formato de frame do DMA de sprites.

## CORREÇÃO (sessão 4): são **32 pistas**, não 16
A tabela de descritores `0C:8402+10*t` é válida para t = 0..31 (a entrada 32 já é outro dado); `00:DEA4` (voltas), `00:DEE4` (estilos de pista), `00:DF24` (pit) também têm 32 entradas. As afirmações anteriores de "16 pistas" neste arquivo referem-se só às pistas 0-15.
* Voltas t=0..31: 3,3,3,6,6,4,6,3,7,5,3,6,7,3,6,8, 3,3,3,3,3,7,6,3,3,6,3,3,8,3,3,4.
* Pistas com pit stop (00:DF24 != FFFF): 3,4,6,8,9,11,12,14,15,21,22,25,28 (então a lista anterior "sem pit: 0,1,2,5,7,10,13" vale só para as pistas 0-15; 16-20,23,24,26,27,29-31 também não têm).
* `tools/track_atlas.py 0` -> `out/tracks.png` (pistas 0-15), `tools/track_atlas.py 1` -> `out/tracks_16_31.png`; `tools/objmap.py` agora cobre as 32 -> `out/objects.png`.
* Estrutura provável: 8 países x 4 pistas (o mapeamento número do menu -> `$1F06` ainda não foi decodificado; pista 4 = túnel perto da largada, confirmado pelo usuário).
* Tabelas por pista indexadas pela pista (offsets dos bots `00:DDE4[track*6+diff*2]`, gráficos `00:DFA4`, paleta `00:E0E4`, céu `E124`) presumivelmente também têm 32 entradas; verifique antes de usar pistas >= 16.

## Tabelas por pista verificadas nas 32 pistas (sessão 4)
Método: alterar `$1F06` (pista) nos frames 2000-2400 no emulador headless (`scripts/dump_track.lua`, TRACK=n), despejar `$7E4000-$7E71FF` na largada e comparar com os loaders em Python nas pistas 16, 21, 25, 31:
os streams de ladeira, curva, cenário e objetos são **idênticos palavra por palavra** (p. ex. t=16: 1216/1216, 1216/1216, 1248/1248, 1248/1248). Comprimento `$0200`, voltas `$1E56` e início do pit `$1EF0` também concordam com as tabelas (t=21: voltas 7, `$1EF0`=0x7600 = 2*(0xBB00&0x7FFF)).
Todas as tabelas abaixo têm 32 entradas, guardadas em sequência (64 bytes cada, 00:DDE4 tem 6 bytes por pista):
| tabela | conteúdo |
|---|---|
| `00:DDE4` (6 B/pista) | offsets de velocidade dos bots por dificuldade: pistas 0-15 p. ex. t0 {0,80,160}, t1 {128,416,704}; pistas 16-31 todas começam em 288 (p. ex. t18 {288,672,1056}, t22 {288,224,160} -> essa pista fica *mais fácil* com a dificuldade, t20 {288,320,352}) |
| `00:DEA4` voltas, `00:DEE4` estilos de pista, `00:DF24` pit | verificados, veja acima |
| `00:DF64` | ponteiro (banco 5 para t<16, banco 6 para t>=16: `ROL` do carry de CPX #$20, 00:C20D) para um stream comprimido, descompactado por 00:EA8E/EA9B na VRAM $6800 = gráficos de fundo/horizonte por pista |
| `00:DFA4` | blocos gráficos de 64 bytes (0xC849 + 0x40*t) copiados para a VRAM $1AE0/$1EE0 |
| `00:DFE4` | offset de paleta 0x20*t (upload para a CGRAM de 05:8A5A / 8E5A, 00:BAFB / BB6B) |
| `00:E024`, `00:E064` | ponteiros por pista copiados para `$0106` (todos 0x84F0 / 0x8664, exceto as pistas 2 (0x8400) e 9 (0x8826/0x87D8): scripts diferentes de som/música/fundo?) |
| `00:E0A4` | cor opcional por pista (negativo = nenhuma; usado em 00:CDB0) |
| `00:E0E4` | palavras de paleta de fundo, `00:E124` offsets do stream de degradê do céu (0x0, 0xB0, 0x1F8, ...) |
| `0D:C6D6[t]` | voltas de novo (bytes), `0D:C6F6[t]` = número de peças de 1024 unidades (22, 41, 42, ...), ambos usados pela tela de menu/seleção de pista |
* `$1F06 & 0x1C` = **país** (0..7; pista = país*4 + 0..3); um caminho de pista aleatória mascara `$1FFC & 0x1F`.
* **Senhas** (menu 0F:85F2): mostradas para os países 1..7 (do 2º ao 8º), 8 caracteres, tabela `0D:C513` = 7 por dificuldade x 3: amateur MOONBATH, GEARBOX, CAR PARK, ROAD HOG, EMULATOR, ANALYSER, HORIZONS; professional FOUR MEG, LEGEND, THEWORLD, LETSRACE, ALCHEMY, A LOOPER, SEASONAL; championship EDUCATED, OILCLOTH, WRECKAGE, CARACOLE, EPYLLION, GLUCAGON, KEELSON
  (índice = (country-1)*8 + difficulty*0x38; país 1 = pistas 4-7 etc.; o país 0 não precisa).
