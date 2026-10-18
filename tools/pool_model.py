#!/usr/bin/env python3 -I
"""Model of the roadside scanner's VRAM allocator (00:E20D..E500, docs/10 "Graphics pool").

The scanner looks at the 4 slots 40..43 ahead of the camera on every second frame; the graphic id of each object is loaded into an
8 KB pool (256 units of 32 bytes, sizes at 00:E888 + 4 * id, first fit by address, at most 8 blocks); a block is freed when the camera
has passed the last object of its type.  A type that fits nowhere is skipped (the "drops"), its objects in view are then drawn with
whatever tiles are in VRAM (the garbled scenery).  The model moves the camera one slot per step.
Usage: tools/pool_model.py seed...        garbled camera slots of generated tracks (8 hex digits)
       tools/pool_model.py --orig         the same for the 32 original environments (they glitch a little too)
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trackgen as T
from tracks import B, descriptor

def simulate(objs, L, step=1, laps=2, ahead=40, scanw=4, keepw=45):
    """-> (drops, garble): drops = (camera slot, id, size, live blocks) of failed loads; garble = (camera slot, ids of objects in view
    that are not loaded) in the last lap."""
    n = L * 32
    live = []                                            # [id, start, end, last slot seen] sorted by address
    pend = []                                            # [id, slot]
    drops = []; garble = []
    cc = 0
    while cc < n * laps:
        c = cc % n
        live = [b for b in live if (b[3] - c) % n < keepw]
        for k in range(scanw):
            s = (c + ahead + k) % n
            for i in T.gfx_ids(objs[s]):
                for b in live:
                    if b[0] == i: b[3] = s; break
                else:
                    for p in pend:
                        if p[0] == i: p[1] = s; break
                    else: pend.append([i, s])
        if pend and len(live) < 8:
            i, s = pend.pop(0); S = T.gfx_units(i)
            pos = None; idx = 0
            if not live: pos = 0
            elif live[0][1] >= S: pos = 0
            else:
                for q in range(len(live) - 1):
                    if live[q + 1][1] - live[q][2] >= S: pos = live[q][2]; idx = q + 1; break
                if pos is None and 256 - live[-1][2] >= S: pos = live[-1][2]; idx = len(live)
            if pos is None: drops.append((c, i, S, [(b[0], b[1], b[2]) for b in live]))
            else: live.insert(idx, [i, pos, pos + S, s])
        if cc >= n:
            want = set()
            for s in range(c, c + ahead): want.update(T.gfx_ids(objs[s % n]))
            miss = want - {b[0] for b in live}
            if miss: garble.append((c, sorted(miss)))
        cc += step
    return drops, garble

def runs(lst, gap=24):
    out = []; last = -999
    for x in lst:
        if x[0] - last > gap: out.append(x[0])
        last = x[0]
    return out

if __name__ == '__main__':
    if sys.argv[1:] == ['--orig']:
        for env in range(32):
            d = descriptor(env); n = d['nelem'] + 1
            recs = [[B(0xC, d['objs'] + 5 * r + i) for i in range(5)] for r in range(2 * n)]
            o = T.expand_objs(recs, 1); o += o[:64]
            dr, g = simulate(o, n - 1)
            print('env %2d L %d  drops %3d  garbled camera slots %3d at %s' % (env, n - 1, len(dr), len(g), runs(g)[:6]))
    else:
        for a in sys.argv[1:]:
            t = T.generate(int(a, 16)); o = T.tables(t)['objs']
            dr, g = simulate(o, t['L'])
            print('%s env %2d L %d  drops %3d  garbled camera slots %3d at %s' % (a, t['env'], t['L'], len(dr), len(g), runs(g)[:6]))
