#!/usr/bin/env python3
"""Contact sheet of out/<tag>_NN.png (NN=1..n), 4 columns: python3 -I tools/sheet_grid.py tag n [crop]"""
import sys
from PIL import Image
tag, n = sys.argv[1], int(sys.argv[2])
ims = [Image.open('out/%s_%02d.png' % (tag, i)) for i in range(1, n + 1)]
w, h = ims[0].size
cols = 4
sh = Image.new('RGB', (w * cols, h * ((n + cols - 1) // cols)))
for i, im in enumerate(ims):
    sh.paste(im, ((i % cols) * w, (i // cols) * h))
sh.save('out/%s_sheet.png' % tag)
