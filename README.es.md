# Top Gear (USA, SNES) – ingeniería inversa

[English](README.md) · [Português (BR)](README.pt-br.md) · **Español**

Notas, herramientas y scripts de emulador que documentan cómo funciona el juego de SNES *Top Gear (USA)*:
física del coche y nitro, IA de los oponentes, pit stops, posición en la carrera, las 32 pistas (streams de carretera/escenario/objetos),
contraseñas, minimapas y día/noche. Todo se derivó del código ensamblador del juego y de la inspección en tiempo de ejecución en el
emulador Mesen2.

**Este repositorio no contiene datos del juego.** Necesitas tu propia ROM obtenida legalmente
(`Top Gear (USA).sfc`, 512 KB, LoROM, sin cabecera). Colócala en la raíz del repositorio, o apunta `TOPGEAR_ROM` hacia ella.

## Randomizer (BETA 0.5, parche en `release/`)
`python3 -I tools/build_rando.py` convierte tu ROM en `out/rando.sfc` (1 MB): cada carrera es una **pista aleatoria generada en la
consola a partir de una semilla de 8 dígitos hex** (3-8 vueltas, siempre con pit stop, uno de los 32 entornos originales). El menú principal tiene `1 PLAYER`, `DIFFICULTY`,
`<n> TRACKS` (Left/Right: 1..99 o infinito), `SEED xxxxxxxx` (A = teclado hex, Left/Right = nueva semilla aleatoria; solo con `1 TRACK`), `SPEED KPH/MPH` y `PLAY GAME`.
Una pista: la pantalla de resultados vuelve al menú y la semilla se conserva para repetir la pista. Más pistas (o infinito): una pista aleatoria nueva tras cada carrera,
los puntos de campeonato de todos los pilotos se suman, y una escena de podio cierra una serie finita. `python3 -I tools/make_ips.py` genera un parche IPS (solo nuestros bytes).
Resumen de funciones y correcciones: [docs/es/17](docs/es/17-resumen-del-randomizer.md). Detalles y pruebas: docs/09, docs/10.

## Pistas (32 = 8 países × 4)
EE. UU.: 0 Las Vegas, 1 Los Angeles, 2 New York, 3 San Francisco · Sudamérica: 4 Rio, 5 Machu Picchu,
6 Chichen Itza, 7 Rain Forest · Japón: 8 Tokyo, 9 Hiroshima, 10 Yokohama, 11 Kyoto ·
Alemania: 12 Munich, 13 Cologne, 14 Black Forest, 15 Frankfurt · Escandinavia: 16 Stockholm,
17 Copenhagen, 18 Helsinki, 19 Oslo · Francia: 20 Paris, 21 Nice, 22 Bordeaux, 23 Monaco ·
Italia: 24 Pisa, 25 Rome, 26 Sicily, 27 Florence · Reino Unido: 28 London, 29 Sheffield, 30 Loch Ness, 31 Stonehenge

## Documentación (`docs/es/`, también en inglés: [`docs/en/`](docs/en/) y portugués: [`docs/pt-br/`](docs/pt-br/))
1. [Visión general, herramientas, arranque, vídeo](docs/es/01-vision-general.md)
2. [Física del coche, marchas, nitro, el truco de la 3ª marcha](docs/es/02-fisica-del-coche-nitro.md)
3. [Lista de coches de la carrera, bots/IA, velocidad en el HUD, posición](docs/es/03-coches-ia-hud-posicion.md)
4. [Pit stops](docs/es/04-pit-stops.md)
5. [Datos de las pistas, streams de escenario y objetos, tablas por pista](docs/es/05-pistas-escenario-objetos.md)
6. [Nombres de las pistas, contraseñas, minimapas, día/noche](docs/es/06-nombres-minimapa-dia-noche.md)
7. [Pendientes y correcciones](docs/es/07-pendientes-y-correcciones.md)
8. [Truco acelerador + freno en las curvas (solo P1)](docs/es/08-truco-acelerador-freno-curvas.md)
9. [Plan y decisiones del randomizer](docs/es/09-plan-del-randomizer.md)
10. [Estado de la implementación del randomizer, mapa de memoria, pruebas](docs/es/10-implementacion-del-randomizer.md)
11. [Globos de diálogo y mensajes](docs/es/11-globos-de-dialogo-mensajes.md)
12. [Cambios de marcha ideales](docs/es/12-cambios-de-marcha-ideales.md)
13. [Resultados de la carrera, puntos del campeonato, clasificación / game over, escena del podio](docs/es/13-resultados-clasificacion-podio.md)
14. [Qué difiere entre los cuatro coches](docs/es/14-diferencias-entre-coches.md)
15. [USA vs Europa vs Japón: las tres versiones](docs/es/15-versiones-de-la-rom.md)
16. [Ahorrar combustible: qué funciona y qué no](docs/es/16-ahorro-de-combustible.md)
17. [Resumen del randomizer: funciones y corrección de bugs](docs/es/17-resumen-del-randomizer.md)

## Herramientas (`tools/`, Python 3, ejecuta desde la raíz del repositorio con `python3 -I`)
| herramienta | finalidad |
|---|---|
| `disasm.py` | desensamblador 65816 con seguimiento de M/X y semillas de traza (`make disasm`) |
| `tracks.py`, `objects.py` | decodifican datos de pendiente/curva, escenario y streams de objetos |
| `track_atlas.py`, `objmap.py`, `minimaps.py`, `minimap_path.py`, `daynight.py` | renderizan mapas/minimapas de las pistas (necesitan Pillow) |
| `physics.py` | modelo exacto de la física de velocidad/marcha/nitro |
| `names.py` | nombres de pistas y países |
| `asm65816.py`, `build_rando.py`, `trackgen.py`, `make_ips.py`, `rando_test.py` | randomizer: ensamblador, constructor de la ROM, generador de referencia en Python, exportación IPS, prueba del generador contra el código de la consola (Mesen headless) |

## Retomar el trabajo: el desensamblado anotado
`make disasm` genera `disasm/top_gear.asm` (necesita tu ROM, `out/trace_main.txt` y `out/wram_3300.bin`, producidos por
`tools/mesen.sh scripts/trace.lua` y `scripts/dumpram.lua`). Está **generado y no se sube al repositorio** (contiene
el código del juego). Todo el conocimiento escrito a mano vive en `disasm/annot/`:

| archivo | contenido |
|---|---|
| `symbols.txt` | nombres de rutinas y bloques de documentación (`@BBAAAA name`, `;; text`) - se muestran como cabeceras con llamadores y listas de lectura/escritura/llamada |
| `ram.txt` | nombres y significados de variables de la WRAM/direct page (se muestran en cada operando) |
| `hwregs.txt` | registros de PPU/CPU/DMA; los valores inmediatos escritos en registros clave se decodifican |
| `comments.txt` | comentarios por dirección (`BBAAAA text`) |
| `regions.txt` | regiones de datos tipadas (tablas) y descripciones de bancos |

Las rutinas marcadas `(not yet analysed)` en la salida aún hay que leerlas; añade su nombre/documentación en `symbols.txt`
y vuelve a ejecutar `make disasm`. `disasm/names.txt` es la lista de etiquetas más antigua (aún se respeta).
Flujo principal del juego: `reset_vec` -> `main_restart` -> `load_track` -> `race_loop`; los menús son `menu_entry` (0F:806D) llamado
con JSL desde el banco 00; el renderizador por frame corre dentro del IRQ (`irq_handler_race` -> `vblank_main_work`).

## Scripts de emulador (`scripts/`)
Scripts Lua para [Mesen2](https://github.com/SourMesen/Mesen2/releases) (probado con 2.1.1) ejecutados headless con
`tools/mesen.sh scripts/<nombre>.lua`. Instala antes Mesen2 en `tools/mesen/`. El lanzador usa un
`HOME` aislado (`tools/mesen-home`) para no tocar tu configuración de Mesen; los scripts necesitan
`AllowIoOsAccess` activado en su `settings.json` (el lanzador lo modifica si el archivo existe – ejecútalo una vez,
y luego otra vez). En algunas configuraciones Linux hace falta un `LD_PRELOAD` de la libstdc++ del sistema (ya incluido en el lanzador).

## Preguntas abiertas
Formato de frame/DMA de sprites, umbrales de impacto de objetos,
el papel de los bloques de escenario dentro de un tipo de carretera. Ver docs/07.

## Licencia
MIT (código y docs), ver `LICENSE`.
