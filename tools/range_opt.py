#!/usr/bin/env python3 -I
"""Longest distance on one tank per car: exact fuel-burn model (05:D5F6..D67B) + the speed model of tools/physics.py.
Fuel per tick = ((RPM*burn_byte)>>14 & 0x3FF)+1, RPM = ((speed*ratio)>>8)<<1 - it does NOT depend on the throttle.
Run from the repo root:  python3 -I tools/range_opt.py"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import physics as P
KMH = 1 / 41.7; TICK = 1.5 / 60; NAMES = ['red', 'white', 'purple', 'blue']
BURN = list(P.ROM[0x97DB & 0x7fff:(0x97DB & 0x7fff) + 4])
RATIO = lambda car, g: P.ROM[(0x9767 + car * 16 + g * 2) & 0x7fff]
FULL = 0xA7FF

def burn(v, car, g):
    rpm = (((v * RATIO(car, g)) >> 8) << 1) & 0xFFFF
    if rpm == 0 or rpm >= 0x8000: return 0
    return (((rpm * BURN[car]) >> 14) & 0x3FF) + 1

def km(units): return units * KMH * TICK / 3600

def run(car, cruise, target, sw, glide_gear=None, max_ticks=20000):
    """launch at full throttle with the best gear <= cruise each tick until the speed reaches `sw`, then stay in the cruise gear
    with bang-bang throttle around `target` (None = throttle always on).
    returns (km driven under power, km glided, ticks, speed at empty)"""
    v, g, fuel, dist, t = 0, 0, FULL, 0, 0
    while fuel > 0 and t < max_ticks:
        if v >= sw:
            g = cruise
            nv = P.tick(v, g, False, fuel, 0, car=car, throttle=target is None or v < target)[0]
        else:
            nv, g = max((P.tick(v, g2, False, fuel, 0, car=car)[0], g2) for g2 in (g - 1, g, g + 1) if 0 <= g2 <= cruise)
        v = nv; fuel -= burn(v, car, g)                     # RPM (and so the burn) comes from the speed after this tick's update (verified: 846/852 ticks)
        dist += v; t += 1
    v_empty, gl = v, 0
    gg = cruise if glide_gear is None else glide_gear
    for _ in range(2400):                                   # capped at 60 s: drag stops slowing the car within 256 units of the gear's drag constant
        if v <= 0: break
        v, _ = P.tick(v, gg, False, 0, 0, car=car, throttle=False); gl += v
    return km(dist), km(gl), t, v_empty

SWS = [int(k / KMH) for k in (150, 190)]

def best(car, cruise):
    top = P.tab(P.TOP, car, cruise, False)
    out = None
    for sw in SWS:
        r = run(car, cruise, None, sw)
        if out is None or r[0] > out[0][0]: out = (r, None, sw)
        for T in range(int(150 / KMH), int(240 / KMH), int(6 / KMH)):
            r = run(car, cruise, T, sw)
            if r[0] > out[0][0]: out = (r, T, sw)
    return out

if __name__ == '__main__':
    for car in range(4):
        print('== %s car' % NAMES[car])
        for cruise in (3, 4):
            r, T, sw = best(car, cruise)
            held = max(run(car, cruise, None, sw2)[0] for sw2 in SWS)
            print('  gear %d: throttle held %.2f km; best %.2f km with target %s, shift at %d km/h (+%.2f km glide)' % (
                cruise + 1, held, r[0], 'full throttle' if T is None else '%d km/h' % (T * KMH), sw * KMH, r[1]))
