#!/usr/bin/env python3
"""Big gold font: digits that the game does not have, composed on the console from rectangles of the existing letter tiles.

The menu font (VRAM tiles 128..255, 16x16 glyphs = 4 tiles in sprite layout) has no 0,3..9.  Zero, five and eight are the squared
letters O, S and B; the other glyphs are cut out of letters (no game graphics are stored in this repo or the patch recipe - only
rectangles).  A recipe entry is (y0, y1, slot, x0, x1): copy rows y0..y1 / columns x0..x1 of font glyph `slot` (A=1 .. Z=26, '1'=28,
'2'=29, left arrow=30; slot 0 is blank).  Later entries overwrite earlier ones.  Output: assembler text for src/keypad.asm.
"""
B, H, O, S, T, C = 2, 8, 15, 19, 20, 3
FULL = lambda s: (0, 15, s, 0, 15)
GLYPHS = [                                    # order = index j of the new glyphs (tiles 256 + 2j)
    ('3', [FULL(B), (3, 4, 0, 0, 4), (8, 9, S, 0, 5)]),
    ('4', [(0, 10, H, 0, 15), (11, 15, H, 9, 15)]),
    ('6', [FULL(B), (2, 4, 0, 6, 15)]),
    ('7', [(0, 1, O, 0, 15), (2, 5, T, 0, 3), (2, 5, S, 4, 8), (2, 15, H, 9, 15)]),
    ('9', [FULL(B), (8, 9, S, 0, 5)]),
    ('b', [(0, 4, H, 0, 5), (5, 15, B, 0, 15), (3, 4, B, 0, 5)]),   # hex digit 11: lowercase b (a full B would read as 8)
]
def tile(slot): return 128 + (slot >> 3) * 32 + (slot & 7) * 2
# tile (top-left of the 16x16 glyph) of every key, hex value 0..15, then the left arrow (delete)
NEW = {k: 256 + 2 * i for i, (k, _) in enumerate(GLYPHS)}
KEYS = [tile(O), tile(28), tile(29), NEW['3'], NEW['4'], tile(S), NEW['6'], NEW['7'], tile(B), NEW['9'], tile(1), NEW['b'],
        tile(C), tile(4), tile(5), tile(6), tile(30)]
END_TILES = [tile(5), tile(14), tile(4)]      # E N D
COL0, ROW0, PITCH_X, PITCH_Y = 6, 11, 3, 4    # key grid: 6 columns x 3 rows of 16x16 glyphs (tile units)

def asm():
    out = ['kp_recipe:']
    for k, spec in GLYPHS:
        out.append('    .db ' + ','.join('%d,%d,%d,%d,%d' % e for e in spec) + ',$FF    ; "%s"' % k)
    out.append('kp_keys:                        ; glyph tile of every key (hex value 0..15, 16 = delete arrow)')
    out.append('    .dw ' + ','.join(str(t) for t in KEYS))
    out.append('kp_end_tiles:')
    out.append('    .dw ' + ','.join(str(t) for t in END_TILES))
    out.append('kp_cells:                       ; per cell 0..17: buffer offset (bytes from $0C6C) of the glyph, bar position ($48), bar length ($4A)')
    cells = []
    for c in range(18):
        col, row = c % 6, c // 6
        gc, gr = COL0 + PITCH_X * col, ROW0 + PITCH_Y * row
        cells.append((gr * 64 + gc * 2, (gr << 8) | (gc - 1), 3 if c == 17 else 2))
    for off, pos, ln in cells:
        out.append('    .dw %d,$%04X,%d' % (off, pos, ln))
    out.append('kp_shr:                         ; $FF >> n')
    out.append('    .db $FF,$7F,$3F,$1F,$0F,$07,$03,$01,$00')
    return '\n'.join(out) + '\n'

if __name__ == '__main__':
    print(asm())
