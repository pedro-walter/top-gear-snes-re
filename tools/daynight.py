#!/usr/bin/env python3 -I
"""Sky colour along each track from lap screenshots (out/lap/<t>_<frame>.png, positions in lap_<t>.txt) -> out/daynight.png + out/daynight.csv.
Sample = mean colour of the player-1 view below the HUD (x 8..248, y 30..100); luminance <28 night, <60 dusk, else day."""
import sys,os,statistics
sys.path.insert(0,'tools')
from names import label
from tracks import descriptor
from PIL import Image, ImageDraw
IW=1100;RH=34
img=Image.new('RGB',(IW,32*RH+10),(255,255,255)); dr=ImageDraw.Draw(img)
csv=open('out/daynight.csv','w'); csv.write('track,name,frame,pos,r,g,b,lum,class\n')
def cls(l): return 'night' if l<28 else ('dusk' if l<60 else 'day')
for t in range(32):
    y=t*RH+6; dr.text((2,y),label(t),fill=(0,0,0))
    f='out/lap/lap_%d.txt'%t
    if not os.path.exists(f): continue
    L=descriptor(t)['length']
    samples=[]
    for line in open(f):
        fr,pos=map(int,line.split())
        p='out/lap/%d_%05d.png'%(t,fr)
        if not os.path.exists(p) or fr<3500 and pos>L*0.9: continue
        im=Image.open(p).convert('RGB')
        px=[im.getpixel((x,yy)) for x in range(8,248,4) for yy in range(30,100,4)]
        c=tuple(statistics.mean(v[i] for v in px) for i in range(3))
        lum=0.3*c[0]+0.59*c[1]+0.11*c[2]
        samples.append((pos,c,lum)); csv.write('%d,%s,%d,%d,%d,%d,%d,%.0f,%s\n'%(t,label(t).split(' ',1)[1],fr,pos,*c,lum,cls(lum)))
    samples=[s for s in samples if s[0]<=L]; samples.sort()
    for pos,c,lum in samples:
        x0=200+int(pos*(IW-200)/L)
        dr.rectangle([x0,y,x0+max(2,(IW-200)*150*6//L//1),y+RH-8],fill=tuple(int(v) for v in c))
img.save('out/daynight.png')
