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
#define joystick_1_x_PIN   3  // analog reading for Speed Poti
#define joystick_1_y_PIN   2  // analog reading for Speed Poti
#define clickPin 2   //input for switch

//Timer frequency is 2MHz for ( /8 prescale from 16MHz )
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
int direction = 0;
int last_locoSpeed=0;
int last_direction;
int locoAdr=7;   // this is the (fixed) address of the loco

int joystick_1_x;
int joystick_1_y;
LiquidCrystal lcd(RW_PIN, ENABLE_PIN, 8, 9, 10, 11); //initialize display
testtestestesttesttestestesttesttestestesttesttestestesttesttestestesttesttestestesttesttestestesttesttestestesttesttestestest
