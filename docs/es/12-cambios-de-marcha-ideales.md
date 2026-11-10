# Velocidades ideales de cambio de marcha por coche (pista plana, depósito lleno)

Objetivo: alcanzar la velocidad máxima lo antes posible con el cambio manual. `python3 -I tools/gear_opt.py` lo resuelve exactamente con programación dinámica sobre el modelo de velocidad del propio juego (`tools/physics.py`, que coincide con el juego a la unidad, ver docs/02). El mapa de velocidad de un tick es monótono en la velocidad para toda marcha, así que conservar la mayor velocidad por marcha en cada tick es óptimo. El cambio manual mueve una marcha por tick (unos 25 ms), como el código real (`05:D3B0`); el cambio en sí no cuesta nada en esta rutina. Las marchas se numeran 1ª..5ª (índice 0..4 en el juego). Las velocidades son km/h en el HUD (unidades / 41,7). Tiempo: 2 ticks de física cada 3 frames.

Supuestos: pista plana, depósito lleno (la quema de combustible eleva un poco la velocidad máxima, hasta +670 unidades con el depósito vacío), sin dirección, colisiones ni salidas de pista, acelerador mantenido. Aún no jugado en el juego.

## Sin nitro

| coche (índice) | 1ª → 3ª (la 2ª se usa un tick) | 3ª → 4ª | 4ª → 5ª | mejor velocidad máxima | tiempo hasta el 99 % |
|---|---|---|---|---|---|
| rojo (0) | ~80 (ventana 70..84) | ~127 (ventana 98..144) | **nunca** (la 4ª es más rápida: 224 vs 212) | 224 | 11,2 s |
| blanco (1) | ~38 (hasta 57) | ~92 (en cualquier punto hasta ~135) | ~166 (ventana 150..174) | 201 | 5,0 s |
| morado (2) | ~63 (41..73) | ~167 (150..175) | ~189 (176..195, ganancia diminuta) | 212 | 9,3 s |
| azul (3) | ~52 (11..64) | ~186 (180..189) | ~195 (185..198, ganancia diminuta) | 209 | 6,8 s |

Las ventanas son las velocidades de cada cambio por separado que cuestan como mucho un tick respecto al óptimo. El cambio automático pierde de 0,2 s (blanco) a 1,4 s (azul) por el camino y nunca alcanza la velocidad máxima del coche rojo (sube a 5ª a 211 km/h).

## Con nitro (disparado en la salida; dura 320 frames = 5,3 s)

| coche | 1ª → 3ª | 3ª → 5ª (4ª por un solo tick) | velocidad cuando acaba el nitro | cambio auto |
|---|---|---|---|---|
| rojo (0) | ~57 | ~162 (ventana hasta 227) | 360 | 359 |
| blanco (1) | ~68 | ~253 (234..265) | 318 | 293 |
| morado (2) | ~57 | ~229 (191..248) | 333 | 322 |
| azul (3) | ~62 | ~254 (242..262) | 293 | 258 |

Así que el viejo truco "3ª marcha + nitro" (docs/02) es correcto, y el cruce exacto es 160 / 230 / 253 / 254 km/h (rojo / morado / blanco / azul). Sin cambio manual el automático desperdicia hasta 35 km/h al final del nitro en los coches blanco y azul. Cuándo se dispara el nitro importa poco para el tiempo hasta el pico: disparado en la salida alcanza el 99 % de su pico a unos 5,1 s en todos los coches. Disparado más tarde (tras alcanzar la velocidad máxima normal) el pico termina un 2-3 % más alto (rojo 368, blanco 332, morado 349, azul 305 km/h), pero más tarde.

## Combustible (05:D638..D67B)

Por tick la quema es `((RPM * burn_byte) >> 14) + 1`, con RPM = `((speed * ratio) >> 8) << 1`, ratio 127/96/58/42/30 para 1ª..5ª (igual para todos los coches, también en las filas de nitro) y burn_byte 100/64/90/82 (rojo/blanco/morado/azul). El combustible por km es, por tanto, casi proporcional a la relación de marcha: la 5ª quema alrededor de un 30 % menos que la 4ª a la misma velocidad. Un depósito lleno son 43007 unidades. A medida que el depósito se vacía, la velocidad máxima sube hasta 670 unidades (+16 km/h).

En matemática simple (las divisiones redondean hacia abajo a un entero, como los shifts; `mod 1024` es la máscara `& 0x3FF`, el resto de dividir entre 1024):

```
RPM  = (speed * ratio / 256) * 2
burn = (RPM * burn_byte / 16384) mod 1024 + 1
fuel = fuel - burn
```

El `mod 1024` nunca importa en la práctica (rojo, 1ª marcha, 5000 unidades: la quema es alrededor de 30), es solo un límite de seguridad en el código. Ignorándolo y los redondeos intermedios, todo se reduce a `burn ~ speed * ratio * burn_byte / 2.097.152 + 1` (2.097.152 = 128 * 16384). Ejemplo, coche rojo (burn_byte 100), 5ª marcha (ratio 30), velocidad 9000: RPM = (9000 * 30 / 256) * 2 = 2108, burn = 2108 * 100 / 16384 + 1 = 13 unidades por tick, de un depósito de 43007.

Pista plana, acelerador mantenido, depósito lleno, una vuelta de 2,4 km desde parado (solo modelo, no medido en el juego; los km asumen 40 ticks/s):

| | tiempo | combustible |
|---|---|---|
| rojo, se queda en 4ª | 39,4 s (termina a 239 km/h) | 29857 (69 % de un depósito) |
| rojo, 5ª desde ~190 km/h | 41,5 s | 22517 (52 %), -25 % |
| blanco / morado / azul, cambios óptimos | 43,3 / 41,4 / 41,4 s | 13774 / 20045 / 18523 |
| igual, cada subida de marcha al 70 % de la velocidad óptima | +0,05 / +0,2 / +0,3 s | -1 / -3 / -3 % |

Así que las velocidades de cambio apenas importan para el combustible (la fase de aceleración es corta); la marcha de crucero sí. Blanco, morado y azul ya crucean en 5ª, que es a la vez la marcha más rápida y la más económica. Solo el coche rojo tiene una elección real: 4ª (+2 s cada 2,4 km, +33 % de combustible) o 5ª. Un nitro cuesta 2700-3800 unidades (6-9 % de un depósito) pero cubre unos 0,35-0,40 km en 5,3 s, así que su coste por km es 0,7-1,1 veces el normal.

## Quemar combustible a propósito (combustible de sobra en la meta)

La bonificación de combustible es pequeña: 1 unidad de velocidad máxima por cada 64 unidades de combustible quemadas, +16 km/h con un depósito entero. Mantener una marcha más baja para quemar más rápido solo compensa cuando esa marcha no es más lenta de entrada, lo cual vale solo para el coche rojo (su 4ª supera a su 5ª). Modelo, pista plana, depósito lleno, acelerador mantenido, marcha final mantenida desde parado:

| coche | velocidad máxima a 20 / 40 / 60 s, 5ª | igual, 4ª | 4,8 km, 5ª / 4ª |
|---|---|---|---|
| blanco | 203 / 207 / 209 | 193 / 196 / 200 | 84,6 s / 88,4 s |
| morado | 217 / 221 / 226 | 212 / 219 / 225 | 79,5 s / depósito vacío |
| azul | 214 / 219 / 224 | 212 / 218 / 224 | 80,0 s / depósito vacío |
| rojo | 219 / 227 / 236 | 232 / 240 (vacío a los 55 s) | la 4ª es más rápida |

En el blanco, la 4ª es 12 km/h más lenta. En el morado y el azul, la 4ª quema alrededor de un 35 % más por segundo y solo alcanza a la 5ª hacia los 60 s, cuando su depósito está casi vacío (65 s / 70 s). Por tanto, para estos tres coches quedarse en 5ª es la mejor elección incluso con combustible de sobra. El único otro gasto de combustible es el nitro (2700-3800 unidades, alrededor de +1 km/h de velocidad máxima), que de todos modos se usa por su propio impulso. No probado en el juego; los km asumen 40 ticks/s.

## Mayor distancia con un depósito (`tools/range_opt.py`)

La quema **no** depende del acelerador: el código en `05:D5F6..D67B` calcula las RPM a partir de la velocidad y quema `((RPM*burn_byte)>>14 & 0x3FF)+1` en cada tick, esté el acelerador pulsado o no (comprobado con `out/ticks_a.csv`: 846 de 852 ticks exactos; las RPM usadas son las de después de la actualización de velocidad de ese tick). Así que soltar el acelerador nunca ahorra combustible; las únicas palancas son la marcha (la quema es proporcional a la relación 127/96/58/42/30) y la velocidad (la quema es `k*speed` más 1 constante por tick, así que un crucero más rápido es mejor por km, salvo los escalones de entero de abajo).

Pista plana, depósito lleno, acelerador mantenido tras la salida, distancia hasta que el depósito se vacía (los km asumen 40 ticks/s; el coche luego se desliza otros 0,2-0,6 km):

| coche | 4ª | 5ª | ganancia de la 5ª | mejor objetivo bang-bang en 5ª |
|---|---|---|---|---|
| rojo | 3,46 km | **4,75 km** | +37 % | 4,86 km (mantener ~215 km/h, +2 %) |
| blanco | 5,34 | 7,35 | +38 % | 7,75 (mantener ~155, +5 %, pero 25 % más lento) |
| morado | 3,84 | 5,27 | +37 % | 5,48 (+4 %) |
| azul | 4,19 | 5,78 | +38 % | 6,04 (+4 %) |

Conclusiones:
* **Todos los coches: cruzar en 5ª con el acelerador mantenido.** Esa es la respuesta para el coche rojo también: su 4ª es más rápida (+12 km/h, ver arriba) pero quema un 40 % más por km, así que un depósito dura 3,5 km en lugar de 4,75 km. El rojo sigue siendo el coche más sediento (burn byte 100 vs 64/90/82): el blanco hace 7,35 km con un depósito, el rojo 4,75 km.
* Las velocidades de cambio son irrelevantes para la autonomía (ver la tabla anterior); sube de marcha en cuanto la siguiente marcha acelere mejor.
* Pequeño extra: la quema es un entero que sube en escalones a velocidades fijas, así que una velocidad justo por debajo de un escalón es un poco más barata por km que la velocidad de equilibrio justo por encima (modelo con medio depósito, relativo al acelerador a fondo): rojo 5ª a 218 km/h (equilibrio 227) +3,6 %; azul 5ª a 205 (221) +2 %; blanco 5ª a 210 km/h (211) +12 % (una diferencia de 1 km/h que la velocidad máxima creciente de un depósito que se vacía borra, así que no es práctico); morado ninguno. Mantener esa velocidad exige pulsar el acelerador a impulsos y cuesta tiempo, así que solo importa si el objetivo es puramente terminar la carrera limitada por el depósito con combustible de sobra.
* Deslizarse tras vaciarse el depósito: sin acelerador, el término de arrastre `|DRAG[gear]-speed|>>8` deja de frenar el coche cuando su velocidad está a menos de 256 unidades de la constante de arrastre de la marcha (9500..11000), así que cambia a la marcha cuya constante esté más cerca de la velocidad actual (3ª para el coche rojo) para deslizarte lo más lejos posible. No probado en el juego.

Solo modelo, no medido en el juego.
