# O que difere entre os quatro carros (vermelho, branco, roxo, azul)

Os textos da tela de seleção (MAX SPEED / 0 TO 60 / TIRE GRIP / FUEL CONSUMPTION) são strings estáticas, um bloco por carro
(ROM ~0x7A883, 0x7AA41, 0x7AACB, 0x7AB59). Nada na física os lê.
`$1F8F` = carro, `$1EE8` = carro*16 (00:A714); cada tabela por carro tem linhas de 16 bytes (5 palavras de marcha, linhas de nitro em +58), indexadas por `car*16 + 2*gear`.
δ = `$1E90` (frames desde o último tick + 1; 2..3 nas execuções headless). Scripts de teste: `scripts/car_accel.lua`, `scripts/car_steer.lua`.

| | vermelho | branco | roxo | azul |
|---|---|---|---|---|
| rótulo MAX SPEED / 0-60 / GRIP / FUEL | 147 / 5.9 / LOW / HIGH | 131 / 3.5 / **HIGH** / LOW | 137 / 5.0 / LOW / MID | 137 / 4.3 / MID / MID |
| velocidade máxima `$9597` por marcha 0..4 | 4500 6000 8400 9600 10000 | 4000 5800 7400 8000 8500 | 4200 6000 8400 8900 9200 | 4200 6000 8400 8900 9000 |
| fator de empuxo k `$967F` | 108 32 16 12 8 | 112 48 38 34 24 | 108 32 22 17 14 | 108 40 30 18 15 |
| centro de arrasto D `$960B` | 24000 12500 9500 9900 11000 | 24000 12500 7500 8750 9000 | 24000 12500 9500 9750 10000 | 24000 12500 9500 9750 9500 |
| consumo `$97DB` | 100 | 64 | 90 | 82 |

## Atualização de velocidade por tick de física (05:D3E1..D486, D4DB..D527), acelerador ligado, v = velocidade, T = velocidade máxima (`$1EE2`)
1. `v += (T - v) * k >> 10` enquanto v < T (k = `$967F`; pela metade se o bit 4 de `$1EF5`). Se v > T: `v -= (v - T) >> 8` (byte baixo). T = `$9597` + `(A7FF - fuel) >> 6`.
2. Ladeira: `v += (-slope * hillfactor[gear]) >> 4` (`$96F3`, igual para todos os carros: 4 5 6 9 14).
3. Arrasto (D453..D486): `v -= min(255, |D - v| >> 8)`. D = entrada de `$960B`. É mínimo quando v = D; não é um coeficiente simples.
Nenhum dos passos usa δ. Equilíbrio (ladeira 0): `v* = (k*T - 4*D) / (k - 4)`; medido em pista plana, acelerador a fundo, câmbio automático,
a velocidade 4120 (= 60 mph) é atingida após 2,1 s (vermelho), 1,25 (branco), 1,78 (roxo), 1,33 (azul) frames/60; o platô na marcha mais alta foi
8850+ (vermelho, ainda subindo), 8375, 8840, 8730; ou seja, a velocidade máxima é onde empuxo e arrasto se equilibram, abaixo do valor de `$9597` no caso do vermelho.
Os números 0-60 da tela de seleção mantêm a mesma ordem e proporções parecidas (x2,8), exceto o azul (x3,2).

## Direção ("grip")
* Limite do deslocamento lateral por tick (`$1E94`): sem acelerar 640*δ para todos os carros; acelerador ligado 384*δ, **branco 416*δ** (+8,3%); acelerador+freio (P1) 640*δ. Medido, idêntico nos outros três carros.
* Rampa do ângulo de direção por tick (líquida, medida, idêntica nos quatro carros): `608*δ` (x2 abaixo da velocidade 0x280) menos a força de recentralização `320*δ` (`$9B01`).
* `$9DDF` (subtraído da rampa acima da velocidade 0x280) tem uma linha diferente de zero só para o azul (160..1280), mas o código a indexa apenas com X = 2*δ (bits altos sobram de código anterior, 0 para o P1), então lê a linha 0 (tudo zero). Medido: a rampa do azul é igual à dos outros. A linha é morta para o jogador 1 (a cópia do P2/computador em 05:E120 usa o mesmo padrão).
Portanto a única diferença física de grip para um jogador humano é o limite do acelerador do branco; o MID do azul não afeta a direção do P1, e vermelho/roxo/azul são iguais.
