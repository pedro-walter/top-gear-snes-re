#!/usr/bin/env python3 -I
"""usage: contact_sheet.py TAG COLS FIRST LAST OUT.png -> grid of out/TAG_<n>.png frames (n in FIRST..LAST), n printed on each"""
import sys,glob
from PIL import Image, ImageDraw
tag=sys.argv[1]; cols=int(sys.argv[2]); a=int(sys.argv[3]); b=int(sys.argv[4]); out=sys.argv[5]
fs=sorted(glob.glob(__import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)),'..','out','%s_*.png'%tag)))
fs=[f for f in fs if a<=int(f[-8:-4])<=b]
ims=[]
for f in fs:
    im=Image.open(f).convert('RGB'); d=ImageDraw.Draw(im); d.text((2,2),f[-8:-4],fill=(255,255,0)); ims.append(im)
w,h=ims[0].size; rows=(len(ims)+cols-1)//cols
sh=Image.new('RGB',(w*cols,h*rows))
for i,im in enumerate(ims): sh.paste(im,((i%cols)*w,(i//cols)*h))
sh.save(out); print(len(ims),sh.size)
