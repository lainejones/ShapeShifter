	IFND	LIBRARIES_PICASSO96_I
LIBRARIES_PICASSO96_I	SET	1
**
** Minimal Picasso96 assembler include for building ShapeShifter.
** Values read back from the released ShapeShifter 3.11 binary (PIP tag list
** and p96GetBitMapAttr calls); they agree with the Picasso96 API layout.
** Only the names ShapeShifter uses exist.
**

; p96GetBitMapAttr attributes
P96BMA_MEMORY		EQU	3
P96BMA_BYTESPERROW	EQU	4

; p96PIP_OpenTagList / p96PIP_GetTagList tags
P96PIP_Dummy		EQU	$80030060
P96PIP_SourceFormat	EQU	(P96PIP_Dummy+1)
P96PIP_SourceBitMap	EQU	(P96PIP_Dummy+2)
P96PIP_SourceWidth	EQU	(P96PIP_Dummy+4)
P96PIP_SourceHeight	EQU	(P96PIP_Dummy+5)

; RGBFTYPE
RGBFB_R5G5B5		EQU	11

	ENDC
