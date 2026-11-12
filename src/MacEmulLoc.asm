**
** MacEmulLoc.asm - catalog texts for the parts added in 3.20
**
** LocalizeNew stores the catalog's string for each message in a text
** pointer of the new modules (MacEmulTabs, MacEmulCheck, MacEmulPRam).
** Called once at the start, after Localize in MacEmul.asm.
**

		INCLUDE	"exec/types.i"
		INCLUDE	"intuition/intuition.i"
		INCLUDE	"libraries/gadtools.i"
CATCOMP_NUMBERS	= 1
		INCLUDE	"Strings.i"

		XDEF	LocalizeNew

		XREF	TheLocale
		XREF	GetString
		XREF	CPUFPUP
		XREF	CPUMMUP
		XREF	CPUNGads
		XREF	CPUNoFPUP
		XREF	CPUNoMMUP
		XREF	CPUTabLabelP
		XREF	CfgLabelP
		XREF	CfgSaveP
		XREF	CfgDefP
		XREF	CfgAdvP
		XREF	MdIconNameP

		SECTION	"CODE",CODE

LocalizeNew	movem.l	d0-d1/a0-a2,-(sp)
		lea	LocTab,a2
1$		move.l	(a2)+,d0	;Message number
		bmi	9$
		lea	TheLocale,a0
		jsr	GetString
		move.l	(a2)+,a1	;Where the pointer goes
		move.l	d0,(a1)
		bra	1$
9$		movem.l	(sp)+,d0-d1/a0-a2
		rts

		SECTION	"DATA",DATA

LocTab
		dc.l	MSG_CONFIG_GAD,CfgLabelP
		dc.l	MSG_CONFIGSAVE_GAD,CfgSaveP
		dc.l	MSG_DEFAULTS_GAD,CfgDefP
		dc.l	MSG_ADVANCED_GAD,CfgAdvP
		dc.l	MSG_CPU_TAB,CPUTabLabelP
		dc.l	MSG_CPUINFO_GAD,CPUNGads+gng_GadgetText
		dc.l	MSG_CPUOPT0_GAD,CPUNGads+1*gng_SIZEOF+gng_GadgetText
		dc.l	MSG_CPUOPT1_GAD,CPUNGads+2*gng_SIZEOF+gng_GadgetText
		dc.l	MSG_CPUOPT2_GAD,CPUNGads+3*gng_SIZEOF+gng_GadgetText
		dc.l	MSG_CPUOPT4_GAD,CPUNGads+4*gng_SIZEOF+gng_GadgetText
		dc.l	MSG_CPUOPT5_GAD,CPUNGads+5*gng_SIZEOF+gng_GadgetText
		dc.l	MSG_CPUOPT6_GAD,CPUNGads+6*gng_SIZEOF+gng_GadgetText
		dc.l	MSG_CPUOPT7_GAD,CPUNGads+7*gng_SIZEOF+gng_GadgetText
		dc.l	MSG_CPUOPT8_GAD,CPUNGads+8*gng_SIZEOF+gng_GadgetText
		dc.l	MSG_CPU_FPU,CPUFPUP
		dc.l	MSG_CPU_NOFPU,CPUNoFPUP
		dc.l	MSG_CPU_MMU,CPUMMUP
		dc.l	MSG_CPU_NOMMU,CPUNoMMUP
		dc.l	MSG_APPICON_NAME,MdIconNameP
		dc.l	-1

		END
