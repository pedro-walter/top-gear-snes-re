# Economizar combustível: o que funciona e o que não funciona (medido no Mesen headless, ROM USA)

Pergunta: jogo de torneio, carro roxo (vermelho em segundo). Algumas pistas exigem dois pit stops; existe alguma forma, além de passar cedo para a 5ª, de economizar o pouco de combustível que elimina uma parada? Dirigir mais devagar (cerca de 170 km/h, ZSNES 1.42) "saiu pela culatra".

Método: `scripts/fuel_lab.lua` dirige o jogo real com um bot de direção (controlador PD na posição lateral `$1E8A`, acelerador mantido, câmbio manual forçado, carro/pista alterados) e registra cada tick de física (velocidade, marcha, combustível, posição, delta de frames). `tools/fuel_sum.py` resume por volta, `tools/fuel_stops.py` transforma o combustível por volta em contagens de pit stops. Todos os números são do Mesen (timing preciso); veja a questão em aberto no fim.

## 1. Mais devagar não é mais barato (isso explica o tiro pela culatra)

Por tick a queima é `((RPM*burn_byte)>>14)+1`, um tick a cada ~3 frames (`$1E90` = delta de frames, 2,5..3,0), e a distância por tick é `speed*delta/2`. Combustível por distância medido, roxo, 5ª marcha, voltas de Tokyo + London (cerca de 30 000 ticks):

| velocidade | 105-160 km/h | 160-200 | 200-220 | abaixo de 100 |
|---|---|---|---|---|
| combustível por distância (relativo) | 1,00 | 1,00 | 1,00 | **1,4 a 3** (o delta também cai para 2,2..2,6 quando se rasteja, então mais ticks por km, mais o +1 constante por tick) |

Na 5ª marcha o combustível por km é **plano de 150 a 220 km/h**; o `+1` constante por tick é só 5-8 % da queima. Tirar o pé do acelerador nunca ajuda (docs/12: a queima não depende do acelerador). Um limite de velocidade na 5ª: 200 km/h ou mais = mesmo combustível, 170 = +2,5 % por volta, e 150 = +32 % **só porque o bot nunca chegou à velocidade de troca 4ª→5ª e ficou na 4ª**. Se o carro fica na 4ª a 170 km/h (ou o câmbio automático, que só sobe para a 5ª a ~211 km/h) o RPM é 40 % maior, o que é uma causa provável do resultado no ZSNES. Regra: qualquer que seja a velocidade, esteja na 5ª.

## 2. Coisas que economizam combustível (roxo, bot com direção)

| alavanca | efeito | custo |
|---|---|---|
| **Subir de marcha cedo** (`SH=20,28,36,44` ou "sobe a cada tick") | primeira volta Tokyo 9748 vs 10121 (-3,7 %), London 3 voltas 31041 vs 31620 (-1,8 %); cerca de -370 por trecho (largada e toda saída do pit) | cerca de 0 a +1 s |
| **Deixar o tanque secar e deslizar** | o carro vazio desliza **5550 unidades de posição a partir de 171 km/h = 0,14 volta = cerca de 1400 equivalentes de combustível (3 % de um tanque)**; as marchas 2-5 são idênticas (+-2 %), a 1ª só 3800 | nenhum, se terminar na entrada do pit ou na linha |
| **Nitro** (os três) | neutro em combustível: um nitro 700 frames após a largada: 9752 vs 9748 de combustível, **-1,9 s**; 1500 frames: 9465 (-3 %), -1,4 s | nenhum |
| Limitar a velocidade logo abaixo de um degrau de queima (roxo 200,4 e 218,6 km/h) | 3 voltas London: 30905 (limite 218) / 30966 (limite 200) vs 31041: -0,3 %, +1,4 s / +3,1 s | não vale a pena |
| Tirar o pé nas curvas (`CORNER=lift`) ou truque do freio | 1,5 % menos combustível, +2 s por volta (tirar o pé perde velocidade) | não vale a pena |

A queima é um inteiro que sobe 1 a velocidades fixas, então o custo por km é um dente de serra de +-4 %: roxo 5ª degraus em 182,2, **200,4**, **218,6**, 236,8 km/h (vermelho 5ª 180,4, 196,8, 213,0, 229,4; vermelho 4ª a cada 11-12 km/h). Na prática a duração do tick (`$1E90` entre 2,5 e 3,0, dependendo de quanto o jogo precisa desenhar) muda o combustível por km em até +-8 %, mais que o dente de serra, então manter uma velocidade logo abaixo de um degrau não é mensurável e custa mais tempo do que economiza.

## 3. Quanto custa um pit stop (gatilho forçado em Tokyo, P1)

* Sem reabastecer (sair no estado "espera acelerar" com combustível != 0): **5,3 s** perdidos.
* Com reabastecimento: **7,5 s + 0,26 s por 1000 unidades** adicionadas. O reabastecimento roda a 63,5 unidades por frame (`+$7F` a cada dois frames, não a cada frame como docs/04 supunha): 34400 → 43007 leva 150 frames. Uma parada completa a partir de 34400 leva 9,7 s.
* Sair antes exige apertos *novos* do acelerador durante o estado de reabastecimento (segurar desde antes não faz nada), então um reabastecimento parcial é possível: reabasteça só o que o resto da corrida precisa.

Então o combustível economizado vale só 0,26 s por 1000 unidades, mas **uma parada economizada vale 7,5 s mais toda a sobrecarga do segundo reabastecimento**: o que importa é só se você cruza um limiar de parada.

## 4. Quantas paradas (modelo ocioso de `base_t<track>_c<car>.csv`, carro centralizado, pit só na entrada do pit, reabastecimento até o cheio)

Rode `python3 -I tools/fuel_stops.py 2` (roxo) ou `0` (vermelho). Tanques necessários para a corrida toda (1 tanque = 43007), ideal / realista com bot (+3,4 % de combustível por volta como medido com o bot de direção, três voltas London/Tokyo):

| pista | voltas | tanques do roxo | paradas do roxo: ideal, realista, + 5ª cedo, + deslizar com tanque seco | tanques do vermelho | paradas do vermelho iguais |
|---|---|---|---|---|---|
| 3 San Francisco | 6 | 1,00 | 0, 1, 1, **0** | 1,10 | 1,1,1,1 |
| 4 Rio | 6 | 1,38 | 1,1,1,1 | 1,55 | 1,1,1,1 |
| 6 Chichen Itza | 6 | 1,09 | 1,1,1,1 | 1,23 | 1,1,1,1 |
| 8 Tokyo | 7 | 1,53 | 1,1,1,1 | 1,70 | 1,1,1,1 |
| 9 Hiroshima | 5 | 1,03 | 1,1,1,1 | 1,17 | 1,1,1,1 |
| 11 Kyoto | 6 | 1,45 | 1,1,1,1 | 1,62 | 1,1,1,1 |
| 12 Munich | 7 | 1,43 | 1,1,1,1 | 1,62 | 1,1,1,1 |
| 14 Black Forest | 6 | 1,20 | 1,1,1,1 | 1,33 | 1,1,1,1 |
| 15 Frankfurt | 8 | 1,39 | 1,1,1,1 | 1,52 | 1,1,1,1 |
| 21 Nice | 7 | 1,32 | 1,1,1,1 | 1,46 | 1,1,1,1 |
| 22 Bordeaux | 6 | 1,21 | 1,1,1,1 | 1,34 | 1,1,1,1 |
| 25 Rome | 6 | 1,39 | 1,1,1,1 | 1,54 | 1,1,1,1 |
| 28 London | 8 | 1,86 | 1, **2, 2, 1** | 2,07 | 2,2,2,2 |

(As outras pistas não têm pit e têm 3-4 voltas.) Consumo extra que um plano de 1 parada consegue absorver antes de precisar de uma segunda parada (modelo ideal): roxo Tokyo +18 %, Rio +33 %, Rome +34 %, **London +1 %**; vermelho Tokyo **+6 %**, Kyoto +17 %, Rome +20 %, Munich +20 %, Frankfurt +21 %.

Portanto, por este modelo, a **única pista do roxo em que economizar combustível elimina uma parada é London** (e San Francisco poderia ir sem parada nenhuma); London com o vermelho precisa de duas paradas aconteça o que acontecer. **Tokyo é uma parada para o roxo com margem de 18 % e para o vermelho com margem de 6 %.** Se Tokyo exige duas paradas no seu jogo, ele queima pelo menos 18 % (roxo) / 6 % (vermelho) a mais do que nestas execuções.

London com o roxo de ponta a ponta (bot de direção, troca de marcha cedo, gatilho do pit forçado na entrada pos 10752 da volta 5, combustível 0): o tanque secou exatamente na entrada (sem deslizar faltam 2500 unidades de posição, com o pit a 27 % da volta), o carro entrou no pit a 177 km/h com `fuel == 0` (o jogo lida com isso, 05:D75E liga o bit 0 de `$1EB4`), reabasteceu 0 → 39243 em 600 frames e tinha 8566 sobrando com 0,8 volta para o fim (cerca de 8500 necessários). O registro terminou ali, então a chegada em si não foi observada: uma parada funciona, mas com margem de cerca de 1-2 %.

## 5. Questão em aberto: o emulador

O combustível por distância é proporcional a `1/delta`, onde delta (`$1E90`) é quantos frames leva uma passagem do laço principal. O laço é limitado pela CPU (cerca de 3 frames por passagem num SNES real e no Mesen, docs/15). Um emulador que roda o laço do 65816 mais rápido que o hardware (o ZSNES 1.42 não é preciso em ciclos) consegue 2 frames por passagem, e então **a mesma direção queima 50 % mais combustível por km** (e os temporizadores de nitro/reabastecimento, contados em frames, continuam iguais). Se o torneio roda em hardware ou num núcleo preciso, planeje com a tabela acima; se for o ZSNES, as contagens de paradas acima são otimistas. Em qual emulador é o torneio, e quantas paradas Tokyo (roxo) precisa lá? Isso resolve; não consigo rodar o ZSNES aqui.

## Reproduzir

```
TRACK=28 CAR=2 LAPS=5 STEER=1 SH=20,28,36,44 TAG=L_ref tools/mesen.sh scripts/fuel_lab.lua
python3 -I tools/fuel_sum.py out/fuel/L_ref.csv
```

Env: `TRACK CAR(0 vermelho,1 branco,2 roxo,3 azul) LAPS STEER(1=o bot dirige, 0=lateral fixada em 0) SH(velocidades de troca km/h 1→2,2→3,3→4,4→5) CAP/CAPU(tirar o pé acima de km/h / unidades brutas) CORNER(full|lift|brake) NITRO(frame após a largada para apertar A) PITAT/PITLAP/PITFUEL(forçar o pit nessa pos nessa volta, sair com esse combustível) COASTAT/COASTG(secar nesse frame, marcha de deslize)`. Execuções `base_t<track>_c<car>`: `TRACK=t CAR=c LAPS=3 TAG=base_t<t>_c<c> ... scripts/fuel_lab.lua` (padrão `SH=40,63,100,167`, `STEER=0`). Execuções em paralelo precisam de homes separados: `tools/mesen.sh`, `mesen2.sh` .. `mesen4.sh`.
