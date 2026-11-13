**
** Macintosh IIci-Emulator - Amiga Netzwerk Treiber
** ================================================
**
** © Copyright 1994-2001 Christian Bauer
**

DEBUG_DETAIL	SET 0

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/lists.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"exec/io.i"
		INCLUDE	"dos/dos.i"
		INCLUDE	"dos/dostags.i"
		INCLUDE	"devices/sana2.i"
		INCLUDE	"macros.i"
		INCLUDE	"macinclude.i"

		XREF	SubtaskSet		;MacEmul.asm

		XDEF	OpenNetwork
		XDEF	CloseNetwork
		XDEF	CleanupNetwork
		XDEF	EtherOpen
		XDEF	EtherPrime
		XDEF	EtherControl
		XDEF	EtherStatus
		XDEF	EtherClose

		XDEF	NetworkSig
		XDEF	NetworkExcept

		SECTION	"CODE",CODE


*
* Definitionen
*

NUM_REQUESTS	= 30	;Anzahl ReadIOs, die vorab an das Device geschickt werden

HTYPE_ETHER	= 0	;Ethernet
HTYPE_PLIP	= 1	;PLIP
HTYPE_SLIP	= 2	;SLIP
HTYPE_AMOK	= 3	;AmokNet

 STRUCTURE Protocol,0
	STRUCT	prot_Node,MLN_SIZE	;Zum Verketten
	WORD	prot_Type		;Protokoll-Typ
	WORD	prot_pad0
	APTR	prot_Handler		;Protocol Handler
	STRUCT	prot_ReadIOs,IOS2_SIZE*NUM_REQUESTS
 LABEL	SIZEOF_Protocol


*
* Initialisierung
*

OpenNetwork	tst.b	Sana2Name	;Leerer Name? Dann alles überspringen
		beq	ONDone

; Protokoll-Liste initialisieren
		lea	ProtList,a0
		NEWLIST	a0

; Signale einrichten
		move.l	_ExecBase,a6
		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,NTReadySig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,NTReadySet

		moveq	#-1,d0		;Signal für Exception
		JSRLIB	AllocSignal
		move.b	d0,NetworkSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,NetworkSet
		move.l	d1,d0
		JSRLIB	SetExcept

; Task starten
		move.l	_DOSBase,a6
		move.l	#ProcTags,d1
		JSRLIB	CreateNewProc
		move.l	d0,NetTaskProc
		beq	ONDone

; Auf Signal warten
		move.l	_ExecBase,a6
		move.l	SubtaskSet,d0
		JSRLIB	Wait
ONDone		rts


*
* Beenden
*

CloseNetwork	tst.b	Sana2Name
		beq	CNDone

; Task stoppen
		move.l	_ExecBase,a6
		move.l	NetworkTask,d0
		beq	1$
		move.l	d0,a1
		move.l	NetQuitSet,d0
		JSRLIB	Signal
		move.l	SubtaskSet,d0
		JSRLIB	Wait

; Signale freigeben
1$		moveq	#0,d0
		move.l	NetworkSet,d1
		JSRLIB	SetExcept
		move.b	NetworkSig,d0
		JSRLIB	FreeSignal

		move.b	NTReadySig,d0
		JSRLIB	FreeSignal
CNDone		rts


*
* Alle Protokolle entfernen (wird beim Reset aufgerufen)
*

CleanupNetwork	tst.b	NetIsOpen
		beq	1$
		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		move.l	NetworkTask,a1
		move.l	NetCleanupSet,d0
		JSRLIB	Signal
		move.l	(sp)+,a6
1$		rts


*
* Open()-Routine
*

EtherOpen	DPRINTF	"EtherOpen"
		move.l	a1,NetDCE
		moveq	#0,d0
		rts


*
* Prime()/Status()-Routine
*

EtherPrime
EtherStatus	moveq	#-17,d0
		rts


*
* Close()-Routine
*

EtherClose	DPRINTF	"EtherClose"
		moveq	#-24,d0
		rts


*
* Control()-Routine
*

EtherControl	movem.l	a0-a1,-(sp)
		tst.b	NetIsOpen
		beq	IOReturnOK

		move.w	csCode(a0),d2
		subq.w	#1,d2			;KillIO?
		beq	Control1
		sub.w	#244,d2
		blt	IOControlImpl
		cmp.w	#8,d2
		bgt	IOControlImpl

		move.l	a0,a3			;a3: EParamBlock
		move.l	(CtrlJmp,d2.w*4),a2
		jmp	(a2)

CtrlJmp		dc.l	DelMulti		;245
		dc.l	AddMulti		;246
		dc.l	AttachPH		;247
		dc.l	DetachPH		;248
		dc.l	EtherWrite		;249
		dc.l	EtherRead		;250
		dc.l	RdCancel		;251
		dc.l	GetInfo			;252
		dc.l	SetGeneral		;253

; Control(1) - KillIO
Control1	movem.l	(sp)+,a0-a1
		moveq	#-1,d0
		rts

; Control(245) - DelMulti
DelMulti	DPRINTF	"DelMulti %08lx%08lx",csParam(a3),csParam+4(a3)
		move.l	a3,NetParmBlock

		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		move.l	NetworkTask,a1
		move.l	NetDelMultiSet,d0
		JSRLIB	Signal
		move.l	NTReadySet,d0
		EJSRLIB	Wait
		move.l	(sp)+,a6

		move.w	NetError,d0
		bra	IOReturn

; Control(246) - AddMulti
AddMulti	DPRINTF	"AddMulti %08lx%08lx",csParam(a0),csParam+4(a0)
		move.l	a3,NetParmBlock

		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		move.l	NetworkTask,a1
		move.l	NetAddMultiSet,d0
		JSRLIB	Signal
		move.l	NTReadySet,d0
		EJSRLIB	Wait
		move.l	(sp)+,a6

		move.w	NetError,d0
		bra	IOReturn

; Control(247) - AttachPH
AttachPH	DPRINTF	"AttachPH %08lx",csParam(a3)
		move.l	a3,NetParmBlock

		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		move.l	NetworkTask,a1
		move.l	NetAttachPHSet,d0
		JSRLIB	Signal
		move.l	NTReadySet,d0
		EJSRLIB	Wait
		move.l	(sp)+,a6

		move.w	NetError,d0
		bra	IOReturn

; Control(248) - DetachPH
DetachPH	DPRINTF	"DetachPH %08lx",csParam(a3)
		move.l	a3,NetParmBlock

		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		move.l	NetworkTask,a1
		move.l	NetDetachPHSet,d0
		JSRLIB	Signal
		move.l	NTReadySet,d0
		EJSRLIB	Wait
		move.l	(sp)+,a6

		move.w	NetError,d0
		bra	IOReturn

; Control(249) - Write
EtherWrite	DPRINTF	"EtherWrite"
		move.l	csParam+2(a3),a2	;ePointer: Zeiger auf WDS
		cmp.w	#14,(a2)		;Mindestens 14 Byte?
		blo	ELenErr

		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		move.l	a2,NetWDS
		move.l	NetworkTask,a1
		move.l	NetWriteSet,d0
		JSRLIB	Signal
		move.l	(sp)+,a6

		movem.l	(sp)+,a0-a1
		moveq	#0,d0
		rts

; Control(250) - Read
EtherRead	DPRINTF	"EtherRead"
		move.l	a6,-(sp)
		move.l	_IntuitionBase,a6
		sub.l	a0,a0
		lea	NoEtherReadReq,a1
		sub.l	a2,a2
		sub.l	a3,a3
		EJSRLIB	EasyRequestArgs
		move.l	(sp)+,a6
		bra	IOControlImpl

; Control(251) - RdCancel
RdCancel	DPRINTF	"ERdCancel"
		bra	IOControlImpl

; Control(252) - GetInfo
GetInfo		DPRINTF	"GetInfo"
		move.l	a3,NetParmBlock

		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		move.l	NetworkTask,a1
		move.l	NetGetInfoSet,d0
		JSRLIB	Signal
		move.l	NTReadySet,d0
		EJSRLIB	Wait
		move.l	(sp)+,a6
		bra	IOReturnOK

; Control(253) - SetGeneral
SetGeneral	bra	IOReturnOK


*
* Rückkehr aus Treiberroutine
*

IOControlImpl	moveq	#-17,d0
		bra	IOReturn
ELenErr		moveq	#-92,d0
		bra	IOReturn
EHardwareErr	moveq	#-95,d0
		bra	IOReturn

IOReturnOK	moveq	#0,d0		;Alles OK

IOReturn	movem.l	(sp)+,a0-a1

		btst	#noQueueBit-8,ioTrap(a0) ;Immediate call mit RTS beenden
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
IODone		jmp	([JIODone])


**
** Subtask für Netzwerk-Handling
**

; Task ermitteln
NetTaskMain	move.l	_ExecBase,a6
		sub.l	a1,a1
		JSRLIB	FindTask
		move.l	d0,NetworkTask

; Signale zur Kommunikation anfordern
		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,NetAddMultiSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,NetAddMultiSet

		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,NetDelMultiSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,NetDelMultiSet

		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,NetGetInfoSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,NetGetInfoSet

		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,NetWriteSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,NetWriteSet

		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,NetAttachPHSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,NetAttachPHSet

		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,NetDetachPHSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,NetDetachPHSet

		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,NetCleanupSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,NetCleanupSet

		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,NetQuitSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,NetQuitSet

; ControlPort/ControlIO einrichten
		JSRLIB	CreateMsgPort
		move.l	d0,ControlPort
		beq	NTSigEmul

		move.l	ControlPort,a0
		moveq	#IOS2_SIZE,d0
		JSRLIB	CreateIORequest
		move.l	d0,ControlIO
		beq	NTSigEmul

; Netzwerk-Treiber öffnen
		lea	Sana2Name,a0
		move.l	Sana2Unit,d0
		move.l	ControlIO,a1
		move.l	#BufferTags,IOS2_BUFFERMANAGEMENT(a1)
		moveq	#0,d1
		JSRLIB	OpenDevice
		tst.l	d0
		bne	NTCloseDev

; Ist es Ethernet?
		move.l	ControlIO,a1
		move.w	#S2_DEVICEQUERY,IO_COMMAND(a1)
		lea	QueryData,a0
		move.l	#S2DQ_SIZE,S2DQ_SIZEAVAILABLE(a0)
		move.l	a0,IOS2_STATDATA(a1)
		JSRLIB	DoIO
		tst.l	d0
		bne	NTCloseDev

		DPRINTF	"Addr %08lx",QueryData+S2DQ_ADDRFIELDSIZE

		cmp.l	#S2WIRETYPE_ETHERNET,QueryData+S2DQ_HARDWARETYPE
		beq	NTIsEther
		cmp.l	#S2WIRETYPE_PLIP,QueryData+S2DQ_HARDWARETYPE
		beq	NTIsPLIP
	;!!	cmp.l	#S2WIRETYPE_SLIP,QueryData+S2DQ_HARDWARETYPE
	;	beq	NTIsSLIP
		cmp.l	#S2WIRETYPE_AMOKNET,QueryData+S2DQ_HARDWARETYPE
		beq	NTIsAmok
		bra	NTNotEther

NTIsEther	move.w	#HTYPE_ETHER,HardwareType
		move.b	#SANA2IOF_RAW,IOFlags
		bra	NTIsDone

NTIsPLIP	move.w	#HTYPE_PLIP,HardwareType
		clr.b	IOFlags

		move.l	#$80000000,OtherPLIPAddr ;Es wird nur zwischen Unit 0 und 1 unterschieden
		tst.l	Sana2Unit
		beq	1$
		clr.l	OtherPLIPAddr
1$		bra	NTIsDone

NTIsSLIP	move.w	#HTYPE_SLIP,HardwareType
		clr.b	IOFlags

		move.l	#$80000000,OtherPLIPAddr ;Es wird nur zwischen Unit 0 und 1 unterschieden
		tst.l	Sana2Unit		;Die slip.devices müssen auf IP 0.0.0.0 und 128.0.0.0 konfiguriert sein
		beq	1$
		clr.l	OtherPLIPAddr
1$		bra	NTIsDone

NTIsAmok	move.w	#HTYPE_AMOK,HardwareType
		clr.b	IOFlags
NTIsDone

; WritePort/WriteIO einrichten
		JSRLIB	CreateMsgPort
		move.l	d0,WritePort
		beq	NTSigEmul

		move.l	d0,a0			;Signal des Ports holen
		move.b	MP_SIGBIT(a0),d0
		move.b	d0,WritePortSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,WritePortSet

		move.l	WritePort,a0
		moveq	#IOS2_SIZE,d0
		JSRLIB	CreateIORequest
		move.l	d0,WriteIO
		beq	NTSigEmul

		move.l	ControlIO,a0		;ControlIO kopieren
		move.l	WriteIO,a1
		moveq	#IOS2_SIZE,d0
		JSRLIB	CopyMem

		move.l	WriteIO,a0		;WritePort zum WriteIO
		move.l	WritePort,MN_REPLYPORT(a0)

; ReadPort erzeugen
		JSRLIB	CreateMsgPort
		move.l	d0,ReadPort
		beq	NTSigEmul

		move.l	d0,a0			;Signal des Ports holen
		move.b	MP_SIGBIT(a0),d0
		move.b	d0,ReadPortSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,ReadPortSet

; Ethernet konfigurieren
		move.l	ControlIO,a1
		move.w	#S2_GETSTATIONADDRESS,IO_COMMAND(a1)
		JSRLIB	DoIO

		move.l	ControlIO,a1
		move.l	IOS2_DSTADDR(a1),IOS2_SRCADDR(a1)
		move.w	IOS2_DSTADDR+4(a1),IOS2_SRCADDR+4(a1)
		move.w	#S2_CONFIGINTERFACE,IO_COMMAND(a1)
		JSRLIB	DoIO

		cmp.w	#HTYPE_ETHER,HardwareType
		beq	1$
		cmp.w	#HTYPE_AMOK,HardwareType
		beq	2$

		move.l	Sana2Unit,d0
		or.l	#$08535300,d0
		move.l	d0,MyEtherAddr	;PLIP/SLIP: Pseudo-Ethernet-Adresse
		move.w	#'SS',MyEtherAddr+4
		bra	3$

1$		move.l	ControlIO,a1	;Ethernet
		move.l	IOS2_SRCADDR(a1),MyEtherAddr
		move.w	IOS2_SRCADDR+4(a1),MyEtherAddr+4
		bra	3$

2$		move.l	ControlIO,a1	;AmokNet: Pseudo-Ethernet-Adresse
		move.l	#$08535353,MyEtherAddr
		move.w	IOS2_SRCADDR(a1),MyEtherAddr+4

3$		DPRINTF	"My Address: %08lx%08lx",MyEtherAddr,MyEtherAddr+4

		st.b	NetIsOpen
		bra	NTSigEmul

; Fehler aufgetreten, Device schließen
NTNotEther	move.l	_IntuitionBase,a6
		sub.l	a0,a0
		lea	NoEthernetReq,a1
		sub.l	a2,a2
		sub.l	a3,a3
		JSRLIB	EasyRequestArgs
		move.l	_ExecBase,a6

NTCloseDev	move.l	ControlIO,a1
		tst.l	IO_DEVICE(a1)
		beq	1$
		JSRLIB	CloseDevice
1$		move.l	ControlIO,a0
		JSRLIB	DeleteIORequest
		clr.l	ControlIO

; Dem Emulator Bescheid sagen
NTSigEmul	move.l	MyTask,a1
		move.l	SubtaskSet,d0
		JSRLIB	Signal

; Hauptschleife: Auf Signal warten
NTMainLoop	move.l	_ExecBase,a6
		move.l	NetAddMultiSet,d0
		or.l	NetDelMultiSet,d0
		or.l	NetGetInfoSet,d0
		or.l	NetWriteSet,d0
		or.l	NetAttachPHSet,d0
		or.l	NetDetachPHSet,d0
		or.l	NetCleanupSet,d0
		or.l	NetQuitSet,d0
		or.l	WritePortSet,d0
		or.l	ReadPortSet,d0
		JSRLIB	Wait
		move.l	d0,TheSignals

NTSigLoop	move.l	TheSignals,d0
		move.l	d0,d1
		and.l	NetAddMultiSet,d1
		beq	1$
		eor.l	d1,TheSignals
		bra	NTAddMulti

1$		move.l	d0,d1
		and.l	NetDelMultiSet,d1
		beq	2$
		eor.l	d1,TheSignals
		bra	NTDelMulti

2$		move.l	d0,d1
		and.l	NetGetInfoSet,d1
		beq	3$
		eor.l	d1,TheSignals
		bra	NTGetInfo

3$		move.l	d0,d1
		and.l	NetWriteSet,d1
		beq	4$
		eor.l	d1,TheSignals
		bra	NTWrite

4$		move.l	d0,d1
		and.l	NetAttachPHSet,d1
		beq	5$
		eor.l	d1,TheSignals
		bra	NTAttachPH

5$		move.l	d0,d1
		and.l	NetDetachPHSet,d1
		beq	6$
		eor.l	d1,TheSignals
		bra	NTDetachPH

6$		move.l	d0,d1
		and.l	WritePortSet,d1
		beq	7$
		eor.l	d1,TheSignals
		bra	NTWriteDone

7$		move.l	d0,d1
		and.l	ReadPortSet,d1
		beq	8$
		eor.l	d1,TheSignals
		bra	NTReadDone

8$		move.l	d0,d1
		and.l	NetCleanupSet,d1
		beq	9$
		eor.l	d1,TheSignals
		bra	NTCleanup

9$		move.l	d0,d1
		and.l	NetQuitSet,d1
		beq	NTMainLoop
		eor.l	d1,TheSignals
		bra	NTQuit

; Multicast-Adresse hinzufügen
NTAddMulti	move.w	#S2_ADDMULTICASTADDRESS,d0
		bra	DoMulti

; Multicast-Adresse entfernen
NTDelMulti	move.w	#S2_DELMULTICASTADDRESS,d0

DoMulti		cmp.w	#HTYPE_ETHER,HardwareType ;Nur für Ethernet
		bne	MultiDoneOK

		move.l	_ExecBase,a6
		move.l	NetParmBlock,a0
		move.l	ControlIO,a1
		move.w	d0,IO_COMMAND(a1)
		move.l	csParam(a0),IOS2_SRCADDR(a1)
		move.w	csParam+4(a0),IOS2_SRCADDR+4(a1)
		JSRLIB	DoIO
		cmp.b	#S2ERR_NOT_SUPPORTED,d0
		beq	MultiNotSupp
		tst.l	d0
		beq	MultiDoneOK
		moveq	#-91,d0
		bra	MultiDone

MultiNotSupp	move.l	_IntuitionBase,a6	;Device kann kein Multicast
		sub.l	a0,a0
		lea	NoMulticastReq,a1
		sub.l	a2,a2
		sub.l	a3,a3
		JSRLIB	EasyRequestArgs

MultiDoneOK	moveq	#0,d0
MultiDone	move.w	d0,NetError

		move.l	_ExecBase,a6		;Signal an Emulator
		move.l	MyTask,a1
		move.l	NTReadySet,d0
		JSRLIB	Signal
		bra	NTSigLoop

; Ethernet-Informationen holen
NTGetInfo	move.l	_ExecBase,a6

		DPRINTF	" NTGetInfo"

		move.l	MyEtherAddr,GetInfoBuf
		move.w	MyEtherAddr+4,GetInfoBuf+4

		move.l	ControlIO,a1		;Statistik ermitteln
		move.w	#S2_GETGLOBALSTATS,IO_COMMAND(a1)
		move.l	#StatData,IOS2_STATDATA(a1)
		JSRLIB	DoIO
		lea	StatData,a0
		move.l	S2DS_OVERRUNS(a0),GetInfoBuf+6	;# of receive queue overflows
		clr.l	GetInfoBuf+10			;# of timeouts
		move.l	S2DS_BADDATA(a0),GetInfoBuf+14	;# of incorrect packets

		lea	GetInfoBuf,a0		;Daten kopieren
		move.l	NetParmBlock,a2
		move.l	csParam+2(a2),a1	;ePointer
		moveq	#0,d0
		move.w	csParam+6(a2),d0	;eBuffSize
		cmp.w	#18,d0			;Maximal 18 Bytes
		bls	1$
		moveq	#18,d0
1$		move.w	d0,csParam+8(a2)	;eDataSize
		JSRLIB	CopyMem

		move.l	MyTask,a1
		move.l	NTReadySet,d0
		JSRLIB	Signal
		bra	NTSigLoop

; Packet senden
NTWrite		move.l	NetWDS,a2

		moveq	#0,d0			;Gesamtlänge zusammenrechnen
		moveq	#0,d1			;d1: Gesamtlänge
		move.l	a2,a0
1$		move.w	(a0)+,d0
		beq	EWLenCalced
		add.l	d0,d1
		addq.l	#4,a0
		bra	1$

EWLenCalced	cmp.l	#60,d1			;Minimale Länge sind 60 Bytes
		bhs	6$
		moveq	#60,d1

6$		move.l	2(a2),a0		;Zeiger auf Header

		move.l	WriteIO,a1
		move.l	a2,IOS2_DATA(a1)	;Zeiger auf WDS
		move.l	d1,IOS2_DATALENGTH(a1)	;Gesamtlänge
		move.l	(a0)+,IOS2_DSTADDR(a1)	;Zieladresse
		move.w	(a0)+,IOS2_DSTADDR+4(a1)
		move.l	MyEtherAddr,(a0)+	;Quelladresse
		move.w	MyEtherAddr+4,(a0)+

		cmp.w	#HTYPE_ETHER,HardwareType
		beq	3$
		cmp.w	#HTYPE_AMOK,HardwareType
		bne	4$
		move.w	IOS2_DSTADDR+4(a1),IOS2_DSTADDR(a1)	;AmokNet Zieladresse
		bra	3$
4$		move.l	OtherPLIPAddr,IOS2_DSTADDR(a1) ;PLIP Zieladresse
3$
		moveq	#0,d0
		move.w	(a0)+,d0		;Packet Type
		move.l	d0,IOS2_PACKETTYPE(a1)
		cmp.w	#$5dc,d0		;802.3?
		bhi	1$
		clr.l	IOS2_PACKETTYPE(a1)	;Ja, Typ auf Null setzen
1$
		move.w	#CMD_WRITE,d0
		cmp.w	#HTYPE_ETHER,HardwareType ;Multicast nur bei Ethernet/AmokNet
		beq	5$
		cmp.w	#HTYPE_AMOK,HardwareType
		bne	2$
5$		btst	#0,IOS2_DSTADDR(a1)	;Multicast-Flag
		beq	2$
		move.w	#S2_MULTICAST,d0
		DPRINTF	" multicast"
		cmp.l	#-1,IOS2_DSTADDR(a1)
		bne	2$
		cmp.w	#-1,IOS2_DSTADDR+4(a1)
		bne	2$
		move.w	#S2_BROADCAST,d0
		DPRINTF	" broadcast"
2$		move.w	d0,IO_COMMAND(a1)

		move.b	IOFlags,IO_FLAGS(a1)

		DPRINTF	" NTWrite dest %08lx%08lx",IOS2_DSTADDR(a1),IOS2_DSTADDR+4(a1)

		move.l	IO_DEVICE(a1),a6	;Request abschicken
		jsr	-30(a6)
		bra	NTSigLoop

; Packet gesendet
NTWriteDone	;DPRINTF	" NTWriteDone"

		move.l	_ExecBase,a6		;Request empfangen
		move.l	WritePort,a0
		JSRLIB	GetMsg
		tst.l	d0
		beq	NTSigLoop

		move.l	MyTask,a1		;Exception auslösen
		move.l	NetworkSet,d0
		JSRLIB	Signal
		bra	NTWriteDone

; Protocol Handler installieren
NTAttachPH	move.l	_ExecBase,a6
		move.l	NetParmBlock,a3

		DPRINTF	" NTAttachPH"

		moveq	#0,d2
		move.w	csParam(a3),d2		;eProtType
		move.l	csParam+2(a3),d3	;ePointer

		move.l	ProtList+LH_HEAD,a0	;Protokoll schon installiert?
4$		move.l	LN_SUCC(a0),d0
		beq	3$
		cmp.w	prot_Type(a0),d2
		beq	NTAttachPHErr
		move.l	d0,a0
		bra	4$
3$
		move.l	#SIZEOF_Protocol,d0	;Protokoll-Block holen
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		JSRLIB	AllocMem
		tst.l	d0
		beq	NTAttachPHErr

		move.l	d0,a3
		move.w	d2,prot_Type(a3)	;Type und Handler speichern
		move.l	d3,prot_Handler(a3)

		lea	ProtList,a0		;Protokoll in Liste hängen
		move.l	a3,a1
		JSRLIB	AddTail

		moveq	#NUM_REQUESTS-1,d7	;Requests einrichten und abschicken
		lea	prot_ReadIOs(a3),a2
		move.l	ControlIO,a4
1$
		move.l	a4,a0			;ControlIO kopieren
		move.l	a2,a1
		moveq	#IOS2_SIZE-1,d0
2$		move.b	(a0)+,(a1)+
		dbra	d0,2$

		move.l	a2,a1
		clr.b	LN_TYPE(a1)
		move.l	ReadPort,MN_REPLYPORT(a1)
		move.w	#CMD_READ,IO_COMMAND(a1)
		move.l	d2,IOS2_PACKETTYPE(a1)
		move.l	a3,IOS2_DATA(a1)	;Zeigt auf Protokoll
		move.b	IOFlags,IO_FLAGS(a1)
		move.l	IO_DEVICE(a1),a6	;Request abschicken
		jsr	-30(a6)
		lea	IOS2_SIZE(a2),a2
		dbra	d7,1$

		clr.w	NetError		;Alles OK
		bra	NTAttachPHDone

NTAttachPHErr	DPRINTF	" already installed"
		move.w	#-94,NetError		;Fehler aufgetreten (LAPProtErr)
NTAttachPHDone	move.l	_ExecBase,a6		;Emulator benachrichtigen
		move.l	MyTask,a1
		move.l	NTReadySet,d0
		JSRLIB	Signal
		bra	NTSigLoop

; Protocol Handler entfernen
NTDetachPH	move.l	_ExecBase,a6
		move.l	NetParmBlock,a3
		move.w	csParam(a3),d2		;eProtType

		DPRINTF	" NTDetachPH"

		move.l	ProtList+LH_HEAD,a3	;Protokoll installiert?
4$		move.l	LN_SUCC(a3),d0
		beq	NTDetachPHErr
		cmp.w	prot_Type(a3),d2
		beq	3$
		move.l	d0,a3
		bra	4$
3$
		bsr	RemoveProtocol		;Ja, entfernen
		clr.w	NetError		;Alles OK
		bra	NTDetachPHDone

NTDetachPHErr	DPRINTF	" not installed"
		move.w	#-94,NetError		;Fehler aufgetreten (LAPProtErr)
NTDetachPHDone	move.l	_ExecBase,a6		;Emulator benachrichtigen
		move.l	MyTask,a1
		move.l	NTReadySet,d0
		JSRLIB	Signal
		bra	NTSigLoop

; Packet empfangen
NTReadDone	move.l	_ExecBase,a6
		move.l	ReadPort,a0
		JSRLIB	GetMsg
		tst.l	d0
		beq	NTSigLoop

		DPRINTF	"NTReadDone"

		move.l	d0,a1			;Request wieder anstoßen
		tst.b	IO_ERROR(a1)		;A failed read (device offline) comes back at
		beq	1$			; once: wait a little, so this is no busy loop
		move.l	a1,-(sp)
		move.l	_DOSBase,a6
		moveq	#10,d1
		JSRLIB	Delay
		move.l	(sp)+,a1
		move.b	IOFlags,IO_FLAGS(a1)
		move.l	IO_DEVICE(a1),a6
		jsr	-30(a6)
		move.l	_ExecBase,a6		;It may fail again at once: look at the other
		sub.l	a1,a1			; signals first (this task may be asked to end
		JSRLIB	FindTask		; while the device is offline), then go on here
		move.l	d0,a1
		move.l	ReadPortSet,d0
		JSRLIB	Signal
		bra	NTSigLoop
1$		move.b	IOFlags,IO_FLAGS(a1)
		move.l	IO_DEVICE(a1),a6
		jsr	-30(a6)
		bra	NTReadDone

; Alle Protokolle entfernen
NTCleanup	DPRINTF	"NTCleanup"
		move.l	_ExecBase,a6
		move.l	ProtList+LH_HEAD,a3
1$		move.l	LN_SUCC(a3),d7		;d7: Succ
		beq	NTSigLoop
		bsr	RemoveProtocol
		move.l	d7,a3
		bra	1$

; NetworkTask beenden
NTQuit		move.l	_ExecBase,a6

		move.l	ProtList+LH_HEAD,a3	;Alle Protokolle entfernen
7$		move.l	LN_SUCC(a3),d7		;d7: Succ
		beq	6$
		bsr	RemoveProtocol
		move.l	d7,a3
		bra	7$
6$
		move.l	ReadPort,d0
		beq	5$
		move.l	d0,a0
		JSRLIB	DeleteMsgPort
5$
		move.l	WriteIO,d0
		beq	4$
		move.l	d0,a1
		JSRLIB	CheckIO
		tst.l	d0
		bne	41$
		move.l	WriteIO,a1
		JSRLIB	AbortIO
		move.l	WriteIO,a1
		JSRLIB	WaitIO
41$		move.l	WriteIO,a0
		JSRLIB	DeleteIORequest
4$
		move.l	WritePort,d0
		beq	3$
		move.l	d0,a0
		JSRLIB	DeleteMsgPort
3$
		move.l	ControlIO,d0
		beq	2$
		move.l	d0,a1
		JSRLIB	CloseDevice
		move.l	ControlIO,a0
		JSRLIB	DeleteIORequest
2$
		move.l	ControlPort,d0
		beq	1$
		move.l	d0,a0
		JSRLIB	DeleteMsgPort
1$
		move.b	NetAddMultiSig,d0
		JSRLIB	FreeSignal
		move.b	NetDelMultiSig,d0
		JSRLIB	FreeSignal
		move.b	NetGetInfoSig,d0
		JSRLIB	FreeSignal
		move.b	NetWriteSig,d0
		JSRLIB	FreeSignal
		move.b	NetAttachPHSig,d0
		JSRLIB	FreeSignal
		move.b	NetDetachPHSig,d0
		JSRLIB	FreeSignal
		move.b	NetCleanupSig,d0
		JSRLIB	FreeSignal
		move.b	NetQuitSig,d0
		JSRLIB	FreeSignal

		JSRLIB	Forbid
		move.l	MyTask,a1
		move.l	SubtaskSet,d0
		JSRLIB	Signal
		moveq	#0,d0
		rts


*
* Protokoll entfernen
* a3: Protokoll (unverändert)
* a6: ExecBase
*

RemoveProtocol	JSRLIB	Disable			;Protokoll ausklinken
		move.l	a3,a1
		JSRLIB	Remove
		JSRLIB	Enable

		lea	prot_ReadIOs(a3),a2	;Alle Requests abbrechen
		moveq	#NUM_REQUESTS-1,d2
1$		move.l	a2,a1
		JSRLIB	AbortIO
		move.l	a2,a1
		JSRLIB	WaitIO
		lea	IOS2_SIZE(a2),a2
		dbra	d2,1$

		move.l	a3,a1
		move.l	#SIZEOF_Protocol,d0
		JMPLIB	FreeMem


*
* CopyBuff-Callbacks
*

; Lesen, a0: Protocol, a1: Quellpuffer
MyCopyToBuff	tst.w	MacRunning
		beq	3$
		movem.l	d2-d3/a2-a6,-(sp)
		move.l	_ExecBase,a6

		move.l	prot_Handler(a0),d3
		beq	1$

		DPRINTF	"MyCopyToBuff, a1 %08lx, d0 %08lx, data %08lx%08lx%08lx%08lx",a1,d0,(a1),4(a1),8(a1),12(a1)

		moveq	#-14,d1			;14 Bytes Header. SANA-II liefert Pakete ohne CRC;
						;3.11 zog bei Ethernet 18 ab (A2065/Ariadne haengten
						;die 4 CRC-Bytes an) und verlor so mit anderen
						;Treibern die letzten 4 Bytes jedes IP-Pakets.
2$		add.l	d0,d1			;d1: Packetlänge (ohne Header)
		moveq	#0,d0
		move.w	12(a1),d0		;(d0: Packet-Typ)
		lea	14(a1),a0		;(a0: Zeiger auf Packet)
		move.l	a0,a3			;a3: Zeiger hinter Header
		lea	ReadFuncs,a4		;a4: ReadPacket/ReadRest
		lea	JsrD3Proc,a5
		JSRLIB	Supervisor

1$		movem.l	(sp)+,d2-d3/a2-a6
3$		moveq	#1,d0			;Erfolgreich
		rts

JsrD3Proc	addq.w	#1,NoSuperSwitch
		move.l	d3,a5
		jsr	(a5)			;Protocol Handler aufrufen
		subq.w	#1,NoSuperSwitch
		rte

;Schreiben, a0: Zielpuffer, a1: WDS
MyCopyFromBuff	movem.l	d2/a2-a3/a6,-(sp)
		move.l	_ExecBase,a6
		move.l	a1,a2			;a2: Quelle
		move.l	a0,a3			;a3: Ziel

		DPRINTF	"MyCopyFromBuff"

		moveq	#0,d2			;d2: Gesamtlänge
1$		moveq	#0,d0			;Länge holen
		move.w	(a2)+,d0
		beq	2$			;0: Ende
		add.l	d0,d2
		move.l	(a2)+,a0		;Quelle
		move.l	a3,a1			;Ziel
		add.l	d0,a3			;Zielzeiger erhöhen
		JSRLIB	CopyMem
		bra	1$

2$		cmp.l	#60,d2			;Minimale Länge sind 60 Bytes
		bhs	3$
		moveq	#59,d0
		sub.l	d2,d0
4$		clr.b	(a3)+
		dbra	d0,4$

3$		movem.l	(sp)+,d2/a2-a3/a6
		moveq	#1,d0			;Erfolgreich
		rts


*
* ReadPacket und ReadRest
*

ReadFuncs	bra.b	ReadPacket

; d3: Länge, a3: Ziel
; (a0: Quelle, d1: Restlänge)
ReadRest	move.w	d3,d0		;Überschüssige Länge berechnen
		sub.w	d1,d0
		tst.w	d3		;0 Bytes angefordert? Dann nichts lesen
		beq	1$
		bsr	ReadPacket	;Daten lesen
1$		move.w	d0,d3		;d3: Überschüssige Länge
		moveq	#0,d0		;Alles OK (Z-Flag)
		rts

; d3: Länge, a3: Ziel
; (a0: Quelle, d1: Restlänge)
ReadPacket	movem.l	d0/a1,-(sp)
		move.l	a3,a1		;a1: Ziel

		moveq	#0,d0		;Nur maximal soviel lesen, wie da ist
		move.w	d3,d0
		cmp.w	d1,d3
		bls	1$
		move.w	d1,d0		;d0: Zu kopierende Länge
1$
		sub.w	d0,d1		;Restlänge vermindern
		sub.w	d0,d3		;Angeforderte Länge vermindern (Rückgabewert)
		add.w	d0,a3		;Zeiger im Zielpuffer erhöhen

		movem.l	d0-d1/a0/a6,-(sp)
		move.l	_ExecBase,a6
		JSRLIB	CopyMem		;Daten kopieren
		movem.l	(sp)+,d0-d1/a0/a6
		add.w	d0,a0		;Zeiger im Quellpuffer erhöhen

		movem.l	(sp)+,d0/a1
		tst.w	d3		;Rückgabe (Z-Flag)
		rts


*
* Exception zum Schreiben
*

NetworkExcept	DPRINTF	" NetworkExcept"

		move.l	#$0700,d0	;Rekursiven Aufruf verhindern
		move.l	d0,d1
		JSRLIB	SetSR

		move.l	WriteIO,a0	;JIODone aufrufen
		moveq	#0,d0
		tst.b	IO_ERROR(a0)
		beq	1$
		moveq	#-95,d0
1$		move.l	NetDCE,a1
		lea	JumpIODoneProc,a5
		JSRLIB	Supervisor

		DPRINTF	" IODone called"
		rts

JumpIODoneProc	move.l	JIODone,a0
		jsr	(a0)
		rte


**
** Konstanten
**

; Strings
NetTaskName	dc.b	"ShapeShifter NetworkTask",0
ReqTitle	dc.b	"ShapeShifter Network Error",0
ReqGads		dc.b	"OK",0
NoEtherReadTxt	dc.b	"Unsupported ERead call",0
NoMulticastTxt	dc.b	"Your Ethernet card does not",10
		dc.b	"support multicast and is not",10
		dc.b	"usable with AppleTalk. Please",10
		dc.b	"report this to the manufacturer",10
		dc.b	"of the card.",0
NoEthernetTxt	dc.b	"The selected network device is",10
		dc.b	"not an Ethernet/PLIP device.",10
		dc.b	"Networking will be disabled.",0
		CNOP	0,4

; Taglists
BufferTags	dc.l	S2_COPYTOBUFF,MyCopyToBuff
		dc.l	S2_COPYFROMBUFF,MyCopyFromBuff
		dc.l	0,0

ProcTags	dc.l	NP_Entry,NetTaskMain
		dc.l	NP_Name,NetTaskName
		dc.l	NP_Priority,1
		dc.l	0,0


**
** Initialisierte Daten
**

		SECTION	"DATA",DATA

; Requester
NoMulticastReq	dc.l	20,0,ReqTitle,NoMulticastTxt,ReqGads
NoEtherReadReq	dc.l	20,0,ReqTitle,NoEtherReadTxt,ReqGads
NoEthernetReq	dc.l	20,0,ReqTitle,NoEthernetTxt,ReqGads


**
** Nicht initialisierte Daten
**

		SECTION	"BSS",BSS
ControlPort	ds.l	1	;Port für ControlIO
WritePort	ds.l	1	;Port für WriteIO
ReadPort	ds.l	1	;Port für ReadIOs

ControlIO	ds.l	1	;Steuerung (1 Request)
WriteIO		ds.l	1	;Ausgabe (1 Request)

NetTaskProc	ds.l	1	;ProcID des NetworkTask
NetworkTask	ds.l	1	;Zeiger auf Task des Prozesses

TheSignals	ds.l	1	;Empfangene Signale

NetParmBlock	ds.l	1	;ParamBlock für NetworkTask
NetWDS		ds.l	1	;WDS für NetworkTask
NetDCE		ds.l	1	;DCE des .ENET-Treibers
NetError	ds.w	1	;Fehlercode des NetworkTask

ProtList	ds.b	MLH_SIZE ;Liste der aktiven Protokolle

GetInfoBuf	ds.b	18		;Puffer für GetInfo
StatData	ds.b	S2DS_SIZE	;Puffer für S2_GETGLOBALSTATS
QueryData	ds.b	S2DQ_SIZE	;Puffer für S2_DEVICEQUERY

MyEtherAddr	ds.b	6	;Unsere Ethernet-Hardware-Adresse

OtherPLIPAddr	ds.l	1	;PLIP: Die Hardwareadresse der Gegenstelle ($00/$80)

HardwareType	ds.w	1	;Verwendete Netzwerkhardware (HTYPE_#?)
IOFlags		ds.b	1	;IO_FLAGS

		CNOP	0,4
NetAddMultiSet	ds.l	1	;Signal: Multicast-Adresse dazunehmen
NetDelMultiSet	ds.l	1	;Signal: Multicast-Adresse entfernen
NetGetInfoSet	ds.l	1	;Signal: Ethernet-Informationen holen
NetWriteSet	ds.l	1	;Signal: Packet senden
NetAttachPHSet	ds.l	1	;Signal: Protocol Handler installieren
NetDetachPHSet	ds.l	1	;Signal: Protocol Handler entfernen
NetCleanupSet	ds.l	1	;Signal: Alle Protokolle entfernen
NetQuitSet	ds.l	1	;Signal: NetworkTask soll sich beenden
WritePortSet	ds.l	1	;Signal: WriteIO fertig
ReadPortSet	ds.l	1	;Signal: ReadIO fertig
NTReadySet	ds.l	1	;Signal: NetworkTask fertig
NetworkSet	ds.l	1	;Signal für Exception
NetAddMultiSig	ds.b	1
NetDelMultiSig	ds.b	1
NetGetInfoSig	ds.b	1
NetWriteSig	ds.b	1
NetAttachPHSig	ds.b	1
NetDetachPHSig	ds.b	1
NetCleanupSig	ds.b	1
NetQuitSig	ds.b	1
WritePortSig	ds.b	1
ReadPortSig	ds.b	1
NTReadySig	ds.b	1
NetworkSig	ds.b	1

NetIsOpen	ds.b	1	;#0: Öffnen des Devices etc. ist gelungen

		END
