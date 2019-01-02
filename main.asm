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
w_temp	    RES 1
status_temp RES 1
bsr_temp    RES 1
tick	    RES 1
sec_tenth   RES 1
	    
#define	LED		PORTD
#define	TRIS_LED	TRISD
#define	BUTTON1		PORTB,0
#define	TRIS_BUTTON1	TRISB,0
#define	BUTTON2		PORTA,5
#define	TRIS_BUTTON2	TRISA,5
#define	INT_TMR		INTCON,TMR0IF

;*******************************************************************************
;
; Reset Vector
;
;*******************************************************************************
RES_VECT    CODE    0x0000            ; processor reset vector
    GOTO    START                   ; go to beginning of program

INT_VECT  CODE    0x0008
    GOTO    HighInterrupt

;*******************************************************************************
;
; MAIN PROGRAM
;
;*******************************************************************************
MAIN_PROG CODE                      ; let linker place main program
 
 ;*******************************************************************************
;
; TODO Step #4 - Interrupt Service Routines
;
;*******************************************************************************
HighInterrupt
    ; 4 cycles to get in
    movwf   w_temp		    ;save w (1 cycle)
    movff   STATUS, status_temp	    ;save status (2 cycles)
    movff   BSR, bsr_temp	    ;save bsr (2 cycles)
    
    bcf	    T0CON,7		    ; stop the timer0 (1 cycle)
    bcf	    INT_TMR		    ;clear interrupt flag (1 cycle)
    ; 45551 (65535 - 20000 + 16)
    movlw   b'10110001'		    ; (1 cycle)
    movwf   TMR0H   		    ;restore timer H value (1 cycle)
    movlw   b'11101111'		    ; (1 cycle)
    movwf   TMR0L		    ;restore timer L value (1 cycle)
    bsf	    T0CON,7		    ; start the timer0 (1 cycle)
    
    incf    tick		    ; increment the time tick
    movlw   0x32		    ;
    cpfseq  tick		    ; check if tick == 50 (0.1 sec)
    goto    int_end
    
    clrf    tick		    ; reset the tick counter
    incf    sec_tenth		    ; increment 1/10 sec counter

int_end
    movff   bsr_temp, BSR	    ;restore bsr
    movf    w_temp, w		    ;restore w
    movff   status_temp, STATUS	    ;save status
    
    retfie
    
;*******************************************************************************
;
; TODO Step #4 - Interrupt Service Routines
;
;*******************************************************************************
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
    
    movlw   b'00001000'	    ;
    movwf   T0CON	    ; set the timer0 with prescaler disabled
    movlw   b'10110001'	    ;
    movwf   TMR0H	    ;
    movlw   b'11011111'	    ;
    movwf   TMR0L	    ; set the timer to 45535 (65535 - 20000) to get an interruption every 2 ms
    bsf	    RCON,IPEN	    ; enable high priority interrupts
    movlw   b'10100000'	    ;
    movwf   INTCON	    ; enable GIE and TMR0 interrupts
    movlw   b'10000100'	    ;
    movwf   INTCON2	    ; set TMR0 interrupts as high priority
    bsf	    T0CON,7	    ; start the timer0
    
    clrf    tick	    ; set time to 0
    
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
 
debounce_button1
    btfss   BUTTON1	    ;
    goto    $-2		    ; wait for user to release the button
    return
 
debounce_button2
    btfss   BUTTON2	    ;
    goto    $-2		    ; wait for user to release the button
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
    btfss   BUTTON1	    ; button1 pressed
    goto    subroutine_display
    btfsc   BUTTON2
    goto    menu_display
    call    debounce_button2
    
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
    call    debounce_button2
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
    call    debounce_button2
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
    call    debounce_button2
    ;display menu is selected
    
    GOTO    main	    ; loop forever

    
subroutine_display
    call    debounce_button1
    movff   sec_tenth,temp_wr
    call    d_write
    call    LCDLine_1
    btfsc   BUTTON1
    goto    subroutine_display
    call    debounce_button1
    goto    menu_display
    
subroutine_settings
    call    debounce_button1
    movlw   0x01
    movwf   LED
    goto    menu_settings
;----------------- End of main program ----------------------------------------
    END