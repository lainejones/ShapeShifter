	IFND	SHAPE_EXTVIDEO_I
SHAPE_EXTVIDEO_I SET	1

*
* ShapeShifter Macintosh Emulator - Definitions for external video drivers
*
* $VER: shapeextvideo.i 2.0 (12.11.95)
*
* (C) Copyright 1995 Christian Bauer
*

	IFND	EXEC_TYPES_I
	INCLUDE	"exec/types.i"
	ENDC

	IFND	UTILITY_TAGITEM_I
	INCLUDE	"utility/tagitem.i"
	ENDC

*
* Every external video driver must begin like this
* The EVHEADER macro is provided for convenience
*

 STRUCTURE	ShapeExternalVideo,0
	STRUCT	shev_RTS,4		;moveq #0,d0; rts for safety
	STRUCT	shev_ID,8		;Magic value for identification
	APTR	shev_Tags		;Pointer to TagItem array
 LABEL	shev_SIZEOF

EVHEADER	MACRO	;Parameter: Pointer to TagItem array
		moveq	#0,d0		;shev_RTS
		rts
		dc.b	"SHAPEEXV"	;shev_ID
		dc.l	\1		;shev_Tags
		ENDM

*
* These tags may appear in the shev_Tags array
*

SHEV_Level		= TAG_USER+"LEV" ;Interface level of the driver
SHEV_Version		= TAG_USER+"VER" ;Internal driver version
SHEV_Revision		= TAG_USER+"REV" ;Internal driver revision
SHEV_Name		= TAG_USER+"NAM" ;Pointer to driver name
SHEV_ID			= TAG_USER+"$VE" ;Pointer to ID string
SHEV_Author		= TAG_USER+"AUT" ;Pointer to author's name

SHEV_OpenScreen		= TAG_USER+"OPN" ;Routine for opening a screen
SHEV_CloseScreen	= TAG_USER+"CLS" ;Routine for closing a screen
SHEV_Refresh		= TAG_USER+"REF" ;Routine for refreshing the display
SHEV_LockDisplay	= TAG_USER+"LOK" ;Routine for locking the display memory
SHEV_UnlockDisplay	= TAG_USER+"ULK" ;Routine for unlocking the display memory
SHEV_LoadRGB32		= TAG_USER+"L32" ;Routine for setting the palette
SHEV_PointerInvisible	= TAG_USER+"PTI" ;Routine for blanking the Amiga mouse pointer
SHEV_PointerVisible	= TAG_USER+"PTV" ;Routine for making the Amiga mouse pointer visible

*
* These tags are used for communication between ShapeShifter and the driver
* (including SHEV_Level)
*

SHEV_Context		= TAG_USER+"CON" ;Context for storing local variables
SHEV_ScreenX		= TAG_USER+"SCX" ;Width of screen
SHEV_ScreenY		= TAG_USER+"SCY" ;Height of screen
SHEV_DisplayID		= TAG_USER+"DID" ;DisplayID
SHEV_OverscanType	= TAG_USER+"OVS" ;Overscan type
SHEV_VideoMode		= TAG_USER+"VMD" ;Video mode (see below)
SHEV_Screen		= TAG_USER+"SCR" ;Pointer to Intuition screen
SHEV_ScreenBase		= TAG_USER+"BAS" ;Pointer to base of display memory
SHEV_BytesPerRow	= TAG_USER+"MOD" ;Bytes per row of Mac screen
SHEV_RefreshType	= TAG_USER+"RTY" ;Refresh type (see below)
SHEV_ColorTable		= TAG_USER+"RGB" ;Pointer to color table
SHEV_Flags		= TAG_USER+"FLG" ;Special flags (see below)

*
* Video modes
*

VMODE_1BIT	= 0	;1 bit per pixel, indexed
VMODE_2BIT	= 1	;2 bits per pixel, indexed
VMODE_4BIT	= 2	;4 bits per pixel, indexed
VMODE_8BIT	= 3	;8 bits per pixel, indexed
VMODE_15BIT	= 4	;16 bits per pixel (15 used), direct
VMODE_24BIT	= 5	;32 bits per pixel (24 used), direct

*
* Refresh types
*

RTYPE_NONE	= 0	;No refresh required, SHEV_ScreenBase is displayed
RTYPE_CUSTOM	= 1	;Refresh required, SHEV_Refresh is provided,
			; SHEV_ScreenBase is the Mac screen buffer

			;Refresh required, SHEV_(Un)LockDisplay are provided
			; SHEV_ScreenBase is the Amiga screen buffer
RTYPE_RGB15PC	= 2	;GGGBBBBBxRRRRRGG
RTYPE_BGR15PC	= 3	;GGGRRRRRxBBBBBGG
RTYPE_RGB16PC	= 4	;GGxBBBBBRRRRRGGG
RTYPE_RGB24	= 5	;RGB
RTYPE_BGR24	= 6	;BGR
RTYPE_RGBA32	= 7	;RGBx
RTYPE_BGRA32	= 8	;BGRx

*
* Special flags
*

	BITDEF	SHEV,DblWidthWin,0	;ShapeShifter must open a window of double width

	ENDC	;SHAPE_EXTVIDEO_I
