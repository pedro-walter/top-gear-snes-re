"""Finds, per environment, which object types must be dropped so that the start gantry is drawn (see docs/10).
usage: python3 -I tools/gantry_search.py [env ...]   -> out/gantry_drop.json (needs out/rando.sfc, out/env_seeds.txt)"""
import json, os, subprocess, sys, itertools
sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
import trackgen as g
from collections import Counter
from PIL import Image, ImageChops
ROOT = os.getcwd()
seeds = {int(a): b for a, b in (l.split() for l in open('out/env_seeds.txt'))}
def run(seed, mode):
    env = dict(os.environ, MODE=mode, TG_ROM=ROOT + '/out/rando.sfc', TG_ROOT=ROOT, SEED=seed, TAG='gs')
    subprocess.run(['tools/mesen2.sh', 'scripts/rando_gantry2.lua'], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return Image.open('out/gs_%s_pos.png' % mode).convert('RGB').crop((116, 10, 160, 30))
def diff(a, b): return sum(1 for p in ImageChops.difference(a, b).getdata() if sum(p) > 60)
def types(env):
    d = g.descriptor(env); n = d['nelem'] + 1
    recs = [[g.B(0xC, d['objs'] + 5 * r + i) for i in range(5)] for r in range(2 * n)]
    c = Counter((x >> 9) & 0x7F for x in g.expand_objs(recs, 1) if x and x < 0x8000)
    return [t for t, _ in c.most_common() if t not in (8, 9, 13, 21, 58)]
res = json.load(open('out/gantry_drop.json')) if os.path.exists('out/gantry_drop.json') else {}
for env in (map(int, sys.argv[1:]) or range(32)):
    s = seeds[env]
    ref = run(s, 'all')
    ok = lambda mode: diff(run(s, mode), ref) < 60
    if ok('none'): res[str(env)] = []
    else:
        found = None
        ts = types(env)
        for k in (1, 2, 3):
            for combo in itertools.combinations(ts, k):
                if ok('t' + '_'.join(map(str, combo))): found = list(combo); break
            if found: break
        res[str(env)] = found
    print(env, res[str(env)], flush=True)
    json.dump(res, open('out/gantry_drop.json', 'w'))
