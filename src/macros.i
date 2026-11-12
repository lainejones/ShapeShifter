**
** Macintosh IIci-Emulator - Makros und Definitionen
** =================================================
**
** Copyright 1993-2001 Christian Bauer
**

		MACHINE	68020

; Globale Variablen
		PUBLIC	_ExecBase
		PUBLIC	_DOSBase
		PUBLIC	_GfxBase
		PUBLIC	_IntuitionBase
		PUBLIC	_GadToolsBase
		PUBLIC	_AslBase
		PUBLIC	_IFFParseBase
		PUBLIC	_IconBase
		PUBLIC	_UtilityBase
		PUBLIC	_ExpansionBase
		PUBLIC	_SocketBase
		PUBLIC	_EGSBase
		PUBLIC	_CyberGfxBase
		PUBLIC	_P96Base
		PUBLIC	_TimerBase
		PUBLIC	_DiskBase
		PUBLIC	_CiaBase
		PUBLIC	_MiscBase
		PUBLIC	_FDCBase
		PUBLIC	_AHIBase
		PUBLIC	MyTask
		PUBLIC	MacRunning
		PUBLIC	NoSuperSwitch

; Preferences
		PUBLIC	LargestBlock
		PUBLIC	MouseDirect
		PUBLIC	VideoMode1
		PUBLIC	RefreshRate
		PUBLIC	BlackBorder
		PUBLIC	FastROM
		PUBLIC	DisplayID1
		PUBLIC	ScreenX1
		PUBLIC	ScreenY1
		PUBLIC	MemSize
		PUBLIC	AFDFileName1
		PUBLIC	AFDFileName2
		PUBLIC	AFDFileName3
		PUBLIC	AFDFileName4
		PUBLIC	ADDName1
		PUBLIC	ADDName2
		PUBLIC	ADDUnit1
		PUBLIC	ADDUnit2
		PUBLIC	ADDStartSector1
		PUBLIC	ADDStartSector2
		PUBLIC	ADDSectors1
		PUBLIC	ADDSectors2
		PUBLIC	SERDNameA
		PUBLIC	SERDNameB
		PUBLIC	SERDUnitA
		PUBLIC	SERDUnitB
		PUBLIC	SCSIEnable
		PUBLIC	SERDAIsPar
		PUBLIC	SERDBIsPar
		PUBLIC	AppleCD
		PUBLIC	VideoType1
		PUBLIC	VideoType2
		PUBLIC	Sana2Name
		PUBLIC	Sana2Unit
		PUBLIC	VideoMode2
		PUBLIC	BlackBorder2
		PUBLIC	DisplayID2
		PUBLIC	ScreenX2
		PUBLIC	ScreenY2
		PUBLIC	ProtectROM
		PUBLIC	SCSIMemType
		PUBLIC	OverscanType1
		PUBLIC	OverscanType2
		PUBLIC	NumMonitors
		PUBLIC	ADDMaxTransfer1
		PUBLIC	ADDMaxTransfer2
		PUBLIC	AppleHD
		PUBLIC	Floppy1
		PUBLIC	Floppy2
		PUBLIC	BootFrom
		PUBLIC	InhibitFloppy1
		PUBLIC	InhibitFloppy2
		PUBLIC	RefreshAlways
		PUBLIC	ExtVideoName1
		PUBLIC	UseAmigaMouse
		PUBLIC	ADDRemovable1
		PUBLIC	ADDRemovable2
		PUBLIC	MMURefresh
		PUBLIC	SCSIName0
		PUBLIC	SCSIName1
		PUBLIC	SCSIName2
		PUBLIC	SCSIName3
		PUBLIC	SCSIName4
		PUBLIC	SCSIName5
		PUBLIC	SCSIName6
		PUBLIC	SCSIUnit0
		PUBLIC	SCSIUnit1
		PUBLIC	SCSIUnit2
		PUBLIC	SCSIUnit3
		PUBLIC	SCSIUnit4
		PUBLIC	SCSIUnit5
		PUBLIC	SCSIUnit6
		PUBLIC	AudioOn
		PUBLIC	ROMMemType
		PUBLIC	ExtVideoName2
		PUBLIC	SCSIDirect
		PUBLIC	UseSCCSerial
		PUBLIC	FastCrapMode
		PUBLIC	UseAHI
		PUBLIC	AudioID
		PUBLIC	MacOS8Mode

; Definitionen
	IFND	SHAPE_EXTVIDEO_I
VMODE_1BIT	= 0
VMODE_2BIT	= 1
VMODE_4BIT	= 2
VMODE_8BIT	= 3
VMODE_15BIT	= 4
VMODE_24BIT	= 5
	ENDC

VTYPE_AMIGA	= 0	;Amiga-Screen, 1,2,4 oder 8 Bit, Refresh bei 2,4 und 8 Bit
VTYPE_CYBER	= 1	;CyberGfx-Screen, 8 Bit
VTYPE_EGS	= 2	;EGS-Screen, 8,16 oder 24 Bit, Refresh bei 16 und 24 Bit
VTYPE_MACINABOX	= 3	;Monochrom in einem Fenster
VTYPE_EXTERNAL	= 4	;Externer Treiber

SCSIMEM_CHIP	= 0	;Chip-Speicher
SCSIMEM_24BIT	= 1	;24-Bit-DMA-Speicher (Zorro II)
SCSIMEM_ANY	= 2	;Egal

BOOTFROM_LAST	= 0	;Letztes ausgewähltes
BOOTFROM_ANY	= 1	;Egal
BOOTFROM_FILE1	= 2	;FileDisk1
BOOTFROM_DEV1	= 3	;DeviceDisk1
BOOTFROM_CDROM	= 4	;CD-ROM

FTYPE_NONE	= 0	;Floppy-Typ: Keins
FTYPE_DF0	= 1
FTYPE_DF1	= 2
FTYPE_DF2	= 3
FTYPE_DF3	= 4
FTYPE_PH0	= 5
FTYPE_PH1	= 6

; Nützliche Makros
JSRSELF		MACRO
		XREF	\1
		jsr	\1
		ENDM

JMPSELF		MACRO
		XREF	\1
		jmp	\1
		ENDM

EJSRLIB		MACRO
		XREF	_LVO\1
		addq.w	#1,NoSuperSwitch
		jsr	_LVO\1(a6)
		subq.w	#1,NoSuperSwitch
		ENDM

NJSRLIB		MACRO
		addq.w	#1,NoSuperSwitch
		jsr	_LVO\1(a6)
		subq.w	#1,NoSuperSwitch
		ENDM

; Debugging
	IFNE	DEBUG_DETAIL
		XREF	KPrintF
		XREF	KPutChar
	ENDC

DPRINTF		MACRO	; <string>,...
	IFNE	DEBUG_DETAIL
PUSHCOUNT	SET	0

		movem.l	d0-d1/a0-a1,-(sp)

		IFGE	NARG-9
		move.l	\9,-(sp)
PUSHCOUNT	SET	PUSHCOUNT+4
		ENDC

		IFGE	NARG-8
		move.l	\8,-(sp)
PUSHCOUNT	SET	PUSHCOUNT+4
		ENDC

		IFGE	NARG-7
		move.l	\7,-(sp)
PUSHCOUNT	SET	PUSHCOUNT+4
		ENDC

		IFGE	NARG-6
		move.l	\6,-(sp)
PUSHCOUNT	SET	PUSHCOUNT+4
		ENDC

		IFGE	NARG-5
		move.l	\5,-(sp)
PUSHCOUNT	SET	PUSHCOUNT+4
		ENDC

		IFGE	NARG-4
		move.l	\4,-(sp)
PUSHCOUNT	SET	PUSHCOUNT+4
		ENDC

		IFGE	NARG-3
		move.l	\3,-(sp)
PUSHCOUNT	SET	PUSHCOUNT+4
		ENDC

		IFGE	NARG-2
		move.l	\2,-(sp)
PUSHCOUNT	SET	PUSHCOUNT+4
		ENDC

		movem.l a0/a1,-(sp)
		lea.l	.PSS\@(pc),A0
		lea.l	4*2(sp),A1
		jsr	KPrintF
		movem.l (sp)+,a0/a1
		bra.s	.PSE\@

.PSS\@		dc.b	\1
		dc.b	13,10,0
		even
.PSE\@
		lea.l	PUSHCOUNT(sp),sp

		movem.l	(sp)+,d0-d1/a0-a1
	ENDC
		ENDM
