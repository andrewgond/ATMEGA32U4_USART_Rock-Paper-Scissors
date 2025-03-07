
;***********************************************************
;*
;*	This is the TRANSMIT skeleton file for Lab 7 of ECE 375
;*
;*  	Rock Paper Scissors
;* 	Requirement:
;* 	1. USART1 communication
;* 	2. Timer/counter1 Normal mode to create a 1.5-sec delay
;***********************************************************
;*
;*	 Author: Andrew Gondoputro
;*	   Date: 3-05-202
;*
;***********************************************************

.include "m32U4def.inc"         ; Include definition file

;***********************************************************
;*  Internal Register Definitions and Constants
;***********************************************************
.def    mpr = r16               ; Multi-Purpose Register
.def	stat = r17
.def	choice = r18

.def	waitcnt = r17				; Wait Loop Counter
.def	ilcnt = r18				; Inner Loop Counter
.def	olcnt = r19				; Outer Loop Counter

.equ	But7 = 7				; Right Whisker Input Bit
.equ	But2 = 4				; Left Whisker Input Bit
.equ	WTime = 150				; Time to wait in wait loop
.def	i = r25

.equ	Rock = 1
.equ	Paper = 2
.equ	Scissors = 3

; Use this signal code between two boards for their game ready
.equ    SendReady = 0b11111111



;***********************************************************
;*  Macros
;***********************************************************


;-----------------------------------------------------------
; Func: Word to MEM (Word, Loc, Size)
; Desc: 
;-----------------------------------------------------------
.MACRO	WORD_TO_MEM
    ; Initialize Z register to point to STRING_BEG
	push    ZL
    push    ZH
    push    XH
    push    XL
    push    r16
    push    r17  ; Used as loop counter	
	

    ldi     ZL, low(@0 << 1)      ; Load low byte of address into ZL
    ldi     ZH, high(@0 << 1)     ; Load high byte of address into ZH
    ldi		XH, high(@1)		; Inital Value of X
	ldi		XL, low(@1)		; inital Value of X

	ldi		r17, @2		; Starting i for a loop counter


WRD_LOOP:
    ; Load the character from flash into the register
    lpm     r15, Z+                     ; Load byte from address in Z to a GPR (FLASH-->GPR). Then increment Z to next Flash address
	st		X+, r15						; Load GPR value to SRAM location (GPR-->SRAM). Then increment X to the next SRAM location
	dec		r17							; Decrement the loop counter
	brne	WRD_LOOP					; Continue the loop so long as i is positive
	
	pop     r17
    pop     r15
    pop     XL
    pop     XH
    pop     ZH
	pop		ZL

.ENDMACRO





;***********************************************************
;*  Start of Code Segment
;***********************************************************
.cseg                           ; Beginning of code segment

;***********************************************************
;*  Interrupt Vectors
;***********************************************************
.org    $0000                   ; Beginning of IVs
	    rjmp    INIT            	; Reset interrupt
		

.org    $0056                   ; End of Interrupt Vectors

;***********************************************************
;*  Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
	ldi		mpr, low(RAMEND)  ; Load low byte of RAMEND into 'mpr'
	out		SPL, mpr  ; Store low byte of RAMEND into SPL (stack pointer low byte)
	ldi		mpr, high(RAMEND)  ; Load high byte of RAMEND into 'mpr'
	out		SPH, mpr  ; Store high byte of RAMEND into SPH (stack pointer high byte)
	;I/O Ports

	; Initialize Port B for Output
	ldi		mpr, $FF		; Set Port B Data Direction Register
	out		DDRB, mpr		; for output
	ldi		mpr, $00		; Initialize Port B Data Register
	out		PORTB, mpr		; so all Port B outputs are low

	; Initialize Port D for input
	ldi		mpr, $00		; Set Port D Data Direction Register
	out		DDRD, mpr		; for input
	ldi		mpr, $FF		; Initialize Port D Data Register
	out		PORTD, mpr		; so all Port D inputs are Tri-State

	
	;USART1
		ldi		mpr, (1 << U2X1)
		sts		UCSR1A, mpr
		;Set baudrate at 2400bps
		ldi     mpr, high(0x01A0)	; Set Baud Rate to 2400 bps
		sts     UBRR1H, mpr			; Double-Speed => divider becomes 8
		ldi		mpr, low(0x01A0)	; Look at Slide 96 in Chap 5
		sts		UBRR1L, mpr
		;Enable receiver and transmitter
		ldi     mpr, (1 << UCSZ11) | (1 << UCSZ10) | (1 << USBS1)
		sts     UCSR1C, mpr

		;Set frame format: 8 data bits, 2 stop bits
		ldi     mpr, (1 << UCSZ11) | (1 << UCSZ10) | (1 << USBS1)
		sts     UCSR1C, mpr


	;TIMER/COUNTER1
		;Set Normal mode
		ldi		mpr, 0x00			; Normal mode (WGM bits all 0)
		sts		TCCR1A, mpr
		ldi		mpr, (1 << CS12)	; Prescaler = 256
		sts		TCCR1B, mpr
	;Other

	// Initialize the LCD
		rcall LCDInit

		//load string from memory to SRAM
		WORD_TO_MEM  Welcome_START, Line1, 32
		ldi choice, 2

		//Write to the screen from loaded memory
		rcall LCDWrite



;***********************************************************
;*  Main Program
;***********************************************************
MAIN:

	;TODO: ???
		in		mpr, PIND		; Get Button input from Port D
		sbrs	mpr, BUT7		; If left button is high skip next
		rcall START

		
		//rcall Word_To_Data
		rcall LCDWrite
		rjmp	MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;----------------------------------------------------------------
; Sub:	Wait
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly
;		waitcnt*10ms.  Just initialize wait for the specific amount
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			(((((3*ilcnt)-1+4)*olcnt)-1+4)*waitcnt)-1+16
;----------------------------------------------------------------
Wait:
		push	waitcnt			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt		; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt		; Decrement wait
		brne	Loop			; Continue Wait loop

		pop		olcnt		; Restore olcnt register
		pop		ilcnt		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		ret				; Return from subroutine



START:
	WORD_TO_MEM Game_Start, Line1, 16
	in		mpr, PIND		; Get Button input from Port D
	sbrs	mpr, but2		; If Right button is high skip next
	rcall	EDIT_CHOICE		; increment speed and do operation
	cpi		CHOICE, 1
	BREQ	DISPLAY_ROCK
	cpi		CHOICE, 2
	BREQ	DISPLAY_PAPER
	cpi		CHOICE, 3
	BREQ	DISPLAY_SCISSORS
	push	waitcnt
	ldi		waitcnt, WTime
	rcall	WAIT
	pop		waitcnt


	rjmp START



EDIT_CHOICE:
	inc choice
	sbrc choice, 3
	ldi choice, 1
	ret

DISPLAY_ROCK:
		WORD_TO_MEM Rock_Start, Line2, 16
		rcall LCDWrite
		rjmp START

DISPLAY_PAPER:
		WORD_TO_MEM PAPER_Start, Line2, 16
		rcall LCDWrite
		rjmp START

DISPLAY_SCISSORS:
		WORD_TO_MEM Scissors_Start, Line2, 16
		rcall LCDWrite
		rjmp START







;***********************************************************
;*	Stored Program Data
;***********************************************************

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
Welcome_START:
    .DB		"Welcome!        "		; Declaring data in ProgMem
	.DB		"Please Press PD7"
Welcome_END:

Standby_START:
    .DB		"Welcome!        "		; Declaring data in ProgMem
	.DB		"Please Press PD7"
Standby_END:

Game_Start:
	.DB		"Game Start!     "


Rock_Start:
    .DB		"Rock            "		; Declaring data in ProgMem
Rock_END:

Paper_Start:
	.DB		"Paper           "
Paper_END:

Scissors_Start:
	.DB		"Scissors        "
Scissors_END:






.dseg 
.org $0100
//Top string: This will be the same as STRIN_BEG
Line1:
	.byte 16
//Split the bottom string in half for counters
Line2: 
	.byte 16


;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver

