## Nombres de las pistas (sesión 4) — `tools/names.py`
Los nombres vienen de la tabla de punteros `0D:C77C[track]` -> texto de la pantalla de ubicación en el banco 0F (`0F:81AB`); país = track>>2 (EE. UU., Sudamérica, Japón, Alemania, Escandinavia, Francia, Italia, Reino Unido). Confirmado en el emulador: $1F06=2 muestra **NEW YORK, U.S.A** en la pantalla de ubicación y la carrera es la nocturna en la ciudad; $1F06=0 es la carrera del desierto (Las Vegas); 9 = Hiroshima (empieza al atardecer). 4 = Rio tiene el túnel cerca de la salida.

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
Las entradas de iluminación por pista `00:E0A4/E024/E064` se decodifican en la sección de día/noche más abajo.

## Minimapa (sesión 4) — `out/minimaps.png`, `out/minimap_paths.png`, `tools/minimaps.py`, `tools/minimap_path.py`
**El mapa de la pista es un gráfico separado, dibujado de antemano, no generado a partir de los datos de la pista.** Dos partes:
1. **Bitmap** (el contorno blanco con la marca de la línea de salida): por pista 1024 bytes = 64 tiles de 2bpp (tiles de 8x8 = 64x64 px, solo se usa la parte superior izquierda), guardados comprimidos en el banco 0D: `0D:8000` = pistas 0-15, `0D:911F` = pistas 16-31
   (elegido en `0F:821D`, descomprimido por `sub_0FB334` en `$7E2000`; el mismo decodificador estilo LZ de `00:EA8E/EA9B`, búfer en anillo de 2 KB en `$044C`). La pista t usa los bytes `(t&15)*1024` de su bloque. La pantalla de ubicación ("splash") copia cada tile de 16 bytes a 32 bytes (planos 2,3 = 0)
   y lo envía por DMA a la VRAM, filas del tilemap mediante `$0EFD86[track]`. En la carrera los mismos tiles los muestra el BG1 (tilemap `$C00`, filas 1-4 x columnas 1-8 para el jugador 1; tiles 0x91..0xA1, tile en blanco 0x90) con un subconjunto de 17 tiles – mismo gráfico, deduplicado. Las 32 están renderizadas en `out/minimaps.png`.
2. **Camino de los marcadores** (los puntos que se mueven): `$7E3E00` tiene **un par de bytes (x,y) por cada 256 unidades de pista** (= `$1ED7>>8` para el jugador, el mismo índice para el coche líder y para el jugador 2). Se construye al cargar la pista (`00:C0F2-C15A`): punto de partida `00:E0E4[track]` (byte bajo x, byte alto y); después el flujo de deltas
   en `0E:`... `00:E124[track]` (descomprimido con `00:EA8E/EA9B`) se acumula: `x += dx`, `y += dy` por paso. `sub_008910` lee `$7E3E00[pos>>8]` en `$0112` (jugador 1), `$0114` (jugador 2) y `$0116` (coche líder = mayor progreso en la lista de coches);
   `sprite_renderer` (`01:808B..80AE` para el jugador 1, `01:8590..85BF` para el jugador 2; `00:8966/8A2C` *no* se ejecutan en la carrera) los escribe como las tres primeras entradas de OAM (palabra x|y<<8 seguida de `$307F`/`$30FF`/`$327F` = tile 0x7F/0xFF, paletas) del búfer de sprites de cada jugador; la vista del jugador 2 suma 0x70 a y (mitad inferior). Así el punto se mueve a lo largo de una poligonal con resolución de 256 unidades (salta cada 256 unidades).
   Las coordenadas de sprite se mapean al bitmap con desplazamiento (8,8): píxel del bitmap = (x-8, y-8) para el HUD en la esquina superior izquierda de la pantalla; superposición verificada en las 32 pistas (`out/minimap_paths.png`: la poligonal queda exactamente sobre el contorno dibujado, empezando en la marca de la línea de salida).
**Correcciones de afirmaciones anteriores:** las tablas de "degradado del cielo / paleta" `00:E0E4`, `00:E124` y el "flujo de paleta del cielo" `$7E3E00` son la posición inicial y el camino del marcador del mapa, no colores. `00:DFA4[t]` (02:C849 + 0x40*t) es el tilemap 8x? de la *imagen del horizonte* por pista (tilemap de BG, VRAM $1AE0/$1EE0), con gráficos = flujo comprimido `00:DF64[t]` -> VRAM $6800 (dunas del desierto en Las Vegas, etc.), no el minimapa.
Día/noche: ver la sección siguiente (`00:E0A4`).
Crear una pista exige por tanto: un bitmap de mapa 64x64 2bpp, un punto de partida y un paso (dx,dy) por cada 256 unidades (o solo la tabla final `$7E3E00`).

## Día / noche (resuelto) — `scripts/light_log.lua`, `scripts/night_diff.lua`, `scripts/cm_probe.lua`
**Es un temporizador por pista en frames desde el inicio de la carrera, no una posición en la vuelta** (la redacción anterior "posición en la vuelta" venía de vueltas a fondo, que duran casi lo mismo; un piloto más lento ve el cambio en una posición anterior).

La inicialización en `00:CDB6` (carga de la carrera) lee `00:E0A4[track]`:
* **bit 15 activo** = script de iluminación activo. `$0102 = (E0A4 & 0x3FFF) - 1` = frames hasta el cambio (0 -> `$FFFF` = nunca), `$0100 = E0A4 & 0xC000`; bit 14 = empieza de **noche**.
  Inicio nocturno: `$0100=C0DF` (el byte bajo `DF` codifica la oscuridad), color fijo `$2132=0xED`, paleta nocturna (ver abajo), `$0104=E064[t]`, `$66=B494`. Inicio diurno: `$0100=8000`, `$2132=0xE0`, paleta diurna, `$0104=E024[t]`, `$66=B6B6`.
* **bit 15 limpio** = sin script; el valor de 15 bits es solo un **color BGR555** copiado a `$0398/$039A/$039C` y `$03CC..` (color del cielo/horizonte): Las Vegas 152F (R15 G9 B5), Rio 0D11 (R17 G8 B3), Paris 6317 (R23 G24 B24), Monaco 52B4 (R20 G21 B20, gris), Sheffield 1DD6 (R22 G14 B7).
  (Así que el "atardecer" de Monaco en la medición de brillo anterior era un cielo gris, no noche.) Las pistas con valor 0 mantienen el predeterminado.

Por frame (`00:BAB9..BBC0`, llamado una vez por frame de carrera, `INC $1EAE` en 00:B960):
`$0102` cuenta hacia atrás 1 por frame. Al llegar a 0 corre el **fundido**: noche -> día: `$0100` se decrementa `C0DF -> C001` (~222 frames), luego pasa a `8000`; día -> noche: se incrementa `8000 -> 80DF` (~223 frames), luego `C0DF`. `$0102` pasa a `$FFFF` tras el cambio, así que **ocurre una vez por carrera, nunca más** (no se repite en cada vuelta) y `$0106` va 2 -> 1 -> 2 como contador de pasos.
En cada frame `$2132 = 0xE0 | (($0100 >> 4) & 0x1F)`: color fijo con los tres canales = nivel de oscuridad (0 día, 13 en plena noche). La PPU está en **modo de resta del color math** (`$2131`: capas BG3 + OBJ + backdrop, máscara 0x34), así que esas capas se oscurecen con el color fijo;
al mismo tiempo se intercambian 16 colores (CGRAM $10..$1F): paleta diurna `00:8A5A + DFE4[t]`, paleta nocturna `00:8E5A + DFE4[t]` (DMA de 32 bytes, 00:BAED..BB33 y BB66..BBA3). Una copia de la paleta pasa por `$03AE/$038E/$044E` en el cargador.
`$E024[t]/$E064[t]` ($84F0/$8664 predeterminado, $8826/$87D8 Hiroshima, $8400 New York) son los valores cargados en `$0104`/`$0106` para el script de día y de noche (el uso exacto no está decodificado; nunca importan para el tiempo).

| pista | E0A4 | inicio | cambia tras |
|---|---|---|---|
| 2 New York (USA) | C000 | noche | nunca (noche toda la carrera) |
| 9 Hiroshima (Japan) | CA00 | noche | 2560 frames (~43 s) -> día |
| 13 Cologne (Germany) | 8B00 | día | 2816 frames (~47 s) -> noche |
| 14 Black Forest (Germany) | C500 | noche | 1280 frames (~21 s) -> día |
| 26 Sicily (Italy) | 9800 | día | 6144 frames (~102 s) -> noche |
| 27 Florence (Italy) | D400 | noche | 5120 frames (~85 s) -> día |

Verificado aparcando el coche y registrando `$0100/$0102` (`scripts/light_log.lua`, MODE=park): Hiroshima C0DF -> fundido en el frame 2603 -> 8000 en 2825; Cologne 8000 -> C0DF en 3090 (fin del fundido, `$0102=FFFF`); Black Forest fundido en 1325 -> día 1547; Florence 5175 -> 5398; Sicily noche en 6430.
Medición anterior por vuelta (capturas, brillo): New York toda de noche; Hiroshima noche -> día (~17000-18000 unidades); Black Forest noche en las primeras ~7500 unidades; Florence noche en las primeras ~36000 unidades; Cologne día y luego noche desde ~19000 (pero se midió "día otra vez justo al final" y Sicily "atardecer ~40000-43000" – esto último es el fundido; el día al final de la vuelta en Cologne no se explicó, posiblemente un túnel/objeto o el reinicio de la vuelta).
Contradicción con el informe del usuario por comprobar: Cologne se describe como noche-y-quizá-día; según la tabla es día en los primeros ~47 s de la carrera y noche en el resto.
