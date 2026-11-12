*
* DracoGfx.asm - ShapeShifter external video driver for DraCo
*
* $VER: DracoGfx.asm 1.0 (11.08.95)
*
* (C) Copyright 1995 Christian Bauer
*

		MACHINE	68020

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"intuition/intuition.i"
		INCLUDE	"utility/tagitem.i"
		INCLUDE	"exec/alerts.i"
		INCLUDE	"retina/retina.i"
		INCLUDE	"retina/retinaemu.i"
		INCLUDE	"retina/retina_lib.i"
		INCLUDE	"retina/retinaemu_lib.i"
		INCLUDE	"shapeextvideo.i"

*
* Definition of our private context structure for storing local variables
*

 STRUCTURE	MyContext,0
	APTR	conIntuitionBase
	APTR	conGfxBase
	APTR	conDOSBase
	APTR	conRetinaBase
	APTR	conDracoGfxBase

	APTR	conScreen	;The screen
	APTR	conViewPort	;The screen's ViewPort
	APTR	conBitMap	;The screen's RastPort
	APTR	conRetinaScr	;The screen's RetinaScreen

	WORD	conVideoMode	;Video mode (VMODE_*)
	WORD	conPad0

	STRUCT	conRGBBuf,(256*3+2)*4	;Buffer for LoadRGB32
 LABEL	MyContext_SIZEOF

*
* Other definitions
*

; dracographics.library
GetRetinaScreen	= -30

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

DriverName	dc.b	"DraCo Retina Driver",0
		CNOP	0,4
DriverID	dc.b	"$VER: DraCo 1.0 (11.08.95)",13,10,0
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

; Open dos.library (for Delay())
		move.l	_ExecBase,a6
		lea	DOSName,a1
		moveq	#37,d0
		JSRLIB	OpenLibrary
		move.l	d0,conDOSBase(a2)
		beq	OpenFailed

; Open retina.library
		move.l	_ExecBase,a6
		lea	RetinaName,a1
		moveq	#0,d0
		JSRLIB	OpenLibrary
		move.l	d0,conRetinaBase(a2)
		beq	OpenFailed

; Open dracographics.library
		move.l	_ExecBase,a6
		lea	DracoGfxName,a1
		moveq	#0,d0
		JSRLIB	OpenLibrary
		move.l	d0,conDracoGfxBase(a2)
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
		move.w	d0,conVideoMode(a2)

		cmp.l	#VMODE_8BIT,d0
		bne	10$
		move.l	a5,a0
		move.l	#SHEV_RefreshType,d0
		JSRLIB	FindTagItem
		tst.l	d0
		beq	12$
		move.l	d0,a1
		move.l	#RTYPE_NONE,ti_Data(a1)
		move.l	#8,ScrDepth
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
		move.l	#2,ScrDepth		;Necessary for RE_OpenDeepScreen()
		move.l	#16,DeepScrDepth
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
		move.l	#RTYPE_BGR24,ti_Data(a1)
		move.l	#2,ScrDepth		;Necessary for RE_OpenDeepScreen
		move.l	#24,DeepScrDepth
12$

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
		cmp.w	#VMODE_8BIT,conVideoMode(a2)
		bne	OpenDeepScreen

		move.l	conIntuitionBase(a2),a6	;8 Bit
		sub.l	a0,a0
		lea	ScreenTags,a1
		JSRLIB	OpenScreenTagList
		move.l	d0,a3			;a3: Screen
		move.l	d0,conScreen(a2)
		beq	OpenFailed
		bra	ScreenOpened

OpenDeepScreen	move.l	a2,-(sp)		;16/24 Bit
		move.l	conDracoGfxBase(a2),a6
		sub.l	a0,a0
		lea	ScreenTags,a1
		lea	DeepScreenTags,a2
		jsr	_LVORE_OpenDeepScreen(a6)
		move.l	d0,a3
		move.l	(sp)+,a2
		move.l	d0,conScreen(a2)
		beq	OpenFailed

ScreenOpened	move.l	_UtilityBase,a6
		move.l	a5,a0
		move.l	#SHEV_Screen,d0
		JSRLIB	FindTagItem
		move.l	d0,a0
		move.l	a3,ti_Data(a0)

; Wait a bit (dracographics seems to need this)
		move.l	conDOSBase(a2),a6
		moveq	#15,d1
		JSRLIB	Delay

; Extract our private data
		lea	sc_ViewPort(a3),a0
		move.l	a0,conViewPort(a2)
		lea	sc_RastPort(a3),a0
		move.l	rp_BitMap(a0),conBitMap(a2)

; Did it open on the Retina card?
		move.l	conDracoGfxBase(a2),a6
		move.l	conBitMap(a2),a0
		jsr	GetRetinaScreen(a6)
		move.l	d0,conRetinaScr(a2)
		beq	OpenFailed

; Extract all the other data that the caller wants
		move.l	_UtilityBase,a6
		move.l	a5,a0
		move.l	#SHEV_ScreenBase,d0
		JSRLIB	FindTagItem
		tst.l	d0
		beq	1$
		move.l	d0,a1
		move.l	conRetinaScr(a2),a0
		move.l	_rs_BitMap(a0),a0
		move.l	conRetinaBase(a2),a6
		jsr	_LVORetina_SetSegmentPtr(a6)	;Preserves a1
		move.l	d0,ti_Data(a1)
1$
		move.l	_UtilityBase,a6
		move.l	a5,a0
		move.l	#SHEV_BytesPerRow,d0
		JSRLIB	FindTagItem
		tst.l	d0
		beq	2$
		move.l	d0,a1
		move.l	conRetinaScr(a2),a0
		moveq	#0,d0
		move.w	_rs_Modulo(a0),d0
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
		move.l	conScreen(a2),d0
		beq	1$
		cmp.w	#VMODE_8BIT,conVideoMode(a2)
		bne	11$
		move.l	d0,a0			;8 Bit
		move.l	conIntuitionBase(a2),a6
		JSRLIB	CloseScreen
		bra	1$
11$		move.l	d0,a0			;16/24 Bit
		move.l	conDracoGfxBase(a2),a6
		jsr	_LVORE_CloseDeepScreen(a6)
1$

; Close dracographics.library
		move.l	conDracoGfxBase(a2),d0
		beq	2$
		move.l	d0,a1
		move.l	_ExecBase,a6
		JSRLIB	CloseLibrary
2$

; Close retina.library
		move.l	conRetinaBase(a2),d0
		beq	3$
		move.l	d0,a1
		move.l	_ExecBase,a6
		JSRLIB	CloseLibrary
3$

; Close dos.library
		move.l	conDOSBase(a2),d0
		beq	4$
		move.l	d0,a1
		move.l	_ExecBase,a6
		JSRLIB	CloseLibrary
4$

; Close graphics.library
		move.l	conGfxBase(a2),d0
		beq	5$
		move.l	d0,a1
		move.l	_ExecBase,a6
		JSRLIB	CloseLibrary
5$

; Close intuition.library
		move.l	conIntuitionBase(a2),d0
		beq	6$
		move.l	d0,a1
		move.l	_ExecBase,a6
		JSRLIB	CloseLibrary
6$

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
		move.w	#256*3-1,d1
1$		move.l	(a0)+,d0
		rol.l	#8,d0
		move.b	d0,(a1)+
		dbra	d1,1$

; Activate palette
		move.l	conRetinaBase(a2),a6
		move.l	conRetinaScr(a2),a0
		moveq	#0,d0		;Start with color #0
		move.l	#256,d1		;Load 256 colors
		lea	conRGBBuf(a2),a1
		jsr	_LVORetina_LoadPalette(a6)

		movem.l	(sp)+,d2-d7/a2-a6
		moveq	#0,d0
		rts

*
* Constants
*

; Library names
UtilityName	dc.b	"utility.library",0
IntuitionName	dc.b	"intuition.library",0
GfxName		dc.b	"graphics.library",0
DOSName		dc.b	"dos.library",0
RetinaName	dc.b	"retina.library",0
DracoGfxName	dc.b	"dracographics.library",0

; The name of our screen
ScreenName	dc.b	"ShapeShifter Screen",0
		CNOP	0,4

*
* Data section
*

		SECTION	"DATA",DATA

; Taglist for OpenScreen()
; Note that it's only safe to use this structure here because
;  the SHEV_OpenScreen routine is guaranteed not to be called
;  more than once at a time. The buffer for LoadRGB32, however,
;  is declared in the Context and not in the BSS segment because
;  that routine may be called multiple times for multiple
;  screens.
ScreenTags	dc.l	SA_Depth
ScrDepth	dc.l	0
		dc.l	SA_Width
ScrWidth	dc.l	0
		dc.l	SA_Height
ScrHeight	dc.l	0
		dc.l	SA_DisplayID
ScrDisplayID	dc.l	0
		dc.l	SA_Overscan
ScrOverscan	dc.l	0
		dc.l	SA_Quiet,-1
		dc.l	SA_Title,ScreenName
		dc.l	TAG_END,0

; Taglist for RE_OpenDeepScreen()
DeepScreenTags	dc.l	RESA_Depth
DeepScrDepth	dc.l	0
		dc.l	0,0

*
* BSS section
*

		SECTION	"BSS",BSS

; Library base pointers
_ExecBase	ds.l	1
_UtilityBase	ds.l	1

		END
