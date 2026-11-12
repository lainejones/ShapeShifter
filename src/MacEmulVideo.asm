**
** Macintosh IIci-Emulator - Amiga Video Modul
** ===========================================
**
** © Copyright 1993-2001 Christian Bauer
**

DEBUG_DETAIL	SET 0

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"exec/ports.i"
		INCLUDE	"dos/dos.i"
		INCLUDE	"dos/dostags.i"
		INCLUDE	"graphics/gfx.i"
		INCLUDE	"graphics/displayinfo.i"
		INCLUDE	"graphics/rastport.i"
		INCLUDE	"graphics/gfxbase.i"
		INCLUDE	"graphics/view.i"
		INCLUDE	"graphics/videocontrol.i"
		INCLUDE	"intuition/intuition.i"
		INCLUDE	"intuition/screens.i"
		INCLUDE	"intuition/intuitionbase.i"
		INCLUDE	"egs/egs.i"
		INCLUDE	"libraries/cybergraphics.i"
		INCLUDE	"libraries/Picasso96.i"
		INCLUDE	"macinclude.i"
		INCLUDE	"shapeextvideo.i"
		INCLUDE	"macros.i"

		XDEF	OpenCyberGfx
		XDEF	VideoOpen
		XDEF	VideoPrime
		XDEF	VideoCtrl
		XDEF	VideoStatus
		XDEF	VideoClose
		XDEF	OpenVideo
		XDEF	CloseVideo
		XDEF	IsEmulActive
		XDEF	TogglePointer
		XDEF	DrawDisk1Icon
		XDEF	DrawDisk2Icon
		XDEF	DrawDisk3Icon
		XDEF	DrawDisk4Icon
		XDEF	EraseDiskIcon
		XDEF	ScrnBase1
		XDEF	ScrnBase2
		XDEF	BytesPerRow1
		XDEF	BytesPerRow2

		XREF	UserPort		;MacEmul.asm
		XREF	EGSUserPort
		XREF	PageSize
		XREF	SubtaskSet
		XDEF	BoxBorderLeft
		XDEF	BoxBorderTop
		XDEF	IsRefreshing
		XDEF	RefreshNow
		XDEF	IsPrism
		XDEF	ModeCount1		;MacEmulSlot: Mac depth modes of monitor 1
		XDEF	ModeStart1
		XDEF	ModeVM1
		XREF	SetModeParams		;MacEmulSlot
		XREF	DepthSwitch		;MacEmul: Farbtiefe auf dem Mac waehlbar

		SECTION	"CODE",CODE


**
** Definitionen
**
** Anm 1: Mit DEPTHSWITCH (seit 3.20) kennt der Grafiktreiber bei einem
**        Monitor (Amiga-Bitplanes oder CyberGfx) einen Modus pro Farbtiefe
**        ($80, $81, ...), so dass die Farbtiefe im Kontrollfeld "Monitore"
**        gewechselt werden kann. Der Mac nimmt die Adresse des Grafik-
**        speichers aus den sResources, bevor er SetMode aufruft; darum
**        zeichnet er dann immer in einen festen Puffer (FixedBuf), und jede
**        Farbtiefe wird refresht (auch 1 Bit und direkte Grafikkarten-Modi,
**        mit RefPlainCopy). Der Refresh-Task oeffnet beim Wechsel den neuen
**        Bildschirm und schliesst danach den alten.
**        Ohne DEPTHSWITCH, bei zwei Monitoren und bei den anderen
**        Bildschirmtypen bleibt es bei einem Modus ($80).
** Anm 2: Es darf nur jeweils ein Amiga-Bitplanes-Bildschirm aktiv sein
** Anm 3: Mac-In-A-Box ist nur im Einmonitor-Betrieb möglich
**

; Definitionen für Datenbereich
 STRUCTURE	VideoInfo,0
	WORD	vVideoMode	;VMODE_...
	WORD	vVideoType	;VTYPE_...
	WORD	vOverscanType	;OSCAN_...
	WORD	vpad0
	LONG	vDisplayID	;ModeID
	LONG	vScreenX	;Dimensionen
	LONG	vScreenY

	APTR	vScreen		;Zeiger auf Screen
	APTR	vWindow		;Zeiger auf Fenster
	APTR	vViewPort	;Zeiger auf ViewPort (nur Amiga/CyberGfx)
	APTR	vBitMap		;Zeiger auf BitMap
	APTR	vScrnBase	;Zeiger auf Macintosh-Bildschirmspeicher
	APTR	vEGSStdMouse	;Standard-Mauszeiger für EGS
	LONG	vBytesPerRow	;BytesPerRow des Macintosh-Screens

	APTR	vExtVideoName	;Name des externen Treibers
	APTR	vSegment	;BPTR auf SegList des externen Treibers
	APTR	vTagList	;TagList des externen Treibers
	APTR	vContext	;Kontext des externen Treibers
	APTR	vExtOpenScreen	;Externen Screen öffnen
	APTR	vExtCloseScreen	;Externen Screen schließen
	APTR	vLoadRGB32	;Laden der Farbtabelle

	LONG	vRefreshType	;Refresh-Type des externen Treibers
	LONG	vScreenBytes	;Größe des Mac-Grafikspeichers
	LONG	vScreenRest	;Was nach den MMU-Seiten übrigbleibt
	WORD	vScreenPages	;Anzahl der MMU-Seiten des Mac-Grafikspeichers
	WORD	vpad2
	APTR	vRefreshMem	;Zeiger auf Refresh-Speicher, muß freigegeben werden
	APTR	vRefPageTable	;Zeiger auf Tabelle mit Zeigern auf die MMU-Deskriptoren für die Seiten
	APTR	vComparisonBuf	;Zeiger auf Vergleichspuffer, muß freigegeben werden

	APTR	vLockProc	;BitMap locken
	APTR	vRefProc	;Screen refreshen
	APTR	vUnlockProc	;BitMap unlocken
	APTR	vPtrVisProc	;Mauszeiger sichtbar machen
	APTR	vPtrInvProc	;Mauszeiger unsichtbar machen

	APTR	vSQEl		;Zeiger auf SlotQueueElement
	APTR	vGammaTable	;Zeiger auf Gamma-Tabelle
	APTR	vGammaDir	;Zeiger auf Gamma-Directory

	WORD	vDefMode	;Vorgabe-Videomodus
	WORD	vCurrentMode	;Augenblicklicher Videomodus (immer $80)

	WORD	vNumColors	;Anzahl Farben bei 1,2,4 oder 8 Bit
	WORD	vAlwaysZero1	;Immer Null
	STRUCT	vLoadRGBColors,256*3*4 ;Puffer für Farbtabelle
	LONG	vAlwaysZero2

	BYTE	vGrayFlag	;#0: Graustufen
	BYTE	vDirectFlag	;#0: Direct Pixel Mode
	BYTE	vIntDisFlag	;#0: Interrupt disabled
	BYTE	vpad1
	APTR	vCyberLock	;PrismRTG: LockBitMap-Handle, haelt den Grafikspeicher fest
 LABEL	VideoInfo_SIZEOF

; EGS
E_OpenScreen		= -30
E_CloseScreen		= -36
E_MouseOff		= -42
E_ModifyMouse		= -54
E_SetRGB8		= -84

; CyberGfx
IsCyberModeID		= -54
GetCyberMapAttr		= -96
GetCyberIDAttr		= -102
LockBitMapTagList	= -168
UnLockBitMap		= -174
WritePixelArray 	= -126

; Picasso96
p96GetBitMapAttr	= -$2a
p96PIP_OpenTagList	= -$90
p96PIP_Close		= -$96
p96PIP_GetTagList	= -$a2


; Externe Treiber
OUR_LEVEL	= 2	;ShapeShifter-Level

*
* Open()-Routine
*

VideoOpen	movem.l	a0-a1,-(sp)

; Slot Manager vorbereiten
		sub.w	#56,sp			;spBlock reservieren
		move.l	sp,a0

; Welcher Slot?
		cmp.b	#$87,dCtlSlotId(a1)
		beq	VOTry4243

; Monitor 1
		DPRINTF	"VOpen() $86"

		lea	VideoInfo1,a3
		move.l	a3,dCtlStorage(a1)

		move.b	dCtlSlot(a1),$31(a0)	;spSlot
		clr.b	$32(a0)			;spID
		clr.b	$33(a0)			;spExtDev
		clr.b	$34(a0)			;spHwDev
		clr.b	$30(a0)			;spTBMask
		move.w	#3,$28(a0)		;Type
		move.w	#1,$2a(a0)
		move.w	#1,$2c(a0)
		move.w	#4242,$2e(a0)
		moveq	#$15,d0			;SNextTypeSRsrc
		dc.w	$a06e
		bne	VideoOpenErr
		bra	VOSlotOK

; Monitor 2
VOTry4243	DPRINTF	"VOpen() $87"

		lea	VideoInfo2,a3
		move.l	a3,dCtlStorage(a1)

		move.b	dCtlSlot(a1),$31(a0)	;spSlot
		clr.b	$32(a0)			;spID
		clr.b	$33(a0)			;spExtDev
		clr.b	$34(a0)			;spHwDev
		clr.b	$30(a0)			;spTBMask
		move.w	#3,$28(a0)		;Type
		move.w	#1,$2a(a0)
		move.w	#1,$2c(a0)
		move.w	#4243,$2e(a0)
		moveq	#$15,d0			;SNextTypesRsrc
		dc.w	$a06e
		bne	VideoOpenErr

; Gamma-Tabelle holen
VOSlotOK	move.b	#$40,$32(a0)		;spID=sGammaDir
		moveq	#6,d0
		dc.w	$a06e			;SFindStruct

		move.b	#$80,$32(a0)		;spID=128 Bytes
		moveq	#5,d0
		dc.w	$a06e			;SGetBlock

		move.l	(a0),a0
		move.l	a0,vGammaDir(a3)
		addq.w	#2,a0			;ResID überspringen
1$		tst.b	(a0)+			;Name überspringen
		bne	1$

		move.l	a0,d0
		addq.w	#1,d0
		bclr	#0,d0
		move.l	d0,vGammaTable(a3)
		add.w	#56,sp

; Datenbereich initialisieren
		cmp.b	#$87,dCtlSlotId(a1)
		beq	2$

; Monitor 1
		clr.b	vGrayFlag(a3)
		move.w	ModeStart1,d0		;Mehrere Farbtiefen: der Startmodus
		add.w	#$80,d0
		move.w	d0,vCurrentMode(a3)
		move.w	d0,vDefMode(a3)
		move.w	vVideoMode(a3),d1
		moveq	#0,d0
		bset	d1,d0			;d0: Tiefe
		moveq	#0,d1
		bset	d0,d1			;d1: Anzahl Farben
		move.w	d1,vNumColors(a3)

		moveq	#16,d0
		dc.w	$a71e			;NewPtrSysClear
		move.l	a0,vSQEl(a3)
		bsr	EnableVGuts

		cmp.w	#VMODE_15BIT,vVideoMode(a3)
		shs	vDirectFlag(a3)
		bra	VideoOpenOK

; Monitor 2
2$		clr.b	vGrayFlag(a3)
		move.w	#$80,vCurrentMode(a3)
		move.w	#$80,vDefMode(a3)
		move.w	vVideoMode(a3),d1
		moveq	#0,d0
		bset	d1,d0			;d0: Tiefe
		moveq	#0,d1
		bset	d0,d1			;d1: Anzahl Farben
		move.w	d1,vNumColors(a3)

		moveq	#16,d0
		dc.w	$a71e			;NewPtrSysClear
		move.l	a0,vSQEl(a3)
		bsr	EnableVGuts

		cmp.w	#VMODE_15BIT,vVideoMode(a3)
		shs	vDirectFlag(a3)

VideoOpenOK	moveq	#0,d0
		movem.l	(sp)+,a0-a1
		rts

; Fehler beim Öffnen
VideoOpenErr	add.w	#56,sp
VideoOpenErr2	moveq	#-23,d0			;Open Error
		movem.l	(sp)+,a0-a1
		rts


*
* Prime()-Routine
*

VideoPrime	move.l	d1,a0
		dc.w	$a023			;DisposeHandle
		bra	VideoOpen


*
* Control()-Routine
*

; csCode auswerten und verzweigen
VideoCtrl	movem.l	a0-a1,-(sp)
		move.w	csCode(a0),d0
		move.l	csParam(a0),a2
		move.l	dCtlStorage(a1),a3
		cmp.w	#9,d0
		bhi	VControlErr

		DPRINTF	"VControl slot %08lx, code %ld",$28(a1),d0

		jmp	([VControlJmp,d0.w*4])

; Sprungtabelle für Control()
VControlJmp	dc.l	VReset
		dc.l	VKillIO
		dc.l	VSetMode
		dc.l	VSetEntries
		dc.l	VSetGamma
		dc.l	VGrayPage
		dc.l	VSetGray
		dc.l	VSetInterrupt
		dc.l	VDirectSetEntries
		dc.l	VSetDefaultMode

; Reset
VReset		move.w	vDefMode(a3),(a2)	;csMode auf ersten Modus setzen
		clr.w	6(a2)			;csPage=0
		move.l	vScrnBase(a3),8(a2)	;csBaseAddr
		bra	VReturnOK

; KillIO
VKillIO		moveq	#0,d0
		movem.l	(sp)+,a0-a1
		rts

; Set Mode
VSetMode	move.w	(a2),d1			;csMode
		cmp.w	vCurrentMode(a3),d1	;Bleibt gleich?
		beq	1$
		bsr	VSwitchMode		;Nein, andere Farbtiefe
		tst.l	d0
		bne	VControlErr
1$		move.l	vScrnBase(a3),8(a2)	;csBaseAddr
		bra	VReturnOK

; Farbtiefe wechseln (Modus d1, a3: VideoInfo), im Kontext des Mac.
; Der Refresh-Task oeffnet den Bildschirm neu; der Mac wartet solange.
; Rueckgabe d0: 0 = OK
VSwitchMode	bsr	VCheckMode
		bne	9$
		movem.l	d1-d7/a0-a6,-(sp)
		move.w	d1,d7			;d7: Modus
		moveq	#0,d2
		move.w	d1,d2
		sub.w	#$80,d2
		lea	ModeVM1,a0
		move.w	(a0,d2.l*2),SwitchVM
		lea	ModeDID1,a0
		move.l	(a0,d2.l*4),SwitchDID
		clr.w	SwitchRes
		st	$8cd			;CrsrBusy: der Mac malt den Zeiger nicht
		move.l	a3,SwitchReq		;Auftrag an den Refresh-Task
		move	sr,-(sp)
		move.w	#$2000,sr
		move.l	_ExecBase,a6
		move.l	SwitchDoneSet,d0
		EJSRLIB	Wait
		move	(sp)+,sr
		clr.b	$8cd
		tst.w	SwitchRes
		bne	8$

		move.w	d7,vCurrentMode(a3)	;Daten des Treibers nachfuehren
		move.w	vVideoMode(a3),d1
		moveq	#0,d0
		bset	d1,d0			;d0: Tiefe
		moveq	#0,d1
		cmp.w	#16,d0
		bhs	1$
		bset	d0,d1			;d1: Anzahl Farben
1$		move.w	d1,vNumColors(a3)
		lea	vLoadRGBColors(a3),a0	;LoadRGB32-Tabelle nach der letzten
		mulu	#12,d1			; Farbe beenden (dort steht sonst
		clr.l	(a0,d1.l)		; noch eine Farbe der groesseren Tiefe)
		cmp.w	#VMODE_15BIT,vVideoMode(a3)
		shs	vDirectFlag(a3)

		moveq	#0,d0			;sResource: Basis und BytesPerRow
		move.w	d7,d0			; des Modus
		sub.w	#$80,d0
		move.l	vScrnBase(a3),d1
		move.l	vBytesPerRow(a3),d2
		JSRSELF	SetModeParams

		move.w	vBytesPerRow+2(a3),$106	;ScreenRow (die Basis bleibt)
		movem.l	(sp)+,d1-d7/a0-a6
		moveq	#0,d0
		rts
8$		movem.l	(sp)+,d1-d7/a0-a6
9$		moveq	#-1,d0
		rts

; Set Entries
VSetEntries	move.l	(a2),d0			;csTable=NIL?
		beq	VControlErr		;Ja, Fehler
		tst.b	vDirectFlag(a3)		;DirectMode?
		bne	VControlErr		;Ja, Fehler

		movem.l	d4-d7/a4-a6,-(sp)
		move.l	vGammaTable(a3),a0
		move.w	gFormulaSize(a0),d0
		lea	gFormulaData(a0),a4
		add.w	d0,a4			;Red Table Default
		move.l	a4,a5			;Green Table Default
		move.l	a4,a6			;Blue Table Default
		move.w	gDataWidth(a0),d7
		cmp.w	#1,gChanCnt(a0)		;Nur eine Tabelle?
		beq	VWriteCLUT
		move.w	gDataCnt(a0),d0		;Nein, Zeiger berechnen
		move.w	d7,d1
		addq.w	#7,d1
		lsr.w	#3,d1
		mulu.w	d1,d0
		add.w	d0,a5			;Green Table
		add.w	d0,a6			;Blue Table
		add.w	d0,a6

VWriteCLUT	move.w	6(a2),d3		;csCount
		cmp.w	vNumColors(a3),d3
		bhi	VCLUTError
		move.w	d3,d4
		addq.w	#1,d4
		tst.w	4(a2)			;Sequence?
		bmi	1$
		mulu.w	#3,d4			;Ja, 3 Einträge (r,g,b)
		bra	2$
1$		lsl.w	#2,d4			;Nein 4 Einträge (i,r,g,b)
2$		sub.w	d4,sp			;Platz reservieren
		move.l	sp,a0

		move.l	(a2),a1			;csTable
VCLUTLoop	move.w	(a1)+,d0		;Index holen
		tst.w	4(a2)			;Sequence?
		bpl	3$
		move.b	d0,(a0)+		;Nein, Index merken
3$		move.w	(a1)+,d0		;Farbwerte holen
		move.w	(a1)+,d1
		move.w	(a1)+,d2

		tst.b	vGrayFlag(a3)		;Graustufen?
		beq	4$
		mulu.w	#$4ccc,d0		;Ja, Luminance Mapping
		mulu.w	#$970a,d1
		mulu.w	#$1c29,d2
		add.l	d1,d0
		add.l	d2,d0
		bfextu	d0{0:d7},d1		;Die obersten d7 Bits holen
		move.w	d1,d0
		move.w	d1,d2
		bra	5$
4$		bfextu	d0{16:d7},d0		;Die obersten d7 Bits des Wortes holen
		bfextu	d1{16:d7},d1
		bfextu	d2{16:d7},d2

5$		move.b	(a4,d0.w),(a0)+		;Gamma-Korrektur
		move.b	(a5,d1.w),(a0)+
		move.b	(a6,d2.w),(a0)+
		dbra	d3,VCLUTLoop

		move.l	_GfxBase,a6
		move.w	6(a2),d6		;csCount
		move.l	sp,a5
		tst.w	4(a2)			;Sequence?
		bpl	VCLUTSeq

VCLUTLoopNoSeq	moveq	#0,d0			;Nein
		move.b	(a5)+,d0		;Index holen
		move.b	(a5),d1			;Farbwerte holen und auf Langworte erweitern
		lsl.w	#8,d1
		move.b	(a5),d1
		lsl.l	#8,d1
		move.b	(a5),d1
		lsl.l	#8,d1
		move.b	(a5)+,d1
		move.b	(a5),d2
		lsl.w	#8,d2
		move.b	(a5),d2
		lsl.l	#8,d2
		move.b	(a5),d2
		lsl.l	#8,d2
		move.b	(a5)+,d2
		move.b	(a5),d3
		lsl.w	#8,d3
		move.b	(a5),d3
		lsl.l	#8,d3
		move.b	(a5),d3
		lsl.l	#8,d3
		move.b	(a5)+,d3

		lea	vLoadRGBColors(a3),a0	;In Tabelle speichern
		move.w	d0,d7			;d0 nicht ändern (wg. EGS)
		mulu.w	#3,d7			;d4 darf auch nicht verändert werden, da es zum Aufräumen des Stacks noch gebraucht wird
		move.l	d1,(a0,d7.w*4)
		move.l	d2,4(a0,d7.w*4)
		move.l	d3,8(a0,d7.w*4)

		cmp.w	#VTYPE_EGS,vVideoType(a3)
		beq	VCLUTNoSeqEGS
		cmp.w	#VTYPE_AMIGA,vVideoType(a3)
		bne	VCLUTNoSeqNext
		tst.b	HasGfx39
		bne	VCLUTNoSeqNext

		move.l	vViewPort(a3),a0
		bfextu	d1{0:4},d1		;Die obersten 4 Bits holen
		bfextu	d2{0:4},d2
		bfextu	d3{0:4},d3
		EJSRLIB	SetRGB4
		bra	VCLUTNoSeqNext

VCLUTNoSeqEGS	move.l	_EGSBase,a6
		move.l	vScreen(a3),a0
		jsr	E_SetRGB8(a6)

VCLUTNoSeqNext	dbra	d6,VCLUTLoopNoSeq
		bra	VCLUTOK

VCLUTSeq	move.w	4(a2),d5		;csStart
VCLUTLoopSeq	moveq	#0,d0
		move.b	d5,d0
		move.b	(a5),d1
		lsl.w	#8,d1
		move.b	(a5),d1
		lsl.l	#8,d1
		move.b	(a5),d1
		lsl.l	#8,d1
		move.b	(a5)+,d1
		move.b	(a5),d2
		lsl.w	#8,d2
		move.b	(a5),d2
		lsl.l	#8,d2
		move.b	(a5),d2
		lsl.l	#8,d2
		move.b	(a5)+,d2
		move.b	(a5),d3
		lsl.w	#8,d3
		move.b	(a5),d3
		lsl.l	#8,d3
		move.b	(a5),d3
		lsl.l	#8,d3
		move.b	(a5)+,d3

		lea	vLoadRGBColors(a3),a0	;In Tabelle speichern
		move.w	d0,d7			;d0 nicht ändern (wg. EGS)
		mulu.w	#3,d7
		move.l	d1,(a0,d7.w*4)
		move.l	d2,4(a0,d7.w*4)
		move.l	d3,8(a0,d7.w*4)

		cmp.w	#VTYPE_EGS,vVideoType(a3)
		beq	VCLUTSeqEGS
		cmp.w	#VTYPE_AMIGA,vVideoType(a3)
		bne	VCLUTSeqNext
		tst.b	HasGfx39
		bne	VCLUTSeqNext

		move.l	vViewPort(a3),a0
		bfextu	d1{0:4},d1		;Die obersten 4 Bits holen
		bfextu	d2{0:4},d2
		bfextu	d3{0:4},d3
		EJSRLIB	SetRGB4
		bra	VCLUTSeqNext

VCLUTSeqEGS	move.l	_EGSBase,a6
		move.l	vScreen(a3),a0
		jsr	E_SetRGB8(a6)

VCLUTSeqNext	addq.w	#1,d5
		dbra	d6,VCLUTLoopSeq

VCLUTOK		cmp.w	#VTYPE_EXTERNAL,vVideoType(a3)
		beq	2$
		cmp.w	#VTYPE_CYBER,vVideoType(a3)
		beq	3$
		cmp.w	#VTYPE_AMIGA,vVideoType(a3)
		bne	1$
		tst.b	HasGfx39
		bne	3$
		bra	1$

2$		tst.l	vLoadRGB32(a3)		;Extern: Alle Register gleichzeitig laden
		beq	1$
		lea	vLoadRGBColors(a3),a0
		move.l	a0,ExtLRGBOutTab
		lea	ExtLRGBOutTags,a0
		lea	ExtLRGBInTags,a1
		move.l	vContext(a3),a2
		move.l	_UtilityBase,a6
		move.l	vLoadRGB32(a3),a3
		jsr	(a3)
		bra	1$

3$		move.l	_GfxBase,a6		;Gfx V39/Cyber: Alle Register gleichzeitig laden
		move.l	vViewPort(a3),a0
		lea	vNumColors(a3),a1
		EJSRLIB	LoadRGB32

1$		add.w	d4,sp
		movem.l	(sp)+,d4-d7/a4-a6
		bra	VReturnOK
VCLUTError	movem.l	(sp)+,d4-d7/a4-a6
		bra	VControlErr

; Set Gamma
VSetGamma	move.l	(a2),d0			;csGTable
		beq	VLinearTab

		move.l	d0,a2
		tst.w	(a2)			;gVersion=0?
		bne	VControlErr		;Nein, Fehler
		tst.w	2(a2)			;gType=0?
		beq	VChangeTable		;Ja, OK
		cmp.w	#$18,2(a2)		;gType=24?
		bne	VControlErr		;Nein, Fehler

VChangeTable	move.l	vGammaTable(a3),a0
		move.w	4(a2),d0		;gFormulaSize
		cmp.w	4(a0),d0		;Bleibt gleich?
		bne	VGetNew			;Nein, Größe ändern
		move.w	6(a2),d0		;gChanCnt
		cmp.w	6(a0),d0		;Bleibt gleich?
		bne	VGetNew
		move.w	8(a2),d0		;gDataCnt
		cmp.w	8(a0),d0		;Bleibt gleich?
		beq	VSizeOK

VGetNew		move.w	8(a2),d0		;gDataCnt
		mulu.w	6(a2),d0		;* gChanCnt
		add.w	4(a2),d0		;gFormulaSize
		add.w	#12,d0
		dc.w	$a51e			;NewPtrSys
		bne	VControlErr		;Nicht gelungen, Fehler

		move.l	vGammaTable(a3),d0
		move.l	a0,vGammaTable(a3)
		tst.l	d0
		beq	VSizeOK

		move.l	d0,a0
		bsr	VFreeGamma

		move.l	vGammaTable(a3),a0
VSizeOK		move.w	6(a2),d0		;gChanCnt
		move.w	4(a2),d1		;gFormulaSize
		move.w	8(a2),d2		;gDataCnt
		move.l	(a2)+,(a0)+		;Header kopieren
		move.l	(a2)+,(a0)+
		move.l	(a2)+,(a0)+
		mulu.w	d0,d2
		add.w	d1,d2
		subq.w	#1,d2
1$		move.b	(a2)+,d0
		move.b	d0,(a0)+
		dbra	d2,1$
		bra	VReturnOK

VLinearTab	move.l	vGammaTable(a3),a0
		move.w	4(a0),d0		;dFormulaSize
		move.w	6(a0),d2		;dChanCnt
		subq.w	#1,d2
		add.w	#12,a0
		add.w	d0,a0
2$		move.w	#$ff,d0
1$		move.b	d0,(a0)
		not.b	(a0)+
		dbra	d0,1$
		dbra	d2,2$
		bra	VReturnOK

; Dispose gamma table a0, unless it is the one from the slot ROM: that one
; lies inside the sGammaDir block and is no block of its own.
VFreeGamma	move.l	a0,-(sp)
		move.l	vGammaDir(a3),a0
		dc.w	$a021			;GetPtrSize
		move.l	(sp)+,a0
		move.l	a0,d1
		sub.l	vGammaDir(a3),d1
		cmp.l	d0,d1
		blo	1$
		dc.w	$a01f			;DisposePtr
1$		rts

; Gray Page
VGrayPage	move.w	vCurrentMode(a3),(a2)	;csMode
		tst.w	6(a2)			;csPage=0?
		bne	VControlErr		;Nein, Fehler
		bra	VReturnOK

; SetGray
VSetGray	btst	#0,(a2)			;csMode, hier nur als Byte-Flag
		sne	vGrayFlag(a3)
		bra	VReturnOK

; SetInterrupt
VSetInterrupt	btst	#0,(a2)			;csMode, hier nur als Byte-Flag
		sne	vIntDisFlag(a3)
		bne	1$
		bsr	EnableVGuts		;Enable
		bra	VReturnOK
1$		bsr	DisableVGuts		;Disable
		bra	VReturnOK

EnableVGuts	move.l	vSQEl(a3),a0
		move.w	#6,4(a0)		;qType
		move.l	#BeginIH,6(a0)		;sqAddr
		clr.l	12(a0)			;sqParm
		move.b	$28(a1),d0		;dCtlSlot
		dc.w	$a075			;SIntInstall
		rts

DisableVGuts	move.b	dCtlSlot(a1),d0
		move.l	vSQEl(a3),a0
		dc.w	$a076			;SIntRemove
		rts

BeginIH		moveq	#1,d0
		rts

; DirectSetEntries
VDirectSetEntries
		bra	VControlErr

; SetDefaultMode
VSetDefaultMode	sub.w	#$38,sp
		move.l	sp,a0
		move.b	dCtlSlot(a1),$31(a0)
		clr.b	$33(a0)
		subq.w	#8,sp
		move.l	sp,(a0)
		moveq	#17,d0
		dc.w	$a06e			;SReadPRAMRec
		move.b	(a2),3(sp)		;csID
		move.l	sp,4(a0)
		moveq	#18,d0
		dc.w	$a06e			;SPutPRAMRec
		add.w	#$40,sp
		bra	VReturnOK

; Fehler/Rückkehr
VControlErr	moveq	#-17,d0			;Control Error
		bra	VReturn


*
* Status()-Routine
*

VideoStatus	movem.l	a0-a1,-(sp)
		move.w	csCode(a0),d0
		move.l	csParam(a0),a2
		move.l	dCtlStorage(a1),a3
		cmp.w	#9,d0
		bhi	VStatusErr

		DPRINTF	"VStatus slot %08lx, code %ld",$28(a1),d0

		jmp	([VStatusJmp,d0.w*4])

; Sprungtabelle für Status()
VStatusJmp	dc.l	VStatusErr
		dc.l	VStatusErr
		dc.l	VGetMode
		dc.l	VGetEntries
		dc.l	VGetPages
		dc.l	VGetPageBase
		dc.l	VGetGray
		dc.l	VGetInterrupt
		dc.l	VGetGamma
		dc.l	VGetDefaultMode

; GetMode
VGetMode	move.w	vCurrentMode(a3),(a2)	;csMode
		clr.w	6(a2)			;csPage
		move.l	vScrnBase(a3),8(a2)	;csBaseAddr
		bra	VReturnOK

; GetEntries
VGetEntries	move.l	(a2),d0			;csTable=NIL?
		beq	VStatusErr		;Ja, Fehler

		move.l	d0,a1
		lea	vLoadRGBColors(a3),a0
		move.w	6(a2),d1		;csCount
		move.w	4(a2),d0		;csStart
		bmi	VGetEntNoSeq		;Sequence?

VGetEntSeq	move.l	d3,-(sp)
1$		move.w	d0,d3			;12 Bytes je Eintrag, wie in VSetEntries
		mulu.w	#3,d3
		move.b	(a0,d3.w*4),d2
		move.b	d2,2(a1)
		move.b	d2,3(a1)
		move.b	4(a0,d3.w*4),d2
		move.b	d2,4(a1)
		move.b	d2,5(a1)
		move.b	8(a0,d3.w*4),d2
		move.b	d2,6(a1)
		move.b	d2,7(a1)
		addq.w	#1,d0
		addq.l	#8,a1
		dbra	d1,1$
		move.l	(sp)+,d3
		bra	VReturnOK

VGetEntNoSeq	move.l	d3,-(sp)
1$		move.w	(a1),d3			;Nein, Index holen
		mulu.w	#3,d3
		move.b	(a0,d3.w*4),d2
		move.b	d2,2(a1)
		move.b	d2,3(a1)
		move.b	4(a0,d3.w*4),d2
		move.b	d2,4(a1)
		move.b	d2,5(a1)
		move.b	8(a0,d3.w*4),d2
		move.b	d2,6(a1)
		move.b	d2,7(a1)
		addq.l	#8,a1
		dbra	d1,1$
		move.l	(sp)+,d3
		bra	VReturnOK

; GetPages
VGetPages	move.w	(a2),d1		;csMode
		bsr	VCheckMode
		bne	VStatusErr
		move.w	#1,6(a2)	;csPage
		bra	VReturnOK

; GetPageBase
VGetPageBase	move.w	vCurrentMode(a3),(a2)	;csMode
		tst.w	6(a2)			;csPage=0?
		bne	VStatusErr		;Nein, Fehler
		move.l	vScrnBase(a3),8(a2)	;csBaseAddr
		bra	VReturnOK

; GetGray
VGetGray	moveq	#1,d0
		and.b	vGrayFlag(a3),d0
		move.b	d0,(a2)
		bra	VReturnOK

; GetInterrupt
VGetInterrupt	moveq	#1,d0
		and.b	vIntDisFlag(a3),d0
		move.b	d0,(a2)
		bra	VReturnOK

; GetGamma
VGetGamma	move.l	vGammaTable(a3),(a2)
		bra	VReturnOK

; GetDefaultMode
VGetDefaultMode	sub.w	#$38,sp
		move.l	sp,a0
		move.b	dCtlSlot(a1),$31(a0)
		clr.b	$33(a0)
		subq.w	#8,sp
		move.l	sp,(a0)
		moveq	#17,d0
		dc.w	$a06e		;SReadPRAMRec
		move.b	3(sp),(a2)	;csID
		add.w	#$40,sp
		bra	VReturnOK

; Fehler
VStatusErr	moveq	#-18,d0		;Status Error
		bra	VReturn


*
* Close()-Routine
*

VideoClose	movem.l	a0-a1,-(sp)

; Zeiger auf Datenbereich holen
		move.l	dCtlStorage(a1),a3

; Interrupt abschalten
		bsr	DisableVGuts

; SlotQueueElem freigeben
		move.l	vSQEl(a3),a0
		dc.w	$a01f		;DisposePtr

; Gamma-Tabelle freigeben
		move.l	vGammaTable(a3),a0 ;eine von SetGamma angelegte Tabelle
		bsr	VFreeGamma
		move.l	vGammaDir(a3),a0 ;Zeiger auf Gamma-Directory
		dc.w	$a01f		;DisposePtr

; Rückkehr
		moveq	#0,d0
		movem.l	(sp)+,a0-a1
		rts


*
* Rückkehr aus Treiberroutine
*

VReturnOK	moveq	#0,d0

VReturn		movem.l	(sp)+,a0-a1

		btst	#noQueueBit-8,ioTrap(a0) ;Immediate call mit RTS beenden
		beq	Queued

NotQueued	move.w	d0,ioResult(a0)
		rts

Queued		move.l	JIODone,a0
		jmp	(a0)


*
* Modus d1 erlaubt? (eq=Ja)
*

VCheckMode	cmp.l	#VideoInfo1,a3
		bne	2$
		move.l	d0,-(sp)
		move.w	d1,d0
		sub.w	#$80,d0
		bmi	1$
		cmp.w	ModeCount1,d0
		bhs	1$
		move.l	(sp)+,d0
		cmp.w	d1,d1			;eq: gueltig
		rts
1$		move.l	(sp)+,d0
		cmp.w	#-1,d1			;ne
		rts
2$		cmp.w	vCurrentMode(a3),d1
		rts

		CNOP	0,4
		dc.b	"SHAPESHIFTER (FLY 5)",0
		CNOP	0,4

*
* Öffnen der Bildschirme
* In: ScreenX1/2, ScreenY1/2, VideoMode1/2, VideoType1/2, DisplayID1/2,
*     OverscanType1/2, BlackBorder1/2, MouseDirect, UserPort, EGSUserPort
* Out: BytesPerRow1/2, ScrnBase1/2
* Rückgabe: d0=1  NoScreen
*           d0=2  NoMem
*           d0=3  NoEGS
*           d0=4  NoTrueAmiga
*           d0=5  OnlyOneMacBox
*           d0=6  No124VGA
*           d0=7  NoCyberGfx
*           d0=8  NoCyberMode
*           d0=9  No16BitMode
*           d0=10 OnlyOneAmiga
*           d0=11 NoCyberMem
*           d0=12 CantLoadEVD
*           d0=13 IsNoEVD
*

; LoadRGB32 vorhanden?
OpenVideo	move.l	_GfxBase,a0
		cmp.w	#39,LIB_VERSION(a0)
		shs.b	HasGfx39

; Seitengrößen berechnen
		move.l	PageSize,d0
		lsr.l	#1,d0
		move.l	d0,PageSize2
		lsr.l	#1,d0
		move.l	d0,PageSize4
		lsr.l	#1,d0
		move.l	d0,PageSize8
		lsr.l	#1,d0
		move.l	d0,PageSize16
		move.l	PageSize,d0
		mulu.w	#3,d0
		lsr.l	#2,d0
		move.l	d0,PageSize3o4

; Defaults setzen (wichtig!)
		lea	VideoInfo1,a5
		move.l	#DefLockProc,vLockProc(a5)
		move.l	#DefRefProc,vRefProc(a5)
		move.l	#DefUnlockProc,vUnlockProc(a5)
		move.l	#DefPtrVisProc,vPtrVisProc(a5)
		move.l	#DefPtrInvProc,vPtrInvProc(a5)

		lea	VideoInfo2,a5
		move.l	#DefLockProc,vLockProc(a5)
		move.l	#DefRefProc,vRefProc(a5)
		move.l	#DefUnlockProc,vUnlockProc(a5)
		move.l	#DefPtrVisProc,vPtrVisProc(a5)
		move.l	#DefPtrInvProc,vPtrInvProc(a5)

; Bildschirme öffnen
		lea	VideoInfo1,a5
		move.w	VideoType1,vVideoType(a5)
		move.w	VideoMode1,vVideoMode(a5)
		move.w	OverscanType1,vOverscanType(a5)
		move.l	DisplayID1,vDisplayID(a5)
		move.l	ScreenX1,vScreenX(a5)
		move.l	ScreenY1,vScreenY(a5)
		move.l	#ExtVideoName1,vExtVideoName(a5)
		bsr	PrepDepthSwitch		;DEPTHSWITCH: Modi und fester Puffer
		bsr	DoOpenVideo
		tst.l	d0
		bne	OVError
		tst.b	FixedMismatch		;Passt der Bildschirm nicht zum
		beq	4$			; festen Puffer: ohne Wechsel
		bsr	DoCloseVideo
		bsr	FreeFixedBuf
		move.w	#1,ModeCount1
		clr.w	ModeStart1
		move.w	VideoMode1,vVideoMode(a5)
		bsr	DoOpenVideo
		tst.l	d0
		bne	OVError
4$		cmp.w	#1,ModeCount1		;Ein Modus: der geoeffnete
		bhi	5$
		move.w	vVideoMode(a5),ModeVM1
		move.l	vDisplayID(a5),ModeDID1
5$		move.w	vVideoMode(a5),VideoMode1	;Mac-In-A-Box und CyberGfx können ihn ändern
		move.l	vScrnBase(a5),ScrnBase1
		move.l	vBytesPerRow(a5),BytesPerRow1

		tst.w	NumMonitors
		beq	OVOnlyOneMon
		cmp.w	#VTYPE_MACINABOX,VideoType1
		beq	OVOnlyOneMacBox
		cmp.w	#VTYPE_MACINABOX,VideoType2
		beq	OVOnlyOneMacBox
		cmp.w	#VTYPE_AMIGA,VideoType1
		bne	1$
		cmp.w	#VTYPE_AMIGA,VideoType2
		beq	OVOnlyOneAmiga
1$		lea	VideoInfo2,a5
		move.w	VideoType2,vVideoType(a5)
		move.w	VideoMode2,vVideoMode(a5)
		move.w	OverscanType2,vOverscanType(a5)
		move.l	DisplayID2,vDisplayID(a5)
		move.l	ScreenX2,vScreenX(a5)
		move.l	ScreenY2,vScreenY(a5)
		move.l	#ExtVideoName2,vExtVideoName(a5)
		bsr	DoOpenVideo
		tst.l	d0
		bne	OVError
		move.w	vVideoMode(a5),VideoMode2
		move.l	vScrnBase(a5),ScrnBase2
		move.l	vBytesPerRow(a5),BytesPerRow2

; Refresh-Task einrichten, falls mindestens ein Bildschirm refresht wird
OVOnlyOneMon	cmp.w	#1,ModeCount1		;Farbtiefen wechselbar: der Refresh-
		bls	1$			; Task oeffnet die Bildschirme neu
		move.l	_ExecBase,a6
		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,SwitchDoneSig
		bmi	2$
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,SwitchDoneSet
		bra	3$
2$		move.w	#1,ModeCount1		;Kein Signal: nur ein Modus
		clr.w	ModeStart1
1$		tst.b	IsRefreshing		;Auch ohne Refresh auf eigenen Screens:
		bne	3$			; der Task aktiviert das Mac-Fenster,
		move.w	VideoType1,d0		; wenn der Screen nach vorn kommt
		cmp.w	#VTYPE_AMIGA,d0
		beq	3$
		cmp.w	#VTYPE_CYBER,d0
		bne	OVOK
3$		bsr	CreateRefTask
		tst.l	d0
		bne	OVErrNoMem

OVOK		moveq	#0,d0
OVError		rts
OVErrNoMem	moveq	#2,d0
		rts
OVOnlyOneMacBox	moveq	#5,d0
		rts
OVOnlyOneAmiga	moveq	#10,d0
		rts



*
* PrepDepthSwitch: mit DEPTHSWITCH bei einem Monitor die Modi bestimmen und
* den festen Puffer fuer den groessten belegen. a5: VideoInfo1 (noch zu)
*
PrepDepthSwitch	movem.l	d0-d7/a0-a6,-(sp)
		move.w	#1,ModeCount1
		clr.w	ModeStart1
		clr.b	FixedMismatch
		tst.l	DepthSwitch
		beq	9$
		bsr	BuildModes
		cmp.w	#1,ModeCount1
		bls	9$
		moveq	#0,d6			;d6: groesster Speicher
		moveq	#0,d7
1$		lea	ModeVM1,a0
		move.w	(a0,d7.w*2),d0
		move.l	vScreenX(a5),d1		;X << VMODE >> 3 * Y
		lsl.l	d0,d1
		lsr.l	#3,d1
		mulu.l	vScreenY(a5),d1
		cmp.l	d6,d1
		bls	2$
		move.l	d1,d6
2$		addq.w	#1,d7
		cmp.w	ModeCount1,d7
		blo	1$
		move.l	d6,d0
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		move.l	_ExecBase,a6
		JSRSELF	AllocMMU
		move.l	d0,FixedBuf
		beq	8$
		move.l	d6,FixedSize
		bra	9$
8$		move.w	#1,ModeCount1		;Kein Speicher: ohne Wechsel
		clr.w	ModeStart1
9$		movem.l	(sp)+,d0-d7/a0-a6
		rts

FreeFixedBuf	move.l	FixedBuf,d0
		beq	1$
		move.l	d0,a1
		move.l	FixedSize,d0
		move.l	_ExecBase,a6
		JSRLIB	FreeMem
		clr.l	FixedBuf
1$		rts

*
* BuildModes: die Farbtiefen, die der Mac fuer Monitor 1 waehlen kann.
* Nur bei einem Monitor mit Amiga-Bitplanes oder CyberGfx; sonst nur der
* eingestellte Modus. a5: VideoInfo1 (vVideoMode, vDisplayID, Groesse)
* Ergebnis: ModeCount1, ModeStart1, ModeVM1 (VMODE_), ModeDID1 (ModeID)
*
BuildModes	movem.l	d0-d7/a0-a6,-(sp)
		move.w	#1,ModeCount1
		clr.w	ModeStart1
		move.w	vVideoMode(a5),ModeVM1
		move.l	vDisplayID(a5),ModeDID1
		tst.w	NumMonitors
		bne	99$
		cmp.w	#VTYPE_AMIGA,vVideoType(a5)
		beq	10$
		cmp.w	#VTYPE_CYBER,vVideoType(a5)
		beq	20$
		bra	99$

; Amiga-Bitplanes: 1, 2, 4 und 8 Bit, soweit der Bildschirmmodus sie kann
10$		move.l	_GfxBase,a6
		sub.l	a0,a0
		lea	DimBuf,a1
		moveq	#DimBufSize,d0
		move.l	#DTAG_DIMS,d1
		move.l	vDisplayID(a5),d2
		JSRLIB	GetDisplayInfoData
		tst.l	d0
		beq	99$
		moveq	#0,d6
		move.w	DimBuf+dim_MaxDepth,d6	;d6: groesste Tiefe
		moveq	#0,d7			;d7: Anzahl Modi
		moveq	#VMODE_1BIT,d5		;d5: VMODE
11$		moveq	#0,d0
		bset	d5,d0			;Tiefe
		cmp.l	d6,d0
		bhi	12$
		cmp.w	#VMODE_8BIT,d5		;8 Bit nur mit V39 (Interleaved)
		bne	13$
		tst.b	HasGfx39
		beq	12$
13$		cmp.w	vVideoMode(a5),d5
		bne	14$
		move.w	d7,ModeStart1
14$		lea	ModeVM1,a0
		move.w	d5,(a0,d7.w*2)
		lea	ModeDID1,a0
		move.l	vDisplayID(a5),(a0,d7.w*4)
		addq.w	#1,d7
12$		addq.w	#1,d5
		cmp.w	#VMODE_8BIT,d5
		bls	11$
		bra	90$

; CyberGfx: 256 Farben, Tausende (15, sonst 16 Bit), Millionen (32, sonst
; 24 Bit), jeweils ein Modus derselben Groesse
20$		bsr	OpenCyberGfx
		beq	99$
		moveq	#0,d7
		moveq	#VMODE_8BIT,d5
21$		cmp.w	vVideoMode(a5),d5	;Die eingestellte Tiefe: ihr Modus
		bne	22$
		move.l	vDisplayID(a5),d4
		move.w	d7,ModeStart1
		bra	25$
22$		moveq	#8,d0			;Sonst einen suchen
		cmp.w	#VMODE_8BIT,d5
		beq	23$
		moveq	#15,d0
		cmp.w	#VMODE_15BIT,d5
		bne	24$
		bsr	FindCyberMode
		tst.l	d0
		bne	26$
		moveq	#16,d0
		bra	23$
24$		moveq	#32,d0
		bsr	FindCyberMode
		tst.l	d0
		bne	26$
		moveq	#24,d0
23$		bsr	FindCyberMode
		tst.l	d0
		beq	27$
26$		move.l	d0,d4
25$		lea	ModeVM1,a0
		move.w	d5,(a0,d7.w*2)
		lea	ModeDID1,a0
		move.l	d4,(a0,d7.w*4)
		addq.w	#1,d7
27$		addq.w	#1,d5
		cmp.w	#VMODE_24BIT,d5
		bls	21$

90$		tst.w	d7			;Startmodus muss dabei sein
		beq	98$
		move.w	ModeStart1,d0
		lea	ModeVM1,a0
		move.w	(a0,d0.w*2),d0
		cmp.w	vVideoMode(a5),d0
		bne	98$
		move.w	d7,ModeCount1
		bra	99$
98$		move.w	#1,ModeCount1		;Sonst nur der eingestellte Modus
		clr.w	ModeStart1
		move.w	vVideoMode(a5),ModeVM1
		move.l	vDisplayID(a5),ModeDID1
99$		movem.l	(sp)+,d0-d7/a0-a6
		rts

; CyberGfx-Modus mit Tiefe d0 und der Groesse von a5 suchen, den die
; Umrechnung kann: alle ModeIDs der Display-Datenbank durchgehen, zuerst die
; derselben Karte (obere 16 Bits wie vDisplayID), dann alle.
; Rueckgabe d0: ModeID oder 0
FindCyberMode	movem.l	d1-d5/a0-a1/a6,-(sp)
		move.l	d0,d3			;d3: Tiefe
		tst.l	_CyberGfxBase
		beq	8$
		moveq	#1,d5			;d5: 1 = nur diese Karte, 0 = alle
1$		move.l	#INVALID_ID,d2		;d2: ModeID
2$		move.l	_GfxBase,a6
		move.l	d2,d0
		JSRLIB	NextDisplayInfo
		move.l	d0,d2
		cmp.l	#INVALID_ID,d2
		beq	7$
		tst.l	d5
		beq	3$
		move.l	d2,d0
		move.l	vDisplayID(a5),d1
		swap	d0
		swap	d1
		cmp.w	d1,d0
		bne	2$
3$		move.l	d2,d0
		bsr	CyberModeOK
		beq	2$
		move.l	d2,d0			;Gefunden
		bra	9$
7$		subq.l	#1,d5			;Danach alle Karten
		beq	1$
8$		moveq	#0,d0
9$		movem.l	(sp)+,d1-d5/a0-a1/a6
		rts

; Ist ModeID d0 ein CyberGfx-Modus mit Tiefe d3, der Groesse von a5 und
; einem Pixelformat, das DoOpenCyber kann? Rueckgabe d0 (Z): 0 = nein
CyberModeOK	movem.l	d1-d2/a0-a1/a6,-(sp)
		move.l	d0,d2
		move.l	_CyberGfxBase,a6
		jsr	IsCyberModeID(a6)
		tst.l	d0
		beq	8$
		move.l	#CYBRIDATTR_DEPTH,d0
		move.l	d2,d1
		jsr	GetCyberIDAttr(a6)
		cmp.l	d3,d0
		bne	8$
		move.l	#CYBRIDATTR_WIDTH,d0
		move.l	d2,d1
		jsr	GetCyberIDAttr(a6)
		cmp.l	vScreenX(a5),d0
		bne	8$
		move.l	#CYBRIDATTR_HEIGHT,d0
		move.l	d2,d1
		jsr	GetCyberIDAttr(a6)
		cmp.l	vScreenY(a5),d0
		bne	8$
		move.l	#CYBRIDATTR_PIXFMT,d0
		move.l	d2,d1
		jsr	GetCyberIDAttr(a6)
		lea	PixFmtOK15,a0
		cmp.l	#15,d3
		beq	1$
		lea	PixFmtOK16,a0
		cmp.l	#16,d3
		beq	1$
		lea	PixFmtOK24,a0
		cmp.l	#8,d3
		bne	1$
		lea	PixFmtOK8,a0
1$		move.l	(a0)+,d1
		bmi	8$
		cmp.l	d1,d0
		bne	1$
		moveq	#-1,d0
		bra	9$
8$		moveq	#0,d0
9$		movem.l	(sp)+,d1-d2/a0-a1/a6
		tst.l	d0
		rts

PixFmtOK8	dc.l	PIXFMT_LUT8,-1
PixFmtOK15	dc.l	PIXFMT_RGB15,PIXFMT_RGB15PC,PIXFMT_BGR15PC,-1
PixFmtOK16	dc.l	PIXFMT_RGB16,PIXFMT_RGB16PC,-1
PixFmtOK24	dc.l	PIXFMT_RGB24,PIXFMT_BGR24,PIXFMT_ARGB32,PIXFMT_BGRA32,PIXFMT_RGBA32,-1


*
* DoSwitch: Farbtiefe wechseln, im Refresh-Task (Auftrag von VSwitchMode).
* Der Mac wartet und zeichnet in den festen Puffer, der bleibt.
*
DoSwitch	movem.l	d0-d7/a0-a6,-(sp)
		move.l	SwitchReq,a5
		move.w	vVideoMode(a5),d6	;d6/d7: alte Farbtiefe und ModeID
		move.l	vDisplayID(a5),d7

		bsr	DoCloseVideo		;Alten Bildschirm zu (nur einer darf
		move.w	SwitchVM,d0		; offen sein), neuen oeffnen
		move.l	SwitchDID,d1
		bsr	ReopenVideo
		bne	8$
		clr.w	SwitchRes
		bra	7$

8$		move.w	#1,SwitchRes		;Nicht gegangen: die alte Farbtiefe
		bsr	DoCloseVideo
		move.w	d6,d0
		move.l	d7,d1
		bsr	ReopenVideo

7$		tst.b	PointerBlank		;Mac-Zeiger: Amiga-Zeiger weg
		beq	3$
		tst.l	vWindow(a5)
		beq	3$
		move.l	_UtilityBase,a6
		lea	ExtPtrOutTags,a0
		lea	ExtPtrInTags,a1
		move.l	vContext(a5),a2
		move.l	vPtrInvProc(a5),a3
		jsr	(a3)
3$		move.w	vVideoMode(a5),VideoMode1
		move.l	vScrnBase(a5),ScrnBase1
		move.l	vBytesPerRow(a5),BytesPerRow1
		bsr	SetAccel

9$		clr.l	SwitchReq		;Fertig, dem Mac Bescheid sagen
		move.l	_ExecBase,a6
		move.l	MyTask,a1
		move.l	SwitchDoneSet,d0
		JSRLIB	Signal
		movem.l	(sp)+,d0-d7/a0-a6
		rts

; Bildschirm a5 (geschlossen) mit Farbtiefe d0 und ModeID d1 oeffnen.
; Rueckgabe Z: gelungen (und passt zum festen Puffer)
ReopenVideo	movem.l	d1-d7/a0-a6,-(sp)
		clr.l	vScreen(a5)
		clr.l	vWindow(a5)
		clr.l	vRefreshMem(a5)
		clr.l	vRefPageTable(a5)
		clr.l	vComparisonBuf(a5)
		clr.l	vCyberLock(a5)
		move.l	#DefLockProc,vLockProc(a5)
		move.l	#DefRefProc,vRefProc(a5)
		move.l	#DefUnlockProc,vUnlockProc(a5)
		move.l	#DefPtrVisProc,vPtrVisProc(a5)
		move.l	#DefPtrInvProc,vPtrInvProc(a5)
		move.w	d0,vVideoMode(a5)
		move.l	d1,vDisplayID(a5)
		clr.b	IsDeltaRefresh
		clr.b	FixedMismatch
		bsr	DoOpenVideo
		tst.b	FixedMismatch
		beq	1$
		moveq	#1,d0
1$		movem.l	(sp)+,d1-d7/a0-a6
		tst.l	d0
		rts

; QuickDraw-Beschleunigung nur auf direkt dargestellten CyberGfx-Bildschirmen
; (FastLine nur in 8 Bit). a5: VideoInfo1
SetAccel	clr.b	AccelBltOK
		clr.b	AccelLineOK
		cmp.w	#VTYPE_CYBER,vVideoType(a5)
		bne	9$
		cmp.l	#DefRefProc,vRefProc(a5)
		bne	9$
		move.l	vScreen(a5),a0
		lea	sc_RastPort(a0),a0
		move.l	a0,QDRastPort1
		st	AccelBltOK
		cmp.w	#VMODE_8BIT,vVideoMode(a5)
		bne	9$
		st	AccelLineOK
9$		rts

*
* Refresh-Task erzeugen
*

; Task starten
CreateRefTask	move.l	_DOSBase,a6
		move.l	#ProcTags,d1
		JSRLIB	CreateNewProc
		move.l	d0,RefTaskProc
		beq	1$

; Auf Signal warten
		move.l	_ExecBase,a6
		move.l	SubtaskSet,d0
		JSRLIB	Wait
		moveq	#0,d0
		rts

1$		moveq	#-1,d0
		rts


*
* Refresh-Task vernichten
*

; Task stoppen
DeleteRefTask	move.l	_ExecBase,a6
		move.l	RefTask,d0
		beq	1$
		move.l	d0,a1
		move.l	RefQuitSet,d0
		JSRLIB	Signal
		move.l	SubtaskSet,d0
		JMPLIB	Wait
1$		rts


*
* Einen Bildschirm öffnen, a5: VideoInfo
*

DoOpenVideo	move.w	vVideoType(a5),d0
		cmp.w	#VTYPE_CYBER,d0
		beq	DoOpenCyber
		cmp.w	#VTYPE_EGS,d0
		beq	DoOpenEGS
		cmp.w	#VTYPE_MACINABOX,d0
		beq	DoOpenMacBox
		cmp.w	#VTYPE_EXTERNAL,d0
		beq	DoOpenExternal

*
* Öffnen eines Bildschirms als Amiga-Screen
*

; Prozeduren setzen
DoOpenAmiga1	move.l	#BplLockProc,vLockProc(a5)

; Screen-Tiefe berechnen
		move.w	vVideoMode(a5),d0
		cmp.w	#VMODE_15BIT,d0		;Amiga-Screens nur bis 8 Bit
		bhs	DOVNoTrueAmiga
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,ScreenDepth

; Screen-Eigenschaften setzen
		move.l	vScreenX(a5),d0
		move.l	vScreenY(a5),d1
		move.l	d0,ScreenWidth
		move.l	d1,ScreenHeight
		move.l	d0,WindowWidth
		move.l	d1,WindowHeight
		move.l	vDisplayID(a5),ScreenDID
		move.w	vOverscanType(a5),ScreenOScan+2

		clr.l	ScreenInterl
		cmp.w	#VMODE_8BIT,vVideoMode(a5)
		bne	1$
		move.l	#-1,ScreenInterl
1$

; Overscan-Rect holen
		move.l	_IntuitionBase,a6
		move.l	vDisplayID(a5),a0
		lea	TheRect,a1
		moveq	#0,d0
		move.w	vOverscanType(a5),d0
		JSRLIB	QueryOverscan
		tst.l	d0
		beq	3$
		lea	TheRect,a0
		move.w	ra_MinX(a0),ScreenLeft+2
		move.w	ra_MinY(a0),ScreenTop+2
3$

; Screen öffnen
		move.l	_IntuitionBase,a6
		sub.l	a0,a0
		lea	ScreenTags,a1
		JSRLIB	OpenScreenTagList
		move.l	d0,vScreen(a5)
		move.l	d0,WindowScreen
		beq	DOVNoScreen

; 8 Bit: Die Bitmap muss wirklich interleaved sein. graphics.library faellt
; still auf getrennte Planes zurueck, wenn kein zusammenhaengender Chip-Block
; fuer die ganze Bitmap frei ist (z.B. 640x480x8 = 300KB); Refresh8Bit
; schreibt dann alle Planes in Plane 0 (weisser Bildschirm). Lieber Fehler.
		cmp.w	#VMODE_8BIT,vVideoMode(a5)
		bne	5$
		tst.b	HasGfx39
		beq	5$
		move.l	_GfxBase,a6
		move.l	vScreen(a5),a0
		lea	sc_RastPort(a0),a0
		move.l	rp_BitMap(a0),a0
		moveq	#BMA_FLAGS,d1
		JSRLIB	GetBitMapAttr
		btst	#BMB_INTERLEAVED,d0
		bne	5$
		move.l	_IntuitionBase,a6
		move.l	vScreen(a5),a0
		JSRLIB	CloseScreen
		clr.l	vScreen(a5)
		clr.l	WindowScreen
		bra	DOVNoScreen
5$

; Zeiger auf ViewPort und BitMap und Daten aus BitMap holen
		move.l	vScreen(a5),a0
		lea	sc_ViewPort(a0),a0
		move.l	a0,vViewPort(a5)
		move.l	vScreen(a5),a0
		lea	sc_RastPort(a0),a0
		move.l	rp_BitMap(a0),a0
		move.l	a0,vBitMap(a5)
		move.l	bm_Planes(a0),vScrnBase(a5)

		cmp.w	#VMODE_8BIT,vVideoMode(a5)
		beq	2$
		moveq	#0,d0
		move.w	bm_BytesPerRow(a0),d0
		tst.l	FixedBuf		;Fester Puffer: Planes ohne Luecke?
		beq	6$
		move.l	vScreenX(a5),d1
		lsr.l	#3,d1
		cmp.l	d1,d0
		beq	6$
		st	FixedMismatch
		bra	DoOpenWindow
6$		move.w	vVideoMode(a5),d1
		lsl.l	d1,d0
		move.l	d0,vBytesPerRow(a5)
		bra	4$

; 8 Bit: the Mac buffer's row is as long as the bitmap's, not ScreenX. The
; bitmap is interleaved, so bm_BytesPerRow is the length of all 8 plane rows
; together = the Mac's bytes per row. AGA rounds a row up to 64 pixels: 800
; wide has 832-pixel rows. With ScreenX the planes were written at the wrong
; distance and the picture was garbage.
2$		moveq	#0,d0
		move.w	bm_BytesPerRow(a0),d0
		tst.l	FixedBuf		;Fixed buffer: its rows are ScreenX long
		beq	8$
		cmp.l	vScreenX(a5),d0
		beq	8$
		st	FixedMismatch
		bra	DoOpenWindow
8$		move.l	d0,vBytesPerRow(a5)

; Refresh-Kram einrichten
4$		cmp.w	#VMODE_1BIT,vVideoMode(a5)	;Bei 1 Bit kein Refresh
		bne	7$
		tst.l	FixedBuf		; (ausser mit dem festen Puffer)
		beq	DoOpenWindow
		move.l	#RefPlainCopy,vRefProc(a5)
		bra	10$
7$
		move.w	vVideoMode(a5),d0
		move.l	(AmigaRefProcTab,d0.w*4),vRefProc(a5)

		cmp.w	#VMODE_8BIT,vVideoMode(a5)	;Argl! Selbstmodifizierender Code!
		bne	10$
		move.l	vBytesPerRow(a5),d0
		lsr.l	#3,d0
		move.l	d0,d1
		lea	m8a+2,a0
		lea	m8b+2,a1
		lea	m8a2+2,a2
		lea	m8b2+2,a3
		move.w	d0,6(a1)
		move.w	d0,6(a3)
		add.w	d1,d0
		move.w	d0,12(a1)
		move.w	d0,12(a3)
		add.w	d1,d0
		move.w	d0,(a1)
		move.w	d0,(a3)
		add.w	d1,d0
		move.w	d0,18(a0)
		move.w	d0,18(a2)
		add.w	d1,d0
		move.w	d0,6(a0)
		move.w	d0,6(a2)
		add.w	d1,d0
		move.w	d0,12(a0)
		move.w	d0,12(a2)
		add.w	d1,d0
		move.w	d0,(a0)
		move.w	d0,(a2)
		move.w	d0,madd+2
		move.w	d0,madd2+2
		move.l	_ExecBase,a6
		JSRLIB	CacheClearU
10$
		bsr	AllocRefMem
		tst.l	d0
		bne	DOVNoMem

		tst.w	MMURefresh
		bne	11$
		move.l	_ExecBase,a6		;Keine MMU, dann Comparison Buffer holen
		move.l	vScreenBytes(a5),d0
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		JSRLIB	AllocMem
		move.l	d0,vComparisonBuf(a5)
		beq	11$			;Nicht gelungen, dann ohne Puffer
		st.b	IsDeltaRefresh

11$		st.b	IsRefreshing		;Refresh-Task erzeugen

; Fenster öffnen
		bra	DoOpenWindow

*
* Öffnen eines Bildschirms als Cyber-Screen
*

; Prozeduren setzen
DoOpenCyber	move.l	#CybLockProc,vLockProc(a5)

; cybergraphics.library öffnen
		bsr	OpenCyberGfx
		beq	DOVNoCyberGfx

; CyberGfx-Modus?
		move.l	_CyberGfxBase,a6
		move.l	vDisplayID(a5),d0
		jsr	IsCyberModeID(a6)
		tst.l	d0
		beq	DOVNoCyberMode

; Farbtiefe holen, 16-Bit-Modus abfangen
		move.l	#CYBRIDATTR_DEPTH,d0
		move.l	vDisplayID(a5),d1
		jsr	GetCyberIDAttr(a6)
		move.l	d0,CyberScrDepth

		cmp.l	#16,d0			;16 Bit: geht mit RGB565 (Mac: 15 Bit + Umrechnung)
		bne	29$
		move.l	#CYBRIDATTR_PIXFMT,d0
		move.l	vDisplayID(a5),d1
		jsr	GetCyberIDAttr(a6)
		cmp.l	#PIXFMT_RGB16,d0
		beq	28$
		cmp.l	#PIXFMT_RGB16PC,d0
		bne	DOVNo16BitMode
28$		move.w	#VMODE_15BIT,vVideoMode(a5)
		bra	22$
29$
		cmp.l	#8,d0
		bne	20$
		move.w	#VMODE_8BIT,vVideoMode(a5)
		bra	22$
20$		cmp.l	#15,d0
		bne	21$
		move.w	#VMODE_15BIT,vVideoMode(a5)
		bra	22$
21$		move.w	#VMODE_24BIT,vVideoMode(a5)
22$

; Screen-Eigenschaften setzen
		move.l	vScreenX(a5),d0
		move.l	vScreenY(a5),d1
		move.l	d0,CyberScrWidth
		move.l	d1,CyberScrHeight
		move.l	d0,WindowWidth
		move.l	d1,WindowHeight
		move.l	vDisplayID(a5),CyberScreenDID

; Screen öffnen
		move.l	_IntuitionBase,a6
		sub.l	a0,a0
		lea	CyberScreenTags,a1
		JSRLIB	OpenScreenTagList
		move.l	d0,vScreen(a5)
		move.l	d0,WindowScreen
		beq	DOVNoScreen

; Daten holen
		move.l	vScreen(a5),a0
		lea	sc_ViewPort(a0),a0
		move.l	a0,vViewPort(a5)
		move.l	vScreen(a5),a0
		lea	sc_RastPort(a0),a0
		move.l	rp_BitMap(a0),vBitMap(a5)

; Adresse des Grafikspeichers ermitteln
		move.l	_IntuitionBase,a6
1$		move.l	vScreen(a5),a0
		JSRLIB	ScreenToFront
		move.l	vScreen(a5),d0
		cmp.l	ib_FirstScreen(a6),d0
		bne	1$

		move.l	_CyberGfxBase,a6
		move.l	vBitMap(a5),a0
		move.l	#CYBRMATTR_DISPADR,d0
		jsr	GetCyberMapAttr(a6)
		move.l	d0,vScrnBase(a5)

		cmp.l	#-1,d0
		beq	DOVNoCyberMem

		bsr	PrismPinScreen		;PrismRTG: Grafikspeicher festhalten

		move.l	vBitMap(a5),a0
		move.l	#CYBRMATTR_WIDTH,d0
		jsr	GetCyberMapAttr(a6)
		tst.l	FixedBuf		;Fester Puffer: gleiche Breite?
		beq	26$
		cmp.l	vScreenX(a5),d0
		beq	26$
		st	FixedMismatch
		bra	DoOpenWindow
26$		move.w	vVideoMode(a5),d1
		lsl.l	d1,d0
		lsr.l	#3,d0
		move.l	d0,vBytesPerRow(a5)

; Refresh-Kram einrichten
		move.l	_CyberGfxBase,a6
		move.l	vBitMap(a5),a0
		move.l	#CYBRMATTR_PIXFMT,d0
		jsr	GetCyberMapAttr(a6)

		cmp.l	#PIXFMT_LUT8,d0
		bne	17$
		tst.w	RefreshAlways
		bne	18$
		tst.l	FixedBuf
		beq	DoOpenWindow
18$		move.l	#RefPlainCopy,vRefProc(a5)
		bra	19$
17$
		cmp.l	#PIXFMT_RGB15,d0
		beq	27$

	;PIXFMT_BGR15 !!

		cmp.l	#PIXFMT_RGB16PC,d0	;RGB565, Intel-Byteordnung
		bne	24$
		move.l	#RefRGB16PC,vRefProc(a5)
		bra	19$
24$		cmp.l	#PIXFMT_RGB16,d0	;RGB565, Motorola-Byteordnung
		bne	25$
		move.l	#RefRGB16,vRefProc(a5)
		bra	19$
25$
		cmp.l	#PIXFMT_RGB15PC,d0
		bne	11$
		move.l	#RefRGB15PC,vRefProc(a5)
		bra	19$
11$
		cmp.l	#PIXFMT_BGR15PC,d0
		bne	12$
		move.l	#RefBGR15PC,vRefProc(a5)
		bra	19$
12$
		cmp.l	#PIXFMT_RGB24,d0
		bne	13$
		move.l	#RefRGB24,vRefProc(a5)
		bra	19$
13$
		cmp.l	#PIXFMT_BGR24,d0
		bne	14$
		move.l	#RefBGR24,vRefProc(a5)
		bra	19$
14$
		cmp.l	#PIXFMT_ARGB32,d0
		beq	27$

		cmp.l	#PIXFMT_BGRA32,d0
		bne	15$
		move.l	#RefBGRA32,vRefProc(a5)
		bra	19$
15$
		cmp.l	#PIXFMT_RGBA32,d0
		bne	16$
		move.l	#RefRGBA32,vRefProc(a5)
		bra	19$
16$
27$		tst.l	FixedBuf		;Direkt dargestellt: mit dem festen
		beq	DoOpenWindow		; Puffer eine Kopie
		move.l	#RefPlainCopy,vRefProc(a5)

19$		bsr	AllocRefMem
		tst.l	d0
		bne	DOVNoMem
		st.b	IsRefreshing		;Refresh-Task erzeugen

; Fenster öffnen
		bra	DoOpenWindow

*
* Externen Treiber öffnen
*

; Treiber laden und Zeiger auf Code holen
DoOpenExternal	move.l	_DOSBase,a6
		move.l	vExtVideoName(a5),d1
		JSRLIB	LoadSeg
		move.l	d0,vSegment(a5)
		beq	DOVCantLoadEV

		add.l	d0,d0
		add.l	d0,d0
		addq.l	#4,d0
		move.l	d0,a0

; ID vorhanden?
		cmp.l	#"SHAP",shev_ID(a0)
		bne	DOVIsNoEV
		cmp.l	#"EEXV",shev_ID+4(a0)
		bne	DOVIsNoEV

		move.l	shev_Tags(a0),a0
		move.l	a0,vTagList(a5)

; Mindestens Level 1?
		move.l	_UtilityBase,a6
		move.l	vTagList(a5),a0
		move.l	#SHEV_Level,d0
		moveq	#0,d1
		JSRLIB	GetTagData
		cmp.l	#1,d0
		blo	DOVIsNoEV

; Routinen extrahieren
		move.l	_UtilityBase,a6
		move.l	vTagList(a5),a0
		move.l	#SHEV_OpenScreen,d0
		moveq	#0,d1
		JSRLIB	GetTagData
		move.l	d0,vExtOpenScreen(a5)
		beq	DOVIsNoEV

		move.l	vTagList(a5),a0
		move.l	#SHEV_CloseScreen,d0
		moveq	#0,d1
		JSRLIB	GetTagData
		move.l	d0,vExtCloseScreen(a5)
		beq	DOVIsNoEV

		move.l	vTagList(a5),a0
		move.l	#SHEV_LockDisplay,d0
		move.l	#DefLockProc,d1
		JSRLIB	GetTagData
		move.l	d0,vLockProc(a5)

		move.l	vTagList(a5),a0
		move.l	#SHEV_UnlockDisplay,d0
		move.l	#DefUnlockProc,d1
		JSRLIB	GetTagData
		move.l	d0,vUnlockProc(a5)

		move.l	vTagList(a5),a0
		move.l	#SHEV_Refresh,d0
		move.l	#DefRefProc,d1
		JSRLIB	GetTagData
		move.l	d0,vRefProc(a5)

		move.l	vTagList(a5),a0
		move.l	#SHEV_LoadRGB32,d0
		moveq	#0,d1
		JSRLIB	GetTagData
		move.l	d0,vLoadRGB32(a5)

		move.l	vTagList(a5),a0
		move.l	#SHEV_PointerVisible,d0
		move.l	#DefPtrVisProc,d1
		JSRLIB	GetTagData
		move.l	d0,vPtrVisProc(a5)

		move.l	vTagList(a5),a0
		move.l	#SHEV_PointerInvisible,d0
		move.l	#DefPtrInvProc,d1
		JSRLIB	GetTagData
		move.l	d0,vPtrInvProc(a5)

; Parameter für OpenScreen vorbereiten
		move.l	vScreenX(a5),d0
		move.l	vScreenY(a5),d1
		move.l	d0,ExtScrWidth
		move.l	d1,ExtScrHeight
		move.l	d0,WindowWidth
		move.l	d1,WindowHeight
		move.l	vDisplayID(a5),ExtScreenDID
		move.w	vVideoMode(a5),ExtVideoMode+2
		move.w	vOverscanType(a5),ExtOverscan+2

; OpenScreen aufrufen
		lea	ExtOSOutTags,a0
		lea	ExtOSInTags,a1
		move.l	_UtilityBase,a6
		move.l	vExtOpenScreen(a5),a3
		jsr	(a3)

		move.l	ExtOSContext,vContext(a5)	;Für CloseVideo wichtig

		tst.l	d0
		bne	DOVNoScreen

; Gelungen, Daten entnehmen
		move.l	ExtOSScreen,vScreen(a5)
		move.l	ExtOSScreen,WindowScreen
		move.l	ExtOSScreenBase,vScrnBase(a5)
		move.l	ExtOSBPR,vBytesPerRow(a5)
		move.l	ExtOSRefType,vRefreshType(a5)

		btst	#SHEVB_DblWidthWin,ExtOSFlags+3 ;Flag für Graffiti: Doppelt so breites Fenster öffnen
		beq	1$
		move.l	WindowWidth,d0
		add.l	d0,d0
		move.l	d0,WindowWidth
1$

; Refresh-Kram einrichten
		move.l	vRefreshType(a5),d0
		beq	20$

		cmp.l	#RTYPE_CUSTOM,d0
		bne	10$

		move.l	#DefLockProc,vLockProc(a5)	;Custom
		move.l	#DefUnlockProc,vUnlockProc(a5)
		st.b	IsRefreshing			;Refresh-Task erzeugen
		bra	DoOpenWindow

10$		sub.l	#2,d0				;Speziell
		move.l	(ExtRefProcTab,d0.w*4),vRefProc(a5)

		move.l	vScreenX(a5),d0			;Mac-BytesPerRow ausrechnen
		move.w	vVideoMode(a5),d1
		lsl.l	d1,d0
		lsr.l	#3,d0
		move.l	d0,vBytesPerRow(a5)

		bsr	AllocRefMem
		tst.l	d0
		bne	DOVNoMem
		st.b	IsRefreshing			;Refresh-Task erzeugen
		bra	DoOpenWindow

20$		move.l	#DefRefProc,vRefProc(a5)
		move.l	#DefLockProc,vLockProc(a5)
		move.l	#DefUnlockProc,vUnlockProc(a5)
		bra	DoOpenWindow

*
* Fenster öffnen
*

; Rahmen schwärzen (nur Amiga)
DoOpenWindow	cmp.w	#VTYPE_AMIGA,vVideoType(a5)
		bne	1$
		tst.w	BlackBorder
		beq	1$
		move.l	_GfxBase,a6
		move.l	vScreen(a5),a0
		move.l	sc_ViewPort+vp_ColorMap(a0),a0
		lea	VideoTags,a1
		JSRLIB	VideoControl
		move.l	_IntuitionBase,a6
		move.l	vScreen(a5),a0
		JSRLIB	MakeScreen
		JSRLIB	RethinkDisplay
1$

; Fenster öffnen
		move.l	_IntuitionBase,a6
		sub.l	a0,a0
		lea	WindowTags,a1
		JSRLIB	OpenWindowTagList
		move.l	d0,vWindow(a5)
		beq	DOVNoScreen

; Window-MessagePort setzen und Messages anschalten
		move.l	vWindow(a5),a0
		move.l	UserPort,wd_UserPort(a0)

		move.l	#IDCMP_RAWKEY|IDCMP_MOUSEBUTTONS,d2
		tst.w	MouseDirect
		bne	2$
		or.l	#IDCMP_MOUSEMOVE,d2
		tst.w	UseAmigaMouse
		bne	3$
		or.l	#IDCMP_DELTAMOVE,d2
3$		move.l	vWindow(a5),a0
		moveq	#-1,d0
		JSRLIB	ReportMouse
2$		move.l	vWindow(a5),a0
		move.l	d2,d0
		JSRLIB	ModifyIDCMP

		moveq	#0,d0			;Alles OK
		rts

*
* Öffnen des Mac-In-A-Box-Fensters
*

; Prozeduren setzen
DoOpenMacBox	move.l	#WinPtrVisProc,vPtrVisProc(a5)
		move.l	#WinPtrInvProc,vPtrInvProc(a5)

		clr.l	vScreen(a5)
		clr.l	vViewPort(a5)

; Erst als P96-PIP versuchen
		tst.l	_P96Base
		bne	1$

		move.l	_ExecBase,a6
		lea	P96Name,a1
		moveq	#2,d0
		JSRLIB	OpenLibrary
		move.l	d0,_P96Base
		beq	OpenMacBoxMono

; PIP öffnen
1$		move.l	vScreenX(a5),PIPWidth1
		move.l	vScreenX(a5),PIPWidth2
		move.l	vScreenY(a5),PIPHeight1
		move.l	vScreenY(a5),PIPHeight2
		move.l	_P96Base,a6
		lea	PIPTags,a0
		jsr	p96PIP_OpenTagList(a6)
		move.l	d0,vWindow(a5)
		beq	OpenMacBoxMono

; Bitmap holen, Framebuffer und XMod ermitteln
		move.w	#VMODE_15BIT,vVideoMode(a5)
		move.l	vWindow(a5),a0
		lea	PIPBitmapTags,a1
		jsr	p96PIP_GetTagList(a6)
		move.l	PIPBitmap,a0
		move.l	#P96BMA_MEMORY,d0
		jsr	p96GetBitMapAttr(a6)
		move.l	d0,vScrnBase(a5)
		move.l	PIPBitmap,a0
		move.l	#P96BMA_BYTESPERROW,d0
		jsr	p96GetBitMapAttr(a6)
		move.l	d0,vBytesPerRow(a5)

; Window-MessagePort setzen und Messages anschalten
		move.l	vWindow(a5),a0
		move.b	wd_BorderLeft(a0),BoxBorderLeft+1
		move.b	wd_BorderTop(a0),BoxBorderTop+1
		move.l	UserPort,wd_UserPort(a0)

		move.l	_IntuitionBase,a6
		move.l	vWindow(a5),a0
		moveq	#-1,d0
		JSRLIB	ReportMouse
		move.l	vWindow(a5),a0
		move.l	#IDCMP_RAWKEY|IDCMP_MOUSEBUTTONS|IDCMP_MOUSEMOVE,d0
		JSRLIB	ModifyIDCMP

		moveq	#0,d0
		rts

; Monochromes Fenster öffnen
OpenMacBoxMono	move.w	#VMODE_1BIT,vVideoMode(a5)
		move.l	vScreenX(a5),BoxWinWidth
		move.l	vScreenY(a5),BoxWinHeight
		move.l	_IntuitionBase,a6
		sub.l	a0,a0
		lea	BoxWinTags,a1
		JSRLIB	OpenWindowTagList
		move.l	d0,vWindow(a5)
		beq	DOVNoMem

; Bitmap holen
		move.l	_GfxBase,a6
		tst.b	HasGfx39
		beq	3$

		move.l	vScreenX(a5),d0		;V39
		move.l	vScreenY(a5),d1
		moveq	#1,d2
		moveq	#BMF_CLEAR,d3
		sub.l	a0,a0
		JSRLIB	AllocBitMap
		move.l	d0,vBitMap(a5)
		beq	DOVNoMem
		bra	4$

3$		lea	MacBoxBitMap,a0
		moveq	#1,d0			;Depth
		move.l	vScreenX(a5),d1
		move.l	vScreenY(a5),d2
		JSRLIB	InitBitMap

		move.l	vScreenX(a5),d0
		move.l	vScreenY(a5),d1
		JSRLIB	AllocRaster
		lea	MacBoxBitMap,a0
		move.l	d0,bm_Planes(a0)
		beq	DOVNoMem
		move.l	a0,vBitMap(a5)

; Daten aus Bitmap holen
4$		move.l	vBitMap(a5),a2
		move.l	bm_Planes(a2),vScrnBase(a5)
		moveq	#0,d0
		move.w	bm_BytesPerRow(a2),d0
		move.w	vVideoMode(a5),d1
		lsl.l	d1,d0
		move.l	d0,vBytesPerRow(a5)

; FgPen und BgPen setzen
		move.l	_GfxBase,a6
		tst.b	HasGfx39
		beq	1$

		move.l	vWindow(a5),a2		;V39
		move.l	wd_WScreen(a2),a2
		move.l	sc_ViewPort+vp_ColorMap(a2),a2
		move.l	a2,a0
		moveq	#0,d1			;schwarz
		moveq	#0,d2
		moveq	#0,d3
		sub.l	a1,a1
		JSRLIB	ObtainBestPenA
		move.l	d0,BlackPen
		cmp.l	#-1,d0
		beq	1$
		move.l	vWindow(a5),a1
		move.l	wd_RPort(a1),a1
		JSRLIB	SetAPen
		move.l	a2,a0
		moveq	#-1,d1			;weiß
		moveq	#-1,d2
		moveq	#-1,d3
		sub.l	a1,a1
		JSRLIB	ObtainBestPenA
		move.l	d0,WhitePen
		cmp.l	#-1,d0
		beq	1$
		move.l	vWindow(a5),a1
		move.l	wd_RPort(a1),a1
		JSRLIB	SetBPen
		bra	2$

1$		move.l	vWindow(a5),a1		;V37
		move.l	wd_RPort(a1),a1
		moveq	#1,d0
		JSRLIB	SetAPen
		move.l	vWindow(a5),a1
		move.l	wd_RPort(a1),a1
		moveq	#2,d0
		JSRLIB	SetBPen

2$		move.l	vWindow(a5),a1
		move.l	wd_RPort(a1),a1
		moveq	#RP_JAM2,d0
		JSRLIB	SetDrMd

; Window-MessagePort setzen und Messages anschalten
		move.l	vWindow(a5),a0
		move.b	wd_BorderLeft(a0),BoxBorderLeft+1
		move.b	wd_BorderTop(a0),BoxBorderTop+1
		move.l	UserPort,wd_UserPort(a0)

		move.l	_IntuitionBase,a6
		move.l	vWindow(a5),a0
		moveq	#-1,d0
		JSRLIB	ReportMouse
		move.l	vWindow(a5),a0
		move.l	#IDCMP_RAWKEY|IDCMP_MOUSEBUTTONS|IDCMP_MOUSEMOVE,d0
		JSRLIB	ModifyIDCMP

; Refresh-Kram einrichten
		move.l	#WinRefProc,vRefProc(a5)
		st.b	IsRefreshing		;Refresh-Task erzeugen

		moveq	#0,d0			;Alles OK
		rts


*
* Öffnen eines Bildschirms als EGS-Screen
*

; Prozeduren setzen
DoOpenEGS	move.l	#EGSLockProc,vLockProc(a5)
		move.l	#EGSUnlockProc,vUnlockProc(a5)
		move.l	#EGSPtrVisProc,vPtrVisProc(a5)
		move.l	#EGSPtrInvProc,vPtrInvProc(a5)

; egs.library öffnen
		tst.l	_EGSBase
		bne	5$
		move.l	_ExecBase,a6
		lea	EGSName,a1
		moveq	#6,d0
		JSRLIB	OpenLibrary
		move.l	d0,_EGSBase
		beq	DOVNoEGS
5$

; Nur 8,16 oder 24 Bit
		cmp.w	#VMODE_8BIT,vVideoMode(a5)
		blo	DOVNo124VGA

; Screen-Tiefe berechnen
		move.w	#24,EGSDepth	;24-Bit, und nicht 32-Bit
		move.w	vVideoMode(a5),d0
		cmp.w	#VMODE_24BIT,d0
		beq	1$
		moveq	#0,d1
		bset	d0,d1
		move.w	d1,EGSDepth
1$

; Screen-Eigenschaften setzen
		move.l	_GfxBase,a6
		sub.l	a0,a0
		lea	ModeNameBuf,a1
		moveq	#nif_SIZEOF,d0
		move.l	#DTAG_NAME,d1
		move.l	vDisplayID(a5),d2
		JSRLIB	GetDisplayInfoData

; MessagePort setzen und Messages anschalten
		move.l	EGSUserPort,EGSPort
		move.l	#E_eMOUSEBUTTONS|E_eRAWKEY,d0
		tst.w	MouseDirect
		bne	2$
		or.l	#E_eMOUSEMOVE,d0
2$		move.l	d0,EGSEDCMPFlags

; Screen öffnen
		move.l	_EGSBase,a6
		lea	NewEScreen,a0
		jsr	E_OpenScreen(a6)
		move.l	d0,vScreen(a5)
		beq	DOVNoScreen

; Screen locken
		move.l	vScreen(a5),a0
		move.l	esc_Map(a0),a0
		addq.b	#1,ebm_Lock(a0)

; Daten holen
		clr.l	vWindow(a5)
		clr.l	vViewPort(a5)
		move.l	vScreen(a5),a0
		move.l	esc_Map(a0),a0
		move.l	a0,vBitMap(a5)
		move.w	ebm_Width(a0),d0
		move.w	vVideoMode(a5),d1
		lsl.l	d1,d0
		lsr.l	#3,d0
		move.w	d0,vBytesPerRow+2(a5)
		move.l	ebm_Dest(a0),vScrnBase(a5)

; Screen unlocken
		move.l	vScreen(a5),a0
		move.l	esc_Map(a0),a0
		subq.b	#1,ebm_Lock(a0)

; Maus abschalten
		move.l	vScreen(a5),a0
		move.l	esc_Mouse(a0),vEGSStdMouse(a5)
		jsr	E_MouseOff(a6)

; Refresh-Kram einrichten
		tst.w	RefreshAlways
		bne	10$
		cmp.w	#VMODE_8BIT,vVideoMode(a5) ;Bei 8 Bit kein Refresh
		beq	20$

10$		move.w	vVideoMode(a5),d0
		move.l	(EGSRefProcTab,d0.w*4),vRefProc(a5)
		bsr	AllocRefMem
		tst.l	d0
		bne	DOVNoMem
		st.b	IsRefreshing		;Refresh-Task erzeugen

20$		moveq	#0,d0			;Alles OK
		rts

; Fehlerbehandlung
DOVNoScreen	moveq	#1,d0
		rts
DOVNoMem	moveq	#2,d0
		rts
DOVNoEGS	moveq	#3,d0
		rts
DOVNoTrueAmiga	moveq	#4,d0
		rts
DOVNo124VGA	moveq	#6,d0
		rts
DOVNoCyberGfx	moveq	#7,d0
		rts
DOVNoCyberMode	moveq	#8,d0
		rts
DOVNo16BitMode	moveq	#9,d0
		rts
DOVNoCyberMem	moveq	#11,d0
		rts
DOVCantLoadEV	moveq	#12,d0
		rts
DOVIsNoEV	moveq	#13,d0
		rts

*
* Refresh-Speicher einrichten
* a5: VideoInfo (-> vScreenX, vScreenY, vBytesPerRow - Mac-Screen)
*

; Variablen berechnen
AllocRefMem	move.l	vBytesPerRow(a5),d0
		move.l	vScreenY(a5),d1
		mulu.l	d1,d0
		move.l	d0,vScreenBytes(a5)

		move.l	d0,d1
		divu.l	PageSize,d0
		move.w	d0,vScreenPages(a5)
		mulu.l	PageSize,d0
		sub.l	d0,d1
		move.l	d1,vScreenRest(a5)

; Mac-Grafikspeicher holen (DEPTHSWITCH: der feste Puffer, nicht freigeben)
		move.l	_ExecBase,a6
		move.l	FixedBuf,d0
		beq	1$
		move.l	d0,vScrnBase(a5)
		clr.l	vRefreshMem(a5)
		bra	4$
1$		move.l	vScreenBytes(a5),d0
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		JSRSELF	AllocMMU
		move.l	d0,vScrnBase(a5)
		move.l	d0,vRefreshMem(a5)
		beq	ARMNoMem
4$

; MMU-Refresh?
		tst.w	MMURefresh
		beq	ARMDone

; Ja, Seitentabelle holen
		moveq	#0,d0
		move.w	vScreenPages(a5),d0
		lsl.l	#2,d0			;4 Bytes pro Eintrag
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		JSRLIB	AllocVec
		move.l	d0,vRefPageTable(a5)
		beq	ARMNoMem

; Seitentabelle erstellen
		move.l	d0,a2
		move.l	vScrnBase(a5),d6
		move.w	vScreenPages(a5),d7
		subq.w	#1,d7
2$		move.l	d6,d0
		JSRSELF	GetMMUPage
		addq.l	#3,a0
		move.l	a0,(a2)+
		add.l	PageSize,d6
		dbra	d7,2$

ARMDone		moveq	#0,d0
		rts

ARMNoMem	moveq	#-1,d0
		rts


*
* Schließen der Bildschirme
*

; Beide Bildschirme schließen
CloseVideo	bsr	DeleteRefTask
		lea	VideoInfo1,a5
		bsr	DoCloseVideo
		lea	VideoInfo2,a5
		bsr	DoCloseVideo
		bra	FreeFixedBuf

*
* Einen Bildschirm schließen, a5: VideoInfo
*

; Refresh-Speicher freigeben
DoCloseVideo	move.l	_ExecBase,a6
		move.l	vRefreshMem(a5),d0
		beq	2$
		move.l	d0,a1
		move.l	vScreenBytes(a5),d0
		JSRLIB	FreeMem
		clr.l	vRefreshMem(a5)
2$		move.l	vRefPageTable(a5),d0
		beq	3$
		move.l	d0,a1
		JSRLIB	FreeVec
		clr.l	vRefPageTable(a5)
3$		move.l	vComparisonBuf(a5),d0
		beq	1$
		move.l	d0,a1
		move.l	vScreenBytes(a5),d0
		JSRLIB	FreeMem
		clr.l	vComparisonBuf(a5)
1$

; EGS oder Amiga?
		cmp.w	#VTYPE_EGS,vVideoType(a5)
		beq	DoCloseEGS

; Mac-In-A-Box-Pens freigeben (egal ob sie obtained sind)
DoCloseAmiga	cmp.w	#VTYPE_MACINABOX,vVideoType(a5)
		bne	10$
		cmp.w	#VMODE_15BIT,vVideoMode(a5)
		beq	DoClosePIP
		tst.b	HasGfx39
		beq	10$
		move.l	_GfxBase,a6
		move.l	vWindow(a5),d0
		beq	10$
		move.l	d0,a2
		move.l	wd_WScreen(a2),a2
		move.l	sc_ViewPort+vp_ColorMap(a2),a2
		move.l	a2,a0
		move.l	BlackPen,d0
		JSRLIB	ReleasePen
		move.l	a2,a0
		move.l	WhitePen,d0
		JSRLIB	ReleasePen
10$

; Amiga/CyberGfx: Fenster schließen (CloseWindowSafely)
		move.l	vWindow(a5),d0
		beq	DCVWindowClosed

		move.l	_ExecBase,a6
		JSRLIB	Forbid

		move.l	vWindow(a5),a0
		move.l	wd_UserPort(a0),a0
		move.l	MP_MSGLIST+LH_HEAD(a0),a2
2$		tst.l	LN_SUCC(a2)
		beq	3$
		move.l	vWindow(a5),d0
		cmp.l	im_IDCMPWindow(a2),d0
		bne	1$
		move.l	LN_SUCC(a2),-(sp)	;Nachfolger vor ReplyMsg merken
		move.l	a2,a1
		JSRLIB	Remove
		move.l	a2,a1
		JSRLIB	ReplyMsg
		move.l	(sp)+,a2
		bra	2$
1$		move.l	LN_SUCC(a2),a2
		bra	2$

3$		move.l	_IntuitionBase,a6
		move.l	vWindow(a5),a0
		clr.l	wd_UserPort(a0)
		moveq	#0,d0
		JSRLIB	ModifyIDCMP

		move.l	_ExecBase,a6
		JSRLIB	Permit

		move.l	_IntuitionBase,a6
		move.l	vWindow(a5),a0
		JSRLIB	CloseWindow
		clr.l	vWindow(a5)

; Amiga/CyberGfx: Screen schließen
DCVWindowClosed	cmp.w	#VTYPE_EXTERNAL,vVideoType(a5)
		beq	1$

		bsr	PrismUnpinScreen	;PrismRTG: Lock freigeben

		move.l	vScreen(a5),d0
		beq	DCVScreenClosed

		move.l	_IntuitionBase,a6	;Für Amiga/CyberGfx
		move.l	d0,a0
		JSRLIB	CloseScreen
		clr.l	vScreen(a5)
		bra	DCVScreenClosed

1$		tst.l	vSegment(a5)		;Für Externe
		beq	DCVScreenClosed
		tst.l	vContext(a5)
		beq	DCVScreenClosed

		lea	ExtCSOutTags,a0
		lea	ExtCSInTags,a1
		move.l	vContext(a5),a2
		move.l	_UtilityBase,a6
		move.l	vExtCloseScreen(a5),a3
		jsr	(a3)

		move.l	_DOSBase,a6
		move.l	vSegment(a5),d1
		JSRLIB	UnLoadSeg
		bra	DCVScreenClosed

; PIP schließen
DoClosePIP	move.l	vWindow(a5),d0
		beq	4$

		move.l	_ExecBase,a6
		JSRLIB	Forbid

		move.l	vWindow(a5),a0
		move.l	wd_UserPort(a0),a0
		move.l	MP_MSGLIST+LH_HEAD(a0),a2
2$		tst.l	LN_SUCC(a2)
		beq	3$
		move.l	vWindow(a5),d0
		cmp.l	im_IDCMPWindow(a2),d0
		bne	1$
		move.l	LN_SUCC(a2),-(sp)	;Nachfolger vor ReplyMsg merken
		move.l	a2,a1
		JSRLIB	Remove
		move.l	a2,a1
		JSRLIB	ReplyMsg
		move.l	(sp)+,a2
		bra	2$
1$		move.l	LN_SUCC(a2),a2
		bra	2$

3$		move.l	_IntuitionBase,a6
		move.l	vWindow(a5),a0
		clr.l	wd_UserPort(a0)
		moveq	#0,d0
		JSRLIB	ModifyIDCMP

		move.l	_ExecBase,a6
		JSRLIB	Permit

		move.l	_P96Base,a6
		move.l	vWindow(a5),a0
		jsr	p96PIP_Close(a6)
4$		rts

; EGS-Bildschirm schließen
DoCloseEGS	move.l	vScreen(a5),d0
		beq	DCVScreenClosed
		move.l	d0,a0
		clr.l	esc_Port(a0)
		move.l	_EGSBase,a6
		jsr	E_CloseScreen(a6)

; Mac-In-A-Box: Bitmap freigeben
DCVScreenClosed	cmp.w	#VTYPE_MACINABOX,vVideoType(a5)
		bne	DCVNotBox

		move.l	vBitMap(a5),d0
		beq	DCVNotBox
		move.l	_GfxBase,a6
		JSRLIB	WaitBlit

		tst.b	HasGfx39
		beq	1$

		move.l	vBitMap(a5),a0		;V39
		JSRLIB	FreeBitMap
		bra	DCVNotBox

1$		move.l	vBitMap(a5),a1		;V37
		move.l	bm_Planes(a1),a0
		moveq	#0,d0
		move.w	bm_BytesPerRow(a1),d0
		lsl.l	#3,d0
		moveq	#0,d1
		move.w	bm_Rows(a1),d1
		JSRLIB	FreeRaster
DCVNotBox	rts


**
** Subtask für Refresh
**

; Task ermitteln
RefTaskMain	move.l	_ExecBase,a6
		sub.l	a1,a1
		JSRLIB	FindTask
		move.l	d0,RefTask

; Signal zur Kommunikation anfordern
		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,RefQuitSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,RefQuitSet

; Dem Emulator Bescheid sagen
		move.l	MyTask,a1
		move.l	SubtaskSet,d0
		JSRLIB	Signal

; Hauptschleife: Signal zum Beenden gekommen?
RTMainLoop	move.l	_ExecBase,a6
		moveq	#0,d0
		move.l	RefQuitSet,d1
		JSRLIB	SetSignal
		and.l	RefQuitSet,d0
		bne	RTQuit

; Farbtiefe wechseln?
		tst.l	SwitchReq
		beq	2$
		bsr	DoSwitch
		clr.b	WasFront1		;Neuer Screen: Fenster pruefen
2$

; Nein, etwas warten
		move.l	_DOSBase,a6
		moveq	#0,d1
		move.w	RefreshRate,d1
		JSRLIB	Delay

; Läuft der Mac?
		tst.w	MacRunning
		beq	RTMainLoop

; Mac-Screen gerade nach vorn gekommen (Amiga-M)? Dann sein Fenster
; aktivieren, sonst bekommt der Mac keine Eingaben und kein Refresh
		lea	VideoInfo1,a5
		lea	WasFront1,a1
		bsr	CheckFront
		tst.w	NumMonitors
		beq	3$
		lea	VideoInfo2,a5
		lea	WasFront2,a1
		bsr	CheckFront
3$

; Ja, Emulator-Fenster aktiv? (außer bei Mac-In-A-Box)
		cmp.w	#VTYPE_MACINABOX,VideoType1	;Ist OK, da Mac-In-A-Box nicht mit mehreren Monitoren läuft
		beq	1$
		bsr	IsEmulActive
		bne	RTMainLoop
1$

; Ja, Mauszeiger sichtbar?
		tst.b	PointerBlank
		beq	RTMainLoop

; Nein, ersten Bildschirm refreshen (wenn er einen Refresh braucht)
		lea	VideoInfo1,a5
		cmp.l	#DefRefProc,vRefProc(a5)
		beq	RTSecond
		bsr	LockRefUnlock

; Zweiten Bildschirm refreshen
RTSecond	lea	VideoInfo2,a5
		cmp.l	#DefRefProc,vRefProc(a5)
		beq	RTMainLoop
		bsr	LockRefUnlock
		bra	RTMainLoop

*
* RefreshNow: den Mac-Bildschirm sofort refreshen, im Kontext des Mac.
* Fuer MacsBug: der Debugger laeuft mit gesperrten Interrupts, dann laeuft
* auch kein Amiga-Task (und damit nicht der Refresh-Task). Nur fuer Amiga-
* Bitplanes: deren Lock-Routine ruft keine Library auf (CyberGfx/Prism
* koennten auf eine Semaphore warten). Direkt dargestellte Modi (1 Bit,
* 8 Bit auf Grafikkarten) brauchen keinen Refresh.
*
RefreshNow	movem.l	d0-d7/a0-a6,-(sp)
		tst.b	IsRefreshing
		beq	9$
		lea	VideoInfo1,a5
		bsr	RefreshOne
		tst.w	NumMonitors
		beq	9$
		lea	VideoInfo2,a5
		bsr	RefreshOne
9$		movem.l	(sp)+,d0-d7/a0-a6
		rts

RefreshOne	cmp.w	#VTYPE_AMIGA,vVideoType(a5)
		bne	9$
		tst.l	vRefProc(a5)
		beq	9$
		bra	LockRefUnlock
9$		rts

; BitMap von Bildschirm a5 sperren, refreshen, freigeben. Alle Register
; ausser a5 koennen veraendert sein.
LockRefUnlock	move.l	a5,-(sp)
		move.l	_UtilityBase,a6
		lea	ExtLDOutTags,a0
		lea	ExtLDInTags,a1
		move.l	vContext(a5),a2
		move.l	vLockProc(a5),a3
		jsr	(a3)
		move.l	ExtLDScreenBase,Plane1Base
		move.l	(sp),a5
		move.l	_UtilityBase,a6
		lea	ExtRefOutTags,a0
		lea	ExtRefInTags,a1
		move.l	vContext(a5),a2
		move.l	vRefProc(a5),a3
		jsr	(a3)
		move.l	(sp),a5
		move.l	_UtilityBase,a6
		lea	ExtULDOutTags,a0
		lea	ExtULDInTags,a1
		move.l	vContext(a5),a2
		move.l	vUnlockProc(a5),a3
		jsr	(a3)
		move.l	(sp)+,a5
		rts

; cybergraphics.library oeffnen, wenn sie es noch nicht ist (geschlossen wird
; sie beim Beenden). d0: Base, Z gesetzt: nicht vorhanden. Nur d0 aendert sich.
OpenCyberGfx	move.l	_CyberGfxBase,d0
		bne	1$
		movem.l	d1/a0-a1/a6,-(sp)
		move.l	_ExecBase,a6
		lea	CyberGfxName,a1
		moveq	#40,d0
		JSRLIB	OpenLibrary
		move.l	d0,_CyberGfxBase
		movem.l	(sp)+,d1/a0-a1/a6
		tst.l	d0
1$		rts

; Fenster von Screen a5 aktivieren, wenn der Screen eben nach vorn gekommen
; ist und das Fenster nicht aktiv ist. a1: Merker "war vorn"
CheckFront	move.w	vVideoType(a5),d0
		cmp.w	#VTYPE_AMIGA,d0
		beq	1$
		cmp.w	#VTYPE_CYBER,d0
		bne	9$
1$		move.l	vScreen(a5),d0
		beq	9$
		move.l	vWindow(a5),d1
		beq	9$
		move.l	_IntuitionBase,a6
		moveq	#0,d2
		cmp.l	ib_FirstScreen(a6),d0
		bne	2$
		moveq	#1,d2
		tst.b	(a1)
		bne	2$
		cmp.l	ib_ActiveWindow(a6),d1
		beq	2$
		move.l	a1,-(sp)
		move.l	d1,a0
		JSRLIB	ActivateWindow
		move.l	(sp)+,a1
		moveq	#1,d2
2$		move.b	d2,(a1)
9$		rts

; RefTask beenden
RTQuit		move.l	_ExecBase,a6

		move.b	RefQuitSig,d0
		JSRLIB	FreeSignal

		JSRLIB	Forbid
		move.l	MyTask,a1
		move.l	SubtaskSet,d0
		JSRLIB	Signal
		moveq	#0,d0
		rts


**
** Refresh-Procedures
** a5: VideoInfo
**

; Kein Refresh
DefRefProc	moveq	#0,d0
		rts

; Refresh für 2 Bitplanes (4 Farben)
Refresh2Bit	tst.b	IsDeltaRefresh		;Comparison Buffer?
		bne	Ref2Delta
		tst.w	MMURefresh		;MMU-Refresh?
		beq	Ref2All

		JSRSELF	FlushMMU

		move.l	vScrnBase(a5),a3	;a3: Zeiger in Mac-Speicher
		move.l	Plane1Base,a4		;a4: Zeiger auf Bitplane 1
		move.l	Plane2Base,d6		;d6: Zeiger auf Bitplane 2
		move.l	vRefPageTable(a5),a6	;a6: Zeiger in Seitentabelle
		move.w	vScreenPages(a5),d7
		subq.w	#1,d7			;d7: Zähler für MMU-Seiten
1$		move.l	(a6)+,a0
		bclr	#4,(a0)
		beq	2$

		move.l	PageSize4,d0		;Größe
		subq.l	#1,d0
		move.l	a3,a0
		move.l	a4,a1
		move.l	d6,a2
		moveq	#0,d1
		moveq	#0,d2
		bsr	Ref2Loop		;Eine Seite refreshen

2$		add.l	PageSize,a3		;Zeiger erhöhen
		add.l	PageSize2,a4
		add.l	PageSize2,d6
		dbra	d7,1$

		move.l	vScreenRest(a5),d0	;Den Rest refreshen
		beq	3$
		lsr.l	#2,d0
		subq.l	#1,d0
		move.l	a3,a0
		move.l	a4,a1
		move.l	d6,a2
		bra	Ref2Loop

3$		rts

Ref2All		move.l	vScreenBytes(a5),d0
		lsr.l	#2,d0
		subq.l	#1,d0
		move.l	vScrnBase(a5),a0
		move.l	Plane1Base,a1
		move.l	Plane2Base,a2

Ref2Loop	move.l	(a0)+,d3
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1

		move.w	d1,(a1)+
		move.w	d2,(a2)+
		dbra	d0,Ref2Loop
		clr.w	d0
		subq.l	#1,d0
		bcc	Ref2Loop
		rts

Ref2Delta	move.l	vScreenBytes(a5),d0
		lsr.l	#2,d0
		subq.l	#1,d0
		move.l	vScrnBase(a5),a0
		move.l	Plane1Base,a1
		move.l	Plane2Base,a2
		move.l	vComparisonBuf(a5),a5

Ref2DLoop	move.l	(a0)+,d3

		cmp.l	(a5),d3
		bne	Ref2DChg
		addq.l	#4,a5
		addq.l	#2,a1
		addq.l	#2,a2
		dbra	d0,Ref2DLoop
		clr.w	d0
		subq.l	#1,d0
		bcc	Ref2DLoop
		rts

Ref2DChg	move.l	d3,(a5)+
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1
		add.l	d3,d3
		addx.w	d2,d2
		add.l	d3,d3
		addx.w	d1,d1

		move.w	d1,(a1)+
		move.w	d2,(a2)+
		dbra	d0,Ref2DLoop
		clr.w	d0
		subq.l	#1,d0
		bcc	Ref2DLoop
		rts

; Refresh für 4 Bitplanes (16 Farben)
Refresh4Bit	tst.b	IsDeltaRefresh		;Comparison Buffer?
		bne	Ref4Delta
		tst.w	MMURefresh		;MMU-Refresh?
		beq	Ref4All

		JSRSELF	FlushMMU

		move.l	Plane1Base,a1		;a1..a4: Zeiger in Amiga-Speicher
		move.l	Plane2Base,a2
		move.l	Plane3Base,a3
		move.l	Plane4Base,a4
		move.l	vScrnBase(a5),R4BT	;Zeiger in Mac-Speicher

		move.l	vRefPageTable(a5),a6	;a6: Zeiger in Seitentabelle
		move.w	vScreenPages(a5),d7
		subq.w	#1,d7			;d7: Zähler für MMU-Seiten
1$		move.l	(a6)+,a0
		bclr	#4,(a0)
		beq	2$

		move.l	PageSize8,d0		;Größe
		subq.l	#1,d0
		move.l	R4BT,a0
		movem.l	a1-a4,-(sp)
		bsr	Ref4Loop		;Eine Seite refreshen
		movem.l	(sp)+,a1-a4

2$		move.l	PageSize,d0		;Zeiger erhöhen
		add.l	d0,R4BT
		move.l	PageSize4,d0
		add.l	d0,a1
		add.l	d0,a2
		add.l	d0,a3
		add.l	d0,a4
		dbra	d7,1$

		move.l	vScreenRest(a5),d0	;Den Rest refreshen
		beq	3$
		lsr.l	#3,d0
		subq.l	#1,d0
		move.l	R4BT,a0
		bra	Ref4Loop

3$		rts

		CNOP	0,4
R4BT		dc.l	0

Ref4All		move.l	vScreenBytes(a5),d0
		lsr.l	#3,d0
		subq.l	#1,d0
		move.l	vScrnBase(a5),a0
		move.l	Plane1Base,a1
		move.l	Plane2Base,a2
		move.l	Plane3Base,a3
		move.l	Plane4Base,a4

Ref4Loop	move.l	(a0)+,d5
		move.l	(a0)+,d6

		add.l	d5,d5
		addx.w	d4,d4
		add.l	d5,d5
		addx.w	d3,d3
		add.l	d5,d5
		addx.w	d2,d2
		add.l	d5,d5
		addx.w	d1,d1
		add.l	d5,d5
		addx.w	d4,d4
		add.l	d5,d5
		addx.w	d3,d3
		add.l	d5,d5
		addx.w	d2,d2
		add.l	d5,d5
		addx.w	d1,d1
		add.l	d5,d5
		addx.w	d4,d4
		add.l	d5,d5
		addx.w	d3,d3
		add.l	d5,d5
		addx.w	d2,d2
		add.l	d5,d5
		addx.w	d1,d1
		add.l	d5,d5
		addx.w	d4,d4
		add.l	d5,d5
		addx.w	d3,d3
		add.l	d5,d5
		addx.w	d2,d2
		add.l	d5,d5
		addx.w	d1,d1
		add.l	d5,d5
		addx.w	d4,d4
		add.l	d5,d5
		addx.w	d3,d3
		add.l	d5,d5
		addx.w	d2,d2
		add.l	d5,d5
		addx.w	d1,d1
		add.l	d5,d5
		addx.w	d4,d4
		add.l	d5,d5
		addx.w	d3,d3
		add.l	d5,d5
		addx.w	d2,d2
		add.l	d5,d5
		addx.w	d1,d1
		add.l	d5,d5
		addx.w	d4,d4
		add.l	d5,d5
		addx.w	d3,d3
		add.l	d5,d5
		addx.w	d2,d2
		add.l	d5,d5
		addx.w	d1,d1
		add.l	d5,d5
		addx.w	d4,d4
		add.l	d5,d5
		addx.w	d3,d3
		add.l	d5,d5
		addx.w	d2,d2
		add.l	d5,d5
		addx.w	d1,d1

		add.l	d6,d6
		addx.w	d4,d4
		add.l	d6,d6
		addx.w	d3,d3
		add.l	d6,d6
		addx.w	d2,d2
		add.l	d6,d6
		addx.w	d1,d1
		add.l	d6,d6
		addx.w	d4,d4
		add.l	d6,d6
		addx.w	d3,d3
		add.l	d6,d6
		addx.w	d2,d2
		add.l	d6,d6
		addx.w	d1,d1
		add.l	d6,d6
		addx.w	d4,d4
		add.l	d6,d6
		addx.w	d3,d3
		add.l	d6,d6
		addx.w	d2,d2
		add.l	d6,d6
		addx.w	d1,d1
		add.l	d6,d6
		addx.w	d4,d4
		add.l	d6,d6
		addx.w	d3,d3
		add.l	d6,d6
		addx.w	d2,d2
		add.l	d6,d6
		addx.w	d1,d1
		add.l	d6,d6
		addx.w	d4,d4
		add.l	d6,d6
		addx.w	d3,d3
		add.l	d6,d6
		addx.w	d2,d2
		add.l	d6,d6
		addx.w	d1,d1
		add.l	d6,d6
		addx.w	d4,d4
		add.l	d6,d6
		addx.w	d3,d3
		add.l	d6,d6
		addx.w	d2,d2
		add.l	d6,d6
		addx.w	d1,d1
		add.l	d6,d6
		addx.w	d4,d4
		add.l	d6,d6
		addx.w	d3,d3
		add.l	d6,d6
		addx.w	d2,d2
		add.l	d6,d6
		addx.w	d1,d1
		add.l	d6,d6
		addx.w	d4,d4
		add.l	d6,d6
		addx.w	d3,d3
		add.l	d6,d6
		addx.w	d2,d2
		add.l	d6,d6
		addx.w	d1,d1

		move.w	d1,(a1)+
		move.w	d2,(a2)+
		move.w	d3,(a3)+
		move.w	d4,(a4)+
		dbra	d0,Ref4Loop
		clr.w	d0
		subq.l	#1,d0
		bcc	Ref4Loop
		rts

Ref4Delta	move.l	vScreenBytes(a5),d0
		lsr.l	#3,d0
		subq.l	#1,d0
		move.l	vScrnBase(a5),a0
		move.l	Plane1Base,a1
		move.l	Plane2Base,a2
		move.l	Plane3Base,a3
		move.l	Plane4Base,a4
		move.l	vComparisonBuf(a5),a5

Ref4DLoop	move.l	(a0)+,d5
		move.l	(a0)+,d6

		cmp.l	(a5),d5
		bne	Ref4DChg
		cmp.l	4(a5),d6
		bne	Ref4DChg
		addq.l	#8,a5
		addq.l	#2,a1
		addq.l	#2,a2
		addq.l	#2,a3
		addq.l	#2,a4
		dbra	d0,Ref4DLoop
		clr.w	d0
		subq.l	#1,d0
		bcc	Ref4DLoop
		rts

Ref4DChg	move.l	d5,(a5)+
		move.l	d6,(a5)+

		add.l	d5,d5
		addx.w	d4,d4
		add.l	d5,d5
		addx.w	d3,d3
		add.l	d5,d5
		addx.w	d2,d2
		add.l	d5,d5
		addx.w	d1,d1
		add.l	d5,d5
		addx.w	d4,d4
		add.l	d5,d5
		addx.w	d3,d3
		add.l	d5,d5
		addx.w	d2,d2
		add.l	d5,d5
		addx.w	d1,d1
		add.l	d5,d5
		addx.w	d4,d4
		add.l	d5,d5
		addx.w	d3,d3
		add.l	d5,d5
		addx.w	d2,d2
		add.l	d5,d5
		addx.w	d1,d1
		add.l	d5,d5
		addx.w	d4,d4
		add.l	d5,d5
		addx.w	d3,d3
		add.l	d5,d5
		addx.w	d2,d2
		add.l	d5,d5
		addx.w	d1,d1
		add.l	d5,d5
		addx.w	d4,d4
		add.l	d5,d5
		addx.w	d3,d3
		add.l	d5,d5
		addx.w	d2,d2
		add.l	d5,d5
		addx.w	d1,d1
		add.l	d5,d5
		addx.w	d4,d4
		add.l	d5,d5
		addx.w	d3,d3
		add.l	d5,d5
		addx.w	d2,d2
		add.l	d5,d5
		addx.w	d1,d1
		add.l	d5,d5
		addx.w	d4,d4
		add.l	d5,d5
		addx.w	d3,d3
		add.l	d5,d5
		addx.w	d2,d2
		add.l	d5,d5
		addx.w	d1,d1
		add.l	d5,d5
		addx.w	d4,d4
		add.l	d5,d5
		addx.w	d3,d3
		add.l	d5,d5
		addx.w	d2,d2
		add.l	d5,d5
		addx.w	d1,d1

		add.l	d6,d6
		addx.w	d4,d4
		add.l	d6,d6
		addx.w	d3,d3
		add.l	d6,d6
		addx.w	d2,d2
		add.l	d6,d6
		addx.w	d1,d1
		add.l	d6,d6
		addx.w	d4,d4
		add.l	d6,d6
		addx.w	d3,d3
		add.l	d6,d6
		addx.w	d2,d2
		add.l	d6,d6
		addx.w	d1,d1
		add.l	d6,d6
		addx.w	d4,d4
		add.l	d6,d6
		addx.w	d3,d3
		add.l	d6,d6
		addx.w	d2,d2
		add.l	d6,d6
		addx.w	d1,d1
		add.l	d6,d6
		addx.w	d4,d4
		add.l	d6,d6
		addx.w	d3,d3
		add.l	d6,d6
		addx.w	d2,d2
		add.l	d6,d6
		addx.w	d1,d1
		add.l	d6,d6
		addx.w	d4,d4
		add.l	d6,d6
		addx.w	d3,d3
		add.l	d6,d6
		addx.w	d2,d2
		add.l	d6,d6
		addx.w	d1,d1
		add.l	d6,d6
		addx.w	d4,d4
		add.l	d6,d6
		addx.w	d3,d3
		add.l	d6,d6
		addx.w	d2,d2
		add.l	d6,d6
		addx.w	d1,d1
		add.l	d6,d6
		addx.w	d4,d4
		add.l	d6,d6
		addx.w	d3,d3
		add.l	d6,d6
		addx.w	d2,d2
		add.l	d6,d6
		addx.w	d1,d1
		add.l	d6,d6
		addx.w	d4,d4
		add.l	d6,d6
		addx.w	d3,d3
		add.l	d6,d6
		addx.w	d2,d2
		add.l	d6,d6
		addx.w	d1,d1

		move.w	d1,(a1)+
		move.w	d2,(a2)+
		move.w	d3,(a3)+
		move.w	d4,(a4)+
		dbra	d0,Ref4DLoop
		clr.w	d0
		subq.l	#1,d0
		bcc	Ref4DLoop
		rts

; Refresh für 8 Bitplanes (256 Farben)
Refresh8Bit	tst.b	IsDeltaRefresh		;Comparison Buffer?
		bne	Ref8Delta
		tst.w	MMURefresh		;MMU-Refresh?
		beq	Ref8All

		JSRSELF	FlushMMU

		move.l	vRefPageTable(a5),a6	;a6: Zeiger in Seitentabelle
		moveq	#0,d6			;d6: Index in Mac-Speicher
		move.w	vScreenPages(a5),d7
		subq.w	#1,d7			;d7: Zähler für MMU-Seiten
1$		move.l	(a6)+,a0
		bclr	#4,(a0)
		beq	2$

		movem.l	d6-d7,-(sp)
		move.l	d6,d0			;Erste Zeile der Seite und was davor
		divul.l	vBytesPerRow(a5),d1:d0	; in dieser Zeile liegt
		move.l	d0,d2			;d2: erste Zeile
		add.l	PageSize,d1		;Alle Zeilen, in die die Seite reicht
		add.l	vBytesPerRow(a5),d1	; (auch die angebrochene letzte)
		subq.l	#1,d1
		divu.l	vBytesPerRow(a5),d1
		move.l	vScreenY(a5),d3		;Nicht ueber das Bildende hinaus
		sub.l	d2,d3
		cmp.l	d3,d1
		bls	4$
		move.l	d3,d1
4$		move.l	d1,a4
		mulu.l	vBytesPerRow(a5),d2
		move.l	vScrnBase(a5),a0
		add.l	d2,a0
		move.l	Plane1Base,a1
		add.l	d2,a1
		move.l	#$0f0f0f0f,d5
		move.l	#$55555555,d6
		move.l	#$3333cccc,d7
		bsr	Ref8Loop		;Eine Seite refreshen
		movem.l	(sp)+,d6-d7

2$		add.l	PageSize,d6		;Index erhöhen
		dbra	d7,1$

		tst.l	vScreenRest(a5)		;Den Rest refreshen: alle Zeilen ab der,
		beq	3$			; in der die letzte ganze Seite endet
		move.l	d6,d0
		divu.l	vBytesPerRow(a5),d0
		move.l	vScreenY(a5),d1
		sub.l	d0,d1
		bls	3$
		move.l	d1,a4
		mulu.l	vBytesPerRow(a5),d0
		move.l	vScrnBase(a5),a0
		add.l	d0,a0
		move.l	Plane1Base,a1
		add.l	d0,a1
		move.l	#$0f0f0f0f,d5
		move.l	#$55555555,d6
		move.l	#$3333cccc,d7
		bra	Ref8Loop

3$		rts

Ref8All		move.l	vScrnBase(a5),a0
		move.l	Plane1Base,a1

		move.l	#$0f0f0f0f,d5
		move.l	#$55555555,d6
		move.l	#$3333cccc,d7
		move.l	vScreenY(a5),a4

Ref8Loop	move.l	vBytesPerRow(a5),d0	;Ganze Zeile samt Rand: Mac-Puffer und Planes haben dieselbe Zeilenlänge
		lsr.w	#3,d0
		move.w	d0,a3

nextb8		move.l	(a0)+,d0
		move.l	(a0)+,d1

		move.l	d0,d2
		and.l	d5,d2
		eor.l	d2,d0
		move.l	d1,d3
		and.l	d5,d3
		eor.l	d3,d1
		lsl.l	#4,d2
		or.l	d3,d2
		lsr.l	#4,d1
		or.l	d1,d0
		move.l	d2,d3
		and.l	d7,d3
		move.w	d3,d1
		clr.w	d3
		lsl.l	#2,d3
		lsr.w	#2,d1
		or.w	d1,d3
		swap	d2
		and.l	d7,d2
		or.l	d2,d3
		move.l	d0,d1
		and.l	d7,d1
		move.w	d1,d2
		clr.w	d1
		lsl.l	#2,d1
		lsr.w	#2,d2
		or.w	d2,d1
		swap	d0
		and.l	d7,d0
		or.l	d0,d1
		move.l	d1,d2
		lsr.l	#7,d2
		move.l	d1,d0
		and.l	d6,d0
		eor.l	d0,d1
		move.l	d2,d4
		and.l	d6,d4
		eor.l	d4,d2
		or.l	d4,d1
		lsr.l	#1,d1

m8a		move.b	d1,560(a1)	; plane 7
		swap	d1
		move.b	d1,400(a1)	; plane 5
		or.l	d0,d2
		move.b	d2,480(a1)	; plane 6
		swap	d2
		move.b	d2,320(a1)	; plane 4

		move.l	d3,d2
		lsr.l	#7,d2
		move.l	d3,d0
		and.l	d6,d0
		eor.l	d0,d3
		move.l	d2,d4
		and.l	d6,d4
		eor.l	d4,d2
		or.l	d4,d3
		lsr.l	#1,d3

m8b		move.b	d3,240(a1)	; plane 3
		swap	d3
		move.b	d3,80(a1)	; plane 1
		or.l	d0,d2
		move.b	d2,160(a1)	; plane 2
		swap	d2
		move.b	d2,(a1)+	; plane 0

nx8p		subq.w	#1,a3
		cmp.w	#0,a3
		bne	nextb8

madd		add.w	#560,a1
		subq.w	#1,a4
		cmp.w	#0,a4
		bne	Ref8Loop
		rts

Ref8Delta	move.l	vScrnBase(a5),a0
		move.l	Plane1Base,a1
		move.l	vComparisonBuf(a5),a2

		move.l	#$0f0f0f0f,d5
		move.l	#$55555555,d6
		move.l	#$3333cccc,d7
		move.l	vScreenY(a5),a4

Ref8DLoop	move.l	vBytesPerRow(a5),d0	;Ganze Zeile samt Rand: Mac-Puffer und Planes haben dieselbe Zeilenlänge
		lsr.w	#3,d0
		move.w	d0,a3

nextb82		move.l	(a0)+,d0
		move.l	(a0)+,d1

		cmp.l	(a2),d0
		bne	Ref8DChg
		cmp.l	4(a2),d1
		bne	Ref8DChg
		addq.l	#8,a2
		addq.l	#1,a1
		bra	nx8p2

Ref8DChg	move.l	d0,(a2)+
		move.l	d1,(a2)+

		move.l	d0,d2
		and.l	d5,d2
		eor.l	d2,d0
		move.l	d1,d3
		and.l	d5,d3
		eor.l	d3,d1
		lsl.l	#4,d2
		or.l	d3,d2
		lsr.l	#4,d1
		or.l	d1,d0
		move.l	d2,d3
		and.l	d7,d3
		move.w	d3,d1
		clr.w	d3
		lsl.l	#2,d3
		lsr.w	#2,d1
		or.w	d1,d3
		swap	d2
		and.l	d7,d2
		or.l	d2,d3
		move.l	d0,d1
		and.l	d7,d1
		move.w	d1,d2
		clr.w	d1
		lsl.l	#2,d1
		lsr.w	#2,d2
		or.w	d2,d1
		swap	d0
		and.l	d7,d0
		or.l	d0,d1
		move.l	d1,d2
		lsr.l	#7,d2
		move.l	d1,d0
		and.l	d6,d0
		eor.l	d0,d1
		move.l	d2,d4
		and.l	d6,d4
		eor.l	d4,d2
		or.l	d4,d1
		lsr.l	#1,d1

m8a2		move.b	d1,560(a1)	; plane 7
		swap	d1
		move.b	d1,400(a1)	; plane 5
		or.l	d0,d2
		move.b	d2,480(a1)	; plane 6
		swap	d2
		move.b	d2,320(a1)	; plane 4

		move.l	d3,d2
		lsr.l	#7,d2
		move.l	d3,d0
		and.l	d6,d0
		eor.l	d0,d3
		move.l	d2,d4
		and.l	d6,d4
		eor.l	d4,d2
		or.l	d4,d3
		lsr.l	#1,d3

m8b2		move.b	d3,240(a1)	; plane 3
		swap	d3
		move.b	d3,80(a1)	; plane 1
		or.l	d0,d2
		move.b	d2,160(a1)	; plane 2
		swap	d2
		move.b	d2,(a1)+	; plane 0

nx8p2		subq.w	#1,a3
		cmp.w	#0,a3
		bne	nextb82

madd2		add.w	#560,a1
		subq.w	#1,a4
		cmp.w	#0,a4
		bne	Ref8DLoop
		rts

; Refresh für 15-Bit RGB15
;    xRRR RRGG GGGB BBBB
; -> GGGB BBBB xRRR RRGG
RefRGB15PC	tst.w	MMURefresh		;MMU-Refresh?
		beq	RefRGB15PCAll

		JSRSELF	FlushMMU

		move.l	vScrnBase(a5),a3	;a3: Zeiger in Mac-Speicher
		move.l	Plane1Base,a4		;a4: Zeiger in Amiga-Speicher
		move.l	vRefPageTable(a5),a6	;a6: Zeiger in Seitentabelle
		move.w	vScreenPages(a5),d7
		subq.w	#1,d7			;d7: Zähler für MMU-Seiten
1$		move.l	(a6)+,a0
		bclr	#4,(a0)
		beq	2$

		move.l	PageSize8,d0		;Größe
		move.l	a3,a0
		move.l	a4,a1
		moveq	#0,d2
		bsr	RefRGB15PCPage		;Eine Seite refreshen

2$		add.l	PageSize,a3		;Zeiger erhöhen
		add.l	PageSize,a4
		dbra	d7,1$

		move.l	vScreenRest(a5),d0	;Den Rest nach der letzten ganzen Seite refreshen
		beq	3$
		lsr.l	#2,d0
		move.w	d0,d2
		lsr.l	#1,d0
		move.l	a3,a0
		move.l	a4,a1
		bra	RefRGB15PCPage
3$		rts

RefRGB15PCAll	move.l	vScreenBytes(a5),d0
		move.l	vScrnBase(a5),a0
		move.l	Plane1Base,a1
		lsr.l	#2,d0
		move.w	d0,d2
		lsr.l	#1,d0
RefRGB15PCPage	move.w	d0,d1
		swap	d0
		bra	RefRGB15PCNext
		CNOP	0,4		
RefRGB15PCLoop	movep.l	0(a0),d3		;obere Bytes holen
		movep.l	1(a0),d4		;untere Bytes holen
		movep.l	d4,0(a1)		;und umgekehrt zurück...
		movep.l	d3,1(a1)
		addq.w	#8,a0
		addq.w	#8,a1
RefRGB15PCNext	dbra	d1,RefRGB15PCLoop
		dbra	d0,RefRGB15PCLoop
		andi.w	#1,d2
		beq	1$
		movep.w	0(a0),d3		;wie oben für Rest-Longword
		movep.w	1(a0),d4
		movep.w	d4,0(a1)
		movep.w	d3,1(a1)
1$		rts

; Refresh für 15-Bit BGRPC
;    xRRR RRGG GGGB BBBB
; -> GGGR RRRR xBBB BBGG
RefBGR15PC	tst.w	MMURefresh		;MMU-Refresh?
		beq	RefBGR15PCAll

		JSRSELF	FlushMMU

		move.l	vScrnBase(a5),a3	;a3: Zeiger in Mac-Speicher
		move.l	Plane1Base,a4		;a4: Zeiger in Amiga-Speicher
		move.l	vRefPageTable(a5),a6	;a6: Zeiger in Seitentabelle
		move.w	vScreenPages(a5),d7
		subq.w	#1,d7			;d7: Zähler für MMU-Seiten
1$		move.l	(a6)+,a0
		bclr	#4,(a0)
		beq	2$

		move.l	PageSize4,d0		;Größe
		subq.l	#1,d0
		move.l	a3,a0
		move.l	a4,a1
		move.l	(a0),d4
		not.l	d4
		bsr	RefBGR15PCLoop		;Eine Seite refreshen

2$		add.l	PageSize,a3		;Zeiger erhöhen
		add.l	PageSize,a4
		dbra	d7,1$

		move.l	vScreenRest(a5),d0	;Den Rest nach der letzten ganzen Seite refreshen
		beq	3$
		lsr.l	#2,d0
		subq.l	#1,d0
		move.l	a3,a0
		move.l	a4,a1
		move.l	(a0),d4
		not.l	d4
		bra	RefBGR15PCLoop
3$		rts

RefBGR15PCAll	move.l	vScreenBytes(a5),d0	;Alles refreshen
		lsr.l	#2,d0
		subq.l	#1,d0
		move.l	vScrnBase(a5),a0
		move.l	Plane1Base,a1
		move.l	(a0),d4			;Das erste Langwort immer konvertieren
		not.l	d4

RefBGR15PCLoop	move.l	(a0)+,d1
		cmp.l	d4,d1			;Das gleiche wie vorhin?
		beq	RefBGR15PCSame

		move.l	d1,d2
		move.l	d1,d3
		move.l	d1,d4			;d4: Gemerkte Originaldaten
		lsr.l	#2,d2
		lsl.l	#2,d3
		and.l	#$1f001f00,d2		;d2: Rotanteil richtig geschoben
		and.l	#$007c007c,d3		;d3: Blauanteil richtig geschoben
		ror.w	#8,d1
		swap	d1
		ror.w	#8,d1
		swap	d1
		and.l	#$e003e003,d1		;d1: Grünanteil richtig geschoben
		or.l	d2,d1			;Alles zusammennehmen
		or.l	d3,d1
		move.l	d1,d5			;d5: Gemerkte konvertierte Daten
RefBGR15PCSame	move.l	d5,(a1)+

		dbra	d0,RefBGR15PCLoop
		clr.w	d0
		subq.l	#1,d0
		bcc	RefBGR15PCLoop
		rts

; Refresh für 15-Bit RGB16PC
;    xRRR RRGG GGGB BBBB
; -> GGxB BBBB RRRR RGGG
RefRGB16PC	tst.w	MMURefresh		;MMU-Refresh?
		beq	RefRGB16PCAll

		JSRSELF	FlushMMU

		move.l	vScrnBase(a5),a3	;a3: Zeiger in Mac-Speicher
		move.l	Plane1Base,a4		;a4: Zeiger in Amiga-Speicher
		move.l	vRefPageTable(a5),a6	;a6: Zeiger in Seitentabelle
		move.w	vScreenPages(a5),d7
		subq.w	#1,d7			;d7: Zähler für MMU-Seiten
1$		move.l	(a6)+,a0
		bclr	#4,(a0)
		beq	2$

		move.l	PageSize4,d0		;Größe
		subq.l	#1,d0
		move.l	a3,a0
		move.l	a4,a1
		move.l	(a0),d4
		not.l	d4
		bsr	RefRGB16PCLoop		;Eine Seite refreshen

2$		add.l	PageSize,a3		;Zeiger erhöhen
		add.l	PageSize,a4
		dbra	d7,1$

		move.l	vScreenRest(a5),d0	;Den Rest nach der letzten ganzen Seite refreshen
		beq	3$
		lsr.l	#2,d0
		subq.l	#1,d0
		move.l	a3,a0
		move.l	a4,a1
		move.l	(a0),d4
		not.l	d4
		bra	RefRGB16PCLoop
3$		rts

RefRGB16PCAll	move.l	vScreenBytes(a5),d0	;Alles refreshen
		lsr.l	#2,d0
		subq.l	#1,d0
		move.l	vScrnBase(a5),a0
		move.l	Plane1Base,a1
		move.l	(a0),d4			;Das erste Langwort immer konvertieren
		not.l	d4

RefRGB16PCLoop	move.l	(a0)+,d1
		cmp.l	d4,d1			;Das gleiche wie vorhin?
		beq	RefRGB16PCSame

		move.l	d1,d2
		move.l	d1,d3
		move.l	d1,d4			;d4: Gemerkte Originaldaten
		lsl.l	#8,d2
		add.l	d2,d2
		lsl.l	#8,d3
		and.l	#$c000c000,d2		;d2: 2 LSB des Grünanteils
		and.l	#$1f001f00,d3		;d3: Blauanteil richtig geschoben
		lsr.l	#7,d1
		and.l	#$00ff00ff,d1		;d1: Rot/Grünanteil richtig geschoben
		or.l	d2,d1			;Alles zusammennehmen
		or.l	d3,d1
		move.l	d1,d5			;d5: Gemerkte konvertierte Daten
RefRGB16PCSame	move.l	d5,(a1)+

		dbra	d0,RefRGB16PCLoop
		clr.w	d0
		subq.l	#1,d0
		bcc	RefRGB16PCLoop
		rts

; Refresh fuer 15-Bit RGB16 (RGB565, Motorola-Byteordnung: ZZ9000, Z3660, uaegfx)
;    xRRR RRGG GGGB BBBB
; -> RRRR RGGG GGxB BBBB
RefRGB16	tst.w	MMURefresh		;MMU-Refresh?
		beq	RefRGB16All

		JSRSELF	FlushMMU

		move.l	vScrnBase(a5),a3	;a3: Zeiger in Mac-Speicher
		move.l	Plane1Base,a4		;a4: Zeiger in Amiga-Speicher
		move.l	vRefPageTable(a5),a6	;a6: Zeiger in Seitentabelle
		move.w	vScreenPages(a5),d7
		subq.w	#1,d7			;d7: Zaehler fuer MMU-Seiten
1$		move.l	(a6)+,a0
		bclr	#4,(a0)
		beq	2$

		move.l	PageSize4,d0		;Groesse
		subq.l	#1,d0
		move.l	a3,a0
		move.l	a4,a1
		move.l	(a0),d4
		not.l	d4
		bsr	RefRGB16Loop		;Eine Seite refreshen

2$		add.l	PageSize,a3		;Zeiger erhoehen
		add.l	PageSize,a4
		dbra	d7,1$

		move.l	vScreenRest(a5),d0	;Den Rest nach der letzten ganzen Seite refreshen
		beq	3$
		lsr.l	#2,d0
		subq.l	#1,d0
		move.l	a3,a0
		move.l	a4,a1
		move.l	(a0),d4
		not.l	d4
		bra	RefRGB16Loop
3$		rts

RefRGB16All	move.l	vScreenBytes(a5),d0	;Alles refreshen
		lsr.l	#2,d0
		subq.l	#1,d0
		move.l	vScrnBase(a5),a0
		move.l	Plane1Base,a1
		move.l	(a0),d4			;Das erste Langwort immer konvertieren
		not.l	d4

RefRGB16Loop	move.l	(a0)+,d1
		cmp.l	d4,d1			;Das gleiche wie vorhin?
		beq	RefRGB16Same

		move.l	d1,d4			;d4: Gemerkte Originaldaten
		move.l	d1,d2
		and.l	#$001f001f,d2		;d2: Blauanteil bleibt
		add.l	d1,d1
		and.l	#$ffc0ffc0,d1		;d1: Rot/Gruen eine Stelle hoeher
		or.l	d2,d1
		move.l	d1,d5			;d5: Gemerkte konvertierte Daten
RefRGB16Same	move.l	d5,(a1)+

		dbra	d0,RefRGB16Loop
		clr.w	d0
		subq.l	#1,d0
		bcc	RefRGB16Loop
		rts

; Refresh für 24-Bit RGB
;    xxxx xxxx RRRR RRRR GGGG GGGG BBBB BBBB
; -> RRRR RRRR GGGG GGGG BBBB BBBB
RefRGB24	tst.w	MMURefresh		;MMU-Refresh?
		beq	RefRGB24All

		JSRSELF	FlushMMU

		move.l	vScrnBase(a5),a3	;a3: Zeiger in Mac-Speicher
		move.l	Plane1Base,a4		;a4: Zeiger in Amiga-Speicher
		move.l	vRefPageTable(a5),a6	;a6: Zeiger in Seitentabelle
		move.w	vScreenPages(a5),d7
		subq.w	#1,d7			;d7: Zähler für MMU-Seiten
1$		move.l	(a6)+,a0
		bclr	#4,(a0)
		beq	2$

		move.l	PageSize16,d0		;Größe
		move.l	a3,a0
		move.l	a4,a1
		bsr	RefRGB24Page		;Eine Seite refreshen

2$		add.l	PageSize,a3		;Zeiger erhöhen
		add.l	PageSize3o4,a4
		dbra	d7,1$

		move.l	vScreenRest(a5),d0	;Den Rest nach der letzten ganzen Seite refreshen
		beq	3$
		lsr.l	#4,d0
		move.l	a3,a0
		move.l	a4,a1
		bra	RefRGB24Page
3$		rts

RefRGB24All	move.l	vScreenBytes(a5),d0
		lsr.l	#4,d0			;Immer 16 Bytes auf einmal
		move.l	vScrnBase(a5),a0
		move.l	Plane1Base,a1
RefRGB24Page	move.w	d0,d5
		swap	d0
		bra	RefRGB24Next
		CNOP	0,4
RefRGB24Loop	movem.l	(a0)+,d1-d4		;4 Pixel
		lsl.l	#8,d1			;d1: RGB0
		swap	d2			;d2: GBxR
		move.b	d2,d1			; d1: RGBR
		move.l	d1,(a1)+
		ror.l	#8,d3			;d3: BxRG
		move.w	d3,d2			; d2: GBRG
		move.l	d2,(a1)+
		clr.w	d3			;d3: Bx00
		or.l	d4,d3			;d3: BRGB
		move.l	d3,(a1)+
RefRGB24Next	dbra	d5,RefRGB24Loop
		dbra	d0,RefRGB24Loop
		rts

; Refresh für 24-Bit BGR
;    xxxx xxxx RRRR RRRR GGGG GGGG BBBB BBBB
; -> BBBB BBBB GGGG GGGG RRRR RRRR
RefBGR24	tst.w	MMURefresh		;MMU-Refresh?
		beq	RefBGR24All

		JSRSELF	FlushMMU

		move.l	vScrnBase(a5),a3	;a3: Zeiger in Mac-Speicher
		move.l	Plane1Base,a4		;a4: Zeiger in Amiga-Speicher
		move.l	vRefPageTable(a5),a6	;a6: Zeiger in Seitentabelle
		move.w	vScreenPages(a5),d7
		subq.w	#1,d7			;d7: Zähler für MMU-Seiten
1$		move.l	(a6)+,a0
		bclr	#4,(a0)
		beq	2$

		move.l	PageSize16,d0		;Größe
		move.l	a3,a0
		move.l	a4,a1
		bsr	RefBGR24Page		;Eine Seite refreshen

2$		add.l	PageSize,a3		;Zeiger erhöhen
		add.l	PageSize3o4,a4
		dbra	d7,1$

		move.l	vScreenRest(a5),d0	;Den Rest nach der letzten ganzen Seite refreshen
		beq	3$
		lsr.l	#4,d0
		move.l	a3,a0
		move.l	a4,a1
		bra	RefBGR24Page
3$		rts

RefBGR24All	move.l	vScreenBytes(a5),d0
		lsr.l	#4,d0			;Immer 16 Bytes auf einmal
		move.l	vScrnBase(a5),a0
		move.l	Plane1Base,a1
RefBGR24Page	move.w	d0,d5
		swap	d0
		bra	RefBGR24Next
		CNOP	0,4
RefBGR24Loop	movem.l	(a0)+,d1-d4		;4 Pixel
		rol.w	#8,d1			;d1: xRBG
		swap	d1			;d1: BGxR
		lsl.w	#8,d1			;d1: BGR0
		move.b	d2,d1			; d1: BGRB
		move.l	d1,(a1)+
		lsr.l	#8,d2			;d2: 0xRG
		rol.w	#8,d2			;d2: 0xGR
		swap	d2			;d2: GR0x
		move.w	d3,d2			;d2: GRGB
		rol.w	#8,d2			; d2: GRBG
		move.l	d2,(a1)+
		lsr.l	#8,d3			;d3: 0xRG
		move.b	d4,d3			;d3: 0xRB
		swap	d3			;d3: RB0x
		move.w	d4,d3			;d3: RBGB
		swap	d4			;d4: GBxR
		move.b	d4,d3			; d3: RBGR
		move.l	d3,(a1)+
RefBGR24Next	dbra	d5,RefBGR24Loop
		dbra	d0,RefBGR24Loop
		rts

; Refresh für 32-Bit BGRA
;    xxxx xxxx RRRR RRRR GGGG GGGG BBBB BBBB
; -> BBBB BBBB GGGG GGGG RRRR RRRR xxxx xxxx
RefBGRA32	tst.w	MMURefresh		;MMU-Refresh?
		beq	RefBGRA32All

		JSRSELF	FlushMMU

		move.l	vScrnBase(a5),a3	;a3: Zeiger in Mac-Speicher
		move.l	Plane1Base,a4		;a4: Zeiger in Amiga-Speicher
		move.l	vRefPageTable(a5),a6	;a6: Zeiger in Seitentabelle
		move.w	vScreenPages(a5),d7
		subq.w	#1,d7			;d7: Zähler für MMU-Seiten
1$		move.l	(a6)+,a0
		bclr	#4,(a0)
		beq	2$

		move.l	PageSize16,d0		;Größe
		move.l	a3,a0
		move.l	a4,a1
		bsr	RefBGRA32Page		;Eine Seite refreshen

2$		add.l	PageSize,a3		;Zeiger erhöhen
		add.l	PageSize,a4
		dbra	d7,1$

		move.l	vScreenRest(a5),d0	;Den Rest nach der letzten ganzen Seite refreshen
		beq	3$
		lsr.l	#4,d0
		move.l	a3,a0
		move.l	a4,a1
		bra	RefBGRA32Page
3$		rts

RefBGRA32All	move.l	vScreenBytes(a5),d0
		lsr.l	#4,d0			;Immer 16 Bytes auf einmal
		move.l	vScrnBase(a5),a0
		move.l	Plane1Base,a1
RefBGRA32Page	move.w	d0,d5
		swap	d0
		bra	RefBGRA32Next
		CNOP	0,4
RefBGRA32Loop	movem.l	(a0)+,d1-d4		;4 Pixel
		rol.w	#8,d1			;d1: xRBG
		swap	d1			;d1: BGxR
		rol.w	#8,d1			; d1: BGRx
		move.l	d1,(a1)+
		rol.w	#8,d2
		swap	d2
		rol.w	#8,d2
		move.l	d2,(a1)+
		rol.w	#8,d3
		swap	d3
		rol.w	#8,d3
		move.l	d3,(a1)+
		rol.w	#8,d4
		swap	d4
		rol.w	#8,d4
		move.l	d4,(a1)+
RefBGRA32Next	dbra	d5,RefBGRA32Loop
		dbra	d0,RefBGRA32Loop
		rts

; Refresh für 32-Bit RGBA
;    xxxx xxxx RRRR RRRR GGGG GGGG BBBB BBBB
; -> RRRR RRRR GGGG GGGG BBBB BBBB xxxx xxxx
RefRGBA32	tst.w	MMURefresh		;MMU-Refresh?
		beq	RefRGBA32All

		JSRSELF	FlushMMU

		move.l	vScrnBase(a5),a3	;a3: Zeiger in Mac-Speicher
		move.l	Plane1Base,a4		;a4: Zeiger in Amiga-Speicher
		move.l	vRefPageTable(a5),a6	;a6: Zeiger in Seitentabelle
		move.w	vScreenPages(a5),d7
		subq.w	#1,d7			;d7: Zähler für MMU-Seiten
1$		move.l	(a6)+,a0
		bclr	#4,(a0)
		beq	2$

		move.l	PageSize16,d0		;Größe
		move.l	a3,a0
		move.l	a4,a1
		bsr	RefRGBA32Page		;Eine Seite refreshen

2$		add.l	PageSize,a3		;Zeiger erhöhen
		add.l	PageSize,a4
		dbra	d7,1$

		move.l	vScreenRest(a5),d0	;Den Rest nach der letzten ganzen Seite refreshen
		beq	3$
		lsr.l	#4,d0
		move.l	a3,a0
		move.l	a4,a1
		bra	RefRGBA32Page
3$		rts

RefRGBA32All	move.l	vScreenBytes(a5),d0
		lsr.l	#4,d0			;Immer 16 Bytes auf einmal
		move.l	vScrnBase(a5),a0
		move.l	Plane1Base,a1
RefRGBA32Page	move.w	d0,d5
		swap	d0
		bra	RefRGBA32Next
		CNOP	0,4
RefRGBA32Loop	movem.l	(a0)+,d1-d4		;4 Pixel
		rol.l	#8,d1			; d1: RBGx
		move.l	d1,(a1)+
		rol.l	#8,d2
		move.l	d2,(a1)+
		rol.l	#8,d3
		move.l	d3,(a1)+
		rol.l	#8,d4
		move.l	d4,(a1)+
RefRGBA32Next	dbra	d5,RefRGBA32Loop
		dbra	d0,RefRGBA32Loop
		rts

; Refresh für 8-Bit-Chunky (nur Kopieren)
RefPlainCopy	tst.w	MMURefresh		;MMU-Refresh?
		beq	RefPlainAll

		JSRSELF	FlushMMU

		move.l	vScrnBase(a5),a3	;a3: Zeiger in Mac-Speicher
		move.l	Plane1Base,a4		;a4: Zeiger in Amiga-Speicher
		move.l	vRefPageTable(a5),a6	;a6: Zeiger in Seitentabelle
		move.w	vScreenPages(a5),d7
		subq.w	#1,d7			;d7: Zähler für MMU-Seiten
1$		move.l	(a6)+,a0
		bclr	#4,(a0)
		beq	2$

		move.l	PageSize4,d0		;Größe
		subq.l	#1,d0
		move.l	a3,a0
		move.l	a4,a1
		bsr	RefPlainLoop		;Eine Seite refreshen

2$		add.l	PageSize,a3		;Zeiger erhöhen
		add.l	PageSize,a4
		dbra	d7,1$

		move.l	vScreenRest(a5),d0	;Den Rest nach der letzten ganzen Seite refreshen
		beq	3$
		lsr.l	#2,d0
		subq.l	#1,d0
		move.l	a3,a0
		move.l	a4,a1
		bra	RefPlainLoop
3$		rts

RefPlainAll	move.l	vScreenBytes(a5),d0
		lsr.l	#2,d0
		subq.l	#1,d0
		move.l	vScrnBase(a5),a0
		move.l	Plane1Base,a1

RefPlainLoop	move.l	(a0)+,(a1)+
		dbra	d0,RefPlainLoop
		clr.w	d0
		subq.l	#1,d0
		bcc	RefPlainLoop
		rts


; Refresh für Mac-In-A-Box-Modus
WinRefProc	cmp.w	#VMODE_1BIT,vVideoMode(a5)
		bne	1$

		move.l	_GfxBase,a6		;1 Bit
		move.l	vScrnBase(a5),a0
		moveq	#0,d0
		move.l	vBytesPerRow(a5),d1
		move.l	vWindow(a5),a1
		move.l	wd_RPort(a1),a1
		moveq	#0,d2
		moveq	#0,d3
		move.w	BoxBorderLeft,d2
		move.w	BoxBorderTop,d3
		move.l	vScreenX(a5),d4
		move.l	vScreenY(a5),d5
		JMPLIB	BltTemplate

1$		move.l	_CyberGfxBase,a6	;24 Bit
		move.l	vScrnBase(a5),a0
		moveq	#0,d0
		moveq	#0,d1
		move.l	vBytesPerRow(a5),d2
		move.l	vWindow(a5),a1
		move.l	wd_RPort(a1),a1
		move.w	BoxBorderLeft,d3
		move.w	BoxBorderTop,d4
		move.l	vScreenX(a5),d5
		move.l	vScreenY(a5),d6
		moveq	#RECTFMT_ARGB,d7
		jmp	WritePixelArray(a6)


**
** Default Lock-Procedures (-> Plane1Base)
** a5: VideoInfo
**

; Kein Lock
DefLockProc	move.l	Plane1Base,ExtLDScreenBase
		moveq	#0,d0
		rts

; Amiga Bitplanes
BplLockProc	move.l	vBitMap(a5),a0
		move.l	bm_Planes(a0),Plane1Base
		move.l	bm_Planes+4(a0),Plane2Base
		move.l	bm_Planes+8(a0),Plane3Base
		move.l	bm_Planes+12(a0),Plane4Base
		move.l	bm_Planes+16(a0),Plane5Base
		move.l	bm_Planes+20(a0),Plane6Base
		move.l	bm_Planes+24(a0),Plane7Base
		move.l	bm_Planes+28(a0),Plane8Base
		move.l	Plane1Base,ExtLDScreenBase
		moveq	#0,d0
		rts

*
* PrismRTG: Prism lagert Bitmaps, die nicht angezeigt werden, aus dem
* Grafikkarten-Speicher aus, wenn dieser knapp wird, ausser sie sind mit
* LockBitMap gesperrt. Der Mac schreibt aber die ganze Zeit direkt in die
* Adresse von CYBRMATTR_DISPADR, auch wenn sein Screen hinten liegt. Darum
* wird die Bitmap unter Prism fuer die ganze Laufzeit gesperrt (ein Prism-Lock
* ist nur ein Zaehler und blockiert sonst nichts). Unter CyberGraphX und
* Picasso96 bleibt alles wie bisher, dort sind lange Locks nicht erlaubt.
* a5: VideoInfo, a6: CyberGfxBase (bleibt erhalten)
*
PrismPinScreen	movem.l	d0-d1/a0-a2,-(sp)
		tst.l	vCyberLock(a5)
		bne	9$
		bsr	IsPrism
		beq	9$
		move.l	vBitMap(a5),a0
		lea	CyberLockTags,a1
		jsr	LockBitMapTagList(a6)
		move.l	d0,vCyberLock(a5)
		beq	9$
		move.l	CyberLockBase,d0	;Adresse aus dem Lock ist massgeblich
		beq	9$
		move.l	d0,vScrnBase(a5)
9$		movem.l	(sp)+,d0-d1/a0-a2
		rts

*
* IsPrism: ist die cybergraphics.library in a6 die von PrismRTG ("Prism"
* in der IdString)? Rueckgabe d0: -1 ja, 0 nein (mit Z-Flag)
*
IsPrism		movem.l	d1/a0-a2,-(sp)
		move.l	LIB_IDSTRING(a6),d0
		beq	8$
		move.l	d0,a0
1$		move.b	(a0)+,d0
		beq	8$
		cmp.b	#'P',d0
		bne	1$
		lea	PrismName+1,a1
		move.l	a0,a2
2$		move.b	(a1)+,d1
		beq	3$			;"Prism" gefunden
		cmp.b	(a2)+,d1
		beq	2$
		bra	1$
3$		moveq	#-1,d0
		bra	9$
8$		moveq	#0,d0
9$		movem.l	(sp)+,d1/a0-a2
		rts

PrismUnpinScreen
		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	vCyberLock(a5),d0
		beq	1$
		move.l	_CyberGfxBase,a6
		move.l	d0,a0
		jsr	UnLockBitMap(a6)
		clr.l	vCyberLock(a5)
1$		movem.l	(sp)+,d0-d1/a0-a1/a6
		rts

; CyberGfx
CybLockProc	move.l	_CyberGfxBase,a6
		move.l	vBitMap(a5),a0
		move.l	#CYBRMATTR_DISPADR,d0
		jsr	GetCyberMapAttr(a6)
		move.l	d0,ExtLDScreenBase
		rts

; EGS
EGSLockProc	move.l	vBitMap(a5),a0
		addq.b	#1,ebm_Lock(a0)
		move.l	ebm_Dest(a0),ExtLDScreenBase
		rts


**
** Unlock-Procedures
**

; Kein Unlock
DefUnlockProc	moveq	#0,d0
		rts

; EGS-Unlock
EGSUnlockProc	move.l	vBitMap(a5),a0
		subq.b	#1,ebm_Lock(a0)
		rts


*
* Stellt fest, ob eines der Emlator-Fenster aktiv ist
* Rückgabe: beq = Emulator aktiv
*

IsEmulActive	cmp.w	#VTYPE_EGS,VideoInfo1+vVideoType ;!!
		beq	2$

		move.l	_IntuitionBase,a0
		move.l	ib_ActiveWindow(a0),a0
		cmp.l	VideoInfo1+vWindow,a0
		beq	1$
		cmp.l	VideoInfo2+vWindow,a0
1$		rts

2$		moveq	#0,d0
		rts


*
* Amiga-/EGS-Mauszeiger (un)sichtbar machen
*

TogglePointer	movem.l	d2-d7/a2-a6,-(sp)
		tst.b	PointerBlank
		bne	ToggleVisible

; Unsichtbar machen
ToggleInvisible	st.b	PointerBlank

		lea	VideoInfo1,a5
		move.l	_UtilityBase,a6
		lea	ExtPtrOutTags,a0
		lea	ExtPtrInTags,a1
		move.l	vContext(a5),a2
		move.l	vPtrInvProc(a5),a3
		jsr	(a3)

		lea	VideoInfo2,a5
		move.l	_UtilityBase,a6
		lea	ExtPtrOutTags,a0
		lea	ExtPtrInTags,a1
		move.l	vContext(a5),a2
		move.l	vPtrInvProc(a5),a3
		jsr	(a3)
		bra	ToggleDone

; Sichtbar machen
ToggleVisible	clr.b	PointerBlank

		lea	VideoInfo1,a5
		move.l	_UtilityBase,a6
		lea	ExtPtrOutTags,a0
		lea	ExtPtrInTags,a1
		move.l	vContext(a5),a2
		move.l	vPtrVisProc(a5),a3
		jsr	(a3)

		lea	VideoInfo2,a5
		move.l	_UtilityBase,a6
		lea	ExtPtrOutTags,a0
		lea	ExtPtrInTags,a1
		move.l	vContext(a5),a2
		move.l	vPtrVisProc(a5),a3
		jsr	(a3)

ToggleDone	movem.l	(sp)+,d2-d7/a2-a6
		rts

*
* Unsichtbar machen
*

DefPtrInvProc	tst.w	UseAmigaMouse
		bne	1$
		move.l	_IntuitionBase,a6
		move.l	vWindow(a5),a0
		lea	NullPointer,a1
		moveq	#2,d0
		moveq	#16,d1
		moveq	#0,d2
		moveq	#0,d3
		JMPLIB	SetPointer
1$		rts

EGSPtrInvProc	tst.w	UseAmigaMouse
		bne	1$
		move.l	_EGSBase,a6
		move.l	vScreen(a5),a0
		lea	ClearEGSMouse,a1
		jmp	E_ModifyMouse(a6)
1$		rts

WinPtrInvProc	move.l	_IntuitionBase,a6
		move.l	vWindow(a5),a0
		lea	BoxWindowName,a1
		move.l	#-1,a2
		JMPLIB	SetWindowTitles

*
* Sichtbar machen
*

DefPtrVisProc	tst.w	UseAmigaMouse
		bne	1$
		move.l	_IntuitionBase,a6	;Amiga/CyberGfx
		move.l	vWindow(a5),a0
		JMPLIB	ClearPointer
1$		rts

EGSPtrVisProc	tst.w	UseAmigaMouse
		bne	1$
		move.l	_EGSBase,a6
		move.l	vScreen(a5),a0
		move.l	vEGSStdMouse(a5),a1
		jmp	E_ModifyMouse(a6)
1$		rts

WinPtrVisProc	move.l	_IntuitionBase,a6
		move.l	vWindow(a5),a0
		lea	BoxFrozenName,a1
		move.l	#-1,a2
		JMPLIB	SetWindowTitles


*
* Disk-Eject-Icon in rechte obere Ecke malen
*

DrawDisk1Icon	lea	EjectIcons1,a0
		bra	DrawDiskIcon
DrawDisk2Icon	lea	EjectIcons2,a0
		bra	DrawDiskIcon
DrawDisk3Icon	lea	EjectIcons3,a0
		bra	DrawDiskIcon
DrawDisk4Icon	lea	EjectIcons4,a0
DrawDiskIcon	movem.l	d2-d3,-(sp)
		moveq	#1,d2
		moveq	#1,d3
		move.l	(a0),a1
		cmp.w	#VMODE_1BIT,VideoMode1
		beq	DrawDIDoIt
		moveq	#1,d2
		moveq	#2,d3
		move.l	4(a0),a1
		cmp.w	#VMODE_2BIT,VideoMode1
		beq	DrawDIDoIt
		moveq	#2,d2
		moveq	#4,d3
		move.l	8(a0),a1
		cmp.w	#VMODE_4BIT,VideoMode1
		beq	DrawDIDoIt
		moveq	#4,d2
		moveq	#8,d3
		move.l	12(a0),a1
		cmp.w	#VMODE_8BIT,VideoMode1
		beq	DrawDIDoIt
		moveq	#8,d2
		moveq	#16,d3
		move.l	16(a0),a1
		cmp.w	#VMODE_15BIT,VideoMode1
		beq	DrawDIDoIt
		moveq	#16,d2
		moveq	#32,d3
		move.l	20(a0),a1
		cmp.w	#VMODE_24BIT,VideoMode1
		beq	DrawDIDoIt
		movem.l	(sp)+,d2-d3
		rts

; d2: Anzahl Bytes in einer Zeile des Icons
; d3: Anzahl Bytes Offset vom rechten Bildschirmrand
DrawDIDoIt	move.l	ScrnBase1,a0
		add.l	BytesPerRow1,a0
		add.l	BytesPerRow1,a0
		add.l	BytesPerRow1,a0
		sub.l	d3,a0
		moveq	#5,d0		;6 Zeilen
1$		move.l	d2,d3
		subq.w	#1,d3
2$		move.b	(a1)+,d1
		eor.b	d1,(a0)+
		dbra	d3,2$
		add.l	BytesPerRow1,a0
		sub.l	d2,a0
		dbra	d0,1$
		movem.l	(sp)+,d2-d3
		rts


*
* Disk-Eject-Icon löschen
*

EraseDiskIcon	lea	ClearIcons,a0
		movem.l	d2-d3,-(sp)
		moveq	#1,d2
		moveq	#1,d3
		move.l	(a0),a1
		cmp.w	#VMODE_1BIT,VideoMode1
		beq	EraseDIDoIt
		moveq	#1,d2
		moveq	#2,d3
		move.l	4(a0),a1
		cmp.w	#VMODE_2BIT,VideoMode1
		beq	EraseDIDoIt
		moveq	#2,d2
		moveq	#4,d3
		move.l	8(a0),a1
		cmp.w	#VMODE_4BIT,VideoMode1
		beq	EraseDIDoIt
		moveq	#4,d2
		moveq	#8,d3
		move.l	12(a0),a1
		cmp.w	#VMODE_8BIT,VideoMode1
		beq	EraseDIDoIt
		moveq	#8,d2
		moveq	#16,d3
		move.l	16(a0),a1
		cmp.w	#VMODE_15BIT,VideoMode1
		beq	EraseDIDoIt
		moveq	#16,d2
		moveq	#32,d3
		move.l	20(a0),a1
		cmp.w	#VMODE_24BIT,VideoMode1
		beq	EraseDIDoIt
		movem.l	(sp)+,d2-d3
		rts

; d2: Anzahl Bytes in einer Zeile des Icons
; d3: Anzahl Bytes Offset vom rechten Bildschirmrand
EraseDIDoIt	move.l	ScrnBase1,a0
		add.l	BytesPerRow1,a0
		add.l	BytesPerRow1,a0
		add.l	BytesPerRow1,a0
		sub.l	d3,a0
		moveq	#5,d0		;6 Zeilen
1$		move.l	d2,d3
		subq.w	#1,d3
2$		move.b	(a1)+,(a0)+
		dbra	d3,2$
		add.l	BytesPerRow1,a0
		sub.l	d2,a0
		dbra	d0,1$
		movem.l	(sp)+,d2-d3
		rts


**
** QuickDraw-Beschleunigung
**

		INCLUDE	"MacEmulQDAccel.asm"


**
** Konstanten
**

; Strings
EGSName		dc.b	"egs.library",0
CyberGfxName	dc.b	"cybergraphics.library",0
PrismName	dc.b	"Prism",0
		EVEN
CyberLockTags	dc.l	LBMI_BASEADDRESS,CyberLockBase,TAG_DONE
CyberLockBase	dc.l	0
P96Name		dc.b	"Picasso96API.library",0
RefTaskName	dc.b	"ShapeShifter RefreshTask",0
ScreenName	dc.b	"ShapeShifter Screen",0
BoxWindowName	dc.b	"ShapeShifter Macintosh Display",0
BoxFrozenName	dc.b	"ShapeShifter ***FROZEN***",0
WorkbenchName	dc.b	"Workbench",0
		CNOP	0,4

; Tabellen mit den Prozeduren zum Refresh
AmigaRefProcTab	dc.l	DefRefProc
		dc.l	Refresh2Bit
		dc.l	Refresh4Bit
		dc.l	Refresh8Bit
		dc.l	DefRefProc
		dc.l	DefRefProc

EGSRefProcTab	dc.l	DefRefProc
		dc.l	DefRefProc
		dc.l	DefRefProc
		dc.l	RefPlainCopy
		dc.l	RefBGR15PC
		dc.l	RefRGB24

ExtRefProcTab	dc.l	RefRGB15PC
		dc.l	RefBGR15PC
		dc.l	RefRGB16PC
		dc.l	RefRGB24
		dc.l	RefBGR24
		dc.l	RefRGBA32
		dc.l	RefBGRA32

; Icons für Diskettenentnahme
EjectIcons1	dc.l	EI1_1,EI1_2,EI1_4,EI1_8,EI1_16,EI1_24
EjectIcons2	dc.l	EI2_1,EI2_2,EI2_4,EI2_8,EI2_16,EI2_24
EjectIcons3	dc.l	EI3_1,EI3_2,EI3_4,EI3_8,EI3_16,EI3_24
EjectIcons4	dc.l	EI4_1,EI4_2,EI4_4,EI4_8,EI4_16,EI4_24
ClearIcons	dc.l	CI_1,CI_2,CI_4,CI_8,CI_16,CI_24

EI1_1		dc.b	$40,$c0,$40,$40,$40,$e0
EI1_2		dc.b	$30,$f0,$30,$30,$30,$fc
EI1_4		dc.w	$0f00
		dc.w	$ff00
		dc.w	$0f00
		dc.w	$0f00
		dc.w	$0f00
		dc.w	$fff0
EI1_8		dc.l	$00ff0000
		dc.l	$ffff0000
		dc.l	$00ff0000
		dc.l	$00ff0000
		dc.l	$00ff0000
		dc.l	$ffffff00
EI1_16		dc.l	$00007fff,$00000000
		dc.l	$7fff7fff,$00000000
		dc.l	$00007fff,$00000000
		dc.l	$00007fff,$00000000
		dc.l	$00007fff,$00000000
		dc.l	$7fff7fff,$7fff0000
EI1_24		dc.l	$00000000,$00ffffff,$00000000,$00000000
		dc.l	$00ffffff,$00ffffff,$00000000,$00000000
		dc.l	$00000000,$00ffffff,$00000000,$00000000
		dc.l	$00000000,$00ffffff,$00000000,$00000000
		dc.l	$00000000,$00ffffff,$00000000,$00000000
		dc.l	$00ffffff,$00ffffff,$00ffffff,$00000000

EI2_1		dc.b	$60,$90,$10,$20,$40,$f0
EI2_2		dc.b	$3c,$c3,$03,$0c,$30,$ff
EI2_4		dc.w	$0ff0
		dc.w	$f00f
		dc.w	$000f
		dc.w	$00f0
		dc.w	$0f00
		dc.w	$ffff
EI2_8		dc.l	$00ffff00
		dc.l	$ff0000ff
		dc.l	$000000ff
		dc.l	$0000ff00
		dc.l	$00ff0000
		dc.l	$ffffffff
EI2_16		dc.l	$00007fff,$7fff0000
		dc.l	$7fff0000,$00007fff
		dc.l	$00000000,$00007fff
		dc.l	$00000000,$7fff0000
		dc.l	$00007fff,$00000000
		dc.l	$7fff7fff,$7fff7fff
EI2_24		dc.l	$00000000,$00ffffff,$00ffffff,$00000000
		dc.l	$00ffffff,$00000000,$00000000,$00ffffff
		dc.l	$00000000,$00000000,$00000000,$00ffffff
		dc.l	$00000000,$00000000,$00ffffff,$00000000
		dc.l	$00000000,$00ffffff,$00000000,$00000000
		dc.l	$00ffffff,$00ffffff,$00ffffff,$00ffffff

EI3_1		dc.b	$e0,$10,$60,$10,$10,$e0
EI3_2		dc.b	$fc,$03,$3c,$03,$03,$fc
EI3_4		dc.w	$fff0
		dc.w	$000f
		dc.w	$0ff0
		dc.w	$000f
		dc.w	$000f
		dc.w	$fff0
EI3_8		dc.l	$ffffff00
		dc.l	$000000ff
		dc.l	$00ffff00
		dc.l	$000000ff
		dc.l	$000000ff
		dc.l	$ffffff00
EI3_16		dc.l	$7fff7fff,$7fff0000
		dc.l	$00000000,$00007fff
		dc.l	$00007fff,$7fff0000
		dc.l	$00000000,$00007fff
		dc.l	$00000000,$00007fff
		dc.l	$7fff7fff,$7fff0000
EI3_24		dc.l	$00ffffff,$00ffffff,$00ffffff,$00000000
		dc.l	$00000000,$00000000,$00000000,$00ffffff
		dc.l	$00000000,$00ffffff,$00ffffff,$00000000
		dc.l	$00000000,$00000000,$00000000,$00ffffff
		dc.l	$00000000,$00000000,$00000000,$00ffffff
		dc.l	$00ffffff,$00ffffff,$00ffffff,$00000000

EI4_1		dc.b	$90,$90,$90,$f0,$10,$10
EI4_2		dc.b	$c3,$c3,$c3,$ff,$03,$03
EI4_4		dc.w	$f00f
		dc.w	$f00f
		dc.w	$f00f
		dc.w	$ffff
		dc.w	$000f
		dc.w	$000f
EI4_8		dc.l	$ff0000ff
		dc.l	$ff0000ff
		dc.l	$ff0000ff
		dc.l	$ffffffff
		dc.l	$000000ff
		dc.l	$000000ff
EI4_16		dc.l	$7fff0000,$00007fff
		dc.l	$7fff0000,$00007fff
		dc.l	$7fff0000,$00007fff
		dc.l	$7fff7fff,$7fff7fff
		dc.l	$00000000,$00007fff
		dc.l	$00000000,$00007fff
EI4_24		dc.l	$00ffffff,$00000000,$00000000,$00ffffff
		dc.l	$00ffffff,$00000000,$00000000,$00ffffff
		dc.l	$00ffffff,$00000000,$00000000,$00ffffff
		dc.l	$00ffffff,$00ffffff,$00ffffff,$00ffffff
		dc.l	$00000000,$00000000,$00000000,$00ffffff
		dc.l	$00000000,$00000000,$00000000,$00ffffff

CI_1		dc.b	$03,$01,$01,$00,$00,$00
CI_2		dc.b	0,0,0,0,0,0
CI_4		dc.w	0,0,0,0,0,0
CI_8		dc.l	0,0,0,0,0,0
CI_16		dc.l	$7fff7fff,$7fff7fff
		dc.l	$7fff7fff,$7fff7fff
		dc.l	$7fff7fff,$7fff7fff
		dc.l	$7fff7fff,$7fff7fff
		dc.l	$7fff7fff,$7fff7fff
		dc.l	$7fff7fff,$7fff7fff
CI_24		dc.l	$00ffffff,$00ffffff,$00ffffff,$00ffffff
		dc.l	$00ffffff,$00ffffff,$00ffffff,$00ffffff
		dc.l	$00ffffff,$00ffffff,$00ffffff,$00ffffff
		dc.l	$00ffffff,$00ffffff,$00ffffff,$00ffffff
		dc.l	$00ffffff,$00ffffff,$00ffffff,$00ffffff
		dc.l	$00ffffff,$00ffffff,$00ffffff,$00ffffff

		CNOP	0,4
ProcTags	dc.l	NP_Entry,RefTaskMain
		dc.l	NP_Name,RefTaskName
		dc.l	NP_Priority,1
		dc.l	0,0


**
** Initialisierte Daten
**

		SECTION	"DATA",DATA

; Taglist für den Screen (Amiga)
ScreenTags	dc.l	SA_DisplayID
ScreenDID	dc.l	0
		dc.l	SA_Depth
ScreenDepth	dc.l	0
		dc.l	SA_Width
ScreenWidth	dc.l	0
		dc.l	SA_Height
ScreenHeight	dc.l	0
		dc.l	SA_Left
ScreenLeft	dc.l	0
		dc.l	SA_Top
ScreenTop	dc.l	0
		dc.l	SA_Overscan
ScreenOScan	dc.l	0
		dc.l	SA_Quiet,-1
		dc.l	SA_AutoScroll,-1
		dc.l	SA_Interleaved
ScreenInterl	dc.l	0
		dc.l	SA_Title,ScreenName
		dc.l	0,0

; Taglist für den Screen (Cyber)
CyberScreenTags	dc.l	SA_DisplayID
CyberScreenDID	dc.l	0
		dc.l	SA_Depth
CyberScrDepth	dc.l	0
		dc.l	SA_Width
CyberScrWidth	dc.l	0
		dc.l	SA_Height
CyberScrHeight	dc.l	0
		dc.l	SA_Quiet,-1
		dc.l	SA_Exclusive,-1
		dc.l	SA_Title,ScreenName
		dc.l	0,0

; NewEScreen
NewEScreen	dc.l	ModeNameBuf+16
EGSDepth	dc.w	0,0
		dc.l	0
		dc.l	0
		dc.l	0
		dc.l	0
EGSEDCMPFlags	dc.l	0
EGSPort		dc.l	0

; Taglists für externes OpenScreen
ExtOSOutTags	dc.l	SHEV_Level,OUR_LEVEL
		dc.l	SHEV_ScreenX
ExtScrWidth	dc.l	0
		dc.l	SHEV_ScreenY
ExtScrHeight	dc.l	0
		dc.l	SHEV_DisplayID
ExtScreenDID	dc.l	0
		dc.l	SHEV_OverscanType
ExtOverscan	dc.l	0
		dc.l	SHEV_VideoMode
ExtVideoMode	dc.l	0
		dc.l	0,0

ExtOSInTags	dc.l	SHEV_Context
ExtOSContext	dc.l	0
		dc.l	SHEV_Screen
ExtOSScreen	dc.l	0
		dc.l	SHEV_ScreenBase
ExtOSScreenBase	dc.l	0
		dc.l	SHEV_BytesPerRow
ExtOSBPR	dc.l	0
		dc.l	SHEV_RefreshType
ExtOSRefType	dc.l	0
		dc.l	SHEV_Flags
ExtOSFlags	dc.l	0
		dc.l	0,0

; Taglists für externes CloseScreen und weitere leere Taglists
ExtCSOutTags
ExtCSInTags
ExtLRGBInTags
ExtLDOutTags
ExtULDOutTags
ExtULDInTags
ExtRefOutTags
ExtRefInTags
ExtPtrOutTags
ExtPtrInTags	dc.l	0,0

; Taglist für externes LockDisplay
ExtLDInTags	dc.l	SHEV_ScreenBase
ExtLDScreenBase	dc.l	0
		dc.l	0,0

; Taglists für externes LoadRGB32
ExtLRGBOutTags	dc.l	SHEV_ColorTable
ExtLRGBOutTab	dc.l	0
		dc.l	0,0

; Taglist für das Fenster
WindowTags	dc.l	WA_Left,0
		dc.l	WA_Top,0
		dc.l	WA_Width
WindowWidth	dc.l	0
		dc.l	WA_Height
WindowHeight	dc.l	0
		dc.l	WA_NoCareRefresh,-1
		dc.l	WA_Borderless,-1
		dc.l	WA_Activate,-1
		dc.l	WA_RMBTrap,-1
		dc.l	WA_CustomScreen
WindowScreen	dc.l	0
		dc.l	0,0

; Taglist für das Mac-In-A-Box-Fenster
BoxWinTags	dc.l	WA_Left,0
		dc.l	WA_Top,0
		dc.l	WA_InnerWidth
BoxWinWidth	dc.l	0
		dc.l	WA_InnerHeight
BoxWinHeight	dc.l	0
		dc.l	WA_SimpleRefresh,-1
		dc.l	WA_NoCareRefresh,-1
		dc.l	WA_Activate,-1
		dc.l	WA_RMBTrap,-1
		dc.l	WA_DragBar,-1
		dc.l	WA_DepthGadget,-1
		dc.l	WA_SizeGadget,0
		dc.l	WA_Title,BoxWindowName
		dc.l	0,0

; Taglist für das PIP-Fenster
PIPTags		dc.l	P96PIP_SourceFormat, RGBFB_R5G5B5
		dc.l	P96PIP_SourceWidth
PIPWidth1	dc.l	0
		dc.l	P96PIP_SourceHeight
PIPHeight1	dc.l	0
		dc.l	WA_Left,0
		dc.l	WA_Top,0
		dc.l	WA_InnerWidth
PIPWidth2	dc.l	0
		dc.l	WA_InnerHeight
PIPHeight2	dc.l	0
		dc.l	WA_SimpleRefresh,-1
		dc.l	WA_NoCareRefresh,-1
		dc.l	WA_Activate,-1
		dc.l	WA_RMBTrap,-1
		dc.l	WA_DragBar,-1
		dc.l	WA_DepthGadget,-1
		dc.l	WA_SizeGadget,0
		dc.l	WA_Title,BoxWindowName
		dc.l	WA_PubScreenName, WorkbenchName
		dc.l	0,0

; Taglist zum Lesen der PIP-Bitmap
PIPBitmapTags	dc.l	P96PIP_SourceBitMap, PIPBitmap
		dc.l	0,0

; Taglist für einen schwarzen Rahmen
VideoTags	dc.l	VTAG_BORDERBLANK_SET,0
		dc.l	0,0

; Leere EMouse
ClearEGSMouse	dc.l	$00000001,$ff0000ff,$80000080
		dc.w	1,1,16,16
		dc.l	0,NullPointer

; Stifte für Mac-In-A-Box-Modus (ObtainPen)
BlackPen	dc.l	-1
WhitePen	dc.l	-1


**
** Nicht initialisierte Daten
**

		SECTION	"BSS",BSS
VideoInfo1	ds.b	VideoInfo_SIZEOF	;Datenbereich Monitor 1
FixedBuf	ds.l	1	;DEPTHSWITCH: Grafikspeicher des Mac fuer alle Farbtiefen
FixedSize	ds.l	1
FixedMismatch	ds.b	1	;#0: Bildschirm passt nicht zum festen Puffer
		EVEN
ModeCount1	ds.w	1	;Anzahl Mac-Modi (Farbtiefen) von Monitor 1
ModeStart1	ds.w	1	;Index des Startmodus
ModeVM1		ds.w	6	;VMODE_ der Modi $80, $81, ...
ModeDID1	ds.l	6	;ModeID der Modi
SwitchReq	ds.l	1	;VideoInfo, dessen Farbtiefe der Refresh-Task wechseln soll
SwitchDID	ds.l	1	; neue ModeID
SwitchDoneSet	ds.l	1	;Signal (MyTask): Wechsel fertig
SwitchVM	ds.w	1	; neuer VMODE_
SwitchRes	ds.w	1	; Ergebnis, 0 = OK
SwitchDoneSig	ds.b	1
AccelBltOK	ds.b	1	;#0: BitBlt-Beschleunigung gilt fuer den Bildschirm
AccelLineOK	ds.b	1	;#0: FastLine ebenso
		EVEN
DimBufSize	= 88
DimBuf		ds.b	DimBufSize	;DimensionInfo
VideoInfo2	ds.b	VideoInfo_SIZEOF	;Datenbereich Monitor 2

ModeNameBuf	ds.b	nif_SIZEOF	;Puffer für GetDisplayInfoData
TheRect		ds.b	ra_SIZEOF	;Für QueryOverscan

MacBoxBitMap	ds.b	bm_SIZEOF	;Für Mac-In-A-Box V37
PIPBitmap	ds.l	1

		CNOP	0,4
ScrnBase1	ds.l	1	;Anfang des Mac-Grafikspeichers
ScrnBase2	ds.l	1
BytesPerRow1	ds.l	1	;Für den Mac-Grafikspeicher
BytesPerRow2	ds.l	1

BoxBorderLeft	ds.w	1	;Für Mac-In-A-Box: Ausmaße des linken/oberen
BoxBorderTop	ds.w	1	; Fensterrahmens

; Diese Variablen werden nur für den Refresh benutzt
PageSize2	ds.l	1	;Seitengröße/2
PageSize4	ds.l	1	;Seitengröße/4
PageSize8	ds.l	1	;Seitengröße/8
PageSize16	ds.l	1	;Seitengröße/16
PageSize3o4	ds.l	1	;Seitengröße*3/4

Plane1Base	ds.l	1	;Planes des Amiga-Grafikspeichers
Plane2Base	ds.l	1	;(werden nur für Planar->Chunky benutzt,
Plane3Base	ds.l	1	; mit der Ausnahme von Plane1Base, das
Plane4Base	ds.l	1	; für alle Refresh-Modes die Adresse des
Plane5Base	ds.l	1	; Amiga-Grafikspeichers angibt)
Plane6Base	ds.l	1
Plane7Base	ds.l	1
Plane8Base	ds.l	1

RefTaskProc	ds.l	1	;ProcID des RefreshTask
RefTask		ds.l	1	;Zeiger auf Task des Prozesses

RefQuitSet	ds.l	1	;Signal: RefreshTask soll sich beenden
RefQuitSig	ds.b	1

HasGfx39	ds.b	1	;#0: AGA-Chipset vorhanden
PointerBlank	ds.b	1	;#0: Amiga-Mauszeiger ist unsichtbar
WasFront1	ds.b	1	;#0: Mac-Screen 1/2 war beim letzten Blick vorn
WasFront2	ds.b	1
IsRefreshing	ds.b	1	;#0: Mindestens ein Screen wird refresht,
				;    OpenVideo muß den RefreshTask einrichten
IsDeltaRefresh	ds.b	1	;#0: Comparison Buffer für Amiga-Refresh benutzen

		SECTION	"CHIPBSS",BSS,CHIP
NullPointer	ds.b	1024	;Leerer Mauszeiger

		END
