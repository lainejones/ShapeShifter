**
** Macintosh LC-Emulator
**
** Copyright 1993 Christian Bauer
**
** CIA-A Timer A: Tastatur
** CIA-A Timer B: Time Manager
** CIA-B Timer B: Disk Driver
**


**
** Definitionen
**

; Einstellungen des Benutzers
LoRes		= 0		;0 - HiRes interlace, 1 - LoRes nonlace
ScreenX		= 640		;Größe des (virtuellen) Bildschirms in Pixeln
ScreenY		= 512
OffsetX		= $81		;Bildschirm-Zentrierung (in LoRes-Pixeln)
OffsetY		= $2c
NumPlanes	= 1		;Bittiefe des Bildschirms (1,2,4 oder 8)
EDiskCapable	= 1		;1 - Erweiterungen für EDisk assemblieren
ThirtyTwo	= 0		;1 - FastRAM benutzen

; Grafik
WordsPerRow	= (ScreenX+15)/16
BytesPerRow	= WordsPerRow*2
PlaneBytes	= BytesPerRow*ScreenY
ScreenBytes	= NumPlanes*PlaneBytes
	ifeq	LoRes
VisibleX	= ScreenX/2	;Größe des sichtbaren Bereiches (in LoRes-Pixeln)
VisibleY	= ScreenY/2
	endc
	ifne	LoRes
VisibleX	= ScreenX
VisibleY	= ScreenY
	endc
DiwStart	= (OffsetX&$ff)+(OffsetY&$ff)*$100
DiwStop		= ((OffsetX+VisibleX)&$ff)+((OffsetY+VisibleY)&$ff)*$100
	ifeq	NumPlanes-8
BplConTmp	= $0011
	endc
	ifne	NumPlanes-8
BplConTmp	= $0001+NumPlanes*$1000
	endc
	ifeq	LoRes
DDFStart	= (OffsetX-1)/2-4
DDFStop		= DDFStart+4*(WordsPerRow-2)
BplCon0		= BplConTmp+$8004
BplMod		= BytesPerRow
	endc
	ifne	LoRes
DDFStart	= (OffsetX-1)/2-8
DDFStop		= DDFStart+8*(WordsPerRow-1)
BplCon0		= BplConTmp
BplMod		= 0
	endc
SetCol	macro	;Nummer R G B
	move.w	#(\2*$f/$ffff)*$100+(\3*$f/$ffff)*$10+(\4*$f/$ffff),$dff180+\1*2
	endm

; ROMs
ROMSize		= $080000
OrigROMBase	= $a00000		;Adresse des ROMs im Mac LC
ROMEntry	= $136			;Einsprung ins ROM, Offset zu ROMBase
EDiskROMSize	= $060000
EDiskOffset	= $020000		;Offset zu EDiskROMBase

; Speicher: Grundvariablen
CopperSize	= $200			;Länge der Copperlisten
MFMBufSize	= $6800			;Größe des MFM-Puffers
TrackBufSize	= 512*18		;18 Sektoren à 512 Byte
ChipTop		= $00200000		;Obergrenze des Chip-Memory
FastBase	= $07e00000		;Untergrenze des Fast-Memory
FastTop		= $08000000		;Obergrenze des Fast-Memory
ChipAvailFlags	= $773f

; Aufteilung des Chip-Memory
EDiskROMStart	= ChipTop-EDiskROMSize	;Max. für den Emulator verfügbares RAM
	ifeq	EDiskCapable
CopperBase	= ChipTop-CopperSize	;Hier liegen die Copperlisten
	endc
	ifne	EDiskCapable
CopperBase	= EDiskROMStart-CopperSize
	endc
ScrnBase	= CopperBase-ScreenBytes;Hier liegt der Grafikspeicher
	ifeq	NumPlanes-1
PlanesBase	= ScrnBase		;Ab hier wird dargestellt
	endc
	ifne	NumPlanes-1
PlanesBase	= ScrnBase-ScreenBytes
	endc
Plane1Base	= PlanesBase
Plane2Base	= PlanesBase+PlaneBytes
Plane3Base	= PlanesBase+PlaneBytes*2
Plane4Base	= PlanesBase+PlaneBytes*3
Plane5Base	= PlanesBase+PlaneBytes*4
Plane6Base	= PlanesBase+PlaneBytes*5
Plane7Base	= PlanesBase+PlaneBytes*6
Plane8Base	= PlanesBase+PlaneBytes*7
DiskBufBase	= PlanesBase-MFMBufSize	;MFM-Puffer für Laufwerk

; Speicher des Macintosh
	ifeq	ThirtyTwo
MemBase		= $2000			;Lage der SystemZone ($07e00000)
MemTop		= DiskBufBase		;Obergrenze des Mac-Speichers ($08000000)
ChipBase	= $07ff0000		;Hier werden dem Mac die Custom-Chips vorgegaukelt
PtrMask		= $00ffffff		;Maske für 24-Bit-Zeiger
	endc
	ifne	ThirtyTwo
MemBase		= FastBase
MemTop		= FastTop-ROMSize
ChipBase	= DiskBufBase-$4000
PtrMask		= $07ffffff		;Maske für 24-Bit-Zeiger
	endc
BufPtr		= MemTop
InitStack	= (MemBase+MemTop)/2	;Stackpointer bei Reset

; LVOs
Supervisor	= -30
AllocMem	= -198
FreeMem		= -210
WaitPort	= -384
OpenLibrary	= -408
CloseLibrary	= -414

Open		= -30
Close		= -36
Read		= -42
LoadSeg		= -150
UnLoadSeg	= -156

CloseWindow	= -72
LockPubScreen	= -510
UnlockPubScreen	= -516
EasyRequest	= -588
OpenWindowTags	= -606

CreateGadget	= -30
FreeGadgets	= -36
GetIMsg		= -72
ReplyIMsg	= -78
RefreshWindow	= -84
BeginRefresh	= -90
EndRefresh	= -96
CreateContext	= -114
GetVisualInfo	= -126
FreeVisualInfo	= -132


**
** Hauptprogramm
**

*
* Libraries öffnen
*

; DOS-Library öffnen
Main		move.l	(4).w,a6
		lea	DosName(pc),a1
		jsr	OpenLibrary(a6)
		move.l	d0,DOSBase
		beq	NoDOS

; Intuition-Library öffnen
		lea	IntuitionName(pc),a1
		jsr	OpenLibrary(a6)
		move.l	d0,IntuitionBase
		beq	NoIntui

; GadTools-Library öffnen
		lea	GadToolsName(pc),a1
		jsr	OpenLibrary(a6)
		move.l	d0,GadToolsBase
		beq	NoGadTools

*
* Options-Fenster darstellen
*

; Screen locken
		move.l	IntuitionBase(pc),a6
		sub.l	a0,a0
		jsr	LockPubScreen(a6)
		move.l	d0,Screen
		beq	Exit

; VisualInfo erzeugen
		move.l	GadToolsBase(pc),a6
		move.l	Screen(pc),a0
		sub.l	a1,a1
		jsr	GetVisualInfo(a6)
		move.l	d0,VisualInfo
		beq	Exit

; Context erzeugen
		lea	GList(pc),a0
		jsr	CreateContext(a6)

; Checkpoint-Checkbox-Gadget erzeugen
		move.l	d0,a0
		moveq	#2,d0		;checkboxKind
		lea	NewGadget(pc),a1
		move.w	#16,(a1)
		move.w	#16,2(a1)
		move.w	#26,4(a1)
		move.w	#11,6(a1)
		move.l	#CheckGText,8(a1)
		move.w	#1,16(a1)	;gid
		move.l	#2,18(a1)	;flags
		sub.l	a2,a2
		tst.w	CheckOn
		beq	1$
		lea	CheckboxTags(pc),a2
1$		jsr	CreateGadget(a6)

; Exception-Gadget erzeugen
		move.l	d0,a0
		moveq	#2,d0		;checkboxKind
		lea	NewGadget(pc),a1
		add.w	#12,2(a1)
		move.l	#ExceptionGText,8(a1)
		move.w	#2,16(a1)	;gid
		move.l	#2,18(a1)	;flags
		sub.l	a2,a2
		tst.w	ExceptionOn
		beq	2$
		lea	CheckboxTags(pc),a2
2$		jsr	CreateGadget(a6)

; BusErr-Gadget erzeugen
		move.l	d0,a0
		moveq	#2,d0		;checkboxKind
		lea	NewGadget(pc),a1
		add.w	#12,2(a1)
		move.l	#BusErrGText,8(a1)
		move.w	#3,16(a1)	;gid
		move.l	#2,18(a1)	;flags
		sub.l	a2,a2
		tst.w	BusErrOn
		beq	3$
		lea	CheckboxTags(pc),a2
3$		jsr	CreateGadget(a6)

; LoadEDisk-Gadget erzeugen
		move.l	d0,a0
		moveq	#2,d0		;checkboxKind
		lea	NewGadget(pc),a1
		add.w	#12,2(a1)
		move.l	#LoadEDiskGText,8(a1)
		move.w	#4,16(a1)	;gid
		move.l	#2,18(a1)	;flags
		sub.l	a2,a2
		tst.w	LoadEDisk
		beq	4$
		lea	CheckboxTags(pc),a2
4$		jsr	CreateGadget(a6)

; BootEDisk-Gadget erzeugen
		move.l	d0,a0
		moveq	#2,d0		;checkboxKind
		lea	NewGadget(pc),a1
		add.w	#12,2(a1)
		move.l	#BootEDiskGText,8(a1)
		move.w	#5,16(a1)	;gid
		move.l	#2,18(a1)	;flags
		sub.l	a2,a2
		tst.w	BootEDisk
		beq	5$
		lea	CheckboxTags(pc),a2
5$		jsr	CreateGadget(a6)

; OK-Gadget erzeugen
		move.l	d0,a0
		moveq	#1,d0		;buttonKind
		lea	NewGadget(pc),a1
		move.w	#32,(a1)
		add.w	#16,2(a1)
		move.w	#80,4(a1)
		move.w	#12,6(a1)
		move.l	#OKGText,8(a1)
		move.w	#16,16(a1)	;gid
		move.l	#16,18(a1)	;flags
		sub.l	a2,a2
		jsr	CreateGadget(a6)

; Cancel-Gadget erzeugen
		move.l	d0,a0
		moveq	#1,d0		;buttonKind
		lea	NewGadget(pc),a1
		move.w	#180,(a1)
		move.l	#CancelGText,8(a1)
		move.w	#17,16(a1)	;gid
		move.l	#16,18(a1)	;flags
		sub.l	a2,a2
		jsr	CreateGadget(a6)
		tst.l	d0
		beq	Exit

; Fenster öffnen
		move.l	IntuitionBase(pc),a6
		sub.l	a0,a0
		lea	WindowTags(pc),a1
		jsr	OpenWindowTags(a6)
		move.l	d0,Window
		beq	Exit

; Fenster refreshen
		move.l	GadToolsBase(pc),a6
		move.l	Window(pc),a0
		sub.l	a1,a1
		jsr	RefreshWindow(a6)

; EventLoop
		moveq	#0,d7

EventLoop	tst.l	d7
		bne	WindowDone

		move.l	(4).w,a6
		move.l	Window(pc),a0
		move.l	86(a0),a0	;userPort
		jsr	WaitPort(a6)

		move.l	GadToolsBase(pc),a6
		move.l	Window(pc),a0
		move.l	86(a0),a0
		jsr	GetIMsg(a6)
		move.l	d0,a5

		btst	#6,23(a5)	;gadgetUp?
		beq.s	NotGadget
		move.l	28(a5),a0
		cmp.w	#16,38(a0)	;OK?
		bne	1$
		moveq	#1,d7		;Beenden
		bra.s	EventReply
1$		cmp.w	#17,38(a0)	;Cancel?
		bne	2$
		moveq	#-1,d7		;Beenden
		bra	EventReply
2$		cmp.w	#1,38(a0)	;CheckOn?
		bne	3$
		not.w	CheckOn
		bra	EventReply
3$		cmp.w	#2,38(a0)	;ExceptionOn?
		bne	4$
		not.w	ExceptionOn
		bra	EventReply
4$		cmp.w	#3,38(a0)	;BusErrOn?
		bne	5$
		not.w	BusErrOn
		bra	EventReply
5$		cmp.w	#4,38(a0)	;LoadEDisk?
		bne	6$
		not.w	LoadEDisk
		bra	EventReply
6$		cmp.w	#5,38(a0)	;BootEDisk?
		bne	6$
		not.w	BootEDisk
		bra	EventReply
7$		bra	EventReply

NotGadget	btst	#2,23(a5)	;refresh?
		beq	EventReply
		move.l	Window(pc),a0
		jsr	BeginRefresh(a6)
		move.l	Window(pc),a0
		moveq	#-1,d0
		jsr	EndRefresh(a6)

EventReply	move.l	a5,a1
		jsr	ReplyIMsg(a6)
		bra	EventLoop

; Fenster schließen
WindowDone	move.l	IntuitionBase(pc),a6
		move.l	Window(pc),a0
		jsr	CloseWindow(a6)
		cmp.l	#-1,d7
		beq	Exit

*
* Speicher anfordern
*

; Speicher für LC-ROM anfordern
		move.l	(4).w,a6
		move.l	#ROMSize,d0
		move.l	#0,d1
		jsr	AllocMem(a6)
		move.l	d0,ROMBase
		beq	Exit

; Speicher für Track-Puffer anfordern
		move.l	#TrackBufSize,d0
		move.l	#0,d1
		jsr	AllocMem(a6)
		move.l	d0,TrackBufBase
		beq	Exit

; Speicher für EDisk anfordern
	ifne	EDiskCapable
		move.l	#EDiskROMStart,EDiskROMBase
		move.l	#EDiskROMStart+EDiskOffset,EDiskBase
	endc

*
* ROMs und Treiber laden
*

; LC-ROM laden
		move.l	DOSBase(pc),a6
		move.l	#FileName,d1		;Datei öffnen
		move.l	#1005,d2		;oldFile
		jsr	Open(a6)
		move.l	d0,d7
		beq	Exit

		move.l	d7,d1			;Datei laden
		move.l	ROMBase(pc),d2
		move.l	#ROMSize,d3
		jsr	Read(a6)
		move.l	d0,d6

		move.l	d7,d1			;Datei schließen
		jsr	Close(a6)

		cmp.l	#ROMSize,d6		;Gelungen?
		bne	Exit

; EDisk-ROM laden, wenn erwünscht
	ifne	EDiskCapable
		tst.w	LoadEDisk
		beq	NoEDisk
		move.l	#FileName2,d1		;Datei öffnen
		move.l	#1005,d2		;oldFile
		jsr	Open(a6)
		move.l	d0,d7
		beq	Exit

		move.l	d7,d1			;Datei laden
		move.l	EDiskROMBase(pc),d2
		move.l	#EDiskROMSize,d3
		jsr	Read(a6)
		move.l	d0,d6

		move.l	d7,d1			;Datei schließen
		jsr	Close(a6)

		cmp.l	#EDiskROMSize,d6	;Gelungen?
		bne	Exit
	endc

; Floppy-Treiber laden
NoEDisk		move.l	#FileName3,d1		;Programm laden
		jsr	LoadSeg(a6)
		move.l	d0,DiskDriverSeg
		beq	Exit

		add.l	d0,d0			;Länge und Basisadresse speichern
		add.l	d0,d0
		move.l	d0,a0
		move.l	-4(a0),d0
		addq.l	#4,a0
		move.l	a0,DiskDriverBase
		move.l	d0,DiskDriverLen

*
* Rückfrage beim Benutzer, bevor das Multitasking abgeschaltet wird
*

		move.l	IntuitionBase(pc),a6
		sub.l	a0,a0
		lea	EasyStruct(pc),a1
		sub.l	a2,a2
		sub.l	a3,a3
		jsr	EasyRequest(a6)
		tst.l	d0
		beq	Exit

*
* In Supervisormodus gehen
*

		move.l	(4).w,a6
		lea	Super(pc),a5
		jsr	Supervisor(a6)

*
* Copperlisten kopieren
*

Super		lea	CopList(pc),a0
		lea	CopperBase,a1
		move	CopSize,d0
1$		move.b	(a0)+,(a1)+
		dbra	d0,1$

*
* ROM patchen
*

		move.l	ROMBase(pc),a3

; Reset-Einsprünge auf eigene Routine richten
		move.w	#ROMEntry-$c,$c(a3)
		move.w	#ROMEntry-$10,$10(a3)
		lea	ROMEntry(a3),a0
		move.w	#$4ef9,(a0)+		;jmp	DoReset
		move.l	#DoReset,(a0)

; Beginn der SysZone
		move.l	#MemBase,$518(a3)
		move.l	#MemBase+$1800,$51c(a3)

; 24-Bit-Maske verändern
		move.l	#PtrMask,$11a2(a3)

; Stack im 32-Bit-Modus nicht bei $400000 einrichten
		move.w	#$600c,$5c4(a3)

; Traps patchen
		move.w	#$4eb9,$1ca(a3)		;jsr	PatchTraps
		move.l	#PatchTraps,$1cc(a3)
		move.l	#$4e714e71,$1d0(a3)	;nop

; EDisk-Treiber installieren
	ifne	EDiskCapable
		tst.w	BootEDisk
		beq	DontBootEDisk
		move.w	#$4eb9,$113e(a3)	;jsr	InstallEDisk
		move.l	#InstallEDisk,$1140(a3)

		move.l	EDiskROMBase(pc),a0	;Endadresse für EDisk-Suche
		add.l	#$1e274,a0
		move.l	#EDiskROMStart,(a0)
	endc

; Grafiktreiber installieren
DontBootEDisk	move.w	#$4ef9,$f40(a3)		;jmp	SetGDevice
		move.l	#SetGDevice,$f42(a3)

; Floppy-Disk-Treiber überschreiben
		move.l	a3,a0
		add.l	#$6c3e0,a0
		move.l	DiskDriverBase(pc),a1
		move.l	DiskDriverLen(pc),d0
5$		move.b	(a1)+,(a0)+
		dbra	d0,5$
		move.l	a3,a0
		add.l	#$6c3e0,a0
		move.l	#DiskBufBase,$18(a0)
		move.l	TrackBufBase,$1c(a0)

; ADB-Init patchen (sonst Endlosschleife (wartet auf Interrupt))
		move.l	a3,a0
		add.l	#$a8ec,a0
		move.w	#$4e71,(a0)		;nop

; Relokationen
		moveq	#62,d7
		move.l	#$46044,d6
4$		move.l	d6,d0
		bsr	Reloc
		addq.l	#4,d6
		dbra	d7,4$

; Gestalt-Patch
		move.l	a3,a0
		add.l	#$167ea,a0
		move.l	#ChipBase,(a0)		;Gestalt VIA 2

; Simulierten Chip-Bereich löschen
		lea	ChipBase,a0
		move.w	#$3fff,d0
6$		clr.l	(a0)+
		dbra	d0,6$

; Prozessorgeschwindigkeitstest ersetzen
		lea	$800(a3),a0
		move.l	#$31fc1000,(a0)+	;move.w	#$1000,$d00
		move.w	#$0d00,(a0)+
		move.l	#$31fc1000,(a0)+	;move.w	#$1000,$d02
		move.w	#$0d02,(a0)+
		move.l	#$31fc1000,(a0)+	;move.w	#$1000,$b24
		move.w	#$0b24,(a0)+
		move.l	#$31fc1000,(a0)+	;move.w	#$1000,$cea
		move.w	#$0cea,(a0)+
		move.w	#$4e75,(a0)+		;rts

; Einsprung in System-Data-Fork überspringen
		move.w	#$4e71,$1ea4(a3)	;nop

; Bei Execption: Roter Schirm
		tst.w	ExceptionOn
		beq	NoException
		lea	$26a0(a3),a0
		move.w	#$4ef9,(a0)+		;jmp	Exception
		move.l	#Exception,(a0)

; Bei Checkpoint: Grüner Schirm
NoException	tst.w	CheckOn
		beq	NoCheck
		move.l	a3,a0
		add.l	CheckPoint(pc),a0
		move.w	#$4ef9,(a0)+		;jmp	Check
		move.l	#Check,(a0)

*
* Ins ROM springen, Emulation starten
*

NoCheck		clr.l	$cfc			;WarmStart löschen
		lea	ROMEntry(a3),a0
		jmp	(a0)


*
* Fehlerbehandlung
*

Exit		move.l	Window(pc),d0
		beq	ExitWindow
		move.l	d0,a0
		move.l	IntuitionBase(pc),a6
		jsr	CloseWindow(a6)

ExitWindow	move.l	GadToolsBase(pc),a6
		move.l	GList(pc),a0
		jsr	FreeGadgets(a6)

		move.l	VisualInfo(pc),d0
		beq	ExitVisual
		move.l	d0,a0
		jsr	FreeVisualInfo(a6)

ExitVisual	move.l	Screen(pc),d0
		beq	ExitScreen
		move.l	d0,a0
		move.l	IntuitionBase(pc),a6
		jsr	UnlockPubScreen(a6)

ExitScreen	move.l	DiskDriverSeg(pc),d1
		beq	ExitSeg
		move.l	DOSBase(pc),a6
		jsr	UnLoadSeg(a6)

ExitSeg		move.l	(4).w,a6
		move.l	TrackBufBase(pc),d0
		beq	ExitTrackBuf
		move.l	d0,a1
		move.l	#TrackBufSize,d0
		jsr	FreeMem(a6)

ExitTrackBuf	move.l	ROMBase(pc),d0
		beq	ExitROM
		move.l	d0,a1
		move.l	#ROMSize,d0
		jsr	FreeMem(a6)

ExitROM		move.l	GadToolsBase(pc),a1
		jsr	CloseLibrary(a6)
NoGadTools	move.l	IntuitionBase(pc),a1
		jsr	CloseLibrary(a6)
NoIntui		move.l	DOSBase(pc),a1
		jsr	CloseLibrary(a6)
NoDOS		moveq	#0,d0
		rts

*
* Adresse relozieren (Offset in d0)
*

Reloc		move.l	a3,a0
		sub.l	#OrigROMBase,0(a0,d0.l)
		move.l	a3,d0
		add.l	d0,(a0)
		rts


**
** Patches
**

*
* Reset-Routine
*

; CPU initialisieren
DoReset		move.b	#$03,$bfe201

		lea	InitStack,a7
		move.l	#InitStack,d0
		dc.w	$4e7b,$0800	;movec	d0,usp
		dc.w	$4e7b,$0803	;movec	d0,msp
		dc.w	$4e7b,$0804	;movec	d0,isp
		moveq	#0,d0
		dc.w	$4e7b,$0801	;movec	d0,vbr
		move.w	#$2700,sr
		move.w	#$0808,d0
		dc.w	$4e7b,$0002	;movec	d0,cacr

; DMA abschalten
		move.w	#$7fff,$dff096

; Grafik einrichten
		move.w	#0,$dff1fc		;FMode
		move.w	#BplCon0,$dff100	;Hires, 1 Bitplane, Interlace
		move.w	#BplMod,$dff108		;Modulo
		move.w	#BplMod,$dff10a
		move.w	#0,$dff10c		;BplHMod
		move.w	#0,$dff102		;Scrolling
		move.w	#$0020,$dff106		;BorderBlank
		move.w	#DiwStart,$dff08e	;Display-Window Start
		move.w	#DiwStop,$dff090	;Display-Window Stop
		move.w	#DDFStart,$dff092	;Display-Data-Fetch Start
		move.w	#DDFStop,$dff094	;Display-Data-Fetch Stop
		move.w	#0,$dff142		;Sprite abschalten
	ifeq	NumPlanes-1
		SetCol	0,$ffff,$ffff,$ffff	;2 Farben
		SetCol	1,$0000,$0000,$0000
	endc
	ifeq	NumPlanes-2
		SetCol	0,$ffff,$ffff,$ffff
		SetCol	1,$acac,$acac,$acac
		SetCol	2,$5555,$5555,$5555
		SetCol	3,$0000,$0000,$0000
	endc
	ifeq	NumPlanes-4
		SetCol	0,$ffff,$ffff,$ffff	;16 Farben
		SetCol	1,$fc00,$f37d,$052f
		SetCol	2,$ffff,$648a,$028C
		SetCol	3,$dd6b,$08c2,$06a2
		SetCol	4,$f2d7,$0856,$84ec
		SetCol	5,$46e3,$0000,$a53e
		SetCol	6,$0000,$0000,$d400
		SetCol	7,$0241,$64af,$11b0
		SetCol	8,$1f21,$b793,$1431
		SetCol	9,$0000,$64af,$11b0
		SetCol	10,$5600,$2c9d,$0524
		SetCol	11,$90d7,$7160,$3a34
		SetCol	12,$c000,$c000,$c000
		SetCol	13,$8000,$8000,$8000
		SetCol	14,$4000,$4000,$4000
		SetCol	15,$0000,$0000,$0000
	endc

; Copper starten
1$		btst	#7,$dff004
		beq.s	1$
		move.l	#CopperBase,$dff080
		move.w	#0,$dff088

; DMA anschalten
		move.w	#$8380,$dff096

; Interrupts sperren
		move.w	#$7fff,$dff09a
		move.w	#$7fff,$dff09c
		move.b	#$7f,$bfed01
		move.b	#$7f,$bfdd00

; Register/Variablen setzen/löschen
		lea	MachDef(pc),a2
		move.l	a2,$dd8
		move.l	$18(a2),$dd0
		move.l	$1c(a2),$dd4	;#0: Parity RAM Installed
		move.w	$10(a2),$b22	;HWCfgFlags
					;#9 : A/UX vorhanden
					;#10: SCC vorhanden
					;#12: FPU vorhanden
					;#15: ???
		moveq	#0,d7
		move.b	$12(a2),d7	;ModelID (LC II)
		swap	d7
		move.w	#3,d7		;CPUFlags (68030)

		lea	MMUInfo(pc),a4	;MMUInfo
		lea	BufPtr,a5	;BufPtr
		lea	MemTop,a6	;MemTop

; Da der Stackpointer verändert wurde, müssen wir direkt zurückspringen
		move.l	ROMBase(pc),a0
		lea	ROMEntry+6(a0),a0
		jmp	(a0)

*
* Routine für Exception/Check
*

Exception	move.w	#$f00,$dff180	;Roter Bildschirm
		bra	CoreDump
Check		move.w	#$0f0,$dff180	;Grüner Bildschirm
CoreDump	movem.l	d0-d7/a0-a7,$07ff0000	;Register retten
		move.l	ROMBase(pc),$07ff0040	;ROMBase retten
		lea	$0,a0		;Die untersten 64K kopieren
		lea	$180000,a1
		move.w	#$0fff,d0
1$		move.l	(a0)+,(a1)+
		dbra	d0,1$
		stop	#$2700		;Prozessor anhalten

*
* Traps und Interrupts patchen
*

PatchTraps	move.l	ROMBase(pc),a0	;Wegen Patch
		add.l	#$9a96,a0
		jsr	(a0)

		move.l	#ReadXPRam,a0
		move.w	#$a051,d0
		dc.w	$a247		;SetOSTrapAddress

		move.l	#WriteXPRam,a0
		move.w	#$a052,d0
		dc.w	$a247		;SetOSTrapAddress

		move.l	#ADBReInit,a0
		move.w	#$a07b,d0
		dc.w	$a247		;SetOSTrapAddress

		move.l	#ADBOp,a0
		move.w	#$a07c,d0
		dc.w	$a247		:SetOSTrapAddress

		move.l	#EgretDispatch,a0
		move.w	#$a092,d0
		dc.w	$a247		;SetOSTrapAddress

		move.l	#SysBeep,a0
		move.w	#$a9c8,d0
		dc.w	$a047		;SetTrapAddress

		move.l	#ZeroDivide,$14	;Neue Division-by-Zero-Routine

		move.w	$dff00a,MouseYX	;Mausabfrage initialisieren

		move.b	#54,$bfe401	;CIA-A für Tastatur vorbereiten
		move.b	#0,$bfe501
		move.b	#$18,$bfee01

		move.b	#$cc,$bfe601	;CIA-A Timer B für Time Manager vorbereiten
		move.b	#$02,$bfe701	;Frequenz: 1000 Hz
		move.b	#$11,$bfef01

		move.l	#IntCIAA,$68	;Level 2: CIA-A
		move.l	#IntVBlank,$6c	;Level 3: VBlank
		move.w	#$c028,$dff09a	;VBlank und CIA-A erlauben
		move.b	#$8a,$bfed01	;SP und Timer B erlauben (Tastatur/Time Mgr)
		rts

*
* Lesen des erweiterten Parameter-RAMs
*

ReadXPRam	movem.l	a0-a1,-(sp)
		lea	XPRam(pc),a1
		add.w	d0,a1
		swap	d0
		subq.w	#1,d0
1$		move.b	(a1)+,(a0)+
		dbra	d0,1$
		movem.l	(sp)+,a0-a1
		moveq	#0,d0
		rts

*
* Schreiben des erweiterten Parameter-RAMs
*

WriteXPRam	movem.l	a0-a1,-(sp)
		lea	XPRam(pc),a1
		and.w	#$ff,d0
		add.w	d0,a1
		swap	d0
		subq.w	#1,d0
1$		move.b	(a0)+,(a1)+
		dbra	d0,1$
		movem.l	(sp)+,a0-a1
		moveq	#0,d0
		rts

*
* ADB Initialisieren
*

ADBReInit	moveq	#0,d0
		rts

*
* ABD-Operation
*

ADBOp		cmp.b	#$2f,d0
		bne	ADBOpOK
		move.l	8(a0),a0
		st	(a0)
ADBOpOK		moveq	#0,d0
		rts

*
* Egret
*

EgretDispatch	moveq	#0,d0
		rts

*
* SysBeep - Menüleiste blinken lassen
*

SysBeep		movem.l	d0-d7/a1-a6,-(sp)
		move	sr,d0
		andi.w	#$0700,d0
		bne	NoSysBeep
		tst.b	$8f2
		bne	NoSysBeep
		clr.l	-(sp)
		dc.w	$a94c		;FlashMenuBar
		sub.l	a0,a0
		addq.w	#8,a0
		dc.w	$a03b		;Delay
		dc.w	$a94c		;FlashMenuBar
NoSysBeep	movem.l	(sp)+,d0-d7/a1-a6
		move.l	(sp)+,a0
		addq.w	#2,sp
		jmp	(a0)

*
* Divide-by-Zero-Routine, die den Befehl wiederholt
*

ZeroDivide	tst.l	d5
		bne	1$
		moveq	#1,d5
		move.l	8(sp),2(sp)
1$		rte

*
* Busfehler-Routine, die fehlerhafte 24-Bit-Adressierungen abfängt
*

BusError	;bra	Exception
		;bclr	#0,10(sp)
		;btst	#6,11(sp)
		;beq	1$
		;clr.l	$2c(sp)
1$		;bchg	#1,$bfe001
		;rte

		and.l	#PtrMask,$10(sp)
		and.l	#PtrMask,$14(sp)
		and.l	#PtrMask,$18(sp)
		and.l	#PtrMask,$2c(sp)
		and.l	#PtrMask,$4c(sp)

		move.l	d0,-(sp)
		move.l	a3,d0
		and.l	#PtrMask,d0
		move.l	d0,a3
		move.l	(sp)+,d0

		bchg	#1,$bfe001		;LED blinken
		rte

*
* Installation der EDisk
*

	ifne	EDiskCapable
InstallEDisk	move.l	a1,$12(a0)	;Wegen Patch...
		dc.w	$a000		;Open

		move.l	$2ae,RBSave
		move.l	EDiskBase(pc),$2ae
		move.l	EDiskROMBase(pc),a1
		add.l	#$1f898,a1
		jsr	(a1)		;EDisk-Installation
		move.l	RBSave(pc),$2ae
		rts

RBSave		dc.l	0
	endc

*
* Installation des Grafiktreibers
*

SetGDevice	move.w	#ScreenX,$c20	;RowBits
		move.w	#ScreenY,$c22	;ColLines
		move.w	#BytesPerRow*NumPlanes,d0
		move.w	d0,$106		;ScreenRow
		move.w	d0,$8ac		;CrsrRow
		move.l	#ScreenBytes,$c24
		move.l	#ScrnBase,a0
		move.l	a0,$824		;ScrnBase
		move.l	a0,$dac		;IconTLAddr
		move.l	a0,$898		;CrsrBase
		moveq	#72,d0
		move.w	d0,$102		;ScrHRes
		move.w	d0,$104		;ScrVRes
		move.l	#$5a932bc7,$db0	;VideoInfoOK
		move.w	#50,$d30	;VertRRate
		clr.l	-(sp)
		clr.w	-(sp)		;Driver RefNum
		move.l	#$00000080,-(sp);Mode
		dc.w	$aa2f		;NewGDevice
		move.l	(sp)+,a0
		move.l	a0,$cc8		;TheGDevice
		move.l	a0,$8a8		;DeviceList
		move.l	a0,$8a4		;MainDevice
		move.l	a0,$8a0		;SrcDevice
		move.l	a0,$89c		;CrsrDevice

		move.l	(a0),a1
		ori.w	#$fc00,$14(a1)	;gdFlags
		move.w	#4,$a(a1)	;gdResPref
		move.l	$16(a1),a0	;gdPMap
		move.l	(a0),a0
		move.l	$824,(a0)	;ScrnBase -> pmBaseOffset
		move.w	$106,4(a0)	;ScreenRow -> pmRowBytes
		move.w	#ScreenX,d0
		move.w	#ScreenY,d1
		move.w	d1,$a(a0)	;pmBounds
		move.w	d0,$c(a0)
		move.w	d1,$26(a1)	;gdRect
		move.w	d0,$28(a1)
		moveq	#72,d0
		swap	d0
		move.l	d0,$16(a0)	;pmHRes
		move.l	d0,$1a(a0)	;pmVRes
		move.w	#0,$1e(a0)	;pmPixelType (0-Chunky, 1-ChunkyPlanar, 2-Planar)
		move.w	#NumPlanes,$20(a0) ;pmPixelSize (Bits per Pixel)
		move.w	#1,$22(a0)	;pmCmpCount (Components per Pixel)
		move.w	#NumPlanes,$24(a0) ;pmCmpSize (Bits per Component)
		move.l	#PlaneBytes,$26(a0) ;pmPlaneBytes
		move.l	$2a(a0),a0	;Handle zur ColorTable
		move.l	(a0),a0
		moveq	#1,d1
		move.l	d1,(a0)+
		move.l	d1,(a0)+
		clr.w	(a0)+
		moveq	#-1,d0
		move.l	d0,(a0)+
		move.w	d0,(a0)+
		swap	d1
		move.l	d1,(a0)+
		clr.l	(a0)+
		rts

*
* Server für Interrupts und Deferred Tasks
*

; Level 3 - VBlank
IntVBlank	movem.l	d0-d3/a0-a3,-(sp)
		move.w	#$0020,$dff09c
		lea	VBLServer(pc),a3
		bra	IntServer

; Level 2 - CIA-A
IntCIAA		movem.l	d0-d3/a0-a3,-(sp)
		move.w	#$0008,$dff09c
		lea	CIAAServer(pc),a3

IntServer	jsr	(a3)
		tst.l	$d94		;DTskQHdr
		beq.s	1$
		moveq	#7,d0
		and.b	$20(sp),d0
		bne.s	1$
		move.l	$6e4,a0		;Deferred Tasks
		jsr	(a0)
1$		movem.l	(sp)+,d0-d3/a0-a3
		rte


**
** VBlank-Interrupt-Routine
**

; !! 6.1x Finder-Patch (sonst zuviele Busfehler)
VBLServer	tst.w	BootEDisk
		beq	Ptchend
		cmp.b	#$80,$28548
		bne	2$
		and.l	#PtrMask,$28548
2$		cmp.b	#$80,$28544
		bne	3$
		and.l	#PtrMask,$28544
3$		cmp.b	#$80,$28530
		bne	4$
		and.l	#PtrMask,$28530
4$		move.w	#$0607,$15a

Ptchend		move.l	ROMBase(pc),a0	;!! Hier wird ins ROM geschrieben (System 7)
		add.l	#$fff5,a0
		move.b	#$04,(a0)

		tst.w	BusErrOn
		beq	NoBusErr
		move.l	#BusError,8	;Neue Busfehler-Routine

NoBusErr	move.l	$2d8,d0		;!! Sonst hängt sich AppleTalk auf (System 7)
		beq	1$
		move.l	d0,a0
		not.b	$2c8(a0)

; Sekunden-Interrupt?
1$		addq.b	#1,TickCount
		cmp.b	#50,TickCount
		bne	VBLNotSecond

; Ja, einspringen
		clr.b	TickCount
		lea	ChipBase,a1
		move.l	$192,d0
		beq	VBLNotSecond
		move.l	d0,a0
		jsr	(a0)

; In normale VBL-Routine einspringen
VBLNotSecond	lea	ChipBase,a1
		move.l	$196,d0
		beq	VBLDoCursor
		move.l	d0,a0
		jsr	(a0)

; Maus abfragen und Cursor bewegen
VBLDoCursor	bsr	DoMouse
		lea	ChipBase,a1
		move.l	$8ee,d0		;CrsrTask
		beq	1$
		move.l	d0,a0
		jsr	(a0)
1$		rts

TickCount	dc.b	0,0


**
** CIA-A Interrupt-Routine
**

; Art des Interrupts auswerten
CIAAServer	move.b	$bfed01,d0

; Timer B (Time Manager)?
		btst	#1,d0
		beq	CIAANotTimerB
		move.l	d0,-(sp)
		bsr	DoTimeMgr
		move.l	(sp)+,d0

; SP (Tastatur)?
CIAANotTimerB	btst	#3,d0
		beq	CIAANotSP
		move.l	d0,-(sp)
		bsr	DoKeyboard
		move.l	(sp)+,d0

CIAANotSP	rts


**
** Mausabfrage
**

DoMouse		move.b	#$80,d2		;Maustaste
		btst	#6,$bfe001
		bne	1$
		moveq	#0,d2
1$		move.b	$172,d1		;MBState
		eor.b	d2,d1
		bpl	NoButton
		move.l	$16a,d1		;Ticks
		sub.l	$16e,d1		;MBTicks
		move.w	#$0002,a0	;Event MouseUp
		moveq	#-128,d0
		and.b	d2,d0
		bmi	2$
		subq.l	#2,d1
		blt	NoButton
		addq.l	#2,d1
		subq.w	#1,a0		;Event MouseDown
2$		move.b	d0,$172		;MBState
		add.l	d1,$16e		;MBTicks
		add.l	d1,$156		;RndSeed
		moveq	#0,d0
		dc.w	$a02f		;PostEvent

NoButton	move.w	$dff00a,d1	;Mausbewegung
		cmp.w	MouseYX(pc),d1
		beq	NoMove
		move.w	d1,d0
		sub.b	MouseYX+1(pc),d0;Horizontale (X) Änderung
		bmi	1$
		addq.b	#1,d0
1$		asr.b	#1,d0		;Nicht so schnell...
		ext.w	d0
		add.w	d0,$82a
		move.w	d1,d0
		lsr.w	#8,d0
		sub.b	MouseYX(pc),d0	;Vertikale (Y) Änderung
		bmi	2$
		addq.b	#1,d0
2$		asr.b	#1,d0		;Nicht so schnell...
		ext.w	d0
		add.w	d0,$828
		move.w	d1,MouseYX
		move.b	$8cf,$8ce	;CrsrNew, Maus wurde bewegt
NoMove		rts

MouseYX		dc.w	0

**
** Tastaturabfrage
**

; Keycode holen und Handshake starten
DoKeyboard	move.b	$bfec01,d0	;Keycode holen
		move.b	#$49,$bfee01	;Handshake und Timer starten
		ror.b	#1,d0		;Richtig schieben
		not.b	d0		;Keycode invertieren
		cmp.b	#$78,d0		;Reset Warning?
		beq	ResetWarning

; Keycode vom Amiga- ins Macintosh-Format bringen
		move.b	d0,d1
		and.w	#$7f,d0		;d0 - Keycode ohne Flag
		and.w	#$80,d1		;d1 - Up/Down-Flag
		lea	KeyXLate(pc),a0
		move.b	0(a0,d0.w),d0	;Keycode übersetzen
		or.b	d1,d0		;d0 - Macintosh-Keycode mit Flag

; Einige Register vorbereiten
		move.l	#$02000000,d3	;KeyboardType: Extended
		move.l	$cf8,a0		;ADBBase (das erste ADBDevice ist immer die Tastatur)
		move.l	8(a0),a2	;ADBInfo der Tastatur

; Beginn der eigentlichen Abfrage
		cmpi.b	#$ff,d0		;Keine Taste gedrückt?
		beq	NoKey		;Ja, dann zurück

; Taste gedrückt
		clr.w	$184		;KeyLast
		clr.w	$216		;HiKeyLast

; Bitnummer und Offset für Keymap berechnen
		moveq	#$7f,d1
		and.b	d0,d1		;d1 - Keycode ohne Flag
		move.b	d1,d3
		moveq	#0,d2
		move.b	d3,d2
		lsr.w	#3,d2

; Keymap aktualisieren
		tst.b	d0
		bmi	KeyUp1
		bset	d3,4(a2,d2.w)
		bra	KeyOK1
KeyUp1		bclr	d3,4(a2,d2.w)
		bset	#7,d3
KeyOK1		movem.l	4(a2),d0-d2/a0
		movem.l	d0-d2/a0,$174	;KeyMap

; Keycode übersetzen
		move.l	d3,d0
		lsr.l	#8,d0
		move.b	d0,$218
		swap	d0
		move.b	d0,$21e
		move.w	10(a2),d0
		rol.w	#1,d0
		subq.l	#4,sp
		move.l	$14(a2),-(sp)
		move.w	d3,-(sp)	;Keycode
		move.b	d0,(sp)
		pea	$18(a2)
		dc.w	$a9c3		;KeyTrans
		move.w	(sp)+,d0
		beq	1$
		bsr	KeyPoster
1$		move.w	(sp)+,d0
		beq	NoKey
		bsr	KeyPoster

; Handshake beenden
NoKey		btst	#0,$bfed01	;Auf Timer warten
		beq	NoKey
		move.b	#$08,$bfee01	;Handshake und Timer stoppen
		rts

; Tastatur-Event posten
KeyPoster	ror.w	#8,d0
		swap	d0
		move.w	d3,d0
		rol.l	#8,d0
		tst.b	d3
		bmi	KeyPostUp

; KeyDown posten
		move.l	$16a,d1		;Ticks
		move.l	d1,$186		;KeyTime
		move.l	d1,$18a		;KeyRepTime
		move.w	d0,$184		;KeyLast
		swap	d0
		move.w	d0,$216		;HiKeyLast
		swap	d0
		move.w	#3,a0		;KeyDown
		dc.w	$a02f		;PostEvent
		rts

; KeyUp posten
KeyPostUp	move.w	#4,a0		;KeyUp
		bclr	#$f,d0
		dc.w	$a02f		;PostEvent
		rts

; Bei Reset-Warnung
ResetWarning	move.w	#$ff0,$dff180
		bra	CoreDump

; Übersetzungstabelle Amiga-Code (Amerik.) -> Mac-Code
KeyXLate	dc.b	$32,$12,$13,$14,$15,$17,$16,$1a	;` 1 2 3 4 5 6 7
		dc.b	$1c,$19,$1d,$1b,$18,$2a,$ff,$52	;8 9 0 - = \   0
		dc.b	$0c,$0d,$0e,$0f,$11,$10,$20,$22	;q w e r t y u i
		dc.b	$1f,$23,$21,$1e,$ff,$53,$54,$55	;o p [ ]   1 2 3
		dc.b	$00,$01,$02,$03,$05,$04,$26,$28	;a s d f g h j k
		dc.b	$25,$29,$27,$2a,$ff,$56,$57,$58	;l ; ' #   4 5 6
		dc.b	$32,$06,$07,$08,$09,$0b,$2d,$2e	;< z x c v b n m
		dc.b	$2b,$2f,$2c,$ff,$41,$59,$5b,$5c	;, . /   . 7 8 9
		dc.b	$31,$33,$30,$4c,$24,$35,$75,$ff	;spc bsp tab ent ret esc del
		dc.b	$ff,$ff,$4e,$ff,$7e,$7d,$7c,$7b	;          -     cup cdn crg clf
		dc.b	$7a,$78,$63,$76,$60,$61,$62,$64	; f1  f2  f3  f4  f5  f6  f7  f8
		dc.b	$65,$6d,$47,$51,$4b,$43,$45,$72	; f9 f10   (   )   /   *   + hlp
		dc.b	$38,$3c,$39,$36,$3a,$3d,$37,$37	;shl shr cap ctl all alr aml amr
		dc.b	$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff	;68-6F
		dc.b	$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff	;70-77
		dc.b	$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff	;78-7F


**
** Time Manager Interrupt-Routine
**

DoTimeMgr	move.l	$b30,a2		;TimeVars
		clr.l	12(a2)

; Schleife für alle ausstehenden TimeTasks
; Steht noch ein Task aus?
TimeLoop	move.l	(a2),d0
		beq	TimeExit

; Ja, Zeit erniedrigen. Zeit abgelaufen?
		move.l	d0,a0
		subq.l	#1,10(a0)
		bne	TimeNext

; Ja, Task entfernen
		move.l	(a0),(a2)
		bclr	#7,4(a0)

; Routine vorhanden?
		move.l	6(a0),d0
		beq	TimeNext

; Ja, einspringen
		move.l	a0,-(sp)
		move.l	a0,a1		
		move.l	d0,a0
		jsr	(a0)
		move.l	(sp)+,a0

; Nächsten Task holen
TimeNext	move.l	a0,a2
		bra	TimeLoop

; Noch ausstehende Zeit erniedrigen
TimeExit	rts


*
* Daten des erweiterten Parameter-RAMs
*

XPRam		dc.b	0	;00
		dc.b	0	;01 ???
		dc.w	0	;02 ??? (SCSI)
		dc.w	0	;04
		dc.b	0	;06
		dc.b	$f0	;07 Startmonitor?
		dc.l	0	;08
		dc.l	0	;0C ??? ("Bugs", "NuMc")
		dc.l	0,0,0,0	;10
		dc.l	0	;20 ???
		dc.l	0,0,0	;24
		dc.l	0,0,0,0	;30
		dc.l	0,0,0,0	;40
		dc.l	0,0,0,0	;50
		dc.l	0,0,0,0	;60
		dc.l	0	;70
		dc.w	0	;74
		dc.w	0	;76 OSDefault
		dc.l	0	;78 DefaultStartup
		dc.w	0	;7C ID der snd-Resource des Signaltons
		dc.w	0	;7E
		dc.w	$f0	;80 VideoDefault
		dc.w	$ffff	;82 HiliteRGB
		dc.w	$ffff
		dc.w	$0000
		dc.b	0	;88
		dc.b	0	;89 ???
		dc.b	%10101	;8A bit #0: 32Bit-Modus, #2: 32Bit-SystemHeap, #4: SystemHeap bei $38000000
		dc.b	0	;8B
		dc.l	0	;8C
		dc.l	0,0,0,0	;90
		dc.l	0,0,0,0	;A0
		dc.l	0,0	;B0
		dc.l	0	;B8 "Gone"
		dc.l	0	;BC
		dc.l	0,0,0,0	;C0
		dc.l	0,0,0,0	;D0
		dc.l	0	;E0
		dc.l	0,0,0	;E4 MachineLocation
		dc.l	0	;EC
		dc.l	0,0,0,0	;F0


**
** Daten für Hauptprogramm
**

; Strings
DosName		dc.b	"dos.library",0
IntuitionName	dc.b	"intuition.library",0
GadToolsName	dc.b	"gadtools.library",0
TopazName	dc.b	"topaz.font",0
FileName	dc.b	"PROGDIR:LCROM",0
FileName2	dc.b	"PROGDIR:EDiskROM",0
FileName3	dc.b	"PROGDIR:DiskDriver",0
ReqTitle1	dc.b	"MacEmul",0
ReqText1	dc.b	"Macintosh-Emulation starten?",10,10
		dc.b	"ACHTUNG: Der Rechner wird übernommen!",10
		dc.b	"Speichern Sie noch benötigte Daten",10
		dc.b	"und warten Sie auf das Ende der",10
		dc.b	"Diskaktivität!",0
ReqGads1	dc.b	"Ja|Nein",0
WindowTitle	dc.b	"MacEmul - Einstellungen",0
CheckGText	dc.b	"Am Kontrollpunkt stoppen (grün)",0
ExceptionGText	dc.b	"Exceptions abfangen (rot)",0
BusErrGText	dc.b	"Busfehler unterdrücken",0
LoadEDiskGText	dc.b	"ROM-Disk neu laden",0
BootEDiskGText	dc.b	"Aus ROM-Disk booten",0
OKGText		dc.b	"OK",0
CancelGText	dc.b	"Abbrechen",0
		even

; Variablen
DOSBase		dc.l	0
IntuitionBase	dc.l	0
GadToolsBase	dc.l	0
EDiskROMBase	dc.l	0
EDiskBase	dc.l	0
DiskDriverSeg	dc.l	0
DiskDriverBase	dc.l	0
DiskDriverLen	dc.l	0
TrackBufBase	dc.l	0
Window		dc.l	0

; Strukturen
EasyStruct	dc.l	20		;StructSize
		dc.l	0		;Flags
		dc.l	ReqTitle1
		dc.l	ReqText1
		dc.l	ReqGads1

NewGadget	dc.w	0,0,0,0		;Dimensionen
		dc.l	0		;Label
		dc.l	TextAttr	;TextAttr
		dc.w	0		;GadgetID
		dc.l	0		;Flags
VisualInfo	dc.l	0		;VI
		dc.l	0		;UserData

TextAttr	dc.l	TopazName
		dc.w	8
		dc.b	0,1

WindowTags	dc.l	$8000006e,WindowTitle	;Title
		dc.l	$8000006c		;Gadgets
GList		dc.l	0
		dc.l	$80000090,-1		;AutoAdjust
		dc.l	$80000076,300		;InnerWidth
		dc.l	$80000077,85		;InnerHeight
		dc.l	$80000082,-1		;DragBar
		dc.l	$80000083,-1		;DepthGadget
		dc.l	$80000089,-1		;Activate
		dc.l	$8000006a,$00000044	;IDCMP
		dc.l	$80000079		;PubScreen
Screen		dc.l	0
		dc.l	0

CheckboxTags	dc.l	$80080004,-1		;ChecboxChecked
		dc.l	0

; Macintosh Machine Definitions
		dc.l	ChipAvailFlags
		dc.l	$26
		dc.b	0,0,0,0			;Masken für VIA-Register
		dc.l	0
		dc.b	7,0,0,0
ChipDef
ROMBase		dc.l	0
		dc.l	ChipBase		;???
		dc.l	ChipBase		;VIA 1
		dc.l	ChipBase		;SCC Read
		dc.l	ChipBase		;SCC Write
		dc.l	ChipBase		;IWM
		dc.l	ChipBase		;PWMBuf2
		dc.l	ChipBase		;SoundBase
		dc.l	ChipBase		;SCSI
		dc.l	ChipBase		;SCSI DMA
		dc.l	ChipBase		;SCSI Hsk
		dc.l	ChipBase		;VIA 2
		dc.l	ChipBase		;ASC
		dc.l	ChipBase		;RBV
		dc.l	ChipBase		;???
		dc.l	ChipBase		;SCSI

MachDef		dc.l	ChipDef-MachDef
		dc.l	Struct1-MachDef
		dc.l	Struct2-MachDef
		dc.l	SlotDef-MachDef		;		LC:  IIsi:
		dc.w	$0c00			;HWCfgFlags	dc00 dc00
		dc.w	$0c05			;Machine Type	0d07 0c05
		dc.w	$3fff			;-> ROM85
		dc.w	$0400			;
		dc.l	ChipAvailFlags		;-> $DD0	773f 773f
		dc.l	$00000000		;-> $DD4	01a6 0126
		dc.l	$56000000
		dc.l	$16000000		;		54000000
		dc.l	Struct3-MachDef
		dc.l	0,0,0,0,0

Struct3		dc.l	$262f48f7
		dc.w	$001c

Struct1		dc.w	$0010
		dc.l	$80
		dc.l	$a0
		dc.l	0
		dc.l	$80
		dc.w	0
		dc.l	-1
		dc.l	0
		dc.l	$fee08000
		dc.l	$fee08000
		dc.l	$0e6e0000

Struct2		dc.l	ChipBase
		dc.l	ChipBase
		dc.l	ChipBase
		dc.l	$b5600000
		dc.l	$9f005000
		dc.l	$9f005000
		dc.l	$9f005000
		dc.l	$b5600000
		dc.l	0,0,0,0

SlotDef		dc.b	3,8,8,8,8,8,8,8
		dc.b	8,9,9,8,9,9,$13,0

		dc.l	0,0,0,0	;B0-BF BE MMUTbl2
		dc.l	0,0,0,0	;C0-CF
		dc.l	0,0,0,0	;D0-DF D2 MMUTbl 1
		dc.l	0	;E0
		dc.w	0	;E4
		dc.b	0	;E6 MMUType
		dc.b	1	;E7 MMU vorhanden? (1=Nein)
		dc.l	0	;E8 ???
		dc.l	MemTop	;EC MemTop
		dc.l	0	;F0
		dc.l	0	;F4 BufPtr-Offset
		dc.l	0	;F8
		dc.l	0	;FC "WLSC"-Flag $574c5343
MMUInfo		dc.l	0

; Copperlisten
CopList		dc.w	$0e0,Plane1Base/$10000
		dc.w	$0e2,Plane1Base&$ffff
		dc.w	$0e4,Plane2Base/$10000
		dc.w	$0e6,Plane2Base&$ffff
		dc.w	$0e8,Plane3Base/$10000
		dc.w	$0ea,Plane3Base&$ffff
		dc.w	$0ec,Plane4Base/$10000
		dc.w	$0ee,Plane4Base&$ffff
		dc.w	$0f0,Plane5Base/$10000
		dc.w	$0f2,Plane5Base&$ffff
		dc.w	$0f4,Plane6Base/$10000
		dc.w	$0f6,Plane6Base&$ffff
		dc.w	$0f8,Plane7Base/$10000
		dc.w	$0fa,Plane7Base&$ffff
		dc.w	$0fc,Plane8Base/$10000
		dc.w	$0fe,Plane8Base&$ffff
	ifeq	LoRes
		dc.w	$080,(CopperBase+Cop1Size)/$10000
		dc.w	$082,(CopperBase+Cop1Size)&$ffff
		dc.w	$ffff,$fffe
Cop2		dc.w	$0e0,(Plane1Base+BytesPerRow)/$10000
		dc.w	$0e2,(Plane1Base+BytesPerRow)&$ffff
		dc.w	$0e4,(Plane2Base+BytesPerRow)/$10000
		dc.w	$0e6,(Plane2Base+BytesPerRow)&$ffff
		dc.w	$0e8,(Plane3Base+BytesPerRow)/$10000
		dc.w	$0ea,(Plane3Base+BytesPerRow)&$ffff
		dc.w	$0ec,(Plane4Base+BytesPerRow)/$10000
		dc.w	$0ee,(Plane4Base+BytesPerRow)&$ffff
		dc.w	$0f0,(Plane5Base+BytesPerRow)/$10000
		dc.w	$0f2,(Plane5Base+BytesPerRow)&$ffff
		dc.w	$0f4,(Plane6Base+BytesPerRow)/$10000
		dc.w	$0f6,(Plane6Base+BytesPerRow)&$ffff
		dc.w	$0f8,(Plane7Base+BytesPerRow)/$10000
		dc.w	$0fa,(Plane7Base+BytesPerRow)&$ffff
		dc.w	$0fc,(Plane8Base+BytesPerRow)/$10000
		dc.w	$0fe,(Plane8Base+BytesPerRow)&$ffff
		dc.w	$080,CopperBase/$10000
		dc.w	$082,CopperBase&$ffff
		dc.w	$ffff,$fffe
Cop1Size	= Cop2-CopList
	endc
	ifne	LoRes
		dc.w	$ffff,$fffe
	endc
CopSize		= *-CopList

; Einstellungen des Benutzers
CheckPoint	dc.l	$1f00	;Offset zu ROMBase
CheckOn		dc.w	0	;0 - Check aus, 1 - Check an
ExceptionOn	dc.w	0	;0 - Exception normal, 1 - Exception abfangen
BusErrOn	dc.w	-1	;0 - Busfehler normal, 1 - Busfehler unterdrücken
LoadEDisk	dc.w	0	;0 - Nein, 1 - Ja
BootEDisk	dc.w	0	;0 - Normal starten, 1 - Von EDisk starten
		end
