**
** Macintosh IIci-Emulator - Amiga SCSI Treiber
** ============================================
**
** © Copyright 1994-2001 Christian Bauer
**

DEBUG_DETAIL	SET 0

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"exec/io.i"
		INCLUDE	"devices/scsidisk.i"
		INCLUDE	"macros.i"
		INCLUDE	"macinclude.i"

		XREF	ScanPartMap
		XDEF	OpenSCSI
		XDEF	CloseSCSI
		XDEF	SCSILoadPatch
		XDEF	SCSIDispatch
		XDEF	InstallAppleCD
		XDEF	CDROMRefNum

		SECTION	"CODE",CODE


**
** Definitionen
**

CDROMRefNum	= -62		;Nummer des CD-ROM-Treibers

; Puffergröße, muß mindestens 64KB sein
InitBufferSize	= 65536
CmdBufferSize	= 12

; Fehlercodes
scCommErr	= 2
scArbNBErr	= 3
scBadParmsErr	= 4
scPhaseErr	= 5
scCompareErr	= 6
scMgrBusyErr	= 7
scSequenceErr	= 8
scBusTOErr	= 9
scComplPhaseErr	= 10

; (logische) SCSI-Phasen
phFree		= 0	;Bus frei
phArbitrated	= 1	;Bus arbitriert (SCSIGet)
phSelected	= 2	;Target selektiert (SCSIGet, SCSISelect)
phTransfer	= 3	;Befehl gesendet (SCSIGet, SCSISelect, SCSICmd)

; Datenbereich (a5)
 STRUCTURE	MySCSIData,0
	STRUCT	scSCSICmd,scsi_SIZEOF	;SCSICmd-Struktur (muß am Anfang stehen!)

	LONG	scBufMemType	;Speichertyp für Puffer
	APTR	scBufferSize	;Größe des Puffers
	LONG	scBytesInBuffer	;Füllstand des Puffers
	APTR	scBufferPtr	;Zeiger im Puffer

	APTR	scReplyPort	;Port für IORequest
	STRUCT	scRequests,4*8*8 ;IORequests für ID 0..7, LUN 0..7
	APTR	scTheRequest	;Aktiver Request

	STRUCT	scDeviceClass,8*8 ;SCSI-Geräteklassen für ID 0..7, LUN 0..7

	WORD	scTargetID	;ID des selektierten Gerätes
	WORD	scTargetLUN	;LUN des selektierten Gerätes
	WORD	scFakeStatus	;Gefaketes 5830-Statuswort
	BYTE	scPhase		;Logische SCSI-Phase (ph*)
	BYTE	scCmdPending	;Befehl angenommen, aber noch nicht abgeschickt
	BYTE	scIsAutosense	;Autosense-Daten werden gelesen, keinen Phase-Error erzeugen
	BYTE	scpad0

	WORD	cdTargetID	;ID des CD-ROMs
	WORD	cdRefNum	;RefNum des .AppleCD-Treibers
	BYTE	cdAlwaysPostEvent ;Flag: Auch bei nicht-HFS-CDs diskEvent posten
	BYTE	cdPlayMode	;Aktueller PlayMode
	APTR	cdRequest	;IORequest des CD-ROMs
	APTR	cdDCE		;DCE des .AppleCD-Treibers
	APTR	cdIOParam	;Zwischenspeicher für IOParam
	LONG	cdStartByte	;Byte-Offset zum Anfang des Mediums
	WORD	cd2KOffset	;2K-Offset des letzten Prime-Aufrufs (<0: ungültig)
	WORD	cdBlockSize	;Aktuelle Blockgröße
	STRUCT	cdDriveStatus,DSHD20_SIZEOF ;DriveStatus des CD-Laufwerks
	STRUCT	cdTOC,$324	;TOC der eingelegten CD
	LONG	cdLeadOutMSF	;MSF-Adresse des Lead-Out-Tracks
	BYTE	cdToBeMounted	;Flag: CD muß gemountet werden
	BYTE	cdpad0

	STRUCT	scSenseData,256	;Hier kommen die Sense-Daten hin
 LABEL	SIZEOF_MySCSIData

; Aliases
scBuffer	= scsi_Data	;Zeiger auf Pufferanfang
scCmdBuffer	= scsi_Command	;Zeiger auf Befehlspuffer


**
** Initialisierung
** Rückgabe: d0#0 = Fehler
**

; SCSICmd vorbereiten
OpenSCSI	lea	BssSection,a5
		move.l	_ExecBase,a6

		lea	scSenseData(a5),a0
		move.l	a0,scsi_SenseData(a5)
		move.w	#255,scsi_SenseLength(a5)

; Speichertyp ermitteln
		cmp.w	#SCSIMEM_CHIP,SCSIMemType
		bne	1$
		move.l	#MEMF_CHIP|MEMF_PUBLIC,scBufMemType(a5)
		bra	3$
1$		cmp.w	#SCSIMEM_24BIT,SCSIMemType
		bne	2$
		move.l	#MEMF_24BITDMA|MEMF_PUBLIC,scBufMemType(a5)
		bra	3$
2$		move.l	#MEMF_PUBLIC,scBufMemType(a5)
3$

; Datenpuffer holen
		move.l	#InitBufferSize,d0
		move.l	d0,scBufferSize(a5)
		move.l	scBufMemType(a5),d1
		JSRLIB	AllocMem
		move.l	d0,scBuffer(a5)
		beq	OSError

; Befehlspuffer holen
		move.l	#CmdBufferSize,d0
		move.l	scBufMemType(a5),d1
		or.l	#MEMF_CLEAR,d1
		JSRLIB	AllocMem
		move.l	d0,scCmdBuffer(a5)
		beq	OSError

; ReplyPort einrichten
		JSRLIB	CreateMsgPort
		move.l	d0,scReplyPort(a5)
		beq	OSError

; Schleife für alle 7 Target-IDs (0..6)
		moveq	#0,d7			;ID-Zähler

OSIDLoop	btst	d7,SCSIEnable		;ID eingeschaltet?
		beq	OSNextID

; Schleife für alle 8 LUNs
		moveq	#0,d6			;LUN-Zähler

OSLUNLoop	move.l	scReplyPort(a5),a0
		moveq	#IOSTD_SIZE,d0
		JSRLIB	CreateIORequest		;IORequest erzeugen
		tst.l	d0
		beq	OSNextLUN
		move.l	d0,a2			;a2: Request

		lea	SCSIName0,a4		;Name holen
		move.w	d7,d1
		mulu.w	#80,d1
		add.w	d1,a4
		tst.b	(a4)
		beq	OSDidNot
		movem.l	d6-d7,-(sp)
		lea	SCSIUnit0,a0		;Unit holen
		move.l	(a0,d7.w*4),d7
		mulu.w	#10,d6			;LUN ist Zehnerstelle
		add.l	d6,d7
	;	DPRINTF	"Opening %s, unit %ld",a4,d7

		move.l	a4,a0
		move.l	d7,d0			;Unit
		move.l	a2,a1
		moveq	#0,d1			;Flags
		JSRLIB	OpenDevice

		movem.l	(sp)+,d6-d7
		tst.w	d0
		beq	OSDidIt

OSDidNot	move.l	a2,a0			;Nicht gelungen: den Request entfernen
		JSRLIB	DeleteIORequest
; No answer on this LUN: the higher ones of this ID are not tried. Every
; attempt on a unit that is not there can take seconds (the device waits
; for the selection to time out), and 8 LUNs on each of 7 IDs added up to
; minutes of grey screen before the Mac started.
1$		move.l	d7,d0
		lsl.l	#3,d0
		add.l	d6,d0
		clr.l	(scRequests,a5,d0.l*4)
		addq.b	#1,d6
		cmp.b	#8,d6
		bne	1$
		bra	OSNextID

OSDidIt		move.l	d7,d0			;Zeiger auf Request speichern
		lsl.l	#3,d0
		add.l	d6,d0
		move.l	a2,(scRequests,a5,d0.l*4)

		move.l	a2,a1			;Request einrichten
		move.w	#HD_SCSICMD,IO_COMMAND(a1)
		move.l	a5,IO_DATA(a1)
		move.l	#scsi_SIZEOF,IO_LENGTH(a1)
		clr.l	IO_OFFSET(a1)

		move.l	scCmdBuffer(a5),a0	;Inquiry senden
		move.b	#$12,(a0)
		move.b	#96,4(a0)
		move.w	#6,scsi_CmdLength(a5)
		move.l	scBufferSize(a5),scsi_Length(a5)
		move.b	#SCSIF_READ|SCSIF_AUTOSENSE,scsi_Flags(a5) ;Initialisierung von Flags mit AUTOSENSE ist wichtig!
		JSRLIB	DoIO
		tst.b	IO_ERROR(a2)
		beq	2$
		move.l	a2,a1			;Opened, but nothing answers: close it again
		JSRLIB	CloseDevice
		bra	OSDidNot
2$
		move.b	([scBuffer,a5]),d1	;Gelungen, Geräteklasse lesen
		and.b	#$1f,d1
		move.l	d7,d0
		lsl.l	#3,d0
		add.l	d6,d0
		move.b	d1,(scDeviceClass,a5,d0.l)

OSNextLUN	addq.b	#1,d6		;Nächste LUN
		cmp.b	#8,d6
		bne	OSLUNLoop

OSNextID	addq.b	#1,d7		;Nächste ID
		cmp.b	#7,d7
		bne	OSIDLoop

OSReturn	moveq	#0,d0		;Alles OK
		rts

OSError		moveq	#-1,d0		;Fehler
		rts


**
** Beenden
**

; IORequests entfernen
CloseSCSI	lea	BssSection,a5
		move.l	_ExecBase,a6

		moveq	#0,d7		;ID-Zähler
CSIDLoop	moveq	#0,d6		;LUN-Zähler
CSLUNLoop	move.l	d7,d0
		lsl.l	#3,d0
		add.l	d6,d0
		move.l	(scRequests,a5,d0.l*4),d2
		beq	CSNext

		move.l	d2,a1
		JSRLIB	CloseDevice	;Gerät schließen
		move.l	d2,a0
		JSRLIB	DeleteIORequest	;IORequest entfernen

CSNext		addq.b	#1,d6
		cmp.b	#8,d6
		bne	CSLUNLoop

		addq.b	#1,d7
		cmp.b	#7,d7
		bne	CSIDLoop

; ReplyPort freigeben
		move.l	scReplyPort(a5),d0
		beq	1$
		move.l	d0,a0
		JSRLIB	DeleteMsgPort
1$

; Befehlspuffer entfernen
		move.l	scCmdBuffer(a5),d0
		beq	2$
		move.l	d0,a1
		moveq	#CmdBufferSize,d0
		JSRLIB	FreeMem
2$

; Datenpuffer entfernen
		move.l	scBuffer(a5),d0
		beq	3$
		move.l	d0,a1
		move.l	scBufferSize(a5),d0
		JSRLIB	FreeMem
3$		rts


**
** Patch für SCSILoad: Nicht von anderen SCSI-Geräten als Platten booten
** d5: ID
** Rückgabe: ne = nicht booten
**

SCSILoadPatch	lea	BssSection,a0
		move.l	d5,d0
		lsl.l	#3,d0
		tst.b	(scDeviceClass,a0,d0.l)
		rts


**
** Verteiler
**

SCSIDispatch	move.l	(sp)+,a0	;RTS holen
		move.w	(sp)+,d0	;Selector holen
		move.l	a0,-(sp)	;RTS wiederherstellen

		cmp.w	#14,d0
		bhi	SCSISelectorErr

		link	a6,#0
		movem.l	d2-d7/a2-a5,-(sp)
		lea	BssSection,a5

		move.w	SCSIJump(pc,d0.w*2),d0
		jmp	SCSIJump(pc,d0.w)

SCSIJump	dc.w	SCSIReset-SCSIJump
		dc.w	SCSIGet-SCSIJump
		dc.w	SCSISelect-SCSIJump
		dc.w	SCSIDoCmd-SCSIJump
		dc.w	SCSIComplete-SCSIJump
		dc.w	SCSIRead-SCSIJump
		dc.w	SCSIWrite-SCSIJump
		dc.w	SCSISelectorErr-SCSIJump
		dc.w	SCSIRead-SCSIJump	;RBlind
		dc.w	SCSIWrite-SCSIJump	;WBlind
		dc.w	SCSIStat-SCSIJump
		dc.w	SCSISelect-SCSIJump	;SelAtn
		dc.w	SCSIMsgIn-SCSIJump
		dc.w	SCSIMsgOut-SCSIJump
		dc.w	SCSIMgrBusy-SCSIJump

SCSISelectorErr	moveq	#12,d0		;Unbekannter Selector
		dc.w	$a9c9		;SysError
1$		bra	1$


*
* Rückkehr aus SCSI-Routine, d0: Anzahl Bytes auf dem Stack
*

ReturnZero	moveq	#0,d0
Return		movem.l	(sp)+,d2-d7/a2-a5
		unlk	a6
		move.l	(sp)+,a0
		add.w	d0,sp
		jmp	(a0)


*
* SCSIReset: Bus zurücksetzen
*

SCSIReset	move.b	#phFree,scPhase(a5)
		clr.w	scFakeStatus(a5)
		clr.b	scCmdPending(a5)
		clr.w	8(a6)		;Alles OK
		bra	ReturnZero


*
* SCSIGet: Bus belegen
*

SCSIGet		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		JSRLIB	Disable
		move.l	(sp)+,a6

		moveq	#scMgrBusyErr,d0	;Vorgabe
		cmp.b	#phFree,scPhase(a5)	;Bus frei?
		bne	1$

		move.b	#phArbitrated,scPhase(a5) ;Ja, arbitrieren
		move.w	#$0040,scFakeStatus(a5)	;Bus Busy

		clr.b	scCmdPending(a5)	;Noch kein Befehl gesendet
		clr.b	scIsAutosense(a5)	;Kein Autosense
		clr.l	scBytesInBuffer(a5)	;Puffer leer
		move.l	scBuffer(a5),scBufferPtr(a5)

		moveq	#0,d0			;Alles OK
1$		move.w	d0,8(a6)		;Returncode setzen

		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		JSRLIB	Enable
		move.l	(sp)+,a6
		bra	ReturnZero


*
* SCSISelect: ID des Targets auswählen
*

SCSISelect	moveq	#scSequenceErr,d0
		cmp.b	#phArbitrated,scPhase(a5) ;Bus arbitriert?
		bne	SelReturn

		move.b	#phSelected,scPhase(a5)	;Ja, selektieren
		move.w	8(a6),d0		;ID holen
		DPRINTF	"SCSISelect %08lx",d0	
		cmp.w	scTargetID(a5),d0	;Dasselbe Target wie eben?
		beq	1$
		clr.w	scsi_SenseActual(a5)	;Nein, Sense-Daten löschen
1$
		move.w	d0,scTargetID(a5)	;ID merken
		lsl.l	#3,d0			;LUN 0 annehmen
		tst.l	(scRequests,a5,d0.w*4)	;Zeiger auf Request für LUN 0 vorhanden?
		beq	SelFailed

		move.w	#$006a,scFakeStatus(a5)	;Ja, alles OK
		moveq	#0,d0
		bra	SelReturn

SelFailed	move.b	#phFree,scPhase(a5)	;Nein, Gerät nicht vorhanden
		clr.w	scFakeStatus(a5)	;Bus Free
		moveq	#scCommErr,d0

SelReturn	move.w	d0,10(a6)		;Returncode setzen
		moveq	#2,d0
		bra	Return


*
* SCSIDoCmd: Befehl zwischenspeichern
*

SCSIDoCmd	moveq	#scPhaseErr,d0		;Vorgabe
		cmp.b	#phSelected,scPhase(a5)	;Target selektiert?
		bne	DoCmdReturn

		move.b	#phTransfer,scPhase(a5)	;Ja, Transfer beginnen
		move.w	#$006e,scFakeStatus(a5)

		move.w	8(a6),scsi_CmdLength(a5) ;Befehlslänge merken
		move.l	10(a6),a0		;Befehl kopieren
		move.l	scCmdBuffer(a5),a1
		move.l	(a0)+,(a1)+
		move.l	(a0)+,(a1)+
		move.l	(a0),(a1)

		moveq	#0,d0
		move.l	scCmdBuffer(a5),a0
		move.b	1(a0),d0		;LUN extrahieren
		and.b	#$e0,d0
		lsr.b	#5,d0
		move.w	d0,scTargetLUN(a5)

		move.w	scTargetID(a5),d1	;Zeiger auf Request holen
		lsl.w	#3,d1
		add.w	d0,d1
		move.l	(scRequests,a5,d1.w*4),scTheRequest(a5)
		beq	DoCmdCommErr

		move.b	#SCSIF_READ|SCSIF_AUTOSENSE,scsi_Flags(a5)

		st.b	scCmdPending(a5)	;Befehl wurde angenommen
		clr.b	scIsAutosense(a5)	;Kein Autosense

		move.l	scCmdBuffer(a5),a0
		DPRINTF	"SCSICmd %08lx %08lx %08lx",(a0),4(a0),8(a0)

; Spezialbehandlung für einige Befehle
		move.l	scCmdBuffer(a5),a0
		move.b	(a0),d0
		cmp.b	#$03,d0
		beq	DoCmdReqSense
		cmp.b	#$1a,d0
		beq	DoCmdModeSense
		bra	DoCmdReturnOK

; Request Sense: Autosense-Daten lesen, falls vorhanden
DoCmdReqSense	tst.w	scsi_SenseActual(a5)	;Liegen Autosense-Daten vor?
		beq	DoCmdReturnOK

		DPRINTF	" autosense"

		clr.b	scCmdPending(a5)	;Ja, Befehl nicht mehr schicken
		clr.b	scsi_Status(a5)		;Status löschen
		st.b	scIsAutosense(a5)	;Keinen Phase-Error erzeugen, wenn nicht alle Daten gelesen wurden

		lea	scSenseData(a5),a0	;Sense-Daten in den Puffer kopieren
		move.l	scBuffer(a5),a1
		moveq	#0,d0
		move.w	scsi_SenseActual(a5),d0
		move.l	d0,scBytesInBuffer(a5)
		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		JSRLIB	CopyMem
		move.l	(sp)+,a6
		bra	DoCmdReturnOK

; Mode Sense: AppleHD-Emulation
DoCmdModeSense	move.w	scTargetID(a5),d0	;CD-ROM-Laufwerk ausgewählt?
		lsl.w	#3,d0
		add.w	scTargetLUN(a5),d0
		tst.b	scDeviceClass(a5,d0.w)	;Festplatte ausgewählt?
		bne	DoCmdReturnOK
		tst.w	AppleHD			;Ja, AppleHD-Emulation?
		beq	DoCmdReturnOK

		move.l	scCmdBuffer(a5),a0	;Ja, AppleHD Page 1?
		cmp.l	#$30002200,2(a0)
		bne	DoCmdReturnOK

		move.l	#$04002400,2(a0)	;Ja, Geometry Page lesen
		clr.b	scCmdPending(a5)
		move.b	#SCSIF_READ|SCSIF_AUTOSENSE,scsi_Flags(a5)
		move.l	scBufferSize(a5),scsi_Length(a5) ;Soviel wie möglich lesen
		bsr	SCSISendIt		;Mit Puffer abschicken
		tst.b	d0			;Fehler aufgetreten?
		bne	DoCmdReturnOK

		move.l	scBuffer(a5),a0		;Gewünschte Daten eintragen
		move.b	#34,(a0)
		move.b	#48,12(a0)
		move.b	#20,13(a0)
		move.l	#'APPL',14(a0)
		move.l	#'E CO',18(a0)
		move.l	#'MPUT',22(a0)
		move.l	#'ER, ',26(a0)
		move.l	#'INC ',30(a0)
		move.l	#34,scBytesInBuffer(a5)	;Puffervariable setzen
		bra	DoCmdReturnOK

DoCmdCommErr	moveq	#scCommErr,d0
		bra	DoCmdReturn
DoCmdReturnOK	moveq	#0,d0
DoCmdReturn	move.w	d0,14(a6)		;Returncode setzen
		moveq	#6,d0
		bra	Return


*
* SCSIComplete: Ausstehenden Befehl abschließen
*

SCSIComplete	move.l	12(a6),a0		;VAR Message
		clr.w	(a0)

		moveq	#scPhaseErr,d0		;Vorgabe
		cmp.b	#phTransfer,scPhase(a5)	;Bus in Transfer Phase?
		bne	CompReturn		;Nein, Fehler

		tst.b	scCmdPending(a5)	;Befehl noch ausstehend?
		beq	CompNotPending

		move.l	scBytesInBuffer(a5),scsi_Length(a5) ;Ja, mit Puffer abschicken
		bsr	SCSISendIt		;Dies kann nur ein Write oder ein Befehl ohne Daten sein

		cmp.b	#HFERR_Phase,d1		;Phase Error?
		bne	CompReturnOK

CompNotPending	tst.b	scIsAutosense(a5)	;Autosense? Dann kein Phase Error
		bne	CompReturnOK
		tst.l	scBytesInBuffer(a5)	;Stehen noch Daten im Puffer?
		beq	CompReturnOK

		DPRINTF	" phase error"		;Ja, Completion Phase Error
		moveq	#scComplPhaseErr,d0
		bra	CompReturn
CompCommErr	moveq	#scCommErr,d0
		bra	CompReturn
CompReturnOK	moveq	#0,d0			;Alles OK
CompReturn	clr.w	scFakeStatus(a5)
		move.b	#phFree,scPhase(a5)	;Bus frei
		move.w	d0,20(a6)		;Returncode setzen

		move.l	16(a6),a0		;VAR Status
		moveq	#0,d0
		move.b	scsi_Status(a5),d0
		move.w	d0,(a0)			;Status setzen
		DPRINTF	"SCSIComplete status %08lx",d0

		moveq	#12,d0
		bra	Return	


*
* SCSIRead: Daten lesen
*

SCSIRead	cmp.b	#phTransfer,scPhase(a5)	;Get, Select und Cmd geschickt?
		bne	RWPhaseErr

		DPRINTF	"SCSIRead"

		tst.b	scCmdPending(a5)	;Befehl noch ausstehend?
		beq	ReadCmdSent

		clr.b	scCmdPending(a5)	;Ja, Befehl gleich schicken
		move.b	#SCSIF_READ|SCSIF_AUTOSENSE,scsi_Flags(a5)

		tst.w	SCSIDirect		;Direkten Transfer versuchen?
		beq	1$
		move.l	8(a6),a0		;Ja, Zeiger auf TIB
		bsr	AnalyzeTIB
		tst.l	d0			;Einfacher Transfer?
		bne	ReadWriteDirect		;Ja, direkt lesen

1$		move.l	8(a6),a0		;Zeiger auf TIB
		bsr	ScanTIB			;Datenlänge ermitteln
		DPRINTF	" buffered, %ld bytes",d0
		cmp.l	scBufferSize(a5),d0	;Paßt es in den Puffer?
		bls	ReadBufferFits

		bsr	TryNewBuffer		;Nein, neuen Puffer einrichten
		beq	ReadOverflow

ReadBufferFits	move.l	scBufferSize(a5),scsi_Length(a5) ;Soviel wie möglich lesen
		tst.w	FastCrapMode		;z3scsi.device sucks!
		beq	1$
		bsr	FastCrapFix
1$		bsr	SCSISendIt		;Mit Puffer abschicken
		move.l	scsi_Actual(a5),scBytesInBuffer(a5) ;Puffervariable setzen
		tst.b	d0			;Fehler aufgetreten?
		bne	RWCommErr

ReadCmdSent	move.l	8(a6),a0		;Zeiger auf TIB
		moveq	#0,d0			;Flag: Lesen aus Puffer
		bsr	ExecTIB			;TIB ausführen, Daten kopieren
		DPRINTF	" ExecTIB %08lx"
		bra	RWReturn

ReadOverflow	move.l	a6,-(sp)
		move.l	_IntuitionBase,a6
		sub.l	a0,a0
		lea	NoReadBufReq,a1
		sub.l	a2,a2
		sub.l	a3,a3
		EJSRLIB	EasyRequestArgs
		move.l	(sp)+,a6
		bra	RWCommErr


*
* SCSIWrite: Daten schreiben
*

SCSIWrite	cmp.b	#phTransfer,scPhase(a5)	;Get, Select und Cmd geschickt?
		bne	RWPhaseErr

		move.b	#SCSIF_WRITE|SCSIF_AUTOSENSE,scsi_Flags(a5)

		DPRINTF	"SCSIWrite"

		tst.w	SCSIDirect		;Direkten Transfer versuchen?
		beq	1$
		move.l	8(a6),a0		;Ja, Zeiger auf TIB
		bsr	AnalyzeTIB
		tst.l	d0			;Einfacher Transfer?
		bne	ReadWriteDirect		;Ja, direkt schreiben

1$		move.l	8(a6),a0		;Zeiger auf TIB
		bsr	ScanTIB			;Datenlänge ermitteln
		DPRINTF	" buffered, %ld bytes",d0
		cmp.l	scBufferSize(a5),d0	;Paßt es in den Puffer?
		bls	WriteBufferFits

		bsr	TryNewBuffer		;Nein, neuen Puffer einrichten
		beq	WriteOverflow

WriteBufferFits	move.l	8(a6),a0		;Zeiger auf TIB
		moveq	#-1,d0			;Flag: Schreiben in Puffer
		bsr	ExecTIB
		DPRINTF	" ExecTIB %08lx"
		bra	RWReturn

WriteOverflow	move.l	a6,-(sp)
		move.l	_IntuitionBase,a6
		sub.l	a0,a0
		lea	NoWriteBufReq,a1
		sub.l	a2,a2
		sub.l	a3,a3
		EJSRLIB	EasyRequestArgs
		move.l	(sp)+,a6
		bra	RWCommErr

ReadWriteDirect	DPRINTF	" direct, %ld bytes"
		clr.l	scBytesInBuffer(a5)	;Direkter Transfer ohne Puffer
		clr.b	scCmdPending(a5)	;Dies ist besonders für Write wichtig, denn sonst wird in Complete nochmal geschrieben
		move.l	scsi_Data(a5),-(sp)	;Alten Puffer merken
		move.l	d0,scsi_Length(a5)	;Länge setzen
		move.l	a0,scsi_Data(a5)
		move.l	d1,-(sp)		;Inc-Pointer retten
		bsr	SCSISendIt
		move.l	(sp)+,d1		;Inc-Pointer wiederherstellen
		move.l	(sp)+,scsi_Data(a5)	;Alten Puffer wiederherstellen
		tst.l	d1			;Inc?
		beq	1$
		move.l	d1,a0
		move.l	scsi_Actual(a5),d1
		add.l	d1,2(a0)		;Ja, Datenzeiger im Inc-Befehl erhöhen
1$		tst.b	d0			;Fehler aufgetreten?	
		bne	RWCommErr
		moveq	#0,d0			;Nein
		bra	RWReturn

RWPhaseErr	moveq	#scPhaseErr,d0
		bra	RWReturn
RWCommErr	moveq	#scCommErr,d0
RWReturn	move.w	#$006e,scFakeStatus(a5)
		move.w	d0,12(a6)		;Returncode setzen
		moveq	#4,d0
		bra	Return


*
* TIB (a0) scannen und Datenlänge ermitteln (-> d0)
* d0=0: Fehler
*
* Problem bei scLoop: Wir dürfen den Schleifenzähler nicht ändern,
*   denn der TIB wird noch gebraucht. Daher merkt sich diese Routine
*   die Position EINES scLoops und benutzt ein Datenregister als
*   Schleifenzähler
*

ScanTIB		movem.l	d2-d3/a3,-(sp)
		moveq	#0,d2		;Zähler für Datenlänge

		sub.l	a3,a3		;Position eines Loop-Befehls

ScanTIBMain	move.w	(a0),d0		;Befehl lesen
		move.l	2(a0),a1	;Zeiger auf Ziel
		move.l	6(a0),d1	;Anzahl Bytes

		cmp.w	#8,d0
		bhi	ScanTIBBad
		jmp	([ScanTIBTab,d0.w*4])

ScanTIBTab	dc.l	ScanTIBBad
		dc.l	ScanTIBInc
		dc.l	ScanTIBInc	;scNoInc
		dc.l	ScanTIBNext	;scAdd
		dc.l	ScanTIBNext	;scMove
		dc.l	ScanTIBLoop
		dc.l	ScanTIBNext	;scNop
		dc.l	ScanTIBStop
		dc.l	ScanTIBBad	;scComp

ScanTIBInc	add.l	d1,d2
		bra	ScanTIBNext

ScanTIBLoop	cmp.l	a0,a3		;Das erste Mal auf diesem Loop?
		beq	1$

		move.l	a3,d0		;Ja, vorige Schleife korrekt abgeschlossen?
		bne	ScanTIBBad
		move.l	a0,a3		;Ja, Adresse des Loop
		move.l	d1,d3		; und Schleifenzähler merken

1$		tst.l	d3		;Schleifenende?
		beq	2$
		subq.l	#1,d3		;Nein, Zähler erniedrigen
		beq	ScanTIBNext
		add.l	a1,a0		;Springen
		bra	ScanTIBMain

2$		sub.l	a3,a3		;Schleifenende
		bra	ScanTIBNext

ScanTIBNext	add.w	#10,a0
		bra	ScanTIBMain

ScanTIBStop	move.l	d2,d0
		movem.l	(sp)+,d2-d3/a3
		rts

ScanTIBBad	DPRINTF	" unrecognized TIB"
		moveq	#0,d0
		movem.l	(sp)+,d2-d3/a3
		rts


*
* TIB (a0) scannen und ermitteln, ob es ein einziger zusammenhängender
*  Transfer ist. Dies sind (ohne NOPs):
*   1. NoInc
*      Stop
*   2. Inc
*      Stop
*   3. Inc
*      Loop
*      Stop
*
* d0=0: Komplexer Transfer
* d0#0: Einfacher Transfer, d0 Länge, a0 Puffer, d1 Zeiger auf Inc-Befehl oder NIL
*

AnalyzeTIB	movem.l	d2/a2,-(sp)
		move.l	a0,a2		;a2: TIB
		moveq	#0,d0		;Vorgabe für Datenlänge
		moveq	#0,d1		;Vorgabe für Inc-Flag

; NOPs überspringen
ATIBNopLoop1	cmp.w	#7,(a2)		;Stop?
		beq	AnalyzeTIBDone
		cmp.w	#6,(a2)		;Nop?
		bne	ATIBNoNop1
		lea	10(a2),a2
		bra	ATIBNopLoop1

; Inc oder NoInc?
ATIBNoNop1	cmp.w	#1,(a2)		;Inc?
		beq	AnalyzeTIBInc
		cmp.w	#2,(a2)		;NoInc?
		bne	AnalyzeTIBDone

; NoInc: Jetzt darf nur noch Stop kommen
AnalyzeTIBNoInc	move.l	2(a2),a0	;Zeiger auf Daten
		move.l	6(a2),d0	; und Länge holen
		lea	10(a2),a2

; NOPs überspringen
ATIBNopLoop2	cmp.w	#7,(a2)		;Stop?
		beq	AnalyzeTIBDone
		cmp.w	#6,(a2)		;Nop?
		bne	AnalyzeTIBError
		lea	10(a2),a2
		bra	ATIBNopLoop2

; Inc: Jetzt kann entweder Stop oder Loop kommen
AnalyzeTIBInc	move.l	2(a2),a0	;Zeiger auf Daten
		move.l	6(a2),d0	; und Länge holen
		move.l	a2,d1		;Und Position des NoInc merken
		lea	10(a2),a2

; NOPs überspringen
ATIBNopLoop3	cmp.w	#7,(a2)		;Stop?
		beq	AnalyzeTIBDone
		cmp.w	#6,(a2)		;Nop?
		bne	ATIBNoNop3
		lea	10(a2),a2
		bra	ATIBNopLoop3

; Kein Stop, es darf nur ein (richtiges) Loop kommen
ATIBNoNop3	cmp.w	#5,(a2)		;Loop?
		bne	AnalyzeTIBError
		move.l	a2,d2		;Zeigt der Loop auf den Inc-Befehl?
		add.l	2(a2),d2
		cmp.l	d2,d1
		bne	AnalyzeTIBError		;a loop to anywhere else is no simple transfer
		mulu.l	6(a2),d0	;Ja, Datenlänge mit der Anzahl Durchläufe multiplizieren
		lea	10(a2),a2

; Jetzt darf nur noch Stop kommen
ATIBNopLoop4	cmp.w	#7,(a2)		;Stop?
		beq	AnalyzeTIBDone
		cmp.w	#6,(a2)		;Nop?
		bne	AnalyzeTIBError		;anything but Nop/Stop: no simple transfer
		lea	10(a2),a2
		bra	ATIBNopLoop4

; Alles klar
AnalyzeTIBDone	movem.l	(sp)+,d2/a2
		rts

; Fehler gefunden, kein einfacher Transfer
AnalyzeTIBError	moveq	#0,d0
		movem.l	(sp)+,d2/a2
		rts


*
* TIB (a0) ausführen, Daten kopieren (d0=0: Aus Puffer lesen, d0#0:
*   In Puffer schreiben)
* Rückgabe: Fehler (sc*)
*

ExecTIB		movem.l	d2-d3/a2-a4,-(sp)
		move.l	a0,a4		;a4: TIB
		move.l	d0,d3		;d3: Read/Write-Flag

ExecTIBMain	move.w	(a4),d0		;Befehl lesen
		move.l	2(a4),a2	;Zeiger auf Ziel
		move.l	6(a4),d2	;Anzahl Bytes

		cmp.w	#8,d0
		bhi	ExecTIBBadParam
		move.l	(ExecTIBTab,d0.w*4),a0
		jmp	(a0)

ExecTIBTab	dc.l	ExecTIBBadParam
		dc.l	ExecTIBInc
		dc.l	ExecTIBNoInc
		dc.l	ExecTIBAdd
		dc.l	ExecTIBMove
		dc.l	ExecTIBLoop
		dc.l	ExecTIBNext	;scNop
		dc.l	ExecTIBStop
		dc.l	ExecTIBComp

ExecTIBInc	add.l	d2,2(a4)
ExecTIBNoInc	tst.l	d3			;Flag: Lesen/Schreiben
		bne	ExecTIBWrite

		cmp.l	scBytesInBuffer(a5),d2	;Lesen: Gibt der Puffer noch genügend her?
		bhi	1$

		move.l	scBufferPtr(a5),a0	;Ja, Daten kopieren
		move.l	a2,a1
		move.l	d2,d0
		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		JSRLIB	CopyMem
		move.l	(sp)+,a6
		add.l	d2,scBufferPtr(a5)
		sub.l	d2,scBytesInBuffer(a5)
		bra	ExecTIBNext

1$		tst.l	scBytesInBuffer(a5)	;Nein, ist im Puffer überhaupt noch was drin?
		beq	2$

		move.l	scBufferPtr(a5),a0	;Ja, den Rest aus dem Puffer kopieren
		move.l	a2,a1
		move.l	scBytesInBuffer(a5),d0
		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		JSRLIB	CopyMem
		move.l	(sp)+,a6
		move.l	scBytesInBuffer(a5),d0
		add.l	d0,scBufferPtr(a5)
		clr.l	scBytesInBuffer(a5)
		add.l	d0,a2
		sub.l	d0,d2

2$		move.l	a2,a0			;Alles andere mit Nullen füllen
		bra	4$
3$		clr.b	(a0)+
4$		subq.l	#1,d2
		bpl	3$

		bra	ExecTIBNext

ExecTIBWrite	move.l	scBufferSize(a5),d0	;Schreiben: Paßt soviel noch in den Puffer?
		sub.l	scBytesInBuffer(a5),d0
		cmp.l	d0,d2
		bhi	ExecTIBOver

		move.l	a2,a0			;Ja, Daten kopieren
		move.l	scBufferPtr(a5),a1
		move.l	d2,d0
		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		JSRLIB	CopyMem
		move.l	(sp)+,a6
		add.l	d2,scBufferPtr(a5)
		add.l	d2,scBytesInBuffer(a5)
		bra	ExecTIBNext

ExecTIBAdd	add.l	d2,(a2)
		bra	ExecTIBNext

ExecTIBMove	move.l	d2,a0
		move.l	(a2),(a0)
		bra	ExecTIBNext

ExecTIBLoop	tst.l	d2		;Schleifenende?
		beq	ExecTIBNext
		subq.l	#1,d2		;Nein, Zähler verringern
		move.l	d2,6(a4)
		beq	ExecTIBNext
		add.l	a2,a4		;Springen
		bra	ExecTIBMain

ExecTIBNext	add.w	#10,a4
		bra	ExecTIBMain

ExecTIBStop	movem.l	(sp)+,d2-d3/a2-a4
		moveq	#0,d0		;Alles OK
		rts

ExecTIBComp	move.l	a6,-(sp)
		move.l	_IntuitionBase,a6
		sub.l	a0,a0
		lea	TIBCompReq,a1
		sub.l	a2,a2
		sub.l	a3,a3
		EJSRLIB	EasyRequestArgs
		move.l	(sp)+,a6
		bra	ExecTIBBadParam

ExecTIBOver	move.l	a6,-(sp)
		move.l	_IntuitionBase,a6
		sub.l	a0,a0
		lea	WriteBufOvflReq,a1
		sub.l	a2,a2
		sub.l	a3,a3
		EJSRLIB	EasyRequestArgs
		move.l	(sp)+,a6
ExecTIBBadParam	movem.l	(sp)+,d2-d3/a2-a4
		moveq	#scBadParmsErr,d0
		rts


*
* SCSIStat: Zustand des Bus übermitteln
*

SCSIStat	move.w	scFakeStatus(a5),8(a6)
		DPRINTF	"SCSIStat %08lx",8(a6)
		bra	ReturnZero


*
* SCSIMsgIn: Nachricht lesen
*

SCSIMsgIn	clr.w	12(a6)		;Alles OK
		DPRINTF	"SCSIMsgIn"
		moveq	#4,d0
		bra	Return


*
* SCSIMsgOut: Nachricht schreiben
*

SCSIMsgOut	clr.w	10(a6)		;Alles OK
		DPRINTF	"SCSIMsgOut"
		moveq	#2,d0
		bra	Return


*
* SCSIMgrBusy: SCSI Manager frei?
*

SCSIMgrBusy	cmp.b	#phFree,scPhase(a5)	;Bus frei?
		bne	1$
		clr.w	8(a6)			;Ja
		bra	ReturnZero
1$		move.w	#1,8(a6)		;Nein
		bra	ReturnZero


*
* SCSI-Befehl an das Device schicken, alle Parameter müssen gesetzt sein
* Rückgabe: d0: Status
*           d1: IO_ERROR
*

SCSISendIt	clr.w	scsi_SenseActual(a5)
		clr.l	scsi_Actual(a5)

		move.w	scTargetID(a5),d0	;Festplatte ausgewählt?
		lsl.w	#3,d0
		add.w	scTargetLUN(a5),d0
		tst.b	scDeviceClass(a5,d0.w)
		bne	1$
		tst.w	AppleHD			;Ja, AppleHD-Emulation?
		beq	1$

		move.l	scCmdBuffer(a5),a0	;Ja, Mode Select mit 24 Bytes?
		cmp.l	#$15010000,(a0)
		bne	1$
		cmp.w	#$1800,4(a0)
		bne	1$
		move.l	scBuffer(a5),a0		;Ja, Page 0?
		cmp.l	#$00021000,12(a0)
		bne	1$

		move.l	#$18,scsi_Actual(a5)	;Ja, faken
		moveq	#0,d0
		move.b	d0,scsi_Status(a5)
		moveq	#0,d1
		rts

1$		move.l	scTheRequest(a5),a1
		move.l	a6,-(sp)
		move.l	_ExecBase,a6
	;	DPRINTF	" scsi_Length %08lx",scsi_Length(a5)
		EJSRLIB	DoIO
	;	DPRINTF	" scsi_Actual %08lx",scsi_Actual(a5)
		move.l	(sp)+,a6
		move.b	scsi_Status(a5),d0
		move.l	scTheRequest(a5),a1
		move.b	IO_ERROR(a1),d1
		rts


*
* Neuen Puffer einrichten
* d0: Gewünschte Größe
* Rückgabe: beq Fehlgeschlagen
*           bne Gelungen
*

TryNewBuffer	movem.l	d2-d3/a6,-(sp)

		move.l	_ExecBase,a6
		move.l	d0,d3			;d3: Größe des neuen Puffers
		move.l	scBufMemType(a5),d1
		EJSRLIB	AllocMem
		move.l	d0,d2			;d2: Zeiger auf neuen Puffer
		beq	NoNewBuffer

		move.l	scBuffer(a5),a0		;Daten aus altem Puffer kopieren, solange es ihn gibt
		move.l	d2,a1
		move.l	scBytesInBuffer(a5),d0
		JSRLIB	CopyMem

		move.l	scBuffer(a5),a1
		move.l	d2,scBuffer(a5)
		move.l	a1,d2			;d2: Zeiger auf alten Puffer
		move.l	scBufferSize(a5),d0
		move.l	d3,scBufferSize(a5)
		EJSRLIB	FreeMem

		move.l	scBufferPtr(a5),d0	;Pufferzeiger korrigieren
		sub.l	d2,d0
		add.l	scBuffer(a5),d0
		move.l	d0,scBufferPtr(a5)

		movem.l	(sp)+,d2-d3/a6
		moveq	#-1,d1
		rts

NoNewBuffer	movem.l	(sp)+,d2-d3/a6
		moveq	#0,d1
		rts


*
* scsi_Length berechnen (Workaround für z3scsi.device-Bug)
*

FastCrapFix	move.l	scCmdBuffer(a5),a0	;Befehl testen
		cmp.b	#$08,(a0)		;Read(6)?
		beq	FCFRead6
		cmp.b	#$28,(a0)		;Read(10)?
		beq	FCFRead10
		rts

FCFRead6	move.w	scTargetID(a5),d0	;Geräteklasse testen
		lsl.w	#3,d0
		add.w	scTargetLUN(a5),d0
		tst.b	scDeviceClass(a5,d0.w)	;Festplatte?
		beq	FCF6Harddisk
		cmp.b	#5,scDeviceClass(a5,d0.w) ;CD-ROM?
		beq	FCF6CDROM
		rts

FCF6Harddisk	moveq	#0,d0
		move.b	4(a0),d0		;Anzahl Blocks extrahieren
		mulu.w	#512,d0			;in Anzahl Bytes umrechnen
		move.l	d0,scsi_Length(a5)
		rts

FCF6CDROM	moveq	#0,d0
		move.b	4(a0),d0		;Anzahl Blocks extrahieren
		mulu.w	#2048,d0		;in Anzahl Bytes umrechnen
		move.l	d0,scsi_Length(a5)
		rts

FCFRead10	move.w	scTargetID(a5),d0	;Geräteklasse testen
		lsl.w	#3,d0
		add.w	scTargetLUN(a5),d0
		tst.b	scDeviceClass(a5,d0.w)	;Festplatte?
		beq	FCF10Harddisk
		cmp.b	#5,scDeviceClass(a5,d0.w) ;CD-ROM?
		beq	FCF10CDROM
		rts

FCF10Harddisk	move.w	7(a0),d0		;Anzahl Blocks extrahieren
		mulu.w	#512,d0			;in Anzahl Bytes umrechnen
		move.l	d0,scsi_Length(a5)
		rts

FCF10CDROM	move.w	7(a0),d0		;Anzahl Blocks extrahieren
		mulu.w	#2048,d0		;in Anzahl Bytes umrechnen
		move.l	d0,scsi_Length(a5)
		rts


**
** .AppleCD-Treiber
**

; Laufwerksnummer
CDDriveNum	= 7


*
* Installation
*

; CD-Treiber installieren?
InstallAppleCD	tst.w	AppleCD
		beq	5$

; Ja, erstes CD-ROM-Laufwerk suchen
		move.l	a5,-(sp)
		lea	BssSection,a5
		moveq	#0,d0
1$		move.l	d0,d1
		lsl.l	#3,d1
		cmp.b	#5,scDeviceClass(a5,d1.l)
		bne	2$
		move.w	d0,cdTargetID(a5)	;Gefunden, ID merken
		move.l	scRequests(a5,d1.l*4),cdRequest(a5)
		move.b	#'0',d1
		add.b	d0,d1
		move.b	d1,CDIconID
		move.w	#CDROMRefNum,cdRefNum(a5)
		bra	3$
2$		addq.l	#1,d0
		cmp.b	#7,d0
		bne	1$
		bra	4$
3$

; Treiber installieren
		move.l	a0,-(sp)
		lea	CDHeader,a0
		move.w	cdRefNum(a5),d0
		ext.l	d0
		dc.w	$a43d		;DrvrInstallRsrvMem

; Zeiger auf Treiber holen
		move.l	$11c,a0		;UTableBase
		move.w	cdRefNum(a5),d0
		addq.w	#1,d0
		neg.w	d0
		move.l	(a0,d0.w*4),a0
		move.l	(a0),a2
		dc.w	$a029		;HLock

; Daten kopieren
		lea	CDHeader,a0
		move.l	a0,(a2)
		move.w	(a0)+,dCtlFlags(a2)
		move.w	(a0),dCtlDelay(a2)

; Treiber öffnen
		move.l	(sp)+,a0
		move.l	#CDName,ioNamePtr(a0)
		dc.w	$a000		;Open
4$		move.l	(sp)+,a5
5$		rts


*
* Driver Header
*

CDHeader	dc.w	$6d04		;Flags
		dc.w	120,0,0		;Delay, EMask, Menu
		dc.w	CDOpen-CDHeader
		dc.w	CDPrime-CDHeader
		dc.w	CDControl-CDHeader
		dc.w	CDStatus-CDHeader
		dc.w	CDClose-CDHeader
CDName		dc.b	8,".AppleCD"
		EVEN


*
* Open()-Routine
*

CDOpen		movem.l	a0-a1/a5,-(sp)
		lea	BssSection,a5

; Variablen initialisieren
		move.l	a1,cdDCE(a5)
		st.b	cdAlwaysPostEvent(a5)
		move.b	#%1001,cdPlayMode(a5)	;Stereo
		move.w	#-1,cd2KOffset(a5)
		move.w	#512,cdBlockSize(a5)

; Laufwerk installieren
		lea	cdDriveStatus(a5),a2
		st.b	dsWriteProt(a2)
		move.b	#1,dsInstalled(a2)
		move.b	#1,dsSides(a2)
		move.w	#1,dsQType(a2)		;HD20

		clr.b	dsDiskInPlace(a2)	;Default: Keine CD eingelegt
		clr.b	cdToBeMounted(a5)
		clr.l	dsDriveSize(a2)

		bsr	CDIsDiskInDrive		;CD eingelegt?
		tst.b	d0
		bne	1$

		move.b	#1,dsDiskInPlace(a2)

		bsr	CDLock			;Laufwerk sperren
		bsr	CDReadCapacity		;dsDriveSize setzen (Default, falls keine HFS-Partition)
		bsr	CDReadTOC		;TOC lesen
		bsr	CDFindHFS		;HFS-Partition suchen
		st.b	cdToBeMounted(a5)

1$		move.w	#CDDriveNum,dsDriveType(a2)
		move.w	#CDDriveNum,d0
		swap	d0
		move.w	cdRefNum(a5),d0
		lea	dsQLink(a2),a0
		dc.w	$a04e			;AddDrive

		moveq	#0,d0
		movem.l	(sp)+,a0-a1/a5
		rts


*
* Close()-Routine
*

CDClose		moveq	#-24,d0		;Close error
		rts


*
* Prime()-Routine
*

CDPrime		movem.l	a0-a1/a5,-(sp)
		lea	BssSection,a5

; CD eingelegt?
		tst.b	cdDriveStatus+dsDiskInPlace(a5)
		beq	IOOffLine

; Ja, Lesen?
		move.l	a0,cdIOParam(a5)
		cmp.b	#aWrCmd,ioTrap+1(a0)
		beq	IOWriteProt

; Ja, PreRead notwendig?
		move.l	ioReqCount(a0),d3	;d3: Rest-Datenlänge
		move.l	ioBuffer(a0),a3		;a3: Zielpuffer

		move.l	dCtlPosition(a1),d0
		add.l	cdStartByte(a5),d0
		and.l	#2047,d0
		move.w	d0,cd2KOffset(a5)
		beq	CDPrimeMain

; Ja, PreRead durchführen
CDPrimePre	move.l	#2048,scsi_Length(a5)	;1 Block lesen
		move.l	scCmdBuffer(a5),a0
		move.w	#$2800,(a0)		;Read(10)
		move.l	dCtlPosition(a1),d0
		add.l	cdStartByte(a5),d0
		lsr.l	#8,d0
		lsr.l	#3,d0
		move.l	d0,2(a0)
		clr.b	6(a0)
		move.w	#1,7(a0)
		clr.b	9(a0)
		move.w	#10,scsi_CmdLength(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bsr	CDSCSISendIt
		tst.b	d0
		bne	CDPrimeErr

		move.l	scsi_Data(a5),a0	;Daten in Zielpuffer kopieren
		move.l	cdDCE(a5),a2
		move.l	dCtlPosition(a2),d1
		add.l	cdStartByte(a5),d1
		and.l	#2047,d1
		add.l	d1,a0			;a0: Quelle
		move.l	a3,a1			;a1: Ziel
		move.l	#2048,d0
		sub.l	d1,d0
		cmp.l	d3,d0
		bls	1$
		move.l	d3,d0			;d0: Länge
1$		sub.l	d0,d3			;Restlänge
		add.l	d0,a3			;und Zielpufferzeiger korrigieren
		add.l	d0,dCtlPosition(a2)
		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		JSRLIB	CopyMem
		move.l	(sp)+,a6

; MainRead durchführen
CDPrimeMain	move.l	d3,d1
		and.l	#~2047,d1
		beq	CDPrimePost

		move.l	d1,scsi_Length(a5)
		move.l	scsi_Data(a5),-(sp)	;Alten Puffer merken
		move.l	a3,scsi_Data(a5)
		move.l	scCmdBuffer(a5),a0
		move.w	#$2800,(a0)		;Read(10)
		move.l	cdDCE(a5),a1
		move.l	dCtlPosition(a1),d0
		add.l	cdStartByte(a5),d0
		lsr.l	#8,d0
		lsr.l	#3,d0
		move.l	d0,2(a0)
		clr.b	6(a0)
		lsr.l	#8,d1
		lsr.l	#3,d1
		move.w	d1,7(a0)
		clr.b	9(a0)
		move.w	#10,scsi_CmdLength(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bsr	CDSCSISendIt
		move.l	(sp)+,scsi_Data(a5)	;Alten Puffer wiederherstellen
		tst.b	d0
		bne	CDPrimeErr

		move.l	d3,d0
		and.l	#~2047,d0
		sub.l	d0,d3			;Restlänge
		add.l	d0,a3			;und Zielpufferzeiger korrigieren
		move.l	cdDCE(a5),a1
		add.l	d0,dCtlPosition(a1)

; PostRead durchführen
CDPrimePost	tst.l	d3
		beq	CDPrimeDone

		move.l	#2048,scsi_Length(a5)	;1 Block lesen
		move.l	scCmdBuffer(a5),a0
		move.w	#$2800,(a0)		;Read(10)
		move.l	cdDCE(a5),a1
		move.l	dCtlPosition(a1),d0
		add.l	cdStartByte(a5),d0
		lsr.l	#8,d0
		lsr.l	#3,d0
		move.l	d0,2(a0)
		clr.b	6(a0)
		move.w	#1,7(a0)
		clr.b	9(a0)
		move.w	#10,scsi_CmdLength(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bsr	CDSCSISendIt
		tst.b	d0
		bne	CDPrimeErr

		move.l	cdDCE(a5),a2		;Daten in Zielpuffer kopieren
		move.l	scsi_Data(a5),a0	;a0: Quelle
		move.l	a3,a1			;a1: Ziel
		move.l	d3,d0			;d0: Länge
		add.l	d0,dCtlPosition(a2)
		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		JSRLIB	CopyMem
		move.l	(sp)+,a6

; Fertig
CDPrimeDone	move.l	cdIOParam(a5),a0
		move.l	ioReqCount(a0),ioActCount(a0)
		bra	IOReturnOK

; Fehler beim Lesen
; Wurde versucht, den Rootblock zu lesen?
CDPrimeErr	move.l	cdDCE(a5),a1
		cmp.l	#$400,dCtlPosition(a1)
		bne	IOReadErr
		move.l	cdIOParam(a5),a0
		cmp.l	#$200,ioReqCount(a0)
		bne	IOReadErr

; Ja, faken (sonst werden Audio-CDs nicht gemountet)
		move.l	#$200,d0
		move.l	d0,ioActCount(a0)
		add.l	d0,dCtlPosition(a1)
		move.l	ioBuffer(a0),a0
		moveq	#$200/4-1,d0
1$		clr.l	(a0)+
		dbra	d0,1$
		bra	IOReturnOK


*
* Control()-Routine
*

CDControl	movem.l	a0-a1/a5,-(sp)
		lea	BssSection,a5
		lea	cdDriveStatus(a5),a2
		move.l	a0,cdIOParam(a5)
		DPRINTF	"CDControl %08lx",csCode(a0)

; Control-Code abfragen
; 1: KillIO
		cmp.w	#killCode,csCode(a0)
		bne	ControlNot1

		moveq	#0,d0
		movem.l	(sp)+,a0-a1/a5
		rts

; 5: Verify Disk
ControlNot1	cmp.w	#5,csCode(a0)
		bne	ControlNot5

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine
		bra	IOReturnOK

; 7: Eject Disk
ControlNot5	cmp.w	#7,csCode(a0)
		bne	ControlNot7

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine
		clr.b	dsDiskInPlace(a2)
		move.w	#-1,cd2KOffset(a5)
		bsr	CDEject
		bra	IOReturnOK

; 21: Get Drive Icon
ControlNot7	cmp.w	#21,csCode(a0)
		bne	ControlNot21

		move.l	#CDIcon,csParam(a0)
		bra	IOReturnOK

; 22: Get Media Icon
ControlNot21	cmp.w	#22,csCode(a0)
		bne	ControlNot22

		move.l	#CDIcon,csParam(a0)
		bra	IOReturnOK

; 23: Drive Info
ControlNot22	cmp.w	#23,csCode(a0)
		bne	ControlNot23

		move.l	#$00000b01,csParam(a0)	;External, Removable, SCSI
		bra	IOReturnOK

; 65: Make Periodic Action
ControlNot23	cmp.w	#accRun,csCode(a0)
		bne	ControlNot65

		tst.b	cdToBeMounted(a5)
		bne	2$

		tst.b	dsDiskInPlace(a2)
		bne	IOReturnOK

2$		cmp.b	#phFree,scPhase(a5)	;SCSI-Bus frei?
		bne	IOReturnOK

		clr.b	cdToBeMounted(a5)

		bsr	CDIsDiskInDrive		;Ja, CD eingelegt?
		tst.b	d0
		bne	IOReturnOK

		move.b	#1,dsDiskInPlace(a2)	;Ja

		bsr	CDLock			;Laufwerk sperren
		bsr	CDReadCapacity		;dsDriveSize setzen (Default, falls keine HFS-Partition)
		bsr	CDReadTOC		;TOC lesen
		bsr	CDFindHFS		;HFS-Partition suchen

		tst.l	cdStartByte(a5)		;HFS-Partition gefunden?
		bne	1$
		tst.b	cdAlwaysPostEvent(a5)	;Nein, trotzdem diskEvent posten?
		beq	IOReturnOK

1$		moveq	#CDDriveNum,d0		;Drive Number
		move.w	#7,a0			;diskEvent
		dc.w	$a02f			;PostEvent
		bra	IOReturnOK

; 76: Modify PostEvent
ControlNot65	cmp.w	#76,csCode(a0)
		bne	ControlNot76

		move.b	csParam+1(a0),cdAlwaysPostEvent(a5)
		bra	IOReturnOK

; 79: Change Block Size
ControlNot76	cmp.w	#79,csCode(a0)
		bne	ControlNot79

		move.w	csParam(a0),d0		;Nur Blockgrößen von 512, 1024 oder 2048 Byte zulassen
		cmp.w	#512,d0
		beq	1$
		cmp.w	#1024,d0
		beq	1$
		cmp.w	#2048,d0
		beq	1$
		bra	IOParamErr

1$		move.w	d0,cdBlockSize(a5)
		bra	IOReturnOK

; 80: User Eject
ControlNot79	cmp.w	#80,csCode(a0)
		bne	ControlNot80

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine

		cmp.w	#1,csParam(a0)
		bne	1$
		bsr	CDUnlock
		bra	IOReturnOK
1$		bsr	CDLock
		bra	IOReturnOK

; 81: Set PollFreq
ControlNot80	cmp.w	#81,csCode(a0)
		bne	ControlNot81

		move.w	csParam(a0),dCtlDelay(a1)
		bra	IOReturnOK

; 100: Read TOC
ControlNot81	cmp.w	#100,csCode(a0)
		bne	ControlNot100

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine

		cmp.w	#1,csParam(a0)		;Get first and last track number?
		bne	1$

		lea	cdTOC+2(a5),a1
		lea	ToBCDTab,a2
		moveq	#0,d0
		move.b	(a1),d0			;First track
		move.b	(a2,d0.l),csParam(a0)
		move.b	1(a1),d0		;Last track
		move.b	(a2,d0.l),csParam+1(a0)
		clr.w	csParam+2(a0)
		bra	IOReturnOK

1$		cmp.w	#2,csParam(a0)		;Get Lead Out MSF starting address?
		bne	2$

		lea	cdLeadOutMSF(a5),a1
		lea	ToBCDTab,a2
		moveq	#0,d0
		move.b	1(a1),d0		;M
		move.b	(a2,d0.l),csParam(a0)
		move.b	2(a1),d0		;S
		move.b	(a2,d0.l),csParam+1(a0)
		move.b	3(a1),d0		;F
		move.b	(a2,d0.l),csParam+2(a0)
		clr.b	csParam+3(a0)
		bra	IOReturnOK

2$		cmp.w	#3,csParam(a0)		;Get track starting addresses?
		bne	IOParamErr

		moveq	#0,d1			;Starttrack in binär umrechnen
		move.b	csParam+8(a0),d1
		lea	FromBCDTab,a2
		move.b	(a2,d1.l),d1

		lea	cdTOC+4(a5),a1		;Starttrack in TOC suchen
		moveq	#99,d0
21$		cmp.b	2(a1),d1
		bls	22$
		lea	8(a1),a1
		dbra	d0,21$
		bra	IOReturnOK

22$		move.w	csParam+6(a0),d1	;d1: Pufferlänge
		move.l	csParam+2(a0),a0	;a0: Zielpuffer
		lea	ToBCDTab,a2

23$		subq.w	#4,d1			;Puffer zu Ende?
		bmi	IOReturnOK

		move.b	1(a1),d0		;Control
		and.b	#$0f,d0
		move.b	d0,(a0)
		moveq	#0,d0
		move.b	5(a1),d0		;M
		move.b	(a2,d0.l),1(a0)
		move.b	6(a1),d0		;S
		move.b	(a2,d0.l),2(a0)
		move.b	7(a1),d0		;F
		move.b	(a2,d0.l),3(a0)

		cmp.b	#$aa,2(a1)		;Lead Out erreicht?
		beq	IOReturnOK

		lea	4(a0),a0
		lea	8(a1),a1
		bra	23$

; 101: Read Q
ControlNot100	cmp.w	#101,csCode(a0)
		bne	ControlNot101

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine

		bsr	CDReadPosition
		tst.b	d0
		bne	IOControlErr

		move.l	cdIOParam(a5),a0
		move.l	scsi_Data(a5),a1
		lea	ToBCDTab,a2
		move.b	5(a1),d0		;Control
		and.b	#$0f,d0
		move.b	d0,csParam(a0)
		moveq	#0,d0
		move.b	6(a1),d0		;Track number
		move.b	(a2,d0.l),csParam+1(a0)
		move.b	7(a1),d0,
		move.b	(a2,d0.l),csParam+2(a0)	;Index number
		move.b	13(a1),d0		;M (relativ)
		move.b	(a2,d0.l),csParam+3(a0)
		move.b	14(a1),d0		;S
		move.b	(a2,d0.l),csParam+4(a0)
		move.b	15(a1),d0		;F
		move.b	(a2,d0.l),csParam+5(a0)
		move.b	9(a1),d0		;M (absolut)
		move.b	(a2,d0.l),csParam+6(a0)
		move.b	10(a1),d0		;S
		move.b	(a2,d0.l),csParam+7(a0)
		move.b	11(a1),d0		;F
		move.b	(a2,d0.l),csParam+8(a0)
		bra	IOReturnOK

; 102: Read Header
ControlNot101	cmp.w	#102,csCode(a0)
		bne	ControlNot102

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine

		move.l	csParam(a0),d0		;LBA
		move.l	scCmdBuffer(a5),a0
		move.w	#$4402,(a0)		;Read Header MSF
		move.l	d0,2(a0)
		move.l	#$00000800,6(a0)
		move.w	#10,scsi_CmdLength(a5)
		move.l	#8,scsi_Length(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bsr	CDSCSISendIt
		tst.b	d0
		bne	IOParamErr		;Audio Track

		move.l	cdIOParam(a5),a0
		move.l	scsi_Data(a5),a1
		lea	ToBCDTab,a2
		moveq	#0,d0
		move.b	5(a1),d0		;M
		move.b	(a2,d0.l),csParam(a0)
		move.b	6(a1),d0		;S
		move.b	(a2,d0.l),csParam+1(a0)
		move.b	7(a1),d0		;F
		move.b	(a2,d0.l),csParam+2(a0)
		move.b	(a1),csParam+3(a0)	;Data Mode
		bra	IOReturnOK

; 103: Audio Track Search
ControlNot102	cmp.w	#103,csCode(a0)
		bne	ControlNot103

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine

		cmp.w	#2,csParam(a0)		;Track positioning type? (!!)
		bne	IOParamErr

		;!! Play mode, hold track

		moveq	#0,d0			;Starttrack in binär umrechnen
		move.b	csParam+5(a0),d0
		lea	FromBCDTab,a2
		move.b	(a2,d0.l),d0

		move.l	scCmdBuffer(a5),a0
		move.l	#$48000000,(a0)		;Play Audio Track/Index
		move.b	d0,4(a0)
		move.b	#1,5(a0)
		clr.b	6(a0)
		move.b	#99,7(a0)
		move.b	#1,8(a0)
		clr.b	9(a0)
		move.w	#10,scsi_CmdLength(a5)
		clr.l	scsi_Length(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bsr	CDSCSISendIt
		bra	IOReturnOK

; 104: Audio Play
ControlNot103	cmp.w	#104,csCode(a0)
		bne	ControlNot104

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine

		cmp.w	#2,csParam(a0)		;Track positioning type? (!!)
		bne	IOParamErr

		tst.w	csParam+6(a0)		;Starting address?
		bne	IOControlErr		;!!

		;!! Play mode

		moveq	#0,d0			;Starttrack in binär umrechnen
		move.b	csParam+5(a0),d0
		lea	FromBCDTab,a2
		move.b	(a2,d0.l),d0

		move.l	scCmdBuffer(a5),a0
		move.l	#$48000000,(a0)		;Play Audio Track/Index
		move.b	d0,4(a0)
		move.b	#1,5(a0)
		clr.b	6(a0)
		move.b	#99,7(a0)
		move.b	#1,8(a0)
		clr.b	9(a0)
		move.w	#10,scsi_CmdLength(a5)
		clr.l	scsi_Length(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bsr	CDSCSISendIt
		bra	IOReturnOK

; 105: Audio Pause
ControlNot104	cmp.w	#105,csCode(a0)
		bne	ControlNot105

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine

		move.l	csParam(a0),d0
		beq	1$
		cmp.l	#1,d0
		bne	IOParamErr

		move.l	scCmdBuffer(a5),a0
		move.l	#$4b000000,(a0)		;Pause
		clr.l	4(a0)
		move.w	#$0000,8(a0)
		move.w	#10,scsi_CmdLength(a5)
		clr.l	scsi_Length(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bsr	CDSCSISendIt
		tst.b	d0
		bne	IOControlErr
		bra	IOReturnOK

1$		move.l	scCmdBuffer(a5),a0
		move.l	#$4b000000,(a0)		;Resume
		clr.l	4(a0)
		move.w	#$0100,8(a0)
		move.w	#10,scsi_CmdLength(a5)
		clr.l	scsi_Length(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bsr	CDSCSISendIt
		tst.b	d0
		bne	IOControlErr
		bra	IOReturnOK

; 106: Audio Stop
ControlNot105	cmp.w	#106,csCode(a0)
		bne	ControlNot106

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine

		cmp.w	#2,csParam(a0)		;!!
		beq	IOReturnOK

		move.l	scCmdBuffer(a5),a0	;1 Frame des Lead-Out spielen
		move.w	#$4700,(a0)		;Play Audio MSF
		clr.b	2(a0)
		move.b	cdLeadOutMSF+1(a5),d0
		move.b	cdLeadOutMSF+2(a5),d1
		move.b	cdLeadOutMSF+3(a5),d2
		move.b	d0,3(a0)
		move.b	d1,4(a0)
		move.b	d2,5(a0)
		addq.b	#1,d2			;Endadresse ist 1 Frame höher
		cmp.b	#75,d2
		blo	11$
		moveq	#0,d2
		addq.b	#1,d1
		cmp.b	#60,d1
		blo	11$
		moveq	#0,d1
		addq.b	#1,d0
11$		move.b	d0,6(a0)
		move.b	d1,7(a0)
		move.b	d2,8(a0)
		clr.b	9(a0)
		move.w	#10,scsi_CmdLength(a5)
		clr.l	scsi_Length(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bsr	CDSCSISendIt
		bra	IOReturnOK

; 107: Audio Status
ControlNot106	cmp.w	#107,csCode(a0)
		bne	ControlNot107

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine

		bsr	CDReadPosition
		tst.b	d0
		bne	IOControlErr

		move.l	cdIOParam(a5),a0
		move.l	scsi_Data(a5),a1
		lea	ToBCDTab,a2

		move.b	1(a1),d0		;Audio Status
		cmp.b	#$11,d0
		bne	1$
		move.b	#0,csParam(a0)		;Audio play in progress
		bra	5$
1$		cmp.b	#$12,d0
		bne	2$
		move.b	#1,csParam(a0)		;Audio play paused
		bra	5$
2$		cmp.b	#$13,d0
		bne	3$
		move.b	#3,csParam(a0)		;Audio play completed
		bra	5$
3$		cmp.b	#$14,d0
		bne	4$
		move.b	#4,csParam(a0)		;Error occurred
		bra	5$
4$		move.b	#5,csParam(a0)		;No audio play operation requested
5$
		move.b	cdPlayMode(a5),csParam+1(a0)
		move.b	5(a1),d0		;Control
		and.b	#$0f,d0
		move.b	d0,csParam+2(a0)
		moveq	#0,d0
		move.b	9(a1),d0		;M
		move.b	(a2,d0.l),csParam+3(a0)
		move.b	10(a1),d0		;S
		move.b	(a2,d0.l),csParam+4(a0)
		move.b	11(a1),d0		;F
		move.b	(a2,d0.l),csParam+5(a0)
		bra	IOReturnOK

; 109: Audio Control
ControlNot107	cmp.w	#109,csCode(a0)
		bne	ControlNot109

		move.l	scCmdBuffer(a5),a0
		move.l	#$1a080e00,(a0)		;Mode Sense DBD, CD-ROM Audio Page
		move.w	#$1400,4(a0)
		move.w	#6,scsi_CmdLength(a5)
		move.l	#20,scsi_Length(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bsr	CDSCSISendIt
		tst.b	d0
		bne	IOErr

		move.l	cdIOParam(a5),a0
		move.l	scsi_Data(a5),a1
		move.b	#$04,6(a1)		;Immed
		clr.l	8(a1)
		move.b	csParam(a0),13(a1)	;Links
		move.b	csParam+1(a0),15(a1)	;Rechts

		move.l	scCmdBuffer(a5),a0
		move.l	#$15100000,(a0)		;Mode Select, CD-ROM Audio Page
		move.w	#$1400,4(a0)
		move.w	#6,scsi_CmdLength(a5)
		move.l	#20,scsi_Length(a5)
		move.b	#SCSIF_WRITE,scsi_Flags(a5)
		bsr	CDSCSISendIt
		tst.b	d0
		bne	IOErr
		bra	IOReturnOK

; 110: Read MCN
ControlNot109	cmp.w	#110,csCode(a0)
		bne	ControlNot110

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine

		move.l	scCmdBuffer(a5),a0
		move.l	#$42004002,(a0)		;Read Sub-Channel MCN
		clr.l	4(a0)
		move.w	#$1800,8(a0)
		move.w	#10,scsi_CmdLength(a5)
		move.l	#24,scsi_Length(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bsr	CDSCSISendIt
		tst.b	d0
		bne	IOControlErr

		move.l	cdIOParam(a5),a0
		move.l	scsi_Data(a5),a1
		tst.b	8(a1)
		bmi	1$
		clr.b	csParam(a0)		;Keine MCN gefunden
		bra	IOReturnOK
1$		move.l	8(a1),csParam(a0)
		move.l	12(a1),csParam+4(a0)
		move.l	16(a1),csParam+8(a0)
		move.l	20(a1),csParam+12(a0)
		;!! Pascal string length
		bra	IOReturnOK

; 111: Read ISRC
ControlNot110	cmp.w	#111,csCode(a0)
		bne	ControlNot111

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine

		moveq	#0,d0			;Track in binär umrechnen
		move.b	csParam+1(a0),d0	;(!! oder csParam?)
		lea	FromBCDTab,a2
		move.b	(a2,d0.l),d0

		move.l	scCmdBuffer(a5),a0
		move.l	#$42004003,(a0)		;Read Sub-Channel ISRC
		clr.l	4(a0)
		move.b	d0,6(a0)
		move.w	#$1800,8(a0)
		move.w	#10,scsi_CmdLength(a5)
		move.l	#24,scsi_Length(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bsr	CDSCSISendIt
		tst.b	d0
		bne	IOControlErr

		move.l	cdIOParam(a5),a0
		move.l	scsi_Data(a5),a1
		tst.b	8(a1)
		bmi	1$
		clr.b	csParam(a0)		;Keinen ISRC gefunden
		bra	IOReturnOK
1$		move.l	8(a1),csParam(a0)
		move.l	12(a1),csParam+4(a0)
		move.l	16(a1),csParam+8(a0)
		move.l	20(a1),csParam+12(a0)
		;!! Pascal string length
		bra	IOReturnOK

; 112: Read Audio Volume
ControlNot111	cmp.w	#112,csCode(a0)
		bne	ControlNot112

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine

		move.l	scCmdBuffer(a5),a0
		move.l	#$1a080e00,(a0)		;Mode Sense DBD, CD-ROM Audio Page
		move.w	#$1400,4(a0)
		move.w	#6,scsi_CmdLength(a5)
		move.l	#20,scsi_Length(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bsr	CDSCSISendIt
		tst.b	d0
		bne	IOErr

		move.l	cdIOParam(a5),a0
		move.l	scsi_Data(a5),a1
		move.b	13(a1),csParam(a0)	;Links
		move.b	15(a1),csParam+1(a0)	;Rechts
		bra	IOReturnOK

; 113: Get Spindle Speed
ControlNot112	cmp.w	#113,csCode(a0)
		bne	ControlNot113

		move.w	#$ff,csParam(a0)
		bra	IOReturnOK

; 114: Set Spindle Speed
ControlNot113	cmp.w	#114,csCode(a0)
		bne	ControlNot114

		bra	IOReturnOK

; 126: Get Play Mode (Apple AudioCD braucht das)
ControlNot114	cmp.w	#126,csCode(a0)
		bne	ControlNot126

		clr.w	csParam(a0)
		bra	IOReturnOK

ControlNot126	bra	IOControlErr


*
* Status()-Routine
*

CDStatus	movem.l	a0-a1/a5,-(sp)
		lea	BssSection,a5
		lea	cdDriveStatus(a5),a2
		DPRINTF	"CDStatus %08lx",csCode(a0)

; Status-Code abfragen
; 8: Get Drive Status
		cmp.w	#8,csCode(a0)
		bne	StatusNot8

		lea	csParam(a0),a0
		moveq	#10,d0
1$		move.w	(a2)+,(a0)+
		dbra	d0,1$
		bra	IOReturnOK

; 43: Driver Gestalt
StatusNot8	cmp.w	#43,csCode(a0)
		bne	StatusNot43

		cmp.l	#'sync',csParam(a0)	;Driver Synchronous
		bne	1$
		move.b	#1,csParam+4(a0)
		bra	IOReturnOK
1$
		cmp.l	#'vers',csParam(a0)	;Driver Version
		bne	2$
		move.l	#$05208000,csParam+4(a0)
		bra	IOReturnOK
2$
		cmp.l	#'intf',csParam(a0)	;Interface Type
		bne	3$
		move.l	#'scsi',csParam+4(a0)
		bra	IOReturnOK
3$
		cmp.l	#'devt',csParam(a0)	;Device Type
		bne	4$
		move.l	#'cdrm',csParam+4(a0)
		bra	IOReturnOK
4$
		bra	IOStatusErr

; 95: Get 2K Offset
StatusNot43	cmp.w	#95,csCode(a0)
		bne	StatusNot95

		move.w	cd2KOffset(a5),d0
		bmi	IOStatusErr
		move.w	d0,csParam(a0)
		bra	IOReturnOK

; 96: Get Drive Type
StatusNot95	cmp.w	#96,csCode(a0)
		bne	StatusNot96

		move.w	#3,csParam(a0)	;AppleCD300 or newer
		bra	IOReturnOK

; 97: Who Is There
StatusNot96	cmp.w	#97,csCode(a0)
		bne	StatusNot97

		moveq	#0,d0
		move.w	cdTargetID(a5),d1
		bset	d1,d0
		move.w	d0,csParam(a0)
		bra	IOReturnOK

; 98: Get Block Size
StatusNot97	cmp.w	#98,csCode(a0)
		bne	StatusNot98

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine
		move.w	cdBlockSize(a5),csParam(a0)
		bra	IOReturnOK

; 120: Return DeviceIdent
StatusNot98	cmp.w	#120,csCode(a0)
		bne	StatusNot120

		clr.w	csParam(a0)		;Bus
		move.w	cdTargetID(a5),d0
		move.b	d0,csParam+2(a0)	;Target ID
		clr.b	csParam+3(a0)		;LUN
		bra	IOReturnOK

; 121: Get CD Features
StatusNot120	cmp.w	#121,csCode(a0)
		bne	StatusNot121

		move.w	#$0200,csParam(a0)	;300 KB/s
		move.w	#$0300,csParam+2(a0)	;SCSI-2, Stereo, Caddy
		bra	IOReturnOK

StatusNot121	bra	IOStatusErr


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
IOControlErr	moveq	#-17,d0		;Unimplemented Control
		bra	IOReturn
IOStatusErr	moveq	#-18,d0		;Unimplemented Status
		bra	IOReturn
IOReadErr	moveq	#-19,d0		;Read Error
		bra	IOReturn
IOErr		moveq	#-36,d0		;I/O Error
		bra	IOReturn

IOReturnOK	moveq	#0,d0		;Alles OK

IOReturn	movem.l	(sp)+,a0-a1/a5	;ParamBlock und DCE wiederherstellen

		tst.w	d0
		beq	1$
		move.w	d0,DskErr

1$		btst	#noQueueBit-8,ioTrap(a0) ;Immediate call mit RTS beenden
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


*
* CD im Laufwerk?
* -> d0.b: 0: Ja, #0: Nein
*

CDIsDiskInDrive	move.l	scCmdBuffer(a5),a0
		clr.l	(a0)			;Test Unit Ready
		clr.w	4(a0)
		move.w	#6,scsi_CmdLength(a5)
		clr.l	scsi_Length(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bra	CDSCSISendIt


*
* CD entriegeln und auswerfen
*

CDEject		move.l	scCmdBuffer(a5),a0
		move.l	#$1e000000,(a0)		;Allow Medium Removal
		clr.w	4(a0)
		move.w	#6,scsi_CmdLength(a5)
		clr.l	scsi_Length(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bsr	CDSCSISendIt

		move.l	scCmdBuffer(a5),a0
		move.l	#$1b010000,(a0)	;Start Stop Unit
		move.w	#$0200,4(a0)
		move.w	#6,scsi_CmdLength(a5)
		bra	CDSCSISendIt


*
* CD verriegeln
*

CDLock		move.l	scCmdBuffer(a5),a0
		move.l	#$1e000000,(a0)		;Prevent Medium Removal
		move.w	#$0100,4(a0)
		move.w	#6,scsi_CmdLength(a5)
		clr.l	scsi_Length(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bra	CDSCSISendIt


*
* CD entriegeln
*

CDUnlock	move.l	scCmdBuffer(a5),a0
		move.l	#$1e000000,(a0)		;Allow Medium Removal
		clr.w	4(a0)
		move.w	#6,scsi_CmdLength(a5)
		clr.l	scsi_Length(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bra	CDSCSISendIt


*
* Aktuelle Position lesen
*

CDReadPosition	move.l	scCmdBuffer(a5),a0
		move.l	#$42024001,(a0)		;Read Sub-Channel MSF Current Position
		clr.l	4(a0)
		move.w	#$1000,8(a0)
		move.w	#10,scsi_CmdLength(a5)
		move.l	#16,scsi_Length(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bra	CDSCSISendIt


*
* Kapazität lesen, in dsDriveSize vermerken
*

CDReadCapacity	move.l	scCmdBuffer(a5),a0
		move.l	#$25000000,(a0)		;Read CD-ROM Capacity
		clr.l	4(a0)
		clr.w	8(a0)
		move.w	#10,scsi_CmdLength(a5)
		move.l	#8,scsi_Length(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bsr	CDSCSISendIt

		move.l	scsi_Data(a5),a0
		move.l	(a0),d0
		swap	d0
		move.l	d0,cdDriveStatus+dsDriveSize(a5)
		rts


*
* TOC lesen
*

CDReadTOC	lea	cdTOC(a5),a0		;TOC löschen
		move.w	#$324/4-1,d0
1$		clr.l	(a0)+
		dbra	d0,1$

		move.l	scsi_Data(a5),-(sp)	;Alten Puffer merken
		lea	cdTOC(a5),a0
		move.l	a0,scsi_Data(a5)	;Nach cdTOC lesen
		move.l	scCmdBuffer(a5),a0
		move.l	#$43020000,(a0)		;Read TOC MSF
		move.l	#$00000003,4(a0)
		move.w	#$2400,8(a0)
		move.w	#10,scsi_CmdLength(a5)
		move.l	#804,scsi_Length(a5)	;Maximale TOC-Größe
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bsr	CDSCSISendIt
		move.l	(sp)+,scsi_Data(a5)	;Alten Puffer wiederherstellen

		lea	cdTOC+4(a5),a1		;Lead-Out-Track in TOC suchen
		moveq	#99,d0
2$		cmp.b	#$aa,2(a1)
		beq	3$
		lea	8(a1),a1
		dbra	d0,2$
		clr.l	cdLeadOutMSF(a5)
		rts
3$		move.l	4(a1),cdLeadOutMSF(a5)
		rts


*
* HFS-Partition suchen, Start in cdStartByte vermerken
*

CDFindHFS	movem.l	d0-d1/a3,-(sp)
		clr.l	cdStartByte(a5)		;cdStartByte=0: keine HFS-Partition
		lea	CDPMRead(pc),a3
		jsr	ScanPartMap		;(MacEmulAFD.asm, auch fuer Disk-Dateien)
		beq	1$
		move.l	d0,cdStartByte(a5)
		lsr.l	#8,d1			;Groesse in 512-Byte-Bloecken
		lsr.l	#1,d1
		swap	d1
		move.l	d1,cdDriveStatus+dsDriveSize(a5)
1$		movem.l	(sp)+,d0-d1/a3
		rts

; Leseroutine fuer ScanPartMap: den 2048-Byte-Block der CD lesen, in dem die
; Byteposition d2 liegt. Z gesetzt = gelungen, a4 = die 512 Bytes ab d2
CDPMRead	movem.l	d1-d7/a0-a3,-(sp)
		move.l	d2,d3
		moveq	#11,d0
		lsr.l	d0,d3			;d3: Blocknummer
		move.l	scCmdBuffer(a5),a0
		move.w	#$2800,(a0)		;Read(10)
		move.l	d3,2(a0)
		clr.b	6(a0)
		move.w	#1,7(a0)
		clr.b	9(a0)
		move.w	#10,scsi_CmdLength(a5)
		move.l	#2048,scsi_Length(a5)
		move.b	#SCSIF_READ,scsi_Flags(a5)
		bsr	CDSCSISendIt
		movem.l	(sp)+,d1-d7/a0-a3
		tst.b	d0
		bne	1$
		move.l	d2,d0
		and.l	#2047,d0
		move.l	scsi_Data(a5),a4
		add.l	d0,a4
		moveq	#0,d0
1$		rts


*
* SCSI-Kommando für CD-ROM ausführen
*

CDSCSISendIt	move.w	cdTargetID(a5),scTargetID(a5)
		clr.w	scTargetLUN(a5)
		move.l	cdRequest(a5),scTheRequest(a5)
		bra	SCSISendIt


**
** Konstanten
**

; Strings
ReqTitle	dc.b	"ShapeShifter SCSI Error",0
ReqGads		dc.b	"OK",0
ReqGads2	dc.b	"No",0
NoReadBufTxt	dc.b	"Could not allocate buffer",10
		dc.b	"for reading. The SCSI manager",10
		dc.b	"will now trash your data.",10
		dc.b	"Is that a problem?",0
NoWriteBufTxt	dc.b	"Could not allocate buffer",10
		dc.b	"for writing. The SCSI manager",10
		dc.b	"will now trash your data.",10
		dc.b	"Is that a problem?",0
TIBCompTxt	dc.b	"Unsupported scComp command.",0
WriteBufOvflTxt	dc.b	"Write buffer overflow.",0
		CNOP	0,4

; CD-ROM Icon
CDIcon		dc.l	$3FFFFFF0,$40000008,$801FC004,$80757004
		dc.l	$81AAAC04,$83555604,$86AAAB04,$8D555584
		dc.l	$8AAAAAC4,$955FD544,$9AB06AE4,$B5673564
		dc.l	$AACF9AB4,$B55C5574,$AAD85AB4,$B5585574
		dc.l	$AAC89AB4,$B5673574,$9AB06AF4,$955FD564
		dc.l	$8AAAAAE4,$8D5555C4,$86AAABC4,$83555784
		dc.l	$81AAAF04,$80F57E04,$803FF804,$800FE004
		dc.l	$FFFFFFFC,$80000004,$801FF004,$7FFFFFF8

		dc.l	$3FFFFFF0,$7FFFFFF8,$FFFFFFFC,$FFFFFFFC
		dc.l	$FFFFFFFC,$FFFFFFFC,$FFFFFFFC,$FFFFFFFC
		dc.l	$FFFFFFFC,$FFFFFFFC,$FFFFFFFC,$FFFFFFFC
		dc.l	$FFFFFFFC,$FFFFFFFC,$FFFFFFFC,$FFFFFFFC
		dc.l	$FFFFFFFC,$FFFFFFFC,$FFFFFFFC,$FFFFFFFC
		dc.l	$FFFFFFFC,$FFFFFFFC,$FFFFFFFC,$FFFFFFFC
		dc.l	$FFFFFFFC,$FFFFFFFC,$FFFFFFFC,$FFFFFFFC
		dc.l	$FFFFFFFC,$FFFFFFFC,$FFFFFFFC,$7FFFFFF8
		dc.b	16,"CD-ROM SCSI ID "
CDIconID	dc.b	"0"
		CNOP	0,4

; Tabelle zur Konvertierung Binär->BCD
ToBCDTab	dc.b	$00,$01,$02,$03,$04,$05,$06,$07,$08,$09
		dc.b	$10,$11,$12,$13,$14,$15,$16,$17,$18,$19
		dc.b	$20,$21,$22,$23,$24,$25,$26,$27,$28,$29
		dc.b	$30,$31,$32,$33,$34,$35,$36,$37,$38,$39
		dc.b	$40,$41,$42,$43,$44,$45,$46,$47,$48,$49
		dc.b	$50,$51,$52,$53,$54,$55,$56,$57,$58,$59
		dc.b	$60,$61,$62,$63,$64,$65,$66,$67,$68,$69
		dc.b	$70,$71,$72,$73,$74,$75,$76,$77,$78,$79
		dc.b	$80,$81,$82,$83,$84,$85,$86,$87,$88,$89
		dc.b	$90,$91,$92,$93,$94,$95,$96,$97,$98,$99
		dcb.b	256-100,$ff

; Tabelle zur Konvertierung BCD->Binär
FromBCDTab	dc.b	0,1,2,3,4,5,6,7,8,9,-1,-1,-1,-1,-1,-1
		dc.b	10,11,12,13,14,15,16,17,18,19,-1,-1,-1,-1,-1,-1
		dc.b	20,21,22,23,24,25,26,27,28,29,-1,-1,-1,-1,-1,-1
		dc.b	30,31,32,33,34,35,36,37,38,39,-1,-1,-1,-1,-1,-1
		dc.b	40,41,42,43,44,45,46,47,48,49,-1,-1,-1,-1,-1,-1
		dc.b	50,51,52,53,54,55,56,57,58,59,-1,-1,-1,-1,-1,-1
		dc.b	60,61,62,63,64,65,66,67,68,69,-1,-1,-1,-1,-1,-1
		dc.b	70,71,72,73,74,75,76,77,78,79,-1,-1,-1,-1,-1,-1
		dc.b	80,81,82,83,84,85,86,87,88,89,-1,-1,-1,-1,-1,-1
		dc.b	90,91,92,93,94,95,96,97,98,99,-1,-1,-1,-1,-1,-1
		dcb.b	256-160,$ff


**
** Initialisierte Daten
**

		CNOP	0,4
NoReadBufReq	dc.l	20,0,ReqTitle,NoReadBufTxt,ReqGads2
NoWriteBufReq	dc.l	20,0,ReqTitle,NoWriteBufTxt,ReqGads2
TIBCompReq	dc.l	20,0,ReqTitle,TIBCompTxt,ReqGads
WriteBufOvflReq	dc.l	20,0,ReqTitle,WriteBufOvflTxt,ReqGads


**
** Nicht initialisierte Daten
**

		SECTION	"BSS",BSS
BssSection	ds.b	SIZEOF_MySCSIData

		END
