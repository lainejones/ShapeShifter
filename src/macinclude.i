*
* Macintosh IIci-Emulator - Macintosh-Includes
*

		INCLUDE	"exec/types.i"

; Handle
HANDLE	    MACRO		; pointer to master pointer (32 bits)
\1	    EQU     SOFFSET
SOFFSET     SET     SOFFSET+4
	    ENDM

; Queue Header
 STRUCTURE	QHdr,0
	WORD	qFlags
	APTR	qHead
	APTR	qTail
 LABEL	QHdr_SIZEOF

; Queue Element
 STRUCTURE	QElem,0
	APTR	qLink
	WORD	qType
 LABEL	QElem_SIZEOF

; Device Control Entry
 STRUCTURE	DCtlEntry,0
	APTR	dCtlDriver		;Ptr to ROM driver/Handle to RAM driver
	WORD	dCtlFlags
	STRUCT	dCtlQHdr,QHdr_SIZEOF	;I/O queue header
	LONG	dCtlPosition		;Current R/W byte position
	HANDLE	dCtlStorage		;Handle to private storage
	WORD	dCtlRefNum		;Driver reference number
	LONG	dCtlCurTicks
	APTR	dCtlWindow
	WORD	dCtlDelay		;Ticks between periodic actions
	WORD	dCtlEMask
	WORD	dCtlMenu
	BYTE	dCtlSlot		;Slot
	BYTE	dCtlSlotId		;sResource directory ID
	LONG	dCtlDevBase		;Slot device base address
	APTR	dCtlOwner
	BYTE	dCtlExtDev		;External device ID
	BYTE	dCtlFillByte
 LABEL	DCE_SIZEOF

; Finder Info
 STRUCTURE	FInfo,0
	LONG	fdType			;File type, e.g. "TEXT"/"APPL"
	LONG	fdCreator		;File creator's signature, e.g. "MSWD"
	UWORD	fdFlags			;Finder flags
	LONG	fdLocation		;Icon position
	WORD	fdFldr			;Folder number (not used in HFS)
 LABEL	FInfo_SIZEOF

; Parameter Block
 STRUCTURE	ParamBlock,0
	STRUCT	ioQElem,QElem_SIZEOF	;Queue entry
	WORD	ioTrap			;Routine trap
	APTR	ioCmdAddr		;Routine address
	APTR	ioCompletion		;Completion routine address
	WORD	ioResult		;Result code (1 = pending)
	APTR	ioNamePtr		;Pointer to driver name
	WORD	ioVRefNum		;Volume reference or drive number
 LABEL	PB_SIZEOF

; IO Parameter Block
 STRUCTURE	IOParam,PB_SIZEOF
	WORD	ioRefNum		;Driver reference number
	BYTE	ioVersNum
	BYTE	ioPermssn		;Read/Write permission
	APTR	ioMisc
	APTR	ioBuffer		;Pointer to data buffer
	LONG	ioReqCount		;Requested number of bytes
	LONG	ioActCount		;Actual number of bytes completed
	WORD	ioPosMode		;Positioning mode
	LONG	ioPosOffset		;Positioning offset
 LABEL	IOParam_SIZEOF

; Control Parameter Block
 STRUCTURE	CntrlParam,PB_SIZEOF
	WORD	ioCRefNum		;Driver reference number
	WORD	csCode			;Type of control or status request
	STRUCT	csParam,22		;Control or status information
 LABEL	CntrlParam_SIZEOF

; HVolume Parameter Block
 STRUCTURE	HVolumeParam,PB_SIZEOF
	LONG	iov_filler2
	WORD	ioVolIndex		;>0: volume index, <0: use name/num, 0: use num
	ULONG	ioVCrDate		;Date/time volume created
	ULONG	ioVLsMod		;Date/time of last modification
	WORD	ioVAtrb			;Volume attribute bits
	UWORD	ioVNmFls		;Number of files in root directory
	WORD	ioVBitMap		;Sector of start of volume bitmap
	WORD	ioAllocPtr
	UWORD	ioVNmAlBlks		;Number of allocation blocks on volume
	LONG	ioVAlBlkSiz		;Size of an allocation block in bytes
	LONG	ioVClpSiz		;Default allocation clump size in bytes
	WORD	ioAlBlSt		;First sector represented in bitmap
	LONG	ioVNxtCNID		;Next serial number for new file or dir
	UWORD	ioVFrBlk		;Number of free allocation blocks
	UWORD	ioVSigWord		;Volume signature ($D2D7=flat, $4244=HFS)
	WORD	ioVDrvInfo		;Drive number
	WORD	ioVDRefNum		;Driver reference number
	WORD	ioVFSID			;File system identifier
	ULONG	ioVBkUp			;Date/time of last backup
	UWORD	ioVSeqNum
	LONG	ioVWrCnt		;Volume write count
	LONG	ioVFilCnt		;Total number of files on volume
	LONG	ioVDirCnt		;Total number of dirs on volume
	STRUCT	ioVFndrInfo,32
 LABEL	HVolumeParam_SIZEOF

; Root for HFileParam, HFileInfo and DirInfo
 STRUCTURE	HFRoot,PB_SIZEOF
	WORD	ioFRefNum		;File reference number
	BYTE	ioFVersNum		;Version (0=HFS)
	BYTE	iof_filler1
	WORD	ioFDirIndex		;Directory index
	BYTE	ioFlAttrib		;File attribute bits
	BYTE	ioFlVersNum		;File version number (0)
 LABEL	HFRoot_SIZEOF

; HFile Parameter Block
 STRUCTURE	HFileParam,HFRoot_SIZEOF
	STRUCT	ioFlFndrInfo,FInfo_SIZEOF ;Finder information
	LONG	ioDirID			;"Hard" directory ID
	UWORD	ioFlStBlk		;First allocation block of data fork
	LONG	ioFlLgLen		;Logical EOF of data fork
	LONG	ioFlPyLen		;Physical EOF of data fork
	UWORD	ioFlRStBlk		;First allocation block of rsrc fork
	LONG	ioFlRLgLen		;Logical EOF of rsrc fork
	LONG	ioFlRPyLen		;Physical EOF of rsrc fork
	ULONG	ioFlCrDat		;Date/time of creation
	ULONG	ioFlMdDat		;Date/time of last modification
 LABEL	HFileParam_SIZEOF

; HFileInfo Parameter Block
 STRUCTURE	HFileInfo,HFileParam_SIZEOF
	ULONG	ioFlBkDat		;Date/time of last backup
	STRUCT	ioFlXFndrInfo,16
	LONG	ioFlParID		;"Hard" ID of this dir's parent
	LONG	ioFlClpSize		;Allocation block size (0=use default)
 LABEL	HFileInfo_SIZEOF

; DirInfo Parameter Block
 STRUCTURE	DirInfo,HFRoot_SIZEOF
	STRUCT	ioDrUsrWds,16
	LONG	ioDrDirID		;"Hard" directory ID
	UWORD	ioDrNmFls		;Number of files and dirs in this dir
	STRUCT	iod_filler3,18
	ULONG	ioDrCrDat		;Date/time of creation
	ULONG	ioDrMdDat		;Date/time of last modification
	ULONG	ioDrBkDat		;Date/time of last backup
	STRUCT	ioDrFndrInfo,16
	LONG	ioDrParID		;"Hard" ID of this dir's parent
 LABEL	DirInfo_SIZEOF

; Copy/MoveRename Parameter Block
 STRUCTURE	CopyParam,PB_SIZEOF
	WORD	ioDstVRefNum		;Destination volume identifier
	WORD	ioc_filler8
	APTR	ioNewName		;Pointer to destination pathname
	APTR	ioCopyName		;Pointer to optional new name (NIL if not renaming)
	LONG	ioNewDirID		;Destination directory ID
	LONG	ioc_filler14
	LONG	ioc_filler15
	LONG	io_DirID		;Source directory ID
 LABEL	CopyParam_SIZEOF

; Drive Status
 STRUCTURE	DrvSts,0
	WORD	dsTrack			;Current track
	BYTE	dsWriteProt		;-1 if volume is locked
	BYTE	dsDiskInPlace		;Disk in drive (0 = no disk, 1 = disk inserted, 2 = disk inserted and accessed, 8 = fixed disk)
	BYTE	dsInstalled		;Drive installed (1 = connected, -1 = not connected, 0 = don't know)
	BYTE	dsSides			;-1 for 2-sided, 0 for 1-sided
	APTR	dsQLink			;Next queue entry
	WORD	dsQType			;0 for Sony, 1 for HD20
	WORD	dsDrive			;Drive number
	WORD	dsRefNum		;Driver reference number
	WORD	dsFSID			;File system ID
 LABEL	DrvSts_SIZEOF

 STRUCTURE	DSSony,DrvSts_SIZEOF
	BYTE	dsTwoSideFmt		;After 1st R/W: 0=1 side, -1=2 side
	BYTE	dsNeedsFlush		;-1 for New Interface
	WORD	dsDiskErrs		;Soft error count
	BYTE	dsOnlyTwoSides		;-1: Laufwerk unterstützt nur doppelseitige Disketten
	BYTE	dsMFMDisk		;-1: Diskette ist im MFM-Format
	BYTE	dsHDDisk		;-1: Diskette ist HD
	BYTE	dsPad0
 LABEL	DSSony_SIZEOF

 STRUCTURE	DSHD20,DrvSts_SIZEOF
	WORD	dsDriveSize		;Drive block size low word
	WORD	dsDriveS1		;Drive block size high word
	WORD	dsDriveType		;1 for HD20
	WORD	dsDriveManf		;1 for Apple Computer, Inc.
	BYTE	dsDriveChar		;230 ($E6) for HD20
	BYTE	dsDriveMisc
 LABEL	DSHD20_SIZEOF

; Gamma Table
 STRUCTURE	GammaTbl,0
	WORD	gVersion	;gtab version, currently 0
	WORD	gType		;drHWId value
	WORD	gFormulaSize	;size of formula data below
	WORD	gChanCnt	;# of component channels
	WORD	gDataCnt	;# of values per channel
	WORD	gDataWidth	;size of data in tables
	LABEL	gFormulaData
 LABEL	GammaTbl_SIZEOF

; Read/Write permissions
fsCurPerm	= 0			;Whatever is currently allowed
fsRdPerm	= 1			;Exclusive read
fsWrPerm	= 2			;Exclusive write
fsRdWrPerm	= 3			;Exclusive read/write
fsRdWrShPerm	= 4			;Shared read/write

; Positioning modes
fsAtMark	= 0			;At current mark
fsFromStart	= 1			;Set mark rel to BOF
fsFromLEOF	= 2			;Set mark rel to logical EOF
fsFromMark	= 3			;Set mark rel to current mark

rdVerify	= 64			;Add to above for read-verify
rdVerifyBit	= 6			;Bit number of rdVerify

; Directory IDs
fstRtParID	= 1			;Root's parent dir ID
fstRtDirID	= 2			;Root's dir ID

; Volume attributes
	BITDEF	VA,BUSY,6		;Busy (one or more files opened)
	BITDEF	VA,HARDLOCK,7		;Locked by hardware
	BITDEF	VA,SOFTLOCK,15		;Locked by software
VA_NOTVALIDATED	= $1f			;Inconsistencies on volume

; File attributes
	BITDEF	FA,LOCKED,0		;File is locked
	BITDEF	FA,RFOPEN,2		;Rsrc fork is open
	BITDEF	FA,DFOPEN,3		;Data fork is open
	BITDEF	FA,ISDIR,4		;File is a directory (PBGetCatInfo)
	BITDEF	FA,OPEN,7		;Rsrc/date fork is open

; Allgemeine Konstanten
noQueueBit	= 9			;Bit in TrapWord für Immediate call
aRdCmd		= 2			;Read operation requested
aWrCmd		= 3			;Write operation requested
killCode	= 1			;KillIO control code
accRun		= 65			;Periodic action control code

; Globale Variablen
JIODone		= $8fc
DskErr		= $142
