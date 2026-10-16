#!/usr/bin/env python3 -I
"""Compare the 65816 generator (run in headless Mesen via the harness ROM) with tools/trackgen.py.
Usage: tools/rando_test.py [count]   (default 200 seeds)"""
import sys, os, struct, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trackgen as tg
from build_rando import build

n = int(sys.argv[1]) if len(sys.argv) > 1 else 200
seeds = [0, 1, 0x12345678, 0xFFFFFFFF] + [(i * 2654435761 + 12345) & 0xFFFFFFFF for i in range(n - 4)]
os.makedirs('out', exist_ok=True)
rom, a = build(harness=True)
open('out/rando_harness.sfc', 'wb').write(rom)
open('out/rando_harness.lua', 'w').write('SYM={\n' + ''.join('  %s=0x%06X,\n' % (k, v) for k, v in a.symbols.items() if v < 0x1000000) + '}\n')
open('out/rando_seeds.txt', 'w').write(''.join('%08X\n' % s for s in seeds))
if os.path.exists('out/rando_dump.bin'): os.remove('out/rando_dump.bin')
env = dict(os.environ, TG_ROM=os.path.abspath('out/rando_harness.sfc'))
subprocess.run('tools/mesen.sh scripts/rando_test.lua 2>&1 | grep -v Uninit | tail -5', shell=True, env=env)
d = open('out/rando_dump.bin', 'rb').read()
pos = 0; bad = 0; done = 0
for s in seeds:
    if pos >= len(d): break
    seed, env_, L, laps, pit, P = struct.unpack_from('<IHHHHH', d, pos); pos += 14
    t = tg.generate(s)
    tb = tg.tables(t, 1)
    errs = []
    if seed != s: errs.append('seed %08X' % seed)
    if (env_, L, laps, pit, P) != (t['env'], t['L'], t['laps'], t['pit'], t['P']):
        errs.append('scalars got %s want %s' % ((env_, L, laps, hex(pit), P), (t['env'], t['L'], t['laps'], hex(t['pit']), t['P'])))
    for name in ('slope', 'curve', 'scen', 'objs'):
        got = struct.unpack_from('<%dH' % (P * 32), d, pos); pos += P * 64
        if list(got) != tb[name]:
            dif = [i for i in range(min(len(got), len(tb[name]))) if got[i] != tb[name][i]]
            errs.append('%s differs at %d words (first %s)' % (name, len(dif), dif[:3]))
    sl = struct.unpack_from('<48H', d, pos); pos += 96
    cu = struct.unpack_from('<48H', d, pos); pos += 96
    if list(sl[:P]) != t['slope']: errs.append('slope ids %s want %s' % (list(sl[:P]), t['slope']))
    elif list(cu[:P]) != t['curve']: errs.append('curve ids %s want %s' % (list(cu[:P]), t['curve']))
    done += 1
    if errs:
        bad += 1
        if bad <= 8: print('%08X' % s, errs)
print('compared %d seeds, %d mismatches' % (done, bad))
