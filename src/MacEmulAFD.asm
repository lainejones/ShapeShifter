**
** Macintosh IIci-Emulator - Amiga File Disk Treiber
** =================================================
**
** © Copyright 1993-2001 Christian Bauer
**

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"dos/dos.i"
		INCLUDE	"dos/dostags.i"
		INCLUDE	"macros.i"
		INCLUDE	"macinclude.i"

		XDEF	ScanPartMap
		XDEF	InstallAFD
		XDEF	OpenFileDisks
		XDEF	CloseFileDisks
		XDEF	AFDRefNum
		XDEF	AFDWaitComplete
		XDEF	DrvLog
		XDEF	DrvLogIdx
		XDEF	InsertImage

		XREF	PrefsNameTab
		XREF	SubtaskSet		;MacEmul.asm

		SECTION	"CODE",CODE


**
** Definitionen
**

ASYNCIO		= 1		;Asynchron?

AFDDrive	= 5		;Laufwerksnummer der ersten File-Disk
NUMAFD		= 4		;Anzahl File-Disks (Laufwerke 5, 6, 8, 9; 7 ist die CD)
EJECTBOOT	= 20*60		;Ticks: ejects before that are the ROM's search for a startup disk
AFDRefNum	= -63		;Nummer des File-Disk-Treibers

; DriveStatus
 STRUCTURE	MyDrvSts,DSHD20_SIZEOF
	APTR	dsFileHandle	;FileHandle
	LONG	dsFilePos	;Seek-Position (Mac-Sicht, -1: unbekannt)
	LONG	dsOffset	;Beginn der Daten in der Datei (DiskCopy 4.2: 84)
	WORD	dsDriveNum	;Mac-Laufwerksnummer
	APTR	dsIcon		;Laufwerks-Icon
	LONG	dsRawSec	;Rohe CD-Sektoren (.bin/.cue): Sektorgroesse, sonst 0
	LONG	dsRawHdr	; Beginn der 2048 Datenbytes im Sektor (16, 24, 8, 0)
	LONG	dsRawBase	; Beginn des Datentracks in der Datei
	LONG	dsTocLeadOut	;CD aus einer .cue: Lead-out (Frames ab 00:00:00)
	BYTE	dsTocFirst	; Erster Track (0: kein Inhaltsverzeichnis)
	BYTE	dsTocLast	; Letzter Track
	WORD	dsTocPad
	STRUCT	dsToc,99*4	; Je Track: Control<<24 | Start in Frames
 LABEL	MyDrvSts_SIZEOF


**
** Installation der File-Disk
**

; Treiber installieren
InstallAFD	move.l	a0,-(sp)
		lea	AFDHeader,a0
		moveq	#AFDRefNum,d0
		dc.w	$a43d		;DrvrInstallRsrvMem

; Zeiger auf Treiber holen
		move.l	$11c,a0		;UTableBase
		move.l	-(AFDRefNum+1)*4(a0),a0
		move.l	(a0),a2
		dc.w	$a029		;HLock

; Daten kopieren
		lea	AFDHeader,a0
		move.l	a0,(a2)
		move.w	(a0),dCtlFlags(a2)

; Treiber öffnen
		move.l	(sp)+,a0
		move.l	#AFDName,ioNamePtr(a0)
		dc.w	$a000		;Open
		rts


**
** File-Disks öffnen und FileTask anlegen
**

; FileDisks 1-4: Dateien oeffnen, Groesse und DiskCopy-Kopf ermitteln
OpenFileDisks	movem.l	d2-d7/a2-a5,-(sp)
		lea	DriveStatus1,a2
		lea	PrefsNameTab,a3
		lea	AFDDriveTab,a4
		lea	AFDIconTab,a5
		moveq	#NUMAFD-1,d7
1$		move.w	(a4)+,dsDriveNum(a2)
		move.l	(a5)+,dsIcon(a2)
		move.l	(a3)+,a0
		tst.b	(a0)			;Keine leeren Dateinamen zulassen
		beq	2$
		bsr	OpenOneDisk
2$		lea	MyDrvSts_SIZEOF(a2),a2
		dbra	d7,1$
		movem.l	(sp)+,d2-d7/a2-a5

; Signal einrichten
		move.l	_ExecBase(pc),a6
		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,FTReadySig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,FTReadySet

; Task starten
		move.l	_DOSBase,a6
		move.l	#ProcTags,d1
		JSRLIB	CreateNewProc
		move.l	d0,FileTaskProc
		beq	OFDError

; Auf Signal warten
		move.l	_ExecBase(pc),a6
		move.l	SubtaskSet,d0
		JSRLIB	Wait
		moveq	#0,d0		;Alles OK
		rts

OFDError	moveq	#-1,d0
		rts


; Eine File-Disk oeffnen. a0: Dateiname, a2: DriveStatus
; Eine DiskCopy-4.2-Datei (Mac-Diskettenabbild, 84 Bytes Kopf) wird erkannt
; und ihr Kopf uebersprungen.
OpenOneDisk	move.l	_DOSBase,a6
		clr.b	dsTocFirst(a2)
		clr.b	dsTocLast(a2)
		clr.l	dsTocLeadOut(a2)
		clr.l	dsRawSec(a2)
		clr.l	dsRawHdr(a2)
		clr.l	dsRawBase(a2)
		clr.b	dsWriteProt(a2)
		bsr	IsCueName		;.cue: die .bin-Datei daraus oeffnen
		beq	01$
		bsr	OpenCue
		move.l	d0,dsFileHandle(a2)
		beq	9$
		bra	02$
01$		move.l	a0,d1
		move.l	#MODE_OLDFILE,d2
		JSRLIB	Open
		move.l	d0,dsFileHandle(a2)
		beq	9$

02$		move.l	d0,d1
		move.l	#FIB,d2
		JSRLIB	ExamineFH		;Groesse ermitteln
		tst.l	d0
		beq	8$
		move.l	fib_Size+FIB,d5		;d5: Dateigroesse
		btst	#FIBB_WRITE,fib_Protection+3+FIB ;Datei schreibgeschuetzt:
		beq	07$			; dann ist es die Mac-Disk auch
		st	dsWriteProt(a2)
07$		move.l	dsFileHandle(a2),d1	;Ebenso auf einem schreibgeschuetzten Volume
		JSRLIB	ParentOfFH
		move.l	d0,d4
		beq	09$
		move.l	d4,d1
		move.l	#FIB,d2			;(als InfoData benutzt)
		JSRLIB	Info
		tst.l	d0
		beq	08$
		cmp.l	#ID_WRITE_PROTECTED,id_DiskState+FIB
		bne	08$
		st	dsWriteProt(a2)
08$		move.l	d4,d1
		JSRLIB	UnLock
09$		clr.l	dsOffset(a2)
		move.l	#-1,dsFilePos(a2)	;Erster Zugriff seekt immer
		tst.l	dsRawSec(a2)		;Aus einer .cue
		bne	50$

		cmp.l	#84,d5			;DiskCopy 4.2?
		bls	5$
		move.l	dsFileHandle(a2),d1
		move.l	#DCHeader,d2
		moveq	#84,d3
		JSRLIB	Read
		cmp.l	#84,d0
		bne	5$
		lea	DCHeader,a0		;Rohe CD-Sektoren (.bin): Sync-Muster
		tst.b	(a0)			; 00 FF*10 00 am Anfang?
		bne	03$
		cmp.l	#$00FFFFFF,(a0)
		bne	03$
		cmp.l	#$FFFFFFFF,4(a0)
		bne	03$
		cmp.l	#$FFFFFF00,8(a0)
		bne	03$
		move.l	#2352,dsRawSec(a2)
		moveq	#16,d0			;Mode 1: Daten ab Byte 16
		cmp.b	#2,15(a0)
		bne	04$
		moveq	#24,d0			;Mode 2 Form 1: ab Byte 24
04$		move.l	d0,dsRawHdr(a2)
		bra	50$
03$		cmp.b	#63,(a0)		;Name: Pascal-String bis 63 Zeichen
		bhi	5$
		cmp.w	#$0100,82(a0)		;Kennung
		bne	5$
		move.l	64(a0),d0		;Datengroesse
		move.l	d0,d1
		add.l	68(a0),d1		;+ Tag-Groesse
		add.l	#84,d1			;+ Kopf = Dateigroesse?
		cmp.l	d5,d1
		bne	5$
		move.l	d0,d5			;Ja: nur die Daten zaehlen
		move.l	#84,dsOffset(a2)

		bra	5$

; 50$: rohe Sektoren: d5 = Anzahl Sektoren ab Trackbeginn * 2048
; (schreibgeschuetzt: nur Lesen ist umgesetzt)
50$		move.l	d5,d0			;Lead-out: Sektoren der Datei + 2 s
		divu.l	dsRawSec(a2),d0
		add.l	#150,d0
		move.l	d0,dsTocLeadOut(a2)
		move.l	d5,d0
		sub.l	dsRawBase(a2),d0
		bhi	51$
		moveq	#0,d0
51$		divu.l	dsRawSec(a2),d0
		moveq	#11,d1
		lsl.l	d1,d0
		move.l	d0,d5
		st	dsWriteProt(a2)

5$		tst.l	dsOffset(a2)		;Sonst: Apple-Partitionstabelle
		bne	6$			; (CD-Abbilder .toast/.cdr/.iso, Festplatten)?
		bsr	TryPartMap
6$		move.l	d5,d0
		lsr.l	#8,d0			;/512
		lsr.l	#1,d0
		swap	d0
		move.l	d0,dsDriveSize(a2)
		rts

8$		move.l	dsFileHandle(a2),d1	;Fehler: Datei schliessen
		JSRLIB	Close
		clr.l	dsFileHandle(a2)
9$		rts


; Beginnt die Datei mit einer Apple-Partitionstabelle, wird die erste
; Apple_HFS-Partition mit einem HFS-Volume benutzt: dsOffset = ihr Anfang,
; d5 = ihre Groesse. a2: DriveStatus, a6: DOSBase
TryPartMap	movem.l	d0-d1/a3-a4,-(sp)
		lea	PMRead(pc),a3
		bsr	ScanPartMap
		beq	1$
		move.l	d0,dsOffset(a2)
		move.l	d1,d5
1$		movem.l	(sp)+,d0-d1/a3-a4
		rts

; Apple-Partitionstabelle durchsuchen ("ER", dann "PM"-Eintraege, Bloecke zu
; 512 oder 2048 Bytes; manche CDs haben die Eintraege im 512-Byte-Abstand).
; Fuer Disk-Dateien und fuer SCSI-CD-ROMs (MacEmulSCSI.asm).
; a3: Leseroutine: d2 = Byteposition -> Z gesetzt = gelungen, a4 = 512 Bytes.
;     Sie darf nur d0 und a4 veraendern.
; Rueckgabe: Z geloescht = gefunden, d0 = Anfang, d1 = Groesse (Bytes)
ScanPartMap	movem.l	d2-d7/a0-a1/a4,-(sp)
		moveq	#0,d2
		jsr	(a3)
		bne	9$
		cmp.w	#'ER',(a4)
		bne	9$
		moveq	#0,d4
		move.w	2(a4),d4		;Blockgroesse
		cmp.l	#512,d4
		blo	1$
		move.l	d4,d0
		and.l	#511,d0
		beq	2$
1$		move.l	#512,d4
2$		move.l	d4,d5			;d5: Einheit der Blocknummern
		move.l	d4,d2			;Eintraege im Abstand der Blockgroesse?
		jsr	(a3)
		bne	3$
		cmp.w	#'PM',(a4)
		beq	4$
3$		move.l	#512,d4			;oder im 512-Byte-Abstand
		move.l	d4,d2
		jsr	(a3)
		bne	9$
		cmp.w	#'PM',(a4)
		bne	9$
4$		move.l	4(a4),d6		;Anzahl Eintraege (hoechstens 64)
		cmp.l	#64,d6
		bls	5$
		moveq	#64,d6
5$		moveq	#1,d7
6$		cmp.l	d6,d7
		bhi	9$
		move.l	d7,d2
		mulu.l	d4,d2
		jsr	(a3)
		bne	9$
		cmp.w	#'PM',(a4)
		bne	9$
		lea	48(a4),a0		;pmParType = "Apple_HFS"?
		lea	HFSPartType,a1
7$		move.b	(a1)+,d0
		cmp.b	(a0)+,d0
		bne	8$
		tst.b	d0
		bne	7$
		move.l	8(a4),d0		;Anfang und Groesse in Bloecken
		move.l	12(a4),d1
		move.l	d5,d3			;Erst in der Blockgroesse der Tabelle,
		bsr	PMTryVol
		bne	10$
		cmp.l	#512,d5			; dann in 512 Bytes (so rechnete der
		beq	8$			; alte CD-Treiber immer)
		move.l	#512,d3
		bsr	PMTryVol
		bne	10$
8$		addq.l	#1,d7
		bra	6$
9$		moveq	#0,d0			;Nichts gefunden (Z gesetzt)
10$		movem.l	(sp)+,d2-d7/a0-a1/a4
		rts

; Liegt bei Block d0 (Einheit d3 Bytes) ein HFS-Volume (MDB "BD" bei +1024)?
; Dann Z geloescht, d0 = Anfang, d1 = Groesse in Bytes. Sonst Z gesetzt,
; d0/d1 unveraendert. Zerstoert d2, a4 (Eintrag der Tabelle!)
PMTryVol	movem.l	d0-d1,-(sp)
		mulu.l	d3,d0
		move.l	d0,d2
		add.l	#1024,d2
		jsr	(a3)
		bne	1$
		cmp.w	#'BD',(a4)
		bne	1$
		movem.l	(sp)+,d0-d1
		mulu.l	d3,d0
		mulu.l	d3,d1
		moveq	#1,d2			;Z loeschen
		rts
1$		movem.l	(sp)+,d0-d1
		cmp.l	d0,d0			;Z setzen
		rts

; 512 Bytes ab Dateiposition d2 nach PMBuf lesen. Z gesetzt = gelungen, a4 = PMBuf
PMRead		movem.l	d3/a1,-(sp)
		move.l	#512,d3
		lea	PMBuf,a1
		bsr	ReadAt
		lea	PMBuf,a4
		cmp.l	#512,d0
		movem.l	(sp)+,d3/a1
		beq	1$
		moveq	#1,d0
		rts
1$		moveq	#0,d0
		rts

; ReadAt: d3 Bytes ab Position d2 (Sicht des Mac, mit dsOffset) nach a1
; lesen. Bei rohen CD-Sektoren werden aus jedem Sektor die 2048 Datenbytes
; genommen. a2: DriveStatus, a6: DOSBase. Rueckgabe d0: gelesene Bytes, -1
ReadAt		movem.l	d1-d7/a0-a1,-(sp)
		move.l	a1,d7			;d7: Puffer
		move.l	d3,d6			;d6: Rest
		tst.l	dsRawSec(a2)
		bne	2$
		move.l	dsFileHandle(a2),d1	;Einfaches Abbild
		moveq	#OFFSET_BEGINNING,d3
		JSRLIB	Seek
		cmp.l	#-1,d0
		beq	8$
		move.l	dsFileHandle(a2),d1
		move.l	d7,d2
		move.l	d6,d3
		JSRLIB	Read
		bra	9$

2$		moveq	#0,d5			;d5: bisher gelesen
		move.l	d2,d4			;d4: Position
3$		tst.l	d6
		beq	7$
		move.l	d4,d0			;Dateiposition: Track + Sektor * Groesse
		moveq	#11,d1			; + Kopf + Byte im Sektor
		lsr.l	d1,d0
		mulu.l	dsRawSec(a2),d0
		add.l	dsRawBase(a2),d0
		add.l	dsRawHdr(a2),d0
		move.l	d4,d1
		and.l	#2047,d1
		add.l	d1,d0
		move.l	#2048,d3		;Hoechstens bis zum Sektorende
		sub.l	d1,d3
		cmp.l	d6,d3
		bls	4$
		move.l	d6,d3
4$		move.l	d3,-(sp)
		move.l	d0,d2
		move.l	dsFileHandle(a2),d1
		moveq	#OFFSET_BEGINNING,d3
		JSRLIB	Seek
		move.l	(sp)+,d3
		cmp.l	#-1,d0
		beq	7$
		move.l	d3,-(sp)
		move.l	dsFileHandle(a2),d1
		move.l	d7,d2
		JSRLIB	Read
		move.l	(sp)+,d3
		cmp.l	d3,d0
		bne	6$
		add.l	d3,d7
		add.l	d3,d4
		add.l	d3,d5
		sub.l	d3,d6
		bra	3$
6$		tst.l	d0			;Kurz gelesen
		bmi	7$
		add.l	d0,d5
7$		move.l	d5,d0
		bra	9$
8$		moveq	#-1,d0
9$		movem.l	(sp)+,d1-d7/a0-a1
		rts

; Endet der Name in a0 auf ".cue"? Rueckgabe d0 (Z): #0 ja
IsCueName	move.l	a0,a1
1$		tst.b	(a1)+
		bne	1$
		subq.l	#1,a1
		move.l	a1,d0
		sub.l	a0,d0
		cmp.l	#4,d0
		blo	8$
		cmp.b	#'.',-4(a1)
		bne	8$
		move.b	-3(a1),d0
		or.b	#$20,d0
		cmp.b	#'c',d0
		bne	8$
		move.b	-2(a1),d0
		or.b	#$20,d0
		cmp.b	#'u',d0
		bne	8$
		move.b	-1(a1),d0
		or.b	#$20,d0
		cmp.b	#'e',d0
		bne	8$
		moveq	#-1,d0
		rts
8$		moveq	#0,d0
		rts

; .cue-Datei a0 lesen: FILE "name.bin" (relativ zum Verzeichnis der .cue)
; und den ersten Datentrack (TRACK nn MODE1/2352, MODE2/2352, MODE2/2336,
; MODE1/2048) mit seinem INDEX 01 mm:ss:ff. Setzt dsRawSec/Hdr/Base.
; a2: DriveStatus, a6: DOSBase. Rueckgabe d0: FileHandle der .bin oder 0
OpenCue		movem.l	d1-d7/a0-a1/a3-a4,-(sp)
		move.l	a0,a4			;a4: Name der .cue
		move.l	a0,d1
		move.l	#MODE_OLDFILE,d2
		JSRLIB	Open
		move.l	d0,d7
		beq	90$
		move.l	d7,d1
		move.l	#CueBuf,d2
		move.l	#CUEBUFSIZE-1,d3
		JSRLIB	Read
		move.l	d0,d6
		move.l	d7,d1
		JSRLIB	Close
		tst.l	d6
		ble	90$
		lea	CueBuf,a0
		clr.b	(a0,d6.l)

		lea	CueBuf,a0		;FILE "name"
		lea	KwFile,a1
		bsr	FindWord
		beq	90$
		bsr	SkipSpace
		lea	CueName,a1
		moveq	#' ',d1			;Ende: Leerzeichen
		cmp.b	#'"',(a0)
		bne	1$
		addq.l	#1,a0
		moveq	#'"',d1			;oder das zweite "
1$		move.b	(a0)+,d0
		beq	2$
		cmp.b	d1,d0
		beq	2$
		cmp.b	#10,d0
		beq	2$
		cmp.b	#13,d0
		beq	2$
		cmp.b	#9,d0
		beq	2$
		move.b	d0,(a1)+
		cmp.l	#CueName+CUENAMESIZE-1,a1
		blo	1$
2$		clr.b	(a1)
		tst.b	CueName
		beq	90$

		move.l	a4,a0			;Pfad: Verzeichnis der .cue + Name
		lea	CuePath,a1
		move.l	#CUEPATHSIZE-2,d0
3$		move.b	(a0)+,(a1)+
		dbeq	d0,3$
		clr.b	(a1)
		move.l	#CuePath,d1
		JSRLIB	PathPart
		move.l	d0,a0
		clr.b	(a0)
		move.l	#CuePath,d1
		move.l	#CueName,d2
		move.l	#CUEPATHSIZE,d3
		JSRLIB	AddPart
		tst.l	d0
		beq	90$

		lea	CueBuf,a3		;Ersten Datentrack suchen
10$		move.l	a3,a0
		lea	KwTrack,a1
		bsr	FindWord
		beq	90$
		move.l	a0,a3			;Hier weitersuchen, falls kein Datentrack
		bsr	SkipSpace
		bsr	ParseDec		;Tracknummer
		bsr	SkipSpace
		cmp.l	#'MODE',(a0)
		bne	10$
		move.b	4(a0),d4		;d4: '1' oder '2'
		cmp.b	#'/',5(a0)
		bne	10$
		addq.l	#6,a0
		bsr	ParseDec
		move.l	d0,d5			;d5: Sektorgroesse
		moveq	#16,d6			;d6: Kopf
		cmp.b	#'1',d4
		beq	11$
		cmp.b	#'2',d4
		bne	10$
		moveq	#24,d6
		cmp.l	#2352,d5
		beq	13$
		moveq	#8,d6
		cmp.l	#2336,d5
		beq	13$
		bra	10$
11$		cmp.l	#2352,d5
		beq	13$
		moveq	#0,d6
		cmp.l	#2048,d5
		bne	10$
13$
20$		lea	KwIndex,a1		;INDEX 01 mm:ss:ff
		bsr	FindWord
		beq	90$
		bsr	SkipSpace
		bsr	ParseDec
		cmp.l	#1,d0
		bne	20$
		bsr	SkipSpace
		bsr	ParseMSF		;mm:ss:ff
		move.l	d0,d2
		mulu.l	d5,d2
		move.l	d2,dsRawBase(a2)
		move.l	d5,dsRawSec(a2)
		move.l	d6,dsRawHdr(a2)
		bsr	ParseToc		;Alle Tracks fuer ReadTOC

		move.l	#CuePath,d1		;Die .bin oeffnen
		move.l	#MODE_OLDFILE,d2
		JSRLIB	Open
		bra	99$
90$		moveq	#0,d0
99$		movem.l	(sp)+,d1-d7/a0-a1/a3-a4
		tst.l	d0
		rts

; Wort a1 (Grossbuchstaben, 0-terminiert) in a0 suchen, am Zeilen- oder
; Wortanfang. Rueckgabe a0: dahinter, d0 (Z): 0 = nicht gefunden
FindWord	movem.l	d1/a1-a2,-(sp)
		cmp.l	#CueBuf,a0
		beq	2$
1$		tst.b	(a0)
		beq	8$
		cmp.b	#' ',(a0)+		;Davor muss Leerraum stehen
		bhi	1$
2$		move.l	a0,a2
		move.l	a1,-(sp)
3$		move.b	(a1)+,d1
		beq	4$
		move.b	(a2)+,d0
		cmp.b	#'a',d0
		blo	31$
		cmp.b	#'z',d0
		bhi	31$
		sub.b	#$20,d0
31$		cmp.b	d0,d1
		beq	3$
		move.l	(sp)+,a1
		tst.b	(a0)
		beq	8$
		bra	1$
4$		move.l	(sp)+,a1
		move.l	a2,a0
		moveq	#-1,d0
		bra	9$
8$		moveq	#0,d0
9$		movem.l	(sp)+,d1/a1-a2
		tst.l	d0
		rts

SkipSpace	cmp.b	#' ',(a0)
		beq	1$
		cmp.b	#9,(a0)
		bne	2$
1$		addq.l	#1,a0
		bra	SkipSpace
2$		rts

; mm:ss:ff ab a0. Rueckgabe d0: Frames, a0 dahinter
ParseMSF	move.l	d1,-(sp)
		bsr	ParseDec		;mm
		move.l	d0,d1
		mulu.l	#60,d1
		addq.l	#1,a0
		bsr	ParseDec		;ss
		add.l	d0,d1
		mulu.l	#75,d1
		addq.l	#1,a0
		bsr	ParseDec		;ff
		add.l	d1,d0
		move.l	(sp)+,d1
		rts

; Inhaltsverzeichnis der CD aus CueBuf: jedes "TRACK nn typ" mit seinem
; INDEX 01 (Start = INDEX 01 + 2 s Vorlauf, wie auf der CD). AUDIO-Tracks
; bekommen Control 0, Datentracks 4. Nur eine FILE-Zeile wird beachtet.
; a2: DriveStatus
ParseToc	movem.l	d0-d4/a0-a1/a3,-(sp)
		lea	CueBuf,a3
1$		move.l	a3,a0
		lea	KwTrack,a1
		bsr	FindWord
		beq	9$
		move.l	a0,a3
		bsr	SkipSpace
		bsr	ParseDec
		move.l	d0,d3			;d3: Tracknummer
		beq	1$
		cmp.l	#99,d3
		bhi	1$
		bsr	SkipSpace
		moveq	#4,d4			;Datentrack
		cmp.l	#'AUDI',(a0)
		bne	3$
		moveq	#0,d4			;Audiotrack
3$		lea	KwIndex,a1
		bsr	FindWord
		beq	9$
		bsr	SkipSpace
		bsr	ParseDec
		cmp.l	#1,d0
		bne	3$
		bsr	SkipSpace
		bsr	ParseMSF
		add.l	#150,d0
		moveq	#24,d1
		lsl.l	d1,d4
		or.l	d4,d0
		lea	dsToc(a2),a1
		move.l	d0,-4(a1,d3.l*4)
		tst.b	dsTocFirst(a2)
		beq	4$
		cmp.b	dsTocFirst(a2),d3
		bhs	5$
4$		move.b	d3,dsTocFirst(a2)
5$		cmp.b	dsTocLast(a2),d3
		bls	1$
		move.b	d3,dsTocLast(a2)
		bra	1$
9$		movem.l	(sp)+,d0-d4/a0-a1/a3
		rts

; Dezimalzahl ab a0. Rueckgabe d0, a0 dahinter
ParseDec	move.l	d1,-(sp)
		moveq	#0,d0
1$		moveq	#0,d1
		move.b	(a0),d1
		sub.b	#'0',d1
		cmp.b	#9,d1
		bhi	2$
		mulu.l	#10,d0
		add.l	d1,d0
		addq.l	#1,a0
		bra	1$
2$		move.l	(sp)+,d1
		rts


**
** File-Disks schließen und FileTask beenden
**

; Task stoppen
CloseFileDisks	move.l	_ExecBase(pc),a6
		move.l	FileTask,d0
		beq	3$
		move.l	d0,a1
		move.l	FileQuitSet,d0
		JSRLIB	Signal
		move.l	SubtaskSet,d0
		JSRLIB	Wait

; Signal freigeben
3$		move.b	FTReadySig,d0
		JSRLIB	FreeSignal

; FileDisks schliessen
		move.l	_DOSBase,a6
		lea	DriveStatus1,a2
		moveq	#NUMAFD-1,d7
4$		move.l	dsFileHandle(a2),d1
		beq	5$
		JSRLIB	Close
		clr.l	dsFileHandle(a2)
5$		lea	MyDrvSts_SIZEOF(a2),a2
		dbra	d7,4$
		rts


**
** File-Disk-Treiber
**

; Driver Header
AFDHeader	dc.w	$6f00		;Flags
		dc.w	0,0,0		;Delay, EMask, Menu
		dc.w	Open-AFDHeader
		dc.w	Prime-AFDHeader
		dc.w	Control-AFDHeader
		dc.w	Status-AFDHeader
		dc.w	Close-AFDHeader
AFDName		dc.b	14,".AmigaFileDisk"
		EVEN


*
* Open()-Routine
*

Open		movem.l	a0-a1,-(sp)

; Laufwerke installieren
		move.l	d7,-(sp)
		lea	DriveStatus1,a2
		moveq	#NUMAFD-1,d7
1$		clr.b	dsDiskInPlace(a2)	;Wechselmedium: leer oder Disk im Laufwerk;
		tst.l	dsFileHandle(a2)	; auch leere Laufwerke werden angemeldet
		beq	3$			; (spaeter per AppIcon einlegen)
		move.b	#1,dsDiskInPlace(a2)
3$		move.b	#1,dsInstalled(a2)
		move.w	#1,dsQType(a2)		;HD20
		move.w	dsDriveNum(a2),dsDriveType(a2)
		move.w	dsDriveNum(a2),d0
		swap	d0
		move.w	#AFDRefNum,d0
		lea	dsQLink(a2),a0
		dc.w	$a04e			;AddDrive
2$		lea	MyDrvSts_SIZEOF(a2),a2
		dbra	d7,1$
		move.l	(sp)+,d7

		moveq	#0,d0
		movem.l	(sp)+,a0-a1
		rts


*
* Close()-Routine
*

Close		moveq	#-24,d0		;Close error
		rts


*
* Prime()-Routine
*

Prime		movem.l	a0-a1,-(sp)
		bsr	GetDrvStatus	;Laufwerk vorhanden?
		tst.b	dsDiskInPlace(a2)	;Disk eingelegt?
		beq	IOOffLine
		move.b	#2,dsDiskInPlace(a2)	;Disk accessed

; Auf FileTask warten
		bsr	AFDWaitComplete

; FileTask benachrichtigen
		move.l	a0,FileParmBlock
		move.l	a1,FileDCE
		move.l	a2,FileDrvSts	;Das in Prime ermittelte Laufwerk (Nummer 0 = CD-Abbild)

		move.l	a6,-(sp)
		move.l	_ExecBase(pc),a6
		move.l	FileTask,a1
		move.l	FileSignalSet,d0

	IFEQ	ASYNCIO
		bra	PrimeSync
	ENDC

	IFNE	ASYNCIO
		bsr	CanWait		;Nicht im Mac-Task oder auf Interrupt-Ebene?
		bne	PrimeAsync	;Dann nie warten: der FileTask ruft IODone
		tst.l	ioCompletion(a0) ;Completion Routine vorhanden?
		bne	PrimeSync	;Ja, dann warten (die Routine könnte
					; einen weiteren IO-Vorgang starten
					; und die wird dann vom DiskTask
					; aus ausgeführt...)
	ENDC

PrimeAsync	st.b	FileTaskAsync
		st.b	FileBusy
		JSRLIB	Signal
		move.l	(sp)+,a6
		moveq	#1,d0		;Request noch nicht beendet
		bra	IOReturn

PrimeSync	clr.b	FileTaskAsync
		st.b	FileBusy
		movem.l	d0-d1/a1,-(sp)	;Ein altes "fertig"-Signal loeschen
		moveq	#0,d0
		move.l	FTReadySet,d1
		EJSRLIB	SetSignal
		movem.l	(sp)+,d0-d1/a1
		JSRLIB	Signal
		move.l	FTReadySet,d0
		EJSRLIB	Wait
		move.l	(sp)+,a6
		move.w	FileError,d0
		bra	IOReturn


*
* Control()-Routine
*

Control		movem.l	a0-a1,-(sp)

; Control-Code abfragen
; 65: Make Periodic Action
		cmp.w	#accRun,csCode(a0)
		bne	ControlNot65

		movem.l	d7/a0-a2,-(sp)
		lea	DriveStatus1,a2
		moveq	#NUMAFD-1,d7
1$		tst.l	dsFileHandle(a2)
		beq	2$
		moveq	#0,d0
		move.w	dsDriveNum(a2),d0	;Drive Number
		move.w	#7,a0			;diskEvent
		dc.w	$a02f			;PostEvent
2$		lea	MyDrvSts_SIZEOF(a2),a2
		dbra	d7,1$
		movem.l	(sp)+,d7/a0-a2
		and.w	#$4fff,dCtlFlags(a1)	;NeedNoTime
		bra	IOReturnOK

ControlNot65	bsr	GetDrvStatus	;Laufwerk vorhanden?

; 1: KillIO
		cmp.w	#killCode,csCode(a0)
		bne	ControlNot1

		bsr	AFDWaitComplete

		moveq	#0,d0
		movem.l	(sp)+,a0-a1
		rts

; 5: Verify Disk in Place
ControlNot1	cmp.w	#5,csCode(a0)
		bne	ControlNot5

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine
		bra	IOReturnOK

; 6: Format Disk
ControlNot5	cmp.w	#6,csCode(a0)
		bne	ControlNot6

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine
		bra	IOReturnOK	;Hier wird nichts formatiert

; 7: Eject - der FileTask schliesst die Datei, das Laufwerk ist dann leer
ControlNot6	cmp.w	#7,csCode(a0)
		bne	ControlNot7

		tst.b	dsDiskInPlace(a2)
		beq	IOOffLine
; While it looks for a startup disk, the ROM ejects every removable disk
; without a system on it, as a real Mac spits out such a floppy. A file disk
; has to stay: an empty one is what the system is to be installed on, from
; the CD the Mac then starts from. Nobody else ejects anything in the first
; seconds after the Mac has started.
		cmp.l	#EJECTBOOT,($16a).w	;Ticks
		blo	IOReturnOK
		movem.l	d1/a0-a1/a6,-(sp)
		bsr	AFDWaitComplete
		move.w	dsDriveNum(a2),EjectDrive	;(nicht ueber den ParamBlock: der
		clr.b	EjectDone			; FileTask liest ihn erst spaeter)
		move.l	_ExecBase(pc),a6
		moveq	#0,d0			;Ein altes "fertig"-Signal loeschen
		move.l	FTReadySet,d1
		EJSRLIB	SetSignal
		move.l	FileTask,a1
		move.l	FileEjectSet,d0
		JSRLIB	Signal
1$		move.l	FTReadySet,d0		;Warten, bis der FileTask fertig ist
		EJSRLIB	Wait
		tst.b	EjectDone
		beq	1$
		movem.l	(sp)+,d1/a0-a1/a6
		bra	IOReturnOK

; 21: Get Drive Icon
ControlNot7	cmp.w	#21,csCode(a0)
		bne	ControlNot21

		move.l	dsIcon(a2),csParam(a0)
		bra	IOReturnOK

; 22: Get Disk Icon
ControlNot21	cmp.w	#22,csCode(a0)
		bne	ControlNot22

		move.l	#DiskICON,csParam(a0)
		bra	IOReturnOK

; 23: Get Drive Info
ControlNot22	cmp.w	#23,csCode(a0)
		bne	ControlNot23

		move.l	#$0001,csParam(a0) ;Unspecified drive, removable
		bra	IOReturnOK

;
; CD-ROM-Aufrufe des AppleCD-Treibers, fuer CD-Abbilder aus einer .cue
; (Spiele pruefen damit, ob ihre CD eingelegt ist). Audio wird nicht
; abgespielt: Play/Pause/Stop gelingen, der Status ist "kein Abspielen".
;
ControlNot23	tst.b	dsTocLast(a2)
		beq	IOControlImpl
		move.w	csCode(a0),d0
		cmp.w	#100,d0			;ReadTOC
		beq	CtlReadTOC
		cmp.w	#101,d0			;ReadTheQSubcode
		bne	1$
		move.l	#$04010100,csParam(a0)	;Datentrack 1, Index 1, Zeit 0
		clr.l	csParam+4(a0)
		clr.w	csParam+8(a0)
		bra	IOReturnOK
1$		cmp.w	#103,d0			;AudioTrackSearch
		blo	IOControlImpl
		cmp.w	#106,d0			;AudioPlay, AudioPause, AudioStop
		bls	IOReturnOK
		cmp.w	#107,d0			;AudioStatus
		bne	IOControlImpl
		move.l	#$05090000,csParam(a0)	;Kein Abspielen, Stereo
		clr.w	csParam+4(a0)
		bra	IOReturnOK

; ReadTOC: Typ 1 erster/letzter Track, 2 Lead-out, 3 Startadressen (BCD)
CtlReadTOC	move.w	csParam(a0),d0
		cmp.w	#1,d0
		bne	2$
		move.b	dsTocFirst(a2),d0
		bsr	ToBCD
		move.b	d0,csParam(a0)
		move.b	dsTocLast(a2),d0
		bsr	ToBCD
		move.b	d0,csParam+1(a0)
		clr.w	csParam+2(a0)
		bra	IOReturnOK
2$		cmp.w	#2,d0
		bne	3$
		move.l	dsTocLeadOut(a2),d0
		bsr	FramesToBCD
		lsl.l	#8,d0
		move.l	d0,csParam(a0)		;mm ss ff
		bra	IOReturnOK
3$		cmp.w	#3,d0
		bne	IOParamErr
		movem.l	d1-d4/a1,-(sp)
		move.l	csParam+2(a0),a1	;Puffer: je Track Control, mm ss ff
		moveq	#0,d4
		move.w	csParam+6(a0),d4	;Pufferlaenge
		moveq	#0,d0
		move.b	csParam+8(a0),d0	;Ab Track (BCD)
		bsr	FromBCD
		moveq	#0,d3
		move.b	dsTocFirst(a2),d3
		cmp.l	d3,d0
		bls	4$
		move.l	d0,d3
4$		moveq	#0,d1
		move.b	dsTocLast(a2),d1
		lea	dsToc(a2),a0
5$		subq.l	#4,d4			;Puffer zu Ende?
		bmi	6$
		cmp.l	d1,d3
		bhi	7$
		move.l	-4(a0,d3.l*4),d2
		move.l	d2,d0
		and.l	#$00ffffff,d0
		bsr	FramesToBCD
		and.l	#$ff000000,d2
		or.l	d2,d0
		move.l	d0,(a1)+
		addq.l	#1,d3
		bra	5$
7$		move.l	-4(a0,d1.l*4),d2	;Lead-out als letzter Eintrag
		and.l	#$ff000000,d2
		move.l	dsTocLeadOut(a2),d0
		bsr	FramesToBCD
		or.l	d2,d0
		move.l	d0,(a1)
6$		movem.l	(sp)+,d1-d4/a1
		bra	IOReturnOK

; d0.b binaer (0-99) -> d0 BCD
ToBCD		move.l	d1,-(sp)
		and.l	#$ff,d0
		divu.w	#10,d0			;Rest<<16 | Zehner
		move.w	d0,d1
		lsl.w	#4,d1
		swap	d0
		or.w	d1,d0
		and.l	#$ff,d0
		move.l	(sp)+,d1
		rts

; d0.b BCD -> d0 binaer
FromBCD		move.l	d1,-(sp)
		and.l	#$ff,d0
		move.l	d0,d1
		lsr.l	#4,d1
		mulu.w	#10,d1
		and.l	#$0f,d0
		add.l	d1,d0
		move.l	(sp)+,d1
		rts

; d0: Frames -> d0: $00mmssff (BCD)
FramesToBCD	movem.l	d1-d3,-(sp)
		divu.w	#75,d0
		move.l	d0,d3
		swap	d3			;d3.w: Frames
		and.l	#$ffff,d0
		divu.w	#60,d0
		move.l	d0,d2
		swap	d2			;d2.w: Sekunden
		and.l	#$ffff,d0		;Minuten
		bsr	ToBCD
		move.l	d0,d1
		lsl.l	#8,d1
		move.w	d2,d0
		bsr	ToBCD
		or.b	d0,d1
		lsl.l	#8,d1
		move.w	d3,d0
		bsr	ToBCD
		or.b	d0,d1
		move.l	d1,d0
		movem.l	(sp)+,d1-d3
		rts


*
* Status()-Routine
*

Status		movem.l	a0-a1,-(sp)
		bsr	GetDrvStatus	;Laufwerk vorhanden?

; Status-Code abfragen
; 6: Get Drive Geometry
		cmp.w	#6,csCode(a0)
		bne	StatusNot6

		tst.w	csParam(a0)
		ble	IOParamErr

		move.w	#1,csParam(a0)	;Anzahl Formate
		move.l	csParam+2(a0),a0
		move.l	dsDriveSize(a2),d0
		swap	d0
		move.l	d0,(a0)+
		move.l	#$40000000,(a0)+
		bra	IOReturnOK

; 8: Get Drive Status
StatusNot6	cmp.w	#8,csCode(a0)
		bne	StatusNot8

		lea	csParam(a0),a0
		moveq	#10,d0
1$		move.w	(a2)+,(a0)+
		dbra	d0,1$
		bra	IOReturnOK

StatusNot8	bra	IOStatusImpl


*
* Prüft, ob das angegebene Laufwerk angeschlossen ist,
* (IOParam in a0) und holt das DrvSts nach a2.
* Erzeugt IOError, wenn Laufwerk nicht vorhanden.
* Darf a0 und a1 nicht verändern!
*

GetDrvStatus	move.w	ioVRefNum(a0),d0
		bne	1$
		bsr	GetCDDrv	;Keine Laufwerksnummer: das CD-Abbild
		beq	GetDrvNoDrv
1$		bsr	GetDrvA2
		tst.b	dsInstalled(a2)
		beq	GetDrvNoDrv
		rts

; Laufwerksnummer des ersten CD-Abbilds mit Inhaltsverzeichnis nach d0
; (Z: keins). CD-Programme rufen den Treiber ohne Laufwerksnummer auf.
GetCDDrv	movem.l	d1/a2,-(sp)
		lea	DriveStatus1,a2
		moveq	#NUMAFD-1,d1
1$		tst.b	dsTocLast(a2)
		beq	2$
		tst.l	dsFileHandle(a2)
		beq	2$
		move.w	dsDriveNum(a2),d0
		bra	3$
2$		lea	MyDrvSts_SIZEOF(a2),a2
		dbra	d1,1$
		moveq	#0,d0
3$		movem.l	(sp)+,d1/a2
		tst.w	d0
		rts

; Holt das DrvSts von Laufwerk d0 nach a2
GetDrvA2	move.l	d1,-(sp)
		lea	DriveStatus1,a2
		moveq	#NUMAFD-1,d1
1$		cmp.w	dsDriveNum(a2),d0
		beq	2$
		lea	MyDrvSts_SIZEOF(a2),a2
		dbra	d1,1$
		move.l	(sp)+,d1
		bsr	GetCDDrv	;Unbekannte Nummer: CD-Programme sprechen den Treiber direkt
		bne	GetDrvA2	; an und lassen das Feld auch uninitialisiert - das CD-Abbild
		addq.l	#4,sp		;Kein solches Laufwerk: auch die Ruecksprungadresse
					; nach GetDrvStatus loeschen (GetDrvNoDrv entfernt nur eine)
		bra	GetDrvNoDrv
2$		move.l	(sp)+,d1
		rts

GetDrvNoDrv	move.l	(sp)+,d0	;RTS löschen
		bra	IONoDrive


*
* Rückkehr aus Treiberroutine
*

IOParamErr	moveq	#-50,d0		;Parameter Error
		bra	IOReturn
IOOffLine	moveq	#-65,d0		;Volume Off Line (kein Abbild im Laufwerk)
		bra	IOReturn
IONoDrive	moveq	#-56,d0		;No Such Drive
		bra	IOReturn
IOControlImpl	moveq	#-17,d0		;Unimplemented control
		bra	IOReturn
IOStatusImpl	moveq	#-18,d0		;Unimplemented status
		bra	IOReturn

IOReturnOK	moveq	#0,d0		;Alles OK

IOReturn	movem.l	(sp)+,a0-a1	;ParamBlock und DCE wiederherstellen

; Jeden beendeten Aufruf in einen Ring von 256 Eintraegen schreiben (16 Bytes:
; ioTrap, ioVRefNum, ioRefNum, csCode, Ergebnis, Ticks.w, csParam.l)
		cmp.b	#3,ioTrap+1(a0)	;Read/Write nur bei Fehlern (sonst fuellen sie den Ring)
		bhi	DrvLogIt
		tst.w	d0
		bpl	DrvLogSkip
DrvLogIt	movem.l	d1/a2,-(sp)
		lea	DrvLog,a2
		move.w	DrvLogIdx,d1
		addq.w	#1,DrvLogIdx
		and.w	#255,d1
		lsl.w	#4,d1
		add.w	d1,a2
		move.w	ioTrap(a0),(a2)+
		move.w	ioVRefNum(a0),(a2)+
		move.w	ioRefNum(a0),(a2)+
		move.w	csCode(a0),(a2)+
		move.w	d0,(a2)+
		move.w	$16c,(a2)+
		move.l	csParam(a0),(a2)+
		movem.l	(sp)+,d1/a2
DrvLogSkip

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


; Wenn der FileTask beschäftigt ist, auf Beendigung warten
AFDWaitComplete	tst.b	FileBusy
		beq	WaitDidIt
		bsr	CanWait			;Im FileTask (IODone) oder in einem Interrupt
		bne	WaitDidIt		; darf nicht gewartet werden
		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	_ExecBase(pc),a6
1$		move.l	FTReadySet,d0
		EJSRLIB	Wait
		tst.b	FileBusy
		bne	1$
		movem.l	(sp)+,d0-d1/a0-a1/a6
WaitDidIt	rts

; Z gesetzt: wir laufen im Mac-Task auf Interrupt-Ebene 0 und duerfen Wait()
; rufen. Sonst (IODone aus dem FileTask startet den naechsten Auftrag, oder
; ein Mac-Interrupt ruft den Treiber) wuerde Wait() im falschen Task oder in
; einem Interrupt schlafen. Aendert keine Register.
CanWait		movem.l	d0/a6,-(sp)
		move	sr,d0
		and.w	#$0700,d0
		bne	1$
		move.l	_ExecBase(pc),a6
		move.l	276(a6),d0		;ThisTask
		cmp.l	MyTask,d0
1$		movem.l	(sp)+,d0/a6
		rts


**
** Subtask für File-Handling
**

; Task ermitteln
FileTaskMain	move.l	_ExecBase(pc),a6
		sub.l	a1,a1
		JSRLIB	FindTask
		move.l	d0,FileTask

; Signale zur Kommunikation anfordern
		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,FileSignalSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,FileSignalSet

		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,FileQuitSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,FileQuitSet

		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,FileEjectSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,FileEjectSet

		clr.w	FileError

; Dem Emulator Bescheid sagen
		move.l	MyTask,a1
		move.l	SubtaskSet,d0
		JSRLIB	Signal

; Hauptschleife: Auf Signal warten
FTMainLoop	move.l	_ExecBase(pc),a6
		move.l	FileSignalSet,d0
		or.l	FileQuitSet,d0
		or.l	FileEjectSet,d0
		JSRLIB	Wait
		move.l	d0,TheSignals

FTSigLoop	move.l	TheSignals,d0
		move.l	d0,d1
		and.l	FileSignalSet,d1
		beq	1$
		eor.l	d1,TheSignals
		bra	FTDoIO

1$		move.l	d0,d1
		and.l	FileEjectSet,d1
		beq	2$
		eor.l	d1,TheSignals
		bra	FTEject

2$		move.l	d0,d1
		and.l	FileQuitSet,d1
		beq	FTMainLoop
		eor.l	d1,TheSignals
		bra	FTQuit

; Eject: Datei schliessen, Laufwerk leer
FTEject		move.w	EjectDrive,d0
		lea	DriveStatus1,a2
		moveq	#NUMAFD-1,d1
2$		cmp.w	dsDriveNum(a2),d0
		beq	3$
		lea	MyDrvSts_SIZEOF(a2),a2
		dbra	d1,2$
		bra	4$			;(kein solches Laufwerk)
3$		move.l	_DOSBase,a6
		move.l	dsFileHandle(a2),d1
		beq	1$
		JSRLIB	Close
1$		clr.l	dsFileHandle(a2)
		clr.b	dsDiskInPlace(a2)
		clr.l	dsDriveSize(a2)
		move.l	#-1,dsFilePos(a2)
4$		st.b	EjectDone
		move.l	_ExecBase(pc),a6
		move.l	MyTask,a1
		move.l	FTReadySet,d0
		JSRLIB	Signal
		bra	FTSigLoop

; Ein Abbild einlegen (aus dem Hilfsprozess, MacEmulPRam.asm): ins erste
; leere Laufwerk, dann dem Mac die neue Disk melden.
; a0: voller Dateiname. d0 = 0: eingelegt, 1: kein Laufwerk frei, 2: Datei nicht zu oeffnen
InsertImage	movem.l	d1-d7/a0-a6,-(sp)
		lea	DriveStatus1,a2
		moveq	#NUMAFD-1,d7
1$		tst.l	dsFileHandle(a2)
		beq	2$
		lea	MyDrvSts_SIZEOF(a2),a2
		dbra	d7,1$
		moveq	#1,d0
		bra	9$
2$		bsr	OpenOneDisk
		tst.l	dsFileHandle(a2)
		bne	3$
		moveq	#2,d0
		bra	9$
3$		move.b	#1,dsDiskInPlace(a2)
		move.w	dsDriveNum(a2),PostDrive
		move.l	_ExecBase(pc),a6	;Dem Mac die neue Disk melden
		lea	SuperInserted,a5
		JSRLIB	Supervisor
		moveq	#0,d0
9$		movem.l	(sp)+,d1-d7/a0-a6
		rts

SuperInserted	moveq	#0,d0
		move.w	PostDrive,d0
		move.w	#7,a0			;diskEvent
		dc.w	$a02f			;PostEvent
		rte

; Signal eingetroffen, IO-Daten holen, Laufwerk setzen
FTDoIO		move.l	FileParmBlock,a0
		move.b	FileTaskAsync,FTReqAsync	;Gilt fuer diesen Auftrag
		move.l	FileDrvSts,a2		;DriveSts nach a2

		move.l	FileParmBlock,a0
		move.l	FileDCE,a1

		move.l	dCtlPosition(a1),d2	;d2: Startbyte
		bmi	FTIOOutOfRange		;Negativ: Fehler

		move.l	ioBuffer(a0),a3		;a3: Zieladresse
		move.l	ioReqCount(a0),d4	;d4: Anzahl Bytes
		tst.l	dsRawSec(a2)		;Rohe CD-Sektoren
		bne	FTRawIO

; Seeken
		move.l	_DOSBase,a6
		move.l	dsFileHandle(a2),d1	;d2 enthält das Startbyte
		cmp.l	dsFilePos(a2),d2
		beq	FTSeeked
		move.l	d2,-(sp)
		add.l	dsOffset(a2),d2		;DiskCopy-Kopf ueberspringen
		moveq	#OFFSET_BEGINNING,d3
		JSRLIB	Seek
		move.l	(sp)+,d2
		cmp.l	#-1,d0
		beq	FTSeekErr

; Schreiben oder Lesen?
FTSeeked	move.l	FileParmBlock,a0
		cmp.b	#aWrCmd,ioTrap+1(a0)
		beq	FTWrite

; Lesen
FTRead		move.l	dsFileHandle(a2),d1
		move.l	a3,d2			;Buffer
		move.l	d4,d3			;Länge
		JSRLIB	Read
		move.l	d0,d3			;Actual retten
		cmp.l	d4,d3			;Soviele wie requested?
		beq	FTIODoneOK
		moveq	#-19,d0			;Read Error
		bra	FTIODone

; Rohe CD-Sektoren: nur lesen
FTRawIO		move.l	_DOSBase,a6
		move.l	FileParmBlock,a0
		cmp.b	#aWrCmd,ioTrap+1(a0)
		beq	2$
		add.l	dsOffset(a2),d2
		move.l	d4,d3
		move.l	a3,a1
		bsr	ReadAt
		move.l	d0,d3
		cmp.l	d4,d3
		beq	FTIODoneOK
		tst.l	d3
		bpl	1$
		moveq	#0,d3
1$		moveq	#-19,d0			;Read Error
		bra	FTIODone
2$		moveq	#-44,d0			;Write Protected
		moveq	#0,d3
		bra	FTIODone

FTSeekErr	moveq	#-80,d0			;Seek Error
		moveq	#0,d3			;Actual=0
		bra	FTIODone

; Schreiben
FTWrite		tst.b	dsWriteProt(a2)
		beq	1$
		moveq	#-44,d0			;Write Protected
		moveq	#0,d3
		bra	FTIODone
1$		move.l	dsFileHandle(a2),d1
		move.l	a3,d2			;Buffer
		move.l	d4,d3			;Länge
		JSRLIB	Write
		move.l	d0,d3			;Actual retten
		cmp.l	d4,d3			;Soviele wie requested?
		beq	FTIODoneOK
		moveq	#-20,d0			;Write Error
		bra	FTIODone

; IO-Vorgang beenden, Emulator benachrichtigen
FTIOOutOfRange	moveq	#-50,d0			;Param Error
		moveq	#0,d3			;Kein Transfer
		bra	FTIODone

FTIODoneOK	moveq	#0,d0			;Alles klar

FTIODone	move.w	d0,FileError
		move.w	d0,DskErr

		tst.l	d3			;Read/Write failed outright (-1): nothing moved
		bpl	1$
		moveq	#0,d3
1$		move.l	FileParmBlock,a0	;Zähler erhöhen
		move.l	FileDCE,a1
		move.l	d3,ioActCount(a0)
		add.l	d3,dCtlPosition(a1)
		move.l	dCtlPosition(a1),dsFilePos(a2)
		tst.w	FileError		;After an error the file position is unknown:
		beq	2$			; seek before the next transfer
		move.l	#-1,dsFilePos(a2)
2$

		move.l	_ExecBase(pc),a6
		move.l	FileDCE,a2
		move.w	FileError,d2

		clr.b	FileBusy
		move.l	MyTask,a1
		move.l	FTReadySet,d0
		JSRLIB	Signal

		tst.b	FTReqAsync
		beq	FTSigLoop

		lea	FTJumpIODone,a5
		JSRLIB	Supervisor
		bra	FTSigLoop

FTJumpIODone	move.w	d2,d0		;FileError
		move.l	a2,a1		;FileDCE
		move.l	JIODone,a0
		jsr	(a0)
		and.w	#$f8ff,sr
		rte

; FileTask beenden
FTQuit		move.l	_ExecBase(pc),a6

		move.b	FileEjectSig,d0
		JSRLIB	FreeSignal
		move.b	FileSignalSig,d0
		JSRLIB	FreeSignal
		move.b	FileQuitSig,d0
		JSRLIB	FreeSignal

		JSRLIB	Forbid
		move.l	MyTask,a1
		move.l	SubtaskSet,d0
		JSRLIB	Signal
		moveq	#0,d0
		rts


**
** Konstanten
**

; Strings
FileTaskName	dc.b	"ShapeShifter FileTask",0
		CNOP	0,4

; Disketten-Icon
DiskICON	dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$7FFFFFFE
		dc.l	$80000001,$80000001,$80000001,$80000001
		dc.l	$80000001,$8C000001,$80000001,$80000001
		dc.l	$7FFFFFFE,$00000000,$00000000,$00000000

		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$00000000
		dc.l	$00000000,$00000000,$00000000,$7FFFFFFE
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$FFFFFFFF,$FFFFFFFF,$FFFFFFFF,$FFFFFFFF
		dc.l	$7FFFFFFE,$00000000,$00000000,$00000000

		dc.w	0

; Laufwerks-Icons
DriveICON1	dc.l	$1FFFFC00,$10000600,$10000500,$10000480
		dc.l	$10040440,$10080420,$111007F0,$10A00010
		dc.l	$10400010,$10000010,$10000010,$10000010
		dc.l	$10000010,$10010010,$10030010,$10010010
		dc.l	$10010010,$10010010,$10038010,$10000010
		dc.l	$10000010,$10FFFC10,$11000210,$11000210
		dc.l	$11400210,$11000210,$10FFFC10,$10000010
		dc.l	$10000010,$10000010,$10000010,$1FFFFFF0

		dc.l	$1FFFFC00,$1FFFFE00,$1FFFFF00,$1FFFFF80
		dc.l	$1FFFFFC0,$1FFFFFE0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0

		dc.b	16,"Amiga FileDisk 1"
		EVEN

DriveICON2	dc.l	$1FFFFC00,$10000600,$10000500,$10000480
		dc.l	$10040440,$10080420,$111007F0,$10A00010
		dc.l	$10400010,$10000010,$10000010,$10000010
		dc.l	$10000010,$10030010,$10048010,$10008010
		dc.l	$10010010,$10020010,$10078010,$10000010
		dc.l	$10000010,$10FFFC10,$11000210,$11000210
		dc.l	$11400210,$11000210,$10FFFC10,$10000010
		dc.l	$10000010,$10000010,$10000010,$1FFFFFF0

		dc.l	$1FFFFC00,$1FFFFE00,$1FFFFF00,$1FFFFF80
		dc.l	$1FFFFFC0,$1FFFFFE0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0

		dc.b	16,"Amiga FileDisk 2"
		EVEN

DriveICON3	dc.l	$1FFFFC00,$10000600,$10000500,$10000480
		dc.l	$10040440,$10080420,$111007F0,$10A00010
		dc.l	$10400010,$10000010,$10000010,$10000010
		dc.l	$10000010,$10030010,$10048010,$10010010
		dc.l	$10008010,$10048010,$10030010,$10000010
		dc.l	$10000010,$10FFFC10,$11000210,$11000210
		dc.l	$11400210,$11000210,$10FFFC10,$10000010
		dc.l	$10000010,$10000010,$10000010,$1FFFFFF0

		dc.l	$1FFFFC00,$1FFFFE00,$1FFFFF00,$1FFFFF80
		dc.l	$1FFFFFC0,$1FFFFFE0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0

		dc.b	16,"Amiga FileDisk 3"
		EVEN

DriveICON4	dc.l	$1FFFFC00,$10000600,$10000500,$10000480
		dc.l	$10040440,$10080420,$111007F0,$10A00010
		dc.l	$10400010,$10000010,$10000010,$10000010
		dc.l	$10000010,$10010010,$10030010,$10050010
		dc.l	$10078010,$10010010,$10010010,$10000010
		dc.l	$10000010,$10FFFC10,$11000210,$11000210
		dc.l	$11400210,$11000210,$10FFFC10,$10000010
		dc.l	$10000010,$10000010,$10000010,$1FFFFFF0

		dc.l	$1FFFFC00,$1FFFFE00,$1FFFFF00,$1FFFFF80
		dc.l	$1FFFFFC0,$1FFFFFE0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0
		dc.l	$1FFFFFF0,$1FFFFFF0,$1FFFFFF0,$1FFFFFF0

		dc.b	16,"Amiga FileDisk 4"
		EVEN

; Je File-Disk: Dateiname (Einstellungen), Mac-Laufwerksnummer, Icon
		CNOP	0,4
AFDDriveTab	dc.w	AFDDrive,AFDDrive+1,AFDDrive+3,AFDDrive+4
AFDIconTab	dc.l	DriveICON1,DriveICON2,DriveICON3,DriveICON4
HFSPartType	dc.b	"Apple_HFS",0
KwFile		dc.b	"FILE",0
KwTrack		dc.b	"TRACK",0
KwIndex		dc.b	"INDEX",0
		EVEN
		EVEN

		CNOP	0,4
ProcTags	dc.l	NP_Entry,FileTaskMain
		dc.l	NP_StackSize,16384	;icon.library / AppIcon brauchen mehr als 4K
		dc.l	NP_Name,FileTaskName
		dc.l	NP_Priority,1
		dc.l	0,0

**
** Nicht initialisierte Daten
**

		SECTION	"BSS",BSS
FIB		ds.b	260		;FileInfoBlock für ExamineFH()

DriveStatus1	ds.b	MyDrvSts_SIZEOF	;DriveStatus für FileDisk 1 (HD20)
DriveStatus2	ds.b	MyDrvSts_SIZEOF	;DriveStatus für FileDisk 2 (HD20)
DriveStatus3	ds.b	MyDrvSts_SIZEOF	;FileDisk 3
DriveStatus4	ds.b	MyDrvSts_SIZEOF	;FileDisk 4
DCHeader	ds.b	84		;Kopf einer DiskCopy-4.2-Datei
PMBuf		ds.b	512		;Ein Block der Partitionstabelle
CUEBUFSIZE	= 4096
CUEPATHSIZE	= 256
CUENAMESIZE	= 128
CueBuf		ds.b	CUEBUFSIZE	;Inhalt einer .cue-Datei
CuePath		ds.b	CUEPATHSIZE	;Pfad der .bin
CueName		ds.b	CUENAMESIZE	;Name der .bin aus der .cue

FileTaskProc	ds.l	1	;ProcID des FileTask
FileTask	ds.l	1	;Zeiger auf Task des Prozesses

TheSignals	ds.l	1	;Empfangene Signale

FileParmBlock	ds.l	1	;DiskIO-ParamBlock für FileTask
FileDCE		ds.l	1	;DriverControlEntry für FileTask
FileDrvSts	ds.l	1	;DrvSts des Laufwerks fuer FileTask
FileError	ds.w	1	;Fehlercode des FileTask

FileSignalSet	ds.l	1	;Signal: FileTask soll Daten lesen/schreiben
FileQuitSet	ds.l	1	;Signal: FileTask soll sich beenden
FTReadySet	ds.l	1	;Signal: FileTask fertig
FileEjectSet	ds.l	1	;Signal: FileTask soll ein Abbild auswerfen
PostDrive	ds.w	1
EjectDrive	ds.w	1
EjectDone	ds.b	1
FileEjectSig	ds.b	1
FileSignalSig	ds.b	1
FileQuitSig	ds.b	1
FTReadySig	ds.b	1

FileTaskAsync	ds.b	1	;#0: Der FileTask bearbeitet gerade etwas asynchron
DrvLogIdx	ds.w	1	;Naechster Eintrag in DrvLog
DrvLog		ds.b	16*256
FileBusy	ds.b	1	;#0: Der FileTask hat einen Auftrag in Arbeit
FTReqAsync	ds.b	1	;FileTaskAsync des laufenden Auftrags

		END
