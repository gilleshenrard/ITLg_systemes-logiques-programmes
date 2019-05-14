/*----------------------------------------------------------------------
 * Test 04 : E.Bosly 02/2015
 * Librairie LCD
 * -------------------------------------------------------------------*/
#include "Progr_LCD.h"

/*----------------------------------------------------------------------
 * LCD busy delay
 * -------------------------------------------------------------------*/
void LCDBusy(void) {
    SDelay();
    SDelay();
}

/*----------------------------------------------------------------------
 * Write to MCP923S17 Port A
 * -------------------------------------------------------------------*/
void WritePortA(char b) {
    LCD_CS = 0;

    LCD_SSPBUF = 0x40;
    while (!LCD_SPI_IF);
    LCD_SPI_IF = 0;

    LCD_SSPBUF = 0x12;
    while (!LCD_SPI_IF);
    LCD_SPI_IF = 0;

    LCD_SSPBUF = b;
    while (!LCD_SPI_IF);
    LCD_SPI_IF = 0;

    LCD_CS = 1;
}
/*----------------------------------------------------------------------
 * Write to MCP923S17 Port B
 * -------------------------------------------------------------------*/
void WritePortB(char b) {
    LCD_CS = 0;

    LCD_SSPBUF = 0x40;
    while (!LCD_SPI_IF);
    LCD_SPI_IF = 0;

    LCD_SSPBUF = 0x13;
    while (!LCD_SPI_IF);
    LCD_SPI_IF = 0;

    LCD_SSPBUF = b;
    while (!LCD_SPI_IF);
    LCD_SPI_IF = 0;

    LCD_CS = 1;
}

/*----------------------------------------------------------------------
 * Write the data to the display
 * -------------------------------------------------------------------*/
void d_write(char b) {
    WritePortA(0x80);
    LCDBusy();
    WritePortB(b);
    Nop();
    Nop();
    Nop();
    Nop();
    WritePortA(0xC0);
    Nop();
    Nop();
    Nop();
    Nop();
    Nop();
    Nop();
    WritePortA(0x00);
//    TXREG = b; //carriage return
//    while (!LCD_TXSTA_TRMT); //wait for data TX
//    LCD_TXSTA_TRMT = 0;
}

/*----------------------------------------------------------------------
 * Send a instruction to the display
 * -------------------------------------------------------------------*/
void i_write(char b) {
    WritePortA(0x00);
    LCDBusy();
    WritePortB(b);
    Nop();
    Nop();
    Nop();
    Nop();
    WritePortA(0x40);
    Nop();
    Nop();
    Nop();
    Nop();
    Nop();
    Nop();
    WritePortA(0x00);
}

/*----------------------------------------------------------------------
 * Write to line 2 of the display
 * -------------------------------------------------------------------*/
void LCDLine_1(void) {
    i_write(0x80);
}

/*----------------------------------------------------------------------
 * Write to line 2 of the display
 * -------------------------------------------------------------------*/
void LCDLine_2(void) {
    i_write(0xC0);
}

/*----------------------------------------------------------------------
 * To clear the display
 * -------------------------------------------------------------------*/
void LCDClear(void) {
    i_write(0x01);
}

/*----------------------------------------------------------------------
 * Function to write to the PORT
 * -------------------------------------------------------------------*/
void InitWrite(char b) {
    WritePortA(0);
    WritePortB(b);
    Nop();
    Nop();
    Nop();
    WritePortA(0x40);
    Nop();
    Nop();
    Nop();
    Nop();
    Nop();
    Nop();
    Nop();
    Nop();
    Nop();
    WritePortA(0);
}

/*----------------------------------------------------------------------
 * Initialize MCP923S17 Port A
 * -------------------------------------------------------------------*/
void InitPortA_SPI(char b) {
    LCD_CS = 0;
    LCD_SSPBUF = 0x40;
    while (!LCD_SPI_IF);
    LCD_SPI_IF = 0;

    LCD_SSPBUF = 0x00;
    while (!LCD_SPI_IF);
    LCD_SPI_IF = 0;

    LCD_SSPBUF = b;
    while (!LCD_SPI_IF);
    LCD_SPI_IF = 0;

    LCD_CS = 1;
}

/*----------------------------------------------------------------------
 * Initialize MCP923S17 Port B
 * -------------------------------------------------------------------*/
void InitPortB_SPI(char b) {
    LCD_CS = 0;
    LCD_SSPBUF = 0x40;
    while (!LCD_SPI_IF);
    LCD_SPI_IF = 0;

    LCD_SSPBUF = 0x01;
    while (!LCD_SPI_IF);
    LCD_SPI_IF = 0;

    LCD_SSPBUF = b;
    while (!LCD_SPI_IF);
    LCD_SPI_IF = 0;

    LCD_CS = 1;
}

/*----------------------------------------------------------------------
 * Initialize MCP923S17 SPI
 * -------------------------------------------------------------------*/
void InitSPI(void) {
    LCD_SCK_TRIS = 0;
    LCD_SDO_TRIS = 0;

    LCD_SPICON1 = 0x22;
    LCD_SPISTATbits.CKE = 1;
    //LCD_SPISTATbits.SMP = 0;
    LCD_SPI_IF = 0;
}

/*----------------------------------------------------------------------
 * LCD Initialization function
 * -------------------------------------------------------------------*/
void LCDInit(void) {
    LCD_CS_TRIS = 0;
    LCD_CS = 1;
    Delay();
    Delay();
    Delay();

    LCD_RST_TRIS = 0;
    LCD_RST = 0;
    Delay();
    LCD_RST = 1;
    
    InitSPI();
    InitPortA_SPI(0);
    InitPortB_SPI(0);

    WritePortA(0);

    Delay();
    InitWrite(0x3C); //0011NFxx

    Delay();
    InitWrite(0x0C); //Display Off

    Delay();
    InitWrite(0x01); //Display Clear

    Delay();
    InitWrite(0x06); //Entry mode
}

/*----------------------------------------------------------------------
 * Send string to LCD - EB
 * -------------------------------------------------------------------*/
void sendtoLCD(void) {

    LCDLine_1();
    d_write('L');
    d_write('1');

    LCDLine_2();
    d_write('L');
    d_write('2');

    return;
}

/*----------------------------------------------------------------------
 * Delais en msec
 * -------------------------------------------------------------------*/
void Delay_ms(int t) // t * 1 msec
{
    int i, j;
    for (i = 0; i < t; i++)
        for (j = 0; j < 830; j++);
    return;
}

void Delay(void)
{
    Nop();
    Nop();
    Nop();
    return;
}

void SDelay(void)
{
    return;
}

/*----------------------------------------------------------------------
 * Ecrire la chaine msg au curseur courant
 * -------------------------------------------------------------------*/
void Msg_Write(char * msg)
{
    int i=0;

    while (msg[i]) d_write(msg[i++]);

    return;
}
