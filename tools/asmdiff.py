#!/usr/bin/env python3 -I
"""asmdiff.py A.asm B.asm [maxlines]: instruction-level diff of two disassemblies made by tools/disasm.py.

Jump/branch targets are masked (code moves between ROM versions), and so are 16-bit absolute operands
(`$XXXX`, not immediates `#$XXXX`), so what is left are real changes plus the pointer relocations that
changed the operand's *value* (LDX #$B4A1 vs #$B481). Use `--all` to also list pure operand relocations.
Used for docs/15 (USA vs Europe vs Japan). Disassemble each ROM with its own trace/WRAM image first:
  tools/mesen.sh scripts/trace.lua  (TG_ROM=...)  ->  tools/disasm.py ROM out.asm --seeds trace --wram wram_3300.bin
"""
import re, sys, difflib

BR = ('JSR', 'JMP', 'JSL', 'JML', 'BRA', 'BRL', 'BEQ', 'BNE', 'BCC', 'BCS', 'BMI', 'BPL', 'BVC', 'BVS')

def load(path):
    out = []
    for l in open(path):
        m = re.match(r'  ([0-9A-F]{6})  ((?:[0-9A-F]{2} )+)\s*(\S.*?)(\s+;.*)?$', l.rstrip('\n'))
        if not m:
            continue
        text = m.group(3)
        mn = text.split()[0]
        key = mn + ' T' if mn in BR else text
        out.append((int(m.group(1), 16), text, key))
    return out

def norm(text):
    return re.sub(r'(?<![#])\$[0-9A-F]{4}\b', '$X', text)

def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    show_all = '--all' in sys.argv
    a, b = load(args[0]), load(args[1])
    cap = int(args[2]) if len(args) > 2 else 12
    sm = difflib.SequenceMatcher(None, [x[2] for x in a], [x[2] for x in b], autojunk=False)
    n = 0
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == 'equal':
            continue
        old, new = a[i1:i2], b[j1:j2]
        if not show_all and [norm(x[1]) for x in old] == [norm(x[1]) for x in new]:
            continue
        n += 1
        print(f'--- {tag} A {old[0][0]:06X}..{old[-1][0]:06X} ({len(old)})  B {new[0][0]:06X}..{new[-1][0]:06X} ({len(new)})' if old and new else f'--- {tag} A@{(old or a[i1:i1+1])[0][0]:06X} B@{(new or b[j1:j1+1])[0][0]:06X}')
        for x in old[:cap]:
            print('  -', f'{x[0]:06X}', x[1])
        for x in new[:cap]:
            print('  +', f'{x[0]:06X}', x[1])
    print(n, 'blocks', file=sys.stderr)

main()
