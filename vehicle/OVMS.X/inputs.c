/*
;    Project:       Open Vehicle Monitor System
;    Date:          16 October 2011
;
;    Changes:
;    1.0  Initial release
;
;    (C) 2011  Michael Stegen / Stegen Electronics
;    (C) 2011  Mark Webb-Johnson
;    (C) 2011  Sonny Chen @ EPRO/DX
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in
; all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
; THE SOFTWARE.
*/

#include "ovms.h"
#include "inputs.h"

void inputs_initialise(void)
  {
  TRISA = 0xFF;
#ifdef OVMS_HW_V1
  PORTA = 0x00; // Initialise port A
  ADCON1 = 0x0F; // Switch off A/D converter
#elif OVMS_HW_V2
   // We use default value for +/- Vref
   // VCFG0=0,VCFG1=0
   // That means +Vref = Vdd (5v) and -Vref=GEN
   ADCON1=0b00001110;
   // ADCON2
   //   ADC Result Right Justified.
   //   Conversion Clock = 32 Tosc => TAD = 1.6 us
   //   Automatic Acquisition Time = 20 TAD = 32 us
   ADCON2=0b10111010;
#endif // #ifdef OVMS_HW_??
  // set PORTC outputs we manage low so they're in a consistent state on startup
  PORTC &= 0b11110000;
  // switch PORTC outputs we manage to output mode
  TRISC &= 0b11110000;
  }

unsigned char inputs_gsmgprs(void)
  {
#ifdef OVMS_HW_V1
  return (PORTAbits.RA0==0); // Switch (RA bit 0) is set to GPRS mode
#elif OVMS_HW_V2
  return (PORTAbits.RA1==0); // Switch (RA bit 1) is set to GPRS mode
#endif // #ifdef OVMS_HW_??
  }

#ifdef OVMS_HW_V2

#ifndef OVMS_NO_GPIOFN
unsigned char input_gpi2(void)
  {
  return (PORTAbits.RA2==0);
  }

unsigned char input_gpi3(void)
  {
  return (PORTAbits.RA3==0);
  }

unsigned char input_gpi4(void)
  {
  return (PORTAbits.RA4==0);
  }

unsigned char input_gpi5(void)
  {
  return (PORTAbits.RA5==0);
  }

unsigned char output_gpo0(unsigned char onoff)
  {
  PORTCbits.RC0 = onoff;
  }

unsigned char output_gpo1(unsigned char onoff)
  {
  PORTCbits.RC1 = onoff;
  }

unsigned char output_gpo2(unsigned char onoff)
  {
  PORTCbits.RC2 = onoff;
  }

unsigned char output_gpo3(unsigned char onoff)
  {
  PORTCbits.RC3 = onoff;
  }
#endif

float inputs_voltage(void)
  {
  ADCON0=0;   //Select ADC Channel #0
  ADCON0bits.ADON=1;  //switch on the adc module
  ADCON0bits.GO=1;  //Start conversion
  while(ADCON0bits.GO); //wait for the conversion to finish
  ADCON0bits.ADON=0;  //switch off adc

  return (0.0+ADRES)/47.0;
  }

#endif // #ifdef OVMS_HW_V2
