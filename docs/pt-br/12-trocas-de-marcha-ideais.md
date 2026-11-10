# Velocidades ideais de troca de marcha por carro (pista plana, tanque cheio)

Objetivo: atingir a velocidade máxima o mais cedo possível com o câmbio manual. `python3 -I tools/gear_opt.py` resolve isso exatamente com programação dinâmica sobre o modelo de velocidade do próprio jogo (`tools/physics.py`, que bate com o jogo na unidade, veja docs/02). O mapa de velocidade de um tick é monotônico na velocidade para toda marcha, então guardar a maior velocidade por marcha a cada tick é ótimo. O câmbio manual muda uma marcha por tick (cerca de 25 ms), como o código real (`05:D3B0`); a troca em si não custa nada nessa rotina. As marchas são numeradas 1ª..5ª (índice 0..4 no jogo). As velocidades são km/h no HUD (unidades / 41,7). Tempo: 2 ticks de física a cada 3 frames.

Premissas: pista plana, tanque cheio (a queima de combustível eleva um pouco a velocidade máxima, até +670 unidades com o tanque vazio), sem direção, colisões nem fora da pista, acelerador mantido. Ainda não jogado no jogo.

## Sem nitro

| carro (índice) | 1ª → 3ª (a 2ª é usada por um tick) | 3ª → 4ª | 4ª → 5ª | melhor velocidade máxima | tempo até 99 % |
|---|---|---|---|---|---|
| vermelho (0) | ~80 (janela 70..84) | ~127 (janela 98..144) | **nunca** (a 4ª é mais rápida: 224 vs 212) | 224 | 11,2 s |
| branco (1) | ~38 (até 57) | ~92 (em qualquer ponto até ~135) | ~166 (janela 150..174) | 201 | 5,0 s |
| roxo (2) | ~63 (41..73) | ~167 (150..175) | ~189 (176..195, ganho minúsculo) | 212 | 9,3 s |
| azul (3) | ~52 (11..64) | ~186 (180..189) | ~195 (185..198, ganho minúsculo) | 209 | 6,8 s |

As janelas são as velocidades de cada troca isolada que custam no máximo um tick em relação ao ótimo. O câmbio automático perde de 0,2 s (branco) a 1,4 s (azul) no caminho e nunca atinge a velocidade máxima do carro vermelho (sobe para a 5ª a 211 km/h).

## Com nitro (disparado na largada; dura 320 frames = 5,3 s)

| carro | 1ª → 3ª | 3ª → 5ª (4ª por um único tick) | velocidade quando o nitro acaba | câmbio auto |
|---|---|---|---|---|
| vermelho (0) | ~57 | ~162 (janela até 227) | 360 | 359 |
| branco (1) | ~68 | ~253 (234..265) | 318 | 293 |
| roxo (2) | ~57 | ~229 (191..248) | 333 | 322 |
| azul (3) | ~62 | ~254 (242..262) | 293 | 258 |

Portanto o velho truque "3ª marcha + nitro" (docs/02) está certo, e o ponto exato de troca é 160 / 230 / 253 / 254 km/h (vermelho / roxo / branco / azul). Sem câmbio manual o automático desperdiça até 35 km/h no fim do nitro nos carros branco e azul. Quando o nitro é disparado importa pouco para o tempo até o pico: disparado na largada ele chega a 99 % do pico em cerca de 5,1 s em todos os carros. Disparado depois (após atingir a velocidade máxima normal) o pico termina 2-3 % mais alto (vermelho 368, branco 332, roxo 349, azul 305 km/h), mas mais tarde.

## Combustível (05:D638..D67B)

Por tick a queima é `((RPM * burn_byte) >> 14) + 1`, com RPM = `((speed * ratio) >> 8) << 1`, ratio 127/96/58/42/30 para 1ª..5ª (igual para todos os carros, também nas linhas de nitro) e burn_byte 100/64/90/82 (vermelho/branco/roxo/azul). O combustível por km é, portanto, quase proporcional à relação de marcha: a 5ª queima cerca de 30 % menos que a 4ª na mesma velocidade. Um tanque cheio são 43007 unidades. À medida que o tanque esvazia, a velocidade máxima sobe até 670 unidades (+16 km/h).

Em matemática simples (as divisões arredondam para baixo até um inteiro, como os shifts; `mod 1024` é a máscara `& 0x3FF`, o resto da divisão por 1024):

```
RPM  = (speed * ratio / 256) * 2
burn = (RPM * burn_byte / 16384) mod 1024 + 1
fuel = fuel - burn
```

O `mod 1024` nunca importa na prática (vermelho, 1ª marcha, 5000 unidades: a queima é cerca de 30), é só um limite de segurança no código. Ignorando-o e os arredondamentos intermediários, tudo se reduz a `burn ~ speed * ratio * burn_byte / 2.097.152 + 1` (2.097.152 = 128 * 16384). Exemplo, carro vermelho (burn_byte 100), 5ª marcha (ratio 30), velocidade 9000: RPM = (9000 * 30 / 256) * 2 = 2108, burn = 2108 * 100 / 16384 + 1 = 13 unidades por tick, de um tanque de 43007.

Pista plana, acelerador mantido, tanque cheio, uma volta de 2,4 km a partir do parado (só modelo, não medido no jogo; os km assumem 40 ticks/s):

| | tempo | combustível |
|---|---|---|
| vermelho, fica na 4ª | 39,4 s (termina a 239 km/h) | 29857 (69 % de um tanque) |
| vermelho, 5ª a partir de ~190 km/h | 41,5 s | 22517 (52 %), -25 % |
| branco / roxo / azul, trocas ótimas | 43,3 / 41,4 / 41,4 s | 13774 / 20045 / 18523 |
| igual, toda troca para cima a 70 % da velocidade ótima | +0,05 / +0,2 / +0,3 s | -1 / -3 / -3 % |

Ou seja, as velocidades de troca quase não importam para o combustível (a fase de aceleração é curta); a marcha de cruzeiro importa. Branco, roxo e azul já cruzam na 5ª, que é a marcha mais rápida e mais econômica ao mesmo tempo. Só o vermelho tem uma escolha real: 4ª (+2 s a cada 2,4 km, +33 % de combustível) ou 5ª. Um nitro custa 2700-3800 unidades (6-9 % de um tanque) mas cobre cerca de 0,35-0,40 km em 5,3 s, então seu custo por km é 0,7-1,1 vez o normal.

## Queimar combustível de propósito (combustível sobrando na chegada)

O bônus de combustível é pequeno: 1 unidade de velocidade máxima a cada 64 unidades de combustível queimadas, +16 km/h para um tanque inteiro. Segurar uma marcha mais baixa para queimar mais rápido só compensa quando essa marcha não é mais lenta desde o início, o que vale só para o carro vermelho (a 4ª dele vence a 5ª). Modelo, pista plana, tanque cheio, acelerador mantido, marcha final mantida desde o parado:

| carro | velocidade máxima em 20 / 40 / 60 s, 5ª | igual, 4ª | 4,8 km, 5ª / 4ª |
|---|---|---|---|
| branco | 203 / 207 / 209 | 193 / 196 / 200 | 84,6 s / 88,4 s |
| roxo | 217 / 221 / 226 | 212 / 219 / 225 | 79,5 s / tanque vazio |
| azul | 214 / 219 / 224 | 212 / 218 / 224 | 80,0 s / tanque vazio |
| vermelho | 219 / 227 / 236 | 232 / 240 (vazio aos 55 s) | a 4ª é mais rápida |

No branco, a 4ª é 12 km/h mais lenta. No roxo e no azul, a 4ª queima cerca de 35 % mais por segundo e só alcança a 5ª perto dos 60 s, quando o tanque está quase vazio (65 s / 70 s). Portanto, para esses três carros ficar na 5ª é a melhor escolha mesmo com combustível de sobra. O único outro gasto de combustível é o nitro (2700-3800 unidades, cerca de +1 km/h de velocidade máxima), que de qualquer forma é usado pelo impulso. Não testado no jogo; os km assumem 40 ticks/s.

## Maior distância com um tanque (`tools/range_opt.py`)

A queima **não** depende do acelerador: o código em `05:D5F6..D67B` calcula o RPM a partir da velocidade e queima `((RPM*burn_byte)>>14 & 0x3FF)+1` a cada tick, com o acelerador pressionado ou não (conferido com `out/ticks_a.csv`: 846 de 852 ticks exatos; o RPM usado é o de depois da atualização de velocidade daquele tick). Então tirar o pé nunca economiza combustível; as únicas alavancas são a marcha (a queima é proporcional à relação 127/96/58/42/30) e a velocidade (a queima é `k*speed` mais 1 constante por tick, então um cruzeiro mais rápido é melhor por km, tirando os degraus de inteiro abaixo).

Pista plana, tanque cheio, acelerador mantido após a largada, distância até o tanque esvaziar (os km assumem 40 ticks/s; o carro então desliza mais 0,2-0,6 km):

| carro | 4ª | 5ª | ganho da 5ª | melhor alvo bang-bang na 5ª |
|---|---|---|---|---|
| vermelho | 3,46 km | **4,75 km** | +37 % | 4,86 km (manter ~215 km/h, +2 %) |
| branco | 5,34 | 7,35 | +38 % | 7,75 (manter ~155, +5 %, mas 25 % mais lento) |
| roxo | 3,84 | 5,27 | +37 % | 5,48 (+4 %) |
| azul | 4,19 | 5,78 | +38 % | 6,04 (+4 %) |

Conclusões:
* **Todos os carros: cruzar na 5ª com o acelerador mantido.** Essa é a resposta para o carro vermelho também: a 4ª dele é mais rápida (+12 km/h, veja acima) mas queima 40 % mais por km, então um tanque dura 3,5 km em vez de 4,75 km. O vermelho continua sendo o carro mais sedento (burn byte 100 vs 64/90/82): o branco faz 7,35 km com um tanque, o vermelho 4,75 km.
* As velocidades de troca são irrelevantes para a autonomia (veja a tabela acima); suba de marcha assim que a próxima marcha acelerar melhor.
* Pequeno extra: a queima é um inteiro que sobe em degraus a velocidades fixas, então uma velocidade logo abaixo de um degrau é um pouco mais barata por km que a velocidade de equilíbrio logo acima dele (modelo com meio tanque, relativo ao acelerador a fundo): vermelho 5ª a 218 km/h (equilíbrio 227) +3,6 %; azul 5ª a 205 (221) +2 %; branco 5ª a 210 km/h (211) +12 % (uma diferença de 1 km/h que a velocidade máxima crescente de um tanque esvaziando apaga, então não é prático); roxo nenhum. Manter essa velocidade exige pulsar o acelerador e custa tempo, então só importa se o objetivo for puramente terminar a corrida limitada pelo tanque com combustível de sobra.
* Deslizar depois que o tanque esvazia: sem o acelerador, o termo de arrasto `|DRAG[gear]-speed|>>8` deixa de frear o carro quando sua velocidade está a até 256 unidades da constante de arrasto da marcha (9500..11000), então troque para a marcha cuja constante esteja mais perto da velocidade atual (3ª para o carro vermelho) para deslizar o mais longe possível. Não testado no jogo.

Só modelo, não medido no jogo.
