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
flags_tmp   RES 1
tick	    RES 1
sec_tenth   RES 1
second	    RES 1
minute	    RES 1
hour	    RES 1
MSD	    RES 1
MsD	    RES 1
LSD	    RES 1
tmp_am	    RES 1
temp_btn_1  RES 1
temp_btn_2  RES 1
time_tmp    RES 1
chrono_tick RES 1
chrono_ten  RES 1
chrono_min  RES 1
chrono_sec  RES 1
time_flags  RES 1
	    
#define	LED		PORTD
#define	TRIS_LED	TRISD
#define	BUTTON1		PORTB,0
#define	TRIS_BUTTON1	TRISB,0
#define	BUTTON2		PORTA,5
#define	TRIS_BUTTON2	TRISA,5
#define	INT_TMR		INTCON,TMR0IF
#define	LONG_CLICK_TIME	0x05
#define	IS_AM		time_flags,0
#define	SET_HOUR	time_flags,1
#define	LG_CLICK	time_flags,2
#define	TIME_CY		time_flags,3
#define	CHRONO_ON	time_flags,4

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
; Interrupt Service Routines
;
;*******************************************************************************
HighInterrupt
    ; 4 cycles to get in
    movwf   w_temp		    ;save w (1 cycle)
    movff   STATUS, status_temp	    ;save status (2 cycles)
    movff   BSR, bsr_temp	    ;save bsr (2 cycles)
    movff   time_flags,flags_tmp   ;save custom flags (2 cycles)
    
    bcf	    T0CON,7		    ; stop the timer0 (1 cycle)
    bcf	    INT_TMR		    ;clear interrupt flag (1 cycle)
    ; 45553 (65535 - 20000 + 18)
    movlw   b'10110001'		    ; (1 cycle)
    movwf   TMR0H   		    ;restore timer H value (1 cycle)
    movlw   b'11110001'		    ; (1 cycle)
    movwf   TMR0L		    ;restore timer L value (1 cycle)
    bsf	    T0CON,7		    ; start the timer0 (1 cycle)
    
    ; REGULAR TIME
    
    incf    tick		    ; increment the time tick
    movlw   0x32		    ;
    cpfseq  tick		    ; check if tick == 50 (0.1 sec)
    goto    chrono_interrupt
    
    clrf    tick		    ; reset the tick counter
    incf    sec_tenth		    ; increment 1/10 sec counter
    movlw   .9			    ;
    cpfsgt  sec_tenth		    ; check if more than 0.9s
    goto    chrono_interrupt		    ; if not, continue
    clrf    sec_tenth		    ;
    
    incf    second		    ; otherwise, increment second
    call    compute_sec		    ;
    btfss   TIME_CY		    ;
    goto    chrono_interrupt
    
    incf    minute		    ; 
    call    compute_min		    ; compute minutes out of seconds
    btfss   TIME_CY		    ;
    goto    chrono_interrupt
    
    incf    hour		    ;
    call    compute_hour	    ; compute hours out of minutes
    
    ; CHRONO TIME
    
chrono_interrupt
    btfss   CHRONO_ON
    goto    int_end
    incf    chrono_tick		    ; increment the chrono tick
    movlw   0x32		    ;
    cpfseq  chrono_tick		    ; check if chrono tick == 50 (0.1 sec)
    goto    int_end
    
    clrf    chrono_tick		    ; reset the tick counter
    incf    chrono_ten		    ; increment 1/10 sec counter
    movlw   .9			    ;
    cpfsgt  chrono_ten		    ; check if more than 0.9s
    goto    int_end		    ; if not, continue
    clrf    chrono_ten		    ;
    
    incf    chrono_sec		    ; otherwise, increment second
    movff   second,time_tmp	    ; save second state variable
    movff   chrono_sec,second	    ; put chrono second into second variable
    call    compute_sec		    ; compute incrementation
    movff   second,chrono_sec	    ; restore chrono second variable
    movff   time_tmp,second	    ; restore second state variable

    btfss   TIME_CY		    ; if the minutes have to be incremented
    goto    int_end
    incf    chrono_min		    ;
    movff   minute,time_tmp	    ; save minute state variable
    movff   chrono_min,minute	    ; put chrono minute into minute variable
    call    compute_min		    ; compute minutes out of seconds
    movff   minute,chrono_min	    ; restore chrono minute variable
    movff   time_tmp,minute	    ; restore minute state variable

int_end
    movff   flags_tmp,time_flags    ;restore custom flags
    movff   bsr_temp, BSR	    ;restore bsr
    movf    w_temp, w		    ;restore w
    movff   status_temp, STATUS	    ;save status
    
    retfie
    
;*******************************************************************************
;
; Initialisation routine
;
;*******************************************************************************
START

; -------------------------- table for LCD displays ----------------------------
stan_table
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
#define	TBL_MENU_SETCHRONO	.176
    data    "Chrono :        "
#define	TBL_MENU_CHOICE_CHRONO	.192
    data    "S1:Sor S2:ON/OFF"

; -------------------------- Actual initialisation -----------------------------
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
    clrf    sec_tenth	    ; set tenths of seconds to 0
    clrf    second	    ; set seconds to 0
    clrf    minute	    ; set minutes to 0
    clrf    hour	    ; set hours to 0
    clrf    tmp_am	    ; set temporary AM variable to 0
    clrf    time_flags	    ; set all flags to 0
    bsf	    SET_HOUR	    ; set hour setup instead of min setup
    clrf    temp_btn_1	    ; set the button1 tempo variable to 0
    clrf    temp_btn_2	    ; set the button1 tempo variable to 0
    clrf    chrono_tick
    clrf    chrono_ten
    clrf    chrono_min	    ;
    clrf    chrono_sec	    ; clear chrono variables
    clrf    LED
    
    call    delay_1s	    ;
    call    delay_1s	    ; freeze for 2 seconds to display the name 
    
    goto    main

;*******************************************************************************
;
; Basic (reusable) routines
;
;*******************************************************************************
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

LCDXY
    movwf   temp_wr
    rcall   i_write
    return

; ------------------------------------------------------------------------------
; ---------- Binary (8-bit) to BCD, 255 = highest possible result --------------
bin_bcd
    clrf    MSD
    clrf    MsD
    movwf   LSD         ;move value to LSD
gcptr_1reth
    movlw   .100            ;subtract 100 from LSD
    subwf   LSD,W
    btfss   STATUS,C        ;is value greater then 100
    bra     gtenth          ;NO goto tenths
    movwf   LSD         ;YES, move subtraction result into LSD
    incf    MSD,F           ;increment cptr_1reths
    bra     gcptr_1reth
gtenth
    movlw   .10         ;take care of tenths
    subwf   LSD,W
    btfss   STATUS,C
    bra     over            ;finished conversion
    movwf   LSD
    incf    MsD,F           ;increment tenths position
    bra     gtenth
over                    ;0 - 9, high nibble = 3 for LCD
    movf    MSD,W           ;get BCD values ready for LCD display
    xorlw   0x30            ;convert to LCD digit
    movwf   MSD
    movf    MsD,W
    xorlw   0x30            ;convert to LCD digit
    movwf   MsD
    movf    LSD,W
    xorlw   0x30            ;convert to LCD digit
    movwf   LSD
    retlw   0
	
; ------------------------------------------------------------------------------
; ---------------------------- Delay Routines ----------------------------------
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

; ------------------------------------------------------------------------------
; --------------------------- Button Routines ----------------------------------
; CAUTION : possibility of issues if long click > 1s
; it was easier to implement that way ;)
debounce_button1
    movff   sec_tenth,temp_btn_1    ; otherwise, save time at button1 down
    btfss   BUTTON1		    ;
    goto    $-2			    ; wait for user to release the button
    movff   sec_tenth,temp_btn_2    ; save time at button1 up
    movf    temp_btn_1,0	    ;
    subwf   temp_btn_2		    ; compute time delta
    bcf	    LG_CLICK		    ; prepare the variable
    movlw   LONG_CLICK_TIME	    ;
    cpfslt  temp_btn_2		    ; compare to long click time
    bsf	    LG_CLICK
    return
 
debounce_button2
    movff   sec_tenth,temp_btn_1    ; otherwise, save time at button1 down
    btfss   BUTTON2		    ;
    goto    $-2			    ; wait for user to release the button
    movff   sec_tenth,temp_btn_2    ; save time at button1 up
    movf    temp_btn_1,0	    ;
    subwf   temp_btn_2		    ; compute time delta
    bcf	    LG_CLICK		    ; prepare the variable
    movlw   LONG_CLICK_TIME	    ;
    cpfslt  temp_btn_2		    ; compare to long click time
    bsf	    LG_CLICK
    return
	
; ------------------------------------------------------------------------------
; ---------------------- Time calculation routines -----------------------------
AM_PM
    movff   hour,tmp_am
    btfss   IS_AM	    ;test if AM flag is set
    return
    movlw   .11		    ;
    cpfsgt  hour	    ; if set, check if hours > 11
    goto    ampm_set_time   ; if not, go directly to the end
    movlw   0x00	    ;
    cpfseq  hour	    ;
    goto    hour_not0	    ;
    goto    ampm_set_time   ; if hours == 0, go to the end
hour_not0   
    movlw   .12		    ;
    subwf   tmp_am	    ; if hours > 11, substract 12
ampm_set_time
    movf    tmp_am,0	    ; place result in w
    return
    
compute_sec
    bcf	    TIME_CY	    ; reset time carry flag
    movlw   .59		    ;
    cpfsgt  second	    ; check if second = 60
    return		    ; if not, return
    clrf    second	    ;
    bsf	    TIME_CY	    ; if so, clear second and set carry flag
    return
    
compute_min
    bcf	    TIME_CY	    ; reset time carry flag
    movlw   .59		    ;
    cpfsgt  minute	    ; check if minute = 60
    return		    ; if not, return
    clrf    minute	    ;
    bsf	    TIME_CY	    ; if so, clear minute and set carry flag
    return
    
compute_hour
    bcf	    TIME_CY	    ; reset time carry flag
    movlw   .23		    ;
    cpfsgt  hour	    ; check if hour = 24
    return		    ; if not, return
    clrf    hour	    ;
    bsf	    TIME_CY	    ; if so, clear hour and set carry flag
    return
    
;*******************************************************************************
;
; MAIN LOOP
;
;*******************************************************************************	
; ------------------------------------------------------------------------------
; ---------------------------- Main menu options -------------------------------
main
    movlw   TBL_MENU_DISPLAY; 
    movwf   ptr_pos		;
    call    stan_char_1		; send "Affichage" to the LCD line 1
    movlw   TBL_MENU_CHOICE1	; 
    movwf   ptr_pos		;
    call    stan_char_2		; send "S1:Sel    S2:Svt" to the LCD line 2
menu_display
    btfss   BUTTON1		; button1 pressed
    goto    subroutine_display
    btfsc   BUTTON2
    goto    menu_display
    call    debounce_button2

menu_settings_lcd		; take care of the "Clock setup" manu
    movlw   TBL_MENU_SETTINGS 
    movwf   ptr_pos		;
    call    stan_char_1		; send "Reglage Temps   " to the LCD line 1
    movlw   TBL_MENU_CHOICE1	; 
    movwf   ptr_pos		;
    call    stan_char_2		; send "S1:Sel    S2:Svt" to the LCD line 2
menu_settings
    btfss   BUTTON1
    goto    subroutine_settings
    btfsc   BUTTON2
    goto    menu_settings
    call    debounce_button2

menu_chrono_lcd			; take care of the "Chrono" manu
    movlw   TBL_MENU_CHRONO; 
    movwf   ptr_pos		;
    call    stan_char_1		; send "Chronometre     " to the LCD line 1
    movlw   TBL_MENU_CHOICE1	; 
    movwf   ptr_pos		;
    call    stan_char_2		; send "S1:Sel    S2:Svt" to the LCD line 2
menu_chrono
    btfss   BUTTON1
    goto    subroutine_chrono
    btfsc   BUTTON2
    goto    menu_chrono
    call    debounce_button2

;menu_countdown_lcd	    	; take care of the "Countdown" manu
;    movlw   TBL_MENU_COUNTDOWN 
;    movwf   ptr_pos	    ;
;    call    stan_char_1	    ; send "Compte à rebours" to the LCD line 1
;    movlw   TBL_MENU_CHOICE1; 
;    movwf   ptr_pos	    ;
;    call    stan_char_2	    ; send "S1:Sel    S2:Svt" to the LCD line 2
;menu_countdown
;    btfsc   BUTTON1
;    ;display menu is selected
;    btfsc   BUTTON2
;    goto    menu_countdown
;    call    debounce_button2
;    ;display menu is selected
    
    GOTO    main	    ; loop forever

; ------------------------------------------------------------------------------
; ---------------------------- Submenu routines --------------------------------

; TIME DISPLAY ROUTINE
subroutine_display
    call    debounce_button1	;wait for user to release the button
    movlw   TBL_MENU_CLOCK	;
    movwf   ptr_pos		;
    call    stan_char_1		;display the static part of the first line
    movlw   TBL_MENU_CHOICE_CLOCK
    movwf   ptr_pos		;
    call    stan_char_2		;display the second part of the line
    movlw   0x8D		;
    call    LCDXY		;position the cursor at the right place
    movlw   0x3A		;
    movwf   temp_wr		;
    call    d_write		;display ':'
    movlw   0x8A		;
    call    LCDXY		;position the cursor at the right place
    movlw   0x3A		;
    movwf   temp_wr		;
    call    d_write		;display ':'

subroutine_display_clock
    movf    second,w		;
    call    bin_bcd		;transform the seconds value into BCD for LCD
    movlw   0x8F		;
    call    LCDXY		;position the cursor at the right place
    movff   LSD,temp_wr		;
    call    d_write		;display the unities of seconds
    movlw   0x8E		;
    call    LCDXY		;position the cursor at the right place
    movff   MsD,temp_wr		;
    call    d_write		;display the decades of seconds
    
    movf    minute,w		;
    call    bin_bcd		;transform the seconds value into BCD for LCD
    movlw   0x8C		;
    call    LCDXY		;position the cursor at the right place
    movff   LSD,temp_wr		;
    call    d_write		;display the unities of seconds
    movlw   0x8B		;
    call    LCDXY		;position the cursor at the right place
    movff   MsD,temp_wr		;
    call    d_write		;display the decades of seconds
    
    movf    hour,0
    call    AM_PM		;
    call    bin_bcd		;transform the seconds value into BCD for LCD
    movlw   0x89		;
    call    LCDXY		;position the cursor at the right place
    movff   LSD,temp_wr		;
    call    d_write		;display the unities of seconds
    movlw   0x88		;
    call    LCDXY		;position the cursor at the right place
    movff   MsD,temp_wr		;
    call    d_write		;display the decades of seconds
    
    btfsc   BUTTON2		; if the button1 hasn't been pressed
    goto    display_clock_button1
    call    debounce_button2	; toggle am flag, if button2 pushed
    btg	    IS_AM
display_clock_button1
    btfsc   BUTTON1		; if the button1 hasn't been pressed
    goto    subroutine_display_clock
    call    debounce_button1	; otherwise
    goto    main
    
; TIME SETUP ROUTINE

subroutine_settings
    call    debounce_button1	;wait for user to release the button
    movlw   TBL_MENU_SET24	;
    movwf   ptr_pos		;
    call    stan_char_1		;display the static part of the first line
    movlw   TBL_MENU_CHOICE24
    movwf   ptr_pos		;
    call    stan_char_2		;display the second part of the line
    movlw   0x8D		;
    call    LCDXY		;position the cursor at the right place
    movlw   0x3A		;
    movwf   temp_wr		;
    call    d_write		;display ':'
    bsf	    SET_HOUR		;reset hour setup by default
    
subroutine_settings_clock
    movf    minute,w		;
    call    bin_bcd		;transform the seconds value into BCD for LCD
    movlw   0x8F		;
    call    LCDXY		;position the cursor at the right place
    movff   LSD,temp_wr		;
    call    d_write		;display the unities of seconds
    movlw   0x8E		;
    call    LCDXY		;position the cursor at the right place
    movff   MsD,temp_wr		;
    call    d_write		;display the decades of seconds
    
    movf    hour,w		;
    call    bin_bcd		;transform the seconds value into BCD for LCD
    movlw   0x8C		;
    call    LCDXY		;position the cursor at the right place
    movff   LSD,temp_wr		;
    call    d_write		;display the unities of seconds
    movlw   0x8B		;
    call    LCDXY		;position the cursor at the right place
    movff   MsD,temp_wr		;
    call    d_write		;display the decades of seconds

    btfsc   BUTTON2		; if the button1 has been pressed
    goto    settings_clock_button1
    call    debounce_button2	; wait for a user input
    clrf    second		;
    clrf    sec_tenth		;
    btfss   SET_HOUR		; if hours are to be incremented (<> minutes)
    goto    settings_inc_minute
    incf    hour
    call    compute_hour
settings_inc_minute
    btfsc   SET_HOUR		; if minutes are to be incremented (<> hours)
    goto    settings_clock_button1
    incf    minute
    call    compute_min
    
settings_clock_button1    
    btfsc   BUTTON1		    ; if the button1 hasn't been pressed
    goto    subroutine_settings_clock
    call    debounce_button1	    ; wait for user to release the button
    btfss   LG_CLICK		    ; verify if long click
    goto    menu_settings_lcd
    btg	    SET_HOUR		    ; toggle setting to change
    goto    subroutine_settings_clock
    
; CHRONO ROUTINE

subroutine_chrono
    call    debounce_button1	;wait for user to release the button
    movlw   TBL_MENU_SETCHRONO	;
    movwf   ptr_pos		;
    call    stan_char_1		;display the static part of the first line
    movlw   TBL_MENU_CHOICE_CHRONO
    movwf   ptr_pos		;
    call    stan_char_2		;display the second part of the line
    movlw   0x8D		;
    call    LCDXY		;position the cursor at the right place
    movlw   0x3A		;
    movwf   temp_wr		;
    call    d_write		;display ':'

subroutine_chrono_clock
    movf    chrono_sec,w	;
    call    bin_bcd		;transform the seconds value into BCD for LCD
    movlw   0x8F		;
    call    LCDXY		;position the cursor at the right place
    movff   LSD,temp_wr		;
    call    d_write		;display the unities of seconds
    movlw   0x8E		;
    call    LCDXY		;position the cursor at the right place
    movff   MsD,temp_wr		;
    call    d_write		;display the decades of seconds
    
    movf    chrono_min,w	;
    call    bin_bcd		;transform the seconds value into BCD for LCD
    movlw   0x8C		;
    call    LCDXY		;position the cursor at the right place
    movff   LSD,temp_wr		;
    call    d_write		;display the unities of minutes
    movlw   0x8B		;
    call    LCDXY		;position the cursor at the right place
    movff   MsD,temp_wr		;
    call    d_write		;display the decades of minutes
    
    btfsc   BUTTON2		; if the button2 hasn't been pressed
    goto    chrono_clock_button1
    call    debounce_button2	; wait for user to release the button
    btg	    CHRONO_ON		; toggle the chrono flag
    btg	    LED,0		; toggle the led0
chrono_clock_button1
    btfsc   BUTTON1		; if the button1 hasn't been pressed
    goto    subroutine_chrono_clock
    call    debounce_button1	; otherwise
    bcf	    CHRONO_ON		; clear the chrono flag
    bcf	    LED,0		; turn of the led0
    clrf    chrono_min		;
    clrf    chrono_sec		; reset the chrono time
    goto    menu_chrono_lcd
;*******************************************************************************
;
; END OF PROGRAM
;
;*******************************************************************************
    END