**
** MacEmulSetup.asm - first-run setup (new in 3.20)
**
** Runs once at the start, after the settings file was loaded, unless
** QUICKSTART was given:
** - no Mac ROM in PROGDIR:ShapeShifter ROM: look for a 512K/1MB ROM image
**   in ShapeShifter's drawer, or let the user choose one, and copy it there
** - no settings file (PROGDIR:ShapeShifter Prefs, the default name): offer
**   to choose settings for this Amiga (screen, memory, CPU options, Mac OS 8
**   mode) and to create an empty Mac disk as File disk 1, then show what
**   was chosen. The settings window opens with these values; Save keeps them.
**

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"dos/dos.i"
		INCLUDE	"exec/execbase.i"
		INCLUDE	"graphics/gfxbase.i"
		INCLUDE	"graphics/gfx.i"
		INCLUDE	"graphics/displayinfo.i"
		INCLUDE	"graphics/modeid.i"
		INCLUDE	"intuition/screens.i"
		INCLUDE	"utility/tagitem.i"
		INCLUDE	"intuition/intuition.i"
		INCLUDE	"libraries/cybergraphics.i"
		INCLUDE	"macros.i"
CATCOMP_NUMBERS	= 1
		INCLUDE	"Strings.i"

		XDEF	FirstRunSetup
		XDEF	SuggestDefaults

		XDEF	SReq
		XREF	CreateEmptyDisk
		XREF	PrefsDefName
		XREF	ROMName
		XREF	TheLocale
		XREF	GetString
		XREF	PrefsName
		XREF	QuickStart
		XREF	Has68060
		XREF	HasMMU
		XREF	OptNoCopyBack
		XREF	RequestFile		;MacEmulPrefs

UAE_MANUFACTURER = 2011			;WinUAE's own expansion boards
BestCModeIDTagList = -60		;cybergraphics.library
ROMSIZE512	= $080000
ROMSIZE1M	= $100000
DISKMB		= 256			;Size of the empty Mac disk
SUMEXTRALEN	= 256

		SECTION	"CODE",CODE

FirstRunSetup	movem.l	d0-d7/a0-a6,-(sp)
		moveq	#0,d6			;d6: #0 = offer the setup
		moveq	#0,d5			;d5: #0 = there is no settings file
		move.l	#PrefsName,d1
		bsr	Exists
		bne	1$
		moveq	#1,d5
		lea	PrefsName,a0		;The setup only for the default file
		lea	PrefsDefName,a1
		bsr	StrEq
		beq	1$
		moveq	#1,d6
1$
; Whatever the name: without a settings file the Mac gets settings that fit
; this Amiga, not the built-in 1.7 MB and a black-and-white screen.
; QUICKSTART: nothing is asked
		tst.l	QuickStart
		beq	10$
		tst.l	d5
		beq	99$
		bsr	ChooseDefaults
		bra	99$
10$		tst.l	d6
		bne	11$
		tst.l	d5
		beq	11$
		bsr	ChooseDefaults		;A file named with FILE= that is not there
		pea	PrefsName
		move.l	sp,a3
		move.l	#MSG_SETUP_NOFILE_TXT,d0
		move.l	#MSG_REQGADSOK,d1
		bsr	SReq
		addq.l	#4,sp
11$		moveq	#0,d7			;d7: #0 = ROM missing
		move.l	#ROMName,d1
		bsr	Exists
		bne	2$
		moveq	#1,d7
2$		move.l	d6,d0
		or.l	d7,d0
		beq	99$

		tst.l	d6			;Welcome
		beq	3$
		move.l	#MSG_SETUP_WELCOME_TXT,d0
		move.l	#MSG_SETUP_WELCOME_GADS,d1
		sub.l	a3,a3
		bsr	SReq			;1 Set up, 0 Skip
		tst.l	d0
		bne	3$
		bsr	ChooseDefaults		;Skipped: fitting settings all the same,
		moveq	#0,d6			; without the questions
3$		tst.l	d7
		beq	4$
		bsr	ROMStep
4$		tst.l	d6
		beq	99$
		bsr	ChooseDefaults
		bsr	DiskStep
		lea	SumArgs,a3		;What was chosen
		move.l	#MSG_SETUP_DONE_TXT,d0
		move.l	#MSG_REQGADSOK,d1
		bsr	SReq
99$		movem.l	(sp)+,d0-d7/a0-a6
		rts


; "Defaults" in the settings window: the settings chosen at the first start
; (screen, Mac memory, CPU options), and what they are
SuggestDefaults	movem.l	d0-d7/a0-a6,-(sp)
		bsr	ChooseDefaults
		lea	SumArgs,a3
		move.l	#MSG_DEFAULTS_DONE_TXT,d0
		move.l	#MSG_REQGADSOK,d1
		bsr	SReq
		movem.l	(sp)+,d0-d7/a0-a6
		rts


**
** The ROM
**

ROMStep		movem.l	d2-d7/a2-a6,-(sp)
		bsr	FindROM			;d0: #0 = found, in ROMSrcName
		tst.l	d0
		beq	2$
		move.l	#ROMSrcName,ReqArgs
		move.l	ROMSrcSize,d0
		lsr.l	#8,d0
		lsr.l	#2,d0
		move.l	d0,ReqArgs+4		;Size in K
		lea	ReqArgs,a3
		move.l	#MSG_SETUP_ROMFOUND_TXT,d0
		move.l	#MSG_SETUP_ROMFOUND_GADS,d1
		bsr	SReq			;1 Copy it, 2 Choose another, 0 Skip
		cmp.l	#1,d0
		beq	5$
		cmp.l	#2,d0
		beq	3$
		bra	9$
2$		sub.l	a3,a3			;None found
		move.l	#MSG_SETUP_NOROM_TXT,d0
		move.l	#MSG_SETUP_NOROM_GADS,d1
		bsr	SReq			;1 Choose, 0 Skip
		tst.l	d0
		beq	9$
3$		lea	ROMSrcName,a3		;File requester
		lea	ProgDirName,a4
		sub.l	a5,a5
		move.l	#MSG_SETUP_ROMHAIL,d5
		jsr	RequestFile
		tst.l	d0
		beq	9$
		move.l	#ROMSrcName,d1		;512K or 1MB?
		bsr	FileSize
		move.l	d0,ROMSrcSize
		cmp.l	#ROMSIZE512,d0
		beq	5$
		cmp.l	#ROMSIZE1M,d0
		beq	5$
		move.l	#ROMSrcName,ReqArgs
		lea	ReqArgs,a3
		move.l	#MSG_SETUP_BADROM_TXT,d0
		move.l	#MSG_REQGADSOK,d1
		bsr	SReq
		bra	9$
5$		bsr	CopyROM
		tst.l	d0
		bne	9$
		sub.l	a3,a3
		move.l	#MSG_SETUP_COPYFAIL_TXT,d0
		move.l	#MSG_REQGADSOK,d1
		bsr	SReq
9$		movem.l	(sp)+,d2-d7/a2-a6
		rts

; A file of 512K or 1MB in PROGDIR: that is not a Kickstart and not
; "ShapeShifter ROM" -> ROMSrcName, ROMSrcSize. d0: #0 = found
FindROM		movem.l	d2-d7/a2-a6,-(sp)
		moveq	#0,d7			;d7: result
		move.l	_DOSBase,a6
		move.l	#ProgDirName,d1
		move.l	#ACCESS_READ,d2
		JSRLIB	Lock
		move.l	d0,d6			;d6: lock on PROGDIR:
		beq	9$
		move.l	d6,d1
		move.l	#SetupFIB,d2
		JSRLIB	Examine
		tst.l	d0
		beq	8$
1$		move.l	d6,d1
		move.l	#SetupFIB,d2
		JSRLIB	ExNext
		tst.l	d0
		beq	8$
		lea	SetupFIB,a2
		tst.l	fib_DirEntryType(a2)	;Files only
		bpl	1$
		move.l	fib_Size(a2),d0
		cmp.l	#ROMSIZE512,d0
		beq	2$
		cmp.l	#ROMSIZE1M,d0
		bne	1$
2$		move.l	d0,ROMSrcSize
		lea	fib_FileName(a2),a0
		lea	ROMFileName,a1
		bsr	StrEqNoCase
		bne	1$
		lea	ROMSrcName,a0		;PROGDIR:name
		lea	ProgDirName,a1
3$		move.b	(a1)+,(a0)+
		bne	3$
		move.l	#ROMSrcName,d1
		lea	fib_FileName(a2),a0
		move.l	a0,d2
		move.l	#256,d3
		JSRLIB	AddPart
		move.l	#ROMSrcName,d1		;Not a Kickstart ($1111/$1114)?
		move.l	#MODE_OLDFILE,d2
		JSRLIB	Open
		move.l	d0,d4
		beq	1$
		move.l	d4,d1
		move.l	#ROMHead,d2
		moveq	#4,d3
		JSRLIB	Read
		move.l	d0,d5
		move.l	d4,d1
		JSRLIB	Close
		cmp.l	#4,d5
		bne	1$
		move.w	ROMHead,d0
		cmp.w	#$1111,d0
		beq	1$
		cmp.w	#$1114,d0
		beq	1$
		moveq	#1,d7			;Found
8$		move.l	d6,d1
		JSRLIB	UnLock
9$		move.l	d7,d0
		movem.l	(sp)+,d2-d7/a2-a6
		rts

; ROMSrcName (ROMSrcSize bytes) to PROGDIR:ShapeShifter ROM. d0: #0 = OK
CopyROM		movem.l	d2-d7/a2-a6,-(sp)
		moveq	#0,d7			;d7: result
		move.l	_ExecBase,a6
		move.l	ROMSrcSize,d0
		moveq	#MEMF_ANY,d1
		JSRLIB	AllocVec
		move.l	d0,d6			;d6: buffer
		beq	9$
		move.l	_DOSBase,a6
		move.l	#ROMSrcName,d1
		move.l	#MODE_OLDFILE,d2
		JSRLIB	Open
		move.l	d0,d4
		beq	8$
		move.l	d4,d1
		move.l	d6,d2
		move.l	ROMSrcSize,d3
		JSRLIB	Read
		move.l	d0,d5
		move.l	d4,d1
		JSRLIB	Close
		cmp.l	ROMSrcSize,d5
		bne	8$
		move.l	#ROMName,d1
		move.l	#MODE_NEWFILE,d2
		JSRLIB	Open
		move.l	d0,d4
		beq	8$
		move.l	d4,d1
		move.l	d6,d2
		move.l	ROMSrcSize,d3
		JSRLIB	Write
		move.l	d0,d5
		move.l	d4,d1
		JSRLIB	Close
		cmp.l	ROMSrcSize,d5
		beq	7$
		move.l	#ROMName,d1		;Not all written: remove it
		JSRLIB	DeleteFile
		bra	8$
7$		moveq	#1,d7
8$		move.l	_ExecBase,a6
		move.l	d6,a1
		JSRLIB	FreeVec
9$		move.l	d7,d0
		movem.l	(sp)+,d2-d7/a2-a6
		rts


**
** Settings for this Amiga
**

ChooseDefaults	movem.l	d2-d7/a2-a6,-(sp)
; Memory: half the largest fast memory block, at most 128 MB. Not less than
; a Mac system needs to start, though: 16 MB (Mac OS 8 wants 12, System 7.5
; eight) when the Amiga has that much, else what there is, less 2 MB for
; the Amiga side.
		move.l	_ExecBase,a6
		move.l	#MEMF_FAST|MEMF_LARGEST,d1
		JSRLIB	AvailMem
		move.l	d0,d1			;d1: the largest block
		lsr.l	#1,d0
		and.l	#$fff00000,d0
		cmp.l	#$08000000,d0
		bls	1$
		move.l	#$08000000,d0
1$		cmp.l	#$01000000,d0
		bhs	21$
		sub.l	#$00200000,d1		;(the ROM copy and the Amiga side need it)
		bls	2$			;Next to nothing there: keep the built-in value
		and.l	#$fff80000,d1		;in steps of 512 KB
		cmp.l	#$001b8000,d1
		bls	2$			;Not more than the built-in 1.7 MB: leave it
		cmp.l	#$01000000,d1
		bls	20$
		move.l	#$01000000,d1
20$		move.l	d1,d0
21$		move.l	d0,MemSize
2$		move.l	MemSize,d0
		add.l	#$00080000,d0		;Rounded, in MB
		moveq	#20,d1
		lsr.l	d1,d0
		move.l	d0,SumArgs+4

; Screen: graphics card 640x480 in 256 colours, else AGA 256 colours,
; else black and white
		move.l	#MSG_SETUP_SCR_BW,d2
		move.l	_ExecBase,a6
		lea	CyberGfxName,a1
		moveq	#40,d0
		JSRLIB	OpenLibrary
		move.l	d0,d4
		beq	4$
		move.l	d4,a6
		lea	BestModeTags,a0
		jsr	BestCModeIDTagList(a6)
		move.l	d0,d5
		move.l	_ExecBase,a6
		move.l	d4,a1
		JSRLIB	CloseLibrary
		cmp.l	#-1,d5
		beq	4$
		move.w	#VTYPE_CYBER,VideoType1
		move.w	#VMODE_8BIT,VideoMode1
		move.l	d5,DisplayID1
		move.l	#640,ScreenX1
		move.l	#480,ScreenY1
		move.w	#1,OverscanType1
		move.l	#MSG_SETUP_SCR_CGX,d2
		bra	5$
4$		moveq	#1,d3			;d3: planes of the Amiga screen
		move.l	_GfxBase,a0
		btst	#GFXB_AA_ALICE,gb_ChipRevBits0(a0)
		beq	41$
		moveq	#8,d3
		move.w	#VMODE_8BIT,VideoMode1
		move.l	#MSG_SETUP_SCR_AGA,d2
; 256 colours on Amiga bitplanes are converted from the Mac's screen memory:
; more often than the old default of every 10th frame, and with the MMU
; only the pages the Mac has written to
		move.w	#4,RefreshRate
		move.l	_ExecBase,a0
		btst	#AFB_68040,AttnFlags+1(a0)
		beq	40$
		move.w	#2,RefreshRate
40$		tst.b	HasMMU
		beq	41$
		move.w	#-1,MMURefresh
		st	SetupMMURef
41$		move.l	d3,d0
		bsr	NativeMode		;The screen mode of the Workbench's monitor
5$		move.l	d2,d0
		lea	TheLocale,a0
		jsr	GetString
		move.l	d0,SumArgs

; 68060 in UAE: NOCOPYBACK
		clr.b	SumExtra
		move.l	#SumExtra,SumArgs+8
		tst.b	SetupMMURef		;(what else was chosen, one line each)
		beq	50$
		move.l	#MSG_SETUP_MMUREF,d0
		bsr	AddExtra
50$
		tst.b	Has68060
		beq	6$
		move.l	_ExpansionBase,d0
		beq	6$
		move.l	d0,a6
		sub.l	a0,a0
		move.l	#UAE_MANUFACTURER,d0
		moveq	#-1,d1
		JSRLIB	FindConfigDev
		tst.l	d0
		beq	6$
		move.w	#-1,OptNoCopyBack
		move.l	#MSG_SETUP_NOCB,d0
		bsr	AddExtra

; 1MB ROM (Quadra): Mac OS 8 mode
6$		move.l	#ROMName,d1
		bsr	FileSize
		cmp.l	#ROMSIZE1M,d0
		bne	7$
		move.w	#-1,MacOS8Mode
7$		movem.l	(sp)+,d2-d7/a2-a6
		rts


; Add catalog string d0 to the summary's extra lines
AddExtra	movem.l	d0-d1/a0-a1,-(sp)
		lea	TheLocale,a0
		jsr	GetString
		move.l	d0,a0
		lea	SumExtra,a1
		move.w	#SUMEXTRALEN-2,d1
1$		tst.b	(a1)+			;To the end of what is there
		dbeq	d1,1$
		bne	3$			;Full
		subq.l	#1,a1
2$		move.b	(a0)+,(a1)+
		dbeq	d1,2$
		clr.b	-1(a1)
3$		movem.l	(sp)+,d0-d1/a0-a1
		rts

; Amiga screen: a mode of d0 planes, as near to 640x480 as the monitor the
; Workbench runs on can show (PAL: Hires Laced, Multiscan: Productivity ...),
; and the Mac screen no larger than that mode. Needs graphics V39; without
; it, or when nothing fits, the built-in default stays.
NativeMode	movem.l	d0-d7/a0-a6,-(sp)
		move.l	d0,d5			;d5: planes
		move.l	_GfxBase,a6
		cmp.w	#39,LIB_VERSION(a6)
		blo	9$
		move.l	_IntuitionBase,a6
		sub.l	a0,a0
		JSRLIB	LockPubScreen
		move.l	d0,d4			;d4: Workbench screen
		beq	9$
		move.l	_GfxBase,a6
		move.l	d4,a0
		lea	sc_ViewPort(a0),a0
		JSRLIB	GetVPModeID
		move.l	d0,d6			;d6: its mode
		move.l	_IntuitionBase,a6
		sub.l	a0,a0
		move.l	d4,a1
		JSRLIB	UnlockPubScreen
		move.l	_GfxBase,a6
		lea	BestNatTags,a2
		move.l	d5,BNDepth-BestNatTags+4(a2)
		move.l	#TAG_DONE,BNMonitor-BestNatTags(a2)
		cmp.l	#INVALID_ID,d6
		beq	2$
		sub.l	a0,a0			;Not a graphics card's monitor
		lea	SetupDisp,a1
		moveq	#dis_SIZEOF,d0
		move.l	#DTAG_DISP,d1
		move.l	d6,d2
		JSRLIB	GetDisplayInfoData
		tst.l	d0
		beq	2$
		move.l	SetupDisp+dis_PropertyFlags,d0
		and.l	#DIPF_IS_FOREIGN,d0
		bne	2$
		and.l	#MONITOR_ID_MASK,d6
		move.l	#BIDTAG_MonitorID,BNMonitor-BestNatTags(a2)
		move.l	d6,BNMonitor-BestNatTags+4(a2)
2$		move.l	a2,a0
		JSRLIB	BestModeIDA
		move.l	d0,d7			;d7: the mode
		cmp.l	#INVALID_ID,d0
		beq	9$
		sub.l	a0,a0			;How large is it (text overscan)?
		lea	SetupDims,a1
		moveq	#dim_SIZEOF,d0
		move.l	#DTAG_DIMS,d1
		move.l	d7,d2
		JSRLIB	GetDisplayInfoData
		tst.l	d0
		beq	9$
		lea	SetupDims+dim_TxtOScan,a0
		moveq	#0,d0
		move.w	ra_MaxX(a0),d0
		sub.w	ra_MinX(a0),d0
		addq.w	#1,d0
		moveq	#0,d1
		move.w	ra_MaxY(a0),d1
		sub.w	ra_MinY(a0),d1
		addq.w	#1,d1
		cmp.w	#512,d0			;Too small for a Mac screen: leave it
		blo	9$
		cmp.w	#342,d1
		blo	9$
		move.l	d7,DisplayID1
		and.w	#$fff0,d0		;Width in steps of 16
		cmp.l	ScreenX1,d0
		bhs	3$
		move.l	d0,ScreenX1
3$		cmp.l	ScreenY1,d1
		bhs	9$
		move.l	d1,ScreenY1
9$		movem.l	(sp)+,d0-d7/a0-a6
		rts


**
** An empty Mac disk as File disk 1
**

DiskStep	movem.l	d2-d7/a2-a6,-(sp)
		tst.b	AFDFileName1
		bne	9$
		move.l	#DiskName,d1		;Already there: use it
		bsr	Exists
		bne	8$
		move.l	#DISKMB,ReqArgs
		move.l	#DiskName,ReqArgs+4
		lea	ReqArgs,a3
		move.l	#MSG_SETUP_DISK_TXT,d0
		move.l	#MSG_SETUP_DISK_GADS,d1
		bsr	SReq			;1 Create, 0 No
		tst.l	d0
		beq	9$
		move.l	#DiskName,d1
		move.l	#DISKMB*1024*1024,d2
		jsr	CreateEmptyDisk
		tst.l	d0
		bne	8$
7$		move.l	#DiskName,ReqArgs
		lea	ReqArgs,a3
		move.l	#MSG_SETUP_DISKFAIL_TXT,d0
		move.l	#MSG_REQGADSOK,d1
		bsr	SReq
		bra	9$
8$		lea	DiskName,a0		;File disk 1
		lea	AFDFileName1,a1
		moveq	#79,d0
1$		move.b	(a0)+,(a1)+
		dbeq	d0,1$
9$		movem.l	(sp)+,d2-d7/a2-a6
		rts


**
** Helpers
**

; Requester: d0 text, d1 gadgets (MSG_), a3 arguments. d0: answer
SReq		movem.l	d1-d2/a0-a3/a6,-(sp)
		move.l	d1,d2
		lea	TheLocale,a0
		jsr	GetString
		move.l	d0,SetupES+es_TextFormat
		move.l	d2,d0
		lea	TheLocale,a0
		jsr	GetString
		move.l	d0,SetupES+es_GadgetFormat
		move.l	#MSG_REQTITLE,d0
		lea	TheLocale,a0
		jsr	GetString
		move.l	d0,SetupES+es_Title
		move.l	_IntuitionBase,a6
		sub.l	a0,a0
		lea	SetupES,a1
		sub.l	a2,a2
		JSRLIB	EasyRequestArgs
		movem.l	(sp)+,d1-d2/a0-a3/a6
		rts

; Does file d1 exist? d0 (Z): #0 = yes
Exists		movem.l	d1-d2/a0-a1/a6,-(sp)
		move.l	_DOSBase,a6
		move.l	#ACCESS_READ,d2
		JSRLIB	Lock
		tst.l	d0
		beq	1$
		move.l	d0,d1
		JSRLIB	UnLock
		moveq	#-1,d0
1$		movem.l	(sp)+,d1-d2/a0-a1/a6
		tst.l	d0
		rts

; Size of file d1, 0 if it is not there
FileSize	movem.l	d1-d3/a0-a1/a6,-(sp)
		move.l	_DOSBase,a6
		move.l	#ACCESS_READ,d2
		JSRLIB	Lock
		move.l	d0,d3
		beq	2$
		move.l	d3,d1
		move.l	#SetupFIB,d2
		JSRLIB	Examine
		move.l	d0,-(sp)
		move.l	d3,d1
		JSRLIB	UnLock
		move.l	(sp)+,d0
		tst.l	d0
		beq	2$
		move.l	SetupFIB+fib_Size,d0
		bra	3$
2$		moveq	#0,d0
3$		movem.l	(sp)+,d1-d3/a0-a1/a6
		rts

; Strings a0 and a1 equal? d0 (Z): #0 = yes. StrEqNoCase ignores case
StrEq		moveq	#0,d1
		bra	StrCmp
StrEqNoCase	moveq	#$20,d1
StrCmp		movem.l	d2-d3/a0-a1,-(sp)
1$		move.b	(a0)+,d2
		move.b	(a1)+,d3
		beq	6$
		tst.b	d2
		beq	8$
		or.b	d1,d2
		or.b	d1,d3
		cmp.b	d2,d3
		beq	1$
		bra	8$
6$		tst.b	d2
		bne	8$
		moveq	#-1,d0
		bra	9$
8$		moveq	#0,d0
9$		movem.l	(sp)+,d2-d3/a0-a1
		tst.l	d0
		rts


		SECTION	"DATA",DATA

SetupES		dc.l	EasyStruct_SIZEOF,0,0,0,0
BestNatTags	dc.l	BIDTAG_NominalWidth,640
		dc.l	BIDTAG_NominalHeight,480
BNDepth		dc.l	BIDTAG_Depth,1
BNMonitor	dc.l	TAG_DONE,0		;(BIDTAG_MonitorID, the Workbench's monitor)
		dc.l	TAG_DONE
BestModeTags	dc.l	CYBRBIDTG_Depth,8
		dc.l	CYBRBIDTG_NominalWidth,640
		dc.l	CYBRBIDTG_NominalHeight,480
		dc.l	TAG_DONE
ROMFileName	dc.b	"ShapeShifter ROM",0
ProgDirName	dc.b	"PROGDIR:",0
DiskName	dc.b	"PROGDIR:Mac disk.hfv",0
CyberGfxName	dc.b	"cybergraphics.library",0
EmptyStr	dc.b	0
		EVEN


		SECTION	"BSS",BSS

SetupFIB	ds.b	fib_SIZEOF		;(first: long-aligned)
ReqArgs		ds.l	4
SumArgs		ds.l	3			;Screen text, MB, extra lines
SetupDisp	ds.b	dis_SIZEOF+4		;(long-aligned)
SetupDims	ds.b	dim_SIZEOF+4
SumExtra	ds.b	SUMEXTRALEN		;"NOCOPYBACK is on" ..., one line each
SetupMMURef	ds.b	1
		EVEN
ROMSrcSize	ds.l	1
ROMHead		ds.l	1
ROMSrcName	ds.b	256

		END
