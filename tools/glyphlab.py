#!/usr/bin/env python3
"""Scratch lab: compose the missing big-font digits from rows/columns of the existing glyphs (VRAM dump of the keypad screen)."""
import sys
from PIL import Image
v = open('out/vram_keypad.bin', 'rb').read()
cg = open('out/cgram_keypad.bin', 'rb').read()
PAL = []
for i in range(256):
    c = cg[2*i] | cg[2*i+1] << 8
    PAL.append(((c & 31) * 8, ((c >> 5) & 31) * 8, ((c >> 10) & 31) * 8))
def tile4(off):
    px = [[0]*8 for _ in range(8)]
    for y in range(8):
        b0, b1 = v[off+2*y], v[off+2*y+1]; b2, b3 = v[off+16+2*y], v[off+16+2*y+1]
        for x in range(8):
            s = 7 - x
            px[y][x] = ((b0 >> s) & 1) | (((b1 >> s) & 1) << 1) | (((b2 >> s) & 1) << 2) | (((b3 >> s) & 1) << 3)
    return px
def glyph(g):
    r, c = g // 8, g % 8
    base = 128 + r * 32 + c * 2
    out = [[0]*16 for _ in range(16)]
    for dy in range(2):
        for dx in range(2):
            t = tile4(0x2000 + 32 * (base + dy * 16 + dx))
            for y in range(8):
                for x in range(8): out[dy*8+y][dx*8+x] = t[y][x]
    return out
def compose(spec):
    out = [[0]*16 for _ in range(16)]
    for (y0, y1, slot, x0, x1) in spec:
        s = glyph(slot)
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                out[y][x] = s[y][x]
    return out
def render(glyphs, name, pal=128, scale=6):
    im = Image.new('RGB', (len(glyphs) * 20, 18), (0, 0, 40))
    for k, g in enumerate(glyphs):
        for y in range(16):
            for x in range(16):
                if g[y][x]: im.putpixel((k*20 + 2 + x, 1 + y), PAL[pal + g[y][x]])
    im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    im.save(name)
def text(g):
    H = '0123456789ABCDEF'
    return '\n'.join(''.join(H[p] if p else '.' for p in r) for r in g)
