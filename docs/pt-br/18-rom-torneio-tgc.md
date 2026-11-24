# A ROM de torneio TGC (`Top Gear TGC Rom (E) [!].smc`)

Uma ROM hack da comunidade feita para os torneios do *Top Gear Championships* (TGC). Ela permite que o organizador **escolha as pistas do torneio no menu de
opções** e depois roda todas em sequência com **pontos de campeonato acumulados** e sem regras de qualificação. Tudo abaixo foi descoberto comparando byte a byte
com `Top Gear (Europe).sfc`, desmontando o código novo (`tools/lindis.py`) e rodando no emulador (`scripts/tgc_flow.lua`). A ROM não está no repositório
(tem copyright, `*.smc` está no `.gitignore`); as capturas de tela em `docs/img/tgc_*.png` vêm dela.

| | |
|---|---|
| arquivo | 1 048 576 bytes, **sem header de copiador** (apesar do `.smc`), LoROM |
| base | **Top Gear (Europe)**: os primeiros 512 KB são a ROM europeia (com o patch de 50 Hz do docs/15) com **322 bytes alterados** |
| espaço novo | bancos `10` e `12` (arquivo `0x80000-0x97FFF`; o banco `11` e tudo do banco `13` em diante é `00`). Código e tabelas em `10:8000-9526`, a splash (código, paleta, tilemap, tiles) em `12:8000-E8F7` |
| header | título `TOP GEAR`, país `02`, mas o byte de tamanho `$7FD7` é `00` (Europe: `09`) e as palavras de complemento/checksum `$7FDC-$7FDF` (`$21B2` / `$DE4D`) não batem entre si nem com a imagem; os emuladores não ligam |
| crédito do autor | na splash: *"A gift to Top Gear Championships ... © Kyle Blackthorne, lançada 14/07/2019"*, facebook.com/groups/topgearchampionships |

## 1. O que o jogador vê

1. **Tela splash** (`docs/img/tgc_splash.png`) antes do boot do jogo: logo TGC, uma frase em português, o crédito. Entra com efeito de mosaico e
   sai quando se aperta **qualquer botão do controle** (B, Y, Select, Start, A, X, L, R; o direcional não conta) ou sozinha depois de mais ou menos meio minuto
   (ainda aparecia depois de 1 580 frames no emulador). Depois seguem as telas normais da Kemco e do título.
2. **Menu de opções** (`docs/img/tgc_menu_track.png`): a quarta linha, que era `SPEED KPH/MPH`, agora é **`◄ TRACK ►`** e o nome da pista escolhida é
   escrito embaixo (`SAN FRANCISCO`), seguido à direita de um **número = quantas pistas há na lista do torneio**. `PLAY GAME` desceu uma linha para dar espaço.

   | tecla na linha TRACK | efeito |
   |---|---|
   | Direita / Esquerda | pista escolhida `$1F06` +1 / -1, com volta 31 <-> 0. **Todas as 32 pistas são alcançáveis**, seja qual for o estado de desbloqueio dos países (a linha COUNTRY é ignorada quando existe uma lista) |
   | **A** | acrescenta a pista mostrada ao fim da lista (ignorado com 32 entradas) |
   | **B** | remove a última pista da lista (ignorado se vazia) |
   | PLAY GAME | começa (ver 2.) |

   A lista é **ordenada**, pode ter a mesma pista várias vezes e tem no máximo 32 entradas. A antiga ação "A alterna mph/km/h" dessa linha foi removida.
3. Com uma lista de **4 a 32 pistas** o jogo roda um **torneio**: tela de local -> corrida -> RESULTS (pontos desta corrida) -> **WORLD RANKING**
   (`docs/img/tgc_world_ranking.png`, pontos acumulados dos 20 pilotos) -> tela de local da próxima pista da lista -> corrida ... Depois da última corrida o
   jogo mostra a cena original *"completed Top Gear"* e volta para a tela de título, que **apaga a lista e os pontos**.
4. Com **0 a 3 pistas** não acontece nada de especial: o jogo se comporta como a ROM europeia original (uma corrida na pista da linha TRACK, depois volta para o menu de opções;
   com 0 entradas é exatamente o fluxo original). Ou seja, o torneio mínimo tem quatro corridas (o tamanho de um "país" original).

Diferenças em relação ao campeonato original (todas verificadas forçando o fim das corridas, seção 5):
* **Sem qualificação.** Terminar em 10º está ok; nada é zerado, não há mensagem "sorry you failed to qualify", nem lógica de país/senha, nem desbloqueios.
* Os pontos por posição são os 20, 15, 12, 10, 8, 6, 4, 3, 2, 1 originais (tabela copiada para `10:8010`), mas são somados **sem o limite de 99** em toda a lista.
* A **posição de largada da próxima corrida** continua vindo do resultado anterior (docs/03), como no jogo original.
* No fim `$1F10` (dificuldade) fica em **2 (championship)**: efeito colateral do caminho "completed" (`10:8400` escreve isso). A dificuldade escolhida no menu não é restaurada.

## 2. Estado guardado no banco 7F (`7F:2400-25FF`, nunca inicializado ao ligar)

| endereço | significado |
|---|---|
| `7F:2400` (w) | "uma corrida de torneio está armada". Em cada entrada do menu principal vale `idx != count` (`10:8500`); o primeiro fade-out depois zera (`10:8300`) |
| `7F:2402` (w) | `idx` = número de corridas já terminadas = índice na lista da corrida que vai rodar |
| `7F:2404`, `7F:2406` (w) | cópias de `$1F00` / `$1F02` (posições finais do jogador 1 / 2) tiradas nesse fade-out, devolvidas a `$1F00/$1F02` quando a próxima corrida é preparada |
| `7F:2408` (w) | `count`, número de pistas na lista (0..32) |
| `7F:240A + 2*i` (w) | número da pista (byte baixo) da corrida `i` |
| `7F:244A` | dígito das unidades do contador durante a edição (o das dezenas fica em `$11DC`, tiles `$1B + dígito`) |
| `7F:2450 + 2*car` (w) | tile do **dígito das centenas** a imprimir no ranking para cada carro (0 = nenhum, `$1C` = "1", `$1D` = "2" ...) |
| `7F:2490 + 2*k` (w) | 20 endereços do buffer de tilemap `$1614 + $40*k`, um por linha do ranking (comparados com o endereço que está sendo desenhado) |
| `7F:24FE` | rascunho |
| `7F:2500 + 2*car` (w) | **total do campeonato em 16 bits** de cada id de carro (original: byte em `$1F4E + car`) |

O bloco é zerado (`7F:2400-25FF`) e a tabela de linhas é preenchida por `10:82A0`, ligada à saída da tela de título (`0F:8F4C`). Portanto um **torneio novo sempre começa na tela de
título**, e uma lista montada antes de um soft reset/título se perde. O byte original `$1F4E` continua recebendo `pontos mod 100` (o código o mantém abaixo de 100 e passa o excedente para o tile das centenas), então o código de desenho original segue funcionando.

## 3. Como funciona: os hooks

O hack é um conjunto de desvios `JML` do código europeu para o banco `10`; cada desvio re-executa as instruções que sobrescreveu e volta. (Endereço europeu -> código novo.)

| onde (Europe) | sobrescrito | desvio | o que faz |
|---|---|---|---|
| `00:8000` entrada do reset | `CLD; SEI; LDA #0` | `12:8000` | **splash**: init completo dos registradores PPU/CPU, modo BG 3 (256 cores), paleta `12:8400` (0x200 B), tilemap `12:8700` (0xC00 B), tiles por DMA (programado como 0x8000 B de `12:9000` + 0x6000 B de `13:9000` = um conjunto 8 bpp completo de 896 tiles; os dados realmente presentes são `12:9000-E8F7`, o resto lê zeros); fade in de 16 passos com mosaico + brilho; espera `$4218 & $F0F0` (qualquer botão) ou 255 x ~0,1 s; fade out; `JML 00:8004` |
| `00:818A` entrada do menu principal | `SEP #$20; LDA #0` | `10:8500` | `7F:2400 := (idx != count)`; `JML 00:818E` |
| `0F:821D` `load_minimap_graphic` (a primeira coisa que o menu/tela de local faz) | `LDA $1F06; CMP #$10` | `10:8700` | se `count >= 4`: `$1F06 := list[idx]` (byte baixo), então **todas as telas e a corrida usam a entrada da lista**; senão mantém `$1F06` |
| `0F:9242` laço do menu, Esquerda/Direita | `LDA $5A; BNE` | `10:8100` | linha 0: alternância 1P/2P original; linha 3: `$0A == $0100` (só Direita) -> `$1F06++` (volta em 32), qualquer outra coisa -> `$1F06--` (volta abaixo de 0); depois `JML 0F:9268` (redesenha a linha 3) |
| `0F:9258` laço do menu, outro botão | `LDA $5A; CMP #3` | `10:8600` | só linha 3: `$0A == $0080` (A) acrescenta `$1F06`, `$0A == $8000` (B) remove a última; atualiza o contador de dois dígitos desenhado na palavra de VRAM `$02B8` via `$11DC/$11DE`; termina em `0F:925D`, cuja cauda foi alterada para `JML 0F:922F` (acabou a alternância mph/km/h) |
| `0F:A01C` fim de `draw_string` | `STY $4C; LDA #0` | `10:8200` | quando a linha 3 desenha a string em `$A70B`: copia o **nome da pista** (`0D:C77C[$1F06]`, +4, ASCII - `$40`) para o buffer de texto `$11BE` (13 palavras) |
| `0F:A1E4` `pos_to_tilemap_offset` | `CLC; ADC #$0C6C` | `10:8270` | fixa a posição da string em `0F:A6D5` (uma linha do menu) no offset de buffer `$05CA` (não investigado mais a fundo) |
| dado `0F:A70B` | `SPEED KPH` | `^ TRACK _` | rótulo com os dois glifos de seta (`5E`, `5F`); `0F:A720` `16 -> 17` desce a barra de PLAY GAME uma linha |
| `0F:8F4C` saída do título | `STX $42; SEP #$20` | `10:82A0` | zera `7F:2400-25FF`, preenche `7F:2490..`; `JML 0F:8F50` |
| `0F:9DC5` `fade_out_dma` (15 chamadores) | `SEP #$20; LDA #$20` | `10:8300` | se `7F:2400 != 0`: zera, salva `$1F00/$1F02` em `7F:2404/6`; com `count >= 4` cai no fade normal (reentra no hook, agora desarmado); com `count < 4` faz `idx := 0` e retoma em `0F:8F50` |
| `0F:84A7` | `BCS $84CB` | `EA EA` | o desvio "corrida falhou" depois de `qualify_check_1p` nunca é tomado |
| `0F:8678` | `LDA $1F10; ASL` | `10:8800` | `SP += 2`, depois as mesmas duas instruções (ajuste de pilha para os desvios acima; finalidade não totalmente rastreada) |
| `0F:8733` `advance_track` | `INC $1F04; INC $1F06` | `10:8400` | `idx+1 == count` -> torneio acabou: `idx := 0`, `$1F06 := 0`, `$1F10 := 2`, `JML 0F:84C0` (esse caminho devolve A=3: a cena "completed Top Gear", docs/13). Senão `INC $1F04`, restaura `$1F00/$1F02` de `7F:2404/6`, `idx++`, `JML 0F:8739` (o `INC $1F06` original é pulado; `$1F06` é definido a partir da lista na próxima vez que `10:8700` roda) |
| `0F:8743` | `AND #3` | `LDA #1` | `advance_track` sempre informa "meio do país" (A=1 -> menu principal / próxima tela de local), nunca "país terminado" |
| `0F:8885` soma de pontos | `TYX; TAY; SEP #$20` | `10:9000` | `7F:2500[car] += tabela[posição]` (16 bits) antes da soma de byte original |
| `0F:8894` | `REP #$20; TYA; TXY` | `10:9080` | se o byte original é >= 100: subtrai 100 e `10:94FC` incrementa o tile de centenas desse carro (`7F:2450`) |
| `0F:8965` ordenação da classificação | `TYA; XBA; LDA $1F63,Y` | `10:9200` | compara os totais de 16 bits `7F:2500` em vez dos bytes |
| `0F:9F48` `draw_string` | `LDA #0; SEP #$20` | `10:9100` | quando a string desenhada está em um dos 20 endereços de linha do ranking (`7F:2490`), escreve também o tile de centenas na frente do número |
| dado `0F:8B85` | `#$3D` | `#$30` | o dígito das dezenas de uma linha do ranking é impresso como `0` em vez do ponto de preenchimento (para `105` não ler `.5`) |
| dados `06:E01A..E1F1`, `06:E69C..E873` | | | duas tabelas de 472 bytes com registros de 22 bytes (`xx0c 0300 502c 622c 642c yy0c ...`): ponteiros movidos e dois tiles por registro (`$2C62`, `$2C64`) apagados. Não investigado (parecem registros de tilemap/OAM de um gráfico do banco 06) |
| header `00:FFD7..FFDF` | | | campos de tamanho/checksum, ver a tabela do início |

Os desvios em 65816 são simples; as duas armadilhas encontradas ao lê-los: eles foram escritos para **A = 16 bits** na maioria dos pontos de entrada (o código original está em `REP #$20` ali), e `10:8300` é chamado em **toda** chamada de `fade_out_dma`, mas só age uma vez por corrida armada.

## 4. O fluxo, passo a passo

```
saída da tela de título (0F:8F4C) .... 10:82A0 zera 7F:2400-25FF  (count=0, idx=0, totais=0)
menu de opções: linha TRACK ......... Esq/Dir escolhem $1F06, A acrescenta, B remove     (count mostrado)
entrada do menu principal (00:818A) . 7F:2400 := (idx != count)
PLAY GAME -> fade_out ............... 10:8300: armado -> desarma, salva $1F00/$1F02; count<4: idx=0
tela de local / corrida ............. 10:8700 faz $1F06 = list[idx] (count >= 4)
fim da corrida -> results_flow (0F:83DD) .. RESULTS, depois WORLD RANKING: 7F:2500[car] += pontos[posição]
qualify_check (0F:84A4) ............. não pode falhar (0F:84A7 com NOP)
advance_track (0F:8733 -> 10:8400) .. idx+1 == count ? fim : idx++, restaura $1F00/$1F02, A=1
0F:818E menu principal (-> 10:8500) . 7F:2400 := 1, a próxima tela de local mostra list[idx]; Start/A roda a corrida
fim: cena A=3 "completed Top Gear" ... $1F10 := 2, idx := 0, volta ao título -> tudo zerado
```

## 5. Como foi verificado

`scripts/tgc_flow.lua` navega pelos menus de verdade, monta uma lista e força o fim de cada corrida exatamente como `scripts/race_end_force.lua` (docs/13), imprimindo o estado a cada passo.
Exemplo (`lista = 0, 5, 10, 15`, todas as corridas vencidas):

```
main_menu    1F06=15 flag=0 idx=0 cnt=4 list=0,5,10,15 tot0=0
FORCE        1F06=0  flag=1 idx=0 ...                               corrida 1 em 0 Las Vegas (USA)
draw_points  1F06=0  flag=1 idx=0 ... tot0=20
main_menu    1F06=0  flag=0 idx=1 ... tot0=20                       -> tela de local de 5 Machu Picchu (Peru)
FORCE        1F06=5  flag=1 idx=1 ...   draw_points tot0=40
FORCE        1F06=10 flag=1 idx=2 ...   draw_points tot0=60        corrida 3 em 10 Yokohama (Japan)
FORCE        1F06=15 flag=1 idx=3 ...   draw_points tot0=80        corrida 4 em 15 Frankfurt (Germany)
WIN_COUNTRY  1F06=0  flag=0 idx=0 1F10=2 -> title_screen -> cnt=0, totais 0
```

* Terminar em **10º** na corrida 1 (`PLACES="9,"`) avança normalmente e dá 1 ponto (`tot0=1`): não há qualificação.
* `TRACKS=5` (uma pista) e `TRACKS=x` (nenhuma) voltam ao menu de opções depois da corrida, `idx` fica em 0 (comportamento original).
* Tempos dos testes: splash pulada no frame 700, Start no título em 1100..1700, menu de opções utilizável a partir do frame ~2440, cada ação segurada 20 frames (o jogo lê o controle mais ou menos a cada 3 frames e ignora apertos durante os fades).

Reproduzir:
```
TG_ROM="$PWD/Top Gear TGC Rom (E) [!].smc" TRACKS="0,5,10,15" RACES=4 MAXF=12500 TAG=tgc tools/mesen.sh scripts/tgc_flow.lua | grep -v Uninit
python3 -I tools/romcmp.py "Top Gear (Europe).sfc" "Top Gear TGC Rom (E) [!].smc"      # os 322 bytes alterados
python3 -I tools/lindis.py 108100,108140,0,0 108600,1086CA,0,0                          # um hook, dicas de M/X por faixa (a variável ROM= escolhe o arquivo)
```

## 6. Pendências e notas para o nosso trabalho

* **Não testado:** modo 2 jogadores com lista (`10:8400` faz `INC $1F04`, o `DEC` original mais adiante só compensa se o caminho "meio do país" for tomado, o que agora é sempre), a demo de atração parada com uma lista armada, listas com a mesma pista em sequência, lista maior que a tela de ranking de 20 linhas (ela só mostra os 20 carros, então não deve haver problema).
* O total de 16 bits manda na ordenação; o dígito das centenas é um tile separado e dá errado acima de 999 pontos (32 corridas x 20 = 640 no máximo, inalcançável).
* O bloco `7F:2400` **não** é inicializado ao ligar; ele é zerado ao sair da tela de título. Um hack que pulasse a tela de título começaria com lixo ali.
* `10:8300` com `count < 4` retoma em `0F:8F50` depois de um fade chamado por `JSR` (um endereço de retorno fica na pilha a cada uso); é inofensivo na prática porque o código do menu reinicia a pilha, mas é por isso que esse caminho parece estranho.
* Diferenças em relação ao nosso randomizer (docs/09, 10): este hack muda **qual das 32 pistas originais** é corrida e quando a série termina; o randomizer gera pistas novas. Os dois usam `$1F06` como único seletor de pista e o `advance_track` / fluxo de resultados originais, então poderiam ser combinados: a parte de série/pontos (totais `7F:2500`, `10:9000..9200`) é independente de como os dados da pista são produzidos. Os dois hacks usam espaço livre diferente (aqui os bancos `10` e `12` de uma imagem de 1 MB; a nossa também tem 1 MB, ver docs/10) e ambos alteram código perto de `0F:8733` / `00:818A`, então uma fusão exige conferir manualmente os hooks que se sobrepõem.
