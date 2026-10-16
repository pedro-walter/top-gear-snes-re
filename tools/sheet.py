#!/usr/bin/env python3 -I
"""usage: sheet.py track -> out/drvsheet_<track>.png (top half of each drive screenshot with its position)"""
import sys,glob
from PIL import Image, ImageDraw
t=sys.argv[1]
log=[l.split() for l in open('out/drv_%s.txt'%t)]
ims=[]
for f,pos,sky in log:
    im=Image.open('out/drv_%s_%05d.png'%(t,int(f))).crop((0,0,256,112)).copy()
    ImageDraw.Draw(im).text((90,98),'pos %s'%pos,fill=(255,255,0)); ims.append(im)
cols=5; rows=(len(ims)+cols-1)//cols
sh=Image.new('RGB',(256*cols,112*rows))
for i,im in enumerate(ims): sh.paste(im,((i%cols)*256,(i//cols)*112))
sh.save('out/drvsheet_%s.png'%t)
