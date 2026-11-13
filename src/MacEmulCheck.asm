**
** MacEmulCheck.asm - checks before the Mac starts
**
** Called after the settings window (also with QUICKSTART). Each check
** that finds a problem asks in plain words, with a fix where there is one:
**
**  - a file disk whose image file is missing (it would be left out quietly)
**  - the ROM in "24 bit DMA" memory on an Amiga without 24-bit fast RAM:
**    the ROM then takes a megabyte of chip RAM and 256-colour screens come
**    out white (a non-interleaved bitmap)
**  - a 68060 under UAE without NOCOPYBACK: the Mac hangs on a grey screen
**
** Return d0: 0 = start the Mac, 1 = back to the settings, -1 = quit.
**

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"dos/dos.i"
		INCLUDE	"intuition/intuition.i"
		INCLUDE	"macros.i"
CATCOMP_NUMBERS	= 1
		INCLUDE	"Strings.i"

		XDEF	CheckStart

		XREF	QuickStart
		XREF	SReq
		XREF	PrefsNameTab
		XREF	ADDName1,ADDName2,ADDStartSector1,ADDStartSector2,ADDSectors1,ADDSectors2
		XREF	ADDUnit1,ADDUnit2,DevTotalSectors,Dev64Cmd,DevHasRDB
		XREF	Has68060
		XREF	NoCopyBack
		XREF	ROMSize
		XREF	VideoType1,DisplayID1,SCSIEnable,MemSize,LargestBlock,MacOS8Mode

		SECTION	"CODE",CODE

NUMAFD		= 4
SEEKTEST	= 8*1024*1024		;SlowSeek reads here
SEEKSLOW	= 10			;1/50 s for that: 2.5 s and more for 100 MB is slow
UAE_MANUFACTURER = 2011		;WinUAE's own expansion boards

CheckStart	movem.l	d2-d7/a2-a6,-(sp)

; A screen mode that this Amiga does not have (a settings file from another
; Amiga or another graphics driver): the screen could not be opened
		cmp.w	#VTYPE_CYBER,VideoType1
		bhi	80$
		move.l	DisplayID1,d0
		beq	80$
		move.l	_GfxBase,a6
		JSRLIB	ModeNotAvailable
		tst.l	d0
		beq	80$
		move.l	#MSG_CHK_BADMODE_TXT,d0
		move.l	#MSG_CHK_BADMODE_GADS,d1
		bsr	Ask			;1 Settings, 0 Quit
		tst.l	d0
		beq	CSQuit
		bra	CSSettings
80$
; No disk at all
		lea	PrefsNameTab,a0		;(the file disks come first in it)
		moveq	#NUMAFD-1,d1
81$		move.l	(a0)+,a1
		tst.b	(a1)
		bne	85$
		dbra	d1,81$
		tst.b	ADDName1
		bne	85$
		tst.b	ADDName2
		bne	85$
		tst.b	SCSIEnable
		bne	85$
		move.l	#MSG_CHK_NODISK_TXT,d0
		move.l	#MSG_CHK_MISSING_GADS,d1
		bsr	Ask			;1 Settings, 2 Start anyway, 0 Quit
		cmp.l	#2,d0
		bne	CSAnswer
85$
; Less than a Mac system needs to start: 4 MB, or 12 MB in Mac OS 8 mode
; (the built-in default is 1.7 MB)
		tst.w	LargestBlock
		bne	88$
		move.l	MemSize,d0
		move.l	#$00400000,d1
		tst.w	MacOS8Mode
		beq	87$
		move.l	#$00c00000,d1
87$		cmp.l	d1,d0
		bhs	88$
		lsr.l	#8,d0
		lsr.l	#2,d0
		move.l	d0,ReqArgs
		move.l	#MSG_CHK_LOWMEM_TXT,d0
		move.l	#MSG_CHK_MISSING_GADS,d1
		bsr	Ask
		cmp.l	#2,d0
		bne	CSAnswer
88$

; File disks whose image is missing
		lea	PrefsNameTab,a4
		moveq	#0,d7			;d7: file disk number - 1
1$		move.l	(a4)+,a0
		tst.b	(a0)
		beq	2$
		move.l	a0,d1
		move.l	_DOSBase,a6
		move.l	#ACCESS_READ,d2
		JSRLIB	Lock
		tst.l	d0
		beq	3$
		move.l	d0,d1
		JSRLIB	UnLock
		move.l	-4(a4),a0		;There: is jumping around in it slow?
		bsr	SlowSeek
		tst.l	d0
		beq	2$
		move.l	d0,ReqArgs+8		;Seconds for 100 MB
		move.l	d7,d0
		addq.l	#1,d0
		move.l	d0,ReqArgs
		move.l	-4(a4),ReqArgs+4
		move.l	#MSG_CHK_SLOWSEEK_TXT,d0
		move.l	#MSG_CHK_MISSING_GADS,d1
		bsr	Ask			;1 Settings, 2 Start anyway, 0 Quit
		cmp.l	#2,d0
		bne	CSAnswer
		bra	2$
3$		move.l	d7,d0			;"File disk %ld: %s not found"
		addq.l	#1,d0
		move.l	d0,ReqArgs
		move.l	-4(a4),ReqArgs+4
		move.l	#MSG_CHK_MISSING_TXT,d0
		move.l	#MSG_CHK_MISSING_GADS,d1
		bsr	Ask			;1 Settings, 2 Start anyway, 0 Quit
		cmp.l	#2,d0
		bne	CSAnswer
2$		addq.w	#1,d7
		cmp.w	#NUMAFD,d7
		blo	1$

; Device disks that lie beyond the first 4 GB of their drive
		lea	ADDName1,a0
		lea	ADDStartSector1,a1
		lea	ADDSectors1,a2
		move.l	ADDUnit1,d2
		moveq	#1,d1
		bsr	CheckADD
		cmp.l	#2,d0
		bne	CSAnswer
		lea	ADDName2,a0
		lea	ADDStartSector2,a1
		lea	ADDSectors2,a2
		move.l	ADDUnit2,d2
		moveq	#2,d1
		bsr	CheckADD
		cmp.l	#2,d0
		bne	CSAnswer

; The ROM in 24-bit memory without 24-bit fast RAM
		cmp.w	#SCSIMEM_24BIT,ROMMemType
		bne	10$
		move.l	_ExecBase,a6
		move.l	#MEMF_24BITDMA|MEMF_FAST|MEMF_LARGEST,d1
		JSRLIB	AvailMem
		cmp.l	ROMSize,d0
		bhs	10$
		move.l	#MSG_CHK_ROMCHIP_TXT,d0
		move.l	#MSG_CHK_ROMCHIP_GADS,d1
		bsr	Ask			;1 Use Any, 2 Start anyway, 3 Settings, 0 Quit
		cmp.l	#1,d0
		bne	11$
		move.w	#SCSIMEM_ANY,ROMMemType
		bra	10$
11$		cmp.l	#2,d0
		beq	10$
		cmp.l	#3,d0
		bne	CSQuit
		bra	CSSettings
10$

; 68060 under UAE without NOCOPYBACK
		tst.b	Has68060
		beq	20$
		tst.l	NoCopyBack
		bne	20$
		move.l	_ExpansionBase,d0
		beq	20$
		move.l	d0,a6
		sub.l	a0,a0
		move.l	#UAE_MANUFACTURER,d0
		moveq	#-1,d1
		JSRLIB	FindConfigDev
		tst.l	d0
		beq	20$
		move.l	#MSG_CHK_COPYBACK_TXT,d0
		move.l	#MSG_CHK_COPYBACK_GADS,d1
		bsr	Ask			;1 Turn it on, 2 Start anyway, 3 Settings, 0 Quit
		cmp.l	#1,d0
		bne	21$
		move.l	#-1,NoCopyBack
		bra	20$
21$		cmp.l	#2,d0
		beq	20$
		cmp.l	#3,d0
		bne	CSQuit
		bra	CSSettings
20$
		moveq	#0,d0			;Start
CSDone		movem.l	(sp)+,d2-d7/a2-a6
		rts

; Answer of a "Settings|Start anyway|Quit" requester (2 was handled)
CSAnswer	tst.l	d0
		beq	CSQuit
CSSettings	clr.l	QuickStart		;The settings window must open now
		moveq	#1,d0
		bra	CSDone
CSQuit		moveq	#-1,d0
		bra	CSDone

; Device disk d1 (a0 name, d2 unit, a1 start sector, a2 sectors) within reach
; of 32-bit byte offsets? d0 = 2: go on, else 1 Settings, 0 Quit. With 0
; sectors (the whole drive) the drive is asked how large it is.
CheckADD	tst.b	(a0)
		beq	1$
		movem.l	d1/a0-a2,-(sp)		;At the start of a drive with an Amiga
		moveq	#0,d0			; partition table? The Mac would take the
		cmp.l	#16,(a1)		; whole drive for one unreadable disk.
		bhs	5$
		move.l	d2,d0
		jsr	DevHasRDB
5$		movem.l	(sp)+,d1/a0-a2
		move.l	#MSG_CHK_ADDRDB_TXT,d3
		tst.l	d0
		bne	2$
		move.l	#MSG_CHK_ADD4GB_TXT,d3
		move.l	(a2),d0
		bne	3$
		move.l	#MSG_CHK_ADDWHOLE_TXT,d3
		movem.l	d1/a0-a2,-(sp)
		move.l	d2,d0
		jsr	DevTotalSectors
		movem.l	(sp)+,d1/a0-a2
		bra	4$			;(0: cannot tell, the driver decides)
3$		add.l	(a1),d0
		bcs	6$
4$		cmp.l	#$800000,d0
		bls	1$
6$		movem.l	d1/a0-a2,-(sp)		;Beyond the first 4 GB: fine when the
		move.l	d2,d0			; drive knows the 64-bit commands
		jsr	Dev64Cmd
		movem.l	(sp)+,d1/a0-a2
		cmp.w	#2,d0			;CMD_READ: it does not
		bne	1$
2$		move.l	d1,ReqArgs
		move.l	a3,-(sp)
		lea	ReqArgs,a3
		move.l	d3,d0
		move.l	#MSG_CHK_MISSING_GADS,d1
		jsr	SReq
		move.l	(sp)+,a3
		rts
1$		moveq	#2,d0
		rts

; Is jumping around in image file a0 slow? The Mac reads its disk in small
; pieces all over the image. The Fast File System finds a position in a file
; by walking a chain of blocks from the start of the file (or from where it
; was, when going forward): on a slow drive a jump of 100 MB then takes ten
; seconds and more, and the Mac seems to hang while it starts. PFS3, SFS and
; UAE's directory drives jump at once.
; Reads 512 bytes at SEEKTEST and takes the time. Files shorter than that are
; not tested. d0: seconds a jump of 100 MB would take, 0 = fast enough
SlowSeek	movem.l	d2-d6/a6,-(sp)
		lea	-2*ds_SIZEOF(sp),sp
		moveq	#0,d5
		move.l	_DOSBase,a6
		move.l	a0,d1
		move.l	#MODE_OLDFILE,d2
		JSRLIB	Open
		move.l	d0,d6
		beq	8$
		move.l	sp,d1
		JSRLIB	DateStamp
		move.l	d6,d1
		move.l	#SEEKTEST,d2
		moveq	#OFFSET_BEGINNING,d3
		JSRLIB	Seek
		tst.l	d0
		bmi	7$
		move.l	d6,d1
		move.l	#SeekBuf,d2
		move.l	#512,d3
		JSRLIB	Read
		cmp.l	#512,d0
		bne	7$
		lea	ds_SIZEOF(sp),a0
		move.l	a0,d1
		JSRLIB	DateStamp
		move.l	ds_SIZEOF+ds_Minute(sp),d5
		sub.l	ds_Minute(sp),d5
		mulu.l	#50*60,d5
		add.l	ds_SIZEOF+ds_Tick(sp),d5
		sub.l	ds_Tick(sp),d5		;d5: 1/50 seconds
7$		move.l	d6,d1
		JSRLIB	Close
8$		moveq	#0,d0
		cmp.l	#SEEKSLOW,d5
		blt	9$
		move.l	d5,d0			;ticks * (100 MB / SEEKTEST) / 50
		mulu.l	#(100*1024*1024/SEEKTEST),d0
		divu.l	#50,d0
		bne	9$
		moveq	#1,d0
9$		lea	2*ds_SIZEOF(sp),sp
		movem.l	(sp)+,d2-d6/a6
		rts

; Requester d0 (text) / d1 (gadgets) with the arguments in ReqArgs. d0: answer
Ask		move.l	a3,-(sp)
		lea	ReqArgs,a3
		jsr	SReq
		move.l	(sp)+,a3
		rts


		SECTION	"DATA",DATA


ReqArgs		dc.l	0,0,0

		SECTION	"BSS",BSS
SeekBuf		ds.b	512

		EVEN
