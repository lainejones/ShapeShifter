**
** Macintosh IIci-Emulator - ROM-/Resource-Patches
** ===============================================
**
** © Copyright 1993-2001 Christian Bauer
**

DEBUG_DETAIL	SET 0

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/execbase.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"devices/timer.i"
		INCLUDE	"macros.i"
		INCLUDE	"macinclude.i"
		INCLUDE	"shapesupport.i"

		XDEF	PatchROM
		XDEF	InitRTC
		XDEF	PatchAfterFinder
		XDEF	RmvTime
		XDEF	PrimeTime
		XDEF	InitTimeMgr
		XDEF	ExitTimeMgr
		XDEF	TimeMgrServer
		XDEF	Microseconds
		XDEF	HWPriv
		XDEF	OldPutScrap
		XDEF	MMUTbl1
		XDEF	MMUTbl2

		XREF	ROMBase		;MacEmul.asm
		XREF	ROMSize
		XREF	ROMSubVersion
		XREF	MemBase
		XREF	MemTop
		XREF	VIABase
		XREF	SCCBase
		XREF	ChipFakeBase
		XREF	CiaControlReg
		XREF	CiaTimerReg
		XREF	CPUType
		XREF	Has68060
		XREF	HasMMU
		XREF	HasFPU
		XREF	IsDraco
		XREF	FixROMFor68040
		XREF	CoreDump
		XREF	PowerOff
		XREF	KeyXLate
		XREF	HasRealVIA
		XREF	HasRealSCC
		XREF	SCCFakeRd
		XREF	SCCFakeWr
		XREF	TimerIntPort
		XREF	TimerIO
		XREF	TimeDBRA
		XREF	TimeSCCDBRA
		XREF	TimeSCSIDBRA
		XREF	TimeRAMDBRA
		XREF	XPRam
		XREF	TheShapeSema
		XREF	EmergShutDown
		XREF	ProgSwitch
		XREF	NoQDAccel

		XREF	SonyHeader	;MacEmulADD.asm
		XREF	SonyEnd
		XREF	SonyRefNum
		XREF	ADDRefNum

		XREF	AFDRefNum	;MacEmulAFD.asm

		XREF	PutScrap	;MacEmulClip.asm

		XREF	CleanupNetwork	;MacEmulNet.asm

		XREF	SCSIDispatch	;MacEmulSCSI.asm
		XREF	SCSILoadPatch

		XREF	SERDEntry	;MacEmulSERD.asm
		XREF	SERDEnd

		XREF	SROMStart	;MacEmulSlot.asm
		XREF	SROMLength

		XREF	SquareWaveProc	;MacEmulSound.asm
		XREF	SndDrvrPatch
		XREF	Snth5Patch1
		XREF	Snth5Patch1a
		XREF	Snth5Patch2
		XREF	Snth5Patch3
		XREF	Snth5Patch4
		XREF	Snth5Patch5
		XREF	SiftPatch1
		XREF	SiftPatch2
		XREF	SiftPatch3
		XREF	SiftPatch4
		XREF	ASCRegs
		XREF	GotChannel01

		XREF	ScrnBase1	;MacEmulVideo.asm

		SECTION	"CODE",CODE


**
** Definitionen
**

; Gemeinsame ROM-Eigenschaften
ROMEntry	= $118		;Einsprung
ROMCacheStuff	= $186		;Caches in Ruhe lassen
ROMCacheStuff2L	= $4400		;Caches bei neueren ROMs
ROMCacheStuff2U	= $4500		;Caches bei neueren ROMs
ROMSRPatch	= $1a6		;SR-Patch
ROMPatch1	= $1ca		;Erster Patch (Traps)
ROMPatch1Cnt	= $9a96		;Fortsetzung
ROMPatch2a	= $23a		;Zweiter Patch (Interrupts)
ROMPatch2b	= $23c
ROMPatch3a	= $2ca		;Dritter Patch (Misc)
ROMPatch3b	= $2cc
ROMPatch4	= $113e		;Vierter Patch (InstallAFD)
ROMVBRPatch1	= $25f4		;Erster VBR-Patch
ROMSysZone	= $50a		;SysZone-Daten
ROMSpeedTest	= $800		;Geschwindigkeits-Test
ROMSCSIPatch	= $9a0		;SCSI-Patch
ROMIWMPatch	= $9c0		;IWM-Patch
ROMSCCPatch	= $a30		;SCC-Patch
ROMSysError1	= $2a38		;Erster SysError-Patch
ROMSysError2	= $2a5c		;Zweiter SysError-Patch
ROMMachDefL	= $3400		;MachDef-Grenzen
ROMMachDefU	= $3c00
ROMHWAccess1	= $4234		;Absoluter Hardwarezugriff
ROMSCSILoad	= $71f0		;SCSI-Load-Patch
ROMVBLPatch	= $a2a8		;VBL-Patch
ROMADBPatchL	= $a800		;ADB-Patch-Grenzen
ROMADBPatchU	= $ac00
ROMOSEvent	= $b418		;OSEventAvail-Patch
ROMWaitPatch1	= $bb8c		;Erster WaitIO-Patch
ROMWaitPatch2	= $efde		;Zweiter WaitIO-Patch
ROMAdr4Patch	= $ccb4		;SysBase nicht überschreiben
ROMBERRPatch1	= $db6a		;Erster Busfehler-Patch
ROMBERRPatch2	= $dbf8		;Zweiter Busfehler-Patch
ROMResPatch	= $1b8c0	;ResourceMgr-Patch
ROMResLoad	= $1b8f4	;ResLoad-Patch
ROMCursorPatch	= $2e29a	;InitCursor-Patch
ROMPTESTPatchL	= $87000	;PTEST-Patch
ROMPTESTPatchU	= $87800
ROMEtherPatch	= $a68e2	;Ethernet-Patch
ROMVBRPatch2	= $8d200	;Zweiter VBR-Patch (68040 FPSP)
ROMMemDispPatch = $4f14a

ROMBasePatch1	= $6498		;Offsets zu den ROMBase-Patches
ROMBasePatch2	= $b990
ROMBasePatch4	= $269f8

; Time-Manager-Task
 STRUCTURE TMTask,0
	STRUCT	tm_Node,MLN_SIZE	;Zum Verketten
	STRUCT	tm_TimerIO,IOTV_SIZE	;TimerIO
	STRUCT	tm_ExpTime,TV_SIZE	;Vorausberechneter Zeitpunkt des Expires
	APTR	tm_MacTask		;Zeiger auf Mac-TMTask
 LABEL	SIZEOF_TMTask


**
** ROM patchen
** Rückgabe: d0=0 OK
**           d0#0 ROM nicht verwendbar
**

PatchROM	move.l	ROMBase,a3
		move.l	_ExecBase,a6

; ROM-Grenzen setzen
		move.l	a3,d0
		move.l	d0,ROMLimits
		add.l	ROMSize,d0
		subq.l	#1,d0
		move.l	d0,ROMLimits+4

; MemInfo initialisieren
		move.l	#-1,MemInfo+8

; !! Deep Magic: ROM-Sub-Version des 1MB-ROMs ändern, wenn kein 68040
; vorhanden (wegen lodr/lpch). Gibt sonst "Nicht installierter Trap",
; vermutlich wegen VMem-Kram
		cmp.b	#$15,ROMSubVersion
		bne	3$
		cmp.w	#4,CPUType
		bhs	3$
		move.b	#$13,18(a3)
3$

; Reset-Einsprünge auf eigene Routine richten
		move.w	#ROMEntry-12-6,12(a3)
		move.w	#ROMEntry-16-6,16(a3)
		move.w	#ROMEntry-$2c-6,$2c(a3)

		lea	ROMEntry-6(a3),a0
		move.w	#$4ef9,(a0)+		;jmp	DoReset
		move.l	#DoReset,(a0)

; Die Reset-Routine soll die Finger von den Caches lassen
		lea	ROMCacheStuff(a3),a0
		move.l	#$4e714e71,(a0)+	;nop
		move.l	#$4e714e71,(a0)+
		move.w	#$4e71,(a0)

; Hier versuchen ROMs ab Sub-Version $27, die Caches abzuschalten,
; wenn das PRAM-Byte $8a negativ ist
		lea	ROMCacheStuff2L(a3),a0
		move.w	#(ROMCacheStuff2U-ROMCacheStuff2L)/2-1,d1
32$		cmp.l	#$4e92301f,(a0)
		bne	33$
		move.w	#$4e71,(a0)
		bra	34$
33$
		addq.l	#2,a0
		dbra	d1,32$
34$

; Interrupts in Reset-Routine nicht abschalten
		lea	ROMSRPatch(a3),a0
		move.l	#$4e714e71,(a0)		;nop nop

; SCSI, IWM und SCC nicht initialisieren, wenn nicht vorhanden
		lea	ROMSCSIPatch(a3),a0
		move.w	#$4e75,(a0)		;rts
		lea	ROMIWMPatch(a3),a0
		move.w	#$4e75,(a0)		;rts

		tst.b	HasRealSCC
		bne	81$
		lea	ROMSCCPatch(a3),a0
		move.w	#$4e75,(a0)		;rts
81$

; Machine Record suchen
		lea	ROMMachDefL(a3),a0
		move.w	#(ROMMachDefU-ROMMachDefL)/2-1,d1
21$		cmp.l	#$dc000505,(a0)
		bne	22$
		cmp.l	#$3fff0100,4(a0)
		bne	22$
		lea	-$10(a0),a2		;a2: Zeiger auf MachDef
		move.l	a2,TheMachDef
		bra	23$
22$
		addq.l	#2,a0
		dbra	d1,21$
		bra	ROMNotUsable
23$

; Machine Record patchen (a2: Zeiger auf MachDef)
		cmp.l	#$100000,ROMSize	;Nur 1MB-ROM
		bne	84$
		tst.w	MacOS8Mode		;Nur im MacOS-8-Modus
		beq	84$
		move.b	#14,$12(a2)		;ModelID=Quadra900
84$
		tst.b	HasFPU			;Nur, wenn FPU nicht vorhanden
		bne	8$
		cmp.b	#$11,ROMSubVersion	;Beim $11-ROM schon gar nicht
		bls	8$
		move.b	#$04,$16(a2)		;FPU optional
8$
		move.l	a2,a0
		add.l	(a0),a0			;ChipDef
		move.l	a0,a1
		move.l	ROMBase,(a0)+
		move.l	ChipFakeBase,d0
		moveq	#30,d7
7$		move.l	d0,(a0)+
		dbra	d7,7$

		move.l	#ASCRegs,$30(a1)	;ASC
		tst.b	HasRealVIA
		beq	71$
		move.l	VIABase,8(a1)		;VIA 1
71$		tst.b	HasRealSCC
		beq	73$
		move.l	SCCBase,d0
		move.l	d0,$c(a1)		;SCC Read
		move.l	d0,$10(a1)		;SCC Write
		bra	72$
; No SCC: reads come from an area of its own that always says "line idle,
; transmitter empty, nothing received" (see SCCFakeRd), writes go nowhere.
; Before, the SCC shared the fake area with the VIAs and LocalTalk read
; whatever was there, and waited for an interrupt for ever.
73$		move.l	#SCCFakeRd,$c(a1)	;SCC Read
		move.l	#SCCFakeWr,$10(a1)	;SCC Write
72$
		move.l	a2,a0
		add.l	8(a0),a0		;VideoDef (zur Sicherheit)
		move.l	ScrnBase1,d0
		move.l	d0,(a0)+
		move.l	d0,(a0)+
		move.l	d0,(a0)+
		move.l	#$0b560000,(a0)+
		move.l	d0,(a0)+
		move.l	d0,(a0)+
		move.l	d0,(a0)+
		move.l	#$0b560000,(a0)

		move.l	a2,a0
		add.l	12(a0),a0		;SlotDef
		move.l	#$03080808,(a0)+
		move.l	#$08080808,(a0)+
		move.l	#$08080808,(a0)+
		move.l	#$08080800,(a0)+

; Beginn der SysZone
		lea	ROMSysZone(a3),a0
		move.l	MemBase,d0
		move.l	d0,(a0)+
		add.l	#$1800,d0
		move.l	d0,(a0)

; Traps patchen
		lea	ROMPatch1(a3),a0
		move.w	#$4eb9,(a0)+		;jsr	PatchTraps
		move.l	#PatchTraps,(a0)+
		move.l	#$4e714e71,(a0)		;nop

; Interrupts etc. patchen
		lea	ROMPatch2a(a3),a0
		cmp.l	#$46fc2000,(a0)
		beq	1$
		lea	ROMPatch2b(a3),a0
		cmp.l	#$46fc2000,(a0)
		bne	ROMNotUsable
1$		move.w	#$4eb9,(a0)+		;jsr	PatchIRQ
		move.l	#PatchIRQ,(a0)+
		move.w	#$4e71,(a0)		;nop

; Andere Sachen patchen
		lea	ROMPatch3a(a3),a0
		cmp.l	#$207802a6,(a0)
		beq	2$
		lea	ROMPatch3b(a3),a0
		cmp.l	#$207802a6,(a0)
		bne	ROMNotUsable
2$		move.w	#$4eb9,(a0)+		;jsr	PatchStuff
		move.l	#PatchStuff,(a0)

; SysError patchen
		lea	ROMSysError1(a3),a0
		move.w	#$4eb9,(a0)+		;jsr	SysError1
		move.l	#SysError1,(a0)

; OSEventAvail patchen
		lea	ROMOSEvent(a3),a0
		move.w	#$4eb9,(a0)+		;jsr	OSEventAvail
		move.l	#OSEventAvail,(a0)

; WaitIO patchen
		lea	ROMWaitPatch1(a3),a0
		move.w	#$4ef9,(a0)+		;jmp	MacWaitIO
		move.l	#MacWaitIO,(a0)

		lea	ROMWaitPatch2(a3),a0
		move.w	#$4eb9,(a0)+		;jsr	MacWaitIO
		move.l	#MacWaitIO,(a0)

; Treiber-Installation
		lea	ROMPatch4(a3),a0
		move.w	#$4eb9,(a0)+		;jsr	InstallDrvrs
		move.l	#InstallDrvrs,(a0)

; VBR nicht auf 0 setzen
		lea	ROMVBRPatch1(a3),a0
		move.l	#$4e714e71,(a0)		;nop nop

; Floppy-Treiber ins ROM kopieren
		move.l	#'DRVR',d0
		moveq	#4,d1
		bsr	SearchRsrc
		move.l	a0,a1
		lea	SonyHeader,a0
		move.l	#SonyEnd,d0
		sub.l	#SonyHeader,d0
		JSRLIB	CopyMem

; Seriellen Treiber ins ROM kopieren
		tst.w	UseSCCSerial		;Nicht, wenn SCC benutzt werden soll
		bne	4$

		move.l	#'SERD',d0
		moveq	#0,d1
		bsr	SearchRsrc
		move.l	a0,a1
		lea	SERDEntry,a0
		move.l	#SERDEnd,d0
		sub.l	#SERDEntry,d0
		JSRLIB	CopyMem
4$

; Sound-Treiber patchen
		move.l	#'DRVR',d0
		moveq	#3,d1
		bsr	SearchRsrc

		move.l	-8(a0),d1		;Länge holen
		lsr.l	#1,d1
6$		cmp.l	#$1491d681,(a0)
		bne	5$
		cmp.w	#$4843,4(a0)
		bne	5$
		move.w	#$4eb9,(a0)		;jsr	SndDrvrPatch
		move.l	#SndDrvrPatch,2(a0)
5$
		addq.l	#2,a0
		dbra	d1,6$

; Slot sResources ins ROM kopieren
		move.l	a3,a1
		add.l	ROMSize,a1
		sub.l	#SROMLength,a1
		lea	SROMStart,a0
		move.l	#SROMLength,d0
		JSRLIB	CopyMem

; Slot-CRC berechnen
		move.l	a3,a1
		add.l	ROMSize,a1
		sub.l	#SROMLength,a1

		move.l	#SROMLength,d2
		subq.l	#1,d2
		moveq	#0,d1
		moveq	#0,d3
31$		rol.l	#1,d1
		move.b	(a1)+,d3
		add.l	d3,d1
		dbra	d2,31$

		move.l	a3,a1
		add.l	ROMSize,a1
		move.l	d1,-12(a1)

; ADB-Init patchen (sonst Endlosschleife (wartet auf Interrupt))
		lea	ROMADBPatchL(a3),a0
		move.w	#(ROMADBPatchU-ROMADBPatchL)/2-1,d1
11$		cmp.l	#$082b0005,(a0)		;btst	#5,$15d(a3)
		bne	12$
		cmp.l	#$015d66f8,4(a0)	;bne
		bne	12$
		move.l	#$08ab0005,(a0)		;bclr	#5,$15d(a3)
		move.l	#$015d4e71,4(a0)	;nop
		bra	13$
12$
		addq.w	#2,a0
		dbra	d1,11$
		bra	ROMNotUsable
13$

; VBL-Interrupt patchen (sonst wird jeder VBL zweimal aufgerufen)
		move.l	#$4e714e71,ROMVBLPatch(a3)	;nop nop

; Tests von Zeigern gegen ROMBase patchen
		lea	ROMBasePatch1(a3),a0
		move.l	#$4e714e71,(a0)+	;nop nop
		move.l	#$4e714e71,(a0)+	;nop nop
		move.w	#$4e71,(a0)		;nop

		lea	ROMBasePatch2(a3),a0
		move.l	#$04f93000,(a0)+	;cmp2.l	ROMLimits,d3
		move.l	#ROMLimits,(a0)

		lea	ROMBasePatch4(a3),a0
		move.l	#$04f98000,(a0)+	;cmp2.l	ROMLimits,a0
		move.l	#ROMLimits,(a0)+
		move.b	#$65,(a0)		;bcs	...

; Laden von Resources patchen
		lea	ROMResLoad(a3),a0
		move.w	#$4ef9,(a0)+		;jmp	ResLoadPatch
		move.l	#ResLoadPatch,(a0)

; Prozessorgeschwindigkeitstest ersetzen
		lea	ROMSpeedTest(a3),a0
		move.w	#$31fc,(a0)+		;move.w #xxx,TimeDBRA
		move.w	TimeDBRA,(a0)+
		move.w	#$0d00,(a0)+
		move.w	#$31fc,(a0)+		;move.w #xxx,TimeSCCDBRA
		move.w	TimeSCCDBRA,(a0)+
		move.w	#$0d02,(a0)+
		move.w	#$31fc,(a0)+		;move.w #xxx,TimeSCSIDBRA
		move.w	TimeSCSIDBRA,(a0)+
		move.w	#$0b24,(a0)+
		move.w	#$31fc,(a0)+		;move.w #xxx,TimeRAMDBRA
		move.w	TimeRAMDBRA,(a0)+
		move.w	#$0cea,(a0)+
		move.w	#$4e75,(a0)		;rts

; Busfehler-Patches
		lea	ROMAdr4Patch(a3),a0
		move.l	#$4e714e71,(a0)		;nop nop

		lea	ROMBERRPatch1(a3),a0
		move.w	#$4ef9,(a0)+		;jmp	BERRPatch1
		move.l	#BERRPatch1,(a0)

		lea	ROMBERRPatch2(a3),a0
		move.w	#$4ef9,(a0)+		;jmp	BERRPatch2
		move.l	#BERRPatch2,(a0)

; InitCursor im Amiga-Mauszeiger-Modus patchen
		tst.w	UseAmigaMouse
		beq	77$
		lea	ROMCursorPatch(a3),a0
		move.l	#$4e714e71,(a0)
77$

; EDisk-Patch (scannt nach EDisks von ROMBase..$e00000)
		move.l	#'DRVR',d0
		moveq	#$33,d1			;.EDisk
		bsr	SearchRsrc
		move.l	a0,d0
		beq	74$

		move.l	-8(a0),d1		;Länge holen
		lsr.l	#1,d1
76$		cmp.l	#$d5fc0001,(a0)
		bne	75$
		cmp.l	#$0000b5fc,4(a0)
		bne	75$
		cmp.l	#$00e00000,8(a0)
		bne	75$
		clr.l	8(a0)
		bra	74$
75$
		addq.l	#2,a0
		dbra	d1,76$
74$

; Caches/PTEST
		cmp.w	#4,CPUType		;Nur 68040/060
		bne	53$
		cmp.l	#$100000,ROMSize	;Nur bei 1MB-ROM!
		bne	53$
		lea	ROMPTESTPatchL(a3),a0
		move.w	#(ROMPTESTPatchU-ROMPTESTPatchL)/2-1,d1
51$		cmp.l	#$205f225f,(a0)
		bne	52$
		cmp.l	#$0c380004,4(a0)
		bne	52$
		cmp.w	#$012f,8(a0)
		bne	52$
		move.w	#$4ef9,4(a0)
		move.l	#PTESTPatch,6(a0)
		bra	53$
52$
		addq.l	#2,a0
		dbra	d1,51$
53$

; Caches/PTEST in SANE
		cmp.w	#4,CPUType		;Nur 68040/060
		bne	66$
		move.l	#'PACK',d0
		moveq	#4,d1
		bsr	SearchRsrc

		move.l	a0,-(sp)

		move.l	-8(a0),d1		;Länge holen
61$		cmp.l	#$0c380004,(a0)
		bne	62$
		cmp.l	#$012f6d54,4(a0)
		bne	62$
		move.w	#$4ef9,(a0)		;jmp	PTESTPatch
		move.l	#PTESTPatch,2(a0)
		bra	63$
62$		addq.l	#2,a0
		subq.l	#2,d1
		bpl	61$
63$
		move.l	(sp)+,a0

		lea	-48(a0),a0
		move.l	#'PACK',d0
		moveq	#4,d1
		bsr	SNextRsrc		;Zweites Vorkommen

		move.l	-8(a0),d1		;Länge holen
64$		cmp.l	#$0c380004,(a0)
		bne	65$
		cmp.l	#$012f6d54,4(a0)
		bne	65$
		move.w	#$4ef9,(a0)		;jmp	PTESTPatch
		move.l	#PTESTPatch,2(a0)
		bra	66$
65$		addq.l	#2,a0
		subq.l	#2,d1
		bpl	64$
66$

; Ethernet-Patch (ROMs >=$27 entfernen die sResource $fd)
		cmp.l	#$100000,ROMSize	;Nur bei 1MB-ROM!
		bne	82$
		lea	ROMEtherPatch(a3),a0
		cmp.l	#$7031a06e,(a0)		;SDeleteSRTRec
		bne	82$
		move.l	#$70004e71,(a0)		;moveq #0,d0  nop
82$

; VBR-Patch 2 (68040 FPSP soll nicht ins Amiga-VBR schreiben)
		cmp.l	#$100000,ROMSize	;Nur bei 1MB-ROM!
		bne	83$
		lea	ROMVBRPatch2(a3),a0
		cmp.l	#$4e7a8801,(a0)
		bne	831$
		move.l	#$91c84e71,(a0)		;sub.l a0,a0  nop
831$		cmp.l	#$4e7a8801,8(a0)
		bne	83$
		move.l	#$91c84e71,8(a0)	;sub.l a0,a0  nop
83$

; SCSI-Load-Patch (nicht von anderen SCSI-Geräten als Platten booten)
		lea	ROMSCSILoad(a3),a0
		move.l	#$48e77ffe,(a0)+	;movem.l d1-d7/a0-a6,-(sp)
		move.l	#$1f007a07,(a0)+	;move.b d0,-(sp)  moveq #7,d5
		move.l	#$0b176718,(a0)+	;btst d5,(sp)  beq ...
		move.l	#$0b380b2e,(a0)+	;btst d5,$b2e
		move.l	#$66124eb9,(a0)+	;bne ...
		move.l	#SCSILoadPatch,(a0)+	;jsr SCSILoadPatch
		move.l	#$660a4e71,(a0)+	;bne ...  nop
		move.l	#$4e716114,(a0)+	;nop  bsr ...
		move.l	#$67020b97,(a0)+	;beq ...  bclr d5,(sp)
		move.l	#$51cdffe2,(a0)		;dbra d5,...

; Absolute Hardwarezugriffe lahmlegen
		lea	ROMHWAccess1(a3),a0
		cmp.l	#$50f1a101,(a0)
		bne	80$
		move.l	#$4e714e71,4(a0)	;nop nop
80$

; MemoryDispatch() nicht durch Unimplemented-Trap ersetzen
		lea	ROMMemDispPatch(a3),a0
		cmp.w	#$a247,(a0)
		bne	85$
		move.w	#$4e71,(a0)		;nop
85$
		moveq	#0,d0			;Alles OK
		rts

ROMNotUsable	moveq	#-1,d0			;Fehler aufgetreten
		rts

		MACHINE	68040

PTESTPatch	nop
		cpusha	bc
		nop
		moveq	#0,d0
		rts

		MACHINE	68020


*
* ROM-Resource suchen (Typ in d0, ID in d1, Zeiger nach a0)
*

SearchRsrc	move.l	$1a(a3),a0
		add.l	a3,a0
		move.l	(a0),a0
		add.l	a3,a0

SRsrcLoop	cmp.l	16(a0),d0
		bne	SNextRsrc
		cmp.w	20(a0),d1
		bne	SNextRsrc
		move.l	12(a0),a0
		add.l	a3,a0
		rts

SNextRsrc	move.l	8(a0),a0
		add.l	a3,a0
		cmp.l	a3,a0
		bne	SRsrcLoop
		sub.l	a0,a0		;Nicht gefunden
		rts


**
** Patches
**

*
* Reset-Routine
*

; Mac läuft noch nicht (nach Reset wichtig)
DoReset		clr.w	MacRunning
		clr.w	NoSuperSwitch
		move.l	TheShapeSema,a0
		clr.w	ss_MacRunning(a0)

; Supervisor-Stack setzen (wichtig!)
		move.l	MemTop,a0
		sub.l	#$10000,a0
		move.l	a0,a7

; Parameter-RAM initialisieren
		move.l	#'NuMc',XPRam+$c
		move.w	#1,XPRam+$76		;OSDefault=MacOS
		move.b	#%101,XPRam+$8a		;32Bit-Modus

		tst.b	HasRealSCC		;Echter SCC vorhanden?
		bne	1$
		tst.w	XPRam+$e0		;Nein, LocalTalk eingestellt?
		bne	1$
		move.l	#$00fd000a,XPRam+$e0	;Ja, EtherTalk einstellen
1$
		tst.w	GotChannel01		;Audio-Kanäle vorhanden?
		bne	2$
		and.b	#$f8,XPRam+$20		;Nein, Lautstärke Null
2$

; MemInfo einrichten
		move.l	MemTop,MemInfo-20
		move.w	#$0001,MMUType		;MMU nicht vorhanden

; VIA und SCC initialisieren
		JSRSELF	ResetVIA
		JSRSELF	ResetSCC

; Übriggebliebene Time-Manager-Tasks entfernen
		bsr	CleanupTimeMgr

; Übriggebliebene Protokolle entfernen
		bsr	CleanupNetwork

; Register/Variablen setzen/löschen
		move.l	TheMachDef,a1		;a1: MachDef
		lea	MemInfo,a4		;a4: MemInfo
		move.l	MemTop,a5		;a5: BufPtr
		move.l	MemTop,a6		;a6: MemTop
		move.l	$18(a1),d0		;d0: ChipAvailFlags
		move.l	$1c(a1),d1		;d1: Flags
		move.l	$10(a1),d2		;d2: HWCfgFlags/IDs

		tst.b	HasFPU			;FPU vorhanden?
		bne	3$
		bclr	#28,d2			;Nein, FPU-Flag löschen
3$
		moveq	#0,d7
		move.b	$12(a1),d7		;ModelID
		swap	d7
		move.w	CPUType,d7		;CPUFlags

; Da der Stackpointer verändert wurde, müssen wir direkt zurückspringen
		move.l	ROMBase,a0
		lea	ROMEntry(a0),a0
		jmp	(a0)

*
* Traps patchen
*

; Wegen Patch...
PatchTraps	move.l	ROMBase,a0
		add.l	#ROMPatch1Cnt,a0
		jsr	(a0)

; Keine MMU vorhanden
		clr.b	$cb1

; Traps patchen
		lea	WriteParam,a0
		move.w	#$a038,d0
		dc.w	$a247

		lea	ReadDateTime,a0
		move.w	#$a039,d0
		dc.w	$a247

		lea	SetDateTime,a0
		move.w	#$a03a,d0
		dc.w	$a247

		move.l	$4fc,OldInitUtil
		lea	InitUtil,a0
		move.w	#$a03f,d0
		dc.w	$a247

		lea	ReadXPRam,a0
		move.w	#$a051,d0
		dc.w	$a247

		lea	WriteXPRam,a0
		move.w	#$a052,d0
		dc.w	$a247

		lea	StripAddress,a0
		move.w	#$a055,d0
		dc.w	$a247

		tst.b	HasRealVIA
		bne	2$
		lea	InsTime,a0	;Time Manager ohne VIA
		move.w	#$a058,d0
		dc.w	$a247
		lea	RmvTime,a0
		move.w	#$a059,d0
		dc.w	$a247
		lea	PrimeTime,a0
		move.w	#$a05a,d0
		dc.w	$a247
		lea	Microseconds,a0
		move.w	#$a093,d0
		dc.w	$a247
2$
		lea	PowerOff,a0
		move.w	#$a05b,d0
		dc.w	$a247

		lea	SwapMMUMode,a0
		move.w	#$a05d,d0
		dc.w	$a247

		lea	ADBOp,a0
		move.w	#$a07c,d0
		dc.w	$a247

		tst.b	IsDraco		;Auf dem DraCo kein DebugUtil (wegen CIA-Zugriffen)
		bne	1$
		lea	DebugUtil,a0
		move.w	#$a08d,d0
		dc.w	$a247
1$
		lea	Translate24To32,a0
		move.w	#$a091,d0
		dc.w	$a247

		move.l	$660,OldHWPriv
		lea	HWPriv,a0
		move.w	#$a198,d0
		dc.w	$a247

		move.l	$48c,OldDisposHandle
		lea	DisposHandle,a0
		move.w	#$a023,d0
		dc.w	$a247

		lea	CacheFlush,a0
		move.w	#$a0bd,d0
		dc.w	$a247

		lea	SCSIDispatch,a0
		move.w	#$a815,d0
		dc.w	$a647		;SetToolTrapAddress

		move.l	$15f8,OldPutScrap
		lea	PutScrap,a0
		move.w	#$a9fe,d0
		dc.w	$a647

		lea	DebugStr,a0
		move.w	#$abff,d0
		dc.w	$a647


; Mausabfrage initialisieren
		JSRSELF	InitMouse

; MemInfo restaurieren (Wichtig! Wird beim 68030 aus irgendeinem Grund
;  überschrieben!)
		move.l	MemSize,MemInfo-20 ;Jetzt steht hier die Größe!

; Speichermenge setzen
		move.l	$1ef8,d0	;Physical Size
		sub.l	$1ef4,d0	;Logical Size
		move.l	MemSize,$1ef8
		move.l	MemSize,$1ef4
		sub.l	d0,$1ef4
		rts

*
* Macintosh-Interrupts anschalten
*

; SFindDevBase patchen
PatchIRQ	move.l	$db8,a0
		move.l	#FindDevBase,$6c(a0)
		move.l	#FindDevBase,$70(a0)

; Timer starten
		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		JSRLIB	CacheClearU	;Zur Sicherheit

		tst.b	IsDraco		;Kein CIA-Zugriff auf dem DraCo
		bne	1$
		move.l	CiaControlReg,a0
		or.b	#$01,(a0)	;Timer starten
1$
		move.l	(sp)+,a6

; Der Macintosh läuft jetzt (Interrupts aktiv)
		move.w	#-1,MacRunning
		move.w	#-1,NoSuperSwitch
		move.l	TheShapeSema,a0
		move.w	#-1,ss_MacRunning(a0)
		rts

*
* Andere Sachen patchen
*

; JSwapMMU setzen
PatchStuff	move.l	#SwapMMUMode,$dbc

; Mac-Mauszeiger ausschalten, falls Amiga-Mauszeiger benutzt wird
		tst.w	UseAmigaMouse
		beq	1$
		move.l	$818,OldSetCursor
		move.l	#SetCursor,$818
1$

; Wegen Patch...
		move.l	$2a6,a0		;SysZone
		move.l	(a0),a0		;Limit
2$		rts

*
* Treiber installieren
*

InstallDrvrs	move.l	a1,$12(a0)	;Wegen Patch...
		dc.w	$a000		;Open
		bsr	FixVector16
		JSRSELF	InstallADD
		JSRSELF InstallAFD
		JMPSELF	InstallAppleCD

; MacsBug 6.6 tests a flag at $42(FSVarsPtr) while it loads. FSVarsPtr ($BB8)
; is still -1 then, so it really reads the byte at $41: the second byte of
; exception vector 16, which points into the ROM. If bit 3 of it is set (bit
; 19 of the handler's address) MacsBug calls a trap the System has not
; installed yet and the Mac stops with "unimplemented trap" before it has
; started. On a Mac the ROM is at $408xxxxx and the bit is always clear; under
; ShapeShifter the ROM lies wherever the Amiga had room, so it was a matter
; of luck. Vectors 16-23 are reserved and never taken: when the bit is set,
; vector 16 goes through a jump placed over vectors 22/23.
FixVector16	btst	#3,($41).w
		beq	1$
		move.w	#$4ef9,($58).w		;jmp <old handler>
		move.l	($40).w,($5a).w
		move.l	#$58,($40).w
1$		rts

*
* Patch nach dem Laden der Systemdatei (aufgerufen über MakePeriodicAction des ADD)
*

PatchAfterFinder
		tst.l	NoQDAccel
		bne	1$
		JSRSELF	AccelQuickDraw
1$		JMPSELF	InstallSndInput	;Sound-Input-Treiber installieren

*
* SysError: Emergency Shut Down erlauben
*

; Warten auf Mausklick
SysError1	tst.b	EmergShutDown
		bne	PowerOff
		tst.b	$172
		bne	SysError1
		rts

*
* OSEventAvail: Verschiedenes
*

OSEventAvail	move	sr,d1
		and.w	#$0700,d1
		bne	OSEANoCheck

		tst.b	EmergShutDown
		bne	PowerOff
		tst.b	ProgSwitch
		bne	RaiseNMI

		JSRSELF	CheckClip
		JSRSELF	ExecuteAT

OSEANoCheck	lea	$14a,a1		;EventQueue
		move.l	(sp)+,d1
		move.w	sr,-(sp)
		move.l	d1,-(sp)
		rts

RaiseNMI	clr.b	ProgSwitch
		move.w	#$007c,-(sp)
		move.l	#NMIContinue,-(sp)
		move	sr,-(sp)
		move.l	$7c,-(sp)
		rts
NMIContinue	bra	OSEANoCheck

*
* Schreiben des Parameter-RAMs
*

WriteParam	lea	XPRam+$10,a0
		lea	$1f8,a1
		move.l	(a1)+,(a0)+
		move.l	(a1)+,(a0)+
		move.l	(a1)+,(a0)+
		move.l	(a1),(a0)
		move.l	$208,XPRam+$08
		moveq	#0,d0
		rts

*
* Lesen der Echtzeituhr
*

InitRTC		move.l	_IntuitionBase,a6
		lea	SysTime,a0
		lea	SysMics,a1
		JSRLIB	CurrentTime
		add.l	#$8b31ef80,SysTime
		move.l	SysTime,StartupTime
		rts

ReadDateTime	movem.l a0/a6,-(sp)
		move.l	_IntuitionBase,a6
		lea	SysTime,a0
		lea	SysMics,a1
		EJSRLIB	CurrentTime
		add.l	#$8b31ef80,SysTime
		movem.l (sp)+,a0/a6
		move.l	SysTime,$20c
		move.l	$20c,(a0)
		moveq	#0,d0
		rts

*
* Schreiben der Echtzeituhr
*

SetDateTime	move.l	d0,$20c
		move.l	d0,SysTime
		moveq	#0,d0
		rts

*
* Lesen des Parameter-RAMs
*

InitUtil	move.l	OldInitUtil,a0
		jsr	(a0)

		movem.l	d0-d2,-(sp)
		lea	XPRam+$10,a0	;Einstellungen lesen
		lea	$1f8,a1
		move.l	(a0)+,(a1)+
		move.l	(a0)+,(a1)+
		move.l	(a0)+,(a1)+
		move.l	(a0),(a1)
		move.l	XPRam+$08,$208
		movem.l	a0-a1/a6,-(sp)		;Zeit/Datum jetzt lesen (nicht die Startzeit:
		move.l	_IntuitionBase,a6	; nach einem Mac-Neustart ginge die Uhr sonst nach)
		lea	SysTime,a0
		lea	SysMics,a1
		EJSRLIB	CurrentTime
		add.l	#$8b31ef80,SysTime
		movem.l	(sp)+,a0-a1/a6
		move.l	SysTime,$20c

		movem.l	(sp)+,d0-d2
		tst.w	d0
		rts

*
* Lesen des erweiterten Parameter-RAMs
*

ReadXPRam	lea	XPRam,a1
		add.w	d0,a1
		swap	d0
		subq.w	#1,d0
1$		move.b	(a1)+,(a0)+
		dbra	d0,1$
		moveq	#0,d0
		rts

*
* Schreiben des erweiterten Parameter-RAMs
*

WriteXPRam	and.w	#$ff,d0
		lea	XPRam,a1
		add.w	d0,a1
		swap	d0
		subq.w	#1,d0
1$		move.b	(a0)+,(a1)+
		dbra	d0,1$
		moveq	#0,d0
		rts

*
* StripAddress macht nichts
*

StripAddress	rts

*
* Time Manager initialisieren (kein Mac-Trap)
*

InitTimeMgr	lea	TMTaskList,a0
		NEWLIST	a0
		clr.l	TMFree			;all pool records onto the free list
		lea	TMPool,a0
		moveq	#TMPOOLSIZE-1,d0
1$		move.l	TMFree,(a0)
		move.l	a0,TMFree
		lea	SIZEOF_TMTask(a0),a0
		dbra	d0,1$
		st.b	TimeMgrInited
		rts

*
* Time Manager beenden (kein Mac-Trap)
*

ExitTimeMgr	tst.b	TimeMgrInited
		beq	ETMExit
		move.l	_ExecBase,a6
		move.l	TMTaskList+LH_HEAD,a3
ETMLoop		move.l	LN_SUCC(a3),d2		;d2: Succ
		beq	ETMExit
		move.l	tm_MacTask(a3),a2
		bclr	#7,4(a2)
		beq	1$
		bsr	TMCancel		;Task war aktiv, abbrechen
1$		bsr	TMRelease
		move.l	d2,a3
		bra	ETMLoop
ETMExit		tst.b	TimeMgrInited
		beq	3$
		move.l	TMFree,d2		;free the records that came from AllocMem
		clr.l	TMFree
2$		tst.l	d2
		beq	3$
		move.l	d2,a1
		move.l	(a1),d2
		cmp.l	#TMPool,a1
		blo	4$
		cmp.l	#TMPoolEnd,a1
		blo	2$
4$		moveq	#SIZEOF_TMTask,d0
		JSRLIB	FreeMem
		bra	2$
3$		rts

*
* TMCancel: stop the timer request of a3 and take its reply out of the
* soft interrupt port, so the record can be reused or freed at once.
* (AbortIO replies the request; called with interrupts masked, the soft
* interrupt that would fetch that reply has not run yet.)
*

TMCancel	JSRLIB	Disable
		lea	tm_TimerIO(a3),a1
		JSRLIB	AbortIO
		move.l	TimerIntPort,a0
		move.l	MP_MSGLIST+LH_HEAD(a0),a0
		lea	tm_TimerIO(a3),a1
1$		tst.l	LN_SUCC(a0)
		beq	2$
		cmp.l	a0,a1
		beq	3$
		move.l	LN_SUCC(a0),a0
		bra	1$
3$		JSRLIB	Remove
2$		JSRLIB	Enable
		rts

*
* TMRelease: unlink record a3 and put it on the free list (no FreeMem:
* RmvTime may be called at interrupt time)
*

TMRelease	JSRLIB	Disable
		move.l	a3,a1
		JSRLIB	Remove
		move.l	TMFree,(a3)
		move.l	a3,TMFree
		JSRLIB	Enable
		rts

*
* TMAlloc: d0 = cleared record or 0. Takes it from the pool; AllocMem only
* when the pool is empty.
*

TMAlloc		JSRLIB	Disable
		move.l	TMFree,d0
		beq	1$
		move.l	d0,a0
		move.l	(a0),TMFree
1$		JSRLIB	Enable
		tst.l	d0
		bne	2$
		moveq	#SIZEOF_TMTask,d0
		move.l	#MEMF_CLEAR|MEMF_PUBLIC,d1
		JSRLIB	AllocMem
		tst.l	d0
		rts
2$		move.l	d0,a0
		moveq	#SIZEOF_TMTask/4-1,d1
3$		clr.l	(a0)+
		dbra	d1,3$
		tst.l	d0
		rts

*
* Übriggebliebene Time-Manager-Tasks entfernen (wird im Reset aufgerufen)
*

CleanupTimeMgr	move.l	_ExecBase,a6
		move.l	TMTaskList+LH_HEAD,a3
CTMLoop		move.l	LN_SUCC(a3),d2		;d2: Succ
		beq	CTMExit
		move.l	tm_MacTask(a3),a2
		bclr	#7,4(a2)
		beq	1$
		bsr	TMCancel		;Task war aktiv, abbrechen
1$		bsr	TMRelease
		move.l	d2,a3
		bra	CTMLoop
CTMExit		rts

*
* InsTime: TMTask erzeugen und einhängen
*

InsTime		movem.l	a2-a3/a6,-(sp)
		DPRINTF	" InsTime %08lx",a0
		move.l	_ExecBase,a6
		move.l	a0,a2			;a2: MacTask

		moveq	#$1f,d0
		and.b	4(a2),d0
		and.w	#$0600,d1
		lsr.w	#4,d1
		or.b	d1,d0
		move.b	d0,4(a2)

		clr.l	(a2)			;no record: PrimeTime/RmvTime ignore the task
		bsr	TMAlloc
		beq	2$
		move.l	d0,a3			;a3: TMTask

		move.l	a2,tm_MacTask(a3)
		move.l	a3,(a2)			;qLink zeigt auf TMTask

		move.l	TimerIO,a0
		lea	tm_TimerIO(a3),a1
		moveq	#IOTV_SIZE-1,d0
1$		move.b	(a0)+,(a1)+
		dbra	d0,1$

		JSRLIB	Disable
		lea	TMTaskList,a0
		move.l	a3,a1
		JSRLIB	AddTail
		JSRLIB	Enable

2$		movem.l	(sp)+,a2-a3/a6
		moveq	#0,d0
		rts

*
* RmvTime: TMTask entfernen und freigeben, ggf. Restzeit berechnen
*

RmvTime		movem.l	d2/a2-a3/a6,-(sp)
		DPRINTF	" RmvTime %08lx, tm %08lx",a0,(a0)
		move.l	_ExecBase,a6
		move.l	a0,a2			;a2: MacTask
		move.l	(a0),d0			;TMTask vorhanden?
		beq	4$
		move.l	d0,a3			;a3: TMTask

		bclr	#7,4(a2)		;Task inaktiv machen
		beq	1$
		bsr	TMCancel		;Task war aktiv, abbrechen
		move.l	_TimerBase,a6
		lea	tm_TimerIO+IOTV_TIME(a3),a0 ;Restzeit berechnen
		JSRLIB	GetSysTime
		move.l	a0,a1
		lea	tm_ExpTime(a3),a0
		JSRLIB	SubTime

		move.l	_ExecBase,a6
		moveq	#0,d1			;In 64-Bit-Mikrosekunden umrechnen
		move.l	TV_SECS(a0),d0
		mulu.l	#1000000,d1:d0
		add.l	TV_MICRO(a0),d0
		moveq	#0,d2
		addx.l	d2,d1

		tst.l	d1			;Zu groß für 32-Bit-Mikrosekunden?
		bne	3$
		cmp.l	#$7fffffff,d0
		bhi	3$

		neg.l	d0			;Nein, in negierten Mikrosekunden angeben
		move.l	d0,10(a2)
		bra	2$

3$		divu.l	#1000,d1:d0		;Sonst in Millisekunden umrechnen
		move.l	d0,10(a2)
		bra	2$

1$		clr.l	10(a2)			;Task war inaktiv, Restzeit 0

2$		bsr	TMRelease
		clr.l	(a2)			;qLink entfernen

4$		movem.l	(sp)+,d2/a2-a3/a6
		moveq	#0,d0
		rts

*
* PrimeTime: TimerIO starten
*

PrimeTime	movem.l	a2-a3/a6,-(sp)
		DPRINTF	" PrimeTime %08lx, tm %08lx, time %08lx",a0,(a0),d0
		move.l	_ExecBase,a6
		move.l	a0,a2			;a2: MacTask
		move.l	(a0),d1			;TMTask vorhanden?
		beq	3$
		move.l	d1,a3			;a3: TMTask

		btst	#7,4(a2)		;still running: stop it before sending the
		beq	4$			; request again
		move.l	d0,-(sp)
		bsr	TMCancel
		move.l	(sp)+,d0
4$
		tst.l	d0			;Zeit in Mikrosekunden?
		bmi	1$

		mulu.l	#1000,d1:d0		;Nein, in Mikrosekunden umrechnen
		divu.l	#1000000,d1:d0		; und dann in Sekunden und Mikrosekunden
		move.l	d0,tm_TimerIO+IOTV_TIME+TV_SECS(a3)
		move.l	d1,tm_TimerIO+IOTV_TIME+TV_MICRO(a3)
		bra	2$

1$		neg.l	d0			;Ja, in Sekunden und Mikrosekunden umrechnen
		divul.l	#1000000,d1:d0
		move.l	d0,tm_TimerIO+IOTV_TIME+TV_SECS(a3)
		move.l	d1,tm_TimerIO+IOTV_TIME+TV_MICRO(a3)

2$		move.l	_TimerBase,a6		;Zeitpunkt des Expires berechnen
		lea	tm_ExpTime(a3),a0
		JSRLIB	GetSysTime
		lea	tm_TimerIO+IOTV_TIME(a3),a1
		JSRLIB	AddTime

		bset	#7,4(a2)		;Task ist jetzt aktiv
		lea	tm_TimerIO(a3),a1	;Request starten
		move.w	#TR_ADDREQUEST,IO_COMMAND(a1)
		jsr	-30(a6)

3$		movem.l	(sp)+,a2-a3/a6
		moveq	#0,d0
		rts

*
* Server für Time-Manager-SoftInt
*

TimeMgrServer	move.l	TimerIntPort,a0
		JSRLIB	GetMsg
		tst.l	d0
		beq	TMSExit

		move.l	d0,a0
		lea	-tm_TimerIO(a0),a0	;a0: TMTask
		move.l	tm_MacTask(a0),a1	;a1: MacTask

		bclr	#7,4(a1)		;Task inaktiv machen
		beq	TMSNext
		tst.w	MacRunning
		beq	TMSNext
		move.l	6(a1),d0		;Task war aktiv, Routine vorhanden?
		beq	TMSNext
		move.l	d0,a0			;Ja, Routine aufrufen
		addq.w	#1,NoSuperSwitch
		jsr	(a0)
		subq.w	#1,NoSuperSwitch
TMSNext		bra	TimeMgrServer

TMSExit		rts

*
* Microsecond Timer
*

Microseconds	move.l	a6,-(sp)
		move.l	_TimerBase,a6
		lea	TimeValBuf,a0
		EJSRLIB	GetSysTime
		lea	TimeValBuf,a0
		move.l	TV_SECS(a0),d0
		move.l	TV_MICRO(a0),d2
		mulu.l	#1000000,d1:d0
		add.l	d2,d0
		moveq	#0,d2
		addx.l	d2,d1
		move.l	d1,a0
		move.l	d0,d0		;Mics
		move.l	(sp)+,a6
		rts

*
* SwapMMUMode macht nichts
*

SwapMMUMode	moveq	#1,d0
		rts

*
* ABD-Zugriff
*

ADBOp		movem.l	d1-d3/a0-a3,-(sp)

		DPRINTF	"ADBOp d0 %08lx, a0 %08lx",d0,a0

		move.l	d0,d3
		move.l	a0,a3

		move.b	d0,d1
		beq	ADBOpCompl
		and.b	#$f0,d1		;Adresse auswerten
		lsr.b	#4,d1
		cmp.b	KeyReg3,d1	;Tastatur?
		beq	ADBKey
		cmp.b	MouseReg3,d1	;Maus?
		beq	ADBMouse

; Unbekannte Adresse
		move.b	d0,d1		;Befehl auswerten
		and.b	#$0c,d1
		cmp.b	#$0c,d1
		beq	ADBTalk
		bra	ADBOpCompl

ADBTalk		move.l	(a3),a0		;Talk: 0 Bytes Daten
		clr.b	(a0)
		bra	ADBOpCompl

; Tastatur
ADBKey		move.b	d0,d1		;Befehl auswerten
		and.b	#$0c,d1
		cmp.b	#$08,d1
		beq	ADBKeyListen
		cmp.b	#$0c,d1
		beq	ADBKeyTalk
		bra	ADBOpCompl

ADBKeyListen	move.l	(a3),a0		;Listen: Register auswerten
		and.b	#$03,d0
		cmp.b	#$03,d0
		beq	ADBKeyListen3
		bra	ADBOpCompl

ADBKeyListen3	move.w	1(a0),d0	;Listen Reg 3
		cmp.b	#$fe,d0		;ID auswerten
		beq	1$
		cmp.b	#$ff,d0
		beq	2$
		move.b	KeyReg3+1,d0	;DeviceHanderID nicht ändern
		move.w	d0,KeyReg3	;Normal, Register setzen
		bra	ADBOpCompl
1$		move.b	1(a0),KeyReg3	;Reassign Adr: Neue Adresse eintragen
		bra	ADBOpCompl
2$		bra	ADBOpCompl	;Self Test

ADBKeyTalk	move.l	(a3),a0		;Talk: Register auswerten
		clr.b	(a0)
		and.b	#$03,d0
		cmp.b	#$03,d0
		beq	ADBKeyTalk3
		bra	ADBOpCompl

ADBKeyTalk3	move.b	#2,(a0)+	;Talk Reg 3: 2 Bytes Daten
		move.w	KeyReg3,(a0)	;Register lesen
		bra	ADBOpCompl

; Maus
ADBMouse	move.b	d0,d1		;Befehl auswerten
		and.b	#$0c,d1
		cmp.b	#$08,d1
		beq	ADBMouseListen
		cmp.b	#$0c,d1
		beq	ADBMouseTalk
		bra	ADBOpCompl

ADBMouseListen	move.l	(a3),a0		;Listen: Register auswerten
		and.b	#$03,d0
		cmp.b	#$03,d0
		beq	ADBMouseListen3
		bra	ADBOpCompl

ADBMouseListen3	move.w	1(a0),d0	;Listen Reg 3
		cmp.b	#$fe,d0		;ID auswerten
		beq	1$
		cmp.b	#$ff,d0
		beq	2$
		move.b	MouseReg3+1,d0	;DeviceHanderID nicht ändern
		move.w	d0,MouseReg3	;Normal, Register setzen
		bra	ADBOpCompl
1$		move.b	1(a0),MouseReg3	;Reassign Adr: Neue Adresse eintragen
		bra	ADBOpCompl
2$		bra	ADBOpCompl	;Self Test

ADBMouseTalk	move.l	(a3),a0		;Talk: Register auswerten
		clr.b	(a0)
		and.b	#$03,d0
		cmp.b	#$03,d0
		beq	ADBMouseTalk3
		bra	ADBOpCompl

ADBMouseTalk3	move.b	#2,(a0)+	;Talk Reg 3: 2 Bytes Daten
		move.w	MouseReg3,(a0)	;Register lesen
		bra	ADBOpCompl

; Completion Routine aufrufen
ADBOpCompl	tst.l	4(a3)
		beq	ADBOpOK
		move.l	d3,d0
		move.l	(a3),a0
		move.l	4(a3),a1
		move.l	8(a3),a2
		move.l	$cf8,a3
		jsr	(a1)
ADBOpOK		moveq	#0,d0
		bra	ADBOpRts
ADBOpErr	moveq	#-1,d0
ADBOpRts	movem.l	(sp)+,d1-d3/a0-a3
		rts

*
* DebugUtil: Funktionen für MacsBug
*

DebugUtil	tst.w	d0		;DebuggerGetMax
		beq	DebugUtil0
		cmp.w	#1,d0		;DebuggerEnter
		beq	DebugUtil1
		cmp.w	#2,d0		;DebuggerExit
		beq	DebugUtil2
		cmp.w	#3,d0		;DebuggerPoll
		beq	DebugUtil3
		moveq	#-50,d0		;Sonst Fehler
		rts

DebugUtil0	moveq	#3,d0		;DebuggerGetMax
		rts

DebugUtil1	JSRSELF	RefreshNow	;Den Stand vor dem Debugger zeigen
		move.l	CiaControlReg,a0 ;Timer stoppen
		and.b	#$80,(a0)

		move.l	CiaTimerReg,a0	;Für Tastatur vorbereiten
		move.b	#54,(a0)
		move.b	#0,$100(a0)
		rts

DebugUtil2	move.l	CiaControlReg,a0 ;Timer stoppen
		and.b	#$80,(a0)

		move.l	_ExecBase,a0	;60Hz einstellen
		move.l	ex_EClockFrequency(a0),d0
		divu.w	#60,d0
		move.l	CiaTimerReg,a0
		move.b	d0,(a0)
		lsr.w	#8,d0
		move.b	d0,$100(a0)

		move.l	CiaControlReg,a0 ;Timer starten
		or.b	#$01,(a0)
		rts

DebugUtil3	addq.w	#1,DbgPolls	;Alle 2048 Abfragen den Bildschirm
		move.w	DbgPolls,d0	; refreshen (MacsBug sichtbar, auch
		and.w	#$07ff,d0	; wenn kein Amiga-Task laeuft)
		bne	0$
		JSRSELF	RefreshNow
0$		btst	#3,$bfed01	;SP-Interrupt erhalten?
		beq	1$

		move.b	$bfec01,d0	;Ja, Keycode holen

		or.b	#$40,$bfee01	;Handshake starten
		move.l	CiaControlReg,a0
		or.b	#$09,(a0)	;Timer starten, One-Shot

		ror.b	#1,d0		;Richtig schieben
		not.b	d0		;Und invertieren
		move.b	d0,d1
		and.w	#$7f,d0		;d0 - Keycode ohne Flag
		and.w	#$80,d1		;d1 - Up/Down-Flag
		lea	KeyXLate,a0
		move.b	(a0,d0.w),d0	;Keycode übersetzen
		or.b	d1,d0		;d0 - Macintosh-Keycode mit Flag

		JSRSELF	DoMacKeycode

		move.l	CiaControlReg,a0
2$		btst	#0,(a0)		;Auf Timer warten (über Run-Flag)
		bne	2$

		and.b	#$bf,$bfee01	;Handshake stoppen
		and.b	#$f0,(a0)	;Timer stoppen

1$		moveq	#0,d0
		rts

*
* DebugStr: Text anzeigen
*

DebugStr	move.l	(sp)+,d0
		move.l	(sp)+,a0	;Zeiger auf BSTR holen
		move.l	d0,-(sp)
		movem.l	d1-d2/a1-a3/a6,-(sp)

		lea	DebugStrBuf,a1	;BSTR in CSTR konvertieren
		moveq	#0,d0
		move.b	(a0)+,d0
		beq	1$
		subq.w	#1,d0
2$		move.b	(a0)+,(a1)+
		dbra	d0,2$
1$		clr.b	(a1)+

		move.l	_IntuitionBase,a6
		sub.l	a0,a0
		lea	DebugStrReq,a1
		sub.l	a2,a2
		lea	DebugStrArgs,a3
		EJSRLIB	EasyRequestArgs	;Requester darstellen
		movem.l	(sp)+,d1-d2/a1-a3/a6
		rts

*
* Translate24To32: Macht nichts
*

Translate24To32 rts

*
* CacheFlush: Code-Cache löschen
*             Register müssen gesichert werden!
*

CacheFlush	movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
		rts

*
* DisposeHandle: refuse a handle that does not lead to a relocatable block.
* A program that disposes a handle twice passes a free master pointer, whose
* contents are the link to the next free one. If that link is the first entry
* of a master pointer block, the ROM frees the whole block (it has a valid
* non-relocatable header) and every handle in it goes with it. 32-bit Memory
* Manager only.
*

DisposHandle	tst.b	$cb2		;24-bit Memory Manager: other block headers
		beq	1$
		move.l	a0,d0
		beq	1$
		btst	#0,d0
		bne	1$
		move.l	(a0),d0		;Empty handle: the ROM handles that
		beq	1$
		btst	#0,d0
		bne	1$
		move.l	a1,-(sp)
		move.l	d0,a1
		btst	#7,-12(a1)	;Tag of the block header: relocatable?
		move.l	(sp)+,a1
		beq	2$
1$		move.l	OldDisposHandle,-(sp)
		rts
2$		moveq	#-111,d0	;memWZErr
		move.w	d0,$220		;MemErr
		rts

*
* HWPriv: Caches löschen
*
* 7: Enable/Disable external SCC clocking (Mac IIfx Inside Story)
*

HWPriv		tst.w	d0		;SwapInstructionCache
		beq	HWPriv0
		cmp.w	#1,d0		;FlushInstructionCache
		beq	HWPriv1
		cmp.w	#2,d0		;SwapDataCache
		beq	HWPriv2
		cmp.w	#3,d0		;FlushDataCache
		beq	HWPriv3
		cmp.w	#4,d0		;EnableExtCache
		beq	HWPriv4
		cmp.w	#5,d0		;DisableExtCache
		beq	HWPriv5
		cmp.w	#6,d0		;FlushExtCache
		beq	HWPriv6
		cmp.w	#9,d0		;FlushCodeCacheRange
		beq	HWPriv9
		move.l	OldHWPriv,-(sp)
		rts

HWPriv0		move.l	a6,-(sp)	;SwapInstructionCache
		move.l	_ExecBase,a6
		moveq	#0,d0
		move.l	a0,d2		;An oder aus?
		beq	1$
		or.b	#CACRF_EnableI,d0
1$		move.l	#CACRF_EnableI,d1
		JSRLIB	CacheControl
		move.l	#CACRF_EnableI,d1
		and.l	d0,d1
		move.l	d1,a0		;Rückgabe: Vorheriger Zustand
		move.l	(sp)+,a6
		moveq	#0,d0
		rts

HWPriv1		move.l	a6,-(sp)	;FlushInstructionCache
		move.l	_ExecBase,a6
		cmp.w	#4,CPUType	;68040+?
		blo	1$
		sub.l	a0,a0		;Ja, beide Caches löschen
		moveq	#-1,d0
		move.l	#CACRF_ClearI|CACRF_ClearD,d1
		JSRLIB	CacheClearE
		bra	2$
1$		sub.l	a0,a0		;Sonst nur den I-Cache
		moveq	#-1,d0
		move.l	#CACRF_ClearI,d1
		JSRLIB	CacheClearE
2$		move.l	(sp)+,a6
		moveq	#0,d0
		rts

HWPriv2		move.l	a6,-(sp)	;SwapDataCache
		move.l	_ExecBase,a6
		moveq	#0,d0
		move.l	a0,d2		;An oder aus?
		beq	1$
		or.w	#CACRF_EnableD,d0
1$		move.l	#CACRF_EnableD,d1
		JSRLIB	CacheControl
		move.l	#CACRF_EnableD,d1
		and.l	d0,d1
		lsr.l	#8,d1
		move.l	d1,a0		;Rückgabe: Vorheriger Zustand
		move.l	(sp)+,a6
		moveq	#0,d0
		rts

HWPriv3		move.l	a6,-(sp)	;FlushDataCache
		move.l	_ExecBase,a6
		sub.l	a0,a0		;Den ganzen Cache
		moveq	#-1,d0
		move.l	#CACRF_ClearD,d1
		JSRLIB	CacheClearE
		move.l	(sp)+,a6
		moveq	#0,d0
		rts

HWPriv4		move.l	a6,-(sp)	;EnableExtCache
		move.l	_ExecBase,a6
		move.l	#CACRF_EnableE,d0
		move.l	#CACRF_EnableE,d1
		JSRLIB	CacheControl
		move.l	(sp)+,a6
		moveq	#0,d0
		rts

HWPriv5		move.l	a6,-(sp)	;DisableExtCache
		move.l	_ExecBase,a6
		moveq	#0,d0
		move.l	#CACRF_EnableE,d1
		JSRLIB	CacheControl
		move.l	(sp)+,a6
		moveq	#0,d0
		rts

HWPriv6		move.l	a6,-(sp)	;FlushExtCache
		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		move.l	(sp)+,a6
		moveq	#0,d0
		rts

HWPriv9		move.l	a6,-(sp)	;FlushCodeCacheRange
		move.l	_ExecBase,a6
		move.l	a1,d0
		move.l	#CACRF_ClearI,d1
		JSRLIB	CacheClearE
		move.l	(sp)+,a6
		moveq	#0,d0
		rts

*
* BERR-Patches
*

BERRPatch1	move.l	a0,a1
		move.l	a0,d0
		beq	1$		;NIL-Handle -> NIL
		cmp.l	#$2000,d0	;In den unteren 8K?
		bls	2$
		movem.l	d1/a1/a6,-(sp)	;Nein, gültige RAM-Adresse?
		move.l	_ExecBase,a6
		JSRLIB	TypeOfMem
		movem.l	(sp)+,d1/a1/a6
		tst.l	d0
		bne	2$
		moveq	#-1,d0		;Nein, fehlerhaftes Handle
		move.l	d0,a0
		rts
2$		move.l	(a1),a0
		move.l	a0,d0
1$		rts

BERRPatch2	move.l	a6,d0		;Zone nach d0
		movem.l	d1/a0-a1/a6,-(sp) ;Gültige RAM-Adresse?
		move.l	_ExecBase,a6
		move.l	d0,a1
		lea	$3c(a1),a1
		JSRLIB	TypeOfMem
		movem.l	(sp)+,d1/a0-a1/a6
		tst.l	d0
		beq	1$

		move.l	$3c(a6),d0	;Ja, Backpointer testen
		sub.l	a6,d0
		beq	2$
		moveq	#-113,d0	;Fehler
2$		rts

1$		moveq	#-113,d0	;Nein, Fehler
		rts


*
* (Allgemeines) WaitIO: Emergency Shut Down handhaben
*

MacWaitIO	tst.b	EmergShutDown
		bne	PowerOff

		cmp.w	#AFDRefNum,ioRefNum(a0)	;AFD?
		bne	1$
		JSRSELF	AFDWaitComplete
		bra	WaitIOLoop

1$		cmp.w	#ADDRefNum,ioRefNum(a0)	;ADD?
		bne	2$
		JSRSELF	ADDWaitComplete
		bra	WaitIOLoop

2$		cmp.w	#SonyRefNum,ioRefNum(a0) ;Sony?
		bne	3$
		JSRSELF	ADDWaitComplete

3$
WaitIOLoop	tst.b	EmergShutDown
		bne	PowerOff
		move.w	ioResult(a0),d0
		bgt	WaitIOLoop
WaitIODone	ext.l	d0
		move.w	d0,ioResult(a0)
		rts

*
* FindDevBase: Basisadresse des Bildschirmspeichers ermitteln
*

FindDevBase	move.l	a1,-(sp)
		move.b	$32(a0),-(sp)
		move.l	$18(a0),-(sp)
		clr.l	$18(a0)
		bset	#1,$1b(a0)
		pea	FDB1
		move.l	([$db8],$2c),-(sp)
		rts
FDB1		bne	FDB2
		move.b	#$0a,$32(a0)	;MinorBase
		moveq	#2,d0
		dc.w	$a06e		;ReadLong
		moveq	#0,d0
FDB2		move.l	(sp)+,$18(a0)
		move.b	(sp)+,$32(a0)
		move.l	(sp)+,a1
		rts

*
* SetCursor
*

SetCursor	move.w	#-16,$8d0
		rtd	#14




*
* ResLoadPatch
*

oldserd	dc.l	0

ResLoadPatch	;DPRINTF	"ResLoad %08lx, %08lx",d3,(a2)
		cmp.l	#'ptch',d3
		bne	RLNotPtch
		cmp.w	#26,(a2)
		bne	1$
		jsr	([$7f0])
		bra	PatchPtch26
1$		cmp.w	#420,(a2)
		bne	2$
		jsr	([$7f0])
		bra	PatchPtch420
2$
RLNotPtch	cmp.l	#'snth',d3
		bne	RLNotSnth
		cmp.w	#$0805,(a2)
		bne	1$
		jsr	([$7f0])
		bra	PatchSnth5
1$		cmp.w	#$0801,(a2)
		bne	2$
		jsr	([$7f0])
		bra	PatchSnth1
2$
RLNotSnth	cmp.l	#'scod',d3
		bne	RLNotScod
; Every scod resource: the Process Manager is -16463/-16464 up to Mac OS
; 8.0, and Mac OS 8.1 brings a second one as -16465/-16466 and runs that.
; Left unpatched, a 68060 went astray as soon as the Finder started.
; PatchScod only changes what matches its patterns.
		jsr	([$7f0])
		bra	PatchScod
RLNotScod	cmp.l	#'PTCH',d3
		bne	RLNotPTCH
		cmp.w	#$067c,(a2)
		bne	1$
		jsr	([$7f0])
		bra	PatchPTCH
1$
RLNotPTCH	cmp.l	#'sift',d3
		bne	RLNotSift
		cmp.w	#-16563,(a2)
		bne	1$
		jsr	([$7f0])
		bra	PatchSift
1$
RLNotSift	cmp.l	#'lpch',d3
		bne	RLNotLpch
		cmp.w	#24,(a2)
		bne	1$
		jsr	([$7f0])
		bra	PatchLpch24
1$		cmp.w	#31,(a2)
		bne	2$
		jsr	([$7f0])
		bra	PatchLpch31
2$		tst.b	Has68060
		beq	3$
		cmp.w	#63,(a2)
		bne	3$
		jsr	([$7f0])
		bra	PatchThreads060
3$
RLNotLpch	cmp.l	#'gpch',d3
		bne	RLNotGpch
		cmp.w	#4,CPUType
		blo	1$
		cmp.w	#750,(a2)
		bne	1$
		jsr	([$7f0])
		bra	PatchGpch750
1$		tst.b	Has68060
		beq	2$
		cmp.w	#669,(a2)
		bne	2$
		jsr	([$7f0])
		bra	PatchThreads060
2$		cmp.w	#16,(a2)
		bne	3$
		jsr	([$7f0])
		bra	PatchGpch16
3$		cmp.w	#650,(a2)
		bne	4$
		jsr	([$7f0])
		bra	PatchGpch650
4$
RLNotGpch	cmp.l	#'boot',d3
		bne	RLNotBoot
		cmp.w	#2,(a2)
		bne	1$
		jsr	([$7f0])
		bra	PatchBoot2
1$		cmp.w	#3,(a2)
		bne	2$
		jsr	([$7f0])
		bra	PatchBoot3
2$
RLNotBoot 	cmp.l	#'ltlk',d3
		bne	RLNotLtlk
		tst.w	(a2)
		bne	1$
		jsr	([$7f0])
		bra	PatchLtlk
1$		cmp.w	#2,(a2)
		bne	2$
		jsr	([$7f0])
		bra	PatchLtlk
2$
RLNotLtlk	cmp.l	#'scrn',d3
		bne	RLNotScrn
		tst.w	(a2)
		bne	1$
		jsr	([$7f0])
		bra	PatchScrn
1$
RLNotScrn	cmp.l	#'ccod',d3
		bne	RLNotCcod
		cmp.w	#23,(a2)
		bne	1$
		jsr	([$7f0])
		bra	PatchCcod
1$
RLNotCcod	cmp.l	#'ppci',d3
		bne	RLNotPpci
		cmp.w	#-16409,(a2)
		bne	1$
		move.l	#SCSIDispatch,$e54	;SCSIDispatch restaurieren
1$
RLNotPpci	cmp.l	#'inst',d3
		bne	RLNotInst
		cmp.w	#-19069,(a2)
		bne	1$
		jsr	([$7f0])
		bra	PatchInst
1$
RLNotInst	jsr	([$7f0])
	;	DPRINTF	" addr %08lx",(a0)
	;	tst.b	FixROMFor68040
	;	beq	1$
	;	movem.l	d0-d1/a0-a1/a6,-(sp)
	;	move.l	_ExecBase,a6
	;	JSRLIB	CacheClearU
	;	movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

;
; ptch 26: Trap ABC4 wird mit absoluter ROM-Adresse initialisiert
;
PatchPtch26	DPRINTF	"ptch 26 found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource

2$		cmp.l	#$40833610,(a0)	;Absolute ROM-Adresse ersetzen
		bne	3$
		move.l	ROMBase,d0
		add.l	#$33610,d0
		move.l	d0,(a0)
		bra	4$
3$
		addq.l	#2,a0
		subq.l	#2,d1
		bpl	2$
4$
		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

;
; ptch 420: VM abschalten
;
PatchPtch420	DPRINTF	"ptch 420 found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource

2$		cmp.l	#$a0305240,(a0)		;7.5
		bne	3$
		cmp.l	#$303c0100,4(a0)
		bne	3$
		cmp.l	#$c06efef6,8(a0)
		bne	3$
		move.l	#$4e714e71,2(a0)	;nop
		move.l	#$4e714e71,6(a0)
		move.l	#$4e714e71,10(a0)
		move.l	#$4e714e71,14(a0)
		move.l	#$4e714e71,18(a0)
		move.w	#$4e71,20(a0)
		bra	5$
3$
		cmp.l	#$a0305240,(a0)		;8.0
		bne	4$
		cmp.l	#$7000302e,4(a0)
		bne	4$
		cmp.l	#$fef6323c,8(a0)
		bne	4$
		cmp.w	#$0100,12(a0)
		bne	4$
		move.w	#$4e71,16(a0)		;nop
		move.w	#$4e71,30(a0)		;nop
		bra	5$
4$
		addq.l	#2,a0
		subq.l	#2,d1
		bpl	2$
5$
		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

;
; scod -16463/-16464: Patch für 68060-FPU und Forced Quit
;
PatchScod	DPRINTF	"scod found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource

2$		tst.b	Has68060
		beq	4$
		cmp.l	#$f3274a17,(a0)
		bne	3$
		move.w	#$4ef9,(a0)		;jmp Scod060Patch1
		move.l	#Scod060Patch1,2(a0)
		bra	5$
3$		cmp.l	#$f35f4e75,(a0)
		bne	4$
		move.w	#$4ef9,-2(a0)		;jmp Scod060Patch2
		move.l	#Scod060Patch2,(a0)
		bra	5$
4$
		cmp.l	#$203c0000,(a0)		;move.l	#$4e22,d0
		bne	5$
		cmp.l	#$4e22a9c9,4(a0)	;SysError
		bne	5$
		move.w	#$4eb9,(a0)		;jsr ForcedQuitPatch
		move.l	#ForcedQuitPatch,2(a0)
		move.w	#$4e71,6(a0)
5$
		addq.l	#2,a0
		subq.l	#2,d1
		bpl	2$

10$
		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

		MACHINE	68060

Scod060Patch1	fsave	-(sp)		;FPU-State speichern
		tst.b	2(sp)		;Idle?
		beq	1$
		fmovem.x fp0-fp7,-(sp)	;Nein, FPU-Register sichern
		fmove.l	fpiar,-(sp)
		fmove.l	fpsr,-(sp)
		fmove.l	fpcr,-(sp)
		pea	-1		;Busy Fake Longword
1$		move.l	d1,-(sp)
		move.l	d0,-(sp)
		bsr	3$		;Integer-Register wechseln
		addq.l	#8,sp
		tst.b	2(sp)		;Neuer FPU-State null?
		beq	2$
		addq.l	#4,sp		;Nein, Busy Fake Longword löschen
		fmove.l	(sp)+,fpcr	;FPU-Register wiederherstellen
		fmove.l	(sp)+,fpsr
		fmove.l	(sp)+,fpiar
		fmovem.x (sp)+,fp0-fp7
2$		frestore (sp)+
		movem.l	(sp)+,d0-d1
		rts

3$		move.l	4(sp),a0
		move	sr,-(sp)
		movem.l	d2-d7/a2-a6,-(sp)
		cmp.w	#0,a0
		beq	4$
		move.l	sp,(a0)
4$		move.l	$36(sp),a0
		movem.l	(a0)+,d2-d7/a2-a6
		move	(a0)+,sr
		move.l	a0,sp
		rts

Scod060Patch2	move.l	d0,-(sp)	;060FPU Null Frame erzeugen
		move.l	d0,-(sp)
		move.l	d0,-(sp)
		frestore (sp)+		;und laden
		rts

		MACHINE	68020

ForcedQuitPatch	movem.l	a0-a1,-(sp)
		lea	ForcedQuitDT,a0
		move.l	$d9c,a1
		jsr	(a1)		;JDTInstall
		movem.l	(sp)+,a0-a1
		rts

ForcedQuitTask	bclr	#6,$d92		;DTQueue Flag löschen (sonst werden danach keine Deferred Tasks mehr ausgeführt)
		move.l	#$4e22,d0
		dc.w	$a9c9		;SysError
		rts

ForcedQuitDT	dc.l	0
		dc.w	7,0
		dc.l	ForcedQuitTask
		dc.l	0,0

;
; gpch 669/lpch 63: Patch für 68060-FPU im Thread Manager
;

PatchThreads060	DPRINTF	"Threads 060 found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d2/a0-a2/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource
		move.l	a0,a2		;Original-Zeiger und Länge merken
		move.l	d1,d2

21$		cmp.l	#$226f0008,(a0)		;Erste Routine überspringen (non-FPU -> non-FPU)
		bne	22$
		cmp.l	#$202f0004,4(a0)
		bne	22$
		cmp.w	#$6718,8(a0)
		beq	23$
22$		addq.l	#2,a0
		subq.l	#2,d1
		bpl	21$
		bra	11$
23$
		addq.l	#2,a0
31$		cmp.l	#$226f0008,(a0)		;Zweite Routine patchen (non-FPU -> FPU)
		bne	32$
		cmp.l	#$202f0004,4(a0)
		bne	32$
		cmp.w	#$6718,8(a0)
		bne	32$
		move.w	#$4ef9,(a0)		;jmp ThNonFPUPatch
		move.l	#ThNonFPUPatch,2(a0)
		bra	33$
32$		addq.l	#2,a0
		subq.l	#2,d1
		bpl	31$
		bra	11$
33$
		move.l	a2,a0
		move.l	d2,d1
41$		cmp.l	#$226f0008,(a0)		;Dritte Routine patchen (FPU -> FPU)
		bne	42$
		cmp.l	#$202f0004,4(a0)
		bne	42$
		cmp.w	#$6728,8(a0)
		bne	42$
		move.w	#$4ef9,(a0)		;jmp ThFPUFPUPatch
		move.l	#ThFPUFPUPatch,2(a0)
		bra	51$
42$		addq.l	#2,a0
		subq.l	#2,d1
		bpl	41$
		bra	11$

51$		cmp.l	#$226f0008,(a0)		;Vierte Routine patchen (FPU -> non-FPU)
		bne	52$
		cmp.l	#$202f0004,4(a0)
		bne	52$
		cmp.w	#$6728,8(a0)
		bne	52$
		move.w	#$4ef9,(a0)		;jmp ThFPUNonPatch
		move.l	#ThFPUNonPatch,2(a0)
		bra	53$
52$		addq.l	#2,a0
		subq.l	#2,d1
		bpl	51$
		bra	11$
53$
		move.l	a2,a0
		move.l	d2,d1
61$		cmp.l	#$226f0008,(a0)		;Erste Routine überspringen (8.x non-FPU -> non-FPU)
		bne	62$
		cmp.l	#$202f0004,4(a0)
		bne	62$
		cmp.w	#$6740,8(a0)
		beq	63$
62$		addq.l	#2,a0
		subq.l	#2,d1
		bpl	61$
		bra	11$
63$
		addq.l	#2,a0
71$		cmp.l	#$226f0008,(a0)		;Zweite Routine patchen (8.0 non-FPU -> FPU)
		bne	72$
		cmp.l	#$202f0004,4(a0)
		bne	72$
		cmp.w	#$6740,8(a0)
		bne	72$
		move.w	#$4ef9,(a0)		;jmp ThNonFPUPatch2
		move.l	#ThNonFPUPatch2,2(a0)
		bra	73$
72$		addq.l	#2,a0
		subq.l	#2,d1
		bpl	71$
		bra	11$
73$
		move.l	a2,a0
		move.l	d2,d1
81$		cmp.l	#$226f0008,(a0)		;Dritte Routine patchen (8.x FPU -> FPU)
		bne	82$
		cmp.l	#$202f0004,4(a0)
		bne	82$
		cmp.w	#$6750,8(a0)
		bne	82$
		move.w	#$4ef9,(a0)		;jmp ThFPUFPUPatch2
		move.l	#ThFPUFPUPatch2,2(a0)
		bra	91$
82$		addq.l	#2,a0
		subq.l	#2,d1
		bpl	81$
		bra	11$

91$		cmp.l	#$226f0008,(a0)		;Vierte Routine patchen (8.x FPU -> non-FPU)
		bne	92$
		cmp.l	#$202f0004,4(a0)
		bne	92$
		cmp.w	#$6750,8(a0)
		bne	92$
		move.w	#$4ef9,(a0)		;jmp ThFPUNonPatch2
		move.l	#ThFPUNonPatch2,2(a0)
		bra	93$
92$		addq.l	#2,a0
		subq.l	#2,d1
		bpl	91$
		bra	11$
93$
		move.l	a2,a0
		move.l	d2,d1
101$		cmp.l	#$4a2800a4,(a0)
		bne	102$
		cmp.l	#$670a4a2c,4(a0)
		bne	102$
		cmp.w	#$0040,8(a0)
		bne	102$
		move.w	#$4eb9,6(a0)		;jsr ThInitFPUPatch
		move.l	#ThInitFPUPatch,8(a0)
		move.l	#$4e714e71,12(a0)	;nop nop
		bra	11$
102$		addq.l	#2,a0
		subq.l	#2,d1
		bpl	101$

11$		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d2/a0-a2/a6
1$		rts

		MACHINE	68060

ThFPUFPUPatch	move.l	8(sp),a1
		move.l	4(sp),d0
		beq	1$
		fsave	-(sp)
		tst.b	2(sp)		;FPU null?
		beq	2$
		fmovem.x fp0-fp7,-(sp)
		fmove.l	fpiar,-(sp)
		fmove.l	fpsr,-(sp)
		fmove.l	fpcr,-(sp)
		pea	-1		;Busy Fake Longword
2$		move	sr,-(sp)
		subq.l	#2,sp
		movem.l	d2-d7/a2-a6,-(sp)
		move.l	$130,-(sp)
		move.l	$bae,-(sp)
		move.l	$114,-(sp)
		move.l	d0,a0
		move.l	sp,(a0)
1$		move.l	(a1)+,$114
		move.l	(a1)+,$bae
		move.l	(a1)+,$130
		movem.l	(a1)+,d2-d7/a2-a6
		addq.l	#2,a1
		move	(a1)+,sr
		move.l	a1,sp
		tst.b	2(sp)		;Neuer FPU-State null?
		beq	3$
		addq.l	#4,sp
		fmove.l	(sp)+,fpcr
		fmove.l	(sp)+,fpsr
		fmove.l	(sp)+,fpiar
		fmovem.x (sp)+,fp0-fp7
3$		frestore (sp)+
		rts

ThFPUNonPatch	move.l	8(sp),a1
		move.l	4(sp),d0
		beq	1$
		fsave	-(sp)
		tst.b	2(sp)		;FPU null?
		beq	2$
		fmovem.x fp0-fp7,-(sp)
		fmove.l	fpiar,-(sp)
		fmove.l	fpsr,-(sp)
		fmove.l	fpcr,-(sp)
		pea	-1		;Busy Fake Longword
2$		move	sr,-(sp)
		subq.l	#2,sp
		movem.l	d2-d7/a2-a6,-(sp)
		move.l	$130,-(sp)
		move.l	$bae,-(sp)
		move.l	$114,-(sp)
		move.l	d0,a0
		move.l	sp,(a0)
1$		move.l	(a1)+,$114
		move.l	(a1)+,$bae
		move.l	(a1)+,$130
		movem.l	(a1)+,d2-d7/a2-a6
		addq.l	#2,a1
		move	(a1)+,sr
		move.l	a1,sp
		rts

ThNonFPUPatch	move.l	8(sp),a1
		move.l	4(sp),d0
		beq	1$
		move	sr,-(sp)
		subq.l	#2,sp
		movem.l	d2-d7/a2-a6,-(sp)
		move.l	$130,-(sp)
		move.l	$bae,-(sp)
		move.l	$114,-(sp)
		move.l	d0,a0
		move.l	sp,(a0)
1$		move.l	(a1)+,$114
		move.l	(a1)+,$bae
		move.l	(a1)+,$130
		movem.l	(a1)+,d2-d7/a2-a6
		addq.l	#2,a1
		move	(a1)+,sr
		move.l	a1,sp
		tst.b	2(sp)		;Neuer FPU-State null?
		beq	3$
		addq.l	#4,sp
		fmove.l	(sp)+,fpcr
		fmove.l	(sp)+,fpsr
		fmove.l	(sp)+,fpiar
		fmovem.x (sp)+,fp0-fp7
3$		frestore (sp)+
		rts

ThFPUFPUPatch2	move.l	8(sp),a1
		move.l	4(sp),d0
		beq	1$

		clr.l	-(sp)		;Save Mixed Mode Manager context
		clr.l	-(sp)
		clr.l	-(sp)
		clr.l	-(sp)
		movem.l	d0-d2/a0-a1,-(sp)
		clr.w	-(sp)
		move.l	sp,d1
		add.l	#$16,d1
		move.l	d1,-(sp)
		move.l	#1,-(sp)
		moveq	#3,d0
		dc.w	$aa59
		addq.w	#2,sp
		movem.l	(sp)+,d0-d2/a0-a1

		fsave	-(sp)
		tst.b	2(sp)		;FPU null?
		beq	2$
		fmovem.x fp0-fp7,-(sp)
		fmove.l	fpiar,-(sp)
		fmove.l	fpsr,-(sp)
		fmove.l	fpcr,-(sp)
		pea	-1		;Busy Fake Longword
2$		move	sr,-(sp)
		subq.l	#2,sp
		movem.l	d2-d7/a2-a6,-(sp)
		move.l	$130,-(sp)
		move.l	$bae,-(sp)
		move.l	$114,-(sp)
		move.l	d0,a0
		move.l	sp,(a0)
1$		move.l	(a1)+,$114
		move.l	(a1)+,$bae
		move.l	(a1)+,$130
		movem.l	(a1)+,d2-d7/a2-a6
		addq.l	#2,a1
		move	(a1)+,sr
		move.l	a1,sp
		tst.b	2(sp)		;Neuer FPU-State null?
		beq	3$
		addq.l	#4,sp
		fmove.l	(sp)+,fpcr
		fmove.l	(sp)+,fpsr
		fmove.l	(sp)+,fpiar
		fmovem.x (sp)+,fp0-fp7
3$		frestore (sp)+

		movem.l	d0-d2/a0-a1,-(sp) ;Restore Mixed Mode Manager context
		clr.w	-(sp)
		move.l	sp,d0
		add.l	#$16,d0
		move.l	d0,-(sp)
		move.l	#1,-(sp)
		moveq	#4,d0
		dc.w	$aa59
		addq.w	#2,sp
		movem.l	(sp)+,d0-d2/a0-a1
		lea	16(sp),sp
		rts

ThFPUNonPatch2	move.l	8(sp),a1
		move.l	4(sp),d0
		beq	1$

		clr.l	-(sp)		;Save Mixed Mode Manager context
		clr.l	-(sp)
		clr.l	-(sp)
		clr.l	-(sp)
		movem.l	d0-d2/a0-a1,-(sp)
		clr.w	-(sp)
		move.l	sp,d1
		add.l	#$16,d1
		move.l	d1,-(sp)
		move.l	#1,-(sp)
		moveq	#3,d0
		dc.w	$aa59
		addq.w	#2,sp
		movem.l	(sp)+,d0-d2/a0-a1

		fsave	-(sp)
		tst.b	2(sp)		;FPU null?
		beq	2$
		fmovem.x fp0-fp7,-(sp)
		fmove.l	fpiar,-(sp)
		fmove.l	fpsr,-(sp)
		fmove.l	fpcr,-(sp)
		pea	-1		;Busy Fake Longword
2$		move	sr,-(sp)
		subq.l	#2,sp
		movem.l	d2-d7/a2-a6,-(sp)
		move.l	$130,-(sp)
		move.l	$bae,-(sp)
		move.l	$114,-(sp)
		move.l	d0,a0
		move.l	sp,(a0)
1$		move.l	(a1)+,$114
		move.l	(a1)+,$bae
		move.l	(a1)+,$130
		movem.l	(a1)+,d2-d7/a2-a6
		addq.l	#2,a1
		move	(a1)+,sr
		move.l	a1,sp

		movem.l	d0-d2/a0-a1,-(sp) ;Restore Mixed Mode Manager context
		clr.w	-(sp)
		move.l	sp,d0
		add.l	#$16,d0
		move.l	d0,-(sp)
		move.l	#1,-(sp)
		moveq	#4,d0
		dc.w	$aa59
		addq.w	#2,sp
		movem.l	(sp)+,d0-d2/a0-a1
		lea	16(sp),sp
		rts

ThNonFPUPatch2	move.l	8(sp),a1
		move.l	4(sp),d0
		beq	1$

		clr.l	-(sp)		;Save Mixed Mode Manager context
		clr.l	-(sp)
		clr.l	-(sp)
		clr.l	-(sp)
		movem.l	d0-d2/a0-a1,-(sp)
		clr.w	-(sp)
		move.l	sp,d1
		add.l	#$16,d1
		move.l	d1,-(sp)
		move.l	#1,-(sp)
		moveq	#3,d0
		dc.w	$aa59
		addq.w	#2,sp
		movem.l	(sp)+,d0-d2/a0-a1

		move	sr,-(sp)
		subq.l	#2,sp
		movem.l	d2-d7/a2-a6,-(sp)
		move.l	$130,-(sp)
		move.l	$bae,-(sp)
		move.l	$114,-(sp)
		move.l	d0,a0
		move.l	sp,(a0)
1$		move.l	(a1)+,$114
		move.l	(a1)+,$bae
		move.l	(a1)+,$130
		movem.l	(a1)+,d2-d7/a2-a6
		addq.l	#2,a1
		move	(a1)+,sr
		move.l	a1,sp
		tst.b	2(sp)		;Neuer FPU-State null?
		beq	3$
		addq.l	#4,sp
		fmove.l	(sp)+,fpcr
		fmove.l	(sp)+,fpsr
		fmove.l	(sp)+,fpiar
		fmovem.x (sp)+,fp0-fp7
3$		frestore (sp)+

		movem.l	d0-d2/a0-a1,-(sp) ;Restore Mixed Mode Manager context
		clr.w	-(sp)
		move.l	sp,d0
		add.l	#$16,d0
		move.l	d0,-(sp)
		move.l	#1,-(sp)
		moveq	#4,d0
		dc.w	$aa59
		addq.w	#2,sp
		movem.l	(sp)+,d0-d2/a0-a1
		lea	16(sp),sp
		rts

ThInitFPUPatch	tst.b	$40(a4)
		bne	1$
		moveq	#0,d0
		move.l	d0,-(a3)
		move.l	d0,-(a3)
		move.l	d0,-(a3)
1$		rts

		MACHINE	68020

;
; lpch 24: Time Manager nicht überschreiben
;
PatchLpch24	DPRINTF	"lpch 24 found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource

2$		cmp.l	#$7059a247,(a0)
		bne	3$
		move.w	#$4e71,2(a0)		;nop
		move.w	#$4e71,10(a0)		;nop
		move.w	#$4e71,26(a0)		;nop
		bra	4$
3$
		addq.l	#2,a0
		subq.l	#2,d1
		bpl	2$
4$
		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

;
; lpch 31: WaitIO
;
PatchLpch31	DPRINTF	"lpch 31 found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource

2$		cmp.l	#$30280010,(a0)
		bne	3$
		cmp.w	#$6efa,4(a0)
		bne	3$
		move.w	#$4eb9,(a0)		;jsr MacWaitIO
		move.l	#MacWaitIO,2(a0)
		bra	4$
3$
		cmp.l	#$206e0008,(a0)
		bne	4$
		cmp.l	#$7001b068,4(a0)
		bne	4$
		cmp.l	#$001067f4,8(a0)
		bne	4$
		move.w	#$4eb9,4(a0)		;jsr MacWaitIO
		move.l	#MacWaitIO,6(a0)
		move.w	#$4e71,10(a0)		;nop
4$
		addq.l	#2,a0
		subq.l	#2,d1
		bpl	2$

		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

;
; gpch 750: BlockMove PTEST
;
PatchGpch750	DPRINTF	"gpch 750 found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource

2$		cmp.l	#$a08d0c81,(a0)
		bne	3$
		cmp.l	#$00000c00,4(a0)
		bne	3$
		cmp.l	#$65064e71,8(a0)
		bne	3$
		cmp.w	#$f4f8,12(a0)
		bne	3$
		move.w	#$4e71,8(a0)	;nop
		bra	4$
3$
		addq.l	#2,a0
		subq.l	#2,d1
		bpl	2$
4$
		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

;
; gpch 16: Korrigiert Fehler in System 7.5.1 KeyTrans()
;
PatchGpch16	DPRINTF	"gpch 16 found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource

2$		cmp.l	#$30010240,(a0)
		bne	3$
		cmp.l	#$fb004a40,4(a0)
		bne	3$
		move.w	#$4eb9,(a0)	;jsr Gpch16Patch
		move.l	#Gpch16Patch,2(a0)
		bra	4$
3$
		addq.l	#2,a0
		subq.l	#2,d1
		bpl	2$
4$
		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

Gpch16Patch	move.w	d1,d0
		and.w	#$ff7f,d1
		and.w	#$fb00,d0
		rts

;
; gpch 650: Kein Zugriff auf SonyVars
;
PatchGpch650	DPRINTF	"gpch 650 found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource

2$		cmp.l	#$6600001a,(a0)		;7.5.2
		bne	3$
		cmp.l	#$22780134,4(a0)
		bne	3$
		move.w	#$6000,(a0)		;bra
		bra	7$
3$
		cmp.l	#$66182278,(a0)		;7.5.3
		bne	4$
		cmp.w	#$0134,4(a0)
		bne	4$
		move.w	#$4e71,-12(a0)		;nop
		move.w	#$4e71,-6(a0)
		move.w	#$6018,(a0)		;bra
		bra	7$
4$
		cmp.l	#$666e2278,(a0)		;7.5.5
		bne	5$
		cmp.w	#$0134,4(a0)
		bne	5$
		move.w	#$4e71,-12(a0)		;nop
		move.w	#$4e71,-6(a0)
		move.w	#$606e,(a0)		;bra
		bra	7$
5$
		cmp.l	#$640000e6,(a0)		;7.6
		bne	6$
		cmp.l	#$22780134,4(a0)
		bne	6$
		move.w	#$6000,(a0)		;bra
		bra	7$
6$
		cmp.l	#$6400011c,(a0)		;8.0
		bne	7$
		cmp.l	#$22780134,4(a0)
		bne	7$
		move.w	#$6000,(a0)		;bra
7$
		addq.l	#2,a0
		subq.l	#2,d1
		bpl	2$

		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

;
; PTCH $067c: Diverses
;
PatchPTCH	DPRINTF	"PTCH $067c found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource

2$		cmp.l	#$4e7a8801,(a0)
		bne	3$
		cmp.l	#$21490070,4(a0)
		bne	3$
		move.l	#$4e714e71,(a0)		;Interrupt 4 nicht überschreiben
		move.l	#$4e714e71,4(a0)
3$		cmp.l	#$7015a647,(a0)
		bne	4$
		move.l	#$4e714e71,(a0)		;SCSI-Manager auch nicht
4$		cmp.l	#$40886d1e,(a0)
		bne	5$
		move.l	ROMBase,d0
		add.l	#$86d1e,d0
		move.l	d0,(a0)
5$		cmp.l	#$4a380cb2,(a0)		;SANE-Patches mit ROM $15
		bne	6$
		cmp.l	#$670e0c97,4(a0)
		bne	6$
		cmp.l	#$40800000,8(a0)
		bne	6$
		move.w	#$0c97,(a0)		;cmp.l #ROMBase,(a7)
		move.l	ROMBase,2(a0)
		move.w	#$640c,6(a0)		;bcc.s 1$
		move.l	#$4e714e71,8(a0)
		move.w	#$4e71,12(a0)
		move.w	#$0c97,20(a0)		;1$ cmp.l #ROMBase+ROMSize,(a7)
		move.l	ROMBase,d0
		add.l	ROMSize,d0
		move.l	d0,22(a0)
		move.w	#$64f2,26(a0)		;bcc.s 2$
		move.l	#$4e714e71,28(a0)
		move.l	#$4e714e71,32(a0)
		move.l	#$4e714e71,36(a0)
		move.w	#$4e71,40(a0)
6$		cmp.l	#$408ec1e4,(a0)
		bne	7$
		move.l	ROMBase,d0
		add.l	#$ec1e4,d0
		move.l	d0,(a0)
7$		cmp.l	#$408eb50c,(a0)
		bne	8$
		move.l	ROMBase,d0
		add.l	#$eb50c,d0
		move.l	d0,(a0)
8$		cmp.l	#$408eb1fc,(a0)
		bne	9$
		move.l	ROMBase,d0
		add.l	#$eb1fc,d0
		move.l	d0,(a0)
9$		cmp.l	#$408edce6,(a0)
		bne	10$
		move.l	ROMBase,d0
		add.l	#$edce6,d0
		move.l	d0,(a0)
10$
		addq.l	#2,a0
		subq.l	#2,d1
		bpl	2$

		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

;
; snth 1: Komplett ersetzen
;
PatchSnth1	DPRINTF	"snth 1 found"
		tst.w	GotChannel01
		beq	1$
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	(a0),a0
		move.w	#$4ef9,(a0)+		;jmp	SquareWaveProc
		move.l	#SquareWaveProc,(a0)

		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

;
; snth 5: EASC-Emulation
;
PatchSnth5	DPRINTF	"snth 5 found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource

2$		cmp.l	#$e28c5384,(a0)
		bne	3$
		cmp.l	#$129b135b,4(a0)
		bne	3$
		move.w	#$4eb9,(a0)		;jsr	Snth5Patch1
		move.l	#Snth5Patch1,2(a0)
		move.l	#$4e71600c,6(a0)	;nop bra
		move.w	#$4eb9,10(a0)		;jsr	Snth5Patch1a
		move.l	#Snth5Patch1a,12(a0)
		move.l	#$4e714e71,16(a0)	;nop nop
		move.w	#$4e71,20(a0)		;nop
		bra	7$
3$		cmp.l	#$13470400,(a0)
		bne	4$
		cmp.l	#$48471287,4(a0)
		bne	4$
		move.w	#$4eb9,(a0)		;jsr	Snth5Patch2
		move.l	#Snth5Patch2,2(a0)
		move.w	#$4e71,6(a0)		;nop
		bra	7$
4$		cmp.l	#$12b07000,(a0)
		bne	5$
		cmp.l	#$48471370,4(a0)
		bne	5$
		cmp.l	#$70000400,8(a0)
		bne	5$
		move.w	#$4eb9,(a0)		;jsr	Snth5Patch3
		move.l	#Snth5Patch3,2(a0)
		move.l	#$4e714e71,6(a0)	;nop nop
		move.w	#$4e71,10(a0)		;nop
		bra	7$
5$		cmp.l	#$12874847,(a0)
		bne	6$
		cmp.l	#$13470400,4(a0)
		bne	6$
		move.w	#$4eb9,(a0)		;jsr	Snth5Patch4
		move.l	#Snth5Patch4,2(a0)
		move.w	#$4e71,6(a0)		;nop
		bra	7$
6$		cmp.l	#$14b03000,(a0)
		bne	7$
		cmp.l	#$48431570,4(a0)
		bne	7$
		cmp.l	#$30000400,8(a0)
		bne	7$
		move.w	#$4eb9,(a0)		;jsr	Snth5Patch5
		move.l	#Snth5Patch5,2(a0)
		move.l	#$4e714e71,6(a0)	;nop nop
		move.w	#$4e71,10(a0)		;nop
7$
		addq.l	#2,a0
		subq.l	#2,d1
		bpl	2$

		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

;
; sift -16563: EASC-Emulation für Sound Manager 3.0
;
PatchSift	DPRINTF	"sift found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource

2$		cmp.l	#$00ae01ac,(a0)		;Sprungtabelle suchen
		bne	3$
		cmp.l	#$0020005c,4(a0)
		bne	3$
		cmp.l	#$02c80342,8(a0)
		bne	3$
		cmp.l	#$0232027a,12(a0)
		bne	3$
		cmp.l	#$02d2034c,16(a0)
		bne	3$
		cmp.l	#$023c0284,20(a0)
		bne	3$
		cmp.l	#$00ae01ac,24(a0)
		bne	3$
		cmp.l	#$0020005c,28(a0)
		bne	3$

		move.w	#$4ef9,d0		;jmp
		move.w	d0,$20(a0)
		move.w	d0,$5c(a0)
		move.w	d0,$ae(a0)
		move.w	d0,$1ac(a0)
		move.w	d0,$24a(a0)
		move.w	d0,$292(a0)
		move.w	d0,$2e0(a0)
		move.w	d0,$35a(a0)

		move.l	#SiftPatch1,d0		;Mono->Stereo
		move.l	d0,$22(a0)
		move.l	d0,$b0(a0)

		move.l	#SiftPatch2,d0		;Stereo->Stereo
		move.l	d0,$5e(a0)
		move.l	d0,$1ae(a0)

		move.l	#SiftPatch3,d0		;Mono->Mono
		move.l	d0,$24c(a0)
		move.l	d0,$2e2(a0)

		move.l	#SiftPatch4,d0		;Stereo->Mono
		move.l	d0,$294(a0)
		move.l	d0,$35c(a0)
		bra	4$
3$
		addq.l	#2,a0
		subq.l	#2,d1
		bpl	2$
4$
		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

;
; boot 2: NULL-Handle auf sicheren Speicherbereich setzen (7.5, 8.0)
;
PatchBoot2	DPRINTF	"boot 2 found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource

2$		cmp.l	#$207802ae,(a0)
		bne	3$
		cmp.l	#$d1fc0001,4(a0)
		bne	3$
		cmp.l	#$000021c8,8(a0)
		bne	3$
		cmp.w	#$0000,12(a0)
		bne	3$
		move.w	#$207c,(a0)		;move.l	#ChipFakeBase,a0
		move.l	ChipFakeBase,2(a0)
		move.l	#$4e714e71,6(a0)	;nop nop
		bra	4$
3$
		addq.l	#2,a0
		subq.l	#2,d1
		bpl	2$
4$
		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

;
; boot 3: Boot-Stackpointer setzen (7.5, 8.0)
;
PatchBoot3	DPRINTF	"boot 3 found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource

2$		cmp.l	#$2200e489,(a0)
		bne	3$
		cmp.l	#$90812240,4(a0)
		bne	3$
		move.w	#$4eb9,2(a0)		;jsr Boot3Patch
		move.l	#Boot3Patch,4(a0)
		bra	4$
3$
		cmp.l	#$207802ae,(a0)		;NULL zeigt auf sicheren Speicherbereich
		bne	4$
		cmp.l	#$d1fc0001,4(a0)
		bne	4$
		cmp.l	#$000021c8,8(a0)
		bne	4$
		cmp.w	#$0000,12(a0)
		bne	4$
		move.w	#$207c,(a0)		;move.l	#ChipFakeBase,a0
		move.l	ChipFakeBase,2(a0)
		move.l	#$4e714e71,6(a0)	;nop nop
4$
		addq.l	#2,a0
		subq.l	#2,d1
		bpl	2$

		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

Boot3Patch	move.l	MemSize,d0
		move.l	d0,d1
		lsr.l	#2,d1
		sub.l	d1,d0
		add.l	MemBase,d0
		move.l	d0,a1
		rts

;
; ltlk 0/2: LocalTalk-Speedtest und -Hänger
;
PatchLtlk	DPRINTF	"ltlk 0/2 found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource

2$		tst.b	HasRealSCC
		bne	5$
		cmp.l	#$4a2a060a,(a0)		;Ohne SCC
		bne	3$
		cmp.w	#$66fa,4(a0)
		bne	3$
		move.w	#$4e71,4(a0)		;nop
3$		cmp.l	#$4a2a063e,(a0)
		bne	4$
		cmp.w	#$66fa,4(a0)
		bne	4$
		move.w	#$4e71,4(a0)		;nop
4$
		cmp.l	#$357c2300,(a0)
		bne	5$
		move.w	#$2600,2(a0)
5$
		cmp.l	#$30380d00,(a0)
		bne	6$
		cmp.l	#$4e75a059,4(a0)
		bne	6$
		move.w	#$4ef9,12(a0)		;jmp LtlkPatch1
		move.l	#LtlkPatch1,14(a0)
6$		cmp.l	#$30380d02,(a0)
		bne	7$
		cmp.l	#$4e75a059,4(a0)
		bne	7$
		move.w	#$4ef9,12(a0)		;jmp LtlkPatch2
		move.l	#LtlkPatch2,14(a0)
7$
		addq.l	#2,a0
		subq.l	#2,d1
		bpl	2$

		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

LtlkPatch1	movem.l	d4-d7/a6,-(sp)
		move.l	_ExecBase,a6

		move.l	#$ffff,d5
		moveq	#9,d4

10$		JSRLIB	Disable
		move.l	_TimerBase,a6
		lea	LtlkStartTime,a0
		JSRLIB	GetSysTime
		lea	LtlkEndTime,a0
		JSRLIB	GetSysTime
		lea	LtlkStartTime,a1
		JSRLIB	SubTime
		move.l	_ExecBase,a6
		JSRLIB	Enable
		move.l	LtlkEndTime+TV_MICRO,d7	;d7: Overhead

		JSRLIB	Disable
		move.l	_TimerBase,a6
		lea	LtlkStartTime,a0
		JSRLIB	GetSysTime
		move.l	a0,a0
		move.w	$d00,d0			;Dies sollten 4ms sein
1$		dbra	d0,1$
		move.w	$d00,d0
2$		dbra	d0,2$
		move.w	$d00,d0
3$		dbra	d0,3$
		move.w	$d00,d0
4$		dbra	d0,4$
		lea	LtlkEndTime,a0
		JSRLIB	GetSysTime
		lea	LtlkStartTime,a1
		JSRLIB	SubTime
		move.l	_ExecBase,a6
		JSRLIB	Enable
		move.l	LtlkEndTime+TV_MICRO,d6
		sub.l	d7,d6			;Overhead abziehen
		cmp.l	d6,d5
		bcs	5$
		move.l	d6,d5			;d5: Minimale Zeit
5$		dbra	d4,10$

		move.w	$d00,d1
		mulu.w	#4000,d1
		divu.w	d5,d1
		move.w	d1,d0

		movem.l	(sp)+,d4-d7/a6
		rts

LtlkPatch2	movem.l	d4-d7/a6,-(sp)
		move.l	_ExecBase,a6

		move.l	#$ffff,d5
		moveq	#9,d4

10$		JSRLIB	Disable
		move.l	_TimerBase,a6
		lea	LtlkStartTime,a0
		JSRLIB	GetSysTime
		lea	LtlkEndTime,a0
		JSRLIB	GetSysTime
		lea	LtlkStartTime,a1
		JSRLIB	SubTime
		move.l	_ExecBase,a6
		JSRLIB	Enable
		move.l	LtlkEndTime+TV_MICRO,d7	;d7: Overhead

		JSRLIB	Disable
		move.l	_TimerBase,a6
		lea	LtlkStartTime,a0
		JSRLIB	GetSysTime
		move.l	SCCBase,a1
		move.l	a0,a0
		move.w	$d02,d0			;Dies sollten 4ms sein
1$		btst	#0,(a1)
		dbra	d0,1$
		move.w	$d02,d0
2$		btst	#0,(a1)
		dbra	d0,2$
		move.w	$d02,d0
3$		btst	#0,(a1)
		dbra	d0,3$
		move.w	$d02,d0
4$		btst	#0,(a1)
		dbra	d0,4$
		lea	LtlkEndTime,a0
		JSRLIB	GetSysTime
		lea	LtlkStartTime,a1
		JSRLIB	SubTime
		move.l	_ExecBase,a6
		JSRLIB	Enable
		move.l	LtlkEndTime+TV_MICRO,d6
		sub.l	d7,d6			;Overhead abziehen
		cmp.l	d6,d5
		bcs	5$
		move.l	d6,d5			;d5: Minimale Zeit
5$		dbra	d4,10$

		move.w	$d02,d1
		mulu.w	#4000,d1
		divu.w	d5,d1
		move.w	d1,d0

		movem.l	(sp)+,d4-d7/a6
		rts

;
; scrn 0: Basisadresse des Bildschirmspeichers
;
PatchScrn	DPRINTF	"scrn 0 found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource

		cmp.w	#10,d1
		blo	2$
		move.l	ScrnBase1,6(a0)

2$		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

;
; ccod 23: Fehler in "AppleScript"-Systemerweiterung
;
PatchCcod	DPRINTF	"ccod 23 found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource

2$		cmp.l	#$bcaeffd8,(a0)
		bne	3$
		cmp.l	#$66c84a47,4(a0)
		bne	3$
		cmp.l	#$670e422b,8(a0)
		bne	3$
		cmp.l	#$00067000,12(a0)
		bne	3$
		move.w	#$4eb9,10(a0)
		move.l	#Ccod23Patch,12(a0)
		bra	4$
3$
		addq.l	#2,a0
		subq.l	#2,d1
		bpl	2$

4$		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

Ccod23Patch	tst.l	a3
		beq	1$
		clr.b	6(a3)
1$		moveq	#0,d0
		rts

;
; inst -19069: Microseconds nicht überschreiben (QuickTime 2.0)
;
PatchInst	DPRINTF	"inst-19069 found"
		move.l	a0,d0
		beq	1$
		move.l	(a0),d0
		beq	1$

		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	a0,-(sp)
		dc.w	$a025		;GetHandleSize
		move.l	d0,d1		;d1: Größe
		move.l	(sp)+,a0
		move.l	(a0),a0		;a0: Zeiger auf Resource

2$		cmp.l	#$303ca193,(a0)
		bne	3$
		cmp.w	#$a247,4(a0)
		bne	3$
		move.w	#$4e71,4(a0)		;nop
		bra	4$
3$
		addq.l	#2,a0
		subq.l	#2,d1
		bpl	2$

4$		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
		movem.l	(sp)+,d0-d1/a0-a1/a6
1$		rts

**
** Konstanten
**

; Strings
ReqTitle	dc.b	"DebugStr called",0
ReqGads		dc.b	"Continue",0
DebugStrTxt	dc.b	"%s",0


**
** Initialisierte Daten
**

		SECTION	"DATA",DATA

; Requester
DebugStrReq	dc.l	20,0,ReqTitle,DebugStrTxt,ReqGads
DebugStrArgs	dc.l	DebugStrBuf

; ADB-Register für Maus und Tastatur
KeyReg3		dc.w	$0205	;Extended ISO, Adr 2
MouseReg3	dc.w	$0301	;Mouse, Adr 3


**
** Nicht initialisierte Daten
**

		SECTION	"BSS",BSS

DebugStrBuf	ds.b	256		;Für DebugStr BSTR->CSTR-Konvertierung

; MemInfo
		ds.l	7
MMUTbl2		ds.l	5		;FFBE MMUTbl 2
					;FFC2 SRP
					;FFC6 TC
					;FFCA TT0
					;FFCE TT1
MMUTbl1		ds.l	5		;FFD2 MMUTbl 1
MMUType		ds.b	1		;FFE6 MMUType (0: Keine, 1: AMU, 3: 68581, 4: 68030, 5: 68040)
		ds.b	1		;FFE7 MMU vorhanden? (1=Nein)
		ds.l	1		;FFE8 Differenz zwischen MemTop und MemSize
		ds.l	1		;FFEC MemTop (Größe des installierten Speichers)
		ds.l	1		;FFF0
		ds.l	1		;FFF4 BufPtr-Offset
		ds.l	1		;FFF8 Größe der nachfolgenden Struktur
		ds.l	1		;FFFC "WLSC"
MemInfo		ds.l	1		;0000 MemBase
		ds.l	1		;0004 MemSize
		ds.l	3

; Variablen
		CNOP	0,4
ROMLimits	ds.l	2	;Grenzen des ROMs (zum Vergleichen)

TheMachDef	ds.l	1	;Zeiger auf MachDef im ROM

OldInitUtil	ds.l	1	;Alte Mac-Traps
OldHWPriv	ds.l	1
OldPutScrap	ds.l	1
OldDisposHandle	ds.l	1
OldSetCursor	ds.l	1

SysTime		ds.l	1	;"Echtzeituhr"
SysMics		ds.l	1
StartupTime	ds.l	1
TimeValBuf	ds.b	TV_SIZE	;Für GetSysTime
LtlkStartTime	ds.b	TV_SIZE	;Für LocalTalk-Timing
LtlkEndTime	ds.b	TV_SIZE
TMPOOLSIZE	= 128
TMFree		ds.l	1	;free TMTask records (linked through the first long)
TMPool		ds.b	SIZEOF_TMTask*TMPOOLSIZE
TMPoolEnd
TMTaskList	ds.b	MLH_SIZE ;Liste der Time-Manager-Tasks

TimeMgrInited	ds.b	1	;#0: Time Manager wurde initialisiert
		ds.b	1

		EVEN
DbgPolls	ds.w	1	;Zaehler fuer DebuggerPoll

		END
