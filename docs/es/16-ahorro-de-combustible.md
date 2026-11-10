# Ahorrar combustible: qué funciona y qué no (medido en Mesen headless, ROM USA)

Pregunta: juego de torneo, coche morado (rojo en segundo lugar). Algunas pistas requieren dos pit stops; ¿hay alguna forma, además de pasar pronto a 5ª, de ahorrar el poco combustible que elimina una parada? Conducir más despacio (unos 170 km/h, ZSNES 1.42) "salió mal".

Método: `scripts/fuel_lab.lua` conduce el juego real con un bot de dirección (controlador PD sobre la posición lateral `$1E8A`, acelerador mantenido, cambio manual forzado, coche/pista modificados) y registra cada tick de física (velocidad, marcha, combustible, posición, delta de frames). `tools/fuel_sum.py` resume por vuelta, `tools/fuel_stops.py` convierte el combustible por vuelta en cuentas de pit stops. Todos los números son de Mesen (temporización precisa); ver la pregunta abierta al final.

## 1. Más despacio no es más barato (esto explica que saliera mal)

Por tick la quema es `((RPM*burn_byte)>>14)+1`, un tick cada ~3 frames (`$1E90` = delta de frames, 2,5..3,0), y la distancia por tick es `speed*delta/2`. Combustible por distancia medido, morado, 5ª marcha, vueltas de Tokyo + London (unos 30 000 ticks):

| velocidad | 105-160 km/h | 160-200 | 200-220 | por debajo de 100 |
|---|---|---|---|---|
| combustible por distancia (relativo) | 1,00 | 1,00 | 1,00 | **1,4 a 3** (el delta también baja a 2,2..2,6 al ir muy lento, así que más ticks por km, más el +1 constante por tick) |

En 5ª marcha el combustible por km es **plano de 150 a 220 km/h**; el `+1` constante por tick es solo el 5-8 % de la quema. Soltar el acelerador nunca ayuda (docs/12: la quema no depende del acelerador). Un límite de velocidad en 5ª: 200 km/h o más = mismo combustible, 170 = +2,5 % por vuelta, y 150 = +32 % **solo porque el bot nunca alcanzó la velocidad de cambio 4ª→5ª y se quedó en 4ª**. Si el coche se queda en 4ª a 170 km/h (o el cambio automático, que solo sube a 5ª a ~211 km/h) las RPM son un 40 % mayores, lo que es una causa probable del resultado en ZSNES. Regla: sea cual sea la velocidad, estar en 5ª.

## 2. Cosas que ahorran combustible (morado, bot con dirección)

| palanca | efecto | coste |
|---|---|---|
| **Subir de marcha pronto** (`SH=20,28,36,44` o "subir en cada tick") | primera vuelta Tokyo 9748 vs 10121 (-3,7 %), London 3 vueltas 31041 vs 31620 (-1,8 %); unos -370 por tramo (salida y cada salida del pit) | de 0 a +1 s aprox. |
| **Dejar secar el depósito y deslizar** | el coche vacío se desliza **5550 unidades de posición desde 171 km/h = 0,14 vuelta = unos 1400 equivalentes de combustible (3 % de un depósito)**; las marchas 2-5 son idénticas (+-2 %), la 1ª solo 3800 | ninguno, si termina en la entrada del pit o en la línea |
| **Nitro** (los tres) | neutro en combustible: un nitro 700 frames tras la salida: 9752 vs 9748 de combustible, **-1,9 s**; 1500 frames: 9465 (-3 %), -1,4 s | ninguno |
| Limitar la velocidad justo bajo un escalón de quema (morado 200,4 y 218,6 km/h) | 3 vueltas London: 30905 (límite 218) / 30966 (límite 200) vs 31041: -0,3 %, +1,4 s / +3,1 s | no merece la pena |
| Levantar en las curvas (`CORNER=lift`) o truco del freno | 1,5 % menos combustible, +2 s por vuelta (levantar pierde velocidad) | no merece la pena |

La quema es un entero que sube 1 a velocidades fijas, así que el coste por km es un diente de sierra de +-4 %: morado 5ª escalones en 182,2, **200,4**, **218,6**, 236,8 km/h (rojo 5ª 180,4, 196,8, 213,0, 229,4; rojo 4ª cada 11-12 km/h). En la práctica la duración del tick (`$1E90` entre 2,5 y 3,0, según cuánto tenga que dibujar el juego) cambia el combustible por km hasta +-8 %, más que el diente de sierra, así que mantener una velocidad justo bajo un escalón no es medible y cuesta más tiempo del que ahorra.

## 3. Cuánto cuesta un pit stop (disparador forzado en Tokyo, P1)

* Sin repostar (salir en el estado "espera acelerar" con combustible != 0): **5,3 s** perdidos.
* Con repostaje: **7,5 s + 0,26 s por 1000 unidades** añadidas. El repostaje corre a 63,5 unidades por frame (`+$7F` cada dos frames, no en cada frame como suponía docs/04): 34400 → 43007 tarda 150 frames. Una parada completa desde 34400 son 9,7 s.
* Salir antes exige pulsaciones *nuevas* del acelerador durante el estado de repostaje (mantenerlo desde antes no hace nada), así que un repostaje parcial es posible: reposta solo lo que necesita el resto de la carrera.

Así que el combustible ahorrado vale solo 0,26 s por 1000 unidades, pero **una parada ahorrada vale 7,5 s más toda la sobrecarga del segundo repostaje**: lo único que importa es si cruzas un umbral de parada.

## 4. Cuántas paradas (modelo inactivo de `base_t<track>_c<car>.csv`, coche centrado, pit solo en la entrada del pit, repostaje hasta lleno)

Ejecuta `python3 -I tools/fuel_stops.py 2` (morado) o `0` (rojo). Depósitos necesarios para toda la carrera (1 depósito = 43007), ideal / realista con bot (+3,4 % de combustible por vuelta, medido con el bot de dirección, tres vueltas London/Tokyo):

| pista | vueltas | depósitos del morado | paradas del morado: ideal, realista, + 5ª pronto, + deslizar con depósito seco | depósitos del rojo | paradas del rojo iguales |
|---|---|---|---|---|---|
| 3 San Francisco | 6 | 1,00 | 0, 1, 1, **0** | 1,10 | 1,1,1,1 |
| 4 Rio | 6 | 1,38 | 1,1,1,1 | 1,55 | 1,1,1,1 |
| 6 Chichen Itza | 6 | 1,09 | 1,1,1,1 | 1,23 | 1,1,1,1 |
| 8 Tokyo | 7 | 1,53 | 1,1,1,1 | 1,70 | 1,1,1,1 |
| 9 Hiroshima | 5 | 1,03 | 1,1,1,1 | 1,17 | 1,1,1,1 |
| 11 Kyoto | 6 | 1,45 | 1,1,1,1 | 1,62 | 1,1,1,1 |
| 12 Munich | 7 | 1,43 | 1,1,1,1 | 1,62 | 1,1,1,1 |
| 14 Black Forest | 6 | 1,20 | 1,1,1,1 | 1,33 | 1,1,1,1 |
| 15 Frankfurt | 8 | 1,39 | 1,1,1,1 | 1,52 | 1,1,1,1 |
| 21 Nice | 7 | 1,32 | 1,1,1,1 | 1,46 | 1,1,1,1 |
| 22 Bordeaux | 6 | 1,21 | 1,1,1,1 | 1,34 | 1,1,1,1 |
| 25 Rome | 6 | 1,39 | 1,1,1,1 | 1,54 | 1,1,1,1 |
| 28 London | 8 | 1,86 | 1, **2, 2, 1** | 2,07 | 2,2,2,2 |

(Las demás pistas no tienen pit y tienen 3-4 vueltas.) Consumo extra que un plan de 1 parada puede absorber antes de necesitar una segunda parada (modelo ideal): morado Tokyo +18 %, Rio +33 %, Rome +34 %, **London +1 %**; rojo Tokyo **+6 %**, Kyoto +17 %, Rome +20 %, Munich +20 %, Frankfurt +21 %.

Así que, según este modelo, la **única pista del morado donde ahorrar combustible elimina una parada es London** (y San Francisco podría ir sin ninguna parada); London con el rojo necesita dos paradas hagas lo que hagas. **Tokyo es una parada para el morado con un margen del 18 % y para el rojo con un margen del 6 %.** Si Tokyo necesita dos paradas en tu juego, quema al menos un 18 % (morado) / 6 % (rojo) más que en estas ejecuciones.

London con el morado de punta a punta (bot de dirección, cambio pronto, disparador del pit forzado en la entrada pos 10752 de la vuelta 5, combustible 0): el depósito se secó exactamente en la entrada (sin deslizar faltan 2500 unidades de posición, con el pit al 27 % de la vuelta), el coche entró en el pit a 177 km/h con `fuel == 0` (el juego lo maneja, 05:D75E activa el bit 0 de `$1EB4`), repostó 0 → 39243 en 600 frames y le quedaban 8566 con 0,8 vueltas por delante (unos 8500 necesarios). El registro terminó ahí, así que la llegada en sí no se observó: una parada funciona, pero con un margen de aproximadamente 1-2 %.

## 5. Pregunta abierta: el emulador

El combustible por distancia es proporcional a `1/delta`, donde delta (`$1E90`) es cuántos frames dura una pasada del bucle principal. El bucle está limitado por la CPU (unos 3 frames por pasada en una SNES real y en Mesen, docs/15). Un emulador que ejecuta el bucle del 65816 más rápido que el hardware (ZSNES 1.42 no es exacto al ciclo) consigue 2 frames por pasada, y entonces **la misma conducción quema un 50 % más de combustible por km** (y los temporizadores de nitro/repostaje, contados en frames, siguen igual). Si el torneo corre en hardware o en un núcleo preciso, planifica con la tabla de arriba; si es ZSNES, las cuentas de paradas de arriba son optimistas. ¿En qué emulador es el torneo, y cuántas paradas necesita allí Tokyo (morado)? Eso lo resuelve; no puedo ejecutar ZSNES aquí.

## Reproducir

```
TRACK=28 CAR=2 LAPS=5 STEER=1 SH=20,28,36,44 TAG=L_ref tools/mesen.sh scripts/fuel_lab.lua
python3 -I tools/fuel_sum.py out/fuel/L_ref.csv
```

Variables de entorno: `TRACK CAR(0 rojo,1 blanco,2 morado,3 azul) LAPS STEER(1=el bot conduce, 0=lateral fijada en 0) SH(velocidades de cambio km/h 1→2,2→3,3→4,4→5) CAP/CAPU(levantar por encima de km/h / unidades brutas) CORNER(full|lift|brake) NITRO(frame tras la salida para pulsar A) PITAT/PITLAP/PITFUEL(forzar el pit en esa pos en esa vuelta, salir con ese combustible) COASTAT/COASTG(secar en ese frame, marcha de deslizamiento)`. Ejecuciones `base_t<track>_c<car>`: `TRACK=t CAR=c LAPS=3 TAG=base_t<t>_c<c> ... scripts/fuel_lab.lua` (por defecto `SH=40,63,100,167`, `STEER=0`). Las ejecuciones en paralelo necesitan homes separados: `tools/mesen.sh`, `mesen2.sh` .. `mesen4.sh`.
