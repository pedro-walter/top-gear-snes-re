# Plano do randomizer (rascunho para revisão)

Objetivo: uma ROM com patch em que **toda corrida é uma pista aleatória gerada no console a partir de uma seed hexadecimal**.
As seeds podem ser digitadas (para repetir ou compartilhar uma pista) ou sorteadas. Toda pista tem um pit stop e
3–8 voltas. Os menus são reformulados para seeds; sem minimapa.

Tudo abaixo se baseia nos formatos de dados decodificados (docs/05, 06) e no código de menu lido para este plano.
Os itens marcados **(verify)** são suposições que o primeiro protótipo precisa confirmar.

## 1. O que é uma "pista" neste jogo (por que gerar é viável)

Uma pista de corrida é inteiramente *dado* na WRAM, expandido no início da corrida por `load_track_streams` (00:BF44):

| tabela | conteúdo | como é construída |
|---|---|---|
| `$7E4000` slope | 1 palavra / 32 unidades | por peça de 1024 unidades: byte com sinal -> modelo (33 peças de ladeira, `0C:85D3`) |
| `$7E4C00` curve | 1 palavra / 32 unidades | igual, com 33 modelos de curva (`0C:8591`) |
| `$7E5800` scenery | 1 palavra / 32 unidades | por peça: byte -> um de 38 modelos (`0C:8545`), cada um uniformemente de um *tipo de pista* 0..3 (32 palavras) |
| `$7E6400` objects | 1 palavra / 32 unidades | objetos laterais: `type<<9 | side<<8 | lateral/128`; `0x74xx` = entrada do pit |
| `$0200`, `$1E56`, `$1EF0`, `$1EF2` | comprimento, voltas, posição do pit, lado do pit | descritor, `00:DEA4`, `00:DF24` |

Achados da análise das 32 pistas reais (nesta sessão) que tornam fácil gerar pistas *sensatas*:

* **Os modelos de ladeira e curva são uma gramática minúscula**, não dados livres. Cada modelo começa e termina num *nível*:
  as ladeiras usam os níveis 0, 50, 110, 300, 600, 700, 750, 800, 900, 1000; as curvas 0, 16, 24, 32, 40. Para cada nível há
  *subida de rampa* (0->L), *platô* (L->L) e *descida de rampa* (L->0) (ids de ladeira 1-4, 5-7, 9-13, 14-17, 18-20, 21-23, 24-26,
  27-29, 30-32; ids de curva 1-4, 5-8, 9-16 com variantes curtas de "lombada de uma peça" 17-32 e 13). Um byte de stream negativo
  espelha o modelo (descida / direção de curva oposta). As pistas reais são exatamente caminhadas nesse grafo
  (`[-9, -12, -12]` e depois volta para `[-11, ...]`: as ladeiras continuam através do limite da volta).
* **"Começar e terminar na mesma ladeira/direção" é, portanto, uma regra rígida fácil de impor:** o nível no fim
  da última peça deve ser igual ao nível no início da primeira peça (simplesmente fazemos os dois 0 = plano/reto, ou permitimos
  qualquer nível e rotacionamos o stream – as pistas reais fazem as duas coisas).
* Os tamanhos das tabelas permitem até **48 peças** (`$4000-$4BFF` etc.); as pistas reais usam 23-46.
* Os modelos de cenário são uniformes por peça (um tipo de pista), então um "perfil de pista" é só uma sequência de tipos, p. ex.
  `1 1 1 2 2 2 1 1 0 0 ...`. A peça 0 é sempre o modelo de largada/chegada (5, ou 22 para a Escandinávia).
* **Pit stop = modelo de cenário 20 (tipo de pista 3) ou modelo 2 (tipo de pista 2) por uma peça**, mais a info do pit `00:DF24`
  = `0x8000|side` + `(piece_start - 512)/2` (as 13 pistas originais com pit seguem isso), mais uma palavra de objeto `0x747C`
  (tipo 0x3A, bit de lado, lateral 124) na segunda metade dessa peça. O carro do computador já encontra o pit por
  `$1EF0/$1EF2`.
* O ambiente (gráficos de horizonte, paleta, larguras de pista, script de dia/noite, offsets de velocidade dos bots) é indexado por `$1F06` por meio de
  tabelas de 32 entradas. **Truque: manter `$1F06` = um "id de ambiente" (qualquer um dos 32 originais) e substituir só
  a geometria.** Assim iluminação (p. ex. noite), gráficos e dificuldade dos bots continuam funcionando sem dados novos.

## 2. Arquitetura

```
seed (32 bits, 8 dígitos hex)
  -> PRNG (xorshift/LCG próprio, não o $1FF4 do jogo, para a seed ser reproduzível)
  -> id do ambiente (0..31)         -> $1F06 (todas as tabelas por pista existentes continuam funcionando)
  -> número de peças N (24..46 ?)   -> $0200 = N*1024
  -> voltas 3..8                    -> $1E56
  -> caminhada de ladeira, de curva -> $7E4000 / $7E4C00 (palavras de modelo copiadas do banco 0C)
  -> caminhada de tipo de pista + peça do pit -> $7E5800, $1EF0, $1EF2
  -> objetos laterais + objeto do pit -> $7E6400
```

* O gerador é uma **rotina nova em 65816** que substitui o corpo de `load_track_streams` (00:BF44) — nenhum stream
  é escrito, as tabelas expandidas são produzidas diretamente. Ela lê as tabelas de ponteiros de modelos do banco 0C.
* O código mora em **novos bancos de ROM 10-1F** (ROM expandida para 1 MB: byte de tamanho do header + checksum). Só existem ~6 KB de
  padding zerado no original, o que é apertado demais. **(verify: Mesen, bsnes e flash carts comuns aceitam LoROM de 1 MB
  sem outras mudanças.)**
* **Ferramentas:** não há assembler instalado; escrever um pequeno assembler de 65816 em Python (`tools/asm65816.py`, a tabela de
  opcodes já existe em `tools/disasm.py`) para que o build precise só de Python. Saída = ROM com patch e um **patch BPS/IPS**
  (o repositório fica livre de dados do jogo; os usuários aplicam o patch na própria ROM).
* O **gerador de referência em Python** (`tools/trackgen.py`) implementa o mesmo algoritmo bit a bit; a versão em 65816
  é testada contra ele com milhares de seeds usando uma pequena ROM de teste rodada headless no Mesen (comparando
  as tabelas da WRAM). A versão em Python também renderiza cada seed com `track_atlas` para inspeção visual.

## 3. Regras do gerador (pistas "sensatas")

1. **Comprimento:** N peças, p. ex. 24..44; voltas 3..8 (uniforme). Opcionalmente as voltas são enviesadas por N para que o tempo total
   de corrida fique razoável (questão em aberto).
2. **Ladeira:** caminhar no grafo de níveis. Nível inicial = nível final (padrão plano). Sequência de "eventos": trecho plano de 1-8
   peças, ladeira pequena (modelos de lombada 2, 8, 10, 13, 14), ladeira longa = subida de rampa + k platôs + descida de rampa, com o sinal sorteado
   por evento. O nível máximo depende de um sorteio de "montanhosidade" por pista (então a maioria das pistas é suave, algumas são tipo Loch Ness).
   Restrição: dois eventos de nível máximo não seguidos; subida total ~ descida total (**verify** se o jogo se importa; a ladeira só
   muda a velocidade, então não é obrigatório).
3. **Curva:** a mesma gramática com níveis 16/24/32/40; chicanes (uma lombada seguida da lombada espelhada), grampos
   (lombada de uma peça 17-32), curvas longas. Reta no começo/fim para que o limite da volta seja suave. Um "orçamento de curvas" mantém
   a curvatura líquida com sinal perto de zero (um circuito fechado gira ~360 graus; não é necessário para a física, só para a plausibilidade).
4. **Tipos de pista:** sequência de tipos, na maior parte constante com estreitamentos/alargamentos ocasionais (0<->1<->2), peça 0
   = modelo de largada. **Exatamente uma peça de pit**, não nas 3 primeiras/últimas peças, lado sorteado pela seed.
5. **Info do pit:** `DF24 = 0x8000*side | ((piece*1024 - 512)/2)` equivalente; objeto do pit `0x747C` (bit de lado ligado para esquerda)
   na segunda metade da peça do pit. O tipo do pit (2 ou 3) e seu estilo de pista precisam ser largos o suficiente no ambiente escolhido.
   **(verify por ambiente)**; ambientes sem um tipo utilizável têm a palavra de estilo de pista alterada
   (`00:DEE4`), que é dado simples.
6. **Objetos:** por peça 10-20 objetos (densidade original), alternando lados com espaçamento aleatório, tipos sorteados do
   conjunto de tipos de objeto do próprio ambiente escolhido (p. ex. 27/28/9/38 para o deserto), lateral na faixa original
   (60..206), nenhum dentro da peça do pit exceto a entrada do pit, nenhum na peça 0 (o pórtico é um objeto de grupo `0x8002`
   na posição 0).
7. **Ambiente:** sorteado entre os 32; New York continua noturna, Hiroshima noite->dia etc. automaticamente.
8. **Dificuldade/bots:** inalterados (`00:DDE4[env]`).

## 4. Menus

A leitura de `0F:918B` (menu principal), `0F:943D` (entrada de texto), `0F:821D` (tela de localização) mostra o que precisa mudar:

| mudança | onde | abordagem |
|---|---|---|
| COUNTRY -> `RANDOM` / `SEED` | entrada 2 do menu principal (`0F:929E`, string em `0F:A6CD`) | Left/Right alterna como as entradas 0 e 3; `RANDOM` = sorteia seed baseada em `$1FFC` ao PLAY GAME, `SEED` = abre a entrada de seed com A |
| tela de entrada da seed | reutilizar `text_entry` (`0F:943D`) com um **teclado hex**: 16 teclas + DEL + END em vez de A-Z | as strings da grade são tabelas de texto simples em `0F:A792`.. ; só o wrap do cursor/limites e o mapeamento tecla->char mudam (o buffer de 8 caracteres `$68..$6F` é exatamente uma seed hex de 8 dígitos) |
| tela de splash/localização | fluxo de `0F:815A`, `0F:8A81`, `0F:8ADC` | trocar o texto de cidade/país por `SEED  XXXXXXXX`; STATISTICS mostra voltas (geradas) e distância; pular o upload do minimapa (`0F:821D/82F0`); manter ou tirar a linha de recorde de volta |
| maquinaria do campeonato | `0F:8733`, senhas `0F:93DC` | desativada: sem desbloqueio de países, sem senhas; depois de uma corrida a mesma tela volta com a seed (repetir) ou uma seed nova |
| minimapa do HUD da corrida | upload de tiles nos loaders + `update_map_dots` | apagar os tiles do mapa; os três sprites marcadores são reaproveitados como pontos de progresso da volta na barra preta (docs/10, `src/bar.asm`); **opcional depois:** desenhar um minimapa procedural a partir dos dados de curva (integração de direção) |

Teclado hex proposto (a refinar com seu feedback sobre a distribuição de letras; a grade original tem 6 colunas com
`END` e duas células de glifo para espaço/apagar):

```
0 1 2 3
4 5 6 7
8 9 A B
C D E F
< DEL   END
```

## 5. Marcos (cada um verificado automaticamente no Mesen headless)

1. **M0 ferramentas:** assembler, expansor/patcher de ROM com correção de checksum, ROM de teste, saída BPS.
2. **M1 gerador Python + atlas:** gerar 1000 seeds, validar regras (níveis encadeiam, início/fim iguais, um pit, tamanhos),
   renderizar uma folha de contato.
3. **M2 gerador 65816 + hook no loader:** substituir `load_track_streams`; o harness prova WRAM == Python em 1000 seeds.
4. **M3 a corrida funciona:** fixar uma seed, dirigir/piloto automático por uma volta no Mesen headless (estilo do `trk_drive.lua` existente): velocidade, voltas,
   posição, **o carro do computador para no pit, o gatilho do pit humano funciona**, tela de resultados, sem travar, 20 seeds x 3 ambientes.
5. **M4 menus:** alternância SEED/RANDOM, entrada hex, tela de splash, sem minimapa; passeio roteirizado pelo menu com screenshots.
6. **M5 acabamento:** balanceamento (combustível vs comprimento, voltas), minimapa procedural opcional, modo demo/attract com seeds aleatórias,
   README + release do patch.

## 6. Riscos / incógnitas

* Se todo ambiente tem um tipo de pista largo o bastante para uma pit lane convincente (**M1/M3**); alternativa: alterar as palavras de estilo.
* Combustível vs comprimento da corrida: 8 voltas de uma pista de 46 peças é muito mais longo que qualquer corrida original; o pit stop foi projetado para
  ~3-8 voltas de 23-46 peças, então deve mais ou menos funcionar; ajustar no M5.
* Os conjuntos de tipos de objeto por ambiente e seus tratadores de colisão (`05:F5C3[type]`) são reaproveitados como estão — risco baixo.
* O rascunho de WRAM do gerador (precisa de ~100 bytes) não pode colidir com variáveis do jogo: usar o banco `$7F`.
* O comportamento de uma imagem LoROM de 1 MB em hardware real/flash cart não foi testado (emuladores ok).
* O modo 2 jogadores, o modo demo (`90E6`) e o laço attract passam todos por `$1F06`: precisam apontar para uma seed também.

## 7. Decisões (dono, 2026-10-16)

1. Depois de uma corrida, **voltar ao menu principal**. Sem pontos de campeonato acumulados: mostrar só os tempos e
   pontos daquela corrida. A seed continua selecionada (repetição) até ser alterada no menu.
2. Seed = **8 dígitos hex** (32 bits).
3. O layout do teclado hex (seção 4) está aprovado.
4. **Reutilizar os 32 ambientes originais**; sem ambientes novos.
5. **ROM de 1 MB** é aceitável.
6. O formato de distribuição fica para depois; foco primeiro num protótipo funcional.

Status: a implementação começou e o protótipo funciona – veja docs/10-randomizer-implementation.md.
