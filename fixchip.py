"""fixchip.py EXE MAPFILE - set MEMF_CHIP on the hunks the linker named .datachip / .bsschip.
GNU ld's amiga backend drops the chip attribute of vasm hunk objects, so mark those
hunks in the executable's hunk header size table (bit 30), which LoadSeg uses.
Output section order and sizes come from the ld map file and are checked against the hunks."""
import re, struct, sys
exe, mapf = sys.argv[1], sys.argv[2]
secs = []
for line in open(mapf):
    m = re.match(r'^(\.\w+)\s+0x[0-9a-f]+\s+0x([0-9a-f]+)', line)
    if m and int(m.group(2), 16):
        secs.append((m.group(1), int(m.group(2), 16)))
b = bytearray(open(exe, 'rb').read())
assert struct.unpack('>II', b[:8]) == (0x3f3, 0), 'not a plain hunk executable (resident library names?)'
n, first, last = struct.unpack('>3I', b[8:20])
sizes = [struct.unpack('>I', b[20+4*i:24+4*i])[0] & 0x3fffffff for i in range(last - first + 1)]
assert len(secs) == len(sizes), (secs, sizes)
for i, ((name, size), longs) in enumerate(zip(secs, sizes)):
    assert (size + 3) // 4 == longs, (name, size, longs)
    if name in ('.datachip', '.bsschip'):
        o = 20 + 4 * i
        b[o:o+4] = struct.pack('>I', struct.unpack('>I', b[o:o+4])[0] | 0x40000000)
        print('hunk %d %s (%d bytes) -> CHIP' % (i, name, size))
open(exe, 'wb').write(b)
