#!/usr/bin/env python3
"""Big gold hex font for the seed keypad, drawn here (no game graphics are copied any more).

16 glyphs of 16x16 pixels, 4 bpp, in the sprite layout of the game's own menu font (tile pairs side by side, the lower half 16 tiles
further on) so a glyph can be drawn with the same 2x2 'quad' of tile numbers.  They are uploaded to VRAM tiles 256..319 (word $2000)
when the keypad opens.  The look copies the menu font's style: squared strokes, a light-to-dark gold gradient from top to bottom
(palette indices $F..$8), a bright edge on the top / left of every stroke and a dark ($2) shadow on the right / bottom.
Strokes come from seven segments (a..g) with the outer corners chamfered; 1 and the lowercase b / d are special.
Also provides the key table of src/keypad.asm.  `python3 tools/bigfont.py png out.png` renders a preview sheet.
"""
import sys

W = H = 16
X0, X1 = 1, 12            # glyph box (columns), 12 wide
Y0, Y1 = 1, 13            # rows, 13 tall
T = 3                     # stroke thickness
MID = 6                   # top row of the middle bar

def seg_rects():
    a = (X0, Y0, X1, Y0 + T - 1)
    g = (X0, MID, X1, MID + T - 1)
    d = (X0, Y1 - T + 1, X1, Y1)
    f = (X0, Y0, X0 + T - 1, MID + T - 1)
    b = (X1 - T + 1, Y0, X1, MID + T - 1)
    e = (X0, MID, X0 + T - 1, Y1)
    c = (X1 - T + 1, MID, X1, Y1)
    return dict(a=a, b=b, c=c, d=d, e=e, f=f, g=g)

SEGS = {'0': 'abcdef', '2': 'abged', '3': 'abgcd', '4': 'fgbc', '5': 'afgcd', '6': 'afgedc', '7': 'abc', '8': 'abcdefg',
        '9': 'abcdfg', 'A': 'abcefg', 'b': 'fgedc', 'C': 'afed', 'd': 'bcdeg', 'E': 'afged', 'F': 'afge'}
ORDER = '0123456789AbCdEF'

def mask(ch):
    m = [[0] * W for _ in range(H)]
    if ch == '1':
        for y in range(Y0, Y1 + 1):
            for x in range(6, 9): m[y][x] = 1                 # stem
        for x in range(3, 6):                                  # flag
            for y in range(Y0 + 2 + (5 - x), Y0 + 5 + (5 - x)):
                if y >= Y0: m[y][x] = 1
        for y in range(Y1 - 2, Y1 + 1):
            for x in range(3, 12): m[y][x] = 1                 # foot
        return m
    R = seg_rects()
    for s in SEGS[ch]:
        x0, y0, x1, y1 = R[s]
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1): m[y][x] = 1
    # chamfer the outer corners of the box, only where a stroke meets there
    for (x, y) in ((X0, Y0), (X1, Y0), (X0, Y1), (X1, Y1)):
        m[y][x] = 0
    if ch == '4':                                              # the 4's left arm ends at the bar, bottom corner stays clean
        pass
    return m

GRAD = [0xF, 0xE, 0xE, 0xD, 0xD, 0xC, 0xC, 0xB, 0xB, 0xA, 0xA, 0x9, 0x9, 0x8, 0x8, 0x8]

INF_ROWS = ['..XXXX....XXXX..',
            '.XXXXXX..XXXXXX.',
            '.XX..XXXXXX..XX.',
            'XX....XXXX....XX',
            'XX.....XX.....XX',
            'XX....XXXX....XX',
            '.XX..XXXXXX..XX.',
            '.XXXXXX..XXXXXX.',
            '..XXXX....XXXX..']

def inf_mask():
    m = [[0] * W for _ in range(H)]
    for j, row in enumerate(INF_ROWS):
        for x, c in enumerate(row): m[3 + j][x] = 1 if c == 'X' else 0
    return m

def pixels(ch):
    if ch in BMP_GLYPHS: return bmp_pixels(ch)
    if ch in ('inf_l', 'inf_r'): return bmp_pixels('infinity_left' if ch == 'inf_l' else 'infinity_right')
    return pixels_of(inf_mask() if ch == 'inf' else mask(ch))

def pixels_of(m):
    px = [[0] * W for _ in range(H)]
    def at(x, y): return m[y][x] if 0 <= x < W and 0 <= y < H else 0
    for y in range(H):
        for x in range(W):
            if m[y][x]:
                top = not at(x, y - 1)
                left = not at(x - 1, y)
                px[y][x] = 0xF if (top or left) else GRAD[y]
            else:
                if at(x - 1, y) or at(x, y - 1) or at(x - 1, y - 1):
                    px[y][x] = 2
    return px

def bmp_pixels(name):
    """16x16 colour indexes of font/original/<name>.bmp (indexed BMP, index 0 = transparent, 1..15 = the gold font's colours)."""
    import os, struct
    d = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'font', 'original', name + '.bmp'), 'rb').read()
    off, = struct.unpack_from('<I', d, 10)
    w, h = struct.unpack_from('<ii', d, 18)
    bpp, = struct.unpack_from('<H', d, 28)
    assert (w, abs(h), bpp) == (16, 16, 8), name
    rows = [[d[off + y * 16 + x] for x in range(16)] for y in range(16)]     # 16 bytes per row, no padding
    return rows[::-1] if h > 0 else rows

BMP_GLYPHS = set('0123456789ACEF')       # drawn by us in font/original; b and d stay generated (no lowercase in the game's font)

def tile_bytes(px, tx, ty):
    out = bytearray()
    planes = [bytearray(), bytearray(), bytearray(), bytearray()]
    for y in range(8):
        v = [0, 0, 0, 0]
        for x in range(8):
            c = px[ty * 8 + y][tx * 8 + x]
            for p in range(4): v[p] |= ((c >> p) & 1) << (7 - x)
        for p in range(4): planes[p].append(v[p])
    for y in range(8): out += bytes((planes[0][y], planes[1][y]))
    for y in range(8): out += bytes((planes[2][y], planes[3][y]))
    return bytes(out)

def gfx():
    """3072 bytes = VRAM tiles 256..351: glyph j at tile (j>>3)*32 + (j&7)*2, its lower half 16 tiles on.  Slots 0..15 = hex digits,
    16 / 17 = left / right half of the infinity sign (main menu)."""
    tiles = [bytes(32)] * 96
    for j, ch in enumerate(list(ORDER) + ['inf_l', 'inf_r']):
        px = pixels(ch)
        base = (j >> 3) * 32 + (j & 7) * 2
        for ty in range(2):
            for tx in range(2):
                tiles[base + ty * 16 + tx] = tile_bytes(px, tx, ty)
    return b''.join(tiles)

def tile(slot): return 128 + (slot >> 3) * 32 + (slot & 7) * 2     # the game's own glyph slots (A=1..Z=26, arrows 30/31)
INF_L, INF_R = 16, 17                                           # glyph slots of the infinity halves
def new_tile(v): return 256 + (v >> 3) * 32 + (v & 7) * 2
KEYS = [new_tile(v) for v in range(16)] + [tile(30)]            # hex value 0..15, then the left arrow (delete)
END_TILES = [tile(5), tile(14), tile(4)]                        # E N D (game font)
COL0, ROW0, PITCH_X, PITCH_Y = 6, 11, 3, 4    # key grid: 6 columns x 3 rows of 16x16 glyphs (tile units)

def asm():
    out = ['kp_gfx:                         ; 3072 bytes: VRAM tiles 256..351 (hex digits, infinity halves) (see tools/bigfont.py)']
    g = gfx()
    for i in range(0, len(g), 32):
        out.append('    .db ' + ','.join('$%02X' % b for b in g[i:i + 32]))
    out.append('kp_keys:                        ; glyph tile of every key (hex value 0..15, 16 = delete arrow)')
    out.append('    .dw ' + ','.join(str(t) for t in KEYS))
    out.append('kp_end_tiles:')
    out.append('    .dw ' + ','.join(str(t) for t in END_TILES))
    out.append('kp_cells:                       ; per cell 0..17: buffer offset (bytes from $0C6C) of the glyph, bar position ($48), bar length ($4A)')
    for c in range(18):
        col, row = c % 6, c // 6
        gc, gr = COL0 + PITCH_X * col, ROW0 + PITCH_Y * row
        out.append('    .dw %d,$%04X,%d' % (gr * 64 + gc * 2, (gr << 8) | (gc - 1), 3 if c == 17 else 2))
    return '\n'.join(out) + '\n'

def preview(path, scale=4):
    from PIL import Image
    pal = {0: (30, 30, 60), 2: (60, 40, 0)}
    for i in range(8, 16):
        t = (i - 8) / 7
        pal[i] = (int(120 + 135 * t), int(80 + 150 * t), int(10 + 60 * t))
    im = Image.new('RGB', (17 * 16 * scale, 16 * scale))
    for j, ch in enumerate(list(ORDER) + ['inf']):
        px = pixels(ch)
        for y in range(16):
            for x in range(16):
                for sy in range(scale):
                    for sx in range(scale): im.putpixel((j * 16 * scale + x * scale + sx, y * scale + sy), pal[px[y][x]])
    im.save(path)

if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[1] == 'png': preview(sys.argv[2])
    else: print(asm())
