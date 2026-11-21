#!/usr/bin/env python3 -I
"""Rome (track 25) race model, any car (default white = 1): exact speed physics (tools/physics.py) on the real slope table,
fuel burn, manual gearbox with the 3rd-gear nitro trick; compared with the bot field from tools/rome_bots.py.
Time unit: frames (60/s). A physics tick = DELTA frames ($1E90, 3 on Rome in headless Mesen: 2446 of 2536 ticks). Position per tick = v*DELTA/512.
Nitro = 320 frames (state machine 00:B9ED, per frame)."""
import sys,os
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import physics as P, tracks, rome_bots as B
TRACK=25; D=tracks.descriptor(TRACK); LEN=D['length']; LAPS=6
SL=[];CV=[]
for sb,idx,ptr,seg in tracks.stream_tab(0x85D3,D['slope'],D['w0']+1): SL+=seg
for sb,idx,ptr,seg in tracks.stream_tab(0x8591,D['curve'],D['w0']+1): CV+=seg
DELTA=3; NITRO_FRAMES=320
BURN=list(P.ROM[0x97DB&0x7fff:(0x97DB&0x7fff)+4])
RATIO=lambda car,g:P.ROM[(0x9767+car*16+g*2)&0x7fff]
GRIP={0:196608,1:196608*416//384,2:196608,3:196608}      # speed*|c| limit while accelerating (docs/08, 14)
def burn(v,car,g):
    rpm=(((v*RATIO(car,g))>>8)<<1)&0xFFFF
    if rpm==0 or rpm>=0x8000: return 0
    return (((rpm*BURN[car])>>14)&0x3FF)+1
def slope(pos): return SL[(pos>>5)%len(SL)]
def curve(pos): return CV[(pos>>5)%len(CV)]
def dist(slot): return LAPS*LEN+0x2A0-0x20*slot          # units from the grid slot to the finish line
def run(fire, slot=0, fire_fn=None, car=1, curvecap=False, trace=False, delta=DELTA, fuel0=0xA7FF):
    """fire: ticks at which A is pressed (a press while a nitro is active is ignored, so a late list entry is a re-press).
    curvecap: clamp speed to GRIP/|c| (lift for corners). returns (frames to cross the line, fuel left, log)"""
    v=0; g=0; fuel=fuel0; tot=-(0x2A0-0x20*slot); t=0; nit=0; charges=3; fi=0; log=[]
    while tot<LAPS*LEN and t<40000:
        if nit==0 and charges>0 and ((fire_fn(t,v,g,tot,charges) if fire_fn else (fi<len(fire) and t>=fire[fi]))):
            nit=NITRO_FRAMES; charges-=1; fi+=1
        N=nit>0
        sl=slope(int(tot)%LEN)
        best=None
        for g2 in (g-1,g,g+1):
            if 0<=g2<=4:
                nv,_=P.tick(v,g2,N,fuel,sl,car=car,throttle=fuel>0)
                if best is None or nv>best[0]: best=(nv,g2)
        v,g=best
        if curvecap:
            c=abs(curve(int(tot)%LEN))
            if c and v*c>GRIP[car]: v=GRIP[car]//c
        fuel=max(0,fuel-burn(v,car,g))
        tot+=v*delta/512; t+=1
        if nit>0: nit=max(0,nit-delta)
        if trace and t%10==0: log.append((t*delta,round(v*24/1024),g,fuel,int(tot),N))
    return t*delta,fuel,log
_bt={}
def bot_frames(acc,ramp,speed,slot,delta=DELTA):
    """frames for a bot (start speed 1, +acc per tick for `ramp` ticks) from its grid slot to the finish"""
    k=(acc,ramp,slot,delta)
    if k in _bt: return _bt[k]
    d=LAPS*LEN+0x2A0-0x20*slot; v=1; pos=0.0; t=0
    for i in range(ramp):
        pos+=v*delta/256; t+=1; v+=acc
        if pos>=d: break
    if pos<d:
        step=v*delta/256; n=-(-(d-pos)//step); t+=int(n)
    _bt[k]=t*delta
    return t*delta
def field_times(seed,pslot=0,dif=2,delta=DELTA):
    """finish frame of each of the 18 bots; the human slots are pslot and (1, or 0 if pslot==1)"""
    f=B.field(seed,TRACK,dif); human={pslot,1 if pslot!=1 else 0}
    slots=[x for x in range(20) if x not in human]
    return [bot_frames(b['acc'],b['ramp'],b['speed'],slots[i],delta) for i,b in enumerate(f)]
