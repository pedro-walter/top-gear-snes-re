## Física del coche (banco 05) – variables de la WRAM (vista de la CPU, banco 0)
| dirección | significado (confianza) |
|---|---|
| `$1E5A` | **velocidad** (jugador), 16 bits. ~3500 con 85 km/h en el HUD. **Confirmado por el usuario contra el HUD.** |
| `$1E5E` | **RPM** = `speed * $9767[gear]` << 1. **Confirmado.** |
| `$1E72` | índice de la **marcha**. **Confirmado.** |
| `$1EE2` | límite de velocidad máxima de la marcha actual = `$9597[Y] + (($A7FF-$1E62)>>6)`. Observado siguiendo al coche del *ordenador* (borrador compartido, sobrescrito por la actualización del coche de la IA) – es decir, la misma rutina corre para los dos coches. |
| `$1E62` | **combustible, cuenta HACIA ABAJO** (confirmado por el usuario; 0 = vacío). Consumo por tick = `((RPM * $1EFD) >> 16)` aproximadamente, los 10 bits altos `+1` (código 05:D638-D67B), por lo que es por frame y depende de las RPM. Menos combustible -> `$1EE2` mayor (la fórmula usa `$A7FF - fuel`), como observó el usuario. En 0: limpia el bit0 de `$1EB4`, activa el bit `$20` de `$1EF5`, pone a cero las RPM `$1E5E` -> sin más empuje, el coche se desliza. |
| `$1EFD` (byte) | **factor de consumo del coche del jugador** = `CarStats[$1F8F]` (00:97DB: rojo 100, blanco 64, coche2 90, coche3 82). `$1EFE` = lo mismo para el coche del ordenador (`$1FAC`; índice 0 si `$1F04`==0). Definido por 00:C69E-C6B5. El usuario vio la palabra 25700 (rojo) / 25664 (blanco) = `$1EFE:$1EFD` = $6464 / $6440. |
| `$1FAC` | índice del coche controlado por el ordenador (pantalla de abajo) |
| `$1EEA` | desplazamiento de tabla del coche del ordenador = `$1FAC << 4` |
| `$1EB4` | bits de estado; el bit0 se limpia con el depósito vacío (probablemente 'motor encendido / puede acelerar') |
| `$1ED7` | **posición en la pista** del jugador; vuelve a 0 en cada vuelta. `$7E4000[pos>>4]` es por tanto una tabla por posición de la pista (término de pendiente/curva aplicado a la aceleración). |
| `$1E6C` | **nitro activo**: negativo mientras el nitro está encendido, 0 en otro caso. (selecciona la mitad de tabla +$3A) |
| `$1EF5` | flags. bit `$20` = sin empuje (activo con combustible vacío o RPM 0). bit `$10` = estado de caída de RPM (05:D30F: RPM -= $30/tick, invierte `$1E66` en cada tick, p. ej. tras un cambio de marcha/golpe – semántica no verificada). |
| `$1F10` | **nivel de dificultad/skill** (encontrado por el usuario con búsqueda de memoria; referenciado en 00:A5F3, 00:C062, 05:EE19, 05:EE89, 0F:83EB...; los usos en el banco 05 probablemente son de la IA/rubber-banding) |
| `$1F8F` | **coche seleccionado** (usuario: 0 rojo, 1 blanco, 2 morado, 3 azul); referenciado sobre todo por el código de menú del banco 00, no por la física del banco 05 |
| `$1F7A` | **máscara del botón de subir marcha** (máscara de bits de la palabra del joypad; usuario: 0x0010 = R). 0 => cambio automático. |
| `$1F7C` | **máscara del botón de reducir marcha** (0x0020 = L). 0 en automático. |
| `$1F7E` | **máscara del botón de nitro** (0x0080 = A); sigue activa en automático. Leída en 05:D35F. |
| `$14` (direct page) | palabra actual del joypad del jugador activo; la rutina de velocidad hace `TRB $14` con las máscaras anteriores (comprueba y limpia el bit). Palabra del joypad: B=8000 Y=4000 Sel=2000 Start=1000 Up=800 Down=400 Left=200 Right=100 A=80 X=40 L=20 R=10. |
| manual vs automático | **no hay una flag separada**: manual <=> `$1F7A`/`$1F7C` distintos de cero (el código de menú en 0F:9828 les hace OR para elegir el gráfico AUTO/MANUAL -> `$5A`). Los 4 esquemas de control presumiblemente cargan máscaras distintas. `$0087`/DP`$87` es un borrador sin relación. |
| `$1EE8` | **desplazamiento de tabla del coche del jugador = `$1F8F << 4`** (definido en 00:A714; 0 para rojo, 16 blanco, ...). No depende del nivel de skill (prueba del usuario). Se suma a gear*2 al indexar las tablas por coche. |

Las tablas están en el **banco 00** (DBR=00 durante el código de física), en bloques por coche de 8 palabras (16 bytes), con 5 entradas de marcha cada uno:
| tabla (banco 00) | contenido |
|---|---|
| `$9597` | velocidad máxima por marcha. car0 (rojo): 4500, 6000, 8400, 9600, 10000. car1 (blanco): 4000, 5800, 7400, 8000, 8500. car2: 4200,6000,8400,8900,9200 |
| `$96F3` | factor de aceleración por marcha: 4, 5, 6, 9, 14 (misma forma en los coches vistos) |
| `$960B` | término de arrastre por marcha (car0: 24000,12500,9500,9900,11000; car1 menor desde la marcha 3) |
| `$9767` | relación de marcha para las RPM: 127, 96, 58, 42, 30 |
| `$99DB` / `$9A15` | umbrales de velocidad para reducir / subir marcha: reducir 0,1150,2200,3500,4500; subir 1600,3200,4000,5440,65535 |
| `$97DB` | byte de consumo por coche [100, 64, 90, 82] |
| `$97DF` / `$981F` | escaleras de 8 entradas +640*n / -640*n por coche, indexadas por `$1E90`-1: escritas en `$1E94`/`$1E92` (límites simétricos, probablemente dirección/grip) |
Escala de velocidad: `$1E5A`/~41,7 = km/h (10000 ~ 240 km/h); cambios de marcha hacia arriba a ~38, 77, 96, 130 km/h.
Depósito lleno = `$A7FF` (definido tanto para `$1E62` como `$1E64` al inicio de la carrera, 00:A700). Bonus de velocidad máxima = `($A7FF-fuel)>>6` (0 con el depósito lleno, ~671 con el depósito vacío).
Actualización de la velocidad (`05:D2E0 car_update_speed_gear`, escribe `$1E5A` en 05:D439/D486):
 accel = (`$7E4000[$1ED7>>4]` negado, escalado) x `$96F3[Y]` mediante el multiplicador con signo de la PPU (`$211B/$211C`, resultado en `$2135`),
 `>>4`, sumado a la velocidad; limitado a `$1EE2`; luego el arrastre `$960B[Y]` tira hacia 0; limitado a >= 0.
 Lógica de cambio por encima: modo automático (`$1F7A`==0) compara la velocidad con los umbrales `$99DB`/`$9A15` (sube/baja); modo manual (`$1F7A`!=0) incrementa/decrementa `$1E72` (índice máx. 4) cuando los bits de botón de `$1F7A`/`$1F7C` están activos en `$14`.


## Nitro
* `$1E6C` (P1) / `$1E6E` (P2): **2 bits bajos = cargas de nitro restantes** (3 al inicio de la carrera, 00:82E2), bit15 = nitro activo. El HUD muestra el número de cargas (`AND #3`, menos 1 mientras está activo: 00:D04F).
* Disparador (05:D358): exige cargas != 0 y nitro no activo (bit15 limpio), máscara de botón `$1F7E` (A) pulsada => `$1E6C |= 0x8000`.
* Mientras está activo, la máquina de estados 00:B9ED avanza la palabra en cada frame: fase A (bit14=0): +0x200/frame durante 32 frames (destello de paleta); fase B (bit14=1,bit13=0): +0x20/frame durante 256 frames;
  fase C (bit13=1): +0x100/frame durante 32 frames; luego da la vuelta a positivo y **se resta una carga** (DEC). Total **320 frames (5,3 s)** por nitro. No puede reiniciarse mientras está activo.
* Efecto: toda la consulta a las tablas de física usa `Y += 0x3A` (un segundo conjunto de filas en `$9597/$960B/$967F/$96F3`: velocidad máxima, arrastre, tracción del motor, aceleración). Filas de nitro (coche rojo): máx. 5300/7200/**11400**/12500/15600, tracción 108/50/31/22/18.

## Física de la velocidad (totalmente modelada – `tools/physics.py`, exacta a la unidad respecto al juego en 850 ticks)
Por tick (05:D2E0.., ~2 ticks cada 3 frames):
```
top   = TOP[Y] + ((0xA7FF - fuel) >> 6)                 ; $1EE2   (Y = car*16 + gear*2 (+0x3A si nitro))
speed += slope_term   ; s = $7E4000[pos>>5]; A=-s; si s>0: A>>=2 (aritmético); A>>=4 (extensión de signo de 12 bits)   (la bajada es 4x más fuerte que la subida)
speed -= (|DRAG[Y] - speed| >> 8) & 0xFF                ; arrastre, velocidad limitada a >= 0
si acelera (máscara del botón X $1F76) y fuel>0 y finishers<10:
    diff = top - speed
    si diff < 0: speed -= (|diff|>>8)&0xFF
    si no:       speed += (diff * PULL[Y]) >> 10         ; (tabla $967F; la mitad si el bit 0x10 de $1EF5)
si no: en rueda libre (solo el sangrado del exceso de velocidad)
```
Equilibrio (plano, depósito lleno, coche rojo): m1 3829 / m2 5070 / m3 7959 / **m4 9347** / m5 8857 (219 vs 207 km/h): sin nitro la 4ª marcha del coche rojo es más rápida que la 5ª.
Con nitro: 4655 / 6596 / 11367 / 12408 / **15488** (363 km/h). Menos combustible => `top` mayor (+0..670) => equilibrio mayor y diferencia (velocidad máx.) mayor => aceleración más rápida (esto explica la observación del usuario).

### El truco "3ª marcha + nitro"
Mejor marcha para *aceleración* (ganancia neta de velocidad por tick, pista plana, nitro): 1ª por debajo de ~2500, **3ª marcha (índice 2) desde ~3000 hasta ~6500 unidades (70..155 km/h)**,
5ª por encima de ~7000. El cambio automático (umbrales de subida 1600/3200/4000/5440 unidades) ya está en 4ª/5ª entre 4000-5500, donde la tracción es solo 149/131 (4ª) o 134 (5ª) por tick frente a
**195/169/143 en 3ª** a 4000/5000/6000. Así que: quédate en 3ª (manual), activa el nitro y pasa a 5ª a ~7000 -> notablemente más rápido que el automático. Motivo: la fila de nitro de la 3ª marcha tiene máx. 11400 (frente a 8400 normal) y
tracción 31 (frente a 18 de la 5ª), así que la diferencia `(top - speed)*pull` es mayor allí. Lo mismo vale para los otros coches (sus filas de nitro son casi idénticas).
