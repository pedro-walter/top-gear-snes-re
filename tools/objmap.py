#!/usr/bin/env python3 -I
"""Render roadside objects of all 16 tracks (difficulty 0) to out/objects.png and dump out/objects_all.csv.
Band colour = road type from scenery stream; dot = object (x = position, y = lateral = +-low8*128); red = pit entrance; group words (bit15) in green."""
import sys,colorsys
sys.path.insert(0,'tools')
from names import label
from objects import *
from PIL import Image, ImageDraw
ROM=open(__import__('os').environ.get('TOPGEAR_ROM','Top Gear (USA).sfc'),'rb').read()
def W0(a): o=a&0x7fff; return ROM[o]|(ROM[o+1]<<8)
TYPE=[W0(0x9B3F+2*i)//4 for i in range(512)]
IW=1500;RH=90
img=Image.new('RGB',(IW,32*RH+40),(255,255,255)); dr=ImageDraw.Draw(img)
csv=open('out/objects_all.csv','w'); csv.write('track,pos,word,kind,type,lateral\n')
bandcol=[(225,225,225),(205,225,255),(255,225,205),(225,255,205)]
for t in range(32):
    d=descriptor(t); ow=objects(t,0); L=len(ow)*32
    y0=t*RH+14; yc=y0+RH//2
    dr.text((2,y0-8),label(t),fill=(0,0,0))
    sc=[x for s in scen_words(t) for x in s[3]]
    for i,x in enumerate(sc):
        ty=TYPE[(x&0x7fff)//2] if (x&0x7fff)//2<len(TYPE) else 0
        dr.line([(30+i*(IW-40)/len(sc),yc-RH//2+6),(30+i*(IW-40)/len(sc),yc+RH//2-6)],fill=bandcol[ty&3])
    for i,w in enumerate(ow):
        if not w: continue
        px=30+i*32*(IW-40)/L
        if w&0x8000:
            dr.line([(px,yc-RH//2+6),(px,yc+RH//2-6)],fill=(0,160,0)); csv.write('%d,%d,0x%04X,group,%d,\n'%(t,i*32,w,(w&0x3FFE)>>1)); continue
        ty=(w>>9)&0x3F; lat=(w&0xFF)*(-1 if w&0x100 else 1)
        csv.write('%d,%d,0x%04X,obj,%d,%d\n'%(t,i*32,w,ty,lat*128))
        if ty==0x3A: dr.ellipse([px-4,yc+lat/255*(RH//2-8)-4,px+4,yc+lat/255*(RH//2-8)+4],fill=(255,0,0))
        else:
            r,g,b=colorsys.hsv_to_rgb((ty*0.137)%1,0.8,0.8)
            dr.point((px,yc+lat/255*(RH//2-8)),fill=(int(r*255),int(g*255),int(b*255)))
img.save('out/objects.png')
