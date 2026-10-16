#!/usr/bin/env python3 -I
"""Render the 32 pre-drawn track maps (2bpp tiles, 8x8 tiles = 64x64 px per track) from out/mapgfx_0.bin (tracks 0-15, ROM 0D:8000 compressed) and out/mapgfx_16.bin (tracks 16-31, 0D:911F)."""
import sys
sys.path.insert(0,'tools')
from names import label
from PIL import Image, ImageDraw
pal=[(0,0,0),(90,90,90),(170,170,170),(255,255,255)]
def tile_img(buf,off):
    im=Image.new('RGB',(64,64))
    for ti in range(64):
        for y in range(8):
            b0=buf[off+ti*16+2*y]; b1=buf[off+ti*16+2*y+1]
            for x in range(8):
                s=7-x; p=((b0>>s)&1)|(((b1>>s)&1)<<1)
                im.putpixel(((ti%8)*8+x,(ti//8)*8+y),pal[p])
    return im
bufs=[open('out/mapgfx_0.bin','rb').read(),open('out/mapgfx_16.bin','rb').read()]
S=3;cols=8
sheet=Image.new('RGB',(cols*(64*S+8),4*(64*S+34)),(30,30,40)); dr=ImageDraw.Draw(sheet)
for t in range(32):
    im=tile_img(bufs[t>>4],(t&15)*1024)
    im.save('out/map_%02d.png'%t) if False else None
    x=(t%cols)*(64*S+8)+4; y=(t//cols)*(64*S+34)+4
    sheet.paste(im.resize((64*S,64*S),Image.NEAREST),(x,y+26))
    dr.text((x,y),label(t),fill=(255,255,255))
sheet.save('out/minimaps.png'); print(sheet.size)
