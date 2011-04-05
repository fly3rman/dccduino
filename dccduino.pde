/*Copyright Dimitri Henning, based on code of 2009 Michael Blank

This program is free software; you can redistribute it and/or modify it under the terms of the 
GNU General Public License as published by the Free Software Foundation; 
either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
See the GNU General Public License for more details.
*/
#include <LiquidCrystal.h>


#define RW_PIN  12 //yellow lcd cable
#define ENABLE_PIN 13 //white lcd cable

#define DCC_PIN    4  // Arduino pin for DCC out 
                     // this pin is connected to "DIRECTION" of LMD18200
#define DCC_PWM    5  // must be HIGH for signal out
                      // connected to "PWM in" of LMD18200
#define joystick_1_x_PIN   3  // analog reading for joystick Poti
#define joystick_1_y_PIN   2  // analog reading for joystick Poti
#define clickPin 2   //input for switch

//Timer frequency is 2MHz for ( /8 prescale from 16MHz )
//Timmer clock = 16MHz/8 = 2MHz oder 0,5usec
#define TIMER_SHORT 0x8D  // 58usec pulse length 
#define TIMER_LONG  0x1B  // 116usec pulse length 

// definitions for state machine 
#define PREAMBLE 0    
#define SEPERATOR 1
#define SENDBYTE  2

unsigned char last_timer=TIMER_SHORT;  // store last timer value   
unsigned char flag=0;  // used for short or long pulse
unsigned char every_second_isr = 0;  // pulse up or down
volatile int timer = 0;  //helping construct for stuff

boolean changed = false;
unsigned char state= PREAMBLE;
unsigned char preamble_count = 16;
unsigned char outbyte = 0;
unsigned char cbit = 0x80;


// variables for throttle
int locoSpeed=0;
int locoSpeed_temp=0;
volatile int direction  = 0;
int last_locoSpeed=0;
int last_direction;
int locoAdr=7;   // this is the (fixed) address of the loco

int joystick_1_x;
int joystick_1_y;
LiquidCrystal lcd(RW_PIN, ENABLE_PIN, 8, 9, 10, 11); //initialize display

// buffer for command
struct Message {
   unsigned char data[7];
   unsigned char len;
} ;

#define MAXMSG  2
// for the time being, use only two messages - the idle msg and the loco Speed msg

struct Message msg[MAXMSG] = { 
    { { 0xFF,     0, 0xFF, 0, 0, 0, 0}, 3},   // idle msg
    { { locoAdr, 0x3F,  0, 0, 0, 0, 0}, 4}    // locoMsg with 128 speed steps
  };               // loco msg must be filled later with speed and XOR data byte
                                
int msgIndex=0;  
int byteIndex=0;


//Setup Timer2.
//Configures the 8-Bit Timer2 to generate an interrupt at the specified frequency.
//Returns the time load value which must be loaded into TCNT2 inside your ISR routine.
void SetupTimer2(){
 
  //Timer2 Settings: Timer Prescaler /8, mode 0
  //Timmer clock = 16MHz/8 = 2MHz oder 0,5usec
  TCCR2A = 0;
  TCCR2B = 0<<CS22 | 1<<CS21 | 0<<CS20; 

  //Timer2 Overflow Interrupt Enable   
  TIMSK2 = 1<<TOIE2;

  //load the timer for its first cycle
  TCNT2=TIMER_SHORT; 

}

//Timer2 overflow interrupt vector handler
ISR(TIMER2_OVF_vect) {
  //Capture the current timer value TCTN2. This is how much error we have
  //due to interrupt latency and the work in this function
  //Reload the timer and correct for latency.  
  // for more info, see http://www.uchobby.com/index.php/2007/11/24/arduino-interrupts/
  unsigned char latency;
  
  // for every second interupt just toggle signal
  if (every_second_isr)  {
     digitalWrite(DCC_PIN,1);
     every_second_isr = 0;    
     
     // set timer to last value
     latency=TCNT2;
     TCNT2=latency+last_timer; 
     
  }  else  {  // != every second interrupt, advance bit or state
     digitalWrite(DCC_PIN,0);
     every_second_isr = 1; 
     
     switch(state)  {
       case PREAMBLE:
           flag=1; // short pulse
           preamble_count--;
           if (preamble_count == 0)  {  // advance to next state
              state = SEPERATOR;
              // get next message
              msgIndex++;
              if (msgIndex >= MAXMSG)  {  msgIndex = 0; }  
              byteIndex = 0; //start msg with byte 0
           }
           break;
        case SEPERATOR:
           flag=0; // long pulse
           // then advance to next state
           state = SENDBYTE;
           // goto next byte ...
           cbit = 0x80;  // send this bit next time first         
           outbyte = msg[msgIndex].data[byteIndex];
           break;
        case SENDBYTE:
           if (outbyte & cbit)  { 
              flag = 1;  // send short pulse
           }  else  {
              flag = 0;  // send long pulse
           }
           cbit = cbit >> 1;
           if (cbit == 0)  {  // last bit sent, is there a next byte?
              byteIndex++;
              if (byteIndex >= msg[msgIndex].len)  {
                 // this was already the XOR byte then advance to preamble
                 state = PREAMBLE;
                 preamble_count = 16;
              }  else  {
                 // send separtor and advance to next byte
                 state = SEPERATOR ;
              }
           }
           break;
     }   
     if (flag)  {  // if data==1 then short pulse
        latency=TCNT2;
        TCNT2=latency+TIMER_SHORT;
        last_timer=TIMER_SHORT;
     }  else  {   // long pulse
        latency=TCNT2;
        TCNT2=latency+TIMER_LONG; 
        last_timer=TIMER_LONG;
     }  
  }
}

void setup(void) {
  //Set the pins for DCC to "output".
  pinMode(DCC_PIN,OUTPUT);   // this is for the DCC Signal
  pinMode(clickPin, INPUT); 
  analogWrite(5, 255);
  assemble_dcc_msg();
  //Start the timer 
  SetupTimer2();  
  
  lcd.begin(20, 4);

    lcd.home();
   
}

void loop(void) {

  if (timer > 0){
    timer=timer-1;
  }


   joystick_1_x = (127L * analogRead(joystick_1_x_PIN))/1023;
   joystick_1_y = (127L * analogRead(joystick_1_y_PIN))/1023;
   lcd.print("    ");
   if (joystick_1_x > 100) {
     locoSpeed = locoSpeed + 3;
   }
   if (joystick_1_x < 30) {
     locoSpeed = locoSpeed - 3;
   }
   if (locoSpeed >127) {
     locoSpeed = 127;
   }
   if (locoSpeed <-127) {
     locoSpeed = -127;
   }
   if (digitalRead(clickPin) == LOW) {
     locoSpeed=0;
   }

delay(10);
lcd.home();
    lcd.print("Geschwindigkeit:");
      lcd.print(locoSpeed);
      lcd.print("   ");
      lcd.setCursor(0,1);
      lcd.print("Richtung:");
      if (locoSpeed == 0)  {
        lcd.print("halt         ");
      }
       if (locoSpeed > 0)  {
        lcd.print("vorwaerts     ");
      }
       if (locoSpeed < 0)  {
        lcd.print("rueckwaerts    ");
      }
    lcd.setCursor(0,2);
    lcd.print("joystick:");
    lcd.print(joystick_1_x);

  assemble_dcc_msg();
}



void assemble_dcc_msg() {
   int i;
   unsigned char data, xdata;
   /*if (locoSpeed == 1)  {  // this would result in emergency stop
      locoSpeed = 0;
   }*/
   // direction info first

   if (locoSpeed < 0) {
     locoSpeed_temp = -locoSpeed;
     data = 0;
     direction = 0;
   } else {
     locoSpeed_temp = locoSpeed;
     data = 0x80; //forward
     direction = 1;
   }
   data |=  locoSpeed_temp;
   // add XOR byte 
   xdata = (msg[1].data[0] ^ msg[1].data[1]) ^ data;
   
   noInterrupts();  // make sure that only "matching" parts of the message are used in ISR
   msg[1].data[2] = data;
   msg[1].data[3] = xdata;
   interrupts();

}