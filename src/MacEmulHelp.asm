**
** MacEmulHelp.asm - one line of help for the gadget under the mouse
**
** The settings window gets IDCMP_GADGETHELP (Intuition V39, HelpControl in
** MacEmulTabs.asm). For the gadget under the mouse its line from HelpTab is
** shown in the window title; anywhere else the normal title comes back.
** The texts are MSG_HELP_ messages in Catalogs/ShapeShifter.cd.
**

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"intuition/intuition.i"
		INCLUDE	"macros.i"
		INCLUDE	"MacEmulGUI.i"
CATCOMP_NUMBERS	= 1
		INCLUDE	"Strings.i"

		XDEF	GadgetHelp

		XREF	SettingsWnd
		XREF	TheLocale
		XREF	GetString

		SECTION	"CODE",CODE

; Gadget help event. a0: im_IAddress (gadget, the window, or 0)
GadgetHelp	movem.l	d0-d1/a0-a2/a6,-(sp)
		move.l	SettingsWnd,d0
		beq	9$
		move.l	d0,a1
		tst.l	DefTitle		;Remember the normal title once
		bne	1$
		move.l	wd_Title(a1),DefTitle
1$		move.l	DefTitle,d1		;d1: text to show
		move.l	a0,d0
		beq	4$
		cmp.l	a1,d0			;Over the window, not a gadget
		beq	4$
		move.w	gg_GadgetID(a0),d0
		lea	HelpTab,a2
2$		cmp.w	#-1,(a2)
		beq	4$
		cmp.w	(a2),d0
		beq	3$
		addq.l	#6,a2
		bra	2$
3$		move.l	2(a2),d0		;Message number
		lea	TheLocale,a0
		jsr	GetString
		move.l	d0,d1
4$		cmp.l	ShownTitle,d1		;Already showing it
		beq	9$
		move.l	d1,ShownTitle
		move.l	_IntuitionBase,a6
		move.l	SettingsWnd,a0
		move.l	d1,a1
		move.l	#-1,a2			;Screen title stays
		JSRLIB	SetWindowTitles
9$		movem.l	(sp)+,d0-d1/a0-a2/a6
		rts


		SECTION	"DATA",DATA

H		MACRO	;gadget ID, message number
		dc.w	\1
		dc.l	\2
		ENDM

		CNOP	0,2
HelpTab
; Buttons
		H	GD_OK,MSG_HELP_START
		H	GD_Cancel,MSG_HELP_EXIT
		H	GD_SavePrefs,MSG_HELP_SAVE
; Graphics
		H	GD_NumMonitors,MSG_HELP_NUMMON
		H	GD_VideoMode1,MSG_HELP_DEPTH
		H	GD_VideoMode2,MSG_HELP_DEPTH
		H	GD_VideoType1,MSG_HELP_TYPE
		H	GD_VideoType2,MSG_HELP_TYPE
		H	GD_ExtVideoName1,MSG_HELP_EXTVID
		H	GD_ExtVideoName2,MSG_HELP_EXTVID
		H	GD_GetVideoName1,MSG_HELP_EXTVID
		H	GD_GetVideoName2,MSG_HELP_EXTVID
		H	GD_DisplayID1,MSG_HELP_MODE
		H	GD_DisplayID2,MSG_HELP_MODE
		H	GD_GetDisplayID1,MSG_HELP_MODE
		H	GD_GetDisplayID2,MSG_HELP_MODE
		H	GD_ScreenX1,MSG_HELP_SIZE
		H	GD_ScreenY1,MSG_HELP_SIZE
		H	GD_ScreenX2,MSG_HELP_SIZE
		H	GD_ScreenY2,MSG_HELP_SIZE
		H	GD_RefreshRate,MSG_HELP_REFRATE
		H	GD_BlackBorder,MSG_HELP_BLACK
		H	GD_RefreshAlways,MSG_HELP_REFALWAYS
		H	GD_MMURefresh,MSG_HELP_MMUREF
		H	GD_UseAmigaMouse,MSG_HELP_AMIMOUSE
; Volumes
		H	GD_AFDName1,MSG_HELP_AFD
		H	GD_AFDName2,MSG_HELP_AFD
		H	930,MSG_HELP_AFD
		H	933,MSG_HELP_AFD
		H	GD_GetAFDName1,MSG_HELP_GETAFD
		H	GD_GetAFDName2,MSG_HELP_GETAFD
		H	931,MSG_HELP_GETAFD
		H	934,MSG_HELP_GETAFD
		H	GD_MakeAFD1,MSG_HELP_MAKEAFD
		H	GD_MakeAFD2,MSG_HELP_MAKEAFD
		H	932,MSG_HELP_MAKEAFD
		H	935,MSG_HELP_MAKEAFD
		H	GD_ADDName1,MSG_HELP_ADD
		H	GD_ADDName2,MSG_HELP_ADD
		H	GD_GetADD1,MSG_HELP_GETADD
		H	GD_GetADD2,MSG_HELP_GETADD
		H	936,MSG_HELP_FORMATADD	;GD_FormatADD1/2 (MacEmulTabs)
		H	937,MSG_HELP_FORMATADD
		H	GD_ADDUnit1,MSG_HELP_ADDUNIT
		H	GD_ADDUnit2,MSG_HELP_ADDUNIT
		H	GD_ADDStartSector1,MSG_HELP_ADDSECT
		H	GD_ADDStartSector2,MSG_HELP_ADDSECT
		H	GD_ADDSectors1,MSG_HELP_ADDSECT
		H	GD_ADDSectors2,MSG_HELP_ADDSECT
		H	GD_ADDMaxTransfer1,MSG_HELP_MAXTRANS
		H	GD_ADDMaxTransfer2,MSG_HELP_MAXTRANS
		H	GD_ADDRemovable1,MSG_HELP_REMOV
		H	GD_ADDRemovable2,MSG_HELP_REMOV
		H	GD_BootFrom,MSG_HELP_BOOT
; Floppys
		H	GD_Floppy1,MSG_HELP_FLOPPY
		H	GD_Floppy2,MSG_HELP_FLOPPY
		H	GD_SearchFloppys,MSG_HELP_SEARCH
		H	GD_InhibitFloppy1,MSG_HELP_INHIBIT
		H	GD_InhibitFloppy2,MSG_HELP_INHIBIT
; SCSI
		H	GD_SCSI0,MSG_HELP_SCSION
		H	GD_SCSI1,MSG_HELP_SCSION
		H	GD_SCSI2,MSG_HELP_SCSION
		H	GD_SCSI3,MSG_HELP_SCSION
		H	GD_SCSI4,MSG_HELP_SCSION
		H	GD_SCSI5,MSG_HELP_SCSION
		H	GD_SCSI6,MSG_HELP_SCSION
		H	GD_SCSIName0,MSG_HELP_SCSIDRV
		H	GD_SCSIName1,MSG_HELP_SCSIDRV
		H	GD_SCSIName2,MSG_HELP_SCSIDRV
		H	GD_SCSIName3,MSG_HELP_SCSIDRV
		H	GD_SCSIName4,MSG_HELP_SCSIDRV
		H	GD_SCSIName5,MSG_HELP_SCSIDRV
		H	GD_SCSIName6,MSG_HELP_SCSIDRV
		H	GD_SCSIUnit0,MSG_HELP_SCSIUNIT
		H	GD_SCSIUnit1,MSG_HELP_SCSIUNIT
		H	GD_SCSIUnit2,MSG_HELP_SCSIUNIT
		H	GD_SCSIUnit3,MSG_HELP_SCSIUNIT
		H	GD_SCSIUnit4,MSG_HELP_SCSIUNIT
		H	GD_SCSIUnit5,MSG_HELP_SCSIUNIT
		H	GD_SCSIUnit6,MSG_HELP_SCSIUNIT
		H	GD_SCSIMemType,MSG_HELP_SCSIMEM
		H	GD_AppleCD,MSG_HELP_APPLECD
		H	GD_AppleHD,MSG_HELP_APPLEHD
		H	GD_SCSIDirect,MSG_HELP_DIRECT
		H	GD_FastCrapMode,MSG_HELP_SUMMER
; Memory
		H	GD_MemSize,MSG_HELP_MEMSIZE
		H	GD_MemMax,MSG_HELP_MEMMAX
		H	GD_LargestBlock,MSG_HELP_LARGEST
		H	GD_FastROM,MSG_HELP_FASTROM
		H	GD_ROMMemType,MSG_HELP_ROMMEM
; Serial
		H	GD_SERDNameA,MSG_HELP_SERDRV
		H	GD_SERDNameB,MSG_HELP_SERDRV
		H	GD_GetSERDA,MSG_HELP_SERDRV
		H	GD_GetSERDB,MSG_HELP_SERDRV
		H	GD_SERDUnitA,MSG_HELP_SERUNIT
		H	GD_SERDUnitB,MSG_HELP_SERUNIT
		H	GD_SERDAIsPar,MSG_HELP_SERPAR
		H	GD_SERDBIsPar,MSG_HELP_SERPAR
		H	GD_UseSCCSerial,MSG_HELP_AMAX
; Network
		H	GD_Sana2Name,MSG_HELP_SANA
		H	GD_GetSana2,MSG_HELP_SANA
		H	GD_Sana2Unit,MSG_HELP_SANAUNIT
; Miscellaneous
		H	GD_MouseDirect,MSG_HELP_MOUSE
		H	GD_ProtectROM,MSG_HELP_PROTROM
		H	GD_MacOS8Mode,MSG_HELP_MACOS8
		H	GD_AudioOn,MSG_HELP_AUDIO
		H	GD_UseAHI,MSG_HELP_AHI
		H	GD_AudioID,MSG_HELP_AHIMODE
		H	GD_GetAudioID,MSG_HELP_AHIMODE
; CPU tab
		H	900,MSG_HELP_CPUINFO
		H	901,MSG_HELP_NOCB
		H	902,MSG_HELP_REMAP
		H	903,MSG_HELP_ENFORCER
		H	904,MSG_HELP_USKEY
		H	905,MSG_HELP_NOQD
		H	906,MSG_HELP_720K
		H	907,MSG_HELP_DEBUG
		H	908,MSG_HELP_DEPTHSW
		dc.w	-1

		EVEN


		SECTION	"BSS",BSS

DefTitle	ds.l	1
ShownTitle	ds.l	1
