#!/usr/bin/env python3
"""Generates the 4bpp BG1 tiles of the lap counter font (digits 0-9 and '/') as .db lines for src/bar.asm.
5x6 glyphs at (1,1) of the 8x8 tile, colour 1 (white) with a one pixel colour 2 (black) outline: readable over the road and the grass."""
G = {
 '0': ["01110","10001","10001","10001","10001","01110"],
 '1': ["00100","01100","00100","00100","00100","01110"],
 '2': ["01110","10001","00010","00100","01000","11111"],
 '3': ["01110","10001","00110","00001","10001","01110"],
 '4': ["00010","00110","01010","10010","11111","00010"],
 '5': ["11111","10000","11110","00001","10001","01110"],
 '6': ["00110","01000","11110","10001","10001","01110"],
 '7': ["11111","00001","00010","00100","01000","01000"],
 '8': ["01110","10001","01110","10001","10001","01110"],
 '9': ["01110","10001","01111","00001","00010","01100"],
 '/': ["00001","00010","00100","00100","01000","10000"],
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
for k in "0123456789/":
    b = tile(G[k])
    print("    .db " + ",".join("$%02X" % v for v in b[:16]) + "   ; '" + k + "'")
    print("    .db " + ",".join("$%02X" % v for v in b[16:]))
