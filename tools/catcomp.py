#!/usr/bin/env python3
"""catcomp.py - a small CatComp replacement for ShapeShifter's catalogs.

  catcomp.py header  SRC.cd OUT.i      MSG_ numbers (like CatComp's assembler header)
  catcomp.py code    SRC.cd OUT.asm    GetString + the built-in English strings
  catcomp.py catalog SRC.cd SRC.ct OUT.catalog
                                       a locale.library catalog from a translation
  catcomp.py newct   SRC.cd OLD.ct OUT.ct
                                       OLD.ct with the strings that are new in SRC.cd
                                       added (English text, marked as untranslated)

GetString has the interface of the CatComp-made Strings.o it replaces:
  a0: LocaleInfo (LONG LocaleBase, LONG Catalog), d0: message number
  result d0: the catalog's string, or the built-in one.
Files are read and written as Latin-1, like the originals.
"""
import re
import struct
import sys

ESC = {'n': 10, 't': 9, 'r': 13, 'e': 27, 'a': 7, 'b': 8, 'f': 12, 'v': 11,
       'c': 155, '\\': 92, '"': 34, "'": 39}


def unescape(s):
    out = bytearray()
    i = 0
    while i < len(s):
        c = s[i]
        if c != '\\' or i + 1 >= len(s):
            out += c.encode('latin-1')
            i += 1
            continue
        n = s[i + 1]
        if n in ESC:
            out.append(ESC[n])
            i += 2
        elif n == 'x':
            m = re.match(r'[0-9a-fA-F]{1,2}', s[i + 2:])
            out.append(int(m.group(0), 16))
            i += 2 + len(m.group(0))
        elif n in '01234567':
            m = re.match(r'[0-7]{1,3}', s[i + 1:])
            out.append(int(m.group(0), 8) & 255)
            i += 1 + len(m.group(0))
        else:
            out += n.encode('latin-1')
            i += 2
    return bytes(out)


def read_lines(path):
    return open(path, 'rb').read().decode('latin-1').replace('\r\n', '\n').split('\n')


def string_lines(lines, i):
    """The text starting at lines[i]: lines ending in a backslash continue."""
    parts = []
    while i < len(lines):
        l = lines[i]
        i += 1
        if l.endswith('\\') and not l.endswith('\\\\'):
            parts.append(l[:-1])
            continue
        parts.append(l)
        break
    return unescape(''.join(parts)), i


def parse_cd(path):
    """[(name, id, bytes)] in file order."""
    lines = read_lines(path)
    msgs, nxt, i = [], 0, 0
    while i < len(lines):
        l = lines[i]
        m = re.match(r'^(\w+)\s*\(\s*(\$?[0-9A-Fa-f]*)\s*/\s*(\d*)\s*/\s*(\d*)\s*\)', l)
        if l.startswith(';') or not m:
            i += 1
            continue
        g = m.group(2)
        num = (int(g[1:], 16) if g.startswith('$') else int(g)) if g else nxt
        nxt = num + 1
        text, i = string_lines(lines, i + 1)
        msgs.append((m.group(1), num, text))
    return msgs


def parse_ct(path):
    """{name: bytes} of the translated strings (empty ones left out)."""
    lines = read_lines(path)
    out, i = {}, 0
    while i < len(lines):
        l = lines[i]
        if l.startswith(';') or l.startswith('#') or not re.match(r'^\w+\s*$', l):
            i += 1
            continue
        name = l.strip()
        text, i = string_lines(lines, i + 1)
        if text:
            out[name] = text
    return out


def ct_header(path):
    """language name and version from the ## lines of a .ct file"""
    lang, ver = None, None
    for l in read_lines(path):
        if l.lower().startswith('## language'):
            lang = l.split(None, 2)[2].strip()
        elif l.lower().startswith('## version'):
            ver = l.split(None, 2)[2].strip()
    return lang, ver


def asm_bytes(b):
    """dc.b lines for a byte string (printable runs quoted)"""
    out, run = [], ''
    for c in b:
        if 32 <= c < 127 and c != 39:
            run += chr(c)
        else:
            if run:
                out.append("'%s'" % run)
                run = ''
            out.append(str(c))
    if run:
        out.append("'%s'" % run)
    lines = []
    while out:
        chunk, n = [], 0
        while out and n < 60:
            n += len(out[0]) + 1
            chunk.append(out.pop(0))
        lines.append('\t\tdc.b\t' + ','.join(chunk))
    return lines


def header(cd, outp):
    msgs = parse_cd(cd)
    o = ['\tIFND STRINGS_I', 'STRINGS_I\tSET\t1', '',
         '* Made by tools/catcomp.py from Catalogs/ShapeShifter.cd. Do not edit.', '',
         '\tIFD CATCOMP_NUMBERS', '']
    for name, num, _ in msgs:
        o.append('%s EQU %d' % (name, num))
    o += ['', '\tENDC ; CATCOMP_NUMBERS', '', '\tENDC ; STRINGS_I', '']
    open(outp, 'wb').write('\n'.join(o).encode('latin-1'))


def code(cd, outp):
    msgs = parse_cd(cd)
    o = ['* Made by tools/catcomp.py from Catalogs/ShapeShifter.cd. Do not edit.',
         '* GetString(a0: LocaleInfo, d0: message number) -> d0: string', '',
         '\t\tXDEF\tGetString', '\t\tXDEF\t_GetString', '',
         '\t\tSECTION\t".text",CODE\t;(first hunk, like the CatComp object)', '',
         '_GetString',
         'GetString\tlea\tStrBlock(pc),a1',
         '\t\tbra\t2$',
         '1$\t\tmove.w\t(a1)+,d1\t;skip this string',
         '\t\tadda.w\td1,a1',
         '2$\t\tcmp.l\t(a1)+,d0',
         '\t\tbne\t1$',
         '\t\taddq.l\t#2,a1\t\t;a1: the built-in string',
         '\t\tmove.l\t(a0)+,d1\t;LocaleBase',
         '\t\tbne\t3$',
         '\t\tmove.l\ta1,d0',
         '\t\trts',
         '3$\t\tmove.l\ta6,-(sp)',
         '\t\tmove.l\td1,a6',
         '\t\tmove.l\t(a0),a0\t\t;Catalog',
         '\t\tjsr\t-72(a6)\t\t;GetCatalogStr',
         '\t\tmove.l\t(sp)+,a6',
         '\t\trts', '',
         '\t\tdc.w\t0\t\t;(the block starts on a long word)',
         'StrBlock']
    for name, num, text in msgs:
        b = text + b'\0'
        if len(b) & 1:
            b += b'\0'
        o.append('\t\tdc.l\t%d\t\t;%s' % (num, name))
        o.append('\t\tdc.w\t%d' % len(b))
        o += asm_bytes(b)
    total = 0x28 + sum(6 + ((len(x) + 2) & ~1) for _, _, x in msgs)
    if total & 3:
        o.append('\t\tdc.w\t0\t\t;(padded to a long word, as CatComp did)')
    o += ['', '\t\tEND', '']
    open(outp, 'wb').write('\n'.join(o).encode('latin-1'))


def catalog(cd, ct, outp):
    """IFF CTLG: FVER, LANG, CSET, STRS (id, length, text, padded to 4)."""
    msgs = parse_cd(cd)
    tr = parse_ct(ct)
    lang, ver = ct_header(ct)

    def chunk(cid, data):
        d = cid + struct.pack('>I', len(data)) + data
        return d + (b'\0' if len(data) & 1 else b'')

    # As CatComp wrote them: strings equal to the built-in English are left out;
    # the length is the string's, plus one when that is a multiple of 4; the
    # data is the string, its 0 and padding to a long word.
    strs = b''
    for name, num, default in msgs:
        s = tr.get(name)
        if not s or s == default:
            continue
        ln = len(s) + (1 if len(s) % 4 == 0 else 0)
        data = s + b'\0' * (((len(s) + 1 + 3) & ~3) - len(s))
        strs += struct.pack('>II', num, ln) + data
    body = b'CTLG'
    if ver:
        body += chunk(b'FVER', ver.encode('latin-1') + b'\0')
    if lang:
        body += chunk(b'LANG', lang.encode('latin-1') + b'\0')
    body += chunk(b'CSET', b'\0' * 32)
    body += chunk(b'STRS', strs)
    open(outp, 'wb').write(b'FORM' + struct.pack('>I', len(body)) + body)


def newct(cd, ct, outp):
    """Append the messages that the translation does not have yet."""
    have = set()
    for l in read_lines(ct):
        if re.match(r'^\w+\s*$', l):
            have.add(l.strip())
    add = []
    for name, num, text in parse_cd(cd):
        if name in have:
            continue
        esc = text.decode('latin-1').replace('\\', '\\\\').replace('\n', '\\n')
        add += [name, '', '; ' + esc, ';']
    src = open(ct, 'rb').read().decode('latin-1').rstrip('\n')
    if add and '; New in 3.20' in src:
        src += '\n' + '\n'.join(add)
    elif add:
        src +='\n;\n; New in 3.20 - not translated yet (the English text is in the comment)\n;\n' + '\n'.join(add)
    open(outp, 'wb').write((src + '\n').encode('latin-1'))


if __name__ == '__main__':
    cmd = sys.argv[1]
    {'header': header, 'code': code, 'catalog': catalog, 'newct': newct}[cmd](*sys.argv[2:])
