**
** MacEmulHFS.asm - write an empty Mac (HFS) disk
**
** Mac OS's own "Initialise" writes the whole disk and reads it back: two
** hours for 750 MB on a slow controller. An empty HFS volume is a handful of
** sectors: the master directory block (sector 2, and a copy in the last but
** one), the allocation bitmap, and the two B-tree files (extents overflow,
** empty; catalog, with the root folder and its thread record).
** The layout and every number are the ones Mac OS 8 itself chooses (compared
** with a 750 MB disk it initialised); tools/mkhfs.py is the same in Python.
**
**  FormatFileDisk	a new file disk (called by "Create...")
**  FormatDevDisk	a device disk (the "Format..." buttons), asks first
**

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"exec/io.i"
		INCLUDE	"devices/trackdisk.i"
		INCLUDE	"dos/dos.i"
		INCLUDE	"dos/dosextens.i"
		INCLUDE	"dos/filehandler.i"
		INCLUDE	"macros.i"
CATCOMP_NUMBERS	= 1
		INCLUDE	"Strings.i"

		XDEF	FormatFileDisk
		XDEF	FormatDevDisk
		XDEF	DevTotalSectors

		XREF	SReq

		SECTION	"CODE",CODE

HFSBUFSEC	= 32			;Work buffer, sectors
HFSBUFSIZE	= HFSBUFSEC*512
HFSMINSEC	= 2048			;1 MB
HFSMAXSEC	= $7fffff		;4 GB (ShapeShifter's disks go by byte offsets)
MACTIME		= 2335305600		;Seconds from 1.1.1904 to 1.1.1978
MAXBTREE	= 2048*512		;A B-tree file: 2048 nodes, one map record

**
** Write an empty HFS volume
** d0: sectors (512 bytes)  a0: name (C string; ends at a '.', 27 characters)
** a1: write routine: d0 sector, d1 sectors, a0 data -> d0 0 = written
** -> d0: 0 = done, 1 = size cannot be used, 2 = no memory, 3 = write error
**
HFSFormat	movem.l	d2-d7/a2-a6,-(sp)
		move.l	d0,HFSTotal
		move.l	a1,HFSWrite

; The name as a Pascal string, plain ASCII
		lea	HFSName+1,a1
		moveq	#0,d1
1$		move.b	(a0)+,d0
		beq	4$
		cmp.b	#'.',d0
		beq	4$
		cmp.b	#' ',d0
		blo	2$
		cmp.b	#':',d0
		beq	2$
		cmp.b	#127,d0
		blo	3$
2$		moveq	#'_',d0
3$		move.b	d0,(a1)+
		addq.w	#1,d1
		cmp.w	#27,d1
		blo	1$
4$		tst.w	d1
		bne	6$
		lea	HFSDefName,a0
		lea	HFSName+1,a1
5$		move.b	(a0)+,(a1)+
		beq	6$
		addq.w	#1,d1
		bra	5$
6$		move.b	d1,HFSName
		lea	HFSName+1,a1		;(the rest of the 28 bytes: 0)
		add.w	d1,a1
7$		cmp.l	#HFSName+28,a1
		bhs	8$
		clr.b	(a1)+
		bra	7$
8$
; Layout
		moveq	#1,d7			;(error: size)
		move.l	HFSTotal,d0
		cmp.l	#HFSMINSEC,d0
		blo	HFSExit
		cmp.l	#HFSMAXSEC,d0
		bhi	HFSExit
		move.l	d0,d1			;Sectors per allocation block: at most
		moveq	#16,d2			; 65535 blocks
		lsr.l	d2,d1
		addq.l	#1,d1
		move.l	d1,HFSSpb
		move.l	d0,d2			;Bitmap: one bit per block
		divu.l	d1,d2
		add.l	#4095,d2
		moveq	#12,d3
		lsr.l	d3,d2
		move.l	d2,HFSBm
		addq.l	#3,d2			;First allocation block's sector
		move.l	d2,HFSAlSt
		move.l	d0,d3			;Allocation blocks (the last two sectors
		sub.l	d2,d3			; are the copy of the MDB and a spare)
		subq.l	#2,d3
		divu.l	d1,d3
		move.l	d3,HFSNBlk
		move.l	d1,d4			;Allocation block, bytes
		lsl.l	#8,d4
		add.l	d4,d4
		move.l	d4,HFSAbSz
		move.l	d0,d5			;Each B-tree file: 1/64 of the disk,
		lsl.l	#3,d5			; at most MAXBTREE, whole blocks
		cmp.l	#MAXBTREE,d5
		bls	10$
		move.l	#MAXBTREE,d5
10$		divu.l	d4,d5
		bne	11$
		moveq	#1,d5
11$		move.l	d5,HFSBtBlk
		mulu.l	d4,d5
		move.l	d5,HFSBt
		lsr.l	#8,d5
		lsr.l	#1,d5
		move.l	d5,HFSNodes		;(= sectors of the file)

; Now
		move.l	_DOSBase,a6
		lea	HFSStamp,a0
		move.l	a0,d1
		JSRLIB	DateStamp
		move.l	HFSStamp+ds_Days,d0
		mulu.l	#86400,d0
		move.l	HFSStamp+ds_Minute,d1
		mulu.l	#60,d1
		add.l	d1,d0
		move.l	HFSStamp+ds_Tick,d1
		divu.l	#50,d1
		add.l	d1,d0
		add.l	#MACTIME,d0
		move.l	d0,HFSNow

; Buffer
		moveq	#2,d7			;(error: memory)
		move.l	_ExecBase,a6
		move.l	#HFSBUFSIZE,d0
		move.l	#MEMF_PUBLIC|MEMF_CLEAR,d1
		JSRLIB	AllocVec
		move.l	d0,HFSBuf
		beq	HFSExit
		moveq	#3,d7			;(error: writing)

; Zeros from the boot blocks to the end of the catalog file
		moveq	#0,d2			;d2: sector
		move.l	HFSNodes,d3
		add.l	d3,d3
		add.l	HFSAlSt,d3		;d3: sectors left
20$		move.l	d3,d1
		cmp.l	#HFSBUFSEC,d1
		bls	21$
		moveq	#HFSBUFSEC,d1
21$		move.l	d2,d0
		bsr	HFSPut
		bne	HFSFree
		add.l	d1,d2
		sub.l	d1,d3
		bne	20$

; The bitmap: the blocks of the two B-tree files are taken
		move.l	HFSBuf,a0
		move.l	HFSBtBlk,d0
		add.l	d0,d0
		move.l	d0,d1
		lsr.l	#3,d1
		bra	31$
30$		st.b	(a0)+
31$		dbra	d1,30$
		and.w	#7,d0
		beq	32$
		move.w	#$ff00,d1
		lsr.w	d0,d1
		move.b	d1,(a0)
32$		moveq	#3,d0
		move.l	HFSBm,d1
		bsr	HFSPut
		bne	HFSFree
		bsr	HFSClear

; The master directory block, and its copy
		move.l	HFSBuf,a0
		move.w	#$4244,(a0)		;drSigWord
		move.l	HFSNow,d0
		move.l	d0,2(a0)		;drCrDate
		move.l	d0,6(a0)		;drLsMod
		move.w	#$0100,10(a0)		;drAtrb: unmounted properly
		move.w	#3,14(a0)		;drVBMSt
		move.w	HFSNBlk+2,18(a0)	;drNmAlBlks
		move.l	HFSAbSz,d0
		move.l	d0,20(a0)		;drAlBlkSiz
		lsl.l	#2,d0
		move.l	d0,24(a0)		;drClpSiz
		move.w	HFSAlSt+2,28(a0)	;drAlBlSt
		moveq	#16,d0
		move.l	d0,30(a0)		;drNxtCNID
		move.l	HFSNBlk,d0
		sub.l	HFSBtBlk,d0
		sub.l	HFSBtBlk,d0
		move.w	d0,34(a0)		;drFreeBks
		lea	HFSName,a1
		lea	36(a0),a2		;drVN
		moveq	#27,d0
40$		move.b	(a1)+,(a2)+
		dbra	d0,40$
		moveq	#1,d0
		move.l	d0,70(a0)		;drWrCnt
		move.l	HFSBt,d0
		move.l	d0,74(a0)		;drXTClpSiz
		move.l	d0,78(a0)		;drCTClpSiz
		move.l	d0,130(a0)		;drXTFlSize
		move.l	d0,146(a0)		;drCTFlSize
		move.w	HFSBtBlk+2,d0
		move.w	d0,136(a0)		;drXTExtRec: block 0, d0 blocks
		move.w	d0,150(a0)		;drCTExtRec: block d0, d0 blocks
		move.w	d0,152(a0)
		moveq	#2,d0
		moveq	#1,d1
		bsr	HFSPut
		bne	HFSFree
		move.l	HFSTotal,d0
		subq.l	#2,d0
		moveq	#1,d1
		bsr	HFSPut
		bne	HFSFree
		bsr	HFSClear

; The extents overflow file: a header node, nothing in the tree
		move.l	HFSBuf,a0
		moveq	#0,d0			;Depth
		moveq	#0,d1			;Root
		moveq	#0,d2			;Records
		moveq	#0,d3			;First and last leaf
		moveq	#7,d4			;Longest key
		moveq	#1,d5			;Nodes in use
		bsr	HFSHeader
		move.l	HFSAlSt,d0
		moveq	#1,d1
		bsr	HFSPut
		bne	HFSFree
		bsr	HFSClear

; The catalog file: header node, and one leaf with the root folder (key:
; parent 1, the disk's name) and its thread record (key: folder 2, no name)
		move.l	HFSBuf,a0
		moveq	#1,d0
		moveq	#1,d1
		moveq	#2,d2
		moveq	#1,d3
		moveq	#37,d4
		moveq	#2,d5
		bsr	HFSHeader
		move.l	HFSBuf,a1
		lea	512(a1),a1		;a1: the leaf
		move.b	#$ff,8(a1)		;ndType: leaf
		move.b	#1,9(a1)		;ndNHeight
		move.w	#2,10(a1)		;ndNRecs
		lea	14(a1),a2
		moveq	#0,d0
		move.b	HFSName,d0		;d0: length of the name
		move.l	d0,d1
		addq.l	#6,d1			;Key length: with its length byte even
		btst	#0,d1
		bne	50$
		addq.l	#1,d1
50$		move.b	d1,(a2)+
		clr.b	(a2)+
		moveq	#1,d2
		move.l	d2,(a2)+		;Parent: 1
		lea	HFSName,a3
		move.w	d0,d2
51$		move.b	(a3)+,(a2)+
		dbra	d2,51$
		lea	15(a1),a2
		add.l	d1,a2			;Behind the key: the folder record
		move.w	#$0100,(a2)+		;cdrType: folder
		clr.l	(a2)+			;dirFlags, dirVal
		moveq	#2,d2
		move.l	d2,(a2)+		;dirDirID
		move.l	HFSNow,(a2)+		;dirCrDat
		move.l	HFSNow,(a2)+		;dirMdDat
		lea	52(a2),a2		;dirBkDat, Finder info, reserved
		move.l	a2,d3
		sub.l	a1,d3			;d3: where the second record starts
		move.l	#$07000000,(a2)+	;Key: length 7, folder 2, no name
		move.l	#$00020000,(a2)+
		move.w	#$0300,(a2)+		;cdrType: folder thread
		clr.l	(a2)+
		clr.l	(a2)+
		moveq	#1,d2
		move.l	d2,(a2)+		;thdParID
		lea	HFSName,a3
		move.l	a2,a0
		move.w	d0,d2
52$		move.b	(a3)+,(a0)+		;thdCName
		dbra	d2,52$
		lea	32(a2),a2
		move.l	a2,d0
		sub.l	a1,d0
		move.w	d0,506(a1)		;Free space from here
		move.w	d3,508(a1)
		move.w	#14,510(a1)
		move.l	HFSAlSt,d0
		add.l	HFSNodes,d0
		moveq	#2,d1
		bsr	HFSPut
		bne	HFSFree
		moveq	#0,d7

HFSFree		move.l	_ExecBase,a6
		move.l	HFSBuf,a1
		JSRLIB	FreeVec
HFSExit		move.l	d7,d0
		movem.l	(sp)+,d2-d7/a2-a6
		rts

; B-tree header node into a0. d0 depth, d1 root, d2 leaf records, d3 first
; and last leaf, d4 longest key, d5 nodes in use (1 or 2)
HFSHeader	move.l	d6,-(sp)
		move.b	#1,8(a0)		;ndType: header
		move.w	#3,10(a0)		;ndNRecs
		move.w	d0,14(a0)		;bthDepth
		move.l	d1,16(a0)		;bthRoot
		move.l	d2,20(a0)		;bthNRecs
		move.l	d3,24(a0)		;bthFNode
		move.l	d3,28(a0)		;bthLNode
		move.w	#512,32(a0)		;bthNodeSize
		move.w	d4,34(a0)		;bthKeyLen
		move.l	HFSNodes,d6
		move.l	d6,36(a0)		;bthNNodes
		sub.l	d5,d6
		move.l	d6,40(a0)		;bthFree
		move.w	#$ff00,d6		;The map: one bit per node in use
		lsr.w	d5,d6
		move.b	d6,$f8(a0)
		move.w	#$1f8,504(a0)		;Where the three records start, and
		move.w	#$f8,506(a0)		; the free space
		move.w	#$78,508(a0)
		move.w	#$0e,510(a0)
		move.l	(sp)+,d6
		rts

; Write d1 sectors of the buffer at sector d0. Z: written
HFSPut		movem.l	d1-d7/a0-a6,-(sp)
		move.l	HFSBuf,a0
		move.l	HFSWrite,a1
		jsr	(a1)
		movem.l	(sp)+,d1-d7/a0-a6
		tst.l	d0
		rts

HFSClear	movem.l	d0/a0,-(sp)
		move.l	HFSBuf,a0
		move.w	#HFSBUFSIZE/4-1,d0
1$		clr.l	(a0)+
		dbra	d0,1$
		movem.l	(sp)+,d0/a0
		rts


**
** A new file disk: file d1 (open, d2 bytes long), a0: its path, for the name
** -> d0: 0 = done (otherwise the file is left as it is: the Mac will offer
** to initialise it)
**
FormatFileDisk	movem.l	d2-d3/a2/a6,-(sp)
		move.l	d1,HFSFile
		move.l	d2,d3
		lsr.l	#8,d3
		lsr.l	#1,d3			;d3: sectors
		move.l	_DOSBase,a6
		move.l	a0,d1
		JSRLIB	FilePart
		move.l	d0,a0
		move.l	d3,d0
		lea	HFSFileWrite,a1
		bsr	HFSFormat
		movem.l	(sp)+,d2-d3/a2/a6
		rts

HFSFileWrite	move.l	_DOSBase,a6
		move.l	a0,d4
		move.l	d1,d5
		lsl.l	#8,d5
		add.l	d5,d5			;d5: bytes
		move.l	HFSFile,d1
		move.l	d0,d2
		lsl.l	#8,d2
		add.l	d2,d2
		moveq	#OFFSET_BEGINNING,d3
		JSRLIB	Seek
		addq.l	#1,d0			;-1: error (a position past 2 GB looks negative)
		beq	1$
		move.l	HFSFile,d1
		move.l	d4,d2
		move.l	d5,d3
		JSRLIB	Write
		cmp.l	d5,d0
		bne	1$
		moveq	#0,d0
		rts
1$		moveq	#-1,d0
		rts


**
** A device disk: a0 device name, d0 unit, d1 first sector, d2 sectors
** (0: the whole drive). Asks, formats, says what came of it.
**
FormatDevDisk	movem.l	d2-d7/a2-a6,-(sp)
		move.l	a0,a4			;a4: device name
		move.l	d0,d6			;d6: unit
		move.l	d1,HFSDevStart
		move.l	d2,d5			;d5: sectors
		clr.l	HFSPort
		clr.l	HFSReq
		clr.b	HFSDevOpen
		move.l	a4,FmtArgs
		move.l	d6,FmtArgs+4
		move.l	d1,FmtArgs+8

; A device name, not empty and not a partition's ("DH5:")
		move.l	#MSG_FMT_NAME_TXT,d7
		tst.b	(a4)
		beq	FDDTell
		move.l	a4,a0
1$		tst.b	(a0)+
		bne	1$
		cmp.b	#':',-2(a0)
		beq	FDDTell

; Open it
		move.l	#MSG_FMT_NODEV_TXT,d7
		move.l	_ExecBase,a6
		JSRLIB	CreateMsgPort
		move.l	d0,HFSPort
		beq	FDDTell
		move.l	d0,a0
		moveq	#IOTD_SIZE,d0
		JSRLIB	CreateIORequest
		move.l	d0,HFSReq
		beq	FDDTell
		move.l	a4,a0
		move.l	d6,d0
		move.l	HFSReq,a1
		moveq	#0,d1
		JSRLIB	OpenDevice
		tst.l	d0
		bne	FDDTell
		st.b	HFSDevOpen

; How large? Sectors of 512 bytes only
		move.l	#MSG_FMT_SIZE_TXT,d7
		move.l	HFSReq,a1
		move.w	#TD_GETGEOMETRY,IO_COMMAND(a1)
		move.l	#HFSGeo,IO_DATA(a1)
		move.l	#dg_SIZEOF,IO_LENGTH(a1)
		JSRLIB	DoIO
		tst.l	d0
		bne	2$			;(a device that cannot say: take the numbers)
		cmp.l	#512,HFSGeo+dg_SectorSize
		bne	FDDTell
		move.l	HFSGeo+dg_TotalSectors,d0
		sub.l	HFSDevStart,d0
		bls	FDDTell			;Starts behind the end
		tst.l	d5
		bne	3$
		move.l	d0,d5			;The whole drive
3$		cmp.l	d0,d5
		bhi	FDDTell			;Longer than the drive
2$		cmp.l	#HFSMINSEC,d5
		blo	FDDTell
		move.l	d5,d0
		add.l	HFSDevStart,d0
		bcs	FDDTell
		cmp.l	#HFSMAXSEC,d0		;All of it within the first 4 GB
		bhi	FDDTell

; The mounted Amiga partitions of this drive: which ones the range touches
; (they are switched off while it is written), and whether it lies inside one
		bsr	FDDParts
		move.l	_ExecBase,a6

; An Amiga partition table? All of the first 16 sectors are looked at (the
; partition blocks follow the RDSK block). With one, a range from the start
; of the drive is refused, and so is a range elsewhere that does not lie
; inside one mounted partition. From the start of the drive a sector that
; cannot be read stops it as well.
		moveq	#0,d3			;d3: a table was found
		moveq	#0,d4			;d4: sector
4$		move.l	HFSReq,a1
		move.w	#CMD_READ,IO_COMMAND(a1)
		move.l	#HFSSector,IO_DATA(a1)
		move.l	#512,IO_LENGTH(a1)
		move.l	d4,d0
		lsl.l	#8,d0
		add.l	d0,d0
		move.l	d0,IO_OFFSET(a1)
		JSRLIB	DoIO
		tst.l	d0
		beq	5$
		cmp.l	#16,HFSDevStart
		bhs	51$
		move.l	#MSG_FMT_NODEV_TXT,d7
		bra	FDDTell
5$		cmp.l	#'RDSK',HFSSector
		bne	51$
		moveq	#1,d3
51$		addq.l	#1,d4
		cmp.l	#16,d4
		blo	4$
		tst.l	d3
		beq	6$
		move.l	#MSG_FMT_RDB_TXT,d7
		cmp.l	#16,HFSDevStart
		blo	FDDTell
		move.l	#MSG_FMT_PART_TXT,d7
		tst.b	FDDInside
		beq	FDDTell
6$
; Ask
		move.l	d5,d0
		lsr.l	#8,d0
		lsr.l	#3,d0
		move.l	d0,FmtArgs+12		;MB
		move.l	#MSG_FMT_ASK_TXT,d0
		move.l	#MSG_FMT_ASK_GADS,d1
		lea	FmtArgs,a3
		jsr	SReq
		tst.l	d0
		beq	FDDClose

; Format. An Amiga file system on the range is switched off meanwhile: it
; would write its own blocks over the new Mac disk later. Switched on again
; it reads the disk anew and finds no Amiga disk there.
		moveq	#DOSTRUE,d2
		bsr	FDDInhibit
		move.l	d5,d0
		lea	HFSDefName,a0
		lea	HFSDevWrite,a1
		bsr	HFSFormat
		move.l	d0,d4
		move.l	_ExecBase,a6
		move.l	HFSReq,a1
		move.w	#CMD_UPDATE,IO_COMMAND(a1)
		JSRLIB	DoIO
		moveq	#DOSFALSE,d2
		bsr	FDDInhibit
		move.l	#MSG_FMT_SIZE_TXT,d7
		cmp.l	#1,d4
		beq	FDDTell
		move.l	#MSG_FMT_WRERR_TXT,d7
		tst.l	d4
		bne	FDDTell
		move.l	FmtArgs+12,FmtArgs	;(MB)
		move.l	#MSG_FMT_DONE_TXT,d7

FDDTell		move.l	d7,d0
		move.l	#MSG_REQGADSOK,d1
		lea	FmtArgs,a3
		jsr	SReq

FDDClose	move.l	_ExecBase,a6
		tst.b	HFSDevOpen
		beq	1$
		move.l	HFSReq,a1
		JSRLIB	CloseDevice
1$		move.l	HFSReq,d0
		beq	2$
		move.l	d0,a0
		JSRLIB	DeleteIORequest
2$		move.l	HFSPort,d0
		beq	3$
		move.l	d0,a0
		JSRLIB	DeleteMsgPort
3$		movem.l	(sp)+,d2-d7/a2-a6
		rts

**
** The DOS devices (mounted partitions) on device a4, unit d6 that the range
** HFSDevStart, d5 sectors touches: their names go to FDDInhNames (FDDInhCnt
** of them), and FDDInside says whether the range lies inside one of them.
**
FDDMAXINH	= 4

FDDParts	movem.l	d2-d7/a2-a6,-(sp)
		clr.b	FDDInside
		clr.w	FDDInhCnt
		move.l	HFSDevStart,d3		;d3: first sector
		move.l	d3,d4
		add.l	d5,d4			;d4: the sector behind the last
		move.l	_DOSBase,a6
		moveq	#LDF_DEVICES|LDF_READ,d1
		JSRLIB	LockDosList
		move.l	d0,d7			;d7: place in the list
1$		move.l	d7,d1
		moveq	#LDF_DEVICES|LDF_READ,d2
		JSRLIB	NextDosEntry
		move.l	d0,d7
		beq	9$
		move.l	d0,a3			;a3: device node
		move.l	dol_Startup(a3),d0
		cmp.l	#64,d0			;(nothing or a number: no partition)
		bls	1$
		move.l	d0,d1
		and.l	#$c0000000,d1
		bne	1$
		lsl.l	#2,d0
		move.l	d0,a0			;a0: FileSysStartupMsg
		cmp.l	fssm_Unit(a0),d6
		bne	1$
		move.l	fssm_Environ(a0),d0
		beq	1$
		lsl.l	#2,d0
		move.l	d0,a2			;a2: DosEnvec
		move.l	fssm_Device(a0),d0
		beq	1$
		lsl.l	#2,d0
		move.l	d0,a0			;a0: its device name (BSTR)
		moveq	#0,d0
		move.b	(a0)+,d0
		move.l	a4,a1
2$		subq.w	#1,d0
		bmi	3$
		move.b	(a0)+,d1
		beq	3$
		move.b	(a1)+,d2
		beq	1$
		eor.b	d1,d2			;(upper and lower case are the same)
		and.b	#$df,d2
		beq	2$
		bra	1$
3$		tst.b	(a1)
		bne	1$

		move.l	de_BlocksPerTrack(a2),d0
		mulu.l	de_Surfaces(a2),d0
		move.l	de_SizeBlock(a2),d1
		lsr.l	#7,d1
		mulu.l	d1,d0			;512-byte sectors in a cylinder
		move.l	d0,d1
		mulu.l	de_LowCyl(a2),d0	;d0: its first sector
		move.l	de_HighCyl(a2),d2
		addq.l	#1,d2
		mulu.l	d2,d1			;d1: the sector behind its last
		cmp.l	d1,d3
		bhs	1$			;The range starts behind it
		cmp.l	d0,d4
		bls	1$			; or ends in front of it
		cmp.l	d0,d3
		blo	4$
		cmp.l	d1,d4
		bhi	4$
		st.b	FDDInside
4$		move.w	FDDInhCnt,d0
		cmp.w	#FDDMAXINH,d0
		bhs	1$
		addq.w	#1,FDDInhCnt
		lsl.w	#5,d0
		lea	FDDInhNames,a1
		add.w	d0,a1
		move.l	dol_Name(a3),d0
		lsl.l	#2,d0
		move.l	d0,a0
		moveq	#0,d0
		move.b	(a0)+,d0
		cmp.w	#30,d0
		bls	5$
		moveq	#30,d0
5$		subq.w	#1,d0
		bmi	6$
		move.b	(a0)+,(a1)+
		bra	5$
6$		move.b	#':',(a1)+
		clr.b	(a1)
		bra	1$
9$		moveq	#LDF_DEVICES|LDF_READ,d1
		JSRLIB	UnLockDosList
		movem.l	(sp)+,d2-d7/a2-a6
		rts

; Switch the file systems found by FDDParts off (d2 = DOSTRUE) or on again
FDDInhibit	movem.l	d2-d3/a2/a6,-(sp)
		move.l	_DOSBase,a6
		move.w	FDDInhCnt,d3
		lea	FDDInhNames,a2
1$		subq.w	#1,d3
		bmi	2$
		move.l	a2,d1
		JSRLIB	Inhibit
		lea	32(a2),a2
		bra	1$
2$		movem.l	(sp)+,d2-d3/a2/a6
		rts

**
** How many 512-byte sectors has device a0, unit d0? 0: cannot tell
** (not there, no geometry, other sector size).
**
DevTotalSectors	movem.l	d2-d7/a2-a6,-(sp)
		move.l	a0,a4
		move.l	d0,d6
		moveq	#0,d7			;d7: the answer
		moveq	#0,d4			;d4: port
		moveq	#0,d5			;d5: request
		tst.b	(a4)
		beq	9$
		move.l	_ExecBase,a6
		JSRLIB	CreateMsgPort
		move.l	d0,d4
		beq	9$
		move.l	d0,a0
		moveq	#IOTD_SIZE,d0
		JSRLIB	CreateIORequest
		move.l	d0,d5
		beq	8$
		move.l	a4,a0
		move.l	d6,d0
		move.l	d5,a1
		moveq	#0,d1
		JSRLIB	OpenDevice
		tst.l	d0
		bne	7$
		move.l	d5,a1
		move.w	#TD_GETGEOMETRY,IO_COMMAND(a1)
		move.l	#HFSGeo,IO_DATA(a1)
		move.l	#dg_SIZEOF,IO_LENGTH(a1)
		JSRLIB	DoIO
		tst.l	d0
		bne	6$
		cmp.l	#512,HFSGeo+dg_SectorSize
		bne	6$
		move.l	HFSGeo+dg_TotalSectors,d7
6$		move.l	d5,a1
		JSRLIB	CloseDevice
7$		move.l	d5,a0
		JSRLIB	DeleteIORequest
8$		move.l	d4,a0
		JSRLIB	DeleteMsgPort
9$		move.l	d7,d0
		movem.l	(sp)+,d2-d7/a2-a6
		rts

HFSDevWrite	move.l	_ExecBase,a6
		move.l	HFSReq,a1
		move.w	#CMD_WRITE,IO_COMMAND(a1)
		move.l	a0,IO_DATA(a1)
		lsl.l	#8,d1
		add.l	d1,d1
		move.l	d1,IO_LENGTH(a1)
		add.l	HFSDevStart,d0
		lsl.l	#8,d0
		add.l	d0,d0
		move.l	d0,IO_OFFSET(a1)
		JSRLIB	DoIO
		rts


		SECTION	"DATA",DATA

HFSDefName	dc.b	"Untitled",0
		EVEN

		SECTION	"BSS",BSS

HFSTotal	ds.l	1		;Sectors
HFSWrite	ds.l	1		;Write routine
HFSSpb		ds.l	1		;Sectors per allocation block
HFSBm		ds.l	1		;Sectors of the bitmap
HFSAlSt		ds.l	1		;Sector of the first allocation block
HFSNBlk		ds.l	1		;Allocation blocks
HFSAbSz		ds.l	1		;Allocation block, bytes
HFSBtBlk	ds.l	1		;A B-tree file: blocks,
HFSBt		ds.l	1		; bytes,
HFSNodes	ds.l	1		; nodes
HFSNow		ds.l	1		;Mac time
HFSBuf		ds.l	1
HFSFile		ds.l	1
HFSPort		ds.l	1
HFSReq		ds.l	1
HFSDevStart	ds.l	1
FmtArgs		ds.l	4
HFSStamp	ds.b	ds_SIZEOF
HFSGeo		ds.b	dg_SIZEOF
HFSSector	ds.b	512
HFSName		ds.b	28		;Pascal string
HFSDevOpen	ds.b	1
FDDInside	ds.b	1
FDDInhCnt	ds.w	1
FDDInhNames	ds.b	FDDMAXINH*32

		END
