	IFND	SHAPE_SUPPORT_I
SHAPE_SUPPORT_I	SET	1

*
* ShapeShifter Macintosh Emulator - Support for Amiga applications
*
* $VER: shapesupport.i 1.0 (16.11.94)
*
* (C) Copyright 1994 Christian Bauer
*

	IFND	EXEC_SEMAPHORES_I
	INCLUDE	"exec/semaphores.i"
	ENDC


*
* ShapeShifter offers Amiga applications the possibility to call
* Macintosh system functions while the emulation is running.
*
* The interface used is the ShapeShifter semaphore.
* It contains a pointer to a function that is used to install Macintosh
* routines. These routines are executed asynchonously by the emulator
* and can call all Macintosh operating system functions. They run in
* supervisor mode, so multitaksing will be switched off during execution.
*
* Usage:
* - Call FindSemaphore() to find the ShapeShifter semaphore and access
*   it via ObtainSemaphore()
* - Check the Flag ss_MacRunning in the semaphore to determine whether
*   the emulation is running
* - Create a MacProc structure and initialize mp_Proc with a pointer
*   to your Macintosh routine. The value in mp_Param will be passed
*   to this routine in a1 on execution
* - Call the function ss_ExecMacProc with a pointer to the MacProc
*   structure in a0
* - Wait for termination of the Macintosh routine. The safest way is
*   to have the routine Signal() your main task
* - Release the semaphore with ReleaseSemaphore()
*
* Notes:
* - The semaphore should only be obtained for one routine at a time
* - For every concurrently installed routine you have to use an own
*   MacProc structure. You cannot install one routine, change mp_Proc
*   and install a second routine before the first one has finished
* - The remaining fields of the MacProc structure are for internal
*   purposes and must not be changed
* - The Macintosh routine must preserve all registers except d0-d1/a0-a1
* - ss_ExecMacProc will likewise preserve all registers except a0-a1/d0-d1
*


*
* Name of the ShapeShifter semaphore
*

SHAPESEMANAME	MACRO
		dc.b	"ShapeShifter Semaphore",0
		ENDM


*
* Semaphore structure (signal semaphore extension)
*

 STRUCTURE SHAPESEMA,SS_SIZE
	APTR	ss_ExecMacProc	;Function for installing Mac routines
				;a0: Pointer to MacProc structure
	WORD	ss_MacRunning	;#0: The emulator is in Mac mode
 LABEL ShapeSema_SIZEOF


*
* MacProc structure for defining Macintosh routines
*

 STRUCTURE MACPROC,0
	LONG	mp_priv0
	LONG	mp_priv1
	APTR	mp_Proc		;Pointer to Mac routine to be called
	LONG	mp_Param	;Parameter (will be loaded to a1)
	LONG	mp_priv2
 LABEL macproc_SIZEOF

	ENDC	;SHAPE_SUPPORT_I
