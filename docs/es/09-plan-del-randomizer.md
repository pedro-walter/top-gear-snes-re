# Plan del randomizer (borrador para revisión)

Objetivo: una ROM parcheada en la que **cada carrera es una pista aleatoria generada en la consola a partir de una semilla hexadecimal**.
Las semillas pueden escribirse (para repetir o compartir una pista) o sortearse. Toda pista tiene un pit stop y
3–8 vueltas. Los menús se rehacen para las semillas; sin minimapa.

Todo lo siguiente se basa en los formatos de datos decodificados (docs/05, 06) y en el código de menú leído para este plan.
Los elementos marcados **(verify)** son suposiciones que el primer prototipo debe confirmar.

## 1. Qué es una "pista" en este juego (por qué generar es viable)

Una pista de carrera es íntegramente *dato* en la WRAM, expandido al inicio de la carrera por `load_track_streams` (00:BF44):

| tabla | contenido | cómo se construye |
|---|---|---|
| `$7E4000` slope | 1 palabra / 32 unidades | por pieza de 1024 unidades: byte con signo -> plantilla (33 piezas de pendiente, `0C:85D3`) |
| `$7E4C00` curve | 1 palabra / 32 unidades | igual, con 33 plantillas de curva (`0C:8591`) |
| `$7E5800` scenery | 1 palabra / 32 unidades | por pieza: byte -> una de 38 plantillas (`0C:8545`), cada una uniformemente de un *tipo de carretera* 0..3 (32 palabras) |
| `$7E6400` objects | 1 palabra / 32 unidades | objetos laterales: `type<<9 | side<<8 | lateral/128`; `0x74xx` = entrada del pit |
| `$0200`, `$1E56`, `$1EF0`, `$1EF2` | longitud, vueltas, posición del pit, lado del pit | descriptor, `00:DEA4`, `00:DF24` |

Hallazgos del análisis de las 32 pistas reales (en esta sesión) que hacen fácil generar pistas *razonables*:

* **Las plantillas de pendiente y curva son una gramática diminuta**, no datos libres. Cada plantilla empieza y termina en un *nivel*:
  las pendientes usan los niveles 0, 50, 110, 300, 600, 700, 750, 800, 900, 1000; las curvas 0, 16, 24, 32, 40. Para cada nivel hay
  *subida de rampa* (0->L), *meseta* (L->L) y *bajada de rampa* (L->0) (ids de pendiente 1-4, 5-7, 9-13, 14-17, 18-20, 21-23, 24-26,
  27-29, 30-32; ids de curva 1-4, 5-8, 9-16 con variantes cortas de "badén de una pieza" 17-32 y 13). Un byte de stream negativo
  refleja la plantilla (bajada / dirección de curva contraria). Las pistas reales son exactamente recorridos sobre este grafo
  (`[-9, -12, -12]` y luego vuelve a `[-11, ...]`: las pendientes continúan a través del límite de la vuelta).
* **"Empezar y terminar en la misma pendiente/dirección" es por tanto una regla rígida fácil de imponer:** el nivel al final
  de la última pieza debe ser igual al nivel al inicio de la primera pieza (simplemente hacemos ambos 0 = plano/recto, o permitimos
  cualquier nivel y rotamos el stream — las pistas reales hacen ambas cosas).
* Los tamaños de las tablas permiten hasta **48 piezas** (`$4000-$4BFF` etc.); las pistas reales usan 23-46.
* Las plantillas de escenario son uniformes por pieza (un tipo de carretera), así que un "perfil de carretera" es solo una secuencia de tipos, p. ej.
  `1 1 1 2 2 2 1 1 0 0 ...`. La pieza 0 es siempre la plantilla de salida/meta (5, o 22 para Escandinavia).
* **Pit stop = plantilla de escenario 20 (tipo de carretera 3) o plantilla 2 (tipo de carretera 2) durante una pieza**, más la info del pit `00:DF24`
  = `0x8000|side` + `(piece_start - 512)/2` (las 13 pistas originales con pit lo siguen), más una palabra de objeto `0x747C`
  (tipo 0x3A, bit de lado, lateral 124) en la segunda mitad de esa pieza. El coche del ordenador ya encuentra el pit mediante
  `$1EF0/$1EF2`.
* El entorno (gráficos de horizonte, paleta, anchuras de carretera, script de día/noche, desplazamientos de velocidad de los bots) está indexado por `$1F06` mediante
  tablas de 32 entradas. **Truco: mantener `$1F06` = un "id de entorno" (cualquiera de los 32 originales) y reemplazar solo
  la geometría.** Así la iluminación (p. ej. noche), los gráficos y la dificultad de los bots siguen funcionando sin datos nuevos.

## 2. Arquitectura

```
semilla (32 bits, 8 dígitos hex)
  -> PRNG (xorshift/LCG propio, no el $1FF4 del juego, para que la semilla sea reproducible)
  -> id de entorno (0..31)          -> $1F06 (todas las tablas por pista existentes siguen funcionando)
  -> número de piezas N (24..46 ?)  -> $0200 = N*1024
  -> vueltas 3..8                   -> $1E56
  -> recorrido de pendiente, de curva -> $7E4000 / $7E4C00 (palabras de plantilla copiadas del banco 0C)
  -> recorrido de tipo de carretera + pieza del pit -> $7E5800, $1EF0, $1EF2
  -> objetos laterales + objeto del pit -> $7E6400
```

* El generador es una **rutina nueva en 65816** que reemplaza el cuerpo de `load_track_streams` (00:BF44) — no se escribe ningún stream,
  las tablas expandidas se producen directamente. Lee las tablas de punteros de plantillas del banco 0C.
* El código vive en **nuevos bancos de ROM 10-1F** (ROM ampliada a 1 MB: byte de tamaño de la cabecera + checksum). Solo existen ~6 KB de
  relleno a cero en el original, que es demasiado justo. **(verify: Mesen, bsnes y las flash carts comunes aceptan LoROM de 1 MB
  sin más cambios.)**
* **Herramientas:** no hay ensamblador instalado; escribir un pequeño ensamblador de 65816 en Python (`tools/asm65816.py`, la tabla de
  opcodes ya existe en `tools/disasm.py`) para que el build solo necesite Python. Salida = ROM parcheada y un **parche BPS/IPS**
  (el repositorio queda libre de datos del juego; los usuarios parchean su propia ROM).
* El **generador de referencia en Python** (`tools/trackgen.py`) implementa el mismo algoritmo bit a bit; la versión en 65816
  se prueba contra él con miles de semillas usando una pequeña ROM de pruebas ejecutada headless en Mesen (comparando
  las tablas de la WRAM). La versión en Python también renderiza cada semilla con `track_atlas` para inspección visual.

## 3. Reglas del generador (pistas "razonables")

1. **Longitud:** N piezas, p. ej. 24..44; vueltas 3..8 (uniforme). Opcionalmente las vueltas se sesgan según N para que el tiempo total
   de carrera sea razonable (pregunta abierta).
2. **Pendiente:** recorrer el grafo de niveles. Nivel inicial = nivel final (por defecto plano). Secuencia de "eventos": tramo plano de 1-8
   piezas, colina pequeña (plantillas de badén 2, 8, 10, 13, 14), colina larga = subida de rampa + k mesetas + bajada de rampa, con el signo elegido
   por evento. El nivel máximo depende de un sorteo de "montuosidad" por pista (así la mayoría de las pistas son suaves, unas pocas tipo Loch Ness).
   Restricción: no dos eventos de nivel máximo seguidos; subida total ~ bajada total (**verify** si al juego le importa; la pendiente solo
   cambia la velocidad, así que no es obligatorio).
3. **Curva:** la misma gramática con niveles 16/24/32/40; chicanes (un badén seguido del badén reflejado), horquillas
   (badén de una pieza 17-32), curvas largas. Recta al inicio/final para que el límite de la vuelta sea suave. Un "presupuesto de giros" mantiene
   la curvatura neta con signo cerca de cero (un circuito cerrado gira ~360 grados; no hace falta para la física, solo para la plausibilidad).
4. **Tipos de carretera:** secuencia de tipos, en su mayoría constante con estrechamientos/ensanchamientos ocasionales (0<->1<->2), pieza 0
   = plantilla de salida. **Exactamente una pieza de pit**, no en las 3 primeras/últimas piezas, lado según la semilla.
5. **Info del pit:** `DF24 = 0x8000*side | ((piece*1024 - 512)/2)` equivalente; objeto del pit `0x747C` (bit de lado activo para la izquierda)
   en la segunda mitad de la pieza del pit. El tipo del pit (2 o 3) y su estilo de carretera deben ser lo bastante anchos en el entorno elegido.
   **(verify por entorno)**; los entornos sin un tipo utilizable tienen su palabra de estilo de carretera parcheada
   (`00:DEE4`), que son datos simples.
6. **Objetos:** por pieza 10-20 objetos (densidad original), alternando lados con espaciado aleatorio, tipos sorteados del
   conjunto de tipos de objeto del propio entorno elegido (p. ej. 27/28/9/38 para el desierto), lateral dentro del rango original
   (60..206), ninguno dentro de la pieza del pit salvo la entrada del pit, ninguno en la pieza 0 (el pórtico es un objeto de grupo `0x8002`
   en la posición 0).
7. **Entorno:** sorteado entre los 32; New York sigue siendo nocturna, Hiroshima noche->día etc. automáticamente.
8. **Dificultad/bots:** sin cambios (`00:DDE4[env]`).

## 4. Menús

La lectura de `0F:918B` (menú principal), `0F:943D` (entrada de texto), `0F:821D` (pantalla de ubicación) muestra qué debe cambiar:

| cambio | dónde | enfoque |
|---|---|---|
| COUNTRY -> `RANDOM` / `SEED` | entrada 2 del menú principal (`0F:929E`, cadena en `0F:A6CD`) | Left/Right alterna como hacen las entradas 0 y 3; `RANDOM` = sortea una semilla basada en `$1FFC` al PLAY GAME, `SEED` = abre la entrada de semilla con A |
| pantalla de entrada de la semilla | reutilizar `text_entry` (`0F:943D`) con un **teclado hex**: 16 teclas + DEL + END en lugar de A-Z | las cadenas de la cuadrícula son tablas de texto simples en `0F:A792`.. ; solo cambian el envolvente del cursor/límites y el mapeo tecla->carácter (el búfer de 8 caracteres `$68..$6F` es exactamente una semilla hex de 8 dígitos) |
| pantalla de splash/ubicación | flujo de `0F:815A`, `0F:8A81`, `0F:8ADC` | reemplazar el texto de ciudad/país por `SEED  XXXXXXXX`; STATISTICS muestra vueltas (generadas) y distancia; saltar la carga del minimapa (`0F:821D/82F0`); mantener o quitar la línea del récord de vuelta |
| maquinaria del campeonato | `0F:8733`, contraseñas `0F:93DC` | desactivada: sin desbloqueo de países, sin contraseñas; tras una carrera vuelve la misma pantalla con la semilla (repetir) o una semilla nueva |
| minimapa del HUD de la carrera | carga de tiles en los cargadores + `update_map_dots` | borrar los tiles del mapa; los tres sprites marcadores se reutilizan como puntos de progreso de la vuelta en la barra negra (docs/10, `src/bar.asm`); **opcional más adelante:** dibujar un minimapa procedural a partir de los datos de curva (integración del rumbo) |

Teclado hex propuesto (a refinar con tus comentarios sobre la distribución de letras; la cuadrícula original tiene 6 columnas con
`END` y dos celdas de glifo para espacio/borrar):

```
0 1 2 3
4 5 6 7
8 9 A B
C D E F
< DEL   END
```

## 5. Hitos (cada uno verificado automáticamente en Mesen headless)

1. **M0 herramientas:** ensamblador, expansor/parcheador de ROM con corrección de checksum, ROM de pruebas, salida BPS.
2. **M1 generador Python + atlas:** generar 1000 semillas, validar reglas (los niveles encadenan, inicio/fin iguales, un pit, tamaños),
   renderizar una hoja de contactos.
3. **M2 generador 65816 + hook en el cargador:** reemplazar `load_track_streams`; el arnés demuestra WRAM == Python en 1000 semillas.
4. **M3 la carrera funciona:** fijar una semilla, conducir/piloto automático una vuelta en Mesen headless (estilo del `trk_drive.lua` existente): velocidad, vueltas,
   posición, **el coche del ordenador para en el pit, el disparador del pit humano funciona**, pantalla de resultados, sin cuelgues, 20 semillas x 3 entornos.
5. **M4 menús:** alternancia SEED/RANDOM, entrada hex, pantalla de splash, sin minimapa; recorrido por script del menú con capturas.
6. **M5 pulido:** equilibrio (combustible vs longitud, vueltas), minimapa procedural opcional, modo demo/attract con semillas aleatorias,
   README + publicación del parche.

## 6. Riesgos / incógnitas

* Si todo entorno tiene un tipo de carretera lo bastante ancho para una calle de boxes convincente (**M1/M3**); alternativa: parchear las palabras de estilo.
* Combustible vs longitud de la carrera: 8 vueltas de una pista de 46 piezas es mucho más largo que cualquier carrera original; el pit stop se diseñó para
  ~3-8 vueltas de 23-46 piezas, así que debería más o menos aguantar; ajustar en M5.
* Los conjuntos de tipos de objeto por entorno y sus manejadores de colisión (`05:F5C3[type]`) se reutilizan tal cual — riesgo bajo.
* El borrador de WRAM del generador (necesita ~100 bytes) no debe colisionar con variables del juego: usar el banco `$7F`.
* El comportamiento de una imagen LoROM de 1 MB en hardware real/flash cart no está probado (los emuladores bien).
* El modo 2 jugadores, el modo demo (`90E6`) y el bucle attract pasan todos por `$1F06`: deben apuntarse también a una semilla.

## 7. Decisiones (propietario, 2026-10-16)

1. Tras una carrera, **volver al menú principal**. Sin puntos de campeonato acumulados: mostrar solo los tiempos y
   puntos de esa carrera. La semilla sigue seleccionada (repetición) hasta que se cambie en el menú.
2. Semilla = **8 dígitos hex** (32 bits).
3. El layout del teclado hex (sección 4) está aprobado.
4. **Reutilizar los 32 entornos originales**; sin entornos nuevos.
5. **ROM de 1 MB** es aceptable.
6. El formato de distribución se aplaza; primero un prototipo funcional.

Estado: la implementación ha comenzado y el prototipo funciona – ver docs/10-randomizer-implementation.md.
