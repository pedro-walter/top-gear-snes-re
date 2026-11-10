# Descobertas da sessão 3 (sessão sem supervisão) – oponentes, pistas, nitro, pit stops, HUD

Tudo isto foi lido no disassembly e depois conferido em execuções headless do Mesen
(`scripts/*.lua`, auxiliares compartilhados em `scripts/common.lua`; scripts de análise em `tools/`).

## Velocidade no HUD (o contador digital vermelho)
`sub_00CE61` (00:CE61) o desenha: `km/h = (speed * 24) >> 10`  (`speed*3/128`, ou seja, 1 km/h = 42,67 unidades; a estimativa anterior de 41,7 estava um pouco errada).
Implementado com o multiplicador da PPU: `$211B` = velocidade (16 bits), `$211C` = **24** (km/h) ou **15** (milhas: 15/24 = 0,625 = 1/1,6) e o resultado
`$2135 >> 2`. Qual unidade: `$1FF6` negativo => 24; senão `$1FB0` (jogador 1) / `$1FB1` (jogador 2) diferente de zero => 24, zero => 15 (mph). O resultado é
separado em dígitos com o divisor de hardware (`$4204/$4206` /10 duas vezes) e os glifos dos dígitos (4 palavras cada) da tabela em `00:D666 + digit*8` são enviados por DMA/escritos
na VRAM `$0C5B/$0C7B` (unidades), `$0C59/$0C79` (dezenas), `$0C57/$0C77` (centenas); o jogador 2 usa `$0E1B...`.
Exemplo: SPD 5359 -> 5359*24/1024 = 125 (o usuário viu 124).

## Carros: a "lista de corrida" de 20 entradas (base WRAM $0200, 18 bytes por carro)
* `$0200` = **comprimento da pista** em unidades de posição (`(w0 & 0x3F) * 1024`, 22528 para a pista 0).
* A lista fica em `$0212 + 18*j`, j = 0..19 (20 carros = 18 bots + 2 slots de "jogador"). O slot (offset X, 0..0x156) dos dois carros humano/computador está em
  `$0204` (jogador 1) e `$0206` (jogador 2 / o carro do computador). O código usa DP=$0200, então os offsets aparecem como `$19,X`.
* A lista é mantida **ordenada por progresso** com uma troca de bubble-sort por frame (`00:A1BD`, o código de troca A276–A2B4 troca 8 palavras; a 9ª palavra (+0x10) é por slot e não é trocada).
  Endereço maior = mais à frente (slot 19 = líder).
* Registro por carro (offsets a partir da base da entrada):

| off | significado |
|---|---|
| +0 (word) | 5 bits baixos = id do carro 0..19; 7 bits altos = código de sprite/paleta (0x44 / 0x64 / 0x04 / 0x20...) usado pelo construtor de OAM (`01:8000`, `00:ABFC`) |
| +2 | posição lateral (16 com sinal, 0 = centro da pista; os limites da pista são +-~0x2800) |
| +4 | velocidade lateral (com sinal). Os bots a mantêm constante e só quicam: quando a posição lateral sai do corredor da pista `$7E7000[pos>>4]` (dois bytes com sinal: limites esquerdo e direito, escalados x256) o sinal inverte (00:AC9C..ACD3) |
| +6 / +7 | progresso de 24 bits: byte +6 fração, word +7 = progresso em unidades, dá a volta em `$0200` (comprimento da pista) |
| +9 | contador de voltas (byte); comparado com `$1E56` (= voltas da corrida, `$DEA4[track]` = 3 para a pista 0) |
| +A | velocidade (word). progresso += velocidade * `$1E90` (o multiplicador, 00:A18D) a cada frame |
| +C | aceleração, +E temporizador: enquanto timer>0, speed += accel e timer--; em 0 a aceleração é zerada (rampa usada na largada) |
| +10 | rascunho por slot (zerado a cada frame em 00:A1B5) |
* Quando um carro cruza a linha na última volta (lap == `$1E56`) seu id é anexado à lista de chegada `$1F12[$1EB0++]` e o tempo atual `$1EAE` é guardado em `$1F26[id*2]`
  (00:A1D6..A223, também 00:AB7A para a simulação do fim da corrida). `$1EB0` = número de carros que terminaram. (`$1EB0 >= 10` => estado de resultados/"corrida acabou"; a física pula a força do motor.)

### Grid de largada / parâmetros dos bots (init da corrida `00:A558`)
* O modelo de cada carro é copiado da ROM `00:A732 + 18*k` (k = 0 jogador 1, 1 jogador 2, 2..19 bots). Bots k=2..19 (ordem de largada, de trás para frente):
  (id 6, base 2117, mult 32, ramp 8) (id 9, base 2467, mult 32, ramp 8) (id 3, base 3527, mult 32, ramp 8) (id 7, base 2624, mult 32, ramp 8) (id 10, base 3109, mult 32, ramp 8) (id 12, base 3328, mult 32, ramp 8) (id 8, base 2979, mult 16, ramp 16) (id 5, base 3136, mult 16, ramp 16) (id 19, base 3456, mult 16, ramp 16) (id 11, base 3015, mult 16, ramp 16) (id 16, base 1920, mult 16, ramp 16) (id 18, base 2246, mult 10, ramp 24) (id 2, base 3398, mult 10, ramp 24) (id 13, base 3493, mult 10, ramp 24) (id 17, base 2114, mult 10, ramp 24) (id 15, base 2726, mult 8, ramp 32) (id 4, base 3145, mult 8, ramp 32) (id 14, base 2561, mult 8, ramp 32)
  (id = id do carro 0..19, base = velocidade base, mult/ramp = multiplicador de aceleração e frames de rampa; os ids 0/1 são os dois slots humano/computador).
* A posição lateral inicial é -7680 / 0 / +7168 num padrão repetido (3 faixas), o progresso inicial = `$0200 - 0x2A0 + 0x20*k` (os bots largam espalhados em 0x20 unidades).
* **Velocidade de cruzeiro do bot** = `base + 2*rand(0..255) + diff_offset(track, difficulty)`, com `diff_offset = word[$DDE4 + track*6 + difficulty*2]`
  (pista 0: 0 / 80 / 160, pista 1: 128 / 416 / 704, pista 2: 160/568/976 ...; 16 pistas x 3 words – por isso dificuldade maior deixa os bots mais rápidos). A velocidade é atingida
  pela rampa (accel = (esse valor * multiplicador)>>8 por `timer` frames) e depois nunca muda (sem rubber-banding nos 18 bots).
  Velocidades de bot observadas durante a corrida: 2001..3769 unidades (47..88 km/h equivalentes em unidades de progresso; note que o *progresso* é velocidade * `$1E90`).
* Velocidade lateral do bot = +-(100 + rand(0..255)), sinal aleatório: eles varrem a pista da esquerda para a direita a velocidade lateral constante e quicam nas bordas.
  Esse é o "serpentear" – os bots nunca olham para o jogador.
* RNG: `00:A89E` – LCG em `$1FF4`: `seed = 13*(seed+7)`, devolve o byte `hi ^ lo` (opcionalmente escalado por A+1 via multiplicador da PPU). Mesma seed => mesma corrida.
* Um bot alcançando um carro humano por trás: 00:A2C4 -> `bump_p1`/`bump_p2`. É uma **troca de velocidades, não uma divisão pela metade** (o `LSR $1E5A` é uma conversão de unidade: `$1E5A` é 2x a unidade de velocidade do bot). Veja "Colisões" abaixo.
* O carro humano também é *bloqueado* por um carro à frente: `05:E9AF` (P1) / `05:F174..` (P2) encolhem o corredor lateral permitido `[$1A,$1C]` em torno de qualquer carro a até 0x200 unidades à frente
  (limites do corredor vêm de `$7E7002[pos>>4]`), empurrando você para o lado em vez de deixá-lo atravessar.

### Posição (1º..20º)
`sub_00AA79` calcula a posição do slot X: começa em 21 e decrementa para cada um dos 20 slots cujo (byte de volta, índice do slot) é menor que o nosso => posição = 1 + número de carros
estritamente à frente em (volta, ordem da lista). Como a lista é ordenada por progresso, isso é igual à posição real na corrida. Guardada em `$1E7A` (jogador 1, **base 0**: 0 = 1º, 19 = 20º) e `$1E7C` (jogador 2) (00:A233/A23C).
(`$1F00/$1F02` guardam a posição final do jogador depois da chegada.)



## RNG e comportamento de retardatários (investigado com `scripts/bots_probe.lua`, ROM original)
* **Usuários do RNG** (`00:A89E`, só 7 chamadores): escolha de cores dos carros no título (`00:815E/816A`, 2 sorteios), **race_init** (2 sorteios por bot = 36: variação de velocidade, depois magnitude da velocidade lateral; o sinal vem do bit 0 do mesmo sorteio), e variantes de som no código de batida (`00:B3F2`, `05:E99F`). Nada no laço da corrida sorteia aleatoriedade: o comportamento dos bots é totalmente fixo depois que race_init roda.
* `$1FF4` só é *escrito* por `rng` e pelo modo attract (`0F:90F8`, semeado de `$1FFC`). Começa em 0 no Mesen (o primeiro sorteio dá `$005B = 13*7`), então depois de um boot novo a primeira corrida é sempre a mesma. As corridas seguintes dependem de quantos sorteios aconteceram antes. Os 36 sorteios de race_init são, portanto, toda a "aleatoriedade" de uma corrida.
* **Os bots existem durante toda a corrida**: 18 bots são criados em race_init e nunca surgem/somem. A velocidade deles é fixa depois da rampa de largada (verificado: constante em 17 de 18 bots por 500 frames). O jogador largua no slot do grid da posição final anterior (`final_pos*18` na lista de carros).
* **Os bots nunca se tocam** (o teste de colisão em `00:A2C4` só dispara quando o carro à frente na lista tem velocidade 0, ou seja, um carro humano).
* **O movimento lateral só é simulado perto do jogador** (`update_bot_cars` 00:ABFC, `update_visible_cars_p2` 00:AEF3). A cada frame ele pega os carros de 16 unidades atrás de um carro humano até 0x400 (1024 unidades = 32 slots de pista) à frente, faz `lateral += lateral_speed` e quica no corredor `$7E7000`. Exceção: o primeiro carro no início da janela ou depois dele é sempre atualizado, por mais longe que esteja. Todo o resto fica congelado: sem recuperação, então um carro que reentra na janela continua da posição lateral e direção antigas. Medido: dentro da janela o lateral mudou em 32% dos frames (o jogo avança cerca de um tick a cada três frames), fora 0%, exceto o carro mais próximo à frente (e, em 1P, a mesma regra em torno do carro ocioso do jogador 2).
* A janela também alimenta a lista de desenho (`$178A` profundidade+0x80, `$178C` lado/lateral, máx. 20 entradas); o renderizador da pista na WRAM (`7E:2D6F`) emite um carro quando sua profundidade está abaixo do slot que ele está percorrendo (`CMP $8E`).
* **Não há lógica que mantenha os bots longe do jogador.** Na pista 0 (22528 unidades, 18 bots) a janela cobre cerca de 4,5% da volta, então com o pelotão espalhado você vê 0-1 bots na maior parte do tempo (0 na janela em 87% dos frames da execução de teste, cujo piloto era tosco: só acelerava, sem direção). Só o grid da largada enche a janela (os 18 carros). Pistas mais longas deixam isso mais esparso.
* **O contato jogador-bot transfere velocidade** (`05:E944`, `05:E970..E99E`): o bot tem sua velocidade empurrada em direção à do jogador, e uma aceleração de -(delta)/64 por tick durante 64 ticks (`$0220 = 0x40`) para voltar suavemente à sua velocidade de cruzeiro. Observado: um bot em 2001 pulou para 3072 e decaiu 17 por tick de volta a 2001 em 63 ticks.

### Detalhes do RNG, parâmetros dos bots e o grid de largada (complemento)
* `rng` é um gerador congruencial linear de 16 bits: `seed = 13*seed + 91 (mod 65536)` (13-1 é divisível por 4 e 91 é ímpar, então tem o período completo de 65536). O byte devolvido é `hi ^ lo` da *nova* seed; com A != 0 ele é escalado para `0..A` pelo multiplicador da PPU. Toda chamada avança a seed, então a sequência é totalmente determinada pela seed e pela ordem das chamadas.
* Por bot, race_init sorteia duas vezes: (1) variação de velocidade `j = rand(0..255)`: velocidade alvo `S = template_base + 2*j + diff_offset`, depois accel = `S*mult >> 8` por `ramp` ticks (mult*ramp é 256 em três dos quatro grupos de modelo, 240 no grupo dos ids 18/2/13/17, então a velocidade final é cerca de `S`, 0,94*S nesse grupo); (2) velocidade lateral `100 + rand(0..255)` unidades de posição por tick, negativa quando o bit 0 está ligado. Os dois sorteios são independentes, e também velocidade e velocidade lateral (correlação medida nos 18 bots: -0,18, não significativa). A impressão de que bots rápidos serpenteiam menos vem da distância: um carro mais rápido cobre mais pista por varredura lateral.
* Grid de largada: race_init copia os 20 modelos em ordem e põe o jogador no slot `final_pos*18` da lista, onde `$1F00` é a posição (base 0) da chegada anterior (0 = venceu, 19 = último); o slot 0 é o lugar mais atrás do grid. Então o grid é invertido: vencer te põe no fundo, chegar em último te põe na pole. `$1FF2` é 0 só até o primeiro carregamento de pista após o boot, então a primeiríssima corrida largua no fundo. O randomizer não toca `$1F00`/`$1FF2` nem race_init e se comporta de forma idêntica (conferido com `scripts/rando_grid.lua`: posição anterior 0/5/19 dá slot 0/5/19 nas duas ROMs; uma chegada em último guardou `$0013`).

### Quando a seed do RNG muda (`scripts/rng_watch.lua`, ROM original)
* `$1FF4` fica dentro da área persistente `$1F00-$1FFF`. No reset o código verifica um valor mágico (`$1F91 + $1FAE == $7543`, `00:8101`); se estiver errado a área inteira é zerada (`00:8110`, inclui a seed). A RAM ao ligar falha na verificação, então um **boot a frio começa a seed em 0**; um reset suave a mantém. Escritas registradas: duas no boot (`00:8113`, a limpeza), depois só o próprio `rng` (`00:A8BA`).
* **Escritores**: a limpeza do boot, `rng`, e o modo attract (`0F:90F8`, seed := contador de frames `$1FFC` quando a demo ociosa começa). Nenhum código de menu a escreve (busca estática de todas as escritas indexadas em `$1Fxx`; nenhuma alcança `$1FF4`). Escolher 1P/2P, nomes, câmbio, controles, carro, dificuldade ou país não toca na seed (o passeio por script só cobriu start/down/A; o resto vem da busca estática).
* **Sorteios**: `race_init` 36 por corrida (2 por bot); variantes de som de batida (`00:B3F2`, `05:E99F`) alguns por contato; as escolhas de cor dos carros em `00:815E/816A` só rodam no caminho da demo (`$1FF6` ligado), não no jogo normal.
* **Consequências**: a seed nunca é reiniciada entre corridas. A primeira corrida depois de um boot a frio (sem demo antes) tem sempre as mesmas variações de velocidade/velocidades laterais/direções de serpenteio dos bots. A corrida n+1 começa da seed deixada pela corrida n, então depende do número de sorteios de som de batida, isto é, de como o jogador dirigiu. Esperar no título até a demo rodar re-semeia a partir do contador de frames e torna a próxima corrida dependente de timing.
* **Reset do grid** (não é o RNG): `0F:84CB` / `0F:84E1` colocam a posição final anterior em 0/1 (fundo do grid) quando o humano terminou fora das posições de classificação (`qualify_check_1p`) ou depois que `advance_track` sinaliza o fim do campeonato (lido no código, não rastreado na GUI).
* O randomizer não toca `$1FF4` (seu gerador de seed é separado), então o mesmo comportamento vale para ele. Ideia, não feita: semear `$1FF4` a partir da seed da pista para pelotões de bots reproduzíveis.


## Colisões (medidas com `scripts/collide_hooks.lua`, `collide_probe.lua`, `collide_exp.lua`)
Unidades de velocidade: `$1E5A` (jogador) é **2x** a unidade de velocidade do bot (o jogador avança `$1E5A/2*delta`, um bot `speed*delta`). Nada abaixo danifica o carro; todo contato é uma mudança de velocidade, uma flag de som (`$1EF5 |= 0x80`) e às vezes um chute lateral.
**Não há contato lateral entre carros**: os dois testes de carro disparam só no tick em que o progresso de um carro alcança o do outro, e só se a distância lateral for pequena o bastante.

| Evento | Onde | Condição | Efeito |
|---|---|---|---|
| Jogador alcança um bot à frente | `05:E3D6..E584` -> `sub_05E8E9` | pos do jogador + 7 >= pos projetada do bot; jogador mais rápido (`2*bot < $1E5A`); distância lateral < 0x800 em meias unidades = **4096** unidades | **troca de velocidades**: o jogador fica com `2*bot_speed` (rampa pendente não incluída), o bot salta para ~jogador/2 (arredondado a 64) e depois volta suavemente à velocidade antiga a `-delta/64` por tick durante 64 ticks. Pos do jogador := pos do bot - 8, som de batida. **Sem chute lateral, sem bloqueio de direção.** Medido: 5925 vs bot 2001 -> 4002. |
| Bot alcança o jogador por trás | `00:A2C4` -> `bump_p1` | progresso do bot >= o do jogador; distância lateral < 0x800 em unidades inteiras = **2048** (metade da janela acima); fora do pit, velocidade do jogador não negativa | **troca no sentido oposto**: o jogador fica com `2*bot_speed` (um *impulso* se o jogador estava mais lento), o bot fica com jogador/2 (arredondado) e volta suavemente em 64 ticks; o bot é colocado na posição do jogador. Medido: jogador 2023 -> 7538, bot 3769 -> 953 depois +44 por tick. A velocidade então se dissipa pelo arrasto normal, não é limitada à velocidade máxima da marcha. |
| Jogador vs carro do computador / humano 2 | `05:E524..E569`, `E703..E763` | mesmos testes | mesma troca mais um empurrão lateral `steer = -8 * distância lateral` |
| Objeto na beira da pista, classe **REV** | `05:F6B3` | lateral da palavra do objeto vs lateral do jogador, veja limiares | `speed = -min(speed/2, 1600)` (ou seja, ré, no máximo -37 km/h), distância à frente 0, som de batida. Medido 5924 -> -1600, volta a positivo após ~3 ticks, depois aceleração normal a partir de ~0 (cerca de 1,3 s para voltar a 3000). A variante do som de quique é escolhida com o RNG quando speed >= 0x1770. |
| Objeto classe **EDGE** | `05:F6F5` -> `F6FA/F6FF` | igual | velocidade e distância à frente pela metade; ângulo de direção forçado a +-0x5000 **em direção ao centro da pista** (sinal da lateral do jogador), entrada de direção travada (`$1EEC = 0x600`, o ângulo decai 0x600 por tick, ~14 ticks). O deslocamento lateral por tick é limitado pelo limite de direção (`$1E92/$1E94`), então em alta velocidade o chute costuma ser um empurrão de ~1100 unidades e o bloqueio acaba cedo; em baixa velocidade ele se desenrola por completo (~6500 unidades vistas). |
| Objeto classe **SIDE** | `05:F6F1` | igual | igual ao EDGE, mas o chute é **para longe do objeto** (para o lado de onde você o acertou). Só os tipos 21 e 58. |
| Objetos de grupo (pilares do pórtico, túnel) | `05:ED3A` | faixas laterais de `00:A15F/A167` | comportamento REV (velocidade -> -min(speed/2,1600)). |
| Paredes de túnel/ponte | `05:D808..D838` | só enquanto `$1EBE` está ligado pelos marcadores de grupo C004/C006 | lateral limitada ao limite, chute EDGE (+-0x5000, bloqueio, velocidade pela metade). |
| Fora da pista (sem parede) | `05:D83B` | `|lat|` além do limite do cenário (`$017B/$017D` em `[scenery word]`, p. ex. +-10229) | a cada tick `speed -= speed*6/256` (cerca de 7% a cada 2 ticks, medido) |

Classes de objeto por tipo (tabela P1 `05:F5C3`, tabela P2 `05:F63B`, idênticas): **EDGE** = 5-10, 13, 15, 27, 38, 42; **SIDE** = 21, 58; **REV** = todos os outros tipos 0-59. Cada objeto é testado uma vez, quando a posição do carro cruza seu slot de 32 unidades (cerca de 64 unidades à frente da referência do carro), **sem dependência de altura ou velocidade**. Meia-largura de acerto (lateral do jogador vs lateral do objeto, em unidades `$1E8A` = 2x o valor da tabela): direita `A05F[type]`, esquerda `A0DF[type]`: 2048 para a maioria dos tipos (ou seja +-4096), 1536 para 8-10/13/21/45/59 (+-3072), 1792 para 6/7 (+-3584), 1024 para 27/28/38/39 (+-2048), 768 para 24, 512 para 11/12/15/41/42/56(direita), 256 para 22(direita)/23(esquerda). Assimétricos: 22 (D 256, E 2048), 23 (D 2048, E 256), 40 (E 1536), 54 (D 768, E 1792), 55 (D 1792, E 768), 56 (D 512, E 1792), 57 (D 1792, E 512), 58 (D 1024, E 512).

Notas
* "Ser atingido por um retardatário por trás" é na verdade *qualquer bot que te alcance*: com a troca você sai com o dobro da velocidade dele, então ser atingido enquanto está lento (depois de uma batida, na saída do pit) é um aumento grátis de velocidade de até ~176 km/h, e o bot fica estacionado na sua velocidade por um momento. Bater na traseira de um bot custa só `speed - 2*bot_speed`.
* Um bot serpenteando para o seu lado quando você está ao lado dele não faz nada; o contato só acontece no cruzamento de progresso.
* A rampa de largada pendente do bot é somada à nova velocidade do bot, mas não ao que o jogador recebe.
