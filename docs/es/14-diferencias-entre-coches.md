# Qué difiere entre los cuatro coches (rojo, blanco, morado, azul)

Los textos de la pantalla de selección (MAX SPEED / 0 TO 60 / TIRE GRIP / FUEL CONSUMPTION) son cadenas estáticas, un bloque por coche
(ROM ~0x7A883, 0x7AA41, 0x7AACB, 0x7AB59). Nada en la física los lee.
`$1F8F` = coche, `$1EE8` = coche*16 (00:A714); cada tabla por coche tiene filas de 16 bytes (5 palabras de marcha, filas de nitro en +58), indexadas por `car*16 + 2*gear`.
δ = `$1E90` (frames desde el último tick + 1; 2..3 en las ejecuciones headless). Scripts de prueba: `scripts/car_accel.lua`, `scripts/car_steer.lua`.

| | rojo | blanco | morado | azul |
|---|---|---|---|---|
| etiqueta MAX SPEED / 0-60 / GRIP / FUEL | 147 / 5.9 / LOW / HIGH | 131 / 3.5 / **HIGH** / LOW | 137 / 5.0 / LOW / MID | 137 / 4.3 / MID / MID |
| velocidad máxima `$9597` por marcha 0..4 | 4500 6000 8400 9600 10000 | 4000 5800 7400 8000 8500 | 4200 6000 8400 8900 9200 | 4200 6000 8400 8900 9000 |
| factor de empuje k `$967F` | 108 32 16 12 8 | 112 48 38 34 24 | 108 32 22 17 14 | 108 40 30 18 15 |
| centro de arrastre D `$960B` | 24000 12500 9500 9900 11000 | 24000 12500 7500 8750 9000 | 24000 12500 9500 9750 10000 | 24000 12500 9500 9750 9500 |
| consumo `$97DB` | 100 | 64 | 90 | 82 |

## Actualización de velocidad por tick de física (05:D3E1..D486, D4DB..D527), acelerador activo, v = velocidad, T = velocidad máxima (`$1EE2`)
1. `v += (T - v) * k >> 10` mientras v < T (k = `$967F`; la mitad si el bit 4 de `$1EF5`). Si v > T: `v -= (v - T) >> 8` (byte bajo). T = `$9597` + `(A7FF - fuel) >> 6`.
2. Pendiente: `v += (-slope * hillfactor[gear]) >> 4` (`$96F3`, igual para todos los coches: 4 5 6 9 14).
3. Arrastre (D453..D486): `v -= min(255, |D - v| >> 8)`. D = entrada de `$960B`. Es mínimo cuando v = D; no es un coeficiente simple.
Ninguno de los pasos usa δ. Equilibrio (pendiente 0): `v* = (k*T - 4*D) / (k - 4)`; medido en pista plana, acelerador a fondo, cambio automático,
la velocidad 4120 (= 60 mph) se alcanza tras 2,1 s (rojo), 1,25 (blanco), 1,78 (morado), 1,33 (azul) frames/60; la meseta en la marcha más alta fue
8850+ (rojo, aún subiendo), 8375, 8840, 8730; es decir, la velocidad máxima es donde empuje y arrastre se equilibran, por debajo del valor de `$9597` en el caso del rojo.
Los números 0-60 de la pantalla de selección mantienen el mismo orden y proporciones parecidas (x2,8), salvo el azul (x3,2).

## Dirección ("grip")
* Límite del desplazamiento lateral por tick (`$1E94`): sin acelerar 640*δ para todos los coches; acelerador activo 384*δ, **blanco 416*δ** (+8,3%); acelerador+freno (P1) 640*δ. Medido, idéntico en los otros tres coches.
* Rampa del ángulo de dirección por tick (neta, medida, idéntica en los cuatro coches): `608*δ` (x2 por debajo de la velocidad 0x280) menos la fuerza de recentrado `320*δ` (`$9B01`).
* `$9DDF` (restado de la rampa por encima de la velocidad 0x280) tiene una fila distinta de cero solo para el azul (160..1280), pero el código la indexa solo con X = 2*δ (bits altos sobrantes de código anterior, 0 para el P1), así que lee la fila 0 (todo ceros). Medido: la rampa del azul es igual a la de los demás. La fila está muerta para el jugador 1 (la copia del P2/ordenador en 05:E120 usa el mismo patrón).
Por tanto la única diferencia física de grip para un jugador humano es el límite del acelerador del blanco; el MID del azul no afecta a la dirección del P1, y rojo/morado/azul son iguales.
