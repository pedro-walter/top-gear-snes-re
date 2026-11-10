## Pit stops
* Disparador (jugador 1, 05:D75E–D7C0; ordenador/jugador 2 lo reflejan en 05:DFB8–E03A, 05:F0xx): al pasar sobre un objeto lateral de tipo **0x74xx** (entrada del pit; palabra de `$7E6400` & 0xFE00 == 0x7400) en el lado lateral correspondiente,
  y si el estado `$1E86` (P1) / `$1E88` (P2) aún no es negativo, `$1E86 = 0xFFFF` inicia la secuencia del pit. Si el combustible es 0, entonces `$1EB4 |= 1` (P1) / 2 (P2).
* Máquina de estados `00:90CC` (estado = ~`$1E86`; cada paso hace `DEC $1E86`): 0 monta la escena del pit (`$40 = 0xFFFF` = modo pit, `$A8 = 0x280`, marcha 4, velocidad `$1E5A = $1700`, copia de paleta),
  1 espera, 2 `$E1=1`, `$14=0` (entrada ignorada), 3 espera acelerar (`$1F76`) con combustible != 0 -> **se salta el repostaje**, 4 **repostaje**: `fuel += 0x7F` por frame hasta `0xA7FF`
  (unos 340 frames) – pulsar acelerar (con combustible != 0) sale antes, 5 sale conduciendo hasta que `$A8` esté en 0x300..0x37F, 6 restaura, 7+ libera: limpia `$40`, limpia el bit 0x20 de `$1EF5` (sin empuje).
  El coche del ordenador hace lo mismo con `$1E88`/`$1E64` (00:9222..9380); en el modo de 1 jugador (`$1F04 == 0`) no necesita botón y sale solo.
* **El ordenador (IA) decide parar en el pit** (05:F1AF..F1BF y `sub_05F79F`): solo lo considera cuando su combustible `$1E64 < 0x3000` (28 % de un depósito lleno) **y** `sub_05F79F(X=0x3D)` dice que no puede terminar:
  `needed = (track_len/2 * (laps_total - laps_done) - position/2) * X  *2  >=  fuel`. Si es así activa el bit 0 de `$1EF2` y se guía por las tablas estrechas del **corredor de la calle de boxes** `00:E166/E198` (límites
  izquierdo/derecho según la distancia desde `$1EF0`) en lugar del corredor de la carretera, de modo que lo canalizan hacia el objeto de entrada del pit.
  Mientras reposta (05:EDC5, estado `$1E88 == 0xFFFA`) sale en cuanto `sub_05F79F(X=0x50)` dice que el combustible alcanza para terminar la carrera (es decir, *no* siempre llena el depósito).
  En una carrera normal de 3 vueltas en la pista 0 gasta ~22 000 de 43 007 unidades y nunca para.
