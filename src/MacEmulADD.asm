**
** Macintosh IIci-Emulator - Amiga Device Disk Treiber
** ===================================================
**
** © Copyright 1993-2001 Christian Bauer
**

DEBUG_DETAIL	SET 0

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/nodes.i"
		INCLUDE	"exec/lists.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"exec/io.i"
		INCLUDE	"exec/interrupts.i"
		INCLUDE	"exec/tasks.i"
		INCLUDE	"exec/execbase.i"
		INCLUDE	"dos/dosextens.i"
		INCLUDE	"dos/filehandler.i"
		INCLUDE	"dos/dostags.i"
		INCLUDE	"devices/trackdisk.i"
		INCLUDE	"devices/scsidisk.i"
		INCLUDE	"resources/disk.i"
		INCLUDE	"macros.i"
		INCLUDE	"macinclude.i"

		XDEF	SearchFloppys
		XDEF	CreateDiskTask
		XDEF	DeleteDiskTask
		XDEF	InstallADD
		XDEF	SonyHeader
		XDEF	SonyEnd
		XDEF	SonyRefNum
		XDEF	ADDRefNum
		XDEF	ADDWaitComplete

		XREF	PatchAfterFinder ;MacEmul.asm
		XREF	DrawDisk1Icon
		XREF	DrawDisk2Icon
		XREF	DrawDisk3Icon
		XREF	DrawDisk4Icon
		XREF	EraseDiskIcon
		XREF	Kludge720K
		XREF	SubtaskSet
		XREF	IsDraco
		XREF	DevProbe64	;MacEmulHFS.asm
		XREF	DevScanRDB

		SECTION	"CODE",CODE


**
** Definitionen
**

ASYNCIO		= 1		;Asynchron?

SonyRefNum	= -5		;Nummer des Sony-Treibers
ADDRefNum	= -64		;Nummer des Device-Disk-Treibers

; DriveStatus
 STRUCTURE	MyDrvSts,DSHD20_SIZEOF
	APTR	dsDiskIO	;IORequestPtr
	APTR	dsChangeIO	;IORequestPtr für DiskChange-Interrupt
	LONG	dsStartByte	;Byte-Offset zum Anfang des Mediums
	LONG	dsMaxTransfer	;Maximaler Blocktransfer
	APTR	dsDiskIcon
	APTR	dsDriveIcon
	BYTE	dsDiskEjected	;#0: Diskette ausgeworfen, aber noch nicht entnommen
	BYTE	dsToBeMounted	;#0: Diskette eingelegt, muß noch gemounted werden
	BYTE	dsMFMCrap	;#0: mfm.device <V41, Schrott-Modus aktiv
	BYTE	dsOnlyHD	;#0: Floppy ist nur HD (Draco, multidisk)
	LONG	dsUnit		;Unit-Nummer (nur Floppy)
	APTR	dsChgDevice	;io_Device and io_Unit of dsChangeIO as OpenDevice()
	APTR	dsChgUnit	; set them (see DTCloseDevice)
	LONG	dsStartHi	;High 32 bits of dsStartByte (64-bit drive commands)
	WORD	dsCmdRead	;CMD_READ, TD_READ64 or NSCMD_TD_READ64; 0: leave the disk out
	WORD	dsCmdWrite	;the write command that goes with it
 LABEL	MyDrvSts_SIZEOF

; DraCo
_LVOIsUnit	= -18
_LVOReadUnitID	= -48
_LVOSetUnitID	= -96

FDCDT_NODISK		EQU	0		;no disk in drive
FDCDT_DD512		EQU	1		;720K
FDCDT_DD1024		EQU	2		;820K
FDCDT_XD512		EQU	3		;880K
FDCDT_XD1024		EQU	4		;984K
FDCDT_HD512		EQU	5		;1440K
FDCDT_HD1024		EQU	6		;1804K
FDCDT_DDTD		EQU	$8007		;880K trackdisk READ ONLY
FDCDT_DDDS		EQU	$8008		;984K diskspare READ ONLY
FDCDT_HDTD		EQU	$8009		;1760K trackdisk READ ONLY
FDCDT_HDDS		EQU	$800A		;1968K diskspare READ ONLY


**
** Nach Diskettenlaufwerken suchen
**

SearchFloppys	clr.w	Floppy1			;Vorgabe: Keins
		clr.w	Floppy2

		tst.b	IsDraco
		bne	SearchDraco

		move.l	_DiskBase(pc),d0
		beq	WasLastDisk
		move.l	d0,a6

		moveq	#0,d2
SearchDisk1	move.l	d2,d0
		JSRLIB	GetUnitID
		cmp.l	#DRT_EMPTY,d0
		bne	FoundDisk1
		addq.b	#1,d2
		cmp.b	#4,d2
		bne	SearchDisk1
		bra	WasLastDisk

FoundDisk1	move.w	d2,d0
		addq.w	#FTYPE_DF0,d0
		move.w	d0,Floppy1		;1..4: mfm.device Unit 0..3

		addq.l	#1,d2
SearchDisk2	move.l	d2,d0
		JSRLIB	GetUnitID
		cmp.l	#DRT_EMPTY,d0
		bne	FoundDisk2
		addq.b	#1,d2
		cmp.b	#4,d2
		bne	SearchDisk2
		bra	WasLastDisk

FoundDisk2	addq.w	#FTYPE_DF0,d2
		move.w	d2,Floppy2		;1..4: mfm.device Unit 0..3
WasLastDisk	rts


SearchDraco	move.l	_FDCBase(pc),d0
		beq	WasLastDisk
		move.l	d0,a6

		moveq	#0,d2
SearchDraco1	move.l	d2,d0
		jsr	_LVOIsUnit(a6)
		tst.l	d0
		bne	FoundDraco1
		addq.b	#1,d2
		cmp.b	#2,d2
		bne	SearchDraco1
		bra	WasLastDisk

FoundDraco1	move.w	d2,d0
		addq.w	#FTYPE_DF0,d0
		move.w	d0,Floppy1		;1..2: dracodisk.device Unit 0..1

		addq.l	#1,d2
SearchDraco2	move.l	d2,d0
		jsr	_LVOIsUnit(a6)
		tst.l	d0
		bne	FoundDraco2
		addq.b	#1,d2
		cmp.b	#2,d2
		bne	SearchDraco2
		bra	WasLastDisk

FoundDraco2	addq.w	#FTYPE_DF0,d2
		move.w	d2,Floppy2		;1..2: dracodisk.device Unit 0..1
		rts


**
** Subtask für Disk-Handling einrichten
** Rückgabe: d0#0 = Fehler
**

; Signal für Emulator einrichten
CreateDiskTask	move.l	_ExecBase(pc),a6
		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,DTReadySig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,DTReadySet

; Task starten
		move.l	_DOSBase,a6
		move.l	#ProcTags,d1
		JSRLIB	CreateNewProc
		move.l	d0,DiskTaskProc
		beq	1$

; Auf Signal warten
		move.l	_ExecBase(pc),a6
		move.l	SubtaskSet,d0
		JSRLIB	Wait
		tst.w	DiskError	;Fehler aufgetreten?
		bne	1$
		moveq	#0,d0		;Alles OK
		rts

; Fehler aufgetreten
1$		moveq	#-1,d0
		rts


**
** Subtask entfernen
**

; Task stoppen
DeleteDiskTask	move.l	_ExecBase(pc),a6
		move.l	DiskTask,d0
		beq	1$
		move.l	d0,a1
		move.l	DiskQuitSet,d0
		JSRLIB	Signal
		move.l	SubtaskSet,d0
		JSRLIB	Wait

; Signale freigeben
1$		move.b	DTReadySig,d0
		JMPLIB	FreeSignal


**
** Header des Treibers
**

; Driver Header und Stubs (müssen relokatibel sein!)
SonyHeader	dc.w	$6f00		;Flags
		dc.w	0,0,0		;Delay, EMask, Menu
		dc.w	OpenStub-SonyHeader
		dc.w	PrimeStub-SonyHeader
		dc.w	ControlStub-SonyHeader
		dc.w	StatusStub-SonyHeader
		dc.w	CloseStub-SonyHeader
SonyName	dc.b	5,".Sony"
		EVEN
OpenStub	dc.w	$4ef9
		dc.l	SonyOpen
PrimeStub	dc.w	$4ef9
		dc.l	Prime
ControlStub	dc.w	$4ef9
		dc.l	Control
StatusStub	dc.w	$4ef9
		dc.l	Status
CloseStub	dc.w	$4ef9
		dc.l	SonyClose
SonyEnd

ADDHeader	dc.w	$4f04		;Flags (4: answers Driver Gestalt, see Status 43)
		dc.w	0,0,0		;Delay, EMask, Menu
		dc.w	ADDOpen-ADDHeader
		dc.w	Prime-ADDHeader
		dc.w	Control-ADDHeader
		dc.w	Status-ADDHeader
		dc.w	ADDClose-ADDHeader
ADDName		dc.b	16,".AmigaDeviceDisk"
		EVEN


**
** Installation der Device-Disk
**

; Treiber installieren
InstallADD	movem.l	d2/a0/a3,-(sp)
		lea	ADDHeader,a3
		moveq	#ADDRefNum,d2

		move.l	a3,a0
		move.l	d2,d0
		dc.w	$a43d		;DrvrInstallRsrvMem
		addq.l	#1,d2
		neg.l	d2
		move.l	([$11c],d2.w*4),a0 ;UTableBase
		move.l	(a0),a2
		dc.w	$a029		;HLock
		move.l	a3,a0
		move.l	a0,(a2)
		move.w	(a0)+,dCtlFlags(a2) ;Nur das obere Byte

; Treiber öffnen
		movem.l	(sp)+,d2/a0/a3
		move.l	#ADDName,ioNamePtr(a0)
		dc.w	$a000		;Open
		rts

; ADD-Open()
ADDOpen		moveq	#0,d0
		rts

; ADD-Close()
ADDClose	moveq	#-24,d0		;Close Error
		rts


*
* Open()-Routine
*

SonyOpen	movem.l	a0-a1,-(sp)

; Variablen belegen
		move.l	#$328,d0
		dc.w	$a71e		;NewPtrSysClear
		move.l	a0,$134		;SonyVars
		move.l	a1,(a0)		;DCE speichern

; Treiber auch als #-2 einrichten
		move.l	$11c,a2		;UTableBase
		move.l	16(a2),4(a2)
		move.b	#3,dCtlQHdr+qFlags+1(a1)
		clr.l	dCtlPosition(a1)
		move.l	a0,a2

; VBL-Task einhängen
		lea	4(a2),a0
		move.w	#1,4(a0)
		move.l	#VBLProc,6(a0)
		move.w	#15,10(a0)
		dc.w	$a033		;VInstall

; Laufwerk 1: DrvSts vorbereiten und Laufwerk anmelden
		moveq	#1,d0
		bsr	GetDrvA2
		tst.l	dsDiskIO(a2)
		beq	IONoDrive1

		tst.b	dsDiskEjected(a2)
		beq	1$
		move.b	#1,dsDiskInPlace(a2)
		clr.b	dsDiskEjected(a2)
1$		move.b	dsDiskInPlace(a2),dsToBeMounted(a2)
		move.b	#1,dsInstalled(a2)
		st	dsSides(a2)
		st	dsTwoSideFmt(a2)
		st	dsNeedsFlush(a2)
		st	dsOnlyTwoSides(a2)
		st	dsMFMDisk(a2)
		clr.l	dsStartByte(a2)
		move.l	#-1,dsMaxTransfer(a2)
		move.l	#DiskICON,dsDiskIcon(a2)
		move.l	#IntDriveICON,dsDriveIcon(a2)

		moveq	#1,d0		;Drive Number
		swap	d0
		move.w	#SonyRefNum,d0
		lea	dsQLink(a2),a0
		dc.w	$a04e		;AddDrive
IONoDrive1

; Laufwerk 2: DrvSts vorbereiten und Laufwerk anmelden
		moveq	#2,d0
		bsr	GetDrvA2
		tst.l	dsDiskIO(a2)
		beq	IONoDrive2

		tst.b	dsDiskEjected(a2)
		beq	1$
		move.b	#1,dsDiskInPlace(a2)
		clr.b	dsDiskEjected(a2)
1$		move.b	dsDiskInPlace(a2),dsToBeMounted(a2)
		move.b	#1,dsInstalled(a2)
		st	dsSides(a2)
		st	dsTwoSideFmt(a2)
		st	dsNeedsFlush(a2)
		st	dsOnlyTwoSides(a2)
		st	dsMFMDisk(a2)
		clr.l	dsStartByte(a2)
		move.l	#-1,dsMaxTransfer(a2)
		move.l	#DiskICON,dsDiskIcon(a2)
		move.l	#ExtDriveICON,dsDriveIcon(a2)

		moveq	#2,d0		;Drive Number
		swap	d0
		move.w	#SonyRefNum,d0
		lea	dsQLink(a2),a0
		dc.w	$a04e		;AddDrive
IONoDrive2

; Laufwerk 3: DrvSts vorbereiten und Laufwerk anmelden
		moveq	#3,d0
		bsr	GetDrvA2
		tst.l	dsDiskIO(a2)
		beq	IONoDrive3

		tst.b	dsDiskEjected(a2)
		beq	1$
		move.b	#1,dsDiskInPlace(a2)
		clr.b	dsDiskEjected(a2)
1$		move.b	dsDiskInPlace(a2),dsToBeMounted(a2)
		move.b	#1,dsSides(a2)
		move.w	#1,dsQType(a2)		;HD20
		move.w	#3,dsDriveType(a2)
		move.l	ADDSectors1,d0
		swap	d0
		move.l	d0,dsDriveSize(a2)
		tst.w	dsCmdRead(a2)		;Left out by ADDProbe64 (Amiga partition table)
		beq	IONoDrive3
		move.l	ADDStartSector1,d0	;Beyond the first 4 GB of the drive the drive
		add.l	ADDSectors1,d0		; has to know the 64-bit commands (ADDProbe64
		bcs	30$			; looked). Without them the disk is left out:
		cmp.l	#$800000,d0		; the 32-bit byte offsets would wrap onto the
		bls	31$			; start of the drive (MacEmulCheck says why).
30$		cmp.w	#CMD_READ,dsCmdRead(a2)
		beq	IONoDrive3
31$		move.b	#1,dsInstalled(a2)	;(only now: a disk left out must not answer driver calls)
		move.l	ADDStartSector1,d0
		move.l	d0,d1
		lsl.l	#8,d0
		lsl.l	#1,d0		;*512
		move.l	d0,dsStartByte(a2)
		moveq	#23,d0
		lsr.l	d0,d1
		move.l	d1,dsStartHi(a2)
		move.l	#-1,dsMaxTransfer(a2)	;Vorgabe
		move.l	ADDMaxTransfer1,d0
		beq	2$
		and.l	#-512,d0		;Abrunden
		move.l	d0,dsMaxTransfer(a2)
2$		move.l	#ADDDiskICON,dsDiskIcon(a2)
		move.l	#ADD1DriveICON,dsDriveIcon(a2)

		moveq	#3,d0		;Drive Number
		swap	d0
		move.w	#ADDRefNum,d0
		lea	dsQLink(a2),a0
		dc.w	$a04e		;AddDrive
IONoDrive3

; Laufwerk 4: DrvSts vorbereiten und Laufwerk anmelden
		moveq	#4,d0
		bsr	GetDrvA2
		tst.l	dsDiskIO(a2)
		beq	IONoDrive4

		tst.b	dsDiskEjected(a2)
		beq	1$
		move.b	#1,dsDiskInPlace(a2)
		clr.b	dsDiskEjected(a2)
1$		move.b	dsDiskInPlace(a2),dsToBeMounted(a2)
		move.b	#1,dsSides(a2)
		move.w	#1,dsQType(a2)		;HD20
		move.w	#4,dsDriveType(a2)
		move.l	ADDSectors2,d0
		swap	d0
		move.l	d0,dsDriveSize(a2)
		tst.w	dsCmdRead(a2)		;Left out by ADDProbe64 (Amiga partition table)
		beq	IONoDrive4
		move.l	ADDStartSector2,d0	;Beyond the first 4 GB of the drive the drive
		add.l	ADDSectors2,d0		; has to know the 64-bit commands (ADDProbe64
		bcs	30$			; looked). Without them the disk is left out:
		cmp.l	#$800000,d0		; the 32-bit byte offsets would wrap onto the
		bls	31$			; start of the drive (MacEmulCheck says why).
30$		cmp.w	#CMD_READ,dsCmdRead(a2)
		beq	IONoDrive4
31$		move.b	#1,dsInstalled(a2)	;(only now: a disk left out must not answer driver calls)
		move.l	ADDStartSector2,d0
		move.l	d0,d1
		lsl.l	#8,d0
		lsl.l	#1,d0		;*512
		move.l	d0,dsStartByte(a2)
		moveq	#23,d0
		lsr.l	d0,d1
		move.l	d1,dsStartHi(a2)
		move.l	#-1,dsMaxTransfer(a2)	;Vorgabe
		move.l	ADDMaxTransfer2,d0
		beq	2$
		and.l	#-512,d0		;Abrunden
		move.l	d0,dsMaxTransfer(a2)
2$		move.l	#ADDDiskICON,dsDiskIcon(a2)
		move.l	#ADD2DriveICON,dsDriveIcon(a2)

		moveq	#4,d0		;Drive Number
		swap	d0
		move.w	#ADDRefNum,d0
		lea	dsQLink(a2),a0
		dc.w	$a04e		;AddDrive
IONoDrive4

; Traps etc. einrichten
		move.l	#JFigTrkSpd,$222
		move.l	#Prime,$226		;JDiskPrime
		move.l	#JReadAddr,$22a
		move.l	#JReadData,$22e
		move.l	#JWriteData,$232
		move.l	#ADDIllegal,$236	;JSeek
		move.l	#JSetupPoll,$23a
		move.l	#ADDIllegal,$23e	;JRecal
		move.l	#Control,$242		;JControl
		move.l	#ADDIllegal,$246	;JWakeUp
		move.l	#ADDIllegal,$24a	;JReSeek
		move.l	#ADDIllegal,$24e	;JMakeSpdTbl
		move.l	#JAdrDisk,$252
		move.l	#JSetSpeed,$256
		move.l	#NiblTbl,$25a

		move.l	#JReadAddr,$680		;Traps $a0a0-$a0a2
		move.l	#JReadData,$684
		move.l	#JWriteData,$688

		lea	ADDIllegal,a0
		lea	$b40,a1
		move.l	a0,(a1)+
		move.l	a0,(a1)+
		move.l	a0,(a1)
		move.l	a0,$13e		;PollProc

; Zurückkehren
		moveq	#0,d0		;Alles OK
		movem.l	(sp)+,a0-a1
		rts

; Dummy-Routinen
ADDIllegal	moveq	#0,d0
JSetSpeed	rts

JFigTrkSpd	moveq	#-1,d0
		rts

JReadAddr	moveq	#-67,d0		;noAdrMkErr
		rts

JReadData	moveq	#-71,d0		;noDtaMkErr
		rts

JWriteData	moveq	#-74,d0		;wrUnderrun
		rts

JSetupPoll	move.l	$1d8,a6
		addq.l	#6,a6
		move.l	$1d4,a5
		lea	$1e00(a5),a5
		move.l	sp,$13a
		add.l	d0,$13a
		rts

JAdrDisk	move.l	$1e0,a0
		move.l	$1d4,a2
		clr.w	d1
		rts

*
* Close()-Routine (wird nie aufgerufen)
*

SonyClose	moveq	#-24,d0		;Close error
		rts


*
* Prime()-Routine
*

Prime		movem.l	a0-a1,-(sp)
		bsr	GetDrvStatus	;Laufwerk vorhanden?

; Diskette vorhanden?
		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine
		cmp.b	#8,dsDiskInPlace(a2)
		beq	1$
		move.b	#2,dsDiskInPlace(a2)	;Disk accessed
1$

; Auf DiskTask warten
		bsr	ADDWaitComplete

; DiskTask benachrichtigen
		move.l	a0,DiskParmBlock
		move.l	a1,DiskDCE

		move.l	a6,-(sp)
		move.l	_ExecBase(pc),a6
		move.l	DiskTask,a1
		move.l	DiskSignalSet,d0

	IFEQ	ASYNCIO
		bra	PrimeSync
	ENDC

	IFNE	ASYNCIO
		tst.l	ioCompletion(a0) ;Completion Routine vorhanden?
		bne	PrimeSync	;Ja, dann warten (die Routine könnte
					; einen weiteren IO-Vorgang starten
					; und die wird dann vom DiskTask
					; aus ausgeführt...)
	ENDC

PrimeAsync	st.b	DiskTaskAsync
		JSRLIB	Signal
		move.l	(sp)+,a6
		moveq	#1,d0		;Request noch nicht beendet
		bra	IOReturn

PrimeSync	clr.b	DiskTaskAsync
		JSRLIB	Signal
		move.l	DTReadySet,d0
		EJSRLIB	Wait
		move.l	(sp)+,a6
		move.w	DiskError,d0
		bra	IOReturn

PrimeFromDT	move.l	a0,DiskParmBlock
		move.l	a1,DiskDCE
		move.l	DiskSignalSet,d0
		or.l	d0,TheSignals
		moveq	#1,d0
		bra	IOReturn


*
* Control()-Routine
*

Control		movem.l	a0-a1,-(sp)

		DPRINTF	"ADD Control %08lx %08lx",csCode(a0),csParam+2(a0)

; Control-Code abfragen
; 65: Make Periodic Action
		cmp.w	#accRun,csCode(a0)
		bne	ControlNot65

		movem.l	a0-a1,-(sp)

		tst.b	DriveStatus1+dsToBeMounted
		beq	1$
		moveq	#1,d0		;Drive Number
		move.w	#7,a0		;diskEvent
		dc.w	$a02f		;PostEvent
		clr.b	DriveStatus1+dsDiskEjected
		clr.b	DriveStatus1+dsToBeMounted
		cmp.b	#8,DriveStatus1+dsDiskInPlace
		beq	1$
		move.b	#1,DriveStatus1+dsDiskInPlace

1$		tst.b	DriveStatus2+dsToBeMounted
		beq	2$
		moveq	#2,d0		;Drive Number
		move.w	#7,a0		;diskEvent
		dc.w	$a02f		;PostEvent
		clr.b	DriveStatus2+dsDiskEjected
		clr.b	DriveStatus2+dsToBeMounted
		cmp.b	#8,DriveStatus2+dsDiskInPlace
		beq	2$
		move.b	#1,DriveStatus2+dsDiskInPlace

2$		tst.b	DriveStatus3+dsToBeMounted
		beq	3$
		moveq	#3,d0		;Drive Number
		move.w	#7,a0		;diskEvent
		dc.w	$a02f		;PostEvent
		clr.b	DriveStatus3+dsDiskEjected
		clr.b	DriveStatus3+dsToBeMounted
		cmp.b	#8,DriveStatus3+dsDiskInPlace
		beq	3$
		move.b	#1,DriveStatus3+dsDiskInPlace

3$		tst.b	DriveStatus4+dsToBeMounted
		beq	4$
		moveq	#4,d0		;Drive Number
		move.w	#7,a0		;diskEvent
		dc.w	$a02f		;PostEvent
		clr.b	DriveStatus4+dsDiskEjected
		clr.b	DriveStatus4+dsToBeMounted
		cmp.b	#8,DriveStatus4+dsDiskInPlace
		beq	4$
		move.b	#1,DriveStatus4+dsDiskInPlace

4$		movem.l	(sp)+,a0-a1
		and.w	#$4fff,dCtlFlags(a1)	;NeedNoTime

		movem.l	d4-d7/a4-a6,-(sp)	;Patches anbringen
		bsr	PatchAfterFinder
		movem.l	(sp)+,d4-d7/a4-a6

		bra	IOReturnOK

ControlNot65	cmp.w	#8,csCode(a0)	;Set Tag Buffer?
		beq	IOReturnOK	;Ja, Rückkehr
		cmp.w	#9,csCode(a0)	;Track Cache?
		beq	IOReturnOK	;Ja, RÜckkehr

		bsr	GetDrvStatus	;Laufwerk vorhanden?

; 1: KillIO
		cmp.w	#killCode,csCode(a0)
		bne	ControlNot1

		bsr	ADDWaitComplete

		moveq	#0,d0
		movem.l	(sp)+,a0-a1
		rts

; 5: Verify Disk
ControlNot1	cmp.w	#5,csCode(a0)
		bne	ControlNot5

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine
		tst.w	dsQType(a2)
		bne	IOControlImpl	;HD20 -> Befehl nicht vorhanden

		move.l	a6,-(sp)
		bsr	ADDWaitComplete
		move.l	a0,DiskParmBlock
		move.l	a1,DiskDCE
		move.l	_ExecBase(pc),a6
		move.l	DiskTask,a1
		move.l	DiskVerifySet,d0
		JSRLIB	Signal
		move.l	DTReadySet,d0
		EJSRLIB	Wait
		move.l	(sp)+,a6

		move.w	DiskError,d0
		bra	IOReturn

; 6: Format Disk
ControlNot5	cmp.w	#6,csCode(a0)
		bne	ControlNot6

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine
		tst.b	dsWriteProt(a2)
		bmi	IOWriteProt
		tst.w	dsQType(a2)
		bne	IOReturnOK	;HD 20 -> Alles OK

		move.l	a6,-(sp)
		bsr	ADDWaitComplete
		move.l	a0,DiskParmBlock
		move.l	a1,DiskDCE
		clr.l	DiskFormatData	;Nur formatieren
		move.l	_ExecBase(pc),a6
		move.l	DiskTask,a1
		move.l	DiskFormatSet,d0
		JSRLIB	Signal
		move.l	DTReadySet,d0
		EJSRLIB	Wait
		move.l	(sp)+,a6

		move.w	DiskError,d0
		bra	IOReturn

; 7: Eject
ControlNot6	cmp.w	#7,csCode(a0)
		bne	ControlNot7

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine
		cmp.b	#8,dsDiskInPlace(a2)	;Fixed Disk?
		beq	ADDCtrl6Remount

		move.l	a6,-(sp)
		bsr	ADDWaitComplete
		move.l	a0,DiskParmBlock
		move.l	a1,DiskDCE
		move.l	_ExecBase(pc),a6
		move.l	DiskTask,a1
		move.l	DiskEjectSet,d0
		JSRLIB	Signal
		move.l	DTReadySet,d0
		EJSRLIB	Wait
		move.l	(sp)+,a6
		bra	IOReturnOK

ADDCtrl6Remount	moveq	#0,d0
		move.w	dsDrive(a2),d0
		move.w	#7,a0		;diskEvent
		dc.w	$a02f		;PostEvent
		bra	IOControlImpl

; 21: Return Drive Icon
ControlNot7	cmp.w	#21,csCode(a0)
		bne	ControlNot21

		move.l	dsDriveIcon(a2),csParam(a0)
		bra	IOReturnOK

; 22: Return Disk Icon
ControlNot21	cmp.w	#22,csCode(a0)
		bne	ControlNot22

		move.l	dsDiskIcon(a2),csParam(a0)
		bra	IOReturnOK

; 23: Return Drive Info
ControlNot22	cmp.w	#23,csCode(a0)
		bne	ControlNot23

		tst.w	dsQType(a2)
		bne	1$
		moveq	#4,d0		;SuperDrive
		bra	2$
1$		moveq	#1,d0		;Unspecified
2$
		cmp.w	#2,dsDrive(a2)	;Zweites Diskettenlaufwerk?
		bne	3$
		or.w	#$0100,d0	;Ja, extern
3$
		cmp.w	#4,dsDrive(a2)	;Zweite ADD?
		bne	4$
		or.w	#$0800,d0	;Ja, secondary
4$
		cmp.b	#8,dsDiskInPlace(a2) ;Fixed Disk?
		bne	5$
		or.w	#$0400,d0	;Ja, Flag setzen
5$
		move.l	d0,csParam(a0)
		bra	IOReturnOK

; 'SC': Format And Write To Disk
ControlNot23	cmp.w	#'SC',csCode(a0)
		bne	ControlNotSC

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine
		tst.b	dsWriteProt(a2)
		bmi	IOWriteProt
		tst.w	dsQType(a2)
		beq	1$
		moveq	#-1,d0		;HD20: Fehler
		bra	IOReturn

1$		move.l	a6,-(sp)
		bsr	ADDWaitComplete
		move.l	a0,DiskParmBlock
		move.l	a1,DiskDCE
		move.l	csParam+2(a0),DiskFormatData
		move.l	_ExecBase(pc),a6
		move.l	DiskTask,a1
		move.l	DiskFormatSet,d0
		JSRLIB	Signal
		move.l	DTReadySet,d0
		EJSRLIB	Wait
		move.l	(sp)+,a6

		move.w	DiskError,d0
		bra	IOReturn

; Unbekannter Control-Code
ControlNotSC	bra	IOControlImpl

*
* Status()-Routine
*

Status		movem.l	a0-a1,-(sp)
		bsr	GetDrvStatus	;Laufwerk vorhanden?

		DPRINTF	"ADD Status %08lx %08lx",csCode(a0),csParam+2(a0)

; Status-Code abfragen
; 6: Return Format List
		cmp.w	#6,csCode(a0)
		bne	StatusNot6

		tst.w	csParam(a0)	;Gewünschte Anzahl Formate <=0: Fehler
		ble	IOParamErr

		move.w	#1,csParam(a0)	;Anzahl Formate
		move.l	csParam+2(a0),a0

		tst.w	dsQType(a2)	;HD20?
		bne	2$

		tst.b	dsHDDisk(a2)	;HD-Diskette?
		bpl	1$
		move.l	#2880,(a0)+	;Ja, 2880 Sektoren
		move.l	#$d2120050,(a0)+
		bra	IOReturnOK

1$		tst.l	Kludge720K
		beq	11$
		move.l	#1439,(a0)+	;Nein, 1439 Sektoren
		move.l	#$c2090050,(a0)+
		bra	IOReturnOK
11$		move.l	#1440,(a0)+	;Nein, 1440 Sektoren
		move.l	#$c2090050,(a0)+
		bra	IOReturnOK

2$		move.l	dsDriveSize(a2),d0	;HD20
		swap	d0
		move.l	d0,(a0)+
		move.l	#$40000000,(a0)+ ;Current disk has this format
		bra	IOReturnOK

; 8: Get Drive Status
StatusNot6	cmp.w	#8,csCode(a0)
		bne	StatusNot8

		lea	csParam(a0),a0	;Statusinformationen kopieren
		moveq	#10,d0
1$		move.w	(a2)+,(a0)+
		dbra	d0,1$
		bra	IOReturnOK

; 10: Get Disk Type
StatusNot8	cmp.w	#10,csCode(a0)
		bne	StatusNot10

		tst.w	dsQType(a2)	;Sony?
		bne	1$
		move.l	dsOnlyTwoSides(a2),d0 ;Ja, OnlyTwoSides/MFM/HD holen
		move.b	#$fe,d0		;SWIM vorhanden
		move.l	d0,csParam(a0)	;Information kopieren
		bra	IOReturnOK
1$		move.l	#$fe,csParam(a0)
		bra	IOReturnOK

; 'DV': Duplicator Version Supported
StatusNot10	cmp.w	#'DV',csCode(a0)
		bne	StatusNotDV

		move.w	#$410,csParam(a0)	;4.1.0
		bra	IOReturnOK

; 'SC': Return Address Header Format Byte
StatusNotDV	cmp.w	#'SC',csCode(a0)
		bne	StatusNotSC

		move.b	#$22,csParam(a0)	;512 Byte pro Sektor
		bra	IOReturnOK

; 43: Driver Gestalt. 'wide': positions of 64 bits are understood
StatusNotSC	cmp.w	#43,csCode(a0)
		bne	StatusNot43

		cmp.l	#'wide',csParam(a0)
		bne	IOStatusImpl
		move.l	#$01000000,csParam+4(a0)	;true
		bra	IOReturnOK

; Unbekannter Status-Code
StatusNot43	bra	IOStatusImpl


*
* Prüft, ob das angegebene Laufwerk angeschlossen ist,
* (IOParam in a0) und holt das DrvSts nach a2.
* Erzeugt IOError, wenn Laufwerk nicht vorhanden.
* Darf a0 und a1 nicht verändern!
*

GetDrvStatus	move.w	ioVRefNum(a0),d0
		beq	GetDrvNoDrv
		cmp.w	#SonyRefNum,ioRefNum(a0)
		bne	1$
		cmp.w	#2,d0		;Höchste Nummer für .Sony
		bhi	GetDrvNoDrv
		bra	2$
1$		cmp.w	#2,d0		;Niedrigste Nummer für .ADD
		bls	GetDrvNoDrv
		cmp.w	#4,d0		;Höchste Nummer für .ADD
		bhi	GetDrvNoDrv
2$		bsr	GetDrvA2
		tst.b	dsInstalled(a2)
		beq	GetDrvNoDrv
		rts

; Holt das DrvSts von Laufwerk d0 nach a2
GetDrvA2	cmp.w	#1,d0
		bne	1$
		lea	DriveStatus1,a2
		rts
1$		cmp.w	#2,d0
		bne	2$
		lea	DriveStatus2,a2
		rts
2$		cmp.w	#3,d0
		bne	3$
		lea	DriveStatus3,a2
		rts
3$		lea	DriveStatus4,a2
		rts

GetDrvNoDrv	move.l	(sp)+,d0	;RTS löschen
		bra	IONoDrive


*
* Rückkehr aus Treiberroutine
*

IOParamErr	moveq	#-50,d0		;Parameter Error
		bra	IOReturn
IONoDrive	moveq	#-56,d0		;No Such Drive
		bra	IOReturn
IOOffLine	moveq	#-65,d0		;Volume Off Line
		bra	IOReturn
IOWriteProt	moveq	#-44,d0		;Write Protected
		bra	IOReturn
IOControlImpl	moveq	#-17,d0		;Unimplemented control
		bra	IOReturn
IOStatusImpl	moveq	#-18,d0		;Unimplemented status
		bra	IOReturn

IOReturnOK	moveq	#0,d0		;Alles OK

IOReturn	movem.l	(sp)+,a0-a1	;ParamBlock und DCE wiederherstellen

		tst.w	d0
		beq	1$
		move.w	d0,DskErr

1$		btst	#noQueueBit-8,ioTrap(a0) ;Immediale calls mit RTS beenden
		beq	Queued

NotQueued	tst.w	d0
		ble	ImmedRTS
		clr.w	d0		;Request noch nicht beendet
ImmedRTS	move.w	d0,ioResult(a0)
		rts

Queued		tst.w	d0
		ble	IODone
		clr.w	d0		;Request noch nicht beendet
		rts
IODone		move.l	JIODone,a0
		jmp	(a0)

; Wenn der DiskTask beschäftigt ist, auf Beendigung warten
ADDWaitComplete	tst.b	DiskTaskAsync
		beq	WaitDidIt
		movem.l	d0-d1/a0-a1/a6,-(sp)
		move	sr,-(sp)
		move.w	#$2000,sr
		move.l	_ExecBase(pc),a6
		move.l	DTReadySet,d0
		EJSRLIB	Wait
		move	(sp)+,sr
		movem.l	(sp)+,d0-d1/a0-a1/a6
		clr.b	DiskTaskAsync
WaitDidIt	rts


**
** VBL-Routine
**

; Zähler neu setzen
VBLProc		move.w	#15,10(a0)

; Kennzeichen blinken, wenn Diskette "ausgeworfen"
		tst.b	DriveStatus1+dsDiskEjected
		beq	1$
		jmp	DrawDisk1Icon
1$		tst.b	DriveStatus2+dsDiskEjected
		beq	2$
		jmp	DrawDisk2Icon
2$		tst.b	DriveStatus3+dsDiskEjected
		beq	3$
		jmp	DrawDisk3Icon
3$		tst.b	DriveStatus4+dsDiskEjected
		beq	4$
		jmp	DrawDisk4Icon
4$		rts


**
** Subtask für Disk-Handling
**

; Task ermitteln
DiskTaskMain	move.l	_ExecBase(pc),a6
		sub.l	a1,a1
		JSRLIB	FindTask
		move.l	d0,DiskTask

; Signale zur Kommunikation anfordern
		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,DiskSignalSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,DiskSignalSet

		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,DiskEjectSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,DiskEjectSet

		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,DiskFormatSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,DiskFormatSet

		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,DiskVerifySig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,DiskVerifySet

		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,DiskChangedSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,DiskChangedSet

		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,DiskQuitSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,DiskQuitSet

; MessagePort einrichten
		move.w	#-1,DiskError		;Vorgabe: Fehler

		JSRLIB	CreateMsgPort
		move.l	d0,DiskMsgPort
		beq	DTSigEmul		;Fehler: Auf Quit-Signal warten

; Partitionsnamen in ADDs konvertieren
		lea	ADDName1,a0		;':' als letztes Zeichen?
		tst.b	(a0)
		beq	10$
		moveq	#79,d0
11$		tst.b	(a0)+
		dbeq	d0,11$
		cmp.b	#':',-2(a0)
		bne	10$
		lea	ADDName1,a2		;Ja, Daten holen
		lea	PartPrefsTab1,a5
		bsr	AnalyzePart
10$
		lea	ADDName2,a0
		tst.b	(a0)
		beq	20$
		moveq	#79,d0
21$		tst.b	(a0)+
		dbeq	d0,21$
		cmp.b	#':',-2(a0)
		bne	20$
		lea	ADDName2,a2
		lea	PartPrefsTab2,a5
		bsr	AnalyzePart
20$

; Floppy 1 öffnen
		lea	DriveStatus1,a2
		moveq	#0,d2
		move.w	Floppy1,d2
		beq	1$			;Keins?
		cmp.w	#FTYPE_PH0,d2		;Nein, multidisk.device?
		blt	101$
		subq.l	#FTYPE_PH0,d2		;Ja
		move.l	d2,dsUnit(a2)
		st	dsOnlyHD(a2)
		moveq	#3,d4			;OpenFlags: MS-DOS HD
		lea	MultiName,a3
		bra	100$
101$		subq.l	#FTYPE_DF0,d2		;Nein
		move.l	d2,dsUnit(a2)
		moveq	#0,d4			;OpenFlags
		lea	TrackName,a3
		clr.b	dsOnlyHD(a2)
		tst.b	IsDraco
		beq	100$
		lea	DracoName,a3
		st	dsOnlyHD(a2)
100$		lea	DiskInterrupt1,a4
		moveq	#-1,d3			;Wechselmedium
		bsr	DTOpenDevice

		lea	DriveStatus1,a2		;HD oder DD?
		tst.b	dsDiskInPlace(a2)
		beq	1$
		bsr	DTIsHD
1$

; Floppy 2 öffnen
		lea	DriveStatus2,a2
		moveq	#0,d2
		move.w	Floppy2,d2
		beq	2$			;Keins?
		cmp.w	#FTYPE_PH0,d2		;Nein, multidisk.device?
		blt	201$
		subq.l	#FTYPE_PH0,d2		;Ja
		move.l	d2,dsUnit(a2)
		moveq	#3,d4			;OpenFlags: MS-DOS HD
		lea	MultiName,a3
		bra	200$
201$		subq.l	#FTYPE_DF0,d2		;Nein
		move.l	d2,dsUnit(a2)
		moveq	#0,d4			;OpenFlags
		lea	TrackName,a3
		tst.b	IsDraco
		beq	200$
		lea	DracoName,a3
200$		lea	DiskInterrupt2,a4
		moveq	#-1,d3			;Wechselmedium
		bsr	DTOpenDevice

		lea	DriveStatus2,a2		;HD oder DD?
		tst.b	dsDiskInPlace(a2)
		beq	2$
		bsr	DTIsHD
2$

; ADD 1 öffnen
		lea	DriveStatus3,a2
		lea	ADDName1,a3
		lea	DiskInterrupt3,a4
		move.l	ADDUnit1,d2
		move.w	ADDRemovable1,d3
		moveq	#0,d4
		bsr	DTOpenDevice
		lea	ADDSectors1,a0
		move.l	ADDStartSector1,d0
		bsr	ADDWholeDrive
		move.l	ADDStartSector1,d0
		move.l	ADDSectors1,d1
		bsr	ADDProbe64

; ADD 2 öffnen
		lea	DriveStatus4,a2
		lea	ADDName2,a3
		lea	DiskInterrupt4,a4
		move.l	ADDUnit2,d2
		move.w	ADDRemovable2,d3
		moveq	#0,d4
		bsr	DTOpenDevice
		lea	ADDSectors2,a0
		move.l	ADDStartSector2,d0
		bsr	ADDWholeDrive
		move.l	ADDStartSector2,d0
		move.l	ADDSectors2,d1
		bsr	ADDProbe64

; Floppy 1 sperren, falls gewünscht
		move.w	Floppy1,d0
		beq	3$			;Keins?
		tst.w	InhibitFloppy1
		beq	3$
		add.b	#'0'-FTYPE_DF0,d0
		move.b	d0,FloppyDOSChar
		move.l	_DOSBase,a6
		move.l	#FloppyDOSName,d1
		move.l	#DOSTRUE,d2
		JSRLIB	Inhibit
		st.b	Flop1Inhibited
3$

; Floppy 2 sperren, falls gewünscht
		move.w	Floppy2,d0
		beq	4$			;Keins?
		tst.w	InhibitFloppy2
		beq	4$
		add.b	#'0'-FTYPE_DF0,d0
		move.b	d0,FloppyDOSChar
		move.l	_DOSBase,a6
		move.l	#FloppyDOSName,d1
		move.l	#DOSTRUE,d2
		JSRLIB	Inhibit
		st.b	Flop2Inhibited
4$
		clr.w	DiskError

; Dem Emulator Bescheid sagen
DTSigEmul	move.l	_ExecBase(pc),a6
		move.l	MyTask,a1
		move.l	SubtaskSet,d0
		JSRLIB	Signal

; Hauptschleife: Auf Signal warten
DTMainLoop	move.l	_ExecBase(pc),a6
		move.l	DiskSignalSet,d0
		or.l	DiskEjectSet,d0
		or.l	DiskFormatSet,d0
		or.l	DiskVerifySet,d0
		or.l	DiskChangedSet,d0
		or.l	DiskQuitSet,d0
		JSRLIB	Wait
		move.l	d0,TheSignals

DTSigLoop	move.l	TheSignals,d0
		move.l	d0,d1
		and.l	DiskSignalSet,d1
		beq	1$
		eor.l	d1,TheSignals
		bra	DTDoIO

1$		move.l	d0,d1
		and.l	DiskEjectSet,d1
		beq	2$
		eor.l	d1,TheSignals
		bra	DTEject

2$		move.l	d0,d1
		and.l	DiskFormatSet,d1
		beq	3$
		eor.l	d1,TheSignals
		bra	DTFormat

3$		move.l	d0,d1
		and.l	DiskChangedSet,d1
		beq	4$
		eor.l	d1,TheSignals
		bra	DTChanged

4$		move.l	d0,d1
		and.l	DiskQuitSet,d1
		beq	5$
		eor.l	d1,TheSignals
		bra	DTQuit

5$		move.l	d0,d1
		and.l	DiskVerifySet,d1
		beq	DTMainLoop
		eor.l	d1,TheSignals
		bra	DTVerify

; Signal eingetroffen, IO-Daten holen, Laufwerk setzen
DTDoIO		move.l	DiskParmBlock,a0
		move.w	ioVRefNum(a0),d0	;Drive Number
		bsr	GetDrvA2		;DriveSts nach a2

		move.l	DiskParmBlock,a0
		move.l	DiskDCE,a1

; Where on the Mac disk. A wide request (kUseWidePositioning in ioPosMode)
; carries a 64-bit position in ioWPosOffset: the Mac sends those to a disk
; of more than 4 GB. Else it is dCtlPosition, an unsigned number (a device
; disk may have 2 to 4 GB); on a floppy a negative one stays an error.
		moveq	#0,d5			;d5: high 32 bits of the position
		moveq	#0,d7			;d7: a wide request
		btst	#0,ioPosMode(a0)		;(kWidePosOffsetBit = 8)
		beq	70$
		moveq	#1,d7
		move.l	ioPosOffset(a0),d5	;(ioWPosOffset: 8 bytes from here)
		bmi	DTIOOutOfRange
		move.l	ioPosOffset+4(a0),d2
		bra	71$
70$		move.l	dCtlPosition(a1),d2
		bpl	71$
		cmp.w	#1,dsQType(a2)		;HD20?
		bne	DTIOOutOfRange

71$		add.l	dsStartByte(a2),d2	;d2/d5: Startbyte
		move.l	dsStartHi(a2),d0
		addx.l	d0,d5
		bcs	DTIOOutOfRange
		move.l	ioReqCount(a0),d3	;d3: Anzahl Bytes
		move.l	d3,d6			;d6: all of it (ioActCount when it is done)
		cmp.w	#CMD_READ,dsCmdRead(a2)	;32-bit commands: no wrapping past 4 GB
		bne	7$
		tst.l	d5
		bne	DTIOOutOfRange
		move.l	d2,d0
		add.l	d3,d0
		bcc	7$
		tst.l	d0			;ending exactly at 4 GB is still fine
		bne	DTIOOutOfRange
7$		move.l	ioBuffer(a0),a3		;a3: Zieladresse

; Schreiben oder Lesen?
		cmp.b	#aWrCmd,ioTrap+1(a0)
		beq	DTWrite

; Lesen
		btst	#rdVerifyBit,ioPosMode+1(a0)
		bne	DTPrimeVerify

DTRead		clr.l	$2fc		;TagBuf löschen
		clr.l	$300
		clr.l	$304

DTReadLoop	move.l	dsDiskIO(a2),a1

		move.l	dsMaxTransfer(a2),d0
		cmp.l	d0,d3		;Blockgröße > MaxTransfer?
		bhi	1$
		move.l	d3,d4		;Nein, alles übertragen
		bra	2$
1$		move.l	d0,d4		;Ja, nur MaxTransfer übertragen
2$
		move.l	a3,IO_DATA(a1)
		move.l	d2,IO_OFFSET(a1)
		move.l	d5,IO_ACTUAL(a1)	;(64-bit commands: the high half of the offset)
		move.l	d4,IO_LENGTH(a1)
		move.w	dsCmdRead(a2),IO_COMMAND(a1)
		JSRLIB	DoIO
		tst.l	d0
		bne	DTReadErr
		sub.l	d4,d3		;Übertragene Größe von Restlänge abziehen
		beq	DTIOAll		;Alles übertragen, dann fertig
		add.l	d4,d2		;Sonst Offset und Data erhöhen
		moveq	#0,d0
		addx.l	d0,d5
		add.l	d4,a3
		bra	DTReadLoop	;und den nächsten Block lesen

DTReadErr	moveq	#-19,d0		;Read Error
		bra	DTIONone

; Schreiben
DTWrite		tst.b	dsWriteProt(a2)	;Schreibschutz an?
		bmi	DTWriteProt

DTWriteLoop	move.l	dsDiskIO(a2),a1

		move.l	dsMaxTransfer(a2),d0
		cmp.l	d0,d3		;Blockgröße > MaxTransfer?
		bhi	1$
		move.l	d3,d4		;Nein, alles übertragen
		bra	2$
1$		move.l	d0,d4		;Ja, nur MaxTransfer übertragen
2$
		move.l	a3,IO_DATA(a1)
		move.l	d2,IO_OFFSET(a1)
		move.l	d5,IO_ACTUAL(a1)	;(64-bit commands: the high half of the offset)
		move.l	d4,IO_LENGTH(a1)
		move.w	dsCmdWrite(a2),IO_COMMAND(a1)
		JSRLIB	DoIO
		tst.l	d0
		bne	DTWriteErr
		sub.l	d4,d3		;Übertragene Größe von Restlänge abziehen
		beq	DTIOAll		;Alles übertragen, dann fertig
		add.l	d4,d2		;Sonst Offset und Data erhöhen
		moveq	#0,d0
		addx.l	d0,d5
		add.l	d4,a3
		bra	DTWriteLoop	;und den nächsten Block schreiben

DTWriteErr	moveq	#-20,d0		;Write Error
		bra	DTIONone
DTWriteProt	moveq	#-44,d0		;Write Protected
		bra	DTIONone

; All of it was transferred (io_Actual of the last piece is not the sum)
DTIOAll		move.l	dsDiskIO(a2),a1
		move.l	d6,IO_ACTUAL(a1)
		moveq	#0,d0
		bra	DTIODone

; Verifizieren
DTPrimeVerify	moveq	#0,d0		;Alles OK
		move.l	dsDiskIO(a2),a1	;Transfer vortäuschen
		move.l	d3,IO_ACTUAL(a1)
		bra	DTIODone

; IO-Vorgang beenden, Emulator benachrichtigen
DTIOOutOfRange	moveq	#-50,d0		;Param Error
DTIONone	move.l	dsDiskIO(a2),a1	;Kein Transfer
		clr.l	IO_ACTUAL(a1)

DTIODone	move.w	d0,DiskError
		move.w	d0,DskErr

		move.l	dsDiskIO(a2),a1	;Zähler erhöhen
		move.l	IO_ACTUAL(a1),d0
		move.l	DiskParmBlock,a0
		move.l	DiskDCE,a1
		move.l	d0,ioActCount(a0)
		tst.l	d7		;(dCtlPosition means nothing to a wide request)
		bne	80$
		add.l	d0,dCtlPosition(a1)
80$

		move.l	DiskDCE,a2	;Für JIODone (kann nach Signal zerstört sein,
		move.w	DiskError,d2	; wenn der Emulator auf Beendigung wartet
					; und danach einen neuen Request postet)

		move.l	MyTask,a1
		move.l	DTReadySet,d0
		JSRLIB	Signal

		tst.b	DiskTaskAsync
		beq	DTSigLoop

		lea	DTJumpIODone,a5
		JSRLIB	Supervisor
		bra	DTSigLoop

DTJumpIODone	move.w	d2,d0		;DiskError
		move.l	a2,a1		;DiskDCE
		move.l	JIODone,a0
		jsr	(a0)
		and.w	#$f8ff,sr
		rte

; Diskette "auswerfen"
DTEject		move.l	DiskParmBlock,a0
		move.w	ioVRefNum(a0),d0 ;Drive Number
		bsr	GetDrvA2	;DriveStatus nach a2

		move.l	DiskDCE,a1
		clr.l	dCtlPosition(a1)

		move.l	dsDiskIO(a2),a1
		move.w	#CMD_UPDATE,IO_COMMAND(a1)
		JSRLIB	DoIO

		move.l	dsDiskIO(a2),a1
		clr.l	IO_LENGTH(a1)	;Motor aus
		move.w	#TD_MOTOR,IO_COMMAND(a1)
		JSRLIB	DoIO

		move.l	dsDiskIO(a2),a1
		move.l	#1,IO_LENGTH(a1) ;Auswerfen
		move.w	#TD_EJECT,IO_COMMAND(a1)
		JSRLIB	DoIO
		tst.l	d0
		beq	1$		;Gelungen?
		st	dsDiskEjected(a2) ;Nein, dann Flag setzen
1$		clr.b	dsDiskInPlace(a2)

		move.l	MyTask,a1	;Emulator benachrichtigen
		move.l	DTReadySet,d0
		JSRLIB	Signal
		bra	DTSigLoop

; Diskette formatieren
DTFormat	move.l	DiskParmBlock,a0
		move.l	DiskDCE,a1
		move.w	ioVRefNum(a0),d0 ;Drive Number
		bsr	GetDrvA2	;DriveStatus nach a2

		move.w	#-108,DiskError	;Vorgabe: Memory Full

		move.l	#TD_SECTOR*9,d3	;Vorgabe: DD, 9 Sektoren
		tst.b	dsHDDisk(a2)	;HD-Diskette?
		bpl	1$
		move.l	#TD_SECTOR*18,d3 ;Größe eines Tracks (HD)
1$
		tst.b	IsDraco		;DraCo: Format einstellen
		beq	5$
		move.l	_FDCBase,a6
		move.l	dsUnit(a2),d0
		move.l	#FDCDT_DD512,d1
		tst.b	dsHDDisk(a2)
		bpl	6$
		move.l	#FDCDT_HD512,d1
6$		jsr	_LVOSetUnitID(a6)
		move.l	_ExecBase,a6
5$
		tst.l	DiskFormatData	;Beschreiben?
		bne	3$

		move.l	d3,d0		;Nein, Puffer holen und löschen
		move.l	#MEMF_PUBLIC,d1
		JSRLIB	AllocVec
		tst.l	d0
		beq	DTFormatNoMem
		move.l	d0,a3		;a3: TrackBuffer

		move.l	d0,a0		;Puffer löschen
		move.l	d3,d0
		lsr.l	#2,d0
		subq.l	#1,d0
2$		move.l	#$f6f6f6f6,(a0)+
		dbra	d0,2$

		move.l	dsDiskIO(a2),a1
		move.l	a3,IO_DATA(a1)
		clr.l	IO_OFFSET(a1)
		move.l	d3,IO_LENGTH(a1)
		bra	4$

3$		move.l	dsDiskIO(a2),a1
		move.l	DiskFormatData,IO_DATA(a1)
		clr.l	IO_OFFSET(a1)
		move.l	d3,IO_LENGTH(a1)

4$		move.w	#-74,DiskError	;Vorgabe: Write Underrun

		move.w	#159,d2		;Anzahl Tracks
DTFormatLoop	move.l	dsDiskIO(a2),a1
		move.w	#TD_FORMAT,IO_COMMAND(a1)
		JSRLIB	DoIO
		tst.l	d0
		bne	DTFormatDone
		move.l	dsDiskIO(a2),a1
		add.l	d3,IO_OFFSET(a1) ;Offset erhöhen
		tst.l	DiskFormatData
		beq	1$
		add.l	d3,IO_DATA(a1)	;Zeiger in Puffer erhöhen
1$		dbra	d2,DTFormatLoop

		clr.w	DiskError	;Alles OK

DTFormatDone	tst.l	DiskFormatData	;Puffer freigeben
		bne	DTFormatNoMem
		move.l	a3,a1
		JSRLIB	FreeVec

DTFormatNoMem	move.l	MyTask,a1	;Emulator benachrichtigen
		move.l	DTReadySet,d0
		JSRLIB	Signal
		bra	DTSigLoop

; Diskette verifizieren
DTVerify	move.l	DiskParmBlock,a0
		move.l	DiskDCE,a1
		move.w	ioVRefNum(a0),d0 ;Drive Number
		bsr	GetDrvA2	;DriveStatus nach a2

		move.w	#-108,DiskError	;Vorgabe: Memory Full

		move.l	#TD_SECTOR*9,d3	;Vorgabe: DD, 9 Sektoren
		tst.b	dsHDDisk(a2)	;HD-Diskette?
		bpl	1$
		move.l	#TD_SECTOR*18,d3 ;Größe eines Tracks (HD)
1$
		move.l	d3,d0		;Nein, Puffer holen
		move.l	#MEMF_PUBLIC,d1
		JSRLIB	AllocVec
		tst.l	d0
		beq	DTVerifyNoMem
		move.l	d0,a3		;a3: TrackBuffer

		move.w	#-84,DiskError	;Vorgabe: Verify Error

		move.l	dsDiskIO(a2),a1
		move.l	a3,IO_DATA(a1)
		clr.l	IO_OFFSET(a1)
		move.l	d3,IO_LENGTH(a1)

		move.w	#159,d2		;Anzahl Tracks
DTVerifyLoop	move.l	dsDiskIO(a2),a1
		move.w	#CMD_READ,IO_COMMAND(a1)
		JSRLIB	DoIO
		tst.l	d0
		bne	DTVerifyDone
		move.l	dsDiskIO(a2),a1
		add.l	d3,IO_OFFSET(a1) ;Offset erhöhen
		dbra	d2,DTVerifyLoop

		clr.w	DiskError	;Alles OK

DTVerifyDone	move.l	a3,a1		;Puffer freigeben
		JSRLIB	FreeVec

DTVerifyNoMem	move.l	MyTask,a1	;Emulator benachrichtigen
		move.l	DTReadySet,d0
		JSRLIB	Signal
		bra	DTSigLoop

; Diskette wurde gewechselt: Eingelegt oder entnommen?
DTChanged	move.w	DiskChangeNum,d0
		bsr	GetDrvA2

		move.l	dsDiskIO(a2),a1
		move.w	#TD_CHANGESTATE,IO_COMMAND(a1)
		JSRLIB	DoIO
		move.l	dsDiskIO(a2),a1
		tst.l	IO_ACTUAL(a1)
		beq	DTDiskInserted

; Diskette entnommen, wurde Diskette "ausgeworfen"?
		tst.b	dsDiskEjected(a2)
		bne	DTDiskEjected

; Nein, Diskette wurde mutwillig entfernt, Event posten
		clr.b	dsDiskInPlace(a2) ;Diskette nicht mehr im Laufwerk

		lea	SuperRemoved,a5
		JSRLIB	Supervisor
		bra	DTSigLoop

SuperRemoved	moveq	#-1,d0
		move.w	DiskChangeNum,d0
		move.w	#7,a0		;diskEvent
		dc.w	$a02f		;PostEvent
		rte

; Ja, Auswurf-Flag löschen und Bildschirmecke wiederherstellen
DTDiskEjected	clr.b	dsDiskEjected(a2)
		jsr	EraseDiskIcon
		bra	DTSigLoop

; Diskette eingelegt, Typ und Schreibschutz abfragen und Event posten
DTDiskInserted	move.b	#1,dsDiskInPlace(a2)

		bsr	DTIsHD

		st.b	dsWriteProt(a2)
		move.l	dsDiskIO(a2),a1
		move.w	#TD_PROTSTATUS,IO_COMMAND(a1)
		JSRLIB	DoIO
		move.l	dsDiskIO(a2),a1
		tst.l	IO_ACTUAL(a1)
		bne	DTDoPost
		clr.b	dsWriteProt(a2)

DTDoPost	lea	SuperInserted,a5
		JSRLIB	Supervisor
		bra	DTSigLoop

SuperInserted	moveq	#0,d0
		move.w	DiskChangeNum,d0
		move.w	#7,a0		;diskEvent
		dc.w	$a02f		;PostEvent
		rte

; DiskTask beenden
DTQuit		move.l	_ExecBase(pc),a6

		move.b	DiskSignalSig,d0
		JSRLIB	FreeSignal
		move.b	DiskEjectSig,d0
		JSRLIB	FreeSignal
		move.b	DiskFormatSig,d0
		JSRLIB	FreeSignal
		move.b	DiskVerifySig,d0
		JSRLIB	FreeSignal
		move.b	DiskChangedSig,d0
		JSRLIB	FreeSignal
		move.b	DiskQuitSig,d0
		JSRLIB	FreeSignal

		move.l	_DOSBase,a6
		tst.b	Flop1Inhibited
		beq	2$
		move.w	Floppy1,d0
		add.b	#'0'-FTYPE_DF0,d0
		move.b	d0,FloppyDOSChar
		move.l	#FloppyDOSName,d1
		move.l	#DOSFALSE,d2
		JSRLIB	Inhibit
2$		tst.b	Flop2Inhibited
		beq	3$
		move.w	Floppy2,d0
		add.b	#'0'-FTYPE_DF0,d0
		move.b	d0,FloppyDOSChar
		move.l	#FloppyDOSName,d1
		move.l	#DOSFALSE,d2
		JSRLIB	Inhibit
3$		move.l	_ExecBase,a6

		lea	DriveStatus1,a2		;Floppy
		lea	DiskInterrupt1,a4
		bsr	DTCloseDevice
		lea	DriveStatus2,a2
		lea	DiskInterrupt2,a4
		bsr	DTCloseDevice

		lea	DriveStatus3,a2		;ADD
		lea	DiskInterrupt3,a4
		bsr	DTCloseDevice
		lea	DriveStatus4,a2
		lea	DiskInterrupt4,a4
		bsr	DTCloseDevice

		tst.b	ADDWhole1		;"The whole drive" stays that in the settings
		beq	31$
		clr.l	ADDSectors1
		clr.b	ADDWhole1
31$		tst.b	ADDWhole2
		beq	32$
		clr.l	ADDSectors2
		clr.b	ADDWhole2
32$
		move.l	DiskMsgPort,d0
		beq	1$
		move.l	d0,a0
		JSRLIB	DeleteMsgPort

1$		JSRLIB	Forbid		;Dem Emulator Bescheid sagen
		move.l	MyTask,a1
		move.l	SubtaskSet,d0
		JSRLIB	Signal
		moveq	#0,d0
		rts


**
** Interrupt-Routinen für Diskettenwechsel
**

IntDiskChange1	move.w	#1,DiskChangeNum
		bra	IntDiskChange

IntDiskChange2	move.w	#2,DiskChangeNum
		bra	IntDiskChange

IntDiskChange3	move.w	#3,DiskChangeNum
		bra	IntDiskChange

IntDiskChange4	move.w	#4,DiskChangeNum

; Signal abschicken
IntDiskChange	tst.w	MacRunning(pc)
		beq	1$

		move.l	a6,-(sp)
		move.l	_ExecBase(pc),a6
		move.l	DiskTask,a1
		move.l	DiskChangedSet,d0
		JSRLIB	Signal
		move.l	(sp)+,a6
1$		rts


**
** Device disk with "Number of sectors" 0: the whole drive from the first
** sector on. The device says how large it is (TD_GETGEOMETRY); only drives
** with 512-byte sectors. For a drive the Mac has to itself, without an
** Amiga partition table, nobody has to work the number out.
** a2: DriveStatus (after DTOpenDevice), a0: ^ADDSectors, d0: ADDStartSector
**
ADDWholeDrive	movem.l	d2/a3/a6,-(sp)
		move.l	a0,a3
		move.l	d0,d2
		tst.l	(a3)
		bne	9$
		move.l	dsDiskIO(a2),d0
		beq	9$
		move.l	d0,a1
		move.l	_ExecBase,a6
		move.w	#TD_GETGEOMETRY,IO_COMMAND(a1)
		move.l	#ADDGeometry,IO_DATA(a1)
		move.l	#dg_SIZEOF,IO_LENGTH(a1)
		JSRLIB	DoIO
		tst.b	d0
		bne	9$
		cmp.l	#512,ADDGeometry+dg_SectorSize
		bne	9$
		move.l	ADDGeometry+dg_TotalSectors,d0
		sub.l	d2,d0
		bls	9$
		move.l	d0,(a3)
		cmp.l	#ADDSectors1,a3		;(put back to 0 when the drives are closed)
		bne	8$
		st.b	ADDWhole1
		bra	9$
8$		st.b	ADDWhole2
9$		movem.l	(sp)+,d2/a3/a6
		rts

**
** A device disk that starts at the beginning of a drive with an Amiga
** partition table is left out (dsCmdRead 0): the Mac would take the whole
** drive for one unreadable disk and offer to erase it. And a device disk
** that reaches beyond the first 4 GB of its drive needs the 64-bit drive
** commands: DevProbe64 says whether the drive knows them. Disks within the
** first 4 GB keep the plain commands, as before.
** a2: DriveStatus (after DTOpenDevice), d0: first sector, d1: sectors
**
ADDProbe64	movem.l	d2-d3/a6,-(sp)
		move.l	d0,d2
		move.l	d1,d3
		tst.l	dsDiskIO(a2)
		beq	9$
		cmp.l	#16,d2
		bhs	1$
		move.l	dsDiskIO(a2),a1
		jsr	DevScanRDB
		tst.l	d0
		beq	1$
		clr.w	dsCmdRead(a2)
		bra	9$
1$		add.l	d3,d2
		bcs	2$
		cmp.l	#$800000,d2
		bls	9$
2$		move.l	dsDiskIO(a2),a1
		jsr	DevProbe64
		move.w	d0,dsCmdRead(a2)
		addq.w	#1,d0
		move.w	d0,dsCmdWrite(a2)
9$		movem.l	(sp)+,d2-d3/a6
		rts

**
** Routine zum Einrichten und Öffnen der IORequests
** a2: DrvSts
** a3: DeviceName
** a4: Interrupt (nur Floppy)
** d2: UnitNumber
** d3: Flag (word): Removable?
** d4: OpenFlags
**

; IORequests anfordern
DTOpenDevice	move.l	_ExecBase,a6
		move.w	#CMD_READ,dsCmdRead(a2)	;(a device disk beyond 4 GB: see ADDProbe64)
		move.w	#CMD_WRITE,dsCmdWrite(a2)
		clr.l	dsStartHi(a2)
		move.l	DiskMsgPort,a0
		moveq	#IOTD_SIZE,d0
		JSRLIB	CreateIORequest
		move.l	d0,dsDiskIO(a2)
		beq	DTODErrReq1		;Nicht gelungen, Fehler

		move.l	DiskMsgPort,a0
		moveq	#IOTD_SIZE,d0
		JSRLIB	CreateIORequest
		move.l	d0,dsChangeIO(a2)
		beq	DTODErrReq2

; Device öffnen
		tst.b	(a3)			;Leerer Name: Fehler
		beq	DTODErrOpen

		move.l	a3,a0			;DeviceName
		move.l	d2,d0			;UnitNumber
		move.l	dsDiskIO(a2),a1		;IORequest
		move.l	d4,d1			;Flags
	;mfm.device V40.6 zerstört d3 beim OpenDevice()!
		move.l	d3,-(sp)		;Workaround für mfm.device-V40.6-Bug
		JSRLIB	OpenDevice		;Device öffnen
		move.l	(sp)+,d3
		tst.l	d0			;Fehler aufgetreten?
		bne	DTODErrOpen

		cmp.l	#TrackName,a3		;mfm.device <V41?
		bne	1$
		move.l	dsDiskIO(a2),a0
		move.l	IO_DEVICE(a0),a0
		cmp.w	#41,LIB_VERSION(a0)
		bhs	1$

		st	dsMFMCrap(a2)		;Ja, Schrott-Modus aktivieren
		move.l	dsDiskIO(a2),a0		;Und zweiten Request kopieren
		move.l	dsChangeIO(a2),a1
		moveq	#IOTD_SIZE,d0
		JSRLIB	CopyMem
		bra	2$
1$
		move.l	a3,a0			;Sonst zweiten Request öffnen
		move.l	d2,d0			;UnitNumber
		move.l	dsChangeIO(a2),a1	;IORequest
		move.l	d4,d1			;Flags
		move.l	d3,-(sp)
		JSRLIB	OpenDevice
		move.l	(sp)+,d3
		tst.l	d0
		bne	DTODErrOpen2

; Wechselmedium?
2$		move.l	dsChangeIO(a2),a0	;Remember whom the request belongs to
		move.l	IO_DEVICE(a0),dsChgDevice(a2)
		move.l	IO_UNIT(a0),dsChgUnit(a2)
		move.b	#8,dsDiskInPlace(a2)	;Vorgabe: FixedDisk
		tst.w	d3
		beq	DTODDoProt

; Ja, DiskChange-Interrupt installieren
		move.l	dsChangeIO(a2),a1
		move.l	#IS_SIZE,IO_LENGTH(a1)
		move.l	a4,IO_DATA(a1)		;Interrupt
		move.w	#TD_ADDCHANGEINT,IO_COMMAND(a1)
		JSRLIB	SendIO

; Datenträger eingelegt?
		move.l	dsDiskIO(a2),a1
		move.w	#TD_CHANGESTATE,IO_COMMAND(a1)
		JSRLIB	DoIO
		move.l	dsDiskIO(a2),a1
		tst.l	IO_ACTUAL(a1)		;Datenträger eingelegt?
		bne	DTODNoDisk
		move.b	#1,dsDiskInPlace(a2)	;Ja

; Ja, Schreibschutz abfragen
DTODDoProt	st.b	dsWriteProt(a2)		;Vorgabe
		move.l	dsDiskIO(a2),a1
		move.w	#TD_PROTSTATUS,IO_COMMAND(a1)
		JSRLIB	DoIO
		move.l	dsDiskIO(a2),a1
		tst.l	IO_ACTUAL(a1)
		bne	1$
		clr.b	dsWriteProt(a2)
1$		rts

; Kein Datenträger eingelegt
DTODNoDisk	clr.b	dsDiskInPlace(a2)
		rts

; Fehlerbehandlung
DTODErrOpen2	move.l	dsDiskIO(a2),a1
		JSRLIB	CloseDevice

DTODErrOpen	move.l	dsChangeIO(a2),a0
		JSRLIB	DeleteIORequest
		clr.l	dsChangeIO(a2)

DTODErrReq2	move.l	dsDiskIO(a2),a0
		JSRLIB	DeleteIORequest
		clr.l	dsDiskIO(a2)

DTODErrReq1	clr.b	dsDiskInPlace(a2)
		rts


**
** Routine zum Schließen und Entfernen der IORequests
** a2: DrvSts
** a4: Interrupt
**

DTCloseDevice	move.l	_ExecBase,a6
		tst.l	dsChangeIO(a2)		;ChangeInt vorhanden?
		beq	DTCDNoReqInt
		cmp.b	#8,dsDiskInPlace(a2)	;Ja, FixedDisk?
		beq	DTCDFixed

		move.l	dsChangeIO(a2),a1	;Nein, Interrupt entfernen
		move.l	#IS_SIZE,IO_LENGTH(a1)
		move.l	a4,IO_DATA(a1)		;Interrupt
		move.w	#TD_REMCHANGEINT,IO_COMMAND(a1)
		JSRLIB	DoIO

; mfm.device (also 45.4) hands a TD_ADDCHANGEINT request on to trackdisk.device
; and leaves trackdisk's device and unit in it. Closing the request like that
; closes trackdisk.device, not mfm.device: after every run mfm.device stays open
; once more and trackdisk.device has one opener too few, until its unit goes
; away under the file system and the next floppy command never comes back.
; So: put back what OpenDevice() had set.
DTCDFixed	move.l	dsChangeIO(a2),a1
		move.l	dsChgDevice(a2),IO_DEVICE(a1)
		move.l	dsChgUnit(a2),IO_UNIT(a1)
		tst.b	dsMFMCrap(a2)		;MFM-Schrott?
		bne	1$
		move.l	dsChangeIO(a2),a1	;Nein, schließen
		JSRLIB	CloseDevice
1$
		move.l	dsChangeIO(a2),a0
		JSRLIB	DeleteIORequest
		clr.l	dsChangeIO(a2)

DTCDNoReqInt	move.l	dsDiskIO(a2),d0
		beq	DTCDNoReqPtr
		move.l	d0,a1
		move.w	#CMD_UPDATE,IO_COMMAND(a1)
		JSRLIB	DoIO

		move.l	dsDiskIO(a2),a1
		JSRLIB	CloseDevice

		move.l	dsDiskIO(a2),a0
		JSRLIB	DeleteIORequest
		clr.l	dsDiskIO(a2)
DTCDNoReqPtr	rts


**
** Routine zum Ermitteln DD/HD
** a2: Zeiger auf DriveStatus
**

DTIsHD		tst.b	dsOnlyHD(a2)
		bne	2$

		clr.b	dsHDDisk(a2)
		move.l	dsDiskIO(a2),a1
		move.w	#TD_GETDRIVETYPE,IO_COMMAND(a1)
		JSRLIB	DoIO
		tst.l	d0
		bne	1$
		move.l	dsDiskIO(a2),a1
		cmp.l	#DRIVE3_5_150RPM,IO_ACTUAL(a1)
		seq	dsHDDisk(a2)
1$		rts

2$		st.b	dsHDDisk(a2)
		rts


**
** Aus einem Partitionsnamen die Daten für eine DeviceDisk ermitteln
** a2: Zeiger auf Name (mit ':')
** a5: Zeiger auf PartPrefsTab
**

AnalyzePart	move.l	a2,a0			;Nach ':' suchen und löschen
		moveq	#79,d0
20$		cmp.b	#':',(a0)+
		bne	21$
		clr.b	-1(a0)
		bra	22$
21$		dbra	d0,20$
22$
		move.l	_DOSBase,a6		;DeviceList locken
		moveq	#LDF_DEVICES|LDF_READ,d1
		JSRLIB	LockDosList
		move.l	d0,d6			;d6: dlist	

		move.l	d6,d1			;Entry suchen
		move.l	a2,d2			;Name
		moveq	#LDF_DEVICES,d3
		JSRLIB	FindDosEntry
		tst.l	d0
		beq	APError

		move.l	d0,a0			;DeviceNode gefunden
		move.l	dol_Startup(a0),d0	;FileSysStartupMsg holen
		beq	APError
		add.l	d0,d0
		add.l	d0,d0
		move.l	d0,a0
		move.l	fssm_Environ(a0),d0	;DosEnvec holen
		beq	APError
		add.l	d0,d0
		add.l	d0,d0
		move.l	d0,a2
		move.l	fssm_Unit(a0),([4,a5])	;ADDUnit setzen

		move.l	fssm_Device(a0),d0	;ADDName setzen
		add.l	d0,d0
		add.l	d0,d0
		addq.l	#1,d0
		move.l	d0,a0
		move.l	(a5),a1			;Zeiger auf ADDName holen
		moveq	#79,d0
3$		move.b	(a0)+,(a1)+
		dbeq	d0,3$

		move.l	de_BlocksPerTrack(a2),d0
		mulu.l	de_Surfaces(a2),d0
		mulu.l	de_LowCyl(a2),d0
		move.l	de_SizeBlock(a2),d1
		lsr.l	#7,d1
		mulu.l	d1,d0
		move.l	d0,([8,a5])		;ADDStartSector setzen

		move.l	de_HighCyl(a2),d0
		sub.l	de_LowCyl(a2),d0
		addq.l	#1,d0
		mulu.l	de_BlocksPerTrack(a2),d0
		mulu.l	de_Surfaces(a2),d0
		move.l	de_SizeBlock(a2),d1
		lsr.l	#7,d1
		mulu.l	d1,d0
		move.l	d0,([12,a5])		;ADDSectors setzen

		move.l	de_MaxTransfer(a2),([16,a5]) ;ADDMaxTransfer setzen

APError		move.l	_DOSBase,a6
		moveq	#LDF_DEVICES|LDF_READ,d1
		JSRLIB	UnLockDosList
		rts

; Zeiger auf die Prefs
PartPrefsTab1	dc.l	ADDName1
		dc.l	ADDUnit1
		dc.l	ADDStartSector1
		dc.l	ADDSectors1
		dc.l	ADDMaxTransfer1

PartPrefsTab2	dc.l	ADDName2
		dc.l	ADDUnit2
		dc.l	ADDStartSector2
		dc.l	ADDSectors2
		dc.l	ADDMaxTransfer2


**
** Konstanten
**

; Strings
TrackName	dc.b	"mfm.device",0
DracoName	dc.b	"dracodisk.device",0
MultiName	dc.b	"multidisk.device",0
DiskTaskName	dc.b	"ShapeShifter DiskTask",0
DiskIntName	dc.b	"ShapeShifter DiskChange Int",0
		CNOP	0,4

; Unbenutzte Nibble-Tabelle
NiblTbl		dc.l	$96979A9B,$9D9E9FA6,$A7ABACAD,$AEAFB2B3
		dc.l	$B4B5B6B7,$B9BABBBC,$BDBEBFCB,$CDCECFD3
		dc.l	$D6D7D9DA,$DBDCDDDE,$DFE5E6E7,$E9EAEBEC
		dc.l	$EDEEEFF2,$F3F4F5F6,$F7F9FAFB,$FCFDFEFF

; Disketten-Icons
DiskICON	dc.l	$7FFFFFF8,$81000104,$81007102,$81008901
		dc.l	$81008901,$81008901,$81008901,$81008901
		dc.l	$81007101,$81000101,$80FFFE01,$80000001
		dc.l	$80000001,$80000001,$80000001,$80000001
		dc.l	$80000001,$80000001,$87FFFFE1,$88000011
		dc.l	$88000011,$88000011,$88000011,$88000011
		dc.l	$88000011,$88000011,$88000011,$88000011
		dc.l	$88000011,$88000011,$88000011,$7FFFFFFE

		dc.l	$7FFFFFF8,$FFFFFFFC,$FFFFFFFE,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$7FFFFFFE

		dc.w	0

ADDDiskICON	dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$7FFFFFFE
		dc.l	$80000001,$80000001,$80000001,$80000001
		dc.l	$80000001,$8C000001,$80000001,$80000001
		dc.l	$7FFFFFFE,$00000000,$00000000,$00000000

		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$7FFFFFFE
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$7FFFFFFE,$00000000,$00000000,$00000000

		dc.w	0

; Laufwerks-Icons
IntDriveICON	dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000080,$00000080,$00000080
		dc.l	$00000080,$000003E0,$000001C0,$00000080
		dc.l	$00000000,$FFFFFFFF,$80000001,$FFFFFFFF
		dc.l	$80000001,$80010001,$80000001,$FFFFFFFF
		dc.l	$80000001,$80000FF9,$80000001,$80000001
		dc.l	$80000001,$FFFFFFFF,$80000001,$FFFFFFFF
		dc.l	$00000000,$00000000,$00000000,$00000000

		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000080,$00000080,$00000080
		dc.l	$00000080,$000003E0,$000001C0,$00000080
		dc.l	$00000000,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$00000000,$00000000,$00000000,$00000000

		dc.w	0

ExtDriveICON	dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000010
		dc.l	$00000010,$FFFFFC10,$80000410,$FFFFFC7C
		dc.l	$80000438,$80000410,$FFFFFC00,$8001F5FF
		dc.l	$80000501,$FFFFFD7D,$80000501,$FFFFFDFF
		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000000

		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000010
		dc.l	$00000010,$FFFFFC10,$FFFFFC10,$FFFFFC7C
		dc.l	$FFFFFC38,$FFFFFC10,$FFFFFC00,$FFFFFDFF
		dc.l	$FFFFFDFF,$FFFFFDFF,$FFFFFDFF,$FFFFFDFF
		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000000

		dc.w	0

ADD1DriveICON	dc.l	$7FFFFFF0,$81000108,$81007104,$81008902
		dc.l	$81008901,$81008901,$81008901,$81008901
		dc.l	$81007101,$81000101,$80FFFE01,$80000001
		dc.l	$80000001,$80000001,$87FFFFE1,$88000011
		dc.l	$88000411,$88010C11,$88020411,$88440411
		dc.l	$88280411,$88100E11,$88000011,$88000011
		dc.l	$887FFE11,$88800111,$88800111,$88A00111
		dc.l	$88800111,$887FFE11,$88000011,$7FFFFFFE

		dc.l	$7FFFFFF0,$FFFFFFF8,$FFFFFFFC,$FFFFFFFE
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$7FFFFFFE

		dc.b	18,"Amiga DeviceDisk 1"
		EVEN

ADD2DriveICON	dc.l	$7FFFFFF0,$81000108,$81007104,$81008902
		dc.l	$81008901,$81008901,$81008901,$81008901
		dc.l	$81007101,$81000101,$80FFFE01,$80000001
		dc.l	$80000001,$80000001,$87FFFFE1,$88000011
		dc.l	$88000C11,$88011211,$88020211,$88440411
		dc.l	$88280811,$88101E11,$88000011,$88000011
		dc.l	$887FFE11,$88800111,$88800111,$88A00111
		dc.l	$88800111,$887FFE11,$88000011,$7FFFFFFE

		dc.l	$7FFFFFF0,$FFFFFFF8,$FFFFFFFC,$FFFFFFFE
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$7FFFFFFE

		dc.b	18,"Amiga DeviceDisk 2"
		EVEN

		CNOP	0,4
ProcTags	dc.l	NP_Entry,DiskTaskMain
		dc.l	NP_Name,DiskTaskName
		dc.l	NP_Priority,1
		dc.l	0,0


**
** Initialisierte Daten
**

		SECTION	"DATA",DATA

; Interrupts für Diskettenwechsel
DiskInterrupt1	dc.l	0,0
		dc.b	NT_INTERRUPT,0
		dc.l	DiskIntName
		dc.l	0
		dc.l	IntDiskChange1
		dc.w	0

DiskInterrupt2	dc.l	0,0
		dc.b	NT_INTERRUPT,0
		dc.l	DiskIntName
		dc.l	0
		dc.l	IntDiskChange2
		dc.w	0

DiskInterrupt3	dc.l	0,0
		dc.b	NT_INTERRUPT,0
		dc.l	DiskIntName
		dc.l	0
		dc.l	IntDiskChange3
		dc.w	0

DiskInterrupt4	dc.l	0,0
		dc.b	NT_INTERRUPT,0
		dc.l	DiskIntName
		dc.l	0
		dc.l	IntDiskChange4
		dc.w	0

; DOS-Name eines Diskettenlaufwerks
FloppyDOSName	dc.b	"DF"
FloppyDOSChar	dc.b	0
		dc.b	":",0


**
** Nicht initialisierte Daten
**

		SECTION	"BSS",BSS
ADDGeometry	ds.b	dg_SIZEOF+2	;TD_GETGEOMETRY (ADDWholeDrive)
ADDWhole1	ds.b	1		;ADDSectors1/2 were filled in by ADDWholeDrive
ADDWhole2	ds.b	1
		EVEN
DriveStatus1	ds.b	MyDrvSts_SIZEOF	;Diskettenlaufwerk 1 (Sony)
DriveStatus2	ds.b	MyDrvSts_SIZEOF	;Diskettenlaufwerk 2 (Sony)
DriveStatus3	ds.b	MyDrvSts_SIZEOF	;DeviceDisk 1 (HD20)
DriveStatus4	ds.b	MyDrvSts_SIZEOF	;DeviceDisk 2 (HD20)

DiskTaskProc	ds.l	1	;ProcID des DiskTask
DiskTask	ds.l	1	;Zeiger auf Task des Prozesses
DiskMsgPort	ds.l	1	;ReplyPort für DiskTask

DiskParmBlock	ds.l	1	;DiskIO-ParamBlock für DiskTask
DiskDCE		ds.l	1	;DriverControlEntry für DiskTask
DiskFormatData	ds.l	1	;Zeiger auf Daten fürs Formatieren (NIL=Nur Formatieren)
DiskChangeNum	ds.w	1	;Laufwerksnummer für Diskettenwechsel
DiskError	ds.w	1	;Fehlercode des DiskTask

TheSignals	ds.l	1	;Empfangene Signale

DiskSignalSet	ds.l	1	;Signal: DiskTask soll Daten lesen/schreiben
DiskEjectSet	ds.l	1	;Signal: DiskTask soll Diskette auswerfen
DiskFormatSet	ds.l	1	;Signal: DiskTask soll Diskette formatieren
DiskVerifySet	ds.l	1	;Signal: DiskTask soll Diskette verifizieren
DiskChangedSet	ds.l	1	;Signal: Diskette wurde gewechselt
DiskQuitSet	ds.l	1	;Signal: DiskTask beenden
DTReadySet	ds.l	1	;Signal: DiskTask hat Daten gelesen/geschrieben
DiskSignalSig	ds.b	1
DiskEjectSig	ds.b	1
DiskFormatSig	ds.b	1
DiskVerifySig	ds.b	1
DiskChangedSig	ds.b	1
DiskQuitSig	ds.b	1
DTReadySig	ds.b	1

DiskTaskAsync	ds.b	1	;#0: Der DiskTask bearbeitet gerade etwas asynchron
Flop1Inhibited	ds.b	1	;#0: Floppy 1 wurde gesperrt
Flop2Inhibited	ds.b	1	;#0: Floppy 2 wurde gesperrt

		END
