#include <SdFat.h>
#include <Wire.h>
#include <RTClib.h>

int DOOR = 7;
int RFID_ENABLE = 2;
int CODE_SIZE = 10;
int ARRAY_SIZE = 11;

char DATE_SEPARATOR = '/';
char TIME_SEPARATOR = ':';
char DATE_AND_TIME_SEPARATOR = '-';
char CSV_SEPARATOR = ',';

int bytesRead = 0;
char lastReadRFID[] = "0000000000";
char code[] = "0000000000";

DateTime lastTimeStamp;

int elementIdx = 0;
String tokenCode = "";
String endDateStr = "";
String tmpString = "";
boolean equalsReadToken = false;

char tmpChar;
int converted = 0;
char allowedFileName[] = "allowed.csv";
int csvSeparatorCount;
String logFileName;

//The RTC related object
RTC_DS1307 RTC;
DateTime now;

//The SD card related objects
Sd2Card card;
SdVolume volume;
SdFile root;
SdFile accessLogDir;
SdFile adminDir;
SdFile logFile;
SdFile allowedFile;


//===================================================================================
// SETUP METHOD
//===================================================================================
void setup() { 

  Serial.begin(2400);     // RFID reader SOUT pin connected to Serial RX pin at 2400bps 
  Wire.begin();
  RTC.begin();
  pinMode(RFID_ENABLE,OUTPUT);   // Set digital pin 2 as OUTPUT to connect it to the RFID /ENABLE pin 
  pinMode(DOOR, OUTPUT);   // Set digital pin 13 as OUTPUT to connect it to door opener
  activateRFID();
  // initialize the SD card at SPI_FULL_SPEED for best performance.
  // try SPI_HALF_SPEED if bus errors occur.
  if (!card.init(SPI_FULL_SPEED)) Serial.println("card.init failed");

  // initialize a FAT volume
  if (!volume.init(&card)) Serial.println("volume.init failed");

  // open the root directory
  if (!root.openRoot(&volume)) Serial.println("openRoot failed");

  //open the logDir
  char logDirName[] = "logs";
  if (!accessLogDir.open(&root, logDirName, O_RDONLY)) {
    Serial.println("figure out error while opening logs and admin dir");
  }
  //open the admin
  char adminDirName[] = "admin";
  adminDir.open(&root, adminDirName, O_RDONLY);

}  

//===================================================================================
// MAIN APP LOOP
//===================================================================================
void loop() {
  now = RTC.now();

  activateRFID();
  readRFID();
  if (bytesRead == CODE_SIZE) {
    deActivateRFID();
    handleReadRFID();
  }
}

//===================================================================================
// close the log file
//===================================================================================
void closeLogFile() {
  logFile.close();
}

//===================================================================================
// opens the log file
//===================================================================================
void openLogFile() {
  if (!accessLogDir.isOpen()) {
    Serial.println ("access log dir not opened");
  } 
  else {
    char name[13];
    name[12] = '\0';
    constructLogFileName();
    logFileName.toCharArray(name,13);
    logFile.open(&accessLogDir, name, O_CREAT | O_WRITE | O_APPEND);
    if (!logFile.isOpen()) {
      Serial.print("Unable to open log file ");
      Serial.println(name);
    }
  }
}


//===================================================================================
// construct the correct file name, containing the time stamp, for the log file of today
//===================================================================================
void constructLogFileName() {
  logFileName = String(now.year());
  int month = now.month();
  if (month < 10) {
    logFileName += 0;
  }
  logFileName += month;
  int day = now.day();
  if (day < 10) {
    logFileName += 0;
  }
  logFileName += day;

  logFileName += ".csv";
}

//===================================================================================
// handle the read RFID tag
//===================================================================================
void handleReadRFID(){
  if (codesAreDifferent(now) ) {
    openLogFile();
    if (userIsAllowed()) {     //if rfid token allowed
      logAccessToSerial(true);     //log to serial out
      logAccessToLogFile(true);//write to log file
      digitalWrite(DOOR, HIGH);            // unlock the door
      delay(2000);                         // wait for 2 seconds
      setLastReadRFID();
      digitalWrite(DOOR, LOW);             // lock the door
    } 
    else {
      logAccessToSerial(false);     //log to serial out
      logAccessToLogFile(false);  //log not allowed user to log file
      delay(2000);                         // wait for 2 seconds
    }
    closeLogFile();
  }
}

//===================================================================================
// logs the access to the log file
//===================================================================================
void logAccessToLogFile(boolean isAccessAllowed) {
  if (logFile.isOpen()) {
    if (!isAccessAllowed) {
      logFile.print("NOT ALLOWED - ");
    }
    logFile.print(now.year(), DEC);
    logFile.print(DATE_SEPARATOR);
    logFile.print(now.month(), DEC);
    logFile.print(DATE_SEPARATOR);
    logFile.print(now.day(), DEC);
    logFile.print(DATE_AND_TIME_SEPARATOR);
    logFile.print(now.hour(), DEC);
    logFile.print(TIME_SEPARATOR);
    logFile.print(now.minute(), DEC);
    logFile.print(TIME_SEPARATOR);
    logFile.print(now.second(), DEC);
    logFile.print(CSV_SEPARATOR);       // possibly a good TAG 
    logFile.println(code);                  // print the TAG code 
  } 
  else {
    Serial.println("Unable to write to the log file on the SD card.");
  }
}

//===================================================================================
// logs the access to serial output
//===================================================================================
void logAccessToSerial(boolean wasAllowed) {
  Serial.print(now.year(), DEC);
  Serial.print(DATE_SEPARATOR);
  Serial.print(now.month(), DEC);
  Serial.print(DATE_SEPARATOR);
  Serial.print(now.day(), DEC);
  Serial.print(DATE_AND_TIME_SEPARATOR);
  Serial.print(now.hour(), DEC);
  Serial.print(TIME_SEPARATOR);
  Serial.print(now.minute(), DEC);
  Serial.print(TIME_SEPARATOR);
  Serial.print(now.second(), DEC);
  Serial.print(" RFID code ");       // possibly a good TAG 
  Serial.print(code);      // print the TAG code 
  Serial.print(" -> access ");
  if (wasAllowed) {
    Serial.println("GRANTED");
  } else {
    Serial.println("DENIED");
  }
}

//===================================================================================
// checks whether the read RFID token is of a user that is still allowed access
//===================================================================================
boolean userIsAllowed() {
  if (adminDir.isOpen()) {
    allowedFile.open(&adminDir, allowedFileName, O_RDONLY);
    if (allowedFile.isOpen()) {
      equalsReadToken = false;
      int16_t c;
      while ((c = allowedFile.read()) > 0){
        if ((char)c == CSV_SEPARATOR) {
          switch(elementIdx) {
            case 0:
              if (tmpString.equals(String(code))) {
                equalsReadToken = true;
                Serial.print("token ");
                Serial.print(tmpString);
                Serial.println(" found in allowed file");
              } else {
                equalsReadToken = false;
              }
  
              break;
            case 1:
              if (equalsReadToken == true) {
                Serial.print("evaluate against date: ");
                Serial.println(tmpString);
                if (equalsReadToken) {//only check the end date for the corresponding entry for the read RFID code
                  if(isNowBeforeEndDate(tmpString)) {
                    return true;
                  }
                }
              }
              break;
          }
          tmpString = "";
          csvSeparatorCount++;
          if (csvSeparatorCount == 2) {
            csvSeparatorCount = 0;
            elementIdx = 0;
          } else {
            elementIdx++;
          }
        } else {
          csvSeparatorCount = 0;
          if (((char)c != '\n')&&((char)c !='\r')) {  //prevent newline chars to end up in tmpString
            tmpString += (char)c;                    //accumulate the chars to eventually hold the contents of one element
          }
        }
      }
      allowedFile.close();
    } else {
      Serial.println("allowed file is not open");
    }
  } else {
    Serial.println("admin dir is not open");
  }
  return false;
}

//===================================================================================
// checks whether current time has passed the given subscription end date
//===================================================================================
boolean isNowBeforeEndDate(String endDateString) {
  if (((int)now.year()) < getInteger(endDateString.substring(0,4))) {
    return true;
  } else if (((int)now.year()) == getInteger(endDateString.substring(0,4))) {
    if (((int)now.month()) < getInteger(endDateString.substring(5,7))) {
      return true;
    } else if (((int)now.month()) == getInteger(endDateString.substring(5,7))){
      if (((int)now.day()) <= getInteger(endDateString.substring(8))) {
        return true;
      }
    }
  }
  return false;
}

int getInteger(String intAsString) {
  converted = 0;
  for (int i =  0; i < intAsString.length(); i++) {
    converted *= 10;
    tmpChar = intAsString.charAt(i);
    converted += (tmpChar - '0');//convert from ascii char to corresponding int
  }
  return converted;
}

//===================================================================================
// checks wether the current code is different from the previously read code
//===================================================================================
boolean codesAreDifferent(DateTime now){
  for (int i = 0; i < CODE_SIZE; i++) {
    if (code[i] != lastReadRFID[i]) {
      lastTimeStamp = now;
      return true;
    } 
    else {//if more than one minute has passed same token can be reused
      if ((lastTimeStamp.year() <= now.year()) 
        && (lastTimeStamp.month() <= now.month()) 
        && (lastTimeStamp.day() <= now.day())
        && (lastTimeStamp.hour() <= now.hour())
        && (lastTimeStamp.minute() < now.minute())) {
        lastTimeStamp = now;
        return true;
      }
    }
  }
  return false;
}

//===================================================================================
// Activate the RFID reader
//===================================================================================
void activateRFID() {
  digitalWrite(RFID_ENABLE, LOW);// Activate the RFID reader
}

//===================================================================================
// DeActivate the RFID reader
//===================================================================================
void deActivateRFID() {
  digitalWrite(RFID_ENABLE, HIGH);// Deactivate the RFID reader
}

//===================================================================================
// read the code from the RFID reader
//===================================================================================
void readRFID(){
  bytesRead = 0;
  int val = 0;

  if(Serial.available() > 0) {          // if data available from reader 
    if((val = Serial.read()) == CODE_SIZE) {   // check for header 
      while(bytesRead<10) {              // read 10 digit code 
        if( Serial.available() > 0) { 
          val = Serial.read(); 
          if((val == 10)||(val == 13)) { // if header or stop bytes before the 10 digit reading 
            break;                       // stop reading 
          }
          code[bytesRead] = val;         // add the digit           
          bytesRead++;                   // ready to read next digit  
        } 
      } 
    }
  }
}

//===================================================================================
// set the lastReadRFID code
//===================================================================================
void setLastReadRFID(){
  for (int i = 0; i < CODE_SIZE; i++) {
    lastReadRFID[i] = code[i];        // copy the content of the last read RFID code into lastReadRFID
  }
  lastReadRFID[10] = 0;
  code[10] = 0;
}
