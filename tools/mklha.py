#!/usr/bin/env python3
"""mklha.py DIR ARCHIVE.lha - pack the contents of DIR into an LhA archive (paths relative to DIR).

Files are stored, not compressed (-lh0-, level 0 headers): every LhA and LHA reads that, and no
packer is needed on the PC. Names are written as the Amiga has them: ISO 8859-1, and the Czech
catalogue drawer in ISO 8859-2 as the Czech locale names it. Amiga protection bits: all default."""
import os, struct, sys, time

AMIGA_NAMES = {'čeština': b'\xe8e\xb9tina'}       # "cestina" with caron c and caron s, Latin-2

def crc16(data, table=[]):
    if not table:
        for i in range(256):
            c = i
            for _ in range(8): c = (c >> 1) ^ 0xA001 if c & 1 else c >> 1
            table.append(c)
    c = 0
    for b in data: c = (c >> 8) ^ table[(c ^ b) & 0xff]
    return c

def aname(part):
    return AMIGA_NAMES[part] if part in AMIGA_NAMES else part.encode('latin-1')

def entry(name, data, mtime):
    t = time.localtime(mtime)
    dos = ((t.tm_year - 1980) << 25) | (t.tm_mon << 21) | (t.tm_mday << 16) | (t.tm_hour << 11) | (t.tm_min << 5) | (t.tm_sec // 2)
    body = b'-lh0-' + struct.pack('<III', len(data), len(data), dos) + bytes([0x20, 0, len(name)]) + name + struct.pack('<H', crc16(data))
    assert len(name) < 200
    return bytes([len(body), sum(body) & 0xff]) + body + data

def pack(top, out):
    base = os.path.abspath(top)
    n = 0
    with open(out, 'wb') as f:
        for root, dirs, files in os.walk(top):
            dirs.sort(); files.sort()
            for fn in files:
                p = os.path.join(root, fn)
                rel = os.path.relpath(p, base).replace('\\', '/')
                name = b'/'.join(aname(x) for x in rel.split('/'))
                f.write(entry(name, open(p, 'rb').read(), os.path.getmtime(p))); n += 1
        f.write(b'\0')
    return n

if __name__ == '__main__':
    print(pack(sys.argv[1], sys.argv[2]), 'files ->', sys.argv[2], os.path.getsize(sys.argv[2]), 'bytes')
