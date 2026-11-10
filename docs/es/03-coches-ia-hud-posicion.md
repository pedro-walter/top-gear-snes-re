# Hallazgos de la sesión 3 (sesión sin supervisión) – oponentes, pistas, nitro, pit stops, HUD

Todo esto se leyó en el desensamblado y luego se contrastó en ejecuciones headless de Mesen
(`scripts/*.lua`, ayudantes compartidos en `scripts/common.lua`; scripts de análisis en `tools/`).

## Velocidad en el HUD (el contador digital rojo)
`sub_00CE61` (00:CE61) lo dibuja: `km/h = (speed * 24) >> 10`  (`speed*3/128`, es decir, 1 km/h = 42,67 unidades; la estimación anterior de 41,7 era algo inexacta).
Implementado con el multiplicador de la PPU: `$211B` = velocidad (16 bits), `$211C` = **24** (km/h) o **15** (millas: 15/24 = 0,625 = 1/1,6) y el resultado
`$2135 >> 2`. Qué unidad: `$1FF6` negativo => 24; si no `$1FB0` (jugador 1) / `$1FB1` (jugador 2) distinto de cero => 24, cero => 15 (mph). El resultado se
separa en dígitos con el divisor de hardware (`$4204/$4206` /10 dos veces) y los glifos de los dígitos (4 palabras cada uno) de la tabla en `00:D666 + digit*8` se envían por DMA/escriben
en la VRAM `$0C5B/$0C7B` (unidades), `$0C59/$0C79` (decenas), `$0C57/$0C77` (centenas); el jugador 2 usa `$0E1B...`.
Ejemplo: SPD 5359 -> 5359*24/1024 = 125 (el usuario vio 124).

## Coches: la "lista de carrera" de 20 entradas (base WRAM $0200, 18 bytes por coche)
* `$0200` = **longitud de la pista** en unidades de posición (`(w0 & 0x3F) * 1024`, 22528 para la pista 0).
* La lista está en `$0212 + 18*j`, j = 0..19 (20 coches = 18 bots + 2 slots de "jugador"). El slot (desplazamiento X, 0..0x156) de los dos coches humano/ordenador está en
  `$0204` (jugador 1) y `$0206` (jugador 2 / el coche del ordenador). El código usa DP=$0200, así que los desplazamientos aparecen como `$19,X`.
* La lista se mantiene **ordenada por progreso** con un intercambio de bubble-sort por frame (`00:A1BD`, el código de intercambio A276–A2B4 intercambia 8 palabras; la 9ª palabra (+0x10) es por slot y no se intercambia).
  Dirección mayor = más adelante (slot 19 = líder).
* Registro por coche (desplazamientos desde la base de la entrada):

| off | significado |
|---|---|
| +0 (word) | 5 bits bajos = id del coche 0..19; 7 bits altos = código de sprite/paleta (0x44 / 0x64 / 0x04 / 0x20...) usado por el constructor de OAM (`01:8000`, `00:ABFC`) |
| +2 | posición lateral (16 con signo, 0 = centro de la carretera; los límites de la carretera son +-~0x2800) |
| +4 | velocidad lateral (con signo). Los bots la mantienen constante y solo rebotan: cuando la posición lateral sale del corredor de la carretera `$7E7000[pos>>4]` (dos bytes con signo: límites izquierdo y derecho, escalados x256) el signo se invierte (00:AC9C..ACD3) |
| +6 / +7 | progreso de 24 bits: byte +6 fracción, word +7 = progreso en unidades, da la vuelta en `$0200` (longitud de la pista) |
| +9 | contador de vueltas (byte); comparado con `$1E56` (= vueltas de la carrera, `$DEA4[track]` = 3 para la pista 0) |
| +A | velocidad (word). progreso += velocidad * `$1E90` (el multiplicador, 00:A18D) en cada frame |
| +C | aceleración, +E temporizador: mientras timer>0, speed += accel y timer--; en 0 la aceleración se pone a cero (rampa usada en la salida) |
| +10 | borrador por slot (puesto a cero en cada frame en 00:A1B5) |
* Cuando un coche cruza la línea en la última vuelta (lap == `$1E56`) su id se añade a la lista de llegada `$1F12[$1EB0++]` y el tiempo actual `$1EAE` se guarda en `$1F26[id*2]`
  (00:A1D6..A223, también 00:AB7A para la simulación del final de carrera). `$1EB0` = número de coches que han terminado. (`$1EB0 >= 10` => estado de resultados/"carrera terminada"; la física se salta la fuerza del motor.)

### Parrilla de salida / parámetros de los bots (init de la carrera `00:A558`)
* La plantilla de cada coche se copia de la ROM `00:A732 + 18*k` (k = 0 jugador 1, 1 jugador 2, 2..19 bots). Bots k=2..19 (orden de salida, de atrás hacia delante):
  (id 6, base 2117, mult 32, ramp 8) (id 9, base 2467, mult 32, ramp 8) (id 3, base 3527, mult 32, ramp 8) (id 7, base 2624, mult 32, ramp 8) (id 10, base 3109, mult 32, ramp 8) (id 12, base 3328, mult 32, ramp 8) (id 8, base 2979, mult 16, ramp 16) (id 5, base 3136, mult 16, ramp 16) (id 19, base 3456, mult 16, ramp 16) (id 11, base 3015, mult 16, ramp 16) (id 16, base 1920, mult 16, ramp 16) (id 18, base 2246, mult 10, ramp 24) (id 2, base 3398, mult 10, ramp 24) (id 13, base 3493, mult 10, ramp 24) (id 17, base 2114, mult 10, ramp 24) (id 15, base 2726, mult 8, ramp 32) (id 4, base 3145, mult 8, ramp 32) (id 14, base 2561, mult 8, ramp 32)
  (id = id del coche 0..19, base = velocidad base, mult/ramp = multiplicador de aceleración y frames de rampa; los ids 0/1 son los dos slots humano/ordenador).
* La posición lateral inicial es -7680 / 0 / +7168 en un patrón repetido (3 carriles), el progreso inicial = `$0200 - 0x2A0 + 0x20*k` (los bots salen repartidos en 0x20 unidades).
* **Velocidad de crucero del bot** = `base + 2*rand(0..255) + diff_offset(track, difficulty)`, con `diff_offset = word[$DDE4 + track*6 + difficulty*2]`
  (pista 0: 0 / 80 / 160, pista 1: 128 / 416 / 704, pista 2: 160/568/976 ...; 16 pistas x 3 words – por eso mayor dificultad hace a los bots más rápidos). La velocidad se alcanza
  mediante la rampa (accel = (ese valor * multiplicador)>>8 durante `timer` frames) y luego no cambia nunca (sin rubber-banding en los 18 bots).
  Velocidades de bot observadas durante la carrera: 2001..3769 unidades (47..88 km/h equivalentes en unidades de progreso; ojo: el *progreso* es velocidad * `$1E90`).
* Velocidad lateral del bot = +-(100 + rand(0..255)), signo aleatorio: barren la carretera de izquierda a derecha a velocidad lateral constante y rebotan en los bordes.
  Ese es el "zigzagueo" – los bots nunca miran al jugador.
* RNG: `00:A89E` – LCG sobre `$1FF4`: `seed = 13*(seed+7)`, devuelve el byte `hi ^ lo` (opcionalmente escalado por A+1 mediante el multiplicador de la PPU). Misma semilla => misma carrera.
* Un bot que alcanza a un coche humano por detrás: 00:A2C4 -> `bump_p1`/`bump_p2`. Es un **intercambio de velocidades, no una división por la mitad** (el `LSR $1E5A` es una conversión de unidad: `$1E5A` es 2x la unidad de velocidad del bot). Ver "Colisiones" más abajo.
* El coche humano también es *bloqueado* por un coche delante: `05:E9AF` (P1) / `05:F174..` (P2) estrechan el corredor lateral permitido `[$1A,$1C]` alrededor de cualquier coche a menos de 0x200 unidades delante
  (los límites del corredor vienen de `$7E7002[pos>>4]`), empujándote a un lado en lugar de dejarte atravesarlo.

### Posición (1º..20º)
`sub_00AA79` calcula la posición del slot X: empieza en 21 y decrementa por cada uno de los 20 slots cuyo (byte de vuelta, índice de slot) es menor que el nuestro => posición = 1 + número de coches
estrictamente por delante en (vuelta, orden de la lista). Como la lista está ordenada por progreso, esto equivale a la posición real en la carrera. Guardada en `$1E7A` (jugador 1, **base 0**: 0 = 1º, 19 = 20º) y `$1E7C` (jugador 2) (00:A233/A23C).
(`$1F00/$1F02` guardan la posición final del jugador tras la llegada.)



## RNG y comportamiento de los rezagados (investigado con `scripts/bots_probe.lua`, ROM original)
* **Usuarios del RNG** (`00:A89E`, solo 7 llamadores): elección de colores de coches en el título (`00:815E/816A`, 2 sorteos), **race_init** (2 sorteos por bot = 36: variación de velocidad, luego magnitud de la velocidad lateral; el signo sale del bit 0 del mismo sorteo), y variantes de sonido en el código de choque (`00:B3F2`, `05:E99F`). Nada en el bucle de la carrera sortea aleatoriedad: el comportamiento de los bots es totalmente fijo una vez que race_init ha corrido.
* `$1FF4` solo se *escribe* por `rng` y por el modo attract (`0F:90F8`, sembrado desde `$1FFC`). Empieza en 0 en Mesen (el primer sorteo da `$005B = 13*7`), así que tras un arranque nuevo la primera carrera es siempre la misma. Las carreras siguientes dependen de cuántos sorteos hubo antes. Los 36 sorteos de race_init son, por tanto, toda la "aleatoriedad" de una carrera.
* **Los bots existen durante toda la carrera**: 18 bots se crean en race_init y nunca aparecen/desaparecen. Su velocidad es fija tras la rampa de salida (verificado: constante en 17 de 18 bots durante 500 frames). El jugador sale en el slot de la parrilla de la posición final anterior (`final_pos*18` en la lista de coches).
* **Los bots nunca se tocan entre sí** (la prueba de colisión en `00:A2C4` solo dispara cuando el coche de delante en la lista tiene velocidad 0, es decir, un coche humano).
* **El movimiento lateral solo se simula cerca del jugador** (`update_bot_cars` 00:ABFC, `update_visible_cars_p2` 00:AEF3). En cada frame toma los coches desde 16 unidades detrás de un coche humano hasta 0x400 (1024 unidades = 32 slots de carretera) delante, hace `lateral += lateral_speed` y rebota en el corredor `$7E7000`. Excepción: el primer coche en o después del inicio de la ventana se actualiza siempre, por lejos que esté. Todo lo demás está congelado: no hay recuperación, así que un coche que reentra en la ventana continúa desde su posición lateral y dirección antiguas. Medido: dentro de la ventana el lateral cambió en el 32% de los frames (el juego avanza un tick cada tres frames aprox.), fuera 0%, salvo el coche más cercano delante (y, en 1P, la misma regla alrededor del coche inactivo del jugador 2).
* La ventana también alimenta la lista de dibujo (`$178A` profundidad+0x80, `$178C` lado/lateral, máx. 20 entradas); el renderizador de carretera en la WRAM (`7E:2D6F`) emite un coche cuando su profundidad está por debajo del slot que está recorriendo (`CMP $8E`).
* **No hay lógica que mantenga a los bots lejos del jugador.** En la pista 0 (22528 unidades, 18 bots) la ventana cubre alrededor del 4,5% de la vuelta, así que con el pelotón disperso ves 0-1 bots la mayor parte del tiempo (0 en la ventana en el 87% de los frames de la ejecución de prueba, cuyo piloto era tosco: solo aceleraba, sin dirección). Solo la parrilla de salida llena la ventana (los 18 coches). Las pistas más largas lo vuelven más escaso.
* **El contacto jugador-bot transfiere velocidad** (`05:E944`, `05:E970..E99E`): la velocidad del bot es empujada hacia la del jugador, con una aceleración de -(delta)/64 por tick durante 64 ticks (`$0220 = 0x40`) para que vuelva suavemente a su velocidad de crucero. Observado: un bot en 2001 saltó a 3072 y decayó 17 por tick de vuelta a 2001 en 63 ticks.

### Detalles del RNG, parámetros de los bots y la parrilla de salida (complemento)
* `rng` es un generador congruencial lineal de 16 bits: `seed = 13*seed + 91 (mod 65536)` (13-1 es divisible por 4 y 91 es impar, así que tiene el periodo completo de 65536). El byte devuelto es `hi ^ lo` de la *nueva* semilla; con A != 0 se escala a `0..A` mediante el multiplicador de la PPU. Cada llamada avanza la semilla, así que la secuencia queda totalmente determinada por la semilla y el orden de las llamadas.
* Por bot, race_init sortea dos veces: (1) variación de velocidad `j = rand(0..255)`: velocidad objetivo `S = template_base + 2*j + diff_offset`, luego accel = `S*mult >> 8` durante `ramp` ticks (mult*ramp es 256 en tres de los cuatro grupos de plantilla, 240 en el grupo de los ids 18/2/13/17, así que la velocidad final es aproximadamente `S`, 0,94*S en ese grupo); (2) velocidad lateral `100 + rand(0..255)` unidades de posición por tick, negativa cuando el bit 0 está activo. Los dos sorteos son independientes, y también lo son velocidad y velocidad lateral (correlación medida en los 18 bots: -0,18, no significativa). La impresión de que los bots rápidos zigzaguean menos viene de la distancia: un coche más rápido cubre más carretera por barrido lateral.
* Parrilla de salida: race_init copia las 20 plantillas en orden y pone al jugador en el slot `final_pos*18` de la lista, donde `$1F00` es la posición (base 0) de la llegada anterior (0 = ganó, 19 = último); el slot 0 es el puesto más atrasado de la parrilla. Así que la parrilla está invertida: ganar te pone al fondo, terminar último te pone en la pole. `$1FF2` es 0 solo hasta la primera carga de pista tras el arranque, así que la primerísima carrera sale al fondo. El randomizer no toca `$1F00`/`$1FF2` ni race_init y se comporta igual (comprobado con `scripts/rando_grid.lua`: posición anterior 0/5/19 da slot 0/5/19 en las dos ROM; una llegada en último lugar guardó `$0013`).

### Cuándo cambia la semilla del RNG (`scripts/rng_watch.lua`, ROM original)
* `$1FF4` está dentro del área persistente `$1F00-$1FFF`. En el reset el código comprueba un valor mágico (`$1F91 + $1FAE == $7543`, `00:8101`); si es incorrecto toda el área se pone a cero (`00:8110`, incluye la semilla). La RAM al encender falla la comprobación, así que un **arranque en frío empieza la semilla en 0**; un reset suave la conserva. Escrituras registradas: dos en el arranque (`00:8113`, la limpieza), luego solo `rng` mismo (`00:A8BA`).
* **Escritores**: la limpieza del arranque, `rng`, y el modo attract (`0F:90F8`, semilla := contador de frames `$1FFC` cuando empieza la demo inactiva). Ningún código de menú la escribe (búsqueda estática de todas las escrituras indexadas en `$1Fxx`; ninguna alcanza `$1FF4`). Elegir 1P/2P, nombres, cambio, controles, coche, dificultad o país no toca la semilla (el recorrido por script solo cubrió start/down/A; el resto viene de la búsqueda estática).
* **Sorteos**: `race_init` 36 por carrera (2 por bot); variantes de sonido de choque (`00:B3F2`, `05:E99F`) unos pocos por contacto; las elecciones de color de coches en `00:815E/816A` solo corren en el camino de la demo (`$1FF6` activo), no en el juego normal.
* **Consecuencias**: la semilla nunca se reinicia entre carreras. La primera carrera tras un arranque en frío (sin demo antes) tiene siempre las mismas variaciones de velocidad/velocidades laterales/direcciones de zigzag de los bots. La carrera n+1 parte de la semilla que dejó la carrera n, así que depende del número de sorteos de sonido de choque, es decir, de cómo condujo el jugador. Esperar en el título hasta que corra la demo resiembra desde el contador de frames y hace que la siguiente carrera dependa del momento.
* **Reinicio de la parrilla** (no es el RNG): `0F:84CB` / `0F:84E1` ponen la posición final anterior en 0/1 (fondo de la parrilla) cuando el humano terminó fuera de los puestos de clasificación (`qualify_check_1p`) o después de que `advance_track` señale el fin del campeonato (leído en el código, no trazado en la GUI).
* El randomizer no toca `$1FF4` (su generador de semillas es aparte), así que el mismo comportamiento vale para él. Idea, no hecha: sembrar `$1FF4` desde la semilla de la pista para pelotones de bots reproducibles.


## Colisiones (medidas con `scripts/collide_hooks.lua`, `collide_probe.lua`, `collide_exp.lua`)
Unidades de velocidad: `$1E5A` (jugador) es **2x** la unidad de velocidad del bot (el jugador avanza `$1E5A/2*delta`, un bot `speed*delta`). Nada de lo siguiente daña el coche; todo contacto es un cambio de velocidad, una flag de sonido (`$1EF5 |= 0x80`) y a veces un empujón lateral.
**No hay contacto lateral entre coches**: las dos pruebas de coche disparan solo en el tick en que el progreso de un coche alcanza al del otro, y solo si la distancia lateral es lo bastante pequeña.

| Evento | Dónde | Condición | Efecto |
|---|---|---|---|
| El jugador alcanza a un bot delante | `05:E3D6..E584` -> `sub_05E8E9` | pos del jugador + 7 >= pos proyectada del bot; jugador más rápido (`2*bot < $1E5A`); distancia lateral < 0x800 en medias unidades = **4096** unidades | **intercambio de velocidades**: el jugador pasa a `2*bot_speed` (rampa pendiente no incluida), el bot salta a ~jugador/2 (redondeado a 64) y luego vuelve suavemente a su velocidad antigua a `-delta/64` por tick durante 64 ticks. Pos del jugador := pos del bot - 8, sonido de choque. **Sin empujón lateral, sin bloqueo de dirección.** Medido: 5925 vs bot 2001 -> 4002. |
| Un bot alcanza al jugador por detrás | `00:A2C4` -> `bump_p1` | progreso del bot >= el del jugador; distancia lateral < 0x800 en unidades enteras = **2048** (la mitad de la ventana anterior); fuera del pit, velocidad del jugador no negativa | **intercambio en el sentido contrario**: el jugador pasa a `2*bot_speed` (un *impulso* si el jugador iba más lento), el bot pasa a jugador/2 (redondeado) y vuelve suavemente en 64 ticks; el bot se coloca en la posición del jugador. Medido: jugador 2023 -> 7538, bot 3769 -> 953 y luego +44 por tick. La velocidad se disipa entonces por el arrastre normal, no se limita a la velocidad máxima de la marcha. |
| Jugador vs coche del ordenador / humano 2 | `05:E524..E569`, `E703..E763` | mismas pruebas | mismo intercambio más un empujón lateral `steer = -8 * distancia lateral` |
| Objeto al borde de la carretera, clase **REV** | `05:F6B3` | lateral de la palabra del objeto vs lateral del jugador, ver umbrales | `speed = -min(speed/2, 1600)` (es decir, marcha atrás, como mucho -37 km/h), distancia hacia delante 0, sonido de choque. Medido 5924 -> -1600, vuelve a positivo tras ~3 ticks, luego aceleración normal desde ~0 (alrededor de 1,3 s para volver a 3000). La variante del sonido de rebote se elige con el RNG cuando speed >= 0x1770. |
| Objeto clase **EDGE** | `05:F6F5` -> `F6FA/F6FF` | igual | velocidad y distancia hacia delante a la mitad; ángulo de dirección forzado a +-0x5000 **hacia el centro de la carretera** (signo de la lateral del jugador), entrada de dirección bloqueada (`$1EEC = 0x600`, el ángulo decae 0x600 por tick, ~14 ticks). El desplazamiento lateral por tick está limitado por el límite de dirección (`$1E92/$1E94`), así que a alta velocidad el empujón suele ser un golpe de ~1100 unidades y el bloqueo termina pronto; a baja velocidad se desarrolla por completo (~6500 unidades vistas). |
| Objeto clase **SIDE** | `05:F6F1` | igual | igual que EDGE pero el empujón es **alejándose del objeto** (hacia el lado desde el que lo golpeaste). Solo los tipos 21 y 58. |
| Objetos de grupo (pilares del pórtico, túnel) | `05:ED3A` | rangos laterales de `00:A15F/A167` | comportamiento REV (velocidad -> -min(speed/2,1600)). |
| Paredes de túnel/puente | `05:D808..D838` | solo mientras `$1EBE` está activado por los marcadores de grupo C004/C006 | lateral limitada al límite, empujón EDGE (+-0x5000, bloqueo, velocidad a la mitad). |
| Fuera de la carretera (sin pared) | `05:D83B` | `|lat|` más allá del límite del escenario (`$017B/$017D` en `[scenery word]`, p. ej. +-10229) | en cada tick `speed -= speed*6/256` (alrededor del 7% cada 2 ticks, medido) |

Clases de objeto por tipo (tabla P1 `05:F5C3`, tabla P2 `05:F63B`, idénticas): **EDGE** = 5-10, 13, 15, 27, 38, 42; **SIDE** = 21, 58; **REV** = todos los demás tipos 0-59. Cada objeto se prueba una vez, cuando la posición del coche cruza su slot de 32 unidades (unas 64 unidades por delante de la referencia del coche), **sin dependencia de altura ni de velocidad**. Semianchura de impacto (lateral del jugador vs lateral del objeto, en unidades `$1E8A` = 2x el valor de la tabla): derecha `A05F[type]`, izquierda `A0DF[type]`: 2048 para la mayoría de los tipos (es decir +-4096), 1536 para 8-10/13/21/45/59 (+-3072), 1792 para 6/7 (+-3584), 1024 para 27/28/38/39 (+-2048), 768 para 24, 512 para 11/12/15/41/42/56(derecha), 256 para 22(derecha)/23(izquierda). Asimétricos: 22 (D 256, I 2048), 23 (D 2048, I 256), 40 (I 1536), 54 (D 768, I 1792), 55 (D 1792, I 768), 56 (D 512, I 1792), 57 (D 1792, I 512), 58 (D 1024, I 512).

Notas
* "Ser golpeado por un rezagado por detrás" es en realidad *cualquier bot que te alcance*: con el intercambio sales al doble de su velocidad, así que ser golpeado yendo lento (tras un choque, en la salida del pit) es un aumento gratis de velocidad de hasta ~176 km/h, y el bot queda aparcado a tu velocidad un momento. Chocar por detrás a un bot solo te cuesta `speed - 2*bot_speed`.
* Un bot que zigzaguea hacia ti cuando vas a su lado no hace nada; el contacto solo ocurre en el cruce de progreso.
* La rampa de salida pendiente del bot se suma a la nueva velocidad del bot pero no a lo que recibe el jugador.
