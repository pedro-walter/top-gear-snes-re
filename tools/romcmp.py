#!/usr/bin/env python3 -I
"""romcmp.py A.sfc B.sfc: header fields, a 4 KB block similarity map and the differing regions per bank.

  .  identical   -  < 64 bytes differ   +  < 1024   #  more.
Regions are merged when closer than 64 bytes. The last part of each 32 KB bank is uninitialised padding
that differs in every build, and everything after an inserted byte differs too (docs/15) - read the map
together with tools/asmdiff.py.
"""
import sys

a = open(sys.argv[1], 'rb').read()
b = open(sys.argv[2], 'rb').read()
for name, d in (('A', a), ('B', b)):
    h = d[0x7FC0:0x7FE0]
    print(f'{name}: title {h[:21].decode("ascii", "replace")!r} map {h[21]:02X} size {h[23]:02X} country {h[25]:02X} maker {h[26]:02X} '
          f'version {h[27]:02X} checksum {h[30] | h[31] << 8:04X}')
print(len(a), len(b), 'differing bytes:', sum(1 for i in range(min(len(a), len(b))) if a[i] != b[i]))
for k in range(0, min(len(a), len(b)), 0x8000):
    row = ''
    for o in range(k, k + 0x8000, 0x1000):
        n = sum(1 for i in range(o, o + 0x1000) if a[i] != b[i])
        row += '.' if n == 0 else '-' if n < 64 else '+' if n < 1024 else '#'
    print(f'bank {k >> 15:02X} {row}')
gap = 64
i, n = 0, min(len(a), len(b))
while i < n:
    if a[i] == b[i]:
        i += 1
        continue
    s = last = i
    while i < n and i - last <= gap:
        if a[i] != b[i]:
            last = i
        i += 1
    print(f'{s >> 15:02X}:{(s & 0x7FFF) | 0x8000:04X}-{(last & 0x7FFF) | 0x8000:04X}  {last + 1 - s} bytes span')
    i = last + 1
