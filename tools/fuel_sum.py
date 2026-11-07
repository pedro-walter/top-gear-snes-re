#!/usr/bin/env python3 -I
"""Summarise out/fuel/<tag>.csv from scripts/fuel_lab.lua: per-lap fuel burned, frames, mean delta."""
import sys,csv
def laps(path):
    rows=[r for r in csv.DictReader(open(path))]
    out=[];cur=None
    for r in rows:
        f=int(r['f']);fuel=int(r['fuel']);l=int(r['laps']);l=0 if l==65535 else l
        if cur is None or l!=cur['l']:
            if cur: cur['f1']=f;cur['fuel1']=fuel;out.append(cur)
            cur={'l':l,'f0':f,'fuel0':fuel,'n':0,'d':0,'v':0}
        cur['n']+=1;cur['d']+=int(r['delta']);cur['v']+=int(r['spd'])
    return out,rows
if __name__=='__main__':
    for p in sys.argv[1:]:
        o,rows=laps(p)
        print(p, 'final fuel',rows[-1]['fuel'],'frames',rows[-1]['f'])
        for c in o:
            print('  lap %d: fuel %d  frames %d (%.1f s)  ticks %d  mean delta %.2f  mean km/h %.0f'%(c['l'],c['fuel0']-c['fuel1'],c['f1']-c['f0'],(c['f1']-c['f0'])/60,c['n'],c['d']/c['n'],c['v']/c['n']*24/1024))
