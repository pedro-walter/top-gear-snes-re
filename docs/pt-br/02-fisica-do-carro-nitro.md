## Física do carro (banco 05) – variáveis da WRAM (visão da CPU, banco 0)
| endereço | significado (confiança) |
|---|---|
| `$1E5A` | **velocidade** (jogador), 16 bits. ~3500 com 85 km/h no HUD. **Confirmado pelo usuário contra o HUD.** |
| `$1E5E` | **RPM** = `speed * $9767[gear]` << 1. **Confirmado.** |
| `$1E72` | índice da **marcha**. **Confirmado.** |
| `$1EE2` | limite de velocidade máxima da marcha atual = `$9597[Y] + (($A7FF-$1E62)>>6)`. Observado acompanhando o carro do *computador* (rascunho compartilhado, sobrescrito pela atualização do carro da IA) – ou seja, a mesma rotina roda para os dois carros. |
| `$1E62` | **combustível, conta PARA BAIXO** (confirmado pelo usuário; 0 = vazio). Consumo por tick = `((RPM * $1EFD) >> 16)` aproximadamente, os 10 bits altos `+1` (código 05:D638-D67B), portanto é por frame e depende do RPM. Menos combustível -> `$1EE2` maior (a fórmula usa `$A7FF - fuel`), como o usuário observou. Em 0: limpa o bit0 de `$1EB4`, ativa o bit `$20` de `$1EF5`, zera o RPM `$1E5E` -> sem mais empuxo, o carro desliza. |
| `$1EFD` (byte) | **fator de consumo do carro do jogador** = `CarStats[$1F8F]` (00:97DB: vermelho 100, branco 64, carro2 90, carro3 82). `$1EFE` = o mesmo para o carro do computador (`$1FAC`; índice 0 se `$1F04`==0). Definido por 00:C69E-C6B5. O usuário viu a palavra 25700 (vermelho) / 25664 (branco) = `$1EFE:$1EFD` = $6464 / $6440. |
| `$1FAC` | índice do carro controlado pelo computador (tela de baixo) |
| `$1EEA` | offset de tabela do carro do computador = `$1FAC << 4` |
| `$1EB4` | bits de status; o bit0 é limpo com o tanque vazio (provavelmente 'motor ligado / pode acelerar') |
| `$1ED7` | **posição na pista** do jogador; volta a 0 a cada volta. `$7E4000[pos>>4]` é portanto uma tabela por posição da pista (termo de ladeira/curva aplicado à aceleração). |
| `$1E6C` | **nitro ativo**: negativo enquanto o nitro está ligado, 0 caso contrário. (seleciona a metade de tabela +$3A) |
| `$1EF5` | flags. bit `$20` = sem empuxo (ativo com combustível vazio ou RPM 0). bit `$10` = estado de queda de RPM (05:D30F: RPM -= $30/tick, inverte `$1E66` a cada tick, p. ex. após troca de marcha/batida – semântica não verificada). |
| `$1F10` | **nível de dificuldade/skill** (achado pelo usuário por busca de memória; referenciado em 00:A5F3, 00:C062, 05:EE19, 05:EE89, 0F:83EB...; os usos no banco 05 provavelmente são da IA/rubber-banding) |
| `$1F8F` | **carro selecionado** (usuário: 0 vermelho, 1 branco, 2 roxo, 3 azul); referenciado sobretudo pelo código de menu do banco 00, não pela física do banco 05 |
| `$1F7A` | **máscara do botão de troca para CIMA** (máscara de bits da palavra do joypad; usuário: 0x0010 = R). 0 => câmbio automático. |
| `$1F7C` | **máscara do botão de troca para BAIXO** (0x0020 = L). 0 no automático. |
| `$1F7E` | **máscara do botão de nitro** (0x0080 = A); continua ativa no automático. Lida em 05:D35F. |
| `$14` (direct page) | palavra atual do joypad do jogador ativo; a rotina de velocidade faz `TRB $14` com as máscaras acima (testa e limpa o bit). Palavra do joypad: B=8000 Y=4000 Sel=2000 Start=1000 Up=800 Down=400 Left=200 Right=100 A=80 X=40 L=20 R=10. |
| manual vs automático | **não há flag separada**: manual <=> `$1F7A`/`$1F7C` diferentes de zero (o código de menu em 0F:9828 faz OR deles para escolher o gráfico AUTO/MANUAL -> `$5A`). Os 4 layouts de controle presumivelmente carregam máscaras diferentes. `$0087`/DP`$87` é rascunho sem relação. |
| `$1EE8` | **offset de tabela do carro do jogador = `$1F8F << 4`** (definido em 00:A714; 0 para vermelho, 16 branco, ...). Não depende do nível de skill (teste do usuário). Somado a gear*2 ao indexar as tabelas por carro. |

As tabelas ficam no **banco 00** (DBR=00 durante o código de física), em blocos por carro de 8 palavras (16 bytes), com 5 entradas de marcha cada:
| tabela (banco 00) | conteúdo |
|---|---|
| `$9597` | velocidade máxima por marcha. car0 (vermelho): 4500, 6000, 8400, 9600, 10000. car1 (branco): 4000, 5800, 7400, 8000, 8500. car2: 4200,6000,8400,8900,9200 |
| `$96F3` | fator de aceleração por marcha: 4, 5, 6, 9, 14 (mesmo formato nos carros vistos) |
| `$960B` | termo de arrasto por marcha (car0: 24000,12500,9500,9900,11000; car1 menor a partir da marcha 3) |
| `$9767` | relação de marcha para o RPM: 127, 96, 58, 42, 30 |
| `$99DB` / `$9A15` | limiares de velocidade para reduzir / subir marcha: reduzir 0,1150,2200,3500,4500; subir 1600,3200,4000,5440,65535 |
| `$97DB` | byte de consumo por carro [100, 64, 90, 82] |
| `$97DF` / `$981F` | escadas de 8 entradas +640*n / -640*n por carro, indexadas por `$1E90`-1: escritas em `$1E94`/`$1E92` (limites simétricos, provavelmente direção/grip) |
Escala de velocidade: `$1E5A`/~41,7 = km/h (10000 ~ 240 km/h); trocas de marcha para cima em ~38, 77, 96, 130 km/h.
Tanque cheio = `$A7FF` (definido tanto para `$1E62` quanto `$1E64` no início da corrida, 00:A700). Bônus de velocidade máxima = `($A7FF-fuel)>>6` (0 com tanque cheio, ~671 com tanque vazio).
Atualização da velocidade (`05:D2E0 car_update_speed_gear`, escreve `$1E5A` em 05:D439/D486):
 accel = (`$7E4000[$1ED7>>4]` negado, escalado) x `$96F3[Y]` pelo multiplicador com sinal da PPU (`$211B/$211C`, resultado em `$2135`),
 `>>4`, somado à velocidade; limitado a `$1EE2`; depois o arrasto `$960B[Y]` puxa em direção a 0; limitado a >= 0.
 Lógica de troca acima dele: modo automático (`$1F7A`==0) compara a velocidade com os limiares `$99DB`/`$9A15` (sobe/desce); modo manual (`$1F7A`!=0) incrementa/decrementa `$1E72` (índice máx. 4) quando os bits de botão de `$1F7A`/`$1F7C` estão ligados em `$14`.


## Nitro
* `$1E6C` (P1) / `$1E6E` (P2): **2 bits baixos = cargas de nitro restantes** (3 no início da corrida, 00:82E2), bit15 = nitro ativo. O HUD mostra o número de cargas (`AND #3`, menos 1 enquanto ativo: 00:D04F).
* Gatilho (05:D358): exige cargas != 0 e nitro não ativo (bit15 limpo), máscara de botão `$1F7E` (A) pressionada => `$1E6C |= 0x8000`.
* Enquanto ativo, a máquina de estados 00:B9ED avança a palavra a cada frame: fase A (bit14=0): +0x200/frame por 32 frames (flash de paleta); fase B (bit14=1,bit13=0): +0x20/frame por 256 frames;
  fase C (bit13=1): +0x100/frame por 32 frames; depois dá a volta para positivo e **uma carga é subtraída** (DEC). Total de **320 frames (5,3 s)** por nitro. Não pode ser reiniciado enquanto ativo.
* Efeito: toda a consulta às tabelas de física usa `Y += 0x3A` (um segundo conjunto de linhas em `$9597/$960B/$967F/$96F3`: velocidade máxima, arrasto, tração do motor, aceleração). Linhas de nitro (carro vermelho): máx. 5300/7200/**11400**/12500/15600, tração 108/50/31/22/18.

## Física da velocidade (totalmente modelada – `tools/physics.py`, exata à unidade em relação ao jogo por 850 ticks)
Por tick (05:D2E0.., ~2 ticks a cada 3 frames):
```
top   = TOP[Y] + ((0xA7FF - fuel) >> 6)                 ; $1EE2   (Y = car*16 + gear*2 (+0x3A se nitro))
speed += slope_term   ; s = $7E4000[pos>>5]; A=-s; se s>0: A>>=2 (aritmético); A>>=4 (extensão de sinal de 12 bits)   (descida é 4x mais forte que subida)
speed -= (|DRAG[Y] - speed| >> 8) & 0xFF                ; arrasto, velocidade limitada a >= 0
se acelerando (máscara do botão X $1F76) e fuel>0 e finishers<10:
    diff = top - speed
    se diff < 0: speed -= (|diff|>>8)&0xFF
    senão:       speed += (diff * PULL[Y]) >> 10         ; (tabela $967F; pela metade se o bit 0x10 de $1EF5)
senão: em roda livre (só a sangria do excesso de velocidade)
```
Equilíbrio (plano, tanque cheio, carro vermelho): m1 3829 / m2 5070 / m3 7959 / **m4 9347** / m5 8857 (219 vs 207 km/h): sem nitro a 4ª marcha do carro vermelho é mais rápida que a 5ª.
Com nitro: 4655 / 6596 / 11367 / 12408 / **15488** (363 km/h). Menos combustível => `top` maior (+0..670) => equilíbrio maior e diferença (velocidade máx.) maior => aceleração mais rápida (isso explica a observação do usuário).

### O truque "3ª marcha + nitro"
Melhor marcha para *aceleração* (ganho líquido de velocidade por tick, pista plana, nitro): 1ª abaixo de ~2500, **3ª marcha (índice 2) de ~3000 até ~6500 unidades (70..155 km/h)**,
5ª acima de ~7000. O câmbio automático (limiares de subida 1600/3200/4000/5440 unidades) já fica na 4ª/5ª entre 4000-5500, onde a tração é só 149/131 (4ª) ou 134 (5ª) por tick contra
**195/169/143 na 3ª** em 4000/5000/6000. Então: fique na 3ª (manual), use o nitro e passe para a 5ª em ~7000 -> bem mais rápido que o automático. Motivo: a linha de nitro da 3ª marcha tem máx. 11400 (contra 8400 normal) e
tração 31 (contra 18 da 5ª), então a diferença `(top - speed)*pull` é maior ali. O mesmo vale para os outros carros (as linhas de nitro deles são quase idênticas).
