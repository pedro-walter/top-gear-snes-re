## Nomes das pistas (sessão 4) — `tools/names.py`
Os nomes vêm da tabela de ponteiros `0D:C77C[track]` -> texto da tela de localização no banco 0F (`0F:81AB`); país = track>>2 (EUA, América do Sul, Japão, Alemanha, Escandinávia, França, Itália, Reino Unido). Confirmado no emulador: $1F06=2 mostra **NEW YORK, U.S.A** na tela de localização e a corrida é a corrida noturna na cidade; $1F06=0 é a corrida no deserto (Las Vegas); 9 = Hiroshima (começa ao entardecer). 4 = Rio tem o túnel perto da largada.

```
0 Las Vegas (USA)
1 Los Angeles (USA)
2 New York (USA)
3 San Francisco (USA)
4 Rio (Brazil)
5 Machu Picchu (Peru)
6 Chichen Itza (Mexico)
7 Rain Forest (Brazil)
8 Tokyo (Japan)
9 Hiroshima (Japan)
10 Yokohama (Japan)
11 Kyoto (Japan)
12 Munich (Germany)
13 Cologne (Germany)
14 Black Forest (Germany)
15 Frankfurt (Germany)
16 Stockholm (Sweden)
17 Copenhagen (Denmark)
18 Helsinki (Finland)
19 Oslo (Norway)
20 Paris (France)
21 Nice (France)
22 Bordeaux (France)
23 Monaco (Monaco)
24 Pisa (Italy)
25 Rome (Italy)
26 Sicily (Italy)
27 Florence (Italy)
28 London (England)
29 Sheffield (England)
30 Loch Ness (Scotland)
31 Stonehenge (England)
```
As entradas de iluminação por pista `00:E0A4/E024/E064` são decodificadas na seção de dia/noite abaixo.

## Minimapa (sessão 4) — `out/minimaps.png`, `out/minimap_paths.png`, `tools/minimaps.py`, `tools/minimap_path.py`
**O mapa da pista é um gráfico separado, pré-desenhado, não gerado a partir dos dados da pista.** Duas partes:
1. **Bitmap** (o contorno branco com o traço da linha de largada): por pista 1024 bytes = 64 tiles de 2bpp (tiles 8x8 = 64x64 px, só a parte superior esquerda é usada), guardados comprimidos no banco 0D: `0D:8000` = pistas 0-15, `0D:911F` = pistas 16-31
   (escolhido em `0F:821D`, descomprimido por `sub_0FB334` em `$7E2000`; o mesmo decodificador estilo LZ de `00:EA8E/EA9B`, buffer em anel de 2 KB em `$044C`). A pista t usa os bytes `(t&15)*1024` do seu bloco. A tela de localização ("splash") copia cada tile de 16 bytes para 32 bytes (planos 2,3 = 0)
   e faz DMA para a VRAM, linhas do tilemap via `$0EFD86[track]`. Na corrida os mesmos tiles aparecem no BG1 (tilemap `$C00`, linhas 1-4 x colunas 1-8 para o jogador 1; tiles 0x91..0xA1, tile em branco 0x90) com um subconjunto de 17 tiles – mesmo gráfico, deduplicado. As 32 estão renderizadas em `out/minimaps.png`.
2. **Caminho dos marcadores** (os pontos em movimento): `$7E3E00` tem **um par de bytes (x,y) por 256 unidades de pista** (= `$1ED7>>8` para o jogador, o mesmo índice para o carro líder e para o jogador 2). É montado no carregamento da pista (`00:C0F2-C15A`): ponto de partida `00:E0E4[track]` (byte baixo x, byte alto y); depois o fluxo de deltas
   em `0E:`... `00:E124[track]` (descomprimido com `00:EA8E/EA9B`) é acumulado: `x += dx`, `y += dy` por passo. `sub_008910` lê `$7E3E00[pos>>8]` para `$0112` (jogador 1), `$0114` (jogador 2) e `$0116` (carro líder = maior progresso na lista de carros);
   `sprite_renderer` (`01:808B..80AE` para o jogador 1, `01:8590..85BF` para o jogador 2; `00:8966/8A2C` *não* são executados na corrida) escreve-os como as três primeiras entradas de OAM (palavra x|y<<8 seguida de `$307F`/`$30FF`/`$327F` = tile 0x7F/0xFF, paletas) do buffer de sprites de cada jogador; a visão do jogador 2 soma 0x70 ao y (metade de baixo). Assim o ponto se move ao longo de uma poligonal com resolução de 256 unidades (pula a cada 256 unidades).
   As coordenadas de sprite mapeiam para o bitmap com offset (8,8): pixel do bitmap = (x-8, y-8) para o HUD no canto superior esquerdo da tela; sobreposição verificada nas 32 pistas (`out/minimap_paths.png`: a poligonal fica exatamente sobre o contorno desenhado, começando no traço da linha de largada).
**Correções de afirmações anteriores:** as tabelas de "degradê do céu / paleta" `00:E0E4`, `00:E124` e o "fluxo de paleta do céu" `$7E3E00` são a posição inicial e o caminho do marcador do mapa, não cores. `00:DFA4[t]` (02:C849 + 0x40*t) é o tilemap 8x? da *imagem do horizonte* por pista (tilemap de BG, VRAM $1AE0/$1EE0), com gráficos = fluxo comprimido `00:DF64[t]` -> VRAM $6800 (dunas do deserto em Las Vegas etc.), não o minimapa.
Dia/noite: veja a seção abaixo (`00:E0A4`).
Criar uma pista exige portanto: um bitmap de mapa 64x64 2bpp, um ponto de partida e um passo (dx,dy) por 256 unidades (ou apenas a tabela final `$7E3E00`).

## Dia / noite (resolvido) — `scripts/light_log.lua`, `scripts/night_diff.lua`, `scripts/cm_probe.lua`
**É um temporizador por pista em frames desde o início da corrida, não uma posição na volta** (a redação anterior "posição na volta" veio de voltas a fundo, que levam quase o mesmo tempo; um piloto mais lento vê a mudança numa posição anterior).

A inicialização em `00:CDB6` (carregamento da corrida) lê `00:E0A4[track]`:
* **bit 15 ligado** = script de iluminação ativo. `$0102 = (E0A4 & 0x3FFF) - 1` = frames até a mudança (0 -> `$FFFF` = nunca), `$0100 = E0A4 & 0xC000`; bit 14 = começa de **noite**.
  Início noturno: `$0100=C0DF` (o byte baixo `DF` codifica a escuridão), cor fixa `$2132=0xED`, paleta noturna (veja abaixo), `$0104=E064[t]`, `$66=B494`. Início diurno: `$0100=8000`, `$2132=0xE0`, paleta diurna, `$0104=E024[t]`, `$66=B6B6`.
* **bit 15 limpo** = sem script; o valor de 15 bits é apenas uma **cor BGR555** copiada para `$0398/$039A/$039C` e `$03CC..` (cor do céu/horizonte): Las Vegas 152F (R15 G9 B5), Rio 0D11 (R17 G8 B3), Paris 6317 (R23 G24 B24), Monaco 52B4 (R20 G21 B20, cinza), Sheffield 1DD6 (R22 G14 B7).
  (Então o "entardecer" de Monaco na medição de brilho anterior era um céu cinza, não noite.) Pistas com valor 0 mantêm o padrão.

Por frame (`00:BAB9..BBC0`, chamado uma vez por frame de corrida, `INC $1EAE` em 00:B960):
`$0102` conta para trás 1 por frame. Ao chegar a 0 o **fade** roda: noite -> dia: `$0100` é decrementado `C0DF -> C001` (~222 frames), depois vira `8000`; dia -> noite: incrementado `8000 -> 80DF` (~223 frames), depois `C0DF`. `$0102` vira `$FFFF` depois da mudança, então **acontece uma vez por corrida, nunca mais** (não se repete a cada volta) e `$0106` vai 2 -> 1 -> 2 como contador de passos.
A cada frame `$2132 = 0xE0 | (($0100 >> 4) & 0x1F)`: cor fixa com os três canais = nível de escuridão (0 dia, 13 em plena noite). A PPU está em **modo de subtração do color math** (`$2131`: camadas BG3 + OBJ + backdrop, máscara 0x34), então essas camadas escurecem pela cor fixa;
ao mesmo tempo 16 cores (CGRAM $10..$1F) são trocadas: paleta diurna `00:8A5A + DFE4[t]`, paleta noturna `00:8E5A + DFE4[t]` (DMA de 32 bytes, 00:BAED..BB33 e BB66..BBA3). Uma cópia da paleta passa por `$03AE/$038E/$044E` no loader.
`$E024[t]/$E064[t]` ($84F0/$8664 padrão, $8826/$87D8 Hiroshima, $8400 New York) são os valores carregados em `$0104`/`$0106` para o script de dia e de noite (o uso exato não foi decodificado; nunca importam para o tempo).

| pista | E0A4 | início | muda após |
|---|---|---|---|
| 2 New York (USA) | C000 | noite | nunca (noite a corrida toda) |
| 9 Hiroshima (Japan) | CA00 | noite | 2560 frames (~43 s) -> dia |
| 13 Cologne (Germany) | 8B00 | dia | 2816 frames (~47 s) -> noite |
| 14 Black Forest (Germany) | C500 | noite | 1280 frames (~21 s) -> dia |
| 26 Sicily (Italy) | 9800 | dia | 6144 frames (~102 s) -> noite |
| 27 Florence (Italy) | D400 | noite | 5120 frames (~85 s) -> dia |

Verificado estacionando o carro e registrando `$0100/$0102` (`scripts/light_log.lua`, MODE=park): Hiroshima C0DF -> fade no frame 2603 -> 8000 em 2825; Cologne 8000 -> C0DF em 3090 (fim do fade, `$0102=FFFF`); Black Forest fade em 1325 -> dia 1547; Florence 5175 -> 5398; Sicily noite em 6430.
Medição anterior por volta (screenshots, brilho): New York toda de noite; Hiroshima noite -> dia (~17000-18000 unidades); Black Forest noite nas primeiras ~7500 unidades; Florence noite nas primeiras ~36000 unidades; Cologne dia e depois noite a partir de ~19000 (mas foi medido "dia de novo bem no final" e Sicily "entardecer ~40000-43000" – este último é o fade; o dia no fim da volta em Cologne não foi explicado, possivelmente um túnel/objeto ou o reinício da volta).
Contradição com o relato do usuário a verificar: Cologne é descrita como noite-e-talvez-dia; pela tabela é dia nos primeiros ~47 s da corrida e noite no resto.
