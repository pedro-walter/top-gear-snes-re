#!/usr/bin/env python3
"""Labelled contact sheet of out/<tag>_<type>.png: python3 -I tools/sheet_types.py tag out.png [cols] [crop top,bottom]"""
import sys, glob, re
from PIL import Image, ImageDraw
tag, dst = sys.argv[1], sys.argv[2]
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 3
fs = sorted(glob.glob('out/%s_[0-9]*.png' % tag), key=lambda f: int(re.search(r'_(\d+)\.png', f).group(1)))
ims = []
for f in fs:
    im = Image.open(f).convert('RGB')
    w, h = im.size
    pass
    d = ImageDraw.Draw(im); d.rectangle((0, 0, 60, 12), fill=(0, 0, 0))
    d.text((2, 1), 'type ' + re.search(r'_(\d+)\.png', f).group(1), fill=(255, 255, 0))
    ims.append(im)
w, h = ims[0].size
rows = (len(ims) + cols - 1) // cols
sh = Image.new('RGB', (w * cols, h * rows))
for i, im in enumerate(ims): sh.paste(im, ((i % cols) * w, (i // cols) * h))
sh.save(dst); print(dst, sh.size)
