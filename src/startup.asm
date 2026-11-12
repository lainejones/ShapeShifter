**
** startup.asm - minimal startup for building ShapeShifter with vasm.
** Replaces PhxAss's Lib:Astartup.obj: ShapeShifter's _main parses its own
** arguments (ReadArgs / tooltypes), so only _SysBase, _DOSBase and
** _WBenchMsg are provided. _main is called with a plain jsr and returns
** with rts.
**

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/execbase.i"
		INCLUDE	"dos/dosextens.i"
		INCLUDE	"workbench/startup.i"

		XREF	_main
		XDEF	_SysBase
		XDEF	_DOSBase
		XDEF	_WBenchMsg

		XREF	_LVOForbid
		XREF	_LVOFindTask
		XREF	_LVOGetMsg
		XREF	_LVOReplyMsg
		XREF	_LVOWaitPort
		XREF	_LVOCloseLibrary
		XREF	_LVOOpenLibrary
		XREF	_LVOCurrentDir

		SECTION	"startup",CODE

Start		movem.l	d2-d7/a2-a6,-(sp)
		move.l	4.w,a6
		move.l	a6,_SysBase
		clr.l	_WBenchMsg
		sub.l	a1,a1
		jsr	_LVOFindTask(a6)
		move.l	d0,a4			;a4: our Process

		tst.l	pr_CLI(a4)
		bne.s	.opendos
		lea	pr_MsgPort(a4),a0	;started from Workbench
		jsr	_LVOWaitPort(a6)
		lea	pr_MsgPort(a4),a0
		jsr	_LVOGetMsg(a6)
		move.l	d0,_WBenchMsg

.opendos	lea	DOSName(pc),a1
		moveq	#37,d0
		jsr	_LVOOpenLibrary(a6)
		move.l	d0,_DOSBase
		beq.s	.nodos

		clr.l	OldDir			;_main does not preserve registers,
		clr.w	RestoreDir		;so keep these in memory
		move.l	_WBenchMsg,d0
		beq.s	.run
		move.l	d0,a0
		move.l	sm_ArgList(a0),d0
		beq.s	.run
		move.l	d0,a0
		move.l	wa_Lock(a0),d1
		beq.s	.run
		move.l	_DOSBase,a6
		jsr	_LVOCurrentDir(a6)
		move.l	d0,OldDir
		st	RestoreDir

.run		jsr	_main
		move.l	d0,d5			;d5: return code

		tst.w	RestoreDir
		beq.s	.closedos
		move.l	OldDir,d1
		move.l	_DOSBase,a6
		jsr	_LVOCurrentDir(a6)

.closedos	move.l	_SysBase,a6
		move.l	_DOSBase,a1
		jsr	_LVOCloseLibrary(a6)
		bra.s	.reply

.nodos		moveq	#20,d5			;RETURN_FAIL

.reply		move.l	_WBenchMsg,d0
		beq.s	.done
		move.l	_SysBase,a6
		jsr	_LVOForbid(a6)		;reply with multitasking off
		move.l	_WBenchMsg,a1
		jsr	_LVOReplyMsg(a6)

.done		move.l	d5,d0
		movem.l	(sp)+,d2-d7/a2-a6
		rts

DOSName		dc.b	"dos.library",0
		EVEN

		SECTION	"startupbss",BSS

_SysBase	ds.l	1
_DOSBase	ds.l	1
_WBenchMsg	ds.l	1
OldDir		ds.l	1		;current dir lock to restore on exit
RestoreDir	ds.w	1		;#0: OldDir is valid
