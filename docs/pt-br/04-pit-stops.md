## Pit stops
* Gatilho (jogador 1, 05:D75E–D7C0; computador/jogador 2 espelham em 05:DFB8–E03A, 05:F0xx): ao passar sobre um objeto lateral do tipo **0x74xx** (entrada do pit; palavra de `$7E6400` & 0xFE00 == 0x7400) no lado lateral correspondente,
  e se o estado `$1E86` (P1) / `$1E88` (P2) ainda não for negativo, `$1E86 = 0xFFFF` inicia a sequência do pit. Se o combustível for 0, então `$1EB4 |= 1` (P1) / 2 (P2).
* Máquina de estados `00:90CC` (estado = ~`$1E86`; cada passo faz `DEC $1E86`): 0 monta a cena do pit (`$40 = 0xFFFF` = modo pit, `$A8 = 0x280`, marcha 4, velocidade `$1E5A = $1700`, cópia de paleta),
  1 espera, 2 `$E1=1`, `$14=0` (entrada ignorada), 3 espera acelerar (`$1F76`) com combustível != 0 -> **pula o reabastecimento**, 4 **reabastece**: `fuel += 0x7F` por frame até `0xA7FF`
  (cerca de 340 frames) – apertar acelerar (com combustível != 0) sai antes, 5 sai dirigindo até `$A8` ficar em 0x300..0x37F, 6 restaura, 7+ libera: limpa `$40`, limpa o bit 0x20 de `$1EF5` (sem empuxo).
  O carro do computador faz o mesmo com `$1E88`/`$1E64` (00:9222..9380); no modo 1 jogador (`$1F04 == 0`) ele não precisa de botão e sai sozinho.
* **O computador (IA) decide parar no pit** (05:F1AF..F1BF e `sub_05F79F`): só considera quando seu combustível `$1E64 < 0x3000` (28 % de um tanque cheio) **e** `sub_05F79F(X=0x3D)` diz que não consegue terminar:
  `needed = (track_len/2 * (laps_total - laps_done) - position/2) * X  *2  >=  fuel`. Se sim, ativa o bit 0 de `$1EF2` e se guia pelas tabelas estreitas do **corredor da pit lane** `00:E166/E198` (limites
  esquerdo/direito pela distância a partir de `$1EF0`) em vez do corredor da pista, de modo que é afunilado para o objeto de entrada do pit.
  Enquanto reabastece (05:EDC5, estado `$1E88 == 0xFFFA`) ele sai assim que `sub_05F79F(X=0x50)` diz que o combustível basta para terminar a corrida (ou seja, *nem sempre* enche o tanque).
  Numa corrida normal de 3 voltas na pista 0 ele gasta ~22 000 de 43 007 unidades e nunca para.
