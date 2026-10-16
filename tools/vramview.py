#!/usr/bin/env python3 -I
"""vramview.py vram.bin cgram.bin out.png [firstTile nTiles palette bpp(4)] : render 8x8 tile sheet (16 tiles per row), chr base 0x5000 words"""
import sys
from PIL import Image
v=open(sys.argv[1],'rb').read(); c=open(sys.argv[2],'rb').read()
first=int(sys.argv[4],0) if len(sys.argv)>4 else 0x180; n=int(sys.argv[5],0) if len(sys.argv)>5 else 128
pal=int(sys.argv[6],0) if len(sys.argv)>6 else 1
import os
base=int(os.environ.get("BASE","0xA000"),0)
def col(i):
    w=c[2*i]|(c[2*i+1]<<8); return ((w&31)*8,((w>>5)&31)*8,((w>>10)&31)*8)
cols=16; rows=(n+cols-1)//cols
im=Image.new('RGB',(cols*8,rows*8))
for k in range(n):
    t=first+k; o=base+t*32
    for y in range(8):
        b0,b1=v[o+2*y],v[o+2*y+1]; b2,b3=v[o+16+2*y],v[o+16+2*y+1]
        for x in range(8):
            s=7-x; p=((b0>>s)&1)|(((b1>>s)&1)<<1)|(((b2>>s)&1)<<2)|(((b3>>s)&1)<<3)
            im.putpixel(((k%cols)*8+x,(k//cols)*8+y),col(pal*16+p))
im=im.resize((im.width*4,im.height*4),Image.NEAREST); im.save(sys.argv[3])
