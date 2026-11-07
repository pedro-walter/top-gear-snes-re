#!/usr/bin/env python3 -I
"""Pit-stop count and fuel headroom per pit track, from scripts/fuel_lab.lua baseline runs (out/fuel/base_t<track>_c<car>.csv).
usage: fuel_stops.py <car> [prefix]
A stop is only possible when the car passes the pit entrance (once per lap, at pos 2*(00:DF24[t]&0x7FFF)); each stop refuels to a full tank.
For each track: minimum number of stops at the measured consumption, and the % of extra consumption (scale) that plan can absorb
before one more stop is needed."""
import sys,os,csv,bisect; sys.path.insert(0,os.path.dirname(__file__))
import names
H=os.path.join(os.path.dirname(__file__),'..')
R=open(os.path.join(H,'Top Gear (USA).sfc'),'rb').read()
FULL=43007
def curve(path):
    """fuel burned from the start of the lap to pos, for lap 0 (from the standing start) and lap 1 (steady)"""
    laps={}
    for r in csv.DictReader(open(path)):
        l=int(r['laps']); l=0 if l==65535 else l
        laps.setdefault(l,[]).append((int(r['pos']),int(r['fuel'])))
    out={}
    L=max(p for p,_ in laps[1])
    for l in (0,1):
        pts=laps[l]; f0=pts[0][1]
        if l==0:   # the grid is a little behind the line: positions before the first wrap are negative
            q=[];wrapped=False;prev=pts[0][0]
            for p,f in pts:
                if p<prev-20000: wrapped=True
                prev=p
                q.append((p if wrapped else p-L,f))
            pts=q
        out[l]=[(p,f0-f) for p,f in pts]
    return out
def burn_at(c,pos):
    i=bisect.bisect_left([p for p,_ in c],pos)
    return c[min(i,len(c)-1)][1]
def lapburn(c): return c[-1][1]-(burn_at(c,0) if c[0][0]<0 else 0)
def stops(t,car,scale,prefix='base',glide=0.0,early=0):
    cv=curve(os.path.join(H,'out/fuel/%s_t%d_c%d.csv'%(prefix,t,car)))
    laps=R[0x5EA4+2*t]; P=(R[0x5F24+2*t]|(R[0x5F25+2*t]<<8))&0x7FFF; P*=2
    # cumulative burn at every pit pass (end of lap k at pos P) measured from the start line, laps >= 1 use the steady curve
    def cum(k,pos):   # fuel burned from start until lap k, position pos
        tot=0
        for l in range(k): tot+=lapburn(cv[0] if l==0 else cv[1])
        return (tot+burn_at(cv[0] if k==0 else cv[1],pos))*scale
    total=cum(laps-1,10**9)
    # greedy: at each pit pass k (0..laps-1) stop at the last reachable pass; fuel used since last refuel <= FULL
    n=0; base=0.0; k=0; ok=True
    G=glide*lapburn(cv[1])*scale     # fuel-equivalent of the distance coasted after the tank is empty
    cap=FULL+G+early                 # 'early' = fuel saved per stint by shifting up early at the launch
    while total-base>cap:
        best=None
        for kk in range(k,laps):
            if cum(kk,P)-base<=cap: best=kk
            else: break
        if best is None: return None,total
        base=cum(best,P); k=best+1; n+=1
        if n>6: return None,total
    return n,total
def plan(t,car,prefix='base'):
    """stops needed for (ideal, realistic +3.4 %, realistic + early 5th, realistic + early 5th + dry-tank glide)"""
    r=1.034
    return [stops(t,car,1.0,prefix)[0], stops(t,car,r,prefix)[0], stops(t,car,r,prefix,0,370)[0], stops(t,car,r,prefix,0.14,370)[0]]
def headroom(t,car,prefix='base'):
    n0,total=stops(t,car,1.0,prefix)
    lo,hi=1.0,3.0
    for _ in range(30):
        m=(lo+hi)/2
        n,_=stops(t,car,m,prefix)
        if n is not None and n<=n0: lo=m
        else: hi=m
    return n0,total,lo
if __name__=='__main__':
    car=int(sys.argv[1]); prefix=sys.argv[2] if len(sys.argv)>2 else 'base'
    print('stops needed: ideal | realistic (+3.4 %) | + early 5th (-370 per stint) | + coasting the empty tank (0.14 lap)')
    for t in [3,4,6,8,9,11,12,14,15,21,22,25,28]:
        try: print('%-26s %s'%(names.label(t),plan(t,car,prefix)))
        except Exception as e: print(names.label(t),'missing',e)
    print()
    print('%-26s laps  race fuel  tanks  stops  extra fuel use allowed before another stop'%'')
    for t in [3,4,6,8,9,11,12,14,15,21,22,25,28]:
        try: n,total,h=headroom(t,car,prefix)
        except Exception as e: print(names.label(t),'missing',e); continue
        print('%-26s %4d  %9d  %5.2f  %5d  %+5.1f %%   (needs a saving of %4.1f %% to drop below %d stops)'%(names.label(t),R[0x5EA4+2*t],total,total/FULL,n,(h-1)*100,0,n) if False else
              '%-26s %4d  %9d  %5.2f  %5s  %+5.1f %%'%(names.label(t),R[0x5EA4+2*t],total,total/FULL,n,(h-1)*100))
