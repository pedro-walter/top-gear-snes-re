#!/usr/bin/env python3 -I
"""Profile sheet of generated tracks (like track_atlas.py): python3 -I tools/trackgen_atlas.py seed [seed ...] -> out/gen_atlas.png
Curve (red) and slope (blue) per 32 units, pit position marker (green)."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
import trackgen as tg
from tracks import s16
from names import label

def render(seeds, fn='out/gen_atlas.png'):
    IW, H = 1400, 120
    img = Image.new('RGB', (IW, len(seeds) * H + 10), (250, 250, 250))
    dr = ImageDraw.Draw(img)
    for n, s in enumerate(seeds):
        t = tg.generate(s)
        tb = tg.tables(t, 1)
        y0 = n * H + 6
        dr.text((4, y0), 'seed %08X  env %s  length %d x 1024, %d laps, hill %d curvy %d, pit piece %d' % (
            s, label(t['env']), t['L'], t['laps'], t['hill'], t['curvy'], t['pitpiece']), fill=(0, 0, 0))
        for data, scale, col, yo in ((tb['curve'], 40, (200, 40, 40), y0 + 38), (tb['slope'], 1000, (40, 40, 200), y0 + 82)):
            dr.line([(0, yo), (IW, yo)], fill=(200, 200, 200))
            pts = [(i * IW / len(data), yo - (s16(v) / scale) * 22) for i, v in enumerate(data)]
            dr.line(pts, fill=col)
        px = t['pitpiece'] * IW / t['P']
        dr.line([(px, y0 + 14), (px, y0 + 112)], fill=(0, 140, 0), width=2)
    os.makedirs(os.path.dirname(fn), exist_ok=True)
    img.save(fn)
    print('saved', fn)

if __name__ == '__main__':
    seeds = [int(a, 16) for a in sys.argv[1:]] or [0x12345678, 0x6B, 0x1A2B3C4D, 0xDEADBEEF, 0xA6A3A450, 0x0FD630F1]
    render(seeds)
