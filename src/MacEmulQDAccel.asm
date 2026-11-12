**
** Macintosh IIci-Emulator - QuickDraw-Beschleunigung
** ==================================================
**
** © Copyright 1995-2001 Christian Bauer
**

		XDEF	AccelQuickDraw

; CyberGfx
InvertPixelArray = -144
FillPixelArray = -150


*
* Beschleuniger installieren
*

; Nur bei nicht refreshtem CyberGfx
AccelQuickDraw	tst.b	IsRefreshing
		bne	1$
		cmp.w	#VTYPE_CYBER,VideoType1
		bne	1$

		move.l	VideoInfo1+vScreen,a0
		lea	sc_RastPort(a0),a0
		move.l	a0,QDRastPort1

		move.l	$1a00,OldBitBlt
		move.l	$1c70,OldFastLine
		move.l	#BitBlt,$1a00
		st	AccelBltOK
		cmp.w	#VMODE_8BIT,VideoMode1
		bne	1$
		move.l	#FastLine,$1c70
		st	AccelLineOK
1$		rts


*
* FastLine(): Horizontale/vertikale Linien zeichnen
*
* a6: Zeiger auf Datenbereich
*     -116.w Y1 lokal
*     -114.w X1 lokal
*     -112.w Y2 lokal
*     -110.w X2 lokal
*     -152.w Mode: 0 APen, 1 Xor, 2 BBen
*     -160.l APen
*     -164.l BPen
*     -212.w VideoMode
*     -238.w Offset Y
*     -236.w Offset X
*     -284.w Y2 ungeclippt
*     -288.w Y1 ungeclippt
*     -292.l A7
*     -300.l X1 fixed
*     -316.l A5
*     -324.b Flag: Onscreen
*

FastLine	tst.b	AccelLineOK	;Gilt fuer den Bildschirm? (Farbtiefe gewechselt)
		beq	DoOldFastLine
		tst.b	-324(a6)	;Onscreen?
		beq	DoOldFastLine
		cmp.w	d1,d3		;Ja, vertikal?
		beq	DoOldFastLine

; Vertikale Linie zeichnen
		move.l	a6,a5
		move.l	QDRastPort1,a4
		move.l	_GfxBase,a6
		move.l	a4,a1
		move.l	-160(a5),d0	;APen
		move.l	-164(a5),d1	;BPen
		move.w	-152(a5),d2
		move.l	(LineModeTab,pc,d2.w*4),d2 ;DrawMode
		EJSRLIB	SetABPenDrMd
		move.l	a4,a1
		move.w	-114(a5),d0
		move.w	-116(a5),d1
		move.w	-112(a5),d3
		move.w	d0,d2
		subq.w	#1,d3
		sub.w	-236(a5),d0	;OffsetPt
		sub.w	-238(a5),d1
		sub.w	-236(a5),d2	;OffsetPt
		sub.w	-238(a5),d3
		EJSRLIB	RectFill
		EJSRLIB	WaitBlit
		move.l	a5,a6

; Aufräumen und beenden
		move.l	-316(a6),a5
		tst.b	-324(a6)
		beq	1$
		jsr	([$f4c])	;ShowCursor
1$		bset	#7,$938		;HiliteMode
		move.l	-292(a6),a7
		movem.l	(sp)+,d0-d7/a1-a5
		unlk	a6
		rtd	#8

DoOldFastLine	jmp	([OldFastLine])	;Zur alten Routine

		CNOP	0,4
		dc.l	RP_JAM1
LineModeTab	dc.l	RP_JAM1
		dc.l	RP_COMPLEMENT
		dc.l	RP_JAM2|RP_INVERSVID


*
* BitBlt(): Bit Block Transfer
*
* a6: Zeiger auf Datenbereich
*
* a2: SrcRect
* a3: DestRect
* a4: SrcPixMap
* a5: DestPixMap
*

; Wird innerhalb des Bildschirmspeichers geblittet?
BitBlt		tst.b	AccelBltOK	;Gilt fuer den Bildschirm? (Farbtiefe gewechselt)
		beq	DoOldBitBlt
		move.l	(a4),d0
		cmp.l	(a5),d0
		bne	DoOldBitBlt
		cmp.l	ScrnBase1,d0
		bne	DoOldBitBlt

; Ja, ohne Pattern?
		move.w	-152(a6),d6	;d6: Transfer Mode
		cmp.w	#10,d6
		beq	DoInvBlt
		cmp.w	#8,d6
		beq	DoPatBlt
		bhs	DoOldBitBlt

	;	DPRINTF	"SrcRect %08lx %08lx, DestRect %08lx %08lx",(a2),4(a2),(a3),4(a3)
	;	DPRINTF	" ClipRect %08lx %08lx",$ffffff8c(a6),$ffffff90(a6)

; Ja, clippen
		move.w	2(a3),d2	;d2/d3/d4/d5: Geclipptes Ziel
		move.w	-114(a6),d0
		cmp.w	d0,d2
		bge	1$
		move.w	d0,d2
1$		move.w	(a3),d3
		move.w	-116(a6),d0
		cmp.w	d0,d3
		bge	2$
		move.w	d0,d3
2$		move.w	6(a3),d4
		move.w	-110(a6),d0
		cmp.w	d0,d4
		ble	3$
		move.w	d0,d4
3$		move.w	4(a3),d5
		move.w	-112(a6),d0
		cmp.w	d0,d5
		ble	4$
		move.w	d0,d5
4$
		sub.w	d2,d4		;d4/d5: SizeX/Y
		ble	BltNothing
		sub.w	d3,d5
		ble	BltNothing

		sub.w	-578(a6),d2	;d2/d3: DestX/Y global
		sub.w	-580(a6),d3

		move.w	d2,d0		;d0/d1: SrcX/Y global
		move.w	d3,d1
		sub.w	2(a3),d0
		sub.w	(a3),d1
		add.w	2(a2),d0
		add.w	(a2),d1

; Blitten
		move.l	QDRastPort1,a0
		move.l	rp_BitMap(a0),a0
		move.l	a0,a1
		move.b	(BlitModeTab,pc,d6.w),d6 ;Minterm
		moveq	#-1,d7			;Mask
		sub.l	a2,a2			;TempA
		move.l	a6,-(sp)
		move.l	_GfxBase,a6
		EJSRLIB	BltBitMap
		EJSRLIB	WaitBlit
		move.l	(sp)+,a6
BltNothing	rts

BlitModeTab	dc.b	$c0	;srcCopy
		dc.b	$e0	;srcOr
		dc.b	$60	;srcXor
		dc.b	$20	;srcBic
		dc.b	$30	;notSrcCopy
		dc.b	$b0	;notSrcOr
		dc.b	$90	;notSrcXor
		dc.b	$80	;notSrcBic

; "byCBauer" in EBCDIC
		dc.b	$82,$a8,$c3,$c2,$81,$a4,$85,$99

*
* Pattern blitten, zu FillRect entartet?
*

DoPatBlt	tst.w	-142(a6)
		bne	DoOldBitBlt

		cmp.w	#VMODE_15BIT,VideoMode1
		beq	DoPatBlt15
		cmp.w	#VMODE_24BIT,VideoMode1
	;!!	beq	DoPatBlt24
	beq	DoOldBitBlt	;Macht z.Z. Probleme

; 8 Bit, Solid Pattern?
		move.l	-136(a6),a0	;Zeiger auf Pattern
		move.b	(a0)+,d0
		cmp.b	(a0)+,d0
		bne	DoOldBitBlt
		cmp.b	(a0)+,d0
		bne	DoOldBitBlt
		cmp.b	(a0)+,d0
		bne	DoOldBitBlt
		move.l	-136(a6),a0
		move.l	(a0)+,d0
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt

; Ja, Pen setzen
		move.l	QDRastPort1,a1	;d0: APen
		moveq	#0,d1		;BPen
		moveq	#RP_JAM1,d2	;DrMd
		move.l	a6,-(sp)
		move.l	_GfxBase,a6
		EJSRLIB	SetABPenDrMd
		move.l	(sp)+,a6

; Clippen
		bsr	DoBltClip

		cmp.w	d2,d0
		bgt	1$
		cmp.w	d3,d1
		bgt	1$

; Füllen
		move.l	QDRastPort1,a1
		move.l	a6,-(sp)
		move.l	_GfxBase,a6
		EJSRLIB	RectFill
		EJSRLIB	WaitBlit
		move.l	(sp)+,a6
1$		rts

; 15 Bit, Solid Pattern?
DoPatBlt15	move.l	-136(a6),a0	;Zeiger auf Pattern
		move.w	(a0)+,d0
		cmp.w	(a0)+,d0
		bne	DoOldBitBlt
		move.l	-136(a6),a0
		move.l	(a0)+,d0
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt

; Ja, Farbe in ARGB konvertieren
		moveq	#0,d4
		bfextu	d0{17:5},d1
		bfins	d1,d4{8:5}
		bfextu	d0{22:5},d1
		bfins	d1,d4{16:5}
		bfextu	d0{27:5},d1
		bfins	d1,d4{24:5}

; Clippen
		bsr	DoBltClip

		sub.w	d0,d2
		addq.w	#1,d2
		bls	1$
		sub.w	d1,d3
		addq.w	#1,d3
		bls	1$

; Füllen
		move.l	QDRastPort1,a1
		move.l	a6,-(sp)
		move.l	_CyberGfxBase,a6
		addq.w	#1,NoSuperSwitch
		jsr	FillPixelArray(a6)
		subq.w	#1,NoSuperSwitch
		move.l	_GfxBase,a6
		EJSRLIB	WaitBlit
		move.l	(sp)+,a6
1$		rts

; 24 Bit, Solid Pattern?
DoPatBlt24	move.l	-136(a6),a0	;Zeiger auf Pattern
		move.l	(a0)+,d4	;d4: ARGB
		cmp.l	(a0)+,d4
		bne	DoOldBitBlt
		cmp.l	(a0)+,d4
		bne	DoOldBitBlt
		cmp.l	(a0)+,d4
		bne	DoOldBitBlt
		cmp.l	(a0)+,d4
		bne	DoOldBitBlt
		cmp.l	(a0)+,d4
		bne	DoOldBitBlt
		cmp.l	(a0)+,d4
		bne	DoOldBitBlt
		cmp.l	(a0)+,d4
		bne	DoOldBitBlt
		cmp.l	(a0)+,d4
		bne	DoOldBitBlt
		cmp.l	(a0)+,d4
		bne	DoOldBitBlt
		cmp.l	(a0)+,d4
		bne	DoOldBitBlt
		cmp.l	(a0)+,d4
		bne	DoOldBitBlt
		cmp.l	(a0)+,d4
		bne	DoOldBitBlt
		cmp.l	(a0)+,d4
		bne	DoOldBitBlt
		cmp.l	(a0)+,d4
		bne	DoOldBitBlt
		cmp.l	(a0)+,d4
		bne	DoOldBitBlt

; Ja, clippen
		bsr	DoBltClip

		sub.w	d0,d2
		addq.w	#1,d2
		bls	1$
		sub.w	d1,d3
		addq.w	#1,d3
		bls	1$

; Füllen
		move.l	QDRastPort1,a1
		move.l	a6,-(sp)
		move.l	_CyberGfxBase,a6
		addq.w	#1,NoSuperSwitch
		jsr	FillPixelArray(a6)
		subq.w	#1,NoSuperSwitch
		move.l	_GfxBase,a6
		EJSRLIB	WaitBlit
		move.l	(sp)+,a6
1$		rts


*
* Invers blitten, zu InverseRect entartet?
*

DoInvBlt	tst.w	-142(a6)
		bne	DoOldBitBlt

		cmp.w	#VMODE_15BIT,VideoMode1
		beq	DoInvBlt15
		cmp.w	#VMODE_24BIT,VideoMode1
		beq	DoInvBlt24

; 8 Bit, Solid Pattern?
		move.l	-136(a6),a0
		moveq	#-1,d1
		move.l	(a0)+,d0
		cmp.l	d1,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt

; Ja, Pen setzen
		move.l	QDRastPort1,a1
		moveq	#-1,d0			;APen
		moveq	#0,d1			;BPen
		moveq	#RP_COMPLEMENT,d2	;DrMd
		move.l	a6,-(sp)
		move.l	_GfxBase,a6
		EJSRLIB	SetABPenDrMd
		move.l	(sp)+,a6

; Clippen
		bsr	DoBltClip

		cmp.w	d2,d0
		bgt	1$
		cmp.w	d3,d1
		bgt	1$

; Invertieren
		move.l	QDRastPort1,a1
		move.l	a6,-(sp)
		move.l	_GfxBase,a6
		EJSRLIB	RectFill
		EJSRLIB	WaitBlit
		move.l	(sp)+,a6
1$		rts

; 15 Bit, Solid Pattern?
DoInvBlt15	move.l	-136(a6),a0
		move.l	(a0)+,d0
		cmp.l	#$7fff7fff,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt

; Ja, clippen
		bsr	DoBltClip

		sub.w	d0,d2
		addq.w	#1,d2
		bls	1$
		sub.w	d1,d3
		addq.w	#1,d3
		bls	1$

; Invertieren
		move.l	QDRastPort1,a1
		move.l	a6,-(sp)
		move.l	_CyberGfxBase,a6
		addq.w	#1,NoSuperSwitch
		jsr	InvertPixelArray(a6)
		subq.w	#1,NoSuperSwitch
		move.l	_GfxBase,a6
		EJSRLIB	WaitBlit
		move.l	(sp)+,a6
1$		rts

; 24 Bit, Solid Pattern?
DoInvBlt24	move.l	-136(a6),a0
		move.l	(a0)+,d0
		cmp.l	#$00ffffff,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt
		cmp.l	(a0)+,d0
		bne	DoOldBitBlt

; Ja, clippen
		bsr	DoBltClip

		sub.w	d0,d2
		addq.w	#1,d2
		bls	1$
		sub.w	d1,d3
		addq.w	#1,d3
		bls	1$

; Invertieren
		move.l	QDRastPort1,a1
		move.l	a6,-(sp)
		move.l	_CyberGfxBase,a6
		addq.w	#1,NoSuperSwitch
		jsr	InvertPixelArray(a6)
		subq.w	#1,NoSuperSwitch
		move.l	_GfxBase,a6
		EJSRLIB	WaitBlit
		move.l	(sp)+,a6
1$		rts

DoOldBitBlt	jmp	([OldBitBlt])


*
* Rects für BitBlt clippen
*

DoBltClip	move.w	2(a3),d0	;d0/d1/d2/d3: Geclipptes Ziel
		move.w	-114(a6),d7
		cmp.w	d7,d0
		bge	1$
		move.w	d7,d0
1$		move.w	(a3),d1
		move.w	-116(a6),d7
		cmp.w	d7,d1
		bge	2$
		move.w	d7,d1
2$		move.w	6(a3),d2
		move.w	-110(a6),d7
		cmp.w	d7,d2
		ble	3$
		move.w	d7,d2
3$		move.w	4(a3),d3
		move.w	-112(a6),d7
		cmp.w	d7,d3
		ble	4$
		move.w	d7,d3
4$
		sub.w	-578(a6),d0	;d0/d1/d2/d3: Ziel global
		sub.w	-580(a6),d1
		sub.w	-578(a6),d2
		sub.w	-580(a6),d3
		subq.w	#1,d2
		subq.w	#1,d3
		rts


*
* Variablen
*

		CNOP	0,4
OldBitBlt	dc.l	0
OldFastLine	dc.l	0

QDRastPort1	dc.l	0
