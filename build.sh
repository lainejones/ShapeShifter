#!/bin/bash
# build.sh - assemble and link ShapeShifter. Run inside WSL from the project root.
set -e
export PATH=/opt/amiga/bin:$PATH
mkdir -p build out
MODS="MacEmul MacEmulPatches MacEmulADD MacEmulAFD MacEmulClip MacEmulNet MacEmulPrefs MacEmulSCSI MacEmulSERD MacEmulSlot MacEmulSound MacEmulVideo MacEmulTabs MacEmulCheck MacEmulPRam MacEmulHelp MacEmulLoc MacEmulSetup MacEmulHFS"
# MacEmulTCP.asm (unfinished MacTCP emulation of 3.11) is not part of the build.
# Strings: the MSG_ numbers, GetString with the built-in English text, and the
# catalogs, all from src/Catalogs (tools/catcomp.py replaces CatComp)
python3 -I tools/catcomp.py header src/Catalogs/ShapeShifter.cd src/Strings.i
python3 -I tools/catcomp.py code src/Catalogs/ShapeShifter.cd build/Strings.asm
vasmm68k_mot -quiet -phxass -Fhunk -o build/Strings.o build/Strings.asm
for d in src/Catalogs/*/; do
  [ -f "$d/ShapeShifter.ct" ] || continue
  mkdir -p "out/Catalogs/$(basename "$d")"
  python3 -I tools/catcomp.py catalog src/Catalogs/ShapeShifter.cd "$d/ShapeShifter.ct" "out/Catalogs/$(basename "$d")/ShapeShifter.catalog"
done
./asm.sh startup.asm
# MacEmulSERD was assembled without optimisation (ShapeShifter-Startup: "Keine PEA-Optimierung!").
# MacEmulVideo patches instruction displacements at run time (m8a/m8b/madd), so its
# encodings must be exactly what is written, not what the optimiser prefers.
for m in $MODS; do case $m in MacEmulSERD|MacEmulVideo) ./asm.sh $m.asm -no-opt;; *) ./asm.sh $m.asm;; esac; done
./asm.sh MacEmulGUI.s
OBJS="build/startup.o"
for m in $MODS; do OBJS="$OBJS build/$m.o"; done
OBJS="$OBJS build/MacEmulGUI.o build/Strings.o src/Boopsi.o"
# unresolved names -> linker definitions (library offsets, hardware addresses)
for o in $OBJS; do m68k-amigaos-nm $o; done > build/syms.txt
awk '$1=="U"{print $2}' build/syms.txt | sort -u > build/undef.txt
awk 'NF==3 && $2 ~ /[TDBAC]/ {print $3}' build/syms.txt | sort -u > build/def.txt
comm -23 build/undef.txt build/def.txt > build/need.txt
python3 -I mklvo.py build/need.txt build/defsyms.txt
mkdir -p out
m68k-amigaos-ld -nostdlib -T shapeshifter.ld -Map build/ShapeShifter.map -o out/ShapeShifter $OBJS $(cat build/defsyms.txt)
python3 -I fixchip.py out/ShapeShifter build/ShapeShifter.map
python3 -I hunks.py out/ShapeShifter
# ReserveLow: one source file, no linker
vasmm68k_mot -quiet -Fhunkexe -kick1hunks -nosym -I /opt/amiga/m68k-amigaos/ndk-include -o out/ReserveLow src/ReserveLow.asm
ls -la out/ShapeShifter out/ReserveLow
