**
** MacEmulPRam.asm - save the Mac's PRAM while the Mac runs
**
** ShapeShifter writes "ShapeShifter PRAM" when the Mac is shut down (also
** after the emergency quit), but not when the Amiga is reset, the emulator
** is killed or something crashes: Mac settings such as the colour depth of
** a display mode were then lost. A small process now looks at the PRAM
** every few seconds and writes the file when it has changed.
**

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"dos/dos.i"
		INCLUDE	"dos/dostags.i"
		INCLUDE	"workbench/workbench.i"
		INCLUDE	"workbench/startup.i"
		INCLUDE	"macros.i"

		XDEF	StartPRamSaver
		XDEF	StopPRamSaver
		XDEF	MdIconNameP

		XREF	XPRam
		XREF	PRamName
		XREF	InsertImage
		XREF	DrvLog
		XREF	DrvLogIdx
		XREF	ExcLog
		XREF	ExcLogIdx

		SECTION	"CODE",CODE

PRAMSIZE	= 256
CHECKSECS	= 5		;seconds between two looks

; Start the saver (main task, multitasking on)
StartPRamSaver	movem.l	d0-d3/a0-a1/a6,-(sp)
		tst.b	SaverRunning
		bne	9$
		lea	XPRam,a0		;What the file holds now
		lea	LastPRam,a1
		moveq	#PRAMSIZE/4-1,d0
1$		move.l	(a0)+,(a1)+
		dbra	d0,1$
		st.b	SaverRunning
		move.l	_DOSBase,a6
		move.l	#SaverTags,d1
		JSRLIB	CreateNewProc
		move.l	d0,SaverProc
		bne	9$
		clr.b	SaverRunning
9$		movem.l	(sp)+,d0-d3/a0-a1/a6
		rts

; Stop it and wait until it has gone (at most two seconds)
StopPRamSaver	movem.l	d0-d2/a0-a1/a6,-(sp)
		tst.b	SaverRunning
		beq	9$
		move.l	_ExecBase,a6
		move.l	SaverProc,a1
		move.l	#SIGBREAKF_CTRL_C,d0
		JSRLIB	Signal
		move.l	_DOSBase,a6
		moveq	#100-1,d2
1$		tst.b	SaverRunning
		beq	9$
		moveq	#1,d1
		JSRLIB	Delay
		dbra	d2,1$
9$		movem.l	(sp)+,d0-d2/a0-a1/a6
		rts


; The saver process
SaverMain	bsr	AddMacDiskIcon		;"Mac disk" on the Workbench
		move.l	_DOSBase,a6
		move.l	#TraceEnvName,d1	;Diagnostic trace wanted? (SetEnv ShapeShifterTrace 1)
		moveq	#ACCESS_READ,d2
		JSRLIB	Lock
		move.l	d0,d1
		beq	SMLoop
		JSRLIB	UnLock
		st.b	TraceOn
SMLoop		moveq	#CHECKSECS*2-1,d7	;Wait in half seconds, look for Ctrl-C
1$		moveq	#25,d1
		JSRLIB	Delay
		bsr	DoDrops			;Images dropped on "Mac disk"?
		bsr	WriteTrace		;Diagnostic logs changed?
		move.l	_DOSBase,a6
		move.l	_ExecBase,a6
		moveq	#0,d0
		moveq	#0,d1
		JSRLIB	SetSignal
		move.l	_DOSBase,a6
		and.l	#SIGBREAKF_CTRL_C,d0
		bne	SMQuit
		dbra	d7,1$

		lea	XPRam,a0		;Changed since the last save?
		lea	LastPRam,a1
		moveq	#PRAMSIZE/4-1,d0
2$		cmpm.l	(a0)+,(a1)+
		dbne	d0,2$
		beq	SMLoop

		lea	XPRam,a0		;Take a copy, and only one that holds
		lea	TmpPRam,a1		; still (the Mac may be writing)
		moveq	#PRAMSIZE/4-1,d0
3$		move.l	(a0)+,(a1)+
		dbra	d0,3$
		lea	XPRam,a0
		lea	TmpPRam,a1
		moveq	#PRAMSIZE/4-1,d0
4$		cmpm.l	(a0)+,(a1)+
		dbne	d0,4$
		bne	SMLoop

		move.l	#PRamName,d1		;Write the file
		move.l	#MODE_NEWFILE,d2
		JSRLIB	Open
		move.l	d0,d6
		beq	SMLoop
		move.l	d6,d1
		move.l	#TmpPRam,d2
		move.l	#PRAMSIZE,d3
		JSRLIB	Write
		move.l	d0,d5
		move.l	d6,d1
		JSRLIB	Close
		cmp.l	#PRAMSIZE,d5
		bne	SMLoop
		lea	TmpPRam,a0
		lea	LastPRam,a1
		moveq	#PRAMSIZE/4-1,d0
5$		move.l	(a0)+,(a1)+
		dbra	d0,5$
		bra	SMLoop

SMQuit		bsr	RemMacDiskIcon
		clr.b	SaverRunning
		moveq	#0,d0
		rts


; Diagnostics (only with the variable ENV:ShapeShifterTrace set at start): when the
; driver call log or the exception log has new entries,
; write both to SYS:T/ShapeShifter.trace (or RAM:). Format: DrvLogIdx.w,
; ExcLogIdx.w, DrvLog (256 x 16 bytes), ExcLog (32 x 48 bytes).
WriteTrace	movem.l	d0-d7/a0-a6,-(sp)
		tst.b	TraceOn
		beq	9$
		move.w	DrvLogIdx,d0
		swap	d0
		move.w	ExcLogIdx,d0
		cmp.l	LastTraceIdx,d0
		beq	9$
		move.l	d0,LastTraceIdx
		move.l	_DOSBase,a6
		move.l	#TraceName1,d1
		move.l	#MODE_NEWFILE,d2
		JSRLIB	Open
		move.l	d0,d6
		bne	1$
		move.l	#TraceName2,d1
		move.l	#MODE_NEWFILE,d2
		JSRLIB	Open
		move.l	d0,d6
		beq	9$
1$		move.l	d6,d1
		move.l	#LastTraceIdx,d2
		moveq	#4,d3
		JSRLIB	Write
		move.l	d6,d1
		move.l	#DrvLog,d2
		move.l	#16*256,d3
		JSRLIB	Write
		move.l	d6,d1
		move.l	#ExcLog,d2
		move.l	#48*32,d3
		JSRLIB	Write
		move.l	d6,d1
		JSRLIB	Close
9$		movem.l	(sp)+,d0-d7/a0-a6
		rts

; Images dropped on the "Mac disk" MdAppIcon go into the first empty file disk
DoDrops		movem.l	d0-d7/a0-a6,-(sp)
1$		move.l	MdAppPort,d0
		beq	9$
		move.l	_ExecBase,a6
		move.l	d0,a0
		JSRLIB	GetMsg
		tst.l	d0
		beq	9$
		move.l	d0,a4
		move.l	am_NumArgs(a4),d6
		move.l	am_ArgList(a4),a3
		bra	5$
2$		move.l	wa_Name(a3),a0		;Files only
		tst.b	(a0)
		beq	4$
		move.l	_DOSBase,a6
		move.l	wa_Lock(a3),d1
		move.l	#DropPath,d2
		move.l	#256,d3
		JSRLIB	NameFromLock
		tst.l	d0
		beq	4$
		move.l	#DropPath,d1
		move.l	wa_Name(a3),d2
		move.l	#256,d3
		JSRLIB	AddPart
		tst.l	d0
		beq	4$
		lea	DropPath,a0
		jsr	InsertImage
		tst.l	d0
		beq	4$
		move.l	_IntuitionBase,a6	;No free drive, or not openable
		sub.l	a0,a0
		JSRLIB	DisplayBeep
4$		addq.l	#wa_SIZEOF,a3
5$		subq.l	#1,d6
		bpl	2$
		move.l	_ExecBase,a6
		move.l	a4,a1
		JSRLIB	ReplyMsg
		bra	1$
9$		movem.l	(sp)+,d0-d7/a0-a6
		rts

AddMacDiskIcon	movem.l	d0-d1/a0-a4/a6,-(sp)
		move.l	_ExecBase,a6
		lea	WBName,a1
		moveq	#37,d0
		JSRLIB	OpenLibrary
		move.l	d0,MdWBBase
		beq	9$
		JSRLIB	CreateMsgPort
		move.l	d0,MdAppPort
		beq	9$
		move.l	_IconBase,d0
		beq	9$
		move.l	d0,a6
		moveq	#WBDISK,d0
		JSRLIB	GetDefDiskObject
		move.l	d0,MdDiskObj
		beq	9$
		move.l	d0,a0
		move.l	#NO_ICON_POSITION,do_CurrentX(a0)
		move.l	#NO_ICON_POSITION,do_CurrentY(a0)
		move.l	MdWBBase,a6
		moveq	#0,d0
		moveq	#0,d1
		move.l	MdIconNameP,a0
		move.l	MdAppPort,a1
		sub.l	a2,a2
		move.l	MdDiskObj,a3
		sub.l	a4,a4
		JSRLIB	AddAppIconA
		move.l	d0,MdAppIcon
9$		movem.l	(sp)+,d0-d1/a0-a4/a6
		rts

RemMacDiskIcon	movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	MdAppIcon,d0
		beq	1$
		move.l	MdWBBase,a6
		move.l	d0,a0
		JSRLIB	RemoveAppIcon
		clr.l	MdAppIcon
1$		move.l	_ExecBase,a6
		move.l	MdAppPort,d0
		beq	3$
2$		move.l	MdAppPort,a0
		JSRLIB	GetMsg
		tst.l	d0
		beq	21$
		move.l	d0,a1
		JSRLIB	ReplyMsg
		bra	2$
21$		move.l	MdAppPort,a0
		JSRLIB	DeleteMsgPort
		clr.l	MdAppPort
3$		move.l	MdDiskObj,d0
		beq	4$
		move.l	_IconBase,a6
		move.l	d0,a0
		JSRLIB	FreeDiskObject
		clr.l	MdDiskObj
4$		move.l	MdWBBase,d0
		beq	5$
		move.l	_ExecBase,a6
		move.l	d0,a1
		JSRLIB	CloseLibrary
		clr.l	MdWBBase
5$		movem.l	(sp)+,d0-d1/a0-a1/a6
		rts


		SECTION	"DATA",DATA

		CNOP	0,4
SaverTags	dc.l	NP_Entry,SaverMain
		dc.l	NP_Name,SaverName
		dc.l	NP_Priority,-1
		dc.l	NP_StackSize,16384
		dc.l	TAG_DONE
SaverName	dc.b	"ShapeShifter helper",0
TraceEnvName	dc.b	"ENV:ShapeShifterTrace",0
TraceName1	dc.b	"SYS:T/ShapeShifter.trace",0
TraceName2	dc.b	"RAM:ShapeShifter.trace",0
WBName		dc.b	"workbench.library",0
MdIconNameP	dc.l	IconName	;(set by LocalizeNew)
IconName	dc.b	"Mac disk",0
		EVEN


		SECTION	"BSS",BSS

LastTraceIdx	ds.l	1
TraceOn		ds.b	1
TracePad	ds.b	1

SaverProc	ds.l	1
MdWBBase		ds.l	1
MdAppPort		ds.l	1
MdAppIcon		ds.l	1
MdDiskObj		ds.l	1
DropPath	ds.b	256
LastPRam	ds.b	PRAMSIZE
TmpPRam		ds.b	PRAMSIZE
SaverRunning	ds.b	1
		EVEN
