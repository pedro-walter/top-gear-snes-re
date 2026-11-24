"""Linear 65816 disassembler with M/X hints, for code the recursive tools/disasm.py cannot follow (hook targets, data mixed with code).
usage: ROM=file.sfc python3 -I tools/lindis.py START,END,M,X [START,END,M,X ...]   (hex addresses, M/X = 1 for 8-bit, 0 for 16-bit; REP/SEP update them)
example: python3 -I tools/lindis.py 108100,108140,0,0 -> the TGC hook at 10:8100 (docs/18)
"""
import sys
import os
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import disasm as D
import os
rom=D.Rom(os.environ.get("ROM","Top Gear TGC Rom (E) [!].smc"))
def lin(a,end,m=1,x=1):
    while a<end:
        i=D.decode(rom,a,m,x)
        if i is None: print('??',hex(a)); a+=1; continue
        raw=' '.join('%02X'%rom.rd(a+k) for k in range(i.len))
        fm=D.FMT.get(i.mode,'')
        if i.mode in('immm','immx'): fm=('#$%02X' if i.len==2 else '#$%04X')%i.operand
        elif i.mode in('rel','rell'): fm='$%04X'%(i.target&0xFFFF)
        else: fm=fm.format(i.operand)
        print(f'{a>>16:02X}:{a&0xFFFF:04X} {raw:<12}{i.mn} {fm}')
        if i.mn=='REP': m=0 if i.operand&0x20 else m; x=0 if i.operand&0x10 else x
        if i.mn=='SEP': m=1 if i.operand&0x20 else m; x=1 if i.operand&0x10 else x
        a+=i.len
        if i.mn in('RTS','RTL','JML','JMP','BRA'): print()
for arg in sys.argv[1:]:
    s,e,m,x=arg.split(',')
    print('----',s); lin(int(s,16),int(e,16),int(m),int(x))
