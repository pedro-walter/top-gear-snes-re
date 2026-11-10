## Pendientes / próximos pasos
1. Nombrar las rutinas restantes del banco 05 (dirección, colisiones, IA, lógica de vuelta/posición). Usa el patrón de `scripts/writers.lua`
   (callbacks de escritura/lectura) en los vecinos de `$1E5A` ($1E58-$1EFF parece ser la struct del coche del jugador) y en las
   structs de los oponentes.
2. Formato de los datos de la pista (curvas/pendientes): encontrar el lector que rellena las tablas de scroll de HDMA.
3. IA (rubber-banding): inspeccionar las escrituras en la struct del ordenador.
4. Descompresor (`$00:EA8E`/`EA9B`, `EBB6`) y los bancos de gráficos/música (el 91% de la ROM no es código).
5. Carga del driver de sonido SPC700 (`$07:8000` parece serlo).
6. 13 saltos indirectos sin resolver listados al final del desensamblado (tablas de salto).

---

## Adendas (verificadas en el emulador)
* `$1E90` = delta de frames (`$0C` frames transcurridos + 1) – el bucle principal se basa en el tiempo; el progreso y el movimiento lateral escalan con él, motor/arrastre/combustible son por tick (así que el consumo de combustible depende de la tasa de frames).
* Progreso por frame: bots `speed/256` unidades (medido exactamente), jugador `speed/512` por unidad de velocidad => un valor de bot v equivale a una velocidad de jugador 2v (km/h = v*0,0469): los bots crucean a ~94..177 km/h en la pista 0 fácil.
* **Rubber band del coche del ordenador** (05:EE19, verificado): solo en la marcha más alta, solo si la dificultad `$1F10 != 3`, y solo cuando el ordenador va *por delante*: `top -= min(gap, 1024)` donde
  `gap = (laps_ahead*track_len + camera_pos_diff)`; la dificultad 0 lo duplica (hasta -2048). Nunca lo acelera. Las dificultades 1 y 2 se comportan igual aquí, la 3 no tiene ninguno.
* Prueba del pit (modificar la pista `$1F06=3` antes del cargador): el ordenador con combustible 6642 entró en el pit cerca de la pos 7450, repostó hasta 0xA7FF y salió. Pistas con pit: 3,4,6,8,9,11,12,14,15 (`00:DF24`, FFFF = ninguno). Vueltas por pista `00:DEA4`: 3,3,3,6,6,4,6,3,7,5,3,6,7,3,6,8.
* Nitro medido: activo durante 320 frames, cargas 3 -> 2.
* `out/tracks.png` (tools/track_atlas.py): perfiles de curva (rojo) y pendiente (azul) de las 16 pistas.

## Correcciones / confirmado por el usuario (final de la sesión 3)
- La dificultad `$1F10` solo va de 0..2 desde el menú (amateur/professional/championship; escrita en 0F:940D, 0F:96C6). El valor 3 en el código del rubber-band (05:EE19) es solo una rama "ninguno", sin escritor conocido. Amateur duplica la desaceleración del ordenador; professional == championship.
- Truco 3ª marcha + nitro, confirmado por el usuario jugando: 3ª marcha hasta ~250 km/h y luego 5ª. Modelo (physics.py, nitro, depósito lleno, plano) cruce donde la 5ª >= 3ª: tabla de coche 0: 154 km/h (rojo, "igual por encima de ~150"), tabla 2: 221 (morado "~220"), tablas 1/3: 248 (blanco/azul "~250"). Mapeo color->índice inferido, por verificar con $1F8F. Techo de la 3ª marcha con nitro ~265-273 km/h.



## Correcciones encontradas al anotar el desensamblado (sesión 6)
* `$1FF6` **no** es una flag de unidades: es la **cuenta atrás del modo attract / flag de demo** de la pantalla de título ($04B0 frames, luego `0F:90E6`
  inicia una carrera de demo en una pista aleatoria y lo pone en `$8000`; cualquier botón termina la demo). El "km/h cuando
  es negativo" del HUD en docs/03 significa solo "las carreras de demo muestran km/h".
* El trabajo por frame de la carrera no corre en la NMI: `nmi_handler_race` solo lee los mandos. El manejador de IRQ despacha
  mediante el puntero en `$0A` (`00:B6D1` ...) y la gran rutina de vblank se llama mediante `$08` (`00:B75A`); día/noche
  (`00:BAB9`), puntos del mapa, DMA del equipo de boxes y el escáner de escenario son secciones de ella.
* La entrada de texto del menú (`0F:943D`) es una cuadrícula de 6 columnas (`A..Z`, luego celdas de glifo `3`/`4` = espacio/borrar, `END`) que escribe hasta 8
  caracteres en `$68..$6F`; el menú principal (`0F:918B`) tiene 5 entradas (jugadores, skill, país, mph/kph, play game).

## Hallazgos al construir el randomizer (sesión 7, docs/10)
* **Palabras de objetos laterales**: `type<<9 | side<<8 | lateral/128`, y el **bit de lado activo significa IZQUIERDA** (el código de colisión niega la lateral
  cuando el bit está activo). El disparador de la entrada del pit (`05:D75E..D7C0`, jugador 1) se activa cuando se pasa una palabra de objeto `& $FE00 == $7400`
  con el coche *más allá* del objeto lateralmente, en su lado (p. ej. palabra `$757C`: izquierda, 15872 -> lateral del coche por debajo de
  aproximadamente -16000).
* La tabla de objetos es leída **hasta $58 bytes más allá de la última pieza de la vuelta** por `scan_roadside_objects` (`00:E20D`); el cargador
  original expande L+2 piezas (las piezas extra se leen más allá del final de los streams). Basura ahí significa
  bucles de objetos de grupo de hasta 65536 iteraciones.
* **El banco 7F se usa en parte**: la tabla de corredor (`$7E7000 + 2*(position/2)`) continúa en `7F:0000..$2800`.
* La fuente dorada grande del menú no tiene glifos para `0` y `5..9` (los dígitos `1`,`2` existen, `3`/`4` son los glifos de flecha); la fuente pequeña
  (`draw_string`, tiles de 8x8 en la misma zona de VRAM) tiene todos los dígitos. `0F:9E1C` "upload_font" solo limpia la VRAM $0000-$0FFF.
* Los objetos de grupo (bit 15 de la palabra: túneles, pórtico) vienen de los bytes de registro `b0..b3` con el bit 6 activo; solo las pistas 4, 20, 23, 29
  los tienen (además del pórtico de salida `$8002`).
* Las tablas de página de menú `0D:C716/C738/C75A` (listas a, b, c por página) guardan 17 páginas; la página 8 es la cuadrícula de PASSWORD, la 3 la cuadrícula de nombres,
  la 15 la pantalla de ubicación. `$0F:ABE9` es la lista de textos de la pantalla de ubicación, `0D:C6D6/C6F6[track]` vueltas/piezas para sus estadísticas.

## Catálogo de tipos de objeto y fuente del menú (trabajo del randomizer, sesión 8)
Visto colocando un tipo cada vez en una carrera en marcha (`scripts/rando_types.lua`, `tools/sheet_types.py`; los gráficos son por tipo, parte
del arte puede variar según el entorno): 5 = valla publicitaria KEMCO, 6 = barriles, 7 = barrera de rayas de peligro, **8 = chevron `>` (curva a la derecha), 9 = chevron `<`
(curva a la izquierda)**, 10 = triángulo de aviso, 11/12 = farolas, **13 = bandera PITS**, 14/15 = vallas/arbustos, 21-23 = palmeras, 24-31 = árboles/cactus/
plantas, 30 = valla publicitaria GREMLIN, 37-47 = vallas publicitarias, 53-57 = mástiles de bandera/banderines, 58 = disparador de la entrada del pit. 1-4, 16-17 = otros coches.
En los datos originales el tipo 8 está siempre a la izquierda (bit de lado 1) antes de una curva *negativa* y el tipo 9 a la derecha antes de una positiva;
la dirección de un chevron la fija su tipo, no el lado en el que está.
Fuente del menú: los tiles 128..255 de la VRAM guardan los glifos dorados de 16x16 en el layout de sprite (slot s = tile 128 + (s>>3)*32 + (s&7)*2, mitad inferior +16);
la fuente blanca pequeña es un bloque aparte (`0F:BBA7` -> palabra de VRAM $1000); el texto dibujado por `draw_string_to_buffer` escribe palabras de tile en el
búfer en `$0C6C` (paso $40 por fila de tiles; la segunda pasada suma 16 a los números de tile para la mitad inferior). `draw_selection_bar` construye la
píldora azul con **sprites de la OAM** (tiles `$0EC2..$0EC8`, `$4A` = longitud en sprites, X = desplazamiento de byte de la OAM; X=8 reserva el sprite 0 para el cursor del texto).
Descompresor gráfico `0F:B306` (variante de LZ, anillo de 2 KB): el bloque `0D:A44D` -> palabra de VRAM $1800 es la fuente dorada.
