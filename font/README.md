# Big menu font glyphs

16x16 indexed (8 bit) BMPs. Palette index 0 = transparent (magenta in the editor), indexes 1..15 = the game's gold font colours
(index 15 = top of the gradient, 8 = bottom, 2 = shadow). Edit with any pixel editor that keeps the palette (e.g. GIMP indexed mode, Aseprite, GrafX2).

* `original/` - the game's own glyphs: A-Z, `1`, `2`, arrows. No 0 (the O is used), no 3-9 (5 = S, 8 = B).
* `current/` - the hex digits `tools/bigfont.py` draws today (0-9, A, b, C, d, E, F).
* `new/` - blank 16x16 canvases for `0`, `3`-`9` and `!` to draw into (same palette).
