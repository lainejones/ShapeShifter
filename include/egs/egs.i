	IFND	EGS_EGS_I
EGS_EGS_I	SET	1
**
** Minimal EGS assembler include for building ShapeShifter.
** The original EGS SDK headers are not available. These values were read
** back from the instructions assembled into the released ShapeShifter 3.11
** binary (MacEmulVideo.asm screen open/close code), so they match what
** Christian Bauer built against. Only the names ShapeShifter uses exist.
**

; EIDCMP flags for an EGS screen. The 3.11 binary only shows the combination
; E_eMOUSEBUTTONS|E_eRAWKEY = 5 and E_eMOUSEMOVE = 2; which of 1 and 4 is
; which is not known, so never use E_eMOUSEBUTTONS or E_eRAWKEY on its own.
E_eMOUSEBUTTONS	EQU	$00000001
E_eRAWKEY	EQU	$00000004
E_eMOUSEMOVE	EQU	$00000002

; EScreen fields
esc_Map		EQU	12	;EBitMap pointer
esc_Mouse	EQU	20	;standard mouse pointer
esc_Port	EQU	36	;user message port

; EBitMap fields
ebm_Width	EQU	0
ebm_Dest	EQU	8	;frame buffer address
ebm_Lock	EQU	12	;lock count (byte)

	ENDC
