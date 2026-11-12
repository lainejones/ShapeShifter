**
** Macintosh IIci-Emulator - Amiga Sound Synthesizer
** =================================================
**
** © Copyright 1993-2001 Christian Bauer
**

DEBUG_DETAIL	SET 0

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/nodes.i"
		INCLUDE	"graphics/gfxbase.i"
		INCLUDE	"devices/audio.i"
		INCLUDE	"devices/ahi.i"
		INCLUDE	"devices/ahi_lib.i"
		INCLUDE	"resources/misc.i"
		INCLUDE	"hardware/custom.i"
		INCLUDE	"hardware/dmabits.i"
		INCLUDE	"hardware/intbits.i"
		INCLUDE	"macros.i"
		INCLUDE	"macinclude.i"

		XDEF	OpenAudio
		XDEF	CloseAudio
		XDEF	InstallSndInput

		XDEF	FakeAudioInt
		XDEF	SquareWaveProc
		XDEF	SndDrvrPatch
		XDEF	SiftPatch1
		XDEF	SiftPatch2
		XDEF	SiftPatch3
		XDEF	SiftPatch4
		XDEF	Snth5Patch1
		XDEF	Snth5Patch1a
		XDEF	Snth5Patch2
		XDEF	Snth5Patch3
		XDEF	Snth5Patch4
		XDEF	Snth5Patch5
		XDEF	ASCRegs
		XDEF	GotChannel01

		XREF	_dmacon
		XREF	_intena
		XREF	_intreq
		XREF	_intreqr
		XREF	_custom
		XREF	_ciaaprb
		XREF	_ciaaddrb

		SECTION	"CODE",CODE


**
** Definitionen
**

; Paula
AUDIO0		= $dff0a0
AUDIO1		= $dff0b0
AUDIO2		= $dff0c0
AUDIO3		= $dff0d0

PAL_CLOCK	= 3546895
NTSC_CLOCK	= 3579545

SAMPLE_FREQ	= 22050

SndInRefNum	= -56		;Nummer des Sound-Input-Treibers

; Voice Control Block
 STRUCTURE VCB,0
	STRUCT	vcbPad1,32
	BYTE	vcbVoiceNumber	;Stimmennummer
	BYTE	vcbState	;Sound aktiv?
			;SquareWave:
			; 1=Ja
			;Record:
			; 1=Aufnahme läuft, 2=Sofort beenden, 3=Pause
	WORD	vcbAllocArray	;Allocation Array
	APTR	vcbAudioIO	;AudioIORequest
	WORD	vcbDMAOn	;DMA an
	WORD	vcbDMAOff	;DMA aus
	WORD	vcbINTOn	;Interrupt an
	WORD	vcbINTOff	;Interrupt aus
	APTR	vcbPaula	;Zeiger auf Paula-Basis
	APTR	vcbBuffer	;Zeiger auf ChipRAM-Puffer
	APTR	vcbPosition	;Aktuelle Position im Sample
	LONG	vcbLength	;Restlänge des Samples
	APTR	vcbIOParam	;Zeiger auf IOParam (Record)
	APTR	vcbSIData	;Zeiger auf Datenbereich (Record)
	WORD	vcbWaveLength	;Länge/2 (SquareWave)
	BYTE	vcbTimbre	;Timbre (SquareWave)
	BYTE	vcbMeterCnt	;Zähler (Record)
	BYTE	vcbMeterMax	;Bisheriges Maximum (Record)
	BYTE	vcbMeterVal	;Level Meter (128..255)
 LABEL	vcb_SIZEOF


**
** Initialisierung
**

; Clock Constant ermitteln
OpenAudio	move.l	#PAL_CLOCK,ClkConst
		move.l	_GfxBase,a0
		btst	#REALLY_PALn,gb_DisplayFlags+1(a0)
		bne	4$
		btst	#PALn,gb_DisplayFlags+1(a0)
		bne	4$
		move.l	#NTSC_CLOCK,ClkConst
4$

; Variablen initialisieren
		clr.l	FIFOPtr
		move.b	#$0f,ASCRegs+$800	;ASC-Version

; VCBs einrichten
		lea	SoundVCB1,a0
		clr.b	vcbVoiceNumber(a0)
		move.b	#1,vcbAllocArray(a0)
		move.w	#DMAF_AUD0|DMAF_SETCLR,vcbDMAOn(a0)
		move.w	#DMAF_AUD0,vcbDMAOff(a0)
		move.w	#INTF_AUD0|INTF_SETCLR,vcbINTOn(a0)
		move.w	#INTF_AUD0,vcbINTOff(a0)
		move.l	#AUDIO0,vcbPaula(a0)
		move.l	#SoundBufV1,vcbBuffer(a0)

		lea	SoundVCB2,a0
		move.b	#1,vcbVoiceNumber(a0)
		move.b	#2,vcbAllocArray(a0)
		move.w	#DMAF_AUD1|DMAF_SETCLR,vcbDMAOn(a0)
		move.w	#DMAF_AUD1,vcbDMAOff(a0)
		move.w	#INTF_AUD1|INTF_SETCLR,vcbINTOn(a0)
		move.w	#INTF_AUD1,vcbINTOff(a0)
		move.l	#AUDIO1,vcbPaula(a0)
		move.l	#SoundBufV2,vcbBuffer(a0)

		lea	SoundVCB3,a0
		move.b	#2,vcbVoiceNumber(a0)
		move.b	#4,vcbAllocArray(a0)
		move.w	#DMAF_AUD2|DMAF_SETCLR,vcbDMAOn(a0)
		move.w	#DMAF_AUD2,vcbDMAOff(a0)
		move.w	#INTF_AUD2|INTF_SETCLR,vcbINTOn(a0)
		move.w	#INTF_AUD2,vcbINTOff(a0)
		move.l	#AUDIO2,vcbPaula(a0)
		move.l	#SoundBufV3,vcbBuffer(a0)

		lea	SoundVCB4,a0
		move.b	#3,vcbVoiceNumber(a0)
		move.b	#8,vcbAllocArray(a0)
		move.w	#DMAF_AUD3|DMAF_SETCLR,vcbDMAOn(a0)
		move.w	#DMAF_AUD3,vcbDMAOff(a0)
		move.w	#INTF_AUD3|INTF_SETCLR,vcbINTOn(a0)
		move.w	#INTF_AUD3,vcbINTOff(a0)
		move.l	#AUDIO3,vcbPaula(a0)
		move.l	#SoundBufV4,vcbBuffer(a0)

; Audio-Support eingeschaltet?
		tst.w	AudioOn
		beq	5$

; ReplyPort einrichten
		move.l	_ExecBase,a6
		JSRLIB	CreateMsgPort
		move.l	d0,ReplyPort
		beq	5$

; Requests für alle 4 Soundkanäle holen und öffnen (auch bei AHI, wegen SquareWave)
		moveq	#0,d7
		lea	SoundVCBTab,a5
2$		move.l	(a5)+,a4		;Zeiger auf VCB
		move.l	ReplyPort,a0
		moveq	#ioa_SIZEOF,d0
		JSRLIB	CreateIORequest
		move.l	d0,vcbAudioIO(a4)
		beq	3$
		lea	AudioName,a0
		move.l	d7,d0			;Unit
		move.l	vcbAudioIO(a4),a1
		moveq	#0,d1			;Flags
		JSRLIB	OpenDevice
		tst.l	d0
		beq	3$
		move.l	vcbAudioIO(a4),a0	;Nicht gelungen, Request löschen
		JSRLIB	DeleteIORequest
		clr.l	vcbAudioIO(a4)
3$		addq.l	#1,d7
		cmp.b	#ADHARD_CHANNELS,d7
		bne	2$

; Soll AHI benutzt werden?
		tst.w	UseAHI
		beq	1$
		tst.l	_AHIBase
		bne	OpenAudioAHI

; Nein, Kanal 0 und 1 belegen
1$		lea	SoundVCB1,a0
		bsr	Alloc1Voice1
		tst.l	d0
		bne	5$

		lea	SoundVCB2,a0
		bsr	Alloc1Voice1
		tst.l	d0
		bne	6$

		move.w	#-1,GotChannel01

; Kanal 0 und 1 vorbereiten, Interrupt installieren und DMA starten
		move.l	ClkConst,d0		;Periode für 22kHz berechnen
		divu	#SAMPLE_FREQ,d0

		lea	AUDIO0,a0
		move.w	#0,ac_vol(a0)
		move.w	d0,ac_per(a0)
		move.w	#370,ac_len(a0)
		move.l	#SoundEmpty,ac_ptr(a0)

		lea	AUDIO1,a0
		move.w	#0,ac_vol(a0)
		move.w	d0,ac_per(a0)
		move.w	#370,ac_len(a0)
		move.l	#SoundEmpty,ac_ptr(a0)

		move.w	#INTF_AUD0,_intena
		move.w	#INTF_AUD0,_intreq

		move.l	_ExecBase,a6
		lea	Channel0Int,a1
		moveq	#INTB_AUD0,d0
		JSRLIB	SetIntVector
		move.l	d0,SoundIntOld

		move.w	#INTF_AUD0|INTF_SETCLR,_intena
		move.w	#$8003,_dmacon

; Alles klar
5$		rts

6$		lea	SoundVCB1,a0
		bsr	FreeVoice
		rts

; AHI, 2 Kanäle holen
OpenAudioAHI	move.l	AudioID,AATID

		move.l	_AHIBase,a6
		lea	AHIAllocTags,a1
		jsr	_LVOAHI_AllocAudioA(a6)
		move.l	d0,AHICtrl
		beq	1$

; Sounds laden (0 - Buffer 0, 1 - Buffer 1, 2 - Leer)
		moveq	#0,d0
		moveq	#AHIST_DYNAMICSAMPLE,d1
		lea	AHISound0,a0
		move.l	AHICtrl,a2
		jsr	_LVOAHI_LoadSound(a6)

		moveq	#1,d0
		moveq	#AHIST_DYNAMICSAMPLE,d1
		lea	AHISound1,a0
		move.l	AHICtrl,a2
		jsr	_LVOAHI_LoadSound(a6)

		moveq	#2,d0
		moveq	#AHIST_SAMPLE,d1
		lea	AHISound2,a0
		move.l	AHICtrl,a2
		jsr	_LVOAHI_LoadSound(a6)

; Lautstärke auf Null
		moveq	#0,d0
		moveq	#0,d1
		move.l	#$8000,d2
		moveq	#AHISF_IMM,d3
		move.l	AHICtrl,a2
		jsr	_LVOAHI_SetVol(a6)

; Frequenz setzen
		moveq	#0,d0
		move.l	#SAMPLE_FREQ,d1
		moveq	#AHISF_IMM,d2
		move.l	AHICtrl,a2
		jsr	_LVOAHI_SetFreq(a6)

; Leeren Sound starten
		moveq	#0,d0
		moveq	#2,d1
		moveq	#0,d2
		moveq	#0,d3
		moveq	#AHISF_IMM,d4
		move.l	AHICtrl,a2
		jsr	_LVOAHI_SetSound(a6)

; Audio anschalten
		lea	AHICtrlOnTags,a1
		move.l	AHICtrl,a2
		jsr	_LVOAHI_ControlAudioA(a6)

; Alles klar
		move.w	#-1,GotChannel01
1$		rts


**
** Beenden
**

; Kanal 0 und 1 aufräumen
CloseAudio	tst.w	GotChannel01
		beq	4$

; AHI benutzt?
		tst.l	AHICtrl
		beq	5$

; Ja, Sound abschalten und AHI freigeben
		move.l	_AHIBase,a6
		lea	AHICtrlOffTags,a1
		move.l	AHICtrl,a2
		jsr	_LVOAHI_ControlAudioA(a6)

		move.l	AHICtrl,a2
		jsr	_LVOAHI_FreeAudio(a6)

		clr.w	GotChannel01
		bra	4$

; Kein AHI
5$		move.w	#$0003,_dmacon
		move.w	#INTF_AUD0,_intena
		move.w	#INTF_AUD0,_intreq

		move.l	_ExecBase,a6
		move.l	SoundIntOld,a1
		moveq	#INTB_AUD0,d0
		JSRLIB	SetIntVector

		lea	SoundVCB1,a0
		bsr	FreeVoice

		lea	SoundVCB2,a0
		bsr	FreeVoice

		clr.w	GotChannel01

; ReplyPort und Requests entfernen
4$		move.l	_ExecBase,a6
		moveq	#ADHARD_CHANNELS-1,d7
		lea	SoundVCBTab,a5
2$		move.l	(a5)+,a4		;a4: Zeiger auf VCB
		move.l	vcbAudioIO(a4),d0	;AudioIO vorhanden?
		beq	3$
		move.l	d0,a1
		JSRLIB	CloseDevice		;Gerät schließen
		move.l	vcbAudioIO(a4),a0
		JSRLIB	DeleteIORequest		;IORequest entfernen
		clr.l	vcbAudioIO(a4)
3$		dbra	d7,2$

		move.l	ReplyPort,d0
		beq	1$
		move.l	d0,a0
		JSRLIB	DeleteMsgPort
1$		rts


**
** SoundInt
**

*
* Normal
*

; a1: Zeiger auf ASC-Register
SoundInt	move.w	#INTF_AUD0,_intreq
		movem.l	d2-d3/a2-a3,-(sp)
		move.l	a1,a3

; ASC-Version setzen
		move.b	#$0f,$800(a3)

; ASC im single voice mode?
		cmp.b	#1,$801(a3)
		beq	SingleVoice

; Nein, dann abschalten
		clr.b	$804(a3)
		clr.l	FIFOPtr

		lea	AUDIO0,a0
		lea	SoundEmpty,a1
		move.w	#370,ac_len(a0)
		move.l	a1,ac_ptr(a0)
		lea	AUDIO1,a0
		move.w	#370,ac_len(a0)
		move.l	a1,ac_ptr(a0)

		movem.l	(sp)+,d2-d3/a2-a3
		rts

; Single voice mode über FIFO
; Puffer tauschen
SingleVoice	eor.w	#$400,SoundBufPtr

; Genug Daten vorhanden?
		cmp.l	#3,FIFOPtr
		bhi	1$

; Nein, abschalten
		lea	AUDIO0,a0
		lea	SoundEmpty,a1
		move.w	#370,ac_len(a0)
		move.l	a1,ac_ptr(a0)
		lea	AUDIO1,a0
		move.w	#370,ac_len(a0)
		move.l	a1,ac_ptr(a0)
		bra	SingleDone

; Sound-Daten beider Kanäle konvertieren
1$		move.l	#$80808080,d2
		move.l	FIFOPtr,d3
		lsr.l	#2,d3
		subq.w	#1,d3			;d3: Zähler für dbra

		move.l	a3,a0			;Linker Kanal
		lea	SoundBufV1,a1
		add.w	SoundBufPtr,a1
		move.w	d3,d1
2$		move.l	(a0)+,d0
		eor.l	d2,d0
		move.l	d0,(a1)+
		dbra	d1,2$

		move.l	a3,a0			;Rechter Kanal
		cmp.b	#2,$802(a3)		;Stereo mode?
		bne	3$
		lea	$400(a0),a0		;Ja, Daten aus zweitem Puffer lesen
3$		lea	SoundBufV2,a1
		add.w	SoundBufPtr,a1
		move.w	d3,d1
4$		move.l	(a0)+,d0
		eor.l	d2,d0
		move.l	d0,(a1)+
		dbra	d1,4$

; Paula-Register setzen
		lea	AUDIO0,a0
		lea	AUDIO1,a1
		moveq	#0,d0			;Lautstärke
		move.b	$806(a3),d0
		lsr.b	#2,d0
		move.w	d0,ac_vol(a0)
		move.w	d0,ac_vol(a1)
		move.l	FIFOPtr,d0		;Länge
		lsr.l	#1,d0
		move.w	d0,ac_len(a0)
		move.w	d0,ac_len(a1)
		move.w	SoundBufPtr,d0		;und Zeiger setzen
		lea	(SoundBufV1,d0.w),a2
		move.l	a2,ac_ptr(a0)
		lea	(SoundBufV2,d0.w),a2
		move.l	a2,ac_ptr(a1)

; FIFO-Zeiger löschen und dies im ASC simulieren
SingleDone	clr.l	FIFOPtr
		moveq	#5,d0
		cmp.b	#2,$802(a3)		;Stereo mode?
		beq	3$
		moveq	#1,d0
3$		cmp.b	#$0a,$804(a3)
		beq	1$
		cmp.b	$804(a3),d0
		beq	1$
		moveq	#0,d0
1$		move.b	d0,$804(a3)

; Mac-Audio-Interrupt aufrufen
		tst.w	MacRunning
		beq	2$
		tst.l	$d80			;Mac-Audio-Interrupt-Vektor
		ble	2$
		bsr	MacAudioInt
2$		movem.l	(sp)+,d2-d3/a2-a3
		rts


*
* AHI Audio-Interrupt
*

; a2-AHICtrl, a1-AHISoundMessage
AHISoundFunc	movem.l	d2-d4/a2-a3/a6,-(sp)
		move.l	_AHIBase,a6

; ASC-Version setzen
		lea	ASCRegs,a3
		move.b	#$0f,$800(a3)

; ASC im single voice mode?
		cmp.b	#1,$801(a3)
		beq	AHISingleVoice

; Nein, dann abschalten
		clr.b	$804(a3)
		clr.l	FIFOPtr

		moveq	#0,d0
		moveq	#2,d1
		moveq	#0,d2
		moveq	#0,d3
		moveq	#0,d4
		move.l	AHICtrl,a2
		jsr	_LVOAHI_SetSound(a6)

		movem.l	(sp)+,d2-d4/a2-a3/a6
		moveq	#0,d0
		rts

; Single voice mode über FIFO
; Puffer tauschen
AHISingleVoice	eor.w	#$800,SoundBufPtr
		eor.w	#1,AHIBufNum

; Genug Daten vorhanden?
		cmp.l	#3,FIFOPtr
		bhi	1$

; Nein, abschalten
		moveq	#0,d0
		moveq	#2,d1
		moveq	#0,d2
		moveq	#0,d3
		moveq	#0,d4
		move.l	AHICtrl,a2
		jsr	_LVOAHI_SetSound(a6)
		bra	AHISingleDone

; Sound-Daten beider Kanäle konvertieren
1$		move.b	#$80,d2
		move.l	FIFOPtr,d3
		subq.w	#1,d3			;d3: Zähler für dbra

		cmp.b	#2,$802(a3)		;Stereo mode?
		beq	3$

		move.l	a3,a0			;Nein
		lea	AHISoundBuf0,a1
		add.w	SoundBufPtr,a1
2$		move.b	(a0)+,d0
		eor.b	d2,d0
		move.b	d0,(a1)+
		move.b	d0,(a1)+
		dbra	d3,2$
		bra	5$

3$		move.l	a3,a0			;Ja
		move.l	a3,a2
		lea	$400(a2),a2
		lea	AHISoundBuf0,a1
		add.w	SoundBufPtr,a1
4$		move.b	(a0)+,d0
		eor.b	d2,d0
		move.b	d0,(a1)+
		move.b	(a2)+,d0
		eor.b	d2,d0
		move.b	d0,(a1)+
		dbra	d3,4$

; Lautstärke setzen
5$		moveq	#0,d0
		moveq	#0,d1
		move.b	$806(a3),d1
		lsl.w	#8,d1
		move.l	#$8000,d2
		moveq	#0,d3
		move.l	AHICtrl,a2
		jsr	_LVOAHI_SetVol(a6)

; Neue Puffer starten
		moveq	#0,d0
		moveq	#0,d1
		add.w	AHIBufNum,d1
		moveq	#0,d2
		move.l	FIFOPtr,d3
		moveq	#0,d4
		move.l	AHICtrl,a2
		jsr	_LVOAHI_SetSound(a6)

; FIFO-Zeiger löschen und dies im ASC simulieren
AHISingleDone	clr.l	FIFOPtr
		moveq	#5,d0
		cmp.b	#2,$802(a3)		;Stereo mode?
		beq	3$
		moveq	#1,d0
3$		cmp.b	#$0a,$804(a3)
		beq	1$
		cmp.b	$804(a3),d0
		beq	1$
		moveq	#0,d0
1$		move.b	d0,$804(a3)

; Mac-Audio-Interrupt aufrufen
		tst.w	MacRunning
		beq	2$
		tst.l	$d80			;Mac-Audio-Interrupt-Vektor
		ble	2$
		bsr	MacAudioInt
2$		movem.l	(sp)+,d2-d4/a2-a3/a6
		moveq	#0,d0
		rts


*
* Gefaketer Audio-Interrupt, falls audio.device nicht geöffnet werden konnte
*

FakeAudioInt	movem.l	d2-d3/a2-a3,-(sp)
		lea	ASCRegs,a3
		move.b	#$0f,$800(a3)
		cmp.b	#1,$801(a3)
		beq	FakeSingleVoice
		clr.b	$804(a3)
		movem.l	(sp)+,d2-d3/a2-a3
		rts

FakeSingleVoice	clr.l	FIFOPtr
		moveq	#5,d0
		cmp.b	#2,$802(a3)
		beq	3$
		moveq	#1,d0
3$		cmp.b	#$0a,$804(a3)
		beq	1$
		cmp.b	$804(a3),d0
		beq	1$
		moveq	#0,d0
1$		move.b	d0,$804(a3)

		tst.w	MacRunning
		beq	2$
		tst.l	$d80			;Mac-Audio-Interrupt-Vektor
		ble	2$
		bsr	MacAudioInt
2$		movem.l	(sp)+,d2-d3/a2-a3
		rts


*
* Mac-Audio-Interrupt aufrufen
*

MacAudioInt	movem.l	a5-a6,-(sp)
		move.l	_ExecBase,a6
		lea	MacAudioIntProc,a5
		JSRLIB	Supervisor
		movem.l	(sp)+,a5-a6
		rts

MacAudioIntProc	move.l	$2b6,a0			;ExpandMem
		move.l	$110(a0),a0
		move.l	$1e(a0),d1
		ble	1$
		moveq	#0,d0
		move.b	ASCRegs+$804,d0
		btst	#0,d0
		beq	1$
		bset	#31,d0
		move.l	d1,a1
		move.l	d0,a0
		addq.w	#1,NoSuperSwitch
		jsr	(a1)
		subq.w	#1,NoSuperSwitch
		move.l	$2b6,a0
		move.l	$110(a0),a0
1$		move.l	$22(a0),d1
		ble	2$
		moveq	#0,d0
		move.b	ASCRegs+$804,d0
		btst	#2,d0
		beq	2$
		bset	#31,d0
		move.l	d1,a1
		move.l	d0,a0
		addq.w	#1,NoSuperSwitch
		jsr	(a1)
		subq.w	#1,NoSuperSwitch
2$		rte


**
** Sift-Patches
**

; Mono->Stereo
SiftPatch1	moveq	#0,d2
		cmp.l	#$ffff,d1
		bcs	1$
		move.l	#$ffff,d1
1$		move.l	d1,d3

		lea	ASCRegs,a0
		lea	$400(a0),a2
		lea	$804(a0),a3
		moveq	#8,d4
		bra	2$

3$		move.l	FIFOPtr,d0
		cmp.w	#$400,d0
		bhs	5$
		move.b	(a1),(a0,d0.l)
		move.b	(a1)+,(a2,d0.l)
		addq.l	#1,d0
		move.l	d0,FIFOPtr
		clr.b	(a3)
		bra	2$
5$		move.b	#$0a,(a3)
2$		move.b	(a3),d0
		and.b	d4,d0
		dbne	d3,3$
		beq	4$
		moveq	#1,d2
		sub.l	d3,d1
4$		rts

; Stereo->Stereo
SiftPatch2	moveq	#0,d2
		cmp.l	#$ffff,d1
		bcs	1$
		move.l	#$ffff,d1
1$		move.l	d1,d3

		lea	ASCRegs,a0
		lea	$400(a0),a2
		lea	$804(a0),a3
		moveq	#8,d4
		bra	2$

3$		move.l	FIFOPtr,d0
		cmp.w	#$400,d0
		bhs	5$
		move.b	(a1)+,(a0,d0.l)
		move.b	(a1)+,(a2,d0.l)
		addq.l	#1,d0
		move.l	d0,FIFOPtr
		clr.b	(a3)
		bra	2$
5$		move.b	#$0a,(a3)
2$		move.b	(a3),d0
		and.b	d4,d0
		dbne	d3,3$
		beq	4$
		moveq	#1,d2
		sub.l	d3,d1
4$		rts

; Mono->Mono
SiftPatch3	moveq	#0,d2
		cmp.l	#$ffff,d1
		bcs	1$
		move.l	#$ffff,d1
1$		move.l	d1,d3

		move	sr,-(sp)
		move	#$2700,sr
		btst	#3,ASCRegs+$804
		bne	5$
		move.l	FIFOPtr,d4
		bra	2$

3$		move.b	(a1)+,(a2,d4.l)
		addq.l	#1,d4
2$		cmp.w	#$400,d4
		dbhs	d3,3$
		blo	4$

		move.l	d4,FIFOPtr
		move.b	#$0a,ASCRegs+$804
5$		moveq	#1,d2
		sub.l	d3,d1
		move	(sp)+,sr
		rts

4$		move.l	d4,FIFOPtr
		clr.b	ASCRegs+$804
		move	(sp)+,sr
		rts

; Stereo->Mono
SiftPatch4	moveq	#0,d2
		cmp.l	#$ffff,d1
		bcs	1$
		move.l	#$ffff,d1
1$		move.l	d1,d3

		move	sr,-(sp)
		move	#$2700,sr
		btst	#3,ASCRegs+$804
		bne	5$
		move.l	FIFOPtr,d4
		bra	2$

3$		move.b	(a1)+,d0
		add.b	(a1)+,d0
		roxr.b	#1,d0
		move.b	d0,(a2,d4.l)
		addq.l	#1,d4
2$		cmp.w	#$400,d4
		dbhs	d3,3$
		blo	4$

		move.l	d4,FIFOPtr
		move.b	#$0a,ASCRegs+$804
5$		moveq	#1,d2
		sub.l	d3,d1
		move	(sp)+,sr
		rts

4$		move.l	d4,FIFOPtr
		clr.b	ASCRegs+$804
		move	(sp)+,sr
		rts


**
** Snth-Patches
**

; Stereo->Stereo
Snth5Patch1	lsr.l	#1,d4
Snth5Patch1a	move.l	FIFOPtr,d7
		bra	2$

3$		move.b	(a3)+,(a1,d7.l)
		move.b	(a3)+,$400(a1,d7.l)
		addq.l	#1,d7
2$		cmp.w	#740,d7
		dbhs	d4,3$
		blo	4$

		move.l	d7,FIFOPtr
		move.b	#$0a,$804(a1)
		moveq	#0,d0
		rts

4$		move.l	d7,FIFOPtr
		clr.b	$804(a1)
		moveq	#1,d0
		rts

; 8 Bit Stereo, Daten vorgegeben
Snth5Patch2	move.l	FIFOPtr,d0
		cmp.w	#740,d0
		bhs	1$
		move.b	d7,$400(a1,d0.l)
		swap	d7
		move.b	d7,(a1,d0.l)
		addq.l	#1,d0
		move.l	d0,FIFOPtr
		clr.b	$804(a1)
		rts
1$		move.b	#$0a,$804(a1)
		rts

; 8 Bit Stereo, über Index
Snth5Patch3	move.l	FIFOPtr,d0
		cmp.w	#740,d0
		bhs	1$
		move.b	(a0,d7.w),(a1,d0.l)
		swap	d7
		move.b	(a0,d7.w),$400(a1,d0.l)
		addq.l	#1,d0
		move.l	d0,FIFOPtr
		clr.b	$804(a1)
		rts
1$		move.b	#$0a,$804(a1)
		rts

; 8 Bit Stereo, umgekehrte Bytefolge
Snth5Patch4	move.l	FIFOPtr,d0
		cmp.w	#740,d0
		bhs	1$
		move.b	d7,(a1,d0.l)
		swap	d7
		move.b	d7,$400(a1,d0.l)
		addq.l	#1,d0
		move.l	d0,FIFOPtr
		clr.b	$804(a1)
		rts
1$		move.b	#$0a,$804(a1)
		rts

; 8 Bit Stereo, über Index
Snth5Patch5	move.l	FIFOPtr,d0
		cmp.w	#740,d0
		bhs	1$
		move.b	(a0,d3.w),(a2,d0.l)
		swap	d3
		move.b	(a0,d3.w),$400(a2,d0.l)
		addq.l	#1,d0
		move.l	d0,FIFOPtr
		clr.b	$804(a2)
		rts
1$		move.b	#$0a,$804(a2)
		rts


**
** .Sound-Treiber Patch
**

SndDrvrPatch	move.l	d1,-(sp)
		move.l	FIFOPtr,d1
		cmp.w	#740,d1
		bhs	1$
		move.b	(a1),(a2,d1.l)
		addq.l	#1,d1
		move.l	d1,FIFOPtr
		clr.b	$804(a2)
		move.l	(sp)+,d1
		add.l	d1,d3
		swap	d3
		rts
1$		move.b	#$0a,$804(a2)
		move.l	(sp)+,d1
		add.l	d1,d3
		swap	d3
		rts


**
** SquareWave-Synthesizer
**

SquareWaveProc	link	a6,#0
		movem.l	d3/a3-a4,-(sp)
		move.l	12(a6),a3	;a3: sndCommand
		move.l	8(a6),a4	;a4: Daten
		move.w	(a3),d0		;d0: Befehl
		clr.w	(a3)		;Befehl löschen
		cmp.w	#24,d0		;availableCmd?
		beq	SWAvailable
		cmp.w	#25,d0		;versionCmd?
		beq	SWVersion
		tst.l	8(a6)		;Zeiger auf Daten gültig?
		beq	SynthRts	;Nein, Rücksprung
		lea	8(a4),a4
		cmp.w	#1,d0		;initCmd?
		beq	SWInit
		tst.l	(a4)		;Kanal initialisiert?
		beq	SynthRts	;Nein, Rücksprung
		cmp.w	#2,d0		;freeCmd?
		beq	SWFree
		move.l	(a4),a4		;Zeiger auf VCB holen
		cmp.w	#3,d0		;quietCmd?
		beq	SWQuiet
		cmp.w	#15,d0		;emptyCmd?
		beq	SWQuiet
		cmp.w	#40,d0		;freqDurationCmd?
		beq	SWFreqDuration
		cmp.w	#41,d0		;restCmd?
		beq	SWRest
		cmp.w	#42,d0		;freqCmd?
		beq	SWFreq
		cmp.w	#43,d0		;ampCmd?
		beq	SWAmp
		cmp.w	#44,d0		;timbreCmd?
		beq	SWTimbre
		move.w	d0,(a3)		;Befehl wiederherstellen

SynthRts	clr.b	20(a6)		;Rückgabe noErr
		movem.l	(sp)+,d3/a3-a4
		unlk	a6
		rtd	#12

; 24 - availableCmd
SWAvailable	clr.w	2(a3)
		tst.l	4(a3)		;param1=1, wenn Init options=0
		bne	SynthRts
		move.w	#1,2(a3)
		bra	SynthRts

; 25 - versionCmd
SWVersion	move.l	#$00010003,4(a3) ;Version 1.3
		bra	SynthRts

; 1 - initCmd
SWInit		move.l	#-1,4(a3)	;Vorgabe: Mißlungen
		clr.l	(a4)		;Kanal nicht initialisiert

		moveq	#$f,d1		;Alle Stimmen probieren
		bsr	AllocVoice	;Stimme belegen
		tst.w	d0
		bmi	SynthRts	;Keine Stimme gefunden
		move.l	a0,(a4)		;Zeiger auf VCB eintragen

		move.l	(a4),a4
		clr.b	vcbState(a4)	;Sound nicht aktiv

 		move.b	#$50,vcbTimbre(a4)
		move.w	#16,vcbWaveLength(a4)

		move.l	vcbPaula(a4),a0
		move.b	$260,d0		;SdVolume
		bsr	SetVolume	;Lautstärke setzen

		clr.l	4(a3)		;Alles OK
		move.b	#1,$27e		;SoundActive
		bra	SynthRts

; 2 - freeCmd
SWFree		move.l	(a4),a0		;VCB holen
		clr.b	vcbState(a0)	;Sound nicht aktiv
		clr.l	(a4)		;Kanal nicht initialisiert
		bsr	FreeVoice	;Stimme als frei markieren
		tst.b	ChannelMask	;Alle Stimmen frei?
		bne	SynthRts
		clr.b	$27e		;Ja, SoundActive löschen
		bra	SynthRts

; 3 - quietCmd / 15 - emptyCmd
SWQuiet		move.w	vcbDMAOff(a4),_dmacon
		clr.b	vcbState(a4)	;Sound nicht aktiv
		move.w	#3,(a3)		;Befehl wiederherstellen
		bra	SynthRts

; 40 - freqDurationCmd
SWFreqDuration	bsr	SWDoSound	;Sound starten
		move.w	#10,(a3)	;Befehl auf waitCmd ändern
		clr.l	4(a3)		;Frequenz löschen
		bra	SynthRts

; 41 - restCmd
SWRest		move.w	vcbDMAOff(a4),_dmacon
		clr.b	vcbState(a4)	;Sound nicht aktiv
		move.w	#10,(a3)	;Befehl auf waitCmd ändern
		bra	SynthRts

; 42 - freqCmd
SWFreq		bsr	SWDoSound	;Sound starten
		bra	SynthRts

; 43 - ampCmd
SWAmp		move.l	vcbPaula(a4),a0
		move.w	2(a3),d0	;Amplitude
		and.l	#$ff,d0
		move.b	$260,d1		;SdVolume
		and.w	#7,d1
		mulu.w	d1,d0
		divu.w	#28,d0
		move.w	d0,ac_vol(a0)
		bra	SynthRts

; 44 - timbreCmd
SWTimbre	move.b	3(a3),vcbTimbre(a4)
		bsr	SWCalcWave
		bra	SynthRts

; Wellenform berechnen, Periode ermitteln und Sound starten
SWDoSound	move.w	vcbDMAOff(a4),_dmacon

		move.w	6(a3),d0		;Note holen
		and.w	#$007f,d0
		lea	SoundPerTable,a0
		move.w	0(a0,d0.w*2),d2		;Periode lesen
		lea	SoundLenTable,a0
		move.w	0(a0,d0.w*2),d3		;Länge lesen
		lsr.w	#1,d3
		move.w	d3,vcbWaveLength(a4)	;Länge/2 sichern

		bsr	SWCalcWave

		move.l	vcbPaula(a4),a0		;Paula-Register setzen
		move.l	vcbBuffer(a4),ac_ptr(a0)
		move.w	d3,ac_len(a0)
		move.w	d2,ac_per(a0)

		bsr	Wait1Line

		move.w	vcbDMAOn(a4),_dmacon
		move.b	#1,vcbState(a4)		;Sound aktiv
		rts

; Wellenform berechnen
SWCalcWave	movem.l	d2-d4,-(sp)

		move.l	vcbBuffer(a4),a0 ;Zeiger auf Sound-Puffer
		lea	SinTab,a2	;Zeiger auf Sinus-Tabelle

		move.l	#1024,d3	;Sinus-Skip berechnen
		divu.w	vcbWaveLength(a4),d3

		moveq	#0,d2		;Timbre holen
		moveq	#0,d4
		move.b	vcbTimbre(a4),d2
		move.b	d2,d4
		lsr.b	#1,d4
		not.b	d2

		move.w	vcbWaveLength(a4),d1 ;Schleifenzähler
		subq.w	#1,d1
1$		move.b	(a2),d0		;Sinus-Wert holen
		ext.w	d0
		mulu.w	d2,d0
		asr.l	#8,d0
		add.b	d4,d0
		move.b	d0,(a0)+
		add.w	d3,a2
		dbra	d1,1$

		neg.b	d4
		move.w	vcbWaveLength(a4),d1
		subq.w	#1,d1
2$		move.b	(a2),d0
		ext.w	d0
		mulu.w	d2,d0
		asr.l	#8,d0
		add.b	d4,d0
		move.b	d0,(a0)+
		add.w	d3,a2
		dbra	d1,2$
		movem.l	(sp)+,d2-d4
		rts


**
** Sound-Input-Treiber
**

*
* Definitionen
*

rate4kHz	= $0fa00000	;Minimum
rate48kHz	= $bb800000	;Maximum

rate11kHz	= $2b110000
rate15kHz	= $3d090000
rate22kHz	= $56220000

; Lokale Daten
 STRUCTURE SndInpData,0
	LONG	siRate		;Sample-Rate (Fixed)
	WORD	siComp		;Kompression (0-NONE, 3-MAC3, 4-MAC6)
	WORD	siMeterOn	;#0: Level Meter angeschaltet
	WORD	siTwos		;#0: Two's complement
	WORD	siVol		;Durchschleif-Lautstärke (0..7)
	APTR	siUserIRQ	;Benutzer-Interrupt
	APTR	siSPB		;Sound-Parameter-Block
	APTR	siVCB		;Zeiger auf VCB (Zum Aufnehmen wird eine Stimme benötigt)
	APTR	siOldInt	;Alter Audio-Interrupt
 LABEL	sid_SIZEOF


*
* Installation
*

; Rücksprung, wenn keine misc.resource vorhanden (DraCo)
InstallSndInput	tst.l	_MiscBase
		beq	1$

; Treiber installieren
		lea	SndInHeader,a0
		moveq	#SndInRefNum,d0
		dc.w	$a43d		;DrvrInstallRsrvMem

; Treiber locken
		move.l	$11c,a0		;UTableBase
		move.l	-(SndInRefNum+1)*4(a0),a0
		move.l	(a0),a2
		dc.w	$a029		;HLock

; Daten kopieren
		lea	SndInHeader,a0
		move.l	a0,(a2)
		move.w	(a0),dCtlFlags(a2)

; Treiber öffnen
		sub.w	#$32,sp
		move.l	sp,a0
		clr.b	ioPermssn(a0)
		lea	SndInName,a1
		move.l	a1,ioNamePtr(a0)
		dc.w	$a000		;Open
		add.w	#$32,sp

; Treiber registrieren
		subq.w	#4,sp
		move.w	#SndInRefNum,-(sp)
		pea	SndDevName
		move.l	#$030c0014,d0	;SPBSignInDevice
		dc.w	$a800
		addq.w	#4,sp
1$		rts


*
* Treiber-Header
*

SndInHeader	dc.w	$4d00		;Flags
		dc.w	0,0,0		;Delay, EMask, Menu
		dc.w	SIOpen-SndInHeader
		dc.w	SIPrime-SndInHeader
		dc.w	SIControl-SndInHeader
		dc.w	SIStatus-SndInHeader
		dc.w	SIClose-SndInHeader

SndInName	dc.b	16,".AmigaSoundInput"
		EVEN
SndDevName	dc.b	12,"Parallelport"
		CNOP	0,4


*
* Open()-Routine
*

SIOpen		movem.l	a0-a2,-(sp)
		move.l	a1,SndInDCE	;DCE sichern

; Datenbereich holen
		move.l	#sid_SIZEOF,d0
		dc.w	$a71e		;NewPtrSysClear
		move.l	a0,dCtlStorage(a1)
		move.l	a0,a2

; und initialisieren
		bsr	SIInitData

		movem.l	(sp)+,a0-a2
		moveq	#0,d0
		rts

; Datenbereich initialisieren
SIInitData	move.l	#rate22kHz,siRate(a2)
		clr.w	siComp(a2)
		clr.w	siMeterOn(a2)
		clr.w	siTwos(a2)
		move.w	#7,siVol(a2)
		clr.l	siUserIRQ(a2)
		rts


*
* Close()-Routine
*

SIClose		movem.l	a0-a1,-(sp)

; Datenbereich freigeben
		move.l	dCtlStorage(a1),a0
		dc.w	$a01f		;DisposePtr

		movem.l	(sp)+,a0-a1
		moveq	#0,d0
		rts


*
* Prime()-Routine
*
* ioBuffer  : Zielpuffer oder NIL
* ioReqCount: Länge in Bytes
* ioMisc    : Sound-Parameter-Block
*

SIPrime		movem.l	a0-a3,-(sp)
		move.l	dCtlStorage(a1),a2

		move.l	siVCB(a2),d0		;Stimme initialisiert?
		beq	SIReturnOK		;Nein, Rückkehr
		move.l	d0,a3			;Zeiger auf VCB holen

		tst.b	vcbState(a3)		;Aufnahme aktiv?
		bne	SIReturnOK		;Ja, Rückkehr

		move.l	a0,vcbIOParam(a3)	;Zeiger auf IOParam eintragen
		move.l	ioBuffer(a0),vcbPosition(a3) ;Sample-Zeiger (kann NIL sein!)
		move.l	ioReqCount(a0),vcbLength(a3) ;Restlänge
		clr.l	ioActCount(a0)		;Tatsächliche Länge löschen
		move.l	ioMisc(a0),siSPB(a2)	;Sound-Parameter-Block setzen

		move.l	vcbPaula(a3),a0
		move.l	siRate(a2),d0		;Rate holen
		clr.w	d0
		swap	d0			;Ganzzahligen Anteil holen
		tst.w	d0
		beq	1$
		move.l	ClkConst,d1
		divu	d0,d1
		asr.w	#1,d1			;DIV 2
		move.w	d1,ac_per(a0)		;Periode speichern

1$		move.w	siVol(a2),d0		;Lautstärke holen
		bsr	SetVolume		;und setzen

		move.b	#1,vcbState(a3)		;Aufnahme aktiv
		move.w	vcbINTOff(a3),_intreq	;Interrupt zurücksetzen,
		move.w	vcbINTOn(a3),_intena	;erlauben
		move.w	#0,ac_dat(a0)		;und anstoßen

		moveq	#1,d0			;Request noch nicht beendet
		bra	SIReturn


*
* Control()-Routine
*

SIControl	movem.l	a0-a3,-(sp)
		move.l	dCtlStorage(a1),a2

		cmp.w	#1,csCode(a0)
		beq	SIKillIO
		cmp.w	#2,csCode(a0)
		bne	UnknownInfoType

		move.l	csParam(a0),d0		;infoSelector
		lea	csParam+4(a0),a0

		DPRINTF	"SIControl %08lx",d0

		cmp.l	#'comp',d0	;Core selectors
		beq	SICComp
		cmp.l	#'cont',d0
		beq	SICCont
		cmp.l	#'lmet',d0
		beq	SICLmet
		cmp.l	#'chan',d0
		beq	SICChan
		cmp.l	#'qual',d0
		beq	SICQual
		cmp.l	#'srat',d0
		beq	SICSrat
		cmp.l	#'ssiz',d0
		beq	SICSsiz
		cmp.l	#'twos',d0
		beq	SICTwos

		cmp.l	#'plth',d0	;Optional selectors
		beq	SICPlth

		cmp.l	#'init',d0	;Special selectors
		beq	SICInit
		cmp.l	#'clos',d0
		beq	SICClos
		cmp.l	#'paus',d0
		beq	SICPaus
		cmp.l	#'user',d0
		beq	SICUser
		bra	UnknownInfoType

; Control(1) - KillIO
SIKillIO	tst.l	siVCB(a2)		;Stimme initialisiert?
		beq	1$			;Nein, Rückkehr
		move.l	siVCB(a2),a3		;VCB holen
		tst.b	vcbState(a3)		;Interrupt aktiv?
		beq	1$			;Nein, Rückkehr
		move.b	#2,vcbState(a3)		;Aufnahme abbrechen

1$		moveq	#0,d0
		movem.l	(sp)+,a0-a3
		rts

; Initialisierung vor der Aufnahme
SICInit		clr.l	siVCB(a2)
		bsr	SIInitData

		move.l	a6,-(sp)
		move.l	_MiscBase,a6
		moveq	#MR_PARALLELPORT,d0
		lea	BaseName,a1
		EJSRLIB	AllocMiscResource
		move.l	(sp)+,a6
		tst.l	d0
		bne	DeviceBusy

		move.b	#$00,_ciaaddrb	;Port auf Eingabe

		moveq	#%1111,d1	;Irgendeine
		bsr	AllocVoice	;Stimme belegen
		tst.w	d0
		bpl	1$

		move.l	a6,-(sp)	;Nicht gelungen, Port wieder freigeben
		move.l	_MiscBase,a6
		moveq	#MR_PARALLELPORT,d0
		EJSRLIB	FreeMiscResource
		move.l	(sp)+,a6
		bra	SINoMem

1$		move.l	a0,siVCB(a2)	;VCB sichern
		move.l	a0,RecordVCB	;Für Interrupt (is_data)

		move.l	a0,a3
		move.l	a2,vcbSIData(a3) ;Zeiger auf Datenbereich eintragen

		move.w	vcbINTOff(a3),_intena
		move.w	vcbDMAOff(a3),_dmacon
		clr.b	vcbState(a3)	;Aufnahme nicht aktiv
		moveq	#0,d0
		move.b	vcbVoiceNumber(a3),d0
		addq.w	#INTB_AUD0,d0	;In Int-Nummer konvertieren
		lea	RecordInterrupt,a1 ;Zeiger auf Handler
		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		EJSRLIB	SetIntVector	;Interrupt einrichten
		move.l	d0,siOldInt(a2)
		move.l	(sp)+,a6

		bra	SIReturnOK

; Beenden der Aufnahme
SICClos		tst.l	siVCB(a2)
		beq	SIReturnOK

		move.l	siVCB(a2),a3

		move.w	vcbINTOff(a3),_intena
		moveq	#0,d0
		move.b	vcbVoiceNumber(a3),d0
		addq.w	#INTB_AUD0,d0	;In Int-Nummer konvertieren
		move.l	siOldInt(a2),a1
		clr.l	siOldInt(a2)	;Alten Handler löschen
		move.l	a6,-(sp)
		move.l	_ExecBase,a6
		EJSRLIB	SetIntVector
		move.l	(sp)+,a6

		move.l	a3,a0		;Stimme freigeben
		bsr	FreeVoice
		clr.l	siVCB(a2)	;VCB löschen

		move.l	a6,-(sp)	;Port wieder freigeben
		move.l	_MiscBase,a6
		moveq	#MR_PARALLELPORT,d0
		EJSRLIB	FreeMiscResource
		move.l	(sp)+,a6

		bsr	SIInitData
		bra	SIReturnOK

; Standard-Parameter setzen
SICQual		clr.w	siComp(a2)	;Compression NONE
		move.l	(a0),d0
		cmp.l	#'good',d0
		bne	1$
		move.l	#rate11kHz,siRate(a2)
		bra	SIReturnOK
1$		cmp.l	#'betr',d0
		bne	2$
		move.l	#rate15kHz,siRate(a2)
		bra	SIReturnOK
2$		cmp.l	#'best',d0
		bne	UnknownQuality
		move.l	#rate22kHz,siRate(a2)
		bra	SIReturnOK

; Level Meter an-/ausschalten
SICLmet		move.w	(a0),siMeterOn(a2)
		bra	SIReturnOK

; Two's complement an-/ausschalten
SICTwos		move.w	(a0),siTwos(a2)
		bra	SIReturnOK

; Kompression auswählen
SICComp		move.l	(a0),d0
		cmp.l	#'NONE',d0
		bne	InvalidComp
		clr.w	siComp(a2)	;Compression NONE
		bra	SIReturnOK

; Benutzer-Interrupt setzen
SICUser		move.l	(a0),siUserIRQ(a2)
		bra	SIReturnOK

; Sample-Größe setzen
SICSsiz		cmp.w	#8,(a0)		;8 Bit?
		bne	InvalidSSiz	;Nein, Fehler
		bra	SIReturnOK

; Sample-Rate setzen
SICSrat		move.l	(a0),d0
		cmp.l	#rate4kHz,d0
		blo	InvalidSRat
		cmp.l	#rate48kHz,d0
		bhi	InvalidSRat
		move.l	d0,siRate(a2)
		bra	SIReturnOK

; Anzahl Kanäle auswählen
SICChan		cmp.w	#1,(a0)		;1 Kanal?
		beq	SIReturnOK
		bra	NotEnoughHW	;Nein, Fehler

; Durchschleif-Lautstärke setzen
SICPlth		move.w	(a0),d0
		and.w	#7,d0
		move.w	d0,siVol(a2)

		tst.l	siVCB(a2)	;Stimme initialisiert?
		beq	SIReturnOK	;Nein, Rückkehr
		move.l	siVCB(a2),a3	;VCB holen

		move.l	vcbPaula(a3),a0
		bsr	SetVolume	;Lautstärke setzen
		bra	SIReturnOK

; Pause an-/ausschalten
SICPaus		move.w	(a0),d0
		tst.l	siVCB(a2)	;Stimme initialisiert?
		beq	SIReturnOK	;Nein, Rückkehr
		move.l	siVCB(a2),a3	;VCB holen
		tst.b	vcbState(a3)	;Interrupt aktiv?
		beq	SIReturnOK	;Nein, Rückkehr

		tst.w	d0		;Pause anschalten?
		beq	1$
		move.b	#3,vcbState(a3)	;Ja
		bra	SIReturnOK
1$		move.b	#1,vcbState(a3)	;Nein
		bra	SIReturnOK

; Continuous recording an-/ausschalten
SICCont		bra	SIReturnOK


*
* Status()-Routine
*

SIStatus	movem.l	a0-a3,-(sp)
		move.l	dCtlStorage(a1),a2

		cmp.w	#2,csCode(a0)
		bne	UnknownInfoType

		lea	csParam(a0),a0
		move.l	(a0),d0			;infoSelector
		cmp.l	#'lmet',d0
		beq	SISLmet

		DPRINTF	"SIStatus %08lx",d0

		cmp.l	#'asyn',d0	;Core selectors
		beq	SISAsyn
		cmp.l	#'chav',d0
		beq	SISChanChav
		cmp.l	#'cmav',d0
		beq	SISCmav
		cmp.l	#'cmfa',d0
		beq	SISCmfa
		cmp.l	#'comp',d0
		beq	SISComp
		cmp.l	#'cont',d0
		beq	SISCont
		cmp.l	#'dbin',d0
		beq	SISDbin
		cmp.l	#'dcon',d0
		beq	SISDcon
		cmp.l	#'icon',d0
		beq	SISIcon
		cmp.l	#'name',d0
		beq	SISName
		cmp.l	#'chan',d0
		beq	SISChanChav
		cmp.l	#'qual',d0
		beq	SISQual
		cmp.l	#'srat',d0
		beq	SISSrat
		cmp.l	#'srav',d0
		beq	SISSrav
		cmp.l	#'ssiz',d0
		beq	SISSsiz
		cmp.l	#'ssav',d0
		beq	SISSsav
		cmp.l	#'twos',d0
		beq	SISTwos

		cmp.l	#'plth',d0	;Optional selectors
		beq	SISPlth

		cmp.l	#'paus',d0	;Special selectors
		beq	SISPaus
		bra	UnknownInfoType

; Name zurückgeben
SISName		clr.l	(a0)		;Länge: Puffer
		move.l	4(a0),a1
		lea	SndDevName,a0
		moveq	#0,d0
		move.b	(a0),d0
		addq.w	#1,d0
		dc.w	$a02e		;BlockMove
		bra	SIReturnOK

; Icon zurückgeben
SISIcon		move.l	a0,a3
		subq.l	#2,sp
		dc.w	$a994		;CurResFile
		clr.w	-(sp)
		dc.w	$a998		;UseResFile
		subq.l	#4,sp
		move.l	#'ICN#',-(sp)
		move.w	#-16522,-(sp)
		dc.w	$a9a0		;GetResource
		move.l	(sp)+,a2
		dc.w	$a998		;UseResFile
		move.l	a2,d0
		bne	1$
		move.l	a3,a0
		move.w	#-192,d0	;resNotFound
		bra	SIReturn
1$		move.l	a2,-(sp)
		dc.w	$a992		;DetachResource
		move.l	a2,a0
		dc.w	$a04a		;HNoPurge
		move.l	#4,(a3)		;Länge: 4
		move.l	a2,4(a3)	;Handle auf Icon
		bra	SIReturnOK

; Sample-Größe zurückgeben
SISSsiz		move.l	#2,(a0)		;Länge: 2
		move.w	#8,4(a0)	;Größe: 8 Bit
		bra	SIReturnOK

; Verfügbare Sample-Größen zurückgeben
SISSsav		move.l	#6,(a0)		;Länge: 6
		move.l	a0,a3
		moveq	#2,d0
		dc.w	$a122		;NewHandleSys
		bne	SIReturn
		move.l	(a0),a2
		move.w	#8,(a2)		;Größe: 8 Bit
		move.w	#1,4(a3)	;Anzahl: 1
		move.l	a0,6(a3)
		bra	SIReturnOK

; Asynchrone Aufnahme möglich?
SISAsyn		move.l	#2,(a0)		;Länge: 2
		move.w	#1,4(a0)	;Ja
		bra	SIReturnOK

; Anzahl Kanäle zurückgeben
SISChanChav	move.l	#2,(a0)		;Länge: 2
		move.w	#1,4(a0)	;1 Kanal
		bra	SIReturnOK

; Sample-Rate zurückgeben
SISSrat		move.l	#4,(a0)		;Länge: 4
		move.l	siRate(a2),4(a0)
		bra	SIReturnOK

; Qualität ermitteln
SISQual		move.l	#4,(a0)		;Länge: 4
		move.l	#'good',4(a0)	;Vorgabe
		cmp.l	#rate15kHz,siRate(a2)
		blo	SIReturnOK
		move.l	#'betr',4(a0)
		cmp.l	#rate22kHz,siRate(a2)
		blo	SIReturnOK
		move.l	#'best',4(a0)
		bra	SIReturnOK

; Level-Meter auslesen
SISLmet		move.l	#4,(a0)		;Länge: 4
		moveq	#0,d0
		move.w	siMeterOn(a2),4(a0)
		beq	1$
		tst.l	siVCB(a2)	;Stimme initialisiert?
		beq	1$
		move.l	siVCB(a2),a3	;VCB holen
		tst.b	vcbState(a3)	;Interrupt aktiv?
		beq	1$
		move.b	vcbMeterVal(a3),d0	;Level Meter holen
		sub.b	#$80,d0			;und umrechnen
		add.b	d0,d0
1$		move.w	d0,6(a0)	;Wert setzen
		bra	SIReturnOK

; Two's complement auslesen
SISTwos		move.l	#2,(a0)		;Länge: 2
		move.w	siTwos(a2),4(a0)
		bra	SIReturnOK

; Verfügbare Kompressionstypen ermitteln
SISCmav		move.l	#6,(a0)		;Länge: 6
		move.l	a0,a3
		moveq	#0,d0
		dc.w	$a122		;NewHandleSys
		bne	SIReturn
		clr.w	4(a3)		;Anzahl Kompressionstypen
		move.l	a0,6(a3)	;Handle
		bra	SIReturnOK

	;	moveq	#8,d0
	;	dc.w	$a122		;NewHandleSys
	;	bne	SIReturn
	;	move.l	(a0),a2		;Handle auflösen
	;	move.l	#'MAC3',(a2)
	;	move.l	#'MAC6',4(a2)
	;	move.w	#2,4(a3)	;Anzahl Kompressionstypen
	;	move.l	a0,6(a3)	;Handle
	;	bra	SIReturnOK

; Kompression zurückgeben
SISComp		move.l	#4,(a0)		;Länge: 4
		move.w	siComp(a2),d0
		bne	1$
		move.l	#'NONE',4(a0)
		bra	SIReturnOK
1$		cmp.w	#3,d0
		bne	2$
		move.l	#'MAC3',4(a0)
		bra	SIReturnOK
2$		cmp.w	#4,d0
		bne	SIReturnOK
		move.l	#'MAC6',4(a0)
		bra	SIReturnOK

; Kompressionsfaktor ermitteln
SISCmfa		move.w	siComp(a2),d0
		cmp.w	#3,d0		;MAC3
		bne	1$
		move.w	#3,d0		;-> Faktor 1:3
		bra	3$
1$		cmp.w	#4,d0		;MAC6
		bne	2$
		move.w	#6,d0		;-> Faktor 1:6
		bra	3$
2$		move.w	#1,d0		;Sonst Faktor 1:1
3$		move.l	#2,(a0)		;Länge: 2
		move.w	d0,4(a0)	;Faktor
		bra	SIReturnOK

; Digitizer angeschlossen?
SISDcon		move.l	#2,(a0)		;Länge: 2
		move.w	#-1,4(a0)	;Keine Ahnung
		bra	SIReturnOK

; Größe des Puffers ermitteln
SISDbin		move.l	#4,(a0)		;Länge: 4
		move.l	#1,4(a0)	;Puffer für 1 Byte
		bra	SIReturnOK

; Verfügbare Sampleraten ermitteln
SISSrav		move.l	#6,(a0)		;Länge: 6
		move.l	a0,a3
		moveq	#8,d0
		dc.w	$a122		;NewHandleSys
		bne	SIReturn
		move.l	(a0),a2
		move.l	#rate4kHz,(a2)	;Bereichsgrenzen
		move.l	#rate48kHz,4(a2)
		move.w	#0,4(a3)	;Ein Bereich ist angegeben
		move.l	a0,6(a3)
		bra	SIReturnOK

; Kontinuiertliche Aufnahme verfügbar?
SISCont		move.l	#2,(a0)		;Länge: 2
		clr.w	4(a0)		;Nein
		bra	SIReturnOK

; Durchschleif-Lautstärke ermitteln
SISPlth		move.l	#2,(a0)		;Länge: 2
		move.w	siVol(a2),4(a0)
		bra	SIReturnOK

; Pause?
SISPaus		move.l	#2,(a0)		;Länge: 2
		clr.w	4(a0)		;Vorgabe: Nein
		tst.l	siVCB(a2)	;Stimme initialisiert?
		beq	SIReturnOK	;Nein, Rückkehr
		move.l	siVCB(a2),a3	;VCB holen
		cmp.b	#3,vcbState(a3)	;Pause?
		bne	SIReturnOK	;Nein, Rückkehr
		move.w	#1,4(a0)	;Ja
		bra	SIReturnOK


*
* Rückkehr aus Treiberroutine
*

NotEnoughHW	move.w	#-201,d0	;notEnoughHardware
		bra	SIReturn
InvalidComp	move.w	#-223,d0	;siInvalidCompression
		bra	SIReturn
InvalidSRat	move.w	#-225,d0	;siInvalidSampleRate
		bra	SIReturn
InvalidSSiz	move.w	#-226,d0	;siInvalidSampleSize
		bra	SIReturn
DeviceBusy	move.w	#-227,d0	;siDeviceBusyErr
		bra	SIReturn
UnknownInfoType	move.w	#-231,d0	;siUnknownInfoType
		bra	SIReturn
UnknownQuality	move.w	#-232,d0	;siUnknownQuality
		bra	SIReturn
SINoMem		moveq	#-108,d0	;noMemErr
		bra	SIReturn

SIReturnOK	moveq	#0,d0		;Alles OK

SIReturn	movem.l	(sp)+,a0-a3	;ParamBlock, DCE u.a. wiederherstellen

		btst	#noQueueBit-8,ioTrap(a0) ;Immediale calls mit RTS beenden
		beq	SIQueued

SINotQueued	tst.w	d0
		ble	SIImmedRTS
		clr.w	d0		;Request noch nicht beendet
SIImmedRTS	move.w	d0,ioResult(a0)
		rts

SIQueued	tst.w	d0
		ble	SIIODone
		clr.w	d0		;Request noch nicht beendet
		rts
SIIODone	move.l	JIODone,a0
		jmp	(a0)


*
* Interrupt-Routine zum Aufnehmen
*

IntRecord	move.b	_ciaaprb,d0		;Sample lesen
		move.w	vcbINTOff(a1),_intreq

		cmp.b	#2,vcbState(a1)		;Aufnahme abbrechen?
		beq	IntRecStop

		move.l	vcbPaula(a1),a0
		move.b	d0,d1
		lsl.w	#8,d1
		move.b	d0,d1
		eor.w	#$8080,d1
		move.w	d1,ac_dat(a0)		;Playthrough (notwendig!)

		move.l	vcbSIData(a1),a0	;Level Meter
		tst.w	siMeterOn(a0)
		beq	2$
		move.b	vcbMeterMax(a1),d1	;Maximum suchen
		cmp.b	d0,d1
		bhs	3$
		move.b	d0,vcbMeterMax(a1)
3$		addq.b	#1,vcbMeterCnt(a1)	;Zähler erhöhen
		bne	2$
		move.b	vcbMeterMax(a1),vcbMeterVal(a1)
		clr.b	vcbMeterMax(a1)

2$		cmp.b	#1,vcbState(a1)		;Aufnahme aktiv?
		bne	IntRecNothing

		move.l	siUserIRQ(a0),d1	;User-Interrupt aufrufen, falls vorhanden
		beq	5$
		movem.l	d1/a0-a2,-(sp)
		move.l	d1,a2
		move.l	siSPB(a0),a0		;Zeiger auf SPB
		lea	SndInBuf,a1		;Sample speichern
		move.b	d0,(a1)
		moveq	#0,d0
		move.b	vcbMeterMax(a1),d0	;Maximale Amplitude
		moveq	#1,d1			;Größe des Puffers
		addq.w	#1,NoSuperSwitch
		jsr	(a2)
		subq.w	#1,NoSuperSwitch
		movem.l	(sp)+,d1/a0-a2
		move.b	SndInBuf,d0		;Sample wiederholen

5$		move.l	vcbSIData(a1),a0	;Two's complement
		tst.w	siTwos(a0)
		beq	1$
		eor.b	#$80,d0

1$		move.l	vcbPosition(a1),d1	;NIL: Samples nicht speichern
		beq	4$
		move.l	d1,a0			;Sample-Zeiger holen
		move.b	d0,(a0)+		;Sample speichern
		move.l	a0,vcbPosition(a1)	;Sample-Zeiger setzen
4$		move.l	vcbIOParam(a1),a0	;Zeiger auf IOParam
		addq.l	#1,ioActCount(a0)	;Tatsächliche Länge erhöhen
		subq.l	#1,vcbLength(a1)	;Restlänge erniedrigen
		bls	IntRecDone
IntRecNothing	rts

IntRecDone	moveq	#0,d0			;OK
		bra	IntRecIODone
IntRecStop	moveq	#-27,d0			;abortErr

IntRecIODone	clr.b	vcbState(a1)		;Nicht mehr aktiv
		move.w	vcbINTOff(a1),_intena	;Interrupt abschalten
		movem.l	d2-d3/a2-a3,-(sp)
		move.l	SndInDCE,a1
		move.l	JIODone,a0
		addq.w	#1,NoSuperSwitch
		jsr	(a0)
		subq.w	#1,NoSuperSwitch
		movem.l	(sp)+,d2-d3/a2-a3
		rts


**
** Unterroutinen
**

; Eine Zeile warten
Wait1Line	movem.l	d0-d1,-(sp)
		moveq	#3,d1
2$		move.b	$dff006,d0
1$		cmp.b	$dff006,d0
		beq	1$
		dbra	d1,2$
		movem.l	(sp)+,d0-d1
		rts

; Lautstärke für eine Stimme setzen
; d0: Lautstärke (0..7)
; a0: Zeiger auf Paula-Basis (nicht verändern!)
SetVolume	and.l	#7,d0
		lsl.w	#6,d0
		divu.w	#7,d0
		move.w	d0,ac_vol(a0)
		rts

; Stimme reservieren
; d1: Belegungsmaske (1 Bit pro Stimme)
; Rückgabe d0: Stimmennummer (-1 = Fehlschlag)
;          a0: Zeiger auf VCB
AllocVoice	moveq	#-1,d2
AllocLoop	addq.w	#1,d2
		lsr.b	#1,d1		;Diese Stimme prüfen?
		bcs	AllocTry
AllocNext	cmp.b	#3,d2		;Nein, Alle Stimmen probiert?
		bne	AllocLoop
		moveq	#-1,d0		;Keine Stimme gefunden
		rts

AllocTry	btst	d2,ChannelMask	;Stimme schon von uns belegt?
		bne	AllocNext	;Ja, weiter suchen

		lea	SoundVCBTab,a0
		move.l	(a0,d2.w*4),a0	;Zeiger auf VCB holen
		bsr	Alloc1Voice	;Stimme belegen
		tst.l	d0		;Gelungen?
		bne	AllocNext	;Nein, weiter suchen
		move.l	d2,d0		;Stimmennummer holen
		bset	d0,ChannelMask	;Als belegt markieren
		lea	SoundVCBTab,a0
		move.l	(a0,d2.w*4),a0	;Zeiger auf VCB holen
		rts

; Eine Stimme belegen
; a0: VCB
; Rückgabe: d0#0: Fehler
Alloc1Voice	movem.l	d1/a6,-(sp)
		bsr	Alloc1Voice1
		movem.l	(sp)+,d1/a6
		rts

Alloc1Voice1	move.l	vcbAudioIO(a0),d0
		beq	1$
		move.l	d0,a1
		move.w	#ADCMD_ALLOCATE,IO_COMMAND(a1)
		lea	vcbAllocArray(a0),a0
		move.l	a0,ioa_Data(a1)
		move.l	#1,ioa_Length(a1)
		move.b	#ADALLOC_MAXPREC,LN_PRI(a1)
		move.b	#IOF_QUICK|ADIOF_NOWAIT,IO_FLAGS(a1)
		move.l	IO_DEVICE(a1),a6
		move.l	a1,-(sp)
		addq.w	#1,NoSuperSwitch
		jsr	-30(a6)		;BeginIO
		subq.w	#1,NoSuperSwitch
		move.l	(sp)+,a1
		move.b	IO_ERROR(a1),d0
		extb.l	d0
		rts

1$		moveq	#-1,d0
		rts

; Stimme freigeben
; a0: VCB
FreeVoice	move.l	a6,-(sp)
		move.l	_ExecBase,a6
		move.b	vcbVoiceNumber(a0),d0
		bclr	d0,ChannelMask		;Als frei markieren
		move.l	vcbAudioIO(a0),a1
		move.w	#ADCMD_FREE,IO_COMMAND(a1)
		EJSRLIB	DoIO
		move.l	(sp)+,a6
		rts


**
** Konstanten
**

; Strings
AudioName	AUDIONAME
AudIntName	dc.b	"ShapeShifter Audio Int",0
BaseName	dc.b	"ShapeShifter",0
		CNOP	0,4

; Tabelle mit Zeigern auf VCBs
SoundVCBTab	dc.l	SoundVCB1
		dc.l	SoundVCB2
		dc.l	SoundVCB3
		dc.l	SoundVCB4

; Tabelle mit Periodenwerten
SoundPerTable	dc.w	252,238,224,212,200,189,178,168,159,150,141,133
		dc.w	252,238,224,212,200,189,178,168,159,150,141,133
		dc.w	252,238,224,212,200,189,178,168,159,150,141,133
		dc.w	252,238,224,212,200,189,178,168,159,150,141,133
		dc.w	252,238,224,212,200,189,178,168,159,150,141,133
		dc.w	252,238,224,212,200,189,178,168,159,150,141,133
		dc.w	252,238,224,212,200,189,178,168,159,150,141,133
		dc.w	252,238,224,212,200,189,178,168,159,150,141,133
		dc.w	252,238,224,212,200,189,178,168,159,150,141,133
		dc.w	252,238,224,212,200,189,178,168,159,150,141,133
		dc.w	252,238,224,212,200,189,178,168,159,150,141,133

; Tabelle mit Wellenform-Längen
SoundLenTable	dc.w	2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048
		dc.w	1024,1024,1024,1024,1024,1024,1024,1024,1024,1024,1024,1024
		dc.w	512,512,512,512,512,512,512,512,512,512,512,512
		dc.w	256,256,256,256,256,256,256,256,256,256,256,256
		dc.w	128,128,128,128,128,128,128,128,128,128,128,128
		dc.w	64,64,64,64,64,64,64,64,64,64,64,64
		dc.w	32,32,32,32,32,32,32,32,32,32,32,32
		dc.w	16,16,16,16,16,16,16,16,16,16,16,16
		dc.w	8,8,8,8,8,8,8,8,8,8,8,8
		dc.w	4,4,4,4,4,4,4,4,4,4,4,4
		dc.w	2,2,2,2,2,2,2,2,2,2,2,2

; Sinus-Tabelle
SinTab		INCBIN	"sintab.bin"


**
** Initialisierte Daten
**

		SECTION	"DATA",DATA

; Interrupt-Strukturen
Channel0Int	dc.l	0,0
		dc.b	NT_INTERRUPT,0
		dc.l	AudIntName
		dc.l	ASCRegs
		dc.l	SoundInt

RecordInterrupt	dc.l	0,0
		dc.b	NT_INTERRUPT,0
		dc.l	AudIntName
RecordVCB	dc.l	0
		dc.l	IntRecord

; Taglists für AHI
AHIAllocTags	dc.l	AHIA_AudioID
AATID		dc.l	AHI_DEFAULT_ID
		dc.l	AHIA_MixFreq,SAMPLE_FREQ
		dc.l	AHIA_Channels,1
		dc.l	AHIA_Sounds,3
		dc.l	AHIA_SoundFunc,AHISoundHook
		dc.l	TAG_DONE

AHICtrlOnTags	dc.l	AHIC_Play,1
		dc.l	TAG_DONE

AHICtrlOffTags	dc.l	AHIC_Play,0
		dc.l	TAG_DONE

; AHI SoundFunc-Hook
AHISoundHook	dc.l	0,0
		dc.l	AHISoundFunc
		dc.l	0,0

; AHI Sounds
AHISound0	dc.l	AHIST_S8S
		dc.l	AHISoundBuf0
		dc.l	$400

AHISound1	dc.l	AHIST_S8S
		dc.l	AHISoundBuf1
		dc.l	$400

AHISound2	dc.l	AHIST_S8S
		dc.l	AHISoundEmpty
		dc.l	740


**
** Nicht initialisierte Daten
**

		SECTION	"BSS",BSS
ChannelMask	ds.b	1	;Belegungsmaske für Soundkanäle

		CNOP	0,4
ClkConst	ds.l	1	;Clock Constant

SoundVCB1	ds.b	vcb_SIZEOF	;Voice Control Blocks
SoundVCB2	ds.b	vcb_SIZEOF
SoundVCB3	ds.b	vcb_SIZEOF
SoundVCB4	ds.b	vcb_SIZEOF

ReplyPort	ds.l	1	;ReplyPort für Audio

SoundIntOld	ds.l	4	;Alte Audio-Interrupts

SndInDCE	ds.l	1	;DCE des Sound-Input-Treibers
SndInBuf	ds.l	1	;Fake-Input-Buffer (1 Byte)

AHICtrl		ds.l	1	;AHI-Control

ASCRegs		ds.b	$1000	;Simulierte EASC-Register
FIFOPtr		ds.l	1	;Zeiger in EASC-FIFO

GotChannel01	ds.w	1	;Flag: Kanal 0 und 1 belegt, Audio-Ausgabe möglich
SoundBufPtr	ds.w	1	;Double-Buffering-Zeiger
AHIBufNum	ds.w	1	;Double-Buffering-Puffernummer (AHI)

		CNOP	0,4
AHISoundBuf0	ds.b	$800
AHISoundBuf1	ds.b	$800
AHISoundEmpty	ds.b	740*2

		SECTION	"CHIPBSS",BSS,CHIP
		CNOP	0,4
SoundBufV1	ds.b	$800
SoundBufV2	ds.b	$800
SoundBufV3	ds.b	$800
SoundBufV4	ds.b	$800
SoundEmpty	ds.b	$800

		END
