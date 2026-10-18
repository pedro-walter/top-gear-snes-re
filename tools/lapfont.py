#!/usr/bin/env python3
"""Generates the 4bpp BG1 tiles L, P and '/' of the lap counter as .db lines for src/bar.asm (the digits and the A are the HUD font's own
tiles $35..$3E and $4B, the timer's; the HUD font has no L, P or slash).
6x6 glyphs (2 pixel strokes, like the timer font) at (1,1) of the 8x8 tile, colour 1 (white) with a one pixel colour 2 (black) outline: readable over the road and the grass."""
G = {
 'L': ["110000","110000","110000","110000","111111","111111"],
 'P': ["111110","111111","110011","111110","110000","110000"],
 '/': ["000011","000111","001110","001110","011100","111000"],
}
def tile(g):
    px = [[0]*8 for _ in range(8)]
    for y, row in enumerate(g):
        for x, c in enumerate(row):
            if c == '1': px[y+1][x+1] = 1
    for y in range(8):
        for x in range(8):
            if px[y][x] == 0 and any(px[y+dy][x+dx] == 1 for dy in (-1,0,1) for dx in (-1,0,1)
                                      if 0 <= y+dy < 8 and 0 <= x+dx < 8):
                px[y][x] = 2
    out = []
    for y in range(8):
        p0 = sum(((px[y][x] & 1) << (7-x)) for x in range(8))
        p1 = sum((((px[y][x] >> 1) & 1) << (7-x)) for x in range(8))
        out += [p0, p1]
    return out + [0]*16
for k in "LP/":
    b = tile(G[k])
    print("    .db " + ",".join("$%02X" % v for v in b[:16]) + "   ; '" + k + "'")
    print("    .db " + ",".join("$%02X" % v for v in b[16:]))
