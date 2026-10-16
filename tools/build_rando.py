#!/usr/bin/env python3 -I
"""Build the randomizer ROM:  python3 -I tools/build_rando.py [--harness] [-o out/rando.sfc]
Original ROM (env TOPGEAR_ROM or 'Top Gear (USA).sfc') -> 1 MB image + src/*.asm assembled in. The original is never modified.
--harness additionally redirects the reset vector to a loop that runs the generator (for tests/rando_test.py)."""
import sys, os, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asm65816 import Asm

def fix_header(rom):
    rom[0x7FD7] = 0x0A                                   # 1 MB
    rom[0x7FDC:0x7FE0] = b'\0\0\0\0'
    s = sum(rom) & 0xFFFF
    rom[0x7FDE] = s & 0xFF; rom[0x7FDF] = s >> 8
    c = s ^ 0xFFFF
    rom[0x7FDC] = c & 0xFF; rom[0x7FDD] = c >> 8

def build(harness=False, root='.'):
    path = os.environ.get('TOPGEAR_ROM', 'Top Gear (USA).sfc')
    rom = bytearray(open(path, 'rb').read())
    assert len(rom) == 0x80000, 'expected the 512 KB headerless USA ROM'
    rom.extend(bytes(0x80000))
    names = ['gen.asm', 'hooks.asm'] + (['harness.asm'] if harness else [])
    text = ''
    for n in names:
        text += open(os.path.join(root, 'src', n)).read() + '\n'
    a = Asm(rom)
    a.assemble(text, 'src/' + '+'.join(names))
    fix_header(rom)
    return rom, a

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--harness', action='store_true')
    ap.add_argument('-o', default=None)
    ar = ap.parse_args()
    rom, a = build(ar.harness)
    out = ar.o or ('out/rando_harness.sfc' if ar.harness else 'out/rando.sfc')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, 'wb').write(rom)
    with open(out[:-4] + '.lua', 'w') as f:
        f.write('SYM={\n' + ''.join('  %s=0x%06X,\n' % (k, v) for k, v in sorted(a.symbols.items()) if v < 0x1000000) + '}\n')
    if not ar.harness:
        # Mesen auto-applies <rom name>.ips: a stale patch next to the ROM silently corrupts it, so refresh it on every build
        import make_ips
        orig = bytearray(open(os.environ.get('TOPGEAR_ROM', 'Top Gear (USA).sfc'), 'rb').read())
        orig.extend(bytes(len(rom) - len(orig)))
        open(out[:-4] + '.ips', 'wb').write(make_ips.ips(orig, rom))
    print('wrote', out, len(rom), 'bytes;', 'gen end', hex(max(v for k, v in a.symbols.items() if k in ('pit_styles',))))
