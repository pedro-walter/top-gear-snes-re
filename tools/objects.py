#!/usr/bin/env python3 -I
"""Scenery ($7E5800) and object ($7E6400) stream expansion, port of 00:C042..C0EF. Verifies against a WRAM dump (track 0, difficulty of that dump)."""
import sys
sys.path.insert(0,'tools')
from tracks import *
def scenery(t):
    d=descriptor(t); out=[]
    p=d['scen']
    for k in range(d['nelem']+1):
        w=W(0xC,p+2*k)               # LDA $0000,X ; X=ptr, INX (byte step!)
        out.append(w)
    return d,out
def scen_words(t):
    d=descriptor(t); p=d['scen']; res=[]
    for k in range(d['nelem']+1):
        w=W(0xC,p+k)                 # X increments by 1
        a=(w<<1)&0x1FF
        src=W(0xC,0x8545+a)
        res.append((w,a,src,[W(0xC,src+2*i) for i in range(32)]))
    return res
def objects(t,diff):
    d=descriptor(t); p=d['objs']; n=d['nelem']+1
    mask=W(0xC,0x8541+diff)&0xE000
    words=[]
    for r in range(2*n):
        w0=W(0xC,p); w1=W(0xC,p+2); w2=W(0xC,p+3); p+=5
        D=[0]*4
        a=(w0<<1)&0xFFFF; D[0]=(a&0xFF)<<8; D[1]=a&0xFF00
        a=(w1<<1)&0xFFFF; D[2]=(a&0xFF)<<8; D[3]=a&0xFF00
        y=((w2&0xFF00)>>3)
        for i in range(16):
            e=W(0xC,0x8615+y+2*i)
            if e==0: words.append(0); continue
            if not (e&mask): words.append(0); continue
            idx=(e>>9)&3
            d_=D[idx]
            if d_==0: words.append(0); continue
            low=e&0x1FF
            if d_&0x8000:
                low=(d_&0x3E00)>>8
                words.append((d_&0xC000)|low)
            else: words.append(d_|low)
    return words
if __name__=='__main__':
    dump=open('out/wram_6000.bin','rb').read()
    sw=scen_words(0)
    flat=[x for s in sw for x in s[3]]
    ok=sum(1 for i,v in enumerate(flat) if dump[0x5800+2*i]|(dump[0x5801+2*i]<<8)==v)
    print('scenery match',ok,len(flat))
    for diff in range(3):
        ow=objects(0,diff)
        ok=sum(1 for i,v in enumerate(ow) if (dump[0x6400+2*i]|(dump[0x6401+2*i]<<8))==v)
        print('diff',diff,'object match',ok,len(ow),'nonzero',sum(1 for v in ow if v))
