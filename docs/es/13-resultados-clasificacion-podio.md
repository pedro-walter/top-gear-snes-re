# Flujo posterior a la carrera: resultados, puntos del campeonato, clasificación, game over, escena del podio

Todo aquí se leyó en el desensamblado (`results_flow` 0F:83D7 y alrededores) y luego se **reprodujo en Mesen headless** falsificando el final de una carrera
(`scripts/race_end_force.lua`, ver "Cómo reproducir"). Los caminos y mensajes exactos de abajo se vieron todos en pantalla.
Nombres: `$1F4E` etc. están en `disasm/annot/ram.txt`, las rutinas en `disasm/annot/symbols.txt`.

## 1. Dónde la carrera cede el control
* Bucle de la carrera (00:877D): `$1EB0` (finish_count) >= 10 -> `race_exit` 00:8834 -> `JSL menu_entry` (0F:806D) con **A=1** -> `results_flow`.
  (A=0 es el camino de arranque/juego nuevo = `location_screen`.) Después 00:8875 `JMP main_restart` inicia la siguiente carrera.
* `$1F12[0..9]` = ids de coche en orden de llegada (escrito por `cars_update` 00:A1F9 para los bots y 05:E7E2 para el humano; `race_end_simulation`
  rellena el resto), `$1F26 + 2*id` = tiempo de llegada en frames, `$1F00` / `$1F02` = puesto (base 0) del jugador 1 / 2 (`$1EB0` en el momento en que terminaron).
  Id de coche 0 = jugador 1, id 1 = jugador 2 / el coche COMPUTER, ids 2..19 = los 18 bots con nombre (nombres en 0D:C47B + (id-2)*8).
* `$1F00..$1FFF` **no** lo limpia `main_restart` (limpia solo `$0000-$1EFF`), así que ese bloque es el "estado de guardado" persistente de una
  sesión: pista `$1F06`, skill `$1F10`, desbloqueo `$1F0A`, puntos `$1F4E`, nombres, récords de vuelta `$1FB2`, ...

## 2. Pantallas, en orden (todas dentro de `results_flow`, 0F:83D7)
1. **RESULTS** (`draw_race_result_table` 0F:882D): 10 filas, puesto, nombre, tiempo (primera fila absoluta, las demás `+diferencia`), puntos de esta carrera. Espera una tecla.
2. **WORLD RANKING** (`draw_points_table` 0F:894F): los 20 coches ordenados por puntos del campeonato, con desplazamiento hacia arriba y abajo. Espera una tecla.
3. Prueba de clasificación (abajo). Según el resultado:
   * pasó a mitad de país -> directo al menú principal (`loc_0F818E`) con la siguiente pista seleccionada, **sin mensaje**;
   * todo lo demás -> la **pantalla de escena** (sección 5) con un mensaje, y luego el menú principal o la pantalla de título/KEMCO.

## 3. Puntos del campeonato
* Tabla en **0E:8024**, indexada por la posición de llegada 0..9: `20 15 12 10 8 6 4 3 2 1` (luego ceros). Solo puntúan las 10 entradas de `$1F12`.
* `$1F4E + id del coche` (1 byte por coche, 20 bytes). Se **suman como efecto secundario de dibujar** la tabla RESULTS (0F:887F..8891:
  `$1F4E[id] += 0E:8024[position]`), es decir, solo cuando corre la pantalla de resultados.
* Se conservan entre carreras porque nada los pone a cero salvo:
  * el arranque (00:80B2, corre solo en el reset),
  * `advance_track` al **inicio de un país nuevo** (0F:8750, es decir, después de cada 4ª carrera, *antes* de la prueba de país, usando la lista ordenada ya construida),
  * los dos caminos de fallo (0F:84CB / 0F:84E1).
  El menú principal (COUNTRY / SKILL / 1-2 PLAYERS) nunca los toca; así que cambiar de país a mitad de camino conserva los puntos.
* `draw_points_table` construye `$1F62[0..19]` = ids de coche ordenados por puntos, **el mejor primero** (un bubble sort sobre `$1F4E[id]`; los empates conservan el orden de la lista),
  y dibuja los nombres (tabla 0D:C47B; id 0 / 1 usan los nombres de los jugadores, o "COMPUTER") más la columna de puntos (`draw_points_column`, 0F:8B4E, limitada a 2 dígitos por `byte_to_ascii`).
  Así `$1F62` es la clasificación del campeonato y `$1F62[0]` es el líder.

## 4. Clasificación (este es el "game over")
Un país = 4 pistas consecutivas (`$1F06 & 3` = 0..3, país = `$1F06 >> 2`, 8 países, 32 pistas). Sea `N` = número de humanos (`$1F04 + 1`; 1 en 1P, 2 en 2P); los ids de coche < N son los humanos.

| prueba | código | regla | resultado del fallo |
|---|---|---|---|
| **por carrera** `qualify_check_1p` 0F:871A | llamado en 0F:84A4 | un id humano debe estar entre las primeras **5** entradas de `$1F12` (terminó 1º..5º en la carrera) | mensaje A=1, puntos borrados |
| **por país** `advance_track` 0F:8733 | solo tras la 4ª carrera (`$1F06 & 3 == 0` después del INC) | un id humano debe estar en `$1F62[0..2]` (**top 3** de la clasificación del campeonato, orden de empate como ordenado) | mensaje A=2, puntos borrados |

Límites verificados en el emulador: el 5º puesto en una carrera pasa, el 6º falla; el 3º en la clasificación se clasifica, el 4º no (pruebas: `PLACE=4`/`5`, falsificando `PTS=`).
En 2P basta con que pase uno de los humanos. La dificultad no cambia los umbrales (solo cambia qué texto de contraseña/continuar se muestra).

Flujo tras las pruebas (`results_flow` 0F:84A4-84F5; el valor que acaba en la pila = código de mensaje `A`):

| resultado | A | qué ocurre |
|---|---|---|
| falló la prueba de carrera (0F:84CB) | **1** | puntos `$1F4E` a cero, `$1F00=0`, `$1F02=1` (reinicio de la parrilla: el humano sale al fondo); **`advance_track` se salta**, `$1F06` sin cambios. |
| carrera OK, mitad de país | 1 (de `advance_track`, carry limpio) | `$1F06++`, `JMP 0F:818E` = menú principal con la siguiente pista. Sin pantalla de mensaje. |
| fin de país OK, no es el último país | **0** | `$1F06` ya es la primera pista del siguiente país; muestra la escena feliz + contraseña, luego `JMP 0F:818E` (menú principal). |
| falló el fin de país (0F:84E1) | **2** | puntos a cero, reinicio de la parrilla como en A=1, `$1F06` **ya avanzó al siguiente país** (ver la rareza). |
| fin de país OK en la pista 31 (`$1F06` vuelve a 0) | **3** | escena "completed Top Gear" (0F:84C0 pone A=3 cuando `$1F06 == 0`). |

El valor A=1 que `advance_track` devuelve para "siguiente carrera en este país" es también el que empuja el camino de carrera fallida; los dos se distinguen por el `BCS` justo después de `qualify_check_1p`.
El **reinicio de la parrilla** (`$1F00=0, $1F02=1` = puestos de llegada anteriores) es lo que hace que el humano salga al fondo/frente de la siguiente parrilla (ver docs/03).

### Qué hace un fallo con el flujo del programa
Los mensajes con A != 0 terminan en 0F:866F: `$1FF6 (attract_flag) = A` (1/2/3), música 0, luego
```
$1F08 = $1F06 & 0x1C ; $1F0A[skill] = max($1F0A[skill], $1F08 >> 2) ; JMP results_flow
```
y el principio de `results_flow` (0F:83DD) ve `$1FF6 != 0`: `$1F06 = $1F08` y `JMP location_screen` (0F:815A) -> `title_screen` (0F:8C95) con la introducción completa:
**logo "presents" de KEMCO -> animación del logo TOP GEAR -> PRESS START** (unos 860 frames hasta que el título espera una tecla), la misma secuencia que al encender la consola.
La pantalla de título sobrescribe `$1FF6` con la cuenta atrás de attract 0x04B0, así que la flag solo sirve para que `results_flow` tome esta rama. Una tecla pasa entonces al menú principal
(opciones: 1 PLAYER / SKILL LEVEL / COUNTRY / SPEED / PLAY GAME, `main_menu` 0F:918B); una cuenta atrás inactiva de 0x4B0 frames inicia la carrera demo de attract.
Solo A=0 (país superado) salta el título y va directo al menú. Nombres, récords de vuelta, skill, unidades, controles sobreviven; puntos y posiciones de parrilla no.

### Rarezas encontradas (para que nadie tropiece)
* **Fallar la prueba de fin de país no bloquea realmente el siguiente país.** `advance_track` ya incrementó `$1F06` a la base del siguiente país, así que
  `$1F08` / `$1F0A[skill]` reciben el siguiente país: tras "SORRY YOU FAILED TO QUALIFY FOR THE NEXT COUNTRY" el menú principal está en el país N+1 y COUNTRY lo lista como desbloqueado
  (observado: `$1F06=4`, `$1F0A=1` tras fallar en la pista 3). Solo se pierden los puntos. Fallar una sola carrera (A=1) sí te mantiene en el mismo país (`$1F06` sin cambios -> reinicia en la
  primera pista de ese país, ya que `$1F06 = $1F08` = base del país).
* El mensaje de fallo A=2 **también imprime la contraseña del siguiente país** (el código de contraseña en 0F:85F2 solo comprueba `$1F06 & 0x1C != 0`).
* El puesto impreso junto al nombre del jugador es el **puesto de la carrera** en el fallo A=1 (`$1F00+1`, `build_finish_order` se salta) pero la **clasificación del campeonato**
  en todos los demás caminos (`build_finish_order` 0F:86E7 lee `$1F62`, así que "PLAYER 1  9TH" tras un país fallido significa 9º en la clasificación).
* El bucle de `advance_track` en 0F:875E compara ids adyacentes que son siempre distintos, así que es un `Y=2` constante ("top 3"), no una prueba de empate.
* Las contraseñas de un país solo se muestran (nunca se exigen durante el juego): `0D:C513 + (country-1)*8 + skill*0x38`, ver docs/05.

## 5. La pantalla de escena ("podio"): piloto en el estrado + mensaje
No existe un podio con varios coches. La imagen es **un piloto apoyado en una barandilla frente a una pared de cuadros "TG"**, más un mensaje de 3-4 líneas y, para 1P, una etiqueta amarilla/negra
`PLAYER 1  <place>` sobre el piloto (dos etiquetas y dos pilotos en 2P).
* Los gráficos, todos en `results_flow` 0F:84F5-8532: `0D:AE51` -> VRAM $2200 (tiles del piloto/pared), `0D:C24B` -> WRAM `$7E2000` (una franja de tilemap de 8x19 tiles, los *frames* del piloto),
  `0F:BBA7` -> VRAM $1000 (fuente del mensaje). Paleta: `0E:FD66` (`load_results_palette` 0F:8705, 16 colores), fundido a negro de entrada/salida con `fade_in_dma` / `fade_out_dma`.
* La escena la compone **`draw_country_flag` 0F:914E** (nombre engañoso heredado del menú principal, donde dibuja la bandera del país; aquí A selecciona al piloto): escribe
  los tiles de la pared con `draw_flag_tiles` (0F:911C, 8 columnas x 19 filas copiadas de `$7E2000` al búfer de tilemap del BG `$0C6C+Y`) y luego al piloto con `sub_0F9102` (0F:9102):
  * A = **0 o 3** (se clasificó / completó el juego): base de tile `$25`, desplazamiento de franja `$0130`: **el piloto celebrando** (brazo en alto, corona de laurel verde, botella de champán);
  * A = **1 o 2** (falló): base de tile `$A1`, desplazamiento `$0260`: **el piloto triste** (brazos cruzados sobre la barandilla, mirando hacia abajo).
  En 2P se dibujan ambas mitades (base de paleta $0D20 para el jugador 2) usando el mismo A.
* Cadenas de mensaje (ROM 0F:B1C7..B2F3, formato `draw_string`: byte de fila, byte de columna, ASCII, 0 ... terminador 0 de la lista), 0F:8551 las elige con A:

| A | cadenas | música (`play_music`) |
|---|---|---|
| 0 | "CONGRATULATIONS / YOU QUALIFIED FOR THE NEXT COUNTRY / PASSWORD xxxxxxxx" (B1C7) | 5 |
| 1 | "SORRY / YOU FAILED TO QUALIFY FOR / THE NEXT RACE" (B23B) | ninguna (la música del menú sigue sonando) |
| 2 | "SORRY / YOU FAILED TO QUALIFY FOR / THE NEXT COUNTRY / PASSWORD ..." (B202) | ninguna |
| 3 | "CONGRATULATIONS / ON COMPLETING TOP GEAR" (B271) + amateur: "BUT CAN YOU WIN ON PROFESSIONAL LEVEL" (B29E), professional: "... CHAMPIONSHIP LEVEL" (B2CA), championship: nada más | 6 |

  (las etiquetas de puesto las dibuja `draw_result_row` 0F:8693 con sufijo ST/ND/RD/TH de `$1FF8`/`$1FFA`; en 2P se dibujan las dos etiquetas, el orden depende de qué jugador quedó mejor, no rastreado más allá.)
* Luego `wait_input_long` (0F:9EAC), fundido de salida y la salida dependiente de A, arriba.

## 6. Ganchos para un hack
* Para hacer inofensivo un fallo (p. ej. un randomizer sin campeonato): parchear `qualify_check_1p` (0F:871A) a `CLC; RTS` y el final de `advance_track` (0F:8733) para devolver carry limpio. El randomizer ya
  esquiva todo esto, ver docs/09 / docs/10 (`0F:8487`: resultados -> menú principal).
* Umbrales distintos: la cuenta top-5 es el `LDY #$0004` en 0F:871D; la cuenta top-3 es el `LDY #$0002` en 0F:8759 (inicio del bucle en 0F:875E; la cadena de comparación usa Y como último índice).
* Valores de puntos: 10 bytes en la ROM 0E:8024 (offset de archivo 0x70024).
* Escenas distintas por resultado: A es solo el selector de tabla en `draw_country_flag`; los dos frames de piloto viven en la franja `0D:C24B` (ids de tile `$25..` / `$A1..`).

## Cómo reproducir (receta para agente)
```
TAG=a PLACE=5 TRACK=1 MAXF=6000 tools/mesen.sh scripts/race_end_force.lua | grep -v Uninit      # fallo a mitad de país (6º)
TAG=b PLACE=0 TRACK=3 MAXF=4300 tools/mesen.sh scripts/race_end_force.lua                         # país superado (1º, solo la 4ª carrera)
TAG=c PLACE=4 TRACK=3 PTS="0,0,90,80,70,60,50,40,30,20,0,0,0,0,0,0,0,0,0,0" ...                 # fallo de país (9º en la clasificación)
TAG=d PLACE=0 TRACK=31 DIFF=0 ...                                                                 # completó el juego
python3 -I tools/contact_sheet.py a 4 330 660 out/a.png                                          # frames out/a_<n>.png como cuadrícula
```
El script inicia una carrera real de 1P a través de los menús, luego en el frame 3300 (en la siguiente ejecución de 00:877D, donde M=0 y DP=0 están garantizados) escribe `$1F12` (lista de llegada, el humano en `PLACE`),
`$1F26`, `$1EB0=10`, `$1F00`, puntos `$1F4E` opcionales, `$1F06`, `$1F10` y pone el PC en 00:8834 (`race_exit`). **No** pongas el PC desde `endFrame`: se atiende antes una NMI y el RTI restaura
los flags M/X antiguos, lo que decodifica mal las cargas de 16 bits (vimos basura `$1FF6=$0080` así). Imprime el flujo con hooks de PC (`FAIL_RACE`, `FAIL_COUNTRY`, `WIN_COUNTRY`, `msg0..2`, `set_flag`, `title_screen`, ...)
y líneas `STATE` (`$1F06`, `$1F08`, desbloqueo `$1F0A..`) y pulsa A cada 1,5 s para pasar por las pantallas de espera de tecla.
