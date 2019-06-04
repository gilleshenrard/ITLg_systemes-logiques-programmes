    /*
 * File:   main.c
 * Author: Gilles
 *
 * Created on January 17, 2019, 3:54 PM
 */

#include "Progr_LCD.h"
#include <math.h>
#include <string.h>

// microcontroller configuration word
#pragma    config	OSC = HSPLL
#pragma    config	FCMEN = OFF
#pragma    config	IESO = OFF
#pragma    config	PWRT = OFF
#pragma    config	BOREN = OFF
#pragma    config	WDT = OFF
#pragma    config	MCLRE = ON
#pragma    config	LVP = OFF
#pragma    config	XINST = OFF

// precompiler definitions
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

#define     POT         0b0000
#define     ADC         0b0001

#define     PI          3.141592
#define     D_PI        6.283184

#define     BUFSZ       3200

char freq_buf[] = "0";
int cutoff = 0;
int FE_choice = 0;
int x0=0, x1=0, prev=0, Al=0, Ah=0, B=0, cur=0, final=0, step=BUFSZ/2;
float k0=0, w0=0, Ahf=0, Alf=0, Bf=0;
int filter=0, delay=0;
char menu[8][17] ={"     Mean 2     ",
                   "     Mean 4     ",
                   "     Mean 8     ",
                   "    Low pass    ",
                   "   High pass    ",
                   "      Echo      ",
                   "      Delay     ",
                   "  Cutoff freq.  "};
unsigned char buf[BUFSZ] = {0};

void init(void);
void run_filter(void);
int get_sample_freq();

/****************************************************************************/
/*  I : /                                                                   */
/*  P : Deals with the timer interruption                                   */
/*  O : /                                                                   */
/****************************************************************************/
void __interrupt(high_priority) Int_Vect_High(void)
{
    LED0 = 1;

    //launch ADC
    ADCON0bits.GO_DONE = 1;
    while(ADCON0bits.GO_DONE);
    
    //inform DAC that we are communicating with him
    CS_DAC = 0;
    SSPBUF=0x10;
    while(!SSPSTATbits.BF);
    //load the DCA value in the SPI output buffer (depending on the filter)
    switch(filter){
        case 0: //low pass filter by two members mean
            x0 = ADRESH;
            SSPBUF = (x0 + x1) >>1;
            x1 = x0;
            break;
            
        case 1: //low pass filter by four members mean
            x0 = ADRESH;
            SSPBUF = (x0 + x1) >>1;
            x1 = x0;
            break;
            
        case 2: //low pass filter by eight members mean
            x0 = ADRESH;
            SSPBUF = (x0 + x1) >>1;
            x1 = x0;
            break;
            
        case 3: //low pass filter AO2
            x0 = ADRESH;
            cur = ((Al*(x0+x1)) + (B*prev)) >> 7;
            SSPBUF = cur + 1;
            prev = cur;
            x1 = x0;
            break;
            
        case 4: //high pass filter AO2
            x0 = ADRESH;
            cur = ((Ah*(x0-x1)) + (B*prev)) >> 7;
            SSPBUF = cur + 127;
            prev = cur;
            x1 = x0;
            break;
            
        case 5: //echo filter
            buf[x0] = ADRESH;
            cur = ((5 * buf[x0]) + (3 * buf[x1])) >> 3;
            SSPBUF = cur + 1;
            x0 = x1;
            x1 = (x1 + 1) % delay;
            break;
        
        default: //#nofilter
            SSPBUF = ADRESH + 1;
            break;
    }
    //wait until the data is ready
    while(!SSPSTATbits.BF);
    //inform DAC that we stop communicating with him
    CS_DAC = 1;
    //send an impulsion to the DAC latch
    LDAC_DAC = 0;
    LDAC_DAC = 1;

    LED0 = 0;
    PIR2bits.CCP2IF = 0;
}

/****************************************************************************/
/*  I : /                                                                   */
/*  P : Main program loop                                                   */
/*  O : /                                                                   */
/****************************************************************************/
void main(void) {
    char tmp = 0;
    float delaytmp = 0.0;
    
    LCDInit();
    init();
    
    //sample frequency setup at boot
    LCDLine_1();
    Msg_Write("sample frequency");
    while(Button_Left){
        //read potentiometer
        ADCON0bits.GO_DONE = 1;
        while(ADCON0bits.GO_DONE);
        FE_choice = ADRESH/128;
        //interpret choice
        if(FE_choice){
            LCDLine_2();
            Msg_Write("     16 kHz     ");
            CCPR2 = CPT16kHz;
        }
        else{
            LCDLine_2();
            Msg_Write("     8 kHz     ");
            CCPR2 = CPT8kHz;
        }
    }
    //debounce button
    Delay_ms(5);
    while(!Button_Left);
    //clear LCD
    LCDLine_1();
    Msg_Write("                ");
    LCDLine_2();
    Msg_Write("                ");
    
    while(1){
        ////////////////////////// MAIN MENU DISPLAY ///////////////////////////
        while(Button_Left){
            //read potentiometer
            ADCON0bits.GO_DONE = 1;
            while(ADCON0bits.GO_DONE);
            filter = ADRESH/32;
            filter = (filter > 7 ? 7 : filter);
            LCDLine_1();
            Msg_Write(menu[filter]);
        }
        //debounce button
        Delay_ms(5);
        while(!Button_Left);
        
        ////////////////////////// MAIN MENU DISPLAY ///////////////////////////
        switch(filter){
            case 0: //2 terms mean low pass filter
                run_filter();
                x0 = 0;
                x1 = 0;
                break;
                
            case 1: //4 terms mean low pass filter
                run_filter();
                x0 = 0;
                x1 = 0;
                break;
                
            case 2: //8 terms mean low pass filter
                run_filter();
                x0 = 0;
                x1 = 0;
                break;
                
            case 3: //low pass filter
                run_filter();
                break;
                
            case 4: //high pass filter
                run_filter();
                break;
                
            case 5: //echo filter
                //force sampling freq. to 8kHz for echo to sound right
                tmp = CCPR2;
                CCPR2 = CPT8kHz;
                
                //reset pointers and variables, then run filter
                x0 = x1 = 0;
                run_filter();
                
                //reset the buffer after use
                memset(&buf, 0, sizeof(buf));
                
                // restore sampling freq. once filter is off
                CCPR2 = tmp;
                break;
                
            case 6: //echo delay choice
                while(Button_Left){
                    //read potentiometer
                    ADCON0bits.GO_DONE = 1;
                    while(ADCON0bits.GO_DONE);
                    delay = ADRESH/16;
                    
                    //compute the echo delay (size of the buffer compared to total size)
                    if(delay > 0)
                        delay = (int)(((float)delay/15.0) * (float)BUFSZ);
                    
                    //compute delay in seconds and print the result on the LCD
                    delaytmp = ((float)delay/(float)BUFSZ)*0.4;
                    sprintf(freq_buf, "      %4.2f s    ", delaytmp);
                    LCDLine_2();
                    Msg_Write(freq_buf);
                }
                //debounce button
                Delay_ms(5);
                while(!Button_Left);
                break;
                
            case 7: //cutoff frequency choice
                while(Button_Left){
                    //read potentiometer
                    ADCON0bits.GO_DONE = 1;
                    while(ADCON0bits.GO_DONE);
                    filter = ADRESH/16;
                    
                    //compute the cutoff frequency according to the pot.
                    cutoff = get_sample_freq();
                    cutoff /= 2;
                    cutoff = (int)((float)cutoff/16.0) * filter;
                    
                    //print the result on the LCD
                    sprintf(freq_buf, "      %4d      ", cutoff);
                    LCDLine_2();
                    Msg_Write(freq_buf);
                }
                //debounce button
                Delay_ms(5);
                while(!Button_Left);
                
                //if cutoff > 0, compute all the components for filter equations
                //  (multiply A and B by 128 to base computation on integers)
                if(cutoff){
                    k0 = (float)cutoff / (float)get_sample_freq();
                    w0 = D_PI * k0;
                    Alf = w0 / (2.0+w0);
                    Ahf = (2.0 / (2.0+w0));
                    Bf  = (2.0-w0) / (2.0+w0);
                    Al = (int)(128.0 * Alf);
                    Ah = (int)(128.0 * Ahf);
                    B = (int)(128.0 * B);
                }
                break;
                
            default: //error
                LED2 = 1;
                LED3 = 1;
                LED4 = 1;
                break;
        }
    }
    return;
}

/****************************************************************************/
/*  I : /                                                                   */
/*  P : PIC18F8722 registers configuration                                  */
/*  O : /                                                                   */
/****************************************************************************/
void init(){
    // disable interruptions + enable high priority
    // (interrupts disabled by default until proper function selected)
    INTCON = 1;
    INTCONbits.GIE = 0;
    RCONbits.IPEN = 1;
    
    // enable timer1 (2*8 bits, timer enabled, prescaler 1:1, rest is unused)
    // + assign timer1 as a source for ECCP2
    T1CON = 0;
    T1CONbits.TMR1ON = 1;
    T3CON = 0;
    
    // enable timer2 (high prio) and ccp2 interrupts and clear interrupt flag
    PIE2bits.CCP2IE = 1;
    PIR2bits.CCP2IF = 0;
    IPR2bits.CCP2IP = 1;
    
    // configure CCP2 module as comparator + enable special trigger
    // + set default timer period to 62.5 us
    CCP2CON = 0;
    CCP2CONbits.CCP2M = 0b1011;
    CCPR2 = CPT16kHz;
    
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
    
    //enable ADC module
    //channel 0 (AN0) = potentiometer R3 on the board
    //channel 1 (AN1) = temperature sensor on the board, used as analog in
    ADCON0 = 0;             
    ADCON0bits.CHS = POT; //select channel 0
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

/****************************************************************************/
/*  I : /                                                                   */
/*  P : launches the running mode                                           */
/*  O : /                                                                   */
/****************************************************************************/
void run_filter(void){
    int tmp = 0;
    
    //inform the filter is running
    LCDLine_2();
    Msg_Write("    Running     ");
    
    //select temp. sensor
    ADCON0bits.CHS = ADC;
    
    //if cutoff frequency = 0, force signal copy instead of filter
    if(!cutoff){
        tmp = filter;
        filter = -1;
    }
    
    //enable timer interrupt
    INTCONbits.GIE = 1;
    
    //wait for button press + debounce
    while(Button_Left);
    Delay_ms(5);
    while(!Button_Left);
    
    //disable timer interrupt
    INTCONbits.GIE = 0;
    
    //restore filter choice
    if(!cutoff)
        filter = tmp;
    
    //clear LCD SPI flag
    LCD_SPI_IF = 0;
    
    //select potentiometer
    ADCON0bits.CHS = POT;
    //clear LCD
    LCDLine_2();
    Msg_Write(freq_buf);
}

/****************************************************************************/
/*  I : /                                                                   */
/*  P : returns the sample frequency as an integer                          */
/*  O : sample frequency                                                    */
/****************************************************************************/
int get_sample_freq(){
    return (CCPR2 == CPT16kHz ? 16000 : 8000);
}