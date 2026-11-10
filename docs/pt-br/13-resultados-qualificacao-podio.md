# Fluxo pós-corrida: resultados, pontos do campeonato, qualificação, game over, cena do pódio

Tudo aqui foi lido no disassembly (`results_flow` 0F:83D7 e arredores) e depois **reproduzido no Mesen headless** forjando o fim de uma corrida
(`scripts/race_end_force.lua`, veja "Como reproduzir"). Os caminhos e mensagens exatos abaixo foram todos vistos na tela.
Nomes: `$1F4E` etc. estão em `disasm/annot/ram.txt`, as rotinas em `disasm/annot/symbols.txt`.

## 1. Onde a corrida passa o controle
* Laço da corrida (00:877D): `$1EB0` (finish_count) >= 10 -> `race_exit` 00:8834 -> `JSL menu_entry` (0F:806D) com **A=1** -> `results_flow`.
  (A=0 é o caminho de boot/novo jogo = `location_screen`.) Depois 00:8875 `JMP main_restart` inicia a próxima corrida.
* `$1F12[0..9]` = ids dos carros na ordem de chegada (escrito por `cars_update` 00:A1F9 para os bots e 05:E7E2 para o humano; `race_end_simulation`
  preenche o resto), `$1F26 + 2*id` = tempo de chegada em frames, `$1F00` / `$1F02` = colocação (base 0) do jogador 1 / 2 (`$1EB0` no momento em que terminaram).
  Id de carro 0 = jogador 1, id 1 = jogador 2 / o carro COMPUTER, ids 2..19 = os 18 bots com nome (nomes em 0D:C47B + (id-2)*8).
* `$1F00..$1FFF` **não** é limpo por `main_restart` (ele limpa só `$0000-$1EFF`), então esse bloco é o "estado de save" persistente de uma
  sessão: pista `$1F06`, skill `$1F10`, desbloqueio `$1F0A`, pontos `$1F4E`, nomes, recordes de volta `$1FB2`, ...

## 2. Telas, em ordem (todas dentro de `results_flow`, 0F:83D7)
1. **RESULTS** (`draw_race_result_table` 0F:882D): 10 linhas, posição, nome, tempo (primeira linha absoluta, as outras `+diferença`), pontos desta corrida. Espera uma tecla.
2. **WORLD RANKING** (`draw_points_table` 0F:894F): os 20 carros ordenados por pontos do campeonato, com rolagem para cima e para baixo. Espera uma tecla.
3. Teste de qualificação (abaixo). Dependendo do resultado:
   * passou no meio do país -> direto para o menu principal (`loc_0F818E`) com a próxima pista selecionada, **sem mensagem**;
   * todo o resto -> a **tela de cena** (seção 5) com uma mensagem, e depois o menu principal ou a tela de título/KEMCO.

## 3. Pontos do campeonato
* Tabela em **0E:8024**, indexada pela posição de chegada 0..9: `20 15 12 10 8 6 4 3 2 1` (depois zeros). Só as 10 entradas de `$1F12` pontuam.
* `$1F4E + id do carro` (1 byte por carro, 20 bytes). São **somados como efeito colateral de desenhar** a tabela RESULTS (0F:887F..8891:
  `$1F4E[id] += 0E:8024[position]`), ou seja, só quando a tela de resultados roda.
* Mantidos entre corridas porque nada os zera exceto:
  * o boot (00:80B2, roda só no reset),
  * `advance_track` no **início de um país novo** (0F:8750, isto é, depois de toda 4ª corrida, *antes* do teste de país, usando a lista ordenada já construída),
  * os dois caminhos de falha (0F:84CB / 0F:84E1).
  O menu principal (COUNTRY / SKILL / 1-2 PLAYERS) nunca os toca; então trocar de país no meio do caminho mantém os pontos.
* `draw_points_table` constrói `$1F62[0..19]` = ids de carro ordenados por pontos, **melhor primeiro** (um bubble sort em `$1F4E[id]`; empates mantêm a ordem da lista),
  e desenha os nomes (tabela 0D:C47B; id 0 / 1 usam os nomes dos jogadores, ou "COMPUTER") mais a coluna de pontos (`draw_points_column`, 0F:8B4E, limitada a 2 dígitos por `byte_to_ascii`).
  Então `$1F62` é a classificação do campeonato e `$1F62[0]` é o líder.

## 4. Qualificação (este é o "game over")
Um país = 4 pistas consecutivas (`$1F06 & 3` = 0..3, país = `$1F06 >> 2`, 8 países, 32 pistas). Seja `N` = número de humanos (`$1F04 + 1`; 1 em 1P, 2 em 2P); ids de carro < N são os humanos.

| teste | código | regra | resultado da falha |
|---|---|---|---|
| **por corrida** `qualify_check_1p` 0F:871A | chamado em 0F:84A4 | um id humano deve estar entre as primeiras **5** entradas de `$1F12` (terminou em 1º..5º na corrida) | mensagem A=1, pontos zerados |
| **por país** `advance_track` 0F:8733 | só depois da 4ª corrida (`$1F06 & 3 == 0` depois do INC) | um id humano deve estar em `$1F62[0..2]` (**top 3** da classificação do campeonato, ordem de empate como ordenado) | mensagem A=2, pontos zerados |

Limites verificados no emulador: 5º lugar numa corrida passa, 6º falha; 3º na classificação se qualifica, 4º não (testes: `PLACE=4`/`5`, forjando `PTS=`).
Em 2P basta um dos humanos passar. A dificuldade não muda os limites (só muda qual texto de senha/continuar é mostrado).

Fluxo depois dos testes (`results_flow` 0F:84A4-84F5; o valor que acaba na pilha = código de mensagem `A`):

| resultado | A | o que acontece |
|---|---|---|
| teste da corrida falhou (0F:84CB) | **1** | pontos `$1F4E` zerados, `$1F00=0`, `$1F02=1` (reset do grid: o humano largua no fundo); **`advance_track` é pulado**, `$1F06` inalterado. |
| corrida OK, meio do país | 1 (de `advance_track`, carry limpo) | `$1F06++`, `JMP 0F:818E` = menu principal com a próxima pista. Sem tela de mensagem. |
| fim de país OK, não é o último país | **0** | `$1F06` já é a primeira pista do próximo país; mostra a cena feliz + senha, depois `JMP 0F:818E` (menu principal). |
| fim de país falhou (0F:84E1) | **2** | pontos zerados, reset do grid como em A=1, `$1F06` **já avançou para o próximo país** (veja a esquisitice). |
| fim de país OK na pista 31 (`$1F06` volta a 0) | **3** | cena "completed Top Gear" (0F:84C0 coloca A=3 quando `$1F06 == 0`). |

O valor A=1 que `advance_track` devolve para "próxima corrida neste país" é também o que o caminho de corrida falha empilha; os dois se distinguem pelo `BCS` logo depois de `qualify_check_1p`.
O **reset do grid** (`$1F00=0, $1F02=1` = colocações anteriores) é o que faz o humano largar no fundo/frente do próximo grid (veja docs/03).

### O que uma falha faz com o fluxo do programa
As mensagens com A != 0 terminam em 0F:866F: `$1FF6 (attract_flag) = A` (1/2/3), música 0, depois
```
$1F08 = $1F06 & 0x1C ; $1F0A[skill] = max($1F0A[skill], $1F08 >> 2) ; JMP results_flow
```
e o topo de `results_flow` (0F:83DD) vê `$1FF6 != 0`: `$1F06 = $1F08` e `JMP location_screen` (0F:815A) -> `title_screen` (0F:8C95) com a introdução completa:
**logo "presents" da KEMCO -> animação do logo TOP GEAR -> PRESS START** (cerca de 860 frames até o título esperar uma tecla), a mesma sequência de quando se liga o console.
A tela de título sobrescreve `$1FF6` com o contador regressivo de attract 0x04B0, então a flag só serve para fazer `results_flow` tomar esse ramo. Uma tecla então vai ao menu principal
(opções: 1 PLAYER / SKILL LEVEL / COUNTRY / SPEED / PLAY GAME, `main_menu` 0F:918B); uma contagem ociosa de 0x4B0 frames inicia a corrida demo de attract.
Só A=0 (país passado) pula o título e vai direto ao menu. Nomes, recordes de volta, skill, unidades, controles sobrevivem; pontos e posições de grid não.

### Esquisitices encontradas (para ninguém tropeçar)
* **Falhar no teste de fim de país não bloqueia de verdade o próximo país.** `advance_track` já incrementou `$1F06` para a base do próximo país, então
  `$1F08` / `$1F0A[skill]` recebem o próximo país: depois de "SORRY YOU FAILED TO QUALIFY FOR THE NEXT COUNTRY" o menu principal está no país N+1 e COUNTRY o lista como desbloqueado
  (observado: `$1F06=4`, `$1F0A=1` depois de falhar na pista 3). Só os pontos se perdem. Falhar numa única corrida (A=1) mantém você no mesmo país (`$1F06` inalterado -> reinicia na
  primeira pista daquele país, já que `$1F06 = $1F08` = base do país).
* A mensagem de falha A=2 **também imprime a senha do próximo país** (o código de senha em 0F:85F2 só testa `$1F06 & 0x1C != 0`).
* A colocação impressa ao lado do nome do jogador é a **colocação da corrida** no caso de falha A=1 (`$1F00+1`, `build_finish_order` é pulado), mas a **classificação do campeonato**
  em todos os outros caminhos (`build_finish_order` 0F:86E7 lê `$1F62`, então "PLAYER 1  9TH" depois de um país falho significa 9º na classificação).
* O laço de `advance_track` em 0F:875E compara ids adjacentes que são sempre diferentes, então é um `Y=2` constante ("top 3"), não um teste de empate.
* As senhas de um país só são exibidas (nunca exigidas durante o jogo): `0D:C513 + (country-1)*8 + skill*0x38`, veja docs/05.

## 5. A tela de cena ("pódio"): piloto no palanque + mensagem
Não existe pódio com vários carros. A imagem é **um piloto apoiado numa grade na frente de uma parede quadriculada "TG"**, mais uma mensagem de 3-4 linhas e, para 1P, uma etiqueta amarela/preta
`PLAYER 1  <place>` acima do piloto (duas etiquetas e dois pilotos em 2P).
* Os gráficos, todos em `results_flow` 0F:84F5-8532: `0D:AE51` -> VRAM $2200 (tiles do piloto/parede), `0D:C24B` -> WRAM `$7E2000` (uma faixa de tilemap de 8x19 tiles, os *frames* do piloto),
  `0F:BBA7` -> VRAM $1000 (fonte da mensagem). Paleta: `0E:FD66` (`load_results_palette` 0F:8705, 16 cores), fade preto de entrada/saída com `fade_in_dma` / `fade_out_dma`.
* A cena é composta por **`draw_country_flag` 0F:914E** (nome enganoso herdado do menu principal, onde desenha a bandeira do país; aqui A seleciona o piloto): ela escreve
  os tiles da parede com `draw_flag_tiles` (0F:911C, 8 colunas x 19 linhas copiadas de `$7E2000` para o buffer de tilemap do BG `$0C6C+Y`) e depois o piloto com `sub_0F9102` (0F:9102):
  * A = **0 ou 3** (qualificou / completou o jogo): base de tile `$25`, offset da faixa `$0130`: **o piloto comemorando** (braço erguido, coroa de louros verde, garrafa de champanhe);
  * A = **1 ou 2** (falhou): base de tile `$A1`, offset `$0260`: **o piloto triste** (braços cruzados na grade, olhando para baixo).
  Em 2P as duas metades são desenhadas (base de paleta $0D20 para o jogador 2) usando o mesmo A.
* Strings de mensagem (ROM 0F:B1C7..B2F3, formato `draw_string`: byte de linha, byte de coluna, ASCII, 0 ... terminador 0 da lista), 0F:8551 as escolhe com A:

| A | strings | música (`play_music`) |
|---|---|---|
| 0 | "CONGRATULATIONS / YOU QUALIFIED FOR THE NEXT COUNTRY / PASSWORD xxxxxxxx" (B1C7) | 5 |
| 1 | "SORRY / YOU FAILED TO QUALIFY FOR / THE NEXT RACE" (B23B) | nenhuma (a música do menu continua) |
| 2 | "SORRY / YOU FAILED TO QUALIFY FOR / THE NEXT COUNTRY / PASSWORD ..." (B202) | nenhuma |
| 3 | "CONGRATULATIONS / ON COMPLETING TOP GEAR" (B271) + amateur: "BUT CAN YOU WIN ON PROFESSIONAL LEVEL" (B29E), professional: "... CHAMPIONSHIP LEVEL" (B2CA), championship: nada mais | 6 |

  (as etiquetas de colocação são desenhadas por `draw_result_row` 0F:8693 com sufixo ST/ND/RD/TH de `$1FF8`/`$1FFA`; em 2P as duas etiquetas são desenhadas, a ordem depende de qual jogador ficou melhor, não rastreado além disso.)
* Depois `wait_input_long` (0F:9EAC), fade out e a saída dependente de A, acima.

## 6. Ganchos para um hack
* Para tornar uma falha inofensiva (p. ex. um randomizer sem campeonato): alterar `qualify_check_1p` (0F:871A) para `CLC; RTS` e o fim de `advance_track` (0F:8733) para devolver carry limpo. O randomizer já
  contorna tudo isso, veja docs/09 / docs/10 (`0F:8487`: resultados -> menu principal).
* Limites diferentes: a contagem top-5 é o `LDY #$0004` em 0F:871D; a contagem top-3 é o `LDY #$0002` em 0F:8759 (início do laço em 0F:875E; a cadeia de comparação usa Y como último índice).
* Valores de pontos: 10 bytes na ROM 0E:8024 (offset de arquivo 0x70024).
* Cenas diferentes por resultado: A é só o seletor de tabela em `draw_country_flag`; os dois frames de piloto ficam na faixa `0D:C24B` (ids de tile `$25..` / `$A1..`).

## Como reproduzir (receita para agente)
```
TAG=a PLACE=5 TRACK=1 MAXF=6000 tools/mesen.sh scripts/race_end_force.lua | grep -v Uninit      # falha no meio do país (6º)
TAG=b PLACE=0 TRACK=3 MAXF=4300 tools/mesen.sh scripts/race_end_force.lua                         # país passado (1º, só a 4ª corrida)
TAG=c PLACE=4 TRACK=3 PTS="0,0,90,80,70,60,50,40,30,20,0,0,0,0,0,0,0,0,0,0" ...                 # falha de país (9º na classificação)
TAG=d PLACE=0 TRACK=31 DIFF=0 ...                                                                 # completou o jogo
python3 -I tools/contact_sheet.py a 4 330 660 out/a.png                                          # frames out/a_<n>.png como uma grade
```
O script inicia uma corrida real de 1P pelos menus, depois no frame 3300 (na próxima execução de 00:877D, onde M=0 e DP=0 são garantidos) escreve `$1F12` (lista de chegada, o humano em `PLACE`),
`$1F26`, `$1EB0=10`, `$1F00`, pontos `$1F4E` opcionais, `$1F06`, `$1F10` e coloca o PC em 00:8834 (`race_exit`). **Não** coloque o PC a partir de `endFrame`: um NMI é tomado antes e o RTI restaura
os flags M/X antigos, o que decodifica errado os loads de 16 bits (vimos lixo `$1FF6=$0080` assim). Ele imprime o fluxo com hooks de PC (`FAIL_RACE`, `FAIL_COUNTRY`, `WIN_COUNTRY`, `msg0..2`, `set_flag`, `title_screen`, ...)
e linhas `STATE` (`$1F06`, `$1F08`, desbloqueio `$1F0A..`) e aperta A a cada 1,5 s para passar pelas telas de espera por tecla.
