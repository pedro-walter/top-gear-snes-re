#!/usr/bin/env python3
"""65816 recursive-descent disassembler for the Top Gear LoROM image.

Tracks the M/X register-width flags through REP/SEP/PHP/PLP/XCE so immediate
operands decode with the right length. Extra entry points (e.g. from a runtime
trace) are read from a seeds file: one line per seed, "BBAAAA m x" (hex addr,
m/x = 1 for 8-bit, 0 for 16-bit).

Usage: disasm.py ROM OUT.asm [--seeds seeds.txt] [--names names.txt]
names.txt lines: "BBAAAA label_name" override auto labels.
"""
import sys, argparse, collections

# ---- opcode table: (mnemonic, mode) -------------------------------------
T = """
00 BRK sig;01 ORA indx;02 COP sig;03 ORA sr;04 TSB dp;05 ORA dp;06 ASL dp;07 ORA indl;
08 PHP imp;09 ORA immm;0A ASL acc;0B PHD imp;0C TSB abs;0D ORA abs;0E ASL abs;0F ORA long;
10 BPL rel;11 ORA indy;12 ORA ind;13 ORA sriy;14 TRB dp;15 ORA dpx;16 ASL dpx;17 ORA indly;
18 CLC imp;19 ORA absy;1A INC acc;1B TCS imp;1C TRB abs;1D ORA absx;1E ASL absx;1F ORA longx;
20 JSR abs;21 AND indx;22 JSL long;23 AND sr;24 BIT dp;25 AND dp;26 ROL dp;27 AND indl;
28 PLP imp;29 AND immm;2A ROL acc;2B PLD imp;2C BIT abs;2D AND abs;2E ROL abs;2F AND long;
30 BMI rel;31 AND indy;32 AND ind;33 AND sriy;34 BIT dpx;35 AND dpx;36 ROL dpx;37 AND indly;
38 SEC imp;39 AND absy;3A DEC acc;3B TSC imp;3C BIT absx;3D AND absx;3E ROL absx;3F AND longx;
40 RTI imp;41 EOR indx;42 WDM sig;43 EOR sr;44 MVP blk;45 EOR dp;46 LSR dp;47 EOR indl;
48 PHA imp;49 EOR immm;4A LSR acc;4B PHK imp;4C JMP abs;4D EOR abs;4E LSR abs;4F EOR long;
50 BVC rel;51 EOR indy;52 EOR ind;53 EOR sriy;54 MVN blk;55 EOR dpx;56 LSR dpx;57 EOR indly;
58 CLI imp;59 EOR absy;5A PHY imp;5B TCD imp;5C JML long;5D EOR absx;5E LSR absx;5F EOR longx;
60 RTS imp;61 ADC indx;62 PER rell;63 ADC sr;64 STZ dp;65 ADC dp;66 ROR dp;67 ADC indl;
68 PLA imp;69 ADC immm;6A ROR acc;6B RTL imp;6C JMP absind;6D ADC abs;6E ROR abs;6F ADC long;
70 BVS rel;71 ADC indy;72 ADC ind;73 ADC sriy;74 STZ dpx;75 ADC dpx;76 ROR dpx;77 ADC indly;
78 SEI imp;79 ADC absy;7A PLY imp;7B TDC imp;7C JMP absindx;7D ADC absx;7E ROR absx;7F ADC longx;
80 BRA rel;81 STA indx;82 BRL rell;83 STA sr;84 STY dp;85 STA dp;86 STX dp;87 STA indl;
88 DEY imp;89 BIT immm;8A TXA imp;8B PHB imp;8C STY abs;8D STA abs;8E STX abs;8F STA long;
90 BCC rel;91 STA indy;92 STA ind;93 STA sriy;94 STY dpx;95 STA dpx;96 STX dpy;97 STA indly;
98 TYA imp;99 STA absy;9A TXS imp;9B TXY imp;9C STZ abs;9D STA absx;9E STZ absx;9F STA longx;
A0 LDY immx;A1 LDA indx;A2 LDX immx;A3 LDA sr;A4 LDY dp;A5 LDA dp;A6 LDX dp;A7 LDA indl;
A8 TAY imp;A9 LDA immm;AA TAX imp;AB PLB imp;AC LDY abs;AD LDA abs;AE LDX abs;AF LDA long;
B0 BCS rel;B1 LDA indy;B2 LDA ind;B3 LDA sriy;B4 LDY dpx;B5 LDA dpx;B6 LDX dpy;B7 LDA indly;
B8 CLV imp;B9 LDA absy;BA TSX imp;BB TYX imp;BC LDY absx;BD LDA absx;BE LDX absy;BF LDA longx;
C0 CPY immx;C1 CMP indx;C2 REP imm8;C3 CMP sr;C4 CPY dp;C5 CMP dp;C6 DEC dp;C7 CMP indl;
C8 INY imp;C9 CMP immm;CA DEX imp;CB WAI imp;CC CPY abs;CD CMP abs;CE DEC abs;CF CMP long;
D0 BNE rel;D1 CMP indy;D2 CMP ind;D3 CMP sriy;D4 PEI ind;D5 CMP dpx;D6 DEC dpx;D7 CMP indly;
D8 CLD imp;D9 CMP absy;DA PHX imp;DB STP imp;DC JML absindl;DD CMP absx;DE DEC absx;DF CMP longx;
E0 CPX immx;E1 SBC indx;E2 SEP imm8;E3 SBC sr;E4 CPX dp;E5 SBC dp;E6 INC dp;E7 SBC indl;
E8 INX imp;E9 SBC immm;EA NOP imp;EB XBA imp;EC CPX abs;ED SBC abs;EE INC abs;EF SBC long;
F0 BEQ rel;F1 SBC indy;F2 SBC ind;F3 SBC sriy;F4 PEA abs;F5 SBC dpx;F6 INC dpx;F7 SBC indly;
F8 SED imp;F9 SBC absy;FA PLX imp;FB XCE imp;FC JSR absindx;FD SBC absx;FE INC absx;FF SBC longx
"""
OP = {}
for ent in T.replace("\n", "").split(";"):
    ent = ent.strip()
    if ent:
        o, m, mode = ent.split()
        OP[int(o, 16)] = (m, mode)
assert len(OP) == 256

FIXED = dict(imp=0, acc=0, imm8=1, sig=1, dp=1, dpx=1, dpy=1, ind=1, indx=1, indy=1,
             indl=1, indly=1, sr=1, sriy=1, rel=1, abs=2, absx=2, absy=2, absind=2,
             absindx=2, absindl=2, rell=2, long=3, longx=3, blk=2)
FMT = dict(imp="", acc="A", imm8="#${0:02X}", sig="#${0:02X}", dp="${0:02X}", dpx="${0:02X},X",
           dpy="${0:02X},Y", ind="(${0:02X})", indx="(${0:02X},X)", indy="(${0:02X}),Y",
           indl="[${0:02X}]", indly="[${0:02X}],Y", sr="${0:02X},S", sriy="(${0:02X},S),Y",
           abs="${0:04X}", absx="${0:04X},X", absy="${0:04X},Y", absind="(${0:04X})",
           absindx="(${0:04X},X)", absindl="[${0:04X}]", long="${0:06X}", longx="${0:06X},X")


def l2f(a):
    """LoROM CPU address -> file offset, or None."""
    b, o = a >> 16, a & 0xFFFF
    if o < 0x8000:
        return None
    b &= 0x7F
    if b >= 0x7E:  # WRAM banks 7E/7F are RAM; FE/FF mirror ROM
        if (a >> 16) < 0x80:
            return None
    return ((b << 15) | (o & 0x7FFF))


class Rom:
    def __init__(self, path, wram=None):
        self.d = open(path, "rb").read()
        if len(self.d) % 0x8000 == 0x200:
            self.d = self.d[0x200:]
        self.size = len(self.d)
        self.wram = open(wram, "rb").read() if wram else None

    def rd(self, a):
        b = a >> 16
        if b in (0x7E, 0x7F) or (b == 0 and (a & 0xFFFF) < 0x2000):
            if self.wram is None:
                return None
            return self.wram[((b & 1) << 16 | (a & 0xFFFF)) if b else (a & 0xFFFF)]
        f = l2f(a)
        if f is None or f >= self.size:
            return None
        return self.d[f]

    def rd16(self, a):
        lo, hi = self.rd(a), self.rd(a + 1)
        return None if lo is None or hi is None else lo | hi << 8


class Insn:
    __slots__ = ("addr", "len", "op", "mn", "mode", "operand", "m", "x", "target")


def decode(rom, a, m, x):
    op = rom.rd(a)
    if op is None:
        return None
    mn, mode = OP[op]
    n = FIXED.get(mode)
    if mode == "immm":
        n = 1 if m else 2
    elif mode == "immx":
        n = 1 if x else 2
    if n is None:
        return None
    raw = [rom.rd(a + 1 + i) for i in range(n)]
    if any(v is None for v in raw):
        return None
    val = int.from_bytes(bytes(raw), "little") if n else 0
    i = Insn()
    i.addr, i.len, i.op, i.mn, i.mode, i.operand, i.m, i.x = a, 1 + n, op, mn, mode, val, m, x
    i.target = None
    bank = a >> 16
    if mode == "rel":
        off = val - 256 if val >= 128 else val
        i.target = (bank << 16) | ((a + 2 + off) & 0xFFFF)
    elif mode == "rell":
        off = val - 65536 if val >= 32768 else val
        i.target = (bank << 16) | ((a + 3 + off) & 0xFFFF)
    elif mode == "abs" and mn in ("JSR", "JMP"):
        i.target = (bank << 16) | val
    elif mode in ("long",) and mn in ("JSL", "JML"):
        i.target = val
    return i


ENDS = {"RTS", "RTL", "RTI", "JMP", "JML", "BRA", "BRL", "STP", "BRK"}


def explore(rom, seeds):
    code = {}                       # addr -> Insn (first decode wins)
    covered = {}                    # byte addr -> insn start
    seen = set()
    labels = collections.defaultdict(set)   # addr -> kinds
    jumptables = []                 # (addr, mn) of unresolved indirect jumps
    work = [(a, m, x, ()) for a, m, x in seeds]
    conflicts = []
    while work:
        a, m, x, stk = work.pop()
        while True:
            if (a, m, x) in seen:
                break
            ins = decode(rom, a, m, x)
            if ins is None:
                break
            if a in code and (code[a].m, code[a].x) != (m, x) and code[a].len != ins.len:
                conflicts.append((a, (code[a].m, code[a].x), (m, x)))
            seen.add((a, m, x))
            if a not in code:
                code[a] = ins
                for k in range(ins.len):
                    covered.setdefault(a + k, a)
            mn = ins.mn
            nm, nx = m, x
            if mn == "REP":
                nm = 0 if ins.operand & 0x20 else m
                nx = 0 if ins.operand & 0x10 else x
            elif mn == "SEP":
                nm = 1 if ins.operand & 0x20 else m
                nx = 1 if ins.operand & 0x10 else x
            elif mn == "PHP":
                stk = stk + ((m, x),)
            elif mn == "PLP":
                if stk:
                    nm, nx = stk[-1]
                    stk = stk[:-1]
            if ins.target is not None:
                if mn == "JSR" or mn == "JSL":
                    labels[ins.target].add("sub")
                    work.append((ins.target, m, x, ()))
                elif mn in ("JMP", "JML"):
                    labels[ins.target].add("jmp")
                    work.append((ins.target, m, x, ()))
                else:
                    labels[ins.target].add("loc")
                    work.append((ins.target, nm, nx, stk))
            elif mn in ("JMP", "JML", "JSR") and ins.mode in ("absind", "absindx", "absindl"):
                jumptables.append((a, mn))
            if mn in ENDS:
                break
            a += ins.len
            m, x = nm, nx
    return code, covered, labels, jumptables, conflicts


def fmt_insn(ins, rom, lab):
    """'RAWBYTES  MNEMONIC operand' text for one instruction."""
    a = ins.addr
    ops = FMT.get(ins.mode)
    if ins.mode in ("rel", "rell") or ins.target is not None:
        t = lab(ins.target)
        txt = t if t else "$%06X" % ins.target
        if ins.mode == "abs":
            txt = t if t else "$%04X" % (ins.target & 0xFFFF)
    elif ins.mode == "immm":
        txt = ("#$%02X" if ins.m else "#$%04X") % ins.operand
    elif ins.mode == "immx":
        txt = ("#$%02X" if ins.x else "#$%04X") % ins.operand
    elif ins.mode == "blk":
        txt = "$%02X,$%02X" % (ins.operand & 0xFF, ins.operand >> 8)
    else:
        txt = ops.format(ins.operand)
    raw = " ".join("%02X" % rom.rd(a + k) for k in range(ins.len))
    return "%-11s %s %s" % (raw, ins.mn, txt)



STORE_MN = {"STA", "STX", "STY", "STZ", "INC", "DEC", "ASL", "LSR", "ROL", "ROR", "TSB", "TRB"}
A_WRITERS = {"LDA", "PLA", "TXA", "TYA", "TDC", "TSC", "ADC", "SBC", "AND", "ORA", "EOR", "ASL", "LSR",
             "ROL", "ROR", "INC", "DEC", "XBA", "MVN", "MVP"}
DMA_REGS = ["DMAP", "BBAD", "A1TL", "A1TH", "A1B", "DASL", "DASH", "DASB", "A2AL", "A2AH", "NTRL"]


class Annot:
    """Hand-written knowledge: WRAM variable names, hardware registers, routine docs, inline comments."""

    def __init__(self, d):
        self.ram = {}      # addr -> (size, name, desc)
        self.hw = {}       # addr -> (name, desc)
        self.doc = {}      # addr -> [lines]
        self.sym = {}      # addr -> name
        self.cmt = {}      # addr -> text
        self.regions = []  # (lo, hi, kind, text)
        self.banks = {}    # bank -> text
        if not d:
            return
        import os
        def rd(n):
            p = os.path.join(d, n)
            return open(p).read().split("\n") if os.path.exists(p) else []
        for ln in rd("ram.txt"):
            if ln.startswith("#") or not ln.strip():
                continue
            p = ln.split(None, 3)
            self.ram[int(p[0], 16)] = (1 if p[1] == "b" else 2, p[2], p[3] if len(p) > 3 else "")
        for ln in rd("hwregs.txt"):
            if ln.startswith("#") or not ln.strip():
                continue
            p = ln.split(None, 2)
            self.hw.setdefault(int(p[0], 16), (p[1], p[2] if len(p) > 2 else ""))
        cur = None
        for ln in rd("symbols.txt"):
            if ln.startswith("@"):
                p = ln[1:].split(None, 1)
                cur = int(p[0], 16)
                self.sym[cur] = p[1].strip() if len(p) > 1 else None
                self.doc[cur] = []
            elif ln.startswith(";;") and cur is not None:
                self.doc[cur].append(ln[2:].strip())
            elif ln.strip() and not ln.startswith("#"):
                cur = None
        for ln in rd("comments.txt"):
            if ln.startswith("#") or not ln.strip():
                continue
            p = ln.split(None, 1)
            self.cmt[int(p[0], 16)] = p[1].strip() if len(p) > 1 else ""
        for ln in rd("regions.txt"):
            if ln.startswith("#") or not ln.strip():
                continue
            if ln.startswith("bank "):
                p = ln.split(None, 2)
                self.banks[int(p[1], 16)] = p[2]
                continue
            p = ln.split(None, 2)
            lo, hi = p[0].split("-")
            self.regions.append((int(lo, 16), int(hi, 16), p[1], p[2] if len(p) > 2 else ""))
        self.regions.sort()

    def ram_name(self, a):
        """Name for WRAM address a (0..0x1FFF or 0x7Exxxx), with +offset into a table."""
        a &= 0xFFFF if a >> 16 in (0, 0x7E) else a
        if a in self.ram:
            return self.ram[a][1]
        for back in range(1, 4):
            e = self.ram.get(a - back)
            if e and e[0] > back:
                return "%s+%d" % (e[1], back)
        return None

    def hw_name(self, a):
        if a in self.hw:
            return self.hw[a][0]
        if 0x4300 <= a <= 0x437F:
            ch, r = (a >> 4) & 7, a & 0xF
            if r < len(DMA_REGS):
                return "%s%d" % (DMA_REGS[r], ch)
        return None

    def operand_comment(self, ins):
        """Annotation for the operand of one instruction, or None."""
        mode, v = ins.mode, ins.operand
        if mode in ("abs", "absx", "absy") and ins.mn not in ("JSR", "JMP"):
            if 0x2100 <= v <= 0x437F:
                n = self.hw_name(v)
                return n
            if v < 0x2000:
                return self.ram_name(v)
        elif mode in ("long", "longx") and ins.mn not in ("JSL", "JML"):
            if v >> 16 in (0x7E, 0x7F):
                n = self.ram_name(v) if v >> 16 == 0x7E else None
                return n
        return None

    def has_region(self, a):
        for lo, hi, k, t in self.regions:
            if lo <= a <= hi:
                return (lo, hi, k, t)
        return None


def decode_hw(name, val):
    """Bit decode of a few important registers when the stored value is known."""
    if name == "INIDISP":
        return "%s, brightness %d" % ("forced blank" if val & 0x80 else "display on", val & 15)
    if name == "NMITIMEN":
        f = [n for b, n in ((0x80, "NMI"), (0x20, "V-IRQ"), (0x10, "H-IRQ"), (1, "auto-joypad")) if val & b]
        return "enable: " + (",".join(f) or "none")
    if name in ("MDMAEN", "HDMAEN"):
        return "channels " + ("".join(str(i) for i in range(8) if val >> i & 1) or "none")
    if name == "BGMODE":
        return "mode %d%s" % (val & 7, ", BG3 priority" if val & 8 else "")
    if name in ("TM", "TS"):
        n = [x for b, x in ((1, "BG1"), (2, "BG2"), (4, "BG3"), (8, "BG4"), (16, "OBJ")) if val & b]
        return "layers " + ",".join(n)
    if name == "COLDATA":
        ch = "".join(c for b, c in ((0x20, "R"), (0x40, "G"), (0x80, "B")) if val & b)
        return "fixed colour %s=%d" % (ch, val & 31)
    if name == "CGADSUB":
        return "%s%s, layers %02X" % ("subtract" if val & 0x80 else "add", "/half" if val & 0x40 else "", val & 0x3F)
    if name.startswith("DMAP"):
        return "%s, mode %d" % ("B->A (read)" if val & 0x80 else "A->B", val & 7)
    return None


def read_seeds(path):
    out = []
    for ln in open(path):
        p = ln.split("#")[0].split()
        if len(p) >= 3:
            out.append((int(p[0], 16), int(p[1]), int(p[2])))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("rom"); ap.add_argument("out")
    ap.add_argument("--seeds"); ap.add_argument("--names"); ap.add_argument("--wram")
    ap.add_argument("--annot", help="directory with ram.txt, hwregs.txt, symbols.txt, comments.txt, regions.txt")
    args = ap.parse_args()
    rom = Rom(args.rom, args.wram)
    an = Annot(args.annot)
    # vectors (LoROM header at 00:FFC0)
    vec = {}
    for name, off in (("COP_N", 0xFFE4), ("BRK_N", 0xFFE6), ("ABORT_N", 0xFFE8), ("NMI_N", 0xFFEA),
                      ("IRQ_N", 0xFFEE), ("COP_E", 0xFFF4), ("ABORT_E", 0xFFF8), ("NMI_E", 0xFFFA),
                      ("RESET", 0xFFFC), ("IRQ_E", 0xFFFE)):
        vec[name] = rom.rd16(off)
    seeds = [(v, 1, 1) for k, v in vec.items()
             if v and v >= 0x8000 and (k.endswith("_E") or k == "RESET")]
    # native vectors: assume 16-bit (game switches to native early); decode both 8/16 is noisy -> 8-bit
    for k in ("NMI_N", "IRQ_N", "COP_N", "BRK_N"):
        v = vec[k]
        if v and v >= 0x8000:
            seeds.append((v, 0, 0))
    if args.seeds:
        seeds += read_seeds(args.seeds)
    # canonicalise: drop RAM/IO addresses, fold 80-FF mirrors onto 00-7F
    def canon(sd):
        a, m, x = sd
        b, o = a >> 16, a & 0xFFFF
        if b in (0x7E, 0x7F):
            return (a, m, x) if rom.wram else None
        if b == 0 and o < 0x2000:
            return (0x7E0000 | o, m, x) if rom.wram else None
        return (a & 0x7FFFFF, m, x) if o >= 0x8000 else None
    seeds = [c for c in map(canon, seeds) if c]
    names = {}
    if args.names:
        for ln in open(args.names):
            p = ln.split("#")[0].split()
            if len(p) >= 2:
                names[int(p[0], 16)] = p[1]
    for a, n in an.sym.items():
        if n:
            names[a] = n
    for k, v in vec.items():
        names.setdefault(v, k.lower() + "_vec") if v else None
    names.setdefault(0x7E0000, "wram_nmi_stub")
    names.setdefault(0x7E0004, "wram_irq_stub")
    code, covered, labels, jts, conflicts = explore(rom, seeds)

    def lab(a):
        if a in names:
            return names[a]
        k = labels.get(a)
        if not k:
            return None
        pre = "sub" if "sub" in k else ("loc" if "loc" in k else "jmp")
        return "%s_%06X" % (pre, a)

    # ---- cross references: callee -> callers
    callers = collections.defaultdict(list)
    for a, ins in code.items():
        if ins.mn in ("JSR", "JSL") and ins.target is not None:
            callers[ins.target].append(a)

    def sub_summary(a):
        """Approximate extent of a routine and the variables it reads/writes/calls."""
        rd, wr, calls = collections.OrderedDict(), collections.OrderedDict(), collections.OrderedDict()
        n = 0
        while a in code and n < 600:
            ins = code[a]
            nm = an.operand_comment(ins)
            if nm:
                (wr if ins.mn in STORE_MN else rd)[nm.split("+")[0]] = 1
            if ins.mn in ("JSR", "JSL") and ins.target is not None:
                calls[lab(ins.target) or "$%06X" % ins.target] = 1
            n += 1
            if ins.mn in ("RTS", "RTL", "RTI") and not (a + ins.len in code and a + ins.len in labels
                                                         and "loc" in labels[a + ins.len]):
                break
            a += ins.len
        return rd, wr, calls, n

    state = dict(imm=None)

    def inline_comment(ins):
        """Compose the '; ...' text for one instruction."""
        parts = []
        a = ins.addr
        mn = ins.mn
        # track A immediate for register writes
        if mn == "LDA" and ins.mode == "immm":
            state["imm"] = ins.operand
        elif mn in A_WRITERS or mn in ("PLP", "REP", "SEP") and False:
            state["imm"] = None
        nm = an.operand_comment(ins)
        if nm:
            if ins.mode in ("abs", "absx", "absy") and 0x2100 <= ins.operand <= 0x437F:
                txt = nm
                base = nm.rstrip("0123456789")
                if mn == "STA" and state["imm"] is not None:
                    d = decode_hw(nm if not nm[-1].isdigit() or nm in ("BG1SC", "BG2SC", "BG3SC", "BG4SC")
                                  else base, state["imm"])
                    if d:
                        txt += " <= " + d
                parts.append(txt)
                desc = an.hw.get(ins.operand, (None, ""))[1]
                if desc and mn in ("STA", "STX", "STY", "STZ") and not parts[-1].count("<="):
                    parts.append(desc)
            else:
                e = an.ram.get(ins.operand & 0xFFFF)
                parts.append(nm + ((" - " + e[2]) if e and e[2] and a not in an.cmt else ""))
        if ins.target is not None and mn in ("JSR", "JSL", "JMP", "JML"):
            t = ins.target
            d = an.doc.get(t)
            if d:
                parts.append(d[0])
        if a in an.cmt:
            parts.append(an.cmt[a])
        if mn in ("RTS", "RTL", "RTI"):
            state["imm"] = None
        return "; " + " | ".join(parts) if parts else ""

    def emit_range(f, lo, hi, where):
        a = lo
        while a < hi:
            if a in code:
                ins = code[a]
                l = lab(a)
                if a in labels and "sub" in labels[a] or (a in an.doc and an.doc[a]):
                    # routine header
                    f.write("\n;" + "-" * 78 + "\n")
                    f.write("; %s  (%06X)\n" % (l or "sub_%06X" % a, a))
                    for t in an.doc.get(a, []):
                        f.write(";   %s\n" % t)
                    if not an.doc.get(a):
                        f.write(";   (not yet analysed)\n")
                    cs = sorted(set(callers.get(a, [])))
                    if cs:
                        f.write(";   called from: %s%s\n" % (", ".join("%06X" % c for c in cs[:8]),
                                                              " ... (%d total)" % len(cs) if len(cs) > 8 else ""))
                    rd, wr, calls, n = sub_summary(a)
                    if rd:
                        f.write(";   reads : %s\n" % ", ".join(list(rd)[:14]))
                    if wr:
                        f.write(";   writes: %s\n" % ", ".join(list(wr)[:14]))
                    if calls:
                        f.write(";   calls : %s\n" % ", ".join(list(calls)[:12]))
                    f.write(";" + "-" * 78 + "\n")
                    state["imm"] = None
                if l:
                    f.write("%s:\n" % l)
                    if "loc" in labels.get(a, ()) and "sub" not in labels.get(a, ()):
                        state["imm"] = None
                c = inline_comment(ins)
                txt = fmt_insn(ins, rom, lab)
                f.write("  %06X  %-40s %s\n" % (a, txt, c) if c else "  %06X  %s\n" % (a, txt))
                a += ins.len
            else:
                reg = an.has_region(a)
                if reg and (a == reg[0] or a == lo):
                    f.write("\n; ---- data %06X-%06X [%s] %s\n" % (reg[0], reg[1], reg[2], reg[3]))
                step = 16
                kind = reg[2] if reg else "db"
                if kind == "dw" or kind == "ptr":
                    step = 16
                n = 0
                lim = (reg[1] + 1) if reg else hi
                while a + n < min(hi, lim) and (a + n) not in covered and n < step:
                    if n and (lab(a + n) or (reg and a + n == reg[0])):
                        break
                    n += 1
                l = lab(a)
                if l:
                    f.write("%s:\n" % l)
                if kind in ("dw", "ptr") and n >= 2:
                    n -= n & 1
                    ws = ",".join("$%04X" % (rom.rd(a + k) | rom.rd(a + k + 1) << 8) for k in range(0, n, 2))
                    f.write("  %06X  .dw %s\n" % (a, ws))
                else:
                    f.write("  %06X  .db %s\n" % (a, ",".join("$%02X" % rom.rd(a + k) for k in range(n))))
                a += n

    ncode = sum(i.len for i in code.values())
    with open(args.out, "w") as f:
        f.write("; Top Gear (USA) annotated disassembly - generated by tools/disasm.py\n")
        f.write("; DO NOT COMMIT: contains ROM-derived code/data. Rebuild with `make disasm`.\n")
        f.write("; Hand-written knowledge lives in disasm/annot/*.txt (symbols, ram, comments, regions) and docs/.\n")
        f.write("; vectors: " + ", ".join("%s=%04X" % (k, v) for k, v in vec.items()) + "\n")
        f.write("; code bytes: %d / %d (%.1f%%)\n; unresolved indirect jumps: %d\n" %
                (ncode, rom.size, 100.0 * ncode / rom.size, len(jts)))
        f.write("; Operand comments assume DBR=0 / DP=0 (true for nearly all game code); bank 05 car code uses\n")
        f.write("; DP=$0200 in places, so '$19,X' style operands there are car-record offsets.\n")
        nbanks = rom.size // 0x8000
        for b in range(nbanks):
            base = (b << 16) | 0x8000
            f.write("\n\n; " + "=" * 78 + "\n; ===== bank $%02X =====  %s\n; " % (b, an.banks.get(b, "")) + "=" * 78 + "\n")
            emit_range(f, base, base + 0x8000, "rom")
        if rom.wram:
            for lo, hi, title in ((0x7E0000, 0x7E0010, "WRAM interrupt stubs"),
                                  (0x7E2000, 0x7E3700, "WRAM-resident engine code (decompressed from ROM at boot)")):
                f.write("\n\n; ===== %s =====\n" % title)
                emit_range(f, lo, hi, "wram")
        if jts:
            f.write("\n; unresolved indirect jumps (jump tables):\n")
            for a, mn in jts:
                f.write(";   %06X %s\n" % (a, mn))
    print("code bytes %d/%d (%.1f%%), subs %d, unresolved jumps %d, flag conflicts %d" %
          (ncode, rom.size, 100.0 * ncode / rom.size,
           sum(1 for k in labels.values() if "sub" in k), len(jts), len(conflicts)))
    print("vectors:", {k: "%04X" % v for k, v in vec.items()})


if __name__ == "__main__":
    main()
