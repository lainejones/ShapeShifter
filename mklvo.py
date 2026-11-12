"""mklvo.py UNDEF_LIST OUT - write linker --defsym lines for _LVO names and fixed hardware addresses.
LVO values come from the NDK and toolchain lvo/*.i files; a name with conflicting values is an error."""
import sys, re, glob, collections
need = [l.strip() for l in open(sys.argv[1]) if l.strip()]
vals = collections.defaultdict(set)
src = collections.defaultdict(set)
for f in glob.glob('/opt/amiga/m68k-amigaos/ndk-include/lvo/*.i') + glob.glob('/opt/amiga/m68k-amigaos/include/lvo/*.i'):
    for line in open(f, encoding='latin1'):
        m = re.match(r'\s*(_LVO\w+)\s+EQU\s+(-?\d+)', line)
        if m:
            vals[m.group(1)].add(int(m.group(2))); src[m.group(1)].add(f.rsplit('/', 1)[1])
hw = {'_custom': 0xdff000, '_intena': 0xdff09a, '_intreq': 0xdff09c, '_dmacon': 0xdff096,
      '_ciaa': 0xbfe001, '_ciab': 0xbfd000, '_ciaaprb': 0xbfe101, '_ciaaddrb': 0xbfe301}
out, bad = [], 0
for n in need:
    if n in hw:
        out.append('--defsym=%s=0x%x' % (n, hw[n])); continue
    v = vals.get(n)
    if not v:
        print('MISSING', n); bad += 1; continue
    if len(v) > 1:
        print('CONFLICT', n, sorted(v), sorted(src[n])); bad += 1; continue
    out.append('--defsym=%s=%d' % (n, v.pop()))
open(sys.argv[2], 'w').write('\n'.join(out) + '\n')
print(len(out), 'symbols written,', bad, 'problems')
sys.exit(1 if bad else 0)
