**
** Macintosh IIci-Emulator - Amiga Clipboard Support
** =================================================
**
** © Copyright 1994-2001 Christian Bauer
**
** Funktionsweise:
** ---------------
**
** PutScrap  : Daten lesen, konvertieren und Clip-Task benachrichtigen
** ChangeHook: ClipTask benachrichtigen
** CheckClip : Wenn Flag gesetzt, Daten in Mac-Clipboard schreiben
** ClipTask  : Amiga -> Mac: Daten lesen, konvertieren und Flag für CheckClip setzen
**             Mac -> Amiga: Daten in Amiga-Clipboard schreiben
**

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"exec/tasks.i"
		INCLUDE	"dos/dostags.i"
		INCLUDE	"devices/clipboard.i"
		INCLUDE	"libraries/iffparse.i"
		INCLUDE	"macros.i"

		XDEF	OpenClipboard
		XDEF	CloseClipboard
		XDEF	PutScrap
		XDEF	CheckClip
		XDEF	CTTogglePointer

		XREF	SubtaskSet	;MacEmul.asm

		XREF	OldPutScrap	;MacEmulPatches.asm

		SECTION	"CODE",CODE


**
** Initialisierung
** Rückgabe: d0#0 = Fehler
**

; ReplyPort einrichten
OpenClipboard	move.l	_ExecBase(pc),a6
		JSRLIB	CreateMsgPort
		move.l	d0,ClipPort
		beq	OpenErr

; IORequest einrichten
		move.l	ClipPort,a0
		moveq	#iocr_SIZEOF,d0
		JSRLIB	CreateIORequest
		move.l	d0,HookRequest
		beq	OpenErr

; Clipboard öffnen
		lea	ClipBoardName,a0
		moveq	#PRIMARY_CLIP,d0
		move.l	HookRequest,a1
		moveq	#0,d1		;Flags
		JSRLIB	OpenDevice
		tst.l	d0
		bne	OpenDevErr

; Task starten
		move.l	_DOSBase,a6
		move.l	#ProcTags,d1
		JSRLIB	CreateNewProc
		move.l	d0,ClipTaskProc
		beq	OpenErr

; Auf Signal warten
		move.l	_ExecBase(pc),a6
		move.l	SubtaskSet,d0
		JSRLIB	Wait

; ChangeHook installieren
		move.l	HookRequest,a1
		move.w	#CBD_CHANGEHOOK,IO_COMMAND(a1)
		move.l	#ClipHook,IO_DATA(a1)
		move.l	#1,IO_LENGTH(a1)	;Add Hook
		JSRLIB	DoIO
		moveq	#0,d0			;Alles OK
		rts

; Fehler aufgetreten
OpenErr		moveq	#-1,d0
		rts

OpenDevErr	move.l	HookRequest,a0
		JSRLIB	DeleteIORequest
		clr.l	HookRequest
		moveq	#-1,d0
		rts


**
** Beenden
**

; ChangeHook entfernen und IORequest freigeben
CloseClipboard	move.l	_ExecBase(pc),a6
		move.l	HookRequest,d0
		beq	2$

		move.l	d0,a1
		move.w	#CBD_CHANGEHOOK,IO_COMMAND(a1)
		move.l	#ClipHook,IO_DATA(a1)
		clr.l	IO_LENGTH(a1)		;Remove Hook
		JSRLIB	DoIO

		move.l	HookRequest,a1
		JSRLIB	CloseDevice

		move.l	HookRequest,a0
		JSRLIB	DeleteIORequest

; ReplyPort freigeben
2$		move.l	ClipPort,d0
		beq	3$
		move.l	d0,a0
		JSRLIB	DeleteMsgPort

; ClipTask entfernen
3$		move.l	ClipTask,d0
		beq	1$
		move.l	d0,a1
		move.l	ClipQuitSet,d0
		JSRLIB	Signal
		move.l	SubtaskSet,d0
		JSRLIB	Wait

; Speicher freigeben
1$		move.l	AmigaScrap,d0		;AmigaScrap vorhanden?
		beq	4$
		move.l	d0,a1			;Ja, freigeben
		JSRLIB	FreeVec

4$		move.l	MacClipboard,d0		;MacClipboard vorhanden?
		beq	5$
		move.l	d0,a1			;Ja, freigeben
		JSRLIB	FreeVec
5$		rts


**
** Mauszeiger (un)sichtbar machen
**

CTTogglePointer	move.l	a6,-(sp)
		move.l	_ExecBase(pc),a6
		move.l	ClipTask,a1
		move.l	ClipPointerSet,d0
		JSRLIB	Signal
		move.l	(sp)+,a6
		rts


**
** ChangeHook - Der Inhalt des Amiga-Clipboards hat sich geändert,
**              ClipTask benachrichtigen
**

; Dürfen wir aktiv werden?
ChangeHook	tst.w	MacRunning
		beq	1$
		tst.b	EmulDidChange
		bne	2$

; Ja, Signal an ClipTask schicken
		move.l	a6,-(sp)
		move.l	_ExecBase(pc),a6
		move.l	ClipTask,a1
		move.l	ClipAmiga2MacSet,d0
		JSRLIB	Signal
		move.l	(sp)+,a6

2$		clr.b	EmulDidChange
1$		moveq	#0,d0
		rts


**
** PutScrap - Der Inhalt des Mac-Clipboards hat sich geändert,
**            ClipTask benachrichtigen
**

PutScrap	tst.b	EmulDidPut
		bne	1$
		cmp.l	#'TEXT',8(sp)
		beq	PutTEXT
1$		clr.b	EmulDidPut
		move.l	OldPutScrap,-(sp)
		rts

PutTEXT		move.l	4(sp),ScrapPtr
		move.l	12(sp),ScrapLength

		movem.l	d2/a3/a6,-(sp)
		move.l	_ExecBase(pc),a6
		move.l	ScrapLength,d0		;Speicher zum Konvertieren anfordern
		ble	3$			;Leerer Text: nichts zu konvertieren
		moveq	#MEMF_PUBLIC,d1
		EJSRLIB	AllocVec
		tst.l	d0
		beq	3$
		move.l	d0,a3

		move.l	ScrapPtr,a0		;Text konvertieren
		move.l	a3,a1
		move.l	ScrapLength,d2
1$		move.b	(a0)+,d0
		JSRSELF	ConvMacToIso
		move.b	d0,(a1)+
		subq.l	#1,d2
		bne	1$

		JSRLIB	Forbid
		move.l	MacClipboard,d0		;Altes MacClipboard vorhanden?
		beq	2$
		move.l	d0,a1			;Ja, freigeben
		EJSRLIB	FreeVec
2$		move.l	a3,MacClipboard		;Neues MacClipboard eintragen
		move.l	ScrapLength,MacLength
		JSRLIB	Permit

		move.l	ClipTask,a1		;ClipTask benachrichtigen
		move.l	ClipMac2AmigaSet,d0
		JSRLIB	Signal

3$		movem.l	(sp)+,d2/a3/a6
		move.l	OldPutScrap,-(sp)
		rts


**
** CheckClip - Wenn von der Amiga-Seite neue Daten eingetroffen sind,
**             diese in das Mac-Clipboard schreiben
**
** Es dürfen keine Register geändert werden
**

CheckClip	move.l	a6,-(sp)
		move.l	_ExecBase(pc),a6
		JSRLIB	Forbid

		tst.b	NewAmigaScrap
		beq	1$

		movem.l	a0-a1/d0-d1,-(sp)
		st.b	EmulDidPut		;Wir haben das Clipboard geändert
		subq.l	#4,sp
		dc.w	$a9fc			;ZeroScrap
		move.l	AmigaLength,-(sp)	;Länge
		move.l	#'TEXT',-(sp)		;Typ
		move.l	AmigaScrap,-(sp)	;Ptr
		dc.w	$a9fe			;PutScrap
		addq.l	#4,sp
		clr.b	NewAmigaScrap

		move.l	AmigaScrap,a1		;AmigaScrap freigeben
		EJSRLIB	FreeVec
		clr.l	AmigaScrap

		movem.l	(sp)+,a0-a1/d0-d1

1$		JSRLIB	Permit
		move.l	(sp)+,a6
		rts


**
** ClipTask - Wenn ein Signal vom ChangeHook eintrifft,
**            Daten lesen, konvertieren und Flag für CheckClip setzen
**

; Task ermitteln
ClipTaskMain	move.l	_ExecBase(pc),a6
		sub.l	a1,a1
		JSRLIB	FindTask
		move.l	d0,ClipTask

; Signale zur Kommunikation anfordern
		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,ClipAmiga2MacSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,ClipAmiga2MacSet

		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,ClipMac2AmigaSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,ClipMac2AmigaSet

		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,ClipPointerSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,ClipPointerSet

		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,ClipQuitSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,ClipQuitSet

; IFFHandles zum Lesen und Schreiben erzeugen
		move.l	_IFFParseBase(pc),a6
		JSRLIB	AllocIFF
		move.l	d0,IFFR
		beq	CTSigEmul	;Fehler: Auf Quit warten

		JSRLIB	AllocIFF
		move.l	d0,IFFW
		beq	CTSigEmul

; Clipboard öffnen
		moveq	#PRIMARY_CLIP,d0
		JSRLIB	OpenClipboard
		move.l	IFFR,a0
		move.l	d0,iff_Stream(a0)
		beq	CTSigEmul

		moveq	#PRIMARY_CLIP,d0
		JSRLIB	OpenClipboard
		move.l	IFFW,a0
		move.l	d0,iff_Stream(a0)
		beq	CTSigEmul

; IFFHandles initialisieren
		move.l	IFFR,a0
		JSRLIB	InitIFFasClip

		move.l	IFFW,a0
		JSRLIB	InitIFFasClip

; Dem Emulator Bescheid sagen
CTSigEmul	move.l	_ExecBase(pc),a6
		move.l	MyTask,a1
		move.l	SubtaskSet,d0
		JSRLIB	Signal

; Hauptschleife: Auf Signal warten
CTMainLoop	move.l	_ExecBase(pc),a6
		move.l	ClipAmiga2MacSet,d0
		or.l	ClipMac2AmigaSet,d0
		or.l	ClipPointerSet,d0
		or.l	ClipQuitSet,d0
		JSRLIB	Wait
		move.l	d0,TheSignals

CTSigLoop	move.l	TheSignals,d0
		move.l	d0,d1
		and.l	ClipAmiga2MacSet,d1
		beq	1$
		eor.l	d1,TheSignals
		bra	CTAmiga2Mac

1$		move.l	d0,d1
		and.l	ClipMac2AmigaSet,d1
		beq	2$
		eor.l	d1,TheSignals
		bra	CTMac2Amiga

2$		move.l	d0,d1
		and.l	ClipPointerSet,d1
		beq	3$
		eor.l	d1,TheSignals
		bra	CTPointer

3$		move.l	d0,d1
		and.l	ClipQuitSet,d1
		beq	CTMainLoop
		eor.l	d1,TheSignals
		bra	CTQuit

; Amiga-Clipboard wurde geändert
CTAmiga2Mac	move.l	_IFFParseBase(pc),a6
		move.l	IFFR,a0			;IFF-Stream öffnen
		moveq	#IFFF_READ,d0
		JSRLIB	OpenIFF
		tst.l	d0
		bne	CTSigLoop

		move.l	IFFR,a0			;Bei CHRS-Chunk anhalten
		move.l	#'FTXT',d0
		move.l	#'CHRS',d1
		JSRLIB	StopChunk
		tst.l	d0
		bne	1$

		move.l	IFFR,a0			;Clipboard parsen
		moveq	#IFFPARSE_SCAN,d0
		JSRLIB	ParseIFF
		tst.l	d0
		bne	1$

		move.l	IFFR,a0			;Aktuellen Chunk holen
		JSRLIB	CurrentChunk
		tst.l	d0
		beq	1$
		move.l	d0,a2			;a2: CurrentChunk
		cmp.l	#'FTXT',cn_Type(a2)
		bne	1$
		cmp.l	#'CHRS',cn_ID(a2)
		bne	1$

		move.l	_ExecBase(pc),a6
		move.l	cn_Size(a2),d0		;Speicher zum Konvertieren anfordern
		ble	1$			;Leerer Chunk
		moveq	#MEMF_PUBLIC,d1
		JSRLIB	AllocVec
		tst.l	d0
		beq	1$
		move.l	d0,a3			;a3: Buffer

		move.l	_IFFParseBase(pc),a6
		move.l	IFFR,a0			;CHRS-Chunk lesen
		move.l	a3,a1
		move.l	cn_Size(a2),d0
		JSRLIB	ReadChunkBytes

		move.l	a3,a1			;Text konvertieren
		move.l	cn_Size(a2),d1
10$		move.b	(a1),d0
		JSRSELF	ConvIsoToMac
		move.b	d0,(a1)+
		subq.l	#1,d1
		bne	10$

		move.l	_ExecBase(pc),a6
		JSRLIB	Forbid

		move.l	AmigaScrap,d0		;Alter AmigaScrap vorhanden?
		beq	2$
		move.l	d0,a1			;Ja, freigeben
		JSRLIB	FreeVec

2$		move.l	a3,AmigaScrap		;Neuen AmigaScrap eintragen
		move.l	cn_Size(a2),AmigaLength
		st.b	NewAmigaScrap

		JSRLIB	Permit

1$		move.l	_IFFParseBase(pc),a6
		move.l	IFFR,a0
		JSRLIB	CloseIFF
		bra	CTSigLoop

; Mac-Clipboard wurde geändert
CTMac2Amiga	move.l	_IFFParseBase(pc),a6
		move.l	IFFW,a0			;IFF-Stream öffnen
		moveq	#IFFF_WRITE,d0
		JSRLIB	OpenIFF
		tst.l	d0
		bne	3$

		move.l	IFFW,a0			;FORM-ID schreiben
		move.l	#'FTXT',d0
		move.l	#'FORM',d1
		moveq	#IFFSIZE_UNKNOWN,d2
		JSRLIB	PushChunk
		tst.l	d0
		bne	1$

		move.l	IFFW,a0			;CHRS-ID schreiben
		moveq	#0,d0
		move.l	#'CHRS',d1
		moveq	#IFFSIZE_UNKNOWN,d2
		JSRLIB	PushChunk
		tst.l	d0
		bne	2$

		move.l	IFFW,a0			;CHRS-Chunk schreiben
		move.l	MacClipboard,a1
		move.l	MacLength,d0
		JSRLIB	WriteChunkBytes

		st.b	EmulDidChange		;Wir haben das Clipboard geändert

		move.l	IFFW,a0
		JSRLIB	PopChunk

2$		move.l	IFFW,a0
		JSRLIB	PopChunk

1$		move.l	IFFW,a0
		JSRLIB	CloseIFF

3$		move.l	_ExecBase(pc),a6	;MacClipboard freigeben
		JSRLIB	Forbid
		move.l	MacClipboard,a1
		JSRLIB	FreeVec
		clr.l	MacClipboard
		JSRLIB	Permit

		bra	CTSigLoop

; Mauszeiger (un)sichtbar machen
CTPointer	JSRSELF	TogglePointer
		bra	CTSigLoop

; ClipTask beenden
CTQuit		move.l	_ExecBase(pc),a6

		move.b	ClipAmiga2MacSig,d0
		JSRLIB	FreeSignal
		move.b	ClipMac2AmigaSig,d0
		JSRLIB	FreeSignal
		move.b	ClipPointerSig,d0
		JSRLIB	FreeSignal
		move.b	ClipQuitSig,d0
		JSRLIB	FreeSignal

		move.l	_IFFParseBase(pc),a6

		move.l	IFFW,d0			;IFFHandle zum Schreiben vorhanden?
		beq	3$
		move.l	d0,a0			;Ja, Stream vorhanden?
		move.l	iff_Stream(a0),d0
		beq	4$
		move.l	d0,a0			;Ja, Clipboard schließen
		JSRLIB	CloseClipboard
4$		move.l	IFFW,a0			;IFFHandle freigeben
		JSRLIB	FreeIFF

3$		move.l	IFFR,d0			;IFFHandle zum Lesen vorhanden?
		beq	1$
		move.l	d0,a0			;Ja, Stream vorhanden?
		move.l	iff_Stream(a0),d0
		beq	2$
		move.l	d0,a0			;Ja, Clipboard schließen
		JSRLIB	CloseClipboard
2$		move.l	IFFR,a0			;IFFHandle freigeben
		JSRLIB	FreeIFF

1$		move.l	_ExecBase(pc),a6	;Dem Emulator Bescheid sagen
		JSRLIB	Forbid
		move.l	MyTask,a1
		move.l	SubtaskSet,d0
		JSRLIB	Signal
		moveq	#0,d0
		rts


**
** Konstanten
**

ClipBoardName	dc.b	"clipboard.device",0
ClipTaskName	dc.b	"ShapeShifter ClipTask",0
		CNOP	0,4

ProcTags	dc.l	NP_Entry,ClipTaskMain
		dc.l	NP_Name,ClipTaskName
		dc.l	NP_Priority,1
		dc.l	0,0


**
** Initialisierte Daten
**

		SECTION	"DATA",DATA
ClipHook	dc.l	0,0,ChangeHook,0,0


**
** Nicht initialisierte Daten
**

		SECTION	"BSS",BSS
ClipTaskProc	ds.l	1	;ProcID des ClipTask
ClipTask	ds.l	1	;Zeiger auf Task des Prozesses

ClipPort	ds.l	1	;Zeiger auf ReplyPort
HookRequest	ds.l	1	;Request für CBD_CHANGEHOOK

IFFW		ds.l	1	;IFFHandle für PutScrap
IFFR		ds.l	1	;IFFHandle für ChangeHook

ScrapPtr	ds.l	1	;Hilfsvariablen für PutScrap
ScrapLength	ds.l	1

AmigaScrap	ds.l	1	;Zeiger auf konvertierte Daten aus dem Amiga-Clipboard
AmigaLength	ds.l	1	;Länge der Daten

MacClipboard	ds.l	1	;Zeiger auf konvertierte Daten aus dem Mac-Clipboard
MacLength	ds.l	1	;Länge der Daten

TheSignals	ds.l	1	;Empfangene Signale

ClipAmiga2MacSet ds.l	1	;Signal: ChangeHook wurde aufgerufen
ClipMac2AmigaSet ds.l	1	;Signal: PutScrap wurde aufgerufen
ClipPointerSet	ds.l	1	;Signal: Mauszeiger (un)sichtbar machen
ClipQuitSet	ds.l	1	;Signal: ClipTask beenden
ClipAmiga2MacSig ds.b	1
ClipMac2AmigaSig ds.b	1
ClipPointerSig	ds.b	1
ClipQuitSig	ds.b	1

NewAmigaScrap	ds.b	1	;#0: Amiga-Clipboard wurde geändert, AmigaScrap ist gültig
EmulDidChange	ds.b	1	;#0: Der ChangeHook braucht nichts zu tun,
				;weil das Clipboard von PutScrap geändert wurde
EmulDidPut	ds.b	1	;#0: PutScrap braucht nichts zu tun,
				;weil der Emulator es aufgerufen hat

		END
