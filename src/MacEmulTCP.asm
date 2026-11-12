**
** Macintosh IIci-Emulator - MacTCP-Emulation über AmiTCP
** ======================================================
**
** © Copyright 1996-2001 Christian Bauer
**

DEBUG_DETAIL	SET 0

		INCLUDE	"exec/types.i"
		INCLUDE	"exec/macros.i"
		INCLUDE	"exec/memory.i"
		INCLUDE	"macros.i"
		INCLUDE	"macinclude.i"

		XDEF	OpenTCP
		XDEF	CloseTCP
		XDEF	InstallIPP
		XDEF	DNREntry

		XDEF	TCPSig
		XDEF	TCPExcept

		SECTION	"CODE",CODE


**
** Definitionen
**

IPPRefNum	= -54		;Nummer des IPP-Treibers

; Struktur für einen UDP/TCP-Stream
 STRUCTURE	Stream,0
	LONG	strSocket	;AmiTCP Socket-Deskriptor
	APTR	strIOParam	;Zeiger auf IOParam-Block
	APTR	strBuf		;Zeiger auf Puffer
	LONG	strBufLen	;Länge des Puffers
	APTR	strNotifyProc	;Zeiger auf ASR
	APTR	strUserData	;Daten für ASR

	LABEL	strSockAddr	;Socket address
	UBYTE	strSinLen
	UBYTE	strSinFamily
	UWORD	strSinPort
	LONG	strSinAddr
	LONG	strSinZero0
	LONG	strSinZero1
 LABEL	Stream_SIZEOF

; MacTCP errors
ipBadLapErr		= -23000 ;bad network configuration
ipBadCnfgErr		= -23001 ;bad IP configuration error
ipNoCnfgErr		= -23002 ;missing IP or LAP configuration error
ipLoadErr		= -23003 ;error in MacTCP load
ipBadAddr		= -23004 ;error in getting address
connectionClosing	= -23005 ;connection is closing
invalidLength		= -23006
connectionExists	= -23007 ;request conflicts with existing connection
connectionDoesntExist	= -23008 ;connection does not exist
insufficientResources	= -23009 ;insufficient resources to perform request
invalidStreamPtr	= -23010
streamAlreadyOpen	= -23011
connectionTerminated	= -23012
invalidBufPtr		= -23013
invalidRDS		= -23014
invalidWDS		= -23014
openFailed		= -23015
commandTimeout		= -23016
duplicateSocket		= -23017
ipDontFragErr		= -23032 ;Packet too large to send w/o fragmenting
ipDestDeadErr		= -23033 ;destination not responding
icmpEchoTimeoutErr	= -23035 ;ICMP echo timed-out
ipNoFragMemErr		= -23036 ;no memory to send fragmented pkt
ipRouteErr		= -23037 ;can't route packet off-net
nameSyntaxErr		= -23041
cacheFault		= -23042
noResultProc		= -23043
noNameServer		= -23044
authNameErr		= -23045
noAnsErr		= -23046
dnrErr			= -23047
outOfMemory		= -23048

; bsdsocket.library
_LVOsocket		= -30
_LVOconnect		= -54
_LVOshutdown		= -84
_LVOsetsockopt		= -90
_LVOIoctlSocket		= -114
_LVOCloseSocket		= -120
_LVOErrno		= -162
_LVOInet_ntoa		= -174
_LVOInet_addr		= -180
_LVOgethostbyname	= -210
_LVOgethostbyaddr	= -216
_LVOgethostid		= -288
_LVOSocketBaseTagList	= -294
_LVOGetSocketEvents	= -300

AF_INET		= 2	;Address family: Internetwork

SOCK_STREAM	= 1	;stream socket
SOCK_DGRAM	= 2	;datagram socket
SOCK_RAW	= 3	;raw-protocol interface

IPPROTO_IP	= 0	;dummy for IP
IPPROTO_ICMP	= 1	;control message protocol
IPPROTO_TCP	= 6	;tcp
IPPROTO_UDP	= 17	;user datagram protocol

; Ioctl()
FIONBIO		= $8004667e	;non-blocking i/o
FIOASYNC	= $8004667d	;async i/o

; setsockopt()
SOL_SOCKET	= $ffff		;options for socket level

SO_DEBUG	= $0001		;turn on debugging info recording
SO_ACCEPTCONN	= $0002		;socket has had listen()
SO_REUSEADDR	= $0004		;allow local address reuse
SO_KEEPALIVE	= $0008		;keep connections alive
SO_DONTROUTE	= $0010		;just use interface addresses
SO_BROADCAST	= $0020		;permit sending of broadcast msgs
SO_USELOOPBACK	= $0040		;bypass hardware when possible
SO_LINGER	= $0080		;linger on close if data present
SO_OOBINLINE	= $0100		;leave received OOB data in line
SO_SNDBUF	= $1001		;send buffer size
SO_RCVBUF	= $1002		;receive buffer size
SO_SNDLOWAT	= $1003		;send low-water mark
SO_RCVLOWAT	= $1004		;receive low-water mark
SO_SNDTIMEO	= $1005		;send timeout
SO_RCVTIMEO	= $1006		;receive timeout
SO_ERROR	= $1007		;get error status and clear
SO_TYPE		= $1008		;get socket type
SO_EVENTMASK	= $2001		;socket event mask,    

IP_OPTIONS	= 1		;buf/ip_opts; set/get IP per-packet options
IP_HDRINCL	= 2		;int; header is included with data (raw)
IP_TOS		= 3		;int; IP type of service and precedence
IP_TTL		= 4		;int; IP time to live
IP_RECVOPTS	= 5		;bool; receive all IP options w/datagram
IP_RECVRETOPTS	= 6		;bool; receive IP options for response
IP_RECVDSTADDR	= 7		;bool; receive IP dst addr w/datagram
IP_RETOPTS	= 8		;ip_opts; set/get IP per-packet options

; TCP/IP-Fehlercodes
EINPROGRESS	= 36	;Operation now in progress
EALREADY	= 37	;Operation already in progress
ENOTSOCK	= 38	;Socket operation on non-socket
EDESTADDRREQ	= 39	;Destination address required
EMSGSIZE	= 40	;Message too long
EPROTOTYPE	= 41	;Protocol wrong type for socket
ENOPROTOOPT	= 42	;Protocol not available
EPROTONOSUPPORT	= 43	;Protocol not supported
ESOCKTNOSUPPORT	= 44	;Socket type not supported
EOPNOTSUPP	= 45	;Operation not supported on socket
EPFNOSUPPORT	= 46	;Protocol family not supported
EAFNOSUPPORT	= 47	;Address family not supported by protocol family
EADDRINUSE	= 48	;Address already in use
EADDRNOTAVAIL	= 49	;Can't assign requested address
ENETDOWN	= 50	;Network is down
ENETUNREACH	= 51	;Network is unreachable
ENETRESET	= 52	;Network dropped connection on reset
ECONNABORTED	= 53	;Software caused connection abort
ECONNRESET	= 54	;Connection reset by peer
ENOBUFS		= 55	;No buffer space available
EISCONN		= 56	;Socket is already connected
ENOTCONN	= 57	;Socket is not connected
ESHUTDOWN	= 58	;Can't send after socket shutdown
ETOOMANYREFS	= 59	;Too many references: can't splice
ETIMEDOUT	= 60	;Connection timed out
ECONNREFUSED	= 61	;Connection refused
ELOOP		= 62	;Too many levels of symbolic links
EHOSTDOWN	= 64	;Host is down
EHOSTUNREACH	= 65	;No route to host

; DNR-Fehlercodes
HOST_NOT_FOUND	= 1	;Authoritative Answer Host not found
TRY_AGAIN	= 2	;Non-Authoritive Host not found, or SERVERFAIL
NO_RECOVERY	= 3	;Non recoverable errors, FORMERR, REFUSED, NOTIMP
NO_DATA		= 4	;Valid name, no data record of requested type


*
* Initialisierung
*

; Signal einrichten
OpenTCP		tst.l	_SocketBase
		beq	1$

		move.l	_ExecBase,a6
		moveq	#-1,d0
		JSRLIB	AllocSignal
		move.b	d0,TCPSig
		moveq	#0,d1
		bset	d0,d1
		move.l	d1,TCPSet
		move.l	d1,d0
		JSRLIB	SetExcept

		move.l	_SocketBase,a6
		lea	SocketTags,a0
		move.l	TCPSet,4(a0)
		jsr	_LVOSocketBaseTagList(a6)
1$		rts


*
* Beenden (muß auch dann funktionieren, wenn OpenTCP nicht aufgerufen wurde!)
*

CloseTCP	move.l	_ExecBase,a6
		moveq	#0,d0
		move.l	TCPSet,d1
		beq	1$
		JSRLIB	SetExcept
		move.b	TCPSig,d0	
		JSRLIB	FreeSignal
1$		rts


*
* Installation des Treibers
*

; Treiber installieren
InstallIPP	tst.l	_SocketBase
		beq	1$

		move.l	a0,-(sp)
		lea	IPPHeader,a0
		moveq	#IPPRefNum,d0
		dc.w	$a43d		;DrvrInstallRsrvMem

; Zeiger auf Treiber holen
		move.l	$11c,a0		;UTableBase
		move.l	-(IPPRefNum+1)*4(a0),a0
		move.l	(a0),a2
		dc.w	$a029		;HLock

; Daten kopieren
		lea	IPPHeader,a0
		move.l	a0,(a2)
		move.w	(a0),dCtlFlags(a2)

; Teiber noch nicht geöffnet
		clr.b	DriverOpen

; Gestalt installieren
		move.l	#'mtcp',d0
		lea	IPPGestalt,a0
		dc.w	$a3ad		;NewGestalt

		move.l	(sp)+,a0
1$		rts


**
** Header des Treibers
**

IPPHeader	dc.w	$5c00		;Flags
		dc.w	0,0,0		;Delay, EMask, Menu
		dc.w	IPPOpen-IPPHeader
		dc.w	IPPPrime-IPPHeader
		dc.w	IPPControl-IPPHeader
		dc.w	IPPStatus-IPPHeader
		dc.w	IPPClose-IPPHeader
IPPName		dc.b	4,".ipp"
		EVEN


*
* Open()-Routine
*

IPPOpen		DPRINTF	"Open"
		st.b	DriverOpen
		or.w	#$0001,dCtlFlags(a1)

		moveq	#0,d0
		rts

*
* Prime()-Routine
*

IPPPrime	DPRINTF	"Prime"
		moveq	#-19,d0
		move.l	JIODone,-(sp)
		rts


*
* Control()-Routine
*

IPPControl	movem.l	d1-d7/a0-a6,-(sp)
		move.l	_SocketBase,a6
		move.l	a0,a5			;a5: ioParmBlock
		moveq	#0,d0
		move.w	csCode(a0),d0
		DPRINTF	"Control %ld",d0

		cmp.w	#-1,d0
		beq	IPPShutdown
		cmp.w	#15,d0
		beq	IPCtlGetAddr
		sub.w	#20,d0
		bmi	ErrControlImpl
		cmp.w	#23,d0
		bhi	ErrControlImpl
		move.l	(CtrlJmp,d0.w*4),a0
		jmp	(a0)

		CNOP	0,4
CtrlJmp		dc.l	UDPCreate	;20
		dc.l	UDPRead		;21
		dc.l	UDPBfrReturn	;22
		dc.l	UDPWrite	;23
		dc.l	UDPRelease	;24
		dc.l	UDPMaxMTUSize	;25
		dc.l	UDPStatus	;26
		dc.l	UDPMultiCreate	;27
		dc.l	UDPMultiSend	;28
		dc.l	UDPMultiRead	;29
		dc.l	TCPCreate	;30
		dc.l	TCPPassiveOpen	;31
		dc.l	TCPActiveOpen	;32
		dc.l	ErrControlImpl	;33
		dc.l	TCPSend		;34
		dc.l	TCPNoCopyRcv	;35
		dc.l	TCPRcvBfrReturn	;36
		dc.l	TCPRcv		;37
		dc.l	TCPClose	;38
		dc.l	TCPAbort	;39
		dc.l	TCPStatus	;40
		dc.l	TCPExtendedStat	;41
		dc.l	TCPRelease	;42
		dc.l	TCPGlobalInfo	;43

ErrOpenFailed	move.l	#openFailed,d0
		bra	Return
ErrConnExists	move.l	#connectionExists,d0
		bra	Return
ErrConnDoesnt	move.l	#connectionDoesntExist,d0
		bra	Return
ErrDuplSocket	move.l	#duplicateSocket,d0
		bra	Return
ErrInvStream	move.l	#invalidStreamPtr,d0
		bra	Return
ErrInsuffRsrc	move.l	#insufficientResources,d0
		bra	Return
ErrControlImpl	moveq	#-17,d0
		bra	Return

ReturnOK	moveq	#0,d0

Return		movem.l	(sp)+,d1-d7/a0-a6

		btst	#noQueueBit-8,ioTrap(a0) ;Immediate call mit RTS beenden
		beq	Queued

NotQueued	tst.w	d0
		ble	ImmedRTS
		clr.w	d0		;Request noch nicht beendet
ImmedRTS	move.w	d0,ioResult(a0)
		rts

Queued		tst.w	d0
		ble	IODone
		clr.w	d0		;Request noch nicht beendet
		rts
IODone		jmp	([JIODone])


*
* Status()-Routine
*

IPPStatus	DPRINTF	"Status"
		moveq	#-18,d0
		move.l	JIODone,-(sp)
		rts


*
* Close()-Routine
*

IPPClose	DPRINTF	"Close"
		moveq	#-24,d0		;closeErr
		rts


*
* Gestalt-Routine
*

IPPGestalt	link	a6,#0
		move.l	8(a6),a0
		moveq	#0,d0
		tst.b	DriverOpen
		beq	1$
		moveq	#3,d0		;MacTCP 2.x
1$		move.l	d0,(a0)
		clr.w	16(a6)
		unlk	a6
		rtd	#8


*
* IPPShutdown - Shutting down
*

IPPShutdown	DPRINTF	"Shutdown"
		bra	ErrControlImpl


*
* IPCtlGetAddr - Get our own IP address
*

IPCtlGetAddr	DPRINTF	"IPCtlGetAddr"
		NJSRLIB	gethostid
		DPRINTF	" addr %08lx",d0
		move.l	d0,csParam(a5)
		move.l	#-1,csParam+4(a5)	;Pseudo-Netmask
		bra	ReturnOK


*
* UDPCreate - Open UDP stream
*

UDPCreate	DPRINTF	"UDPCreate"
		bra	ErrControlImpl


*
* UDPRead - Receive UDP datagram
*

UDPRead		DPRINTF	"UDPRead"
		bra	ErrControlImpl


*
* UDPBfrReturn - Return receive buffer to UDP driver
*

UDPBfrReturn	DPRINTF	"UDPBfrReturn"
		bra	ErrControlImpl


*
* UDPWrite - Send UDP datagram
*

UDPWrite	DPRINTF	"UDPWrite"
		bra	ErrControlImpl


*
* UDPRelease - Close UDP stream
*

UDPRelease	DPRINTF	"UDPRelease"
		bra	ErrControlImpl


*
* UDPMaxMTUSize - Return maximum UDP datagram size without fragmentation
*

UDPMaxMTUSize	DPRINTF	"UDPMaxMTUSize"
		move.w	#548,32(a5)
		bra	ReturnOK


*
* UDPStatus - Get statistics
*

UDPStatus	DPRINTF	"UDPStatus"
		bra	ErrControlImpl


*
* UDPMultiCreate - Open UDP connections on a consecutive series of ports
*

UDPMultiCreate	DPRINTF	"UDPMultiCreate"
		bra	ErrControlImpl


*
* UDPMultiSend - Send datagram from specified port
*

UDPMultiSend	DPRINTF	"UDPMultiSend"
		bra	ErrControlImpl


*
* UDPMultiRead - Receive data from port created with UDPMultiCreate
*

UDPMultiRead	DPRINTF	"UDPMultiRead"
		bra	ErrControlImpl


*
* TCPCreate - Open TCP stream
*

TCPCreate	DPRINTF	"TCPCreate"
		move.l	44(a5),strUserData(a4)

; Struktur für Stream erzeugen
		move.l	_ExecBase,a6
		moveq	#Stream_SIZEOF,d0
		move.l	#MEMF_CLEAR,d1
		EJSRLIB	AllocVec
		move.l	d0,a4		;a4: Stream

		move.l	32(a5),strBuf(a4)
		move.l	36(a5),strBufLen(a4)
		move.l	40(a5),strNotifyProc(a4)
		move.l	#-1,strSocket(a4)

; Alles OK, Zeiger auf Stream zurückgeben
		move.l	a4,28(a5)
		DPRINTF	" stream %08lx",a4
		bra	ReturnOK


*
* TCPPassiveOpen - Listen for an incoming connection
*

TCPPassiveOpen	DPRINTF	"TCPPassiveOpen"
		move.l	28(a5),a4	;a4: Stream
		bra	ErrControlImpl


*
* TCPActiveOpen - Initiate outgoing call to remote TCP
*

TCPActiveOpen	DPRINTF	"TCPActiveOpen ip %08lx, port %08lx, opts %08lx%08lx",36(a5),40(a5),48(a5),52(a5)
		move.l	28(a5),a4	;a4: Stream
		move.l	94(a5),strUserData(a4)

; Stream bereits geöffnet?
		cmp.l	#-1,strSocket(a4)
		bne	ErrConnExists

; Socket erzeugen
		moveq	#AF_INET,d0
		moveq	#SOCK_STREAM,d1
		moveq	#IPPROTO_TCP,d2
		NJSRLIB	socket
		cmp.l	#-1,d0
		beq	ErrInsuffRsrc
		move.l	d0,strSocket(a4)

	;!!	move.l	#FIONBIO,d1	;Auf non-blocking setzen
	;	lea	Long1,a0
	;	NJSRLIB	IoctlSocket
	;	DPRINTF	" ioctrl returns %ld",d0

; Optionen setzen
		move.b	34(a5),d0	;Precedence/TOS gültig?
		and.b	#$30,d0
		beq	1$
		moveq	#0,d0
		move.b	48(a5),d0	;TOS
		lsl.b	#2,d0
		moveq	#0,d1
		move.b	49(a5),d1	;Precedence
		move.b	(PrecTab,d1.l),d1
		or.b	d1,d0
		DPRINTF	" tos/prec %08lx",d0
		move.l	d0,-(sp)
		move.l	strSocket(a4),d0
		moveq	#IPPROTO_IP,d1
		moveq	#IP_TTL,d2
		move.l	sp,a0
		moveq	#4,d3
		NJSRLIB	setsockopt
		DPRINTF	"  returns %ld",d0
		addq.l	#4,sp
1$
		moveq	#0,d0		;TTL
		move.b	51(a5),d0
		beq	2$
		DPRINTF	" ttl %ld",d0
		move.l	d0,-(sp)
		move.l	strSocket(a4),d0
		moveq	#IPPROTO_IP,d1
		moveq	#IP_TTL,d2
		move.l	sp,a0
		moveq	#4,d3
		NJSRLIB	setsockopt
		DPRINTF	"  returns %ld",d0
		addq.l	#4,sp
2$

; Gelungen, Verbindung aufbauen
		move.l	36(a5),strSinAddr(a4)
		move.w	40(a5),strSinPort(a4)
		move.b	#AF_INET,strSinFamily(a4)

		move.l	strSocket(a4),d0
		lea	strSockAddr(a4),a0
		moveq	#16,d1
		NJSRLIB	connect
		tst.l	d0
		beq	ReturnOK

; Fehler aufgetreten, Socket schließen
		NJSRLIB	Errno

		move.l	d0,-(sp)
		move.l	strSocket(a4),d0
		NJSRLIB	CloseSocket
		move.l	#-1,strSocket(a4)
		move.l	(sp)+,d0

		cmp.l	#EADDRINUSE,d0
		beq	ErrDuplSocket
		bra	ErrOpenFailed


*
* TCPSend - Send data on connection
*

TCPSend		DPRINTF	"TCPSend"
		move.l	28(a5),a4	;a4: Stream
		bra	ErrControlImpl


*
* TCPNoCopyRcv - Retrieve data received on connection
*

TCPNoCopyRcv	DPRINTF	"TCPNoCopyRcv"
		move.l	28(a5),a4	;a4: Stream
		bra	ErrControlImpl


*
* TCPRcvBfrReturn - Return receive buffers to TCP driver
*

TCPRcvBfrReturn	DPRINTF	"TCPRcvBfrReturn"
		move.l	28(a5),a4	;a4: Stream
		bra	ErrControlImpl


*
* TCPRcv - Retrieve data received on connection
*

TCPRcv		DPRINTF	"TCPRcv"
		move.l	28(a5),a4	;a4: Stream
		bra	ErrControlImpl


*
* TCPClose - Signal that the user has no more data to send on connection
*

TCPClose	DPRINTF	"TCPClose %08lx",28(a5)
		move.l	28(a5),a4	;a4: Stream
		move.l	36(a5),strUserData(a4)

; Socket schließen
		move.l	strSocket(a4),d0
		moveq	#-1,d1
		move.l	d1,strSocket(a4)
		cmp.l	d1,d0
		beq	ErrConnDoesnt
		NJSRLIB	CloseSocket
		tst.l	d0
		beq	ReturnOK
		bra	ErrConnDoesnt


*
* TCPAbort - Terminate connection
*

TCPAbort	DPRINTF	"TCPAbort %08lx",28(a5)
		move.l	28(a5),a4	;a4: Stream
		move.l	32(a5),strUserData(a4)

; Verbindung abbrechen
		move.l	strSocket(a4),d0
		cmp.l	#-1,d0
		beq	ErrConnDoesnt
		moveq	#2,d1		;Senden und Empfangen abbrechen
		NJSRLIB	shutdown

; Socket schließen
		move.l	strSocket(a4),d0
		move.l	#-1,strSocket(a4)
		NJSRLIB	CloseSocket
		tst.l	d0
		beq	ReturnOK
		bra	ErrConnDoesnt


*
* TCPStatus - Get information on connection
*

TCPStatus	DPRINTF	"TCPStatus %08lx",28(a5)
		move.l	28(a5),a4	;a4: Stream
		move.l	98(a5),strUserData(a4)
;	bra	ErrControlImpl	;!!

		clr.b	32(a5)		;ULP timeout value
		clr.b	33(a5)		;ULP timeout action

		clr.l	38(a5)		;Remote IP address
		clr.w	42(a5)		;Remote TCP port
		clr.l	44(a5)		;Local IP address
		clr.w	46(a5)		;Local TCP port

		clr.b	50(a5)		;TOS
		clr.b	51(a5)		;Precedence

		clr.b	52(a5)		;TCP connection state
		cmp.l	#-1,strSocket(a4)
		beq	1$
		move.b	#8,52(a5)	; connection established
1$
		clr.w	54(a5)		;Send window
		clr.w	56(a5)		;Receive window
		clr.w	58(a5)		;Amount of unacknowledged data
		clr.w	60(a5)		;Amount of unread data

		clr.l	62(a5)		;Security option pointer
		clr.l	66(a5)		;Send unacknowledged
		clr.l	70(a5)		;Send next
		clr.l	74(a5)		;Congestion window
		clr.l	78(a5)		;Receive next

		clr.l	82(a5)		;Smoothed round-trip time in milliseconds
		clr.l	86(a5)		;Last round-trip time in milliseconds
		clr.l	90(a5)		;Maximum segment size that can be sent
		clr.l	94(a5)		;Pointer to statistics block
		bra	ReturnOK


*
* TCPExtendedStat - Get extended information on connection
*

TCPExtendedStat	DPRINTF	"TCPExtendedStat"
		move.l	28(a5),a4	;a4: Stream
		bra	ErrControlImpl


*
* TCPRelease - Close TCP stream
*

TCPRelease	DPRINTF	"TCPRelease %08lx",28(a5)
		move.l	28(a5),a4	;a4: Stream
		move.l	40(a5),strUserData(a4)

		move.l	strBuf(a4),32(a5)
		move.l	strBufLen(a4),36(a5)

		move.l	_ExecBase,a6
		move.l	a4,a1
		JSRLIB	FreeVec
		bra	ReturnOK


*
* TCPGlobalInfo - Access global statistics
*

TCPGlobalInfo	DPRINTF	"TCPGlobalInfo"
		move.l	28(a5),a4	;a4: Stream
		bra	ErrControlImpl


**
** Domain Name Resolver
**

DNREntry	link	a5,#0
		movem.l	d1-d7/a0-a4/a6,-(sp)
		move.l	_SocketBase,a6
		move.l	8(a5),d0
		DPRINTF	"DNREntry %ld",d0
		cmp.l	#8,d0
		bhs	DNRImpl
		move.l	(DNRJmp,d0.l*4),a0
		jmp	(a0)

		CNOP	0,4
DNRJmp		dc.l	DNRImpl		;0
		dc.l	OpenResolver	;1
		dc.l	CloseResolver	;2
		dc.l	StrToAddr	;3
		dc.l	AddrToStr	;4
		dc.l	EnumCache	;5
		dc.l	AddrToName	;6
		dc.l	HInfo		;7
		dc.l	MXInfo		;8

DNRImpl		moveq	#-1,d0
		bra	DNRReturn
DNRReturnOK	moveq	#0,d0
DNRReturn	movem.l	(sp)+,d1-d7/a0-a4/a6
		unlk	a5
		rts


*
* OpenResolver
*

OpenResolver	DPRINTF	"OpenResolver"
		bra	DNRReturnOK


*
* CloseResolver
*

CloseResolver	DPRINTF	"CloseResolver"
		bra	DNRReturnOK


*
* StrToAddr - Convert host name to IP address
*

StrToAddr	DPRINTF	"StrToAddr %s",12(a5)
		move.l	16(a5),a4	;a4: hostInfo
		move.l	#dnrErr,(a4)	;Vorgabe

; Zuerst als a.b.c.d probieren		
		move.l	12(a5),a0
		NJSRLIB	Inet_addr
		cmp.l	#-1,d0
		beq	STANotDotted

; Gelungen, Adresse eintragen
		clr.l	(a4)		;Alles OK

		clr.b	4(a4)		;Name löschen

		move.l	d0,260(a4)
		clr.l	264(a4)
		clr.l	268(a4)
		clr.l	272(a4)
		bra	DNRReturnOK

; Nicht gelungen, nach dem Namen suchen
STANotDotted	move.l	12(a5),a0
		NJSRLIB	gethostbyname
		tst.l	d0
		beq	STAError
		move.l	d0,a3		;a3: hostent

STAFound	clr.l	(a4)		;Alles OK

		move.l	(a3),a0		;CName des Hosts kopieren
		lea	4(a4),a1
		move.w	#255,d0
1$		move.b	(a0)+,(a1)+
		dbeq	d0,1$

		clr.l	260(a4)		;Adressen löschen
		clr.l	264(a4)
		clr.l	268(a4)
		clr.l	272(a4)

		move.l	16(a3),a0	;Benutzte Adressen kopieren
		lea	260(a4),a1
		moveq	#3,d0
2$		move.l	(a0)+,d1
		beq	3$
		move.l	d1,a2
		move.l	(a2),(a1)+
		DPRINTF	" addr %08lx",(a2)
		dbra	d0,2$
3$		bra	DNRReturnOK

; Fehler aufgetreten, Fehlercode setzen
STAError	bsr	GetHerrno
		bsr	ConvertHerrno
		move.l	d0,(a4)
		bra	DNRReturnOK


*
* AddrToStr - Convert IP address to ASCII string
*

AddrToStr	DPRINTF	"AddrToStr %08lx",12(a5)
		move.l	12(a5),d0	;IP->String umwandeln
		NJSRLIB	Inet_ntoa

		move.l	d0,a0		;String kopieren
		move.l	16(a5),a1
		moveq	#16,d0
1$		move.b	(a0)+,(a1)+
		dbeq	d0,1$
		bra	DNRReturnOK


*
* EnumCache
*

EnumCache	DPRINTF	"EnumCache"
		bra	DNRImpl


*
* AddrToName - Convert IP address to host name
*

AddrToName	DPRINTF	"AddrToName %08lx",12(a5)
		move.l	16(a5),a4	;a4: hostInfo
		move.l	#dnrErr,(a4)	;Vorgabe

; Name suchen
		lea	12(a5),a0
		moveq	#4,d0
		moveq	#AF_INET,d1
		NJSRLIB	gethostbyaddr
		tst.l	d0
		beq	STAError
		move.l	d0,a3		;a3: hostent
		bra	STAFound


*
* HInfo
*

HInfo		DPRINTF	"HInfo"
		bra	DNRImpl


*
* MXInfo
*

MXInfo		DPRINTF	"MXInfo"
		bra	DNRImpl


**
** Exception
**

TCPExcept	move.l	_SocketBase,a6
		clr.l	-(sp)
		move.l	sp,a0
		jsr	_LVOGetSocketEvents(a6)
		move.l	(sp)+,d1
		DPRINTF	"TCPExcept fd %08lx, event %08lx",d0,d1
		rts


*
* Fehlercode des DNR holen (->d0)
*

GetHerrno	movem.l	d1/a0-a1/a6,-(sp)
		move.l	_SocketBase,a6
		lea	GetHerrnoTags,a0
		NJSRLIB	SocketBaseTagList
		move.l	GetHerrnoTags+4,d0
		DPRINTF	" herrno %ld",d0
		movem.l	(sp)+,d1/a0-a1/a6
		rts


*
* AmiTCP-herrno in MacTCP-DNR-Fehlercode umwandeln (d0->d0)
*

ConvertHerrno	cmp.l	#HOST_NOT_FOUND,d0
		bne	1$
		move.l	#authNameErr,d0
		rts
1$		cmp.l	#TRY_AGAIN,d0
		bne	2$
		move.l	#noAnsErr,d0
		rts
2$		cmp.l	#NO_RECOVERY,d0
		bne	3$
		move.l	#noAnsErr,d0
		rts
3$		cmp.l	#NO_DATA,d0
		bne	4$
		move.l	#dnrErr,d0
		rts
4$		move.l	#dnrErr,d0
		rts


**
** Konstanten
**

Long0		dc.l	0
Long1		dc.l	1

; Tabelle der IP-Precedences
PrecTab		dc.b	$10	;Routine
		dc.b	$20	;Priority
		dc.b	$40	;Immediate
		dc.b	$60	;Flash
		dc.b	$80	;Flash Override
		dc.b	$a0	;CRITIC/ECP
		dc.b	$c0	;Internet Control
		dc.b	$e0	;Net Control


**
** Initialisierte Daten
**

		SECTION	"DATA",DATA

SocketTags	dc.l	$80000009,0	;SBTC_SIGEVENTMASK
		dc.l	0,0

GetHerrnoTags	dc.l	$8000000E,0	;STBC_HERRNO
		dc.l	0,0


**
** Nicht initialisierte Daten
**

		SECTION	"BSS",BSS

TCPSet		ds.l	1		;Signal für Socket-Events
TCPSig		ds.b	1

DriverOpen	ds.b	1		;#0: IPP-Treiber geöffnet

		END
