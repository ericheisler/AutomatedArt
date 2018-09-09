/*
  Processing sketch for "Automate the art"
  A 2016 Hackaday prize entry by shlonkin
  
  When running the sketch:
  1. Select an image file to use.
  2. Set the various parameters by clicking.
  3. Select a circular region by pressing the mouse in the center of the circle
     and dragging it to the desired size.
  4. Click the "set circle" button.
  5. If you are ready, click the "compute" button.
  6. wait.
  7. Clicking the "display" button will show different things.
  8. Clicking the save button will produce a file for use with the matching
     Arduino sketch.
  
  NOTE: 
    A selected region with diameter of about 500 to 800 pixels works well.
    Resize your image to allow that for best results.
    
    Adjusting some parameters requires recalculation, so it may take 
    a while to update the display.
  
  This code is in the public domain
*/

// These parameters can only be set here
int pinCount = 193;
int maxStepCount = 6000;

// These can be set while running the sketch
int fade = 50;
int opacity = 160;
int ignoreDist = 30;
int stepCount = 2000; //must be less than maxStepCount
int resolution = 400; // number of pixels in the diameter of the circle

String fileName, outputFileName, loadFileName;
boolean fileSelectedRun;

PImage pic, pic2;
short[] steps = new short[maxStepCount];
int[][] pinsXY = new int[pinCount][2];

int[][][] paths; // this can get big. You may need to increase allowed memory size
int[][] pathLengths;

int circleX, circleY, circleRadius;
int circleX2, circleY2, circleRadius2; // for the resized picture
char circleCentered, circleSet, circlePinned, pinsShifted, stepsDone, withPic, pathsDone;

float picScale, picScale2;
int picX, picY;

float totalLength;


void setup(){
  size(950, 850);
  picX = 80;
  picY = 80;
  
  // select the image file
  fileName = null;
  while(fileName == null){
    fileSelectedRun = false;
    selectInput("Select an image file", "fileSelected", new File(sketchPath("select an image file")));
    println("waiting");
    while(!fileSelectedRun){
      delay(500);
      print(".");
    }
    println("waiting2");
  }
  println("file selected");
  // load the picture
  pic = loadImage(fileName);
  println("pic loaded");
  if(pic.width > pic.height){
    picScale = (width-picX)*1.0/pic.width;
    image(pic, picX, picY, width-picX, pic.height*picScale);
  }else{
    picScale = (height-picY)*1.0/pic.height;
    image(pic, picX, picY, pic.width*picScale, height-picY);
  }
  pic.filter(GRAY);
  
  circleCentered = 0;
  circleSet = 0;
  circlePinned = 0;
  pinsShifted = 0;
  stepsDone = 0;
  withPic = 0;
  pathsDone = 0;
  totalLength = 0;
  ellipseMode(RADIUS);
}

void draw(){
  background(255);
  
  //These are the various contols ////////////////////////////////
  fill(150);
  stroke(0);
  // reset button
  rect(0,picY,picX,30);
  
  // set circle button
  // this button computes the pin points and converts the circle to gray
  rect(0, picY+30, picX, 30);
  
  // this button computes the steps
  rect(0, picY+60, picX, 30);
  
  // this button displays the picture in the background
  rect(0, picY+90, picX, 30);
  
  // this button saves the data file
  rect(0, picY+120, picX, 30);
  
  // this button reads a data file
  rect(0, picY+150, picX, 30);
  
  // this is the transparency of the lines
  rect(100 + opacity*(width-100-20)/255, 0, 20, 20);
  
  // this is the amount paths fade the image
  rect(100 + fade*(width-100-20)/255, 20, 20, 20);
  line(0, 20, width, 20);
  
  // this is the ignore distance
  rect(100 + ignoreDist*(width-100-20)/(pinCount/2), 40, 20, 20);
  line(0, 40, width, 40);
  
  // this is the line count
  rect(100 + (stepCount*(width-100-20))/maxStepCount, 60, 20, 20);
  line(0, 60, width, 60);
  line(100, 0, 100, picY);
  
  // labels
  fill(0);
  textSize(12);
  text("reset", 5, picY+20);
  text("set circle", 5, picY+50);
  text("compute", 5, picY+80);
  text("display", 5, picY+110);
  text("save data", 5, picY+140);
  text("load data", 5, picY+170);
  text("darkness", 5, 18);
  text(opacity, 70, 18);
  text("fade ", 5, 38);
  text(fade, 70, 38);
  text("min dist.", 5, 58);
  text(ignoreDist, 70, 58);
  text("lines", 5, 78);
  text(stepCount, 70, 78);
  
  text("length", 5, picY + 200);
  text(totalLength, 5, picY + 220);
  text("(x diameter)", 5, picY + 240);
  text("resolution", 5, picY + 260);
  text(resolution, 5, picY + 280);
  
  if(stepsDone > 0){
    stroke(0, opacity);
    strokeWeight(1);
    
    if(withPic == 1){
      image(pic2, picX, picY, height-picY, height-picY);
      for(int i=1; i<stepCount; i++){
        line(picX + pinsXY[steps[i-1]][0]*picScale2, picY + pinsXY[steps[i-1]][1]*picScale2, picX + pinsXY[steps[i]][0]*picScale2, picY + pinsXY[steps[i]][1]*picScale2);
      }
    }else if(withPic == 0){
      fill(255);
      rect(picX, picY, height-picY, height-picY);
      for(int i=1; i<stepCount; i++){
        line(picX + pinsXY[steps[i-1]][0]*picScale2, picY + pinsXY[steps[i-1]][1]*picScale2, picX + pinsXY[steps[i]][0]*picScale2, picY + pinsXY[steps[i]][1]*picScale2);
      }
    }else{
      image(pic2, picX, picY, height-picY, height-picY);
    }
    
    for(int i=0; i<pinCount; i++){
      rect(picX + pinsXY[i][0]*picScale2, picY + pinsXY[i][1]*picScale2, 1, 1);
    }
    
  }else if(circlePinned > 0){
    if(pic.width > pic.height){
      image(pic, picX, picY, width-picX, pic.height*picScale);
    }else{
      image(pic, picX, picY, pic.width*picScale, height-picY);
    }
    // draw the pin locations
    // note that pins are in pic pixels not display pixels
    stroke(0);
    strokeWeight(1);
    for(int i=0; i<pinCount; i++){
      rect(picX + pinsXY[i][0]*picScale, picY + pinsXY[i][1]*picScale, 1, 1);
    }
  }else if(circleCentered > 0){
    if(pic.width > pic.height){
      image(pic, picX, picY, width-picX, pic.height*picScale);
    }else{
      image(pic, picX, picY, pic.width*picScale, height-picY);
    }
    stroke(0);
    noFill();
    strokeWeight(2);
    ellipse(circleX*picScale + picX, circleY*picScale + picY, circleRadius*picScale, circleRadius*picScale);
  }else{
    if(pic.width > pic.height){
      image(pic, picX, picY, width-picX, pic.height*picScale);
    }else{
      image(pic, picX, picY, pic.width*picScale, height-picY);
    }
  }
  
  
}

void fileSelected(File f){
  println("fs");
  if(f != null){
    fileName = f.getName();
  }
  fileSelectedRun = true;
  println("fs2");
}

void mousePressed(){
  // first handle buttons
  if(mouseX < picX){
    if(mouseY < picY + 30){
      circleCentered = 0;
      circleSet = 0;
      circlePinned = 0;
      pinsShifted = 0;
      stepsDone = 0;
      withPic = 0;
      pathsDone = 0;
      pic = loadImage(fileName);
      if(pic.width > pic.height){
        image(pic, picX, picY, width-picX, pic.height*picScale);
      }else{
        image(pic, picX, picY, pic.width*picScale, height-picY);
      }
      pic.filter(GRAY);
      return;
    }else if(mouseY < picY + 60){
      if(circlePinned < 1){
        pinCircle();
        circlePinned = 1;
      }
    }else if(mouseY < picY + 90){
      if(stepsDone < 1){
        computeSteps();
        stepsDone = 1;
      }
    }else if(mouseY < picY + 120){
      withPic++;
      if(withPic > 2){
        withPic = 0;
      }
    }else if(mouseY < picY + 150){
      saveFile();
    }else if(mouseY < picY + 180){
      loadFile();
    }
  }else if(mouseX < 100){
    // this is the label area
  }else if(mouseY < 20){
    opacity = (mouseX-100)*255/(width-100-20);
  }else if(mouseY < 40){
    fade = (mouseX-100)*255/(width-100-20);
    // have to recompute
    if(stepsDone > 0){
      computeSteps();
    }
    
  }else if(mouseY < 60){
    ignoreDist = (mouseX-100)*(pinCount/2)/(width-100-20);
    // have to recompute
    if(stepsDone > 0){
      computeSteps();
    }
    
  }else if(mouseY < picY){
    int tmpstepCount = ((mouseX-100)*maxStepCount)/(width-100-20);
    if(tmpstepCount > stepCount){
      // recomupte
      // yes, I know this is unnecessary, but I'm lazy
      if(stepsDone > 0){
        computeSteps();
      }
    }
    stepCount = tmpstepCount;
  }else if(circleCentered < 1){
    // set the circle center
    circleX = round((mouseX - picX)*1.0/picScale);
    circleY = round((mouseY - picY)*1.0/picScale);
    circleCentered = 1;
  }
  
}

void mouseDragged(){
  if(circleCentered < 1){
    return;
  }
  if(circleSet < 1){
    circleRadius = max(abs(round((mouseX-picX)*1.0/picScale) - circleX), abs(round((mouseY-picY)*1.0/picScale) - circleY));
  }
  
}

void mouseReleased(){
  if(circleCentered < 1){
    return;
  }
  if(circleSet < 1){
    circleRadius = max(abs(round((mouseX-picX)*1.0/picScale) - circleX), abs(round((mouseY-picY)*1.0/picScale) - circleY));
    circleSet = 1;
  }
}

void pinCircle(){
  color white = color(255);
  for(int i=0; i<pic.width; i++){
    for(int j=0; j<pic.height; j++){
      if((((circleX-i)*(circleX-i)) + ((circleY-j)*(circleY-j))) > circleRadius*circleRadius){
        pic.set(i, j, white);
      }
    }
  }
  updatePixels();
  
  // compute the pin locations
  // angle between each is ...
  // start at the right and follow standard orientation
  float angle = PI*2.0/pinCount;
  for(int i=0; i<pinCount; i++){
    pinsXY[i][0] = round(circleX + circleRadius * cos(i*angle));
    pinsXY[i][1] = round(circleY - circleRadius * sin(i*angle));
  }
}

void keyPressed(){
  if(keyCode == UP){
    if(resolution < 1000){
      resolution += 50;
      
      pinCircle();
      pinsShifted = 0;
      pathsDone = 0;
      computeSteps();
    }
  }else if(keyCode == DOWN){
    if(resolution > 50){
      resolution -= 50;
      
      pinCircle();
      pinsShifted = 0;
      pathsDone = 0;
      computeSteps();
    }
  }
}

void computeSteps(){
  // work with a copy of the pic
  pic2 = createImage(circleRadius*2+2, circleRadius*2+2, RGB);
  pic2.copy(pic, round(circleX - circleRadius), round(circleY - circleRadius), circleRadius*2+2, circleRadius*2+2, 0, 0, circleRadius*2+2, circleRadius*2+2);
  pic2.filter(INVERT);
  pic2.resize(resolution, resolution);
  pic2.loadPixels();
  println(pic2.pixels.length);
  picScale2 = (height-picY)*1.0/(resolution);
  circleRadius2 = resolution/2;
  circleX2 = circleRadius2;
  circleY2 = circleX2;
  
  long[] sum = new long[pinCount];
  
  // shift all the pin locations
  if(pinsShifted < 1){
    float angle = PI*2.0/pinCount;
    for(int i=0; i<pinCount; i++){
      pinsXY[i][0] = round(circleX2 + (circleRadius2-1) * cos(i*angle));
      pinsXY[i][1] = round(circleY2 - (circleRadius2-1) * sin(i*angle));
    }
    pinsShifted = 1;
  }
  
  
  // compute paths if not done
  if(pathsDone < 1){
    getPaths();
    pathsDone = 1;
  }
  
  // now perform the steps
  // compute average "darkness" along each possible path and choose the darkest
  // then lighten the chosen path a little
  // start at pin 0
  steps[0] = 0;
  totalLength = 0;
  long maxSum;
  short maxIndex;
  boolean ignore;
  for(int i=1; i<stepCount; i++){
    // sum all the gray values over the line to each other pin
    maxSum = 0;
    maxIndex = 100;
    ignore = false;
    for(int j=0; j<pinCount; j++){
      sum[j] = 0;
      int d = 0;
      // ignore pins within some distance
      ignore = false;
      if(j < steps[i-1]){
        if(steps[i-1]-j < ignoreDist){
          ignore = true;
        }
      }else{
        if(j-steps[i-1] < ignoreDist){
          ignore = true;
        }
      }
      if((steps[i-1] < ignoreDist) && (j > pinCount-ignoreDist + steps[i-1])){
        ignore = true;
      }else if((steps[i-1] > pinCount-ignoreDist) && (j < ignoreDist - (pinCount-steps[i-1]))){
        ignore = true;
      }
      
      // skip the ignored pins
      if((j != steps[i-1]) && (!ignore)){
        if(steps[i-1] > j){
          for(int k=0; k<pathLengths[j][steps[i-1]-j-1]; k++){
            sum[j] += pic2.pixels[paths[j][steps[i-1]-j-1][k]] & 0xFF;
            d++;
          }
        }else if(steps[i-1] < j){
          for(int k=0; k<pathLengths[steps[i-1]][j-steps[i-1]-1]; k++){
            sum[j] += pic2.pixels[paths[steps[i-1]][j-steps[i-1]-1][k]] & 0xFF;
            d++;
          }
        }
        sum[j] = round(sum[j]*1.0/d);
        
        if(sum[j] > maxSum){
          maxSum = sum[j];
          maxIndex = (short)j;
        }
      }
      
      // one sum done
    }
    
    
    steps[i] = maxIndex;
    
    // now go back and lighten that line
    if(steps[i-1] > steps[i]){
      for(int k=0; k<pathLengths[steps[i]][steps[i-1]-steps[i]-1]; k++){
        pic2.pixels[paths[steps[i]][steps[i-1]-steps[i]-1][k]] = lighten(pic2.pixels[paths[steps[i]][steps[i-1]-steps[i]-1][k]]);
      }
      totalLength += pathLengths[steps[i]][steps[i-1]-steps[i]-1] * 1.0/(circleRadius2*2);
    }else if(steps[i-1] < steps[i]){
      for(int k=0; k<pathLengths[steps[i-1]][steps[i]-steps[i-1]-1]; k++){
        pic2.pixels[paths[steps[i-1]][steps[i]-steps[i-1]-1][k]] = lighten(pic2.pixels[paths[steps[i-1]][steps[i]-steps[i-1]-1][k]]);
      }
      totalLength += pathLengths[steps[i-1]][steps[i]-steps[i-1]-1] * 1.0/(circleRadius2*2);
    }
    
    
    // step done
  }
  // all done
  
  pic2.filter(INVERT);
  pic2.updatePixels();
}

void getPaths(){
  // build all the paths between pins
  paths = new int[pinCount][][];
  pathLengths = new int[pinCount][];
  // don't store redundant paths
  // the one with smaller index is first
  float slope = 0;
  int distance = 0;
  int dest = 0;
  int pathind = 0;
  for(int i=0; i<pinCount-1; i++){
    paths[i] = new int[pinCount-i-1][];
    pathLengths[i] = new int[pinCount-i-1];
    for(int j=i+1; j<pinCount; j++){
      dest = j-i-1;
      // find the distance between points
      if(pinsXY[i][0] == pinsXY[j][0]){
        // this means the line is vertical
        distance = abs(pinsXY[i][1] - pinsXY[j][1]);
      }else if(abs(pinsXY[i][0] - pinsXY[j][0]) > abs(pinsXY[i][1] - pinsXY[j][1])){
        distance = abs(pinsXY[i][0] - pinsXY[j][0]);
      }else{
        distance = abs(pinsXY[i][1] - pinsXY[j][1]);
      }
      paths[i][dest] = new int[distance];
      pathLengths[i][dest] = distance;
      
      // find the slope and fill the path data
      // vertical is handled separately
      pathind = 0;
      if(pinsXY[i][0] == pinsXY[j][0]){
        // vertical
        if(pinsXY[i][1] > pinsXY[j][1]){
          for(int k=pinsXY[i][1]; k>pinsXY[j][1]; k--){
            paths[i][dest][pathind] = pinsXY[i][0] + k*pic2.width;
            pathind++;
          }
        }else{
          for(int k=pinsXY[i][1]; k<pinsXY[j][1]; k++){
            paths[i][dest][pathind] = pinsXY[i][0] + k*pic2.width;
            pathind++;
          }
        }
        // vertical done
      }else{
        slope = (pinsXY[j][1] - pinsXY[i][1])*1.0 / (pinsXY[j][0] - pinsXY[i][0]);
        // if the slope is steep, iterate along Y, if not, X
        if(abs(slope) > 1){
          if(pinsXY[i][1] > pinsXY[j][1]){
            for(int k=pinsXY[i][1]; k>pinsXY[j][1]; k--){
              // going (-,-) slope is + or going (+,-) slope is -
              paths[i][dest][pathind] = pinsXY[i][0] - round(pathind*1.0/slope) + k*pic2.width;
              pathind++;
            }
          }else{
            for(int k=pinsXY[i][1]; k<pinsXY[j][1]; k++){
              // going (-,+) slope is - or going (+,+) slope is +
              paths[i][dest][pathind] = pinsXY[i][0] + round(pathind*1.0/slope) + k*pic2.width;
              pathind++;
            }
          }
        }else{
          // here the slope is shallow
          if(pinsXY[i][0] > pinsXY[j][0]){
            for(int k=pinsXY[i][0]; k>pinsXY[j][0]; k--){
              // going (-,-) slope is + or going (+,-) slope is -
              paths[i][dest][pathind] = k + (pinsXY[i][1] - round(slope*pathind))*pic2.width;
              pathind++;
            }
          }else{
            for(int k=pinsXY[i][0]; k<pinsXY[j][0]; k++){
              // going (-,+) slope is - or going (+,+) slope is +
              paths[i][dest][pathind] = k + (pinsXY[i][1] + round(slope*pathind))*pic2.width;
              pathind++;
            }
          }
        }
      }
      // one path done
    }
    // one pin's paths done
  }
  // all paths done
}

color lighten(color c){
  int b = c & 0xFF;
  if(b < fade){
    b = 0;
  }else{
    b -= fade;
  }
  return color(b);
}

void saveFile(){
  // The first two bytes are the number of steps (msB first)
  // The next byte is the number of pins.
  // Note that the maximum number of pins is 255 because steps
  // are stored in single bytes.
  byte[] data = new byte[3+stepCount];
  data[0] = 0;
  data[1] = 0;
  data[2] = 0;
  data[0] |= (stepCount>>8) & 0xFF;
  data[1] |= stepCount & 0xFF;
  data[2] |= pinCount & 0xFF;
  for(int i=0; i<stepCount; i++){
    data[i+3] = 0;
    data[i+3] |= steps[i] & 0xFF;
  }
  fileSelectedRun = false;
  selectOutput("Select a file to write to:", "outputFileSelected", new File(sketchPath("*.art")));
  while(!fileSelectedRun){
    delay(500);
    print(".");
  }
  saveBytes(outputFileName, data);
  
}

void outputFileSelected(File f){
  if (f == null) {
    outputFileName = sketchPath("s.art");
  }else{
    outputFileName = f.getAbsolutePath();
  }
  fileSelectedRun = true;
}

void loadFile(){
  fileSelectedRun = false;
  selectInput("Select a data file", "loadFileSelected", new File(sketchPath("*.art")));
  while(!fileSelectedRun){
    delay(500);
    print(".");
  }
  if(loadFileName == null){
    // do nothing
    return;
  }
  // copy the data into the steps array and prepare to draw
  byte data[] = loadBytes(loadFileName);
  short l = 0;
  l |= data[0];
  l <<= 8;
  l |= data[1];
  stepCount = l;
  steps = new short[stepCount];
  pinCount = 0+data[2];
  
  for(int i=0; i<l; i++){
    steps[i] = 0;
    steps[i] |= data[i+3];
    if(steps[i] < 0){
      println("neg step");
      println(i);
    }
  }
  pic2 = createImage(width-picX, height-picY, RGB);
  pic2.loadPixels();
  for(int i=0; i<pic2.pixels.length; i++){
    pic2.pixels[i] = color(255);
  }
  float angle = PI*2.0/pinCount;
  for(int i=0; i<pinCount; i++){
    pinsXY[i][0] = round(pic2.height/2 + pic2.height/2 * cos(i*angle));
    pinsXY[i][1] = round(pic2.height/2 - pic2.height/2 * sin(i*angle));
  }
  picScale2 = 1;
  stepsDone = 1;
  withPic = 0;
  
}

void loadFileSelected(File f){
  if (f == null) {
    loadFileName = null;
  }else{
    loadFileName = f.getAbsolutePath();
  }
  fileSelectedRun = true;
}