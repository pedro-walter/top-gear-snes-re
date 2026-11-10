## Datos de la pista (cargador `sub_00BF44`, llamado desde `sub_00BF14` = load_track; las tablas están en el banco 0C, número de pista `$1F06`, 16 pistas)
Descriptor de la pista = 10 bytes en `0C:8402 + 10*t`: w0 = número de piezas de 1024 unidades (6 bits bajos; longitud = piezas*1024), luego 4 punteros (banco 0C):
`slope stream`, `curve stream`, `scenery stream`, `object stream`. El cargador los expande en la WRAM:

| WRAM | construido a partir de | significado |
|---|---|---|
| `$7E4000` | slope stream | **pendientes**: una palabra con signo por cada 32 unidades de posición. Byte con signo por pieza -> tabla de punteros `0C:85D3`, cada plantilla = 32 palabras; byte negativo = plantilla negada. 0 plano; +-50..1000, con rampas de entrada y salida. Positivo = subida (decelera, factor 1/64 por tick), negativo = bajada (acelera, factor 1/16 por tick). Verificado exactamente contra la memoria en la pista 0. |
| `$7E4C00` | curve stream | **curvas**: mismo formato, tabla de punteros `0C:8591`. |valor| máx. 16..40 por palabra. Usado en 05:E9AF/F358 como `$7E4C08[pos>>4]` (8 palabras = 256 unidades por delante) x velocidad = empuje centrífugo sobre la posición lateral. Verificado exactamente en la pista 0. |
| `$7E5800` | scenery stream | 64 bytes por pieza copiados de la tabla de punteros `0C:8545`; palabras (bit15 + índice) consultan la forma del borde de la carretera mediante `00:9B3F`; usado por `sub_00A8E1` para construir `$7E7000` |
| `$7E6400` | object stream | objetos/señales laterales/entrada del pit. Registros de 5 bytes expandidos mediante la tabla en `0C:8615`: una palabra por 32 unidades; 7 bits altos = tipo (0x74xx = **entrada del pit**); los objetos solo existen en las dificultades permitidas por la máscara de `0C:8541[$1F10]&0xE000` |
| `$7E7000` | calculado (00:A8E1.. A9xx, AA09/AA6A) | corredor de la carretera: dos bytes con signo por 32 unidades = límite izquierdo/derecho; `$7E7002` = siguiente entrada |
| `$7E3E00` | flujo de paleta (`0E`/`E124[t]`, decodificado con 00:EA8E/EA9B) | degradado de color de cielo/fondo por pista |
Constantes por pista: vueltas `00:DEA4[t]` (word), info del pit `00:DF24[t]` (bit15 -> lado, `&0x7FFF*2` -> `$1EF0` = posición de inicio de la calle de boxes), tablas de borde de la calle de boxes `00:E166/E198` (indexadas por distancia/16 desde `$1EF0`),
paleta de fondo `00:E0E4[t]`, gráficos `00:DFA4[t]`, desplazamientos de velocidad de los bots `00:DDE4`.
`tools/tracks.py` reimplementa el cargador y verifica las tablas de slope+curve contra un volcado de la WRAM (23/23 piezas idénticas en la pista 0). Las 16 pistas son datos simples en la ROM (banco 0C),
así que una pista nueva = streams nuevos + descriptor (diseñar pistas es viable; la incógnita que queda es la tabla de forma de borde de 00:A8E1 en `00:9B3F` y los registros de objetos).


## Streams de escenario y de objetos (sesión 4) — `tools/objects.py`, `tools/objmap.py`, `out/objects.png`, `out/objects_all.csv`
Los dos cargadores (00:C042–C0EF) están portados y **verificados exactamente contra la WRAM** (pista 0: escenario 736/736 palabras, objetos 736/736 en las dificultades 0/1; la dificultad 2 añade 20 palabras).
### Escenario ($7E5800, una palabra por 32 unidades)
* Stream = un byte por pieza de 1024 unidades (elemento k = byte en stream+k, leído como word, solo se usa el byte bajo) -> índice de plantilla `(b<<1)&0x1FF` -> tabla de punteros `0C:8545` -> 32 palabras.
* Palabra = `0x8000 | block<<4 | phase<<1`, fase 0..7 repite a..h a lo largo de una pieza, block = 0..26. La lógica solo usa `Y = 00:9B3F[word&0x7FFF]` = **tipo de carretera 0..3** (desplazamiento de registro 0/4/8/12):
  bloques 0,4,7,8,12,15,18..25,27.. -> tipo 0; 1,6,9,13,16,28 -> 1; 2,5,14,17,29 -> 2; 3,10,11,26 -> 3. Los bloques del mismo tipo son indistinguibles para física/corredor (probablemente solo gráficos; el papel del bloque 4 frente al 0 es desconocido).
* Tipo de carretera t -> palabra por pista `00:DEE4[track]`: bits 0-2 = estilo del tipo 0, bits 3-5 tipo 1, 6-8 tipo 2, 9-11 tipo 3 (bit 15 = variante de tile espejada, `$E0`). Un estilo (0..7) indexa tablas en 00:C552 (gráficos de borde izquierdo/derecho de la carretera, DMA de 0x300 bytes cada uno a la VRAM $1000/$1400, $1180/$1580, ...),
  00:C572 (**límite de la pared** $017B+4t/$017D+4t = `-10229/+10229` estrecha, `18636`, `26424` ancha; estilo 7 = 13301) y 00:C592 (borde dibujado $013F+4t/$0141+4t = -80/80, -138/138, -192/192; estilo 7 = 102). Estilos 0..6 = combinaciones (anchura izquierda, anchura derecha): izquierda en {estrecha, más ancha, la más ancha} x derecha en {estrecha, más ancha, la más ancha}.
  05:D7FC limita la lateral del jugador `$1E8A` al límite de la pared del tipo de carretera bajo el coche (rebotando, `sub_05F6FA`); 00:A8E1 construye el corredor `$7E7000`.
* En el mapa `out/objects.png` los colores de fondo son los 4 tipos de carretera por pista: la **entrada del pit está siempre donde el tipo de carretera cambia a un tramo ensanchado** (calle de boxes).
### Objetos ($7E6400, una palabra por 32 unidades, solo el primer objeto de un slot; 0 = vacío)
* Registro del stream = 5 bytes por 512 unidades: w0 (2 B), w1 (2 B), luego el byte b2 en +4. w0<<1 y w1<<1 dan cada uno dos "plantillas" de 16 bits D0..D3 ($ED/$EF/$F1/$F3: byte bajo<<8 y byte alto<<8). b2*32 selecciona uno de 16 patrones de palabras en `0C:8615`.
* Palabra de patrón e: 0 = vacío; bits 13-15 = máscara de dificultad (AND con `0C:8541[$1F10]&0xE000`; el objeto solo existe en esas dificultades); bits 9-10 eligen D0..D3; los 9 bits bajos e&0x1FF se rellenan:
  si el bit15 de D = 0 -> resultado = D | (e & 0x1FF) (objeto ordinario); si el bit15 de D = 1 -> resultado = (D&0xC000) | ((D&0x3E00)>>8) (un "grupo"/especial; los bits bajos de e se ignoran).
* **Palabra de objeto ordinario** (bit15=0): bits 9-14 = **tipo** (0..63, id gráfico de `00:E9BA[type*2]`, manejador de colisión `05:F5C3[type*2]`), bit 8 = lado (1 = lateral negativa), bits 0-7 = distancia lateral x128 en unidades `$1E8A`
  (límites de pared 10229..26424 = 80..206). También alimenta al constructor de corredor (00:A8E1: los objetos estrechan el corredor en +-0x40 a su alrededor) para que los coches no atraviesen objetos y el coche del ordenador los esquive.
  La prueba de colisión 05:D6F4+ mira los 32 slots (1024 unidades) antes del coche: diferencia lateral vs umbrales `05:A05F/A0DF[type]`; los manejadores F6B3 (REV: velocidad -> -min(speed/2,1600)), F6F5 (EDGE: mitad de velocidad, empujón hacia el centro de la carretera) y F6F1 (SIDE: mitad, empujón alejándose del objeto) activan el bit 0x80 de `$1EF5` (sonido de choque); detalles medidos en docs/03 "Colisiones".
  Tipos usados en las 16 pistas: 5-15, 21-24, 26-29, 31, 37, 38, 40-43, 46, 54-56, 58; los más comunes son 8, 9, 15 (objetos laterales tipo cactus), 24, 27, 31, 41. **Tipo 0x3A (palabra del stream 0x74xx/0x75xx) = entrada del pit** (lado del bit 8, lateral p. ej. 0x3C=60, 0x7C=124).
* **Palabra de grupo** (bit15=1): `(w&0x3FFE)` indexa `00:E888` -> lista en `00:E89A` de sprites dibujados juntos. Solo se usa para: id 1 (`0x8002`) en la posición 0 y al final de toda pista = **pórtico de salida/meta**, y en la pista 4 la serie 0xC004..0xC00E alrededor de las posiciones 5150-5550 (estructura tipo túnel/puente, las líneas verdes en `out/objects.png`). Los objetos de grupo colisionan mediante `sub_05ED3A` (comportamiento REV).
* Tabla de sprites: el renderizador (00:E286.., E5B7..) explora 4 palabras por delante desde `camera+0x50` en busca de objetos, construye una pequeña caché de ids de sprite (`$1BC6`..) y hace DMA de frames escalados; datos por id en `00:E882+4*id` (palabras usadas: tamaños/cuentas, `$E886` = número de frames). El formato exacto del frame no está decodificado.
### Cómo crear una pista
Usa el descriptor `0C:8402+10t` (w0 piezas, 4 punteros de stream) + `00:DEE4[t]` (estilos de carretera) + vueltas `00:DEA4`, pit `00:DF24`, tablas de paleta/gráficos; escenario = un byte de plantilla por pieza; objetos = registros de 5 bytes. Todo esto son datos simples (ver `tools/objects.py` para la regla exacta de expansión).
Desconocido: el papel de los bloques de escenario dentro de un tipo, la semántica de la tabla de umbrales (los valores de 05:A05F parecen distancias de 16 bits en unidades `$1E8A/2`, 0x1000..), el formato de frame del DMA de sprites.

## CORRECCIÓN (sesión 4): son **32 pistas**, no 16
La tabla de descriptores `0C:8402+10*t` es válida para t = 0..31 (la entrada 32 ya es otro dato); `00:DEA4` (vueltas), `00:DEE4` (estilos de carretera), `00:DF24` (pit) también tienen 32 entradas. Las afirmaciones anteriores de "16 pistas" en este archivo se refieren solo a las pistas 0-15.
* Vueltas t=0..31: 3,3,3,6,6,4,6,3,7,5,3,6,7,3,6,8, 3,3,3,3,3,7,6,3,3,6,3,3,8,3,3,4.
* Pistas con pit stop (00:DF24 != FFFF): 3,4,6,8,9,11,12,14,15,21,22,25,28 (así que la lista anterior "sin pit: 0,1,2,5,7,10,13" vale solo para las pistas 0-15; 16-20,23,24,26,27,29-31 tampoco lo tienen).
* `tools/track_atlas.py 0` -> `out/tracks.png` (pistas 0-15), `tools/track_atlas.py 1` -> `out/tracks_16_31.png`; `tools/objmap.py` ahora cubre las 32 -> `out/objects.png`.
* Estructura probable: 8 países x 4 pistas (el mapeo número de menú -> `$1F06` aún no está decodificado; pista 4 = túnel cerca de la salida, confirmado por el usuario).
* Las tablas por pista indexadas por la pista (desplazamientos de los bots `00:DDE4[track*6+diff*2]`, gráficos `00:DFA4`, paleta `00:E0E4`, cielo `E124`) presumiblemente también tienen 32 entradas; verifica antes de usar pistas >= 16.

## Tablas por pista verificadas en las 32 pistas (sesión 4)
Método: modificar `$1F06` (pista) en los frames 2000-2400 en el emulador headless (`scripts/dump_track.lua`, TRACK=n), volcar `$7E4000-$7E71FF` en la salida y comparar con los cargadores en Python en las pistas 16, 21, 25, 31:
los streams de pendiente, curva, escenario y objetos son **idénticos palabra por palabra** (p. ej. t=16: 1216/1216, 1216/1216, 1248/1248, 1248/1248). Longitud `$0200`, vueltas `$1E56` e inicio del pit `$1EF0` también concuerdan con las tablas (t=21: vueltas 7, `$1EF0`=0x7600 = 2*(0xBB00&0x7FFF)).
Todas las tablas siguientes tienen 32 entradas, guardadas seguidas (64 bytes cada una, 00:DDE4 tiene 6 bytes por pista):
| tabla | contenido |
|---|---|
| `00:DDE4` (6 B/pista) | desplazamientos de velocidad de los bots por dificultad: pistas 0-15 p. ej. t0 {0,80,160}, t1 {128,416,704}; pistas 16-31 todas empiezan en 288 (p. ej. t18 {288,672,1056}, t22 {288,224,160} -> esa pista se vuelve *más fácil* con la dificultad, t20 {288,320,352}) |
| `00:DEA4` vueltas, `00:DEE4` estilos de carretera, `00:DF24` pit | verificados, ver arriba |
| `00:DF64` | puntero (banco 5 para t<16, banco 6 para t>=16: `ROL` del carry de CPX #$20, 00:C20D) a un stream comprimido, descomprimido por 00:EA8E/EA9B en la VRAM $6800 = gráficos de fondo/horizonte por pista |
| `00:DFA4` | bloques gráficos de 64 bytes (0xC849 + 0x40*t) copiados a la VRAM $1AE0/$1EE0 |
| `00:DFE4` | desplazamiento de paleta 0x20*t (carga a la CGRAM desde 05:8A5A / 8E5A, 00:BAFB / BB6B) |
| `00:E024`, `00:E064` | punteros por pista copiados a `$0106` (todos 0x84F0 / 0x8664, salvo las pistas 2 (0x8400) y 9 (0x8826/0x87D8): ¿scripts distintos de sonido/música/fondo? |
| `00:E0A4` | color opcional por pista (negativo = ninguno; usado en 00:CDB0) |
| `00:E0E4` | palabras de paleta de fondo, `00:E124` desplazamientos del stream de degradado del cielo (0x0, 0xB0, 0x1F8, ...) |
| `0D:C6D6[t]` | vueltas otra vez (bytes), `0D:C6F6[t]` = número de piezas de 1024 unidades (22, 41, 42, ...), ambos usados por la pantalla de menú/selección de pista |
* `$1F06 & 0x1C` = **país** (0..7; pista = país*4 + 0..3); un camino de pista aleatoria enmascara `$1FFC & 0x1F`.
* **Contraseñas** (menú 0F:85F2): mostradas para los países 1..7 (del 2º al 8º), 8 caracteres, tabla `0D:C513` = 7 por dificultad x 3: amateur MOONBATH, GEARBOX, CAR PARK, ROAD HOG, EMULATOR, ANALYSER, HORIZONS; professional FOUR MEG, LEGEND, THEWORLD, LETSRACE, ALCHEMY, A LOOPER, SEASONAL; championship EDUCATED, OILCLOTH, WRECKAGE, CARACOLE, EPYLLION, GLUCAGON, KEELSON
  (índice = (country-1)*8 + difficulty*0x38; país 1 = pistas 4-7 etc.; el país 0 no necesita).
