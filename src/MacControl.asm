*
* Mac-Handler-Kontrollprogramm zum Umschalten zwischen den Forks
*
* © Copyright 1995 Christian Bauer
*

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"dos/dosextens.i"

		XDEF	_main
		XREF	_DOSBase

		SECTION	"CODE",CODE


**
** Definitionen
**

ACTION_USER	= 2050


**
** Hauptprogramm
**

; Argumente lesen
_main		move.l	_DOSBase,a6
		move.l	#Template,d1
		move.l	#ArgArray,d2
		moveq	#0,d3
		JSRLIB	ReadArgs
		move.l	d0,d1
		beq	PrintError
		JSRLIB	FreeArgs

; Device suchen
		move.l	DevName,d1
		moveq	#0,d2
		JSRLIB	GetDeviceProc
		move.l	d0,TheDevProc
		beq	PrintError

; Data-Fork anschalten?
		tst.l	DataSwitch
		beq	1$
		move.l	TheDevProc,a0
		move.l	dvp_Port(a0),d1
		move.l	#ACTION_USER,d2
		moveq	#0,d3
		JSRLIB	DoPkt
		bra	2$

; Resource-Fork anschalten?
1$		tst.l	RsrcSwitch
		beq	2$
		move.l	TheDevProc,a0
		move.l	dvp_Port(a0),d1
		move.l	#ACTION_USER,d2
		moveq	#1,d3
		JSRLIB	DoPkt

; Device freigeben
2$		move.l	TheDevProc,d1
		JSRLIB	FreeDeviceProc

; Beenden
		moveq	#0,d0
		rts

; Fehlerbehandlung
PrintError	JSRLIB	IoErr
		move.l	d0,d1
		moveq	#0,d2
		JSRLIB	PrintFault
		moveq	#10,d0
		rts


**
** Konstanten
**

; Strings
Version		dc.b	"$VER: MacControl 1.0",0
Template	dc.b	"DEVICE/A,DATA/S,RESOURCE=RSRC/S",0
DevNotTxt	dc.b	"The specified device could not be found",10,0
ArgErrTxt	dc.b	"Invalid arguments",10,0
		CNOP	0,4

**
** Nicht-initialisierte Daten
**

		SECTION	"BSS",BSS
TheDevProc	ds.l	1

ArgArray
DevName		ds.l	1
DataSwitch	ds.l	1
RsrcSwitch	ds.l	1

		END
