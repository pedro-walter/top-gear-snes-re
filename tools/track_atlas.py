#!/usr/bin/env python3 -I
"""Render curve/hill profiles of all 16 tracks to out/tracks.png (uses tools/tracks.py loader port)."""
from PIL import Image, ImageDraw
src=open('tools/tracks.py').read().split("if __name__")[0]
exec(src)
IW,H=1400,120
img=Image.new("RGB",(IW,16*(2*H//1)+20),(250,250,250))
dr=ImageDraw.Draw(img)
import sys
sys.path.insert(0,'tools')
from names import label,GROUPS
HALF=int(sys.argv[1]) if len(sys.argv)>1 else 0
for t in range(16*HALF,16*HALF+16):
    d=descriptor(t)
    n=d['nelem']
    cv=[v for e in stream_tab(0x8591,d['curve'],n) for v in e[3]]
    sl=[v for e in stream_tab(0x85D3,d['slope'],n) for v in e[3]]
    y0=(t-16*HALF)*2*H//1+10
    laps=ROM[0x5EA4+2*t]|(ROM[0x5EA5+2*t]<<8)
    dr.text((4,y0),'track %s  -  %s  |  length %d (%d x 1024), %d laps'%(label(t),GROUPS[t>>2],d['length'],n,laps),fill=(0,0,0))
    # curve graph (top), slope graph (bottom)
    for k,(data,scale,col,yo) in enumerate(((cv,40,(200,40,40),y0+38),(sl,1000,(40,40,200),y0+95))):
        dr.line([(0,yo),(IW,yo)],fill=(200,200,200))
        pts=[(i*IW/len(data), yo-(v/scale)*28) for i,v in enumerate(data)]
        dr.line(pts,fill=col)
fn='out/tracks.png' if HALF==0 else 'out/tracks_16_31.png'
img.save(fn)
print('saved',fn)
