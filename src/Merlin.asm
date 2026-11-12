*
* Merlin.asm - ShapeShifter external video driver for Merlin
*
* $VER: Merlin.asm 1.0 (20.08.95)
*
* (C) Copyright 1995 Christian Bauer
*

		MACHINE	68020

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"intuition/intuition.i"
		INCLUDE	"utility/tagitem.i"
		INCLUDE	"hrg/hrgsystem.i"
		INCLUDE	"shapeextvideo.i"

*
* Definition of our private context structure for storing local variables
*

 STRUCTURE	MyContext,0
	APTR	conHRGSystemBase

	APTR	conHRGScreen	;The HRG screen
	APTR	conBitMap	;The screen's RastPort

	STRUCT	conRGBBuf,256*4	;Buffer for SetPaletteRGBA
 LABEL	MyContext_SIZEOF

*
* hrgsystem.library vectors
*

hrLockBitMap	= -78
hrUnlockBitMap	= -84
hrOpenScreenTagList = -90
hrCloseScreen	= -96
hrSetPaletteRGBA = -126
hrSwitchCursor	= -216

*
* This is the driver header
*

		EVHEADER DriverTags

*
* The header tags that describe the driver and provide pointers to
* the driver's routines
*

DriverTags	dc.l	SHEV_Level,1		;Interface level 1
		dc.l	SHEV_Version,1
		dc.l	SHEV_Revision,0
		dc.l	SHEV_Name,DriverName
		dc.l	SHEV_ID,DriverID
		dc.l	SHEV_Author,DriverAuthor

		dc.l	SHEV_OpenScreen,MyOpenScreen
		dc.l	SHEV_CloseScreen,MyCloseScreen
		dc.l	SHEV_LoadRGB32,MyLoadRGB32
		dc.l	SHEV_LockDisplay,MyLockDisplay
		dc.l	SHEV_UnlockDisplay,MyUnlockDisplay
		dc.l	SHEV_PointerVisible,MyPointerVisible
		dc.l	SHEV_PointerInvisible,MyPointerInvisible
		dc.l	TAG_END,0

DriverName	dc.b	"Merlin Driver",0
		CNOP	0,4
DriverID	dc.b	"$VER: Merlin 1.0 (20.08.95)",13,10,0
		CNOP	0,4
DriverAuthor	dc.b	"Christian Bauer",0
		CNOP	0,4

*
* The OpenScreen routine
* a0: Taglist with input parameters
* a1: Taglist with output parameters
* a6: Base of utility.library
*

MyOpenScreen	movem.l	d2-d7/a2-a6,-(sp)
		move.l	a0,a4			;a4: Input taglist
		move.l	a1,a5			;a5: Output taglist
		move.l	a6,_UtilityBase
		move.l	(4).w,_ExecBase

; Allocate memory for context
		move.l	_ExecBase,a6
		move.l	#MyContext_SIZEOF,d0
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		JSRLIB	AllocVec
		tst.l	d0
		beq	OpenFailed
		move.l	d0,a2			;a2: Context

; Open hrgsystem.library
		move.l	_ExecBase,a6
		lea	HRGSystemName,a1
		moveq	#2,d0
		JSRLIB	OpenLibrary
		move.l	d0,conHRGSystemBase(a2)
		beq	OpenFailed

; Store context pointer in output taglist
		move.l	_UtilityBase,a6
		move.l	a5,a0
		move.l	#SHEV_Context,d0
		JSRLIB	FindTagItem
		move.l	d0,a0
		move.l	a2,ti_Data(a0)

; Get video mode and set the refresh type and screen depth accordingly
; This driver only supports VMODE_8BIT, VMODE_15BIT and VMODE_24BIT
		move.l	_UtilityBase,a6
		move.l	a4,a0
		move.l	#SHEV_VideoMode,d0
		moveq	#VMODE_1BIT,d1		;Dummy default
		JSRLIB	GetTagData

		cmp.l	#VMODE_8BIT,d0
		bne	10$
		move.l	a5,a0
		move.l	#SHEV_RefreshType,d0
		JSRLIB	FindTagItem
		tst.l	d0
		beq	12$
		move.l	d0,a1
		move.l	#RTYPE_NONE,ti_Data(a1)
		move.l	#HRCOL_PACKED8,HRGScrType
		bra	12$
10$
		cmp.l	#VMODE_15BIT,d0
		bne	11$
		move.l	a5,a0
		move.l	#SHEV_RefreshType,d0
		JSRLIB	FindTagItem
		tst.l	d0
		beq	12$
		move.l	d0,a1
		move.l	#RTYPE_RGB16PC,ti_Data(a1)
		move.l	#HRCOL_TARGA,HRGScrType
		bra	12$
11$
		cmp.l	#VMODE_24BIT,d0
		bne	OpenFailed
		move.l	a5,a0
		move.l	#SHEV_RefreshType,d0
		JSRLIB	FindTagItem
		tst.l	d0
		beq	12$
		move.l	d0,a1
		move.l	#RTYPE_RGB24,ti_Data(a1)
		move.l	#HRCOL_RGB24,HRGScrType
12$

; Extract screen parameters from input taglist
		move.l	_UtilityBase,a6
		move.l	a4,a0
		move.l	#SHEV_ScreenX,d0
		moveq	#0,d1
		JSRLIB	GetTagData
		move.l	d0,HRGScrWidth

		move.l	a4,a0
		move.l	#SHEV_ScreenY,d0
		moveq	#0,d1
		JSRLIB	GetTagData
		move.l	d0,HRGScrHeight

; Open the screen and store pointer in output taglist
		move.l	conHRGSystemBase(a2),a6
		lea	HRGScreenTags,a0
		jsr	hrOpenScreenTagList(a6)
		move.l	d0,a3			;a3: HRHandle
		move.l	d0,conHRGScreen(a2)
		beq	OpenFailed

		move.l	_UtilityBase,a6
		move.l	a5,a0
		move.l	#SHEV_Screen,d0
		JSRLIB	FindTagItem
		move.l	d0,a1
		move.l	conHRGScreen(a2),a0
		move.l	hrh_IScr(a0),ti_Data(a1)

; Extract out private data
		lea	hrh_BitMap(a3),a0
		move.l	a0,conBitMap(a2)

; Extract all the other data that the caller wants
		move.l	_UtilityBase,a6
		move.l	a5,a0
		move.l	#SHEV_ScreenBase,d0
		JSRLIB	FindTagItem
		tst.l	d0
		beq	1$
		move.l	d0,-(sp)
		move.l	conHRGSystemBase(a2),a6
		move.l	conBitMap(a2),a0
		jsr	hrLockBitMap(a6)
		move.l	(sp)+,a1
		move.l	d0,ti_Data(a1)
		move.l	conBitMap(a2),a0
		jsr	hrUnlockBitMap(a6)
1$
		move.l	_UtilityBase,a6
		move.l	a5,a0
		move.l	#SHEV_BytesPerRow,d0
		JSRLIB	FindTagItem
		tst.l	d0
		beq	2$
		move.l	d0,a1
		move.l	conBitMap(a2),a0
		moveq	#0,d0
		move.w	hrbm_BytesPerRow(a0),d0
		move.l	d0,ti_Data(a1)
2$

; Everything is OK
		movem.l	(sp)+,d2-d7/a2-a6
		moveq	#0,d0
		rts

; An error occurred
OpenFailed	movem.l	(sp)+,d2-d7/a2-a6
		moveq	#-1,d0
		rts

*
* The CloseScreen routine
* a0: Taglist with input parameters
* a1: Taglist with output parameters
* a2: Context pointer (never NULL)
* a6: Base of utility.library
*

MyCloseScreen	movem.l	d2-d7/a2-a6,-(sp)

; Close the screen
		move.l	conHRGScreen(a2),d0
		beq	1$
		move.l	conHRGSystemBase(a2),a6
		move.l	d0,a0
		jsr	hrCloseScreen(a6)
1$

; Close hrgsystem.library
		move.l	conHRGSystemBase(a2),d0
		beq	3$
		move.l	d0,a1
		move.l	_ExecBase,a6
		JSRLIB	CloseLibrary
3$

; Free context
		move.l	_ExecBase,a6
		move.l	a2,a1
		JSRLIB	FreeVec

CloseDone	movem.l	(sp)+,d2-d7/a2-a6
		moveq	#0,d0
		rts

*
* The LoadRGB32 routine
* a0: Taglist with input parameters
* a1: Taglist with output parameters
* a2: Context pointer
* a6: Base of utility.library
*

; Get pointer to 32 bit color table
MyLoadRGB32	movem.l	d2-d7/a2-a6,-(sp)
		move.l	a0,a4		;a4: Input taglist
		move.l	#SHEV_ColorTable,d0
		moveq	#0,d1
		JSRLIB	GetTagData
		move.l	d0,a0		;a0: Color table

; Convert to 8 bit color table
		lea	conRGBBuf(a2),a1
		move.w	#256-1,d1
1$		move.l	(a0)+,d0
		rol.l	#8,d0
		move.b	d0,(a1)+
		move.l	(a0)+,d0
		rol.l	#8,d0
		move.b	d0,(a1)+
		move.l	(a0)+,d0
		rol.l	#8,d0
		move.b	d0,(a1)+
		clr.b	(a1)+
		dbra	d1,1$

; Activate palette
		move.l	conHRGSystemBase(a2),a6
		move.l	conHRGScreen(a2),a0
		lea	conRGBBuf(a2),a1
		moveq	#0,d0
		move.l	#255,d1
		jsr	hrSetPaletteRGBA(a6)

		movem.l	(sp)+,d2-d7/a2-a6
		moveq	#0,d0
		rts

*
* The LockDisplay routine
* a0: Taglist with input parameters
* a1: Taglist with output parameters
* a2: Context pointer
* a6: Base of utility.library
*

; Find tag
MyLockDisplay	move.l	a6,-(sp)
		move.l	a1,a0
		move.l	#SHEV_ScreenBase,d0
		JSRLIB	FindTagItem
		move.l	d0,-(sp)

; Lock display and get screen base
		move.l	conHRGSystemBase(a2),a6
		move.l	conBitMap(a2),a0
		jsr	hrLockBitMap(a6)

; Store data in tag
		move.l	(sp)+,a1
		move.l	d0,ti_Data(a1)
		move.l	(sp)+,a6
		moveq	#0,d0
		rts

*
* The UnlockDisplay routine
* a0: Taglist with input parameters
* a1: Taglist with output parameters
* a2: Context pointer
* a6: Base of utility.library
*

MyUnlockDisplay	move.l	a6,-(sp)
		move.l	conHRGSystemBase(a2),a6
		move.l	conBitMap(a2),a0
		jsr	hrUnlockBitMap(a6)
		move.l	(sp)+,a6
		moveq	#0,d0
		rts

*
* The PointerVisible routine
* a0: Taglist with input parameters
* a1: Taglist with output parameters
* a2: Context pointer
* a6: Base of utility.library
*

MyPointerVisible
		move.l	a6,-(sp)
		move.l	conHRGSystemBase(a2),a6
		move.l	conHRGScreen(a2),a0
		moveq	#HRCUR_ON,d0
		jsr	hrSwitchCursor(a6)
		move.l	(sp)+,a6
		moveq	#0,d0
		rts

*
* The PointerInvisible routine
* a0: Taglist with input parameters
* a1: Taglist with output parameters
* a2: Context pointer
* a6: Base of utility.library
*

MyPointerInvisible
		move.l	a6,-(sp)
		move.l	conHRGSystemBase(a2),a6
		move.l	conHRGScreen(a2),a0
		moveq	#HRCUR_OFF,d0
		jsr	hrSwitchCursor(a6)
		move.l	(sp)+,a6
		moveq	#0,d0
		rts

*
* Constants
*

; Library names
HRGSystemName	dc.b	"hrgsystem.library",0
ScreenName	dc.b	"ShapeShifter Screen",0
		CNOP	0,4

*
* Data section
*

		SECTION	"DATA",DATA

; Taglist für den Screen
HRGScreenTags	dc.l	HTOS_BitMapType
HRGScrType	dc.l	0
		dc.l	HTOS_Width
HRGScrWidth	dc.l	0
		dc.l	HTOS_Height
HRGScrHeight	dc.l	0
		dc.l	HTOS_Active,-1
		dc.l	HTOS_MatchModeInfo,-1
		dc.l	HTOS_EazyScreen,HRES_SIMPLE
		dc.l	HTOS_Title,ScreenName
		dc.l	0,0

*
* BSS section
*

		SECTION	"BSS",BSS

; Library base pointers
_ExecBase	ds.l	1
_UtilityBase	ds.l	1

		END
