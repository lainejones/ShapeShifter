**
** MacEmulTabs.asm - tabbed settings window
**
** Replaces the old main window (a column of buttons that each opened its own
** settings window) with one window: a row of tabs, the selected page below it
** and Start / Save / Exit at the bottom. The pages are the GadToolsBox layouts
** from MacEmulGUI.s, attached to this window with AddGList when their tab is
** selected and removed again with RemoveGList. While a page is attached its
** window variable (GraphicsWnd, ...) points at this window, so the existing
** Set/Get/Ghost code in MacEmulPrefs.asm works unchanged.
**
** The tabs are drawn by hand so that this works on every OS version
** ShapeShifter supports (2.04+), without ReAction's clicktab.gadget.
**

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"exec/execbase.i"
		INCLUDE	"graphics/rastport.i"
		INCLUDE	"graphics/text.i"
		INCLUDE	"intuition/intuition.i"
		INCLUDE	"intuition/screens.i"
		INCLUDE	"libraries/gadtools.i"
		INCLUDE	"utility/tagitem.i"
		INCLUDE	"dos/dos.i"
		INCLUDE	"workbench/workbench.i"
		INCLUDE	"workbench/startup.i"
		INCLUDE	"macros.i"
CATCOMP_NUMBERS	= 1
		INCLUDE	"Strings.i"

		XDEF	OpenTabWindow
		XDEF	CloseTabWindow
		XDEF	SwitchTab
		XDEF	NextTab
		XDEF	TabClick
		XDEF	AttachPage
		XDEF	DetachPage
		XDEF	CurTab
		XDEF	OpenCPUWnd
		XDEF	CloseCPUWnd
		XDEF	CPUGadget
		XDEF	SetCPUGads
		XDEF	ConfigGadget
		XREF	LoadConfig
		XREF	SetPathField
		XREF	SaveConfigAs
		XREF	ShowConfig,ReadConfig,SuggestDefaults
		XREF	OptAdvanced
		XREF	PrefsName
		XDEF	PageVolumesX
		XDEF	AppSigSet
		XDEF	HandleAppMsgs
		XDEF	PrepVolumesX
		XDEF	SetVolumesXGads
		XDEF	GetVolumesXGads
		XDEF	VolXGadgets
		XDEF	CfgDefP,CfgAdvP
		XDEF	CfgLabelP,CfgSaveP,CPUTabLabelP,CPUFPUP,CPUNoFPUP,CPUMMUP,CPUNoMMUP
		XDEF	CPUNGads		;(MacEmulLoc)
		XREF	SReq
		XREF	GetString
		XREF	TheLocale
		XREF	PrefsNameTab
		XREF	PrefsDefName
		XREF	VolumesNGads
		XREF	AFDFileName3
		XREF	AFDFileName4
		XREF	SharedDrawer

		XREF	_IntuitionBase
		XREF	_GadToolsBase
		XREF	_GfxBase
		XREF	_UtilityBase
		XREF	_SysBase

		XREF	Scr
		XREF	VisualInfo
		XREF	Font
		XREF	FontY
		XREF	OffX
		XREF	OffY
		XREF	getImage
		XREF	ComputeFont
		XREF	ComputeX
		XREF	ComputeY
		XREF	SettingsWnd
		XREF	SettingsGList
		XREF	SettingsMenus
		XREF	SettingsGadgets
		XREF	SettingsNGads
		XREF	SettingsGTags
		XREF	SettingsWindowTags
		XREF	SettingsNewMenu0
		XREF	MTags0
		XREF	MTags1
		XREF	PageDescs
		XREF	CloseSettingsWindow
		XREF	HasFPU
		XREF	HasMMU
		XREF	OptNoCopyBack
		XREF	OptRemap8K
		XREF	OptEnforcer
		XREF	OptUSKeyMap
		XREF	OptNoQDAccel
		XREF	Opt720K
		XREF	OptDebug
		XREF	OptDepthSwitch
		XREF	NoCopyBack
		XREF	Remap8K
		XREF	EnforcerCompat
		XREF	USKeyMap
		XREF	NoQDAccel
		XREF	Kludge720K
		XREF	DebugMode
		XREF	DepthSwitch

		XREF	TabFuncs		;MacEmulPrefs: Open/Close routine per tab
		XREF	TabLabelGDX		;MacEmulPrefs: gadget whose label names the tab

; Page descriptor (built in MacEmulGUI.s, one per settings page)
pd_NGads	EQU	0	;NewGadget array
pd_GTypes	EQU	4	;gadget kinds
pd_GTags	EQU	8	;tag lists
pd_Gadgets	EQU	12	;gadget pointer array
pd_GList	EQU	16	;-> gadget list variable
pd_Wnd		EQU	20	;-> window variable
pd_Width	EQU	24	;-> design width (word)
pd_Height	EQU	28	;-> design height (word)
pd_Count	EQU	32	;number of gadgets (word)
pd_Next		EQU	36	;another descriptor attached with this one, or 0
pd_SIZEOF	EQU	40

NUMPAGES	EQU	8
NUMTABS		EQU	9
LABELMAX	EQU	32	;bytes per stripped tab label

TABSCALEMIN	EQU	176	;Rows are 18 lines apart as designed: not closer than 12
TABPADMAX	EQU	8	;horizontal padding in a tab (pixels)

GetPen		MACRO	;Pen index -> d0
		move.l	TabDri,a0
		move.l	dri_Pens(a0),a0
		move.w	\1*2(a0),d0
		ENDM

		SECTION	"CODE",CODE

**
** Open the tabbed window. Called instead of OpenSettingsWindow, after
** SetupScreen. d0 = 0 on success.
**
OpenTabWindow	movem.l	d2-d7/a2-a6,-(sp)

; Largest page = size of the page area (design units)
		lea	PageDescs,a2
		moveq	#0,d4
		moveq	#0,d5
		moveq	#NUMPAGES-1,d6
1$		move.l	pd_Width(a2),a0
		cmp.w	(a0),d4
		bhs	2$
		move.w	(a0),d4
2$		move.l	pd_Height(a2),a0
		cmp.w	(a0),d5
		bhs	3$
		move.w	(a0),d5
3$		lea	pd_SIZEOF(a2),a2
		dbra	d6,1$
		move.w	d4,MaxPageW
		move.w	d5,MaxPageH

; Whole window in design units, so ComputeFont can fall back to topaz
		addq.w	#8,d4
		move.w	d4,TabDesignW
		add.w	#62,d5			;tabs, frame, configuration row, buttons
		move.w	d5,TabDesignH
		bsr	TabComputeFont

; Layout in pixels
		move.w	FontY,d0		;Tab row
		addq.w	#6,d0
		move.w	d0,TabH
		move.w	OffY,d0
		addq.w	#3,d0
		move.w	d0,TabY0
		add.w	TabH,d0
		move.w	d0,FrameY		;Frame top = tab baseline
		addq.w	#2,d0
		move.w	d0,PageOrgY		;Page gadgets are placed from here
		move.w	OffX,d0
		addq.w	#2,d0
		move.w	d0,FrameX
		addq.w	#2,d0
		move.w	d0,PageOrgX

		moveq	#0,d0
		move.w	MaxPageW,d0
		jsr	ComputeX
		addq.w	#4,d0
		move.l	Scr,a0			;Not wider than the screen
		move.w	sc_Width(a0),d1
		sub.w	FrameX,d1
		subq.w	#2,d1
		move.b	sc_WBorRight(a0),d2
		ext.w	d2
		sub.w	d2,d1
		cmp.w	d1,d0
		bls	14$
		move.w	d1,d0
14$		move.w	d0,FrameW
		moveq	#0,d0
		move.w	MaxPageH,d0
		jsr	ComputeY
		addq.w	#4,d0
		move.w	d0,FrameH

		moveq	#14,d0
		jsr	ComputeY
		move.w	d0,ButtonH

; Too tall for the screen (640x256, 640x200)? Then squeeze the page: rows move
; closer together, gadgets keep at least the height a line of text needs
		move.w	#256,TabScale
		move.l	Scr,a0
		move.w	FrameY,d0
		add.w	FrameH,d0
		add.w	ButtonH,d0
		add.w	ButtonH,d0
		add.w	#12,d0
		move.b	sc_WBorBottom(a0),d1
		ext.w	d1
		add.w	d1,d0			;d0: window height as designed
		sub.w	sc_Height(a0),d0	;d0: lines too many
		ble	21$
		move.w	#TABSCALEMIN,d2
		moveq	#0,d1
		move.w	FrameH,d1
		sub.w	d0,d1			;d1: page height that fits
		ble	20$
		lsl.l	#8,d1
		divu	FrameH,d1
		cmp.w	d2,d1
		bls	20$
		move.w	d1,d2
20$		move.w	d2,TabScale
		mulu	FrameH,d2
		lsr.l	#8,d2
		move.w	d2,FrameH
21$
		move.w	FrameY,d0		;Configuration row below the frame,
		add.w	FrameH,d0		; then the buttons
		addq.w	#4,d0
		move.w	d0,ConfigY
		add.w	ButtonH,d0
		addq.w	#4,d0
		move.w	d0,ButtonY
		move.l	#122,d0
		jsr	ComputeX
		move.w	d0,ButtonW

; Start / Exit / Save gadgets (SettingsNGads 0..2), the tab buttons are not created
		lea	SettingsGadgets,a0
		moveq	#11-1,d0
4$		clr.l	(a0)+
		dbra	d0,4$

		move.l	_GadToolsBase,a6
		lea	SettingsGList,a0
		JSRLIB	CreateContext
		move.l	d0,a3
		tst.l	d0
		beq	OTWError

		lea	SettingsGTags,a4
		moveq	#0,d3
5$		move.l	_SysBase,a6
		lea	SettingsNGads,a0
		move.l	d3,d0
		mulu	#gng_SIZEOF,d0
		add.l	d0,a0
		lea	TabNewGad,a1
		moveq	#gng_SIZEOF,d0
		JSRLIB	CopyMem
		lea	TabNewGad,a0
		move.l	VisualInfo,gng_VisualInfo(a0)
		move.l	Font,gng_TextAttr(a0)
		move.w	ButtonY,gng_TopEdge(a0)
		move.w	ButtonW,gng_Width(a0)
		move.w	ButtonH,gng_Height(a0)
		move.w	FrameX,d0		;0: Start at the left
		cmp.w	#1,d3
		bne	6$
		add.w	FrameW,d0		;1: Exit at the right
		sub.w	ButtonW,d0
		bra	7$
6$		cmp.w	#2,d3
		bne	7$
		move.w	FrameW,d1		;2: Save in the middle
		sub.w	ButtonW,d1
		lsr.w	#1,d1
		add.w	d1,d0
7$		move.w	d0,gng_LeftEdge(a0)

		move.l	_GadToolsBase,a6
		moveq	#BUTTON_KIND,d0
		move.l	a3,a0
		lea	TabNewGad,a1
		move.l	a4,a2
		JSRLIB	CreateGadgetA
		tst.l	d0
		beq	OTWError
		move.l	d0,a3
		lea	SettingsGadgets,a0
		move.l	d3,d0
		lsl.l	#2,d0
		move.l	a3,(a0,d0.l)
8$		tst.l	(a4)			;Next tag list
		beq	9$
		addq.l	#8,a4
		bra	8$
9$		addq.l	#4,a4
		addq.w	#1,d3
		cmp.w	#3,d3
		blo	5$

		bsr	ScanConfigs		;Configuration cycle + "Save as..."
		lea	TabNewGad,a0
		move.l	VisualInfo,gng_VisualInfo(a0)
		move.l	Font,gng_TextAttr(a0)
		move.w	ConfigY,gng_TopEdge(a0)
		move.w	ButtonH,gng_Height(a0)
		move.w	FrameX,d0		;Save as: at the right
		add.w	FrameW,d0
		sub.w	ButtonW,d0
		move.w	d0,gng_LeftEdge(a0)
		move.w	ButtonW,gng_Width(a0)
		move.l	CfgSaveP,gng_GadgetText(a0)
		move.w	#GD_CfgSaveAs,gng_GadgetID(a0)
		move.l	#PLACETEXT_IN,gng_Flags(a0)
		move.l	_GadToolsBase,a6
		moveq	#BUTTON_KIND,d0
		move.l	a3,a0
		lea	TabNewGad,a1
		lea	NoTags,a2
		JSRLIB	CreateGadgetA
		tst.l	d0
		beq	OTWError
		move.l	d0,a3
; "Defaults": in the bottom row, between Start and Save
		lea	TabNewGad,a0
		move.w	ButtonY,gng_TopEdge(a0)
		move.w	FrameW,d0
		sub.w	ButtonW,d0
		lsr.w	#1,d0			;where Save starts, from FrameX
		sub.w	ButtonW,d0		;the gap between Start and Save
		sub.w	ButtonW,d0		;what is left of it beside the button
		bpl	29$
		moveq	#0,d0
29$		lsr.w	#1,d0
		add.w	ButtonW,d0
		add.w	FrameX,d0
		move.w	d0,gng_LeftEdge(a0)
		move.l	CfgDefP,gng_GadgetText(a0)
		move.w	#GD_CfgDefaults,gng_GadgetID(a0)
		move.l	_GadToolsBase,a6
		moveq	#BUTTON_KIND,d0
		move.l	a3,a0
		lea	TabNewGad,a1
		lea	NoTags,a2
		JSRLIB	CreateGadgetA
		tst.l	d0
		beq	OTWError
		move.l	d0,a3
; "Advanced": a checkbox right of Save
		lea	TabNewGad,a0
		move.w	FrameW,d0
		sub.w	ButtonW,d0
		lsr.w	#1,d0
		add.w	ButtonW,d0
		add.w	FrameX,d0
		addq.w	#8,d0
		move.w	d0,gng_LeftEdge(a0)
		move.w	#26,gng_Width(a0)
		move.l	CfgAdvP,gng_GadgetText(a0)
		move.w	#GD_CfgAdvanced,gng_GadgetID(a0)
		move.l	#PLACETEXT_RIGHT,gng_Flags(a0)
		moveq	#0,d0
		tst.w	OptAdvanced
		sne	d0
		and.l	#1,d0
		move.l	d0,CfgAdvTags+4
		move.l	_GadToolsBase,a6
		moveq	#CHECKBOX_KIND,d0
		move.l	a3,a0
		lea	TabNewGad,a1
		lea	CfgAdvTags,a2
		JSRLIB	CreateGadgetA
		tst.l	d0
		beq	OTWError
		move.l	d0,a3
		move.l	d0,CfgAdvGad
		lea	TabNewGad,a0
		move.w	ButtonW,gng_Width(a0)
		move.l	#PLACETEXT_IN,gng_Flags(a0)
		lea	TabNewGad,a0		;(the cycle below is in the row above)
		move.w	ConfigY,gng_TopEdge(a0)
		lea	TabNewGad,a0		;Cycle: from after its label to Save as
		move.l	#140,d0
		jsr	ComputeX
		add.w	FrameX,d0
		move.w	d0,gng_LeftEdge(a0)
		move.w	FrameX,d1
		add.w	FrameW,d1
		sub.w	ButtonW,d1
		subq.w	#8,d1
		sub.w	d0,d1
		move.w	d1,gng_Width(a0)
		move.l	CfgLabelP,gng_GadgetText(a0)
		move.w	#GD_CfgCycle,gng_GadgetID(a0)
		move.l	#PLACETEXT_LEFT,gng_Flags(a0)
		move.l	CfgLabelPtr,CfgCycTags+4
		moveq	#0,d0
		move.w	CfgActive,d0
		move.l	d0,CfgCycTags+12
		moveq	#CYCLE_KIND,d0
		move.l	a3,a0
		lea	TabNewGad,a1
		lea	CfgCycTags,a2
		JSRLIB	CreateGadgetA
		move.l	d0,CfgCycle
		beq	OTWError
		move.l	d0,a3

; Menus as in the generated window
		move.l	_GadToolsBase,a6
		lea	SettingsNewMenu0,a0
		lea	MTags0,a1
		JSRLIB	CreateMenusA
		move.l	d0,SettingsMenus
		beq	OTWError
		move.l	d0,a0
		move.l	VisualInfo,a1
		lea	MTags1,a2
		JSRLIB	LayoutMenusA

; Window size and position
		move.l	Scr,a2
		move.w	FrameX,d0
		add.w	FrameW,d0
		addq.w	#2,d0
		move.b	sc_WBorRight(a2),d1
		ext.w	d1
		add.w	d1,d0
		ext.l	d0
		move.l	d0,TWWidth+4
		move.w	sc_Width(a2),d1
		sub.w	d0,d1
		bpl	10$
		moveq	#0,d1
10$		lsr.w	#1,d1
		ext.l	d1
		move.l	d1,TWLeft+4

		move.w	ButtonY,d0
		add.w	ButtonH,d0
		addq.w	#4,d0
		move.b	sc_WBorBottom(a2),d1
		ext.w	d1
		add.w	d1,d0
		ext.l	d0
		move.l	d0,TWHeight+4
		moveq	#0,d1
		move.b	sc_BarHeight(a2),d1
		addq.w	#1,d1
		move.w	sc_Height(a2),d2	;Below the screen title if there is room
		sub.w	d0,d2
		bpl	16$
		moveq	#0,d2
16$		cmp.w	d2,d1
		bls	17$
		move.w	d2,d1
17$		move.l	d1,TWTop+4

		move.l	SettingsGList,TWGadgets+4
		move.l	a2,TWScreen+4

		move.l	_UtilityBase,a6		;Localized titles of the old window
		move.l	#WA_Title,d0
		lea	SettingsWindowTags,a0
		JSRLIB	FindTagItem
		tst.l	d0
		beq	11$
		move.l	d0,a0
		move.l	ti_Data(a0),TWTitle+4
11$		move.l	#WA_ScreenTitle,d0
		lea	SettingsWindowTags,a0
		JSRLIB	FindTagItem
		tst.l	d0
		beq	12$
		move.l	d0,a0
		move.l	ti_Data(a0),TWScrTitle+4
12$
		move.l	_IntuitionBase,a6
		sub.l	a0,a0
		lea	TabWindowTags,a1
		JSRLIB	OpenWindowTagList
		move.l	d0,SettingsWnd
		beq	OTWError

		move.l	d0,a0
		move.l	SettingsMenus,a1
		JSRLIB	SetMenuStrip

		cmp.w	#39,LIB_VERSION(a6)	;Gadget help (one line in the title)
		blo	15$
		move.l	SettingsWnd,a0
		moveq	#HC_GADGETHELP,d0
		JSRLIB	HelpControl
15$

		move.l	Scr,a0
		JSRLIB	GetScreenDrawInfo
		move.l	d0,TabDri
		beq	OTWError

		move.l	_GfxBase,a6		;Tab labels in the gadget font
		move.l	Font,a0
		JSRLIB	OpenFont
		move.l	d0,TabFont
		beq	13$
		move.l	SettingsWnd,a1
		move.l	wd_RPort(a1),a1
		move.l	d0,a0
		JSRLIB	SetFont
13$
		move.l	_GadToolsBase,a6
		move.l	SettingsWnd,a0
		sub.l	a1,a1
		JSRLIB	GT_RefreshWindow

		bsr	LayoutTabs
		bsr	DrawFrame
		bsr	OpenAppWindow		;Disk images can be dropped on the window
		move.w	#-1,CurTab
		moveq	#0,d0
		bsr	SwitchTab

		moveq	#0,d0
OTWDone		movem.l	(sp)+,d2-d7/a2-a6
		rts

OTWError	bsr	CloseTabWindow
		moveq	#4,d0
		bra	OTWDone


**
** Close the tabbed window (pages must already be detached)
**
CloseTabWindow	movem.l	d0-d1/a0-a1/a6,-(sp)
		bsr	CloseAppWindow
		jsr	CloseSettingsWindow
		move.l	_GfxBase,a6
		move.l	TabFont,d0
		beq	1$
		move.l	d0,a1
		JSRLIB	CloseFont
		clr.l	TabFont
1$		move.l	_IntuitionBase,a6
		move.l	TabDri,d0
		beq	2$
		move.l	Scr,a0
		move.l	d0,a1
		JSRLIB	FreeScreenDrawInfo
		clr.l	TabDri
2$		movem.l	(sp)+,d0-d1/a0-a1/a6
		rts


**
** ComputeFont for the whole tab window
**
TabComputeFont	movem.l	d0-d3/a0-a1,-(sp)
		moveq	#0,d2
		moveq	#0,d3
		move.w	TabDesignW,d2
		move.w	TabDesignH,d3
		jsr	ComputeFont
		movem.l	(sp)+,d0-d3/a0-a1
		rts


**
** Select a tab. d0.w = tab number (0..NUMTABS-1)
**
SwitchTab	movem.l	d0-d7/a0-a6,-(sp)
		move.w	d0,d7
		bsr	TabIsHidden		;(a shortcut key for a page that is not on show)
		bne	3$
		cmp.w	CurTab,d7
		beq	3$
		tst.l	SettingsWnd
		beq	3$

		move.w	CurTab,d0		;Detach the current page
		bmi	1$
		lea	TabFuncs,a0
		lsl.w	#3,d0
		move.l	4(a0,d0.w),a0
		jsr	(a0)

1$		move.w	d7,CurTab
		bsr	ClearPage
		bsr	DrawTabs

		move.w	d7,d0			;Attach the new one
		lea	TabFuncs,a0
		lsl.w	#3,d0
		move.l	(a0,d0.w),a0
		jsr	(a0)
3$		movem.l	(sp)+,d0-d7/a0-a6
		rts

; Next tab (Tab key)
NextTab		move.w	CurTab,d0
2$		addq.w	#1,d0
		cmp.w	#NUMTABS,d0
		blo	1$
		moveq	#0,d0
1$		bsr	TabIsHidden
		bne	2$
		bra	SwitchTab

; Is page d0.w left out of the simple view? Z set: it is shown.
; Without "Advanced" the window has the four pages everybody needs:
; Graphics, Volumes/Disks, Memory and Network. Floppys, SCSI, Serial,
; Miscellaneous and CPU keep their settings and are just not on show.
TabIsHidden	movem.l	d0/a0,-(sp)
		tst.w	OptAdvanced
		bne	1$
		and.w	#15,d0
		lea	SimpleHide(pc),a0
		tst.b	(a0,d0.w)
		movem.l	(sp)+,d0/a0
		rts
1$		movem.l	(sp)+,d0/a0
		cmp.w	d0,d0			;Z set
		rts
SimpleHide	dc.b	0,0,1,1,0,1,0,1,1,0,0,0,0,0,0,0
		EVEN

; "Advanced" was switched, or other settings were loaded: tabs anew, and
; away from a page that is no longer on show
ApplyAdvanced	movem.l	d0-d1/a0-a3/a6,-(sp)
		tst.l	SettingsWnd
		beq	9$
		move.l	CfgAdvGad,d0		;The checkbox follows the setting
		beq	1$
		move.l	d0,a0
		moveq	#0,d0
		tst.w	OptAdvanced
		sne	d0
		and.l	#1,d0
		move.l	d0,CfgAdvTags+4
		move.l	SettingsWnd,a1
		sub.l	a2,a2
		lea	CfgAdvTags,a3
		move.l	_GadToolsBase,a6
		JSRLIB	GT_SetGadgetAttrsA
1$		bsr	LayoutTabs
		move.w	CurTab,d0
		bmi	2$
		bsr	TabIsHidden
		beq	2$
		moveq	#0,d0
		bsr	SwitchTab		;(draws the tabs)
		bra	9$
2$		bsr	DrawTabs
9$		movem.l	(sp)+,d0-d1/a0-a3/a6
		rts


**
** Mouse button pressed at d0.w/d1.w (window coordinates): select the tab there
**
TabClick	movem.l	d0-d3/a0,-(sp)
		cmp.w	TabY0,d1
		blt	9$
		cmp.w	FrameY,d1
		bgt	9$
		lea	TabX,a0
		moveq	#0,d2
1$		move.w	(a0),d3
		cmp.w	d3,d0
		blt	2$
		add.w	TabW-TabX(a0),d3
		cmp.w	d3,d0
		bge	2$
		move.w	d2,d0
		bsr	SwitchTab
		bra	9$
2$		addq.l	#2,a0
		addq.w	#1,d2
		cmp.w	#NUMTABS,d2
		blo	1$
9$		movem.l	(sp)+,d0-d3/a0
		rts


**
** Tab labels and widths. The labels are the localized texts of the old
** "Graphics...", "Memory... (p)" buttons without '_' and from the first '.'
**
LayoutTabs	movem.l	d2-d7/a2-a6,-(sp)
		moveq	#0,d6			;d6: sum of text widths
		moveq	#0,d7			;d7: tab number
1$		lea	TabLabelGDX,a0		;Source text
		move.w	d7,d0
		add.w	d0,d0
		move.w	(a0,d0.w),d0
		bpl	15$
		move.l	CPUTabLabelP,a0	;Not one of the old buttons
		bra	16$
15$		mulu	#gng_SIZEOF,d0
		lea	SettingsNGads,a0
		move.l	gng_GadgetText(a0,d0.l),a0
16$
		lea	TabLabels,a1		;Destination
		move.w	d7,d0
		mulu	#LABELMAX,d0
		add.l	d0,a1
		move.l	a1,a2
		moveq	#0,d2			;d2: length
		move.l	a0,d0
		beq	4$
2$		move.b	(a0)+,d0
		beq	4$
		cmp.b	#'.',d0
		beq	4$
		cmp.b	#'(',d0
		beq	4$
		cmp.b	#'_',d0
		beq	2$
		cmp.w	#LABELMAX-1,d2
		bhs	4$
		move.b	d0,(a1)+
		addq.w	#1,d2
		bra	2$
4$		tst.w	d2			;Trailing blanks off
		beq	5$
		cmp.b	#' ',-1(a1)
		bne	5$
		subq.l	#1,a1
		subq.w	#1,d2
		bra	4$
5$		clr.b	(a1)
		move.w	d7,d0
		bsr	TabIsHidden
		beq	51$
		moveq	#0,d2			;Not on show
		clr.b	(a2)
51$		lea	TabLen,a0
		move.w	d7,d0
		add.w	d0,d0
		move.w	d2,(a0,d0.w)

		move.l	_GfxBase,a6		;Text width
		move.l	SettingsWnd,a1
		move.l	wd_RPort(a1),a1
		move.l	a2,a0
		moveq	#0,d0
		move.w	d2,d0
		JSRLIB	TextLength
		lea	TabTW,a0
		move.w	d7,d1
		add.w	d1,d1
		move.w	d0,(a0,d1.w)
		add.w	d0,d6
		addq.w	#1,d7
		cmp.w	#NUMTABS,d7
		blo	1$

; Padding: up to TABPADMAX on each side, less if the window is narrow
		move.w	FrameW,d5
		subq.w	#4,d5			;d5: room for the tabs
		move.w	d5,d0
		sub.w	d6,d0
		bmi	6$
		ext.l	d0
		divu	#NUMTABS*2,d0
		cmp.w	#TABPADMAX,d0
		bls	7$
		moveq	#TABPADMAX,d0
		bra	7$
6$		moveq	#0,d0
7$		cmp.w	#2,d0
		bhs	8$
		moveq	#2,d0
8$		move.w	d0,TabPad

; Labels that still do not fit: the widest one loses a character, again
; and again until everything fits, so short labels keep their room
		move.w	TabPad,d4
		mulu	#NUMTABS*2,d4		;d4: all the padding
9$		move.w	d6,d0
		add.w	d4,d0
		cmp.w	d5,d0
		bls	12$			;Everything fits
		moveq	#0,d7			;d3: the widest tab
		moveq	#0,d3
		moveq	#-1,d2
		lea	TabTW,a0
91$		move.w	(a0)+,d0
		cmp.w	d2,d0
		ble	92$
		move.w	d0,d2
		move.w	d7,d3
92$		addq.w	#1,d7
		cmp.w	#NUMTABS,d7
		blo	91$
		lea	TabLen,a0		;One character less
		move.w	d3,d0
		add.w	d0,d0
		subq.w	#1,(a0,d0.w)
		ble	12$			;(nothing left to take)
		move.w	(a0,d0.w),d2
		lea	TabLabels,a0
		move.w	d3,d0
		mulu	#LABELMAX,d0
		add.l	d0,a0
		move.l	_GfxBase,a6
		move.l	SettingsWnd,a1
		move.l	wd_RPort(a1),a1
		moveq	#0,d0
		move.w	d2,d0
		JSRLIB	TextLength
		lea	TabTW,a0
		move.w	d3,d1
		add.w	d1,d1
		sub.w	(a0,d1.w),d6		;Sum: old width out, new one in
		add.w	d0,d6
		move.w	d0,(a0,d1.w)
		bra	9$

; Positions
12$		move.w	FrameX,d0
		addq.w	#2,d0
		moveq	#0,d7
13$		lea	TabX,a0
		move.w	d7,d1
		add.w	d1,d1
		move.w	d0,(a0,d1.w)
		lea	TabTW,a0
		move.w	(a0,d1.w),d2
		add.w	TabPad,d2
		add.w	TabPad,d2
		move.w	d0,d3
		move.w	d7,d0
		bsr	TabIsHidden
		beq	131$
		moveq	#0,d2			;Not on show: no room, no clicks
131$		move.w	d3,d0
		lea	TabW,a0
		move.w	d2,(a0,d1.w)
		add.w	d2,d0
		addq.w	#1,d7
		cmp.w	#NUMTABS,d7
		blo	13$
		movem.l	(sp)+,d2-d7/a2-a6
		rts


**
** Draw the page frame (its top edge is the line the tabs stand on)
**
DrawFrame	movem.l	d0-d7/a0-a6,-(sp)
		move.l	SettingsWnd,a0
		move.l	wd_RPort(a0),a5
		move.l	_GfxBase,a6
		move.w	FrameX,d4		;d4/d5: left/top
		move.w	FrameY,d5
		move.w	d4,d6
		add.w	FrameW,d6
		subq.w	#1,d6			;d6/d7: right/bottom
		move.w	d5,d7
		add.w	FrameH,d7
		subq.w	#1,d7

		GetPen	SHINEPEN
		move.l	a5,a1
		JSRLIB	SetAPen
		move.l	a5,a1
		move.w	d4,d0
		move.w	d7,d1
		JSRLIB	Move
		move.l	a5,a1
		move.w	d4,d0
		move.w	d5,d1
		JSRLIB	Draw
		move.l	a5,a1
		move.w	d6,d0
		move.w	d5,d1
		JSRLIB	Draw

		GetPen	SHADOWPEN
		move.l	a5,a1
		JSRLIB	SetAPen
		move.l	a5,a1
		move.w	d6,d0
		move.w	d5,d1
		addq.w	#1,d1
		JSRLIB	Move
		move.l	a5,a1
		move.w	d6,d0
		move.w	d7,d1
		JSRLIB	Draw
		move.l	a5,a1
		move.w	d4,d0
		addq.w	#1,d0
		move.w	d7,d1
		JSRLIB	Draw
		movem.l	(sp)+,d0-d7/a0-a6
		rts


**
** Clear the inside of the page frame
**
ClearPage	movem.l	d0-d3/a0-a1/a6,-(sp)
		move.l	_GfxBase,a6
		GetPen	BACKGROUNDPEN
		move.l	SettingsWnd,a1
		move.l	wd_RPort(a1),a1
		JSRLIB	SetAPen
		move.l	SettingsWnd,a1
		move.l	wd_RPort(a1),a1
		move.w	FrameX,d0
		addq.w	#1,d0
		move.w	FrameY,d1
		addq.w	#1,d1
		move.w	FrameX,d2
		add.w	FrameW,d2
		subq.w	#2,d2
		move.w	FrameY,d3
		add.w	FrameH,d3
		subq.w	#2,d3
		ext.l	d0
		ext.l	d1
		ext.l	d2
		ext.l	d3
		JSRLIB	RectFill
		movem.l	(sp)+,d0-d3/a0-a1/a6
		rts


**
** Draw all tabs; CurTab is drawn raised and open towards the page
**
DrawTabs	movem.l	d0-d7/a0-a6,-(sp)
		move.l	SettingsWnd,a0
		move.l	wd_RPort(a0),a5
		move.l	_GfxBase,a6

		move.l	a5,a1			;Clear the tab row
		GetPen	BACKGROUNDPEN
		move.l	a5,a1
		JSRLIB	SetAPen
		move.l	a5,a1
		move.w	FrameX,d0
		move.w	TabY0,d1
		move.w	FrameX,d2
		add.w	FrameW,d2
		subq.w	#1,d2
		move.w	FrameY,d3
		subq.w	#1,d3
		ext.l	d0
		ext.l	d1
		ext.l	d2
		ext.l	d3
		JSRLIB	RectFill

		GetPen	SHINEPEN		;Frame top line again (tabs cut into it)
		move.l	a5,a1
		JSRLIB	SetAPen
		move.l	a5,a1
		move.w	FrameX,d0
		move.w	FrameY,d1
		JSRLIB	Move
		move.l	a5,a1
		move.w	FrameX,d0
		add.w	FrameW,d0
		subq.w	#1,d0
		move.w	FrameY,d1
		JSRLIB	Draw

		move.l	a5,a1
		moveq	#RP_JAM1,d0
		JSRLIB	SetDrMd

		moveq	#0,d7			;d7: tab number
1$		move.w	d7,d0
		add.w	d0,d0
		lea	TabX,a0
		move.w	(a0,d0.w),d4		;d4: left
		lea	TabW,a0
		move.w	(a0,d0.w),d6
		beq	7$			;(not on show)
		add.w	d4,d6
		subq.w	#1,d6			;d6: right
		move.w	TabY0,d5		;d5: top
		cmp.w	CurTab,d7
		beq	2$
		addq.w	#2,d5			;Unselected tabs are lower

2$		GetPen	SHINEPEN		;Left and top edge
		move.l	a5,a1
		JSRLIB	SetAPen
		move.l	a5,a1
		move.w	d4,d0
		move.w	FrameY,d1
		JSRLIB	Move
		move.l	a5,a1
		move.w	d4,d0
		move.w	d5,d1
		addq.w	#1,d1
		JSRLIB	Draw
		move.l	a5,a1
		move.w	d4,d0
		addq.w	#1,d0
		move.w	d5,d1
		JSRLIB	Draw
		move.l	a5,a1
		move.w	d6,d0
		subq.w	#1,d0
		move.w	d5,d1
		JSRLIB	Draw

		GetPen	SHADOWPEN		;Right edge
		move.l	a5,a1
		JSRLIB	SetAPen
		move.l	a5,a1
		move.w	d6,d0
		move.w	d5,d1
		addq.w	#1,d1
		JSRLIB	Move
		move.l	a5,a1
		move.w	d6,d0
		move.w	FrameY,d1
		cmp.w	CurTab,d7
		beq	3$
		subq.w	#1,d1
3$		JSRLIB	Draw

		cmp.w	CurTab,d7		;Selected: open towards the page
		bne	4$
		GetPen	BACKGROUNDPEN
		move.l	a5,a1
		JSRLIB	SetAPen
		move.l	a5,a1
		move.w	d4,d0
		addq.w	#1,d0
		move.w	FrameY,d1
		JSRLIB	Move
		move.l	a5,a1
		move.w	d6,d0
		subq.w	#1,d0
		move.w	FrameY,d1
		JSRLIB	Draw

4$		cmp.w	CurTab,d7		;Label
		bne	5$
		GetPen	HIGHLIGHTTEXTPEN
		bra	6$
5$		GetPen	TEXTPEN
6$		move.l	a5,a1
		JSRLIB	SetAPen
		move.l	a5,a1
		move.w	d4,d0
		add.w	TabPad,d0
		move.w	d5,d1
		addq.w	#3,d1
		add.w	rp_TxBaseline(a5),d1
		JSRLIB	Move
		lea	TabLabels,a0
		move.w	d7,d0
		mulu	#LABELMAX,d0
		add.l	d0,a0
		lea	TabLen,a1
		move.w	d7,d0
		add.w	d0,d0
		move.w	(a1,d0.w),d0
		ble	7$
		ext.l	d0
		move.l	a5,a1
		JSRLIB	Text

7$		addq.w	#1,d7
		cmp.w	#NUMTABS,d7
		blo	1$
		movem.l	(sp)+,d0-d7/a0-a6
		rts


**
** Create a page's gadgets and add them to the tab window.
** a0: page descriptor. d0 = 0 on success.
**
AttachPage	movem.l	d1-d7/a1-a6,-(sp)
		move.l	a0,a5
		bsr	TabComputeFont		;Another window may have changed the scaling

		move.l	_GadToolsBase,a6
		move.l	pd_GList(a5),a0
		JSRLIB	CreateContext
		move.l	d0,a3
		tst.l	d0
		beq	APError

		move.l	pd_GTags(a5),a4
		moveq	#0,d3
1$		move.l	_SysBase,a6
		move.l	pd_NGads(a5),a0
		move.l	d3,d0
		mulu	#gng_SIZEOF,d0
		add.l	d0,a0
		lea	TabNewGad,a1
		moveq	#gng_SIZEOF,d0
		JSRLIB	CopyMem
		lea	TabNewGad,a0
		move.l	VisualInfo,gng_VisualInfo(a0)
		move.l	Font,gng_TextAttr(a0)
		moveq	#0,d0
		move.w	gng_LeftEdge(a0),d0
		jsr	ComputeX
		add.w	PageOrgX,d0
		move.w	d0,gng_LeftEdge(a0)
		moveq	#0,d0
		move.w	gng_TopEdge(a0),d0
		jsr	ComputeY
		bsr	SqueezeY
		add.w	PageOrgY,d0
		move.w	d0,gng_TopEdge(a0)
		move.l	pd_GTypes(a5),a1
		move.l	d3,d0
		add.l	d0,d0
		moveq	#0,d2
		move.w	(a1,d0.l),d2		;d2: kind
		cmp.w	#GENERIC_KIND,d2	;"Get" image buttons keep the size of
		beq	5$			; their image, as in the old windows
		moveq	#0,d0
		move.w	gng_Width(a0),d0
		jsr	ComputeX
		move.w	d0,gng_Width(a0)
		moveq	#0,d0
		move.w	gng_Height(a0),d0
		jsr	ComputeY
		cmp.w	#256,TabScale
		beq	6$
		move.w	d0,d4			;d4: height as designed
		bsr	SqueezeY
		move.w	FontY,d5		;At least a line of text and its border,
		addq.w	#4,d5
		cmp.w	d4,d5			; but never taller than designed
		bls	7$
		move.w	d4,d5
7$		cmp.w	d5,d0
		bhs	6$
		move.w	d5,d0
6$		move.w	d0,gng_Height(a0)
5$
		move.l	_GadToolsBase,a6
		move.l	d2,d0
		move.l	a3,a0
		lea	TabNewGad,a1
		move.l	a4,a2
		JSRLIB	CreateGadgetA
		tst.l	d0
		beq	APError
		move.l	d0,a3
		move.l	pd_Gadgets(a5),a0
		move.l	d3,d0
		lsl.l	#2,d0
		move.l	a3,(a0,d0.l)

		cmp.w	#GENERIC_KIND,d2	;"Get" image buttons
		bne	2$
		or.w	#GFLG_GADGIMAGE!GFLG_GADGHIMAGE,gg_Flags(a3)
		or.w	#GACT_RELVERIFY,gg_Activation(a3)
		move.l	getImage,gg_GadgetRender(a3)
		move.l	getImage,gg_SelectRender(a3)

2$		tst.l	(a4)			;Next tag list
		beq	3$
		addq.l	#8,a4
		bra	2$
3$		addq.l	#4,a4
		addq.w	#1,d3
		cmp.w	pd_Count(a5),d3
		blo	1$

; Add to the window
		move.l	_IntuitionBase,a6
		move.l	SettingsWnd,a0
		move.l	pd_GList(a5),a1
		move.l	(a1),a1
		moveq	#-1,d0
		moveq	#-1,d1
		sub.l	a2,a2
		JSRLIB	AddGList
		move.l	pd_GList(a5),a0
		move.l	(a0),a0
		move.l	SettingsWnd,a1
		sub.l	a2,a2
		moveq	#-1,d0
		JSRLIB	RefreshGList
		move.l	_GadToolsBase,a6
		move.l	SettingsWnd,a0
		sub.l	a1,a1
		JSRLIB	GT_RefreshWindow

		move.l	pd_Wnd(a5),a0
		move.l	SettingsWnd,(a0)
		move.l	pd_Next(a5),d0		;More gadgets on the same page?
		beq	4$
		move.l	d0,a0
		bsr	AttachPage
		bra	APDone
4$		moveq	#0,d0
APDone		movem.l	(sp)+,d1-d7/a1-a6
		rts

APError		move.l	_GadToolsBase,a6	;Free what was created
		move.l	pd_GList(a5),a0
		move.l	(a0),d0
		beq	1$
		move.l	d0,a0
		JSRLIB	FreeGadgets
		move.l	pd_GList(a5),a0
		clr.l	(a0)
1$		moveq	#2,d0
		bra	APDone


**
** Vertical squeeze for screens the window does not fit on. d0.w: pixels -> d0.l
**
SqueezeY	and.l	#$ffff,d0
		mulu	TabScale,d0
		lsr.l	#8,d0
		rts


**
** Remove a page's gadgets from the tab window and free them. a0: page descriptor
**
DetachPage	movem.l	d0-d3/a0-a2/a5-a6,-(sp)
		move.l	a0,a5
		move.l	pd_Next(a5),d0		;The chained part first (added last)
		beq	5$
		move.l	d0,a0
		bsr	DetachPage
5$
		move.l	pd_GList(a5),a0
		move.l	(a0),d0
		beq	2$
		move.l	SettingsWnd,d1
		beq	1$
		move.l	_IntuitionBase,a6
		move.l	d1,a0
		move.l	d0,a1
		moveq	#-1,d0
		JSRLIB	RemoveGList
1$		move.l	_GadToolsBase,a6
		move.l	pd_GList(a5),a0
		move.l	(a0),a0
		JSRLIB	FreeGadgets
		move.l	pd_GList(a5),a0
		clr.l	(a0)
		move.l	pd_Gadgets(a5),a0	;No dangling gadget pointers
		move.w	pd_Count(a5),d0
		bra	4$
3$		clr.l	(a0)+
4$		dbra	d0,3$
2$		move.l	pd_Wnd(a5),a0
		clr.l	(a0)
		movem.l	(sp)+,d0-d3/a0-a2/a5-a6
		rts



**
** CPU tab: the start options that used to exist only as tooltypes/arguments.
** A checkbox shows the saved option (OptXXX in the prefs file). An option that
** was also given as a tooltype or argument is shown checked and ghosted.
**
GD_CPUInfo	EQU	900
GD_CPUOpt0	EQU	901
CPU_CNT		EQU	9
NUMCPUOPTS	EQU	8

OpenCPUWnd	lea	PageCPU,a0
		jsr	AttachPage
		tst.l	d0
		beq	SetCPUGads
		rts

CloseCPUWnd	lea	PageCPU,a0
		jmp	DetachPage

; Gadgets from the current settings
SetCPUGads	movem.l	d2-d7/a2-a6,-(sp)
		tst.l	CPUWnd
		beq	9$
		bsr	MakeCPUInfo
		move.l	_GadToolsBase,a6
		move.l	CPUGadgets,a0
		move.l	CPUWnd,a1
		sub.l	a2,a2
		lea	CPUInfoTags,a3
		JSRLIB	GT_SetGadgetAttrsA

		lea	CPUOptTab,a4
		lea	CPUGadgets+4,a5
		moveq	#NUMCPUOPTS-1,d7
1$		moveq	#0,d0			;d0: checked, d1: ghosted
		moveq	#0,d1
		move.l	(a4),a0			;saved option
		tst.w	(a0)
		beq	2$
		moveq	#1,d0
2$		move.l	4(a4),a0		;tooltype / argument
		tst.l	(a0)
		beq	3$
		moveq	#1,d0
		moveq	#1,d1
3$		tst.w	8(a4)			;needs an MMU?
		beq	4$
		tst.b	HasMMU
		bne	4$
		moveq	#1,d1
4$		move.l	d0,CPUCheckTags+4
		move.l	d1,CPUCheckTags+12
		move.l	(a5)+,a0
		move.l	CPUWnd,a1
		sub.l	a2,a2
		lea	CPUCheckTags,a3
		JSRLIB	GT_SetGadgetAttrsA
		lea	12(a4),a4
		dbra	d7,1$
9$		movem.l	(sp)+,d2-d7/a2-a6
		rts

; "68060, FPU, MMU" into CPUInfoBuf
MakeCPUInfo	movem.l	d0-d1/a0-a2/a6,-(sp)
		move.l	_SysBase,a6
		move.w	AttnFlags(a6),d0
		lea	CPU68000Txt,a0
		btst	#AFB_68010,d0
		beq	1$
		lea	CPU68010Txt,a0
1$		btst	#AFB_68020,d0
		beq	2$
		lea	CPU68020Txt,a0
2$		btst	#AFB_68030,d0
		beq	3$
		lea	CPU68030Txt,a0
3$		btst	#AFB_68040,d0
		beq	4$
		lea	CPU68040Txt,a0
4$		btst	#7,d0			;AFB_68060
		beq	5$
		lea	CPU68060Txt,a0
5$		lea	CPUInfoBuf,a1
		bsr	StrCat
		move.l	CPUFPUP,a0
		tst.b	HasFPU
		bne	6$
		move.l	CPUNoFPUP,a0
6$		bsr	StrCat
		move.l	CPUMMUP,a0
		tst.b	HasMMU
		bne	7$
		move.l	CPUNoMMUP,a0
7$		bsr	StrCat
		clr.b	(a1)
		movem.l	(sp)+,d0-d1/a0-a2/a6
		rts

StrCat		move.b	(a0)+,(a1)+		;a0 -> a1, a1 ends on the 0 byte
		bne	StrCat
		subq.l	#1,a1
		rts

; GADGETUP from the CPU page? a0: gadget. d0 = 1 if handled
CPUGadget	movem.l	d1/a0-a1,-(sp)
		moveq	#0,d0
		move.w	gg_GadgetID(a0),d1
		sub.w	#GD_CPUOpt0,d1
		bmi	9$
		cmp.w	#NUMCPUOPTS,d1
		bhs	9$
		mulu	#12,d1
		lea	CPUOptTab,a1
		move.l	(a1,d1.l),a1
		not.w	(a1)
		moveq	#1,d0
9$		movem.l	(sp)+,d1/a0-a1
		rts


**
** Volumes tab: FileDisk 3 and 4, a second gadget list on the Volumes page
** (the GadToolsBox list keeps its numbering). The gadgets' events are
** handled in MacEmulPrefs.asm (GD_GetAFDName3...); the labels are made from
** the localized "FileDisk 1" and "Create..." texts.
**
GD_AFDName3	EQU	930
GD_GetAFDName3	EQU	931
GD_MakeAFD3	EQU	932
GD_AFDName4	EQU	933
GD_GetAFDName4	EQU	934
GD_MakeAFD4	EQU	935
GD_FormatADD1	EQU	936		;"Format..." for the device disks
GD_FormatADD2	EQU	937
GD_SharedDrawer	EQU	938		;"Synced drawer"
VOLX_CNT	EQU	9
VNG_AFDNAME1	EQU	6		;index in VolumesNGads
VNG_MAKEAFD1	EQU	2

PrepVolumesX	movem.l	d0-d1/a0-a3,-(sp)
		lea	VolumesNGads,a0
		move.l	VNG_MAKEAFD1*gng_SIZEOF+gng_GadgetText(a0),d0
		lea	VolXNGads,a1
		move.l	d0,2*gng_SIZEOF+gng_GadgetText(a1)
		move.l	d0,5*gng_SIZEOF+gng_GadgetText(a1)
		move.l	#MSG_FORMATADD_GAD,d0
		lea	TheLocale,a0
		jsr	GetString
		lea	VolXNGads,a1
		move.l	d0,6*gng_SIZEOF+gng_GadgetText(a1)
		move.l	d0,7*gng_SIZEOF+gng_GadgetText(a1)
		move.l	#MSG_SHARED_GAD,d0
		lea	TheLocale,a0
		jsr	GetString
		lea	VolXNGads,a1
		move.l	d0,8*gng_SIZEOF+gng_GadgetText(a1)
		lea	VolumesNGads,a0
		move.l	VNG_AFDNAME1*gng_SIZEOF+gng_GadgetText(a0),a0
		lea	VolXLabel3,a1
		moveq	#'3',d0
		bsr	CopyLabelDigit
		lea	VolumesNGads,a0
		move.l	VNG_AFDNAME1*gng_SIZEOF+gng_GadgetText(a0),a0
		lea	VolXLabel4,a1
		moveq	#'4',d0
		bsr	CopyLabelDigit
		movem.l	(sp)+,d0-d1/a0-a3
		rts

; Copy the label a0 to a1 (at most 31 characters), the last '1' becomes d0
CopyLabelDigit	move.l	a1,a2
		suba.l	a3,a3
		moveq	#30,d1
1$		move.b	(a0)+,(a1)
		beq	2$
		cmp.b	#'1',(a1)
		bne	3$
		move.l	a1,a3
3$		addq.l	#1,a1
		dbra	d1,1$
		clr.b	(a1)
2$		move.l	a3,d1
		beq	4$
		move.b	d0,(a3)
4$		rts

SetVolumesXGads	movem.l	d0-d1/a0-a3/a6,-(sp)
		tst.l	VolXWnd
		beq	1$
		move.l	_GadToolsBase,a6
		move.l	#AFDFileName3,VolXStrTags+4
		move.l	VolXGadgets,a0
		move.l	VolXWnd,a1
		sub.l	a2,a2
		lea	VolXStrTags,a3
		JSRLIB	GT_SetGadgetAttrsA
		move.l	#AFDFileName4,VolXStrTags+4
		move.l	VolXGadgets+3*4,a0
		move.l	VolXWnd,a1
		sub.l	a2,a2
		lea	VolXStrTags,a3
		JSRLIB	GT_SetGadgetAttrsA
		move.l	#SharedDrawer,VolXStrTags+4
		move.l	VolXGadgets+8*4,a0
		move.l	VolXWnd,a1
		sub.l	a2,a2
		lea	VolXStrTags,a3
		JSRLIB	GT_SetGadgetAttrsA
1$		movem.l	(sp)+,d0-d1/a0-a3/a6
		rts

; String gadget contents back into the settings
GetVolumesXGads	movem.l	d0/a0-a1,-(sp)
		tst.l	VolXWnd
		beq	3$
		move.l	VolXGadgets,a0
		lea	AFDFileName3,a1
		bsr	CopyStrGad
		move.l	VolXGadgets+3*4,a0
		lea	AFDFileName4,a1
		bsr	CopyStrGad
		move.l	VolXGadgets+8*4,a0
		lea	SharedDrawer,a1
		bsr	CopyStrGad
3$		movem.l	(sp)+,d0/a0-a1
		rts

CopyStrGad	move.l	gg_SpecialInfo(a0),a0
		move.l	(a0),a0			;si_Buffer
		moveq	#79,d0
1$		move.b	(a0)+,(a1)+
		dbeq	d0,1$
		rts


**
** Disk images dropped on the settings window (a Workbench AppWindow): each
** file goes into the first empty FileDisk slot, and the Volumes tab is shown.
**
OpenAppWindow	movem.l	d0-d2/a0-a2/a6,-(sp)
		move.l	_ExecBase,a6
		lea	WBName,a1
		moveq	#37,d0
		JSRLIB	OpenLibrary
		move.l	d0,TabWBBase
		beq	9$
		JSRLIB	CreateMsgPort
		move.l	d0,AppPort
		beq	9$
		move.l	d0,a0
		moveq	#0,d1
		move.b	MP_SIGBIT(a0),d0
		bset	d0,d1
		move.l	d1,AppSigSet
		move.l	TabWBBase,a6
		moveq	#1,d0			;id
		moveq	#0,d1			;user data
		move.l	SettingsWnd,a0
		move.l	AppPort,a1
		sub.l	a2,a2
		JSRLIB	AddAppWindowA
		move.l	d0,AppWin		;(0: not on the Workbench screen)
9$		movem.l	(sp)+,d0-d2/a0-a2/a6
		rts

CloseAppWindow	movem.l	d0-d1/a0-a1/a6,-(sp)
		move.l	AppWin,d0
		beq	1$
		move.l	TabWBBase,a6
		move.l	d0,a0
		JSRLIB	RemoveAppWindow
		clr.l	AppWin
1$		move.l	_ExecBase,a6
		move.l	AppPort,d0
		beq	3$
2$		move.l	AppPort,a0		;Answer what is still queued
		JSRLIB	GetMsg
		tst.l	d0
		beq	21$
		move.l	d0,a1
		JSRLIB	ReplyMsg
		bra	2$
21$		move.l	AppPort,a0
		JSRLIB	DeleteMsgPort
		clr.l	AppPort
3$		clr.l	AppSigSet
		move.l	TabWBBase,d0
		beq	4$
		move.l	d0,a1
		JSRLIB	CloseLibrary
		clr.l	TabWBBase
4$		movem.l	(sp)+,d0-d1/a0-a1/a6
		rts

HandleAppMsgs	movem.l	d0-d7/a0-a6,-(sp)
		tst.l	AppPort
		beq	HAMDone
		moveq	#0,d5			;d5: something taken
		moveq	#0,d4			;d4: no free slot for something
		cmp.w	#1,CurTab		;Volumes shown: put its strings away first,
		bne	HAMNext			; so they don't overwrite the new names
		lea	TabFuncs,a0
		move.l	12(a0),a0		;tab 1 (Volumes): close routine
		jsr	(a0)
		move.w	#-1,CurTab
		moveq	#1,d5
HAMNext		move.l	_ExecBase,a6
		move.l	AppPort,a0
		JSRLIB	GetMsg
		tst.l	d0
		beq	HAMShow
		move.l	d0,a2
		move.l	am_NumArgs(a2),d6
		move.l	am_ArgList(a2),a3
		bra	HAMArgEnd
HAMArg		move.l	wa_Name(a3),a0		;A file (not a drawer or disk)?
		tst.b	(a0)
		beq	HAMArgNext
		move.l	_DOSBase,a6
		move.l	wa_Lock(a3),d1
		move.l	#DropPath,d2
		move.l	#256,d3
		JSRLIB	NameFromLock
		tst.l	d0
		beq	HAMArgNext
		lea	PrefsNameTab,a4		;First empty FileDisk slot
		moveq	#4-1,d7
1$		move.l	(a4)+,a1
		tst.b	(a1)
		beq	2$
		dbra	d7,1$
		moveq	#1,d4			;All four in use
		bra	HAMArgNext
2$		move.l	a2,-(sp)		;Drawer + name into the slot, if it fits
		move.l	a1,a2
		lea	DropPath,a0
		move.l	wa_Name(a3),a1
		moveq	#80,d0
		jsr	SetPathField
		move.l	(sp)+,a2
		tst.l	d0
		beq	HAMArgNext
		moveq	#1,d5
HAMArgNext	addq.l	#wa_SIZEOF,a3
HAMArgEnd	subq.l	#1,d6
		bpl	HAMArg
		move.l	_ExecBase,a6
		move.l	a2,a1
		JSRLIB	ReplyMsg
		bra	HAMNext

HAMShow		tst.l	d5			;Show the Volumes tab
		beq	1$
		moveq	#1,d0
		bsr	SwitchTab
1$		tst.l	d4
		beq	HAMDone
		move.l	#MSG_DISKSFULL_TXT,d0
		move.l	#MSG_REQGADSOK,d1
		sub.l	a3,a3
		jsr	SReq
HAMDone		movem.l	(sp)+,d0-d7/a0-a6
		rts


**
** Configurations: "ShapeShifter Prefs" and every file in
** PROGDIR:Configurations, chosen with the cycle gadget under the pages.
** Choosing one loads it (Save then writes back to it); "Save as..." saves
** the settings under a new name there.
**
GD_CfgCycle	EQU	940
GD_CfgSaveAs	EQU	941
GD_CfgDefaults	EQU	942
GD_CfgAdvanced	EQU	943
MAXCFG		EQU	16
CFGNAMELEN	EQU	32

; Build the label list (into the array not shown at the moment) and find
; the entry PrefsName names
ScanConfigs	movem.l	d0-d7/a0-a6,-(sp)
		lea	CfgLabelsA,a4		;Fill the other array
		cmp.l	CfgLabelPtr,a4
		bne	1$
		lea	CfgLabelsB,a4
1$		move.l	a4,a5			;a5: array start
		move.l	#CfgDefLabel,(a4)+
		moveq	#1,d7			;d7: count
		move.l	_DOSBase,a6
		move.l	#CfgDirName,d1
		moveq	#ACCESS_READ,d2
		JSRLIB	Lock
		move.l	d0,d6			;d6: lock
		beq	5$
		move.l	d6,d1
		move.l	#CfgFIB,d2
		JSRLIB	Examine
		tst.l	d0
		beq	4$
2$		cmp.w	#MAXCFG,d7
		bhs	4$
		move.l	d6,d1
		move.l	#CfgFIB,d2
		JSRLIB	ExNext
		tst.l	d0
		beq	4$
		tst.l	CfgFIB+fib_DirEntryType	;Files only, no icons
		bpl	2$
		lea	CfgFIB+fib_FileName,a0
		move.l	a0,a1
3$		tst.b	(a1)+
		bne	3$
		subq.l	#1,a1			;a1: end of the name
		move.l	a1,d0
		sub.l	a0,d0
		cmp.l	#5,d0
		blo	31$
		cmp.b	#'.',-5(a1)
		bne	31$
		cmp.b	#'i',-4(a1)
		beq	2$
31$		move.l	d7,d0			;Copy into this entry's buffer
		mulu	#CFGNAMELEN,d0
		lea	CfgNames,a1
		add.l	d0,a1
		move.l	a1,(a4)+
		moveq	#CFGNAMELEN-2,d0
32$		move.b	(a0)+,(a1)+
		dbeq	d0,32$
		clr.b	(a1)
		addq.w	#1,d7
		bra	2$
4$		move.l	d6,d1
		JSRLIB	UnLock
5$		clr.l	(a4)
		move.w	d7,CfgCount
		move.l	a5,CfgLabelPtr

		clr.w	CfgActive		;Which one is PrefsName?
		moveq	#1,d5
6$		cmp.w	d7,d5
		bhs	9$
		move.w	d5,d0
		bsr	CfgPath			;-> CfgPathBuf
		lea	CfgPathBuf,a0
		lea	PrefsName,a1
7$		move.b	(a0)+,d0
		cmp.b	(a1)+,d0
		bne	8$
		tst.b	d0
		bne	7$
		move.w	d5,CfgActive
		bra	9$
8$		addq.w	#1,d5
		bra	6$
9$		movem.l	(sp)+,d0-d7/a0-a6
		rts

; Full name of entry d0.w into CfgPathBuf
CfgPath		movem.l	d0-d1/a0-a1,-(sp)
		lea	CfgPathBuf,a1
		tst.w	d0
		bne	1$
		lea	PrefsDefName,a0
		bra	3$
1$		lea	CfgDirSlash,a0
2$		move.b	(a0)+,(a1)+
		bne	2$
		subq.l	#1,a1
		mulu	#CFGNAMELEN,d0
		lea	CfgNames,a0
		add.l	d0,a0
3$		move.b	(a0)+,(a1)+
		bne	3$
		movem.l	(sp)+,d0-d1/a0-a1
		rts

; GADGETUP. a0: gadget, d0: code. d0 = 1 if it was one of ours
ConfigGadget	movem.l	d1-d7/a0-a6,-(sp)
		move.w	gg_GadgetID(a0),d1
		cmp.w	#GD_CfgCycle,d1
		bne	2$
		cmp.w	CfgCount,d0		;Load the chosen configuration
		bhs	1$
		move.w	d0,CfgActive
		bsr	CfgPath
		lea	CfgPathBuf,a0
		lea	PrefsName,a1
11$		move.b	(a0)+,(a1)+
		bne	11$
		jsr	LoadConfig
		bsr	ApplyAdvanced
1$		moveq	#1,d0
		bra	9$

2$		cmp.w	#GD_CfgAdvanced,d1
		bne	271$
		moveq	#0,d0
		btst	#7,gg_Flags+1(a0)	;GFLG_SELECTED
		sne	d0
		ext.w	d0
		move.w	d0,OptAdvanced
		bsr	ApplyAdvanced
		moveq	#1,d0
		bra	9$
271$		cmp.w	#GD_CfgDefaults,d1
		bne	28$
		jsr	ReadConfig		;What was typed so far stays
		jsr	SuggestDefaults
		jsr	ShowConfig
		moveq	#1,d0
		bra	9$
28$		cmp.w	#GD_CfgSaveAs,d1
		bne	8$
		move.l	_DOSBase,a6		;Configurations drawer, made if needed
		move.l	#CfgDirName,d1
		moveq	#ACCESS_READ,d2
		JSRLIB	Lock
		tst.l	d0
		bne	21$
		move.l	#CfgDirName,d1
		JSRLIB	CreateDir
		tst.l	d0
		beq	22$
21$		move.l	d0,d1
		JSRLIB	UnLock
22$		lea	PrefsName,a0		;Keep the name: it comes back if "Save as" is cancelled
		lea	CfgKeepName,a1
25$		move.b	(a0)+,(a1)+
		bne	25$
; The requester offers the file in use: "ShapeShifter Prefs" in the program's
; drawer (what is loaded at every start) unless a configuration was chosen,
; then that one. A new name saved into Configurations makes a configuration.
23$		jsr	SaveConfigAs
		tst.l	d0
		bne	27$
		lea	CfgKeepName,a0
		lea	PrefsName,a1
26$		move.b	(a0)+,(a1)+
		bne	26$
27$
		bsr	ScanConfigs		;Show the new list
		move.l	_GadToolsBase,a6
		move.l	CfgLabelPtr,CfgSetTags+4
		moveq	#0,d0
		move.w	CfgActive,d0
		move.l	d0,CfgSetTags+12
		move.l	CfgCycle,a0
		move.l	SettingsWnd,a1
		sub.l	a2,a2
		lea	CfgSetTags,a3
		JSRLIB	GT_SetGadgetAttrsA
		moveq	#1,d0
		bra	9$

8$		moveq	#0,d0
9$		movem.l	(sp)+,d1-d7/a0-a6
		rts

		SECTION	"DATA",DATA

TabWindowTags
TWLeft		dc.l	WA_Left,0
TWTop		dc.l	WA_Top,0
TWWidth		dc.l	WA_Width,0
TWHeight	dc.l	WA_Height,0
		dc.l	WA_IDCMP,CYCLEIDCMP!TEXTIDCMP!BUTTONIDCMP!INTEGERIDCMP!CHECKBOXIDCMP!STRINGIDCMP!NUMBERIDCMP!IDCMP_GADGETUP!IDCMP_GADGETDOWN!IDCMP_MOUSEMOVE!IDCMP_MOUSEBUTTONS!IDCMP_MENUPICK!IDCMP_CLOSEWINDOW!IDCMP_VANILLAKEY!IDCMP_REFRESHWINDOW!IDCMP_GADGETHELP
		dc.l	WA_Flags,WFLG_DRAGBAR!WFLG_DEPTHGADGET!WFLG_CLOSEGADGET!WFLG_SMART_REFRESH!WFLG_ACTIVATE!WFLG_NEWLOOKMENUS
TWGadgets	dc.l	WA_Gadgets,0
TWTitle		dc.l	WA_Title,0
TWScrTitle	dc.l	WA_ScreenTitle,0
TWScreen	dc.l	WA_PubScreen,0
		dc.l	WA_AutoAdjust,1
		dc.l	TAG_DONE

CurTab		dc.w	-1

CfgCycTags	dc.l	GTCY_Labels,0,GTCY_Active,0,TAG_DONE
CfgSetTags	dc.l	GTCY_Labels,0,GTCY_Active,0,TAG_DONE
NoTags		dc.l	TAG_DONE
; Text pointers, set from the catalog by LocalizeNew (MacEmulLoc.asm)
CfgLabelP	dc.l	CfgLabelText
CfgSaveP	dc.l	CfgSaveText
CfgDefP		dc.l	CfgDefText
CfgAdvP		dc.l	CfgAdvText
CfgAdvTags	dc.l	GTCB_Checked,0,GTCB_Scaled,1,TAG_DONE
CfgAdvGad	dc.l	0
CPUTabLabelP	dc.l	CPUTabLabel
CPUFPUP		dc.l	CPUFPUTxt
CPUNoFPUP	dc.l	CPUNoFPUTxt
CPUMMUP		dc.l	CPUMMUTxt
CPUNoMMUP	dc.l	CPUNoMMUTxt

CfgLabelText	dc.b	"Configuration",0
CfgSaveText	dc.b	"Save as...",0
CfgDefText	dc.b	"Defaults",0
CfgAdvText	dc.b	"Advanced",0
CfgDefLabel	dc.b	"ShapeShifter Prefs",0
CfgDirName	dc.b	"PROGDIR:Configurations",0
CfgDirSlash	dc.b	"PROGDIR:Configurations/",0
CfgNewPath	dc.b	"PROGDIR:Configurations/My setup",0
		EVEN

WBName		dc.b	"workbench.library",0
		EVEN
		EVEN

; FileDisk 3/4 on the Volumes page (GadToolsBox format, design units)
		CNOP	0,4
PageVolumesX	dc.l	VolXNGads,VolXGTypes,VolXGTags,VolXGadgets,VolXGList,VolXWnd,VolXWidth,VolXHeight
		dc.w	VOLX_CNT,0
		dc.l	0
VolXWidth	dc.w	0			;(the Volumes page has the size)
VolXHeight	dc.w	0

VolXNGads	dc.w	113,42,265,14
		dc.l	VolXLabel3,0
		dc.w	GD_AFDName3
		dc.l	PLACETEXT_LEFT,0,0
		dc.w	378,42,20,14
		dc.l	0,0
		dc.w	GD_GetAFDName3
		dc.l	0,0,0
		dc.w	408,42,105,14
		dc.l	0,0			;"Create...", set by PrepVolumesX
		dc.w	GD_MakeAFD3
		dc.l	PLACETEXT_IN,0,0
		dc.w	113,60,265,14
		dc.l	VolXLabel4,0
		dc.w	GD_AFDName4
		dc.l	PLACETEXT_LEFT,0,0
		dc.w	378,60,20,14
		dc.l	0,0
		dc.w	GD_GetAFDName4
		dc.l	0,0,0
		dc.w	408,60,105,14
		dc.l	0,0
		dc.w	GD_MakeAFD4
		dc.l	PLACETEXT_IN,0,0
		dc.w	408,96,105,14		;Under "Choose..." of device disk 1
		dc.l	0,0			;"Format...", set by PrepVolumesX
		dc.w	GD_FormatADD1
		dc.l	PLACETEXT_IN,0,0
		dc.w	408,173,105,14
		dc.l	0,0
		dc.w	GD_FormatADD2
		dc.l	PLACETEXT_IN,0,0
		dc.w	378,234,135,14		;Right of "Boot from"
		dc.l	0,0			;"Synced drawer", set by PrepVolumesX
		dc.w	GD_SharedDrawer
		dc.l	PLACETEXT_LEFT,0,0

VolXGTypes	dc.w	STRING_KIND,GENERIC_KIND,BUTTON_KIND,STRING_KIND,GENERIC_KIND,BUTTON_KIND
		dc.w	BUTTON_KIND,BUTTON_KIND,STRING_KIND

VolXGTags	dc.l	GTST_MaxChars,79,TAG_DONE
		dc.l	TAG_DONE
		dc.l	GT_Underscore,'_',TAG_DONE
		dc.l	GTST_MaxChars,79,TAG_DONE
		dc.l	TAG_DONE
		dc.l	GT_Underscore,'_',TAG_DONE
		dc.l	TAG_DONE
		dc.l	TAG_DONE
		dc.l	GTST_MaxChars,79,TAG_DONE

VolXStrTags	dc.l	GTST_String,0,TAG_DONE

; CPU page in the GadToolsBox format (design units, topaz 8)
		CNOP	0,4
PageCPU		dc.l	CPUNGads,CPUGTypes,CPUGTags,CPUGadgets,CPUGList,CPUWnd,CPUWidth,CPUHeight
		dc.w	CPU_CNT,0
		dc.l	0

CPUWidth	dc.w	440
CPUHeight	dc.w	142

CPUNGads	dc.w	120,4,300,12
		dc.l	CPUInfoLabel,0
		dc.w	GD_CPUInfo
		dc.l	PLACETEXT_LEFT,0,0
CPUBOX		MACRO	;y, text, n
		dc.w	20,\1,26,11
		dc.l	\2,0
		dc.w	GD_CPUOpt0+\3
		dc.l	PLACETEXT_RIGHT,0,0
		ENDM
		CPUBOX	22,CPUOpt0Txt,0
		CPUBOX	36,CPUOpt1Txt,1
		CPUBOX	50,CPUOpt2Txt,2
		CPUBOX	70,CPUOpt4Txt,3
		CPUBOX	84,CPUOpt5Txt,4
		CPUBOX	98,CPUOpt6Txt,5
		CPUBOX	112,CPUOpt7Txt,6
		CPUBOX	126,CPUOpt8Txt,7

CPUGTypes	dc.w	TEXT_KIND
		dcb.w	NUMCPUOPTS,CHECKBOX_KIND

CPUGTags	dc.l	GTTX_Border,1,TAG_DONE
		dcb.l	NUMCPUOPTS,TAG_DONE

; saved option, tooltype/argument variable, needs MMU
CPUOptTab	dc.l	OptNoCopyBack,NoCopyBack
		dc.w	0,0
		dc.l	OptRemap8K,Remap8K
		dc.w	1,0
		dc.l	OptEnforcer,EnforcerCompat
		dc.w	1,0
		dc.l	OptUSKeyMap,USKeyMap
		dc.w	0,0
		dc.l	OptNoQDAccel,NoQDAccel
		dc.w	0,0
		dc.l	Opt720K,Kludge720K
		dc.w	0,0
		dc.l	OptDebug,DebugMode
		dc.w	0,0
		dc.l	OptDepthSwitch,DepthSwitch
		dc.w	0,0

CPUInfoTags	dc.l	GTTX_Text,CPUInfoBuf,TAG_DONE
CPUCheckTags	dc.l	GTCB_Checked,0,GA_Disabled,0,TAG_DONE

CPUTabLabel	dc.b	"CPU",0
CPUInfoLabel	dc.b	"Processor",0
CPUOpt0Txt	dc.b	"Disable copyback cache (NOCOPYBACK)",0
CPUOpt1Txt	dc.b	"Remap lower 8K with the MMU (REMAP8K)",0
CPUOpt2Txt	dc.b	"Enforcer compatible (ENFORCER)",0
CPUOpt4Txt	dc.b	"US keyboard layout (USKEYMAP)",0
CPUOpt5Txt	dc.b	"No QuickDraw acceleration (NOQDACCEL)",0
CPUOpt6Txt	dc.b	"720K floppy kludge (720KKLUDGE)",0
CPUOpt7Txt	dc.b	"Debug mode (DEBUG)",0
CPUOpt8Txt	dc.b	"Mac chooses the colour depth (DEPTHSWITCH)",0
CPU68000Txt	dc.b	"68000",0
CPU68010Txt	dc.b	"68010",0
CPU68020Txt	dc.b	"68020",0
CPU68030Txt	dc.b	"68030",0
CPU68040Txt	dc.b	"68040",0
CPU68060Txt	dc.b	"68060",0
CPUFPUTxt	dc.b	", FPU",0
CPUNoFPUTxt	dc.b	", no FPU",0
CPUMMUTxt	dc.b	", MMU",0
CPUNoMMUTxt	dc.b	", no MMU",0
		EVEN


		SECTION	"BSS",BSS
CfgKeepName	ds.b	256	;PrefsName while the Save as requester is open

TabNewGad	ds.b	gng_SIZEOF
		CNOP	0,4
TabDri		ds.l	1
TabFont		ds.l	1
TabDesignW	ds.w	1
TabDesignH	ds.w	1
MaxPageW	ds.w	1
MaxPageH	ds.w	1
TabH		ds.w	1
TabScale	ds.w	1	;256 = pages at their designed height
TabY0		ds.w	1
TabPad		ds.w	1
FrameX		ds.w	1
FrameY		ds.w	1
FrameW		ds.w	1
FrameH		ds.w	1
PageOrgX	ds.w	1
PageOrgY	ds.w	1
ButtonY		ds.w	1
ButtonW		ds.w	1
ButtonH		ds.w	1
TabX		ds.w	NUMTABS
TabW		ds.w	NUMTABS
TabTW		ds.w	NUMTABS
TabLen		ds.w	NUMTABS
TabLabels	ds.b	NUMTABS*LABELMAX
CPUGadgets	ds.l	CPU_CNT
CPUGList	ds.l	1
CPUWnd		ds.l	1
CPUInfoBuf	ds.b	64
VolXGadgets	ds.l	VOLX_CNT
VolXGList	ds.l	1
VolXWnd		ds.l	1
VolXLabel3	ds.b	32
VolXLabel4	ds.b	32
TabWBBase	ds.l	1
AppPort		ds.l	1
AppWin		ds.l	1
AppSigSet	ds.l	1
DropPath	ds.b	256
		CNOP	0,4
CfgFIB		ds.b	fib_SIZEOF
CfgLabelsA	ds.l	MAXCFG+1
CfgLabelsB	ds.l	MAXCFG+1
CfgLabelPtr	ds.l	1
CfgCycle	ds.l	1
CfgNames	ds.b	MAXCFG*CFGNAMELEN
CfgPathBuf	ds.b	256
CfgCount	ds.w	1
CfgActive	ds.w	1
ConfigY		ds.w	1
