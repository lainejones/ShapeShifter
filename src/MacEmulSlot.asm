**
** Macintosh IIci-Emulator - Slot sResources
** =========================================
**
** © Copyright 1994-2001 Christian Bauer
**

		INCLUDE	"ShapeShifter_rev.i"

; Makros
Offs		MACRO	;ID, Adr
		dc.l	((\1&$ff)<<24)|((\2-*)&$ffffff)
		ENDM

Rsrc		MACRO	;ID, Dat
		dc.l	((\1&$ff)<<24)|(\2&$ffffff)
		ENDM

EndOfList	MACRO
		dc.l	$ff000000
		ENDM

VMODE_1BIT	= 0
VMODE_2BIT	= 1
VMODE_4BIT	= 2
VMODE_8BIT	= 3
VMODE_16BIT	= 4
VMODE_24BIT	= 5

		XDEF	SROMStart
		XDEF	SROMLength
		XDEF	InitSlot

		XREF	VideoOpen
		XREF	VideoPrime
		XREF	VideoCtrl
		XREF	VideoStatus
		XREF	VideoClose
		XREF	ScreenX1
		XREF	ScreenY1
		XREF	ScreenX2
		XREF	ScreenY2
		XREF	BytesPerRow1
		XREF	BytesPerRow2
		XREF	ScrnBase1
		XREF	ScrnBase2
		XREF	VideoMode1
		XREF	ModeCount1		;MacEmulVideo
		XREF	ModeStart1
		XREF	ModeVM1
		XDEF	SetModeParams
		XREF	VideoMode2
		XREF	NumMonitors
		XREF	CPUType

		XREF	EtherOpen
		XREF	EtherPrime
		XREF	EtherControl
		XREF	EtherStatus
		XREF	EtherClose

		SECTION	"CODE",CODE


**
** Initialisierung (nach OpenVideo und OpenNetwork aufrufen)
**

InitSlot	moveq	#0,d4			;Monitor 1: ein Modus pro Farbtiefe
		moveq	#0,d5			;d5: groesster Grafikspeicher
1$		move.l	d4,d0
		mulu	#VidModeLength,d0
		lea	VidModeParms1_0,a0
		add.l	d0,a0
		move.l	d4,d0
		lsl.l	#4,d0			;VIDMODELISTLEN
		lea	VidMode1_0,a1
		add.l	d0,a1
		lea	ModeVM1,a2
		move.w	d4,d0
		add.w	d0,d0
		move.w	(a2,d0.w),d0
		move.l	ScreenX1,d1		;BytesPerRow: X << VMODE >> 3
		lsl.l	d0,d1			; (der Startmodus: der echte Wert)
		lsr.l	#3,d1
		cmp.w	ModeStart1,d4
		bne	2$
		move.l	BytesPerRow1,d1
2$		move.l	d1,d2
		mulu	ScreenY1+2,d2
		cmp.l	d5,d2
		bls	3$
		move.l	d2,d5
3$		move.l	ScreenX1,d2
		move.l	ScreenY1,d3
		bsr	InitVidParam
		addq.w	#1,d4
		cmp.w	ModeCount1,d4
		blo	1$
		lea	VidModeTab1,a0		;Liste nach dem letzten Modus beenden
		move.w	d4,d0
		lsl.w	#2,d0
		move.l	#$ff000000,(a0,d0.w)
		move.l	d5,MinorLength1

		lea	VidModeParms2,a0
		lea	VidMode2,a1
		move.w	VideoMode2,d0
		move.l	BytesPerRow2,d1
		move.l	ScreenX2,d2
		move.l	ScreenY2,d3
		bsr	InitVidParam

		move.l	ScrnBase1,MinorBase1
		move.l	ScrnBase2,MinorBase2

		move.l	BytesPerRow2,d0
		move.l	ScreenY2,d1
		mulu	d1,d0
		move.l	d0,MinorLength2

		tst.w	NumMonitors
		bne	10$

		move.l	#sRsrcDir1,d0		;1 Monitor
		sub.l	#FormatBlock,d0
		and.l	#$00ffffff,d0
		move.l	d0,FormatBlock
		bra	11$

10$		move.l	#sRsrcDir2,d0		;2 Monitore
		sub.l	#FormatBlock,d0
		and.l	#$00ffffff,d0
		move.l	d0,FormatBlock
11$
		cmp.w	#4,CPUType		;68040?
		bne	12$
		move.l	#CPUType040,d0		;Ja
		sub.l	#sRsrcCPU,d0
		or.l	#$01000000,d0
		move.l	d0,sRsrcCPU
		move.l	#CPUName040,d0
		sub.l	#sRsrcCPU+4,d0
		or.l	#$02000000,d0
		move.l	d0,sRsrcCPU+4
12$		rts

; Nach einem Farbtiefenwechsel: Basis (als Abstand von MinorBase1) und
; BytesPerRow des Modus d0 (0, 1, ...) von Monitor 1 setzen
; d1: Adresse des Grafikspeichers, d2: BytesPerRow
SetModeParams	movem.l	d0-d1/a0,-(sp)
		mulu	#VidModeLength,d0
		lea	VidModeParms1_0,a0
		add.l	d0,a0
		sub.l	MinorBase1,d1
		move.l	d1,4(a0)		;Base offset
		move.w	d2,8(a0)		;Row bytes
		movem.l	(sp)+,d0-d1/a0
		rts

; VidParam initialisieren
; a0: VideoModeParamRsrc
; a1: VideoModeRsrc
; d0: VideoMode
; d1: BytesPerRow
; d2: ScreenX
; d3: ScreenY
InitVidParam	cmp.w	#VMODE_1BIT,d0
		bne	1$
		move.w	#1,36(a0)
		move.w	#1,38(a0)
		move.w	#1,40(a0)
		bra	6$

1$		cmp.w	#VMODE_2BIT,d0
		bne	2$
		move.w	#2,36(a0)
		move.w	#1,38(a0)
		move.w	#2,40(a0)
		bra	6$

2$		cmp.w	#VMODE_4BIT,d0
		bne	3$
		move.w	#4,36(a0)
		move.w	#1,38(a0)
		move.w	#4,40(a0)
		bra	6$

3$		cmp.w	#VMODE_8BIT,d0
		bne	4$
		move.w	#8,36(a0)
		move.w	#1,38(a0)
		move.w	#8,40(a0)
		bra	6$

4$		cmp.w	#VMODE_16BIT,d0
		bne	5$
		move.w	#2,10(a1)
		move.w	#16,34(a0)
		move.w	#16,36(a0)
		move.w	#3,38(a0)
		move.w	#5,40(a0)
		bra	6$

5$		cmp.w	#VMODE_24BIT,d0
		bne	7$
		move.w	#2,10(a1)
		move.w	#16,34(a0)
		move.w	#32,36(a0)
		move.w	#3,38(a0)
		move.w	#8,40(a0)

6$		move.w	d1,8(a0)
		move.w	d3,14(a0)
		move.w	d2,16(a0)
7$		rts


**
** sResource Directory
**

		SECTION	"DATA",DATA

SROMStart

; Monitor 1, CPU, Ethernet
sRsrcDir1	Offs	$01,sRsrcBoard
		Offs	$86,sRsrcVideo1
		Offs	$f0,sRsrcCPU
		Offs	$fd,sRsrcEthernet
		EndOfList

; Monitor 1, Monitor 2, CPU, Ethernet
sRsrcDir2	Offs	$01,sRsrcBoard
		Offs	$86,sRsrcVideo1
		Offs	$87,sRsrcVideo2
		Offs	$f0,sRsrcCPU
		Offs	$fd,sRsrcEthernet
		EndOfList


**
** Board sResource
**

sRsrcBoard	Offs	$01,BoardType	;Board descriptor
		Offs	$02,BoardName	;Board name
		Rsrc	$20,31		;Board ID
		Offs	$22,PrimaryInit	;Primary Init
		Offs	$24,VendorInfo	;Vendor info
		Offs	$26,SecondaryInit ;Secondary Init
		EndOfList

BoardType	dc.w	1,0,0,0		;Board sResource

BoardName	dc.b	"Macintosh IIci Built-In Video",0
		EVEN

VendorInfo	Offs	$01,VendorID	;Vendor ID
		Offs	$03,RevLevel	;Revision level
		Offs	$04,PartNum	;Part number
		Offs	$05,Date	;ROM build date
		EndOfList

VendorID	dc.b	"Christian Bauer",0
		EVEN
RevLevel	VERS
		dc.b	0
		EVEN
PartNum		dc.b	"ShapeShifter (FLY 5)",0
		EVEN
Date		DATE
		dc.b	0
		EVEN

PrimaryInit	dc.l	PrimaryEnd-PrimaryInit
		dc.b	2,2,0,0		;Rev. 2, 68020
		dc.l	4
		move.w	#1,2(a0)	;seStatus
		rts
PrimaryEnd

SecondaryInit	dc.l	SecondaryEnd-SecondaryInit
		dc.b	2,2,0,0		;Rev. 2, 68020
		dc.l	4
		move.w	#1,2(a0)	;seStatus
		rts
SecondaryEnd


**
** Video sResources
**

sRsrcVideo1	Offs	$01,VideoType1	;Video type descriptor
		Offs	$02,VideoName1	;Driver name
		Offs	$04,VidDrvrDir1	;Driver directory
		Rsrc	$08,4242	;Hardware device ID
		Offs	$0a,MinorBase1	;Frame buffer base
		Offs	$0b,MinorLength1 ;Frame buffer length
		Offs	$40,GammaDir	;Gamma directory
		Rsrc	$7d,%110	;Video Attributes: Default to Color, Built-In
VidModeTab1	Offs	$80,VidMode1_0	;Video mode parameters: one mode per
		Offs	$81,VidMode1_1	; depth (InitSlot ends the list after
		Offs	$82,VidMode1_2	; the last one)
		Offs	$83,VidMode1_3
		Offs	$84,VidMode1_4
		Offs	$85,VidMode1_5
		EndOfList

VideoType1	dc.w	3,1,1,4242	;Display Video Apple Amiga 1

VideoName1	dc.b	"Display_Video_Apple_Amiga1",0
		EVEN

MinorBase1	dc.l	0
MinorLength1	dc.l	0

sRsrcVideo2	Offs	$01,VideoType2	;Video type descriptor
		Offs	$02,VideoName2	;Driver name
		Offs	$04,VidDrvrDir2	;Driver directory
		Rsrc	$08,4243	;Hardware device ID
		Offs	$0a,MinorBase2	;Frame buffer base
		Offs	$0b,MinorLength2 ;Frame buffer length
		Offs	$40,GammaDir	;Gamma directory
		Rsrc	$7d,%110	;Video Attributes: Default to Color, Built-In
		Offs	$80,VidMode2	;Video mode parameters
		EndOfList

VideoType2	dc.w	3,1,1,4243	;Display Video Apple Amiga 2

VideoName2	dc.b	"Display_Video_Apple_Amiga2",0
		EVEN

MinorBase2	dc.l	0
MinorLength2	dc.l	0

VidDrvrDir1	Offs	$02,VideoDrvr1	;sMacOS68020
		EndOfList

VidDrvrDir2	Offs	$02,VideoDrvr2	;sMacOS68020
		EndOfList

VideoDrvr1	dc.l	VideoDrvrLength1
VideoHdr1	dc.w	$4c00		;Flags
		dc.w	0,0,0
		dc.w	VDOpen-VideoHdr1
		dc.w	VDPrime-VideoHdr1
		dc.w	VDControl-VideoHdr1
		dc.w	VDStatus-VideoHdr1
		dc.w	VDClose-VideoHdr1
		dc.b	27,".Display_Video_Apple_Amiga1"
		EVEN
		dc.w	1		;Driver version

VideoDrvr2	dc.l	VideoDrvrLength2
VideoHdr2	dc.w	$4c00		;Flags
		dc.w	0,0,0
		dc.w	VDOpen-VideoHdr2
		dc.w	VDPrime-VideoHdr2
		dc.w	VDControl-VideoHdr2
		dc.w	VDStatus-VideoHdr2
		dc.w	VDClose-VideoHdr2
		dc.b	27,".Display_Video_Apple_Amiga2"
		EVEN
		dc.w	1		;Driver version

VDOpen		dc.w	$4ef9
		dc.l	VideoOpen
VDPrime		dc.w	$4ef9
		dc.l	VideoPrime
VDControl	dc.w	$4ef9
		dc.l	VideoCtrl
VDStatus	dc.w	$4ef9
		dc.l	VideoStatus
VDClose		dc.w	$4ef9
		dc.l	VideoClose
VideoDrvrLength1 = *-VideoDrvr1
VideoDrvrLength2 = *-VideoDrvr2

GammaDir	Offs	$80,DefaultGamma
		EndOfList

DefaultGamma	dc.l	GammaLength
		dc.w	$2000		;Resource ID
		dc.b	"Mac HiRes Std Gamma",0
		EVEN
		dc.w	0		;Version
		dc.w	0		;Type
		dc.w	0		;FormulaSize
		dc.w	1		;ChanCnt
		dc.w	$0100		;DataCnt
		dc.w	8		;ChanWidth
		dc.l	$0005090B,$0E101315,$17191B1D,$1E202224
		dc.l	$2527282A,$2C2D2F30,$31333436,$37383A3B
		dc.l	$3C3E3F40,$42434445,$4748494A,$4B4D4E4F
		dc.l	$50515254,$55565758,$595A5B5C,$5E5F6061
		dc.l	$62636465,$66676869,$6A6B6C6D,$6E6F7071
		dc.l	$72737475,$76777879,$7A7B7C7D,$7E7F8081
		dc.l	$81828384,$85868788,$898A8B8C,$8C8D8E8F
		dc.l	$90919293,$94959596,$9798999A,$9B9B9C9D
		dc.l	$9E9FA0A1,$A1A2A3A4,$A5A6A6A7,$A8A9AAAB
		dc.l	$ABACADAE,$AFB0B0B1,$B2B3B4B4,$B5B6B7B8
		dc.l	$B8B9BABB,$BCBCBDBE,$BFC0C0C1,$C2C3C3C4
		dc.l	$C5C6C7C7,$C8C9CACA,$CBCCCDCD,$CECFD0D0
		dc.l	$D1D2D3D3,$D4D5D6D6,$D7D8D9D9,$DADBDCDC
		dc.l	$DDDEDFDF,$E0E1E1E2,$E3E4E4E5,$E6E7E7E8
		dc.l	$E9E9EAEB,$ECECEDEE,$EEEFF0F1,$F1F2F3F3
		dc.l	$F4F5F5F6,$F7F8F8F9,$FAFAFBFC,$FCFDFEFF
GammaLength	= *-DefaultGamma

VidMode1_0	Offs	$01,VidModeParms1_0	;Video parameters
		Rsrc	$03,1			;Page count
		Rsrc	$04,0			;Device type
		EndOfList
VIDMODELISTLEN	= 16

VidMode1_1	Offs	$01,VidModeParms1_1
		Rsrc	$03,1
		Rsrc	$04,0
		EndOfList

VidMode1_2	Offs	$01,VidModeParms1_2
		Rsrc	$03,1
		Rsrc	$04,0
		EndOfList

VidMode1_3	Offs	$01,VidModeParms1_3
		Rsrc	$03,1
		Rsrc	$04,0
		EndOfList

VidMode1_4	Offs	$01,VidModeParms1_4
		Rsrc	$03,1
		Rsrc	$04,0
		EndOfList

VidMode1_5	Offs	$01,VidModeParms1_5
		Rsrc	$03,1
		Rsrc	$04,0
		EndOfList

VidModeParms1_0	dc.l	VidModeLength
		dc.l	0		;Base offset
		dc.w	0		;Row bytes
		dc.w	0,0,0,0		;Bounds
		dc.w	0,0		;Version, pack type
		dc.l	0		;Pack size
		dc.l	$00480000	;HRes
		dc.l	$00480000	;VRes
		dc.w	0,0,0,0		;Pixel specs
		dc.l	0		;Plane size
VidModeLength	= *-VidModeParms1_0

VidModeParms1_1	dc.l	VidModeLength
		dc.l	0		;Base offset
		dc.w	0		;Row bytes
		dc.w	0,0,0,0		;Bounds
		dc.w	0,0		;Version, pack type
		dc.l	0		;Pack size
		dc.l	$00480000	;HRes
		dc.l	$00480000	;VRes
		dc.w	0,0,0,0		;Pixel specs
		dc.l	0		;Plane size

VidModeParms1_2	dc.l	VidModeLength
		dc.l	0		;Base offset
		dc.w	0		;Row bytes
		dc.w	0,0,0,0		;Bounds
		dc.w	0,0		;Version, pack type
		dc.l	0		;Pack size
		dc.l	$00480000	;HRes
		dc.l	$00480000	;VRes
		dc.w	0,0,0,0		;Pixel specs
		dc.l	0		;Plane size

VidModeParms1_3	dc.l	VidModeLength
		dc.l	0		;Base offset
		dc.w	0		;Row bytes
		dc.w	0,0,0,0		;Bounds
		dc.w	0,0		;Version, pack type
		dc.l	0		;Pack size
		dc.l	$00480000	;HRes
		dc.l	$00480000	;VRes
		dc.w	0,0,0,0		;Pixel specs
		dc.l	0		;Plane size

VidModeParms1_4	dc.l	VidModeLength
		dc.l	0		;Base offset
		dc.w	0		;Row bytes
		dc.w	0,0,0,0		;Bounds
		dc.w	0,0		;Version, pack type
		dc.l	0		;Pack size
		dc.l	$00480000	;HRes
		dc.l	$00480000	;VRes
		dc.w	0,0,0,0		;Pixel specs
		dc.l	0		;Plane size

VidModeParms1_5	dc.l	VidModeLength
		dc.l	0		;Base offset
		dc.w	0		;Row bytes
		dc.w	0,0,0,0		;Bounds
		dc.w	0,0		;Version, pack type
		dc.l	0		;Pack size
		dc.l	$00480000	;HRes
		dc.l	$00480000	;VRes
		dc.w	0,0,0,0		;Pixel specs
		dc.l	0		;Plane size


VidMode2	Offs	$01,VidModeParms2	;Video parameters
		Rsrc	$03,1			;Page count
		Rsrc	$04,0			;Device type
		EndOfList

VidModeParms2	dc.l	VidModeLength
		dc.l	0		;Base offset
		dc.w	0		;Row bytes
		dc.w	0,0,0,0		;Bounds
		dc.w	0,0		;Version, pack type
		dc.l	0		;Pack size
		dc.l	$00480000	;HRes
		dc.l	$00480000	;VRes
		dc.w	0,0,0,0		;Pixel specs
		dc.l	0		;Plane size


**
** CPU sResources
**

sRsrcCPU	Offs	$01,CPUType030	;Type descriptor
		Offs	$02,CPUName030	;CPU name
		Offs	$81,CPURsrc1	;Major RAM space
		Offs	$82,CPURsrc2	;Minor RAM space
		EndOfList

CPUType030	dc.w	10,4,0,24	;CPU 68030 MacIIFamily
CPUType040	dc.w	10,5,0,24	;CPU 68040

CPUName030	dc.b	"CPU_68030_\_MacIIFamily",0
		EVEN
CPUName040	dc.b	"CPU_68040",0
		EVEN

CPURsrc1	dc.l	0
		dc.l	$7fffffff

CPURsrc2	dc.l	$f0800000
		dc.l	$f0ffffff


**
** Ethernet sResources
**

sRsrcEthernet	Offs	$01,EtherType	;Type descriptor
		Offs	$02,EtherName	;Driver Name
		Offs	$04,EtherDrvrDir
		Rsrc	$07,2		;Flags=OpenAtStart
		Rsrc	$08,1		;Device ID
		EndOfList

EtherType	dc.w	4,1,1,4242	;Network Ethernet Apple SANA-2

EtherName	dc.b	"Network_Ethernet_Apple_SANA-2",0
		EVEN

EtherDrvrDir	Offs	$02,EtherDrvr	;sMacOS68020
		EndOfList

EtherDrvr	dc.l	EtherDrvrLength
EtherHdr	dc.w	$4400		;Flags
		dc.w	0,0,0
		dc.w	EDOpen-EtherHdr
		dc.w	EDPrime-EtherHdr
		dc.w	EDControl-EtherHdr
		dc.w	EDStatus-EtherHdr
		dc.w	EDClose-EtherHdr
		dc.b	5,".ENET"
		dc.w	$0111,$8000	;Version
		dc.w	0
		dc.b	7,"1.1.1  "
		dc.b	34,"ShapeShifter SANA-2 Network Driver"
		EVEN

EDOpen		dc.w	$4ef9
		dc.l	EtherOpen
EDPrime		dc.w	$4ef9
		dc.l	EtherPrime
EDControl	dc.w	$4ef9
		dc.l	EtherControl
EDStatus	dc.w	$4ef9
		dc.l	EtherStatus
EDClose		dc.w	$4ef9
		dc.l	EtherClose

EtherDrvrLength	= *-EtherDrvr

**
** Format/Header Blocks
**

FormatBlock	dc.l	(sRsrcDir1-FormatBlock)&$ffffff ;sResource directory
		dc.l	SROMLength	;Length of declaration data
		dc.l	0		;CRC
		dc.b	1,1		;Revision level, format
		dc.l	$5a932bc7	;Test pattern
		dc.b	0,$0f		;Byte lanes

SROMLength	= *-SROMStart
