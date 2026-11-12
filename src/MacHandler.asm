*
* Mac-Handler - Zugriff auf Mac-Partitionen von der Amiga-Seite
*
* © Copyright 1994-2001 Christian Bauer
*

		MACHINE	68020

**
** Konvention in allen Routinen: a6 muß _SysBase enthalten
**

DEBUG_DETAIL	SET	0

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/nodes.i"
		INCLUDE	"exec/io.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"dos/dos.i"
		INCLUDE	"dos/dosextens.i"
		INCLUDE	"dos/filehandler.i"
		INCLUDE	"devices/input.i"
		INCLUDE	"devices/inputevent.i"

		INCLUDE	"macinclude.i"
		INCLUDE	"shapesupport.i"

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
		lea.l	PSS\@(pc),A0
		lea.l	4*2(sp),A1
		jsr	KPrintF
		movem.l (sp)+,a0/a1
		bra.s	PSE\@

PSS\@		dc.b	\1
		dc.b	13,10,0
		even
PSE\@
		lea.l	PUSHCOUNT(sp),sp

		movem.l	(sp)+,d0-d1/a0-a1
	ENDC
		ENDM


**
** Definitionen
**

ACTION_USER	= 2050

*
* Datenstrukturen
*

; Das fl_Key unserer Locks und das fh_Arg1 unserer FileHandles
; zeigt auf eine solche Struktur
 STRUCTURE	MacObject,0
	WORD	mo_FDirIndex		;Für ExNext
	WORD	mo_VRefNum		;Volume reference number
	WORD	mo_FRefNum		;File reference number (für geöffnete Dateien, sonst 0)
	WORD	mo_res0
	LONG	mo_ParDirID		;Directory ID des Dirs, in dem das Objekt liegt
	LONG	mo_DirID		;0: Datei, #0: Directory ID dieses Verzeichnisses
	LONG	mo_Pos			;Position des Schreib-/Lese-Zeigers
	LONG	mo_Size			;Größe der Datei (für Seek)
	STRUCT	mo_Name,36		;Name des Objekts (BSTR)
 LABEL	mo_SIZEOF

*
* Makros
*

; Rückkehr aus einer Mac-Routine, Handler benachrichtigen
RETMAC	MACRO
		move.w	d0,MacResult
		move.l	a6,-(sp)
		move.l	_SysBase,a6
		move.l	MyTask,a1
		move.l	MacSignalSet,d0
		JSRLIB	Signal
		move.l	(sp)+,a6
		rts
	ENDM


**
** Startup/Exit
**

		SECTION	"CODE",CODE

; _SysBase und MyTask setzen
Main		move.l	(4).w,a6
		move.l	a6,_SysBase

		sub.l	a1,a1
		JSRLIB	FindTask
		move.l	d0,MyTask
		add.l	#pr_MsgPort,d0
		move.l	d0,MyProc

		move.l	MyTask,a0	;Als Programm aufgerufen?
		tst.l	pr_CLI(a0)
		bne	ExitFail	;Ja, dann Abbruch

; Globale Variablen löschen
		move.l	#1,VolumeIndex
		clr.l	VolumeNode
		clr.l	NumberOfLocks
		clr.l	NumberOfHandles
		clr.w	VRefNum
		clr.b	UseRsrcFork
		move.l	#'TEXT',FileType
		move.l	#'ttxt',FileCreator

; DOS öffnen
		lea	DOSName,a1
		moveq	#0,d0
		JSRLIB	OpenLibrary
		move.l	d0,_DOSBase

; Signal für ExecMacProc holen
		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,MacSignal
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,MacSignalSet

; Speicher für VolumeNode holen
		move.l	#DevList_SIZEOF,d0
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		JSRLIB	AllocVec
		move.l	d0,VolumeNode
		beq	ExitFail

; Auf Startup-Packet warten und Daten entnehmen
		bsr	WaitPacket
		move.l	dp_Arg3(a0),d0
		add.l	d0,d0
		add.l	d0,d0
		move.l	d0,MyNode
		move.l	dp_Arg2(a0),d0
		beq	1$
		move.l	d0,VolumeIndex
1$

; dn_Task setzen
		move.l	MyNode,a0
		move.l	MyProc,dn_Task(a0)

; Mac-VolumeInfo holen
		bsr	GetVolInfo
		tst.l	d0
		beq	VolInfoOK
		bsr	ReturnPacketErr
		bra	ExitHandler

; Gelungen, Startup-Packet zurückschicken
VolInfoOK	bsr	ReturnPacketOK

; RootObject einrichten
		move.w	VolumeInfo+ioVRefNum,VRefNum

		lea	RootObject,a0
		clr.w	mo_FDirIndex(a0)
		move.w	VRefNum,mo_VRefNum(a0)
		move.l	#fstRtParID,mo_ParDirID(a0)
		move.l	#fstRtDirID,mo_DirID(a0)
		lea	mo_Name(a0),a1		;Ziel
		lea	VolumeName,a0		;Quelle
		bsr	CopyBSTR

; Mac-Volume mounten
		lea	VolumeName,a0		;Name Null-terminieren
		moveq	#0,d0
		move.b	(a0)+,d0
		clr.b	(a0,d0.w)

		move.l	VolumeNode,a0
		move.l	#DLT_VOLUME,dl_Type(a0)
		move.l	#VolumeName,d0
		asr.l	#2,d0
		move.l	d0,dl_Name(a0)
		move.l	MyProc,dl_Task(a0)
		move.l	#ID_DOS_DISK,dl_DiskType(a0)

		move.l	VolumeInfo+ioVCrDate,d0
		lea	dl_VolumeDate(a0),a0
		bsr	MacToDateStamp

		move.l	_DOSBase,a6
		move.l	VolumeNode,d1
		JSRLIB	AddDosEntry

; "Diskette einlegen"
		move.l	_SysBase,a6
		moveq	#-1,d0		;Inserted
		bsr	SendEvent

; Hauptschleife ausführen
		bsr	MainLoop

; Aufräumen
		move.l	MyNode,a0
		clr.l	dn_Task(a0)
		bra	ExitHandler

; Beenden
ExitHandler	DPRINTF	"Exiting"

		tst.l	VolumeNode
		beq	ExitNotMounted

		move.l	VolumeNode,a0		;Handler neu laden
		clr.l	dl_Task(a0)

		move.l	_DOSBase,a6		;Volume unmounten
		move.l	#LDF_VOLUMES|LDF_WRITE,d1
		JSRLIB	LockDosList
		move.l	VolumeNode,d1
		JSRLIB	RemDosEntry
		move.l	#LDF_VOLUMES|LDF_WRITE,d1
		JSRLIB	UnLockDosList
		move.l	_SysBase,a6
		move.l	VolumeNode,a1
		JSRLIB	FreeVec

		moveq	#0,d0			;Removed
		bsr	SendEvent

ExitNotMounted	move.l	_SysBase,a6
		move.b	MacSignal,d0
		JSRLIB	FreeSignal

		JSRLIB	Forbid

		move.l	_DOSBase,a6
		move.l	MyNode,a0
		move.l	dn_SegList(a0),d1
		JSRLIB	UnLoadSeg

		move.l	_SysBase,a6
		move.l	_DOSBase,a1
		JSRLIB	CloseLibrary

		move.l	MyNode,a0
		clr.l	dn_SegList(a0)

ExitOK		moveq	#0,d0
		rts

ExitFail	moveq	#20,d0
		rts


**
** Hauptschleife des Handlers
**

; Packet holen
MainLoop	bsr	WaitPacket

; Typ auswerten
		move.l	dp_Type(a0),d0
		cmp.l	#ACTION_DIE,d0
		beq	Die

		lea	ActionTable,a1
1$		move.l	(a1)+,d1
		bmi	NotKnown
		cmp.l	d1,d0
		beq	ActFound
		addq.l	#4,a1
		bra	1$

; Routine aufrufen. Diese muß das Packet selbst zurücksenden!
ActFound	move.l	(a1),a1
		jsr	(a1)

; Wiederholen
		bra	MainLoop

; Unbekanntes Packet
NotKnown	DPRINTF	"Received unknown packet type %08lx",d0
		move.l	#ERROR_ACTION_NOT_KNOWN,d0
		bsr	ReturnPacketErr
		bra	MainLoop

; ACTION_DIE: Handler beenden
Die		bsr	ReturnPacketOK
		tst.l	NumberOfLocks
		bne	MainLoop
		tst.l	NumberOfHandles
		bne	MainLoop
		rts


**
** Actions
**

; Tabelle der Action-Routinen
ActionTable	dc.l	ACTION_IS_FILESYSTEM,IsFileSystem
		dc.l	ACTION_FLUSH,Flush

		dc.l	ACTION_CURRENT_VOLUME,CurrentVolume
		dc.l	ACTION_INFO,LockInfo
		dc.l	ACTION_DISK_INFO,DiskInfo
		dc.l	ACTION_RENAME_DISK,RenameDisk

		dc.l	ACTION_LOCATE_OBJECT,LocateObject
		dc.l	ACTION_COPY_DIR,CopyDir
		dc.l	ACTION_FREE_LOCK,FreeLock
		dc.l	ACTION_SAME_LOCK,SameLock
		dc.l	ACTION_EXAMINE_FH,ExamineFH
		dc.l	ACTION_EXAMINE_OBJECT,ExamineObject
		dc.l	ACTION_EXAMINE_NEXT,ExamineNext
		dc.l	ACTION_PARENT_FH,ParentFH
		dc.l	ACTION_PARENT,Parent
		dc.l	ACTION_SET_PROTECT,SetProtect
		dc.l	ACTION_SET_DATE,SetDate
		dc.l	ACTION_SET_COMMENT,SetComment
		dc.l	ACTION_CREATE_DIR,CreateDir
		dc.l	ACTION_DELETE_OBJECT,DeleteObject
		dc.l	ACTION_RENAME_OBJECT,RenameObject

		dc.l	ACTION_FINDINPUT,FindInput
		dc.l	ACTION_FINDOUTPUT,FindOutput
		dc.l	ACTION_FINDUPDATE,FindUpdate
		dc.l	ACTION_END,EndFH
		dc.l	ACTION_READ,Read
		dc.l	ACTION_WRITE,Write
		dc.l	ACTION_SEEK,Seek

		dc.l	ACTION_USER,User
		dc.l	-1,-1					;Ende

*
* ACTION_IS_FILESYSTEM: Immer wahr
*

IsFileSystem	DPRINTF	"IsFileSystem"
		bra	ReturnPacketOK

*
* ACTION_FLUSH: Puffer schreiben
*

Flush		DPRINTF	"Flush"
		bsr	FlushVol
		bra	ReturnPacketOK

*
* ACTION_CURRENT_VOLUME: Zeiger auf DeviceListEntry zurückgeben
*  Arg1: FileHandle Arg1
*

CurrentVolume	DPRINTF	"CurrentVolume"
		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),d0
		beq	1$

	;!! DeviceList muß durchsucht werden!

1$		move.l	VolumeNode,d0
		asr.l	#2,d0
		move.l	ThisPacket,a0
		move.l	d0,dp_Res1(a0)
		clr.l	dp_Res2(a0)
		bra	ReturnPacket

*
* ACTION_INFO: InfoData-Struktur ausfüllen
*  Arg1: Lock
*  Arg2: BPTR auf InfoData
*

LockInfo	DPRINTF	"Info"
		bsr	GetVolInfo
		tst.l	d0
		bne	ReturnPacketErr

		move.l	ThisPacket,a0
		move.l	dp_Arg2(a0),a1
		add.l	a1,a1
		add.l	a1,a1
		lea	VolumeInfo,a0
		bra	DiskInfoFill

*
* ACTION_DISK_INFO: InfoData-Struktur ausfüllen
*  Arg1: BPTR auf InfoData
*

; VolumeInfo lesen
DiskInfo	DPRINTF	"DiskInfo"
		bsr	GetVolInfo
		tst.l	d0
		bne	ReturnPacketErr

		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a1
		add.l	a1,a1
		add.l	a1,a1
		lea	VolumeInfo,a0

; Daten in die InfoData-Struktur übertragen
DiskInfoFill	clr.l	id_NumSoftErrors(a1)
		clr.l	id_InUse(a1)
		move.l	VolumeIndex,id_UnitNumber(a1)
		move.l	#ID_DOS_DISK,id_DiskType(a1)

		move.l	VolumeNode,d0
		asr.l	#2,d0
		move.l	d0,id_VolumeNode(a1)

		moveq	#0,d0
		move.w	ioVNmAlBlks(a0),d0
		move.l	d0,id_NumBlocks(a1)
		move.w	ioVNmAlBlks(a0),d0
		sub.w	ioVFrBlk(a0),d0
		move.l	d0,id_NumBlocksUsed(a1)
		move.l	ioVAlBlkSiz(a0),id_BytesPerBlock(a1)

		move.w	ioVAtrb(a0),d0
		and.w	#VA_NOTVALIDATED,d0
		bne	1$
		btst	#VAB_HARDLOCK,ioVAtrb+1(a0)
		bne	2$
		btst	#VAB_SOFTLOCK-8,ioVAtrb(a0)
		bne	2$
		move.l	#ID_VALIDATED,d0
		bra	3$
2$		move.l	#ID_WRITE_PROTECTED,d0
		bra	3$
1$		move.l	#ID_VALIDATING,d0
3$		move.l	d0,id_DiskState(a1)

		bra	ReturnPacketOK

*
* ACTION_RENAME_DISK: Datenträger umbenennen
*  Arg1: BSTR mit neuem Namen
*

RenameDisk	move.l	ThisPacket,a0
		DPRINTF	"RenameDisk name '%b'",dp_Arg1(a0)

; Umbenennen
		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a0
		add.l	a0,a0
		add.l	a0,a0			;a0: Zeiger auf Namen
		bsr	RenameVol
		tst.l	d0
		bne	ReturnPacketErr

; Neuen Namen in die DevList und das RootObject kopieren
		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a0
		add.l	a0,a0
		add.l	a0,a0
		move.l	a0,-(sp)
		lea	VolumeName,a1
		bsr	CopyBSTR
		lea	VolumeName,a0		;Null-terminieren
		moveq	#0,d0
		move.b	(a0)+,d0
		clr.b	(a0,d0.w)
		move.l	(sp)+,a0
		lea	RootObject+mo_Name,a1
		bsr	CopyBSTR

		bra	ReturnPacketOK

*
* ACTION_LOCATE_OBJECT: Neuen Lock erzeugen
*  Arg1: Lock des ParentDir
*  Arg2: BSTR mit Objektname
*  Arg3: Modus
*

LocateObject	move.l	ThisPacket,a0
		DPRINTF	"LocateObject lock %08lx, name '%b', mode %08lx",dp_Arg1(a0),dp_Arg2(a0),dp_Arg3(a0)

; Modus testen. Nur Shared erlauben.
		move.l	ThisPacket,a0
		cmp.l	#SHARED_LOCK,dp_Arg3(a0)
		bne	LocObNotShared

; Objekt des ParentDir holen
		move.l	dp_Arg1(a0),a0
		bsr	ObjFromLock
		move.l	a0,a4			;a4: Parent Object

; Objekt-Name in normalen String konvertieren
		move.l	ThisPacket,a0
		move.l	dp_Arg2(a0),a0
		add.l	a0,a0
		add.l	a0,a0
		lea	StringBuf,a1
		bsr	ConvertBSTR

; Nach ':' suchen
		lea	StringBuf,a0
		bsr	SearchPrefix
		lea	StringBuf,a0
		tst.b	(a0,d0.w)
		bne	LocObMustOpen

; Kein weiteres Element nach ':', dann Parent-Object klonen
		move.l	a4,a0
		bsr	CloneObject
		bra	LocObLock

; Sonst Objekt öffnen
LocObMustOpen	move.l	a4,a0
		lea	StringBuf,a1
		add.l	d0,a1			;d0: Zeichen nach ':'
		moveq	#0,d0			;Nur existierende Objekte
		bsr	OpenObject

; Objekt vorhanden? Dann Lock erzeugen und zurückgeben
LocObLock	move.l	a0,d1			;d0 enthält Fehlercode!
		beq	ReturnPacketErr
		move.l	a0,a2			;a2: Neues Objekt

		move.l	ThisPacket,a0
		move.l	dp_Arg3(a0),d0
		move.l	a2,a0
		bsr	LockObject

		move.l	ThisPacket,a0
		move.l	d0,dp_Res1(a0)
		beq	LocObFailed
		bra	ReturnPacket

; Fehlerbehandlung
LocObFailed	move.l	a2,a0
		bsr	CloseObject
		move.l	#ERROR_NO_FREE_STORE,d0
		bra	ReturnPacketErr

LocObNotShared	move.l	#ERROR_OBJECT_IN_USE,d0
		bra	ReturnPacketErr

*
* ACTION_COPY_DIR: Lock duplizieren
*  Arg1: Lock
*

CopyDir		move.l	ThisPacket,a0
		DPRINTF	"CopyDir lock %08lx",dp_Arg1(a0)

; Objekt des Lock holen und klonen
		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a0
		bsr	ObjFromLock

		bsr	CloneObject
		move.l	a0,d0
		beq	CpyDirNoMem
		move.l	a0,a2			;a2: Neues Objekt

; Lock erzeugen und zurückgeben
		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a0
		add.l	a0,a0
		add.l	a0,a0
		move.l	fl_Access(a0),d0
		move.l	a2,a0
		bsr	LockObject

		move.l	ThisPacket,a0
		move.l	d0,dp_Res1(a0)
		beq	CpyDirFailed
		bra	ReturnPacket

; Fehlerbehandlung
CpyDirFailed	move.l	a2,a0
		bsr	CloseObject
CpyDirNoMem	move.l	#ERROR_NO_FREE_STORE,d0
		bra	ReturnPacketErr

*
* ACTION_FREE_LOCK: Lock vernichten
*  Arg1: Lock
*

FreeLock	move.l	ThisPacket,a0
		DPRINTF	"FreeLock lock %08lx",dp_Arg1(a0)

		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),d0
		beq	1$
		add.l	d0,d0
		add.l	d0,d0
		move.l	d0,a0
		bsr	UnLockObject

1$		bra	ReturnPacketOK

*
* ACTION_SAME_LOCK: Locks auf die gleichen Objekte?
*  Arg1: Lock 1
*  Arg2: Lock 2
*

SameLock	move.l	ThisPacket,a0
		DPRINTF	"SameLock lock1 %08lx, lock2 %08lx",dp_Arg1(a0),dp_Arg2(a0)

; Objekte der Locks holen
		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a0
		bsr	ObjFromLock
		move.l	a0,a2			;a2: Objekt 1

		move.l	ThisPacket,a0
		move.l	dp_Arg2(a0),a0
		bsr	ObjFromLock

; Und vergleichen
		move.l	a2,a1			;a0: Objekt 2
		bsr	SameObjects

		move.l	ThisPacket,a0
		move.l	d0,dp_Res1(a0)
		bra	ReturnPacket

*
* ACTION_EXAMINE_FH: ExamineObject mit FileHandle
*  Arg1: FileHandle Arg1
*  Arg2: BPTR auf FileInfoBlock
*

ExamineFH	move.l	ThisPacket,a0
		DPRINTF	"ExmineFH, arg %08lx",dp_Arg1(a0)

		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a0
		bra	ExamineThis

*
* ACTION_EXAMINE_OBJECT: FileInfoBlock ausfüllen
*  Arg1: Lock
*  Arg2: BPTR auf FileInfoBlock
*

ExamineObject	move.l	ThisPacket,a0
		DPRINTF	"ExamineObject lock %08lx",dp_Arg1(a0)

		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a0
		bsr	ObjFromLock

ExamineThis	move.l	a0,a2			;a2: MacObject
		clr.w	mo_FDirIndex(a0)	;Für ExNext vorbereiten

; FileInfo/DirInfo lesen
		bsr	GetCatInfo		;a0: MacObject
		tst.l	d0
		bne	ReturnPacketErr

		move.l	ThisPacket,a0
		move.l	dp_Arg2(a0),a4
		add.l	a4,a4
		add.l	a4,a4			;a4: FIB
		clr.l	fib_DiskKey(a4)
		lea	FileInfo,a0		;a0: Zeiger auf FileInfo
		lea	mo_Name(a2),a3		;a3: Zeiger auf Namen (Ziel)

; Daten übertragen
ExamineFill	tst.b	UseRsrcFork
		bne	1$

		move.l	ioFlLgLen(a0),fib_Size(a4)
		move.l	ioFlPyLen(a0),d0
		divu.l	VolumeInfo+ioVAlBlkSiz,d0
		move.l	d0,fib_NumBlocks(a4)
		bne	4$
		move.l	#1,fib_NumBlocks(a4)	;Einen Block mindestens
		bra	4$

1$		move.l	ioFlRLgLen(a0),fib_Size(a4)
		move.l	ioFlRPyLen(a0),d0
		divu.l	VolumeInfo+ioVAlBlkSiz,d0
		move.l	d0,fib_NumBlocks(a4)
		bne	4$
		move.l	#1,fib_NumBlocks(a4)	;Einen Block mindestens

4$		clr.l	fib_OwnerUID(a4)
		clr.l	fib_OwnerGID(a4)

		move.b	#9,fib_Comment(a4)	;Type/Creator als Kommentar
		move.l	ioFlFndrInfo+fdType(a0),fib_Comment+1(a4)
		move.b	#'/',fib_Comment+5(a4)
		move.l	ioFlFndrInfo+fdCreator(a0),fib_Comment+6(a4)

		move.l	#ST_FILE,d0
		btst	#FAB_ISDIR,ioFlAttrib(a0)
		beq	2$

		movem.l	a0/a2,-(sp)
		move.w	ioDrNmFls(a0),Scratch1	;Anzahl Objekte als Kommentar
		lea	NumObjsFmt,a0
		lea	Scratch1,a1
		lea	StringBuf2,a2
		bsr	SPrintF
		lea	StringBuf2,a0
		lea	fib_Comment+1(a4),a1
		moveq	#-1,d0
6$		move.b	(a0)+,(a1)+
		dbeq	d0,6$
		not.b	d0
		move.b	d0,fib_Comment(a4)
		movem.l	(sp)+,a0/a2
		move.l	#ST_USERDIR,d0

2$		move.l	d0,fib_DirEntryType(a4)
		move.l	d0,fib_EntryType(a4)

		moveq	#0,d0
		cmp.l	#'APPL',ioFlFndrInfo+fdType(a0)
		beq	5$
		move.l	#FIBF_EXECUTE,d0
5$		btst	#FAB_LOCKED,ioFlAttrib(a0)
		beq	3$
		or.l	#FIBF_WRITE|FIBF_DELETE,d0
3$		move.l	d0,fib_Protection(a4)

		move.l	ioFlMdDat(a0),d0
		lea	fib_DateStamp(a4),a0
		bsr	MacToDateStamp

; Name kopieren. In "dos.i" steht zwar, daß der Name im C-Format
; vorliegen soll, aber diese Konvertierung scheinen Examine()/ExNext()
; intern vorzunehmen.
		move.l	a3,a0
		lea	fib_FileName(a4),a1
		bsr	CopyBSTR
		bra	ReturnPacketOK

*
* ACTION_EXAMINE_NEXT: Verzeichnis durchkämmen
*  Arg1: Lock des Verzeichnisses
*  Arg2: BPTR auf FileInfoBlock
*

ExamineNext	move.l	ThisPacket,a0
		DPRINTF	"ExamineNext lock %08lx",dp_Arg1(a0)

		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a0
		bsr	ObjFromLock

; Wenn sich der Lock auf eine Datei bezieht, Fehlermeldung
		tst.l	mo_DirID(a0)
		beq	ExNxNoDir

; Index erhöhen
		addq.w	#1,mo_FDirIndex(a0)

; FileInfo/DirInfo lesen
		bsr	GetCatInfoIX
		tst.l	d0
		bne	ExNxNoMore

		move.l	ThisPacket,a0
		move.l	dp_Arg2(a0),a4
		add.l	a4,a4
		add.l	a4,a4			;a4: FIB
		lea	FileInfo,a0
		lea	StringBuf,a3		;a3: Zeiger auf Namen

; Daten übertragen und Packet zurückgeben
		bra	ExamineFill

ExNxNoDir	move.l	#ERROR_OBJECT_WRONG_TYPE,d0
		bra	ReturnPacketErr

ExNxNoMore	move.l	#ERROR_NO_MORE_ENTRIES,d0
		bra	ReturnPacketErr

*
* ACTION_PARENT_FH: Parent für FileHandle
*  Arg1: FileHandle Arg1
*

ParentFH	move.l	ThisPacket,a0
		DPRINTF	"ParentFH arg %08lx",dp_Arg1(a0)

		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a0
		bra	ParentThis

*
* ACTION_PARENT: Lock auf Übergeordnetes Verzeichnis holen
*  Arg1: Lock
*

Parent		move.l	ThisPacket,a0
		DPRINTF	"Parent lock %08lx",dp_Arg1(a0)

		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a0
		bsr	ObjFromLock

; Parent-DirectoryID lesen
ParentThis	move.l	mo_ParDirID(a0),d0
		cmp.l	#fstRtParID,d0
		beq	ParIsRoot

; Parent zum Objekt öffnen
		bsr	OpenParent

; Objekt vorhanden? Dann Lock erzeugen und zurückgeben
		move.l	a0,d1			;d0: Fehlercode!
		beq	ReturnPacketErr
		move.l	a0,a2			;a2: Neues Objekt

		move.l	a2,a0
		move.l	#ACCESS_READ,d0
		bsr	LockObject

		move.l	ThisPacket,a0
		move.l	d0,dp_Res1(a0)
		beq	ParLockFailed
		bra	ReturnPacket

; Parent des Root-Verzeichnisses existiert nicht
ParIsRoot	move.l	ThisPacket,a0
		clr.l	dp_Res1(a0)
		clr.l	dp_Res2(a0)
		bra	ReturnPacket

; Fehlerbehandlung
ParLockFailed	move.l	a2,a0
		bsr	CloseObject
		move.l	#ERROR_NO_FREE_STORE,d0
		bra	ReturnPacketErr

*
* ACTION_SET_PROTECT: Objektschutzbits setzen
*  Arg2: Lock des ParentDir
*  Arg3: BSTR mit Objektname
*  Arg4: Maske
*

SetProtect	move.l	ThisPacket,a0
		DPRINTF	"SetProtect lock %08lx, name '%b', mask %08lx",dp_Arg2(a0),dp_Arg3(a0),dp_Arg4(a0)

; Objekt öffnen
		move.l	ThisPacket,a2
		move.l	dp_Arg2(a2),a0
		move.l	dp_Arg3(a2),a1
		moveq	#0,d0			;Nur existierende Objekte
		bsr	OpenByLockName

; Objekt vorhanden?
		move.l	a0,d1			;d0 enthält Fehlercode!
		beq	ReturnPacketErr
		move.l	a0,a2			;a2: Neues Objekt

; Ja, Maske testen
		move.l	ThisPacket,a0
		move.l	dp_Arg4(a0),d0
		btst	#FIBB_WRITE,d0
		bne	SetPrLockIt
		btst	#FIBB_DELETE,d0
		bne	SetPrLockIt

; Datei unlocken
SetPrUnlockIt	move.l	a2,a0
		bsr	RstFLock
		bra	SetPrDone

; Datei locken
SetPrLockIt	move.l	a2,a0
		bsr	SetFLock

; Objekt vernichten
SetPrDone	move.l	d0,-(sp)
		move.l	a2,a0
		bsr	CloseObject
		move.l	(sp)+,d0
		bne	ReturnPacketErr
		bra	ReturnPacketOK

*
* ACTION_SET_DATE: Objektdatum setzen
*  Arg2: Lock des ParentDir
*  Arg3: BSTR mit Objektname
*  Arg4: APTR auf DateStamp
*

SetDate		move.l	ThisPacket,a0
		DPRINTF	"SetDate lock %08lx, name '%b', date %08lx",dp_Arg2(a0),dp_Arg3(a0),dp_Arg4(a0)

; Objekt öffnen
		move.l	ThisPacket,a2
		move.l	dp_Arg2(a2),a0
		move.l	dp_Arg3(a2),a1
		moveq	#0,d0			;Nur existierende Objekte
		bsr	OpenByLockName

; Objekt vorhanden?
		move.l	a0,d1			;d0 enthält Fehlercode!
		beq	ReturnPacketErr
		move.l	a0,a2			;a2: Neues Objekt

; Ja, Datum holen, konvertieren und setzen
		move.l	ThisPacket,a0
		move.l	dp_Arg4(a0),a0
		bsr	DateStampToMac
		move.l	d0,FileInfo+ioFlMdDat

; CatInfo schreiben
		move.l	a2,a0
		bsr	SetCatInfo

; Objekt vernichten
SetDaDone	move.l	d0,-(sp)
		move.l	a2,a0
		bsr	CloseObject
		move.l	(sp)+,d0
		bne	ReturnPacketErr
		bra	ReturnPacketOK

*
* ACTION_SET_COMMENT: Typ/Creator von Dateien setzen
*  Arg2: Lock des ParentDir
*  Arg3: BSTR mit Objektname
*  Arg4: BSTR der Form "xxxx/yyyy"
*

SetComment	move.l	ThisPacket,a0
		DPRINTF	"SetComment lock %08lx, name '%b', comm '%b'",dp_Arg2(a0),dp_Arg3(a0),dp_Arg4(a0)

; Objekt öffnen
		move.l	ThisPacket,a2
		move.l	dp_Arg2(a2),a0
		move.l	dp_Arg3(a2),a1
		moveq	#0,d0			;Nur existierende Objekte
		bsr	OpenByLockName

; Objekt vorhanden?
		move.l	a0,d1			;d0 enthält Fehlercode!
		beq	ReturnPacketErr
		move.l	a0,a2			;a2: Neues Objekt

; Ja, ist es auch eine Datei?
		btst	#FAB_ISDIR,FileInfo+ioFlAttrib
		bne	SetCoWrong

; Ja, String konvertieren und Typ/Creator extrahieren
		move.l	ThisPacket,a0
		move.l	dp_Arg4(a0),a0
		add.l	a0,a0
		add.l	a0,a0
		cmp.b	#9,(a0)
		bne	SetCoIsDir
		lea	StringBuf,a1
		bsr	ConvertBSTR

		lea	StringBuf,a0
		moveq	#8,d0
2$		tst.b	(a0)+
		bne	1$
		move.b	#' ',-1(a0)
1$		dbra	d0,2$

		move.l	StringBuf,FileInfo+ioFlFndrInfo+fdType
		move.l	StringBuf+5,FileInfo+ioFlFndrInfo+fdCreator

; CatInfo schreiben
		move.l	a2,a0
		bsr	SetCatInfo
		move.l	d0,-(sp)
		bsr	FlushVol
		move.l	(sp)+,d0
		bra	SetPrDone

; Fehlerbehandlung
SetCoWrong	move.l	#ERROR_COMMENT_TOO_BIG,d0
		bra	SetCoDone
SetCoIsDir	move.l	#ERROR_OBJECT_WRONG_TYPE,d0
SetCoDone	move.l	d0,-(sp)
		move.l	a2,a0
		bsr	CloseObject
		move.l	(sp)+,d0
		bne	ReturnPacketErr
		bra	ReturnPacketOK

*
* ACTION_CREATE_DIR: Neues Verzeichnis anlegen
*  Arg1: Lock des ParentDir
*  Arg2: BSTR mit Verzeichnisname
*

CreateDir	move.l	ThisPacket,a0
		DPRINTF	"CreateDir lock %08lx, name '%b'",dp_Arg1(a0),dp_Arg2(a0)

; Objekt öffnen/erstellen
		move.l	ThisPacket,a2
		move.l	dp_Arg1(a2),a0
		move.l	dp_Arg2(a2),a1
		moveq	#-1,d0			;Neues Objekt erzeugen
		bsr	OpenByLockName

; Gelungen?
		move.l	a0,d1			;d0 enthält Fehlercode!
		beq	ReturnPacketErr

; Ja, wurde wirklich ein neues Objekt erzeugt?
		tst.l	d0
		beq	CreDirAlready

; Ja, Verzeichnis anlegen
		move.l	a0,a2			;a0: Neues Objekt
		bsr	DirCreate
		tst.l	d0
		bne	CreDirError

; DirID eintragen
		move.l	FileParam+ioDirID,mo_DirID(a2)

; Ok, Lock erzeugen und zurückgeben
		move.l	a2,a0
		move.l	#ACCESS_WRITE,d0
		bsr	LockObject

		move.l	ThisPacket,a0
		move.l	d0,dp_Res1(a0)
		beq	CreDirNoMem
		bra	ReturnPacket

; Fehlerbehandlung
CreDirNoMem	move.l	#ERROR_NO_FREE_STORE,d0
CreDirError	move.l	d0,-(sp)
		move.l	a2,a0
		bsr	CloseObject
		move.l	(sp)+,d0
		bra	ReturnPacketErr

CreDirAlready	move.l	#ERROR_OBJECT_EXISTS,d0
		bra	ReturnPacketErr

*
* ACTION_DELETE_OBJECT: Objekt löschen
*  Arg1: Lock des ParentDir
*  Arg2: BSTR mit Objektname
*

DeleteObject	move.l	ThisPacket,a0
		DPRINTF	"DeleteObject lock %08lx, name '%b'",dp_Arg1(a0),dp_Arg2(a0)

; Objekt öffnen
		move.l	ThisPacket,a2
		move.l	dp_Arg1(a2),a0
		move.l	dp_Arg2(a2),a1
		moveq	#0,d0			;Nur existierende Objekte
		bsr	OpenByLockName

; Objekt vorhanden?
		move.l	a0,d1			;d0 enthält Fehlercode!
		beq	ReturnPacketErr
		move.l	a0,a2			;a2: Neues Objekt

; Datei/Verzeichnis löschen
		move.l	a2,a0
		bsr	DeleteFile

; Objekt vernichten
		move.l	d0,-(sp)
		move.l	a2,a0
		bsr	CloseObject
		move.l	(sp)+,d0
		bne	ReturnPacketErr
		bra	ReturnPacketOK

*
* ACTION_RENAME_OBJECT: Objekt verschieben und/oder umbenennen
*  Arg1: Lock des Quell-ParentDir
*  Arg2: BSTR mit Objektname
*  Arg3: Lock des Ziel-Verzeichnis
*  Arg4: BSTR mit neuem Namen
*

RenameObject	move.l	ThisPacket,a0
		DPRINTF	"RenameObject lock %08lx, name '%b', lock %08lx, name '%b'",dp_Arg1(a0),dp_Arg2(a0),dp_Arg3(a0),dp_Arg4(a0)

; Existierendes Objekt öffnen
		move.l	ThisPacket,a2
		move.l	dp_Arg1(a2),a0
		move.l	dp_Arg2(a2),a1
		moveq	#0,d0			;Nur existierende Objekte
		bsr	OpenByLockName

; Objekt vorhanden?
		move.l	a0,d1			;d0 enthält Fehlercode!
		beq	ReturnPacketErr
		move.l	a0,a2			;a2: Existierendes Objekt

; Neues Objekt öffnen
		move.l	ThisPacket,a1
		move.l	dp_Arg3(a1),a0
		move.l	dp_Arg4(a1),a1
		moveq	#-1,d0			;Neues Objekt erzeugen
		bsr	OpenByLockName

; Gelungen?
		move.l	a0,d1
		bne	1$
		move.l	d0,-(sp)
		move.l	a2,a0
		bsr	CloseObject
		move.l	(sp)+,d0
		bra	ReturnPacketErr
1$		move.l	a0,a3			;a3: Neues Objekt

; Objekt verschieben/umbenennen
		move.l	a2,a0
		move.l	a3,a1
		bsr	RenameFile

; Objekte vernichten
		move.l	d0,-(sp)
		move.l	a3,a0
		bsr	CloseObject
		move.l	a2,a0
		bsr	CloseObject
		move.l	(sp)+,d0
		bne	ReturnPacketErr
		bra	ReturnPacketOK

*
* ACTION_FINDINPUT: Existierende Datei zum Lesen/Schreiben öffnen
*  Arg1: FileHandle
*  Arg2: Lock des ParentDir
*  Arg3: BSTR mit Dateiname
*

FindInput	move.l	ThisPacket,a0
		DPRINTF	"FindInput handle %08lx, lock %08lx, name '%b'",dp_Arg1(a0),dp_Arg2(a0),dp_Arg3(a0)

; Objekt öffnen
		move.l	ThisPacket,a2
		move.l	dp_Arg2(a2),a0
		move.l	dp_Arg3(a2),a1
		moveq	#0,d0			;Nur existierende Objekte
		bsr	OpenByLockName

; Objekt vorhanden?
		move.l	a0,d1			;d0 enthält Fehlercode!
		beq	ReturnPacketErr
		move.l	a0,a2			;a2: Neues Objekt

; Ja, ist es auch eine Datei (und kein Verzeichnis)?
		tst.l	mo_DirID(a2)
		bne	FIWrongType

; Ja, Länge holen
		tst.b	UseRsrcFork
		bne	1$
		move.l	FileInfo+ioFlLgLen,d2	;d2: Dateilänge
		bra	2$
1$		move.l	FileInfo+ioFlRLgLen,d2
2$

; Datei öffnen
		move.l	a2,a0
		bsr	OpenFileIn
		tst.l	d0
		bne	FIError

; Daten für geöffnete Dateien in Objekt eintragen
		move.w	FileParam+ioFRefNum,mo_FRefNum(a2)
		clr.l	mo_Pos(a2)
		move.l	d2,mo_Size(a2)

; FileHandle einrichten
		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a0
		add.l	a0,a0
		add.l	a0,a0
		move.l	a2,fh_Arg1(a0)
		addq.l	#1,NumberOfHandles
		bra	ReturnPacketOK

; Fehlerbehandlung
FIWrongType	move.l	#ERROR_OBJECT_WRONG_TYPE,d0
FIError		move.l	d0,-(sp)
		move.l	a2,a0
		bsr	CloseObject
		move.l	(sp)+,d0
		bra	ReturnPacketErr

*
* ACTION_FINDOUTPUT: Neue Datei erzeugen und zum Schreiben öffnen
*  Arg1: FileHandle
*  Arg2: Lock des ParentDir
*  Arg3: BSTR mit Dateiname
*

FindOutput	move.l	ThisPacket,a0
		DPRINTF	"FindOutput handle %08lx, lock %08lx, name '%b'",dp_Arg1(a0),dp_Arg2(a0),dp_Arg3(a0)

; Objekt öffnen
		move.l	ThisPacket,a2
		move.l	dp_Arg2(a2),a0
		move.l	dp_Arg3(a2),a1
		moveq	#-1,d0			;Neues Objekt erzeugen
		bsr	OpenByLockName

; Gelungen?
		move.l	a0,d1			;d0 enthält Fehlercode!
		beq	ReturnPacketErr
		move.l	a0,a2			;a2: Neues Objekt

; Ja, wurde neues Objekt erzeugt?
		tst.l	d0
		beq	FOAlready

; Ja, Datei anlegen und öffnen
		move.l	a2,a0
		bsr	CreateFile
		tst.l	d0
		bne	FOError
		bra	FOOpenIt

; Alte Datei wurde gefunden. Ist es auch eine Datei (und kein Verzeichnis)?
FOAlready	tst.l	mo_DirID(a2)
		bne	FOWrongType

; Datei öffnen
FOOpenIt	move.l	a2,a0
		bsr	OpenFileOut
		tst.l	d0
		bne	FOError

; Daten für geöffnete Dateien in Objekt eintragen
		move.w	FileParam+ioFRefNum,mo_FRefNum(a2)
		clr.l	mo_Pos(a2)
		clr.l	mo_Size(a2)		;Länge ist Null

; Fork löschen
		move.l	a2,a0
		bsr	TruncateFile

; FileHandle einrichten
		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a0
		add.l	a0,a0
		add.l	a0,a0
		move.l	a2,fh_Arg1(a0)
		addq.l	#1,NumberOfHandles
		bra	ReturnPacketOK

; Fehlerbehandlung
FOWrongType	move.l	#ERROR_OBJECT_WRONG_TYPE,d0
FOError		move.l	d0,-(sp)
		move.l	a2,a0
		bsr	CloseObject
		move.l	(sp)+,d0
		bra	ReturnPacketErr

*
* ACTION_FINDUPDATE: Datei erzeugen, falls sie noch nicht existiert und
*                    zum Lesen/Schreiben öffnen
*  Arg1: FileHandle
*  Arg2: Lock des ParentDir
*  Arg3: BSTR mit Dateiname
*

FindUpdate	move.l	ThisPacket,a0
		DPRINTF	"FindUpdate handle %08lx, lock %08lx, name '%b'",dp_Arg1(a0),dp_Arg2(a0),dp_Arg3(a0)

; Objekt öffnen
		move.l	ThisPacket,a2
		move.l	dp_Arg2(a2),a0
		move.l	dp_Arg3(a2),a1
		moveq	#-1,d0			;Neues Objekt erzeugen
		bsr	OpenByLockName

; Gelungen?
		move.l	a0,d1			;d0 enthält Fehlercode!
		beq	ReturnPacketErr
		move.l	a0,a2			;a2: Neues Objekt

; Ja, wurde neues Objekt erzeugt?
		tst.l	d0
		beq	FUAlready

; Ja, Datei anlegen
		move.l	a2,a0
		bsr	CreateFile
		tst.l	d0
		bne	FUError

; Länge ist Null
		moveq	#0,d2
		bra	FUOpenIt

; Alte Datei wurde gefunden. Ist es auch eine Datei (und kein Verzeichnis)?
FUAlready	tst.l	mo_DirID(a2)
		bne	FUWrongType

; Ja, Länge holen
		tst.b	UseRsrcFork
		bne	1$
		move.l	FileInfo+ioFlLgLen,d2	;d2: Dateilänge
		bra	2$
1$		move.l	FileInfo+ioFlRLgLen,d2
2$

; Datei öffnen
FUOpenIt	move.l	a2,a0
		bsr	OpenFileOut
		tst.l	d0
		bne	FUError

; Daten für geöffnete Dateien in Objekt eintragen
		move.w	FileParam+ioFRefNum,mo_FRefNum(a2)
		clr.l	mo_Pos(a2)
		move.l	d2,mo_Size(a2)

; FileHandle einrichten
		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a0
		add.l	a0,a0
		add.l	a0,a0
		move.l	a2,fh_Arg1(a0)
		addq.l	#1,NumberOfHandles
		bra	ReturnPacketOK

; Fehlerbehandlung
FUWrongType	move.l	#ERROR_OBJECT_WRONG_TYPE,d0
FUError		move.l	d0,-(sp)
		move.l	a2,a0
		bsr	CloseObject
		move.l	(sp)+,d0
		bra	ReturnPacketErr

*
* ACTION_END: FileHandle schließen
*  Arg1: FileHandle Arg1
*

EndFH		move.l	ThisPacket,a0
		DPRINTF	"End obj %08lx",dp_Arg1(a0)

		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a2		;a2: Objekt

		move.l	a2,a0
		bsr	CloseFile

		subq.l	#1,NumberOfHandles
		clr.w	mo_FRefNum(a2)

		move.l	a2,a0
		bsr	CloseObject
		bra	ReturnPacketOK

*
* ACTION_READ: Daten aus Datei lesen
*  Arg1: FileHandle Arg1
*  Arg2: Zeiger auf Puffer (kein BPTR!)
*  Arg3: Anzahl Bytes
*

Read		move.l	ThisPacket,a0
		DPRINTF	"Read obj %08lx, buf %08lx, bytes %08lx",dp_Arg1(a0),dp_Arg2(a0),dp_Arg3(a0)

		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a2		;a2: Objekt

; Daten lesen
		move.l	dp_Arg2(a0),d0
		move.l	dp_Arg3(a0),d1
		move.l	a2,a0
		bsr	ReadFromFile

		DPRINTF	" actual %08lx",d0

; mo_Pos aktualisieren
		move.l	ThisPacket,a0
		add.l	d0,mo_Pos(a2)
		move.l	d0,dp_Res1(a0)
		bra	ReturnPacket

*
* ACTION_WRITE: Daten in Datei schreiben
*  Arg1: FileHandle Arg1
*  Arg2: Zeiger auf Puffer (kein BPTR!)
*  Arg3: Anzahl Bytes
*

Write		move.l	ThisPacket,a0
		DPRINTF	"Write obj %08lx, buf %08lx, bytes %08lx",dp_Arg1(a0),dp_Arg2(a0),dp_Arg3(a0)

		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a2		;a2: Objekt

; Daten schreiben
		move.l	dp_Arg2(a0),d0
		move.l	dp_Arg3(a0),d1
		move.l	a2,a0
		bsr	WriteToFile

		DPRINTF	" actual %08lx",d0

; mo_Pos aktualisieren
		move.l	ThisPacket,a0
		add.l	d0,mo_Pos(a2)
		move.l	d0,dp_Res1(a0)

; Wenn über die bisherige Dateigrenze hinaus geschrieben wurde,
; muß die Dateilänge angepaßt werden
		move.l	mo_Pos(a2),d0
		cmp.l	mo_Size(a2),d0
		blo	1$
		move.l	d0,mo_Size(a2)
1$		bra	ReturnPacket

*
* ACTION_SEEK: Schreib-/Lese-Zeiger verschieben
*  Arg1: FileHandle Arg1
*  Arg2: Position
*  Arg3: Modus
*

Seek		move.l	ThisPacket,a0
		DPRINTF	"Seek obj %08lx, pos %08lx, mode %08lx",dp_Arg1(a0),dp_Arg2(a0),dp_Arg3(a0)

		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),a2		;a2: Objekt

; Alte Position zurückgeben
		move.l	mo_Pos(a2),dp_Res1(a0)

; Neue Position berechnen
		move.l	dp_Arg2(a0),d0
		move.l	dp_Arg3(a0),d1
		beq	SeekCur
		cmp.l	#OFFSET_BEGINNING,d1
		beq	SeekCheck
		cmp.l	#OFFSET_END,d1
		bne	SeekError

SeekEnd		add.l	mo_Size(a2),d0
		bra	SeekCheck

SeekCur		add.l	mo_Pos(a2),d0

; d0: Ungültige Position?
SeekCheck	tst.l	d0
		bmi	SeekError
		cmp.l	mo_Size(a2),d0
		bhi	SeekError

; Alles klar, neue Position eintragen
		move.l	d0,mo_Pos(a2)
		bra	ReturnPacket

SeekError	move.l	ThisPacket,a0
		move.l	#-1,dp_Res1(a0)
		move.l	#ERROR_SEEK_ERROR,dp_Res2(a0)
		bra	ReturnPacket

*
* ACTION_USER: Data/Resource-Fork auswählen
*  Arg1: 0: Data, 1: Resource
*

User		move.l	ThisPacket,a0
		move.l	dp_Arg1(a0),d0
		beq	UserToData
		cmp.l	#1,d0
		beq	UserToRsrc
		move.l	#999,d0
		bra	ReturnPacketErr

UserToData	clr.b	UseRsrcFork
		bra	ReturnPacketOK

UserToRsrc	st.b	UseRsrcFork
		bra	ReturnPacketOK


**
** Unterroutinen
**

*
* Auf DOS-Packet warten
* Rückgabe: a0: Zeiger auf Packet
*

WaitPacket	move.l	MyProc,a0
		JSRLIB	WaitPort

		move.l	MyProc,a0
		JSRLIB	GetMsg

		move.l	d0,a0
		move.l	LN_NAME(a0),a0
		move.l	a0,ThisPacket
		rts

*
* DOS-Packet ohne Fehler zurückgeben
*

ReturnPacketOK	move.l	ThisPacket,a0
		move.l	#DOSTRUE,dp_Res1(a0)
		bra	ReturnPacket

*
* DOS-Packet mit Fehler zurückgeben
* d0: Fehlercode
*

ReturnPacketErr	move.l	ThisPacket,a0
		move.l	#DOSFALSE,dp_Res1(a0)
		move.l	d0,dp_Res2(a0)

ReturnPacket	movem.l	a2-a3,-(sp)

		move.l	ThisPacket,a2		;a2: Packet
		move.l	dp_Link(a2),a1		;a1: Exec Message
		move.l	dp_Port(a2),a3		;a3: Reply Port

		move.l	a2,LN_NAME(a1)
		clr.l	LN_SUCC(a1)
		clr.l	LN_PRED(a1)
		move.l	MyProc,dp_Port(a2)

		move.l	a3,a0			;Reply Port
		JSRLIB	PutMsg
		movem.l	(sp)+,a2-a3
		rts

*
* BSTR in C-String konvertieren
* a0: APTR (!) auf BSTR
* a1: Zeiger auf Ziel-Puffer
*

ConvertBSTR	moveq	#0,d0
		move.b	(a0)+,d0
		beq	2$
		subq.w	#1,d0
1$		move.b	(a0)+,(a1)+
		dbra	d0,1$
2$		clr.b	(a1)+
		rts

*
* Kopiert einen BSTR
* a0: Zeiger auf Quell-BSTR
* a1: Zeiger auf Ziel-BSTR
* Rückgabe: a1: Zeiger direkt hinter den Ziel-BSTR
*

CopyBSTR	moveq	#0,d0
		move.b	(a0),d0
1$		move.b	(a0)+,(a1)+
		dbra	d0,1$
		rts

*
* In einem Pfadnamen nach ':' suchen und die Position des ersten
*  Zeichens nach dem ':' zurückgeben. Null, wenn kein ':' gefunden.
* a0: Zeiger auf Name (C-String)
* Rückgabe: d0: Zeichenposition
*

SearchPrefix	moveq	#-1,d0
2$		addq.l	#1,d0
		move.b	(a0)+,d1
		beq	1$
		cmp.b	#':',d1
		bne	2$
		addq.l	#1,d0
		rts

1$		moveq	#0,d0
		rts

*
* sprintf
* a0: Zeiger auf Format-String
* a1: Zeiger auf Daten
* a2: Zeiger auf Ziel-String
*

SPrintF		move.l	a3,-(sp)
		move.l	a2,a3
		lea	StuffChar,a2
		JSRLIB	RawDoFmt
		move.l	(sp)+,a3
		rts

StuffChar	move.b	d0,(a3)+
		rts

*
* Macintosh-Datum/Zeit in DateStamp konvertieren
* d0: Macintosh-Sekunden
* a0: Zeiger auf DateStamp
*

MacToDateStamp	sub.l	#$8b31ef80,d0
		divul.l	#24*60*60,d1:d0
		move.l	d0,ds_Days(a0)
		divul.l	#60,d0:d1
		move.l	d1,ds_Minute(a0)
		mulu	#TICKS_PER_SECOND,d0
		move.l	d0,ds_Tick(a0)
		rts

*
* DateStamp in Macintosh-Datum/Zeit konvertieren
* a0: Zeiger auf DateStamp
* Rückgabe: d0: Macintosh-Sekunden
*

DateStampToMac	move.l	ds_Days(a0),d0
		mulu.l	#24*60*60,d0
		move.l	ds_Minute(a0),d1
		mulu.l	#60,d1
		add.l	d1,d0
		move.l	ds_Tick(a0),d1
		divu.l	#TICKS_PER_SECOND,d1
		add.l	d1,d0
		add.l	#$8b31ef80,d0
		rts

*
* Objekt zu einem Lock holen
* a0: BPTR auf Lock
* Rückgabe: a0: Zeiger auf MacObject
*

ObjFromLock	move.l	a0,d0
		beq	1$

		add.l	d0,d0
		add.l	d0,d0
		move.l	d0,a0
		move.l	fl_Key(a0),a0
		rts

1$		lea	RootObject,a0
		rts

*
* Lock zu einem Objekt erzeugen. fl_Key enthält einen Zeiger
*  auf das Objekt
* a0: Zeiger auf MacObject
* d0: LockMode
* Rückgabe: d0: BPTR auf Lock, Null bei Fehler (kein Speicher)
*

LockObject	movem.l	d2/a2,-(sp)
		move.l	a0,a2			;a2: MacObject
		move.l	d0,d2			;d2: LockMode

; Speicher für Lock holen
		move.l	#fl_SIZEOF,d0
		move.l	#MEMF_PUBLIC,d1
		JSRLIB	AllocVec	;MUSS ALLOCVEC SEIN!
		tst.l	d0
		beq	1$

; Daten eintragen
		move.l	d0,a0
		clr.l	fl_Link(a0)
		move.l	a2,fl_Key(a0)
		move.l	d2,fl_Access(a0)
		move.l	MyProc,fl_Task(a0)
		move.l	VolumeNode,d0
		asr.l	#2,d0
		move.l	d0,fl_Volume(a0)

		addq.l	#1,NumberOfLocks

		move.l	a0,d0
		asr.l	#2,d0
1$		movem.l	(sp)+,d2/a2
		rts

*
* Lock und zugehöriges Objekt vernichten
* a0: Zeiger auf Lock (kein BPTR!)
*

UnLockObject	move.l	a2,-(sp)
		move.l	a0,a2
		subq.l	#1,NumberOfLocks
		move.l	fl_Key(a2),a0
		bsr	CloseObject
		move.l	a2,a1
		JSRLIB	FreeVec
		move.l	(sp)+,a2
		rts

*
* Objekt klonen
* a0: Zeiger auf MacObject
* Rückgabe: a0: Zeiger auf geklontes Objekt, Null bei Fehler
*           d0: Fehlercode (ERROR_*), nur gültig, wenn a0=Null
*

CloneObject	move.l	a2,-(sp)
		move.l	a0,a2			;a2: Original-Objekt

; Speicher holen
		move.l	#mo_SIZEOF,d0
		move.l	#MEMF_PUBLIC,d1
		JSRLIB	AllocVec
		tst.l	d0
		beq	1$

; Objekt kopieren
		move.l	a2,a0
		move.l	d0,a1
		moveq	#mo_SIZEOF-1,d1
2$		move.b	(a0)+,(a1)+
		dbra	d1,2$

		move.l	d0,a0
		move.l	(sp)+,a2
		rts

1$		sub.l	a0,a0
		move.l	#ERROR_NO_FREE_STORE,d0
		move.l	(sp)+,a2
		rts

*
* Ein neues MacObject erzeugen, daß das übergeordnete Verzeichnis
*  eines bestehenden MacObject beschreibt
* a0: Zeiger auf MacObject
* Rückgabe: a0: Zeiger auf Parent-Objekt, Null bei Fehler
*           d0: Fehlercode (ERROR_*), nur gültig, wenn a0=Null
*

OpenParent	movem.l	a2-a3,-(sp)
		move.l	a0,a2			;a2: Original-Objekt

; Speicher holen
		move.l	#mo_SIZEOF,d0
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		JSRLIB	AllocVec
		tst.l	d0
		beq	OPNoMem

; Einige Daten kopieren
		move.l	d0,a3			;a3: Neues Parent-Objekt
		move.w	mo_VRefNum(a2),mo_VRefNum(a3)
		move.l	mo_ParDirID(a2),mo_DirID(a3)

; GetCatInfo aufrufen, um die Parent-DirID und den Namen zu erhalten
		move.l	a3,a0
		bsr	GetCatInfo
		tst.l	d0
		bne	OPError

; (Name wird von GetCatInfo gesetzt)
		move.l	FileInfo+ioDrParID,mo_ParDirID(a3)

		move.l	a3,a0
		movem.l	(sp)+,a2-a3
		rts

OPNoMem		sub.l	a0,a0
		move.l	#ERROR_NO_FREE_STORE,d0
		movem.l	(sp)+,a2-a3
		rts

; Fehlerbehandlung (Fehlercode in d0)
OPError		move.l	d0,-(sp)
		move.l	a3,a1
		JSRLIB	FreeVec
		sub.l	a0,a0
		move.l	(sp)+,d0
		movem.l	(sp)+,a2-a3
		rts

*
* Ein neues MacObject erzeugen
* a0: Zeiger auf MacObject des ParentDir
* a1: Zeiger auf Pfadname des Objekts (C-String)
* d0: #0: Wenn das Objekt nicht existiert soll kein Fehler gemeldet
*     sondern trotzdem ein MacObject erstellt werden
* Rückgabe: a0: Zeiger auf MacObject, Null bei Fehler
*           d0: Amiga-Fehlercode (ERROR_*), nur gültig, wenn a0=Null
*               Sonst: 0: Objekt vorhanden, #0: Objekt erstellt
*           FileInfo: CatInfo des Objekts (außer bei neuen Objekten)
*

OpenObject	movem.l	d2-d3/a2-a4,-(sp)
		move.l	a0,a2			;a2: Parent-Objekt
		move.l	a1,a4			;a4: Zeiger auf Name
		move.l	d0,d3			;d3: Create New?

; Wenn Pfadname mit ':' beginnt, RootObject klonen
		cmp.b	#':',(a4)
		bne	OONotAbs

		lea	RootObject,a0
		bsr	CloneObject
		move.l	a0,d1			;d0: Fehlercode!
		beq	OORts
		move.l	a0,a3			;a3: Neues Objekt
		addq.l	#1,a4
		bra	OOPrefixesDone

; Sonst erstmal Objekt des ParentDir klonen
OONotAbs	move.l	a2,a0
		bsr	CloneObject
		move.l	a0,d1			;d0: Fehlercode!
		beq	OORts
		move.l	a0,a3

; Solange der Pfadname mit '/' beginnt, Parent holen, altes Objekt freigeben
OOPreSlashLoop	cmp.b	#'/',(a4)
		bne	OOPrefixesDone

		move.l	a3,a0
		bsr	OpenParent
		move.l	a0,d1			;d0: Fehlercode
		beq	OORts

		exg.l	a0,a3
		bsr	CloseObject

		addq.l	#1,a4
		bra	OOPreSlashLoop

; So, a3 zeigt nun auf ein Objekt, das das übergeordnete Verzeichnis
; des Restpfades ab a4 darstellt
OOPrefixesDone

; Jetzt wird immer eine Pfadkomponente extrahiert, solange noch
; Komponenten übrig sind
OOLoop		tst.b	(a4)
		beq	OODone

; Nächste Pfadkomponente nach StringBuf2 extrahieren
		lea	StringBuf2+1,a1
OOExtrLoop	move.b	(a4),d0
		beq	OOExtrDone
		addq.l	#1,a4
		cmp.b	#'/',d0
		beq	OOExtrDone
		move.b	d0,(a1)+
		bra	OOExtrLoop

OOExtrDone	move.l	a1,d0
		sub.l	#StringBuf2+1,d0
		move.b	d0,StringBuf2

; GetCatInfo aufrufen, um die Existenz zu testen und die DirID zu erhalten
		move.l	mo_DirID(a3),d2		;d2: Parent DirID
		move.l	a3,a0
		bsr	GetCatInfoName
		cmp.l	#ERROR_OBJECT_NOT_FOUND,d0
		beq	OOMaybeNew
		tst.l	d0
		bne	OOError

; Wenn die Pfadkomponente kein Verzeichnis darstellt, aber noch
; weitere Komponenten folgen, abbrechen
		btst	#FAB_ISDIR,FileInfo+ioFlAttrib
		bne	OOIsDir
		tst.b	(a4)
		bne	OONotFound

; Daten in Objekt kopieren
OOIsDir		move.l	d2,mo_ParDirID(a3)
		clr.l	mo_DirID(a3)		;Bei Files steht hier die FileID,
						; und die wollen wir nicht
		btst	#FAB_ISDIR,FileInfo+ioFlAttrib
		beq	1$
		move.l	FileInfo+ioDirID,mo_DirID(a3)
1$

; Wiederholen
		bra	OOLoop

; Fertig, Name in Objekt kopieren
OODone		lea	StringBuf2,a0
		lea	mo_Name(a3),a1
		bsr	CopyBSTR

		move.l	a3,a0
		moveq	#0,d0			;Objekt gefunden
		movem.l	(sp)+,d2-d3/a2-a4
		rts

; Ein Objekt im Pfad wurde nicht gefunden. Wenn dies die letzte
; Komponente war und d3 gesetzt ist, erstellen wir trotzdem ein Objekt
OOMaybeNew	tst.l	d3
		beq	OOError
		tst.b	(a4)
		bne	OOError

		move.l	d2,mo_ParDirID(a3)	;OK, Daten kopieren
		clr.l	mo_DirID(a3)

		lea	StringBuf2,a0
		lea	mo_Name(a3),a1
		bsr	CopyBSTR

		move.l	a3,a0
		moveq	#-1,d0			;Objekt neu erstellt
		movem.l	(sp)+,d2-d3/a2-a4
		rts

; Fehlerbehandlung
OONoMem		move.l	#ERROR_NO_FREE_STORE,d0
OORts		sub.l	a0,a0
		movem.l	(sp)+,d2-d3/a2-a4
		rts

OONotFound	move.l	#ERROR_OBJECT_NOT_FOUND,d0
OOError		move.l	d0,-(sp)
		move.l	a3,a1
		JSRLIB	FreeVec
		sub.l	a0,a0
		move.l	(sp)+,d0
		movem.l	(sp)+,d2-d3/a2-a4
		rts

*
* Objekt über Lock des ParentDir und Namen öffnen
* a0: BPTR auf Lock des ParentDir
* a1: BSTR mit Name
* d0: #0: Wenn das Objekt nicht existiert soll kein Fehler gemeldet
*     sondern trotzdem ein MacObject erstellt werden
* Rückgabe: a0: Zeiger auf MacObject, Null bei Fehler
*           d0: Amiga-Fehlercode (ERROR_*), nur gültig, wenn a0=Null
*               Sonst: 0: Objekt vorhanden, #0: Objekt erstellt
*           FileInfo: CatInfo des Objekts (außer bei neuen Objekten)
*

; Objekt des ParentDir holen
OpenByLockName	movem.l	d2/a2-a3,-(sp)
		move.l	a1,a3			;a3: Name
		move.l	d0,d2			;d2: Create New?
		bsr	ObjFromLock
		move.l	a0,a2			;a2: Parent Object

; Objekt-Name in normalen String konvertieren
		move.l	a3,a0
		add.l	a0,a0
		add.l	a0,a0
		lea	StringBuf,a1
		bsr	ConvertBSTR

; ':' überspringen
		lea	StringBuf,a0
		bsr	SearchPrefix

; Objekt öffnen
		move.l	a2,a0
		lea	StringBuf,a1
		add.l	d0,a1			;d0: Zeichen nach ':'
		move.l	d2,d0			;Create New?
		bsr	OpenObject
		movem.l	(sp)+,d2/a2-a3
		rts

*
* Objekte vergleichen
* a0: MacObject 1
* a1: MacObject 2
* Rückgabe: d0: DOSTRUE, wenn gleich, sonst DOSFALSE
*

SameObjects	move.w	mo_VRefNum(a0),d0
		cmp.w	mo_VRefNum(a1),d0
		bne	SONotSame

		move.l	mo_ParDirID(a0),d0
		cmp.l	mo_ParDirID(a1),d0
		bne	SONotSame

		move.l	mo_DirID(a0),d0
		cmp.l	mo_DirID(a1),d0
		bne	SONotSame

		lea	mo_Name(a0),a0
		lea	mo_Name(a1),a1
		move.b	(a0),d0
1$		cmp.b	(a0)+,(a1)+
		bne	SONotSame
		dbra	d0,1$

		move.l	#DOSTRUE,d0
		rts

SONotSame	move.l	#DOSFALSE,d0
		rts

*
* Objekt vernichten
* a0: Zeiger auf MacObject
*

CloseObject	cmp.l	RootObject,a0
		beq	1$
		move.l	a0,a1
		JSRLIB	FreeVec
1$		rts

*
* Disk-Inserted/Removed-Event abschicken
* d0: #0: Inserted, 0: Removed
*

SendEvent	link	a5,#-16
		move.l	d0,-4(a5)		;-4: Flag

		JSRLIB	CreateMsgPort
		move.l	d0,-8(a5)		;-8: Port
		beq	1$

		move.l	d0,a0
		move.l	#IOSTD_SIZE,d0
		JSRLIB	CreateIORequest
		move.l	d0,-12(a5)		;-12: IOReq
		beq	2$

		lea	InputName,a0
		moveq	#0,d0
		move.l	-12(a5),a1
		moveq	#0,d1
		JSRLIB	OpenDevice
		tst.l	d0
		bne	3$

		move.l	#ie_SIZEOF,d0
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		JSRLIB	AllocVec
		move.l	d0,-16(a5)		;-16: InputEvent
		beq	4$

		move.l	-16(a5),a1
		tst.l	-4(a5)
		beq	10$
		move.b	#IECLASS_DISKINSERTED,d0
		bra	20$
10$		move.b	#IECLASS_DISKREMOVED,d0
20$		move.b	d0,ie_Class(a1)

		move.l	-12(a5),a1
		move.w	#IND_WRITEEVENT,IO_COMMAND(a1)
		move.l	-16(a5),IO_DATA(a1)
		move.l	#ie_SIZEOF,IO_LENGTH(a1)
		JSRLIB	DoIO

		move.l	-16(a5),a1
		JSRLIB	FreeVec

4$		move.l	-12(a5),a1
		JSRLIB	CloseDevice

3$		move.l	-12(a5),a0
		JSRLIB	DeleteIORequest

2$		move.l	-8(a5),a0
		JSRLIB	DeleteMsgPort

1$		unlk	a5
		rts

*
* Mac-Routine aufrufen und auf deren Beendigung warten
* a0: Zeiger auf Routine
* a1: Parameter für Routine
* Rückgabe: d0: Mac-Fehlercode (0=OK)
*

; Parameter sichern
CallMac		link	a5,#-12
		move.l	a0,-8(a5)		;-8: Routine
		move.l	a1,-12(a5)		;-12: Parameter

; Semaphor suchen und prüfen, ob Mac läuft
		JSRLIB	Forbid
		lea	SemaName,a1
		JSRLIB	FindSemaphore
		move.l	d0,-4(a5)		;-4: Semaphore
		beq	1$
		move.l	d0,a0
		tst.w	ss_MacRunning(a0)
		beq	1$
		JSRLIB	ObtainSemaphore
		JSRLIB	Permit

; MacProc ausfüllen und zur Ausführung übergeben
		lea	MacProc,a0
		move.l	-8(a5),mp_Proc(a0)
		move.l	-12(a5),mp_Param(a0)
		move.l	-4(a5),a1
		move.l	ss_ExecMacProc(a1),a1
		jsr	(a1)

; Auf Beendigung warten
		move.l	MacSignalSet,d0
		JSRLIB	Wait

; Semaphor freigeben
		move.l	-4(a5),a0
		JSRLIB	ReleaseSemaphore

		move.w	MacResult,d0
		unlk	a5
		rts

1$		JSRLIB	Permit
		moveq	#-1,d0
		unlk	a5
		rts

*
* Mac-Fehlercode in Amiga-Fehlercode umwandeln
* d0: Mac-Fehlercode
* Rückgabe: d0: Amiga-Fehlercode
*

ConvError	tst.w	d0
		beq	111$
		cmp.w	#-39,d0			;eof
		beq	111$
		cmp.w	#-1,d0			;ShapeShifter läuft nicht
		beq	1$
		cmp.w	#-53,d0			;volumeOffLine
		beq	1$
		cmp.w	#-124,d0		;volumeGone
		beq	1$
		cmp.w	#-33,d0			;dirFull
		beq	2$
		cmp.w	#-34,d0			;diskFull
		beq	2$
		cmp.w	#-35,d0			;noSuchVolume
		beq	3$
		cmp.w	#-36,d0			;ioError
		beq	4$
		cmp.w	#-123,d0		;wrongVolumeType
		beq	4$
		cmp.w	#-37,d0			;badName
		beq	5$
		cmp.w	#-40,d0			;posError
		beq	6$
		cmp.w	#-41,d0			;memFull
		beq	7$
		cmp.w	#-108,d0		;memFull
		beq	7$
		cmp.w	#-43,d0			;fileNotFound
		beq	8$
		cmp.w	#-44,d0			;writeProtected
		beq	9$
		cmp.w	#-46,d0			;volumeLocked
		beq	9$
		cmp.w	#-45,d0			;fileLocked
		beq	10$
		cmp.w	#-54,d0			;permError
		beq	10$
		cmp.w	#-61,d0			;writePerm
		beq	10$
		cmp.w	#-47,d0			;fileBusy
		beq	11$
		cmp.w	#-49,d0			;openWrite
		beq	11$
		cmp.w	#-48,d0			;dupFileName
		beq	12$
		cmp.w	#-59,d0			;fsds
		beq	13$
		cmp.w	#-121,d0		;tmwdo
		beq	13$
		cmp.w	#-120,d0		;dirNotFound
		beq	14$
		move.l	#333,d0			;Unbekannter Fehler
		rts

111$		moveq	#0,d0
		rts
1$		move.l	#ERROR_DEVICE_NOT_MOUNTED,d0
		rts
2$		move.l	#ERROR_DISK_FULL,d0
		rts
3$		move.l	#ERROR_NO_DISK,d0
		rts
4$		move.l	#ERROR_NOT_A_DOS_DISK,d0
		rts
5$		move.l	#ERROR_INVALID_COMPONENT_NAME,d0
		rts
6$		move.l	#ERROR_SEEK_ERROR,d0
		rts
7$		move.l	#ERROR_NO_FREE_STORE,d0
		rts
8$		move.l	#ERROR_OBJECT_NOT_FOUND,d0
		rts
9$		move.l	#ERROR_DISK_WRITE_PROTECTED,d0
		rts
10$		move.l	#ERROR_WRITE_PROTECTED,d0
		rts
11$		move.l	#ERROR_OBJECT_IN_USE,d0
		rts
12$		move.l	#ERROR_OBJECT_EXISTS,d0
		rts
13$		move.l	#ERROR_RENAME_ACROSS_DEVICES,d0
		rts
14$		move.l	#ERROR_DIR_NOT_FOUND,d0
		rts

*
* VolumeInfo holen
* Rückgabe: d0: Amiga-Fehlercode
*           VolumeInfo: VolumeInfo des Volumes
*           VolumeName: Name des Volumes
*

GetVolInfo	lea	MGetVolInfo,a0
		lea	VolumeName,a1
		bsr	CallMac
		bra	ConvError

MGetVolInfo	lea	VolumeInfo,a0
		clr.w	ioVRefNum(a0)
		move.w	VolumeIndex+2,ioVolIndex(a0)
		move.l	a1,ioNamePtr(a0)
		dc.w	$a207			;PBHGetVInfo
		RETMAC

*
* Volume flushen
* Rückgabe: d0: Amiga-Fehlercode
*

FlushVol	lea	MFlushVol,a0
		bsr	CallMac
		bra	ConvError

MFlushVol	lea	VolumeParam,a0
		move.w	VRefNum,ioVRefNum(a0)
		clr.l	ioNamePtr(a0)
		dc.w	$a013			;PBFlushVol
		RETMAC

*
* Volume umbenennen
* a0: APTR auf Namen (BSTR)
* Rückgabe: d0: Amiga-Fehlercode
*

RenameVol	move.l	a0,a1
		lea	MRenameVol,a0
		bsr	CallMac
		bra	ConvError

MRenameVol	lea	VolumeParam,a0
		move.w	VRefNum,ioVRefNum(a0)
		clr.l	ioNamePtr(a0)
		move.l	a1,ioMisc(a0)
		move.l	#fstRtDirID,ioDirID(a0)
		dc.w	$a20b			;PBHRename
		RETMAC

*
* CatInfo zu einem Objekt holen
* a0: Zeiger auf MacObject
* Rückgabe: d0: Amiga-Fehlercode
*           FileInfo: CatInfo des Objekts
*

GetCatInfo	move.l	a0,a1
		lea	MGetCatInfo,a0
		bsr	CallMac
		bra	ConvError

MGetCatInfo	lea	FileInfo,a0
		move.w	mo_VRefNum(a1),ioVRefNum(a0)
		move.l	mo_DirID(a1),ioDirID(a0)
		beq	1$

		move.w	#-1,ioFDirIndex(a0)	;Directory
		bra	2$

1$		clr.w	ioFDirIndex(a0)		;Datei
		move.l	mo_ParDirID(a1),ioDirID(a0)

2$		lea	mo_Name(a1),a1
		move.l	a1,ioNamePtr(a0)

		moveq	#9,d0			;PBGetCatInfo
		dc.w	$a260			;HFSDispatch
		RETMAC

*
* CatInfo zu einem Objekt eines Verzeichnisses per Index holen.
*  Name kommt nach StringBuf
* a0: Zeiger auf MacObject des Verzeichnisses, in dem FDirIndex gesetzt ist
* Rückgabe: d0: Amiga-Fehlercode
*           FileInfo: CatInfo des Objekts
*

GetCatInfoIX	move.l	a0,a1
		lea	MGetCatInfoIX,a0
		bsr	CallMac
		bra	ConvError

MGetCatInfoIX	lea	FileInfo,a0
		move.w	mo_FDirIndex(a1),ioFDirIndex(a0)
		move.w	mo_VRefNum(a1),ioVRefNum(a0)
		move.l	mo_DirID(a1),ioDirID(a0)
		move.l	#StringBuf,ioNamePtr(a0)

		moveq	#9,d0			;PBGetCatInfo
		dc.w	$a260			;HFSDispatch
		RETMAC

*
* CatInfo per VRefNum/DirID (MacObject) und Name (StringBuf2) holen
* a0: Zeiger auf MacObject
* Rückgabe: d0: Amiga-Fehlercode
*           FileInfo: CatInfo des Objekts
*

GetCatInfoName	move.l	a0,a1
		lea	MGetCatInfoName,a0
		bsr	CallMac
		bra	ConvError

MGetCatInfoName	lea	FileInfo,a0
		clr.w	ioFDirIndex(a0)
		move.w	mo_VRefNum(a1),ioVRefNum(a0)
		move.l	mo_DirID(a1),ioDirID(a0)
		move.l	#StringBuf2,ioNamePtr(a0)

		moveq	#9,d0			;PBGetCatInfo
		dc.w	$a260			;HFSDispatch
		RETMAC

*
* CatInfo eines Objekts setzen
* a0: Zeiger auf MacObject
* FileInfo: CatInfo des Objekts
* Rückgabe: d0: Amiga-Fehlercode
*

SetCatInfo	move.l	a0,a1
		lea	MSetCatInfo,a0
		bsr	CallMac
		bra	ConvError

MSetCatInfo	lea	FileInfo,a0
		move.w	mo_VRefNum(a1),ioVRefNum(a0)
		move.l	mo_ParDirID(a1),ioDirID(a0)

		lea	mo_Name(a1),a1
		move.l	a1,ioNamePtr(a0)

		moveq	#10,d0			;PBSetCatInfo
		dc.w	$a260			;HFSDispatch
		RETMAC

*
* Neues Verzeichnis erzeugen
* a0: Zeiger auf MacObject mir ParDirID/Namen
* Rückgabe: d0: Amiga-Fehlercode
*           FileParam.ioDirID: DirID des Verzeichnisses
*

DirCreate	move.l	a0,a1
		lea	MDirCreate,a0
		bsr	CallMac
		bra	ConvError

MDirCreate	lea	FileParam,a0
		move.w	mo_VRefNum(a1),ioVRefNum(a0)
		move.l	mo_ParDirID(a1),ioDirID(a0)

		lea	mo_Name(a1),a1
		move.l	a1,ioNamePtr(a0)

		moveq	#6,d0			;PBDirCreate
		dc.w	$a260			;HFSDispatch
		RETMAC

*
* Datei locken
* a0: Zeiger auf MacObject
* Rückgabe: d0: Amiga-Fehlercode
*

SetFLock	move.l	a0,a1
		lea	MSetFLock,a0
		bsr	CallMac
		bra	ConvError

MSetFLock	lea	FileParam,a0
		move.w	mo_VRefNum(a1),ioVRefNum(a0)
		move.l	mo_ParDirID(a1),ioDirID(a0)

		lea	mo_Name(a1),a1
		move.l	a1,ioNamePtr(a0)

		dc.w	$a241			;PBHSetFLock
		RETMAC

*
* Datei unlocken
* a0: Zeiger auf MacObject
* Rückgabe: d0: Amiga-Fehlercode
*

RstFLock	move.l	a0,a1
		lea	MRstFLock,a0
		bsr	CallMac
		bra	ConvError

MRstFLock	lea	FileParam,a0
		move.w	mo_VRefNum(a1),ioVRefNum(a0)
		move.l	mo_ParDirID(a1),ioDirID(a0)

		lea	mo_Name(a1),a1
		move.l	a1,ioNamePtr(a0)

		dc.w	$a242			;PBHRstFLock
		RETMAC

*
* Datei zum Lesen/Schreiben öffnen, wenn möglich, sonst nur zum Lesen
* a0: Zeiger auf MacObject
* Rückgabe: d0: Amiga-Fehlercode
*           FileParam.ioFRefNum: RefNum der Datei
*

OpenFileIn	move.l	a0,a1
		lea	MOpenFileIn,a0
		bsr	CallMac
		bra	ConvError

MOpenFileIn	lea	FileParam,a0
		move.w	mo_VRefNum(a1),ioVRefNum(a0)
		move.l	mo_ParDirID(a1),ioDirID(a0)
		clr.l	ioMisc(a0)
		move.b	#fsCurPerm,ioPermssn(a0)

		lea	mo_Name(a1),a1
		move.l	a1,ioNamePtr(a0)

		tst.b	UseRsrcFork
		bne	1$
		moveq	#$1a,d0			;PBHOpenDF
		dc.w	$a260			;HFSDispatch
		bra	2$
1$		dc.w	$a20a			;PBHOpenRF
2$
		cmp.w	#-49,d0			;Already open for writing?
		bne	4$

		lea	FileParam,a0
		move.b	#fsRdPerm,ioPermssn(a0)
		tst.b	UseRsrcFork
		bne	3$
		moveq	#$1a,d0			;PBHOpenDF
		dc.w	$a260			;HFSDispatch
		bra	4$
3$		dc.w	$a20a			;PBHOpenRF
4$		RETMAC

*
* Datei zum Lesen/Schreiben öffnen
* a0: Zeiger auf MacObject
* Rückgabe: d0: Amiga-Fehlercode
*           FileParam.ioFRefNum: RefNum der Datei
*

OpenFileOut	move.l	a0,a1
		lea	MOpenFileOut,a0
		bsr	CallMac
		bra	ConvError

MOpenFileOut	lea	FileParam,a0
		move.w	mo_VRefNum(a1),ioVRefNum(a0)
		move.l	mo_ParDirID(a1),ioDirID(a0)
		clr.l	ioMisc(a0)
		move.b	#fsRdWrPerm,ioPermssn(a0)

		lea	mo_Name(a1),a1
		move.l	a1,ioNamePtr(a0)

		tst.b	UseRsrcFork
		bne	1$
		moveq	#$1a,d0			;PBHOpenDF
		dc.w	$a260			;HFSDispatch
		bra	2$
1$		dc.w	$a20a			;PBHOpenRF
2$		RETMAC

*
* Datei schließen
* a0: Zeiger auf MacObject
* Rückgabe: d0: Amiga-Fehlercode
*

CloseFile	move.l	a0,a1
		lea	MCloseFile,a0
		bsr	CallMac
		bra	ConvError

MCloseFile	lea	FileParam,a0
		move.w	mo_FRefNum(a1),ioFRefNum(a0)

		dc.w	$a001			;PBClose
		RETMAC

*
* Neue Datei erzeugen
* a0: Zeiger auf MacObject
* Rückgabe: d0: Amiga-Fehlercode
*

CreateFile	move.l	a0,a1
		lea	MCreateFile,a0
		bsr	CallMac
		bra	ConvError

MCreateFile	move.l	a1,a2
		lea	FileParam,a0
		move.w	mo_VRefNum(a1),ioVRefNum(a0)
		move.l	mo_ParDirID(a1),ioDirID(a0)
		clr.b	ioFlVersNum(a0)

		lea	mo_Name(a1),a1
		move.l	a1,ioNamePtr(a0)

		dc.w	$a208			;PBHCreate
		tst.w	d0
		bne	1$

		move.l	a2,a1
		lea	FileParam,a0
		move.w	mo_VRefNum(a1),ioVRefNum(a0)
		move.l	mo_ParDirID(a1),ioDirID(a0)
		clr.w	ioFDirIndex(a0)
		clr.b	ioFVersNum(a0)

		lea	mo_Name(a1),a1
		move.l	a1,ioNamePtr(a0)

		dc.w	$a20c			;PBHGetFInfo
		tst.w	d0
		bne	1$

		move.l	a2,a1
		lea	FileParam,a0
		move.w	mo_VRefNum(a1),ioVRefNum(a0)
		move.l	mo_ParDirID(a1),ioDirID(a0)
		move.l	FileType,ioFlFndrInfo+fdType(a0)
		move.l	FileCreator,ioFlFndrInfo+fdCreator(a0)

		lea	mo_Name(a1),a1
		move.l	a1,ioNamePtr(a0)

		dc.w	$a20d			;PBHSetFInfo
		tst.w	d0
		bne	1$

		lea	VolumeParam,a0
		move.w	VRefNum,ioVRefNum(a0)
		clr.l	ioNamePtr(a0)
		dc.w	$a013			;PBFlushVol
1$		RETMAC

*
* Datei/Verzeichnis löschen
* a0: Zeiger auf MacObject
* Rückgabe: d0: Amiga-Fehlercode
*

DeleteFile	move.l	a0,a1
		lea	MDeleteFile,a0
		bsr	CallMac
		bra	ConvError

MDeleteFile	lea	FileParam,a0
		move.w	mo_VRefNum(a1),ioVRefNum(a0)
		move.l	mo_ParDirID(a1),ioDirID(a0)

		lea	mo_Name(a1),a1
		move.l	a1,ioNamePtr(a0)

		dc.w	$a209			;PBHDelete
		RETMAC

*
* Datei/Verzeichnis umbenennen/verschieben
* a0: Zeiger auf Quell-MacObject
* a1: Zeiger auf Ziel-MacObject
* Rückgabe: d0: Amiga-Fehlercode
*

RenameFile	move.l	a0,SrcObject
		move.l	a1,DestObject
		move.l	a0,a1
		lea	MRenameFile,a0
		bsr	CallMac
		bra	ConvError

MRenameFile	lea	FileParam,a0		;CopyParam
		move.w	mo_VRefNum(a1),ioVRefNum(a0)
		move.l	mo_ParDirID(a1),ioDirID(a0)

		lea	mo_Name(a1),a1
		move.l	a1,ioNamePtr(a0)

		move.l	DestObject,a1		;Verzeichnisse gleich?
		move.l	mo_ParDirID(a1),d0
		cmp.l	ioDirID(a0),d0
		beq	1$			;Dann nur umbenennen
		move.l	d0,ioNewDirID(a0)	;Sonst erst verschieben
		clr.l	ioNewName(a0)

		moveq	#5,d0			;PBHCatMove
		dc.w	$a260			;HFSDispatch
		tst.w	d0
		bne	2$

		lea	FileParam,a0		;Dann im Zielverzeichnis umbenennen
		move.l	DestObject,a1
		move.l	mo_ParDirID(a1),ioDirID(a0)

1$		lea	mo_Name(a1),a1
		move.l	a1,ioMisc(a0)

		dc.w	$a20b			;PBHRename
2$		RETMAC

*
* Aktuelle Fork einer geöffneten Datei löschen
* a0: Zeiger auf MacObject
* RÜckgabe: d0: Amiga-Fehlercode
*

TruncateFile	move.l	a0,a1
		lea	MTruncateFile,a0
		bsr	CallMac
		bra	ConvError

MTruncateFile	lea	FileParam,a0
		move.w	mo_FRefNum(a1),ioFRefNum(a0)
		clr.l	ioMisc(a0)		;Länge := 0

		dc.w	$a012			;PBSetEOF
		RETMAC

*
* Aus Datei lesen. mo_Pos wird NICHT aktualisiert!
* a0: Zeiger auf MacObject
* d0: Zeiger auf Puffer
* d1: Anzahl Bytes
* Rückgabe: d0: Tatsächliche Anzahl gelesener Bytes
*

ReadFromFile	move.l	d0,BufPtr
		move.l	d1,NumBytes
		move.l	a0,a1
		lea	MReadFromFile,a0
		bsr	CallMac
		move.l	FileParam+ioActCount,d0
		rts

MReadFromFile	lea	FileParam,a0
		move.w	mo_FRefNum(a1),ioFRefNum(a0)
		move.l	BufPtr,ioBuffer(a0)
		move.l	NumBytes,ioReqCount(a0)
		move.w	#fsFromStart,ioPosMode(a0)
		move.l	mo_Pos(a1),ioPosOffset(a0)

		dc.w	$a002			;PBRead
		RETMAC

*
* In Datei schreiben. mo_Pos wird NICHT aktualisiert!
* a0: Zeiger auf MacObject
* d0: Zeiger auf Puffer
* d1: Anzahl Bytes
* Rückgabe: d0: Tatsächliche Anzahl geschriebener Bytes
*

WriteToFile	move.l	d0,BufPtr
		move.l	d1,NumBytes
		move.l	a0,a1
		lea	MWriteToFile,a0
		bsr	CallMac
		move.l	FileParam+ioActCount,d0
		rts

MWriteToFile	lea	FileParam,a0
		move.w	mo_FRefNum(a1),ioFRefNum(a0)
		move.l	BufPtr,ioBuffer(a0)
		move.l	NumBytes,ioReqCount(a0)
		move.w	#fsFromStart,ioPosMode(a0)
		move.l	mo_Pos(a1),ioPosOffset(a0)

		dc.w	$a003			;PBWrite
		RETMAC


**
** Konstanten
**

; Strings
DOSName		dc.b	"dos.library",0
InputName	dc.b	"input.device",0
SemaName	SHAPESEMANAME
NumObjsFmt	dc.b	"%d Objekte",0
VersTag		dc.b	0,"$VER: MacHandler V1.1 (12.09.95)",0
		CNOP	0,4


**
** Nicht initialisierte Daten
**

		SECTION	"BSS",BSS
_SysBase	ds.l	1
_DOSBase	ds.l	1

MyTask		ds.l	1		;Handler-Task
MyProc		ds.l	1		;Handler-Prozess
MyNode		ds.l	1		;Zeiger auf Dos-Node
ThisPacket	ds.l	1		;Gerade bearbeitetes Packet
VolumeNode	ds.l	1		;DeviceListEntry des Volumes

NumberOfLocks	ds.l	1		;Zähler für Anzahl der Locks
NumberOfHandles	ds.l	1		;Zähler für Anzahl der FileHandles

MacProc		ds.b	macproc_SIZEOF

VolumeInfo	ds.b	HVolumeParam_SIZEOF ;Info des aktuellen Volume
VolumeParam	ds.b	HVolumeParam_SIZEOF
VolumeName	ds.b	36		;BSTR mit Namen des Volume

FileInfo	ds.b	HFileInfo_SIZEOF ;Info der aktuellen Datei
FileParam	ds.b	HFileParam_SIZEOF

StringBuf	ds.b	256		;String-Puffer
StringBuf2	ds.b	256		;String-Puffer für OpenObject

RootObject	ds.b	mo_SIZEOF	;Object für das Root-Directory

BufPtr		ds.l	1		;Für ReadFromFile/WriteToFile
NumBytes	ds.l	1

MacSignalSet	ds.l	1		;Für ExecMacProc
MacSignal	ds.b	1
UseRsrcFork	ds.b	1		;Flag: Resource-Fork ansprechen
MacResult	ds.w	1		;Rückgabecode der Mac-Routinen

FileType	ds.l	1		;Typ von erzeugten Dateien
FileCreator	ds.l	1		;Creator von erzeugten Dateien

SrcObject	ds.l	1		;Zeiger auf Quell-Objekt für RenameFile
DestObject	ds.l	1		;Zeiger auf Ziel-Objekt für RenameFile

VolumeIndex	ds.l	1		;Indexnummer des Mac-Volumes

VRefNum		ds.w	1		;VRefNum des Mac-Volume
Scratch1	ds.w	1

		END
