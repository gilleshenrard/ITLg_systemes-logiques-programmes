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
	    
#define	LED		PORTD
#define	TRIS_LED	TRISD
#define	BUTTON1		PORTB,0
#define	TRIS_BUTTON1	TRISB,0
#define	BUTTON2		PORTA,5
#define	TRIS_BUTTON2	TRISA,5

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
#define TBL_INTRO1		.0
    data    " Gilles Henrard "
#define	TBL_INTRO2		.16
    data    "Dossier 18F8722 "
#define	TBL_MENU_DISPLAY	.32
    data    "Affichage       "
#define	TBL_MENU_CHOICE1	.48
    data    "S1:Sel    S2:Svt"
#define	TBL_MENU_SETTINGS	.64
    data    "Reglage Temps   "
#define	TBL_MENU_CHRONO		.80
    data    "Chronometre     "
#define	TBL_MENU_COUNTDOWN	.96
    data    "Compte à rebours"
#define	TBL_MENU_CLOCK		.112
    data    "Horloge         "
#define	TBL_MENU_CHOICE_CLOCK	.128
    data    "S1:Sor  S2:24/12"
#define	TBL_MENU_SET24		.144
    data    "Regler a        "
#define	TBL_MENU_CHOICE24	.160
    data    "S1:Svt/Sor S2:++"
    
    clrf    TRIS_LED	    ;
    clrf    LED		    ; set PORTD as output and clear leds

    call    LCDInit	    ; initialize LCD
    call    ClearLCD	    ; clear the LCD
    movlw   TBL_INTRO1	    ; 
    movwf   ptr_pos	    ;
    call    stan_char_1	    ; send " Gilles Henrard " to the LCD line 1
    movlw   TBL_INTRO2	    ; 
    movwf   ptr_pos	    ;
    call    stan_char_2	    ; send "Dossier 18F8722 " to the LCD line 2

    bcf	    BUTTON1	    ; clear BUTTON1
    bsf	    TRIS_BUTTON1    ; set PORTB,0 as input
    movlw   b'00001110'	    ;
    movwf   ADCON1	    ; set PORTA as digital
    bcf	    BUTTON2	    ; clear BUTTON2
    bsf	    TRIS_BUTTON2    ; set PORTA,5 as input
    
    call    delay_1s	    ;
    call    delay_1s	    ; freeze for 5 seconds to display the name 
    
    goto    main
    
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

    
;----------------- Main loop ---------------------------------------------------
main
    movlw   TBL_MENU_DISPLAY; 
    movwf   ptr_pos	    ;
    call    stan_char_1	    ; send "Affichage" to the LCD line 1
    movlw   TBL_MENU_CHOICE1; 
    movwf   ptr_pos	    ;
    call    stan_char_2	    ; send "S1:Sel    S2:Svt" to the LCD line 2
    
menu_display
    btfsc   BUTTON1
    ;display menu is selected
    btfsc   BUTTON2
    goto    menu_display
    btfss   BUTTON2
    goto    $-2
    ;display menu is selected
    
    movlw   TBL_MENU_SETTINGS 
    movwf   ptr_pos	    ;
    call    stan_char_1	    ; send "Reglage Temps   " to the LCD line 1
    movlw   TBL_MENU_CHOICE1; 
    movwf   ptr_pos	    ;
    call    stan_char_2	    ; send "S1:Sel    S2:Svt" to the LCD line 2
menu_settings
    btfsc   BUTTON1
    ;display menu is selected
    btfsc   BUTTON2
    goto    menu_settings
    btfss   BUTTON2
    goto    $-2
    ;display menu is selected
    
    movlw   TBL_MENU_CHRONO; 
    movwf   ptr_pos	    ;
    call    stan_char_1	    ; send "Chronometre     " to the LCD line 1
    movlw   TBL_MENU_CHOICE1; 
    movwf   ptr_pos	    ;
    call    stan_char_2	    ; send "S1:Sel    S2:Svt" to the LCD line 2
menu_chrono
    btfsc   BUTTON1
    ;display menu is selected
    btfsc   BUTTON2
    goto    menu_chrono
    btfss   BUTTON2
    goto    $-2
    ;display menu is selected
    
    movlw   TBL_MENU_COUNTDOWN 
    movwf   ptr_pos	    ;
    call    stan_char_1	    ; send "Compte à rebours" to the LCD line 1
    movlw   TBL_MENU_CHOICE1; 
    movwf   ptr_pos	    ;
    call    stan_char_2	    ; send "S1:Sel    S2:Svt" to the LCD line 2
menu_countdown
    btfsc   BUTTON1
    ;display menu is selected
    btfsc   BUTTON2
    goto    menu_countdown
    btfss   BUTTON2
    goto    $-2
    ;display menu is selected
    
    GOTO    main	    ; loop forever

;----------------- End of main program ----------------------------------------
    END