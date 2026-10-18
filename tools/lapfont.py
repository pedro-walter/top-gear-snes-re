#!/usr/bin/env python3
"""Generates the 4bpp BG1 tiles of the lap counter font (digits 0-9, '/', L, A, P) as .db lines for src/bar.asm.
They are the glyphs of the game's small font (splash screens, seed in the main menu); the shadow (colour 6) becomes colour 2 (black) of BG1
palette 3, the fill (colour 1) stays white."""
TILES = {   # the game's small font (VRAM word $1000 + 16 * tile, 4bpp: 1 = white, 6 = shadow), as drawn on the splash screens
 '0': '3c0266194631c621c621cc237886003c02001900310021002100230086003c00',
 '1': '180438041804300c30086018601000700400040004000c000800180010007000',
 '2': '3c02661966110c733806700cfc0200fe020019001100730006000c000200fe00',
 '3': '3c02661906711c030c12cc027886007c02001900710003001200020086007c00',
 '4': '1e0136096413cc32fe0118e71804001c01000900130032000100e70004001c00',
 '5': '3e01300f70087c020679ce017c83007e01000f00080002007900010083007e00',
 '6': '1c023609601f7c02e619ce317c83007e020009001f0002001900310083007e00',
 '7': '7c020c721806300c7008e018e01000f00200720006000c00080018001000f000',
 '8': '1c02360966197e01ec13cc227886007c02000900190001003300220086007c00',
 '9': '3c02661966113e410c33cc027886007c02001900110041003300020086007c00',
 '/': '3e0166190c731806300c6619fc0300fe01001900730006000c0019000300fe00',
 'L': '3008300860186010c030c621fc0300fe0800080018001000300021000300fe00',
 'A': '1c023e01360966197e01c639c62100e70200010009001900010039002100e700',
 'P': '3c02360966196611fc03c03ec02000e0020009001900110003003e002000e000',
}

# the game's font has no real slash (its '/' tile is a Z-like glyph): drawn in the same style, '#' = white, '.' = shadow
SLASH = ["     ##.", "    ##..", "    ##. ", "   ##.. ", "   ##.  ", "  ##..  ", "  ##.   ", "  ...   "]

def slash():
    out = []
    for r in SLASH:
        out += [sum(0x80 >> x for x, c in enumerate(r) if c == '#'), sum(0x80 >> x for x, c in enumerate(r) if c == '.')]
    return out + [0]*16

def tile(h):
    b = bytes.fromhex(h)
    p0 = b[0:16:2]; p1 = b[1:16:2]; p2 = b[16:32:2]; p3 = b[17:32:2]
    out = []
    for y in range(8):
        w = f = 0
        for x in range(8):
            c = ((p0[y] >> (7-x)) & 1) | (((p1[y] >> (7-x)) & 1) << 1) | (((p2[y] >> (7-x)) & 1) << 2) | (((p3[y] >> (7-x)) & 1) << 3)
            if c == 1: w |= 0x80 >> x
            elif c: f |= 0x80 >> x
        out += [w, f]
    return out + [0]*16
for k in "0123456789/LAP":
    b = slash() if k == '/' else tile(TILES[k])
    print("    .db " + ",".join("$%02X" % v for v in b[:16]) + "   ; '" + k + "'")
    print("    .db " + ",".join("$%02X" % v for v in b[16:]))
