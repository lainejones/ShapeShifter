*
* PrepareEmul - Vorbereitung für Macintosh-Emulator:
*               Untere 8K des Chip-Memory freihalten
*
* © Copyright 1994-2001 Christian Bauer
* © Copyright 1995 Dirk-Michael Brosig
*

		MACHINE	68020

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/nodes.i"
		INCLUDE	"exec/execbase.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"exec/libraries.i"
		INCLUDE	"exec/io.i"
		INCLUDE	"exec/resident.i"
		INCLUDE	"dos/dos.i"
		INCLUDE	"dos/dosextens.i"
		INCLUDE	"devices/inputevent.i"

		XREF	_SysBase
		XREF	_DOSBase
		XDEF	_main


**
** Definitionen
**

; Shutdown.library
Shutdown	= -48


**
** Hauptprogramm
**

		SECTION	"CODE",CODE,CHIP

*
* System für MacEmul geeignet?
*

_main		move.l	_SysBase,a6
		move.w	AttnFlags(a6),d0
		btst	#AFB_68020,d0		;68020 vorhanden?
		beq	Exit			;Nein, beenden
		cmp.w	#37,LIB_VERSION(a6)	;Exec V37+ (2.0)?
		bcs	Exit			;Nein, beenden

*
* CapsLock gedrückt? Dann nichts machen
*

		lea	InputName,a0
		moveq	#0,d0
		lea	IORequest,a1
		moveq	#0,d1
		JSRLIB	OpenDevice

		move.l	IORequest+IO_DEVICE,a6
		JSRLIB	PeekQualifier
		move.w	d0,d2

		move.l	_SysBase,a6
		lea	IORequest,a1
		JSRLIB	CloseDevice
		btst	#IEQUALIFIERB_CAPSLOCK,d2
		bne	Exit

*
* Test auf Schalter A1200, wenn gesetzt -> Sprung zu _dmb_main1200
* 

		move.l	_DOSBase,a6
		move.l	#_dmb_template,d1
		lea	_dmb_S_A1200,a0
		moveq	#0,d3
		move.l	d3,(a0)
		move.l	a0,d2
		JSRLIB	ReadArgs
		tst.l	d0
		beq	Exit

		move.l	d0,d1
		JSRLIB	FreeArgs
                                    	
		tst.l	_dmb_S_A1200
		bne	_dmb_main1200

*
* Sind die untersten 8K schon reserviert?
*

		move.l	_SysBase,a6
		lea	MemList(a6),a0
		lea	ChipMemName,a1
		JSRLIB	FindName
		cmp.l	#$2000,d0
		bhs	KickTagPresent

*
* Nein, KickTag schon installiert?
*

		lea	KickTagName,a1
		JSRLIB	FindResident
		tst.l	d0
		bne	KickTagPresent

*
* Nein, installieren
*

		JSRLIB	Disable

		move.l	#KickTagSize,d0		;Speicher holen
		move.l	#MEMF_REVERSE|MEMF_CHIP,d1
		JSRLIB	AllocMem
		move.l	d0,a2

		lea	KickTag,a0			;KickTag kopieren
		move.l	a2,a1
		move.l	#KickTagSize,d0
		JSRLIB	CopyMem

		lea	KTMemList-KickTag(a2),a0	;MemList einrichten
		move.l	KickMemPtr(a6),LN_SUCC(a0)
		move.l	a2,d0
		add.l	d0,LN_NAME(a0)
		move.l	a2,ML_ME+ME_ADDR(a0)
		move.l	a0,KickMemPtr(a6)

		lea	KTResList-KickTag(a2),a0	;ResList einrichten
		move.l	a2,(a0)
		addq.l	#8,(a0)				;Zeigt auf Resident
		move.l	KickTagPtr(a6),d0
		beq	1$
		bset	#31,d0
1$		move.l	d0,4(a0)
		move.l	a0,KickTagPtr(a6)

		lea	KickRes-KickTag(a2),a0
		move.l	a0,RT_MATCHTAG(a0)		;Resident einrichten
		move.l	a2,d0
		add.l	d0,RT_ENDSKIP(a0)
		add.l	d0,RT_NAME(a0)
		add.l	d0,RT_IDSTRING(a0)
		add.l	d0,RT_INIT(a0)

		JSRLIB	SumKickData
		move.l	d0,KickCheckSum(a6)

		JSRLIB	Enable

*
* ShutDown vorhanden?
*

RestartMe	lea	ShutDownName,a1
		moveq	#2,d0
		JSRLIB	OpenLibrary
		move.l	d0,_ShutdownBase
		beq	NoShutDown

*
* Ja, neustarten
*

		move.l	_ShutdownBase,a6
		moveq	#1,d0			;Fast
		jmp	Shutdown(a6)

*
* Nein, wird ein Datenträger gerade validiert?
*

NoShutDown	move.l	_DOSBase,a6
		move.l	#LDF_VOLUMES|LDF_READ,d1
		JSRLIB	LockDosList
		move.l	d0,d7		;d7: dlist
		beq	RebootMe

VLLoop		move.l	d7,d1
		move.l	#LDF_VOLUMES,d2
		JSRLIB	NextDosEntry
		move.l	d0,d7
		beq	NoneValidating

		move.l	d0,a0
		move.l	dol_Name(a0),d0
		add.l	d0,d0
		add.l	d0,d0
		move.l	d0,a0
		lea	StrBuf,a1
		bsr	ConvertBSTR

		move.l	#StrBuf,d1
		move.l	#ACCESS_READ,d2
		JSRLIB	Lock
		move.l	d0,d6		;d6: lock
		beq	VLLoop

		move.l	d6,d1
		move.l	#MyInfoData,d2
		JSRLIB	Info
		move.l	d6,d1
		JSRLIB	UnLock

		lea	MyInfoData,a0
		cmp.l	#ID_VALIDATING,id_DiskState(a0)
		bne	VLLoop

		move.l	#LDF_VOLUMES|LDF_READ,d1
		JSRLIB	UnLockDosList
		bra	Exit

NoneValidating	move.l	#LDF_VOLUMES|LDF_READ,d1
		JSRLIB	UnLockDosList

*
* Nein, alle Volumes sperren
*

; Erst alle Namen sammeln (weil Inhibit nicht funktioniert
; während die DosList gelockt ist)
		move.l	#ListHead,PtrToLast

		move.l	#LDF_VOLUMES|LDF_READ,d1
		JSRLIB	LockDosList
		move.l	d0,d7			;d7: dlist
		beq	RebootMe

DLLoop		move.l	_DOSBase,a6
		move.l	d7,d1
		move.l	#LDF_VOLUMES,d2
		JSRLIB	NextDosEntry
		move.l	d0,d7
		beq	AllGathered

		move.l	_SysBase,a6
		move.l	#256+4,d0		;Zeiger auf nächsten und 256 Bytes Name
		move.l	#MEMF_CLEAR,d1
		JSRLIB	AllocMem
		move.l	d0,d6
		beq	RebootMe

		move.l	PtrToLast,a0
		move.l	d6,(a0)
		move.l	d6,PtrToLast
		addq.l	#4,d6			;d6 zeigt auf Namen

		move.l	d7,a0
		move.l	dol_Name(a0),d0
		add.l	d0,d0
		add.l	d0,d0
		move.l	d0,a0
		move.l	d6,a1
		bsr	ConvertBSTR

		bra	DLLoop

AllGathered	move.l	#LDF_VOLUMES|LDF_READ,d1
		JSRLIB	UnLockDosList

; Dann alle gesammelten Volumes sperren
		lea	ListHead,a5

INLoop		move.l	(a5),d7			;Nächsten holen
		beq	RebootMe
		move.l	d7,a5
		addq.l	#4,d7

		move.l	d7,d1			;Handler ermitteln
		moveq	#0,d2
		JSRLIB	GetDeviceProc
		tst.l	d0
		beq	INLoop
		move.l	d0,a4

		move.l	dvp_Port(a4),d1		;Dateisystem flushen
		move.l	#ACTION_FLUSH,d2
		JSRLIB	DoPkt

		move.l	d7,d1			;und sperren
		move.l	#DOSTRUE,d2
		JSRLIB	Inhibit

		move.l	a4,d1
		JSRLIB	FreeDeviceProc

		bra	INLoop

*
* Und neu starten
*

RebootMe	move.l	_SysBase,a6
		JMPLIB	ColdReboot

*
* KickTag installiert/Untere 8K reserviert, VBR verschieben
*

KickTagPresent	move.l	_SysBase,a6
		lea	GetVBRProc,a5
		JSRLIB	Supervisor
		tst.l	d0
		bne	VBRInFast	;VBR bereits verschoben

		move.l	#$400,d0
		move.l	#MEMF_PUBLIC,d1
		JSRLIB	AllocMem
		move.l	d0,a3
		move.l	d0,a1
		sub.l	a0,a0
		move.l	#$400,d0
		JSRLIB	CopyMem
		JSRLIB	CacheClearU
		move.l	a3,d0
		lea	SetVBRProc,a5
		JSRLIB	Supervisor
VBRInFast

*
* Beenden
*

Exit		moveq	#0,d0
		rts


*
* BSTR in C-String konvertieren und ":" anhängen
* a0: APTR (!) auf BSTR
* a1: Zeiger auf Ziel-Puffer
*

ConvertBSTR	moveq	#0,d0
		move.b	(a0)+,d0
		beq	2$
		subq.w	#1,d0
1$		move.b	(a0)+,(a1)+
		dbra	d0,1$
2$		move.b	#':',(a1)+
		clr.b	(a1)+
		rts


*
* Routinen zum Setzen/Lesen des VBR
*

SetVBRProc	movec	d0,vbr
		rte

GetVBRProc	movec	vbr,d0
		rte


**
** Konstanten
**

InputName	dc.b	"input.device",0
ShutDownName	dc.b	"shutdown.library",0
_dmb_template	dc.b	"A1200/S",0
		CNOP	0,4


**
** KickTag
**
** Funktionsweise:
**  Im ersten Durchgang wird die Exec-Reset-Routine verkürzt neu
**   aufgerufen, wobei der bestehende Chip-MemHeader verändert
**   und die ExecBase neu eingerichtet wird, so daß der Bereich
**   $0-$2020 erstmal freibleibt
**  Im zweiten Durchgang wird bei $2000 der neue Chip-MemHeader
**   eingerichtet (im wesentlichen wird der veränderte alte kopiert)
**

		SECTION	"KICK",DATA,CHIP

KickTag		dc.l	0,0			;"Pufferzone"

KickRes		dc.w	RTC_MATCHWORD
		dc.l	0
		dc.l	KickTagSize
		dc.b	RTF_COLDSTART,1,0,127
		dc.l	KickTagName-KickTag
		dc.l	KickTagID-KickTag
		dc.l	KTInitCode-KickTag

KTMemList	dc.l	0,0
		dc.b	NT_MEMORY,0
		dc.l	KickTagName-KickTag
		dc.w	1
		dc.l	0
		dc.l	KickTagSize

KTResList	dc.l	0,0

KickTagName	dc.b	"PrepareEmul",0
		dc.b	"$VER: "
KickTagID	dc.b	"PrepareEmul V1.7 (07-Mar-1996)",10,13,0
		CNOP	0,4

KTInitCode	movem.l	a2/a5,-(sp)
		JSRLIB	Disable

		lea	MemList(a6),a0		;Chip-Region holen
		lea	ChipMemName,a1
		JSRLIB	FindName
		move.l	d0,a2

		lea	LibList(a6),a0		;Expansion im LowMem?
		lea	ExpansionName,a1
		JSRLIB	FindName
		cmp.l	#$2000,d0
		bhs	2$

		lea	KTSuperProc,a5		;Ja, MemHeader verschieben
		JMPLIB	Supervisor

; 2. Durchgang
2$		move.l	a2,a0			;Nein, MemHeader kopieren...
		lea	$2000,a1
		moveq	#32/4-1,d0
1$		move.l	(a0)+,(a1)+
		dbra	d0,1$

		move.l	a2,a1			;...und neu einhängen
		JSRLIB	Remove
		lea	MemList(a6),a0
		lea	$2000,a1
		JSRLIB	AddTail

		JSRLIB	Enable
		movem.l	(sp)+,a2/a5
		rts

ChipMemName	dc.b	"chip memory",0
ExpansionName	dc.b	"expansion.library",0
		CNOP	0,4

; 1. Durchgang
KTSuperProc	move.l	#$2020,MH_FIRST(a2)	;Bestehenden MemHeader verändern
		move.l	#$1000,MH_LOWER(a2)	; (wie einen 8K-MemHeader einrichten)
		move.l	MaxLocMem(a6),d0	;MH_LOWER ist $1000 und nicht $2000,
		move.l	d0,MH_UPPER(a2)		; weil sonst die 68040.library die
		sub.l	#$2020,d0		; Seite bei $1000 als ungültig markiert
		move.l	d0,MH_FREE(a2)

		clr.l	$2020			;Erster MemChunk bei $2020
		move.l	d0,$2024

		move.l	a2,a0			;Speicher für ExecBase aus
		moveq	#0,d0			; dieser MemRegion anfordern
		move.w	LIB_NEGSIZE(a6),d0
		add.w	LIB_POSSIZE(a6),d0
		JSRLIB	Allocate		;d0: Zeiger auf neue ExecBase

		lea	$f80000,a1		;In ROM nach Initialisierung
1$		cmp.l	#$323c0303,(a1)		; der Chip-Region und der
		beq	2$			; ExecBase suchen
		addq.w	#2,a1			;1. Suche nach move.w #$0303,d1
		bra	1$
2$		cmp.w	#$2c40,(a1)		;2. Suche nach move.l d0,a6
		beq	21$
		addq.w	#2,a1
		bra	2$			;a1: Zeiger auf move.l d0,a6

21$		clr.l	$1f80			;$1f80 Flag: Exec V39
		cmp.w	#39,LIB_VERSION(a6)
		blt	3$
		move.l	a2,$1f80

3$		move.l	$100,$1f84		;Guru-Nummer retten
		move.l	$104,$1f88

		movem.l	KickMemPtr(a6),d2-d4	;Register für die Reset-
		movem.l	ColdCapture(a6),d5-d7	; Routine laden
		move.l	MaxLocMem(a6),a3
		move.l	$20e(a6),a4
		move.w	AttnFlags(a6),a2
		sub.l	a5,a5
		cmp.l	#$200000,a6
		blt	4$
		move.l	a6,a5
4$		movem.l	d0-d7/a0-a5,$1f00	;...und sichern

		move.l	$f80004,a0		;a0: Zeiger auf ROM-Reset-Routine
		subq.l	#2,a0
		move.l	a0,a2
		sub.l	#$f80000,a2		;a2: Entspr. RAM-Reset (ab Adresse Null)

		move.l	a2,a1			;Reset-Routine kopieren
5$		cmp.w	#$4e7b,(a0)		;Bis zu movec
		beq	6$
		cmp.l	#$22380004,(a0)		;oder move.l $04,d1
		beq	6$
		move.w	(a0)+,(a1)+
		bra	5$

6$		move.w	#$4ef9,(a1)+		;jmp KTReset anhängen
		lea	KTReset,a0
		move.l	a0,(a1)

		subq.w	#4,a2			;reset nop davorsetzen
		move.l	#$4e704e71,(a2)

		JSRLIB	CacheClearU		;Einspringen
		jmp	(a2)

KTReset		movem.l	$1f00,d0-d7/a0-a5
		move.l	$1f84,$100		;$100/$104 zurückholen
		move.l	$1f88,$104
		lea	$400,sp
		tst.l	$1f80
		beq	1$
		move.l	$1f80,-(sp)
1$		jmp	(a1)			;Bei move.l d0,a6 im ROM (s.o.)
						; gehts weiter

KickTagSize	= *-KickTag


**
** Routinen zum Resetfestmachen über COLD/COOLSTART
**

		SECTION	"CODE",CODE,CHIP

_dmb_main1200	jsr	_dmb_SetPnt
		tst.l	D0
		beq	_dmb_ende1200
		jsr	RestartMe
_dmb_ende1200	jmp	Exit

_dmb_CCStart	
_dmb_SetPnt	move.l	$04,A6
		move.l	$2e(A6),A0
		cmp.l	#$00,A0
		beq	_dmb_SetPnt1
           	sub.l	#$04,A0
           	cmp.l	#'CBS0',(A0)
           	bne	_dmb_SetPnt1
		moveq	#$00,D0
		rts
		
_dmb_SetPnt1	move.l	#$f80000,A0
_dmb_SetPntL1	cmp.w	#$4cee,(A0)+
		bne	_dmb_SetPntL1
		move.l	A0,A1
_dmb_SetPntL2	cmp.w	#$6100,(A0)+
		bne	_dmb_SetPntL2
		move.w	(A0),D0
		move.l	A0,A2
		sub.l	A1,A2
		add.l	D0,A2
		add.l	#$02,A2
		lea	_dmb_ColdInJumpOfs(PC),A1
		move.l	A2,(A1)
_dmb_SetPntL3	cmp.w	#$43fa,(A0)+
		bne	_dmb_SetPntL3
     		sub.l	#$02,A0
     		lea	_dmb_ColdBackJump(PC),A1
     		move.l	A0,(A1)
     		
_dmb_SetPnt2	lea	_dmb_NewColdPtr(PC),A0
		lea	_dmb_OldColdPtr(PC),A1
		move.l	$2a(A6),(A1)
		move.l	A0,$2a(A6)
 		
		lea	_dmb_NewCoolPtr(PC),A0
		lea	_dmb_OldCoolPtr(PC),A1
		move.l	$2e(A6),(A1)
		move.l	A0,$2e(A6)
		move.l	(A1),A2
  		cmpa.l	A0,A2
  		bne.s	_dmb_SetPnt3
  		move.l	#$00,(A1)
  		
_dmb_SetPnt3	move.w	#0,$24(A6)
		moveq	#0,D1
		lea	$22(A6),A0
		moveq	#$18,D0
_dmb_SetPntLoop	add.w	(A0)+,D1
		dbra	D0,_dmb_SetPntLoop
		not.w	D1
		move.w	D1,$24(A6)
_dmb_SetPntEnde	rts

;--------------------------------------------------------------------

_dmb_OldCoolPtr		dc.l	0
_dmb_OldColdPtr		dc.l	0
_dmb_ColdInJump		dc.l	0
_dmb_ColdInJumpOfs	dc.l	0
_dmb_ColdBackJump	dc.l	0
_dmb_IsInstalled	dc.b	'CBS0'
                	even
;--------------------------------------------------------------------

_dmb_NewCoolPtr	move.l	_dmb_OldCoolPtr(PC),A0
 		cmp.l	#$00,A0
 		beq	_dmb_NCPtr0
		jsr	(A0)

_dmb_NCPtr0	bsr	_dmb_SetPnt2
		move.l	#_dmb_CCEnde-_dmb_CCStart,D0
		lea	_dmb_CCStart(PC),A1
		move.l	$04,A6
		jsr	-$cc(A6)		; AllocAbs

		lea	_dmb_GetVBR(PC),A5
		move.l	$04,A6
		jsr	-30(A6)			; Supervisor
		tst.l	D0
		bne	_dmb_NCPtrEnde

		move.l	#$400,D0
		moveq	#$00,D1
		move.l	$04,A6
		jsr	-684(A6)		; AllocVec
		move.l	D0,A1
		sub.l	A0,A0
		move.w	#1024/4-1,D1
_dmb_NCPtr1	move.l	(A0)+,(A1)+
		dbra	D1,_dmb_NCPtr1
		lea	_dmb_SetVBR(PC),A5
		move.l	$04,A6
		jsr	-30(A6)			; Supervisor

_dmb_NCPtrEnde	rts

_dmb_SetVBR	movec	d0,vbr
		rte

_dmb_GetVBR	movec	vbr,d0
		rte
		
;--------------------------------------------------------------------

_dmb_NewColdPtr	move.l	#$1e240,D2
_dmb_NColdPtrL	move.b	$dff006,$dff180
		dbra	D2,_dmb_NColdPtrL	; Streifen zaubern

		lea	_dmb_ColdInJump(PC),A4	; Start ROM Rücksprung (A5)
		move.l	A5,(A4)			; merken
 		
 		move.l	_dmb_OldColdPtr(PC),A0
 		cmp.l	#$00,A0
 		beq.s	_dmb_NColdPtr0
		lea	_dmb_NColdPtr0(PC),A5
		jmp	(A0)

_dmb_NColdPtr0	move.l	_dmb_ColdInJump(PC),A4	; Start ROM Rücksprung (A5)
 		move.w	$e(A4),A4
		movem.l	$222(A6),D2-D4
		movem.l	$2a(A6),D5-D7
		move.w	$14(A6),A5
		cmp.w	A5,A4
		bne.s	_dmb_NColdPtr1
		move.l	$20E(A6),A4
_dmb_NColdPtr1	sub.l	A6,A6
		move.l	A6,A5
		move.l	_dmb_ColdInJump(PC),A3
		add.l	_dmb_ColdInJumpOfs(PC),A3
		jsr	(A3)			; ORIG: BSR lbC000B4C
		move.l	D0,A2
		sub.l	A0,A0
		move.l	(A0),A1
		clr.l	(A0)
		sub.l	A3,A3
		move.l	#$f2d4b689,D1
		bra.s	_dmb_NColdPtr3
_dmb_NColdPtr2	move.l	D0,(A3)
_dmb_NColdPtr3	lea	$4000(A3),A3
		cmp.l	#$00200000,A3
		beq.s	_dmb_NColdPtr4
		move.l	(A3),D0
		move.l	D1,(A3)
		nop
		cmp.l	(A0),D1
		beq.s	_dmb_NColdPtr4
		cmp.l	(A3),D1
		beq.s	_dmb_NColdPtr2
_dmb_NColdPtr4	move.l	D0,(A3)
		move.l	A1,(A0)
		move.l	D2,-(SP)
		lea	$00002000,a0		; ORIG: LEA $00000400,A0
		move.l	A2,D2
		btst	#$03,D2
		beq.s	_dmb_NColdPtr5
		lea	$00002c00,A0		; ORIG: LEA $00001000,A0
_dmb_NColdPtr5	move.l	_dmb_ColdBackJump(PC),A1 ; Rücksprung über A1, weil
		jmp	(A1)			; kein anderes Reg mehr frei!

_dmb_CCEnde	NOP


**
** Nicht initialisierte Daten
**

		SECTION	"BSS",BSS,CHIP

MyInfoData	ds.b	id_SIZEOF
IORequest	ds.b	34
StrBuf		ds.b	256
ListHead	ds.l	1
PtrToLast	ds.l	1
_ShutdownBase	ds.l	1
_dmb_S_A1200	ds.l	1

		END
