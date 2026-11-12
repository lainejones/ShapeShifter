**
** ReserveLow - keep the lowest 16 KB of memory free for ShapeShifter
**
** The Mac system has its variables at addresses 0 to $1FFF, and ShapeShifter
** runs Mac code on the real processor: that memory must not belong to anybody
** else. On the Amiga it is the start of chip memory, which is given away as
** soon as the system runs. So it has to be kept out from the very start of a
** boot. ReserveLow leaves a small module in memory and restarts the Amiga
** once; from then on, at every reset and until the Amiga is switched off, the
** start of chip memory is at $4000.
**
**   ReserveLow          in the Startup-Sequence (first line), or from a Shell
**   ReserveLow CHECK    only says whether the memory is reserved (WARN if not)
**   ReserveLow QUIET    no text unless something is wrong
**
** With the left mouse button held down, ReserveLow does nothing, and neither
** does its code in memory at a reset (if an Amiga should not get on with it).
**
** How: a piece of code at the top of chip memory is hooked into exec's
** CoolCapture vector, which exec calls at every reset when its memory lists
** stand. There it cuts everything below $4020 out of chip memory's free
** list and moves the memory header to $4000. expansion.library has been set
** up before that (nothing of ours can run earlier: exec also takes KickMemPtr
** and KickTagPtr only after it), and what it has put into the low memory is
** moved out: the ConfigDevs of the boards and, where it lies there, its
** library base (see MoveExpansion).
** Unlike PrepareEmul, and Reserve Warm on such Amigas, it does not search the
** Kickstart ROM for instructions or re-enter its reset code.
**
** It cannot work, changes nothing and says so, when ExecBase itself lies in
** the low memory: on an Amiga whose only fast memory comes from expansion
** cards, exec has nothing but chip memory when it sets itself up.
**
** Build: vasmm68k_mot -Fhunkexe -kick1hunks -nosym -o ReserveLow ReserveLow.asm
**

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/nodes.i"
		INCLUDE	"exec/lists.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"exec/execbase.i"
		INCLUDE	"exec/resident.i"
		INCLUDE	"exec/libraries.i"
		INCLUDE	"exec/io.i"
		INCLUDE	"devices/inputevent.i"
		INCLUDE	"dos/dos.i"
		INCLUDE	"lvo/exec_lib.i"
		INCLUDE	"lvo/dos_lib.i"

LOWTOP		= $4000			;Chip memory starts here afterwards
NEWFIRST	= LOWTOP+MH_SIZE	;... and its first free chunk here or above
_LVOPeekQualifier = -42			;input.device

; What the module found, for the next "ReserveLow"
ST_NOTRUN	= 0
ST_DONE		= 1
ST_NOTKEPT	= 2			;Something is allocated in the low memory already
ST_NOCHIP	= 3
ST_EXECLOW	= 4
ST_SKIPPED	= 5			;Left mouse button held at that reset
MINLEFT		= 65536			;What the first chunk must still hold

CALL		MACRO
		jsr	_LVO\1(a6)
		ENDM

		SECTION	"CODE",CODE

Start		move.l	4.w,a6
		lea	DosName(pc),a1
		moveq	#36,d0
		CALL	OpenLibrary
		move.l	d0,d7			;d7: DOSBase
		bne	1$
		moveq	#20,d0			;(Kickstart 1.x: nothing for us)
		rts
1$		lea	ArgArray(pc),a0
		clr.l	(a0)
		clr.l	4(a0)
		move.l	d7,a6
		lea	Template(pc),a0
		move.l	a0,d1
		lea	ArgArray(pc),a0
		move.l	a0,d2
		moveq	#0,d3
		CALL	ReadArgs
		move.l	d0,d6			;d6: RDArgs
		bne	2$
		lea	TxtUsage(pc),a0
		bsr	Say
		moveq	#20,d5
		bra	Exit
2$		moveq	#0,d5			;d5: return code

; (ChipName lies in the part that stays in memory)

; Reserved already? (by us, PrepareEmul, Reserve Warm ...: $2000 is what
; ShapeShifter asks for)
		bsr	ChipHeader
		move.l	d0,d4			;d4: chip memory header
		beq	Exit
		cmp.l	#$2000,d4
		blo	NotReserved
		lea	TxtIsReserved(pc),a0
		bsr	SayUnlessQuiet
		bra	Exit

NotReserved	move.l	ArgArray(pc),d0		;CHECK: say so, change nothing
		beq	3$
		lea	TxtNotReserved(pc),a0
		bsr	SayUnlessQuiet
		moveq	#5,d5
		bra	Exit

; Our module is in memory and the memory is not reserved: it did not work
3$		move.l	4.w,a6
		move.l	CoolCapture(a6),d0
		beq	4$
		move.l	d0,a0
		cmp.l	#'RLOW',CoolMark-CoolEntry(a0)
		bne	4$
		cmp.l	#ST_SKIPPED,CoolStatus-CoolEntry(a0)
		bne	31$
		lea	TxtSkipped(pc),a0	;Asked to leave it alone at this start
		bsr	SayUnlessQuiet
		moveq	#5,d5
		bra	Exit
31$		lea	TxtFailed(pc),a0
		bsr	Say
		moveq	#5,d5			;(a warning: the Startup-Sequence must go on)
		bra	Exit

; Left mouse button held down, or Caps Lock on: leave everything alone.
; (The button is read from the hardware and works from the first moment;
; Caps Lock is only known once the key has been pressed since the reset.)
4$		btst	#6,$bfe001
		bne	41$
		lea	TxtButton(pc),a0
		bsr	SayUnlessQuiet
		moveq	#5,d5
		bra	Exit
41$		bsr	CapsLock
		beq	5$
		lea	TxtCapsLock(pc),a0
		bsr	SayUnlessQuiet
		moveq	#5,d5
		bra	Exit

; ExecBase (with its jump table below it) in the low memory: cannot be done
5$		move.l	a6,d0
		moveq	#0,d1
		move.w	LIB_NEGSIZE(a6),d1
		sub.l	d1,d0
		cmp.l	#NEWFIRST,d0
		bhs	Install
		lea	TxtExecLow(pc),a0
		bsr	Say
		moveq	#5,d5
		bra	Exit

; Put the module into memory that survives a reset, and restart
Install		move.l	#KickEnd-KickStart,d0	;Chip memory, at its top: it keeps its
		move.l	#MEMF_PUBLIC|MEMF_REVERSE|MEMF_CHIP,d1 ; contents over a reset
		CALL	AllocMem
		tst.l	d0
		beq	21$
		cmp.l	#NEWFIRST,d0		;In the low memory itself (a system that puts it
		bhs	2$			; at the bottom): the Mac would overwrite it
		move.l	d0,a1
		move.l	#KickEnd-KickStart,d0
		CALL	FreeMem
21$		lea	TxtNoMem(pc),a0
		bsr	Say
		moveq	#5,d5
		bra	Exit
2$		move.l	d0,a2			;a2: the block
		lea	KickStart(pc),a0
		move.l	a2,a1
		move.l	#KickEnd-KickStart,d0
		CALL	CopyMem

		lea	TxtRestart(pc),a0
		bsr	SayUnlessQuiet
		move.l	d7,a6			;Let the text out, and the disks settle
		moveq	#75,d1
		CALL	Delay
		move.l	4.w,a6

; exec calls CoolCapture at every reset once its memory lists stand, before
; any module (expansion.library first) is set up. The vector survives a
; reset with ExecBase, whose checksum has to cover it.
		CALL	Forbid
		move.l	a2,CoolSelf-KickStart(a2)
		move.l	CoolCapture(a6),CoolOld-KickStart(a2)
		lea	CoolEntry-KickStart(a2),a0
		move.l	a0,CoolCapture(a6)
		lea	SoftVer(a6),a0		;ExecBase checksum: the words from SoftVer
		moveq	#0,d1			; up to ChkSum add up to $FFFF
		moveq	#(ChkSum-SoftVer)/2-1,d0
6$		add.w	(a0)+,d1
		dbra	d0,6$
		not.w	d1
		move.w	d1,ChkSum(a6)
		CALL	CacheClearU
		CALL	ColdReboot		;(does not come back)

Exit		move.l	d7,a6
		move.l	d6,d1
		beq	1$
		CALL	FreeArgs
1$		move.l	a6,a1
		move.l	4.w,a6
		CALL	CloseLibrary
		move.l	d5,d0
		rts

; d0: the chip memory header (0: none)
ChipHeader	movem.l	a0-a1/a6,-(sp)
		move.l	4.w,a6
		CALL	Forbid
		lea	MemList(a6),a0
		lea	ChipName(pc),a1
		CALL	FindName
		move.l	d0,-(sp)
		CALL	Permit
		move.l	(sp)+,d0
		movem.l	(sp)+,a0-a1/a6
		rts

; Z clear: Caps Lock is on
CapsLock	movem.l	d1-d2/a0-a1/a6,-(sp)
		moveq	#0,d2
		move.l	4.w,a6
		lea	InputName(pc),a0
		moveq	#0,d0
		lea	InputReq(pc),a1
		moveq	#0,d1
		CALL	OpenDevice
		tst.l	d0
		bne	1$
		move.l	InputReq+IO_DEVICE(pc),a6
		CALL	PeekQualifier
		move.w	d0,d2
		move.l	4.w,a6
		lea	InputReq(pc),a1
		CALL	CloseDevice
1$		and.w	#IEQUALIFIER_CAPSLOCK,d2
		movem.l	(sp)+,d1-d2/a0-a1/a6
		rts

SayUnlessQuiet	move.l	ArgArray+4(pc),d0
		bne	SayNot
Say		movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	d7,a6
		move.l	a0,d1
		CALL	PutStr
		movem.l	(sp)+,d0-d1/a0-a1/a6
SayNot		rts

DosName		dc.b	"dos.library",0
InputName	dc.b	"input.device",0
Template	dc.b	"CHECK/S,QUIET/S",0
		dc.b	"$VER: ReserveLow 1.1 (11.11.2026)",0
TxtUsage	dc.b	"ReserveLow [CHECK] [QUIET]: keeps the lowest 16 KB of memory free for ShapeShifter",10,0
TxtIsReserved	dc.b	"The low memory is reserved for ShapeShifter.",10,0
TxtNotReserved	dc.b	"The low memory is not reserved.",10,0
TxtRestart	dc.b	"ReserveLow: reserving the low memory for ShapeShifter. The Amiga restarts once.",10,0
TxtCapsLock	dc.b	"ReserveLow: Caps Lock is on, nothing done.",10,0
TxtButton	dc.b	"ReserveLow: the left mouse button is held down, nothing done.",10,0
TxtSkipped	dc.b	"ReserveLow: the left mouse button was held down at this start: the low",10
		dc.b	"memory is not reserved until the next reset.",10,0
TxtNoMem	dc.b	"ReserveLow: not enough memory.",10,0
TxtExecLow	dc.b	"ReserveLow cannot reserve the low memory on this Amiga: the system itself",10
		dc.b	"(ExecBase) lies there. Nothing was changed.",10
		dc.b	"See the manual, ",34,"Reserving the low memory",34,", for other ways.",10,0
TxtFailed	dc.b	"ReserveLow could not reserve the low memory on this Amiga: the restart did",10
		dc.b	"not keep it free. Nothing more was changed.",10
		dc.b	"See the manual, ",34,"Reserving the low memory",34,", for other ways.",10,0
		EVEN
ArgArray	dc.l	0,0			;CHECK, QUIET
InputReq	dcb.b	IOSTD_SIZE,0


**
** What stays in memory (copied as it is: position independent)
**

		CNOP	0,4
KickStart
CoolSelf	dc.l	0			;Where this block is
CoolOld		dc.l	0			;The CoolCapture that was there before
CoolStatus	dc.l	ST_NOTRUN
CoolMark	dc.l	'RLOW'
ChipName	dc.b	"chip memory",0
		CNOP	0,4

; Called by exec at every reset, when ExecBase and the memory lists stand and
; nothing else has been allocated. Take this block out of the free memory
; (after a reset it is free again), then the low memory.
CoolEntry	movem.l	d0-d3/a0-a3/a6,-(sp)
		move.l	4.w,a6
		move.l	CoolOld(pc),d0		;Whoever was there first
		beq	10$
		move.l	d0,a0
		jsr	(a0)
		move.l	4.w,a6
10$		move.l	#KickEnd-KickStart,d0
		move.l	CoolSelf(pc),a1
		CALL	AllocAbs

; The way out when an Amiga does not start with the low memory reserved:
; with the left mouse button held down at a reset, nothing is changed
		moveq	#ST_SKIPPED,d2
		btst	#6,$bfe001
		beq	9$

		moveq	#ST_NOCHIP,d2		;d2: status
		lea	MemList(a6),a0
		lea	ChipName(pc),a1
		CALL	FindName
		tst.l	d0
		beq	9$
		move.l	d0,a2			;a2: chip memory header
		moveq	#ST_DONE,d2
		cmp.l	#LOWTOP,a2		;Up there already
		bhs	9$

; ExecBase (with its jump table below it) must not be in the low memory
		moveq	#ST_EXECLOW,d2
		move.l	a6,d0
		moveq	#0,d1
		move.w	LIB_NEGSIZE(a6),d1
		sub.l	d1,d0
		cmp.l	#NEWFIRST,d0
		blo	9$

; Take everything below NEWFIRST out of the free list. First see what would
; be left
		moveq	#ST_NOTKEPT,d2
		moveq	#0,d3			;d3: free bytes at and above NEWFIRST
		move.l	MH_FIRST(a2),d0
20$		beq	22$
		move.l	d0,a0
		move.l	a0,d1
		add.l	MC_BYTES(a0),d1		;d1: end of this chunk
		sub.l	#NEWFIRST,d1
		bls	21$			;All of it below
		cmp.l	#NEWFIRST,a0
		blo	23$
		move.l	MC_BYTES(a0),d1		;All of it above
23$		add.l	d1,d3
21$		move.l	MC_NEXT(a0),d0
		bra	20$
22$		cmp.l	#MINLEFT,d3
		blo	9$

		move.l	MH_FIRST(a2),a0		;Now do it. a0: chunk
24$		cmp.l	#NEWFIRST,a0
		bhs	27$			;This one and the rest stay
		move.l	a0,d1
		add.l	MC_BYTES(a0),d1
		sub.l	#NEWFIRST,d1		;d1: what of it lies above
		bls	25$
		cmp.l	#MEM_BLOCKSIZE*2,d1
		blo	25$
		move.l	#NEWFIRST,a1		;It reaches across: the upper part stays
		move.l	MC_NEXT(a0),MC_NEXT(a1)
		move.l	d1,MC_BYTES(a1)
		move.l	a1,a0
		bra	27$
25$		move.l	MC_NEXT(a0),d0		;Gone
		beq	26$
		move.l	d0,a0
		bra	24$
26$		sub.l	a0,a0
27$		move.l	a0,MH_FIRST(a2)
		moveq	#0,d1			;Count again what is free
		move.l	a0,d0
28$		beq	29$
		move.l	d0,a0
		add.l	MC_BYTES(a0),d1
		move.l	MC_NEXT(a0),d0
		bra	28$
29$		move.l	d1,MH_FREE(a2)

; The header moves to LOWTOP. MH_LOWER stays below it, as the header's own
; place always was (and at $1000 like Reserve Warm has it: with $4000 the
; 68040.library would mark the page there invalid, says PrepareEmul's source)
		move.l	a2,a1
		CALL	Remove
		move.l	#LOWTOP,a1
		move.l	a2,a0
		moveq	#MH_SIZE/4-1,d0
1$		move.l	(a0)+,(a1)+
		dbra	d0,1$
		move.l	#LOWTOP,a1
		move.l	#$1000,MH_LOWER(a1)
		lea	MemList(a6),a0
		CALL	Enqueue

; What expansion.library has put into the low memory has to come out of it:
; the Mac will write there. Nothing else exists yet. Memory allocated from
; here on is above NEWFIRST.
		bsr	MoveExpansion
		moveq	#ST_DONE,d2

9$		lea	CoolStatus(pc),a0
		move.l	d2,(a0)
		movem.l	(sp)+,d0-d3/a0-a3/a6
		rts

; expansion.library is set up before anything of ours can run. On an Amiga
; where it finds no better memory, its library base and the ConfigDevs of the
; boards lie at the start of chip memory. Move them: the ConfigDevs by putting
; a copy in their place in the board list, the base as a whole.
; Only what <libraries/expansionbase.h> and <libraries/configvars.h> lay down
; is relied on: the board list and the mount list in the base, and a
; ConfigDev's node and cd_NextCD.
EB_BOARDLIST	= $3c			;eb_Private05: the ConfigDevs
EB_MOUNTLIST	= $4a			;eb_MountList
CD_NEXTCD	= $30			;cd_NextCD
CDCOPY		= 128			;A ConfigDev is 68 bytes (72 as allocated)

MoveExpansion	movem.l	d2-d5/a2-a5,-(sp)
		lea	LibList(a6),a0
		lea	ExpName(pc),a1
		CALL	FindName
		tst.l	d0
		beq	90$
		move.l	d0,a4			;a4: ExpansionBase

; The ConfigDevs
		move.l	EB_BOARDLIST(a4),a2	;a2: ConfigDev
30$		move.l	(a2),d4			;d4: the next one
		beq	40$
		cmp.l	#NEWFIRST,a2
		bhs	35$
; The copy goes into chip memory, which at this point starts right above
; the header: it stays below 32 KB. The TF4060's firmware (spirom.strap 1.0)
; reads its ConfigDev with a 16 bit index (move.l 20(d0.w),d0) and crashed
; with a copy in fast memory (A4000, guru 8000 0004 at every start).
		move.l	#CDCOPY,d0
		move.l	#MEMF_PUBLIC|MEMF_CHIP,d1
		CALL	AllocMem
		tst.l	d0
		beq	35$
		move.l	d0,a3			;a3: the copy
		move.l	a2,a0
		move.l	a3,a1
		moveq	#CDCOPY/4-1,d0
31$		move.l	(a0)+,(a1)+
		dbra	d0,31$
		move.l	LN_PRED(a2),a0		;Into the list in its place
		move.l	a3,LN_SUCC(a0)
		move.l	LN_SUCC(a2),a0
		move.l	a3,LN_PRED(a0)
		move.l	EB_BOARDLIST(a4),a0	;Who has it as cd_NextCD?
32$		tst.l	(a0)
		beq	35$
		cmp.l	CD_NEXTCD(a0),a2
		bne	33$
		move.l	a3,CD_NEXTCD(a0)
33$		move.l	(a0),a0
		bra	32$
35$		move.l	d4,a2
		bra	30$

; The library base, with the jump table below it
40$		moveq	#0,d2
		move.w	LIB_NEGSIZE(a4),d2	;d2: bytes below the base
		moveq	#0,d3
		move.w	LIB_POSSIZE(a4),d3	;d3: bytes from the base on
		move.l	a4,d0
		sub.l	d2,d0
		cmp.l	#NEWFIRST,d0
		bhs	90$
		move.l	d2,d0
		add.l	d3,d0
		move.l	#MEMF_PUBLIC,d1
		CALL	AllocMem
		tst.l	d0
		beq	90$
		move.l	d0,a1
		move.l	a4,a0
		sub.l	d2,a0
		move.l	d2,d0
		add.l	d3,d0
		move.l	a1,a5
		add.l	d2,a5			;a5: the new base
		CALL	CopyMem

; Pointers of the base to itself (empty lists, a semaphore's queue ...)
		move.l	a5,d5
		sub.l	a4,d5			;d5: how far it has moved
		lea	LIB_SIZE(a5),a0
		move.l	d3,d0
		sub.l	#LIB_SIZE+4,d0
		bls	44$
		lsr.l	#1,d0
41$		move.l	(a0),d1
		cmp.l	a4,d1
		blo	42$
		sub.l	a4,d1
		cmp.l	d3,d1
		bhs	42$
		add.l	d5,(a0)
		addq.l	#2,a0			;(a pointer: not also the next word)
		subq.l	#1,d0
		bls	44$
42$		addq.l	#2,a0
		subq.l	#1,d0
		bhi	41$
44$
; Nodes on its two lists point back at the list heads
		lea	EB_BOARDLIST(a5),a0
		bsr	FixList
		lea	EB_MOUNTLIST(a5),a0
		bsr	FixList

; In the library list in place of the old one
		move.l	a4,a1
		CALL	Remove
		lea	LibList(a6),a0
		move.l	a5,a1
		CALL	Enqueue
		move.l	a5,a1
		or.b	#LIBF_CHANGED,LIB_FLAGS(a1)
		CALL	SumLibrary
		CALL	CacheClearU
90$		movem.l	(sp)+,d2-d5/a2-a5
		rts

; a0: a list header that has been copied. Its first and last node still point
; to the old header.
FixList		move.l	LH_HEAD(a0),a1
		tst.l	(a1)
		beq	1$			;Empty (and pointing to itself: done above)
		move.l	a0,LN_PRED(a1)
		move.l	LH_TAILPRED(a0),a1
		lea	LH_TAIL(a0),a0
		move.l	a0,LN_SUCC(a1)
1$		rts

ExpName		dc.b	"expansion.library",0
		CNOP	0,4
KickEnd

		END
