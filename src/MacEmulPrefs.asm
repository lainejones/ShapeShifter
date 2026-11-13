**
** Macintosh IIci-Emulator - Einstellungen
** =======================================
**
** © Copyright 1994-2001 Christian Bauer
**

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"exec/ports.i"
		INCLUDE	"dos/dos.i"
		INCLUDE "dos/dosextens.i"
		INCLUDE	"dos/filehandler.i"
		INCLUDE	"graphics/displayinfo.i"
		INCLUDE	"intuition/intuition.i"
		INCLUDE	"intuition/gadgetclass.i"
		INCLUDE	"workbench/workbench.i"
		INCLUDE	"libraries/asl.i"
		INCLUDE	"libraries/gadtools.i"
		INCLUDE	"libraries/cybergraphics.i"
		INCLUDE	"devices/ahi.i"
		INCLUDE	"devices/ahi_lib.i"
		INCLUDE	"utility/tagitem.i"
		INCLUDE	"ShapeShifter_rev.i"
		INCLUDE	"macros.i"
		INCLUDE	"MacEmulGUI.i"
		XREF	OpenCyberGfx
		XREF	SettingsNGads
CATCOMP_NUMBERS	= 1
		INCLUDE	"Strings.i"

		XDEF	DoSettings
		XDEF	TabFuncs
		XDEF	SetPathField
		XDEF	LoadConfig
		XDEF	SaveConfigAs
		XDEF	ShowConfig,ReadConfig
		XREF	SetCPUGads
		XREF	ConfigGadget
		XDEF	TabLabelGDX
		XDEF	RequestFile	;(MacEmulSetup)
		XDEF	CreateEmptyDisk
		XREF	OpenTabWindow
		XREF	CloseTabWindow
		XREF	SwitchTab
		XREF	NextTab
		XREF	TabClick
		XREF	OpenCPUWnd
		XREF	CloseCPUWnd
		XREF	SReq
		XREF	CPUGadget
		XREF	GadgetHelp
		XREF	AppSigSet
		XREF	HandleAppMsgs
		XREF	PrepVolumesX
		XREF	SetVolumesXGads
		XREF	GetVolumesXGads
		XREF	VolXGadgets
		XREF	FormatFileDisk		;(MacEmulHFS)
		XREF	FormatDevDisk
		XREF	AttachPage
		XREF	DetachPage
		XREF	PageGraphics
		XREF	PageVolumes
		XREF	PageFloppy
		XREF	PageSCSI
		XREF	PageMemory
		XREF	PageSerial
		XREF	PageNetwork
		XREF	PageMisc
		XDEF	LocalizePrefs
		XDEF	OpenThePrefs

		XREF	TheLocale
		XREF	GetString

		XREF	PrefsName
		XREF	OptAdvanced
		XREF	EmulPrefs
		XREF	EmulPrefsEnd
		XREF	PrefsNameTab
		XREF	ROMSize
		XREF	QuickStart
		XREF	HasMMU
		XREF	Has68060
		XREF	HasRealSCC

		SECTION	"CODE",CODE

**
** Definitionen
**

; CyberGfx
CModeRequest	= -66
GetCyberIDAttr	= -102


**
** Makros
**

; Cycle-Gadget setzen (16 Bit)
SetCycleW	MACRO	;Fenster, GDX_#?, Word
		move.l	\2*4(a5),a0
		move.l	\1,a1
		sub.l	a2,a2
		lea	SetCycleTags,a3
		moveq	#0,d0
		move.w	\3,d0
		move.l	d0,SetCycTagsVal
		JSRLIB	GT_SetGadgetAttrsA
		ENDM

; Integer-Gadget setzen (16 Bit)
SetIntW		MACRO	;Fenster, GDX_#?, Word
		move.l	\2*4(a5),a0
		move.l	\1,a1
		sub.l	a2,a2
		lea	SetIntegerTags,a3
		moveq	#0,d0
		move.w	\3,d0
		move.l	d0,SetIntTagsVal
		JSRLIB	GT_SetGadgetAttrsA
		ENDM

; Integer-Gadget setzen (32 Bit)
SetIntL		MACRO	;Fenster, GDX_#?, Long
		move.l	\2*4(a5),a0
		move.l	\1,a1
		sub.l	a2,a2
		lea	SetIntegerTags,a3
		move.l	\3,SetIntTagsVal
		JSRLIB	GT_SetGadgetAttrsA
		ENDM

; Checkbox-Gadget setzen (16 Bit Boolean)
SetCheck	MACRO	;Fenster, GDX_#?, Word
		lea	SetCheckOffTags,a3
		tst.w	\3
		beq	\@1$
		lea	SetCheckOnTags,a3
\@1$		move.l	\2*4(a5),a0
		move.l	\1,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		ENDM

; LongInt-Wert aus Integer-Gadget a0 lesen
GetInt		MACRO	;Ziel
		move.l	gg_SpecialInfo(a0),a0
		move.l	si_LongInt(a0),\1
		ENDM


**
** Einstellungs-Fenster darstellen und handhaben
** Rückgabe: d0<0: Ein Fehler ist aufgetreten
**           d0>1: "OK" wurde betätigt
**           d0=0: "Cancel" wurde betätigt
**

; Options-Fenster öffnen
DoSettings	move.l	_UtilityBase,a6
		move.l	#WA_Flags,d0
		lea	SettingsWindowTags,a0
		JSRLIB	FindTagItem
		move.l	d0,a0
		or.l	#WFLG_NEWLOOKMENUS,ti_Data(a0)
		move.l	#1,SettingsMenus+8

		jsr	SetupScreen
		tst.l	d0
		beq	1$
		moveq	#-1,d0
		rts

1$		tst.l	QuickStart		;Bei Quickstart sofort wieder beenden
		beq	4$
		jsr	CloseDownScreen
		moveq	#1,d0
		rts

4$		jsr	OpenTabWindow
		tst.l	d0
		beq	2$
		jsr	CloseDownScreen
		moveq	#-1,d0
		rts

2$		move.l	_ExecBase,a6
		moveq	#0,d0
		move.l	SettingsWnd,a0
		move.l	wd_UserPort(a0),a0
		move.b	MP_SIGBIT(a0),d1
		bset	d1,d0
		move.l	d0,SettingsSet

* EventLoop
EventLoop	move.l	_ExecBase,a6
		move.l	SettingsSet,d0
		or.l	AppSigSet,d0		;Disk images dropped on the window
		or.l	#SIGBREAKF_CTRL_C,d0
		or.l	#SIGBREAKF_CTRL_F,d0
		JSRLIB	Wait
		move.l	d0,d1
		and.l	#SIGBREAKF_CTRL_C,d0
		bne	ReceivedCtrlC
		move.l	d1,d0
		and.l	#SIGBREAKF_CTRL_F,d0
		bne	ReceivedCtrlF

		move.l	d1,d0			;Dropped disk images
		and.l	AppSigSet,d0
		beq	2$
		jsr	HandleAppMsgs
		move.l	d1,d0			;Nothing else? Then wait again
		and.l	SettingsSet,d0
		beq	EventLoop
2$

		move.l	SettingsWnd,a0		;Es gibt nur noch ein Fenster
		move.l	a0,TheWindow

; Nachricht holen und beantworten
GetEvent	move.l	_GadToolsBase,a6
		move.l	TheWindow,a0
		move.l	wd_UserPort(a0),a0
		JSRLIB	GT_GetIMsg
		tst.l	d0
		beq	EventLoop
		move.l	d0,a1
		move.l	im_Class(a1),TheClass
		move.w	im_Code(a1),TheCode
		move.l	im_IAddress(a1),TheGadget
		move.w	im_MouseX(a1),TheMouseX
		move.w	im_MouseY(a1),TheMouseY
		JSRLIB	GT_ReplyIMsg

; Klasse auswerten
		move.l	TheClass,d0
		and.l	#IDCMP_GADGETUP,d0
		beq	NotGadget
		move.l	TheGadget,a0

		move.w	TheCode,d0
		jsr	ConfigGadget		;Konfigurationen
		tst.l	d0
		bne	GetEvent
		move.l	TheGadget,a0
		jsr	CPUGadget		;CPU-Tab
		tst.l	d0
		bne	GetEvent
		move.l	TheGadget,a0

; FileDisk 3/4 (zweite Gadget-Liste auf der Volumes-Seite, MacEmulTabs.asm)
		cmp.w	#931,gg_GadgetID(a0)	;GD_GetAFDName3
		bne	80$
		lea	SetAFD3Tags,a3
		lea	AFDFileName3,a4
		move.l	VolXGadgets,AFDExtraGad
		moveq	#-1,d4
		bsr	DoGetAFDName
		bra	GetEvent
80$		cmp.w	#934,gg_GadgetID(a0)	;GD_GetAFDName4
		bne	81$
		lea	SetAFD4Tags,a3
		lea	AFDFileName4,a4
		move.l	VolXGadgets+3*4,AFDExtraGad
		moveq	#-1,d4
		bsr	DoGetAFDName
		bra	GetEvent
81$		cmp.w	#932,gg_GadgetID(a0)	;GD_MakeAFD3
		bne	82$
		lea	SetAFD3Tags,a3
		lea	AFDFileName3,a4
		move.l	VolXGadgets,AFDExtraGad
		moveq	#-1,d4
		bsr	DoMakeAFD
		bra	GetEvent
82$		cmp.w	#935,gg_GadgetID(a0)	;GD_MakeAFD4
		bne	83$
		lea	SetAFD4Tags,a3
		lea	AFDFileName4,a4
		move.l	VolXGadgets+3*4,AFDExtraGad
		moveq	#-1,d4
		bsr	DoMakeAFD
		bra	GetEvent
83$		cmp.w	#936,gg_GadgetID(a0)	;GD_FormatADD1
		bne	84$
		bsr	GetVolumesGads		;(what the fields say now)
		lea	ADDName1,a0
		move.l	ADDUnit1,d0
		move.l	ADDStartSector1,d1
		move.l	ADDSectors1,d2
		jsr	FormatDevDisk
		bra	GetEvent
84$		cmp.w	#937,gg_GadgetID(a0)	;GD_FormatADD2
		bne	85$
		bsr	GetVolumesGads
		lea	ADDName2,a0
		move.l	ADDUnit2,d0
		move.l	ADDStartSector2,d1
		move.l	ADDSectors2,d2
		jsr	FormatDevDisk
		bra	GetEvent
85$

; OK
		cmp.w	#GD_OK,gg_GadgetID(a0)
		bne	1$
		moveq	#1,d7			;Beenden
		bra	WindowDone

; Cancel
1$		cmp.w	#GD_Cancel,gg_GadgetID(a0)
		bne	2$
		moveq	#-1,d7			;Beenden
		bra	WindowDone

; Maus direkt abfragen
2$		cmp.w	#GD_MouseDirect,gg_GadgetID(a0)
		bne	20$
		not.w	MouseDirect
		bra	GetEvent

; Schwarzer Rahmen
20$		cmp.w	#GD_BlackBorder,gg_GadgetID(a0)
		bne	21$
		not.w	BlackBorder
		bra	GetEvent

; ROM im schnellen Speicher ablegen
21$		cmp.w	#GD_FastROM,gg_GadgetID(a0)
		bne	22$
		not.w	FastROM
		bsr	DrawMemMaxGad
		bra	GetEvent

; Größten freien Block holen
22$		cmp.w	#GD_LargestBlock,gg_GadgetID(a0)
		bne	23$
		not.w	LargestBlock
		bsr	GhostMemory
		bra	GetEvent

; Bildschirm-Typ
23$		cmp.w	#GD_VideoType1,gg_GadgetID(a0)
		bne	231$
		move.w	TheCode,VideoType1
		bsr	GhostGraphics
		bra	GetEvent

231$		cmp.w	#GD_VideoType2,gg_GadgetID(a0)
		bne	24$
		move.w	TheCode,VideoType2
		bsr	GhostGraphics
		bra	GetEvent

; Immer refreshen
24$		cmp.w	#GD_RefreshAlways,gg_GadgetID(a0)
		bne	25$
		not.w	RefreshAlways
		bra	GetEvent

; Amiga-Mauszeiger
25$		cmp.w	#GD_UseAmigaMouse,gg_GadgetID(a0)
		bne	26$
		not.w	UseAmigaMouse
		bra	GetEvent

; ADD 1 Wechselmedium
26$		cmp.w	#GD_ADDRemovable1,gg_GadgetID(a0)
		bne	27$
		not.w	ADDRemovable1
		bra	GetEvent

; ADD 2 Wechselmedium
27$		cmp.w	#GD_ADDRemovable2,gg_GadgetID(a0)
		bne	28$
		not.w	ADDRemovable2
		bra	GetEvent

; MMU-Refresh
28$		cmp.w	#GD_MMURefresh,gg_GadgetID(a0)
		bne	29$
		not.w	MMURefresh
		bra	GetEvent

; Anzahl Monitore
29$		cmp.w	#GD_NumMonitors,gg_GadgetID(a0)
		bne	3$
		move.w	TheCode,NumMonitors
		bsr	GhostGraphics
		bra	GetEvent

; Farbtiefe
3$		cmp.w	#GD_VideoMode1,gg_GadgetID(a0)
		bne	301$
		move.w	TheCode,VideoMode1
		bra	GetEvent

301$		cmp.w	#GD_VideoMode2,gg_GadgetID(a0)
		bne	30$
		move.w	TheCode,VideoMode2
		bra	GetEvent

; Serieller Treiber Modemport parallel
30$		cmp.w	#GD_SERDAIsPar,gg_GadgetID(a0)
		bne	31$
		not.w	SERDAIsPar
		bra	GetEvent

; Serieller Treiber Druckerport parallel
31$		cmp.w	#GD_SERDBIsPar,gg_GadgetID(a0)
		bne	32$
		not.w	SERDBIsPar
		bra	GetEvent

; Floppy 1
32$		cmp.w	#GD_Floppy1,gg_GadgetID(a0)
		bne	33$
		move.w	TheCode,Floppy1
		bra	GetEvent

; Floppy 2
33$		cmp.w	#GD_Floppy2,gg_GadgetID(a0)
		bne	34$
		move.w	TheCode,Floppy2
		bra	GetEvent

; Floppys suchen
34$		cmp.w	#GD_SearchFloppys,gg_GadgetID(a0)
		bne	35$
		JSRSELF	SearchFloppys
		bsr	DrawFloppyGads
		bra	GetEvent

; Boot from
35$		cmp.w	#GD_BootFrom,gg_GadgetID(a0)
		bne	36$
		move.w	TheCode,BootFrom
		bra	GetEvent

; Inhibit Floppy 1
36$		cmp.w	#GD_InhibitFloppy1,gg_GadgetID(a0)
		bne	37$
		not.w	InhibitFloppy1
		bra	GetEvent

; Inhibit Floppy 2
37$		cmp.w	#GD_InhibitFloppy2,gg_GadgetID(a0)
		bne	38$
		not.w	InhibitFloppy2
		bra	GetEvent

; Use SCC serial
38$		cmp.w	#GD_UseSCCSerial,gg_GadgetID(a0)
		bne	40$
		not.w	UseSCCSerial
		bsr	GhostSerial
		bra	GetEvent

; Serieller Treiber Modemport Auswahl
40$		cmp.w	#GD_GetSERDA,gg_GadgetID(a0)
		bne	41$

		lea	SetSERDATags,a2
		lea	SERDNameA,a3
		lea	DevsName,a4
		move.l	SerialWnd,a5
		move.w	#GDX_SERDNameA,d4
		move.l	#MSG_DEVICEHAIL,d5
		bsr	RequestFileGad
		bra	GetEvent

; Serieller Treiber Druckerport Auswahl
41$		cmp.w	#GD_GetSERDB,gg_GadgetID(a0)
		bne	42$

		lea	SetSERDBTags,a2
		lea	SERDNameB,a3
		lea	DevsName,a4
		move.l	SerialWnd,a5
		move.w	#GDX_SERDNameB,d4
		move.l	#MSG_DEVICEHAIL,d5
		bsr	RequestFileGad
		bra	GetEvent

; DeviceDisk 1 Auswahl
42$		cmp.w	#GD_GetADD1,gg_GadgetID(a0)
		bne	43$

		lea	SetADD1Tags,a3
		lea	PartPrefsTab1,a5
		move.w	#GDX_ADDName1*4,d4
		bsr	DoGetPartName
		bra	GetEvent

; DeviceDisk 2 Auswahl
43$		cmp.w	#GD_GetADD2,gg_GadgetID(a0)
		bne	44$

		lea	SetADD2Tags,a3
		lea	PartPrefsTab2,a5
		move.w	#GDX_ADDName2*4,d4
		bsr	DoGetPartName
		bra	GetEvent

; AppleCD Emulation
44$		cmp.w	#GD_AppleCD,gg_GadgetID(a0)
		bne	45$
		not.w	AppleCD
		bra	GetEvent

; Direkte SCSI-Transfers
45$		cmp.w	#GD_SCSIDirect,gg_GadgetID(a0)
		bne	451$
		not.w	SCSIDirect
		bra	GetEvent

; Fastcrap-Modus
451$		cmp.w	#GD_FastCrapMode,gg_GadgetID(a0)
		bne	46$
		not.w	FastCrapMode
		bra	GetEvent

; Netzwerk-Treiber Auswahl
46$		cmp.w	#GD_GetSana2,gg_GadgetID(a0)
		bne	47$

		lea	SetSana2Tags,a2
		lea	Sana2Name,a3
		lea	DevsNetName,a4
		move.l	NetworkWnd,a5
		move.w	#GDX_Sana2Name,d4
		move.l	#MSG_DEVICEHAIL,d5
		bsr	RequestFileGad
		bra	GetEvent

; SCSI-Speichertyp
47$		cmp.w	#GD_SCSIMemType,gg_GadgetID(a0)
		bne	48$
		move.w	TheCode,SCSIMemType
		bra	GetEvent

; ROM-Speichertyp
48$		cmp.w	#GD_ROMMemType,gg_GadgetID(a0)
		bne	49$
		move.w	TheCode,ROMMemType
		bra	GetEvent

; AppleHD Emulation
49$		cmp.w	#GD_AppleHD,gg_GadgetID(a0)
		bne	50$
		not.w	AppleHD
		bra	GetEvent

; SCSI ID 0
50$		cmp.w	#GD_SCSI0,gg_GadgetID(a0)
		bne	51$
		bchg	#0,SCSIEnable
		bra	GetEvent

; SCSI ID 1
51$		cmp.w	#GD_SCSI1,gg_GadgetID(a0)
		bne	52$
		bchg	#1,SCSIEnable
		bra	GetEvent

; SCSI ID 2
52$		cmp.w	#GD_SCSI2,gg_GadgetID(a0)
		bne	53$
		bchg	#2,SCSIEnable
		bra	GetEvent

; SCSI ID 3
53$		cmp.w	#GD_SCSI3,gg_GadgetID(a0)
		bne	54$
		bchg	#3,SCSIEnable
		bra	GetEvent

; SCSI ID 4
54$		cmp.w	#GD_SCSI4,gg_GadgetID(a0)
		bne	55$
		bchg	#4,SCSIEnable
		bra	GetEvent

; SCSI ID 5
55$		cmp.w	#GD_SCSI5,gg_GadgetID(a0)
		bne	56$
		bchg	#5,SCSIEnable
		bra	GetEvent

; SCSI ID 6
56$		cmp.w	#GD_SCSI6,gg_GadgetID(a0)
		bne	57$
		bchg	#6,SCSIEnable
		bra	GetEvent

; ROM schreibschützen
57$		cmp.w	#GD_ProtectROM,gg_GadgetID(a0)
		bne	581$
		not.w	ProtectROM
		bra	GetEvent

; MacOS-8-Modus
581$		cmp.w	#GD_MacOS8Mode,gg_GadgetID(a0)
		bne	58$
		not.w	MacOS8Mode
		bra	GetEvent

; Tonausgabe ein
58$		cmp.w	#GD_AudioOn,gg_GadgetID(a0)
		bne	59$
		not.w	AudioOn
		bsr	GhostMisc
		bra	GetEvent

; AHI benutzen
59$		cmp.w	#GD_UseAHI,gg_GadgetID(a0)
		bne	590$
		not.w	UseAHI
		bsr	GhostMisc
		bra	GetEvent

; Audio-Mode-Auswahl
590$		cmp.w	#GD_GetAudioID,gg_GadgetID(a0)
		bne	4$
		move.l	_AHIBase,d0
		beq	GetEvent

		move.l	d0,a6
		move.l	MiscWnd,AudioReqWindow
		lea	AudioReqTags,a0
		jsr	_LVOAHI_AllocAudioRequestA(a6)
		move.l	d0,d6			;d6: AudioRequest
		beq	GetEvent

		move.l	d6,a0
		move.l	AudioID,AudioReqID
		lea	DoAudioReqTags,a1
		jsr	_LVOAHI_AudioRequestA(a6)
		tst.l	d0
		beq	591$
		move.l	d6,a0
		move.l	ahiam_AudioID(a0),AudioID

591$		move.l	d6,a0
		jsr	_LVOAHI_FreeAudioRequest(a6)

		bsr	SetAudioIDGad
		bra	GetEvent

; Screenmode-Auswahl 1
4$		cmp.w	#GD_GetDisplayID1,gg_GadgetID(a0)
		bne	5$
		move.w	VideoType1,d0
		lea	DIDPrefsTab1,a5
		bsr	RequestDID
		tst.l	d0
		beq	GetEvent

		move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a4
		move.l	GDX_VideoMode1*4(a4),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		lea	SetCycleTags,a3
		moveq	#0,d0
		move.w	VideoMode1,d0
		move.l	d0,SetCycTagsVal
		JSRLIB	GT_SetGadgetAttrsA
		bra	GetEvent

; Screenmode-Auswahl 2
5$		cmp.w	#GD_GetDisplayID2,gg_GadgetID(a0)
		bne	6$
		move.w	VideoType2,d0
		lea	DIDPrefsTab2,a5
		bsr	RequestDID
		tst.l	d0
		beq	GetEvent

		move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a4
		move.l	GDX_VideoMode2*4(a4),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		lea	SetCycleTags,a3
		moveq	#0,d0
		move.w	VideoMode2,d0
		move.l	d0,SetCycTagsVal
		JSRLIB	GT_SetGadgetAttrsA
		bra	GetEvent

; FileDisk 1 Auswahl
6$		cmp.w	#GD_GetAFDName1,gg_GadgetID(a0)
		bne	7$

		lea	SetAFD1Tags,a3
		lea	AFDFileName1,a4
		move.w	#GDX_AFDName1*4,d4
		bsr	DoGetAFDName
		bra	GetEvent

; FileDisk 2 Auswahl
7$		cmp.w	#GD_GetAFDName2,gg_GadgetID(a0)
		bne	70$

		lea	SetAFD2Tags,a3
		lea	AFDFileName2,a4
		move.w	#GDX_AFDName2*4,d4
		bsr	DoGetAFDName
		bra	GetEvent

; FileDisk 1 anlegen
70$		cmp.w	#GD_MakeAFD1,gg_GadgetID(a0)
		bne	71$

		lea	SetAFD1Tags,a3
		lea	AFDFileName1,a4
		move.w	#GDX_AFDName1*4,d4
		bsr	DoMakeAFD
		bra	GetEvent

; FileDisk 2 anlegen
71$		cmp.w	#GD_MakeAFD2,gg_GadgetID(a0)
		bne	72$

		lea	SetAFD2Tags,a3
		lea	AFDFileName2,a4
		move.w	#GDX_AFDName2*4,d4
		bsr	DoMakeAFD
		bra	GetEvent

; Auswahl externer Videotreiber
72$		cmp.w	#GD_GetVideoName1,gg_GadgetID(a0)
		bne	73$

		lea	SetExtVideo1Tags,a2
		lea	ExtVideoName1,a3
		lea	EVDDirName,a4
		move.l	GraphicsWnd,a5
		move.w	#GDX_ExtVideoName1,d4
		move.l	#MSG_EXTVIDEOHAIL,d5
		bsr	RequestFileGad
		bra	GetEvent

73$		cmp.w	#GD_GetVideoName2,gg_GadgetID(a0)
		bne	8$

		lea	SetExtVideo2Tags,a2
		lea	ExtVideoName2,a3
		lea	EVDDirName,a4
		move.l	GraphicsWnd,a5
		move.w	#GDX_ExtVideoName2,d4
		move.l	#MSG_EXTVIDEOHAIL,d5
		bsr	RequestFileGad
		bra	GetEvent

; Einstellungen speichern
8$		cmp.w	#GD_SavePrefs,gg_GadgetID(a0)
		bne	10$
		bsr	SaveThePrefs
		bra	GetEvent

10$		bra	GetEvent

; Menüs
NotGadget	move.l	TheClass,d0
		and.l	#IDCMP_MENUPICK,d0
		beq	NotMenu
		move.w	TheCode,d0
		cmp.w	#MENUNULL,d0
		beq	GetEvent
		move.b	d0,d1		;d1.b: Menünummer
		and.b	#$1f,d1
		move.w	d0,d2		;d2.b: Itemnummer
		lsr.w	#5,d2
		and.b	#$3f,d2

		tst.b	d1
		bne	GetEvent

		tst.b	d2
		bne	1$
		bsr	OpenThePrefsAs	;Open
		bra	GetEvent

1$		cmp.b	#2,d2
		bne	2$
		bsr	SaveThePrefs	;Save
		bra	GetEvent

2$		cmp.b	#3,d2
		bne	3$
		bsr	SaveConfigAs	;Save As
		bra	GetEvent

3$		cmp.b	#5,d2
		bne	4$
		bsr	DoAbout		;About
		bra	GetEvent

4$		cmp.b	#7,d2
		bne	5$
		moveq	#1,d7		;Starten
		bra	WindowDone

5$		cmp.b	#8,d2
		bne	GetEvent
		moveq	#-1,d7		;Quit
		bra	WindowDone

; VanillaKey
NotMenu		move.l	TheClass,d0
		and.l	#IDCMP_VANILLAKEY,d0
		beq	NotKey

		cmp.w	#9,TheCode		;Tab - naechster Tab
		bne	90$
		jsr	NextTab
		bra	GetEvent
90$

		cmp.w	#'r',TheCode		;r - Starten
		bne	1$
		moveq	#1,d7
		bra	WindowDone

1$		cmp.w	#'s',TheCode		;s - Speichern
		bne	2$
		bsr	SaveThePrefs
		bra	GetEvent

2$		cmp.w	#'e',TheCode		;e - Beenden
		bne	3$
		moveq	#-1,d7
		bra	WindowDone

3$		cmp.w	#'g',TheCode		;g - Grafik
		bne	4$
		moveq	#0,d0			;Tab "Graphics"
		jsr	SwitchTab
		bra	GetEvent

4$		cmp.w	#'d',TheCode		;d - Datenträger
		bne	5$
		moveq	#1,d0			;Tab "Volumes"
		jsr	SwitchTab
		bra	GetEvent

5$		cmp.w	#'c',TheCode		;c - SCSI
		bne	6$
		moveq	#3,d0			;Tab "SCSI"
		jsr	SwitchTab
		bra	GetEvent

6$		cmp.w	#'l',TheCode		;l - Seriell
		bne	7$
		moveq	#5,d0			;Tab "Serial"
		jsr	SwitchTab
		bra	GetEvent

7$		cmp.w	#'n',TheCode		;n - Netzwerk
		bne	8$
		moveq	#6,d0			;Tab "Network"
		jsr	SwitchTab
		bra	GetEvent

8$		cmp.w	#'o',TheCode		;o - Sonstiges
		bne	9$
		moveq	#7,d0			;Tab "Misc"
		jsr	SwitchTab
		bra	GetEvent

9$		cmp.w	#'p',TheCode		;p - Speicher
		bne	10$
		moveq	#4,d0			;Tab "Memory"
		jsr	SwitchTab
		bra	GetEvent

10$		cmp.w	#'f',TheCode		;f - Diskettenlaufwerke
		bne	GetEvent
		moveq	#2,d0			;Tab "Floppy"
		jsr	SwitchTab
		bra	GetEvent

; Mausklick: Tab waehlen
NotKey		move.l	TheClass,d0
		and.l	#IDCMP_MOUSEBUTTONS,d0
		beq	NotMouse
		cmp.w	#SELECTDOWN,TheCode
		bne	GetEvent
		move.w	TheMouseX,d0
		move.w	TheMouseY,d1
		jsr	TabClick
		bra	GetEvent

; Gadget-Hilfe: eine Zeile im Fenstertitel
NotMouse	move.l	TheClass,d0
		and.l	#IDCMP_GADGETHELP,d0
		beq	NotHelp
		move.l	TheGadget,a0
		jsr	GadgetHelp
		bra	GetEvent

; Refresh
NotHelp		move.l	TheClass,d0
		and.l	#IDCMP_REFRESHWINDOW,d0
		beq	NotRefresh
		move.l	TheWindow,a0
		JSRLIB	GT_BeginRefresh
		move.l	TheWindow,a0
		moveq	#-1,d0
		JSRLIB	GT_EndRefresh
		bra	GetEvent

; CloseWindow: Beenden
NotRefresh	move.l	TheClass,d0
		and.l	#IDCMP_CLOSEWINDOW,d0
		beq	GetEvent
		moveq	#-1,d7
		bra	WindowDone

; CTRL-C empfangen: Beenden
ReceivedCtrlC	moveq	#-1,d7
		bra	WindowDone

; CTRL-F empfangen: Fenster aktivieren und nach vorne holen
ReceivedCtrlF	move.l	_IntuitionBase,a6
		move.l	SettingsWnd,a0
		JSRLIB	ActivateWindow
		move.l	SettingsWnd,a0
		JSRLIB	WindowToFront
		bra	EventLoop

; Fenster schließen, Parameter aus den String-/Integer-Gadgets holen
WindowDone	bsr	CloseGraphicsWnd
		bsr	CloseVolumesWnd
		bsr	CloseFloppyWnd
		bsr	CloseSCSIWnd
		bsr	CloseMemoryWnd
		bsr	CloseMiscWnd
		bsr	CloseSerialWnd
		bsr	CloseNetworkWnd
		jsr	CloseCPUWnd
		jsr	CloseTabWindow
		jsr	CloseDownScreen
		moveq	#0,d0
		tst.l	d7
		bmi	1$
		moveq	#1,d0
1$		rts


**
** Strings in Datenstrukturen lokalisieren
**

GetStr		MACRO	;Label
		lea	TheLocale,a0
		move.l	#\1,d0
		jsr	GetString
		ENDM

SetScrTitle	MACRO	;Fenstername
		lea	\1WindowTags,a0
		move.l	#WA_ScreenTitle,d0
		JSRLIB	FindTagItem
		move.l	d0,a0
		move.l	d2,4(a0)
		ENDM

SetWndTitle	MACRO	;Fenstername
		lea	\1WindowTags,a0
		move.l	#WA_Title,d0
		JSRLIB	FindTagItem
		move.l	d0,a0
		move.l	d2,4(a0)
		ENDM

LocalizePrefs	move.l	_UtilityBase,a6

		GetStr	MSG_SCREENTITLE
		move.l	d0,d2
		SetScrTitle	Settings
		SetScrTitle	EnterSize

		GetStr	MSG_MAINTITLE
		move.l	d0,d2
		SetWndTitle	Settings

		GetStr	MSG_SIZETITLE
		move.l	d0,d2
		SetWndTitle	EnterSize

		GetStr	MSG_REQTITLE
		move.l	d0,BadPartReq+es_Title
		move.l	d0,BadAFDReq+es_Title
		move.l	d0,No16BitModeReq+es_Title

		GetStr	MSG_ABOUTTITLE
		move.l	d0,AboutReq+es_Title

		GetStr	MSG_ABOUT_REQ
		move.l	d0,AboutReq+es_TextFormat

		GetStr	MSG_BADPART
		move.l	d0,BadPartReq+es_TextFormat

		GetStr	MSG_BADAFD
		move.l	d0,BadAFDReq+es_TextFormat

		GetStr	MSG_NO16BITMODE
		move.l	d0,No16BitModeReq+es_TextFormat

		GetStr	MSG_REQGADSOK
		move.l	d0,BadPartReq+es_GadgetFormat
		move.l	d0,BadAFDReq+es_GadgetFormat
		move.l	d0,No16BitModeReq+es_GadgetFormat
		move.l	d0,AboutReq+es_GadgetFormat

		GetStr	MSG_PARTHAIL
		move.l	d0,PartHailText

		GetStr	MSG_SCREENHAIL
		move.l	d0,ScreenHailText
		move.l	d0,CyberHailText

		lea	VideoMode1Labels,a2
		lea	VideoMode2Labels,a3
		GetStr	MSG_MODE1_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+
		GetStr	MSG_MODE2_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+
		GetStr	MSG_MODE4_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+
		GetStr	MSG_MODE8_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+
		GetStr	MSG_MODE15_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+
		GetStr	MSG_MODE24_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+

		lea	VideoType1Labels,a2
		lea	VideoType2Labels,a3
		GetStr	MSG_TYPEAMIGA_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+
		GetStr	MSG_TYPECYBER_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+
		GetStr	MSG_TYPEEGS_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+
		GetStr	MSG_TYPEMACINABOX_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+
		GetStr	MSG_TYPEEXTERNAL_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+

		lea	NumMonitorsLabels,a2
		GetStr	MSG_ONEMONITOR_LAB
		move.l	d0,(a2)+
		GetStr	MSG_TWOMONITORS_LAB
		move.l	d0,(a2)+

		lea	Floppy1Labels,a2
		lea	Floppy2Labels,a3
		GetStr	MSG_DFNONE_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+
		GetStr	MSG_DF0_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+
		GetStr	MSG_DF1_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+
		GetStr	MSG_DF2_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+
		GetStr	MSG_DF3_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+
		GetStr	MSG_PH0_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+
		GetStr	MSG_PH1_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+

		lea	BootFromLabels,a2
		GetStr	MSG_BOOTLAST_LAB
		move.l	d0,(a2)+
		GetStr	MSG_BOOTANY_LAB
		move.l	d0,(a2)+
		GetStr	MSG_BOOTFILEDISK1_LAB
		move.l	d0,(a2)+
		GetStr	MSG_BOOTDEVICEDISK1_LAB
		move.l	d0,(a2)+
		GetStr	MSG_BOOTCDROM_LAB
		move.l	d0,(a2)+

		lea	SCSIMemTypeLabels,a2
		lea	ROMMemTypeLabels,a3
		GetStr	MSG_MEMCHIP_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+
		GetStr	MSG_MEM24BITDMA_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+
		GetStr	MSG_MEMANY_LAB
		move.l	d0,(a2)+
		move.l	d0,(a3)+

		lea	SettingsNewMenu0,a2
		GetStr	MSG_PROJECT_MENU
		move.l	d0,gnm_Label(a2)
		lea	gnm_SIZEOF(a2),a2
		GetStr	MSG_OPEN_MENU
		move.l	d0,gnm_Label(a2)
		lea	gnm_SIZEOF*2(a2),a2
		GetStr	MSG_SAVE_MENU
		move.l	d0,gnm_Label(a2)
		lea	gnm_SIZEOF(a2),a2
		GetStr	MSG_SAVEAS_MENU
		move.l	d0,gnm_Label(a2)
		lea	gnm_SIZEOF*2(a2),a2
		GetStr	MSG_ABOUT_MENU
		move.l	d0,gnm_Label(a2)
		lea	gnm_SIZEOF*2(a2),a2
		GetStr	MSG_START_MENU
		move.l	d0,gnm_Label(a2)
		lea	gnm_SIZEOF(a2),a2
		GetStr	MSG_QUIT_MENU
		move.l	d0,gnm_Label(a2)

		lea	SettingsTrTab,a2
		lea	SettingsNGads,a3
		bsr	LocalizeGads
		lea	GraphicsTrTab,a2
		bsr	LocalizeGads
		lea	VolumesTrTab,a2
		bsr	LocalizeGads
		lea	MiscTrTab,a2
		bsr	LocalizeGads
		lea	SerialTrTab,a2
		bsr	LocalizeGads
		lea	NetworkTrTab,a2
		bsr	LocalizeGads
		lea	SCSITrTab,a2
		bsr	LocalizeGads
		lea	MemoryTrTab,a2
		bsr	LocalizeGads
		lea	FloppyTrTab,a2
		bsr	LocalizeGads
		lea	EnterSizeTrTab,a2
		bsr	LocalizeGads
		rts

LocalizeGads	lea	TheLocale,a0
		move.l	(a2)+,d0
		beq	2$
		jsr	GetString
		move.l	(a2)+,d1
		mulu.l	#gng_SIZEOF,d1
		move.l	d0,gng_GadgetText(a3,d1.w)
		bra	LocalizeGads
2$		rts

SettingsTrTab	dc.l	MSG_START_GAD,GDX_OK
		dc.l	MSG_SAVE_GAD,GDX_SavePrefs
		dc.l	MSG_QUIT_GAD,GDX_Cancel
		dc.l	MSG_OPENGRAPHICS_GAD,GDX_OpenGraphics
		dc.l	MSG_OPENVOLUMES_GAD,GDX_OpenVolumes
		dc.l	MSG_OPENFLOPPY_GAD,GDX_OpenFloppy
		dc.l	MSG_OPENSCSI_GAD,GDX_OpenSCSI
		dc.l	MSG_OPENMEMORY_GAD,GDX_OpenMemory
		dc.l	MSG_OPENSERIAL_GAD,GDX_OpenSerial
		dc.l	MSG_OPENNETWORK_GAD,GDX_OpenNetwork
		dc.l	MSG_OPENMISC_GAD,GDX_OpenMisc
		dc.l	0

GraphicsTrTab	dc.l	MSG_VIDEOMODE_GAD,GDX_VideoMode1
		dc.l	MSG_VIDEOTYPE_GAD,GDX_VideoType1
		dc.l	MSG_EXTVIDEONAME_GAD,GDX_ExtVideoName1
		dc.l	MSG_GETDISPLAYID_GAD,GDX_GetDisplayID1
		dc.l	MSG_GETDISPLAYID_GAD,GDX_GetDisplayID2
		dc.l	MSG_DISPLAYID_GAD,GDX_DisplayID1
		dc.l	MSG_SCREENX_GAD,GDX_ScreenX1
		dc.l	MSG_SCREENY_GAD,GDX_ScreenY1
		dc.l	MSG_SCREENY_GAD,GDX_ScreenY2
		dc.l	MSG_REFRESHRATE_GAD,GDX_RefreshRate
		dc.l	MSG_BLACKBORDER_GAD,GDX_BlackBorder
		dc.l	MSG_REFRESHALWAYS_GAD,GDX_RefreshAlways
		dc.l	MSG_MMUREFRESH_GAD,GDX_MMURefresh
		dc.l	MSG_USEAMIGAMOUSE_GAD,GDX_UseAmigaMouse
		dc.l	0

VolumesTrTab	dc.l	MSG_AFDNAME1_GAD,GDX_AFDName1
		dc.l	MSG_AFDNAME2_GAD,GDX_AFDName2
		dc.l	MSG_MAKEAFD_GAD,GDX_MakeAFD1
		dc.l	MSG_MAKEAFD_GAD,GDX_MakeAFD2
		dc.l	MSG_ADDNAME1_GAD,GDX_ADDName1
		dc.l	MSG_ADDUNIT_GAD,GDX_ADDUnit1
		dc.l	MSG_ADDSTARTSECTOR_GAD,GDX_ADDStartSector1
		dc.l	MSG_ADDSECTORS_GAD,GDX_ADDSectors1
		dc.l	MSG_ADDMAXTRANSFER_GAD,GDX_ADDMaxTransfer1
		dc.l	MSG_ADDREMOVABLE_GAD,GDX_ADDRemovable1
		dc.l	MSG_GETADD_GAD,GDX_GetADD1
		dc.l	MSG_ADDNAME2_GAD,GDX_ADDName2
		dc.l	MSG_ADDUNIT_GAD,GDX_ADDUnit2
		dc.l	MSG_ADDSTARTSECTOR_GAD,GDX_ADDStartSector2
		dc.l	MSG_ADDSECTORS_GAD,GDX_ADDSectors2
		dc.l	MSG_ADDMAXTRANSFER_GAD,GDX_ADDMaxTransfer2
		dc.l	MSG_ADDREMOVABLE_GAD,GDX_ADDRemovable2
		dc.l	MSG_GETADD_GAD,GDX_GetADD2
		dc.l	MSG_BOOTFROM_GAD,GDX_BootFrom
		dc.l	0

MiscTrTab	dc.l	MSG_MOUSEDIRECT_GAD,GDX_MouseDirect
		dc.l	MSG_PROTECTROM_GAD,GDX_ProtectROM
		dc.l	MSG_MACOS8MODE_GAD,GDX_MacOS8Mode
		dc.l	MSG_AUDIOON_GAD,GDX_AudioOn
		dc.l	MSG_USEAHI_GAD,GDX_UseAHI
		dc.l	MSG_GETAUDIOID_GAD,GDX_GetAudioID
		dc.l	MSG_AUDIOID_GAD,GDX_AudioID
		dc.l	0

SerialTrTab	dc.l	MSG_SERDNAMEA_GAD,GDX_SERDNameA
		dc.l	MSG_SERDUNIT_GAD,GDX_SERDUnitA
		dc.l	MSG_SERDISPAR_GAD,GDX_SERDAIsPar
		dc.l	MSG_GETSERD_GAD,GDX_GetSERDA
		dc.l	MSG_SERDNAMEB_GAD,GDX_SERDNameB
		dc.l	MSG_SERDUNIT_GAD,GDX_SERDUnitB
		dc.l	MSG_SERDISPAR_GAD,GDX_SERDBIsPar
		dc.l	MSG_GETSERD_GAD,GDX_GetSERDB
		dc.l	MSG_USESCCSERIAL_GAD,GDX_UseSCCSerial
		dc.l	0

NetworkTrTab	dc.l	MSG_SANA2NAME_GAD,GDX_Sana2Name
		dc.l	MSG_SANA2UNIT_GAD,GDX_Sana2Unit
		dc.l	MSG_GETSANA2_GAD,GDX_GetSana2
		dc.l	0

SCSITrTab	dc.l	MSG_SCSINAME_GAD,GDX_SCSIName0
		dc.l	MSG_SCSIUNIT_GAD,GDX_SCSIUnit0
		dc.l	MSG_SCSIMEMTYPE_GAD,GDX_SCSIMemType
		dc.l	MSG_APPLECD_GAD,GDX_AppleCD
		dc.l	MSG_APPLEHD_GAD,GDX_AppleHD
		dc.l	MSG_SCSIDIRECT_GAD,GDX_SCSIDirect
		dc.l	MSG_FASTCRAPMODE_GAD,GDX_FastCrapMode
		dc.l	0

MemoryTrTab	dc.l	MSG_MEMSIZE_GAD,GDX_MemSize
		dc.l	MSG_MEMMAX_GAD,GDX_MemMax
		dc.l	MSG_LARGESTBLOCK_GAD,GDX_LargestBlock
		dc.l	MSG_FASTROM_GAD,GDX_FastROM
		dc.l	MSG_ROMMEMTYPE_GAD,GDX_ROMMemType
		dc.l	0

FloppyTrTab	dc.l	MSG_FLOPPY1_GAD,GDX_Floppy1
		dc.l	MSG_FLOPPY2_GAD,GDX_Floppy2
		dc.l	MSG_SEARCHFLOPPYS_GAD,GDX_SearchFloppys
		dc.l	MSG_INHIBITFLOPPY_GAD,GDX_InhibitFloppy1
		dc.l	MSG_INHIBITFLOPPY_GAD,GDX_InhibitFloppy2
		dc.l	0

EnterSizeTrTab	dc.l	MSG_SIZEKB_GAD,GDX_SizeKB
		dc.l	MSG_SIZEOK_GAD,GDX_SizeOK
		dc.l	MSG_SIZECANCEL_GAD,GDX_SizeCancel
		dc.l	0


**
** Unterprogramme
**

; Einstellungen laden (Dateirequester)
OpenThePrefsAs	lea	PrefsName,a0		;(the name in use, in case the file is refused)
		lea	OpenKeepName,a1
		move.w	#255,d0
2$		move.b	(a0)+,(a1)+
		dbra	d0,2$
		lea	PrefsName,a3
		lea	PrefsName,a4
		move.l	SettingsWnd,a5
		move.l	#MSG_PREFSHAIL,d5
		bsr	RequestFile
		tst.l	d0
		beq	1$

		bsr	LoadConfig		;Laden und anzeigen
		tst.b	PrefsBad		;Refused: "Save" must not write over that file
		beq	1$
		movem.l	d0/a0-a1,-(sp)
		lea	OpenKeepName,a0
		lea	PrefsName,a1
		move.w	#255,d0
3$		move.b	(a0)+,(a1)+
		dbra	d0,3$
		movem.l	(sp)+,d0/a0-a1
1$		rts

; Configuration chosen in the settings window: load PrefsName, show it
LoadConfig	movem.l	d0-d7/a0-a6,-(sp)
		bsr	OpenThePrefs
		bra	LCShow
; Show the settings as they are in memory
ShowConfig	movem.l	d0-d7/a0-a6,-(sp)
LCShow		bsr	SetGraphicsGads
		bsr	SetVolumesGads
		bsr	SetFloppyGads
		bsr	SetSCSIGads
		bsr	SetMemoryGads
		bsr	SetMiscGads
		bsr	SetSerialGads
		bsr	SetNetworkGads
		jsr	SetCPUGads
		movem.l	(sp)+,d0-d7/a0-a6
		rts

; "Save as..." of the settings window. d0 = 0: cancelled
SaveConfigAs	movem.l	d1-d7/a0-a6,-(sp)
		lea	PrefsName,a3
		lea	PrefsName,a4
		move.l	SettingsWnd,a5
		move.l	#MSG_PREFSHAIL,d5
		bsr	RequestFile
		tst.l	d0
		beq	1$
		bsr	SaveThePrefs		;(0 when it could not be saved)
1$		movem.l	(sp)+,d1-d7/a0-a6
		rts

; Einstellungen laden
OpenThePrefs	clr.b	PrefsBad
		move.l	_DOSBase,a6		;Datei öffnen
		move.l	#PrefsName,d1
		move.l	#MODE_OLDFILE,d2
		JSRLIB	Open
		move.l	d0,d7
		beq	1$

		movem.l	d2-d3/d6,-(sp)
		move.l	d7,d1			;Daten lesen (first into a buffer)
		move.l	#PrefsLoadBuf,d2
		move.l	#EmulPrefsEnd,d3
		sub.l	#EmulPrefs,d3
		cmp.l	#PREFSBUFSIZE,d3
		bls	10$
		move.l	#PREFSBUFSIZE,d3
10$		JSRLIB	Read
		move.l	d0,d6			;d6: bytes read
		move.l	d7,d1			;A settings file is a few KB: anything large is
		moveq	#0,d2			; something else (a Mac disk image, say)
		moveq	#OFFSET_END,d3
		JSRLIB	Seek
		move.l	d7,d1
		moveq	#0,d2
		moveq	#OFFSET_CURRENT,d3
		JSRLIB	Seek			;d0: length of the file
		cmp.l	#PREFSMAXSIZE,d0
		bls	101$
		moveq	#0,d6
101$

		move.l	d7,d1			;Datei schließen
		JSRLIB	Close

; Not a settings file (too short, or an impossible screen size): keep the
; current settings and say so.
		cmp.l	#PREFSMINSIZE,d6
		blt	11$
		lea	PrefsLoadBuf,a0
		cmp.l	#16384,16(a0)		;ScreenX1
		bhi	11$
		cmp.l	#16384,20(a0)		;ScreenY1
		bls	12$
11$		movem.l	(sp)+,d2-d3/d6
		st.b	PrefsBad
		move.l	a3,-(sp)
		pea	PrefsName
		move.l	sp,a3
		move.l	#MSG_BADPREFS_TXT,d0
		move.l	#MSG_REQGADSOK,d1
		jsr	SReq
		addq.l	#4,sp
		move.l	(sp)+,a3
		rts

; Take what the file has; what an older, shorter file lacks is cleared, so
; nothing of the previous configuration stays behind.
12$		lea	EmulPrefs,a1
13$		cmp.l	#EmulPrefsEnd,a1
		bhs	15$
		subq.l	#1,d6
		bmi	14$
		move.b	(a0)+,(a1)+
		bra	13$
14$		clr.b	(a1)+
		bra	13$
15$		tst.l	d6			;A file from before "Advanced" (shorter):
		bpl	151$			; its owner knows all the pages
		move.w	#-1,OptAdvanced
151$		lea	PrefsNameTab,a0		;every name field ends within its 80 bytes
16$		move.l	(a0)+,d0
		beq	17$
		move.l	d0,a1
		clr.b	79(a1)
		bra	16$
17$		movem.l	(sp)+,d2-d3/d6

		cmp.w	#VTYPE_EXTERNAL,VideoType1
		bls	2$
		move.w	#VTYPE_EXTERNAL,VideoType1
2$
		tst.b	HasRealSCC		;Kein SCC?
		bne	3$
		clr.w	UseSCCSerial		;Dann auch keine SCC-Treiber (wichtig, wegen Ghosting im Prefs-Fenster)
3$
1$		rts

; What the gadgets say goes into the settings in memory
ReadConfig	bsr	GetGraphicsGads
		bsr	GetVolumesGads
		bsr	GetFloppyGads
		bsr	GetSCSIGads
		bsr	GetMemoryGads
		bsr	GetMiscGads
		bsr	GetSerialGads
		bsr	GetNetworkGads
		rts

; Einstellungen unter bestimmtem Namen speichern
; Einstellungen speichern
; The file is written under another name in the same drawer and takes the
; place of the old one only when all of it is there: a full disk leaves the
; old settings as they were. d0 = 0: not saved (the user has been told).
SaveThePrefs	bsr	ReadConfig		;Werte holen

		lea	PrefsName,a0		;The other name: same drawer
		lea	SaveTmpName,a1
5$		move.b	(a0)+,(a1)+
		bne	5$
		move.l	_DOSBase,a6
		move.l	#SaveTmpName,d1
		JSRLIB	FilePart
		move.l	d0,a1
		lea	SaveTmpTail,a0
6$		move.b	(a0)+,(a1)+
		bne	6$

		move.l	#SaveTmpName,d1		;Datei öffnen
		move.l	#MODE_NEWFILE,d2
		JSRLIB	Open
		move.l	d0,d6
		beq	3$

		move.l	d6,d1			;Daten schreiben
		move.l	#EmulPrefs,d2
		move.l	#EmulPrefsEnd,d3
		sub.l	d2,d3
		JSRLIB	Write
		cmp.l	d3,d0			;all of it written?
		sne	d3

		move.l	d6,d1			;Datei schließen
		JSRLIB	Close
		tst.b	d3
		bne	7$			;Not all of it written
		move.l	#PrefsName,d1		;The old file makes room (there may be none)
		JSRLIB	DeleteFile
		move.l	#SaveTmpName,d1
		move.l	#PrefsName,d2
		JSRLIB	Rename
		tst.l	d0
		bne	4$
7$		move.l	#SaveTmpName,d1
		JSRLIB	DeleteFile
		bra	3$
4$

		move.l	_IconBase,a6		;Icon bereits vorhanden?
		lea	PrefsName,a0
		JSRLIB	GetDiskObject
		tst.l	d0
		beq	1$
		move.l	d0,a0			;Ja, dann nichts machen
		JSRLIB	FreeDiskObject
		moveq	#1,d0
		rts

1$		lea	PrefsName,a0		;Nein, Icon erzeugen
		lea	PrefsIcon,a1
		JSRLIB	PutDiskObject
2$		moveq	#1,d0
		rts

3$		move.l	a3,-(sp)		;Not saved: say so
		pea	PrefsName
		move.l	sp,a3
		move.l	#MSG_SAVEFAIL_TXT,d0
		move.l	#MSG_REQGADSOK,d1
		jsr	SReq
		addq.l	#4,sp
		move.l	(sp)+,a3
		moveq	#0,d0
		rts

SaveTmpTail	dc.b	"ShapeShifter.saving",0
		even

; About-Dialog anzeigen
DoAbout		move.l	_IntuitionBase,a6
		sub.l	a0,a0
		lea	AboutReq,a1
		move.l	a0,a2
		lea	VersionNumber,a3
		JSRLIB	EasyRequestArgs
		rts

; Dateiauswahl
; a3: Zeiger auf Zielpuffer für Dateipfad
; a4: Vorgegebener Dateiname (inkl.Pfad)
; a5: Window
; d5: Hailtext (MSG_*)
; Rückgabe d0:  0=Fehler
;              #0=OK
RequestFile	movem.l	d2-d7/a2-a6,-(sp)
		move.l	_AslBase,a6
		move.l	a5,FileReqWindow
		moveq	#ASL_FileRequest,d0
		lea	FileReqTags,a0
		JSRLIB	AllocAslRequest
		move.l	d0,d6			;d6: FileRequester
		beq	RFError

		lea	DirName,a1		;Verzeichnisname in Puffer kopieren
		move.l	a4,a0
		move.w	#254,d0
2$		move.b	(a0)+,(a1)+
		dbeq	d0,2$
		clr.b	DirName+255

		move.l	_DOSBase,a6		;Dateinamen abschneiden
		move.l	#DirName,d1
		JSRLIB	PathPart
		move.l	d0,a0
		clr.b	(a0)

; The file name of the given path is offered as the name: the settings'
; "Save as..." comes with "My setup" (or the name of the configuration in
; use), a disk gadget with the file it shows
		move.l	a4,d1
		JSRLIB	FilePart
		move.l	d0,a0
		lea	FileName,a1
		moveq	#78,d0
3$		move.b	(a0)+,(a1)+
		dbeq	d0,3$
		clr.b	(a1)

		lea	TheLocale,a0		;Hailtext setzen
		move.l	d5,d0
		jsr	GetString
		move.l	d0,FileHailText

		move.l	_AslBase,a6		;Datei erfragen
		move.l	d6,a0
		lea	DoFileReqTags,a1
		JSRLIB	AslRequest
		tst.l	d0
		beq	RFCancel

		move.l	d6,a0			;Verzeichnis und Dateiname zusammensetzen
		move.l	fr_File(a0),a1
		move.l	fr_Drawer(a0),a0
		move.l	a3,a2
		moveq	#80,d0
		cmp.l	#PrefsName,a3		;(der Name der Einstellungsdatei hat 256 Bytes)
		bne	1$
		move.l	#256,d0
1$		bsr	SetPathField
		move.l	d0,d7			;0: Pfad zu lang, wie Abbruch

		move.l	_AslBase,a6
		move.l	d6,a0
		JSRLIB	FreeAslRequest

		move.l	d7,d0
		movem.l	(sp)+,d2-d7/a2-a6
		rts

RFCancel	move.l	_AslBase,a6
		move.l	d6,a0
		JSRLIB	FreeAslRequest

RFError		movem.l	(sp)+,d2-d7/a2-a6
		moveq	#0,d0
		rts

; Pfad aus Verzeichnis und Dateiname in ein Namensfeld setzen
; a0: Verzeichnis, a1: Dateiname, a2: Zielpuffer, d0: dessen Groesse
; Rueckgabe d0: 0 = passt nicht (Meldung gezeigt, Ziel unveraendert)
SetPathField	movem.l	d2-d4/a2-a3/a6,-(sp)
		move.l	d0,d4
		lea	LongPath,a3
		move.w	#255-1,d0
1$		move.b	(a0)+,(a3)+
		dbeq	d0,1$
		clr.b	(a3)
		move.l	_DOSBase,a6
		move.l	#LongPath,d1
		move.l	a1,d2
		move.l	#256,d3
		JSRLIB	AddPart
		tst.l	d0
		beq	3$
		lea	LongPath,a0
		move.l	a0,a1
2$		tst.b	(a1)+
		bne	2$
		sub.l	a0,a1			;Laenge mit Nullbyte
		cmp.l	d4,a1
		bhi	3$
4$		move.b	(a0)+,(a2)+
		bne	4$
		moveq	#-1,d0
5$		movem.l	(sp)+,d2-d4/a2-a3/a6
		rts
3$		subq.l	#1,d4
		move.l	d4,-(sp)		;%ld: Zeichen, die passen
		pea	LongPath		;%s
		move.l	sp,a3
		move.l	#MSG_PATHLONG_TXT,d0
		move.l	#MSG_REQGADSOK,d1
		jsr	SReq
		addq.l	#8,sp
		moveq	#0,d0
		bra	5$

; Dateiauswahl und Stringgadget setzen
; a2: Taglist zum Setzen des Gadgets
; a3: Zeiger auf Zielpuffer für Dateipfad
; a4: Vorgegebener Dateiname (inkl.Pfad)
; a5: Window
; d4: GadgetIndex
; d5: Hailtext (MSG_*)
; Rückgabe d0:  0=Fehler
;              #0=OK
RequestFileGad	bsr	RequestFile
		tst.l	d0
		beq	RFGDone

		move.l	_GadToolsBase,a6	;Gadget neu setzen
		lea	SettingsGadgets,a0
		move.l	0(a0,d4.w*4),a0
		move.l	a5,a1
		move.l	a2,a3			;Tags
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		moveq	#-1,d0
RFGDone		rts

; Screenmode-Auswahl und Gadgets neu setzen (außer VideoMode)
; d0: VideoType
; a5: Zeiger auf
;       0 ^DisplayID
;       4 ^OverscanType
;       8 ^ScreenX
;      12 ^ScreenY
;      16 ^VideoMode
; Rückgabe d0:  0=Fehler
;              #0=OK
RequestDID	cmp.w	#VTYPE_CYBER,d0
		beq	RDIDCyber

		move.l	_AslBase,a6
		move.l	GraphicsWnd,ScreenReqWindow
		moveq	#ASL_ScreenModeRequest,d0
		lea	ScreenReqTags,a0
		JSRLIB	AllocAslRequest
		move.l	d0,d6			;d6: ScreenRequester
		beq	RDIDErr

		move.l	d6,a0
		move.l	([a5]),ScreenReqID
		move.w	([4,a5]),ScreenReqOScan+2
		lea	DoScreenReqTags,a1
		JSRLIB	AslRequest
		tst.l	d0
		beq	RDIDErr

		move.l	d6,a0
		move.l	sm_DisplayID(a0),([a5])
		move.w	sm_OverscanType(a0),([4,a5])

		move.l	d6,a0
		JSRLIB	FreeAslRequest
		bsr	SetDisplayIDGads

RDIDSetXY	move.l	_IntuitionBase,a6
		move.l	([a5]),a0		;DisplayID
		lea	TheRect,a1
		moveq	#0,d0
		move.w	([4,a5]),d0		;OverscanType
		JSRLIB	QueryOverscan
		tst.l	d0
		beq	RDIDErr

		lea	TheRect,a0
		moveq	#0,d0
		move.w	ra_MaxX(a0),d0
		sub.w	ra_MinX(a0),d0
		addq.w	#1,d0
		move.l	d0,([8,a5])		;ScreenX
		move.w	ra_MaxY(a0),d0
		sub.w	ra_MinY(a0),d0
		addq.w	#1,d0
		move.l	d0,([12,a5])		;ScreenY
		bsr	SetDisplayXYGads
		moveq	#-1,d0
		rts

RDIDCyber	jsr	OpenCyberGfx		;CyberGfx
		beq	RDIDErr

		move.l	_CyberGfxBase,a6
		sub.l	a0,a0
		lea	DoCyberReqTags,a1
		move.l	Scr,CyberReqScreen
		jsr	CModeRequest(a6)
		tst.l	d0
		beq	RDIDErr

		move.l	d0,([a5])
		move.w	#OSCAN_TEXT,([4,a5])
		bsr	SetDisplayIDGads

		move.l	_CyberGfxBase,a6
		move.l	#CYBRIDATTR_DEPTH,d0
		move.l	([a5]),d1		;DisplayID
		jsr	GetCyberIDAttr(a6)

		cmp.l	#16,d0			;16 Bit nur als RGB565 (wird umgerechnet)
		bne	19$
		move.l	#CYBRIDATTR_PIXFMT,d0
		move.l	([a5]),d1
		jsr	GetCyberIDAttr(a6)
		cmp.l	#PIXFMT_RGB16,d0
		beq	18$
		cmp.l	#PIXFMT_RGB16PC,d0
		bne	RDIDNo16Bit
		bsr	PrismOffer15		;PrismRTG: 15 Bit ist schneller
18$		move.w	#VMODE_15BIT,([16,a5])
		bra	12$
19$
		cmp.l	#8,d0
		bne	10$
		move.w	#VMODE_8BIT,([16,a5])	;VideoMode
		bra	12$
10$		cmp.l	#15,d0
		bne	11$
		move.w	#VMODE_15BIT,([16,a5])
		bra	12$
11$		move.w	#VMODE_24BIT,([16,a5])
12$		bra	RDIDSetXY

; PrismRTG: zu einem 16-Bit-Modus (RGB565, muss umgerechnet werden) den
; 15-Bit-Modus derselben Groesse anbieten, in den der Mac direkt zeichnet.
; Prism-ModeIDs: Bits 8-15 = Tiefe (1: 16 Bit, 4: 15 Bit), Bits 0-7 = Groesse.
; a5: wie RequestDID (0: ^DisplayID)
PrismOffer15	movem.l	d0-d2/a0-a3/a6,-(sp)
		move.l	_CyberGfxBase,a6
		JSRSELF	IsPrism
		beq	9$
		move.l	([a5]),d2
		and.l	#$FFFF00FF,d2
		or.l	#$00000400,d2		;d2: der 15-Bit-Modus
		move.l	_GfxBase,a6
		move.l	d2,d0
		JSRLIB	FindDisplayInfo
		tst.l	d0
		beq	5$
		move.l	_CyberGfxBase,a6
		move.l	#CYBRIDATTR_DEPTH,d0
		move.l	d2,d1
		jsr	GetCyberIDAttr(a6)
		cmp.l	#15,d0
		bne	5$
		move.l	#MSG_PRISM15_TXT,d0	;Nehmen?
		move.l	#MSG_PRISM15_GADS,d1
		sub.l	a3,a3
		jsr	SReq
		cmp.l	#1,d0
		bne	9$
		move.l	d2,([a5])
		bsr	SetDisplayIDGads
		bra	9$
5$		move.l	#MSG_PRISM15OFF_TXT,d0	;Prism hat 15 Bit aus
		move.l	#MSG_REQGADSOK,d1
		sub.l	a3,a3
		jsr	SReq
9$		movem.l	(sp)+,d0-d2/a0-a3/a6
		rts

RDIDNo16Bit	move.l	_IntuitionBase,a6
		sub.l	a0,a0
		lea	No16BitModeReq,a1
		move.l	a0,a2
		move.l	a0,a3
		JSRLIB	EasyRequestArgs
		;fällt durch!
RDIDErr		moveq	#0,d0
		rts

; GetAFDName-Gadget handhaben
; a3: SetAFDTags
; a4: AFDFileName
; d4: GadgetIndex*4
DoGetAFDName	clr.l	FileReqResponse

		move.l	_AslBase,a6
		move.l	VolumesWnd,FileReqWindow
		moveq	#ASL_FileRequest,d0
		lea	FileReqTags,a0
		JSRLIB	AllocAslRequest
		move.l	d0,d6			;d6: FileRequester
		beq	2$

		move.l	_DOSBase,a6
		move.l	a4,d1
		JSRLIB	FilePart
		move.l	d0,a2

		lea	DirName,a1		;Verzeichnisname in Puffer kopieren
		move.l	a4,a0
4$		cmp.l	a0,a2
		beq	5$
		move.b	(a0)+,(a1)+
		bra	4$
5$		clr.b	(a1)+

		lea	FileName,a1		;Dateiname in Puffer kopieren
		moveq	#79,d0
3$		move.b	(a2)+,(a1)+
		dbeq	d0,3$

		move.l	_AslBase,a6		;Datei erfragen
		lea	TheLocale,a0
		move.l	#MSG_FILEHAIL,d0
		jsr	GetString
		move.l	d0,FileHailText
		move.l	d6,a0
		lea	DoFileReqTags,a1
		JSRLIB	AslRequest
		move.l	d0,FileReqResponse
		beq	22$

		move.l	d6,a0			;Verzeichnis und Dateiname zusammensetzen
		move.l	fr_File(a0),a1
		move.l	fr_Drawer(a0),a0
		move.l	a4,a2
		moveq	#80,d0
		bsr	SetPathField
		tst.l	d0
		bne	25$
		clr.l	FileReqResponse		;Pfad zu lang, wie Abbruch
		bra	22$
25$

		move.l	_GadToolsBase,a6	;Gadget neu setzen
		tst.w	d4			;d4 < 0: Gadget in AFDExtraGad (FileDisk 3/4)
		bpl	23$
		move.l	AFDExtraGad,a0
		bra	24$
23$		lea	SettingsGadgets,a0
		move.l	0(a0,d4.w),a0
24$
		move.l	VolumesWnd,a1		;a3: AFDTags (s.o.)
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA

22$		move.l	_AslBase,a6
		move.l	d6,a0
		JSRLIB	FreeAslRequest

2$		rts

; Auswahl einer Partition
; a3: SetADDTags
; a5: PartPrefsTab
; d4: GadgetIndex*4
DoGetPartName	move.l	_AslBase,a6
		move.l	VolumesWnd,FileReqWindow
		moveq	#ASL_FileRequest,d0
		lea	FileReqTags,a0
		JSRLIB	AllocAslRequest
		move.l	d0,d7			;d7: FileRequester
		beq	DGPNRts

		clr.b	DirName			;Verzeichnisnamen löschen
		clr.b	FileName		;Dateinamen löschen

		move.l	_AslBase,a6		;Verzeichnis erfragen
		move.l	d7,a0
		lea	DoPartReqTags,a1
		JSRLIB	AslRequest
		tst.l	d0
		beq	DGPNCancel

		move.l	d7,a0			;Nach ':' suchen und löschen
		move.l	fr_Drawer(a0),a0
		moveq	#79,d1
20$		cmp.b	#':',(a0)+
		bne	21$
		clr.b	-1(a0)
		bra	22$
21$		dbra	d1,20$
		bra	DGPNErrorNoLock		;Nicht gefunden, Fehler
22$
		move.l	_DOSBase,a6		;DeviceList locken
		moveq	#LDF_DEVICES|LDF_READ,d1
		JSRLIB	LockDosList
		move.l	d0,d6			;d6: dlist	

		move.l	d6,d1			;Entry suchen
		move.l	d7,a0
		move.l	fr_Drawer(a0),d2
		moveq	#LDF_DEVICES,d3
		JSRLIB	FindDosEntry
		tst.l	d0
		bne	DGPNFoundDev

		move.l	d7,a0			;Nicht gefunden, ':' wieder anhängen
		move.l	fr_Drawer(a0),a0
		moveq	#79,d1
30$		tst.b	(a0)+
		dbeq	d1,30$
		move.w	#$3a00,-1(a0)

		move.l	d7,a0			;DevProc holen
		move.l	fr_Drawer(a0),d1
		moveq	#0,d2
		JSRLIB	GetDeviceProc
		move.l	d0,d5			;d5: DevProc
		beq	DGPNError

		move.l	d5,a0			;Task holen
		move.l	dvp_DevNode(a0),d0
		beq	DGPNErrorDP
		move.l	d0,a0
		move.l	dol_Task(a0),d3		;d3: Task

		move.l	d5,d1			;DevProc freigeben
		JSRLIB	FreeDeviceProc

40$		move.l	d6,d1
		moveq	#LDF_DEVICES|LDF_READ,d2
		JSRLIB	NextDosEntry
		move.l	d0,d6
		beq	DGPNError
		move.l	d0,a0
		cmp.l	dol_Task(a0),d3		;Derselbe Task?
		bne	40$			;Nein, weitersuchen

DGPNFoundDev	move.l	d0,a0			;DeviceNode gefunden
		move.l	dol_Startup(a0),d0	;FileSysStartupMsg holen
		beq	DGPNError
		add.l	d0,d0
		add.l	d0,d0
		move.l	d0,a0
		move.l	fssm_Environ(a0),d0	;DosEnvec holen
		beq	DGPNError
		add.l	d0,d0
		add.l	d0,d0
		move.l	d0,a2
		move.l	fssm_Unit(a0),([4,a5])	;ADDUnit setzen

		move.l	fssm_Device(a0),d0	;ADDName setzen
		add.l	d0,d0
		add.l	d0,d0
		addq.l	#1,d0
		move.l	d0,a0
		move.l	(a5),a1			;Zeiger auf ADDName holen
		moveq	#79,d0
3$		move.b	(a0)+,(a1)+
		dbeq	d0,3$

		move.l	de_BlocksPerTrack(a2),d0
		mulu.l	de_Surfaces(a2),d0
		mulu.l	de_LowCyl(a2),d0
		move.l	de_SizeBlock(a2),d1
		lsr.l	#7,d1
		mulu.l	d1,d0
		move.l	d0,([8,a5])		;ADDStartSector setzen

		move.l	de_HighCyl(a2),d0
		sub.l	de_LowCyl(a2),d0
		addq.l	#1,d0
		mulu.l	de_BlocksPerTrack(a2),d0
		mulu.l	de_Surfaces(a2),d0
		move.l	de_SizeBlock(a2),d1
		lsr.l	#7,d1
		mulu.l	d1,d0
		move.l	d0,([12,a5])		;ADDSectors setzen

		move.l	de_MaxTransfer(a2),([16,a5]) ;ADDMaxTransfer setzen

		move.l	_GadToolsBase,a6	;Name-Gadget neu setzen
		lea	SettingsGadgets,a0
		move.l	0(a0,d4.w),a0
		move.l	VolumesWnd,a1		;a3: SetADDTags (s.o.)
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA

		lea	SettingsGadgets,a0
		move.l	4(a0,d4.w),a0
		move.l	VolumesWnd,a1
		sub.l	a2,a2
		lea	SetIntegerTags,a3
		move.l	([4,a5]),SetIntTagsVal	;ADDUnit
		JSRLIB	GT_SetGadgetAttrsA

		lea	SettingsGadgets,a0
		move.l	8(a0,d4.w),a0
		move.l	VolumesWnd,a1
		sub.l	a2,a2
		lea	SetIntegerTags,a3
		move.l	([8,a5]),SetIntTagsVal	;ADDStartSector
		JSRLIB	GT_SetGadgetAttrsA

		lea	SettingsGadgets,a0
		move.l	12(a0,d4.w),a0
		move.l	VolumesWnd,a1
		sub.l	a2,a2
		lea	SetIntegerTags,a3
		move.l	([12,a5]),SetIntTagsVal	;ADDSectors
		JSRLIB	GT_SetGadgetAttrsA

		lea	SettingsGadgets,a0
		move.l	16(a0,d4.w),a0
		move.l	VolumesWnd,a1
		sub.l	a2,a2
		lea	SetIntegerTags,a3
		move.l	([16,a5]),SetIntTagsVal	;ADDMaxTransfer
		JSRLIB	GT_SetGadgetAttrsA

		move.l	_DOSBase,a6
		moveq	#LDF_DEVICES|LDF_READ,d1
		JSRLIB	UnLockDosList

DGPNCancel	move.l	_AslBase,a6
		move.l	d7,a0
		JSRLIB	FreeAslRequest
DGPNRts		rts

DGPNErrorDP	move.l	_DOSBase,a6
		move.l	d5,d1
		JSRLIB	FreeDeviceProc

DGPNError	move.l	_DOSBase,a6
		moveq	#LDF_DEVICES|LDF_READ,d1
		JSRLIB	UnLockDosList

DGPNErrorNoLock	move.l	_IntuitionBase,a6
		sub.l	a0,a0
		lea	BadPartReq,a1
		move.l	a0,a2
		move.l	a0,a3
		JSRLIB	EasyRequestArgs
		bra	DGPNCancel

; MakeAFD-Gadget handhaben
; a3: SetAFDTags
; a4: AFDFileName
; d4: GadgetIndex*4
DoMakeAFD	jsr	OpenEnterSizeWindow
		tst.l	d0
		bne	MAFDExit
		clr.l	FileDiskSize

MAFDEventLoop	move.l	_ExecBase,a6		;Auf Nachricht warten
		move.l	EnterSizeWnd,a0
		move.l	wd_UserPort(a0),a0
		JSRLIB	WaitPort
		move.l	_GadToolsBase,a6
		move.l	EnterSizeWnd,a0
		move.l	wd_UserPort(a0),a0
		JSRLIB	GT_GetIMsg
		tst.l	d0
		beq	MAFDEventLoop
		move.l	d0,a1
		move.l	im_Class(a1),TheClass
		move.l	im_IAddress(a1),TheGadget
		JSRLIB	GT_ReplyIMsg

		move.l	TheClass,d0
		and.l	#IDCMP_GADGETUP,d0
		beq	MAFDNotGadget
		move.l	TheGadget,a0

		cmp.w	#GD_SizeOK,gg_GadgetID(a0)
		beq	MAFDSizeDone
		cmp.w	#GD_SizeCancel,gg_GadgetID(a0)
		beq	MAFDSizeCanc
		bra	MAFDEventLoop

MAFDNotGadget	move.l	TheClass,d0
		and.l	#IDCMP_CLOSEWINDOW,d0
		beq	MAFDEventLoop
		bra	MAFDSizeCanc

MAFDSizeDone	lea	SettingsGadgets,a1
		move.l	GDX_SizeKB*4(a1),a0
		GetInt	d0
		lsl.l	#8,d0		;*256
		lsl.l	#2,d0		;*1024
		move.l	d0,FileDiskSize

MAFDSizeCanc	jsr	CloseEnterSizeWindow
		cmp.l	#2,FileDiskSize
		blo	MAFDExit

		bsr	DoGetAFDName
		tst.l	FileReqResponse
		beq	MAFDExit

		move.l	_DOSBase,a6		;Eine vorhandene Datei nicht ungefragt ersetzen
		move.l	a4,d1
		moveq	#ACCESS_READ,d2
		JSRLIB	Lock
		move.l	d0,d1
		beq	1$
		JSRLIB	UnLock
		move.l	a3,-(sp)
		move.l	a4,-(sp)
		move.l	sp,a3
		move.l	#MSG_REPLACE_TXT,d0
		move.l	#MSG_REPLACE_GADS,d1
		jsr	SReq
		addq.l	#4,sp
		move.l	(sp)+,a3
		tst.l	d0
		beq	MAFDExit
1$
		move.l	a4,d1
		move.l	FileDiskSize,d2
		bsr	CreateEmptyDisk
		tst.l	d0
		bne	MAFDExit

		move.l	_IntuitionBase,a6	;Nicht gelungen
		sub.l	a0,a0
		lea	BadAFDReq,a1
		move.l	a0,a2
		move.l	a0,a3
		JSRLIB	EasyRequestArgs

MAFDExit	rts

; Leere Disk-Datei anlegen (ohne alte Daten am Anfang). d1: Name, d2: Groesse
; d0: 0 = nicht gelungen; eine angefangene Datei ist dann wieder geloescht
CreateEmptyDisk	movem.l	d2-d6/a6,-(sp)
		move.l	d1,d4
		move.l	d2,d5
		move.l	_DOSBase,a6
		move.l	#MODE_NEWFILE,d2
		JSRLIB	Open
		move.l	d0,d6
		beq	2$
		move.l	d6,d1
		move.l	d5,d2
		moveq	#OFFSET_BEGINNING,d3
		JSRLIB	SetFileSize
		cmp.l	d5,d0
		bne	1$
		move.l	d6,d1
		moveq	#0,d2
		moveq	#OFFSET_BEGINNING,d3
		JSRLIB	Seek
		move.l	d6,d1
		move.l	#AFD2kEmptyBuf,d2
		move.l	#2048,d3
		JSRLIB	Write
		move.l	d6,d1			;An empty Mac disk into it, so that the Mac
		move.l	d5,d2			; need not initialise it (if that cannot be
		move.l	d4,a0			; done, the Mac will offer to)
		jsr	FormatFileDisk
		move.l	_DOSBase,a6
		move.l	d6,d1
		JSRLIB	Close
		moveq	#-1,d0
		bra	2$
1$		move.l	d6,d1
		JSRLIB	Close
		move.l	d4,d1
		JSRLIB	DeleteFile
		moveq	#0,d0
2$		movem.l	(sp)+,d2-d6/a6
		rts


**
** Grafik
**

; Fenster für Grafikeinstellungen öffnen
OpenGraphicsWnd	lea	PageGraphics,a0		;Seite an das Tab-Fenster haengen
		jsr	AttachPage
		tst.l	d0
		beq	97$
		rts
97$

SetGraphicsGads	tst.l	GraphicsWnd
		beq	100$

		move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a5

		SetCycleW GraphicsWnd,GDX_NumMonitors,NumMonitors
		SetCycleW GraphicsWnd,GDX_VideoType1,VideoType1
		SetCycleW GraphicsWnd,GDX_VideoType2,VideoType2
		SetCycleW GraphicsWnd,GDX_VideoMode1,VideoMode1
		SetCycleW GraphicsWnd,GDX_VideoMode2,VideoMode2

		move.l	GDX_ExtVideoName1*4(a5),a0 ;Externer Videotreiber 1
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		lea	SetExtVideo1Tags,a3
		JSRLIB	GT_SetGadgetAttrsA

		move.l	GDX_ExtVideoName2*4(a5),a0 ;Externer Videotreiber 2
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		lea	SetExtVideo2Tags,a3
		JSRLIB	GT_SetGadgetAttrsA

		SetIntW	GraphicsWnd,GDX_RefreshRate,RefreshRate

		SetCheck GraphicsWnd,GDX_BlackBorder,BlackBorder
		SetCheck GraphicsWnd,GDX_RefreshAlways,RefreshAlways
		SetCheck GraphicsWnd,GDX_UseAmigaMouse,UseAmigaMouse
		SetCheck GraphicsWnd,GDX_MMURefresh,MMURefresh

		bsr	SetDisplayXYGads
		bsr	SetDisplayIDGads	;DisplayID 1/2
		bsr	GhostGraphics
100$		rts

; DisplayID-Gadgets neu setzen
SetDisplayIDGads
		movem.l	a2-a6,-(sp)
		move.l	_GfxBase,a6		;DisplayID 1
		sub.l	a0,a0
		lea	DisplayName1,a1
		moveq	#nif_SIZEOF,d0
		move.l	#DTAG_NAME,d1
		move.l	DisplayID1,d2
		JSRLIB	GetDisplayInfoData
		lea	DisplayName1,a1
		move.l	DisplayID1,d2
		bsr	ModeNameOrID
		move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a0
		move.l	GDX_DisplayID1*4(a0),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		lea	SetDID1Tags,a3
		JSRLIB	GT_SetGadgetAttrsA

		move.l	_GfxBase,a6		;DisplayID 2
		sub.l	a0,a0
		lea	DisplayName2,a1
		moveq	#nif_SIZEOF,d0
		move.l	#DTAG_NAME,d1
		move.l	DisplayID2,d2
		JSRLIB	GetDisplayInfoData
		lea	DisplayName2,a1
		move.l	DisplayID2,d2
		bsr	ModeNameOrID
		move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a0
		move.l	GDX_DisplayID2*4(a0),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		lea	SetDID2Tags,a3
		JSRLIB	GT_SetGadgetAttrsA
		movem.l	(sp)+,a2-a6
		rts

; d0: what GetDisplayInfoData returned, a1: NameInfo, d2: mode ID.
; A mode without a name in the display database (no monitor driver for it,
; or the mode is not there at all) is shown by its number instead of an
; empty field
ModeNameOrID	tst.l	d2			;(no mode: leave the field empty)
		beq	9$
		tst.l	d0
		beq	1$
		tst.b	nif_Name(a1)
		bne	9$
1$		lea	nif_Name(a1),a0
		move.b	#'M',(a0)+
		move.b	#'o',(a0)+
		move.b	#'d',(a0)+
		move.b	#'e',(a0)+
		move.b	#' ',(a0)+
		move.b	#'$',(a0)+
		moveq	#7,d1
2$		rol.l	#4,d2
		move.b	d2,d0
		and.b	#15,d0
		add.b	#'0',d0
		cmp.b	#'9',d0
		bls	3$
		addq.b	#7,d0
3$		move.b	d0,(a0)+
		dbra	d1,2$
		clr.b	(a0)
9$		rts

; Dimensions-Gadgets neu setzen
SetDisplayXYGads
		movem.l	a2-a6,-(sp)
		move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a5

		SetIntL	GraphicsWnd,GDX_ScreenX1,ScreenX1
		SetIntL	GraphicsWnd,GDX_ScreenY1,ScreenY1
		SetIntL	GraphicsWnd,GDX_ScreenX2,ScreenX2
		SetIntL	GraphicsWnd,GDX_ScreenY2,ScreenY2

		movem.l	(sp)+,a2-a6
		rts

; Grafik-Gadgets korrekt ghosten
GhostGraphics	move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a5

; Monitor 1
		lea	EnableTags,a3		;Farbtiefe und DisplayID nicht bei Mac-In-A-Box
		cmp.w	#VTYPE_MACINABOX,VideoType1
		bne	1$
		lea	DisableTags,a3
1$		move.l	GDX_VideoMode1*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_GetDisplayID1*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_DisplayID1*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA

		lea	EnableTags,a3		;ExtVideoName nur bei Extern
		cmp.w	#VTYPE_EXTERNAL,VideoType1
		beq	2$
		lea	DisableTags,a3
2$		move.l	GDX_ExtVideoName1*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_GetVideoName1*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA

		tst.w	NumMonitors
		beq	5$

; Monitor 2 aktiv
		lea	EnableTags,a3		;Bildschirmtyp immer an
		move.l	GDX_VideoType2*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		lea	DisableTags,a3		;Amiga-Mauszeiger aus
		move.l	GDX_UseAmigaMouse*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA

		lea	EnableTags,a3		;Farbtiefe und DisplayID nicht bei Mac-In-A-Box
		cmp.w	#VTYPE_MACINABOX,VideoType2
		bne	3$
		lea	DisableTags,a3
3$		move.l	GDX_VideoMode2*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_GetDisplayID2*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_DisplayID2*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA

		lea	EnableTags,a3		;ExtVideoName nur bei Extern
		cmp.w	#VTYPE_EXTERNAL,VideoType2
		beq	4$
		lea	DisableTags,a3
4$		move.l	GDX_ExtVideoName2*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_GetVideoName2*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		bra	6$

; Monitor 2 inaktiv
5$		lea	DisableTags,a3
		move.l	GDX_VideoMode2*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_VideoType2*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_GetDisplayID2*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_DisplayID2*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_ExtVideoName2*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_GetVideoName2*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		lea	EnableTags,a3		;Amiga-Mauszeiger an
		move.l	GDX_UseAmigaMouse*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA

; Gemeinsame Einstellungen
6$		lea	DisableTags,a3		;MMURefresh nur, wenn MMU vorhanden
		tst.b	HasMMU
		beq	7$
		lea	EnableTags,a3
7$		move.l	GDX_MMURefresh*4(a5),a0
		move.l	GraphicsWnd,a1
		sub.l	a2,a2
		JMPLIB	GT_SetGadgetAttrsA

; Parameter aus den Grafik-Gadgets holen
GetGraphicsGads tst.l	GraphicsWnd
		beq	2$

		lea	SettingsGadgets,a1
		move.l	GDX_ExtVideoName1*4(a1),a0
		move.l	34(a0),a0	;SpecialInfo
		move.l	(a0),a0		;Buffer
		lea	ExtVideoName1,a2
		moveq	#79,d0
1$		move.b	(a0)+,(a2)+
		dbeq	d0,1$

		lea	SettingsGadgets,a1
		move.l	GDX_ExtVideoName2*4(a1),a0
		move.l	34(a0),a0	;SpecialInfo
		move.l	(a0),a0		;Buffer
		lea	ExtVideoName2,a2
		moveq	#79,d0
3$		move.b	(a0)+,(a2)+
		dbeq	d0,3$

		move.l	GDX_RefreshRate*4(a1),a0
		GetInt	d0
		move.w	d0,RefreshRate

		move.l	GDX_ScreenX1*4(a1),a0
		GetInt	ScreenX1
		move.l	GDX_ScreenY1*4(a1),a0
		GetInt	ScreenY1
		move.l	GDX_ScreenX2*4(a1),a0
		GetInt	ScreenX2
		move.l	GDX_ScreenY2*4(a1),a0
		GetInt	ScreenY2
2$		rts

; Fenster für Grafikeinstellungen schließen
CloseGraphicsWnd bsr	GetGraphicsGads

		lea	PageGraphics,a0		;Seite vom Tab-Fenster entfernen
		jsr	DetachPage
		rts


**
** Datenträger
**

; Fenster für Datenträgereinstellungen öffnen
OpenVolumesWnd	jsr	PrepVolumesX		;Beschriftung FileDisk 3/4
		lea	PageVolumes,a0		;Seite an das Tab-Fenster haengen
		jsr	AttachPage
		tst.l	d0
		beq	97$
		rts
97$

SetVolumesGads	jsr	SetVolumesXGads		;FileDisk 3/4
		tst.l	VolumesWnd
		beq	100$

		move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a5

		move.l	GDX_AFDName1*4(a5),a0	;FileDisk 1
		move.l	VolumesWnd,a1
		sub.l	a2,a2
		lea	SetAFD1Tags,a3
		JSRLIB	GT_SetGadgetAttrsA

		move.l	GDX_AFDName2*4(a5),a0	;FileDisk 2
		move.l	VolumesWnd,a1
		sub.l	a2,a2
		lea	SetAFD2Tags,a3
		JSRLIB	GT_SetGadgetAttrsA

		move.l	GDX_ADDName1*4(a5),a0	;DeviceDisk 1
		move.l	VolumesWnd,a1
		sub.l	a2,a2
		lea	SetADD1Tags,a3
		JSRLIB	GT_SetGadgetAttrsA

		SetIntL	VolumesWnd,GDX_ADDUnit1,ADDUnit1
		SetIntL	VolumesWnd,GDX_ADDStartSector1,ADDStartSector1
		SetIntL	VolumesWnd,GDX_ADDSectors1,ADDSectors1
		SetIntL	VolumesWnd,GDX_ADDMaxTransfer1,ADDMaxTransfer1
		SetCheck VolumesWnd,GDX_ADDRemovable1,ADDRemovable1

		move.l	GDX_ADDName2*4(a5),a0	;DeviceDisk 2
		move.l	VolumesWnd,a1
		sub.l	a2,a2
		lea	SetADD2Tags,a3
		JSRLIB	GT_SetGadgetAttrsA

		SetIntL	VolumesWnd,GDX_ADDUnit2,ADDUnit2
		SetIntL	VolumesWnd,GDX_ADDStartSector2,ADDStartSector2
		SetIntL	VolumesWnd,GDX_ADDSectors2,ADDSectors2
		SetIntL	VolumesWnd,GDX_ADDMaxTransfer2,ADDMaxTransfer2
		SetCheck VolumesWnd,GDX_ADDRemovable2,ADDRemovable2

		SetCycleW VolumesWnd,GDX_BootFrom,BootFrom
100$		rts

; Parameter aus den Datenträger-Gadgets holen
GetVolumesGads	jsr	GetVolumesXGads		;FileDisk 3/4
		tst.l	VolumesWnd
		beq	5$

		lea	SettingsGadgets,a1
		move.l	GDX_ADDUnit1*4(a1),a0
		GetInt	ADDUnit1

		move.l	GDX_ADDUnit2*4(a1),a0
		GetInt	ADDUnit2

		move.l	GDX_ADDStartSector1*4(a1),a0
		GetInt	ADDStartSector1

		move.l	GDX_ADDStartSector2*4(a1),a0
		GetInt	ADDStartSector2

		move.l	GDX_ADDSectors1*4(a1),a0
		GetInt	ADDSectors1

		move.l	GDX_ADDSectors2*4(a1),a0
		GetInt	ADDSectors2

		move.l	GDX_ADDMaxTransfer1*4(a1),a0
		GetInt	ADDMaxTransfer1

		move.l	GDX_ADDMaxTransfer2*4(a1),a0
		GetInt	ADDMaxTransfer2

		move.l	GDX_AFDName1*4(a1),a0
		move.l	34(a0),a0	;SpecialInfo
		move.l	(a0),a0		;Buffer
		lea	AFDFileName1,a2
		moveq	#79,d0
1$		move.b	(a0)+,(a2)+
		dbeq	d0,1$

		move.l	GDX_AFDName2*4(a1),a0
		move.l	34(a0),a0	;SpecialInfo
		move.l	(a0),a0		;Buffer
		lea	AFDFileName2,a2
		moveq	#79,d0
2$		move.b	(a0)+,(a2)+
		dbeq	d0,2$

		move.l	GDX_ADDName1*4(a1),a0
		move.l	34(a0),a0	;SpecialInfo
		move.l	(a0),a0		;Buffer
		lea	ADDName1,a2
		moveq	#79,d0
3$		move.b	(a0)+,(a2)+
		dbeq	d0,3$

		move.l	GDX_ADDName2*4(a1),a0
		move.l	34(a0),a0	;SpecialInfo
		move.l	(a0),a0		;Buffer
		lea	ADDName2,a2
		moveq	#79,d0
4$		move.b	(a0)+,(a2)+
		dbeq	d0,4$
5$		rts

; Fenster für Datenträgereinstellungen schließen
CloseVolumesWnd bsr	GetVolumesGads

		lea	PageVolumes,a0		;Seite vom Tab-Fenster entfernen
		jsr	DetachPage
		rts


**
** Diskettenlaufwerke
**

; Fenster für Floppy-Einstellungen öffnen
OpenFloppyWnd	lea	PageFloppy,a0		;Seite an das Tab-Fenster haengen
		jsr	AttachPage
		tst.l	d0
		beq	97$
		rts
97$

SetFloppyGads	tst.l	FloppyWnd
		beq	100$

		move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a5

		SetCheck FloppyWnd,GDX_InhibitFloppy1,InhibitFloppy1
		SetCheck FloppyWnd,GDX_InhibitFloppy2,InhibitFloppy2

		bsr	DrawFloppyGads
100$		rts

; Floppy-Gadgets neu darstellen
DrawFloppyGads	move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a5

		SetCycleW FloppyWnd,GDX_Floppy1,Floppy1
		SetCycleW FloppyWnd,GDX_Floppy2,Floppy2
		rts

; Parameter aus den Floppy-Gadgets holen
GetFloppyGads	rts

; Fenster für Floppy-Einstellungen schließen
CloseFloppyWnd	bsr	GetFloppyGads

		lea	PageFloppy,a0		;Seite vom Tab-Fenster entfernen
		jsr	DetachPage
		rts


**
** SCSI
**

; Fenster für SCSI-Einstellungen öffnen
OpenSCSIWnd	lea	PageSCSI,a0		;Seite an das Tab-Fenster haengen
		jsr	AttachPage
		tst.l	d0
		beq	97$
		rts
97$

SetSCSIGads	tst.l	SCSIWnd
		beq	100$

		move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a5

SetSCSIName	MACRO
		move.l	GDX_SCSIName\1*4(a5),a0
		move.l	SCSIWnd,a1
		sub.l	a2,a2
		lea	SetSCSI\1Tags,a3
		JSRLIB	GT_SetGadgetAttrsA
		ENDM

		SetSCSIName 0
		SetSCSIName 1
		SetSCSIName 2
		SetSCSIName 3
		SetSCSIName 4
		SetSCSIName 5
		SetSCSIName 6

		SetIntL	SCSIWnd,GDX_SCSIUnit0,SCSIUnit0
		SetIntL	SCSIWnd,GDX_SCSIUnit1,SCSIUnit1
		SetIntL	SCSIWnd,GDX_SCSIUnit2,SCSIUnit2
		SetIntL	SCSIWnd,GDX_SCSIUnit3,SCSIUnit3
		SetIntL	SCSIWnd,GDX_SCSIUnit4,SCSIUnit4
		SetIntL	SCSIWnd,GDX_SCSIUnit5,SCSIUnit5
		SetIntL	SCSIWnd,GDX_SCSIUnit6,SCSIUnit6

		SetCycleW SCSIWnd,GDX_SCSIMemType,SCSIMemType

		SetCheck SCSIWnd,GDX_AppleCD,AppleCD
		SetCheck SCSIWnd,GDX_AppleHD,AppleHD
		SetCheck SCSIWnd,GDX_SCSIDirect,SCSIDirect
		SetCheck SCSIWnd,GDX_FastCrapMode,FastCrapMode

SetSCSIEnable	MACRO
		lea	SetCheckOffTags,a3
		btst	#\1,SCSIEnable
		beq	\@1$
		lea	SetCheckOnTags,a3
\@1$		move.l	GDX_SCSI\1*4(a5),a0
		move.l	SCSIWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		ENDM

		SetSCSIEnable	0
		SetSCSIEnable	1
		SetSCSIEnable	2
		SetSCSIEnable	3
		SetSCSIEnable	4
		SetSCSIEnable	5
		SetSCSIEnable	6
100$		rts

; Parameter aus den SCSI-Gadgets holen
GetSCSIGads	tst.l	SCSIWnd
		beq	2$

		lea	SettingsGadgets,a1

		move.l	GDX_SCSIUnit0*4(a1),a0
		GetInt	SCSIUnit0
		move.l	GDX_SCSIUnit1*4(a1),a0
		GetInt	SCSIUnit1
		move.l	GDX_SCSIUnit2*4(a1),a0
		GetInt	SCSIUnit2
		move.l	GDX_SCSIUnit3*4(a1),a0
		GetInt	SCSIUnit3
		move.l	GDX_SCSIUnit4*4(a1),a0
		GetInt	SCSIUnit4
		move.l	GDX_SCSIUnit5*4(a1),a0
		GetInt	SCSIUnit5
		move.l	GDX_SCSIUnit6*4(a1),a0
		GetInt	SCSIUnit6

GetSCSIName	MACRO
		move.l	GDX_SCSIName\1*4(a1),a0
		move.l	34(a0),a0	;SpecialInfo
		move.l	(a0),a0		;Buffer
		lea	SCSIName\1,a2
		moveq	#79,d0
\@1$		move.b	(a0)+,(a2)+
		dbeq	d0,\@1$
		ENDM

		GetSCSIName 0
		GetSCSIName 1
		GetSCSIName 2
		GetSCSIName 3
		GetSCSIName 4
		GetSCSIName 5
		GetSCSIName 6
2$		rts

; Fenster für SCSI-Einstellungen schließen
CloseSCSIWnd	bsr	GetSCSIGads

		lea	PageSCSI,a0		;Seite vom Tab-Fenster entfernen
		jsr	DetachPage
		rts


**
** Speicher
**

; Fenster für Speichereinstellungen öffnen
OpenMemoryWnd	lea	PageMemory,a0		;Seite an das Tab-Fenster haengen
		jsr	AttachPage
		tst.l	d0
		beq	97$
		rts
97$

SetMemoryGads	tst.l	MemoryWnd
		beq	100$

		bsr	DrawMemMaxGad

		move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a5

		move.l	GDX_MemSize*4(a5),a0	;MemSize
		move.l	MemoryWnd,a1
		sub.l	a2,a2
		lea	SetIntegerTags,a3
		move.l	MemSize,d0
		lsr.l	#8,d0			;/256
		lsr.l	#2,d0			;/1024
		move.l	d0,SetIntTagsVal
		JSRLIB	GT_SetGadgetAttrsA

		SetCheck MemoryWnd,GDX_LargestBlock,LargestBlock
		SetCheck MemoryWnd,GDX_FastROM,FastROM
		SetCycleW MemoryWnd,GDX_ROMMemType,ROMMemType

		bsr	GhostMemory
100$		rts

; Memory-Gadgets korrekt ghosten
GhostMemory	move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a5

		lea	EnableTags,a3		;LargestBlock -> MemSize disablen
		tst.w	LargestBlock
		beq	1$
		lea	DisableTags,a3
1$		move.l	GDX_MemSize*4(a5),a0
		move.l	MemoryWnd,a1
		sub.l	a2,a2
		JMPLIB	GT_SetGadgetAttrsA

; MemMax-Gadget neu darstellen
DrawMemMaxGad	lea	SettingsGadgets,a5
		move.l	_ExecBase,a6
		move.l	#MEMF_LARGEST|MEMF_PUBLIC,d1
		JSRLIB	AvailMem

		tst.w	FastROM
		beq	2$
		sub.l	ROMSize,d0		;FastROM: ROM-Größe abziehen
2$		sub.l	#16*1024,d0		;16K zur Sicherheit abziehen
		lsr.l	#8,d0			;/256
		lsr.l	#2,d0			;/1024
		move.l	d0,SetNumTagsVal

		move.l	_GadToolsBase,a6
		move.l	GDX_MemMax*4(a5),a0
		move.l	MemoryWnd,a1
		sub.l	a2,a2
		lea	SetNumberTags,a3
		JMPLIB	GT_SetGadgetAttrsA

; Parameter aus den Memory-Gadgets holen
GetMemoryGads	tst.l	MemoryWnd
		beq	1$

		lea	SettingsGadgets,a1
		move.l	GDX_MemSize*4(a1),a0
		GetInt	d0
		cmp.l	#$1fffff,d0		;KB: keep the byte count inside 31 bits
		bls	2$
		move.l	#$1fffff,d0
2$		lsl.l	#8,d0			;*256
		lsl.l	#2,d0			;*256
		move.l	d0,MemSize
1$		rts

; Fenster für Speichereinstellungen schließen
CloseMemoryWnd	bsr	GetMemoryGads

		lea	PageMemory,a0		;Seite vom Tab-Fenster entfernen
		jsr	DetachPage
		rts


**
** Seriell
**

; Fenster für serielle Einstellungen öffnen
OpenSerialWnd	lea	PageSerial,a0		;Seite an das Tab-Fenster haengen
		jsr	AttachPage
		tst.l	d0
		beq	97$
		rts
97$

SetSerialGads	tst.l	SerialWnd
		beq	100$

		move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a5

		move.l	GDX_SERDNameA*4(a5),a0	;Modemport
		move.l	SerialWnd,a1
		sub.l	a2,a2
		lea	SetSERDATags,a3
		JSRLIB	GT_SetGadgetAttrsA

		SetIntL	SerialWnd,GDX_SERDUnitA,SERDUnitA
		SetCheck SerialWnd,GDX_SERDAIsPar,SERDAIsPar

		move.l	GDX_SERDNameB*4(a5),a0	;Druckerport
		move.l	SerialWnd,a1
		sub.l	a2,a2
		lea	SetSERDBTags,a3
		JSRLIB	GT_SetGadgetAttrsA

		SetIntL	SerialWnd,GDX_SERDUnitB,SERDUnitB
		SetCheck SerialWnd,GDX_SERDBIsPar,SERDBIsPar

		SetCheck SerialWnd,GDX_UseSCCSerial,UseSCCSerial
100$		bra	GhostSerial

; Serielle Gadgets korrekt ghosten
GhostSerial	move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a5

		lea	EnableTags,a3		;UseSCCSerial nur, wenn echter SCC vorhanden
		tst.b	HasRealSCC
		bne	1$
		lea	DisableTags,a3
1$		move.l	GDX_UseSCCSerial*4(a5),a0
		move.l	SerialWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA

		lea	EnableTags,a3		;Serielle Einstellungen nur ohne SCC
		tst.w	UseSCCSerial
		beq	2$
		lea	DisableTags,a3
2$		move.l	GDX_SERDNameA*4(a5),a0
		move.l	SerialWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_SERDUnitA*4(a5),a0
		move.l	SerialWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_SERDAIsPar*4(a5),a0
		move.l	SerialWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_GetSERDA*4(a5),a0
		move.l	SerialWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_SERDNameB*4(a5),a0
		move.l	SerialWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_SERDUnitB*4(a5),a0
		move.l	SerialWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_SERDBIsPar*4(a5),a0
		move.l	SerialWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_GetSERDB*4(a5),a0
		move.l	SerialWnd,a1
		sub.l	a2,a2
		JMPLIB	GT_SetGadgetAttrsA

; Parameter aus den Serial-Gadgets holen
GetSerialGads	tst.l	SerialWnd
		beq	3$

		lea	SettingsGadgets,a1
		move.l	GDX_SERDUnitA*4(a1),a0
		GetInt	SERDUnitA

		move.l	GDX_SERDUnitB*4(a1),a0
		GetInt	SERDUnitB

		move.l	GDX_SERDNameA*4(a1),a0
		move.l	34(a0),a0	;SpecialInfo
		move.l	(a0),a0		;Buffer
		lea	SERDNameA,a2
		moveq	#79,d0
1$		move.b	(a0)+,(a2)+
		dbeq	d0,1$

		move.l	GDX_SERDNameB*4(a1),a0
		move.l	34(a0),a0	;SpecialInfo
		move.l	(a0),a0		;Buffer
		lea	SERDNameB,a2
		moveq	#79,d0
2$		move.b	(a0)+,(a2)+
		dbeq	d0,2$
3$		rts

; Fenster für serielle Einstellungen schließen
CloseSerialWnd	bsr	GetSerialGads

		lea	PageSerial,a0		;Seite vom Tab-Fenster entfernen
		jsr	DetachPage
		rts


**
** Netzwerk
**

; Fenster für Netzwerk-Einstellungen öffnen
OpenNetworkWnd	lea	PageNetwork,a0		;Seite an das Tab-Fenster haengen
		jsr	AttachPage
		tst.l	d0
		beq	97$
		rts
97$

SetNetworkGads	tst.l	NetworkWnd
		beq	100$

		move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a5

		move.l	GDX_Sana2Name*4(a5),a0
		move.l	NetworkWnd,a1
		sub.l	a2,a2
		lea	SetSana2Tags,a3
		JSRLIB	GT_SetGadgetAttrsA

		SetIntL	NetworkWnd,GDX_Sana2Unit,Sana2Unit
100$		rts

; Parameter aus den Netzwerk-Gadgets holen
GetNetworkGads	tst.l	NetworkWnd
		beq	2$

		lea	SettingsGadgets,a1
		move.l	GDX_Sana2Unit*4(a1),a0
		GetInt	Sana2Unit

		move.l	GDX_Sana2Name*4(a1),a0
		move.l	34(a0),a0	;SpecialInfo
		move.l	(a0),a0		;Buffer
		lea	Sana2Name,a2
		moveq	#79,d0
1$		move.b	(a0)+,(a2)+
		dbeq	d0,1$
2$		rts

; Fenster für Netzwerk-Einstellungen schließen
CloseNetworkWnd	bsr	GetNetworkGads

		lea	PageNetwork,a0		;Seite vom Tab-Fenster entfernen
		jsr	DetachPage
		rts


**
** Sonstiges
**

; Fenster für sonstige Einstellungen öffnen
OpenMiscWnd	lea	PageMisc,a0		;Seite an das Tab-Fenster haengen
		jsr	AttachPage
		tst.l	d0
		beq	97$
		rts
97$

SetMiscGads	tst.l	MiscWnd
		beq	100$

		move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a5

		SetCheck MiscWnd,GDX_MouseDirect,MouseDirect
		SetCheck MiscWnd,GDX_ProtectROM,ProtectROM
		SetCheck MiscWnd,GDX_MacOS8Mode,MacOS8Mode
		SetCheck MiscWnd,GDX_AudioOn,AudioOn
		SetCheck MiscWnd,GDX_UseAHI,UseAHI

		bsr	SetAudioIDGad
		bsr	GhostMisc
100$		rts

; AudioID-Gadget neu setzen
SetAudioIDGad	movem.l	a2-a6,-(sp)
		move.l	_AHIBase,d0
		beq	1$

		move.l	d0,a6
		move.l	AudioID,d0
		lea	GetAudioIDTags,a1
		sub.l	a2,a2
		jsr	_LVOAHI_GetAudioAttrsA(a6)

		move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a0
		move.l	GDX_AudioID*4(a0),a0
		move.l	MiscWnd,a1
		sub.l	a2,a2
		lea	SetAIDTags,a3
		JSRLIB	GT_SetGadgetAttrsA

1$		movem.l	(sp)+,a2-a6
		rts

; Misc-Gadgets korrekt ghosten
GhostMisc	move.l	_GadToolsBase,a6
		lea	SettingsGadgets,a5

		lea	EnableTags,a3
		tst.b	HasMMU			;ProtectROM disablen, wenn keine MMU da oder 68060
		beq	1$
		tst.b	Has68060
		beq	2$
1$		lea	DisableTags,a3
2$		move.l	GDX_ProtectROM*4(a5),a0
		move.l	MiscWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA

		lea	EnableTags,a3
		tst.w	AudioOn			;UseAHI disablen, wenn AudioOn nicht gesetzt oder kein AHI vorhanden
		beq	3$
		tst.l	_AHIBase
		bne	4$
3$		lea	DisableTags,a3
4$		move.l	GDX_UseAHI*4(a5),a0
		move.l	MiscWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA

		lea	EnableTags,a3
		tst.w	AudioOn			;AudioID disablen, wenn AudioOn und UseAHI nicht gesetzt
		beq	5$
		tst.w	UseAHI
		bne	6$
5$		lea	DisableTags,a3
6$		move.l	GDX_GetAudioID*4(a5),a0
		move.l	MiscWnd,a1
		sub.l	a2,a2
		JSRLIB	GT_SetGadgetAttrsA
		move.l	GDX_AudioID*4(a5),a0
		move.l	MiscWnd,a1
		JMPLIB	GT_SetGadgetAttrsA

; Parameter aus den Misc-Gadgets holen
GetMiscGads	rts

; Fenster für sonstige Einstellungen schließen
CloseMiscWnd	bsr	GetMiscGads

		lea	PageMisc,a0		;Seite vom Tab-Fenster entfernen
		jsr	DetachPage
		rts


**
** Konstanten
**

; Versionsnummer und Seriennummer
; Tabs des Einstellungsfensters: Seite einhaengen / entfernen, Beschriftung
TabFuncs
		dc.l	OpenGraphicsWnd,CloseGraphicsWnd
		dc.l	OpenVolumesWnd,CloseVolumesWnd
		dc.l	OpenFloppyWnd,CloseFloppyWnd
		dc.l	OpenSCSIWnd,CloseSCSIWnd
		dc.l	OpenMemoryWnd,CloseMemoryWnd
		dc.l	OpenSerialWnd,CloseSerialWnd
		dc.l	OpenNetworkWnd,CloseNetworkWnd
		dc.l	OpenMiscWnd,CloseMiscWnd
		dc.l	OpenCPUWnd,CloseCPUWnd
TabLabelGDX	dc.w	GDX_OpenGraphics,GDX_OpenVolumes,GDX_OpenFloppy,GDX_OpenSCSI,GDX_OpenMemory,GDX_OpenSerial,GDX_OpenNetwork,GDX_OpenMisc,-1
		EVEN

VersionNumber	dc.w	VERSION,REVISION

; Strings
		EVEN
DevsName	dc.b	"DEVS:",0
DevsNetName	dc.b	"DEVS:Networks/",0
EVDDirName	dc.b	"Video Drivers/",0
DefaultTool	dc.b	"ShapeShifter",0
NullName	dc.b	0,0
		CNOP	0,4

; Tabellen für DoGetPartName (Zeiger auf die Prefs)
PartPrefsTab1	dc.l	ADDName1
		dc.l	ADDUnit1
		dc.l	ADDStartSector1
		dc.l	ADDSectors1
		dc.l	ADDMaxTransfer1

PartPrefsTab2	dc.l	ADDName2
		dc.l	ADDUnit2
		dc.l	ADDStartSector2
		dc.l	ADDSectors2
		dc.l	ADDMaxTransfer2

; Tabellen für RequestDID (Zeiger auf die Prefs)
DIDPrefsTab1	dc.l	DisplayID1
		dc.l	OverscanType1
		dc.l	ScreenX1
		dc.l	ScreenY1
		dc.l	VideoMode1

DIDPrefsTab2	dc.l	DisplayID2
		dc.l	OverscanType2
		dc.l	ScreenX2
		dc.l	ScreenY2
		dc.l	VideoMode2


**
** Initialisierte Daten
**

		SECTION	"DATA",DATA

; Requester
BadPartReq	dc.l	20,0,0,0,0
BadAFDReq	dc.l	20,0,0,0,0
No16BitModeReq	dc.l	20,0,0,0,0
AboutReq	dc.l	20,0,0,0,0

; Taglists für den Dateirequester
FileReqTags	dc.l	ASLFR_SleepWindow,-1
		dc.l	ASLFR_Flags2,FRF_REJECTICONS
		dc.l	ASLFR_Window
FileReqWindow	dc.l	0
		dc.l	0

DoFileReqTags	dc.l	ASLFR_TitleText
FileHailText	dc.l	0
		dc.l	ASLFR_InitialFile,FileName
		dc.l	ASLFR_InitialDrawer,DirName
		dc.l	0

DoPartReqTags	dc.l	ASLFR_TitleText
PartHailText	dc.l	0
		dc.l	ASLFR_InitialFile,FileName
		dc.l	ASLFR_InitialDrawer,DirName
		dc.l	ASLFR_Flags2,FRF_REJECTICONS|FRF_DRAWERSONLY
		dc.l	0

; Taglists für den ScreenMode-Requester
ScreenReqTags	dc.l	ASLSM_TitleText
ScreenHailText	dc.l	0
		dc.l	ASLSM_SleepWindow,-1
		dc.l	ASLSM_DoOverscanType,-1
		dc.l	ASLSM_PropertyMask,DIPF_IS_HAM|DIPF_IS_EXTRAHALFBRITE|DIPF_IS_DUALPF
		dc.l	ASLSM_PropertyFlags,0
		dc.l	ASLSM_Window
ScreenReqWindow dc.l	0
		dc.l	0

DoScreenReqTags dc.l	ASLSM_InitialDisplayID
ScreenReqID	dc.l	0
		dc.l	ASLSM_InitialOverscanType
ScreenReqOScan	dc.l	0
		dc.l	0

DoCyberReqTags	dc.l	CYBRMREQ_Screen
CyberReqScreen	dc.l	0
		dc.l	CYBRMREQ_WinTitle
CyberHailText	dc.l	0
		dc.l	0,0

; Taglists zum Setzen der Gadget-Werte
SetAFD1Tags	dc.l	GTST_String,AFDFileName1
		dc.l	0

SetAFD2Tags	dc.l	GTST_String,AFDFileName2
		dc.l	0
SetAFD3Tags	dc.l	GTST_String,AFDFileName3
		dc.l	0
SetAFD4Tags	dc.l	GTST_String,AFDFileName4
		dc.l	0

SetADD1Tags	dc.l	GTST_String,ADDName1
		dc.l	0

SetADD2Tags	dc.l	GTST_String,ADDName2
		dc.l	0

SetSCSI0Tags	dc.l	GTST_String,SCSIName0
		dc.l	0

SetSCSI1Tags	dc.l	GTST_String,SCSIName1
		dc.l	0

SetSCSI2Tags	dc.l	GTST_String,SCSIName2
		dc.l	0

SetSCSI3Tags	dc.l	GTST_String,SCSIName3
		dc.l	0

SetSCSI4Tags	dc.l	GTST_String,SCSIName4
		dc.l	0

SetSCSI5Tags	dc.l	GTST_String,SCSIName5
		dc.l	0

SetSCSI6Tags	dc.l	GTST_String,SCSIName6
		dc.l	0

SetSERDATags	dc.l	GTST_String,SERDNameA
		dc.l	0

SetSERDBTags	dc.l	GTST_String,SERDNameB
		dc.l	0

SetSana2Tags	dc.l	GTST_String,Sana2Name
		dc.l	0

SetExtVideo1Tags dc.l	GTST_String,ExtVideoName1
		dc.l	0

SetExtVideo2Tags dc.l	GTST_String,ExtVideoName2
		dc.l	0

SetIntegerTags	dc.l	GTIN_Number
SetIntTagsVal	dc.l	0
		dc.l	0

SetNumberTags	dc.l	GTNM_Number
SetNumTagsVal	dc.l	0
		dc.l	0

SetCycleTags	dc.l	GTCY_Active
SetCycTagsVal	dc.l	0
		dc.l	0

SetCheckOnTags	dc.l	GTCB_Checked,-1
		dc.l	0

SetCheckOffTags	dc.l	GTCB_Checked,0
		dc.l	0

SetDID1Tags	dc.l	GTTX_Text,DisplayName1+16
		dc.l	0

SetDID2Tags	dc.l	GTTX_Text,DisplayName2+16
		dc.l	0

SetAIDTags	dc.l	GTTX_Text,AudioName
		dc.l	0

DisableTags	dc.l	GA_Disabled,-1
		dc.l	0

EnableTags	dc.l	GA_Disabled,0
		dc.l	0

; Taglists für AHI
GetAudioIDTags	dc.l	AHIDB_Name,AudioName
		dc.l	AHIDB_BufferLen,80
		dc.l	0

AudioReqTags	dc.l	AHIR_SleepWindow,-1
		dc.l	AHIR_Window
AudioReqWindow	dc.l	0
		dc.l	0

DoAudioReqTags dc.l	AHIR_InitialAudioID
AudioReqID	dc.l	0
		dc.l	0

; Prefs-Icon
PrefsIcon	dc.w	WB_DISKMAGIC,WB_DISKVERSION
		dc.l	0
		dc.w	0,0,54,23
		dc.w	4,1,1
		dc.l	PrefsI1,0,0,0,0
		dc.w	0
		dc.l	1
		dc.b	WBPROJECT,0
		dc.l	DefaultTool,0
		dc.l	NO_ICON_POSITION,NO_ICON_POSITION
		dc.l	0,0,0

; Image für Prefs-Icon
PrefsI1		dc.w	0,0,54,22,8
		dc.l	PrefsI1Data
		dc.b	255,0
		dc.l	0

; Icon-Daten
		SECTION	"CHIPDATA",DATA,CHIP

PrefsI1Data	dc.w	$0000,$0000,$0000,$0400,$0000,$0000,$0000,$0C00
		dc.w	$003F,$FC00,$0000,$0C00,$00C0,$0300,$0780,$0C00
		dc.w	$0107,$E080,$1FC0,$0C00,$0208,$1040,$3FC0,$0C00
		dc.w	$0204,$105F,$3FE0,$0C00,$0204,$107F,$FFF8,$0C00
		dc.w	$0108,$207F,$FFFE,$0C00,$00F0,$C0FF,$FFF8,$0C00
		dc.w	$0003,$01FF,$FFF0,$0C00,$0004,$0755,$5550,$0C00
		dc.w	$0008,$1A00,$000E,$0C00,$0010,$E200,$0001,$0C00
		dc.w	$0008,$4100,$0002,$0C00,$0007,$8080,$0004,$0C00
		dc.w	$0008,$4060,$0018,$0C00,$0008,$4018,$7860,$0C00
		dc.w	$0007,$8007,$8780,$0C00,$0000,$0000,$0000,$0C00
		dc.w	$0000,$0000,$0000,$0C00,$7FFF,$FFFF,$FFFF,$FC00

		dc.w	$FFFF,$FFFF,$FFFF,$F800,$D555,$5555,$5555,$5000
		dc.w	$D540,$0155,$5555,$5000,$D53F,$FC55,$5055,$5000
		dc.w	$D4F8,$1F55,$4015,$5000,$D5F5,$4F95,$4015,$5000
		dc.w	$D5F9,$4F80,$4015,$5000,$D5F9,$4F80,$0005,$5000
		dc.w	$D4F5,$5F80,$0001,$5000,$D505,$3F7F,$FFF5,$5000
		dc.w	$D554,$FEFF,$FFE5,$5000,$D553,$F955,$5545,$5000
		dc.w	$D557,$E400,$0001,$5000,$D54F,$1400,$0000,$5000
		dc.w	$D557,$9455,$5555,$5000,$D550,$552A,$AAA9,$5000
		dc.w	$D557,$951F,$FFE5,$5000,$D557,$9547,$8795,$5000
		dc.w	$D550,$5550,$5055,$5000,$D555,$5555,$5555,$5000
		dc.w	$D555,$5555,$5555,$5000,$8000,$0000,$0000,$0000

		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0780,$0000,$0000,$0000,$1E00,$0000
		dc.w	$0000,$0000,$1800,$0000,$0000,$001F,$07E0,$0000
		dc.w	$0000,$003F,$FFF8,$0000,$0000,$007F,$FFF0,$0000
		dc.w	$0000,$00FF,$FFE0,$0000,$0000,$01FF,$FFE0,$0000
		dc.w	$0000,$01FF,$FFF0,$0000,$0000,$01FF,$FFFE,$0000
		dc.w	$0000,$00FF,$FFFC,$0000,$0000,$007F,$FFF8,$0000
		dc.w	$0000,$001F,$FFE0,$0000,$0000,$0007,$8780,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000

		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0780,$0000,$0000,$0000,$1E00,$0000
		dc.w	$0000,$0000,$1800,$0000,$0000,$001F,$07E0,$0000
		dc.w	$0000,$003F,$FFF8,$0000,$0000,$007F,$FFF0,$0000
		dc.w	$0000,$00FF,$FFE0,$0000,$0000,$01FF,$FFE0,$0000
		dc.w	$0000,$01FF,$FFF0,$0000,$0000,$01FF,$FFFE,$0000
		dc.w	$0000,$00FF,$FFFC,$0000,$0000,$007F,$FFF8,$0000
		dc.w	$0000,$001F,$FFE0,$0000,$0000,$0007,$8780,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000

		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0780,$0000,$0000,$0000,$1E00,$0000
		dc.w	$0000,$0000,$1800,$0000,$0000,$001F,$07E0,$0000
		dc.w	$0000,$003F,$FFF8,$0000,$0000,$007F,$FFF0,$0000
		dc.w	$0000,$00FF,$FFE0,$0000,$0000,$01FF,$FFE0,$0000
		dc.w	$0000,$01FF,$FFF0,$0000,$0000,$01FF,$FFFE,$0000
		dc.w	$0000,$00FF,$FFFC,$0000,$0000,$007F,$FFF8,$0000
		dc.w	$0000,$001F,$FFE0,$0000,$0000,$0007,$8780,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000

		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0780,$0000,$0000,$0000,$1E00,$0000
		dc.w	$0000,$0000,$1800,$0000,$0000,$001F,$07E0,$0000
		dc.w	$0000,$003F,$FFF8,$0000,$0000,$007F,$FFF0,$0000
		dc.w	$0000,$00FF,$FFE0,$0000,$0000,$01FF,$FFE0,$0000
		dc.w	$0000,$01FF,$FFF0,$0000,$0000,$01FF,$FFFE,$0000
		dc.w	$0000,$00FF,$FFFC,$0000,$0000,$007F,$FFF8,$0000
		dc.w	$0000,$001F,$FFE0,$0000,$0000,$0007,$8780,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000

		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0780,$0000,$0000,$0000,$1E00,$0000
		dc.w	$0000,$0000,$1800,$0000,$0000,$001F,$07E0,$0000
		dc.w	$0000,$003F,$FFF8,$0000,$0000,$007F,$FFF0,$0000
		dc.w	$0000,$00FF,$FFE0,$0000,$0000,$01FF,$FFE0,$0000
		dc.w	$0000,$01FF,$FFF0,$0000,$0000,$01FF,$FFFE,$0000
		dc.w	$0000,$00FF,$FFFC,$0000,$0000,$007F,$FFF8,$0000
		dc.w	$0000,$001F,$FFE0,$0000,$0000,$0007,$8780,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000

		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0780,$0000,$0000,$0000,$1E00,$0000
		dc.w	$0000,$0000,$1800,$0000,$0000,$001F,$07E0,$0000
		dc.w	$0000,$003F,$FFF8,$0000,$0000,$007F,$FFF0,$0000
		dc.w	$0000,$00FF,$FFE0,$0000,$0000,$01FF,$FFE0,$0000
		dc.w	$0000,$01FF,$FFF0,$0000,$0000,$01FF,$FFFE,$0000
		dc.w	$0000,$00FF,$FFFC,$0000,$0000,$007F,$FFF8,$0000
		dc.w	$0000,$001F,$FFE0,$0000,$0000,$0007,$8780,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w	$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000


**
** Nicht initialisierte Daten
**

		SECTION	"BSS",BSS

PREFSBUFSIZE	= 4096
PREFSMINSIZE	= 1024			;3.x files are 1546 bytes or more
PREFSMAXSIZE	= 65536
PrefsBad	ds.b	1		;OpenThePrefs: the file was refused
		even
OpenKeepName	ds.b	256		;PrefsName while "Open..." tries a file
SaveTmpName	ds.b	256+24		;SaveThePrefs: the file while it is written
PrefsLoadBuf	ds.b	PREFSBUFSIZE	;a settings file is checked here before it is used
DisplayName1	ds.b	nif_SIZEOF	;Name des Amiga-DisplayModes (DTAG_NAME)
DisplayName2	ds.b	nif_SIZEOF	;Name des Amiga-DisplayModes (DTAG_NAME)
TheRect		ds.b	ra_SIZEOF

AFD2kEmptyBuf	ds.b	2048		;2k leerer Puffer zum Filedisk-Erzeugen

FileName	ds.b	80		;Puffer für FileRequester
DirName		ds.b	256		;Puffer für FileRequester
LongPath	ds.b	256		;Zusammengesetzter Pfad (SetPathField)

AudioName	ds.b	80		;Puffer für AHI

FileReqResponse ds.l	1	;Rückgabe des GetAFDName-Requesters
FileDiskSize	ds.l	1	;Rückgabe des EnterSize-Requesters

SettingsSet	ds.l	1	;Signalmasken für Fenster

TheWindow	ds.l	1	;Fenster, an dem eine Nachricht eingetroffen ist
TheClass	ds.l	1	;Daten der Nachricht
TheGadget	ds.l	1
TheCode		ds.w	1
TheMouseX	ds.w	1
AFDExtraGad	ds.l	1	;DoGetAFDName mit d4 < 0: das String-Gadget
TheMouseY	ds.w	1

		END
