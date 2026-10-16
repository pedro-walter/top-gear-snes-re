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
    args = ap.parse_args()
    rom = Rom(args.rom, args.wram)
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

    ncode = sum(i.len for i in code.values())
    with open(args.out, "w") as f:
        f.write("; Top Gear (USA) disassembly - auto generated by tools/disasm.py\n")
        f.write("; vectors: " + ", ".join("%s=%04X" % (k, v) for k, v in vec.items()) + "\n")
        f.write("; code bytes: %d / %d (%.1f%%)\n; unresolved indirect jumps: %d\n\n" %
                (ncode, rom.size, 100.0 * ncode / rom.size, len(jts)))
        nbanks = rom.size // 0x8000
        for b in range(nbanks):
            base = (b << 16) | 0x8000
            f.write("\n; ===== bank $%02X =====\n" % b)
            a, end = base, base + 0x8000
            while a < end:
                if a in code:
                    ins = code[a]
                    l = lab(a)
                    if l:
                        f.write("%s:\n" % l)
                    f.write("  %06X  %s\n" % (a, fmt_insn(ins, rom, lab)))
                    a += ins.len
                else:
                    # data run until next code byte (max 16 per line)
                    n = 0
                    while a + n < end and (a + n) not in covered and n < 16:
                        if n and lab(a + n):
                            break
                        n += 1
                    l = lab(a)
                    if l:
                        f.write("%s:\n" % l)
                    f.write("  %06X  .db %s\n" % (a, ",".join("$%02X" % rom.rd(a + k) for k in range(n))))
                    a += n
        if rom.wram:
            for lo, hi, title in ((0x7E0000, 0x7E0010, "WRAM interrupt stubs"),
                                  (0x7E2000, 0x7E3700, "WRAM-resident engine code (decompressed at boot)")):
                f.write("\n; ===== %s =====\n" % title)
                a = lo
                while a < hi:
                    if a in code:
                        ins = code[a]
                        l = lab(a)
                        if l:
                            f.write("%s:\n" % l)
                        f.write("  %06X  %s\n" % (a, fmt_insn(ins, rom, lab)))
                        a += ins.len
                    else:
                        n = 0
                        while a + n < hi and (a + n) not in covered and n < 16:
                            if n and lab(a + n):
                                break
                            n += 1
                        l = lab(a)
                        if l:
                            f.write("%s:\n" % l)
                        f.write("  %06X  .db %s\n" % (a, ",".join("$%02X" % rom.rd(a + k) for k in range(n))))
                        a += n
        if jts:
            f.write("\n; unresolved indirect jumps:\n")
            for a, mn in jts:
                f.write(";   %06X %s\n" % (a, mn))
    print("code bytes %d/%d (%.1f%%), subs %d, unresolved jumps %d, flag conflicts %d" %
          (ncode, rom.size, 100.0 * ncode / rom.size,
           sum(1 for k in labels.values() if "sub" in k), len(jts), len(conflicts)))
    print("vectors:", {k: "%04X" % v for k, v in vec.items()})


if __name__ == "__main__":
    main()
