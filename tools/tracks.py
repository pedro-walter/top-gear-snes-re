#!/usr/bin/env python3 -I
"""Top Gear (USA) track data extractor - replicates the loader at 00:BF44 (sub_00BF44).
Usage: tools/tracks.py [track]   (default: compare track 0 with out/wram_6000.bin)"""
import sys
ROM=open(__import__('os').environ.get('TOPGEAR_ROM','Top Gear (USA).sfc'),'rb').read()
def off(bank,addr): return bank*0x8000+(addr&0x7fff)
def W(bank,addr): o=off(bank,addr); return ROM[o]|(ROM[o+1]<<8)
def B(bank,addr): return ROM[off(bank,addr)]
def s16(v): return v-65536 if v>=32768 else v
def descriptor(t):
    base=0x8402+10*t
    w=[W(0xC,base+2*i) for i in range(5)]
    return dict(w0=w[0],slope=w[1],curve=w[2],scen=w[3],objs=w[4],length=(w[0]&0x3f)*1024,nelem=(w[0]&0x3f))
def stream_tab(tab, stream_ptr, n):
    """Loader loop at 00:BF91: element k = signed byte stream[k+1]; |b| indexes a pointer table (tab);
    each pointer -> 32 words (one 1024-unit track piece); negative b = negated profile."""
    out=[]
    for k in range(n):
        b=B(0xC,stream_ptr+k+1)
        sb=b-256 if b>=128 else b
        ptr=W(0xC,tab+2*abs(sb))
        seg=[s16(W(0xC,ptr+2*i)) for i in range(32)]
        if sb<0: seg=[s16(-v) for v in seg]
        out.append((sb,abs(sb),ptr,seg))
    return out
if __name__=='__main__':
    t=int(sys.argv[1]) if len(sys.argv)>1 else 0
    d=descriptor(t)
    print(t,d)
    n=d['w0']+1
    sl=stream_tab(0x85D3,d['slope'],n)
    dump=open('out/wram_6000.bin','rb').read()
    ok=0;tot=0
    flat=[]
    for w,idx,ptr,seg in sl:
        flat+=seg
    for i,v in enumerate(flat):
        dv=s16(dump[0x4000+2*i]|(dump[0x4001+2*i]<<8))
        tot+=1; ok+= (dv==v)
    print('slope match',ok,'/',tot)
