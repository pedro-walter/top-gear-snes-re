#!/usr/bin/env python3 -I
"""Overlay the marker path ($7E3E00, (x,y) per 256 track units, dumped as out/sky_<t>.bin) on the pre-drawn map bitmap. usage: minimap_path.py [dx dy]"""
import sys,os
sys.path.insert(0,'tools')
from names import label
from tracks import descriptor
from PIL import Image, ImageDraw
exec(open('tools/minimaps.py').read().split("bufs=")[0])   # reuse pal, tile_img
bufs=[open('out/mapgfx_0.bin','rb').read(),open('out/mapgfx_16.bin','rb').read()]
DX=int(sys.argv[1]) if len(sys.argv)>1 else 8; DY=int(sys.argv[2]) if len(sys.argv)>2 else 8
S=3;cols=8
sheet=Image.new('RGB',(cols*(64*S+8),4*(64*S+34)),(30,30,40)); dr=ImageDraw.Draw(sheet)
for t in range(32):
    im=tile_img(bufs[t>>4],(t&15)*1024).resize((64*S,64*S),Image.NEAREST)
    x0=(t%cols)*(64*S+8)+4; y0=(t//cols)*(64*S+34)+4
    d=ImageDraw.Draw(im)
    f='out/sky_%d.bin'%t
    if os.path.exists(f):
        b=open(f,'rb').read(); n=descriptor(t)['nelem']*4
        pts=[((b[2*i]-DX+4)*S,(b[2*i+1]-DY+4)*S) for i in range(n)]
        d.line(pts+[pts[0]],fill=(255,60,60),width=1)
        d.ellipse([pts[0][0]-4,pts[0][1]-4,pts[0][0]+4,pts[0][1]+4],outline=(60,255,60))
    sheet.paste(im,(x0,y0+26)); dr.text((x0,y0),label(t),fill=(255,255,255))
sheet.save('out/minimap_paths.png'); print('ok')
