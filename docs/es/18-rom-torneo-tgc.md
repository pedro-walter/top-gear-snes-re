# La ROM de torneo TGC (`Top Gear TGC Rom (E) [!].smc`)

Una ROM hack de la comunidad hecha para los torneos de *Top Gear Championships* (TGC). Permite que el organizador **elija las pistas del torneo en el menú de
opciones** y luego las corre en orden con **puntos de campeonato acumulados** y sin reglas de clasificación. Todo lo de abajo se descubrió comparando byte a byte
con `Top Gear (Europe).sfc`, desensamblando el código nuevo (`tools/lindis.py`) y ejecutándolo en el emulador (`scripts/tgc_flow.lua`). La ROM no está en el repositorio
(tiene copyright, `*.smc` está en el `.gitignore`); las capturas de `docs/img/tgc_*.png` salen de ella.

| | |
|---|---|
| archivo | 1 048 576 bytes, **sin cabecera de copiador** (pese al `.smc`), LoROM |
| base | **Top Gear (Europe)**: los primeros 512 KB son la ROM europea (con el parche de 50 Hz de docs/15) con **322 bytes cambiados** |
| espacio nuevo | bancos `10` y `12` (archivo `0x80000-0x97FFF`; el banco `11` y todo desde el banco `13` es `00`). Código y tablas en `10:8000-9526`, la splash (código, paleta, tilemap, tiles) en `12:8000-E8F7` |
| cabecera | título `TOP GEAR`, país `02`, pero el byte de tamaño `$7FD7` es `00` (Europe: `09`) y las palabras de complemento/checksum `$7FDC-$7FDF` (`$21B2` / `$DE4D`) no concuerdan entre sí ni con la imagen; a los emuladores les da igual |
| crédito del autor | en la splash: *"A gift to Top Gear Championships ... © Kyle Blackthorne, lanzada el 14/07/2019"*, facebook.com/groups/topgearchampionships |

## 1. Lo que ve el jugador

1. **Pantalla splash** (`docs/img/tgc_splash.png`) antes de arrancar el juego: logo TGC, una frase en portugués, el crédito. Entra con efecto de mosaico y
   sale al pulsar **cualquier botón del mando** (B, Y, Select, Start, A, X, L, R; la cruceta no cuenta) o sola tras más o menos medio minuto
   (seguía en pantalla tras 1 580 frames en el emulador). Después siguen las pantallas normales de Kemco y del título.
2. **Menú de opciones** (`docs/img/tgc_menu_track.png`): la cuarta fila, que era `SPEED KPH/MPH`, ahora es **`◄ TRACK ►`** y el nombre de la pista elegida se
   escribe debajo (`SAN FRANCISCO`), seguido a la derecha de un **número = cuántas pistas hay en la lista del torneo**. `PLAY GAME` bajó una línea para hacer sitio.

   | tecla en la fila TRACK | efecto |
   |---|---|
   | Derecha / Izquierda | pista elegida `$1F06` +1 / -1, con vuelta 31 <-> 0. **Las 32 pistas son accesibles**, sea cual sea el estado de desbloqueo de los países (la fila COUNTRY se ignora cuando existe una lista) |
   | **A** | añade la pista mostrada al final de la lista (se ignora con 32 entradas) |
   | **B** | quita la última pista de la lista (se ignora si está vacía) |
   | PLAY GAME | empieza (ver 2.) |

   La lista es **ordenada**, puede repetir la misma pista y tiene como máximo 32 entradas. La antigua acción "A alterna mph/km/h" de esa fila ya no existe.
3. Con una lista de **4 a 32 pistas** el juego corre un **torneo**: pantalla de lugar -> carrera -> RESULTS (puntos de esta carrera) -> **WORLD RANKING**
   (`docs/img/tgc_world_ranking.png`, puntos acumulados de los 20 pilotos) -> pantalla de lugar de la siguiente pista de la lista -> carrera ... Tras la última carrera el
   juego muestra la escena original *"completed Top Gear"* y vuelve a la pantalla de título, que **borra la lista y los puntos**.
4. Con **0 a 3 pistas** no pasa nada especial: el juego se comporta como la ROM europea original (una carrera en la pista de la fila TRACK y vuelta al menú de opciones;
   con 0 entradas es exactamente el flujo original). Es decir, el torneo mínimo son cuatro carreras (el tamaño de un "país" original).

Diferencias con el campeonato original (todas verificadas forzando el final de las carreras, sección 5):
* **Sin clasificación.** Acabar 10º está bien; no se pone nada a cero, no hay mensaje "sorry you failed to qualify", ni lógica de país/contraseña, ni desbloqueos.
* Los puntos por puesto son los 20, 15, 12, 10, 8, 6, 4, 3, 2, 1 originales (tabla copiada a `10:8010`), pero se suman **sin el límite de 99** en toda la lista.
* La **posición de salida de la siguiente carrera** sigue saliendo del resultado anterior (docs/03), como en el juego original.
* Al final `$1F10` (dificultad) queda en **2 (championship)**: efecto secundario del camino "completed" (`10:8400` lo escribe). La dificultad elegida en el menú no se restaura.

## 2. Estado guardado en el banco 7F (`7F:2400-25FF`, nunca inicializado al encender)

| dirección | significado |
|---|---|
| `7F:2400` (w) | "hay una carrera de torneo armada". En cada entrada al menú principal vale `idx != count` (`10:8500`); el primer fade-out posterior lo pone a 0 (`10:8300`) |
| `7F:2402` (w) | `idx` = número de carreras ya terminadas = índice en la lista de la carrera que va a correr |
| `7F:2404`, `7F:2406` (w) | copias de `$1F00` / `$1F02` (puestos finales del jugador 1 / 2) tomadas en ese fade-out, devueltas a `$1F00/$1F02` cuando se prepara la siguiente carrera |
| `7F:2408` (w) | `count`, número de pistas de la lista (0..32) |
| `7F:240A + 2*i` (w) | número de pista (byte bajo) de la carrera `i` |
| `7F:244A` | dígito de las unidades del contador durante la edición (el de las decenas está en `$11DC`, tiles `$1B + dígito`) |
| `7F:2450 + 2*car` (w) | tile del **dígito de las centenas** a imprimir en el ranking para cada coche (0 = ninguno, `$1C` = "1", `$1D` = "2" ...) |
| `7F:2490 + 2*k` (w) | 20 direcciones del búfer de tilemap `$1614 + $40*k`, una por fila del ranking (se comparan con la dirección que se está dibujando) |
| `7F:24FE` | borrador |
| `7F:2500 + 2*car` (w) | **total del campeonato en 16 bits** de cada id de coche (original: byte en `$1F4E + car`) |

El bloque se borra (`7F:2400-25FF`) y la tabla de filas se rellena en `10:82A0`, enganchado a la salida de la pantalla de título (`0F:8F4C`). Por tanto un **torneo nuevo siempre empieza en la pantalla de
título**, y una lista montada antes de un soft reset/título se pierde. El byte original `$1F4E` sigue recibiendo `puntos mod 100` (el código lo mantiene por debajo de 100 y pasa el exceso al tile de centenas), así que el código de dibujo original sigue funcionando.

## 3. Cómo funciona: los hooks

El hack es un conjunto de desvíos `JML` del código europeo al banco `10`; cada desvío vuelve a ejecutar las instrucciones que sobrescribió y regresa. (Dirección europea -> código nuevo.)

| dónde (Europe) | sobrescrito | desvío | qué hace |
|---|---|---|---|
| `00:8000` entrada del reset | `CLD; SEI; LDA #0` | `12:8000` | **splash**: init completo de registros PPU/CPU, modo BG 3 (256 colores), paleta `12:8400` (0x200 B), tilemap `12:8700` (0xC00 B), tiles por DMA (programado como 0x8000 B desde `12:9000` + 0x6000 B desde `13:9000` = un juego completo de 896 tiles a 8 bpp; los datos realmente presentes son `12:9000-E8F7`, el resto lee ceros); fade in de 16 pasos con mosaico + brillo; espera `$4218 & $F0F0` (cualquier botón) o 255 x ~0,1 s; fade out; `JML 00:8004` |
| `00:818A` entrada del menú principal | `SEP #$20; LDA #0` | `10:8500` | `7F:2400 := (idx != count)`; `JML 00:818E` |
| `0F:821D` `load_minimap_graphic` (lo primero que hace el menú/pantalla de lugar) | `LDA $1F06; CMP #$10` | `10:8700` | si `count >= 4`: `$1F06 := list[idx]` (byte bajo), así que **todas las pantallas y la carrera usan la entrada de la lista**; si no, deja `$1F06` |
| `0F:9242` bucle del menú, Izquierda/Derecha | `LDA $5A; BNE` | `10:8100` | fila 0: alternancia 1P/2P original; fila 3: `$0A == $0100` (solo Derecha) -> `$1F06++` (vuelta en 32), cualquier otra cosa -> `$1F06--` (vuelta por debajo de 0); luego `JML 0F:9268` (redibuja la fila 3) |
| `0F:9258` bucle del menú, otro botón | `LDA $5A; CMP #3` | `10:8600` | solo fila 3: `$0A == $0080` (A) añade `$1F06`, `$0A == $8000` (B) quita la última; actualiza el contador de dos dígitos dibujado en la palabra de VRAM `$02B8` mediante `$11DC/$11DE`; termina en `0F:925D`, cuya cola se cambió a `JML 0F:922F` (se acabó la alternancia mph/km/h) |
| `0F:A01C` final de `draw_string` | `STY $4C; LDA #0` | `10:8200` | cuando la fila 3 dibuja la cadena en `$A70B`: copia el **nombre de la pista** (`0D:C77C[$1F06]`, +4, ASCII - `$40`) al búfer de texto `$11BE` (13 palabras) |
| `0F:A1E4` `pos_to_tilemap_offset` | `CLC; ADC #$0C6C` | `10:8270` | fija la posición de la cadena en `0F:A6D5` (una línea del menú) en el offset de búfer `$05CA` (no investigado más) |
| dato `0F:A70B` | `SPEED KPH` | `^ TRACK _` | etiqueta con los dos glifos de flecha (`5E`, `5F`); `0F:A720` `16 -> 17` baja la barra de PLAY GAME una línea |
| `0F:8F4C` salida del título | `STX $42; SEP #$20` | `10:82A0` | pone a cero `7F:2400-25FF`, rellena `7F:2490..`; `JML 0F:8F50` |
| `0F:9DC5` `fade_out_dma` (15 llamadores) | `SEP #$20; LDA #$20` | `10:8300` | si `7F:2400 != 0`: lo borra, guarda `$1F00/$1F02` en `7F:2404/6`; con `count >= 4` cae en el fade normal (reentra al hook, ya desarmado); con `count < 4` hace `idx := 0` y continúa en `0F:8F50` |
| `0F:84A7` | `BCS $84CB` | `EA EA` | el salto "carrera fallida" tras `qualify_check_1p` nunca se toma |
| `0F:8678` | `LDA $1F10; ASL` | `10:8800` | `SP += 2`, luego las mismas dos instrucciones (ajuste de pila para los desvíos anteriores; finalidad no del todo rastreada) |
| `0F:8733` `advance_track` | `INC $1F04; INC $1F06` | `10:8400` | `idx+1 == count` -> torneo terminado: `idx := 0`, `$1F06 := 0`, `$1F10 := 2`, `JML 0F:84C0` (ese camino devuelve A=3: la escena "completed Top Gear", docs/13). Si no, `INC $1F04`, restaura `$1F00/$1F02` desde `7F:2404/6`, `idx++`, `JML 0F:8739` (se salta el `INC $1F06` original; `$1F06` se fija desde la lista la próxima vez que corre `10:8700`) |
| `0F:8743` | `AND #3` | `LDA #1` | `advance_track` siempre informa "mitad del país" (A=1 -> menú principal / siguiente pantalla de lugar), nunca "país terminado" |
| `0F:8885` suma de puntos | `TYX; TAY; SEP #$20` | `10:9000` | `7F:2500[car] += tabla[puesto]` (16 bits) antes de la suma de byte original |
| `0F:8894` | `REP #$20; TYA; TXY` | `10:9080` | si el byte original es >= 100: resta 100 y `10:94FC` incrementa el tile de centenas de ese coche (`7F:2450`) |
| `0F:8965` ordenación de la clasificación | `TYA; XBA; LDA $1F63,Y` | `10:9200` | compara los totales de 16 bits `7F:2500` en vez de los bytes |
| `0F:9F48` `draw_string` | `LDA #0; SEP #$20` | `10:9100` | cuando la cadena que se dibuja está en una de las 20 direcciones de fila del ranking (`7F:2490`), escribe además el tile de centenas delante del número |
| dato `0F:8B85` | `#$3D` | `#$30` | el dígito de las decenas de una fila del ranking se imprime como `0` en vez del punto de relleno (para que `105` no se lea `.5`) |
| datos `06:E01A..E1F1`, `06:E69C..E873` | | | dos tablas de 472 bytes con registros de 22 bytes (`xx0c 0300 502c 622c 642c yy0c ...`): punteros movidos y dos tiles por registro (`$2C62`, `$2C64`) borrados. No investigado (parecen registros de tilemap/OAM de un gráfico del banco 06) |
| cabecera `00:FFD7..FFDF` | | | campos de tamaño/checksum, ver la tabla del principio |

Los desvíos en 65816 son sencillos; las dos trampas que aparecieron al leerlos: están escritos para **A = 16 bits** en la mayoría de los puntos de entrada (el código original está en `REP #$20` ahí), y `10:8300` se ejecuta en **cada** llamada a `fade_out_dma`, pero solo actúa una vez por carrera armada.

## 4. El flujo, paso a paso

```
salida de la pantalla de título (0F:8F4C) .. 10:82A0 borra 7F:2400-25FF  (count=0, idx=0, totales=0)
menú de opciones: fila TRACK ............... Izq/Der eligen $1F06, A añade, B quita     (count mostrado)
entrada del menú principal (00:818A) ....... 7F:2400 := (idx != count)
PLAY GAME -> fade_out ...................... 10:8300: armado -> desarma, guarda $1F00/$1F02; count<4: idx=0
pantalla de lugar / carrera ................ 10:8700 hace $1F06 = list[idx] (count >= 4)
fin de carrera -> results_flow (0F:83DD) ... RESULTS, luego WORLD RANKING: 7F:2500[car] += puntos[puesto]
qualify_check (0F:84A4) .................... no puede fallar (0F:84A7 con NOP)
advance_track (0F:8733 -> 10:8400) ......... idx+1 == count ? fin : idx++, restaura $1F00/$1F02, A=1
0F:818E menú principal (-> 10:8500) ........ 7F:2400 := 1, la siguiente pantalla de lugar muestra list[idx]; Start/A corre la carrera
final: escena A=3 "completed Top Gear" .... $1F10 := 2, idx := 0, vuelta al título -> todo borrado
```

## 5. Cómo se verificó

`scripts/tgc_flow.lua` navega por los menús reales, monta una lista y fuerza el final de cada carrera exactamente como `scripts/race_end_force.lua` (docs/13), imprimiendo el estado en cada paso.
Ejemplo (`lista = 0, 5, 10, 15`, todas las carreras ganadas):

```
main_menu    1F06=15 flag=0 idx=0 cnt=4 list=0,5,10,15 tot0=0
FORCE        1F06=0  flag=1 idx=0 ...                               carrera 1 en 0 Las Vegas (USA)
draw_points  1F06=0  flag=1 idx=0 ... tot0=20
main_menu    1F06=0  flag=0 idx=1 ... tot0=20                       -> pantalla de lugar de 5 Machu Picchu (Peru)
FORCE        1F06=5  flag=1 idx=1 ...   draw_points tot0=40
FORCE        1F06=10 flag=1 idx=2 ...   draw_points tot0=60        carrera 3 en 10 Yokohama (Japan)
FORCE        1F06=15 flag=1 idx=3 ...   draw_points tot0=80        carrera 4 en 15 Frankfurt (Germany)
WIN_COUNTRY  1F06=0  flag=0 idx=0 1F10=2 -> title_screen -> cnt=0, totales 0
```

* Acabar **10º** en la carrera 1 (`PLACES="9,"`) avanza con normalidad y da 1 punto (`tot0=1`): no hay clasificación.
* `TRACKS=5` (una pista) y `TRACKS=x` (ninguna) vuelven al menú de opciones tras la carrera, `idx` se queda en 0 (comportamiento original).
* Tiempos de las pruebas: splash saltada en el frame 700, Start en el título en 1100..1700, menú de opciones utilizable desde el frame ~2440, cada acción mantenida 20 frames (el juego lee el mando más o menos cada 3 frames e ignora pulsaciones durante los fades).

Reproducir:
```
TG_ROM="$PWD/Top Gear TGC Rom (E) [!].smc" TRACKS="0,5,10,15" RACES=4 MAXF=12500 TAG=tgc tools/mesen.sh scripts/tgc_flow.lua | grep -v Uninit
python3 -I tools/romcmp.py "Top Gear (Europe).sfc" "Top Gear TGC Rom (E) [!].smc"      # los 322 bytes cambiados
python3 -I tools/lindis.py 108100,108140,0,0 108600,1086CA,0,0                          # un hook, pistas de M/X por rango (la variable ROM= elige el archivo)
```

## 6. Pendientes y notas para nuestro trabajo

* **Sin probar:** modo 2 jugadores con lista (`10:8400` hace `INC $1F04`, el `DEC` original más adelante solo compensa si se toma el camino "mitad del país", que ahora es siempre), la demo de atracción en reposo con una lista armada, listas con la misma pista seguida, una lista más larga que la pantalla de ranking de 20 filas (solo muestra los 20 coches, así que no debería haber problema).
* El total de 16 bits manda en la ordenación; el dígito de las centenas es un tile aparte y falla por encima de 999 puntos (32 carreras x 20 = 640 como máximo, inalcanzable).
* El bloque `7F:2400` **no** se inicializa al encender; se borra al salir de la pantalla de título. Un hack que se saltara el título empezaría con basura ahí.
* `10:8300` con `count < 4` continúa en `0F:8F50` tras un fade llamado con `JSR` (queda una dirección de retorno en la pila por cada uso); es inofensivo en la práctica porque el código del menú reinicia la pila, pero por eso ese camino se ve raro.
* Diferencias con nuestro randomizer (docs/09, 10): este hack cambia **cuál de las 32 pistas originales** se corre y cuándo acaba la serie; el randomizer genera pistas nuevas. Ambos usan `$1F06` como único selector de pista y el `advance_track` / flujo de resultados originales, así que podrían combinarse: la parte de serie/puntos (totales `7F:2500`, `10:9000..9200`) es independiente de cómo se producen los datos de la pista. Los dos hacks usan espacio libre distinto (aquí los bancos `10` y `12` de una imagen de 1 MB; la nuestra también es de 1 MB, ver docs/10) y ambos tocan código cerca de `0F:8733` / `00:818A`, así que una fusión exige revisar a mano los hooks que se solapan.
