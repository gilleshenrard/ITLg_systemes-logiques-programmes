    /*
 * File:   main.c
 * Author: Gilles
 *
 * Created on January 17, 2019, 3:54 PM
 */

#include "Progr_LCD.h"
#include <math.h>

#pragma    config	OSC = HSPLL
#pragma    config	FCMEN = OFF
#pragma    config	IESO = OFF
#pragma    config	PWRT = OFF
#pragma    config	BOREN = OFF
#pragma    config	WDT = OFF
#pragma    config	MCLRE = ON
#pragma    config	LVP = OFF
#pragma    config	XINST = OFF

#define     LED0    PORTDbits.AD0
#define     LED1    PORTDbits.AD1
#define     LED2    PORTDbits.AD2
#define     LED3    PORTDbits.AD3
#define     LED4    PORTDbits.AD4

#define     Button_Left PORTBbits.RB0
#define     Button_Right PORTAbits.RA5

#define     SDO         PORTCbits.RC5
#define     SCK         PORTCbits.RC3
#define     CS_DAC      PORTCbits.RC2
#define     LDAC_DAC    PORTCbits.RC0

#define     ANALOG      PORTAbits.RA1   //temperature sensor on the card

#define     CPT8kHz     0x4E2
#define     CPT16kHz    0x271

#define     CHAN_1      0b0001

#define     PI          3.141592
#define     D_PI         6.283184

void init(void);

int x0=0, x1=0;
int filter = 0;
void __interrupt(high_priority) Int_Vect_High(void)
{
    LED0 = 1;

    //launch ADC
    ADCON0bits.GO_DONE = 1;
    while(ADCON0bits.GO_DONE){}
    
    //inform DAC that we are communicating with him
    CS_DAC = 0;
    SSPBUF=0x10;
    while(!SSPSTATbits.BF){}
    //load the DCA value in the SPI output buffer (depending on the filter)
    switch(filter){
        case 1: //low pass filter by two members mean
            x0 = ADRESH;
            SSPBUF = (x0 + x1) >>1;
            x1 = x0;
            break;
        
        default: //#nofilter
            SSPBUF = ADRESH + 1;
            break;
    }
    //wait until the data is ready
    while(!SSPSTATbits.BF){}
    //inform DAC that we stop communicating with him
    CS_DAC = 1;
    //send an impulsion to the DAC latch
    LDAC_DAC = 0;
    LDAC_DAC = 1;

    LED0 = 0;
    PIR1bits.CCP1IF = 0;
}

void main(void) {
    LCDInit();
    init();
    
    while(1){}
    return;
}

void init(){
    // disable interruptions + enable high priority
    // (interrupts disabled by default until proper function selected)
    INTCON = 1;
    INTCONbits.GIE = 1;
    RCONbits.IPEN = 1;
    
    // enable timer1 (16 bits, timer mode, prescaler 1:1, rest is unused)
    T1CON = 0;
    T1CONbits.RD16 = 1;
    T1CONbits.TMR1ON = 1;
    T1CONbits.T1CKPS0 = 0;
    T1CONbits.T1CKPS1 = 0;
    
    // enable timer1 and ccp1 interrupts and clear interrupt flag
    PIE1 = 0;
    PIE1bits.TMR1IE = 1;
    PIE1bits.CCP1IE = 1;
    PIR1 = 0;
    
    // configure CCP1 module as comparator + enable special trigger
    CCP1CON = 0b00001011;
    CCPR1 = CPT16kHz;
    
    // assign timer1 as a source for ECCP1
    T3CON = 0;
    T3CONbits.RD16 = 1;
    
    //set RB0 and RA5 as inputs (buttons)
    TRISBbits.TRISB0 = 1;
    Button_Left = 0;
    TRISAbits.TRISA5 = 1;
    Button_Right = 0;
    
    //set PortD as output (leds)
    TRISD = 0;
    PORTD = 0;

//MSSP1 configuration is useless... LCD already uses it
//just need to configure CS and LDAC for the DAC

    //set MSSP1 as SPI, idle state low, master mode , no collision, clock = TMR2
    //TRISD<1,4> already cleared
    SSPCON1 = 0;
    SSPCON1bits.SSPEN = 1;
    SSPCON1bits.CKP = 0;
    SSPCON1bits.SSPM1 = 1;
    
    //set MSSP1 status register for SPI
    SSPSTAT = 0;
    SSPSTATbits.CKE = 1;
 
    //set DAC CS and LDAC as output
    LATC = 0;
    TRISCbits.TRISC0 = 0;
    TRISCbits.TRISC2 = 0;
    TRISCbits.TRISC3 = 0;
    TRISCbits.TRISC4 = 1;
    TRISCbits.TRISC5 = 0;
    LATCbits.LATC0 = 1;
    LATCbits.LATC2 = 1;
    
    //enable ADC module and select AN0 (potentiometer R3 on the board)
    ADCON0 = 0;             
    ADCON0bits.CHS = CHAN_1; //select channel 1 (AN1)
    ADCON0bits.ADON = 1;    //enable ADC
    ADCON0bits.GO_DONE = 0; //clear conversion status flag
    
    //configure ADC module operation
    ADCON1 = 0;   //select internal voltage references + set all as analog inputs
    ADCON1bits.PCFG = 0b1011;   //set 4 first bits as analog
    
    //configure ADC justification
    ADCON2 = 0;    //set AN0 as left justified
    ADCON2bits.ADCS = 0b001;    //set TAD as 2
    ADCON2bits.ACQT = 0b001;    //set OSC as 8
    
    //set A1 as input
    TRISAbits.TRISA1 = 1;
    
    //clear ADC data registers
    ADRESH = 0;
    ADRESL = 0;
}
