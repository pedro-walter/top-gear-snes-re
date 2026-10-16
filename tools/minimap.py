#!/usr/bin/env python3 -I
"""minimap.py vram.bin cgram.bin out.png : compose the minimap region (BG1 tilemap $C00 rows 1-4, cols 1-8; chr base 0; 4bpp; palette 7) at 6x."""
import sys
from PIL import Image
v=open(sys.argv[1],'rb').read(); c=open(sys.argv[2],'rb').read()
def w(a): return v[2*a]|(v[2*a+1]<<8)
def col(i):
    x=c[2*i]|(c[2*i+1]<<8); return ((x&31)*8,((x>>5)&31)*8,((x>>10)&31)*8)
R0,C0,NR,NC=1,1,8,8
im=Image.new('RGB',(NC*8,NR*8))
for r in range(NR):
    for cc in range(NC):
        e=w(0xC00+(R0+r)*32+C0+cc); t=e&0x3FF; pal=(e>>10)&7
        o=t*32
        for y in range(8):
            b0,b1,b2,b3=v[o+2*y],v[o+2*y+1],v[o+16+2*y],v[o+17+2*y]
            for x in range(8):
                s=7-x; p=((b0>>s)&1)|(((b1>>s)&1)<<1)|(((b2>>s)&1)<<2)|(((b3>>s)&1)<<3)
                im.putpixel((cc*8+x,r*8+y),col(pal*16+p) if p else (0,0,0))
im.resize((im.width*6,im.height*6),Image.NEAREST).save(sys.argv[3])
