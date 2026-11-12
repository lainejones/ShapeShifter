*
* shapesupportexample.asm - Test for ShapeShifter support interface
*                           This example allocates and frees some
*                           Mac memory
*
* PhxAss shapesupportexample.asm INCPATH Include:
* PhxLnk Lib:Qstartup.obj shapesupportexample.o Lib:small.lib TO shapesupportexample
*
* $VER: shapesupportexample.asm 1.0 (20.11.94)
*
* (C) Copyright 1994 Christian Bauer
*

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"dos/dos.i"
		INCLUDE	"shapesupport.i"

		XREF	_SysBase		;Startup
		XREF	_DOSBase
		XDEF	_main


**
** Main program
**

; Find our task
_main		move.l	_SysBase,a6
		sub.l	a1,a1
		JSRLIB	FindTask
		move.l	d0,MyTask

; Get signal for CallMac
		move.l	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,MacSignal
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,MacSignalSet

; Invocation of a Mac routine: Allocate Mac memory
		lea	NewPtr,a0
		lea	$100,a1			;Number of bytes
		bsr	CallMac
		cmp.l	#-1,d0
		beq	NoEmulErr
		tst.l	d0
		beq	NoNewPtrErr

; Success: Print out message
		move.l	d0,MacMemPtr

		move.l	_DOSBase,a6
		move.l	#MacMemTxt,d1
		move.l	#MacMemPtr,d2
		JSRLIB	VPrintf

; Note: When using the allocated memory you have to make sure that
;  the user does not quit the emulator in the meantime. That can
;  be achieved by obtaining the semaphore.
;  When freeing the memory, I don't check the return value,
;  because if the emulation is not running, the memory is freed
;  anyway...

; Invocation of a Mac routine: Free Mac memory
		lea	DisposePtr,a0
		move.l	MacMemPtr,a1		;Pointer to memory block
		bsr	CallMac

; Print message
		move.l	_DOSBase,a6
		move.l	#PtrDisposedTxt,d1
		JSRLIB	PutStr

; Quit
Exit		move.l	_SysBase,a6
		move.b	MacSignal,d0
		JSRLIB	FreeSignal

		moveq	#0,d0
		rts

; Error condition
NoEmulErr	move.l	_DOSBase,a6
		move.l	#NoEmulTxt,d1
		JSRLIB	PutStr
		bra	Exit

NoNewPtrErr	move.l	_DOSBase,a6
		move.l	#NoNewPtrTxt,d1
		JSRLIB	PutStr
		bra	Exit


**
** Subroutines
**

*
* Call a Mac routine and wait for completion
* a0: pointer to routine
* a1: parameter for routine
* Return: d0: Return value of Mac routine (-1: emulation is not running)
*

; Save parameter
CallMac		link	a5,#-12
		move.l	a6,-(sp)
		move.l	_SysBase,a6
		move.l	a0,-8(a5)		;-8: routine
		move.l	a1,-12(a5)		;-12: parameter

; Find semaphore and test if Mac is running
		JSRLIB	Forbid
		lea	SemaName,a1
		JSRLIB	FindSemaphore
		move.l	d0,-4(a5)		;-4: semaphore
		beq	1$
		move.l	d0,a0
		tst.w	ss_MacRunning(a0)
		beq	1$
		JSRLIB	ObtainSemaphore
		JSRLIB	Permit

; Set up MacProc and call ExecMacProc for execution
		lea	MacProc,a0
		move.l	-8(a5),mp_Proc(a0)
		move.l	-12(a5),mp_Param(a0)
		move.l	-4(a5),a1
		move.l	ss_ExecMacProc(a1),a1
		jsr	(a1)

; Wait for completion
		move.l	MacSignalSet,d0
		JSRLIB	Wait

; Release semaphore
		move.l	-4(a5),a0
		JSRLIB	ReleaseSemaphore

		move.l	MacResult,d0
		move.l	(sp)+,a6
		unlk	a5
		rts

; Emulation is not running
1$		JSRLIB	Permit
		moveq	#-1,d0
		move.l	(sp)+,a6
		unlk	a5
		rts

*
* Return from a Mac routine. Must be called with bra/jmp.
* d0: return code of the routine, stored in MacResult
*

RetMac		move.l	d0,MacResult
		move.l	a6,-(sp)
		move.l	_SysBase,a6
		move.l	MyTask,a1
		move.l	MacSignalSet,d0
		JSRLIB	Signal
		move.l	(sp)+,a6
		rts

*
* Mac routine for allocating memory (NewPtr)
* Parameter: Number of bytes
*

NewPtr		move.l	a1,d0		;Number of bytes
		dc.w	$a71e		;NewPtrSysClear
		move.l	a0,d0		;Pointer to allocated area
		bra	RetMac

*
* Mac routine for freeing memory (DisposePtr)
* Parameter: Pointer to memory block
*

DisposePtr	move.l	a1,a0		;Pointer to allocated block
		dc.w	$a01f		;DisposePtr
		bra	RetMac


**
** Constants
**

; Strings
SemaName	SHAPESEMANAME

NoEmulTxt	dc.b	"The Macintosh emulation is not running.",10,0
NoNewPtrTxt	dc.b	"Mac memory allocation failed.",10,0
MacMemTxt	dc.b	"256 bytes of Mac memory allocated at %08lx.",10,0
PtrDisposedTxt	dc.b	"Memory block freed.",10,0
		CNOP	0,4


**
** Non-initialized data
**

		SECTION	"BSS",BSS
MyTask		ds.l	1

MacMemPtr	ds.l	1		;Pointer to Mac memory area

MacProc		ds.b	macproc_SIZEOF
MacResult	ds.l	1		;Return value of Mac routine
MacSignalSet	ds.l	1		;Signal: Mac routine completed
MacSignal	ds.b	1

		END
