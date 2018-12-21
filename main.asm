;*******************************************************************************
; 
; Processor Inclusion
;
;*******************************************************************************
    list p=18F8722
#include p18F8722.inc

;*******************************************************************************
;
; Configuration Word Setup
;
;*******************************************************************************
    CONFIG	OSC = HSPLL
    CONFIG	FCMEN = OFF
    CONFIG	IESO = OFF
    CONFIG	PWRT = OFF           
    CONFIG	BOREN = OFF
    CONFIG	WDT = OFF 
    CONFIG	MCLRE = ON  
    CONFIG	LVP = OFF  
    CONFIG	XINST = OFF

    EXTERN	LCDInit, temp_wr, d_write, i_write, LCDLine_1, LCDLine_2
    EXTERN 	Delay, Check, InitSPI, ClearLCD

;*******************************************************************************
;
; Variable Definitions
;
;*******************************************************************************
variables   UDATA_ACS
ptr_pos	    RES 1
ptr_count   RES 1
temp_1	    RES 1
temp_2	    RES 1
temp_3	    RES 1
	    
#define	LED	    PORTD
#define	TRIS_LED    TRISD

;*******************************************************************************
;
; Reset Vector
;
;*******************************************************************************
RES_VECT  CODE    0x0000            ; processor reset vector
    GOTO    START                   ; go to beginning of program

;*******************************************************************************
;
; TODO Step #4 - Interrupt Service Routines
;
;*******************************************************************************

; TODO INSERT ISR HERE

;*******************************************************************************
;
; MAIN PROGRAM
;
;*******************************************************************************
MAIN_PROG CODE                      ; let linker place main program

START
;----------------- Initialisation ----------------------------------------------
stan_table				;table for LCD displays
;	    "XXXXXXXXXXXXXXXX"	;ptr:
    data    " Gilles Henrard "	;0
    data    "Dossier 18F8722 "	;16
    data    "Yaaaaay clock!  "	;32
    
    clrf    TRIS_LED	    ;
    clrf    LED		    ; set PORTD as output and clear leds

    call    LCDInit	    ; initialize LCD
    call    ClearLCD	    ; clear the LCD
    movlw   0		    ; 
    movwf   ptr_pos	    ;
    call    stan_char_1	    ; send " Gilles Henrard " to the LCD line 1
    movlw   .16		    ; 
    movwf   ptr_pos	    ;
    call    stan_char_2	    ; send "Dossier 18F8722 " to the LCD line 2
    
    call    delay_1s	    ;
    call    delay_1s	    ;
    call    delay_1s	    ;
    call    delay_1s	    ;
    call    delay_1s	    ; freeze for 5 seconds to display the name

;----------------- Main loop ---------------------------------------------------
main
    movlw   0x01
    movwf   LED
    call    delay_100ms
    clrf    LED
    call    delay_100ms
    GOTO main		    ; loop forever

    
    
; ------------------------------------------------------------------------------
; -------------------------- LCD display routines-------------------------------
stan_char_1
    call    LCDLine_1		;move cursor to line 1
    movlw   .16			;1-full line of LCD
    movwf   ptr_count
    movlw   UPPER stan_table
    movwf   TBLPTRU
    movlw   HIGH stan_table
    movwf   TBLPTRH
    movlw   LOW stan_table
    movwf   TBLPTRL
    movf    ptr_pos,W
    addwf   TBLPTRL,F
    clrf    WREG
    addwfc  TBLPTRH,F
    addwfc  TBLPTRU,F

stan_next_char_1
    tblrd   *+
    movff   TABLAT,temp_wr			
    call    d_write		;send character to LCD
    decfsz  ptr_count,F		;move pointer to next char
    bra	    stan_next_char_1

    return
    
stan_char_2	
	call	LCDLine_2	;move cursor to line 2 
	movlw	.16		;1-full line of LCD
	movwf	ptr_count
	movlw	UPPER stan_table
	movwf	TBLPTRU
	movlw	HIGH stan_table
	movwf	TBLPTRH
	movlw	LOW stan_table
	movwf	TBLPTRL
	movf	ptr_pos,W
	addwf	TBLPTRL,F
	clrf	WREG
	addwfc	TBLPTRH,F
	addwfc	TBLPTRU,F

stan_next_char_2
	tblrd	*+
	movff	TABLAT,temp_wr
	call	d_write		;send character to LCD

	decfsz	ptr_count,F	;move pointer to next char
	bra	stan_next_char_2

	return
	
; -------------------------- Delay Routines ------------------------------------
delay_1s                ;1 sec à 10Mhz instruction
    call    delay_100ms
    call    delay_100ms
    call    delay_100ms
    call    delay_100ms
    call    delay_100ms
    call    delay_100ms
    call    delay_100ms
    call    delay_100ms
    call    delay_100ms
    call    delay_100ms
    return

delay_100ms             ;100 ms à 10Mhz instruction
    movlw   0xFF
    movwf   temp_1
    movwf   temp_2
    movlw   0x05
    movwf   temp_3
d1l1
    decfsz  temp_1,F
    bra	d1l1
    decfsz  temp_2,F
    bra	d1l1
    decfsz  temp_3,F
    bra	d1l1
    return

delay_10ms              ;10 ms à 10Mhz instruction
    movlw   0xFF
    movwf   temp_1
    movlw   0x83
    movwf   temp_2
d100l1
    decfsz  temp_1,F
    bra	d100l1
    decfsz  temp_2,F
    bra	d100l1
    return

;----------------- End of main program ----------------------------------------
    END