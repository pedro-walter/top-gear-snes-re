#!/usr/bin/env python3 -I
"""Sky/backdrop colour along each track ($7E3E00, one BGR555 word per 256 units, dumped from the emulator) -> out/sky.png"""
import sys,os
sys.path.insert(0,'tools')
from names import label
from tracks import descriptor
from PIL import Image, ImageDraw
IW=1200;RH=34
img=Image.new('RGB',(IW,32*RH+10),(255,255,255)); dr=ImageDraw.Draw(img)
def rgb(w): return ((w&31)*255//31,((w>>5)&31)*255//31,((w>>10)&31)*255//31)
for t in range(32):
    f='out/sky_%d.bin'%t
    y=t*RH+6
    dr.text((2,y),label(t),fill=(0,0,0))
    if not os.path.exists(f): continue
    d=open(f,'rb').read()
    n=(descriptor(t)['nelem']+1)*4
    ws=[d[2*i]|(d[2*i+1]<<8) for i in range(n)]
    for x in range(IW-200):
        i=min(n-1,x*n//(IW-200))
        dr.line([(200+x,y),(200+x,y+RH-8)],fill=rgb(ws[i]))
img.save('out/sky.png')
