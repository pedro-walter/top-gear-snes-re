#!/usr/bin/env python3 -I
"""Bot field of a race from the RNG seed at race_init (00:A558..A66B). Model verified against Mesen (scripts/rome_bots.lua)."""
import sys,os
ROM=open(os.environ.get('TOPGEAR_ROM','Top Gear (USA).sfc'),'rb').read()
def off(a): return a&0x7fff
def templates():
    T=[]
    for k in range(2,20):
        o=off(0xA732)+18*k; b=ROM[o:o+18]
        T.append(dict(id=b[0]&0x1f,base=b[10]|(b[11]<<8),mult=b[12],ramp=b[14]))
    return T
TPL=templates()
def diff_off(track,dif): o=off(0xDDE4)+6*track+2*dif; return ROM[o]|(ROM[o+1]<<8)
def rng(s):
    s=(13*(s+7))&0xFFFF; return s,((s>>8)^s)&0xFF
def field(seed,track=25,dif=2):
    """-> list of 18 dicts (template order = slot order skipping the 2 human slots): id, S (target), speed (final cruise, bot units), lateral"""
    d=diff_off(track,dif); s=seed&0xFFFF; out=[]
    for t in TPL:
        s,j=rng(s); S=t['base']+2*j+d
        acc=(S*t['mult'])>>8; fin=1+acc*t['ramp']
        s,l=rng(s)
        out.append(dict(id=t['id'],S=S,speed=fin,mult=t['mult'],ramp=t['ramp'],acc=acc))
    return out
if __name__=='__main__':
    seed=int(sys.argv[1]); f=field(seed)
    print(sorted((b['speed'],b['id']) for b in f))
