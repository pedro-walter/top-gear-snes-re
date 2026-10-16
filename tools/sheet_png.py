#!/usr/bin/env python3 -I
"""Contact sheet: tools/sheet_png.py OUT.png in1.png in2.png ... [--cols N]"""
import sys
from PIL import Image
a = sys.argv[1:]
cols = 4
fs = a[1:]
ims = [Image.open(f).convert('RGB') for f in fs]
w, h = ims[0].size
rows = (len(ims) + cols - 1) // cols
sh = Image.new('RGB', (w * cols, h * rows))
for i, im in enumerate(ims): sh.paste(im, ((i % cols) * w, (i // cols) * h))
sh.save(a[0])
