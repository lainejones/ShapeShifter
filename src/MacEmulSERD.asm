**
** Macintosh IIci-Emulator - Amiga Serieller Treiber
** =================================================
**
** © Copyright 1993-2001 Christian Bauer
**

DEBUG_DETAIL	SET 0

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/nodes.i"
		INCLUDE	"exec/lists.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"exec/ports.i"
		INCLUDE	"exec/tasks.i"
		INCLUDE	"exec/errors.i"
		INCLUDE	"devices/serial.i"
		INCLUDE	"devices/parallel.i"
		INCLUDE	"macros.i"
		INCLUDE	"macinclude.i"

		XREF	NetworkSig
		XREF	NetworkExcept


		XDEF	OpenSerial
		XDEF	CloseSerial
		XDEF	SERDEntry
		XDEF	SERDEnd

		SECTION	"CODE",CODE


**
** Definitionen
**

; SERD Data Structure
 STRUCTURE SERDDATA,0
	APTR	serd_DeviceName
	LONG	serd_DeviceUnit

	APTR	serd_ReplyPort
	APTR	serd_ControlPort

	APTR	serd_ReadIO
	APTR	serd_WriteIO
	APTR	serd_ControlIO

	APTR	serd_ReadIOParam
	APTR	serd_WriteIOParam

	APTR	serd_InDCE
	APTR	serd_OutDCE

	BYTE	serd_EventMask
	BYTE	serd_ErrMask
	BYTE	serd_CumErrors
	BYTE	serd_IsPar		;#0: paralleles Gerät
	BYTE	serd_IsOpen		;#0: Gerät geöffnet
	BYTE	serd_pad0

	BYTE	serd_ReadPending	;#0: ReadIO wird benutzt
	BYTE	serd_WritePending	;#0: WriteIO wird benutzt

	STRUCT	serd_Configuration,IO_STATUS-IO_CTLCHAR
 LABEL serd_SIZEOF


**
** Initialisierung
**

; Modemport
OpenSerial	move.l	_ExecBase,a6
		lea	SerialVarsA,a2
		JSRLIB	CreateMsgPort
		move.l	d0,serd_ReplyPort(a2)
		beq	OSError
		move.l	d0,a0
		move.b	MP_SIGBIT(a0),SerialASig

		JSRLIB	CreateMsgPort
		move.l	d0,serd_ControlPort(a2)
		beq	OSError

		move.l	serd_ReplyPort(a2),a0
		moveq	#IOEXTSER_SIZE,d0
		JSRLIB	CreateIORequest
		move.l	d0,serd_ReadIO(a2)
		beq	OSError

		move.l	serd_ReplyPort(a2),a0
		moveq	#IOEXTSER_SIZE,d0
		JSRLIB	CreateIORequest
		move.l	d0,serd_WriteIO(a2)
		beq	OSError

		move.l	serd_ControlPort(a2),a0
		moveq	#IOEXTSER_SIZE,d0
		JSRLIB	CreateIORequest
		move.l	d0,serd_ControlIO(a2)
		beq	OSError

		move.l	#SERDNameA,serd_DeviceName(a2)
		move.l	SERDUnitA,serd_DeviceUnit(a2)
		move.b	SERDAIsPar+1,serd_IsPar(a2)

; Druckerport
		lea	SerialVarsB,a2
		JSRLIB	CreateMsgPort
		move.l	d0,serd_ReplyPort(a2)
		beq	OSError
		move.l	d0,a0
		move.b	MP_SIGBIT(a0),SerialBSig

		JSRLIB	CreateMsgPort
		move.l	d0,serd_ControlPort(a2)
		beq	OSError

		move.l	serd_ReplyPort(a2),a0
		moveq	#IOEXTSER_SIZE,d0
		JSRLIB	CreateIORequest
		move.l	d0,serd_ReadIO(a2)
		beq	OSError

		move.l	serd_ReplyPort(a2),a0
		moveq	#IOEXTSER_SIZE,d0
		JSRLIB	CreateIORequest
		move.l	d0,serd_WriteIO(a2)
		beq	OSError

		move.l	serd_ControlPort(a2),a0
		moveq	#IOEXTSER_SIZE,d0
		JSRLIB	CreateIORequest
		move.l	d0,serd_ControlIO(a2)
		beq	OSError

		move.l	#SERDNameB,serd_DeviceName(a2)
		move.l	SERDUnitB,serd_DeviceUnit(a2)
		move.b	SERDBIsPar+1,serd_IsPar(a2)

; Exception vorbereiten
		move.l	MyTask,a0
		move.l	#SERDExcept,TC_EXCEPTCODE(a0)

		moveq	#0,d0
		move.b	SerialASig,d1
		bset	d1,d0
		move.b	SerialBSig,d1
		bset	d1,d0
		move.l	d0,ExceptionSet
		move.l	d0,d1
		JSRLIB	SetExcept

; Alles OK
		moveq	#0,d0
		rts

; Fehler
OSError		moveq	#-1,d0
		rts


**
** Beenden
**

CloseSerial	move.l	_ExecBase,a6
		moveq	#0,d0			;Exceptions abschalten
		move.l	ExceptionSet,d1
		JSRLIB	SetExcept

		lea	SerialVarsA,a2
		bsr	DoCloseSerial
		lea	SerialVarsB,a2
		;fällt durch

DoCloseSerial	tst.b	serd_IsOpen(a2)
		beq	6$
		move.l	serd_WriteIO(a2),a1
		JSRLIB	AbortIO
		move.l	serd_WriteIO(a2),a1
		JSRLIB	WaitIO
		move.l	serd_ReadIO(a2),a1
		JSRLIB	AbortIO
		move.l	serd_ReadIO(a2),a1
		JSRLIB	WaitIO
		move.l	serd_ReadIO(a2),a1	;Device schließen
		JSRLIB	CloseDevice

6$		move.l	serd_ControlIO(a2),d0
		beq	1$
		move.l	d0,a0
		JSRLIB	DeleteIORequest

1$		move.l	serd_WriteIO(a2),d0
		beq	2$
		move.l	d0,a0
		JSRLIB	DeleteIORequest

2$		move.l	serd_ReadIO(a2),d0
		beq	3$
		move.l	d0,a0
		JSRLIB	DeleteIORequest

3$		move.l	serd_ReplyPort(a2),d0
		beq	4$
		move.l	d0,a0
		JSRLIB	DeleteMsgPort

4$		move.l	serd_ControlPort(a2),d0
		beq	5$
		move.l	d0,a0
		JSRLIB	DeleteMsgPort
5$		rts


**
** Installation (muß relokatibel sein!)
**

; Adressen der Treiber-Header (nicht relativ, da dieser Teil verschoben wird!)
SERDEntry	move.l	#BOutHeader,-(sp)
		move.l	#BInHeader,-(sp)
		move.l	#AOutHeader,-(sp)
		move.l	#AInHeader,-(sp)

; Alle 4 Treiber installieren (stützt sich auf eine Menge
; undokumentierter Eigenschaften von DrvrInstall)
		moveq	#-6,d3		;Erste Treiber-Nummer
1$		move.w	d3,d0
		dc.w	$a53d		;DrvrInstallRsrvMem
		dc.w	$a029		;HLock
		move.l	(a0),a0		;Zeiger auf Treiber
		move.l	(sp)+,a1	;Zeiger auf Header
		move.l	a1,(a0)+
		move.w	(a1),(a0)+	;Flags kopieren
		move.w	#5,(a0)		;Versionsnummer
		subq.w	#1,d3		;Treiber-Nummer erniedrigen
		cmp.w	#-9,d3		;Alle 4 Treiber installiert?
		bge	1$		;Nein, weitermachen
		rts
SERDEnd


**
** Driver Header
**

; .AIn
AInHeader	dc.w	$4d00,0,0,0
		dc.w	AInOpen-AInHeader
		dc.w	AInPrime-AInHeader
		dc.w	AControl-AInHeader
		dc.w	AStatus-AInHeader
		dc.w	InClose-AInHeader
AInName		dc.b	4,".AIn",9
		EVEN

; .AOut
AOutHeader	dc.w	$4e00,0,0,0
		dc.w	AOutOpen-AOutHeader
		dc.w	AOutPrime-AOutHeader
		dc.w	AControl-AOutHeader
		dc.w	AStatus-AOutHeader
		dc.w	AOutClose-AOutHeader
AOutName	dc.b	5,".AOut",9
		EVEN

; .BIn
BInHeader	dc.w	$4d00,0,0,0
		dc.w	BInOpen-BInHeader
		dc.w	BInPrime-BInHeader
		dc.w	BControl-BInHeader
		dc.w	BStatus-BInHeader
		dc.w	InClose-BInHeader
BInName		dc.b	4,".BIn",9
		EVEN

; .BOut
BOutHeader	dc.w	$4e00,0,0,0
		dc.w	BOutOpen-BOutHeader
		dc.w	BOutPrime-BOutHeader
		dc.w	BControl-BOutHeader
		dc.w	BStatus-BOutHeader
		dc.w	BOutClose-BOutHeader
BOutName	dc.b	5,".BOut",9
		EVEN


*
* Open(AIn)
*

AInOpen		DPRINTF	"AInOpen"

		bsr	AllocPortA
		lea	SerialVarsA,a2
		bra	InOpen

*
* Open(BIn)
*

BInOpen		DPRINTF	"BInOpen"

		bsr	AllocPortB
		lea	SerialVarsB,a2
		bra	InOpen


**
** Open(In)-Routine
** a1: DCE
** a2: SerialVars
**

InOpen		move.b	#9,7(a1)	;Versionsnummer
		move.l	a1,serd_InDCE(a2)
		moveq	#0,d0
		rts


*
* Open(AOut)-Routine
* a1: DCE
*

AOutOpen	DPRINTF	"AOutOpen"

		bsr	AllocPortA
		movem.l	d4-d5,-(sp)
		lea	SerialVarsA,a2
		move.w	$1fc,d4		;SPPortA
		bra	OutOpen

*
* Open(BOut)-Routine
* a1: DCE
*

BOutOpen	DPRINTF	"BOutOpen"

		bsr	AllocPortB
		movem.l	d4-d5,-(sp)
		lea	SerialVarsB,a2
		move.w	$1fe,d4		;SPPortB


**
** Open(Out)-Routine
** a1: DCE
** a2: SerialVars
** d4: SerConfig
**

; QFlags setzen
OutOpen		clr.b	serd_IsOpen(a2)
		move.b	#9,7(a1)	;Versionsnummer
		move.l	a1,serd_OutDCE(a2)

; IORequests erzeugen
		move.l	a6,-(sp)
		move.l	_ExecBase,a6

; Gerät öffnen
		move.l	serd_DeviceName(a2),a0
		tst.b	(a0)			;Leerer Name: Fehler
		beq	SERDErrOpen

		move.l	serd_DeviceUnit(a2),d0
		move.l	serd_ReadIO(a2),a1
		tst.b	serd_IsPar(a2)
		bne	10$
		move.b	#SERF_SHARED|SERF_7WIRE,IO_SERFLAGS(a1)
		bra	11$
10$		move.b	#PARF_SHARED,IO_PARFLAGS(a1)
11$		moveq	#0,d1		;Flags
		EJSRLIB	OpenDevice
		move.l	serd_ReadIO(a2),a1
		tst.l	IO_DEVICE(a1)
		beq	SERDErrOpen
		st.b	serd_IsOpen(a2)

; IORequests kopieren
		move.l	serd_ReadIO(a2),a0
		move.l	serd_WriteIO(a2),a1
		move.l	serd_ControlIO(a2),a3
		moveq	#IOEXTSER_SIZE/2-1,d1
1$		move.w	(a0)+,d0
		move.w	d0,(a1)+
		move.w	d0,(a3)+
		dbra	d1,1$

; ControlPort zum ControlIO und Default-Werte setzen
		move.l	serd_ControlIO(a2),a0
		move.l	serd_ControlPort(a2),MN_REPLYPORT(a0)
		move.l	#$11130000,IO_CTLCHAR(a0)
		move.l	#64,IO_RBUFLEN(a0)
		move.l	#250000,IO_BRKTIME(a0)
		bclr	#SERB_7WIRE,IO_SERFLAGS(a0)

; Flags löschen
		clr.b	serd_EventMask(a2)
		clr.b	serd_ErrMask(a2)
		clr.b	serd_CumErrors(a2)
		clr.b	serd_ReadPending(a2)
		clr.b	serd_WritePending(a2)

		lea	serd_Configuration(a2),a0
		moveq	#(IO_STATUS-IO_CTLCHAR)/4-1,d0
3$		clr.l	(a0)+
		dbra	d0,3$

; Port konfigurieren
		move.l	(sp)+,a6
		tst.b	serd_IsPar(a2)
		bne	2$
		move.w	d4,d2
		bsr	SerConfig
2$
		movem.l	(sp)+,d4-d5
		moveq	#0,d0
		rts

; Fehlerbehandlung
SERDErrOpen	move.l	(sp)+,a6
		movem.l	(sp)+,d4-d5
		cmp.l	#SerialVarsA,a2
		bne	1$
		moveq	#8,d3
		bra	2$
1$		moveq	#0,d3
2$		bsr	FreePort
		moveq	#-23,d0		;OpenErr
		rts


**
** Close(In)-Routine
**

InClose		DPRINTF	"InClose"

		moveq	#0,d0
		rts


*
* Close(AOut)-Routine
*

AOutClose	DPRINTF	"AOutClose"

		lea	SerialVarsA,a2
		moveq	#8,d3
		bra	OutClose

*
* Close(BOut)-Routine
*

BOutClose	DPRINTF	"BOutClose"

		lea	SerialVarsB,a2
		moveq	#0,d3


**
** Close(Out)-Routine
** a1: DCE
** a2: SerialVars
** d3: Bitoffset in PortA/BUse
**

OutClose	tst.b	serd_IsOpen(a2)
		beq	1$
		clr.b	serd_IsOpen(a2)

		movem.l	a0-a1/a6,-(sp)
		move.l	_ExecBase,a6
		bsr	AbortWrite		;Abbrechen
		bsr	AbortRead
		move.l	serd_ReadIO(a2),a1	;Device schließen
		EJSRLIB	CloseDevice
		movem.l	(sp)+,a0-a1/a6
		bsr	FreePort
1$		moveq	#0,d0
		rts


*
* Status(A)
*

AStatus		lea	SerialVarsA,a2
		bra	SERDStatus

*
* Status(B)
*

BStatus		lea	SerialVarsB,a2


**
** Status()-Routine
** a0: ParamBlock
** a1: DCE
** a2: SerialVars
**

SERDStatus	movem.l	a0-a1,-(sp)
		tst.b	serd_IsOpen(a2)
		beq	IONotOpen

		lea	csCode(a0),a0
		move.w	(a0)+,d0

		DPRINTF	"SERDStatus Code %08lx",d0

		cmp.w	#$8000,d0
		beq	SERDStatus9

		tst.b	serd_IsPar(a2)
		bne	SERDStatusPar
		subq.w	#2,d0
		beq	SERDStatus2
		subq.w	#6,d0
		beq	SERDStatus8
		subq.w	#1,d0
		beq	SERDStatus9
		bra	IOStatusImpl	;Nicht implementierter Status-Code

; Status für parallele Geräte
SERDStatusPar	subq.w	#2,d0
		beq	SERDStatusP2
		subq.w	#6,d0
		beq	SERDStatusP8
		subq.w	#1,d0
		beq	SERDStatus9
		bra	IOStatusImpl	;Nicht implementierter Status-Code

; Status(2) - SerGetBuf parallel
SERDStatusP2	clr.l	(a0)		;Puffer leer
		bra	IOReturnOK

; Status(8) - SerStatus parallel
SERDStatusP8	DPRINTF	"SerStatus"

		move.b	serd_CumErrors(a2),(a0)+	;cumErrs
		clr.b	serd_CumErrors(a2)		;löschen

		clr.b	(a0)+				;xOffSent löschen

		move.b	serd_ReadPending(a2),(a0)+	;rdPend
		move.b	serd_WritePending(a2),(a0)+	;wrPend

		clr.w	(a0)+			;ctsHold/xOffHold löschen
		clr.b	(a0)+			;dsrHold löschen
		move.b	#42,(a0)		;modemStatus: DSR, CD, CTS
		bra	IOReturnOK

; Status(2) - SerGetBuf
SERDStatus2	clr.l	(a0)			;Vorgabe
		bsr	SERDQuery		;Device befragen
		tst.b	IO_ERROR(a1)		;Fehler?
		bne	IOReturnOK
		move.l	IO_ACTUAL(a1),(a0)	;Nein, Anzahl Bytes im Puffer holen
		bra	IOReturnOK

; Status(8) - SerStatus
SERDStatus8	DPRINTF	"SERDStatus Code 8"

		bsr	SERDQuery

		move.b	serd_CumErrors(a2),(a0)+ ;cumErrs
		clr.b	serd_CumErrors(a2)	;löschen

		moveq	#0,d0
		btst	#IOSTB_XOFFREAD,IO_STATUS(a1)
		beq	1$
		move.b	#$80,d0			;xOffWasSent setzen
1$		btst	#6,IO_STATUS+1(a1)	;RTS aktiv?
		beq	2$
		or.b	#$40,d0			;Nein, dtrNegated setzen
2$		move.b	d0,(a0)+		;xOffSent

		move.b	serd_ReadPending(a2),(a0)+	;rdPend
		move.b	serd_WritePending(a2),(a0)+	;wrPend

		btst	#4,IO_STATUS+1(a1)	;CTS aktiv?
		sne.b	(a0)+			;Nein, ctsHold setzen

		btst	#IOSTB_XOFFWRITE,IO_STATUS(a1)
		sne.b	(a0)+			;xOffHold setzen

		btst	#3,IO_STATUS+1(a1)	;DSR aktiv?
		sne.b	(a0)+			;Nein, dsrHold setzen

		moveq	#0,d0
		btst	#3,IO_STATUS+1(a1)	;DSR
		bne	3$
		or.b	#2,d0
3$		btst	#2,IO_STATUS+1(a1)	;RI
		beq	4$
		or.b	#4,d0
4$		btst	#5,IO_STATUS+1(a1)	;CD
		bne	5$
		or.b	#8,d0
5$		btst	#4,IO_STATUS+1(a1)	;CTS
		bne	6$
		or.b	#32,d0
6$		btst	#2,IO_STATUS(a1)	;Break
		beq	7$
		or.b	#128,d0
7$		move.b	d0,(a0)			;modemStatus

		bra	IOReturnOK

; Status(9) - Serial Driver Version
SERDStatus9	DPRINTF	"SERDStatus Code 9"
		move.b	#9,(a0)			;Second-generation SerialDMA driver
		bra	IOReturnOK

; Query-Befehl mit ControlIO ausführen (Rückgabe: ControlIO in a1)
SERDQuery	movem.l	a0/a6,-(sp)
		move.l	_ExecBase,a6
		move.l	serd_ControlIO(a2),a1
		move.w	#SDCMD_QUERY,IO_COMMAND(a1)
		EJSRLIB	DoIO
		move.l	serd_ControlIO(a2),a1
		movem.l	(sp)+,a0/a6
		rts


*
* Control(A)
*

AControl	lea	SerialVarsA,a2
		bra	SERDControl

*
* Control(B)
*

BControl	lea	SerialVarsB,a2


**
** Control()-Routine
** a0: ParamBlock
** a1: DCE
** a2: SerialVars
**

SERDControl	movem.l	a0-a1,-(sp)
		tst.b	serd_IsOpen(a2)
		beq	IONotOpen

		lea	csCode(a0),a0
		move.w	(a0)+,d0

		DPRINTF	"SERDControl Code %08lx",d0

		cmp.w	#115,d0		;115kbps Highspeed
		beq	Control115
		cmp.w	#230,d0		;230kbps Highspeed
		beq	Control230
		cmp.w	#'jf',d0	;serdSetPollWrite
		beq	IOReturnOK
		cmp.w	#'JF',d0	;serdSetHighSpeed
		beq	Control230

		subq.w	#1,d0
		beq	SERDControl1
		subq.w	#7,d0		;Kleiner als 8?
		bmi	IOControlImpl	;Ja, Fehler
		cmp.w	#20,d0		;Größer als 28?
		bhi	IOControlImpl	;Ja, Fehler
		tst.b	serd_IsPar(a2)	;Parallel?
		bne	SERDControlPar
		move.l	(ControlJmpTable,d0.w*4),a1 ;Nein
		jmp	(a1)

ControlJmpTable	dc.l	Control8
		dc.l	Control9
		dc.l	Control10
		dc.l	Control11
		dc.l	Control12
		dc.l	Control13
		dc.l	Control10
		dc.l	Control15
		dc.l	Control16
		dc.l	Control17
		dc.l	Control18
		dc.l	Control19
		dc.l	Control20
		dc.l	Control21
		dc.l	Control22
		dc.l	Control23
		dc.l	Control24
		dc.l	Control25
		dc.l	Control26
		dc.l	Control27
		dc.l	Control10

SERDControlPar	move.l	(ControlParTable,d0.w*4),a1
		jmp	(a1)

ControlParTable	dc.l	Control27
		dc.l	IOReturnOK
		dc.l	ParControl10
		dc.l	IOReturnOK
		dc.l	IOReturnOK
		dc.l	IOReturnOK
		dc.l	ParControl10
		dc.l	IOControlImpl
		dc.l	IOReturnOK
		dc.l	IOReturnOK
		dc.l	IOReturnOK
		dc.l	IOReturnOK
		dc.l	IOReturnOK
		dc.l	Control21
		dc.l	Control22
		dc.l	IOReturnOK
		dc.l	IOReturnOK
		dc.l	IOReturnOK
		dc.l	IOReturnOK
		dc.l	Control27
		dc.l	ParControl10

; Control(1) - KillIO
SERDControl1	move.l	a6,-(sp)
		move.l	_ExecBase,a6

		move.l	serd_ControlIO(a2),a1
		move.w	#CMD_CLEAR,IO_COMMAND(a1)
		EJSRLIB	DoIO
		DPRINTF	" cleared, error %d",d0

		bsr	AbortRead
		bsr	AbortWrite

		move.l	(sp)+,a6
		moveq	#0,d0
		movem.l	(sp)+,a0-a1
		rts

; Control(8) - SerConfig
Control8	move.w	(a0),d2
		DPRINTF	" serial config word %08lx",d2
		bsr	SerConfig
		bra	IOReturnOK

SerConfig	move.l	serd_ControlIO(a2),a1
		move.w	d2,d0
		and.w	#$3ff,d0		;Baudrate maskieren
		addq.w	#2,d0
		move.l	#115200,d1
		divu	d0,d1
		swap	d1			;Rest der Division löschen
		clr.w	d1
		swap	d1
		move.l	d1,IO_BAUD(a1)
		DPRINTF	" baud rate %ld",d1

		move.w	d2,d0
		bclr	#SERB_PARTY_ON,IO_SERFLAGS(a1)
		btst	#12,d0			;Parity on?
		beq	1$
		bset	#SERB_PARTY_ON,IO_SERFLAGS(a1)
		bset	#SERB_PARTY_ODD,IO_SERFLAGS(a1)
		btst	#13,d0			;Parity even?
		beq	1$
		bclr	#SERB_PARTY_ODD,IO_SERFLAGS(a1)

1$		moveq	#1,d0			;Vorgabe: 1 Stopbit
		btst	#15,d2			;1,5 oder 2 Stopbits?
		beq	2$
		moveq	#2,d0			;Ja, 2 Stopbits setzen
2$		move.b	d0,IO_STOPBITS(a1)

		move.w	d2,d0
		move.b	#5,IO_READLEN(a1)	;5 Datenbits setzen
		move.b	#5,IO_WRITELEN(a1)
		and.w	#$0c00,d0		;Datenbits maskieren
		beq	3$			;Ja, 5 Datenbits
		move.b	#6,IO_READLEN(a1)	;6 Datenbits setzen
		move.b	#6,IO_WRITELEN(a1)
		cmp.w	#$0800,d0
		beq	3$			;Ja, 6 Datenbits
		move.b	#7,IO_READLEN(a1)	;7 Datenbits setzen
		move.b	#7,IO_WRITELEN(a1)
		cmp.w	#$0400,d0
		beq	3$			;Ja, 7 Datenbits
		move.b	#8,IO_READLEN(a1)	;8 Datenbits setzen
		move.b	#8,IO_WRITELEN(a1)

3$		move.l	#250000,IO_BRKTIME(a1)
		bra	SERDSetParams
4$		rts

; Control(9) - SerSetBuf
Control9	moveq	#0,d0
		move.w	4(a0),d0		;BufferLength
		DPRINTF	" buffer size is now %08lx",d0
		cmp.w	#8192,d0		;Mindestens 8K
		bhs	1$
		move.w	#8192,d0
1$		and.l	#$ffffffc0,d0		;Vielfaches von 64
		move.l	serd_ControlIO(a2),a1
		move.l	d0,IO_RBUFLEN(a1)
		bsr	SERDSetParams
		bra	IOReturnOK

; Control(10/14/28) - SerHShake
Control10	DPRINTF	" SerShk record %08lx%08lx",(a0),4(a0)
		move.l	serd_ControlIO(a2),a1

		bclr	#SERB_7WIRE,IO_SERFLAGS(a1)	;Vorgaben
		bset	#SERB_XDISABLED,IO_SERFLAGS(a1)

		tst.b	(a0)+				;fXOn?
		beq	1$
		bclr	#SERB_XDISABLED,IO_SERFLAGS(a1)	;Ja, XON/XOFF

1$		tst.b	(a0)+				;fCTS?
		beq	2$
		DPRINTF	" 7 wire"
		bset	#SERB_7WIRE,IO_SERFLAGS(a1)	;Ja, 7-wire

2$		move.b	(a0)+,IO_CTLCHAR(a1)		;xOn character
		move.b	(a0)+,IO_CTLCHAR+1(a1)		;xOff character

		move.b	(a0)+,serd_ErrMask(a2)		;Errors that will terminate input
		move.b	(a0)+,serd_EventMask(a2)	;Events

		tst.b	(a0)+				;fInX?
		beq	3$
		bclr	#SERB_XDISABLED,IO_SERFLAGS(a1)	;Ja, XON/XOFF

3$		bsr	SERDSetParams
		bra	IOReturnOK

; Control(11) - SerClrBrk
Control11	bra	IOReturnOK		;Keine Aktion

; Control(12) - SerSetBrk
Control12	move.l	a6,-(sp)
		move.l	_ExecBase,a6
		move.l	serd_ControlIO(a2),a1
		move.w	#SDCMD_BREAK,IO_COMMAND(a1)
		EJSRLIB	DoIO
		DPRINTF	" break sent, error %d",d0
		move.l	(sp)+,a6
		bra	IOReturnOK

; Control(13) - Set Baud rate
Control13	move.l	serd_ControlIO(a2),a1
		moveq	#0,d0
		move.w	(a0),d0
		DPRINTF	" baud rate %ld",d0
		cmp.l	IO_BAUD(a1),d0		;Schon gesetzt?
		beq	1$
		move.l	d0,IO_BAUD(a1)
		bsr	SERDSetParams
1$		bra	IOReturnOK

; Control(115) - Set 115kbps mode
Control115	tst.b	serd_IsPar(a2)
		bne	IOReturnOK
		move.l	serd_ControlIO(a2),a1
		move.l	#115200,IO_BAUD(a1)
		bsr	SERDSetParams
		bra	IOReturnOK

; Control(230) - Set 230kbps mode
Control230	tst.b	serd_IsPar(a2)
		bne	IOReturnOK
		move.l	serd_ControlIO(a2),a1
		move.l	#230400,IO_BAUD(a1)
		bsr	SERDSetParams
		bra	IOReturnOK

; Control(15) - Set MIDI clocking
Control15	move.l	serd_ControlIO(a2),a1
		move.l	#31250,IO_BAUD(a1)
		bset	#SERB_XDISABLED,IO_SERFLAGS(a1)
		bclr	#SERB_PARTY_ON,IO_SERFLAGS(a1)
		bclr	#SERB_7WIRE,IO_SERFLAGS(a1)
		bclr	#SERB_RAD_BOOGIE,IO_SERFLAGS(a1)
		move.b	#1,IO_STOPBITS(a1)
		move.b	#8,IO_READLEN(a1)
		move.b	#8,IO_WRITELEN(a1)
		bsr	SERDSetParams
		bra	IOReturnOK

; Control(16) - Set miscellaneous options
Control16	bra	IOReturnOK

; Control(17) - Assert DTR
Control17	bra	IOReturnOK

; Control(18) - Negate DTR
Control18
	;	tst.b	serd_ReadPending(a2)	;Es darf kein Request ausstehen
	;	bne	IOReturnOK
	;	tst.b	serd_WritePending(a2)
	;	bne	IOReturnOK

	;;Device schließen und wieder öffnen
	;!!	move.l	a6,-(sp)
	;	move.l	_ExecBase,a6
	;	move.l	serd_ReadIO(a2),a1
	;	EJSRLIB	CloseDevice

	;	move.l	_DOSBase,a6
	;	moveq	#60,d1
	;	EJSRLIB	Delay

	;	move.l	_ExecBase,a6
	;	move.l	serd_DeviceName(a2),a0
	;	move.l	serd_DeviceUnit(a2),d0
	;	move.l	serd_ReadIO(a2),a1
	;	moveq	#0,d1		;Flags
	;	EJSRLIB	OpenDevice
	;	move.l	(sp)+,a6

	;	bsr	SERDSetParams	;Alte Einstellungen wiederherstellen
		bra	IOReturnOK

; Control(19) - Set replacement char for Parity Errors
Control19	bra	IOReturnOK

; Control(20) - Set alternative replacement char for Parity Errors
Control20	bra	IOReturnOK

; Control(21) - Set XOff state
Control21	bra	Control26

; Control(22) - Set XOn state
Control22	bra	Control24

; Control(23) - Send XOn conditional
Control23	bsr	SERDQuery
		btst	#IOSTB_XOFFREAD,IO_STATUS(a1)
		beq	IOReturnOK	;fällt durch!

; Control(24) - Send XOn unconditional
Control24	move.l	a6,-(sp)
		move.l	_ExecBase,a6
		move.l	serd_ControlIO(a2),a1
		move.w	#CMD_START,IO_COMMAND(a1)
		EJSRLIB	DoIO
		DPRINTF	" started, error %d",d0
		move.l	(sp)+,a6
		bra	IOReturnOK

; Control(25) - Send XOff conditional
Control25	bsr	SERDQuery
		btst	#IOSTB_XOFFREAD,IO_STATUS(a1)
		bne	IOReturnOK	;fällt durch!

; Control(26) - Send XOff unconditional
Control26	move.l	a6,-(sp)
		move.l	_ExecBase,a6
		move.l	serd_ControlIO(a2),a1
		move.w	#CMD_STOP,IO_COMMAND(a1)
		EJSRLIB	DoIO
		DPRINTF	" stopped, error %d",d0
		move.l	(sp)+,a6
		bra	IOReturnOK

; Control(27) - Reset SCC channel
Control27	move.l	a6,-(sp)
		move.l	_ExecBase,a6
		move.l	serd_ControlIO(a2),a1
		move.w	#CMD_RESET,IO_COMMAND(a1)
		EJSRLIB	DoIO
		DPRINTF	" reset, error %d",d0
		move.l	(sp)+,a6
		bra	IOReturnOK

; SetParams-Befehl mit ControlIO ausführen
SERDSetParams	move.l	serd_ControlIO(a2),a1
		bclr	#SERB_RAD_BOOGIE,IO_SERFLAGS(a1)
		btst	#SERB_PARTY_ON,IO_SERFLAGS(a1)
		bne	1$
		btst	#SERB_XDISABLED,IO_SERFLAGS(a1)
		beq	1$
		cmp.b	#8,IO_READLEN(a1)
		bne	1$
		bset	#SERB_RAD_BOOGIE,IO_SERFLAGS(a1)
1$
		lea	serd_Configuration(a2),a0	;Bereits so konfiguriert?
		lea	IO_CTLCHAR(a1),a1
		moveq	#(IO_STATUS-IO_CTLCHAR)/4-1,d0
3$		cmp.l	(a0)+,(a1)+
		dbne	d0,3$
		beq	4$

		move.l	a6,-(sp)
		move.l	_ExecBase,a6

		bsr	AbortRead
		bsr	AbortWrite

		move.l	serd_ControlIO(a2),a1
		DPRINTF	" params: %08lx %08lx %08lx %08lx %08lx %08lx",IO_CTLCHAR(a1),IO_RBUFLEN(a1),IO_EXTFLAGS(a1),IO_BAUD(a1),IO_BRKTIME(a1),IO_READLEN(a1)
		move.w	#SDCMD_SETPARAMS,IO_COMMAND(a1)
		EJSRLIB	DoIO
		DPRINTF	" params set, error %d",d0

		movem.l	a2-a3,-(sp)
		lea	serd_Configuration(a2),a3
		move.l	serd_ControlIO(a2),a0
		move.l	serd_ReadIO(a2),a1
		move.l	serd_WriteIO(a2),a2
		lea	IO_CTLCHAR(a0),a0
		lea	IO_CTLCHAR(a1),a1
		lea	IO_CTLCHAR(a2),a2
		moveq	#(IO_STATUS-IO_CTLCHAR)/4-1,d1
2$		move.l	(a0),(a1)+
		move.l	(a0),(a2)+
		move.l	(a0)+,(a3)+
		dbra	d1,2$
		movem.l	(sp)+,a2-a3

		move.l	(sp)+,a6
4$		rts

; ParControl(10) - SerHShake
ParControl10	move.l	serd_ControlIO(a2),a1

		tst.b	1(a0)				;fCTS?
		beq	1$
		bset	#PARB_ACKMODE,IO_PARFLAGS(a1)	;Ja
		bra	2$
1$		bclr	#PARB_ACKMODE,IO_PARFLAGS(a1)	;Nein

2$		move.b	5(a0),serd_EventMask(a2)	;evts

		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		move.l	serd_ControlIO(a2),a1
		move.w	#PDCMD_SETPARAMS,IO_COMMAND(a1)
		EJSRLIB	DoIO
		move.l	(sp)+,a6
		bra	IOReturnOK


*
* Prime(AOut)
*

AOutPrime	lea	SerialVarsA,a2
		bra	OutPrime

*
* Prime(BOut)
*

BOutPrime	lea	SerialVarsB,a2


**
** Prime(Out)-Routine
** a0: ParamBlock
** a1: DCE
** a2: SerialVars
**

OutPrime	movem.l	a0-a1,-(sp)
		tst.b	serd_IsOpen(a2)
		beq	IONotOpen

		DPRINTF	"OutPrime"

1$		tst.b	serd_WritePending(a2)	;Auf Beendigung warten
		bne	1$

		DPRINTF	" sending"

	IFNE	DEBUG_DETAIL
		bsr	OutPrimeDebug
	ENDC

		st.b	serd_WritePending(a2)

		move.l	serd_WriteIO(a2),a1
		move.l	a0,serd_WriteIOParam(a2)
		move.l	ioBuffer(a0),IO_DATA(a1)
		move.l	ioReqCount(a0),IO_LENGTH(a1)
		clr.l	IO_ACTUAL(a1)
		move.w	#CMD_WRITE,IO_COMMAND(a1)

		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		EJSRLIB	SendIO
		move.l	(sp)+,a6

		movem.l	(sp)+,a0-a1
		moveq	#0,d0
		rts

	IFNE	DEBUG_DETAIL
OutPrimeDebug	move.l	ioBuffer(a0),a1
		move.l	ioReqCount(a0),d1
		subq.l	#1,d1
1$		moveq	#0,d0
		move.b	(a1)+,d0
		DPRINTF	"%02lx",d0
		dbra	d1,1$
		rts
	ENDC

*
* Prime(AIn)
*

AInPrime	lea	SerialVarsA,a2
		bra	InPrime

*
* Prime(BIn)
*

BInPrime	lea	SerialVarsB,a2


**
** Prime(In)-Routine
** a0: ParamBlock
** a1: DCE
** a2: SerialVars
**

InPrime		movem.l	a0-a1,-(sp)
		tst.b	serd_IsOpen(a2)
		beq	IONotOpen

		DPRINTF	"InPrime ReqCount %08lx",ioReqCount(a0)

1$		tst.b	serd_ReadPending(a2)	;Auf Beendigung warten
		bne	1$

		DPRINTF	" receiving"

		st.b	serd_ReadPending(a2)

		move.l	serd_ReadIO(a2),a1
		move.l	a0,serd_ReadIOParam(a2)
		move.l	ioBuffer(a0),IO_DATA(a1)
		move.l	ioReqCount(a0),IO_LENGTH(a1)
		clr.l	IO_ACTUAL(a1)
		move.w	#CMD_READ,IO_COMMAND(a1)

		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		EJSRLIB	SendIO
		move.l	(sp)+,a6

		movem.l	(sp)+,a0-a1
		moveq	#0,d0
		rts


**
** Amiga-Fehlercode in Mac-Fehlercode umwandeln, Request in a1
** Ergibt OSErr in d0 und CumError in d1
**

ConvError	;DPRINTF	"ConvError %08lx",IO_ERROR(a1)

		tst.b	IO_ERROR(a1)
		beq	CENoError
		cmp.b	#IOERR_NOCMD,IO_ERROR(a1)
		beq	CENoError
		cmp.b	#IOERR_ABORTED,IO_ERROR(a1)
		beq	CEAborted

		tst.b	serd_IsPar(a2)
		bne	CEFraming

		cmp.b	#SerErr_DetectedBreak,IO_ERROR(a1)
		beq	CEBreak
		cmp.b	#SerErr_ParityErr,IO_ERROR(a1)
		beq	CEParity
		cmp.b	#SerErr_BufOverflow,IO_ERROR(a1)
		beq	CESWOverrun
		cmp.b	#SerErr_LineErr,IO_ERROR(a1)
		beq	CEHWOverrun

CEFraming	moveq	#$40,d1		;Sonst Framing Error
		bra	CECalcOSErr

CEHWOverrun	moveq	#$20,d1		;CumError: HW Overrun
		DPRINTF	"HW overrun error"
		bra	CECalcOSErr

CEParity	moveq	#$10,d1		;CumError: Parity
		DPRINTF	"Parity error"
		bra	CECalcOSErr

CESWOverrun	moveq	#$01,d1		;CumError: SW Overrun
		DPRINTF	"SW overrun error"
		bra	CECalcOSErr

CEAborted	moveq	#-27,d0		;OSErr: abortErr
		moveq	#0,d1
		rts

CEBreak		moveq	#-90,d0		;OSErr: breakRecd
		moveq	#8,d1		;CumError: Break
		rts

CENoError	moveq	#0,d0
		moveq	#0,d1
		rts

CECalcOSErr	move.b	d1,d0
		and.b	serd_ErrMask(a2),d0
		beq	1$
		moveq	#-89,d0		;rcvrErr
		rts
1$		moveq	#0,d0
		rts


**
** Port A belegen, Fehler wenn nicht möglich
**

AllocPortA	moveq	#4,d1
		moveq	#8,d2
		bra	AllocPort

**
** Port B belegen, Fehler wenn nicht möglich
**

AllocPortB	move.l	$b18,a0		;LAPMgrPtr
		move.l	a0,d0
		ble	1$
		move.w	#19,d0		;LStatPortB
		jsr	2(a0)		;LAP Manager aufrufen
		tst.w	d0
		bne	1$
		cmp.b	#2,d1
		beq	2$
		move.w	#17,d0		;LUsePortB
		move.b	#2,d1
		jsr	2(a0)		;LAP Manager aufrufen
		tst.w	d0
		beq	2$
		addq.w	#4,sp
2$		rts

1$		moveq	#0,d1
		moveq	#0,d2

*
* Port belegen, Fehler wenn nicht möglich
*

AllocPort	move.b	$1fb,d0		;SPConfig
		lsr.b	d1,d0
		andi.b	#$f,d0		;Port frei?
		beq	PortIsFree
		subq.b	#2,d0		;Nein, vom seriellen Treiber benutzt?
		beq	PortIsFree
		moveq	#-98,d0		;Nein, Port ist von AppleTalk belegt
		addq.w	#4,sp
		rts

; Port ist frei
PortIsFree	move.w	$290,d0		;PortA/BUse
		ror.w	d2,d0
		bclr	#7,d0		;Port wird benutzt
		bne	GetThePort	;War vorher belegt?
		eor.b	#2,d0		;Ja, vom seriellen Treiber belegt?
		beq	1$
		moveq	#-99,d0		;Nein, Fehler
		addq.w	#4,sp
1$		rts

; Port ist frei, als belegt markieren
GetThePort	move.b	#2,d0		;Port als belegt markieren
		ror.w	d2,d0
		move.w	d0,$290
		rts


**
** Port freigeben
** d3: Bitoffset in PortA/BUse
**

FreePort	tst.w	d3
		bne	FreeThePort

; Port B: AppleTalk
		move.l	$b18,d0		;LAPMgrPtr
		ble	FreeThePort
		move.l	a0,-(sp)
		move.l	d0,a0
		move.w	#18,d0		;LFreePortB
		move.b	#2,d1
		jsr	2(a0)		;LAP Manager aufrufen
		move.l	(sp)+,a0
		tst.w	d0
		beq	FreePortDidnt

; Port als frei markieren
FreeThePort	move.w	$290,d0		;PortA/BUse
		ror.w	d3,d0
		st.b	d0		;Port free
		ror.w	d3,d0
		move.w	d0,$290		;PortA/BUse
FreePortDidnt	rts


**
** Rückkehr aus Treiberroutine
**

IONotOpen	moveq	#-28,d0		;Driver not open
		bra	IOReturn
IOControlImpl	moveq	#-17,d0		;Unimplemented control
		bra	IOReturn
IOStatusImpl	moveq	#-18,d0		;Unimplemented status
		bra	IOReturn

IOReturnOK	moveq	#0,d0		;Alles OK

IOReturn	movem.l	(sp)+,a0-a1	;ParamBlock und DCE wiederherstellen

		btst	#noQueueBit-8,ioTrap(a0) ;Immediale calls mit RTS beenden
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


**
** ReadIO abbrechen
**

AbortRead	DPRINTF	"AbortRead"

		tst.b	serd_ReadPending(a2)
		beq	1$
		move.l	serd_ReadIO(a2),a1
		EJSRLIB	AbortIO

		DPRINTF	" aborted"

		move	sr,-(sp)
		move.w	#$2000,sr
2$		tst.b	serd_ReadPending(a2)	;Auf Beendigung warten
		bne	2$
		move	(sp)+,sr
1$		rts


**
** WriteIO abbrechen
**

AbortWrite	DPRINTF	"AbortWrite"

		tst.b	serd_WritePending(a2)
		beq	1$
		move.l	serd_WriteIO(a2),a1
		EJSRLIB	AbortIO

		DPRINTF	" aborted"

		move	sr,-(sp)
		move.w	#$2000,sr
2$		tst.b	serd_WritePending(a2)		;Auf Beendigung warten
		bne	2$
		move	(sp)+,sr
1$		rts


**
** Transfer beendet
**

SERDExcept	tst.w	MacRunning
		beq	1$

		DPRINTF	"SERDExcept"

		move.b	NetworkSig,d1		;Netzwerk?
		btst	d1,d0
		beq	3$
		move.l	d0,-(sp)
		bsr	NetworkExcept		;Ja
		move.l	(sp)+,d0
3$		move.b	SerialASig,d1
		btst	d1,d0			;Modemport?
		beq	2$
		move.l	d0,-(sp)
		bsr	SERDExceptA		;Ja
		move.l	(sp)+,d0
2$		move.b	SerialBSig,d1		;Druckerport?
		btst	d1,d0
		beq	1$
		move.l	d0,-(sp)
		bsr	SERDExceptB		;Ja
		move.l	(sp)+,d0
1$		rts

SERDExceptA	lea	SerialVarsA,a2
		bra	SERDExceptChk

SERDExceptB	lea	SerialVarsB,a2
SERDExceptChk	move.l	serd_ReplyPort(a2),a0
		move.l	MP_MSGLIST+LH_HEAD(a0),d0
		cmp.l	serd_WriteIO(a2),d0	;WriteIO?
		beq	SERDExcWrite
		cmp.l	serd_ReadIO(a2),d0
		beq	SERDExcRead
		rts

SERDExcWrite	move.l	serd_WriteIO(a2),a1
		JSRLIB	WaitIO
		clr.b	serd_WritePending(a2)
		move.l	serd_WriteIO(a2),a1
		move.l	serd_WriteIOParam(a2),a0
		move.l	IO_ACTUAL(a1),ioActCount(a0)
		bsr	ConvError
		move.l	serd_OutDCE(a2),a1
		bra	SERDExcDone

SERDExcRead	move.l	serd_ReadIO(a2),a1
		JSRLIB	WaitIO
		clr.b	serd_ReadPending(a2)
		move.l	serd_ReadIO(a2),a1
		move.l	serd_ReadIOParam(a2),a0
		move.l	IO_ACTUAL(a1),ioActCount(a0)
	IFNE	DEBUG_DETAIL
		bsr	InPrimeDebug
	ENDC
		bsr	ConvError
		move.l	serd_InDCE(a2),a1

SERDExcDone	or.b	d1,serd_CumErrors(a2)	;CumError kumulieren

		DPRINTF	" error %08lx",d0

		cmp.w	#-27,d0			;Abgebrochen?
		beq	1$

		lea	SERDJumpIODone,a5	;Nein, IODone aufrufen
		JSRLIB	Supervisor

		DPRINTF	" IODone called"

1$		bra	SERDExceptChk

SERDJumpIODone	move.l	JIODone,a0		;Hier keine Interrupts sperren (trotz Technote 1018),
		jsr	(a0)			; sonst geht FreePPP nicht mehr
		rte

	IFNE	DEBUG_DETAIL
InPrimeDebug	move.l	a1,-(sp)
		move.l	ioBuffer(a0),a1
		move.l	ioActCount(a0),d1
		subq.l	#1,d1
1$		moveq	#0,d0
		move.b	(a1)+,d0
		DPRINTF	"%02lx",d0
		dbra	d1,1$
		move.l	(sp)+,a1
		rts
	ENDC

**
** Nicht initialisierte Daten
**

		SECTION	"BSS",BSS
SerialVarsA	ds.b	serd_SIZEOF	;Variablen für Modemport (Serial 1)
SerialVarsB	ds.b	serd_SIZEOF	;Variablen für Druckerport (Serial 2)

ExceptionSet	ds.l	1		;Maske der Exception-Signale
SerialASig	ds.b	1		;Signal für Port A
SerialBSig	ds.b	1		;Signal für Port B

		END
