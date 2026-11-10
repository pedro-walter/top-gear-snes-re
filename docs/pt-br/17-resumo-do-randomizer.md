# Resumo do randomizer de Top Gear (BETA 0.5)

Visão geral das features e correções de bugs. Os detalhes técnicos estão em [09](09-plano-do-randomizer.md), [10](10-implementacao-do-randomizer.md) e [13](13-resultados-qualificacao-podio.md).

## Features

**Geração de pistas**
- Cada corrida é uma pista aleatória gerada no próprio console (código 65816) a partir de uma seed hexadecimal de 8 dígitos. A mesma seed gera sempre a mesma pista.
- As pistas têm de 24 a 46 peças e de 3 a 8 voltas, e usam um dos 32 ambientes originais.
- Os geradores em Python e em 65816 foram comparados em 1500 seeds e deram resultados idênticos.
- As placas de curva (chevrons) são colocadas antes de cada curva, e as bandeiras do pit antes da entrada dele.
- Árvores e arbustos preenchem as laterais vazias, usando os tipos do próprio ambiente.
- Há obstáculos: um campo de pedras em cerca de 1 pista a cada 8, e um fechamento de faixa com barreiras em cerca de 1 a cada 16. As frequências foram calibradas pelas pistas originais.
- A seed decide a pista, e a dificuldade escolhida não a altera.

**Pit stop**
- Sempre há um pit, exceto em corridas curtas, de até 129 peças no total, que o carro vermelho termina com um tanque só. Isso vale para cerca de 16% das seeds.

**Menu principal (seis linhas)**
- `1 PLAYER` / `2 PLAYERS`, `DIFFICULTY`, `<n> TRACKS`, `SEED`, `SPEED KPH/MPH` e `PLAY GAME`.
- `TRACKS` vai de 1 a 99 ou infinito.
- `SEED` só fica ativo com 1 pista. Com mais de uma, a linha fica cinza.
- O teclado hexadecimal da seed usa glifos grandes desenhados à mão. A/B digitam, X/Y apagam, e Start confirma.
- Left/Right sorteia uma seed nova.

**Séries de pistas**
- Com 1 pista, a tela de resultados volta ao menu e a seed é mantida para repetir a pista. Não há ranking mundial.
- Com 2 a 99 pistas, ou infinito, cada corrida tem uma pista nova e os pontos de todos os pilotos se acumulam.
- O placar passou a ter 16 bits (até 5 dígitos). No original era 1 byte por carro, que estourava depois de 12 vitórias.
- Séries finitas terminam num pódio com a mensagem "THANK YOU FOR PLAYING!", com a música de "completed Top Gear", e voltam à tela de título.
- Não há game over nem qualificação.

**Interface**
- O minimapa foi substituído por uma faixa de progresso da volta, na barra preta entre as duas telas. Ela mostra as linhas de largada e chegada, pontos para o P1, o líder e o P2/computador, e a marca do pit.
- Há um contador `LAP n/m` abaixo de cada cronômetro.
- A tela de título ganhou céu violeta, o texto "RANDOMIZER BY PEDRO WALTER / POWERED BY CLAUDE" e a versão BETA.

**Outros**
- Os glifos de dígitos grandes (0–9, A, C, E, F) foram desenhados à mão, porque a fonte original não tem 0, 3–9.
- O checksum do cabeçalho é corrigido, e a ROM é distribuída como patch IPS (só os nossos bytes).

## Correções de bugs

**Do próprio gerador**
- **Jogo a 1/4 da velocidade com gráficos corrompidos.** O scanner de objetos lia além do fim da volta. O gerador agora cria uma peça extra.
- **Cenário corrompido** (pórtico de largada e objetos laterais). O pool de VRAM de 8 KB fragmentava. Agora há um conjunto gráfico por pista que cabe inteiro, e o pórtico aparece nos 32 ambientes. Em 1000 seeds do modelo não restou nenhuma peça corrompida.
- **Pórtico sumindo em alguns ambientes**, por causa de tipos de objeto extras. Foi corrigido com uma tabela de tipos a descartar.
- **IPS antigo aplicado pelo Mesen por cima da ROM nova.** O build agora regrava o IPS a cada vez.
- **Fonte pequena:** pixels vermelhos soltos no B, D e 8 foram pintados com a cor do contorno.
- **Lixo gráfico** na seed do menu ao voltar de uma corrida (a fonte não estava na VRAM), corrigido ao guardar os glifos na ROM.
- **Letra cortada** no contador de voltas (o T de "LAPS LEFT").

**Bugs do jogo original**
- **Volta perdida ao colidir perto da linha de chegada** (0.3). Se o outro carro já tinha cruzado a linha, a colisão empurrava o humano para trás dela. Esse caso foi corrigido.
- **Colisão com um carro que já deu uma volta de vantagem** (0.4). O jogador era teleportado para o outro lado da linha e ganhava uma volta indevida. Isso foi corrigido, e a correção só atua perto da linha.
- **Retardatário perto da linha** (0.5). Com P2 no modo single player, o carro perdia todo o progresso da volta. A posição agora fica sempre dentro da própria volta, e há um script de teste unitário (`hitpos_unit.lua`).
- **Fade-out errado** quando um carro reabastecido ainda corria depois que o outro terminou (0.3). Isso foi corrigido.
- **Carro dentro da sequência do pit** passou a contar como "em corrida" no fim da prova.
- **Pontuação** de um byte por carro que estourava (veja Séries de pistas).

## Pesquisa e documentação (sem mudar o jogo)
O repositório também documenta várias coisas que o randomizer não altera: as trocas de marcha ideais ([12](12-trocas-de-marcha-ideais.md)), as diferenças entre os quatro carros ([14](14-diferencas-entre-carros.md)), a comparação entre as ROMs USA, Europa e Japão ([15](15-versoes-da-rom.md)), as mensagens e balões de fala ([11](11-baloes-de-fala-mensagens.md)) e experimentos de economia de combustível ([16](16-economia-de-combustivel.md)).
