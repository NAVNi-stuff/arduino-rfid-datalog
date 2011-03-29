#include <SdFat.h>//The SD card related objects

Sd2Card card;
SdVolume volume;
SdFile root;
SdFile accessLogDir;
SdFile adminDir;
SdFile logFile;
SdFile allowedFile;

const int MAX_CMD_LENGTH = 44;
char command[MAX_CMD_LENGTH];
boolean commandEndReached;
int16_t c;
char tmpChar;

//===================================================================================
// SETUP METHOD
//===================================================================================
void setup() { 
  Serial.begin(2400);     // RFID reader SOUT pin connected to Serial RX pin at 2400bps

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
//  Serial.print("available memory loop: ");
//  Serial.println(availableMemory());
    
  readCommand();

  delay(2000);
  
}


//===================================================================================
// read command from Serial if given
//===================================================================================
void readCommand() {

  resetCommand();
  int charIdx = 0;
  commandEndReached = false;
  while(Serial.available() && !commandEndReached) {
    Serial.print("available memory rc: ");
    Serial.println(availableMemory());
    tmpChar = Serial.read();
    if (tmpChar >= 32 && tmpChar <= 'z') {
      command[charIdx] = tmpChar;
      charIdx++;
    } else if ('\n'){
      commandEndReached = true;
    } else {
      commandEndReached = true;
    }
  }
  int commandLength = 0;
  for (int i = 0; i < MAX_CMD_LENGTH; i++) {
      if (command[i] == '\0') {
        break;
      }
      commandLength++;
  }
  if (commandLength > 0) {
    Serial.println("=================================================================");
    Serial.print("The command given: ");
    Serial.println(command);
    if ((command[0] == 'l') && (command[1] == 'l')) {
      Serial.println("list");
      printLogFileList();
    } else if ((command[0] == 's') && (command[1] == 'l')) {
      char tmpFileName[13];
      for (int i = 0; i < 13; i++) {
        tmpFileName[i] = command[3+i];
      }
      
      Serial.print("show content log file ");
      Serial.println(tmpFileName);
      showLogContent(tmpFileName);
    } else if ((command[0] == 'd') && (command[1] == 'l')) {
      Serial.println("Delete a log file");
      char tmpFileName[13];
      for (int i = 0; i < 13; i++) {
        tmpFileName[i] = command[3+i];
      }
      deleteLogFile(tmpFileName);
    } else if ((command[0] == 's') && (command[1] == 't')) {
      Serial.println("Set token");
      char tmpToken[10];
      char tmpEndDate[10];
      char tmpBufferedEndDate[10];
      for (int i = 0; i < 10; i++) {
        tmpToken[i] = command[3+i];
      } 
      setToken(tmpToken, tmpEndDate, tmpBufferedEndDate);
    } else {
        Serial.println("UNKNOWN COMMAND");
    }
  }
}


void resetCommand() {
  for (int i = 0; i < MAX_CMD_LENGTH; i++) {
    command[i] = '\0';
  }
}

//===================================================================================
// show content of log file log files
//===================================================================================
void showLogContent(char logFileName[]) {
  Serial.print("In show log content method ");
  Serial.println(logFileName);
  if (accessLogDir.isOpen()) {
    SdFile tmpFile;
    tmpFile.open(&accessLogDir, logFileName, O_READ);
    if (tmpFile.isOpen()) {
      Serial.print("Reading file");
      Serial.println(logFileName);
      while ((c = tmpFile.read()) > 0){
        Serial.print((char)c);
      }
    } else {
      Serial.print("Unable to open file ");
      Serial.println(logFileName);
    }
  }
}

//===================================================================================
// deletes the log file for which the log file name is given
//===================================================================================
void deleteLogFile(char logFileName[]) {
  Serial.print("Place holder for deleting a log file");
  Serial.println(logFileName);
  SdFile file;
  if (!file.open(&accessLogDir, logFileName, O_WRITE)) {
    Serial.print("Can't open "); 
    Serial.println(logFileName);
  }
  if (!file.remove()) Serial.println("file.remove failed");
  Serial.print(logFileName);
  Serial.println(" deleted.");
}


//===================================================================================
// deletes the log file for which the log file name is given
//===================================================================================
void setToken(char tmpToken[], char tmpEndDate[], char tmpBufferedEndDate[]) {
  Serial.print("Placeholder for setting token ");
  Serial.print(tmpToken);
  Serial.print(" with end date ");
  Serial.print(tmpEndDate);
  Serial.print(" and buffered end date ");
  Serial.print(tmpBufferedEndDate);
  
}

//===================================================================================
// print list of log files
//===================================================================================
void printLogFileList() {
  Serial.println("Log file list");
  if (accessLogDir.isOpen()) {
    Serial.println("access dir is open");
    accessLogDir.ls();
  } else {
    Serial.println("Unable to access log file dir.");
  }
  Serial.print("available memory loop: ");
  Serial.println(availableMemory());
}


//================================================
// check available memory
//================================================
int availableMemory() {
  int size = 1024; // Use 2048 with ATmega328
  byte *buf;

  while ((buf = (byte *) malloc(--size)) == NULL)
    ;

  free(buf);

  return size;
}

