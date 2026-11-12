#!/bin/bash
# asm.sh FILE [extra vasm args] - assemble one source file with vasm in PhxAss mode.
# Run inside WSL from the project root.
export PATH=/opt/amiga/bin:$PATH
I=/opt/amiga/m68k-amigaos
mkdir -p build/inc/libraries
# The toolchain's phase5 header uses C-style 0x80; make a build-local copy vasm accepts.
if [ ! -f build/inc/libraries/cybergraphics.i ]; then
  sed 's/0x\([0-9A-Fa-f]\+\)/$\1/g' $I/include/cybergraphx/cybergraphics.i > build/inc/libraries/cybergraphics.i
fi
f="$1"; shift
vasmm68k_mot -quiet -phxass -x -noesc -Fhunk -I include -I build/inc -I $I/ndk-include -I $I/include -I src \
  -o "build/$(basename "${f%.*}").o" "src/$f" "$@"
