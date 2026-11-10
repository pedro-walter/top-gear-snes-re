# Resumen del randomizer de Top Gear (BETA 0.5)

Visión general de las funciones y correcciones de bugs. Los detalles técnicos están en [09](09-plan-del-randomizer.md), [10](10-implementacion-del-randomizer.md) y [13](13-resultados-clasificacion-podio.md).

## Funciones

**Generación de pistas**
- Cada carrera es una pista aleatoria generada en la propia consola (código 65816) a partir de una semilla hexadecimal de 8 dígitos. La misma semilla da siempre la misma pista.
- Las pistas tienen de 24 a 46 piezas y de 3 a 8 vueltas, y usan uno de los 32 entornos originales.
- Los generadores en Python y en 65816 se compararon en 1500 semillas y dieron resultados idénticos.
- Las señales de curva (chevrons) se colocan antes de cada curva, y las banderas del pit antes de su entrada.
- Árboles y arbustos rellenan los laterales vacíos, usando los tipos del propio entorno.
- Hay obstáculos: un campo de rocas en aproximadamente 1 pista de cada 8, y un cierre de carril con barreras en aproximadamente 1 de cada 16. Las frecuencias se calibraron según las pistas originales.
- La semilla decide la pista, y la dificultad elegida no la altera.

**Pit stop**
- Siempre hay un pit, salvo en carreras cortas, de hasta 129 piezas en total, que el coche rojo termina con un solo depósito. Esto vale para alrededor del 16% de las semillas.

**Menú principal (seis filas)**
- `1 PLAYER` / `2 PLAYERS`, `DIFFICULTY`, `<n> TRACKS`, `SEED`, `SPEED KPH/MPH` y `PLAY GAME`.
- `TRACKS` va de 1 a 99 o infinito.
- `SEED` solo está activa con 1 pista. Con más de una, la fila se ve en gris.
- El teclado hexadecimal de la semilla usa glifos grandes dibujados a mano. A/B escriben, X/Y borran y Start confirma.
- Left/Right sortea una semilla nueva.

**Series de pistas**
- Con 1 pista, la pantalla de resultados vuelve al menú y la semilla se conserva para repetir la pista. No hay ranking mundial.
- Con 2 a 99 pistas, o infinito, cada carrera tiene una pista nueva y los puntos de todos los pilotos se acumulan.
- El marcador tiene 16 bits (hasta 5 dígitos). El original guardaba 1 byte por coche, lo que bastaba para su campeonato corto; una serie de hasta 99 pistas necesita más de 255 puntos, así que el randomizer amplió el campo.
- Las series finitas terminan en un podio con el mensaje "THANK YOU FOR PLAYING!", con la música de "completed Top Gear", y vuelven a la pantalla de título.
- No hay game over ni clasificación.

**Interfaz**
- El minimapa se sustituyó por una franja de progreso de la vuelta, en la barra negra entre las dos pantallas. Muestra las líneas de salida y meta, puntos para el P1, el líder y el P2/ordenador, y la marca del pit.
- Hay un contador `LAP n/m` bajo cada cronómetro.
- La pantalla de título tiene cielo violeta, el texto "RANDOMIZER BY PEDRO WALTER / POWERED BY CLAUDE" y la versión BETA.

**Otros**
- Los glifos de dígitos grandes (0–9, A, C, E, F) se dibujaron a mano, porque la fuente original no tiene 0, 3–9.
- El checksum de la cabecera se corrige, y la ROM se distribuye como parche IPS (solo nuestros bytes).

## Correcciones de bugs

**En el propio generador**
- **Juego a 1/4 de velocidad con gráficos corruptos.** El escáner de objetos leía más allá del final de la vuelta. El generador ahora crea una pieza extra.
- **Escenario corrupto** (pórtico de salida y objetos laterales). El pool de VRAM de 8 KB se fragmentaba. Ahora hay un conjunto gráfico por pista que cabe entero, y el pórtico aparece en los 32 entornos. En 1000 semillas del modelo no quedó ninguna pieza corrupta.
- **Pórtico que desaparecía en algunos entornos**, por tipos de objeto extra. Se corrigió con una tabla de tipos a descartar.
- **IPS antiguo aplicado por Mesen encima de la ROM nueva.** El build ahora reescribe el IPS cada vez.
- **Fuente pequeña:** píxeles rojos sueltos en B, D y 8 se pintaron con el color del contorno.
- **Basura gráfica** en la semilla del menú al volver de una carrera (la fuente no estaba en la VRAM), corregida guardando los glifos en la ROM.
- **Letra cortada** en el contador de vueltas (la T de "LAPS LEFT").

**Bugs del juego original**
- **Vuelta perdida al colisionar cerca de la línea de meta** (corregido en la 0.3). Si el otro coche ya había cruzado la línea, la colisión empujaba al humano por detrás de ella y se descontaba una vuelta. Este es el único bug de colisión que existe en el juego original.
- **Fundido de salida erróneo** cuando un coche repostado aún corría después de que el otro terminara (0.3). Corregido.
- **Un coche dentro de la secuencia del pit** ahora cuenta como "en carrera" al final de la prueba.

**Regresiones de nuestra propia corrección (nunca existieron en el juego original)**
La primera versión de la corrección de la línea de meta (0.3) introdujo dos bugs nuevos, encontrados por jugadores y corregidos en versiones posteriores:
- **Colisión con un coche que ya te había doblado** (encontrado en la 0.3, corregido en la 0.4). El jugador era teletransportado al otro lado de la línea y ganaba una vuelta indebida. El ajuste ahora solo actúa cerca de la línea.
- **Rezagado cerca de la línea** (encontrado en la 0.4, corregido en la 0.5). Con el P2 en modo single player, el coche perdía todo el progreso de la vuelta. La posición ahora queda siempre dentro de la propia vuelta, y hay un script de prueba unitaria (`hitpos_unit.lua`).

## Investigación y documentación (sin cambiar el juego)
El repositorio también documenta cosas que el randomizer no altera: los cambios de marcha ideales ([12](12-cambios-de-marcha-ideales.md)), las diferencias entre los cuatro coches ([14](14-diferencias-entre-coches.md)), la comparación de las ROM USA, Europa y Japón ([15](15-versiones-de-la-rom.md)), los mensajes y globos de diálogo ([11](11-globos-de-dialogo-mensajes.md)) y experimentos de ahorro de combustible ([16](16-ahorro-de-combustible.md)).
