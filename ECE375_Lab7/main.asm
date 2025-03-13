
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
;.def	stat = r17				; 0: ReadyFlag 1: ___ 2: ____ 3: _____ 4: ____ 5: ___ 6: ___ 7:____ 
.def	choice = r18
.def	opponent = r19
.def	waitcnt = r20				; Wait Loop Counter
.def	temp = r25


//USART THingys
.def	send = r18
.def	receive = r19

//Just for wait function
.def	ilcnt = r18				; Inner Loop Counter
.def	olcnt = r19				; Outer Loop Counter



.equ	But7 = 7				; Right Whisker Input Bit
.equ	But2 = 4				; Left Whisker Input Bit
.equ	WTime = 150				; Time to wait in wait loop
.def	i = r25

.equ	is_ready = 0			

.equ	Rock = 1
.equ	Paper = 2
.equ	Scissors = 3


;***********************************************************
;*  Preload Value = 0x48E5
;*  Prescaler = 256 => timer increment time = 256/8MHz = 32 micro seconds
;*  => total timer count to get 1.5 secs = 1.5/ 32 microsec = 46875
;*  => Preload value = 65536 - 46875 = 18661 = 0x48E5
;***********************************************************
.equ PRELOAD_HIGH = 0x48       ; High byte of preload value
.equ PRELOAD_LOW  = 0xE5       ; Low byte of preload value

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
    push    r15
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


.org	$0028
	rcall TIMER1_INT
	reti
.org    $0032
    rjmp    USART_Receive_Interrupt   ; Jump to the ISR when data is received

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
	ldi     mpr, (1 << RXEN1) | (1 << TXEN1) | (1 << RXCIE1)
	sts     UCSR1B, mpr

	;Set frame format: 8 data bits, 2 stop bits
	ldi     mpr, (1 << UCSZ11) | (1 << UCSZ10) | (1 << USBS1)
	sts     UCSR1C, mpr


	;TIMER/COUNTER1
		;Set Normal mode
		ldi		mpr, 0x00			; Normal mode (WGM bits all 0)
		sts		TCCR1A, mpr
		ldi		mpr, (1 << CS12)	; Prescaler = 256
		sts		TCCR1B, mpr

		ldi     mpr, PRELOAD_HIGH      ; Load high byte of preload value
		sts     TCNT1H, mpr
		ldi     mpr, PRELOAD_LOW       ; Load low byte of preload value
		sts     TCNT1L, mpr

		ldi     mpr, (1 << TOIE1)      ; Enable Timer1 Overflow Interrupt
		sts     TIMSK1, mpr

		sei

	;Other

	// Initialize the LCD
		rcall LCDInit

		//load string from memory to SRAM
		WORD_TO_MEM  Welcome_START, Line1, 32
		ldi choice, 1 // Start with ROCK
		ldi opponent, 3 // TEst

		//Write to the screen from loaded memory
		rcall LCDWrite
		
		


;***********************************************************
;*  Main Program
;***********************************************************
MAIN:

	;TODO: ???
		//WORD_TO_MEM  Welcome_START, Line1, 32
		ldi choice, 1 // Start with ROCK
		in		mpr, PIND		; Get Button input from Port D
		sbrs	mpr, BUT7		; If left button is high skip next
		rjmp		STANDBY
		//rcall Word_To_Data
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
HALF_SECOND_WAIT:
    push waitcnt
    push olcnt
    push ilcnt

    ldi waitcnt, 100         ; 50 iterations of ~10ms each = 500ms
HWAIT_OUTER:
    ldi olcnt, 40           ; Outer loop (~10ms per iteration)
HWAIT_LOOP:
    ldi ilcnt, 200          ; Inner loop for short delay
HWAIT_INNER:
    dec ilcnt
    brne HWAIT_INNER
    dec olcnt
    brne HWAIT_LOOP
    dec waitcnt
    brne HWAIT_OUTER       ; Repeat outer loop until 500ms is reached

    pop ilcnt
    pop olcnt
    pop waitcnt
    ret


;***********************************************************
;*  USART Communication
;***********************************************************
USART_Send:
    lds		mpr, UCSR1A
    sbrs	mpr, UDRE1              ; Wait for transmit buffer to be empty
    rjmp	USART_Send
    sts		UDR1, send              ; Send the data
WAIT_TX:
    lds		mpr, UCSR1A
    sbrs	mpr, TXC1                ; Wait for transmission complete flag
    rjmp	WAIT_TX
    ret

USART_Receive:
    lds		mpr, UCSR1A
    sbrs	mpr, RXC1                ; Wait until data is received
    rjmp	USART_Receive
    lds		opponent, UDR1           ; Store received data in opponent
    ret

USART_Receive_Interrupt:
    push    mpr             ; Save working register
    lds     mpr, UDR1       ; Read received data from USART
    mov     receive, mpr    ; Store in receive register
    pop     mpr             ; Restore working register
    reti                    ; Return from interrupt

STANDBY:
    WORD_TO_MEM Standby_START, Line1, 32  ; Display "Ready, Waiting"
	rcall LCDWRITE
	
	push send
	ldi send, SendReady
	rcall USART_SEND
	pop send

STANDBY_LOOP:
    cpi		receive, SendReady ; Check if opponent sent "Ready"
    brne	STANDBY_LOOP       ; If not, keep waiting
    
	rjmp	START              ; If received, proceed




START:
	WORD_TO_MEM Game_Start, Line1, 16
	rcall START_TIMER
CHOICE_LOOP:
	in		mpr, PIND		; Get Button input from Port D
	sbrs	mpr, but2		; If Right button is high skip next
	rcall	EDIT_CHOICE		; increment speed and do operation

	cpi		CHOICE, 1
	BREQ	DISPLAY_ROCK
	cpi		CHOICE, 2
	BREQ	DISPLAY_PAPER
	cpi		CHOICE, 3
	BREQ	DISPLAY_SCISSORS
 
 AFTER_CHOICE:

	IN		mpr, PINB
	ANDI	mpr, $F0
	
	sbrc	mpr, 4
	rjmp	CHOICE_LOOP

	rjmp use_choice


EDIT_CHOICE:
	inc choice
	sbrc choice, 3
	ldi choice, 1
	ret

DISPLAY_ROCK:
		WORD_TO_MEM Rock_Start, Line2, 16
		rcall LCDWrite
		rcall HALF_SECOND_WAIT  ; Wait 500ms to prevent bouncing

		rjmp  AFTER_CHOICE

DISPLAY_PAPER:
		WORD_TO_MEM PAPER_Start, Line2, 16
		rcall LCDWrite
		rcall HALF_SECOND_WAIT  ; Wait 500ms to prevent bouncing


		rjmp  AFTER_CHOICE

DISPLAY_SCISSORS:
		WORD_TO_MEM Scissors_Start, Line2, 16
		rcall LCDWrite
		rcall HALF_SECOND_WAIT  ; Wait to prevent bouncing

		rjmp  AFTER_CHOICE












START_TIMER:
	push	mpr
    ldi     waitcnt, 4          ; Set countdown to 4 steps (4 LEDs)

    ; Load preload value
    ldi     mpr, PRELOAD_HIGH
    sts     TCNT1H, mpr
    ldi     mpr, PRELOAD_LOW
    sts     TCNT1L, mpr

    ; Enable Timer1 Overflow Interrupt
    ldi     mpr, (1 << TOIE1)
    sts     TIMSK1, mpr

	ldi		mpr, (1 << CS12)	; Prescaler = 256
	sts		TCCR1B, mpr

	IN		mpr, PORTB
	ANDI	mpr, $0F
	ORI		mpr, $F0
	OUT		PORTB, mpr

	pop		mpr
    ret


TIMER1_INT:
    push    mpr
    push    temp

    in      mpr, PORTB             ; Read current LED state from PORTB (output register)
    andi    mpr, 0xF0              ; Keep only PB7:PB4 (LEDs), clear PB3:PB0
    mov     temp, mpr              ; Copy the LED bits to temp
    lsr     temp                   ; Shift LEDs right (turn off one LED)
    andi    temp, 0xF0              ; Ensure only PB7:PB4 are modified
    in      mpr, PORTB             ; Read PORTB again to get PB3:PB0
    andi    mpr, 0x0F              ; Mask PB3:PB0 (keep lower nibble)
    or      mpr, temp               ; Merge shifted LEDs with preserved PB3:PB0
    out     PORTB, mpr              ; Update PORTB with new LED state

    ; Decrement countdown counter
    ; Check if countdown is complete
	andi	mpr, $F0
    CPI		mpr, 0
    brne    TIMER_CONTINUE          ; If not zero, continue countdown

    ; Disable Timer1 Interrupt
    ldi     mpr, 0x00
    sts     TIMSK1, mpr
	ldi     mpr, 0x00
    sts     TCCR1B, mpr  ; Stop Timer1 completely
    rjmp    END_TIMER


TIMER_CONTINUE:
    ; Keep the timer running
    ldi     mpr, PRELOAD_HIGH
    sts     TCNT1H, mpr
    ldi     mpr, PRELOAD_LOW
    sts     TCNT1L, mpr
	

END_TIMER:

    pop     temp
    pop     mpr
    ret


Use_Choice:
	rcall USART_SEND

Get_Opp:
    //rcall USART_Receive      ; Wait for data to be received
    rcall	START_TIMER

Recieve_Loop:
	cpi		opponent, 1
	BREQ	DISPLAY_ROCK2
	cpi		opponent, 2
	BREQ	DISPLAY_PAPER2
	cpi		opponent, 3
	BREQ	DISPLAY_SCISSORS2
	rjmp Recieve_Loop

Suspense_Loop:
	IN		mpr, PINB
	ANDI	mpr, $F0
	sbrc	mpr, 4
	rjmp	SUSPENSE_LOOP

	rjmp GAME_LOGIC
	
DISPLAY_ROCK2:
		WORD_TO_MEM Rock_Start, Line1, 16
		rcall LCDWrite
		rcall HALF_SECOND_WAIT  ; Wait 500ms to prevent bouncing

		rjmp	SUSPENSE_LOOP 

DISPLAY_PAPER2:
		WORD_TO_MEM PAPER_Start, Line1, 16
		rcall LCDWrite
		rcall HALF_SECOND_WAIT  ; Wait 500ms to prevent bouncing


		rjmp	SUSPENSE_LOOP 

DISPLAY_SCISSORS2:
		WORD_TO_MEM Scissors_Start, Line1, 16
		rcall LCDWrite
		rcall HALF_SECOND_WAIT  ; Wait to prevent bouncing

		rjmp	SUSPENSE_LOOP 

GAME_LOGIC:	
	sub  choice, opponent  ; choice - opponent
	brpl MODULO            ; If result is positive, go to MODULO
	ldi opponent, 3
	add  choice, opponent        ; If negative, adjust by adding 3

MODULO:
	cpi  choice, 1
	breq DISPLAY_WIN

	cpi  choice, 2
	breq DISPLAY_LOSE

	rjmp DISPLAY_TIE



DISPLAY_TIE:
		rcall START_TIMER
TIE_LOOP:
		WORD_TO_MEM Draw_Start, Line1, 16
		rcall LCDWrite

		IN		mpr, PINB
		ANDI	mpr, $F0
		sbrc	mpr, 4
		rjmp TIE_LOOP

		rjmp restart_game


DISPLAY_WIN:
    rcall START_TIMER
WIN_LOOP:
    WORD_TO_MEM Win_Start, Line1, 16
    rcall LCDWrite
			
	IN		mpr, PINB
	ANDI	mpr, $F0
	sbrc	mpr, 4
    rjmp    WIN_LOOP

    rjmp    RESTART_GAME


DISPLAY_LOSE:
    rcall START_TIMER
LOSE_LOOP:
    WORD_TO_MEM Lose_Start, Line1, 16
    rcall LCDWrite

	IN		mpr, PINB
	ANDI	mpr, $F0
	sbrc	mpr, 4
    rjmp    LOSE_LOOP

    rjmp    RESTART_GAME



RESTART_GAME:
    ; Clear game variables
    ldi     choice, 1
    ldi     opponent, 1
    clr     waitcnt

    ; Reset LEDs
    ldi     mpr, 0x00     ; Turn off all LEDs
    out     PORTB, mpr
	
    ; Reset LCD with welcome message
    WORD_TO_MEM Welcome_START, Line1, 32
    rcall   LCDWrite

    ; Jump back to main loop
    jmp    MAIN

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
    .DB		"Ready, Waiting  "		; Declaring data in ProgMem
	.DB		"For the Opponent"
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

Win_Start:
    .DB		"You Won!!       "		; Declaring data in ProgMem
Win_END:

Lose_Start:
	.DB		"You Lost        "
Lose_END:

Draw_Start:
	.DB		"Draw!           "
Draw_END:




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

