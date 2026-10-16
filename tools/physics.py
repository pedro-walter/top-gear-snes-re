#!/usr/bin/env python3 -I
"""Python model of Top Gear's player speed update (05:D2E0..D6xx), built from the disassembly."""
ROM=open(__import__('os').environ.get('TOPGEAR_ROM','Top Gear (USA).sfc'),'rb').read()
def W(addr): o=addr&0x7fff; return ROM[o]|(ROM[o+1]<<8)   # bank 00
def s16(v): v&=0xFFFF; return v-65536 if v>=32768 else v
TOP,DRAG,ACC,RATIO,PULL=0x9597,0x960B,0x96F3,0x9767,0x967F
def tab(base,car,gear,nitro): return s16(W(base+car*16+gear*2+(0x3A if nitro else 0)))
def tick(v,gear,nitro,fuel,slope,car=0,throttle=True,shiftflag=False):
    top=tab(TOP,car,gear,nitro)+((0xA7FF-fuel)>>6)
    # slope term
    A=(-slope)&0xFFFF
    if A>=0x8000: A=((A>>1)|0x8000)&0xFFFF; A=((A>>1)|0x8000)&0xFFFF
    A=A>>4
    if A>=0x800: A|=0xF000
    v=s16(v+A)
    # drag
    if v>=0:
        t=s16(DRAGv(car,gear,nitro)-v) if False else (DRAGv(car,gear,nitro)-v)
        t=abs(t)
        v=v-((t>>8)&0xFF)
        if v<0: v=0
    # engine
    if throttle and fuel>0:
        diff=top-v
        if diff<0:
            v=v-((abs(diff)>>8)&0xFF)
        else:
            a=(diff*tab(PULL,car,gear,nitro))>>8>>2
            if shiftflag: a>>=1
            v=v+a
    return v,top
def DRAGv(car,gear,nitro): return tab(DRAG,car,gear,nitro)
if __name__=='__main__':
    import csv,sys
    rows=list(csv.DictReader(open(sys.argv[1] if len(sys.argv)>1 else 'out/ticks_a.csv')))
    errs=[]
    for i in range(len(rows)-1):
        r,n=rows[i],rows[i+1]
        v=int(r['spd']); g=int(r['gear']); nit=int(r['nitro']); 
        if int(n['f'])-int(r['f'])>3: continue
        if int(r['flag'])&0x30: continue
        pred,_=tick(v,g,(nit&0x8000)!=0,int(r['fuel']),int(r['slope']))
        errs.append((int(n['spd'])-pred,int(r['f']),v,pred,int(n['spd']),g))
    import collections
    c=collections.Counter(e[0] for e in errs)
    print('ticks compared',len(errs),'exact',c[0],'off by 1',c[1]+c[-1])
    bad=[e for e in errs if abs(e[0])>2][:15]
    print(bad)
