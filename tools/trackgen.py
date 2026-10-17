#!/usr/bin/env python3 -I
"""Random track generator - Python reference implementation (docs/09).

The 65816 generator that runs on the console is a literal port of this file: same PRNG, same draw order,
only byte/word arithmetic.  A track is described exactly like the originals (stream bytes of bank 0C):
  slope[P], curve[P]   signed template ids (byte, negative = mirrored)      P = L+1 pieces of 1024 units
  scen[P]              scenery template ids (road type per piece)
  recs[2P]             object records, 5 bytes per half piece (b0..b4, b4 = group template)
  pit                  00:DF24-style word (bit15 = side, low 15 bits = (pit piece*1024-512)/2)
and is expanded to the WRAM tables $4000/$4C00/$5800/$6400 by the same algorithm as 00:BF44.
Usage: tools/trackgen.py [seed ...]     (default: statistics over 2000 seeds)
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
from tracks import ROM, W, B, s16, descriptor

# ---------------------------------------------------------------- PRNG (32-bit Galois LFSR) -----------------
class Rng:
    def __init__(self, seed):
        s = seed & 0xFFFFFFFF
        if s == 0:
            s = 0xDEADBEEF
        self.s = s
        for _ in range(32):
            self.step()
    def step(self):
        lsb = self.s & 1
        self.s >>= 1
        if lsb:
            self.s ^= 0x80200003
    def byte(self):
        for _ in range(8):
            self.step()
        return self.s & 0xFF
    def rnd(self, n):                    # 0..n-1  (n <= 255) via 8x8 multiply (hardware multiplier on the console)
        return (self.byte() * n) >> 8

# ---------------------------------------------------------------- template grammar --------------------------
# slope levels (up, plateau, down), by increasing steepness: 50 110 300 600 700 750 800 900 1000
SL_LEVELS = [(1, 4, 3), (5, 7, 6), (15, 17, 16), (18, 20, 19), (21, 23, 22), (9, 12, 11), (24, 26, 25),
             (27, 29, 28), (30, 32, 31)]
SL_BUMPS = [2, 14, 13, 10]               # one-piece bumps 50, 300, 750(13), 750(10)
# curve levels 16 24 32 (up, plateau, down); 40 has single-piece bumps only
CU_LEVELS = [(2, 4, 3), (6, 8, 7), (10, 12, 11)]
CU_BUMPS = [[1, 17, 18, 19, 20], [5, 21, 22, 23, 24], [9, 25, 26, 27, 28], [13, 29, 30, 31, 32]]
# pit styles observed in the original ROM: (scenery template, side bit, object group of 1st half)
DROP = [[28, 38, 0, 0],
        [15, 0, 0, 0],
        [11, 12, 42, 0],
        [11, 41, 0, 0],
        [14, 0, 0, 0],
        [24, 0, 0, 0],
        [15, 28, 0, 0],
        [24, 0, 0, 0],
        [55, 0, 0, 0],
        [54, 55, 15, 0],
        [43, 0, 0, 0],
        [0, 0, 0, 0],
        [27, 0, 0, 0],
        [10, 0, 0, 0],
        [0, 0, 0, 0],                   # env 14: type 31 (its trees) only dropped near the gantry, see DROPW
        [11, 12, 26, 0],
        [27, 0, 0, 0],
        [31, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [27, 7, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [27, 0, 0, 0],
        [24, 0, 0, 0],
        [0, 0, 0, 0],
        [25, 0, 0, 0],
        [14, 0, 0, 0],
        [30, 0, 0, 0],
        [15, 29, 0, 0],
        [15, 14, 0, 0]]
# the two most common tree/bush types of each original environment (0 = none: the art of other types is not loaded there)
SCENERY = [27,27,24,27,0,0,24,15,27,15,27,26,27,14,15,27,0,0,27,27,27,15,15,14,24,56,15,15,31,31,24,27,25,31,27,25,15,14,31,15,27,24,24,57,27,15,27,26,26,56,27,26,15,27,24,27,27,24,27,15,27,25,27,27]
DROPW = {14: 31}                          # types removed only within WIN slots of the gantry (Black Forest keeps its trees elsewhere)
WIN = 64
SIGN_TYPES = (8, 9, 13)                  # right chevron, left chevron, pit flag
# (scenery template, pit word side bit, object group of the 1st half, flag template far/near, flag record slot (0 = b0, 1 = b1),
#  road style of type 3, mirror bit of 00:DEE4).  Exactly the combinations of the original tracks: the pit lane is on the left
#  (groups 41, 45) or on the right (group 47) and the road style (00:DEE4 bits 9-11) of the environment is overridden to match.
PIT_STYLES = [(20, 0, 41, 24, 24, 0, 1, 0), (20, 1, 45, 26, 26, 0, 4, 0), (20, 1, 47, 24, 26, 1, 5, 1)]

def neg(i): return (256 - i) & 0xFF if i else 0

def slope_walk(r, P, h):
    out = [0] * P
    pos, end = 1, P - 1
    nlev, nbump = 3 + 2 * h, min(2 + h, 4)
    while pos < end:
        rem = end - pos
        k = r.rnd(100)
        ids = None
        if k >= 60:                                      # long hill: up, plateau * n, down
            u, p, d = SL_LEVELS[r.rnd(nlev)]
            n = r.rnd(4)
            sg = r.rnd(2)
            if n + 2 <= rem:
                ids = [u] + [p] * n + [d]
                if sg: ids = [neg(i) for i in ids]
        elif k >= 35:                                    # single-piece bump
            b = SL_BUMPS[r.rnd(nbump)]
            sg = r.rnd(2)
            ids = [neg(b) if sg else b]
        if ids is None:                                  # flat run
            n = 1 + r.rnd(5)
            ids = [0] * min(n, rem)
        for i in ids:
            if pos < end:
                out[pos] = i; pos += 1
    return out

def curve_walk(r, P, c):
    out = [0] * P
    pos, end = 1, P - 1
    nl = 2 + c
    while pos < end:
        rem = end - pos
        k = r.rnd(100)
        ids = None
        if k >= 72:                                      # sweeper: up, plateau * n, down  (+ optional S-bend)
            lv = r.rnd(min(nl, 3))
            u, p, d = CU_LEVELS[lv]
            n = r.rnd(3)
            sg = r.rnd(2)
            s = r.rnd(3)                                 # 0: S-bend (mirrored copy follows)
            one = [u] + [p] * n + [d]
            if s == 0 and 2 * len(one) <= rem:
                ids = one + [neg(i) for i in one]
            elif len(one) <= rem:
                ids = one
            if ids and sg: ids = [neg(i) for i in ids]
        elif k >= 38:                                    # single-piece bump
            lv = r.rnd(nl)
            b = CU_BUMPS[lv][r.rnd(5 if lv < 3 else 5)]
            sg = r.rnd(2)
            ids = [neg(b) if sg else b]
        if ids is None:
            n = 1 + r.rnd(6)
            ids = [0] * min(n, rem)
        for i in ids:
            if pos < end:
                out[pos] = i; pos += 1
    return out

# ---------------------------------------------------------------- source tracks ------------------------------
def source(env):
    """Scenery bytes, object records and 'allowed' piece list of the original track `env`."""
    d = descriptor(env)
    n = d['nelem'] + 1
    sc = [B(0xC, d['scen'] + k) for k in range(n)]
    recs = [[B(0xC, d['objs'] + 5 * r + i) for i in range(5)] for r in range(2 * n)]
    for rc in recs:                                      # turn signs (8, 9) and pit signs (13) are generated, never copied
        for i in range(4):
            if rc[i] in SIGN_TYPES or (rc[i] and rc[i] in DROP[env]): rc[i] = 0
    pw = W(0, 0xDF24 + 2 * env)
    bad = set()
    if pw != 0xFFFF:
        bad.add(((pw & 0x7FFF) * 2 + 512) // 1024)
    for k in range(n):
        if sc[k] == 20 or any(41 <= recs[2 * k + h][4] <= 48 for h in (0, 1)):
            bad.add(k)
        if k > 0 and any(recs[2 * k + h][i] & 0x40 for h in (0, 1) for i in range(4)):
            bad.add(k)                                   # group objects (tunnel parts) must not be cut out of their context
    allowed = [k for k in range(1, n - 1) if k not in bad and k + 1 not in bad - {k}]
    allowed = [k for k in range(1, n - 1) if k not in bad]
    return sc, recs, allowed, n

# ---------------------------------------------------------------- generator -----------------------------------
def generate(seed):
    r = Rng(seed)
    env = r.rnd(32)
    L = 24 + r.rnd(23)                                   # 24..46 pieces per lap
    laps = 3 + r.rnd(6)                                  # 3..8
    hill = r.rnd(4)
    curvy = r.rnd(3)
    P = L + 2                                            # pieces 0..L-1, L = wrap copy of 0, L+1 = copy of 1 (scanner look-ahead)
    slope = slope_walk(r, L, hill) + [0]; slope.append(slope[1])
    curve = curve_walk(r, L, curvy) + [0]; curve.append(curve[1])
    ssc, srecs, allowed, sn = source(env)
    scen = [0] * P
    recs = [None] * (2 * P)
    for dst in (0, L):                                   # start/finish piece (and its wrap-around copy)
        scen[dst] = ssc[0]
        recs[2 * dst] = list(srecs[0]); recs[2 * dst + 1] = list(srecs[1])
    pos = 1
    while pos < L:
        s0 = allowed[r.rnd(len(allowed))]
        run = 2 + r.rnd(5)
        j = s0
        while run and pos < L and j in allowed:
            scen[pos] = ssc[j]
            recs[2 * pos] = list(srecs[2 * j]); recs[2 * pos + 1] = list(srecs[2 * j + 1])
            pos += 1; j += 1; run -= 1
    scen[L + 1] = scen[1]
    recs[2 * (L + 1)] = list(recs[2]); recs[2 * (L + 1) + 1] = list(recs[3])
    pp = 4 + r.rnd(L - 8)                                # pit piece 4..L-5
    ps = PIT_STYLES[r.rnd(len(PIT_STYLES))]
    st, side, grp, tfar, tnear, fpos, rstyle, mirror = ps
    scen[pp] = st
    recs[2 * pp] = [21, 58, 0, 0, grp]; recs[2 * pp + 1] = [21, 58, 0, 0, grp + 1]
    for q, T in ((pp - 2, tfar), (pp - 1, tnear)):       # pit flags on the two pieces before the pit (like the original tracks)
        rc = [0, 0, 0, 0, T]; rc[fpos] = 13
        recs[2 * q] = list(rc); recs[2 * q + 1] = list(rc)
    recs[2 * (L - 1)] = [0] * 5; recs[2 * (L - 1) + 1] = [0] * 5   # the last piece before the line stays empty (the start gantry needs it)
    pit = (side << 15) | ((pp * 1024 - 512) // 2)
    roadw = (rstyle << 9) | (mirror << 15)               # replaces bits 9-11 and 15 of 00:DEE4[env]
    return dict(seed=seed, env=env, L=L, P=P, laps=laps, hill=hill, curvy=curvy, slope=slope, curve=curve,
                scen=scen, recs=recs, pit=pit, pitpiece=pp, pitstyle=(st, side, grp), roadw=roadw)

# ---------------------------------------------------------------- expansion (same as 00:BF44) ------------------
def expand_stream(tab, bytes_):
    out = []
    for b in bytes_:
        sb = b - 256 if b >= 128 else b
        ptr = W(0xC, tab + 2 * abs(sb))
        seg = [s16(W(0xC, ptr + 2 * i)) for i in range(32)]
        if sb < 0: seg = [s16(-v) for v in seg]
        out += [v & 0xFFFF for v in seg]
    return out
def expand_slope(b): return expand_stream(0x85D3, b)
def expand_curve(b): return expand_stream(0x8591, b)
def expand_scen(b):
    out = []
    for x in b:
        src = W(0xC, 0x8545 + ((x * 2) & 0x1FF))
        out += [W(0xC, src + 2 * i) for i in range(32)]
    return out
def expand_objs(recs, diff):
    mask = 0xE000                                        # every difficulty's objects: the seed decides, not the difficulty
    words = []
    for rc in recs:
        w0 = rc[0] | rc[1] << 8; w1 = rc[2] | rc[3] << 8; w2 = rc[3] | rc[4] << 8
        D = [0] * 4
        a = (w0 << 1) & 0xFFFF; D[0] = (a & 0xFF) << 8; D[1] = a & 0xFF00
        a = (w1 << 1) & 0xFFFF; D[2] = (a & 0xFF) << 8; D[3] = a & 0xFF00
        y = (w2 & 0xFF00) >> 3
        for i in range(16):
            e = W(0xC, 0x8615 + y + 2 * i)
            if e == 0 or not (e & mask): words.append(0); continue
            d_ = D[(e >> 9) & 3]
            if d_ == 0: words.append(0); continue
            low = e & 0x1FF
            if d_ & 0x8000: words.append((d_ & 0xC000) | ((d_ & 0x3E00) >> 8))
            else: words.append(d_ | low)
    return words

def add_chevrons(t, curve, objs, scen):
    """Turn signs along every curve: one chevron every 4 slots from 20 slots ahead of the curve onset to the end of the curve.
    Type 9 ('<', right side of the road) for a positive curve, type 8 ('>', left side) for a negative one."""
    L, pp = t['L'], t['pitpiece']
    sw = (W(0, 0xDEE4 + 2 * t['env']) & 0x71FF) | t['roadw']          # road style word, as hook_style builds it
    i = 24
    while i < L * 32:
        a, b = s16(curve[i - 1]), s16(curve[i])
        if abs(b) >= 8 and (abs(a) < 8 or (a < 0) != (b < 0)):
            typ, side = (9, 0) if b > 0 else (8, 1)
            e = i
            while e + 1 < L * 32 and abs(s16(curve[e + 1])) >= 8 and (s16(curve[e + 1]) < 0) == (b < 0):
                e += 1
            j = i - 20
            while j <= e:
                pc = j // 32
                w = objs[j]
                if not (j < 48 or j >= L * 32 - 48 or pp - 2 <= pc <= pp or pc == L - 1 or w & 0x8000 or (w & 0xFE00) == 0x7400):
                    st_ = (sw >> (3 * (W(0, 0x9B3F + (scen[j] & 0x7FFE)) >> 2))) & 7
                    edge = abs(s16(W(0, 0xC592 + 4 * st_ + (0 if side else 2))))
                    objs[j] = (typ << 9) | (side << 8) | min(255, edge + 44)   # always 44 units outside the drawn road edge
                j += 4
            i = e + 1
        else:
            i += 1
    ta, tb = SCENERY[2 * t['env']], SCENERY[2 * t['env'] + 1]
    if ta:                                               # roadside trees/bushes in the gaps: every 8 slots, alternating sides, 60 units outside the edge
        for j in range(52, L * 32 - 48, 8):
            pc = j // 32
            if objs[j] or pp - 2 <= pc <= pp or pc == L - 1: continue
            side = (j >> 3) & 1
            st_ = (sw >> (3 * (W(0, 0x9B3F + (scen[j] & 0x7FFE)) >> 2))) & 7
            edge = abs(s16(W(0, 0xC592 + 4 * st_ + (0 if side else 2))))
            objs[j] = ((ta if (j >> 3) % 3 else tb) << 9) | (side << 8) | min(255, edge + 60)
    if t['env'] in DROPW:
        for j in list(range(WIN)) + list(range(L * 32 - WIN, L * 32)):
            w = objs[j]
            if w and not w & 0x8000 and (w >> 9) & 63 == DROPW[t['env']]: objs[j] = 0
    for i in range(64):                                  # pieces L, L+1 are copies of 0, 1
        objs[L * 32 + i] = objs[i]

def tables(t, diff=1):
    curve = expand_curve(t['curve']); objs = expand_objs(t['recs'], diff)
    scen = expand_scen(t['scen'])
    add_chevrons(t, curve, objs, scen)
    return dict(slope=expand_slope(t['slope']), curve=curve, scen=scen, objs=objs)

# ---------------------------------------------------------------- validation ---------------------------------
def validate(t):
    errs = []
    P, L = t['P'], t['L']
    if not (24 <= L <= 46 and 3 <= t['laps'] <= 8): errs.append('range')
    if t['slope'][0] or t['slope'][L] or t['curve'][0] or t['curve'][L]: errs.append('ends not flat')
    # continuity: last word of each piece == first word of next (in signed terms)
    for name in ('slope', 'curve'):
        w = tables(t)[name]
        for k in range(P - 1):
            if k == L: continue
            a, b = s16(w[32 * k + 31]), s16(w[32 * (k + 1)])
            if abs(a - b) > 400 and name == 'slope' or abs(a - b) > 8 and name == 'curve':
                errs.append('%s jump piece %d (%d->%d)' % (name, k, a, b)); break
    if t['scen'][t['pitpiece']] != 20: errs.append('pit scen')
    if sum(1 for x in t['scen'] if x == 20) != 1: errs.append('pit count')
    return errs

if __name__ == '__main__':
    if len(sys.argv) > 1:
        for a in sys.argv[1:]:
            t = generate(int(a, 16))
            print('seed %08X env %d L %d laps %d hill %d curvy %d pit piece %d %s pitword %04X' % (
                t['seed'], t['env'], t['L'], t['laps'], t['hill'], t['curvy'], t['pitpiece'], t['pitstyle'], t['pit']))
            print(' slope', t['slope']); print(' curve', t['curve']); print(' scen', t['scen'])
            print(' errors', validate(t))
    else:
        bad = 0
        from collections import Counter
        envc = Counter(); Lc = Counter(); lapc = Counter()
        for s in range(2000):
            t = generate(s * 2654435761 & 0xFFFFFFFF)
            e = validate(t)
            if e:
                bad += 1
                if bad < 10: print(hex(t['seed']), e)
            envc[t['env']] += 1; Lc[t['L']] += 1; lapc[t['laps']] += 1
        print('bad', bad, 'of 2000')
        print('env', sorted(envc.items())); print('L', sorted(Lc.items())); print('laps', sorted(lapc.items()))
