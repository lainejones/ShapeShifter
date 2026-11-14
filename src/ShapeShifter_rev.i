VERSION		EQU	3
REVISION	EQU	20
DATE	MACRO
		dc.b	'13.11.26'
	ENDM
VERS	MACRO
		dc.b	'ShapeShifter 3.20'
	ENDM
VSTRING	MACRO
		dc.b	'ShapeShifter 3.20 beta 4 (13.11.26)',13,10,0
	ENDM
VERSTAG	MACRO
		dc.b	0,'$VER: ShapeShifter 3.20 (13.11.26) beta 4',0
	ENDM
