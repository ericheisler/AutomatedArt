/*
 * Arduino code for Automate the art
 * A 2016 Hackaday prize entry by shlonkin
 * 
 * First set the pin count and file name below.
 * The file should contain the number of steps(2 bytes)
 * followed by the steps(1 byte each)
 * 
 * The solenoid is driven by PORTC0 which is pin A0(14) on Arduino.
 * The photo interruptor is on pin 2.
 * The motor switch is on pin 5 with pwm
 * The oh-crap-the-thread-ran-out signal is on pin 6
 * Button is on pin 7
 * 
 * This code is in the public domain
 */
#include <SPI.h>
#include <SD.h>

// set these parameters for your image
uint8_t pinCount;
#define fileName "s.art"

// step data buffer size
#define BSIZE 128

// some convenient commands
#define ledOn PORTC |= 0b00000001
#define ledOff PORTC &= 0b11111110
#define solenoidOn PORTC |= 0b00000010
#define solenoidOff PORTC &= 0b11111101
#define MOTORPIN 5
#define OCTTROPIN 6
#define BUTTONPIN 7

byte pos;
byte nextPin;
bool pinDone, onPin;
unsigned long toc;
unsigned long tic;
byte checkPos;
bool checkReady, checking;

unsigned int step, totalSteps;
byte stepBuffer[2][BSIZE];
byte nextBuffer, currentBuffer, bufferIndex;
bool readyToFill;
File sFile;
int motorSpeed;
bool finished;


void setup() {
  //
  pinMode(14, OUTPUT); // LED
  pinMode(15, OUTPUT); // solenoid
  pinMode(MOTORPIN, OUTPUT); // motor
  pinMode(OCTTROPIN, INPUT_PULLUP); // oh-crap-the-thread-ran-out
  pinMode(BUTTONPIN, INPUT_PULLUP); // button
  pinMode(2, INPUT); // position sensor
  
  
  pos = 0;
  pinDone = false;
  onPin = false;
  finished = false;
  checkPos = 0;
  checkReady = false;
  checking = false;

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

  // read the number of pins
  pinCount = sFile.read();
  
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

  // wait for the button to be pressed and released to start
  while(digitalRead(BUTTONPIN));
  // debounce and wait for release
  delay(50);
  while(!digitalRead(BUTTONPIN));
  delay(50);
  
  // turn on the motor and here we go
  motorSpeed = 160;
  analogWrite(MOTORPIN, motorSpeed);
  tic = millis();
  toc = tic;
}

void loop() {
  // check the position encoder
  if(PIND&4){
    if(!onPin){
      // ignore signals that are less than a reasonable time apart
      if(millis()-toc > 10){
        onPin = true;
        pos++;
        if(pos == pinCount){
          pos = 0;
        }
        if(pos == nextPin){
          solenoidOn;
          pinDone = true;
        }else{
          solenoidOff;
        }
        toc = millis();
      }
      
    }
    
  }else{
    onPin = false;
  }
  
  // check for various conditions and take the corresponding actions
  // If the solenoid has been triggered, load the next pin.
  if(pinDone){
    step++;
    if(step > totalSteps){
      // the steps are done
      // let it wrap around the last pin before stopping
      finished = true;
      toc = tic;
    }
    nextPin = getNextPin();
    pinDone = false;
  }

  // When fniished, wait for the next pin to pass, then shut down
  if(finished && (toc > tic)){
    // stop and turn on the LED
    analogWrite(MOTORPIN, 0);
    digitalWrite(MOTORPIN, LOW);
    solenoidOff;
    ledOn;
    sFile.close();
    
    while(true);
  }

  if(digitalRead(OCTTROPIN)){
    // not the OCTTRO sensor
    // makes sure the pos is not getting too far off
    if(!checking){
      checking = true;
      if(checkReady){
        if(pos == checkPos){
          // we're good to go
          ledOff;
        }else{
          // it got off somewhere
          // brutally smack the thing back into place
          pos = checkPos;
          ledOn;
        }
      }else{
        checkReady = true;
        checkPos = pos;
      }
    }
  }else{
    // reset checking
    checking = false;
  }

  if(!digitalRead(BUTTONPIN)){
    // nothing here yet
  }

  // check speed and adjust motor speed accordingly
  if(toc > tic){
    if(toc-tic > 40){
      // speed up
      motorSpeed ++;
      if(motorSpeed > 255){
        motorSpeed = 255;
      }
    }else if(toc-tic < 30){
      // slow down
      motorSpeed --;
      if(motorSpeed < 100){
        motorSpeed = 100;
      }
    }
    analogWrite(MOTORPIN, motorSpeed);
    tic = toc;
  }else if(millis() - tic > 500){
    // it's probably stalled, boost the power a chunk
    motorSpeed += 20;
    if(motorSpeed > 255){
      motorSpeed = 255;
    }
    analogWrite(MOTORPIN, motorSpeed);
    tic = millis();
    toc = tic;
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
    bufferIndex = 0;
    fillNextBuffer(); 
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
  analogWrite(MOTORPIN, 0);
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

