#!/usr/bin/env python3 -I
"""Minimal two-pass 65816 assembler (the repo's own - no external assembler is available).

Syntax (one statement per line, ';' starts a comment):
  label:                    define a label at the current address (also  name = expr  /  .equ name expr)
  .org  expr                set the CPU address (LoROM; bytes go to the mapped ROM offset)
  .a8 .a16 .i8 .i16         set the assumed accumulator/index width (REP/SEP #imm update it automatically)
  .db/.dw/.dl  e,e,...      bytes / words / 24-bit words (also "string")
  .ds   n [,fill]           reserve n bytes
  .incbin "file"            raw bytes
  mnemonic operand          lda #1 | lda $12 | lda $1234,x | lda $7e4000,x | lda ($12),y | lda [$12],y
                            lda ($12,x) | lda $12,s | lda ($12,s),y | jmp ($1234) | jsr ($1234,x) | jml [$1234]
                            mvn $7e,$09 (byte order as in the machine code: destination bank, source bank)
  suffixes .b .w .l force 8/16/24-bit operand size (otherwise: by value; unresolved forward labels -> 16 bit,
  24 bit for jsl/jml).  Expressions: numbers ($hex, 0xhex, %bin, dec), labels, + - * / % & | ^ << >> ( ) and
  lo(x) hi(x) bank(x) addr(x) (16-bit part).  '*' alone is the current address.
Usage as a module:  a = Asm(rom_bytearray); a.assemble(text, filename);  a.symbols
"""
import re, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from disasm import OP

MODES = {}
for op, (mn, mode) in OP.items():
    MODES[(mn, mode)] = op

def cpu2off(a):
    b, o = (a >> 16) & 0x7F, a & 0xFFFF
    if o < 0x8000:
        raise ValueError('address %06X not in ROM' % a)
    return (b << 15) | (o & 0x7FFF)

class AsmError(Exception): pass
class BranchRange(AsmError):
    def __init__(self, msg, line): AsmError.__init__(self, msg); self.line = line
INV = {'BCC': 'BCS', 'BCS': 'BCC', 'BEQ': 'BNE', 'BNE': 'BEQ', 'BMI': 'BPL', 'BPL': 'BMI', 'BVC': 'BVS', 'BVS': 'BVC'}

TOK = re.compile(r'\s*(\$[0-9A-Fa-f]+|0x[0-9A-Fa-f]+|%[01]+|\d+|[A-Za-z_.][\w.]*|<<|>>|[-+*/%&|^()~<>])')

class Asm:
    def __init__(self, rom):
        self.rom = rom
        self.symbols = {}
        self.pc = 0
        self.m8 = False; self.x8 = False
        self.pass_ = 1
        self.lst = []
        self.longbr = set()          # line numbers of branches that were out of range -> emitted as inverted branch + JMP
        self.curline = 0

    # ---- expressions
    def eval(self, s, allow_undef=False):
        toks = []
        pos = 0
        s = s.strip()
        while pos < len(s):
            m = TOK.match(s, pos)
            if not m: raise AsmError('bad expression: %r' % s)
            toks.append(m.group(1)); pos = m.end()
        self._t = toks; self._i = 0; self._undef = False; self._allow = allow_undef
        v = self._or()
        if self._i != len(toks): raise AsmError('junk in expression: %r' % s)
        self.last_undef = self._undef
        return v
    def _peek(self): return self._t[self._i] if self._i < len(self._t) else None
    def _next(self): t = self._peek(); self._i += 1; return t
    def _bin(self, sub, ops):
        v = sub()
        while self._peek() in ops:
            o = self._next(); r = sub()
            v = ops[o](v, r)
        return v
    def _or(self): return self._bin(self._xor, {'|': lambda a, b: a | b})
    def _xor(self): return self._bin(self._and, {'^': lambda a, b: a ^ b})
    def _and(self): return self._bin(self._sh, {'&': lambda a, b: a & b})
    def _sh(self): return self._bin(self._add, {'<<': lambda a, b: a << b, '>>': lambda a, b: a >> b})
    def _add(self): return self._bin(self._mul, {'+': lambda a, b: a + b, '-': lambda a, b: a - b})
    def _mul(self): return self._bin(self._un, {'*': lambda a, b: a * b, '/': lambda a, b: a // b if b else 0,
                                                 '%': lambda a, b: a % b if b else 0})
    def _un(self):
        t = self._next()
        if t is None: raise AsmError('unexpected end of expression')
        if t == '-': return -self._un()
        if t == '+': return self._un()
        if t == '~': return ~self._un()
        if t == '<': return self._un() & 0xFF           # low byte
        if t == '>': return (self._un() >> 8) & 0xFF    # high byte
        if t == '(':
            v = self._or()
            if self._next() != ')': raise AsmError('missing )')
            return v
        if t == '*' : return self.pc
        if t[0] == '$': return int(t[1:], 16)
        if t.startswith('0x'): return int(t, 16)
        if t[0] == '%': return int(t[1:], 2)
        if t[0].isdigit(): return int(t)
        low = t.lower()
        if low in ('lo', 'hi', 'bank', 'addr') and self._peek() == '(':
            self._next(); v = self._or()
            if self._next() != ')': raise AsmError('missing )')
            return {'lo': v & 0xFF, 'hi': (v >> 8) & 0xFF, 'bank': (v >> 16) & 0xFF, 'addr': v & 0xFFFF}[low]
        if t in self.symbols: return self.symbols[t]
        if self.pass_ == 1 or self._allow:
            self._undef = True
            return 0
        raise AsmError('undefined symbol %s' % t)

    # ---- emit
    def emit(self, bs):
        if self.pass_ == 2:
            for i, b in enumerate(bs):
                off = cpu2off(self.pc + i)
                if off >= len(self.rom): self.rom.extend(b'\0' * (off + 1 - len(self.rom)))
                self.rom[off] = b & 0xFF
        self.pc += len(bs)

    # ---- statements
    def assemble(self, text, name='<asm>'):
        while True:
            try:
                return self._assemble(text, name)
            except BranchRange as e:
                if e.line in self.longbr: raise AsmError('%s:%d: %s' % (name, e.line, e))
                self.longbr.add(e.line)

    def _assemble(self, text, name='<asm>'):
        lines = text.split('\n')
        snap = (self.m8, self.x8)
        self.symbols = {}
        self._defined = set()
        for p in (1, 2):
            self.pass_ = p
            self.m8, self.x8 = snap
            self.pc = 0
            for n, line in enumerate(lines, 1):
                self.curline = n
                try:
                    self.line(line)
                except BranchRange:
                    raise
                except AsmError as e:
                    raise AsmError('%s:%d: %s   [%s]' % (name, n, e, line.strip()))

    def line(self, line):
        # strip comments (not inside quotes)
        out = ''; q = False
        for ch in line:
            if ch == '"': q = not q
            if ch == ';' and not q: break
            out += ch
        s = out.strip()
        if not s: return
        while True:
            m = re.match(r'([A-Za-z_][\w.]*):\s*(.*)$', s)
            if not m: break
            self.define(m.group(1), self.pc); s = m.group(2)
            if not s: return
        m = re.match(r'([A-Za-z_][\w.]*)\s*=\s*(.*)$', s)
        if m:
            self.define(m.group(1), self.eval(m.group(2))); return
        parts = s.split(None, 1)
        mn = parts[0].lower(); arg = parts[1].strip() if len(parts) > 1 else ''
        if mn.startswith('.'): return self.directive(mn, arg)
        self.insn(mn, arg)

    def define(self, name, val):
        if self.pass_ == 1 and name in self.symbols and self.symbols[name] != val and name in self._defined:
            raise AsmError('duplicate label %s' % name)
        if self.pass_ == 1:
            self._defined.add(name)
        self.symbols[name] = val
    _defined = set()

    def directive(self, d, arg):
        if d == '.org': self.pc = self.eval(arg)
        elif d == '.a8': self.m8 = True
        elif d == '.a16': self.m8 = False
        elif d == '.i8': self.x8 = True
        elif d == '.i16': self.x8 = False
        elif d == '.equ':
            n, e = arg.split(None, 1); self.define(n, self.eval(e))
        elif d in ('.db', '.dw', '.dl'):
            w = {'.db': 1, '.dw': 2, '.dl': 3}[d]
            for item in self.split_args(arg):
                if item.startswith('"'):
                    self.emit(list(item.strip('"').encode('latin1')))
                else:
                    self.emit(list((self.eval(item) & ((1 << 8 * w) - 1)).to_bytes(w, 'little')))
        elif d == '.ds':
            a = self.split_args(arg)
            self.emit([self.eval(a[1]) if len(a) > 1 else 0] * self.eval(a[0]))
        elif d == '.incbin':
            self.emit(list(open(arg.strip('"'), 'rb').read()))
        else:
            raise AsmError('unknown directive ' + d)

    @staticmethod
    def split_args(s):
        res = []; cur = ''; q = False; depth = 0
        for ch in s:
            if ch == '"': q = not q
            if not q:
                if ch in '([': depth += 1
                if ch in ')]': depth -= 1
                if ch == ',' and depth == 0:
                    res.append(cur.strip()); cur = ''; continue
            cur += ch
        if cur.strip(): res.append(cur.strip())
        return res

    # ---- instructions
    def insn(self, mn, arg):
        force = None
        if '.' in mn:
            mn, sfx = mn.split('.', 1)
            force = {'b': 1, 'w': 2, 'l': 3}[sfx]
        MN = mn.upper()
        if MN in ('BCC', 'BCS', 'BEQ', 'BNE', 'BMI', 'BPL', 'BVC', 'BVS', 'BRA') :
            t = self.eval(arg)
            if self.curline in self.longbr:
                if MN == 'BRA': return self.emit([0x4C] + list((t & 0xFFFF).to_bytes(2, 'little')))
                return self.emit([MODES[(INV[MN], 'rel')], 3, 0x4C] + list((t & 0xFFFF).to_bytes(2, 'little')))
            rel = t - (self.pc + 2)
            if self.pass_ == 2 and not -128 <= rel <= 127: raise BranchRange('branch out of range (%d)' % rel, self.curline)
            return self.emit([MODES[(MN, 'rel')], rel & 0xFF])
        if MN in ('BRL', 'PER'):
            t = self.eval(arg); rel = t - (self.pc + 3)
            return self.emit([MODES[(MN, 'rell')]] + list((rel & 0xFFFF).to_bytes(2, 'little')))
        if MN in ('MVN', 'MVP'):
            a, b = self.split_args(arg)
            return self.emit([MODES[(MN, 'blk')], self.eval(a) & 0xFF, self.eval(b) & 0xFF])
        a = arg.strip()
        if a == '' or a.lower() == 'a':
            mode = 'acc' if (MN, 'acc') in MODES and (a.lower() == 'a' or MN in ('ASL', 'LSR', 'ROL', 'ROR', 'INC', 'DEC')) else 'imp'
            if (MN, mode) not in MODES: mode = 'imp' if (MN, 'imp') in MODES else 'acc'
            return self.emit([MODES[(MN, mode)]])
        if a.startswith('#'):
            v = self.eval(a[1:])
            if (MN, 'imm8') in MODES or (MN, 'sig') in MODES:
                op = MODES.get((MN, 'imm8')) or MODES[(MN, 'sig')]
                if MN == 'REP': self.m8 = self.m8 and not (v & 0x20); self.x8 = self.x8 and not (v & 0x10)
                if MN == 'SEP': self.m8 = self.m8 or bool(v & 0x20); self.x8 = self.x8 or bool(v & 0x10)
                return self.emit([op, v & 0xFF])
            if (MN, 'immm') in MODES: op = MODES[(MN, 'immm')]; w8 = self.m8
            else: op = MODES[(MN, 'immx')]; w8 = self.x8
            if force: w8 = force == 1
            return self.emit([op] + list((v & (0xFF if w8 else 0xFFFF)).to_bytes(1 if w8 else 2, 'little')))
        # indirect forms
        m = re.match(r'^\((.*),\s*[sS]\s*\)\s*,\s*[yY]$', a)
        if m: return self.emit([MODES[(MN, 'sriy')], self.eval(m.group(1)) & 0xFF])
        m = re.match(r'^\((.*),\s*[xX]\s*\)$', a)
        if m:
            v = self.eval(m.group(1))
            if (MN, 'absindx') in MODES: return self.emit([MODES[(MN, 'absindx')]] + list((v & 0xFFFF).to_bytes(2, 'little')))
            return self.emit([MODES[(MN, 'indx')], v & 0xFF])
        m = re.match(r'^\((.*)\)\s*,\s*[yY]$', a)
        if m: return self.emit([MODES[(MN, 'indy')], self.eval(m.group(1)) & 0xFF])
        m = re.match(r'^\[(.*)\]\s*,\s*[yY]$', a)
        if m: return self.emit([MODES[(MN, 'indly')], self.eval(m.group(1)) & 0xFF])
        m = re.match(r'^\[(.*)\]$', a)
        if m:
            v = self.eval(m.group(1))
            if (MN, 'absindl') in MODES: return self.emit([MODES[(MN, 'absindl')]] + list((v & 0xFFFF).to_bytes(2, 'little')))
            return self.emit([MODES[(MN, 'indl')], v & 0xFF])
        m = re.match(r'^\((.*)\)$', a)
        if m and not re.search(r'\)\s*[-+*/&|]', a):
            v = self.eval(m.group(1))
            if (MN, 'absind') in MODES: return self.emit([MODES[(MN, 'absind')]] + list((v & 0xFFFF).to_bytes(2, 'little')))
            return self.emit([MODES[(MN, 'ind')], v & 0xFF])
        idx = ''
        m = re.match(r'^(.*),\s*([xXyYsS])$', a)
        if m: a, idx = m.group(1), m.group(2).lower()
        if force is None:                      # $0012 (4 hex digits) means absolute, $12 direct page, $123456 long
            if re.match(r'^\$[0-9A-Fa-f]{4}$', a.strip()): force = 2
            elif re.match(r'^\$[0-9A-Fa-f]{6}$', a.strip()): force = 3
        v = self.eval(a)
        und = self.last_undef
        if idx == 's': return self.emit([MODES[(MN, 'sr')], v & 0xFF])
        if MN in ('JSL', 'JML') or (MN == 'JMP' and force == 3):
            MN2 = {'JMP': 'JML'}.get(MN, MN)
            return self.emit([MODES[(MN2, 'long')]] + list((v & 0xFFFFFF).to_bytes(3, 'little')))
        if MN in ('JSR', 'JMP', 'PEA'):
            return self.emit([MODES[(MN, 'abs')]] + list((v & 0xFFFF).to_bytes(2, 'little')))
        suffix = {'': '', 'x': 'x', 'y': 'y'}[idx]
        order = [('dp' + suffix, 1), ('abs' + suffix, 2), ('long' + suffix, 3)] if suffix != 'y' else [('dpy', 1), ('absy', 2)]
        if suffix == '': order = [('dp', 1), ('abs', 2), ('long', 3)]
        if suffix == 'x': order = [('dpx', 1), ('absx', 2), ('longx', 3)]
        want = force or (1 if 0 <= v < 0x100 else 2 if v < 0x10000 else 3)
        if und and not force: want = 2
        for mode, w in order:
            if w >= want and (MN, mode) in MODES:
                return self.emit([MODES[(MN, mode)]] + list((v & ((1 << 8 * w) - 1)).to_bytes(w, 'little')))
        raise AsmError('no addressing mode for %s %s' % (MN, arg))

def assemble_file(rom, path):
    a = Asm(rom)
    a.assemble(open(path).read(), path)
    return a

if __name__ == '__main__':
    # self test: assemble a snippet, compare with known machine code
    rom = bytearray(0x10000)
    a = Asm(rom)
    a.assemble("""
    .org $008000
    .a16
    .i16
    start: rep #$30
      lda #$1234
      sta $7e4000,x
      lda ($22),y
      bpl start
      jsr start
      jml start
      mvn $7e,$09
      sep #$20
      lda #$7f
      xba
      asl a
      inc $1f06
    """)
    print(rom[:40].hex(' '))
    exp = 'c2 30 a9 34 12 9f 00 40 7e b1 22 10 f3 20 00 80 5c 00 80 00 54 7e 09 e2 20 a9 7f eb 0a ee 06 1f'
    assert rom[:len(exp.split())].hex(' ') == exp, 'selftest mismatch'
    print('ok')
