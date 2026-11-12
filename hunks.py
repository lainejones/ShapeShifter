"""hunks.py EXE [EXE...] - print an AmigaOS executable's hunk table (size and memory type)."""
import struct, sys
for p in sys.argv[1:]:
    b = open(p, 'rb').read()
    assert struct.unpack('>II', b[:8]) == (0x3f3, 0), p + ': not a plain hunk executable'
    o = 8
    n, first, last = struct.unpack('>3I', b[o:o+12]); o += 12
    sz = [struct.unpack('>I', b[o+4*i:o+4*i+4])[0] for i in range(last - first + 1)]
    print(p, len(sz), 'hunks:', ', '.join('%d%s' % ((s & 0x3fffffff) * 4, ' CHIP' if s & 0x40000000 else ' FAST' if s & 0x80000000 else '') for s in sz))
