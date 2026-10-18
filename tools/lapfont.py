#!/usr/bin/env python3
"""Generates the 4bpp BG1 tiles L, P and '/' of the lap counter as .db lines for src/bar.asm.  The digits and the A of the counter are the HUD font's
own tiles ($35..$3E and $4B, the timer's); that font has no L, P or slash, so these are drawn like its R (palette 3 of BG1: a = $A light edge on the top / left,
c = $C fill, b = $B dark edge on the bottom / right)."""
G = {
 'L': ["00000000",
       "aaa00000",
       "accb0000",
       "accb0000",
       "accb0000",
       "acccccb0",
       "acccccbb",
       "0bbbbbb0"],
 'P': ["00000000",
       "aaaaa000",
       "acccccb0",
       "accbbccb",
       "acccccbb",
       "accbbbb0",
       "accb0000",
       "00bb0000"],
 '/': ["00000000",
       "000aaa00",
       "000accb0",
       "00accb00",
       "00accb00",
       "0accb000",
       "0accb000",
       "00bb0000"],
}
def tile(g):
    out = [0]*32
    for y, row in enumerate(g):
        for x, ch in enumerate(row):
            c = int(ch, 16)
            for pl in range(4):
                if (c >> pl) & 1:
                    out[(pl // 2) * 16 + 2 * y + (pl % 2)] |= 0x80 >> x
    return out
for k in "LP/":
    b = tile(G[k])
    print("    .db " + ",".join("$%02X" % v for v in b[:16]) + "   ; '" + k + "'")
    print("    .db " + ",".join("$%02X" % v for v in b[16:]))
