# El truco acelerador + freno en las curvas (solo jugador 1)

Mantener **acelerar (X) y freno (Y) a la vez** permite que el jugador 1 sostenga una curva mucho más cerrada / rápida sin derrapar hacia fuera.
Funciona por cómo se elige el límite de agarre de la dirección en la actualización del jugador 1 (`05:D4A6..D575`), y existe solo para el jugador 1.

## Mecanismo
Por tick de juego (`$1E90` = delta de frames δ, 1..7):

| variable | significado |
|---|---|
| `$1E8E` | distancia hacia delante en este tick = `(speed/2)*δ` (`05:D686..D6BA`, saturando) |
| `$1E7E` | estado de la dirección; su byte alto es el "ángulo de dirección" (Left/Right suman `$9AC3[δ]` por tick, máx. `0x51FF`) |
| `$1E94` / `$1E92` | **límite del desplazamiento lateral que la dirección puede producir en este tick** (+ / −) |
| `$1E8A` | posición lateral (0 = centro de la carretera) |

Desplazamiento de la dirección `D = $1E8E * hi($1E7E) / 256` (`05:D995..D9AA`). Si `D` excede el límite (`CMP $1E94`, `05:D9AC`) se recorta al límite,
el bit 0 de `$1EF5` se activa y el estado de la dirección se revierte (`05:D9B1..D9C7`), así que la dirección no puede crecer más.
La curva entonces empuja el coche hacia fuera con `P = $1E8E * c / 256` (`c = $7E4C00[pos>>5]`, `05:DA1A..DA79`), **sin límite**.

El límite se elige entre tres escaleras en el banco 00 (índice = `(δ-1)*2 + $1EE8`, `$1EE8` = coche*16; 4 coches filas positivas, 4 filas negativas):

| situación | tablas | límite |
|---|---|---|
| sin acelerar (rueda libre) | `$97DF` / `$981F` | **640·δ** (todos los coches) |
| acelerando con combustible (máscara `$1F76` X pulsado, `05:D4B0..D4D7`) | `$985F` / `$989F` | **384·δ** (coche 1 = 416·δ; los demás coches 384) |
| acelerando **y frenando** (máscara `$1F78` Y pulsado, solo P1, `05:D55F..D578`) | `$98DF` / `$991F` | **640·δ** otra vez |

Es decir, el acelerador cuesta el 40 % del agarre, y mantener el freno a la vez devuelve todo el agarre de rueda libre mientras el motor sigue tirando.
El código de freno del jugador 2 (`05:DDC5..DE49`, máscara `$1F95`) solo activa la flag de la luz de freno y frena el coche; nunca carga las tablas `$98DF/$991F`.
Frenar activa el bit 15 de `$0108` (paleta de la luz de freno, `00:BC36..BC6D`). El propio frenado reduce el coche en cada tick en
`(|top-speed| + (0x800 si speed>top)) * 11 / 256` (`05:D57C..D5E4`).

## Condición de curva (verificada en el emulador)
Con δ cancelándose, la curva puede sostenerse mientras la dirección limitada siga venciendo al empuje:

`384·δ ≥ (speed·δ/2)·c/256  ⇔  speed·|c| ≤ 196608`  (acelerando)
`640·δ ...                  ⇔  speed·|c| ≤ 327680`  (acelerar+frenar, o rueda libre)

En km/h (`km/h = speed*24/1024`): km/h máx. ≈ **4608/|c|** acelerando, **7680/|c|** con freno (o rueda libre).

| valor de curva c | acelerando | acelerar + frenar |
|---|---|---|
| 16 | 288 km/h | 480 |
| 24 | 192 | 320 |
| 32 | 144 | 240 |
| 40 | 115 | 192 |

Medido con `scripts/brake_corner.lua` (coche aparcado dentro de una curva constante, velocidad forzada, dirección mantenida hacia la curva; la deriva neta hacia fuera cruza cero en):
c=24: solo X 7900 (185 km/h), X+Y 13100 (307 km/h), rueda libre 12900; c=32: solo X 5900 (138 km/h), X+Y 9900 (232 km/h), rueda libre 9900 (predicción 6144 / 10240 / 10240 unidades).
La observación del usuario con el coche rojo (unos 243 km/h) encaja, por tanto, con curvas de c ≲ 31, y 230 km/h en 4ª marcha encaja con c ≲ 33.

Mayor |c| por pista (`tools/tracks.py`, stream de curvas): la mayoría de las pistas tiene su pico en 32, pero 7 Rain Forest, 8 Tokyo, 12 Munich, 18 Helsinki, 28 London, 29 Sheffield y 30 Loch Ness llegan a 40
(solo ≤192 km/h con el truco); 2 New York, 5 Machu Picchu, 14 Black Forest y 25 Rome tienen el pico en 24, 3 San Francisco, 6 Chichen Itza y 31 Stonehenge en 16.

## Marchas y coches
El límite no depende de la marcha; el coche solo lo cambia por la velocidad que alcanza (y por el límite de 416 del coche 1 solo acelerando). La marcha importa porque mantener el freno reduce el coche en cada tick
en una cantidad que depende del `top` de la marcha (`$1EE2`): la deceleración es `(top-speed)*11/256` por debajo del top y `(speed-top+2048)*11/256` por encima, es decir, mucho mayor cuando la velocidad máxima de la marcha está por debajo de la
velocidad actual. Quedarse en la marcha cuya velocidad máxima está justo por encima de la velocidad actual (la 4ª del coche rojo es más rápida que la 5ª sin nitro) pierde por tanto menos velocidad. Aún no medido con precisión:
en una prueba con marcha forzada (`scripts/brake_eq.lua`, pista plana) la velocidad con acelerar+frenar cayó a ~3600 en la marcha 1 y a 0 en las marchas 2-5 en 400 frames, así que el truco es una técnica de corto plazo.

## Reproducir
`tools/mesen.sh scripts/brake_corner.lua` (escribe `out/brake_corner.txt`), `scripts/brake_probe.lua` (máscaras de botón y tablas), `scripts/brake_eq.lua`.
Máscaras: `$1F76`=0x0040 X acelerar, `$1F78`=0x4000 Y freno, `$1F7A/7C/7E` R/L/A (subir/bajar marcha/nitro), `$1F80`=0x0200 Left, `$1F82`=0x0100 Right.

## La bajada lo facilita (observación del usuario, Loch Ness)
La pendiente solo entra en la actualización de velocidad (`05:D400`: `speed += -slope/16`, la subida dividida por 4), nunca en el límite de la dirección ni en el empuje. El freno resta velocidad en cada tick, así que una
curva en bajada devuelve velocidad y el coche se mantiene por encima/cerca de la velocidad necesaria mientras sostienes el truco (y la curva se mantiene el tiempo que quieras).
Prueba (`scripts/brake_slope.lua`, pista 30 Loch Ness, coche aparcado en el progreso 15040 donde el stream de curvas es c=+32 y la pendiente es -600, es decir +37 de velocidad/tick; velocidad forzada a 9000, 240 frames, dirección mantenida hacia dentro de la curva):

| caso | velocidad a lo largo de 240 frames (cada 30 frames) |
|---|---|
| bajada, marcha 3, solo acelerar | 5417 → 8674 (aún subiendo) |
| bajada, marcha 3, acelerar + frenar | 8572 8553 8537 8519 8588 8593 8563 8545 (**mantenida**, empuje hacia fuera negativo = curva mantenida) |
| plano (lugar c=40), marcha 3, acelerar + frenar | 8585 → 7732 (cayendo ~30/30 frames) |
| plano, marchas 4/5, acelerar + frenar | colapso a ~0-1600 |
| bajada, marchas 4/5, acelerar + frenar | mantiene 9100-9400 durante ~90 frames, luego cae (no explicado; puede ser un choque con un objeto lateral en la posición aparcada) |

Mejor curva de Loch Ness: progreso 14528-17184 (palabras de stream 454-537), curva +32 (empuje a la derecha/positivo; gira a la izquierda para mantener), pendiente -124..-600 (media -536), unas 2650 unidades de longitud. También 10432-14112 (c=-32, pendiente -750..0, media -253).
(Las posiciones aparcadas "plano"/"subida" que elegí tenían pendiente 0, así que no hay medición real de subida.)
