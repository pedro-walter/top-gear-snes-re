# O truque acelerador + freio nas curvas (só jogador 1)

Segurar **acelerar (X) e freio (Y) juntos** permite que o jogador 1 faça uma curva muito mais fechada / rápida sem derrapar para fora.
Funciona por causa de como o limite de aderência da direção é escolhido na atualização do jogador 1 (`05:D4A6..D575`), e existe só para o jogador 1.

## Mecanismo
Por tick de jogo (`$1E90` = delta de frames δ, 1..7):

| variável | significado |
|---|---|
| `$1E8E` | distância à frente neste tick = `(speed/2)*δ` (`05:D686..D6BA`, saturando) |
| `$1E7E` | estado da direção; seu byte alto é o "ângulo de direção" (Left/Right somam `$9AC3[δ]` por tick, máx. `0x51FF`) |
| `$1E94` / `$1E92` | **limite do deslocamento lateral que a direção pode produzir neste tick** (+ / −) |
| `$1E8A` | posição lateral (0 = centro da pista) |

Deslocamento da direção `D = $1E8E * hi($1E7E) / 256` (`05:D995..D9AA`). Se `D` excede o limite (`CMP $1E94`, `05:D9AC`) ele é cortado no limite,
o bit 0 de `$1EF5` é ligado e o estado da direção volta atrás (`05:D9B1..D9C7`), então a direção não consegue crescer mais.
A curva então empurra o carro para fora com `P = $1E8E * c / 256` (`c = $7E4C00[pos>>5]`, `05:DA1A..DA79`), **sem limite**.

O limite é escolhido entre três escadas no banco 00 (índice = `(δ-1)*2 + $1EE8`, `$1EE8` = carro*16; 4 carros linhas positivas, 4 linhas negativas):

| situação | tabelas | limite |
|---|---|---|
| sem acelerar (roda livre) | `$97DF` / `$981F` | **640·δ** (todos os carros) |
| acelerando com combustível (máscara `$1F76` X pressionado, `05:D4B0..D4D7`) | `$985F` / `$989F` | **384·δ** (carro 1 = 416·δ; os outros carros 384) |
| acelerando **e freando** (máscara `$1F78` Y pressionado, só P1, `05:D55F..D578`) | `$98DF` / `$991F` | **640·δ** de novo |

Ou seja, o acelerador custa 40 % da aderência, e segurar o freio junto devolve toda a aderência de roda livre enquanto o motor continua puxando.
O código de freio do jogador 2 (`05:DDC5..DE49`, máscara `$1F95`) só liga a flag da luz de freio e desacelera o carro; nunca carrega as tabelas `$98DF/$991F`.
Frear liga o bit 15 de `$0108` (paleta da luz de freio, `00:BC36..BC6D`). A própria frenagem reduz o carro a cada tick em
`(|top-speed| + (0x800 se speed>top)) * 11 / 256` (`05:D57C..D5E4`).

## Condição de curva (verificada no emulador)
Com o δ se cancelando, a curva pode ser mantida enquanto a direção limitada ainda vence o empurrão:

`384·δ ≥ (speed·δ/2)·c/256  ⇔  speed·|c| ≤ 196608`  (acelerando)
`640·δ ...                  ⇔  speed·|c| ≤ 327680`  (acelerar+frear, ou roda livre)

Em km/h (`km/h = speed*24/1024`): km/h máx. ≈ **4608/|c|** acelerando, **7680/|c|** com freio (ou roda livre).

| valor da curva c | acelerando | acelerar + frear |
|---|---|---|
| 16 | 288 km/h | 480 |
| 24 | 192 | 320 |
| 32 | 144 | 240 |
| 40 | 115 | 192 |

Medido com `scripts/brake_corner.lua` (carro estacionado dentro de uma curva constante, velocidade forçada, direção mantida para a curva; a deriva líquida para fora cruza o zero em):
c=24: só X 7900 (185 km/h), X+Y 13100 (307 km/h), roda livre 12900; c=32: só X 5900 (138 km/h), X+Y 9900 (232 km/h), roda livre 9900 (previsão 6144 / 10240 / 10240 unidades).
A observação do usuário com o carro vermelho (cerca de 243 km/h) combina, portanto, com curvas de c ≲ 31, e 230 km/h na 4ª marcha combina com c ≲ 33.

Maior |c| por pista (`tools/tracks.py`, stream de curvas): a maioria das pistas tem pico em 32, mas 7 Rain Forest, 8 Tokyo, 12 Munich, 18 Helsinki, 28 London, 29 Sheffield e 30 Loch Ness chegam a 40
(só ≤192 km/h com o truque); 2 New York, 5 Machu Picchu, 14 Black Forest e 25 Rome têm pico em 24, 3 San Francisco, 6 Chichen Itza e 31 Stonehenge em 16.

## Marchas e carros
O limite não depende da marcha; o carro só o muda pela velocidade que atinge (e pelo limite de 416 do carro 1 só acelerando). A marcha importa porque segurar o freio reduz o carro a cada tick
numa quantia que depende do `top` da marcha (`$1EE2`): a desaceleração é `(top-speed)*11/256` abaixo do top e `(speed-top+2048)*11/256` acima dele, ou seja, muito maior quando a velocidade máxima da marcha está abaixo da
velocidade atual. Ficar na marcha cuja velocidade máxima está logo acima da velocidade atual (a 4ª do carro vermelho é mais rápida que a 5ª sem nitro) portanto perde menos velocidade. Ainda não medido com precisão:
num teste com marcha forçada (`scripts/brake_eq.lua`, pista plana) a velocidade com acelerar+frear caiu para ~3600 na marcha 1 e para 0 nas marchas 2-5 em 400 frames, então o truque é uma técnica de curto prazo.

## Reproduzir
`tools/mesen.sh scripts/brake_corner.lua` (escreve `out/brake_corner.txt`), `scripts/brake_probe.lua` (máscaras de botão e tabelas), `scripts/brake_eq.lua`.
Máscaras: `$1F76`=0x0040 X acelerar, `$1F78`=0x4000 Y freio, `$1F7A/7C/7E` R/L/A (subir/descer marcha/nitro), `$1F80`=0x0200 Left, `$1F82`=0x0100 Right.

## Descida facilita (observação do usuário, Loch Ness)
A ladeira só entra na atualização de velocidade (`05:D400`: `speed += -slope/16`, subida dividida por 4), nunca no limite da direção nem no empurrão. O freio tira velocidade a cada tick, então uma
curva em descida devolve velocidade e o carro fica acima/perto da velocidade necessária enquanto você segura o truque (e a curva é mantida pelo tempo que você quiser).
Teste (`scripts/brake_slope.lua`, pista 30 Loch Ness, carro estacionado no progresso 15040 onde o stream de curvas é c=+32 e a ladeira é -600, ou seja +37 de velocidade/tick; velocidade forçada a 9000, 240 frames, direção mantida para dentro da curva):

| caso | velocidade ao longo de 240 frames (a cada 30 frames) |
|---|---|
| descida, marcha 3, só acelerar | 5417 → 8674 (ainda subindo) |
| descida, marcha 3, acelerar + frear | 8572 8553 8537 8519 8588 8593 8563 8545 (**mantida**, empurrão para fora negativo = curva mantida) |
| plano (local c=40), marcha 3, acelerar + frear | 8585 → 7732 (caindo ~30/30 frames) |
| plano, marchas 4/5, acelerar + frear | colapso para ~0-1600 |
| descida, marchas 4/5, acelerar + frear | mantém 9100-9400 por ~90 frames, depois cai (não explicado; pode ser batida num objeto lateral na posição estacionada) |

Melhor curva de Loch Ness: progresso 14528-17184 (palavras de stream 454-537), curva +32 (empurrão para a direita/positivo; esterce para a esquerda para manter), ladeira -124..-600 (média -536), cerca de 2650 unidades de comprimento. Também 10432-14112 (c=-32, ladeira -750..0, média -253).
(As posições estacionadas "plano"/"subida" que escolhi tinham ladeira 0, então não há medição real de subida.)
