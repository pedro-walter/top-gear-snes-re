#!/usr/bin/env python3 -I
"""Fastest-acceleration shift points per car on a flat road (full tank), without and with nitro.
Exact dynamic programme over the game's own one-tick speed model (tools/physics.py): the one-tick map is monotone in speed
for every gear, so keeping only the fastest speed per gear at each tick is optimal; gears change by one step per tick like the manual box.
Run from the repo root:  python3 -I tools/gear_opt.py"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import physics as P
KMH = 1 / 41.7                   # speed units -> km/h
TICK = 1.5 / 60                  # one physics tick = 2 per 3 frames
NITRO_TICKS = 213                # 320 frames
NAMES = ['red', 'white', 'purple', 'blue']

def step(v, g, nitro, car): return P.tick(v, g, nitro, 0xA7FF, 0, car=car)[0]

def dp(car, nitro_at, ticks):
    """best[t][g] = highest speed after t ticks in gear g (start: standstill, gear index 0); prev[t][g] = gear of the tick before"""
    NEG = -1
    best, prev = [[0, NEG, NEG, NEG, NEG]], [[None] * 5]
    for t in range(ticks):
        nb, pv = [NEG] * 5, [None] * 5
        for g in range(5):
            v = best[-1][g]
            if v < 0: continue
            for g2 in (g - 1, g, g + 1):
                if 0 <= g2 < 5:
                    s = step(v, g2, nitro_at(t), car)
                    if s > nb[g2]: nb[g2], pv[g2] = s, g
        best.append(nb); prev.append(pv)
    return best, prev

def shift_events(car, nitro, ticks):
    best, prev = dp(car, lambda t: nitro and t < NITRO_TICKS, ticks)
    fin = [max(b) for b in best]
    g = max(range(5), key=lambda i: best[ticks][i]); path = []
    for t in range(ticks, 0, -1): path.append((t, g)); g = prev[t][g]
    ev, g0 = [], 0
    for t, gg in path[::-1]:
        if gg != g0: ev.append((g0 + 1, gg + 1, round(fin[t - 1] * KMH))); g0 = gg
    return fin, ev

if __name__ == '__main__':
    for nitro in (False, True):
        print('WITH NITRO from the start' if nitro else 'WITHOUT NITRO')
        for car in range(4):
            ticks = NITRO_TICKS if nitro else 1200
            fin, ev = shift_events(car, nitro, ticks)
            print(' %-6s peak %3d km/h; shifts (gear a -> b at km/h; later 1-unit chatter near the top is noise):' % (NAMES[car], fin[-1] * KMH),
                  ', '.join('%d->%d@%d' % e for e in ev[:5]))
