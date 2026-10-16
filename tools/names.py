#!/usr/bin/env python3 -I
"""Track names from the ROM: pointer table 0D:C77C[track] -> location-screen text in bank 0F (name, country)."""
import re
ROM=open(__import__('os').environ.get('TOPGEAR_ROM','Top Gear (USA).sfc'),'rb').read()
def _names():
    out=[]
    for t in range(32):
        o=0x6c77c+2*t; p=ROM[o]|(ROM[o+1]<<8)
        s=ROM[0x78000+(p&0x7fff):][:48]
        toks=[x.decode('latin1').replace('=','.') for x in re.findall(rb'[A-Z][A-Z =]*[A-Z]',s)]
        out.append((toks[0].strip(),toks[1].strip()))
    return out
NAMES=_names()
GROUPS=['USA','SOUTH AMERICA','JAPAN','GERMANY','SCANDINAVIA','FRANCE','ITALY','UK']   # country screen order (track>>2)
def label(t): return '%d %s (%s)'%(t,NAMES[t][0].title(),NAMES[t][1].title() if NAMES[t][1]!='U.S.A' else 'USA')
if __name__=='__main__':
    for t in range(32): print(label(t))
