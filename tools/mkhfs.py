#!/usr/bin/env python3
"""mkhfs.py IMAGE [NAME] : write an empty HFS volume into an existing image file (whole file, no partition map).
Reference for ShapeShifter's own formatter (src/MacEmulHFS.asm): same layout, same numbers.
--dump prints the sectors it would write instead."""
import struct, sys, time

def layout(total):
    spb = total // 65536 + 1                    # sectors per allocation block
    bm = (total // spb + 4095) // 4096          # bitmap sectors
    alst = 3 + bm                               # first allocation block's sector
    nblk = (total - alst - 2) // spb
    absz = spb * 512
    bt = min(1048576, total * 512 // 64) // absz * absz   # each B-tree file: at most 2048 nodes (one map record)
    if bt < absz: bt = absz
    return spb, bm, alst, nblk, absz, bt

def build(total, name=b'Untitled', now=None):
    """-> list of (sector, bytes)"""
    spb, bm, alst, nblk, absz, bt = layout(total)
    btblk = bt // absz
    nodes = bt // 512
    if now is None: now = int(time.time()) + 2082844800
    name = name[:27]
    mdb = bytearray(512)
    struct.pack_into('>HIIHHHHHIIHIH', mdb, 0, 0x4244, now, now, 0x0100, 0, 3, 0, nblk, absz, 4 * absz, alst, 16, nblk - 2 * btblk)
    mdb[36] = len(name); mdb[37:37 + len(name)] = name
    struct.pack_into('>I', mdb, 70, 1)                      # drWrCnt
    struct.pack_into('>II', mdb, 74, bt, bt)                # clump sizes
    struct.pack_into('>IHH', mdb, 130, bt, 0, btblk)        # extents file
    struct.pack_into('>IHH', mdb, 146, bt, btblk, btblk)    # catalog file
    out = [(2, bytes(mdb)), (total - 2, bytes(mdb))]
    bits = bytearray(bm * 512)
    for i in range(2 * btblk): bits[i >> 3] |= 0x80 >> (i & 7)
    out.append((3, bytes(bits)))

    def header(depth, root, recs, first, last, keylen, used):
        n = bytearray(512)
        struct.pack_into('>IIBBHH', n, 0, 0, 0, 1, 0, 3, 0)
        struct.pack_into('>HIIIIHHII', n, 14, depth, root, recs, first, last, 512, keylen, nodes, nodes - used)
        for i in range(used): n[0xf8 + (i >> 3)] |= 0x80 >> (i & 7)
        struct.pack_into('>HHHH', n, 504, 0x1f8, 0xf8, 0x78, 0x0e)
        return n
    xt = alst
    ct = alst + btblk * spb
    out.append((xt, bytes(header(0, 0, 0, 0, 0, 7, 1)) + bytes(512)))
    leaf = bytearray(512)
    struct.pack_into('>IIBBHH', leaf, 0, 0, 0, 0xff, 1, 2, 0)
    o = 14
    kl = 6 + len(name)
    if not kl & 1: kl += 1                       # key length byte + key: even
    key = bytes([kl, 0]) + struct.pack('>I', 1) + bytes([len(name)]) + name
    key += bytes(1 + kl - len(key))
    rec = key + struct.pack('>BBHHIIII', 1, 0, 0, 0, 2, now, now, 0) + bytes(48)
    leaf[o:o + len(rec)] = rec; o2 = o + len(rec)
    rec = bytes([7, 0, 0, 0, 0, 2, 0, 0]) + struct.pack('>BBIII', 3, 0, 0, 0, 1) + bytes([len(name)]) + name
    rec += bytes(8 + 46 - len(rec))
    leaf[o2:o2 + len(rec)] = rec; o3 = o2 + len(rec)
    struct.pack_into('>HHH', leaf, 506, o3, o2, o)
    out.append((ct, bytes(header(1, 1, 2, 1, 1, 37, 2)) + bytes(leaf)))
    return out

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    f = open(args[0], 'r+b'); f.seek(0, 2); total = f.tell() // 512
    name = (args[1] if len(args) > 1 else 'Untitled').encode('mac_roman')
    print('sectors %d: %s' % (total, dict(zip('spb bm alst nblk absz bt'.split(), layout(total)))))
    for sec, data in build(total, name):
        if '--dump' in sys.argv: print(sec, len(data) // 512, data.hex())
        else: f.seek(sec * 512); f.write(data)
    # the rest of both B-tree files and the boot blocks must be zero
    spb, bm, alst, nblk, absz, bt = layout(total)
    if '--dump' not in sys.argv:
        z = bytes(65536)
        for start, n in ((0, 2), (alst + 2, bt // 512 - 2), (alst + bt // 512 + 2, bt // 512 - 2)):
            f.seek(start * 512); left = n * 512
            while left: k = min(left, len(z)); f.write(z[:k]); left -= k
