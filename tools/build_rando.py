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

VERSION = 'BETA 0.1'          # shown on the title screen

def title_lines():
    """(.db lines of the title text list, number of glyph sprites).  Lines are centred on pixel 135 like the original ones;
    entry = column, row, pixel offset x, y, text, 0; the list ends with a zero word.  Spaces do not take a sprite (see hooks.asm)."""
    rows = [('POWERED BY CLAUDE', 24, 4), ('PRESS START', 20, 2), ('RANDOMIZER BY PEDRO WALTER', 22, 6), ('VERSION ' + VERSION, 26, 0)]
    out, glyphs = [], 0
    for text, row, dy in rows:
        x = 135 - 4 * len(text)
        out.append('    .db %d,%d,%d,%d,"%s",0' % (x >> 3, row, x & 7, dy, text.replace('.', '=')))    # the list's code for '.' is '=' (sprite tile $88)
        glyphs += len(text.replace(' ', ''))
    return '\n'.join(out) + '\n    .dw 0', glyphs

def purple_title(rom):
    """Title screen sky: the HDMA colour table (224 words, 0D:C7FA and 0D:C8DA, blue gradient) gets red added in proportion to the
    blue so the sky turns violet."""
    for base in (0x6C7FA, 0x6C8DA):
        for i in range(112):
            o = base + 2 * i
            w = rom[o] | rom[o + 1] << 8
            r, g, b = w & 31, (w >> 5) & 31, (w >> 10) & 31
            r = min(31, r + (b * 11 + 10) // 20)
            g = g * 2 // 3
            w = r | g << 5 | b << 10
            rom[o], rom[o + 1] = w & 255, w >> 8

def build(harness=False, root='.'):
    path = os.environ.get('TOPGEAR_ROM', 'Top Gear (USA).sfc')
    rom = bytearray(open(path, 'rb').read())
    assert len(rom) == 0x80000, 'expected the 512 KB headerless USA ROM'
    rom.extend(bytes(0x80000))
    names = ['gen.asm', 'hooks.asm', 'keypad.asm', 'bar.asm'] + (['harness.asm'] if harness else [])
    text = ''
    for n in names:
        text += open(os.path.join(root, 'src', n)).read() + '\n'
        if n == 'keypad.asm':
            import bigfont
            text += bigfont.asm()
    lst, glyphs = title_lines()
    text = text.replace('@TITLE_LIST@', lst.lstrip()).replace('@TITLE_GLYPHS@', str(glyphs))
    a = Asm(rom)
    a.assemble(text, 'src/' + '+'.join(names))
    purple_title(rom)
    rom[0x77D70:0x77D72] = rom[0x77D72:0x77D74]    # small-font sprite palette 7 (0E:FD66): index 5 (red, only a few stray pixels in B, D, 8) = the outline colour
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
