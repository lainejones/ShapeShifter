*
* Example.asm - Test for ShapeShifter external video driver interface
*
* $VER: Example.asm 1.0 (20.08.95)
*
* (C) Copyright 1995 Christian Bauer
*

		MACHINE	68020

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"intuition/intuition.i"
		INCLUDE	"utility/tagitem.i"
		INCLUDE	"shapeextvideo.i"

*
* Definition of our private context structure for storing local variables
*

 STRUCTURE	MyContext,0
	APTR	conIntuitionBase
	APTR	conGfxBase

	APTR	conScreen	;The screen
	APTR	conViewPort	;The screen's ViewPort
	APTR	conBitMap	;The screen's RastPort

	STRUCT	conRGBBuf,(256*3+2)*4	;Buffer for LoadRGB32

	BYTE	conHasGfx39	;Flag: Gfx V39 present
 LABEL	MyContext_SIZEOF

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
		dc.l	TAG_END,0

DriverName	dc.b	"Sample Monochrome Amiga Driver",0
		CNOP	0,4
DriverID	dc.b	"$VER: Example 1.0 (20.08.95)",13,10,0
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

; Open intuition.library
		move.l	_ExecBase,a6
		lea	IntuitionName,a1
		moveq	#37,d0
		JSRLIB	OpenLibrary
		move.l	d0,conIntuitionBase(a2)
		beq	OpenFailed

; Open graphics.library and check version
		move.l	_ExecBase,a6
		lea	GfxName,a1
		moveq	#37,d0
		JSRLIB	OpenLibrary
		move.l	d0,conGfxBase(a2)
		beq	OpenFailed

		move.l	d0,a0
		cmp.w	#39,LIB_VERSION(a0)
		shs.b	conHasGfx39(a2)

; Store context pointer in output taglist
		move.l	_UtilityBase,a6
		move.l	a5,a0
		move.l	#SHEV_Context,d0
		JSRLIB	FindTagItem
		move.l	d0,a0
		move.l	a2,ti_Data(a0)

; This driver only supports VMODE_1BIT
		move.l	_UtilityBase,a6
		move.l	a4,a0
		move.l	#SHEV_VideoMode,d0
		moveq	#VMODE_24BIT,d1		;Dummy default
		JSRLIB	GetTagData
		cmp.l	#VMODE_1BIT,d0
		bne	OpenFailed

; Extract screen parameters from input taglist
		move.l	_UtilityBase,a6
		move.l	a4,a0
		move.l	#SHEV_ScreenX,d0
		moveq	#0,d1
		JSRLIB	GetTagData
		move.l	d0,ScrWidth

		move.l	a4,a0
		move.l	#SHEV_ScreenY,d0
		moveq	#0,d1
		JSRLIB	GetTagData
		move.l	d0,ScrHeight

		move.l	a4,a0
		move.l	#SHEV_DisplayID,d0
		moveq	#0,d1
		JSRLIB	GetTagData
		move.l	d0,ScrDisplayID

		move.l	a4,a0
		move.l	#SHEV_OverscanType,d0
		moveq	#OSCAN_TEXT,d1
		JSRLIB	GetTagData
		move.l	d0,ScrOverscan

; Open the screen and store pointer in output taglist
		move.l	conIntuitionBase(a2),a6
		sub.l	a0,a0
		lea	ScreenTags,a1
		JSRLIB	OpenScreenTagList
		move.l	d0,a3			;a3: Screen
		move.l	d0,conScreen(a2)
		beq	OpenFailed

		move.l	_UtilityBase,a6
		move.l	a5,a0
		move.l	#SHEV_Screen,d0
		JSRLIB	FindTagItem
		move.l	d0,a0
		move.l	a3,ti_Data(a0)

; Extract our private data
		lea	sc_ViewPort(a3),a0
		move.l	a0,conViewPort(a2)
		lea	sc_RastPort(a3),a0
		move.l	rp_BitMap(a0),conBitMap(a2)

; Extract all the other data that the caller wants
		move.l	_UtilityBase,a6
		move.l	a5,a0
		move.l	#SHEV_ScreenBase,d0
		JSRLIB	FindTagItem
		tst.l	d0
		beq	1$
		move.l	d0,a1
		move.l	conBitMap(a2),a0
		move.l	bm_Planes(a0),ti_Data(a1)
1$
		move.l	a5,a0
		move.l	#SHEV_BytesPerRow,d0
		JSRLIB	FindTagItem
		tst.l	d0
		beq	2$
		move.l	d0,a1
		move.l	conBitMap(a2),a0
		moveq	#0,d0
		move.w	bm_BytesPerRow(a0),d0
		move.l	d0,ti_Data(a1)
2$
		move.l	a5,a0
		move.l	#SHEV_RefreshType,d0
		JSRLIB	FindTagItem
		tst.l	d0
		beq	3$
		move.l	d0,a1
		move.l	#RTYPE_NONE,ti_Data(a1)
3$
		move.l	a5,a0			;!! Besondere Flags setzen
		move.l	#SHEV_Flags,d0
		JSRLIB	FindTagItem
		tst.l	d0
		beq	4$
		move.l	d0,a1
		move.l	#SHEVF_DblWidthWin,ti_Data(a1)
4$

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
* a2: Context pointer
* a6: Base of utility.library
*

MyCloseScreen	movem.l	d2-d7/a2-a6,-(sp)

; Close the screen
		move.l	conScreen(a2),d0
		beq	1$
		move.l	d0,a0
		move.l	conIntuitionBase(a2),a6
		JSRLIB	CloseScreen
1$

; Close graphics.library
		move.l	conGfxBase(a2),d0
		beq	2$
		move.l	_ExecBase,a6
		move.l	d0,a1
		JSRLIB	CloseLibrary
2$

; Close intuition.library
		move.l	conIntuitionBase(a2),d0
		beq	3$
		move.l	_ExecBase,a6
		move.l	d0,a1
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
		move.w	#256,(a1)+
		move.w	#0,(a1)+
		move.w	#256*3-1,d1
1$		move.l	(a0)+,(a1)+
		dbra	d1,1$
		clr.l	(a1)

; Activate palette
		move.l	conGfxBase(a2),a6
		move.l	conViewPort(a2),a0
		lea	conRGBBuf(a2),a1
		JSRLIB	LoadRGB32

		movem.l	(sp)+,d2-d7/a2-a6
		moveq	#0,d0
		rts

*
* Constants
*

; Library names
IntuitionName	dc.b	"intuition.library",0
GfxName		dc.b	"graphics.library",0

; The name of our screen
ScreenName	dc.b	"ShapeShifter Screen",0
		CNOP	0,4

*
* Data section
*

		SECTION	"DATA",DATA

; Taglist for OpenScreen()
ScreenTags	dc.l	SA_Depth,1		;Only 1 bit supported
		dc.l	SA_Width
ScrWidth	dc.l	0
		dc.l	SA_Height
ScrHeight	dc.l	0
		dc.l	SA_DisplayID
ScrDisplayID	dc.l	0
		dc.l	SA_Overscan
ScrOverscan	dc.l	0
		dc.l	SA_Quiet,-1
		dc.l	SA_AutoScroll,-1
		dc.l	SA_Title,ScreenName
		dc.l	TAG_END,0

*
* BSS section
*

		SECTION	"BSS",BSS

; Library base pointers
_ExecBase	ds.l	1
_UtilityBase	ds.l	1

		END
