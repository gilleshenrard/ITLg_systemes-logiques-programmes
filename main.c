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
#define     BUFFER_SZ   128

#define     SDO         PORTCbits.RC5
#define     SCK         PORTCbits.RC3
#define     CS_DAC      PORTCbits.RC2
#define     LDAC_DAC    PORTCbits.RC0

#define     PI          3.141592
#define     D_PI         6.283184

int _8MHz=1;
int tick=0;
int duty=0;
int freq_divider=1;
int selection=0;
int select_settings=0;
int selected=0;
int data_buffer[BUFFER_SZ]={0};
int data_ptr = 0;

unsigned char test = 0;

char msg_buffer[17] = {0};
char msg_processing[17] = {" Processing...  "};
char msg_exit[17] = {"Stop            "};
char msg_confirm[17] = {"     Done !     "};
char main_menu[4][17]={ "     Square     ",
                        "      Sine      ",
                        "    Triangle    ",
                        "    Settings    "};

char settings_menu[2][17]={ "  Freq. divider ",
                            "   Duty Cycle   "};

void init(void);

void __interrupt(high_priority) Int_Vect_High(void)
{
    LED0 = 1;
    if(!_8MHz || (_8MHz && !(tick%2))){
        //inform DAC that we are communicating with him
        CS_DAC = 0;
        SSPBUF=0x10;
        while(!SSPSTATbits.BF){}
        //load the current data value in the SPI output buffer
        SSPBUF = data_buffer[data_ptr];
        //wait until the data is ready
        while(!SSPSTATbits.BF){}
        //inform DAC that we stop communicating with him
        CS_DAC = 1;
        //send an impulsion to the DAC latch
        LDAC_DAC = 0;
        LDAC_DAC = 1;

        data_ptr += 1;
        data_ptr %= BUFFER_SZ;
    }
    tick++;
    tick %= 2;
    LED0 = 0;
    PIR1bits.CCP1IF = 0;
}

void main(void) {
    init();
    
    LCDInit();
    
    while(1)
    {   
        ///////////////////////////////////////////////////////////////////
        //////////////////////// Main menu ////////////////////////////////
        ///////////////////////////////////////////////////////////////////
        //print the second line for the main menu
        LCDClear();
        LCDLine_2();
        Msg_Write("Select    Change");
        
        //wait for a selection
        selected = 0;
        while(!selected){
            //Display the main menu
            LCDLine_1();
            Msg_Write(main_menu[selection]);
           
            //if right button is pressed, debounce and scroll through options
            if(!Button_Right){
                Delay_ms(5);
                while(!Button_Right){}
                selection += 1;
                selection %= 4;
            }
           
            //if left button is pressed, debounce and set selection
            if(!Button_Left){
                Delay_ms(5);
                while(!Button_Left){}
                selected = 1;
            }
        }
        
        ///////////////////////////////////////////////////////////////////
        //////////////////////// Actual functions /////////////////////////
        ///////////////////////////////////////////////////////////////////
        
        switch(selection){
            case 0: //square wave
                LCDClear();
                LCDLine_1();
                Msg_Write(msg_processing);
                for(int i=0 ; i<BUFFER_SZ ; i++){
                    data_buffer[i] = i < ((float)duty/100)*BUFFER_SZ ? 0xFF : 0x00;
                }
                
                LCDClear();
                LCDLine_1();
                Msg_Write(msg_confirm);
                LCDLine_2();
                Msg_Write(msg_exit);
                //buffer is filled -> enable interrupts to send values
                //  via SPI to the DAC
                INTCONbits.GIE = 1;
                //wait for button to be pressed
                while(Button_Left){}
                //debounce, disable interrupts and reset data pointer
                Delay_ms(5);
                while(!Button_Left){}
                INTCONbits.GIE = 0;
                
                data_ptr = 0;
                break;
                
            case 1: //sine wave
                LCDClear();
                LCDLine_1();
                Msg_Write(msg_processing);
                for(int i=0 ; i<BUFFER_SZ ; i++){
                    data_buffer[i] = (int)(128.0 + 127.0*sin((D_PI*(float)freq_divider*(float)i)/(float)BUFFER_SZ));
                }
                
                LCDClear();
                LCDLine_1();
                Msg_Write(msg_confirm);
                LCDLine_2();
                Msg_Write(msg_exit);
                //buffer is filled -> enable interrupts to send values
                //  via SPI to the DAC
                INTCONbits.GIE = 1;
                //wait for button to be pressed
                while(Button_Left){}
                //debounce, disable interrupts and reset data pointer
                Delay_ms(5);
                while(!Button_Left){}
                INTCONbits.GIE = 0;
                
                data_ptr = 0;
                break;
                
            case 2: //triangle wave
                LCDClear();
                LCDLine_1();
                Msg_Write(msg_processing);
                Delay_ms(1000);
                break;
                
            case 3: //settings
                selected = 0;
                while(!selected){
                    //Display the settings menu
                    LCDLine_1();
                    Msg_Write(settings_menu[select_settings]);

                    //if right button is pressed, debounce and set selection
                    if(!Button_Right){
                        Delay_ms(5);
                        while(!Button_Right){}
                        select_settings += 1;
                        select_settings %= 2;
                    }

                    //if left button is pressed, debounce and scroll through options
                    if(!Button_Left){
                        Delay_ms(5);
                        while(!Button_Left){}
                        selected = 1;
                    }
                }
                
                //has settings option been selected ?
                selected = 0;
                while(!selected){
                    // option has been selected
                    if(select_settings == 0){
                        LCDLine_2();
                        sprintf(msg_buffer, "Div. value : %d  ", freq_divider);
                        Msg_Write(msg_buffer);
                        selected = 0;
                        while(!selected){
                            //if right button is pressed, debounce and set selection
                            if(!Button_Right){
                                Delay_ms(5);
                                while(!Button_Right){}
                                freq_divider *= 2;
                                freq_divider = (freq_divider == 16 ? 1 : freq_divider);
                            
                                LCDLine_2();
                                sprintf(msg_buffer, "Div. value : %d  ", freq_divider);
                                Msg_Write(msg_buffer);
                            }

                            //if left button is pressed, debounce and scroll through options
                            if(!Button_Left){
                                Delay_ms(5);
                                while(!Button_Left){}
                                selected = 1;
                            }
                        }
                    }
                    else if(select_settings == 1){
                        LCDLine_2();
                        sprintf(msg_buffer, "DC value : %d%   ", duty);
                        Msg_Write(msg_buffer);
                        selected = 0;
                        while(!selected){
                            //if right button is pressed, debounce and set selection
                            if(!Button_Right){
                                Delay_ms(5);
                                while(!Button_Right){}
                                duty += 10;
                                duty %= 100;
                            
                                LCDLine_2();
                                sprintf(msg_buffer, "DC value : %d%   ", duty);
                                Msg_Write(msg_buffer);
                            }

                            //if left button is pressed, debounce and scroll through options
                            if(!Button_Left){
                                Delay_ms(5);
                                while(!Button_Left){}
                                selected = 1;
                            }
                        }
                    }
                }
                break;
                
            default: //error
                LCDClear();
                LCDLine_1();
                Msg_Write("     ERROR      ");
                break;
        }
    }
    return;
}

void init(){
    // disable interruptions + enable high priority
    // (interrupts disabled by default until proper function selected)
    INTCON = 0;
    INTCONbits.GIE = 0;
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
    // + set time interval value to 271 (1 int. every 62.5 us)
    CCPR1H = 0x02;
    CCPR1L = 0x71;
    
    // assign timer1 as a source for ECCP1
    T3CON = 0;
    T3CONbits.T3CCP1 = 0;
    T3CONbits.T3CCP2 = 1;
    
    //set RB0 and RA5 as inputs (buttons)
    TRISBbits.TRISB0 = 1;
    Button_Left = 0;
    TRISAbits.TRISA5 = 1;
    Button_Right = 0;
    
    //set PortD as output (leds)
    TRISD = 0;
    PORTD = 0;
    
    //enable ADC module and select AN0 (potentiometer R3 on the board)
    ADCON0 &= 0b11000011;   //select AN0 channel
    ADCON0bits.ADON = 1;    //enable ADC
    ADCON0bits.GO_DONE = 0; //clear conversion status flag
    
    //configure ADC module operation
    ADCON1 = 0b00001011;    //select internal voltage references
                            //  + set AN[0:3] as analog and rest as digital
    
    //configure ADC justification
    ADCON2bits.ADFM = 0;    //set AN0 as left justified
    
    //clear ADC data registers
    ADRESH = 0;
    ADRESL = 0;
    
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
}
