/*----------------------------------------------------------------------
 * Test 04 : E.Bosly 02/2015
 * Test du LCD : header file
 * -------------------------------------------------------------------*/
#include <xc.h>
#include <stdio.h>

/*----------------------------------------------------------------------
 * Définitions
 * -------------------------------------------------------------------*/
#define	LCD_CS			(LATAbits.LATA2)	//LCD chip select
#define	LCD_CS_TRIS		(TRISAbits.TRISA2)	//LCD chip select
#define	LCD_RST			(LATFbits.LATF6)	//LCD chip select
#define	LCD_RST_TRIS    (TRISFbits.TRISF6)	//LCD chip select

#define LCD_TXSTA_TRMT	(TXSTAbits.TRMT)
#define LCD_SPI_IF		(PIR1bits.SSPIF)
#define LCD_SCK_TRIS	(TRISCbits.TRISC3)
#define LCD_SDO_TRIS	(TRISCbits.TRISC5)
#define LCD_SSPBUF		(SSPBUF)
#define LCD_SPICON1		(SSP1CON1)
#define LCD_SPICON1bits (SSP1CON1bits)
#define LCD_SPICON2		(SSP1CON2)
#define LCD_SPISTAT		(SSP1STAT)
#define LCD_SPISTATbits (SSP1STATbits)

/*----------------------------------------------------------------------
 * Protoytypes
 * -------------------------------------------------------------------*/
void d_write(char b);
void i_write(char b);
void LCDLine_1(void);
void LCDLine_2(void);
void LCDClear(void);
void LCDInit(void);

void sendtoLCD(void);

void Delay(void);
void SDelay(void);
void Delay_ms(int t);

void Msg_Write(char * msg);
