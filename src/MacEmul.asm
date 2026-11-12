**
** Macintosh IIci-Emulator (multitaskingfähig)
** ===========================================
**
** © Copyright 1993-2001 Christian Bauer
**

DEBUG_DETAIL	SET 0
SECURE		SET 0

		INCLUDE "exec/types.i"
		INCLUDE "exec/macros.i"
		INCLUDE "exec/nodes.i"
		INCLUDE	"exec/lists.i"
		INCLUDE "exec/memory.i"
		INCLUDE "exec/execbase.i"
		INCLUDE "exec/tasks.i"
		INCLUDE "dos/dos.i"
		INCLUDE	"dos/dosextens.i"
		INCLUDE	"workbench/workbench.i"
		INCLUDE	"workbench/startup.i"
		INCLUDE "libraries/asl.i"
		INCLUDE	"libraries/configvars.i"
		INCLUDE	"libraries/locale.i"
		INCLUDE	"devices/inputevent.i"
		INCLUDE	"devices/timer.i"
		INCLUDE	"devices/ahi.i"
		INCLUDE	"resources/cia.i"
		INCLUDE "macros.i"
		INCLUDE	"shapesupport.i"
		INCLUDE	"ShapeShifter_rev.i"
CATCOMP_NUMBERS	= 1
		INCLUDE	"Strings.i"

		XREF	_SysBase		;Astartup
		XREF	_WBenchMsg
		XDEF	_main

		XDEF	TheLocale		;Strings.o
		XREF	GetString
		XREF	LocalizeNew

		XREF	ADDRefNum		;MacEmulADD.asm
		XDEF	Kludge720K

		XREF	AFDRefNum		;MacEmulAFD.asm

		XREF	CDROMRefNum		;MacEmulSCSI.asm

		XDEF	ConvMacToIso		;MacEmulClip.asm
		XDEF	ConvIsoToMac

		XREF	RmvTime			;MacEmulPatches.asm
		XREF	PrimeTime
		XREF	TimeMgrServer
		XREF	Microseconds
		XREF	HWPriv
		XREF	MMUTbl1
		XREF	MMUTbl2
		XDEF	ROMBase
		XDEF	ROMSize
		XDEF	ROMSubVersion
		XDEF	MemBase
		XDEF	MemTop
		XDEF	VIABase
		XDEF	SCCBase
		XDEF	ChipFakeBase
		XDEF	SCCFakeRd
		XDEF	SCCFakeWr
		XDEF	CiaControlReg
		XDEF	CiaTimerReg
		XDEF	CPUType
		XDEF	Has68060
		XDEF	OptNoCopyBack
		XDEF	OptRemap8K
		XDEF	OptEnforcer
		XDEF	OptUSKeyMap
		XDEF	OptNoQDAccel
		XDEF	Opt720K
		XDEF	OptDebug
		XDEF	OptDepthSwitch
		XDEF	OptAdvanced
		XDEF	DepthSwitch
		XDEF	EnforcerCompat
		XDEF	DebugMode
		XDEF	NoCopyBack
		XDEF	Remap8K
		XDEF	USKeyMap
		XDEF	HasMMU
		XDEF	HasFPU
		XDEF	IsDraco
		XDEF	FixROMFor68040
		XDEF	CoreDump
		XDEF	ExcLog
		XDEF	ExcLogIdx
		XDEF	PowerOff
		XDEF	ResetVIA
		XDEF	ResetSCC
		XDEF	InitMouse
		XDEF	ExecuteAT
		XDEF	DoMacKeycode
		XDEF	KeyXLate
		XDEF	HasRealVIA
		XDEF	HasRealSCC
		XDEF	TimerIntPort
		XDEF	TimerIO
		XDEF	TimeDBRA
		XDEF	TimeSCCDBRA
		XDEF	TimeSCSIDBRA
		XDEF	TimeRAMDBRA
		XDEF	XPRam
		XDEF	PRamName
		XDEF	TheShapeSema
		XDEF	EmergShutDown
		XDEF	ProgSwitch
		XDEF	NoQDAccel

		XDEF	PrefsName		;MacEmulPrefs.asm
		XDEF	EmulPrefs
		XDEF	EmulPrefsEnd
		XDEF	PrefsNameTab
		XDEF	PrefsDefName
		XDEF	ROMName
		XDEF	ROMSize
		XDEF	QuickStart

		XREF	GotChannel01		;MacEmulSound.asm

		XREF	BoxBorderLeft		;MacEmulVideo.asm
		XREF	BoxBorderTop
		XREF	IsRefreshing
		XDEF	UserPort
		XDEF	EGSUserPort

		XDEF	AllocMMU
		XDEF	HasMMU
		XDEF	HasFPU
		XDEF	GetMMUPage
		XDEF	FlushMMU
		XDEF	PageSize
		XDEF	PageOffsetMask
		XDEF	PageIndexMask

		XDEF	SubtaskSet


**
** Definitionen
**

; ROM-Offsets
ROMEntry	= $118		;Einsprung
ROMCacheStuff	= $186		;Für 68040-Kompatibilitäts-Test

; Speicher
ChipFakeSize	= $2800		;Größe des simulierten Chip-Bereiches
ChipFakeOffset	= $800		;Größe des negativen Chip-Bereiches


**
** Hauptprogramm
**

		SECTION "CODE",CODE

*
* Libraries öffnen
*

; Adresse unseres Tasks herausfinden
_main		move.l	_SysBase,a6
		sub.l	a1,a1
		JSRLIB	FindTask
		move.l	d0,MyTask

; Task-Name setzen
		move.l	d0,a0
		move.l	LN_NAME(a0),OldTaskName
		move.l	#MainTaskName,LN_NAME(a0)

; Intuition-Library öffnen
		move.l	a6,_ExecBase
		lea	IntuitionName,a1
		moveq	#37,d0
		JSRLIB	OpenLibrary
		move.l	d0,_IntuitionBase
		beq	NoIntui

; Graphics-Library öffnen
		lea	GfxName,a1
		moveq	#37,d0
		JSRLIB	OpenLibrary
		move.l	d0,_GfxBase
		beq	NoGfx

; GadTools-Library öffnen
		lea	GadToolsName,a1
		moveq	#37,d0
		JSRLIB	OpenLibrary
		move.l	d0,_GadToolsBase
		beq	NoGadTools

; Asl-Library öffnen
		lea	AslName,a1
		moveq	#37,d0
		JSRLIB	OpenLibrary
		move.l	d0,_AslBase
		beq	NoAsl

; Utility-Library öffnen
		lea	UtilityName,a1
		moveq	#37,d0
		JSRLIB	OpenLibrary
		move.l	d0,_UtilityBase
		beq	NoUtility

; IFFParse-Library öffnen
		lea	IFFParseName,a1
		moveq	#37,d0
		JSRLIB	OpenLibrary
		move.l	d0,_IFFParseBase
		beq	NoIFFParse

; Icon-Library öffnen
		lea	IconName,a1
		moveq	#37,d0
		JSRLIB	OpenLibrary
		move.l	d0,_IconBase
		beq	NoIcon

; Expansion-Library öffnen
		lea	ExpansionName,a1
		moveq	#37,d0
		JSRLIB	OpenLibrary
		move.l	d0,_ExpansionBase
		beq	NoExpansion

; CIA-B-Resource öffnen
		lea	CiaResName,a1
		JSRLIB	OpenResource
		move.l	d0,_CiaBase
		beq	NoCiaRes

; Disk-Resource öffnen (kann ruhig fehlschlagen, wegen DraCo)
		lea	DiskResName,a1
		JSRLIB	OpenResource
		move.l	d0,_DiskBase

; Misc-Resource öffnen (kann ruhig fehlschlagen, wegen DraCo)
		lea	MiscResName,a1
		JSRLIB	OpenResource
		move.l	d0,_MiscBase

; FDC-Resource öffnen (nur DraCo)
		lea	FDCResName,a1
		JSRLIB	OpenResource
		move.l	d0,_FDCBase

; AHI öffnen (kann ruhig fehlschlagen)
		XREF	_LVOCreateMsgPort
		XREF	_LVODeleteMsgPort
		OPENAHI	4
		move.l	d0,_AHIBase

; Draco-Resource antesten
		lea	DracoResName,a1
		JSRLIB	OpenResource
		tst.l	d0
		sne.b	IsDraco

; Locale öffnen und Catalog laden
		move.l	_ExecBase,a6
		moveq	#37,d0
		lea	LocaleName,a1
		JSRLIB	OpenLibrary
		move.l	d0,_LocaleBase
		beq	1$
		move.l	d0,a6
		sub.l	a0,a0
		lea	CatalogName,a1
		lea	CatalogTags,a2
		JSRLIB	OpenCatalogA
		move.l	d0,TheCatalog

; Datenstrukturen lokalisieren
1$		bsr	Localize
		JSRSELF	LocalizePrefs
		JSRSELF	LocalizeNew	;MacEmulLoc: the texts added in 3.20

; Zustand des Cache holen
		move.l	_ExecBase,a6
		moveq	#0,d0
		moveq	#0,d1
		JSRLIB	CacheControl
		move.l	d0,OldCacheStatus

*
* ShapeShifter-Semaphor installieren. Fehler, wenn schon vorhanden
*

; Semaphor schon vorhanden?
		move.l	_ExecBase,a6
		lea	SemaName,a1
		JSRLIB	FindSemaphore
		tst.l	d0
		bne	SemaTwiceExit

; Nein, Speicher für Semaphor holen
		move.l	#ShapeSema_SIZEOF,d0
		move.l	#MEMF_CLEAR|MEMF_PUBLIC,d1
		JSRLIB	AllocVec
		move.l	d0,TheShapeSema
		beq	NoMemExit

; Amiga-Task Queue Header initialisieren
		lea	AmigaTaskQHdr,a1
		clr.w	(a1)+
		clr.l	(a1)+
		clr.l	(a1)

; Semaphor initialisieren und öffentlich machen
		move.l	TheShapeSema,a1
		move.l	#SemaName,LN_NAME(a1)
		move.b	#1,LN_PRI(a1)
		move.l	#ATInstallProc,ss_ExecMacProc(a1)
		JSRLIB	AddSemaphore

*
* Amiga-Konfiguration ermitteln: Ist die Maschine für ShapeShifter geeignet?
*

; Ist PrepareEmul installiert?
		move.l	_ExecBase,a6

		tst.b	IsDraco		;Draco: Immer erfüllt
		bne	PrepEmulOK

		lea	MemList(a6),a0
		lea	ChipMemName,a1
		JSRLIB	FindName
		cmp.l	#$2000,d0	;MemHeader oberhalb von 8K?
		blo	NoPrepExit	;Nein, Fehlermeldung

; Prozessor-Typ ermitteln
PrepEmulOK	move.w	AttnFlags(a6),d0
		btst	#AFB_68020,d0	;68020 vorhanden?
		beq	No68020Exit	;Nein, Fehlermeldung
		move.w	#2,CPUType	;Ja

		btst	#AFB_68030,d0	;68030 vorhanden?
		beq	Not68030
		move.w	#3,CPUType	;Ja

		btst	#AFB_68040,d0	;68040 vorhanden?
		beq	Not68030
		move.w	#4,CPUType	;Ja
		btst	#7,d0		;68060 vorhanden?
		sne.b	Has68060	;Ja
Not68030

; FPU vorhanden?
		btst	#AFB_68881,d0	;68881/882 vorhanden?
		sne.b	HasFPU		;FPU vorhanden

; Brauchbare MMU-Konfig vorhanden?
		move.l	#$100,d0	;Wichtig, da sonst AllocMMU nicht funktioniert, wenn keine MMU da ist
		move.l	d0,PageSize
		subq.l	#1,d0
		move.l	d0,PageOffsetMask
		not.l	d0
		move.l	d0,PageIndexMask

		cmp.w	#4,CPUType	;68040 vorhanden?
		bne	NotMMU
		lea	GetMMUProc,a5	;Ja, SRP und TC lesen
		JSRLIB	Supervisor
		btst	#15,d1		;MMU angeschaltet?
		beq	NotMMU
		btst	#14,d1		;Ja, 4K-Seiten?
		bne	MMUIs8K

MMUIs4K		bfclr	d0{23:9}	;Ja, Zeiger auf MMU-Tabelle speichern
		move.l	d0,MMURoot
		move.l	#$1000,d0
		move.l	d0,PageSize
		subq.l	#1,d0
		move.l	d0,PageOffsetMask
		not.l	d0
		move.l	d0,PageIndexMask
		st.b	HasMMU
		bra	NotMMU

MMUIs8K		bfclr	d0{23:9}	;Nein
		move.l	d0,MMURoot
		move.l	#$2000,d0
		move.l	d0,PageSize
		subq.l	#1,d0
		move.l	d0,PageOffsetMask
		not.l	d0
		move.l	d0,PageIndexMask
		st.b	HasMMU
		st.b	MMUHas8KPages
NotMMU

; VBR ungleich Null?
		lea	GetTheVBR,a5
		JSRLIB	Supervisor
		tst.l	d0
		bne	VBRIsOK

; Nein, VBR verschieben
		move.l	#$400,d0
		move.l	#MEMF_PUBLIC,d1
		JSRLIB	AllocMem
		tst.l	d0
		beq	NoMemExit
		move.l	d0,a3
		move.l	d0,a1
		sub.l	a0,a0
		move.l	#$400,d0
		JSRLIB	CopyMem
		JSRLIB	CacheClearU
		move.l	a3,d0
		lea	SetTheVBR,a5
		JSRLIB	Supervisor

; Prüfen, ob AMAX-Karte installiert
VBRIsOK		move.l	_ExpansionBase,a6
		sub.l	a0,a0
		move.l	#$2100,d0
		moveq	#1,d1
		JSRLIB	FindConfigDev
		tst.l	d0
		beq	AMAXNotFound
		move.l	d0,a0
		move.l	cd_BoardAddr(a0),a0
		lea	$4000(a0),a0
		move.l	a0,VIABase
		st.b	HasRealVIA
		lea	$4000(a0),a0
		move.l	a0,SCCBase
		st.b	HasRealSCC
AMAXNotFound

; Prüfen, ob Emplant-Karte installiert
		move.l	_ExpansionBase,a6
		sub.l	a0,a0
		move.l	#$087b,d0
		moveq	#-1,d1
		JSRLIB	FindConfigDev
		tst.l	d0
		beq	EmplantNotFound
		move.l	d0,a0
		move.l	cd_BoardAddr(a0),a0
		lea	$4000(a0),a0
		cmp.b	#$ff,(a0)	;SCC wirklich da?
		bne	1$
		cmp.b	#$ff,1(a0)
		bne	1$
		cmp.b	#$ff,2(a0)
		bne	1$
		cmp.b	#$ff,3(a0)
		beq	EmplantNotFound
1$		move.l	a0,SCCBase
		st.b	HasRealSCC
EmplantNotFound


*
* Argumente auswerten
*

; Default-Name der Prefs-Datei setzen
		lea	PrefsDefName,a0
		lea	PrefsName,a1
		move.w	#255,d0
1$		move.b	(a0)+,(a1)+
		dbeq	d0,1$

; Vom CLI gestartet?
		move.l	MyTask,a0
		tst.l	pr_CLI(a0)
		beq	FromWB

; Ja, ReadArgs benutzen
FromCLI		move.l	_DOSBase,a6
		move.l	#Template,d1
		move.l	#CLIArgs,d2	;Erstes Argument
		moveq	#0,d3
		JSRLIB	ReadArgs
		move.l	d0,d1		;NULL ist OK

		move.l	PrefsNameArg,d0	;Name der Prefs-Datei kopieren
		beq	1$
		move.l	d0,a0
		lea	PrefsName,a1
		move.w	#255,d0
2$		move.b	(a0)+,(a1)+
		dbeq	d0,2$

1$		JSRLIB	FreeArgs
		bra	ArgsDone

; Von der Workbench gestartet, ToolTypes lesen
FromWB		move.l	_IconBase,a6

		move.l	_WBenchMsg,a0
		move.l	sm_ArgList(a0),a0
		move.l	wa_Name(a0),a0
		JSRLIB	GetDiskObject
		tst.l	d0
		beq	1$
		move.l	d0,a2

		move.l	a2,a0
		move.l	do_ToolTypes(a0),a0
		lea	QuickToolType,a1
		JSRLIB	FindToolType
		tst.l	d0
		beq	3$
		move.l	#-1,QuickStart

3$		move.l	a2,a0
		move.l	do_ToolTypes(a0),a0
		lea	EnforcToolType,a1
		JSRLIB	FindToolType
		tst.l	d0
		beq	4$
		move.l	#-1,EnforcerCompat

4$		move.l	a2,a0
		move.l	do_ToolTypes(a0),a0
		lea	DebugToolType,a1
		JSRLIB	FindToolType
		tst.l	d0
		beq	5$
		move.l	#-1,DebugMode

5$		move.l	a2,a0
		move.l	do_ToolTypes(a0),a0
		lea	NoCBackToolType,a1
		JSRLIB	FindToolType
		tst.l	d0
		beq	6$
		move.l	#-1,NoCopyBack

6$		move.l	a2,a0
		move.l	do_ToolTypes(a0),a0
		lea	Kludge720KToolType,a1
		JSRLIB	FindToolType
		tst.l	d0
		beq	7$
		move.l	#-1,Kludge720K

7$		move.l	a2,a0
		move.l	do_ToolTypes(a0),a0
		lea	Remap8KToolType,a1
		JSRLIB	FindToolType
		tst.l	d0
		beq	8$
		move.l	#-1,Remap8K

8$
9$		move.l	a2,a0
		move.l	do_ToolTypes(a0),a0
		lea	USKeyMapToolType,a1
		JSRLIB	FindToolType
		tst.l	d0
		beq	10$
		move.l	#-1,USKeyMap

10$		move.l	a2,a0
		move.l	do_ToolTypes(a0),a0
		lea	NoQDAccelToolType,a1
		JSRLIB	FindToolType
		tst.l	d0
		beq	12$
		move.l	#-1,NoQDAccel

12$		move.l	a2,a0
		move.l	do_ToolTypes(a0),a0
		lea	DepthSwToolType,a1
		JSRLIB	FindToolType
		tst.l	d0
		beq	11$
		move.l	#-1,DepthSwitch

11$		move.l	a2,a0
		JSRLIB	FreeDiskObject

; Und erstes Icon als Prefs laden
1$		move.l	_WBenchMsg,a0
		cmp.l	#1,sm_NumArgs(a0)
		bls	ArgsDone

		move.l	sm_ArgList(a0),a0
		lea	wa_SIZEOF(a0),a0	;Erstes Icon (wir selbst) überspringen

		move.l	wa_Lock(a0),d1
		beq	ArgsDone
		move.l	wa_Name(a0),d4

		move.l	_DOSBase,a6
		move.l	#PrefsName,d2
		move.l	#256,d3
		JSRLIB	NameFromLock

		move.l	#PrefsName,d1
		move.l	d4,d2
		move.l	#256,d3
		JSRLIB	AddPart

ArgsDone

*
* Enforcer beruhigen, falls gewünscht
*

		tst.b	HasMMU
		beq	100$
		tst.l	EnforcerCompat
		beq	100$
		moveq	#0,d0			;Seite 0 gültig machen
		bsr	GetMMUPage
		bset	#0,3(a0)
		bclr	#2,3(a0)
100$
		clr.l	($100).w

*
* Einstellungen laden
*

; Vorgaben
LoadEmulPrefs	lea	SerialName,a0
		lea	SERDNameA,a1
		moveq	#79,d0
4$		move.b	(a0)+,(a1)+
		dbeq	d0,4$

		lea	ParallelName,a0
		lea	SERDNameB,a1
		moveq	#79,d0
2$		move.b	(a0)+,(a1)+
		dbeq	d0,2$

		move.l	#0,SERDUnitA
		move.l	#0,SERDUnitB
		st.b	SERDBIsPar

		lea	SCSIDefName,a0
		lea	SCSIName0,a1
		moveq	#79,d1
5$		move.b	(a0)+,d0
		move.b	d0,0*80(a1)
		move.b	d0,1*80(a1)
		move.b	d0,2*80(a1)
		move.b	d0,3*80(a1)
		move.b	d0,4*80(a1)
		move.b	d0,5*80(a1)
		move.b	d0,6*80(a1)
		addq.l	#1,a1
		dbeq	d1,5$

		moveq	#0,d0
		move.l	d0,SCSIUnit0
		addq.l	#1,d0
		move.l	d0,SCSIUnit1
		addq.l	#1,d0
		move.l	d0,SCSIUnit2
		addq.l	#1,d0
		move.l	d0,SCSIUnit3
		addq.l	#1,d0
		move.l	d0,SCSIUnit4
		addq.l	#1,d0
		move.l	d0,SCSIUnit5
		addq.l	#1,d0
		move.l	d0,SCSIUnit6

		clr.b	SCSIEnable		;Kein SCSI-Geraet durchreichen, bis der Benutzer eins einschaltet

		move.w	#10,RefreshRate
		move.w	#VTYPE_AMIGA,VideoType1
		move.w	#VTYPE_AMIGA,VideoType2
		move.w	#VMODE_1BIT,VideoMode1
		move.w	#VMODE_1BIT,VideoMode2
		move.l	#640,ScreenX1
		move.l	#480,ScreenY1
		move.l	#640,ScreenX2
		move.l	#480,ScreenY2
		move.w	#1,OverscanType1	;Text
		move.w	#1,OverscanType2
		move.l	#$1b8000,MemSize
		move.w	#SCSIMEM_ANY,ROMMemType
		move.w	#-1,MouseDirect
		move.w	#-1,AppleCD
		move.w	#-1,BlackBorder
		move.l	#-1,ADDMaxTransfer1
		move.l	#-1,ADDMaxTransfer2
		move.w	#-1,AudioOn
		move.l	#AHI_DEFAULT_ID,AudioID

		JSRSELF	SearchFloppys

		move.l	_GfxBase,a6
		move.l	#$00039024,d0		;VGA Productivity verfügbar?
		move.l	d0,DisplayID1
		JSRLIB	ModeNotAvailable
		tst.l	d0
		beq	3$
		move.l	#$00008004,DisplayID1	;Nein, dann Hires Lace
3$

; Einstellungs-Datei laden
		JSRSELF	OpenThePrefs
		JSRSELF	FirstRunSetup	;MacEmulSetup: ROM, Einstellungen, leere Mac-Disk

*
* Größe der ROM-Datei ermitteln und Variable setzen
*

GetROMFileSize	move.l	_DOSBase,a6
		move.l	#ROMName,d1		;Datei öffnen
		move.l	#ACCESS_READ,d2
		JSRLIB	Lock
		move.l	d0,d7
		beq	NoROMExit

		move.l	d7,d1
		move.l	#FIB,d2
		JSRLIB	Examine			;Größe ermitteln
		tst.l	d0
		bne	1$

		move.l	d7,d1			;Fehler, abbrechen
		JSRLIB	UnLock
		bra	NoROMExit

1$		move.l	fib_Size+FIB,d6		;Größe lesen
		move.l	d7,d1			;Datei schließen
		JSRLIB	UnLock

		cmp.l	#$080000,d6		;512K-ROM?
		beq	2$
		cmp.l	#$100000,d6		;Nein, 1MB-ROM?
		bne	ROMSizeExit		;Nein, Fehlermeldung
2$		move.l	d6,ROMSize

*
* Einstellungsfenster darstellen
* && Muß auch bei QuickStart geschehen, da hier das Keyfile dekodiert wird
*

DoTheSettings	JSRSELF	DoSettings
		tst.l	d0
		bmi	NoMemExit
		beq	Exit

*
* Gespeicherte Startoptionen (CPU-Tab) wirken wie die Tooltypes
*

ApplyStartOpts	movem.l	a2-a3,-(sp)
		lea	StartOptTab,a0
		lea	ForcedOpts,a1
		move.b	ForcedSaved,d1
		st	ForcedSaved
10$		move.l	(a0)+,d0
		beq	13$
		move.l	d0,a2			;a2: the flag the emulator tests
		move.l	(a0)+,a3		;a3: the saved option
		tst.b	d1
		bne	11$
		move.l	(a2),(a1)		;First pass: what tooltypes/arguments asked for
11$		move.l	(a1)+,d0
		tst.w	(a3)
		beq	12$
		moveq	#-1,d0
12$		move.l	d0,(a2)			;Each pass: forced or saved. An option unticked
		bra	10$			; after going back to the settings is off again
13$		movem.l	(sp)+,a2-a3
7$		tst.w	OptEnforcer		;Enforcer: Seite 0 nachtraeglich gueltig machen
		beq	8$
		tst.l	EnforcerCompat
		bne	8$
		move.l	#-1,EnforcerCompat
		tst.b	HasMMU
		beq	8$
		moveq	#0,d0
		bsr	GetMMUPage
		bset	#0,3(a0)
		bclr	#2,3(a0)
8$

*
* Einstellungen anpassen
*

*
* Pruefungen vor dem Start (fehlende File-Disks, ROM im Chip-RAM, 68060 ohne
* NOCOPYBACK unter UAE): starten, zurueck zu den Einstellungen oder beenden
*

CheckBeforeStart JSRSELF	CheckStart
		tst.l	d0
		bmi	Exit
		bne	DoTheSettings

AdjSettings	cmp.w	#VTYPE_EGS,VideoType1	;EGS impliziert MouseDirect,
		bne	1$			; da kein DELTAMOVE im EGS
		move.w	#-1,MouseDirect
1$
		cmp.w	#VTYPE_MACINABOX,VideoType1 ;Bei Amiga-Fenster-Modus Amiga-Mauszeiger benutzen
		bne	2$
		move.w	#-1,UseAmigaMouse
2$
		tst.w	NumMonitors		;Mehrere Monitore verbieten Amiga-Mauszeiger
		beq	3$
		clr.w	UseAmigaMouse
3$
		tst.b	HasMMU			;Keine MMU? Dann auch kein ROM-Schreibschutz
		bne	4$			; und kein MMU-Refresh
		clr.w	ProtectROM
		clr.w	MMURefresh
4$
		tst.b	Has68060		;68060? Dann kein ROM-Schreibschutz
		beq	14$
		clr.w	ProtectROM
14$
		move.l	ScreenX1,d0		;Breite auf Vielfaches von 16 bringen
		add.l	#15,d0
		and.l	#$fffffff0,d0
		move.l	d0,ScreenX1

		move.l	ScreenX2,d0
		add.l	#15,d0
		and.l	#$fffffff0,d0
		move.l	d0,ScreenX2

		tst.w	RefreshRate		;Rate 0 nicht zulassen
		bne	5$
		move.w	#1,RefreshRate
5$
		move.w	Floppy1,d0		;Floppy-Units gleich?
		cmp.w	Floppy2,d0
		bne	6$
		clr.w	Floppy2			;Ja, dann Floppy 2 abschalten
6$
		tst.b	IsDraco			;Draco?
		beq	7$
		clr.w	MouseDirect		;Ja, dann keine direkte Mausabfrage
		tst.w	AudioOn
		beq	7$
		move.w	#-1,UseAHI		;Und Sound nur über AHI
7$
		tst.w	UseAmigaMouse		;Amiga-Mauszeiger nie direkt abfragen
		beq	8$
		clr.w	MouseDirect
8$
		cmp.w	#SCSIMEM_CHIP,ROMMemType
		bne	11$
		move.l	#MEMF_CHIP|MEMF_PUBLIC,TheROMMemType
		bra	13$
11$		cmp.w	#SCSIMEM_24BIT,ROMMemType
		bne	12$
		move.l	#MEMF_24BITDMA|MEMF_PUBLIC,TheROMMemType
		bra	13$
12$		move.l	#MEMF_ANY|MEMF_PUBLIC,TheROMMemType
13$
		tst.b	HasRealSCC		;Kein SCC?
		bne	15$
		clr.w	UseSCCSerial		;Dann auch keine SCC-Treiber
15$

*
* US-Tastaturbelegung einschalten
*

		tst.l	USKeyMap
		beq	20$
		move.b	#$32,KeyXLate
20$

*
* Untere 8K remappen
*

		tst.b	HasMMU
		beq	10$
		tst.l	Remap8K
		beq	10$
		bsr	DoRemap8K
10$

*
* Signal für Subtasks belegen
*

AllocSubtaskSig	move.l	_ExecBase,a6
		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,SubtaskSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,SubtaskSet

*
* Timer-Interrupt belegen
*

; DraCo? Dann kein CIA-Zugriff
AllocateTimer	tst.b	IsDraco
		bne	AllocTimerDraco

; Timer A versuchen
4$		move.l	_ExecBase,a6
		JSRLIB	Disable
		move.l	_CiaBase,a6
		lea	TimerInterrupt,a1
		moveq	#0,d0			;Timer A
		JSRLIB	AddICRVector
		tst.l	d0
		bne	1$
		move.w	#1,TimerOpen
		move.l	#$bfe401,CiaTimerReg
		move.l	#$bfee01,CiaControlReg
		bra	2$

; Nicht gelungen, dann Timer B versuchen
1$		lea	TimerInterrupt,a1
		moveq	#1,d0			;Timer B
		JSRLIB	AddICRVector
		tst.l	d0
		bne	3$
		move.w	#2,TimerOpen
		move.l	#$bfe601,CiaTimerReg
		move.l	#$bfef01,CiaControlReg
		bra	2$

; Kein Timer gefunden
3$		move.l	_ExecBase,a6
		JSRLIB	Enable
		bra	NoTimerExit

; Timer gefunden, 60Hz einstellen
2$		move.l	_ExecBase,a6
		JSRLIB	Enable

		move.l	_ExecBase,a6
		move.l	CiaControlReg,a0	;Timer stoppen
		and.b	#$80,(a0)
		move.l	ex_EClockFrequency(a6),d0
		divu.w	#60,d0			;60Hz
		move.l	CiaTimerReg,a0
		move.b	d0,(a0)			;Timer-Wert setzen
		lsr.w	#8,d0
		move.b	d0,$100(a0)
		bra	AllocateTimerIO

; DraCo: 60Hz-Interrupt mit timer.device machen
AllocTimerDraco	move.l	_ExecBase,a6
		moveq	#MP_SIZE,d0
		move.l	#MEMF_CLEAR|MEMF_PUBLIC,d1
		JSRLIB	AllocVec
		move.l	d0,DracoIntPort
		beq	NoMemExit

		move.l	d0,a0
		move.b	#NT_MSGPORT,LN_TYPE(a0)
		move.b	#PA_SOFTINT,MP_FLAGS(a0)
		move.l	#DracoInterrupt,MP_SOFTINT(a0)
		lea	MP_MSGLIST(a0),a0
		NEWLIST	a0

		moveq	#IOTV_SIZE,d0
		move.l	DracoIntPort,a0
		JSRLIB	CreateIORequest
		move.l	d0,DracoTimerIO
		beq	NoMemExit

		lea	TimerName,a0
		moveq	#UNIT_MICROHZ,d0
		move.l	DracoTimerIO,a1
		moveq	#0,d1
		JSRLIB	OpenDevice

		move.l	DracoTimerIO,a1		;Timer starten
		move.l	IO_DEVICE(a1),a6
		clr.l	IOTV_TIME+TV_SECS(a1)
		move.l	#16667,IOTV_TIME+TV_MICRO(a1)
		move.w	#TR_ADDREQUEST,IO_COMMAND(a1)
		jsr	-30(a6)

; TimerIO für Time Manager einrichten
AllocateTimerIO	move.l	_ExecBase,a6
		moveq	#MP_SIZE,d0
		move.l	#MEMF_CLEAR|MEMF_PUBLIC,d1
		JSRLIB	AllocVec
		move.l	d0,TimerIntPort
		beq	NoMemExit

		move.l	d0,a0
		move.b	#NT_MSGPORT,LN_TYPE(a0)
		move.b	#PA_SOFTINT,MP_FLAGS(a0)
		move.l	#TimeMgrInterrupt,MP_SOFTINT(a0)
		lea	MP_MSGLIST(a0),a0
		NEWLIST	a0

		moveq	#IOTV_SIZE,d0
		move.l	TimerIntPort,a0
		JSRLIB	CreateIORequest
		move.l	d0,TimerIO
		beq	NoMemExit

; timer.device öffnen
		lea	TimerName,a0
		moveq	#UNIT_MICROHZ,d0
		move.l	TimerIO,a1
		moveq	#0,d1
		JSRLIB	OpenDevice

; DeviceBase holen
		move.l	TimerIO,a0
		move.l	IO_DEVICE(a0),_TimerBase

; Prozessorgeschwindigkeit testen
		bsr	ProcessorSpeed

; Time Manager initialisieren
		JSRSELF	InitTimeMgr

*
* VBlank-Interrupt einrichten
*

SetupVBLInt	move.l	_ExecBase,a6
		lea	VBLInterrupt,a1
		moveq	#5,d0			;INTB_VBLANK
		JSRLIB	AddIntServer
		st.b	VBLIntInstalled

*
* VIA-Interrupt einrichten, falls VIA vorhanden
*

SetupVIAInt	tst.b	HasRealVIA
		beq	1$
		bsr	ResetVIA		;VIA-Interrupt löschen
		move.l	_ExecBase,a6
		lea	VIAInterrupt,a1
		move.l	VIABase,IS_DATA(a1)	;Interrupt erhält VIABase in a1
		moveq	#3,d0			;INTB_PORTS
		JSRLIB	AddIntServer
		st.b	VIAIntInstalled
1$

*
* SCC-Interrupt einrichten, falls SCC vorhanden
*

SetupSCCInt	tst.b	HasRealSCC
		beq	1$
		bsr	ResetSCC
		move.l	_ExecBase,a6
		lea	SCCInterrupt,a1
		move.l	SCCBase,IS_DATA(a1)	;Interrupt erhält SCCBase in a1
		moveq	#13,d0			;INTB_EXTER
		JSRLIB	AddIntServer
		st.b	SCCIntInstalled
1$

*
* Speicher für ROM anfordern, falls FastROM gesetzt
*

AllocateROM1	tst.w	FastROM
		beq	1$
		move.l	_ExecBase,a6
		move.l	ROMSize,d0
		move.l	TheROMMemType,d1
		bsr	AllocMMU
		move.l	d0,ROMBase
		beq	NoMemExit
1$

*
* Speicher für Mac-RAM anfordern
*

; Mac-Speicher/ROM
AllocateMemory	move.l	_ExecBase,a6
		cmp.l	#$100000,MemSize	;the Mac ROM needs at least 1 MB
		bhs	1$
		move.l	#$100000,MemSize
1$
		tst.w	LargestBlock
		bne	AllocLargest

; Eingestellte Größe
		move.l	MemSize,d0	;Mac-Speicher
		move.l	#MEMF_PUBLIC|MEMF_ANY,d1
		JSRLIB	AllocVec
		move.l	d0,MemBase
		bne	AllocateDone

		move.l	_IntuitionBase,a6	;Nicht gelungen, fragen ob größter freier Block
		moveq	#MSG_TRYLARGEST,d0
		lea	TheLocale,a0
		jsr	GetString
		lea	TryLargestReq,a1
		move.l	d0,es_TextFormat(a1)
		sub.l	a0,a0
		sub.l	a2,a2
		sub.l	a3,a3
		JSRLIB	EasyRequestArgs
		tst.l	d0
		beq	Exit
		move.l	_ExecBase,a6
		;fällt durch!

; Größter freier Block
AllocLargest	JSRLIB	Forbid		;Mac-Speicher largest
		move.l	#MEMF_LARGEST|MEMF_PUBLIC|MEMF_ANY,d1
		JSRLIB	AvailMem	;Größten freien Block ermitteln
		sub.l	#256,d0		;AllocVec braucht etwas mehr
		move.l	d0,MemSize
		move.l	#MEMF_PUBLIC|MEMF_ANY,d1
		JSRLIB	AllocVec	;Speicher anfordern
		JSRLIB	Permit		;Erhält garantiert die Register
		move.l	d0,MemBase
		beq	NoMemExit

; Variablen setzen
AllocateDone	move.l	MemBase,d0
		add.l	MemSize,d0
		move.l	d0,MemTop

*
* Speicher für ROM anfordern, falls FastROM gelöscht
*

AllocateROM2	tst.w	FastROM
		bne	1$
		move.l	_ExecBase,a6
		move.l	ROMSize,d0
		move.l	TheROMMemType,d1
		bsr	AllocMMU
		move.l	d0,ROMBase
		beq	NoMemExit
1$

*
* Speicher für simulierte Mac-Chips anfordern
*

		move.l	_ExecBase,a6
		move.l	#ChipFakeSize,d0
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		JSRLIB	AllocVec
		move.l	d0,ChipFakeBase
		beq	NoMemExit
		add.l	#ChipFakeOffset,ChipFakeBase

*
* ROM laden
*

; ROM laden
LoadROM		move.l	_DOSBase,a6
		move.l	#ROMName,d1		;Datei öffnen
		move.l	#MODE_OLDFILE,d2
		JSRLIB	Open
		move.l	d0,d7
		beq	NoROMExit

		move.l	d7,d1			;Datei laden
		move.l	ROMBase,d2
		move.l	ROMSize,d3
		JSRLIB	Read
		move.l	d0,d6

		move.l	d7,d1			;Datei schließen
		JSRLIB	Close

		cmp.l	ROMSize,d6		;Gelungen?
		bne	NoROMExit

		move.l	ROMBase,a0
		cmp.w	#$067c,8(a0)		;ROM-Version prüfen
		bne	ROMVersionExit

		move.b	18(a0),ROMSubVersion	;Sub-Version holen
		cmp.l	#$00003919,ROMCacheStuff+2(a0) ;68040-Kompatibilität ermitteln
		sne	ROMIs68040Comp
		bne	4$
		cmp.w	#4,CPUType
		shs	FixROMFor68040		;ROM muß für 68040 gepatcht werden
4$

*
* Prüfsumme des ROMs testen
*

		moveq	#0,d0			;Prüfsumme berechnen
		moveq	#0,d1
		move.l	ROMBase,a0
		move.l	ROMSize,d3
		subq.l	#4,d3
		move.l	(a0)+,d4
1$		move.w	(a0)+,d0
		add.l	d0,d1
		subq.l	#2,d3
		bne	1$
		cmp.l	d4,d1			;Gleich der im ROM?
		beq	2$

		move.l	_IntuitionBase,a6	;Nein, nachfragen
		moveq	#MSG_ROMCHECKSUM,d0
		lea	TheLocale,a0
		jsr	GetString
		lea	TryLargestReq,a1
		move.l	d0,es_TextFormat(a1)
		sub.l	a0,a0
		sub.l	a2,a2
		sub.l	a3,a3
		JSRLIB	EasyRequestArgs
		tst.l	d0
		beq	Exit
2$

*
* Screen und Fenster öffnen
*

; Window-Ports einrichten
		move.l	_ExecBase,a6
		moveq	#MP_SIZE,d0
		move.l	#MEMF_CLEAR|MEMF_PUBLIC,d1
		JSRLIB	AllocVec
		move.l	d0,UserPort
		beq	NoMemExit

		move.l	d0,a0
		lea	MP_MSGLIST(a0),a0
		NEWLIST	a0
		move.l	UserPort,a0
		move.b	#NT_MSGPORT,LN_TYPE(a0)
		move.b	#PA_SOFTINT,MP_FLAGS(a0)
		move.l	#WindowInterrupt,MP_SOFTINT(a0)

		moveq	#MP_SIZE,d0
		move.l	#MEMF_CLEAR|MEMF_PUBLIC,d1
		JSRLIB	AllocVec
		move.l	d0,EGSUserPort
		beq	NoMemExit

		move.l	d0,a0
		lea	MP_MSGLIST(a0),a0
		NEWLIST	a0
		move.l	EGSUserPort,a0
		move.b	#NT_MSGPORT,LN_TYPE(a0)
		move.b	#PA_SOFTINT,MP_FLAGS(a0)
		move.l	#EGSInterrupt,MP_SOFTINT(a0)

; Grafik öffnen
		JSRSELF OpenVideo
		cmp.l	#1,d0
		beq	NoScreenExit
		cmp.l	#2,d0
		beq	NoMemExit
		cmp.l	#3,d0
		beq	NoEGSExit
		cmp.l	#4,d0
		beq	NoTrueAmigaExit
		cmp.l	#5,d0
		beq	OnlyOneMacBoxExit
		cmp.l	#6,d0
		beq	No124VGAExit
		cmp.l	#7,d0
		beq	NoCyberGfxExit
		cmp.l	#8,d0
		beq	NoCyberModeExit
		cmp.l	#9,d0
		beq	No16BitModeExit
		cmp.l	#10,d0
		beq	OnlyOneAmigaExit
		cmp.l	#11,d0
		beq	NoCyberMemExit
		cmp.l	#12,d0
		beq	CantLoadEVDExit
		cmp.l	#13,d0
		beq	IsNoEVDExit

*
* Parameter-Ram laden
*

LoadPRam	move.l	#$ffff0000,XPRam+$78	;Starttreiber=Egal
		move.l	#$a8000022,XPRam+$10	;SysParam
		move.l	#$cc0acc0a,XPRam+$14
		move.l	#$00026300,XPRam+$1c
		move.l	#$1788004c,XPRam+$08

		move.l	_DOSBase,a6
		move.l	#PRamName,d1
		move.l	#MODE_OLDFILE,d2
		JSRLIB	Open
		move.l	d0,d7
		beq	LoadNoPRam

		move.l	d7,d1
		move.l	#XPRam,d2
		move.l	#256,d3
		JSRLIB	Read

		cmp.b	#$a8,XPRam		;Alte PRAM-Datei?
		bne	1$
		move.l	_SysBase,a6
		move.l	XPRam,XPRam+36		;Ja, alte Daten kopieren
		move.l	XPRam+4,XPRam+40
		move.l	XPRam+8,XPRam+44
		move.l	XPRam+12,XPRam+48
		move.l	XPRam+16,XPRam+28
		lea	XPRam+20,a0		;PRam verschieben
		lea	XPRam,a1
		move.l	#256-20,d0
		JSRLIB	CopyMem
		move.l	_DOSBase,a6
		move.l	d7,d1			;Und den Rest lesen
		move.l	#XPRam+256-20,d2
		moveq	#20,d3
		JSRLIB	Read

1$		move.l	d7,d1
		JSRLIB	Close
LoadNoPRam

*
* Startlaufwerk setzen, wenn gewünscht
*

		cmp.w	#BOOTFROM_ANY,BootFrom
		bne	1$
		move.w	#0,XPRam+$7a
		bra	4$
1$		cmp.w	#BOOTFROM_FILE1,BootFrom
		bne	2$
		move.w	#AFDRefNum,XPRam+$7a
		bra	4$
2$		cmp.w	#BOOTFROM_DEV1,BootFrom
		bne	3$
		move.w	#ADDRefNum,XPRam+$7a
		bra	4$
3$		cmp.w	#BOOTFROM_CDROM,BootFrom
		bne	4$
		move.w	#CDROMRefNum,XPRam+$7a
4$

*
* SCSI-Treiber öffnen
*

		JSRSELF OpenSCSI
		tst.l	d0
		bne	NoMemExit

*
* Clipboard-Treiber öffnen
*

		JSRSELF	OpenClipboard
		tst.l	d0
		bne	NoMemExit

*
* Audio-Treiber öffnen
*

		JSRSELF	OpenAudio

*
* Seriellen Treiber öffnen
*

		JSRSELF	OpenSerial
		tst.l	d0
		bne	NoMemExit

*
* Netzwerk-Treiber öffnen
*

		JSRSELF	OpenNetwork


*
* FileDisks öffnen
*

		JSRSELF OpenFileDisks
		tst.l	d0
		bne	NoMemExit

		JSRSELF	StartPRamSaver		;PRAM auch ohne sauberes Herunterfahren sichern

*
* Subtask für Disk-Handling einrichten
*

		JSRSELF CreateDiskTask
		tst.l	d0
		bne	NoMemExit

*
* Slot sResources anpassen (muß nach OpenVideo und OpenNetwork geschehen)
*

		JSRSELF	InitSlot

*
* ROM patchen
*

		JSRSELF	PatchROM
		tst.l	d0
		bne	ROMNotUsableExit

*
* Datum und Uhrzeit setzen
*

		JSRSELF	InitRTC

*
* Mauszeiger abschalten, SP sichern, Priorität setzen
* und in Supervisormodus gehen
*

TheTrickyPart	JSRSELF	TogglePointer
		st.b	InputActive

		move.l	_ExecBase,a6
		move.l	MyTask,a1
		moveq	#-1,d0
		JSRLIB	SetTaskPri
		move.b	d0,OldTaskPri		;Fuer Exit merken
		st.b	TaskPriChanged
		move.l	sp,InitialUSP
		JSRLIB	SuperState
		move.l	d0,SysStack

*
* Trap-Handler installieren, ins ROM springen, Emulation starten
*

		JSRLIB	Disable

		movec	vbr,a0			;Amiga-VBR lesen
		move.l	a0,AmigaVBR

		lea	OldVBRTable,a1		;Alte Tabelle kopieren
		moveq	#63,d0
5$		move.l	(a0)+,(a1)+
		dbra	d0,5$

		move.l	AmigaVBR,a0
		move.l	#NewLineA,$28(a0)	;Line-A

		tst.w	ProtectROM
		beq	6$
		move.l	#NewBusError,8(a0)	;Bus Error (ROM-Schreibschutz)
6$
		lea	ExceptHandler,a1
		move.l	a1,$c(a0)		;Address Error
		move.l	a1,$10(a0)		;Illegal Instruction
		move.l	a1,$14(a0)		;Zero Divide
		move.l	a1,$18(a0)		;CHK
		move.l	a1,$1c(a0)		;TRAPV
		move.l	a1,$38(a0)		;Format Error

		tst.b	IsDraco			;Wegen Customchip-Emulation
		bne	7$
		move.l	a1,$24(a0)		;Trace
7$
		tst.b	Has68060		;Wegen 68060.library
		bne	2$
		tst.b	ROMIs68040Comp
		beq	2$
		move.l	a1,$2c(a0)		;Line-F (68040 FPSP)
		move.l	a1,$c0(a0)		;BSUN
		move.l	a1,$c4(a0)		;INEX1/2
		move.l	a1,$c8(a0)		;DZ
		move.l	a1,$cc(a0)		;UNFL
		move.l	a1,$d0(a0)		;OPERR
		move.l	a1,$d4(a0)		;OVFL
		move.l	a1,$d8(a0)		;SNAN
		move.l	a1,$dc(a0)		;FPU Data Format Error
2$
		move.l	a1,$80(a0)		;Trap #0
		move.l	a1,$84(a0)
		move.l	a1,$88(a0)
		move.l	a1,$8c(a0)
		move.l	a1,$90(a0)
		move.l	a1,$94(a0)
		move.l	a1,$98(a0)
		move.l	a1,$9c(a0)
		move.l	a1,$a0(a0)
		move.l	a1,$a4(a0)
		move.l	a1,$a8(a0)
		move.l	a1,$ac(a0)
		move.l	a1,$b0(a0)
		move.l	a1,$b4(a0)
		move.l	a1,$b8(a0)
		move.l	a1,$bc(a0)		;Trap #15

	IFNE	SECURE
		move.l	#NewAutoInt1,$64(a0)
		move.l	#NewAutoInt2,$68(a0)
		move.l	#NewAutoInt3,$6c(a0)
		move.l	#NewAutoInt4,$70(a0)
		move.l	#NewAutoInt5,$74(a0)
		move.l	#NewAutoInt6,$78(a0)
	ENDC

		tst.l	DebugMode
		beq	1$
		move.l	#CoreDump,$c(a0)	;Address Error
		move.l	#CoreDump,$10(a0)	;Illegal Instruction
		move.l	#CoreDump,$14(a0)	;Zero Divide
		move.l	#CoreDump,$18(a0)	;CHK
		move.l	#CoreDump,$1c(a0)	;TRAPV
		move.l	#CoreDump,$2c(a0)	;Line-F
		move.l	#CoreDump,$38(a0)	;Format Error
1$
		tst.b	HasMMU
		beq	3$
		move.l	_ExecBase,a6
		lea	GetMMUProc,a5
		JSRLIB	Supervisor
		movem.l	d0-d3,MMUTbl1+4
		movem.l	d0-d3,MMUTbl2+4
3$
		move.l	_ExecBase,a6
		move.l	ex_LaunchPoint(a6),OldLaunchPoint
		move.l	#NewLaunchPoint,ex_LaunchPoint(a6)

		tst.b	IsDraco
		bne	10$

		move.l	a6,a1			;ExitIntr normal
		move.w	#-36,a0
		move.l	#NewExitIntr,d0
		JSRLIB	SetFunction
		move.l	d0,OldExitIntr
		bra	11$

10$		move.l	a6,a1			;ExitIntr Draco
		move.w	#-36,a0
		move.l	#DracoExitIntr,d0
		JSRLIB	SetFunction
		move.l	d0,OldExitIntr

11$		move.l	a6,a1
		move.w	#-42,a0
		move.l	#NewSchedule,d0
		JSRLIB	SetFunction
		move.l	d0,OldSchedule

		move.l	AmigaVBR,a0		;Merken, welche Vektoren jetzt von uns sind
		lea	NewVBRTable,a1
		moveq	#63,d0
45$		move.l	(a0)+,(a1)+
		dbra	d0,45$

		st.b	TrapsInstalled

; WarmStart-Flag löschen
		clr.l	$cfc

; Caches löschen. Wichtig, da wir Code gepatcht haben.
		JSRLIB	CacheClearU

; ROM schreibschützen
		tst.w	ProtectROM
		beq	4$
		bsr	DoProtectROM
4$

; Bei nicht-68040-kompatiblen ROMs und 68040+ Datencache abschalten
		move.l	_ExecBase,a6
		tst.b	FixROMFor68040
		beq	12$
		moveq	#0,d0
		move.l	#CACRF_EnableD,d1
		JSRLIB	CacheControl
12$

; Bei Option NOCOPYBACK CopyBack abschalten
		tst.l	NoCopyBack
		beq	13$
		moveq	#0,d0
		move.l	#CACRF_CopyBack,d1
		JSRLIB	CacheControl
13$

; Auf 68060 Super Bypass abschalten (CPU-Bug mit MacOS 8)
		tst.b	Has68060
		beq	14$

		MACHINE	68060

		movec	pcr,d0
		bset	#5,d0
		movec	d0,pcr

		MACHINE	68020
14$
		JSRLIB	Enable

; Ab ins ROM
		move.l	ROMBase,a3
		lea	ROMEntry-6(a3),a0
		jmp	(a0)


*
* Fehlerbehandlung
* In der Exit-Routine dürfen keine 68020-Befehle vorkommen!
*

		MACHINE	68000

NoTimerExit	moveq	#MSG_NOTIMER,d0
		bra	ReqExit

NoPrepExit	moveq	#MSG_NOPREP,d0
		bra	ReqExit

No68020Exit	moveq	#MSG_NO68020,d0
		bra	ReqExit

NoMemExit	moveq	#MSG_NOMEM,d0
		bra	ReqExit

NoScreenExit	moveq	#MSG_NOSCREEN,d0
		bra	ReqExit

NoEGSExit	moveq	#MSG_NOEGS,d0
		bra	ReqExit

NoTrueAmigaExit	moveq	#MSG_NOTRUEAMIGA,d0
		bra	ReqExit

OnlyOneMacBoxExit moveq	#MSG_ONLYONEMACBOX,d0
		bra	ReqExit

OnlyOneAmigaExit moveq	#MSG_ONLYONEAMIGA,d0
		bra	ReqExit

No124VGAExit	moveq	#MSG_NO124VGA,d0
		bra	ReqExit

NoCyberGfxExit	moveq	#MSG_NOCYBERGFX,d0
		bra	ReqExit

NoCyberModeExit	moveq	#MSG_NOCYBERMODE,d0
		bra	ReqExit

No16BitModeExit	moveq	#MSG_NO16BITMODE,d0
		bra	ReqExit

SemaTwiceExit	moveq	#MSG_SEMATWICE,d0
		bra	ReqExit

NoROMExit	moveq	#MSG_NOROM,d0
		bra	ReqExit

ROMVersionExit	moveq	#MSG_ROMVERSION,d0
		bra	ReqExit

ROMSizeExit	moveq	#MSG_ROMSIZE,d0
		bra	ReqExit

ROMNotUsableExit moveq	#MSG_ROMNOTUSABLE,d0
		bra	ReqExit

NoCyberMemExit	moveq	#MSG_NOCYBERMEM,d0
		bra	ReqExit

CantLoadEVDExit	moveq	#MSG_CANTLOADEVD,d0
		bra	ReqExit

IsNoEVDExit	moveq	#MSG_ISNOEVD,d0
		bra	ReqExit

ReqExit		lea	TheLocale,a0
		jsr	GetString
ReqExit2	lea	ErrorReq,a1
		move.l	d0,es_TextFormat(a1)
		sub.l	a0,a0
		sub.l	a2,a2
		sub.l	a3,a3
		move.l	_IntuitionBase,a6
		JSRLIB	EasyRequestArgs

; Zustand des Cache wiederherstellen
Exit		move.l	_ExecBase,a6
		move.l	MyTask,d0		;Name und Prioritaet des Tasks zuruecksetzen
		beq	ExitNoTask		; (eine Shell laeuft nach uns weiter)
		move.l	d0,a1
		move.l	OldTaskName,d0
		beq	ExitNoName
		move.l	d0,LN_NAME(a1)
ExitNoName	tst.b	TaskPriChanged
		beq	ExitNoTask
		clr.b	TaskPriChanged
		move.b	OldTaskPri,d0
		ext.w	d0
		ext.l	d0
		JSRLIB	SetTaskPri
ExitNoTask
		move.l	OldCacheStatus,d0
		move.l	#CACRF_EnableI|CACRF_EnableD|CACRF_CopyBack,d1
		JSRLIB	CacheControl

; Exec-Patches und VBR zurücksetzen
		tst.b	TrapsInstalled
		beq	ExitTraps

		move.l	_ExecBase,a6
		JSRLIB	Disable

		lea	OldVBRTable,a0		;Nur die Vektoren zuruecksetzen, die wir
		move.l	AmigaVBR,a1		; selbst geaendert haben: was ein anderes
		moveq	#63,d0			; Programm inzwischen an den uebrigen
1$		move.l	(a0)+,d1		; getan hat, bleibt
		cmp.l	NewVBRTable-OldVBRTable-4(a0),d1
		beq	2$
		move.l	d1,(a1)
2$		addq.l	#4,a1
		dbra	d0,1$

		move.l	OldLaunchPoint,ex_LaunchPoint(a6)
		move.l	a6,a1
		move.w	#-36,a0
		move.l	OldExitIntr,d0
		JSRLIB	SetFunction
		move.l	a6,a1
		move.w	#-42,a0
		move.l	OldSchedule,d0
		JSRLIB	SetFunction

		JSRLIB	Enable

		move.l	_DOSBase,a6
		moveq	#2,d1
		JSRLIB	Delay
		move.l	_ExecBase,a6

; Timer schließen
ExitTraps	move.l	TimerIO,d0
		beq	ExitTimerDev
		JSRSELF	ExitTimeMgr
		move.l	_ExecBase,a6
		move.l	TimerIO,a1
		JSRLIB	CloseDevice
		move.l	TimerIO,a0
		JSRLIB	DeleteIORequest
		move.l	TimerIntPort,d0
		beq	ExitTimerDev
		move.l	d0,a1
		JSRLIB	FreeVec

; Draco-Timer
ExitTimerDev	move.l	DracoTimerIO,d0
		beq	ExitTimerDev2
		move.l	_ExecBase,a6
		move.l	DracoIntPort,a0
		move.b	#PA_IGNORE,MP_FLAGS(a0)
		move.l	DracoTimerIO,a1
		JSRLIB	AbortIO
		move.l	DracoTimerIO,a1
1$		move.b	LN_TYPE(a1),d0
		cmp.b	#NT_REPLYMSG,d0
		bne	1$
		JSRLIB	CloseDevice
		move.l	DracoTimerIO,a0
		JSRLIB	DeleteIORequest
		move.l	DracoIntPort,d0
		beq	ExitTimerDev2
		move.l	d0,a1
		JSRLIB	FreeVec

; SCC-Interrupt entfernen
ExitTimerDev2	tst.b	SCCIntInstalled
		beq	ExitSCCInt
		bsr	ResetSCC
		move.l	_ExecBase,a6
		lea	SCCInterrupt,a1
		moveq	#13,d0
		JSRLIB	RemIntServer

; VIA-Interrupt entfernen
ExitSCCInt	tst.b	VIAIntInstalled
		beq	ExitVIAInt
		bsr	ResetVIA
		move.l	_ExecBase,a6
		lea	VIAInterrupt,a1
		moveq	#3,d0
		JSRLIB	RemIntServer

; CIA-Interrupt entfernen
ExitVIAInt	move.w	TimerOpen,d0
		beq	ExitTimer
		move.l	CiaControlReg,a0
		bclr	#0,(a0)			;Timer stoppen
		move.l	_CiaBase,a6
		lea	TimerInterrupt,a1
		subq.b	#1,d0
		JSRLIB	RemICRVector

; VBL-Interrupt entfernen
ExitTimer	tst.b	VBLIntInstalled
		beq	ExitVBLInt
		move.l	_ExecBase,a6
		lea	VBLInterrupt,a1
		moveq	#5,d0
		JSRLIB	RemIntServer

ExitVBLInt	JSRSELF	StopPRamSaver
		JSRSELF DeleteDiskTask
		JSRSELF CloseFileDisks

		move.l	ChipFakeBase,d0
		beq	ExitChipMem
		move.l	_ExecBase,a6
		sub.l	#ChipFakeOffset,d0
		move.l	d0,a1
		JSRLIB	FreeVec

ExitChipMem	JSRSELF	CloseNetwork
		JSRSELF	CloseSerial
		JSRSELF	CloseAudio
		JSRSELF	CloseClipboard
		JSRSELF CloseSCSI
		JSRSELF CloseVideo

		move.l	EGSUserPort,d0
		beq	ExitEGSPort
		move.l	d0,a1
		move.l	_ExecBase,a6
		JSRLIB	FreeVec

ExitEGSPort	move.l	UserPort,d0
		beq	ExitUserPort
		move.l	d0,a1
		move.l	_ExecBase,a6
		JSRLIB	FreeVec

ExitUserPort	tst.l	ROMBase
		beq	ExitROMMem
		bsr	UnprotectROM		;ROM entschützen
		move.l	_ExecBase,a6
		move.l	ROMBase,a1
		move.l	ROMSize,d0
		JSRLIB	FreeMem

ExitROMMem	move.l	MemBase,d0
		beq	ExitMem
		move.l	_ExecBase,a6
		move.l	d0,a1
		JSRLIB	FreeVec

ExitMem		move.l	TheShapeSema,d0
		beq	ExitSema
		move.l	_ExecBase,a6
		JSRLIB	Forbid
		move.l	TheShapeSema,a1
		JSRLIB	RemSemaphore
		move.l	TheShapeSema,a0
		JSRLIB	ObtainSemaphore
		move.l	TheShapeSema,a0
		JSRLIB	ReleaseSemaphore
		move.l	TheShapeSema,a1
		JSRLIB	FreeVec
		JSRLIB	Permit

ExitSema	move.b	SubtaskSig,d0
		beq	ExitSubSig
		move.l	_ExecBase,a6
		JSRLIB	FreeSignal

ExitSubSig	bsr	Unmap8K			;Untere 8K wieder zurücklegen

		CLOSEAHI
		move.l	_ExecBase,a6
		move.l	_CyberGfxBase,d0
		beq	ExitNoCyber
		move.l	d0,a1
		JSRLIB	CloseLibrary
ExitNoCyber	move.l	_P96Base,d0
		beq	ExitNoP96
		move.l	d0,a1
		JSRLIB	CloseLibrary
ExitNoP96	move.l	_EGSBase,d0
		beq	ExitNoEGS
		move.l	d0,a1
		JSRLIB	CloseLibrary
ExitNoEGS	move.l	_ExecBase,a6
NoMiscRes
NoCiaRes	;Es gibt kein CloseResource()
NoDiskRes	move.l	_LocaleBase,d0
		beq	NoLocale
		move.l	d0,a6
		move.l	TheCatalog,a0
		JSRLIB	CloseCatalog
		move.l	a6,a1
		move.l	_SysBase,a6
		JSRLIB	CloseLibrary
NoLocale	move.l	_ExpansionBase,a1
		JSRLIB	CloseLibrary
NoExpansion	move.l	_IconBase,a1
		JSRLIB	CloseLibrary
NoIcon		move.l	_IFFParseBase,a1
		JSRLIB	CloseLibrary
NoIFFParse	move.l	_UtilityBase,a1
		JSRLIB	CloseLibrary
NoUtility	move.l	_AslBase,a1
		JSRLIB	CloseLibrary
NoAsl		move.l	_GadToolsBase,a1
		JSRLIB	CloseLibrary
NoGadTools	move.l	_GfxBase,a1
		JSRLIB	CloseLibrary
NoGfx		move.l	_IntuitionBase,a1
		JSRLIB	CloseLibrary
NoIntui		rts

		MACHINE	68020


**
** Unterroutinen
**

*
* Routine zum Installieren eines Amiga-Task
* a0: Zeiger auf MacProc-Struktur
*

ATInstallProc	movem.l	a5-a6,-(sp)
		move.w	#7,mp_priv1(a0)		;qType
		move.l	_ExecBase,a6
		lea	ATInstall2,a5
		JSRLIB	Supervisor
		movem.l	(sp)+,a5-a6
		rts

ATInstall2	cmp.w	#7,mp_priv1(a0)
		bne	1$
		lea	AmigaTaskQHdr,a1
		dc.w	$a96f			;Enqueue
		rte
1$		moveq	#-2,d0
		rte

*
* Amiga-Tasks ausführen
*

ExecuteAT	btst	#6,$160
		bne	2$
		bset	#6,AmigaTaskQHdr
		bne	2$

		movem.l	d0-d7/a0-a6,-(sp)
		bra	3$

4$		move.l	d0,a0
		lea	AmigaTaskQHdr,a1
		move.l	$13b8,a2		;Dequeue
		jsr	(a2)
		move.l	8(a0),a2
		move.l	12(a0),a1
		and.w	#$f8ff,sr
		jsr	(a2)

3$		or.w	#$0700,sr
		move.l	AmigaTaskQHdr+2,d0
		bne	4$
		bclr	#6,AmigaTaskQHdr
		movem.l	(sp)+,d0-d7/a0-a6

2$		and.w	#$f8ff,sr
		rts


*
* Speicher an einer MMU-Seitengrenze holen
* d0: Anzahl Bytes
* d1: Speichertyp
*

AllocMMU	movem.l	d6-d7/a4,-(sp)
		move.l	_ExecBase,a6
		move.l	d0,d7		;d7: Originalgröße
		add.l	PageOffsetMask,d0
		move.l	d0,d6		;d6: Erhöhte Größe
					;d1 enthält den Speichertyp
		JSRLIB	AllocMem
		tst.l	d0
		beq	1$
		move.l	d0,a4		;a4: Größerer Block

		JSRLIB	Forbid

		move.l	a4,a1		;Wieder freigeben
		move.l	d6,d0
		JSRLIB	FreeMem

		move.l	a4,d0		;Adresse ausrichten
		add.l	PageOffsetMask,d0
		and.l	PageIndexMask,d0
		move.l	d0,a4

		move.l	d0,a1		;Und nochmal belegen
		move.l	d7,d0
		JSRLIB	AllocAbs

		JSRLIB	Permit
		move.l	a4,d0
1$		movem.l	(sp)+,d6-d7/a4
		rts


*
* ROM schreibschützen (_ExecBase muß in a6 bleiben!)
*

DoProtectROM	move.l	ROMSize,d7
		divu.l	PageSize,d7
		subq.l	#1,d7			;d7: Anzahl Seiten des ROMs für dbra

		move.l	ROMBase,d6		;d6: Zeiger auf aktuelle Seite

1$		move.l	d6,d0
		bsr	GetMMUPage
		bset	#2,3(a0)		;WP-Bit setzen
		add.l	PageSize,d6		;Nächste Seite
		dbra	d7,1$

		bsr	FlushMMU		;ATC löschen

		st.b	ROMProtected
		rts


*
* ROM entschützen
*

UnprotectROM	tst.b	ROMProtected
		beq	1$

		move.l	ROMSize,d7
		divu.l	PageSize,d7
		subq.l	#1,d7			;d7: Anzahl Seiten des ROMs für dbra

		move.l	ROMBase,d6		;d6: Zeiger auf aktuelle Seite

2$		move.l	d6,d0
		bsr	GetMMUPage
		bclr	#2,3(a0)		;WP-Bit löschen
		add.l	PageSize,d6		;Nächste Seite
		dbra	d7,2$

		bra	FlushMMU		;ATC löschen
1$		rts


*
* Untere 8K remappen
*

DoRemap8K	tst.b	HasMMU
		beq	1$

		move.l	#$2000,d0		;8K anfordern
		move.l	#MEMF_PUBLIC|MEMF_ANY,d1
		bsr	AllocMMU
		move.l	d0,Fast8KPtr		;Zeiger merken
		beq	1$

		move.l	_ExecBase,a6		;Alles umkopieren
		move.l	d0,a1
		sub.l	a0,a0
		move.l	#$2000,d0
		JSRLIB	CopyMem

		moveq	#0,d0			;Seite 0
		bsr	GetMMUPage
		move.l	(a0),OldPage0		;Alten Zustand merken
		move.l	Fast8KPtr,d0
		move.b	#$01,d0			;Cachable, Write-Through
		move.l	d0,(a0)			;Seite umleiten

		tst.b	MMUHas8KPages
		bne	2$

		move.l	#$1000,d0		;Seite 1
		bsr	GetMMUPage
		move.l	(a0),OldPage1		;Alten Zustand merken
		move.l	Fast8KPtr,d0
		add.l	#$1000,d0
		move.b	#$01,d0			;Cachable, Write-Through
		move.l	d0,(a0)			;Seite umleiten

2$		bsr	FlushMMU		;ATC löschen

		st.b	Remapped8K
1$		rts


*
* Untere 8K wieder zurücklegen
*

Unmap8K		tst.b	Remapped8K
		beq	1$

		moveq	#0,d0			;Seite 0
		bsr	GetMMUPage
		move.l	OldPage0,(a0)

		tst.b	MMUHas8KPages
		bne	2$

		move.l	#$1000,d0		;Seite 1 (nur bei 4K-Seiten)
		bsr	GetMMUPage
		move.l	OldPage1,(a0)

2$		move.l	_ExecBase,a6
		move.l	Fast8KPtr,a1
		move.l	#$2000,d0
		JSRLIB	FreeMem

		bra	FlushMMU
1$		rts


*
* Zeiger auf MMU-Deskriptor zu einer Adresse holen
* d0: Adresse
* RÜckgabe: a0: Zeiger auf MMU-Deskriptor
*

GetMMUPage	tst.b	MMUHas8KPages
		bne	GetMMUPage8K

GetMMUPage4K	move.l	MMURoot,a0
		bfextu	d0{0:7},d1	;Index A
		move.l	(a0,d1.l*4),d1
		bfclr	d1{23:9}
		move.l	d1,a0
		bfextu	d0{7:7},d1	;Index B
		move.l	(a0,d1.l*4),d1
		clr.b	d1
		move.l	d1,a0
		bfextu	d0{14:6},d1	;Index C
		lea	(a0,d1.l*4),a0
	;indirekte Seiten!
		rts

GetMMUPage8K	move.l	MMURoot,a0
		bfextu	d0{0:7},d1	;Index A
		move.l	(a0,d1.l*4),d1
		bfclr	d1{23:9}
		move.l	d1,a0
		bfextu	d0{7:7},d1	;Index B
		move.l	(a0,d1.l*4),d1
		bfclr	d1{25:7}
		move.l	d1,a0
		bfextu	d0{14:5},d1	;Index C
		lea	(a0,d1.l*4),a0
	;indirekte Seiten!
		rts


*
* ATC flushen
*

FlushMMU	movem.l	a5-a6,-(sp)
		move.l	_ExecBase,a6
		lea	FlushMMUProc,a5
		JSRLIB	Supervisor
		movem.l	(sp)+,a5-a6
		rts


*
* Supervisor-Routinen
*

		MACHINE	68040

GetTheVBR	movec	vbr,d0
		rte

SetTheVBR	movec	d0,vbr
		rte

GetMMUProc	movec	srp,d0
		movec	tc,d1
		movec	dtt0,d2
		movec	dtt1,d3
		rte

FlushMMUProc	nop
		cpusha	dc	;Für den 68060
		nop
		pflusha
		rte

		MACHINE	68020


*
* Core Dump:
* Register  nach $17ff00
* ROMBase   nach $17ff40
* LowMemory nach $180000
*

		MACHINE	68040
CoreDump	move	#$2700,sr
		movem.l d0-d7/a0-a7,$17ff00
		move.l	ROMBase,$17ff40
		move.l	usp,a0
		move.l	a0,$17ff44
		lea	$0,a0
		lea	$180000,a1
		move.w	#$7ff,d0
1$		move.l	(a0)+,(a1)+
		dbra	d0,1$
		nop
		cpusha	bc
		nop
		BLINK
		stop	#$2700
		MACHINE	68020


*
* PowerOff: Amiga-Multitasking einschalten, Emulator beenden
*

; Multitasking einschalten, Stack wiederherstellen
PowerOff	bsr	ResetVIA
		bsr	ResetSCC

		clr.w	MacRunning
		clr.w	NoSuperSwitch
		move.l	TheShapeSema,a0
		clr.w	ss_MacRunning(a0)

		move.l	_ExecBase,a6
		move.l	SysStack,d0
		JSRLIB	UserState

		move.l	InitialUSP,sp

; Parameter-Ram speichern
		JSRSELF	StopPRamSaver
SavePRam	move.l	_DOSBase,a6
		move.l	#PRamName,d1
		move.l	#MODE_NEWFILE,d2
		JSRLIB	Open
		move.l	d0,d7
		beq	SaveNoPRam

		move.l	d7,d1
		move.l	#XPRam,d2
		move.l	#256,d3
		JSRLIB	Write

		move.l	d7,d1
		JSRLIB	Close

; Icon speichern
		move.l	_IconBase,a6	;Icon bereits vorhanden?
		lea	PRamName,a0
		JSRLIB	GetDiskObject
		tst.l	d0
		beq	1$
		move.l	d0,a0		;Ja, dann nichts machen
		JSRLIB	FreeDiskObject
		bra	SaveNoPRam

1$		lea	PRamName,a0	;Nein, Icon erzeugen
		lea	PRAMIcon,a1
		JSRLIB	PutDiskObject

; Emulator beenden
SaveNoPRam	bra	Exit


*
* Prozessorgeschwindigkeitstest
*

ProcessorSpeed	move.l	_ExecBase,a6
		JSRLIB	Forbid

		lea	SpeedFunc1,a2
		bsr	SpeedTest
		move.w	d1,TimeDBRA

		lea	SpeedFunc2,a2
		bsr	SpeedTest
		move.w	d1,TimeSCCDBRA

		lea	SpeedFunc3,a2
		bsr	SpeedTest
		move.w	d1,TimeSCSIDBRA
		move.w	d1,TimeRAMDBRA

		move.l	_ExecBase,a6
		JMPLIB	Permit

SpeedTest	move.l	_TimerBase,a6
		lea	EValBuf,a0
		JSRLIB	ReadEClock

		move.w	#64000-1,d3
		jsr	(a2)

		lea	EValBuf2,a0
		JSRLIB	ReadEClock		;Erhält a0

		move.l	EV_HI(a0),d0		;Obere Langworte müssen gleich sein
		cmp.l	EValBuf+EV_HI,d0
		bne	SpeedTest

		move.l	EV_LO(a0),d0
		sub.l	EValBuf+EV_LO,d0

		move.l	_ExecBase,a0
		move.l	ex_EClockFrequency(a0),d1
		lsl.l	#6,d1			;*64000/1000 (64000 Duchläufe, Ergebnis in ms)
		tst.l	d0			;Keine Zeit vergangen: nicht durch 0 teilen
		bne	SpeedDiv
		moveq	#1,d0
SpeedDiv	divu.l	d0,d1
		cmp.l	#$ffff,d1		;Das Ergebnis wird als Wort gespeichert
		bls	SpeedFits
		move.l	#$ffff,d1
SpeedFits	rts

SpeedFunc1	dbra	d3,SpeedFunc1
		rts

SpeedFunc2	move.l	SCCBase,a0
1$		btst	#0,(a0)
		dbra	d3,1$
		rts

SpeedFunc3	lea	EmulPrefs,a0
1$		btst	#0,(a0)
		dbra	d3,1$
		rts


*
* Zeichenkonvertierungen
*

ConvMacToIso	cmp.b	#13,d0		;CR?
		beq	2$
		tst.b	d0
		bpl	1$
		and.w	#$7f,d0
		move.b	(MacToIso,d0.w),d0
1$		rts
2$		moveq	#10,d0		;CR -> LF
		rts

ConvIsoToMac	cmp.b	#10,d0		;LF?
		beq	2$
		tst.b	d0
		bpl	1$
		and.w	#$7f,d0
		move.b	(IsoToMac,d0.w),d0
1$		rts
2$		moveq	#13,d0		;LF -> CR
		rts


*
* Trap-Handler
*

; Busfehler: ROM-Schreibschutz abfangen. Nur ein Schreibzugriff ins ROM wird
; verschluckt; jeder andere Busfehler (auch der anderer Tasks) geht an den
; Handler, der ohne den Schreibschutz zustaendig waere.
NewBusError	move.l	d0,-(sp)
		move.w	4+6(sp),d0		;Format des Stackframes
		and.w	#$f000,d0
		cmp.w	#$7000,d0		;68040 Access Error
		bne	1$
		btst	#0,4+$c(sp)		;SSW: Lesezugriff?
		bne	3$
		move.l	4+$14(sp),d0		;Fault Address
		sub.l	ROMBase,d0
		cmp.l	ROMSize,d0
		bhs	3$
		move.l	(sp)+,d0		;Schreiben ins ROM: ohne Wirkung weiter
		rte

1$		cmp.w	#$a000,d0		;68030 Bus Error (kurz oder lang)
		beq	2$
		cmp.w	#$b000,d0
		bne	3$
2$		move.w	4+$a(sp),d0		;SSW: Fehler im Datenzyklus, Schreibzugriff?
		and.w	#$0140,d0
		cmp.w	#$0100,d0
		bne	3$
		move.l	4+$10(sp),d0		;Data Cycle Fault Address
		sub.l	ROMBase,d0
		cmp.l	ROMSize,d0
		bhs	3$
		bclr	#0,4+$a(sp)		;DF loeschen: der Zyklus wird nicht wiederholt
		move.l	(sp)+,d0
		rte

3$		move.l	(sp)+,d0
		bra	ExceptHandler

; Line-A geht nicht über den TrapHandler, weil Line-As auch aus
;  Interrupts heraus aufgerufen werden
NewLineA
	IFNE	SECURE
		move.l	_ExecBase,4
	ENDC
		move.l	$28,-(sp)
		rts

ExceptHandler	clr.l	-(sp)		;Exception-Vektor holen
		move.w	10(sp),2(sp)
		and.w	#$0fff,2(sp)

; Fehler-Exceptions (Vektoren 2-15, ohne Line-A) in einen Ring von 32
; Eintraegen schreiben: nach einem Absturz des Mac zeigt ExcLog, wo es war.
; Eintrag (48 Bytes): Format/Vektor.w SR.w PC SSP d0 a0 a1 a5 a6 Ticks Task a4
		cmp.w	#$40,2(sp)
		bhs	ExcNoLog
		cmp.w	#$28,2(sp)
		beq	ExcNoLog
		movem.l	d0/a0-a1,-(sp)
		move	sr,-(sp)
		or.w	#$0700,sr
		lea	ExcLog,a0
		move.w	ExcLogIdx,d0
		addq.w	#1,ExcLogIdx
		and.w	#31,d0
		mulu.w	#48,d0
		add.l	d0,a0
		move.w	24(sp),(a0)+		;Format/Vektor
		move.w	18(sp),(a0)+		;SR
		move.l	20(sp),(a0)+		;PC
		lea	26(sp),a1
		move.l	a1,(a0)+		;SSP vor der Exception
		move.l	2(sp),(a0)+		;d0
		move.l	6(sp),(a0)+		;a0
		move.l	10(sp),(a0)+		;a1
		move.l	a5,(a0)+
		move.l	a6,(a0)+
		move.l	$16a,(a0)+		;Mac-Ticks
		move.l	_ExecBase,a1
		move.l	ThisTask(a1),(a0)+
		move.l	a4,(a0)+
		move	(sp)+,sr
		movem.l	(sp)+,d0/a0-a1
ExcNoLog

		move.l	a0,-(sp)	;Ist es der ShapeShifter-Task?
		move.l	_ExecBase,a0
		move.l	ThisTask(a0),a0
		cmp.l	MyTask,a0
		movea.l	4(sp),a0	;Beeinflußt die Flags nicht
		beq	1$
		add.l	#OldVBRTable,a0	;Nein, alte Tabelle verwenden
1$		move.l	(a0),4(sp)	;Adresse aus Tabelle lesen
		move.l	(sp)+,a0
		rts			;In Vektor einspringen

	IFNE	SECURE
NewAutoInt1	move.l	_ExecBase,4
		move.l	OldVBRTable+$64,-(sp)
		rts

NewAutoInt2	move.l	_ExecBase,4
		move.l	OldVBRTable+$68,-(sp)
		rts

NewAutoInt3	move.l	_ExecBase,4
		move.l	OldVBRTable+$6c,-(sp)
		rts

NewAutoInt4	move.l	_ExecBase,4
		move.l	OldVBRTable+$70,-(sp)
		rts

NewAutoInt5	move.l	_ExecBase,4
		move.l	OldVBRTable+$74,-(sp)
		rts

NewAutoInt6	move.l	_ExecBase,4
		move.l	OldVBRTable+$78,-(sp)
		rts
	ENDC


*
* Preemptives Multitasking im Supervisormodus
*

; Dispatcher
NewLaunchPoint	move	#$2700,sr
		cmp.l	MyTask,a3
		bne	1$
		clr.b	DontSwitchEmul
1$		move.l	OldLaunchPoint,-(sp)
		rts

; Rückkehr aus Interrupt
NewExitIntr	move.l	(sp)+,a6
		move.l	ThisTask(a6),d0		;ShapeShifter-Task aktiv?
		cmp.l	MyTask,d0
		beq	3$

		btst	#5,$18(sp)		;Nein, normales ExitIntr()
		bne	1$
		tst.b	TDNestCnt(a6)
		bge	1$
		tst.w	SysFlags(a6)
		bmi	2$

1$		movem.l	(sp)+,d0-d1/a0-a1/a5-a6
		rte

2$		move	#$2000,sr
		bra	IntSchedule

3$		tst.b	DontSwitchEmul		;ShapeShifter-Task
		bne	1$
		btst	#5,$18(sp)		;im Supervisor-Modus?
		beq	4$
		cmp.b	#$20,$18(sp)		;Ja, Interrupts erlaubt?
		bne	1$
		btst	#2,$dff01d		;Ja, SoftInts erlaubt?
		beq	1$
		tst.w	NoSuperSwitch		;Ja, Supervisor-Switching erlaubt?
		bpl	1$			; (wg. Problemen mit Wait())

4$		tst.b	TDNestCnt(a6)		;Ja oder User-Modus, Forbid()den?
		bge	5$
		tst.w	SysFlags(a6)		;Nein, scheduling attention?
		bmi	IntSchedule		;Ja, schedulen

5$		tst.l	$d94			;Sonst Deferred Tasks ausführen
		beq	6$			;Ohne diesen Test funktioniert der Sound-Input-Treiber nicht asynchron
		movem.l	d2-d3/a2-a3,-(sp)
		move.l	$6e4,a0
		jsr	(a0)
		movem.l	(sp)+,d2-d3/a2-a3
6$		movem.l	(sp)+,d0-d1/a0-a1/a5-a6

		tst.b	ThreadPreEmptive	;Prä-emptives Scheduling?
		bne	7$
		rte

7$		clr.b	([ChipFakeBase],$1a00)	;Ja, VIA-Intreq löschen
		clr.b	ThreadPreEmptive
		and.w	#$f000,6(sp)
		or.w	#$0064,6(sp)		;Level 1 vortäuschen
		move.l	$64,-(sp)		;In Mac-Interrupt 1 einspringen
		rts

DracoExitIntr	move.l	(sp)+,a6
		move.l	ThisTask(a6),d0		;ShapeShifter-Task aktiv?
		cmp.l	MyTask,d0
		beq	3$

		btst	#5,$18(sp)		;Nein, normales ExitIntr()
		bne	1$
		tst.b	TDNestCnt(a6)
		bge	1$
		tst.w	SysFlags(a6)
		bmi	2$

1$		movem.l	(sp)+,d0-d1/a0-a1/a5-a6
		rte

2$		move	#$2000,sr
		bra	IntSchedule

3$		tst.b	DontSwitchEmul		;ShapeShifter-Task
		bne	1$
		btst	#5,$18(sp)		;im Supervisor-Modus?
		beq	4$
		cmp.b	#$20,$18(sp)		;Ja, Interrupts erlaubt?
		bne	1$
		tst.w	NoSuperSwitch		;Ja, Supervisor-Switching erlaubt?
		bpl	1$			; (wg. Interrupts und Problemen mit Wait())

4$		tst.b	TDNestCnt(a6)		;Ja oder User-Modus, Forbid()den?
		bge	5$
		tst.w	SysFlags(a6)		;Nein, scheduling attention?
		bmi	IntSchedule		;Ja, schedulen

5$		tst.l	$d94			;Sonst Deferred Tasks ausführen
		beq	6$
		movem.l	d2-d3/a2-a3,-(sp)
		move.l	$6e4,a0
		jsr	(a0)
		movem.l	(sp)+,d2-d3/a2-a3
6$		movem.l	(sp)+,d0-d1/a0-a1/a5-a6

		tst.b	ThreadPreEmptive	;Prä-emptives Scheduling?
		bne	7$
		rte

7$		clr.b	([ChipFakeBase],$1a00)	;Ja, VIA-Intreq löschen
		clr.b	ThreadPreEmptive
		and.w	#$f000,6(sp)
		or.w	#$0064,6(sp)		;Level 1 vortäuschen
		move.l	$64,-(sp)		;In Mac-Interrupt 1 einspringen
		rts

; Scheduler
NewSchedule	movem.l	d0-d1/a0-a1/a5-a6,-(sp)	;Normaler Scheduler
IntSchedule	move.l	ThisTask(a6),a1
		move	#$2700,sr

		and.w	#~SF_SAR,SysFlags(a6)
		btst	#TB_EXCEPT,TC_FLAGS(a1)
		bne	1$

		lea	TaskReady(a6),a0
		cmp.l	LH_TAILPRED(a0),a0
		beq	2$

		move.l	LH_HEAD(a0),a0
		move.b	LN_PRI(a0),d1
		cmp.b	LN_PRI(a1),d1
		bgt	1$

		btst	#SB_TQE-8,SysFlags(a6)
		beq	2$

1$		cmp.l	MyTask,a1		;Unser Task wird inaktiviert
		bne	3$
		st.b	DontSwitchEmul		;Flag für ExitIntr setzen, sonst krachts!
						;AUF KEINEN FALL DURCH seq.b ERSETZEN!
3$		lea	TaskReady(a6),a0
		JSRLIB	Enqueue
		move.b	#TS_READY,TC_STATE(a1)
		move	#$2000,sr
		movem.l	(sp)+,d0-d1/a0-a1/a5
		move.l	(sp),-(sp)
		move.l	-52(a6),4(sp)
		move.l	(sp)+,a6
		rts

2$		movem.l	(sp)+,d0-d1/a0-a1/a5-a6
		rte


*
* Server für Interrupts
*

numRegs		= 4	;Anzahl Register im movem
statTimer	= 60+(numRegs*4)
statVBL		= 48+(numRegs*4)

; Level 3 - VBlank
IntVBlank	tst.w	MacRunning
		beq	IntNothing
		move.w	#$0020,$dff09c
		lea	VBLServer,a0
		bra	IntServer

; Level 2 - Timer
IntTimer	tst.w	MacRunning
		beq	IntNothing
		lea	TimerServer,a0
		bra	IntServer

; Level 1 - Draco 60Hz SoftInt
IntDraco	lea	DracoServer,a0
		bra	IntServer

; Level 1 - Time Manager SoftInt
IntTimeMgr	tst.w	MacRunning
		beq	IntNothing
		lea	TimeMgrServer,a0
		bra	IntServer

; Level 1 - Window Messages SoftInt
IntWindow	tst.w	MacRunning
		beq	IntNothing
		lea	WindowServer,a0
		bra	IntServer

IntEGS		tst.w	MacRunning
		beq	IntNothing
		lea	EGSServer,a0

IntServer	movem.l	d2-d3/a2-a3,-(sp)
		jsr	(a0)
		movem.l (sp)+,d2-d3/a2-a3
IntNothing	moveq	#0,d0
		rts


**
** Timer-Interrupt-Routine, Level 2 (60Hz)
**

; Draco-60Hz-Interrupt
DracoServer	move.l	a6,-(sp)		;Timer neu starten
		move.l	DracoIntPort,a0
		JSRLIB	GetMsg
		move.l	_TimerBase,a6
		move.l	DracoTimerIO,a1
		clr.l	IOTV_TIME+TV_SECS(a1)
		move.l	#16667,IOTV_TIME+TV_MICRO(a1)
		move.w	#TR_ADDREQUEST,IO_COMMAND(a1)
		jsr	-30(a6)
		move.l	(sp)+,a6

		tst.w	MacRunning
		bne	TimerServer2
		moveq	#0,d0
		rts

; Rücksprung, wenn Mac-Interrupts gesperrt
TimerServer	moveq	#$07,d0
		and.b	statTimer(sp),d0 ;Statusregister
		bne	TimerSrvExit	;Interrupts maskiert, dann Rücksprung

; Patches
TimerServer2	clr.l	$110		;StkLowPt, keine Stackprüfung
		
; In normale Tick-Routine einspringen
		move.l	ChipFakeBase,a1
		move.l	$196,a0
		addq.w	#1,NoSuperSwitch
		jsr	(a0)
		subq.w	#1,NoSuperSwitch

; Sekunden-Interrupt?
		lea	TickCount,a0
		addq.b	#1,(a0)
		move.b	(a0),d0
		cmp.b	#60,d0
		blo	2$

		clr.b	(a0)
		move.l	ChipFakeBase,a1
		move.l	$192,a0
		addq.w	#1,NoSuperSwitch
		jsr	(a0)
		subq.w	#1,NoSuperSwitch
2$
TimerSrvExit

; Gefaketen Audio-Interrupt aufrufen, wenn nötig
		tst.w	GotChannel01
		bne	1$
		JMPSELF	FakeAudioInt
1$		rts


**
** VIA-Interrupt-Routine (nicht über den Server), Level 2
** a1: VIABase
**

IntVIA		tst.w	MacRunning
		beq	2$
		clr.l	$110
		move.b	#$1f,$1c00(a1)		;Alle Interrupts außer Timer 1/2 abschalten
		lea	$1aa,a0			;Timer-1-Vektor
		move.b	$1a00(a1),d0		;Request holen
		and.b	$1c00(a1),d0		; und mit Enable ANDen
		beq	2$
		add.b	d0,d0			;Timer 1?
		bmi	1$
		subq.l	#4,a0			;Sonst Timer 2
1$		move.l	(a0),a0			;Vektor holen
		movem.l	d2-d3/a2-a3,-(sp)
		addq.w	#1,NoSuperSwitch
		jsr	(a0)			; und einspringen
		subq.w	#1,NoSuperSwitch
		movem.l	(sp)+,d2-d3/a2-a3
		moveq	#0,d0			;Ja, der Interrupt war von der VIA
2$		rts

; VIA zurücksetzen
ResetVIA	tst.b	HasRealVIA
		beq	1$
		move.l	VIABase,a0
		clr.b	$600(a0)		;Ports auf Eingang
		clr.b	$400(a0)
		move.b	#$df,(a0)
		st.b	$400(a0)
		move.b	#$7f,$1a00(a0)		;Interrupts sperren
		move.b	#$7f,$1c00(a0)
		st.b	$1800(a0)		;PCR
		clr.b	$1600(a0)
1$		rts


**
** SCC-Interrupt-Routine (nicht über den Server), Level 6
**

IntSCC		tst.w	MacRunning
		beq	1$
		move.l	$70,d0
		ble	1$
		move.w	#$0070,-(sp)
		pea	2$
		move	sr,-(sp)
		move.l	$70,a0
		addq.w	#1,NoSuperSwitch
		jmp	(a0)
2$		subq.w	#1,NoSuperSwitch
1$		moveq	#0,d0
		rts

; SCC zurücksetzen
ResetSCC	tst.b	HasRealSCC
		beq	1$
		move.l	SCCBase,a0
		move.b	(a0),d0
		move.b	#$09,(a0)
		move.b	#$c0,(a0)
1$		rts


**
** VBlank-Interrupt-Routine, Level 3
**

; Patches
VBLServer	tst.b	ROMProtected
		bne	1$
		move.l	ROMBase,a0		;Hier wird ins ROM geschrieben
		add.l	#$fff5,a0		;(System 7.0.1, andere vermutlich auch)
		move.b	#$04,(a0)

1$		tst.b	HasRealVIA
		bne	2$
		move.l	#RmvTime,$564		;Time Manager ohne VIA einrichten
		move.l	#PrimeTime,$568
		move.l	#Microseconds,$64c
2$
		move.l	#HWPriv,$660		;Cache-Routinen einrichten
		move.l	ChipFakeBase,$0		;Damit fehlerhafte Mac-Programme nicht im Speicher rumsemmeln

; Rücksprung, wenn Mac-Interrupts gesperrt
		moveq	#$07,d0
		and.b	statVBL(sp),d0	;Statusregister
		bne	VBLExit		;Interrupts maskiert, dann Rücksprung

; Flag setzen: Thread Manager pre-emptive scheduling in ExitIntr() durchführen
		st.b	ThreadPreEmptive

; Maus abfragen, wenn Emulator-Fenster und Mac-Mauszeiger aktiv sind
; und die direkte Mausabfrage gewählt ist
		JSRSELF IsEmulActive
		bne	VBLNoCursor
		tst.b	InputActive
		beq	VBLNoCursor
		tst.w	MouseDirect
		beq	VBLNoCursor

		bsr	DoMouse

; Cursor bewegen
VBLNoCursor	tst.w	UseAmigaMouse
		beq	1$
		bsr	VBLBoxCursor	;Amiga-Mauszeiger: kein Mac-Cursor, die Slot-VBL-Tasks laufen trotzdem
1$		moveq	#0,d0		;Slot #0
		move.l	$d28,a0		;JVBLTask
		addq.w	#1,NoSuperSwitch
		jsr	(a0)
		subq.w	#1,NoSuperSwitch

; Bei MMU-Refresh den Cache flushen, denn sonst können Stücke des
; Mauszeigers auf dem Bildschirm bleiben
		tst.b	IsRefreshing
		beq	VBLExit
		tst.w	MMURefresh
		beq	VBLExit
		MACHINE	68040
		pflusha
		MACHINE	68020
VBLExit		rts

; Amiga-Mauszeiger: Keinen Mac-Cursor darstellen
VBLBoxCursor	move.l	AmigaMouseXY,d0
		swap	d0
		move.l	d0,$830		;Mouse
		clr.b	$8ce		;CrsrNew
		clr.b	$8d2		;CrsrObscure
		rts

**
** Direkte Mausabfrage
**

InitMouse	clr.w	MouseYX		;Mausabfrage initialisieren
		tst.w	MouseDirect
		beq	1$
		move.w	$dff00a,MouseYX
1$		rts

DoMouse		move.w	$dff00a,d1	;Bewegung
		move.w	d1,d0
		sub.b	MouseYX+1,d0
		bmi	1$
		addq.b	#1,d0
1$		lsr.b	#1,d0
		ror.w	#8,d0
		sub.b	MouseYX,d0
		bmi	2$
		addq.b	#1,d0
2$		lsr.b	#1,d0
		ror.w	#8,d0
		move.w	d1,MouseYX

		or.w	#$0080,d0
		btst	#6,$bfe001	;Maustaste
		beq	3$
		or.w	#$8000,d0
		bra	4$

3$		tst.l	DebugMode	;DebugMode: CoreDump bei Klick links oben
		beq	4$
		tst.l	$830
		beq	CoreDump
4$

DoMacMouse	move.l	$cf8,d1		;ADBBase
		ble	DoMMouseDone
		move.l	d1,a0
		lea	16(a0),a0	;Das zweite ADBDevice ist immer die Maus
		tst.l	(a0)		;Handler vorhanden?
		beq	DoMMouseDone
		move.l	(a0),a1		;Ja, Handler
		move.l	4(a0),a2	; und Data Area holen
		lea	ADBMouseData,a0
		move.b	#2,(a0)		;3 Bytes Daten
		move.w	d0,1(a0)	;Maustaste und Bewegung
		move.b	#$3c,d0		;Talk 0
		jmp	(a1)

DoMMouseDone	rts


**
** Fenster-Interrupt-Routine
**

WindowServer	movem.l d4-d5/a6,-(sp)

; Message holen und beantworten
WindowSrvLoop	move.l	_ExecBase,a6
		move.l	UserPort,a0
		JSRLIB	GetMsg
		tst.l	d0
		beq	ReallyRetInt
		move.l	d0,a1
		move.l	20(a1),d2	;d2: Class
		move.w	24(a1),d3	;d3: Code
		move.l	32(a1),d4	;d4: MouseXY
		move.w	26(a1),d5	;d5: Qualifier
		JSRLIB	ReplyMsg

; Klasse auswerten (MouseMove sollte möglichst schnell sein)
		cmp.w	#$0010,d2	;MouseMove?
		bne	1$
		bsr	DoMouseMove
		bra	WindowSrvLoop

1$		move.w	d3,d0		;d0: Code
		cmp.w	#$0400,d2	;RawKey?
		bne	2$
		bsr	DoKeyboard
		bra	WindowSrvLoop

2$		cmp.w	#$0008,d2	;MouseButtons?
		bne	3$
		bsr	DoMouseButtons
		bra	WindowSrvLoop

3$		cmp.w	#$0200,d2	;CloseWindow?
		bne	WindowSrvLoop
		st.b	EmergShutDown
		bra	WindowSrvLoop

; Vom Interrupt zurückkehren
ReallyRetInt	movem.l (sp)+,d4-d5/a6
		rts

**
** EGS-Interrupt-Routine
**

EGSServer	movem.l d4-d5/a6,-(sp)

; Message holen und beantworten
EGSSrvLoop	move.l	_ExecBase,a6
		move.l	EGSUserPort,a0
		JSRLIB	GetMsg
		tst.l	d0
		beq	ReallyRetInt
		move.l	d0,a1
		move.l	20(a1),d2	;d2: Class
		move.w	24(a1),d3	;d3: Code
		move.l	32(a1),d4	;d4: MouseXY
		move.w	26(a1),d5	;d5: Qualifier
		JSRLIB	ReplyMsg

; Klasse auswerten (MouseMove sollte möglichst schnell sein)
		cmp.w	#$0002,d2	;MouseMove?
		bne	1$
		bsr	DoMouseMove
		bra	EGSSrvLoop

1$		move.w	d3,d0		;d0: Code
		cmp.w	#$0004,d2	;RawKey?
		bne	2$
		bsr	DoKeyboard
		bra	EGSSrvLoop

2$		cmp.w	#$0001,d2	;MouseButtons?
		bne	EGSSrvLoop
		bsr	DoMouseButtons
		bra	EGSSrvLoop


*
* RawKey: Tastatur"abfrage"
*

; Keycode vom Amiga- ins Macintosh-Format bringen
DoKeyboard	btst	#9,d5		;Repeat?
		bne	DoKeyDone	;Ja, dann zurück (Mac macht die Tastenwiederholung)

		move.l	d1,-(sp)		;Caps Lock darf die Notfall-Tasten nicht sperren
		move.b	d5,d1
		and.b	#~IEQUALIFIER_CAPSLOCK&$ff,d1
		cmp.b	#IEQUALIFIER_LSHIFT|IEQUALIFIER_CONTROL|IEQUALIFIER_LALT,d1	;Ctrl-Shift-Alt?
		movem.l	(sp)+,d1		;(movem laesst die Flags stehen)
		bne	2$
		cmp.b	#$45,d0		;Esc?
		bne	3$
		st.b	EmergShutDown	;Ja, Emergency Shut Down
		rts
3$		cmp.b	#$46,d0		;Del? The Mac's Power key: the Mac asks
		bne	4$		; whether to shut down, and does it properly
		movem.l	d0-d2/a0-a2,-(sp)
		move.b	#$b6,d0		;Ctrl-Up
		bsr	DoMacKeycode
		move.b	#$b8,d0		;Shift-Up
		bsr	DoMacKeycode
		move.b	#$ba,d0		;Alt-Up
		bsr	DoMacKeycode
		move.w	#$7f7f,d0	;Power down
		bsr	DoMacKeyWord
		move.w	#$ffff,d0	;Power up
		bsr	DoMacKeyWord
		movem.l	(sp)+,d0-d2/a0-a2
		rts
4$		cmp.b	#$5f,d0		;Help?
		bne	2$
		move.b	#$b6,d0		;Ja, Ctrl-Up
		bsr	DoMacKeycode
		move.b	#$b8,d0		;Shift-Up
		bsr	DoMacKeycode
		move.b	#$ba,d0		;Alt-Up
		bsr	DoMacKeycode
		st.b	ProgSwitch	;NMI auslösen
		rts

2$		cmp.b	#$42,d0		;Tab?
		bne	1$
		move.l	d1,-(sp)
		move.b	d5,d1
		and.b	#~IEQUALIFIER_CAPSLOCK&$ff,d1
		cmp.b	#IEQUALIFIER_CONTROL,d1	;mit Ctrl?
		movem.l	(sp)+,d1
		bne	1$
		JSRSELF	CTTogglePointer	;Ja, Mauszeiger umschalten
		not.b	InputActive
		move.b	#$b6,d0		;Und Ctrl-Up senden (sonst klemmt Ctrl)
		bra	DoMacKeycode

1$		tst.b	InputActive	;Eingabe aktiv?
		beq	DoKeyDone	;Nein, Rückkehr

		move.b	d0,d1
		and.w	#$7f,d0		;d0 - Keycode ohne Flag
		and.w	#$80,d1		;d1 - Up/Down-Flag
		lea	KeyXLate,a0
		move.b	(a0,d0.w),d0	;Keycode übersetzen
		or.b	d1,d0		;d0 - Macintosh-Keycode mit Flag

; Einige Register vorbereiten
DoMacKeycode	move.l	$cf8,d1		;ADBBase
		ble	DoKeyDone
		move.l	d1,a0
		lea	4(a0),a0	;Das erste ADBDevice ist immer die Tastatur
		tst.l	(a0)		;Handler vorhanden?
		beq	DoKeyDone
		move.l	(a0),a1		;Ja, Handler
		move.l	4(a0),a2	; und Data Area holen
		lea	ADBKeyData,a0
		move.b	#2,(a0)		;2 Bytes Daten
		move.b	d0,1(a0)	;Keycode 1
		move.b	#$ff,2(a0)	;Keycode 2
		move.b	#$2c,d0		;Talk 0
		jmp	(a1)		;In Handler einspringen

DoKeyDone	rts

; Both bytes of a keyboard packet from d0.w (the Power key is $7f7f / $ffff)
DoMacKeyWord	move.l	$cf8,d1		;ADBBase
		ble	1$
		move.l	d1,a0
		lea	4(a0),a0
		tst.l	(a0)
		beq	1$
		move.l	(a0),a1
		move.l	4(a0),a2
		lea	ADBKeyData,a0
		move.b	#2,(a0)
		move.w	d0,1(a0)
		move.b	#$2c,d0		;Talk 0
		jmp	(a1)
1$		rts

*
* MouseButtons: Maustasten"abfrage"
*

; Welche Taste?
DoMouseButtons	tst.b	InputActive	;Eingabe aktiv?
		beq	DoMouseDone	;Nein, Rückkehr
		tst.w	MouseDirect
		bne	1$
		cmp.w	#$68,d0		;SelectDown?
		beq	MBSelectDown
		cmp.w	#$e8,d0		;SelectUp?
		beq	MBSelectUp
1$		cmp.w	#$69,d0		;MenuDown?
		beq	MBMenuDown
		cmp.w	#$e9,d0		;MenuUp?
		beq	MBMenuUp
		cmp.w	#$6a,d0		;MiddleDown?
		beq	MBMiddleDown
		cmp.w	#$ea,d0		;MiddleUp?
		beq	MBMiddleUp
DoMouseDone	rts

; Linke Taste gedrückt
MBSelectDown	st.b	MouseIsDown
		move.w	#$0080,d0
		bra	DoMacMouse

; Linke Taste losgelassen
MBSelectUp	clr.b	MouseIsDown
		move.w	#$8080,d0
		bra	DoMacMouse

; Rechte Taste gedrückt -> Option down
MBMenuDown	move.b	#$3a,d0
		bra	DoMacKeycode

; Rechte Taste losgelassen -> Option up
MBMenuUp	move.b	#$ba,d0
		bra	DoMacKeycode

; Mittlere Taste gedrückt -> Shift down
MBMiddleDown	move.b	#$38,d0
		bra	DoMacKeycode

; Mittlere Taste losgelassen -> Shift up
MBMiddleUp	move.b	#$b8,d0
		bra	DoMacKeycode

*
* MouseMove: Maus wurde bewegt
*

DoMouseMove	tst.w	UseAmigaMouse
		bne	4$
		tst.b	InputActive	;Eingabe aktiv?
		beq	5$		;Nein, Rückkehr

		move.b	d4,d0		;Bewegung
		bmi	1$
		addq.b	#1,d0
1$		lsr.b	#1,d0
		ror.w	#8,d0
		swap	d4
		move.b	d4,d0
		bmi	2$
		addq.b	#1,d0
2$		lsr.b	#1,d0

		or.w	#$0080,d0
		tst.b	MouseIsDown	;Maustaste
		bne	3$
		or.w	#$8000,d0
3$		bra	DoMacMouse

4$		sub.w	BoxBorderTop,d4	;Koordinaten auf Fensterinneres begrenzen
		bpl	41$
		clr.w	d4
		bra	42$
41$		cmp.w	ScreenY1+2,d4
		blo	42$
		move.w	ScreenY1+2,d4
		subq.w	#1,d4
42$		swap	d4
		sub.w	BoxBorderLeft,d4
		bpl	43$
		clr.w	d4
		bra	44$
43$		cmp.w	ScreenX1+2,d4
		blo	44$
		move.w	ScreenX1+2,d4
		subq.w	#1,d4
44$		swap	d4
		move.l	d4,AmigaMouseXY
5$		rts


**
** Strings in Datenstrukturen lokalisieren
**

Localize	move.l	_UtilityBase,a6

		lea	TheLocale,a0
		moveq	#MSG_REQTITLE,d0
		jsr	GetString
		move.l	d0,ErrorReq+es_Title
		move.l	d0,TryLargestReq+es_Title
		move.l	d0,ROMChecksumReq+es_Title

		lea	TheLocale,a0
		moveq	#MSG_REQGADS,d0
		jsr	GetString
		move.l	d0,ErrorReq+es_GadgetFormat

		lea	TheLocale,a0
		moveq	#MSG_TRYREQGADS,d0
		jsr	GetString
		move.l	d0,TryLargestReq+es_GadgetFormat
		move.l	d0,ROMChecksumReq+es_GadgetFormat
		rts


**
** Konstanten
**

*
* Strings
*

DosName		dc.b	"dos.library",0
IntuitionName	dc.b	"intuition.library",0
GfxName		dc.b	"graphics.library",0
GadToolsName	dc.b	"gadtools.library",0
UtilityName	dc.b	"utility.library",0
AslName		dc.b	"asl.library",0
IFFParseName	dc.b	"iffparse.library",0
IconName	dc.b	"icon.library",0
LocaleName	dc.b	"locale.library",0
ExpansionName	dc.b	"expansion.library",0
SerialName	dc.b	"serial.device",0
ParallelName	dc.b	"parallel.device",0
SCSIDefName	dc.b	"scsi.device",0
TimerName	dc.b	"timer.device",0
DiskResName	dc.b	"disk.resource",0
CiaResName	dc.b	"ciaa.resource",0
MiscResName	dc.b	"misc.resource",0
FDCResName	dc.b	"dracofdc.resource",0
DracoResName	dc.b	"draco.resource",0
ChipMemName	dc.b	"chip memory",0

CatalogName	dc.b	"ShapeShifter.catalog",0
ROMName		dc.b	"PROGDIR:ShapeShifter ROM",0
PRamName	dc.b	"PROGDIR:ShapeShifter PRAM",0
PrefsDefName	dc.b	"PROGDIR:ShapeShifter Prefs",0

Template	dc.b	"FILE=PREFSFILE,QUICK=QUICKSTART/S,ENFORCER/S,DEBUG/S,NOCOPYBACK/S,720KKLUDGE/S,REMAP8K/S,MACTCPEMUL/S,USKEYMAP/S,NOQDACCEL/S,DEPTHSWITCH/S",0
QuickToolType	dc.b	"QUICKSTART",0
EnforcToolType	dc.b	"ENFORCER",0
DebugToolType	dc.b	"DEBUG",0
NoCBackToolType	dc.b	"NOCOPYBACK",0
Kludge720KToolType dc.b	"720KKLUDGE",0
Remap8KToolType	dc.b	"REMAP8K",0
USKeyMapToolType dc.b	"USKEYMAP",0
NoQDAccelToolType dc.b	"NOQDACCEL",0
DepthSwToolType	dc.b	"DEPTHSWITCH",0

VBLName		dc.b	"ShapeShifter VBlank Int",0
WinIntName	dc.b	"ShapeShifter Window Int",0
TimerIntName	dc.b	"ShapeShifter Timer Int",0
DracoIntName	dc.b	"ShapeShifetr Draco 60Hz Int",0
TimeMgrIntName	dc.b	"ShapeShifter TimeMgr Int",0
VIAIntName	dc.b	"ShapeShifter VIA Int",0
SCCIntName	dc.b	"ShapeShifter SCC Int",0
MainTaskName	dc.b	"ShapeShifter",0
SemaName	SHAPESEMANAME
VersionID	VERSTAG
		CNOP	0,4

*
* Tabellen
*

; Tabelle zur Konvertierung von Mac-ASCII nach ISOLatin1
MacToIso	dc.b	"ÄÅÇÉÑÖÜá"	;128
		dc.b	"àâäãåçéè"	;136
		dc.b	"êëíìîïñó"	;144
		dc.b	"òôöõúùûü"	;152
		dc.b	"+°¢£§·¶ß"	;160 160: dagger
		dc.b	"®© ´¨#ÆØ"	;168 170: TM, 173: notequal
		dc.b	" ±<>¥µðS"	;176 176: infinity, 178: <=, 179: >=, 183: summation
		dc.b	"Pp/ªºOæø"	;184 184: product, 185: pi, 186: integral, 189: Omega
		dc.b	"¿¡¬/f~D«"	;192 195: radical, 196: florin, 197: approxequal, 198: Delta
		dc.b	"». ÀÃÕOo"	;200 201: ellipsis, 206: OE, 207: oe
		dc.b	"--\"\"`\'÷ "	;208 208: endash, 209: emdash, 210: quotedblleft, 211: quotedblright, 212: quoteleft, 213: quoteright, 215: lozenge
		dc.b	"ÿY/¤<>ff"	;216 217: Ydieresis, 222: fi, 223: fl
		dc.b	"#·,",34,"%ÂÊÁ"	;224 224: dbldagger, 225: cdot, 226: quotebase, 227: quotedblbase, 228: perthousand
		dc.b	"ËÈÍÎÏÌÓÔ"	;232
		dc.b	" ÒÚÛÙi^~"	;240 240: apple, 245: dotlessi, 246: circumflex
		dc.b	"¯ ·°¸",34,"¸ "	;248 249: breve, 250: dotaccent, 253: hungarumlaut, 254: ogonek, 255: caron

; Tabelle zur Konvertierung von ISOLatin1 nach Mac-ASCII
IsoToMac	dc.b	"        "	;128
		dc.b	"        "	;136
		dc.b	"        "	;144
		dc.b	"        "	;152
		dc.b	32,193,162,163,219,180,124,164
		dc.b	172,169,187,199,194,45,168,248
		dc.b	161,177,50,51,171,181,166,165	;165 (bullet) oder 225 (cdot)
		dc.b	252,49,188,200,32,32,32,192
		dc.b	203,231,229,204,128,129,174,130
		dc.b	233,131,230,232,237,234,235,236
		dc.b	68,132,241,238,239,205,133,120
		dc.b	175,244,242,243,134,89,32,167
		dc.b	136,135,137,139,138,140,190,141
		dc.b	143,142,144,145,147,146,148,149
		dc.b	182,150,152,151,153,155,154,214
		dc.b	191,157,156,158,159,121,32,216

; Übersetzungstabelle Amiga-Code (Amerik.) -> Mac-Code
KeyXLate	dc.b	$0a,$12,$13,$14,$15,$17,$16,$1a ;` 1 2 3 4 5 6 7
		dc.b	$1c,$19,$1d,$1b,$18,$2a,$ff,$52 ;8 9 0 - = \   0
		dc.b	$0c,$0d,$0e,$0f,$11,$10,$20,$22 ;q w e r t y u i
		dc.b	$1f,$23,$21,$1e,$ff,$53,$54,$55 ;o p [ ]   1 2 3
		dc.b	$00,$01,$02,$03,$05,$04,$26,$28 ;a s d f g h j k
		dc.b	$25,$29,$27,$2a,$ff,$56,$57,$58 ;l ; ' #   4 5 6
		dc.b	$32,$06,$07,$08,$09,$0b,$2d,$2e ;< z x c v b n m
		dc.b	$2b,$2f,$2c,$ff,$41,$59,$5b,$5c ;, . /	 . 7 8 9
		dc.b	$31,$33,$30,$4c,$24,$35,$75,$ff ;spc bsp tab ent ret esc del
		dc.b	$ff,$ff,$4e,$ff,$3e,$3d,$3c,$3b ;         -      cup cdn crg clf
		dc.b	$7a,$78,$63,$76,$60,$61,$62,$64 ; f1  f2  f3  f4  f5  f6  f7  f8
		dc.b	$65,$6d,$47,$51,$4b,$43,$45,$72 ; f9 f10   (   )   /   *   + hlp
		dc.b	$38,$38,$39,$36,$3a,$3a,$37,$37 ;shl shr cap ctl all alr aml amr
		dc.b	$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff ;68-6F
		dc.b	$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff ;70-77
		dc.b	$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff ;78-7F
		CNOP	0,4


*
* Variablen
*

; Einfache Variablen
_ExecBase	dc.l	0	;Für den Linker
_IntuitionBase	dc.l	0
_GfxBase	dc.l	0
_GadToolsBase	dc.l	0
_AslBase	dc.l	0
_UtilityBase	dc.l	0
_EGSBase	dc.l	0
_CyberGfxBase	dc.l	0
_P96Base	dc.l	0
_IFFParseBase	dc.l	0
_IconBase	dc.l	0
_ExpansionBase	dc.l	0
_TimerBase	dc.l	0
_DiskBase	dc.l	0
_CiaBase	dc.l	0
_MiscBase	dc.l	0
_FDCBase	dc.l	0
_AHIBase	dc.l	0

MemBase		dc.l	0	;Speicher
MemTop		dc.l	0
ChipFakeBase	dc.l	0	;Hier werden die Mac-Chips "simuliert"
; Fake SCC without the chip. RR0 = $54: Tx underrun/EOM, Sync/Hunt (line
; idle) and Tx buffer empty set; no Rx character, no Break/Abort. With that
; LocalTalk sends into the void and finds itself alone on the network.
SCCFakeRd	dcb.b	16,$54
SCCFakeWr	dcb.b	16,0
SysStack	dc.l	0	;System-Stack für SuperState/UserState
MacRunning	dc.w	0	;Der Emulator ist im Mac-Modus
NoSuperSwitch	dc.w	0	;>=0: Kein Switch im Supervisor-Modus

CPUType		dc.w	0	;2: 68020, 3: 68030 etc.

TimerOpen	dc.w	0	;Nummer des installierten CIA-Interrupts

MouseYX		dc.w	0	;Hier steht der letze Wert des Mauszählers
AmigaMouseXY	dc.l	0	;Absolute Mausposition für UseAmigaMouse

ADBKeyData	dc.l	0	;Gefakete ADB-Daten von Tastatur und Maus
ADBMouseData	dc.l	0

TickCount	dc.b	0	;Zähler für Ticks in einer Sekunde

DontSwitchEmul	dc.b	0	;#0: Haupttask im Supervisormodus nicht switchen
InputActive	dc.b	0	;#0: Macintosh erhält Input-Events (Tastatur, Maus)
MouseIsDown	dc.b	0	;Für nicht-direkte Mausabfrage: Zustand der Maustaste
EmergShutDown	dc.b	0	;#0: Bei der nächsten Gelegenheit zu PowerOff springen
ProgSwitch	dc.b	0	;#0: NMI auslösen
		CNOP	0,4


**
** Initialisierte Daten
**

		SECTION	"DATA",DATA

; Requester
ErrorReq	dc.l	20,0,0,0,0

; Start options: run-time flag (long), saved option of the CPU tab (word)
StartOptTab	dc.l	NoCopyBack,OptNoCopyBack
		dc.l	Remap8K,OptRemap8K
		dc.l	USKeyMap,OptUSKeyMap
		dc.l	NoQDAccel,OptNoQDAccel
		dc.l	Kludge720K,Opt720K
		dc.l	DebugMode,OptDebug
		dc.l	DepthSwitch,OptDepthSwitch
		dc.l	0

; The 80-byte name fields of the settings (terminated after a load)
PrefsNameTab	dc.l	AFDFileName1,AFDFileName2,AFDFileName3,AFDFileName4
		dc.l	ADDName1,ADDName2,SERDNameA,SERDNameB,Sana2Name
		dc.l	ExtVideoName1,ExtVideoName2
		dc.l	SCSIName0,SCSIName1,SCSIName2,SCSIName3,SCSIName4,SCSIName5,SCSIName6
		dc.l	0
TryLargestReq	dc.l	20,0,0,0,0
ROMChecksumReq	dc.l	20,0,0,0,0

; Taglists für den Dateirequester
FileReqTags	dc.l	ASLFR_SleepWindow,-1
		dc.l	ASLFR_Flags2,FRF_REJECTICONS
		dc.l	ASLFR_Window,0
		dc.l	0

DoEmuReqTags	dc.l	ASLFR_TitleText,0
		dc.l	0

; Taglist für OpenCatalog
CatalogTags	dc.l	OC_Version,40
		dc.l	0

; VBL-Interrupt
		CNOP	0,4
VBLInterrupt	dc.l	0,0
		dc.b	NT_INTERRUPT,0
		dc.l	VBLName
		dc.l	0
		dc.l	IntVBlank

; Timer-Interrupt
		CNOP	0,4
TimerInterrupt	dc.l	0,0
		dc.b	NT_INTERRUPT,0
		dc.l	TimerIntName
		dc.l	0
		dc.l	IntTimer

; Draco-60Hz-Interrupt
		CNOP	0,4
DracoInterrupt	dc.l	0,0
		dc.b	NT_INTERRUPT,0
		dc.l	DracoIntName
		dc.l	0
		dc.l	IntDraco

; Time-Manager-Interrupt
		CNOP	0,4
TimeMgrInterrupt dc.l	0,0
		dc.b	NT_INTERRUPT,0
		dc.l	TimeMgrIntName
		dc.l	0
		dc.l	IntTimeMgr

; VIA-Interrupt
		CNOP	0,4
VIAInterrupt	dc.l	0,0
		dc.b	NT_INTERRUPT,0
		dc.l	VIAIntName
		dc.l	0
		dc.l	IntVIA

; SCC-Interrupt
		CNOP	0,4
SCCInterrupt	dc.l	0,0
		dc.b	NT_INTERRUPT,32
		dc.l	SCCIntName
		dc.l	0
		dc.l	IntSCC

; Interrupt des Fenster-IDCMP
		CNOP	0,4
WindowInterrupt dc.l	0,0
		dc.b	NT_INTERRUPT,0
		dc.l	WinIntName
		dc.l	0
		dc.l	IntWindow

; Interrupt des EGS-Screen-EDCMP
		CNOP	0,4
EGSInterrupt	dc.l	0,0
		dc.b	NT_INTERRUPT,0
		dc.l	WinIntName
		dc.l	0
		dc.l	IntEGS

; PRAM-Icon
		CNOP	0,4
PRAMIcon	dc.w	WB_DISKMAGIC,WB_DISKVERSION
		dc.l	0
		dc.w	0,0,54,23
		dc.w	4,1,1
		dc.l	PRAMI1,0,0,0,0
		dc.w	0
		dc.l	1
		dc.b	WBPROJECT,0
		dc.l	0,0
		dc.l	NO_ICON_POSITION,NO_ICON_POSITION
		dc.l	0,0,0

; Image für PRAM-Icon
PRAMI1		dc.w	0,0,54,22,2
		dc.l	PRAMI1Data
		dc.b	3,0
		dc.l	0

; Icon-Daten
		SECTION	"CHIPDATA",DATA,CHIP
PRAMI1Data	dc.w	$0000,$0000,$0000,$0400,$0000,$0000,$0000,$0C00
		dc.w	$003F,$FC00,$0000,$0C00,$00C0,$0300,$0000,$0C00
		dc.w	$0107,$E080,$0000,$0C00,$0208,$1040,$0000,$0C00
		dc.w	$0204,$1040,$0000,$0C00,$0204,$1040,$0000,$0C00
		dc.w	$0108,$2040,$0000,$0C00,$00F0,$C080,$0000,$0C00
		dc.w	$0007,$01FF,$FFFE,$0C00,$0004,$07FF,$FFFE,$0C00
		dc.w	$0008,$1FF4,$BFFE,$0C00,$0010,$FFFF,$FFF8,$0C00
		dc.w	$0008,$7FF1,$B7FE,$0C00,$0007,$FFFF,$FFFE,$0C00
		dc.w	$0008,$7FFF,$FFFE,$0C00,$0008,$4000,$0000,$0C00
		dc.w	$0007,$8000,$0000,$0C00,$0000,$0000,$0000,$0C00
		dc.w	$0000,$0000,$0000,$0C00,$7FFF,$FFFF,$FFFF,$FC00

		dc.w	$FFFF,$FFFF,$FFFF,$F800,$D555,$5555,$5555,$5000
		dc.w	$D540,$0155,$5555,$5000,$D53F,$FC55,$5555,$5000
		dc.w	$D4F8,$1F55,$5555,$5000,$D5F5,$4F95,$5555,$5000
		dc.w	$D5F9,$4F95,$5555,$5000,$D5F9,$4F95,$5555,$5000
		dc.w	$D4F5,$5F95,$5555,$5000,$D505,$3F19,$9999,$5000
		dc.w	$D550,$FE00,$0000,$5000,$D553,$F800,$0000,$5000
		dc.w	$D557,$E00B,$4000,$5000,$D54F,$0000,$0000,$5000
		dc.w	$D557,$800E,$4800,$5000,$D550,$0000,$0000,$5000
		dc.w	$D557,$8000,$0000,$5000,$D557,$9999,$9998,$5000
		dc.w	$D550,$0000,$0000,$5000,$D555,$5555,$5555,$5000
		dc.w	$D555,$5555,$5555,$5000,$8000,$0000,$0000,$0000


**
** Nicht initialisierte Daten
**

*
* Variablen und Puffer
*

		SECTION "BSS",BSS
FIB		ds.b	260	;FileInfoBlock für ExamineFH()
XPRam		ds.b	256	;Parameter-RAM

PrefsName	ds.b	256	;Puffer für Namen der Prefs-Datei

EValBuf		ds.b	EV_SIZE
EValBuf2	ds.b	EV_SIZE

		CNOP	0,4
CiaTimerReg	ds.l	1	;Basisregister Timer Lo/Hi
CiaControlReg	ds.l	1	;Kontrollregister Timer

TheShapeSema	ds.l	1	;ShapeShifter-Semaphor
UserPort	ds.l	1	;UserPort der Emulator-Fenster
EGSUserPort	ds.l	1	;UserPort für EGS-Screens

ForcedOpts	ds.l	8	;start options as the tooltypes/arguments set them
ForcedSaved	ds.b	1
		CNOP	0,4
TimerIntPort	ds.l	1	;MsgPort mit SoftInt für Time Manager
TimerIO		ds.l	1	;Für Time Manager als "Vorlage"
DracoIntPort	ds.l	1	;MsgPort mit SoftInt für Draco-60Hz-Interrupt
DracoTimerIO	ds.l	1	;Für Draco-60Hz-Interrupt

TheLocale			;Struktur für GetString
_LocaleBase	ds.l	1
TheCatalog	ds.l	1

MyTask		ds.l	1	;Amiga-Multitasking
AmigaVBR	ds.l	1

CLIArgs				;Argumente (Reihenfolge ist wichtig!)
PrefsNameArg	ds.l	1
QuickStart	ds.l	1
EnforcerCompat	ds.l	1
DebugMode	ds.l	1
NoCopyBack	ds.l	1
Kludge720K	ds.l	1
Remap8K		ds.l	1
MacTCPEmul	ds.l	1	;(Argument MACTCPEMUL: wird noch angenommen, hat keine Wirkung)
USKeyMap	ds.l	1
NoQDAccel	ds.l	1
DepthSwitch	ds.l	1	;#0: Farbtiefe auf dem Mac waehlbar (DEPTHSWITCH)

ROMBase		ds.l	1	;ROM-Start
ROMSize		ds.l	1	;ROM-Größe
TheROMMemType	ds.l	1	;Speichertyp für das ROM

MMURoot		ds.l	1	;MMU-Rootpointer
PageSize	ds.l	1	;Seitengröße
PageOffsetMask	ds.l	1	;Bitmaske für Seitenoffset (untere Bits)
PageIndexMask	ds.l	1	;Bitmaske für Seitenindex (obere Bits)

VIABase		ds.l	1	;Zeiger auf echte Mac-Hardware (siehe HasRealVIA etc.)
SCCBase		ds.l	1

Fast8KPtr	ds.l	1	;Zeiger auf umgelenkte 8K
OldPage0	ds.l	1	;Alter Zustand der Seiten 0 und 1
OldPage1	ds.l	1

OldCacheStatus	ds.l	1	;Zustand des Cache vor dem Start

OldVBRTable	ds.l	64	;Alte VBR-Tabelle
NewVBRTable	ds.l	64	;Die Tabelle mit unseren Vektoren (direkt nach OldVBRTable!)

OldLaunchPoint	ds.l	1	;Alte Exec-Vektoren
OldExitIntr	ds.l	1
ExcLogIdx	ds.w	1	;Naechster Eintrag in ExcLog
ExcLogPad	ds.w	1
ExcLog		ds.b	48*32
OldTaskName	ds.l	1	;Name des Tasks vor dem Start
OldTaskPri	ds.b	1
TaskPriChanged	ds.b	1
OldSchedule	ds.l	1

InitialUSP	ds.l	1	;Ursprünglicher Stackpointer

SubtaskSet	ds.l	1	;Signal für Subtask-Erzeugung
SubtaskSig	ds.b	1
		CNOP	0,4

TimeDBRA	ds.w	1	;Prozessorgeschwindigkeit
TimeSCCDBRA	ds.w	1
TimeSCSIDBRA	ds.w	1
TimeRAMDBRA	ds.w	1

AmigaTaskQHdr	ds.b	10	;Queue Header für Amiga-Tasks

ROMSubVersion	ds.b	1	;Sub-Version des ROMs
ROMProtected	ds.b	1	;#0: ROM schreibgeschützt

Remapped8K	ds.b	1	;#0: Untere 8K ins FastRAM umgelenkt

ROMIs68040Comp	ds.b	1	;#0: ROM ist 68040-kompatibel
FixROMFor68040	ds.b	1	;#0: ROM muß für 68040/060 gepatcht werden
HasFPU		ds.b	1	;#0: FPU im Amiga vorhanden
HasMMU		ds.b	1	;#0: Brauchbare MMU vorhanden
Has68060	ds.b	1	;#0: 68060
IsDraco		ds.b	1	;#0: Wir laufen auf dem Draco
MMUHas8KPages	ds.b	1	;#0: MMU läuft mit 8K-Seitengröße
HasRealVIA	ds.b	1	;#0: Echte VIA vorhanden, VIABase gültig
HasRealSCC	ds.b	1	;#0: Echter SCC vorhanden, SCCBase gültig
VBLIntInstalled	ds.b	1	;#0: VBL-Server installiert
SCCIntInstalled	ds.b	1	;#0: SCC-Interrupt installiert
VIAIntInstalled	ds.b	1	;#0: VIA-Interrupt installiert
TrapsInstalled	ds.b	1	;#0: Trap-Handler installiert

ThreadPreEmptive ds.b	1	;#0: In ExitIntr() prä-emptives Scheduling des Thread Managers durchführen

*
* Einstellungen des Benutzers (Anordnung nicht verändern!)
*

		CNOP	0,4
EmulPrefs
LargestBlock	ds.w	1	;Größten freien Speicherblock holen?
MouseDirect	ds.w	1	;#0: Maus direkt abfragen, sonst über Systemroutinen
VideoMode1	ds.w	1	;Nummer des Grafikmodus (VMODE_...)
RefreshRate	ds.w	1	;Anzahl VBLs zwischen Bildschirm-Refresh
BlackBorder	ds.w	1	;Schwarzer Rahmen um den Bildschirm?
FastROM		ds.w	1	;#0: Speicher für ROM zuerst belegen
DisplayID1	ds.l	1	;Display-Modus
ScreenX1	ds.l	1	;Breite des Bildschirms
ScreenY1	ds.l	1	;Höhe des Bildschirms
MemSize		ds.l	1	;Größe des Mac-Speichers
AFDFileName1	ds.b	80	;Name der ersten FileDisk
AFDFileName2	ds.b	80	;Name der zweiten FileDisk
ADDName1	ds.b	80	;Device der ersten DeviceDisk
ADDName2	ds.b	80	;Device der zweiten DeviceDisk
ADDUnit1	ds.l	1	;Unit der ersten DeviceDisk
ADDUnit2	ds.l	1	;Unit der zweiten DeviceDisk
ADDStartSector1 ds.l	1	;Startsektor der ersten DeviceDisk
ADDStartSector2 ds.l	1	;Startsektor der zweiten DeviceDisk
ADDSectors1	ds.l	1	;Anzahl Sektoren der ersten DeviceDisk
ADDSectors2	ds.l	1	;Anzahl Sektoren der zweiten DeviceDisk
SERDNameA	ds.b	80	;Device des Modem-Ports
SERDNameB	ds.b	80	;Device des Drucker-Ports
SERDUnitA	ds.l	1	;Unit des Modem-Ports
SERDUnitB	ds.l	1	;Unit des Drucker-Ports
prefsunused1	ds.b	80	;<>
SCSIEnable	ds.b	1	;SCSI-Geräte einzeln geschaltet
prefsunused2	ds.b	1	;<>
prefsunused3	ds.w	1	;<>
SERDAIsPar	ds.w	1	;Modem-Port ist parallel?
SERDBIsPar	ds.w	1	;Drucker-Port ist parallel?
AppleCD		ds.w	1	;AppleCD-Emulation?
VideoType1	ds.w	1	;Typ der Video-Emulation (VTYPE_...)
VideoType2	ds.w	1
prefsunused4	ds.l	1	;<>
Sana2Name	ds.b	80	;Name des Netzwerk-Treibers
Sana2Unit	ds.l	1	;Unit des Netzwerk-Treibers
VideoMode2	ds.w	1	;Für zweiten Monitor...
BlackBorder2	ds.w	1
DisplayID2	ds.l	1
ScreenX2	ds.l	1
ScreenY2	ds.l	1
ProtectROM	ds.w	1	;#0: ROM schreibschützen
SCSIMemType	ds.w	1	;SCSI-Speichertyp
OverscanType1	ds.w	1	;Overscan-ID für ersten Monitor
OverscanType2	ds.w	1	;für zweiten Monitor
prefsunused5	ds.w	1	;<>
NumMonitors	ds.w	1	;Anzahl Monitore minus 1
ADDMaxTransfer1	ds.l	1	;Maximale Blocktransfers der DeviceDisks
ADDMaxTransfer2	ds.l	1
AppleHD		ds.w	1	;AppleHD-Emulation?
Floppy1		ds.w	1	;Unit des ersten Diskettenlaufwerkes
Floppy2		ds.w	1	;Unit des zweiten Diskettenlaufwerkes
BootFrom	ds.w	1	;0: Egal, 1: FileDisk1, 2: DeviceDisk1, 3: Löschen
InhibitFloppy1	ds.w	1	;#0: Floppy 1 inhibiten
InhibitFloppy2	ds.w	1	;#0: Floppy 2 inhibiten
RefreshAlways	ds.w	1	;#0: Immer refreshen (auch in 8 Bit)
ExtVideoName1	ds.b	80	;Name des externen Videotreibers
UseAmigaMouse	ds.w	1	;#0: Amiga-Mauszeiger benutzen
ADDRemovable1	ds.w	1	;#0: DeviceDisk 1 ist Wechselmedium
ADDRemovable2	ds.w	1	;#0: DeviceDisk 2 ist Wechselmedium
MMURefresh	ds.w	1	;#0: MMU zum Refreshen benutzen
SCSIName0	ds.b	80	;Treiber der SCSI-IDs
SCSIName1	ds.b	80
SCSIName2	ds.b	80
SCSIName3	ds.b	80
SCSIName4	ds.b	80
SCSIName5	ds.b	80
SCSIName6	ds.b	80
SCSIUnit0	ds.l	1	;Einheiten der SCSI-IDs
SCSIUnit1	ds.l	1
SCSIUnit2	ds.l	1
SCSIUnit3	ds.l	1
SCSIUnit4	ds.l	1
SCSIUnit5	ds.l	1
SCSIUnit6	ds.l	1
AudioOn		ds.w	1	;#0: Audio-Support an
ROMMemType	ds.w	1	;ROM-Speichertyp
ExtVideoName2	ds.b	80	;Name des zweiten externen Videotreibers
SCSIDirect	ds.w	1	;#0: Direkte SCSI-Transfers, wenn möglich
UseSCCSerial	ds.w	1	;#0: Original serielle Treiber benutzen
FastCrapMode	ds.w	1	;#0: z3scsi.device sucks!
UseAHI		ds.w	1	;#0: ahi.device für Sound benutzen
AudioID		ds.l	1	;AHI Audio-Mode
MacOS8Mode	ds.w	1	;#0: Quadra900-ModelID bei 1MB-ROM verwenden
; Startoptionen aus dem CPU-Tab (wie die gleichnamigen Tooltypes), seit 3.20
OptNoCopyBack	ds.w	1	;#0: NOCOPYBACK
OptRemap8K	ds.w	1	;#0: REMAP8K
OptEnforcer	ds.w	1	;#0: ENFORCER
OptMacTCP	ds.w	1	;unbenutzt (war MACTCPEMUL); bleibt wegen des Dateiformats
OptUSKeyMap	ds.w	1	;#0: USKEYMAP
OptNoQDAccel	ds.w	1	;#0: NOQDACCEL
Opt720K	ds.w	1	;#0: 720KKLUDGE
OptDebug	ds.w	1	;#0: DEBUG
AFDFileName3	ds.b	80	;Name der dritten FileDisk
AFDFileName4	ds.b	80	;Name der vierten FileDisk
OptDepthSwitch	ds.w	1	;#0: DEPTHSWITCH
OptAdvanced	ds.w	1	;#0: settings window shows every page (else the four everyday ones)
EmulPrefsEnd

		END
