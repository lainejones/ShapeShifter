# ShapeShifter 3.20 (beta)

ShapeShifter is Christian Bauer's Macintosh II emulator for the Amiga. It runs
System 7 to Mac OS 8.1 as an ordinary AmigaOS task, with Mac code executing
directly on the Amiga's 68020-68060.

This repository starts from the ShapeShifter 3.11 source that Christian Bauer
released under the ISC licence, and adds fixes and features. It is **not** his
release; please do not send him bug reports for it.

**Status: beta 1.** It has run on three real Amigas and in WinUAE. See
[Tested](#tested) and [Known issues](#known-issues) before trusting it with anything you care about.

## What is new since 3.11

**Getting started**
- An installer (Commodore Installer script) and a first-start setup that finds
  the ROM, picks a screen and memory for the Amiga and creates an empty Mac disk.
- One settings window with tabs instead of nine windows, a line of help for the
  gadget under the mouse, named configurations, a **Defaults** button, and an
  **Advanced** switch: without it only the four everyday pages are shown.
- Checks before the Mac starts, in plain words: missing disk image, no disk at
  all, too little memory, a screen mode that does not exist, ROM in chip
  memory, 68060 under UAE without NOCOPYBACK.

**Disks**
- Four file disks, removable: eject on the Mac, insert by dropping an image.
- CD and hard disk images as file disks: raw `.bin`/`.cue` (with the audio
  track table), Toast/`.cdr`/hybrid `.iso` with an Apple partition map, and
  DiskCopy 4.2 floppy images. The Mac boots from them.
- Empty Mac disks are formatted by ShapeShifter itself in seconds (Create...,
  and Format... for device disks) instead of the Mac's Initialise.
- Device disks may be a whole drive. A disk that lies beyond the first 4 GB
  of its drive is refused (3.11 wrote over the start of the drive instead).

**Video**
- Thousands of colours on 16-bit RTG screens; PrismRTG support.
- The Mac can switch colour depth itself (DEPTHSWITCH).

**Fixes**
- Mac OS 8.1 on a 68060 (its second Process Manager was not patched).
- The Mac OS 8.1 Setup Assistant froze (LocalTalk waiting for a serial chip
  that is not there).
- A program that disposes a handle twice could free a whole block of master
  pointers and crash the Mac; such a DisposeHandle is now refused.
- "Unimplemented trap" at boot with MacsBug; Ethernet packets 4 bytes short;
  minutes of grey screen with SCSI on for IDs without a drive; floppy close
  through mfm.device; and about two dozen defects from a source
  review.

**Alongside**
- `ReserveLow`: keeps the lowest memory free for ShapeShifter, replacing
  PrepareEmul (no longer in the archive). Holding the left mouse button at
  start or reset skips it.
- The Mac disk tools from the MacBrowse project: `MacBrowse`, `MacMount` and
  `L:MacHFS-Handler` read and write Mac disk images from the Amiga side.

## Using it

Unpack `ShapeShifter-3.20-beta1.lha` on the Amiga and double-click
`Install_ShapeShifter`. The manual is `ShapeShifter_E.guide` (English) and
`ShapeShifter.guide` (German); start with **Quick start**. You need a Macintosh
ROM file from a Mac you own and a Macintosh system to install; neither is part
of this project.

## Building

The sources are 68k assembler in Latin-1. They build under Linux or WSL with
[vasm](http://sun.hasenbraten.de/vasm/) (`vasmm68k_mot`), Bebbo's amiga-gcc
(for `ld` and the NDK includes in `/opt/amiga`) and Python 3:

```
./build.sh          # out/ShapeShifter, out/ReserveLow, out/Catalogs
python3 mkdist.py   # dist/ShapeShifter-3.20-beta1.lha
```

`mkdist.py` takes the Mac disk tools from a MacBrowse checkout next to this
one (`../MacBrowse/out`, or set `MACBROWSE`).

Texts live in `src/Catalogs/ShapeShifter.cd`; `tools/catcomp.py` turns them
into `src/Strings.i` and the catalogs. `tools/mkhfs.py` is the reference for
the built-in HFS formatter (`src/MacEmulHFS.asm`).

## Tested

| Machine | What ran |
|---|---|
| Amiga 1200, 68030 + 68882, Kickstart 3.2.3, AGA | Mac OS 8.0 and 8.1, Marathon with sound (Paula, heard), POV-Ray, device disk on SCSI, installer, ReserveLow |
| Amiga 4000, 68060, Kickstart 3.2.3, RTG card and AGA | Mac OS 8.0 and 8.1, sound through AHI (recorded to a file), TCP/IP, ReserveLow |
| The same Amiga 4000, Kickstart 3.1, AGA | Mac OS 8.1, POV-Ray |
| Amiga 2000, 68030 accelerator (no FPU), Kickstart 3.2.3, ECS and a Picasso II+ | System 7.5 in 2, 4 and 16 colours on the ECS screen; System 7.5 and Mac OS 8.1 in 256 and thousands of colours on the graphics card; sound (Paula); installer, ReserveLow, Mac disk tools |
| WinUAE A1200 68030, Kickstart 3.1 and 3.2.3 | System 7.5, Mac OS 8.0 and 8.1, installer |
| WinUAE A4000 68060, Kickstart 3.2.3 | Mac OS 8.0 and 8.1 |

## Known issues

**Not tested**
- 68020 and 68040 processors, OCS screens, the DraCo.
- Long sessions (many hours).
- CD music on real hardware.
- AGA screens whose width is not a multiple of 64 (800x600, for one) together
  with MMU refresh or with depth switching. Without those two they work.
- **Format...** for device disks above 2 GB, and Disk First Aid on a disk that
  ShapeShifter formatted.
- ReserveLow's left mouse button with a real button on anything but the
  Amiga 4000, and a cold start of ReserveLow under Kickstart 3.1 on real
  hardware.

**Seen**
- A Mac disk image on a Fast File System partition of a slow drive makes the
  Mac start extremely slowly. ShapeShifter measures this and warns; use a
  PFS3 or SFS partition, or a device disk.
- A device disk set to "whole drive" on a drive larger than 4 GB is left out
  without a message.
- **Format...** with a start sector typed by hand checks the partition table
  only when the disk starts in the first 16 sectors. Use **Choose...** to
  pick a partition.
- A settings file from 3.11 may name a screen mode that no longer exists.
  ShapeShifter says so and opens the settings.
- Each SCSI ID that is switched on but has no drive adds a few seconds of
  grey screen before the Mac starts (3.11 took minutes). Switch unused IDs
  off on the SCSI tab.
- The extras of the 3.11 archive (PrepareEmul, SaveROM, KickShifter,
  Mac-Handler, the external video drivers) are not in this archive; those of
  3.11 still work. An Amiga whose only fast memory is on Zorro cards still
  needs PrepareEmul from there, because ReserveLow cannot work on it.

## Licence

ISC, see `LICENSE.txt`. Copyright (c) 2001 Christian Bauer; changes since the
3.11 source release are under the same licence.
