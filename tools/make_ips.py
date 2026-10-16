#!/usr/bin/env python3 -I
"""Create an IPS patch (original ROM -> randomizer ROM): python3 -I tools/make_ips.py [out/rando.ips]
The patch only contains the bytes that differ (our code and hooks), no game data.  The original is first extended with
zeros to the size of the patched image, like tools/build_rando.py does."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_rando import build

def ips(orig, new):
    out = bytearray(b'PATCH')
    i = 0
    n = len(new)
    while i < n:
        if orig[i] == new[i]:
            i += 1
            continue
        last = i                                       # last differing byte of this record
        j = i + 1
        while j < n and j - i < 0xFFFF and j - last <= 6:
            if orig[j] != new[j]:
                last = j
            j += 1
        end = last + 1
        start = i
        if start == 0x454F46:                          # an offset equal to "EOF" would end the patch: start one byte earlier
            start -= 1
        out += start.to_bytes(3, 'big') + (end - start).to_bytes(2, 'big') + bytes(new[start:end])
        i = end
    out += b'EOF'
    return bytes(out)

if __name__ == '__main__':
    path = os.environ.get('TOPGEAR_ROM', 'Top Gear (USA).sfc')
    orig = bytearray(open(path, 'rb').read())
    new, _ = build(False)
    orig.extend(bytes(len(new) - len(orig)))
    p = ips(orig, new)
    dst = sys.argv[1] if len(sys.argv) > 1 else 'out/rando.ips'
    open(dst, 'wb').write(p)
    print('wrote', dst, len(p), 'bytes')
