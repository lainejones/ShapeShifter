**
** MacEmulShare.asm - the synced drawer
**
** An AmigaDOS drawer (settings: "Synced drawer") appears on the Mac desktop
** as a disk. It is not a live file system: before the Mac starts, MacBrowse
** makes the Mac disk PROGDIR:SyncedDrawer.hfv match the drawer (SYNCIN, the
** disk is created when there is none), and ShapeShifter gives it to the Mac
** in a file disk place that is empty. When the Mac has shut down, MacBrowse
** brings what changed on the Mac back to the drawer (SYNCOUT).
**
** MacBrowse is looked for in PROGDIR:MacDiskTools, then in the path.
**

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"dos/dos.i"
		INCLUDE	"dos/dostags.i"
		INCLUDE	"utility/tagitem.i"
		INCLUDE	"macros.i"
CATCOMP_NUMBERS	= 1
		INCLUDE	"Strings.i"

		XDEF	SharedSyncIn
		XDEF	SharedSyncOut

		XREF	SReq
		XREF	PrefsNameTab
		XREF	SharedDrawer

		SECTION	"CODE",CODE

NUMAFD		= 4

**
** Before the Mac starts. d0: 0 = start the Mac, 1 = back to the settings,
** -1 = quit
**
SharedSyncIn	movem.l	d2-d7/a2-a6,-(sp)
		clr.b	ShareActive
		tst.b	SharedDrawer
		beq	SIGo

; A file disk place that is empty, the last one first
		lea	PrefsNameTab,a0
		moveq	#NUMAFD-1,d1
1$		move.l	(a0,d1.w*4),a2
		tst.b	(a2)
		beq	2$
		dbra	d1,1$
		move.l	#MSG_SHARE_NOSLOT_TXT,d0
		bra	SIAsk
2$		move.l	a2,ShareSlot

		bsr	ShareNames
		lea	ShareFmtIn,a0
		bsr	ShareRun
		move.l	d0,ShareArgs
		beq	3$
		move.l	#MSG_SHARE_FAIL_TXT,d0
		bra	SIAsk

; The Mac gets the disk
3$		move.l	ShareSlot,a1
		lea	ShareSlotName,a0
4$		move.b	(a0)+,(a1)+
		bne	4$
		st.b	ShareActive
SIGo		moveq	#0,d0
SIDone		movem.l	(sp)+,d2-d7/a2-a6
		rts

; Settings / Start anyway (without the drawer) / Quit
SIAsk		move.l	#MSG_CHK_MISSING_GADS,d1
		lea	ShareArgs,a3
		jsr	SReq
		cmp.l	#2,d0
		beq	SIGo
		tst.l	d0
		bne	SIDone			;1: settings
		moveq	#-1,d0
		bra	SIDone

**
** After the Mac has shut down and its disks are closed
**
SharedSyncOut	movem.l	d2-d7/a2-a6,-(sp)
		tst.b	ShareActive
		beq	9$
		clr.b	ShareActive
		move.l	ShareSlot,a0		;the place was only borrowed
		clr.b	(a0)
		lea	ShareFmtOut,a0
		bsr	ShareRun
		move.l	d0,ShareArgs
		beq	9$
		move.l	#MSG_SHARE_OUTFAIL_TXT,d0
		move.l	#MSG_REQGADSOK,d1
		lea	ShareArgs,a3
		jsr	SReq
9$		movem.l	(sp)+,d2-d7/a2-a6
		rts

**
** ShareImage: the Mac disk with its whole path (MacBrowse has another
** PROGDIR:). ShareTool: MacBrowse.
**
ShareNames	move.l	_DOSBase,a6
		lea	ShareImage,a0
		clr.b	(a0)
		move.l	#ProgDirName,d1
		moveq	#ACCESS_READ,d2
		JSRLIB	Lock
		move.l	d0,d4
		beq	1$
		move.l	d4,d1
		move.l	#ShareImage,d2
		move.l	#200,d3
		JSRLIB	NameFromLock
		move.l	d4,d1
		JSRLIB	UnLock
1$		move.l	#ShareImage,d1
		move.l	#ShareFileName,d2
		move.l	#260,d3
		JSRLIB	AddPart

		lea	ShareTool,a1		;MacBrowse beside ShapeShifter, else in the path
		lea	ToolPlain,a0
2$		move.b	(a0)+,(a1)+
		bne	2$
		move.l	#ToolLocal,d1
		moveq	#ACCESS_READ,d2
		JSRLIB	Lock
		move.l	d0,d4
		beq	3$
		move.l	d4,d1
		move.l	#ShareTool,d2
		move.l	#260,d3
		JSRLIB	NameFromLock
		move.l	d4,d1
		JSRLIB	UnLock
3$		rts

**
** Run MacBrowse with the command line format a0 (tool, image, drawer) in a
** console window that opens when there is something to see. d0: its return
** code, -1 when it could not be started
**
ShareRun	movem.l	d2-d5/a2-a3/a6,-(sp)
		move.l	_ExecBase,a6
		lea	ShareFmtArgs,a1
		move.l	#ShareTool,(a1)
		move.l	#ShareImage,4(a1)
		move.l	#SharedDrawer,8(a1)
		lea	SharePutCh,a2
		lea	ShareCmd,a3
		JSRLIB	RawDoFmt

		move.l	_DOSBase,a6
		move.l	#ShareConName,d1
		move.l	#MODE_OLDFILE,d2
		JSRLIB	Open
		move.l	d0,d4			;d4: console (0: none, then without)
		lea	ShareTags,a0
		move.l	d4,4(a0)
		move.l	#ShareCmd,d1
		move.l	a0,d2
		tst.l	d4
		bne	1$
		lea	ShareTags+16,a0		;no console: our own streams
		move.l	a0,d2
1$		JSRLIB	SystemTagList
		move.l	d0,d5
		move.l	d4,d1
		beq	2$
		JSRLIB	Close
2$		move.l	d5,d0
		movem.l	(sp)+,d2-d5/a2-a3/a6
		rts

SharePutCh	move.b	d0,(a3)+
		rts


		SECTION	"DATA",DATA

ShareTags	dc.l	SYS_Input,0
		dc.l	SYS_Output,0
		dc.l	NP_StackSize,65536	;(folders in folders)
		dc.l	TAG_DONE
ShareArgs	dc.l	0,0
ShareFmtArgs	dc.l	0,0,0

ProgDirName	dc.b	"PROGDIR:",0
ShareFileName	dc.b	"SyncedDrawer.hfv",0
ShareSlotName	dc.b	"PROGDIR:SyncedDrawer.hfv",0
ToolLocal	dc.b	"PROGDIR:MacDiskTools/MacBrowse",0
ToolPlain	dc.b	"MacBrowse",0
ShareFmtIn	dc.b	'"%s" "%s" SYNCIN "%s" NAME "Amiga"',0
ShareFmtOut	dc.b	'"%s" "%s" SYNCOUT "%s"',0
ShareConName	dc.b	"CON:20/30/600/150/ShapeShifter: synced drawer/AUTO/CLOSE",0
		EVEN


		SECTION	"BSS",BSS

ShareSlot	ds.l	1		;the file disk name field that was borrowed
ShareActive	ds.b	1		;#0: the Mac has the disk, SYNCOUT is owed
		EVEN
ShareImage	ds.b	264
ShareTool	ds.b	264
ShareCmd	ds.b	900

		END
