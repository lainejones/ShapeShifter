#!/usr/bin/env python3
"""mkdist.py - put the release together: dist/ShapeShifter-<ver>/ShapeShifter (+ its drawer icon).
Run after build.sh. Icons, the Installer script, and README come from dist-src."""
import os, re, shutil, sys
ver = re.search(r"ShapeShifter (\d+\.\d+)", open('src/ShapeShifter_rev.i', encoding='latin-1').read()).group(1)
top = 'dist/ShapeShifter-%s' % ver
d = top + '/ShapeShifter'
shutil.rmtree(top, ignore_errors=True); os.makedirs(d)
cp = shutil.copyfile
cp('dist-src/icons/drawer.info', top + '/ShapeShifter.info')
cp('out/ShapeShifter', d + '/ShapeShifter')
for n in ('ShapeShifter.info', 'ShapeShifter.guide.info', 'ShapeShifter_E.guide.info', 'Install_ShapeShifter.info'):
    cp('dist-src/icons/' + n, d + '/' + n)
for n in ('Install_ShapeShifter', 'README'): cp('dist-src/' + n, d + '/' + n)
cp('out/ReserveLow', d + '/ReserveLow')
for n in ('ShapeShifter.guide', 'ShapeShifter_E.guide'): cp('docs/' + n, d + '/' + n)
cp('LICENSE.txt', d + '/LICENSE.txt')
# The Mac disk tools: built in their own project (C:\projects\MacBrowse, "make")
MB = os.environ.get('MACBROWSE', '../MacBrowse')
os.makedirs(d + '/MacDiskTools')
for n in ('MacBrowse', 'MacBrowse.info', 'MacMount', 'MacHFS-Handler'): cp(MB + '/out/' + n, d + '/MacDiskTools/' + n)
cp(MB + '/docs/HFV0', d + '/MacDiskTools/HFV0')
open(d + '/MacDiskTools/MacBrowse.readme', 'wb').write(open(MB + '/README.md', encoding='utf-8').read().encode('latin-1', 'replace'))
shutil.copytree('out/Catalogs', d + '/Catalogs')
s = open(d + '/Install_ShapeShifter', 'rb').read()
assert b'\r' not in s and ('(set #version "%s")' % ver).encode() in s, 'Installer script: CR or wrong version'
sys.path.insert(0, 'tools'); import mklha
SUFFIX = '-beta2'      # '' for a final release
lha = top + SUFFIX + '.lha'
n = mklha.pack(top, lha)
print(lha, n, 'files', os.path.getsize(lha), 'bytes')
