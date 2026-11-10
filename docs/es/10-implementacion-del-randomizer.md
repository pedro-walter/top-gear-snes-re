# Randomizer: estado de la implementación y mapa

Build: `python3 -I tools/build_rando.py` (necesita la ROM original, variable `TOPGEAR_ROM`, por defecto `Top Gear (USA).sfc`) escribe
`out/rando.sfc` (1 MB, LoROM, byte de tamaño de la cabecera + checksum corregidos). Nada del original se guarda en el repositorio: las
fuentes son `src/gen.asm` (generador), `src/hooks.asm` (parches del código original + pegamento del menú), `src/harness.asm`
(solo en el build de pruebas), ensambladas por `tools/asm65816.py` (ensamblador de 65816 propio, de dos pasadas; los saltos largos se relajan
automáticamente, `$0012` = absoluto, `$12` = direct page, `$123456` = long, los sufijos `.l/.w/.b` fuerzan tamaños).

## Qué funciona (todo verificado headless en Mesen)

* **Generador** (`src/gen.asm`, referencia `tools/trackgen.py`): semilla (32 bits) -> LFSR -> entorno (una de las 32 pistas
  originales, guardada en `$1F06` para que toda tabla por pista siga funcionando), 24..46 piezas, 3..8 vueltas, recorridos de pendiente y curva sobre el
  grafo de plantillas (docs/09), objetos laterales y tipo de carretera por pieza copiados en tramos de la propia pista del entorno
  (así los conjuntos de objetos, el escenario sin túneles y las anchuras de carretera encajan con el entorno), exactamente una pieza de pit (plantilla 20 +
  objetos del pit, palabra del pit como `00:DF24`), expansión a las tablas de la WRAM `$7E4000/$4C00/$5800/$6400` idéntica a
  `00:BF44`. **`tools/rando_test.py` ejecuta el generador 65816 en Mesen headless (ROM de pruebas) y compara las cuatro
  tablas con la referencia Python: 1500/1500 semillas idénticas.**
  * El cargador expande **L+2** piezas (una copia de vuelta de la pieza 0 y una copia de anticipación de la pieza 1). El escáner de objetos
    (`00:E20D`) lee hasta 0x58 bytes más allá del final de la vuelta; datos sin inicializar ahí hacían que un bucle de grupo corriera ~65 mil iteraciones
    (el juego iba a 1/4 de velocidad, gráficos basura). Corregido generando la pieza extra.
  * El banco `$7F:0000..$2800` NO está libre: la tabla de corredor `$7E7000` (bytes de longitud) invade ese espacio. El borrador/estado vive en
    `7F:F000..F8FF`: semilla `F800`, magic `F806` (= $A55A una vez inicializado), flag del teclado `F808`, flag de saltar título `F80A`,
    variables del generador `F830..F87A`, arrays de stream `F000..F7FF`.
* **Hooks en el juego** (`src/hooks.asm`): `00:BF59` (expansión de streams -> generador, define `$1F06`, `$0200`),
  `00:BF38` (vueltas), `00:C162` (palabra / lado del pit), `0F:9281` (PLAY GAME: deriva el entorno de la semilla, borra la
  tabla de puntos para que resultados/ranking muestren solo esta carrera), `0F:8487` (resultados -> vuelta al menú principal, título saltado una vez),
  entrada de menú `COUNTRY` -> `SEED` (el menú entero se rehízo después, ver "Menú principal y series de pistas" abajo).
* **Interfaz de la semilla**: el menú principal muestra `SEED xxxxxxxx`; Left/Right en esa fila sortea una semilla nueva; A abre el teclado
  (`src/keypad.asm`, página 8 de los menús reutilizada): **glifos dorados grandes**, una cuadrícula de 6x3, el código escrito en la
  caja con la fuente grande, barra de selección = la píldora de sprite del propio juego, el cursor da la vuelta dentro de las 18 celdas (ninguna celda vacía puede quedar
  seleccionada). Teclas como en la entrada de nombre: A o B = pulsar la tecla (añade un carácter), X o Y = borrar el último, START o la tecla `END` = aceptar; la tecla `<-` borra. No escribir nada y
  aceptar = sortear una semilla nueva. La semilla persiste tras la carrera (repetición). La pantalla de splash muestra `SEED xxxxxxxx`,
  distancia (piezas/vuelta * 15/256 km) y LAPS.
  Cuadrícula: `0 1 2 3 4 5 / 6 7 8 9 A B / C D E F <- END`; el dígito hex 11 se dibuja como una `b` minúscula porque la `B` cuadrada de la
  fuente es idéntica a un `8`.
* **Glifos de dígitos grandes** (`tools/bigfont.py`, dibujados a mano en `font/original/*.bmp`, BMP indexados de 16x16, índice 0 transparente, 1..15 = los colores de la fuente dorada): la fuente
  dorada del juego (tiles 128..255 de la VRAM) no tiene 0, 3-9 (0 = `O`, 5 = `S`, 8 = `B`), así que `0`-`9`, `A`, `C`, `E`, `F` se leen de los BMP en el momento del build. Los hex 11 / 13 siguen generados como `b` / `d` minúsculas
  (una `B` / `D` cuadrada se leería como `8` / `0`; código de siete segmentos de `bigfont.py`). El signo de infinito son dos glifos, `infinity_left.bmp` + `infinity_right.bmp`.
  Los 18 glifos se guardan en la ROM como 3 KB de tiles 4bpp (`kp_gfx`) y se copian a los tiles 256..351 de la VRAM (palabra `$2000`) en forced blank por `kp_build_glyphs` (teclado y menú principal);
  layout = el layout de sprite del juego (`tile = 256 + (j>>3)*32 + (j&7)*2`, mitad inferior +16; slot 0..15 = valor hex, 16 / 17 = mitades del infinito = tiles 320 / 322). La flecha y `END` aún usan los tiles de glifo del juego.
  `python3 tools/bigfont.py png out.png` renderiza una vista previa (desactualizada: solo dígitos generados).
* **Pantalla de título** (final de `hooks.asm`, `purple_title` en `tools/build_rando.py`): el degradado del cielo es una tabla de colores de HDMA (CGADD/CGDATA, 224 palabras en `0D:C7FA` y `0D:C8DA`, solo azul); el build suma rojo proporcionalmente al azul y reduce el verde, así que el cielo queda violeta. Los textos son sprites de 8x8 dibujados por `draw_string_list` (`0F:9ED3`) a partir de la lista en `0F:AFC6` (entradas: columna, fila, desplazamiento de píxel x, y, texto, 0; fin de la lista = palabra 0). La lista se sustituye por una en `0F:FB62` (relleno sin uso del banco 0F; comprobado con callbacks de lectura en el título, menús y una carrera) con `RANDOMIZER BY PEDRO WALTER` en lugar de la línea de licencia de Nintendo y `POWERED BY CLAUDE` en lugar de la línea de Kemco; PRESS START queda igual, la línea de copyright de Gremlin se elimina y la última línea dice `VERSION BETA 0.1`. La lista de texto la genera `title_lines()` en `tools/build_rando.py` (centrado, cuenta de glifos para el bucle de abajo); **cambia el nombre de la versión solo en `VERSION` allí**. El código de la lista para `.` es `=` (tile de sprite `$88`; los dígitos son `$7B..$84`). El búfer de OAM solo tiene sitio para 72 sprites de texto (sprites 56..127) y las líneas más largas necesitan 81 con espacios, así que los espacios ya no emiten un sprite (hook en `0F:9EFB` salta a `0F:FBD0`, que solo avanza la x del siguiente glifo en 8), y la cuenta en el bucle de ajuste de tiles en `0F:8EDC` es el número de glifos (62 ahora, eran 70; calculado en el build).
* **Puntos rojos en la fuente pequeña**: la paleta 7 de la fuente de sprites pequeña (`0E:FD66`) tiene rojo en el índice 5, usado por algunos píxeles sueltos en B, D y 8 (visibles también en el texto original del título); el build copia el color del contorno (índice 6) encima.
* **Señales** (catálogo de objetos en docs/07): los tipos de chevron (8, 9) y las banderas del pit (13) de la pista de origen nunca se copian; el generador coloca
  5 chevrons (cada 4 slots, el último 4 slots antes de la curva) antes del inicio de toda curva - tipo 9 (`<`) a la derecha antes de una
  curva positiva, tipo 8 (`>`) a la izquierda antes de una negativa - y banderas de pit (tipo 13, plantilla `$18`/`$1A`) en las dos piezas
  antes del pit como hacen las pistas originales. La referencia Python y el código 65816 son idénticos (`add_chevrons`).
* **Contadores de vueltas** (`src/bar.asm`, `hook_lapctr`): `LAP vuelta/vueltas` (p. ej. `LAP 3/7`) alineado a la derecha en la columna de tile 29 (tan ancho como el cronómetro) de la fila del BG1 bajo cada cronómetro (filas 5 y 19; las 7 celdas de `LAP n/m` empiezan en la columna 23, la celda en la columna 21/22 se deja en paz para que la última letra de los mensajes anchos como `4 LAPS LEFT` (columnas 11..21) no se borre; el medidor de combustible está en la columna 30 desde la fila 6 hacia abajo), uno por coche (el de abajo es el ordenador en el modo de un jugador). `$1E76` / `$1E78` cuentan vueltas completas (`$FFFF` mientras el coche aún está antes de la línea de la vuelta 1), mostrado = eso + 1, mínimo 1, máximo `$1E56`. Fuente = los propios tiles del HUD para los dígitos (`$35..$3E`, los del cronómetro) y la A (`$4B`), más los tiles `$B0..$B2` del BG1 (palabra de VRAM `$0B00`) para L, P y la barra en el mismo estilo, sombra recoloreada en negro, paleta 3, generados por `tools/lapfont.py`, cargados por `hook_bar`). Las celdas se reescriben en cada frame desde un JSL al inicio de `draw_hud_speed` (`00:CE61`, corre con la VRAM escribible; el hook termina con el `LDA $1E5A` sustituido porque quien llama ramifica según sus flags).
* **Fila de la semilla en el menú principal** (`hooks.asm`, `build_seed_tiles`): la fuente pequeña tiene 8 líneas de alto pero la barra selectora tiene 16, así que los 16 glifos hex (copiados a la ROM como `seed_glyphs`: la fuente aún no está en la VRAM cuando el menú vuelve de una carrera, lo que mostraba basura en la GUI) se escriben al dibujar el menú (forced blank) en los tiles `$40..$5F` del BG1 desplazados 4 líneas hacia abajo (mitad superior / inferior, palabra de VRAM `$1400`) y la semilla se dibuja en dos filas de texto con códigos de carácter `$80+2v` / `$81+2v` (el juego dibuja el código c como el tile c-$40).
* **Sin minimapa, franja de progreso de la vuelta en su lugar** (`src/bar.asm`): el bitmap descomprimido del minimapa se borra (`0F:8232`) y la línea del récord de vuelta se mueve
  fuera de la pantalla. La barra negra entre las dos vistas muestra el progreso a lo largo de la vuelta: una línea de salida roja (a la izquierda, borde blanco), una línea de meta (a la derecha), y
  tres puntos pequeños de 4x2 sin borde en carriles fijos: jugador 1 arriba, el líder en el medio (oculto mientras el jugador 1 o 2 lidera), jugador 2 / coche del
  ordenador abajo. x = posición en la vuelta (`$1ED7` / `$1EDA` / `$0219+slot`, escalada por la longitud de la vuelta `$0200` a 200 píxeles, multiplicación 8x8 +
  división 16/8). Los colores son la paleta de sprite del propio coche, color 9 (claro: el contraste sobre negro va bien con todas las paletas): los jugadores usan las paletas 0 / 1
  como en el original, el líder la paleta del registro de su coche (`word >> 13 & 3`; los bots alternan las paletas 2 y 3 según el código de registro `$22`/`$32`).
  * Los puntos son los sprites marcadores del propio juego; el tile `$7F` (usado solo por ellos, byte de VRAM `$4FE0`) lo redibuja `hook_bar` al construir el HUD. `update_map_dots` (`00:8910`) se sustituye por un JSL a `hook_mapdots`
    que escribe `$0112/$0114/$0116` = x | y << 8; el renderizador de sprites (`01:808B..80AE`, búfer del jugador 1) ya los copia a los sprites. La
    palabra de tile/atributo del líder va a `$1FB2` (`LDA` parcheado en `01:80A0`); el líder se encuentra con el bucle del propio juego (mayor clave `$021A` entre los 20 coches) y se oculta cuando es el slot en `$0204` o `$0206`.
    El búfer del jugador 2 (`01:8590/85A2/85B4`, y + $70) se aparca fuera de la pantalla. **Corrección:** las rutinas `00:8966/8A2C` que el texto anterior llamaba
    escritoras de marcadores no se ejecutan en la carrera (cuenta de ejecuciones 0); los parches antiguos de aparcamiento en ellas no hacían nada, así que los puntos originales se dibujaban
    sobre la esquina en blanco del minimapa. Se dejaron en su sitio por lo que pudiera llamarlas.
  * Por qué solo una franja fina: el juego fuerza blank en las líneas de escaneo 109..114 (`INIDISP` $8F en `00:BE88`, restaurado en `00:BEF4`) mientras hace DMA de la paleta
    y de la OAM para la segunda vista, y la segunda vista empieza en la línea 115, así que no se puede dibujar nada ahí. La parte visible de la "barra" es la fila de tiles 13 del BG1
    = líneas 104..108 (cinco líneas); la franja se hace negra opaca (cubre las últimas líneas de la primera vista), así que la barra negra son las
    líneas 104..114. El divisor original (líneas 108..115, en blanco en 109..114) y toda la primera vista quedan intactos. No se puede dibujar nada en 109..114 (forced blank) y las únicas líneas de divisor visibles son 108 y 115, así que la franja se dibuja sobre las tres últimas líneas de la primera vista sin fondo: guiones de 4x1 con extremos negros en carriles en las líneas 106 / 107 / 108, líneas de salida/meta como un tile de 3 líneas en las líneas 106..108. El contraste sobre una carretera gris es débil.
  * Las líneas de salida/meta son un tile 4bpp del BG1 (`$A8`, palabra de VRAM `$A80`; `$A9` = negro sólido) escrito junto con el tilemap del HUD: el hook en `00:CBE2`
    (forced blank) sustituye el bucle de la fila 13 y escribe él mismo las filas 13/14 (`$0DA0..$0DDF`). El BG1 usa los colores 1 (blanco), 2 (negro) y 3 (rojo) de la paleta 3
    que el juego ya carga. Los tiles `$82..$BF` de la zona de caracteres del BG1 (VRAM `$1040..$17FF`) estaban sin uso en todas las pistas probadas.
* Smoke test (`tools/rando_smoke.sh seed...`): 40 semillas aleatorias, ~5000 frames cada una con un piloto automático, sin atascos
  (race_frames dentro del 6% del tiempo real; las pistas más largas son algo más lentas). `scripts/rando_pit.lua`: el coche del ordenador
  para en el pit en una pista generada (estado FFFF..0000, combustible repostado hasta A7FF).
* Pit stop humano (`tools/rando_pit_test.sh "seed objetivo"`, `scripts/rando_pit_human.lua`): el coche del jugador se guía más allá del objeto de
  entrada del pit (el bit de lado del objeto activo = *izquierda* = lateral negativa; objetivos -9300 estilo 41, -17500 estilo 45,
  +17500 estilo 47) y la secuencia del pit corre hasta el final con el depósito lleno - verificado en New York, Hiroshima, Rio, Rome.
* El modo 2 jugadores (`TWO=1 scripts/rando_menu.lua`) arranca y renderiza las dos vistas.
* Ciclo completo (`scripts/rando_loop.lua`): menú -> carrera -> resultados -> ranking -> menú principal -> nueva carrera.
* El modo demo/attract (título inactivo) inicia una carrera demo con la semilla que haya en `7F:F800`.

## Limitaciones conocidas / ideas

* Las semillas son hex simple, 8 dígitos; el teclado escribe alineado a la derecha (`AB12` = `0000AB12`).
* Sin minimapa procedural (sustituido por la franja de progreso de la vuelta de arriba). La calle de boxes necesita una pieza de plantilla de escenario 20 (tipo 3): verificado visualmente
  en varios entornos, pero no exhaustivamente.
* Equilibrio de combustible: 8 vueltas de una pista de 46 piezas necesitan dos paradas; la IA se ocupa de eso, el jugador tiene que usar el pit.
* Trampa: **Mesen aplica automáticamente el `<nombre de la rom>.ips`** que encuentre junto a la ROM. Un `out/rando.ips` viejo de un build anterior se aplicó encima
  del nuevo `out/rando.sfc` en la GUI (síntoma: Left/Right en la fila SEED caía en la RAM en `00:2020`); `build_rando.py` ahora reescribe
  el IPS en cada build. El `--testRunner` headless lo ignora, así que el bug solo se veía en la GUI.
* El modo 2 jugadores, los niveles de skill y las opciones usan el código original (no reprobados individualmente).
* La tabla de récords de vuelta sin uso `$1FB2..$1FF1` se usa como borrador de cadenas por los hooks del menú.

## Ronda de revisión 2 (2026-10-16)
* Los **estilos de pit** son copias de las combinaciones originales (plantilla, bit de lado, grupo 41/45 = pit a la izquierda, 47 = pit a la derecha, plantillas de bandera y slot,
  estilo de carretera del tipo 3, espejo). El bit 15 de la palabra del pit no es izquierda/derecha. `hook_style` (`00:C270`) sobrescribe la palabra de estilo de carretera por entorno
  `00:DEE4` (bits 9-11, bit 15) para que la calle de boxes sea una carretera de verdad en entornos cuyo estilo propio del tipo 3 es otro.
* Banderas: `13` en b0/b1 de las piezas pp-2 y pp-1 en el lado del pit; chevrons cada 4 slots desde 20 slots antes de una curva hasta su final.
  Solo la última pieza antes de la línea es vacía y recta (las curvas pueden llegar hasta ella, como en la Florence original); sin chevrons a menos de 48 slots del pórtico de salida (un conflicto de gráficos los corrompía en la semilla 12345678).
* **Pórtico de salida**: el escáner `00:E20D` conserva como mucho 8 ids gráficos distintos; tipos de objeto extra de las piezas de pit/chevron hacen que el
  pórtico (grupo `$8002`) desaparezca en algunos entornos. `tools/gantry_search.py` encuentra por entorno tipos de objeto que descartar de la fuente
  copiada (tabla `DROP` en trackgen.py / `dropt` en gen.asm). Los 32 entornos muestran el pórtico (`out/ge_sheet.png`).
* El sorteo de semilla mezcla los contadores H/V y la semilla antigua en 4 rondas del RNG para que cada dígito cambie.

## Pool de gráficos: escenario corrompido (ronda de revisión 4, 2026-10-17)
Informe del usuario: pórtico de salida/meta corrompido (semillas E3973884, 77675249), gráficos laterales corrompidos cerca de la meta / a mitad de vuelta / junto a las rocas grandes
(3142E2A7, B09742CB, FF6E4160, 82C31DDC) y corrupción "por todas partes" donde aparecen muchos árboles (84373410).

**Causa.** El escáner lateral `00:E20D` corre cada dos frames y mira los 4 slots 40..43 por delante de la cámara. El id gráfico de cada
tipo de objeto (`00:E9BA[type]`; los objetos de grupo se expanden mediante `00:E888 / E89A`) se carga por DMA en un **pool de VRAM de 8 KB = 256 unidades de 32 bytes**
(tamaño del id `i` = palabra en `00:E888 + 4 * i`; árboles 34..184 unidades, chevrons 54, banderas de pit 58, **el pórtico de salida 254**). La asignación es
*first fit por dirección* en una lista de como mucho 8 bloques; un bloque se libera cuando la cámara pasa el último objeto de su tipo. Un tipo que no cabe
en ningún sitio se salta (`00:E3BF`, contado por `scripts/rando_pool_probe.lua`) y, como un slot solo se explora durante pocas llamadas, sus objetos se dibujan con
los tiles que casualmente haya en la VRAM. Dos cosas lo rompían en las pistas generadas: (1) el pórtico necesita el pool entero, así que cualquier objeto a ~43 slots antes
o ~41 después de la línea (las piezas aleatorias 1 y L-1 tienen árboles) no le deja sitio, o los vecinos no pueden cargar; (2) piezas mezcladas + obstáculos + chevrons + árboles
mezclan muchos tipos y el pool se fragmenta (un árbol de 142 unidades necesita un hueco libre de 142 unidades; el espacio libre total no basta). Las pistas originales evitan la mayor parte a mano
(y aun así fallan brevemente en algunos puntos: `tools/pool_model.py --orig`).

**Modelo** (`tools/pool_model.py`): la cámara avanza un slot por paso, mismas reglas de lista / first fit / expiración. Reproduce el emulador: la semilla 3142E2A7 falló las cargas
en los slots de cámara 709, 1061, 1205 en ambos; E3973884 en 1269 (cubo del emulador 1264); la pista original 3 falla en 663-667 (emulador: 656).
`garble` = objetos a 40 slots o menos de la cámara cuyos gráficos no están cargados.

**Corrección** (`fit_pool` en trackgen.py, `fit_pool` / `pal_tier` en gen.asm, ejecutados al final de `add_chevrons`, antes de la copia de vuelta):
1. Solo el pórtico a 44 slots antes y 42 slots después de la línea de meta (todo otro objeto que no sea de grupo ahí se elimina).
2. Un conjunto gráfico por pista que cabe en el pool *por completo* (todos los tipos de la vuelta, de modo que nunca haya que desalojar nada): primero los siempre necesarios
   (objetos de grupo, señales de curva 8/9, banderas de pit 13, entrada del pit 21/58; el id 10 del pórtico no cuenta, nada más está cerca), luego el tipo de obstáculo (marcado en
   el array de palabras `KEEP` por `hz_put`), luego los tipos ordinarios según cuántos objetos los usan (la primera aparición desempata) mientras la suma se mantenga <= 224 unidades (256 menos un margen para la fragmentación del first fit: 224 no dejó corrupción en 1000 semillas del modelo, 232 dejó alguna, 256 alrededor de 1 semilla de cada 30 - siempre alrededor del pit).
   Los objetos de tipos no seleccionados se eliminan (alrededor del 27% de los objetos, tipos enteros de las piezas de origen mezcladas; los obstáculos de un tipo que no cabe junto a chevrons y gráficos del pit
   se descartan en lugar de mostrarse corruptos).
Borrador: `KEEP` 7F:3400.., contadores 7F:4000..418F, variables F89A..F8A9. Coste: unos 130 mil ciclos de CPU además de los 740 mil del resto del generador.

**Resultado.** Modelo, 1000 semillas aleatorias: ningún slot de cámara corrupto (antes: 40 de 60 semillas, unos 130 slots cada una; con 256 unidades en lugar de 224: 5 de 300 semillas, en la zona del pit).
Emulador (`scripts/rando_pool_probe.lua`, contador de cargas fallidas a lo largo de una vuelta): las siete semillas reportadas pasaron de 9..141 cargas fallidas a 0, igual que 7 otras semillas;
las tres semillas que la versión de 256 unidades aún fallaba (BC095D63, 5A40D714, 8441E20C) quedan limpias con 224. Un primer intento, adelgazar objetos siempre que la suma de tipos distintos en una ventana de 79 slots superara 256 unidades, no bastó (fragmentación) y se descartó.

## Relleno del escenario lateral (ronda de revisión 3)
Los entornos cuya pista original es escasa quedaban con los laterales vacíos. Tras las señales de curva, `add_chevrons` (ambos generadores) rellena cada
8º slot vacío (desde el slot 52, nunca a menos de 48 slots del pórtico, nunca en las piezas del pit ni en la última pieza) con un árbol/arbusto,
alternando lados, 60 unidades fuera del borde dibujado de la carretera. Los dos tipos vienen de una tabla por entorno (`SCENERY` / `scent`:
los dos tipos de árbol/arbusto más comunes del entorno en los datos originales, menos el tipo DROP del entorno). Los entornos 2, 8, 9, 14 y algunos otros no tienen ninguno
(su arte para otros tipos no se carga - probado en el entorno 14: los tipos 15/24/27 no dibujan nada), así que siguen tan escasos como los originales.

## Obstáculos e independencia de la dificultad (ronda de revisión 3)
* La máscara de objetos es ahora siempre `$E000` (objetos de todas las dificultades): la semilla decide la pista, no el ajuste de dificultad.
* Los árboles de Black Forest (tipo 31) solo se eliminan a 64 slots o menos del pórtico (`DROPW`); todo otro entorno sigue descartando sus tipos DROP en todas partes (una ventana de 128 slots no bastaba para ellos).
* `add_hazards` (ambos generadores, después de las señales de curva, antes del relleno de escenario; `HAZARD` / `hazt` = tipo de roca y tipo de barrera por entorno, tomados de los tipos que usa el propio original del entorno):
  **Frecuencia igualada a la de los originales** (objetos del campeonato: 18 grupos de objetos en la carretera / 13 grupos de barrera en 32 pistas = 0,56 / 0,41 por pista; los tramos copiados ya dan 0,48 / 0,32, así que solo se añade un poco: 0,60 / 0,34 en 400 semillas):
  una pista de cada 8 recibe un campo de rocas (el patrón de la salida original de Los Angeles, 26 slots) en lo primero que ocurra de: 70 slots antes del inicio de una curva cerrada (|curve| >= 32), 8 slots después del final de una pendiente pronunciada (|slope| >= 64);
  una pista de cada 16 recibe un cierre de carril único con barreras (tipo 7, barreras amarillas donde el entorno las tiene) en la primera recta de 112 slots después del slot 300:
  el lado derecho se estrecha hacia dentro, se mantiene, se estrecha hacia fuera mientras el izquierdo se estrecha hacia dentro, se mantiene, se estrecha hacia fuera (como Las Vegas en el campeonato). Nada a menos de 96 slots del pórtico ni en las piezas del pit; señales/pit/objetos de grupo nunca se sobrescriben.
  Pórtico visible en los 32 entornos (comprobado con un script del mismo tipo que `tools/gantry_search.py`).

## Menú principal y series de pistas (2026-10-24)
`src/menu.asm` sustituye el `main_menu` original (`0F:918B` es un `JML mm_run`; los parches del antiguo menú de cinco filas - etiqueta COUNTRY, longitudes de barra,
`hook_lr`, `hook_menu_draw` - han desaparecido). Seis filas, **3 filas de tiles de separación** (filas 6, 9 .. 21 dentro del marco de la página 0, así que nada tiene que desplazarse y las
flechas de "más opciones" arriba/abajo que se planeaban no hicieron falta; si se añade una fila más tarde, el paso puede bajar a 3 con 7 filas antes de que el marco se llene):

| fila | etiqueta | Left/Right | A / Start |
|---|---|---|---|
| 0 | `1 PLAYER` / `2 PLAYERS` | alterna | configuración de jugadores (original `0F:929B`) |
| 1 | `DIFFICULTY` (el menú de skill original, su título también se renombró) | - | menú de skill `0F:9652` |
| 2 | `<n> TRACKS` | anillo `<infinito> 1 2 .. 99`: Left desde `1 TRACK` = infinito, Right desde 99 = infinito | - |
| 3 | `SEED xxxxxxxx` | sortea una semilla nueva | teclado hex |
| 4 | `SPEED KPH` / `MPH` | alterna | alterna |
| 5 | `PLAY GAME` | - | empieza |

* Las etiquetas son la fuente grande del juego dibujada por `draw_string_to_buffer` en el búfer de texto (`mm_text`, cadenas en el banco `$10`); el número de pistas es un campo de dos glifos en la columna de tile 5 (dígitos alineados a la derecha, así ` 7`
  y `12`, `mm_dig`) escrito directamente en el tilemap a partir de los glifos de dígito de arriba, luego un espacio y `TRACKS` / `TRACK ` en la columna 11; el **signo de infinito** (dos glifos) llena el campo. La lista de etiquetas de la página 0 se redirigió (`0D:C738`, tabla b) a una lista que solo
  tiene el título `OPTIONS` (en la cola libre del banco `$0F`, `0F:FF17`).
* **SEED solo está activa con `1 TRACK`.** Si no, la etiqueta, los 8 dígitos y el selector se ven en gris: las palabras de tile reciben la paleta 5 (`$1400`; ¡la paleta de BG 1 es la foto!),
  la paleta de texto gris se escribe en la sombra de paleta `$050C`, el selector (paleta de sprite 7, sombra `$064C`) se intercambia entre el original y uno gris
  (`mm_selpal`); la NMI sube la sombra cuando `$90 = $004C` (en ese frame no hace nada más, de ahí que `mm_push_pal` espere un frame). El cursor puede pararse en la fila gris,
  A y Left/Right no hacen nada ahí.
* El cursor vuelve a la fila del submenú de donde venías (`MCUR`); tras `PLAY GAME` empieza arriba otra vez.
* Estado (banco `$7F`, `MAGIC2 $5AA5` lo protege, inicializado por `menu_init` - separado del magic de la semilla porque los scripts de prueba tocan el magic de la semilla): `TRKS $FA00`
  (0 = infinito, 1 = una carrera = por defecto), `DONE $FA02`, `PODIUM $FA04`, `MCUR $FA06`, `CUR $FA08`, `SELG $FA0A`, puntuaciones `TOTLO $FA20..` / `TOTHI $FA40..` (20 coches).

* **Carrera única (`1 TRACK`): sin ranking mundial.** `0F:8457` -> `hook_rank` (hace él mismo el `unpad_names`, pues destruye A): con `TRKS == 1` se salta el desplazamiento hasta el ranking y la pantalla de resultados va directa al fundido de salida (`0F:8484`) y al menú principal; las series sí muestran el ranking.

### Series (TRKS != 1)
* `PLAY GAME` (`hook_play`): puntuaciones a cero, **una semilla aleatoria nueva** para cada carrera (SEED está inactiva), `DONE = 0`.
* Tras la pantalla de ranking (`hook_afterresults`, `0F:8487`): `DONE++`; infinito o `DONE < TRKS` -> `roll_seed`, `rando_env`, el estado de scroll/fuente del camino original
  de "carrera superada", `JMP 0F:818E` = pantalla de splash de la siguiente pista y la carrera (el original sigue el mismo camino tras una carrera superada; la parrilla de la siguiente carrera sigue
  los puestos `$1F00/$1F02`, como en el campeonato). `TRKS == 1` -> vuelta al menú principal como antes (título saltado una vez).
* **Las puntuaciones siguen sumándose, como valores de 16 bits** (el original tiene un byte por coche, lo que bastaba para su campeonato corto; una serie larga daría la vuelta tras 12 victorias y mostraría dos dígitos, así que el randomizer amplía el campo): `0F:8889` (la suma en la tabla
  de resultados) -> `hook_addpts`, el bubble sort del ranking mundial (`0F:896F`) -> `hook_cmp`, `draw_points_column` (`0F:8B4E`) -> `hook_ptscol` (hasta 5 dígitos, 0..65535, **alineado a la izquierda** desde la
  columna 17, espacios tras los números cortos; `HIGH=1` en scripts/rando_series.lua falsifica puntuaciones grandes para comprobarlo). Los coches 0 y 1 son los dos humanos (o el jugador 1 y el coche COMPUTER en 1P), 2..19 los bots; `$1F4E` ya no se usa.
* **Sin game over.** Las pruebas de clasificación (top 5 por carrera, top 3 por país), el borrado de puntos y el regreso al título/KEMCO del original ya no son alcanzables
  (docs/13 las lista); nada en el randomizer termina una sesión por un mal puesto.
* **Podio** (tras la última carrera de una serie finita, `podium_start`): se reutiliza la pantalla de escena de docs/13 sección 5 - pared de cuadros `TG`, un piloto por humano
  (celebrando si un humano está en el top 3 de la clasificación, si no el triste) y una etiqueta `PLAYER n <place>` de `build_finish_order` (puesto = posición en la
  serie, `$1F62`); 2P muestra a los dos jugadores, 1P solo al humano (el coche COMPUTER no tiene escena). El mensaje es nuestro (`THANK YOU FOR PLAYING!` para ambos pilotos; la fuente no tiene `!`, así que `pod_bang` sube un tile de 8x8 dibujado (`font/podium/exclam.bmp`, incorporado en `pb_gfx` por `tools/bigfont.py`) a la palabra de VRAM `$1600` y lo escribe detrás del texto), con hooks en `0F:8584` / `0F:8592`; el bloque de contraseña (`0F:85F2`) se salta; el podio toca la música de la escena original "completed Top Gear" (`play_music` 6, mediante `t_music`, ambas escenas) y `hook_podend` llama a `play_music` 0 (sube y reinicia la música del título / menú, como hace el original de camino al título) antes de `jml 0F:815A` - sin eso el título quedaba mudo (comprobado registrando el puerto 0 de la APU: `07` en el podio, `00`,`01` al volver); el scroll del BG1 debe
  ponerse en `$0010` antes (el ranking desplaza la capa fuera: pantalla negra sin eso). Tras pulsar una tecla `hook_podend` (`0F:8669`) va al menú principal (título saltado una vez).
* Las series infinitas nunca llegan al podio; el ranking mundial tras cada carrera es el marcador.

Pruebas: `scripts/rando_series.lua` (variable `TRACKS` = 0 infinito / n, `TWO=1`, `PLACES="0,3,.."`, `SHOTS`): configura el menú mediante las teclas, fuerza el final de cada carrera como
`race_end_force.lua` e imprime `results_flow / har_next / podium_start / hook_podend / mm_run` con números de frame (verificado: 1 pista -> menú, 2 y 8 pistas -> podio, 0 -> 9
carreras sin podio, podio 2P con los dos pilotos, puntuaciones de 3 dígitos en el ranking). Los scripts que navegan el menú se actualizaron (SEED es la fila 3, PLAY GAME la fila 5;
`common.lua` añade el Down extra cuando `TG_ROM` contiene `rando`).

## Sin pit en carreras cortas
El coche rojo hace 4,75 km con un depósito en 5ª (docs/12, el coche más sediento). Una pieza son 15/256 km, así que una carrera tiene `L * laps * 15/256` km. Cuando eso es menos del 90 % de 4,75 km (`L * laps <= 72`) la pista se queda sin pit: sin objeto de entrada, sin banderas, sin pieza de plantilla 20, y la palabra del pit es `$7FFF` (posición `$FFFE`, nunca alcanzada, así que sin flecha de pit y sin corredor de pit de la IA). Mismos sorteos de RNG que antes, así que el resto de la pista no cambia. `NOPIT_PIECES` en `tools/trackgen.py`, `pn_m` en `pit_setup` (`src/gen.asm`). Solo ~1 % de las semillas cumplen (3 vueltas de 24 piezas es la única combinación, ya que la carrera más corta tiene 4,2 km); p. ej. 000B99A1, 00150673 (verificado en el smoke test, 400 semillas coinciden con la referencia Python).

**Actualización:** la prueba de juego mostró al coche rojo terminando 3 vueltas de 46 piezas (138 piezas) con un depósito, así que el alcance se toma como 130 piezas y el límite sin pit es el 90 % de eso: `L * laps <= 117` (`NOPIT_PIECES`, `cmp #118`). Alrededor del 16 % de las semillas ahora no tienen pit (p. ej. 0004B66A, 0005CCD1). La cifra de 72 piezas anterior queda sustituida.

**Actualización 2:** el límite se fija a mano en `L * laps <= 129` (`NOPIT_PIECES`, `cmp #130`): sin pit en carreras de 129 piezas o menos. Sustituye al 117 anterior.

**Marcador del pit en la franja de vueltas:** `hook_bar` pone el tile `$AA` del BG1 (VRAM `$0AA0`: caja negra con un guion blanco en las tres líneas de la franja) en la fila 13 en la columna de tile del pit, `(24 + pit position * 200 / lap length) / 8`, usando la palabra del pit del generador `$7FF83E` (`$1EF0` aún no está definido cuando se construye el HUD). Las pistas sin pit no tienen marcador. Comprobado por captura: semilla 00163BC9 (pit en la columna 17), 0004B66A (ninguno).
**Desplazamiento:** el marcador se dibuja 2 piezas (2048 unidades) después de la palabra del pit, es decir, en la entrada y no al comienzo de las banderas (semilla 00163BC9: columna 17 -> 18).

## Vuelta perdida en una colisión en la línea de meta (bug del juego original, corregido en el randomizer)
*Solo el primer problema de abajo existe en el juego original. Las dos "regresiones" las introdujo nuestra propia corrección y se corrigieron en la 0.4 y la 0.5.*
Un golpe entre coches coloca el coche humano en "posición del otro coche - 8" (`05:E55C`, `E577` para el humano 1; `E73B`, `E756` para el jugador 2 / el coche del ordenador). Si el otro coche ya está más allá de la línea (posición 0..7, byte de vuelta +1) y el humano está a pocas unidades antes de ella, el resultado es negativo (>= `$FC00`): la comprobación de vuelta en `05:E789` lo lee como "aún antes de la línea de salida" y quita una vuelta (`$1E76`, byte de vuelta `+9`), y el cruce real un instante después solo se la devuelve, así que la vuelta nunca cuenta (en la última vuelta: la carrera no termina). Reproducido en la ROM original y en el randomizer con `scripts/finish_collide.lua` (humano en línea-3/-6, coche más lento en 0/3/6 por delante en la lista: vuelta 0 en lugar de 1; el coche detrás en la lista está bien).
Corrección (`src/hooks.asm`, `hook_hit1/2` + `hit_pos` en `13:8000`): la nueva posición se calcula en la vuelta del propio humano: la diferencia de byte de vuelta +1 suma la longitud de la pista, -1 la resta, y el resultado se limita a `0..length-1`. El estado de parrilla de la vuelta 1 (posición >= `$FC00`) mantiene el comportamiento original. Tras la corrección las mismas configuraciones dan vuelta 1 y la carrera continúa con normalidad. El caso opuesto (humano más allá, otro coche no) no puede colisionar: la prueba de solapamiento compara posiciones brutas.

**Regresión encontrada en la BETA 0.3 (informe de un amigo: golpear a un bot cerca del pit lanzaba el coche más allá de la línea de meta e iniciaba la siguiente vuelta):** `hit_pos` trataba toda diferencia de byte de vuelta de +1 como "el otro coche ya cruzó la línea" y sumaba la longitud de la pista, así que golpear a un bot que había doblado al humano (mismo punto de la pista, byte de vuelta +1) limitaba el coche a la última unidad de la vuelta y el cruce de la línea contaba una vuelta (semilla 12345678, humano 7000 / bot 7004 vuelta+1: pos 262, vuelta 1; la ROM original mantiene pos 7505, vuelta 0). Ahora el ajuste solo se aplica junto a la línea: vuelta+1 cuando el otro coche está en posición < `$0400` (o negativa), vuelta-1 cuando está a `$0408` o menos del final. Los casos de línea de `finish_collide.lua` siguen dando vuelta 1; los casos de coche doblado dan el resultado simple.

**Segunda regresión (BETA 0.4, informe: el P2 en single player golpeó a un rezagado cerca de la línea y fue puesto en la línea, una vuelta atrás):** la primera corrección aún solo miraba al *otro* coche. Los dos coches antes de la línea con el rezagado una vuelta atrás (byte de vuelta -1) tomaban la rama "humano ya más allá, otro no", restaban la longitud de la pista y limitaban a 0: el coche perdía todo su progreso de la vuelta. `hit_pos` (compartido por el humano 1 y el P2/coche del ordenador) ahora exige que el propio coche golpeado esté del lado correcto de la línea: vuelta +1 solo si nuestra posición está en los últimos `$0400` o ya pasó la longitud (la vuelta en `05:E789` llega después en el mismo tick, en el juego vimos `$B80C` frente a la longitud `$B800`), vuelta -1 solo si estamos en los primeros `$0400`. En otro caso vale el simple "otro - 8", limitado a 0 para que un coche justo después de la línea nunca sea puesto detrás de ella (esto también corrige el defecto original para "nos dobló justo después de la línea"). `scripts/hitpos_unit.lua` llama a `hook_hit1/2` directamente dentro de una carrera (WHO=1|2, OWN, OPOS, OLAP; las posiciones negativas son distancias antes de la línea) e imprime la posición devuelta; `scripts/finish_collide.lua` comprueba al humano de punta a punta (47100/3/+1, 47098/0/+1, 47090/6/+1: vuelta 1; 7000/7004/+1: simple).
