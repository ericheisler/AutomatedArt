/*
 * Arduino code for Automate the art
 * A 2016 Hackaday prize entry by shlonkin
 * 
 * First set the pin count and file name below.
 * The file should contain the number of steps(2 bytes)
 * followed by the steps(1 byte each)
 * 
 * The solenoid is driven by PORTC0 which is pin A0(14) on Arduino.
 * The photo interruptor uses INT0 on pin 2.
 * The motor switch is on pin 5
 * The oh-crap-the-thread-ran-out signal is on pin 6
 * 
 * 
 * This code is in the public domain
 */
#include <SPI.h>
#include <SD.h>

// set these parameters for your image
#define PINCOUNT 207
#define fileName "s.art"

// step data buffer size
#define BSIZE 64

// some convenient commands
#define ledOn PORTC |= 0b00000001
#define ledOff PORTC &= 0b11111110
#define solenoidOn PORTC |= 0b00000010
#define solenoidOff PORTC &= 0b11111101
#define MOTORPIN 5
#define OCTTROPIN 6

volatile byte pos;
volatile byte nextPin;
volatile bool pinDone;

unsigned int step, totalSteps;
byte stepBuffer[2][BSIZE];
byte nextBuffer, currentBuffer, bufferIndex;
bool readyToFill;
File sFile;

ISR(INT0_vect){
  // increment pos and if necessary switch on solenoid
  pos++;
  if(pos == PINCOUNT){
    pos = 0;
  }
  if(pos == nextPin){
    solenoidOn;
    pinDone = true;
  }else{
    solenoidOff;
  }
}

void setup() {
  //
  pinMode(14, OUTPUT); // LED
  pinMode(15, OUTPUT); // solenoid
  pinMode(MOTORPIN, OUTPUT); // motor
  pinMode(OCTTROPIN, INPUT_PULLUP); // oh-crap-the-thread-ran-out
  pinMode(2, INPUT); // position sensor
  
  
  pos = 0;
  pinDone = false;

  // open the file on the SD card
  if (!SD.begin(4)){
    errorStop(1); // couldn't initiate SD card
  }
  // open a file
  if(SD.exists(fileName)){
    sFile = SD.open(fileName);
  }else{
    errorStop(2); // file doesn't exist
  }
  if(!sFile){
    errorStop(3); // problem opening file
  }
  
  // read the number of steps (2 bytes)
  totalSteps = sFile.read();
  totalSteps = (totalSteps << 8) + sFile.read();
  
  // fill the first buffer
  nextBuffer = 0;
  currentBuffer = 0;
  int tmp = sFile.available();
  if(tmp < 2){
    // there was no data
    errorStop(4);
  }else if(tmp < BSIZE){
    // the buffer is partially full
    sFile.read(stepBuffer[nextBuffer], tmp);
    nextBuffer = 1;
    readyToFill = false;
  }else{
    // fill it up
    sFile.read(stepBuffer[nextBuffer], BSIZE);
    nextBuffer = 1;
    readyToFill = true;
  }

  // the steps begin at pin 0
  // prepare for the next step
  step = 2;
  bufferIndex = 1;
  nextPin = stepBuffer[currentBuffer][bufferIndex];
  bufferIndex = 2;
  
  EICRA = (1<<ISC00)|(1<<ISC01); // rising on pin 2 triggers interrupt
  EIMSK = (1<<INT0);
  sei();

  // turn on the motor and here we go
  digitalWrite(MOTORPIN, HIGH);
}

void loop() {
  // check for various conditions and take the corresponding actions
  if(pinDone){
    step++;
    if(step > totalSteps){
      // the steps are done
      // turn stop and turn on the LED
      EIMSK = 0;
      digitalWrite(MOTORPIN, LOW);
      solenoidOff;
      ledOn;
      while(true);
    }
    nextPin = getNextPin();
    pinDone = false;
  }
  
  if(readyToFill){
    fillNextBuffer();
  }

  if(!digitalRead(OCTTROPIN)){
    // thread ran out. Just stop
    errorStop(5);
  }
}

byte getNextPin(){
  if(bufferIndex == BSIZE){
    // switch to the next buffer and flag for filling
    if(currentBuffer == 0){
      currentBuffer = 1;
    }else{
      currentBuffer = 0;
    }
    readyToFill = true;
    bufferIndex = 0;
  }
  // return the next byte in the buffer
  bufferIndex++;
  return stepBuffer[currentBuffer][bufferIndex-1];
}

void fillNextBuffer(){
  int tmp = sFile.available();
  if(tmp < 1){
    // there was no data
    // let's assume we're at the end
    // and do nothing
  }else if(tmp < BSIZE){
    // the buffer is partially full
    sFile.read(stepBuffer[nextBuffer], tmp);
    nextBuffer = (nextBuffer+1)%2;
  }else{
    // fill it up
    sFile.read(stepBuffer[nextBuffer], BSIZE);
    nextBuffer = (nextBuffer+1)%2;
  }
  readyToFill = false;
}

void errorStop(int i){
  // just stop and flash the LED
  EIMSK = 0;
  digitalWrite(MOTORPIN, LOW);
  solenoidOff;
  while(true){
    for(int j=0; j<i; j++){
      // led on
      ledOn;
      delay(200);
      // led off
      ledOff;
      delay(200);
    }
    delay(1000);
  }
}

