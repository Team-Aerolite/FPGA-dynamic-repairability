#include <SPI.h>

const int SS_PIN = 10;

// SPI command masks - upper two bits define command type
#define CMD_SET_FUNCTION  0x00  // bits 7-6 = 00
#define CMD_SET_INPUT_A   0x40  // bits 7-6 = 01
#define CMD_SET_INPUT_B   0x80  // bits 7-6 = 10
#define CMD_READ_RESULT   0xC0  // bits 7-6 = 11

// Logic function codes (only 0-3 used)
#define FUNC_AND    0
#define FUNC_OR     1
#define FUNC_XOR    2
#define FUNC_NAND   3

// Map function codes to names for display
String functionNames[] = {
  "AND", "OR", "XOR", "NAND"
};

uint8_t currentInputA = 0;
uint8_t currentInputB = 0;

bool err_disp = false;

void setup() {
  Serial.begin(115200);
  Serial.println("FPGA SPI Logic Function Demo - 4 functions, 4 LEDs");
  Serial.println("Commands:");
  Serial.println("  f<0-3> : Set logic function (AND=0, OR=1, XOR=2, NAND=3)");
  Serial.println("  a<0-3> : Set input A (2-bit)");
  Serial.println("  b<0-3> : Set input B (2-bit)");
  Serial.println("  r      : Read result from FPGA");

  pinMode(SS_PIN, OUTPUT);
  digitalWrite(SS_PIN, HIGH); // SS inactive

  SPI.begin();
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0)); // 1 MHz, mode 0

  delay(500);
  
  demoSequence();
}

void loop() {
  handleSerialInput();
  houskeeping();
  delay(100);
}

// Send one byte over SPI with SS held low for entire transfer
uint8_t spiTransferByte(uint8_t data) {
  digitalWrite(SS_PIN, LOW);
  uint8_t received = SPI.transfer(data);
  digitalWrite(SS_PIN, HIGH);
  delayMicroseconds(10);  // line settling delay
  return received;
}

// Functions to send commands to FPGA
void setLogicFunction(uint8_t func) {
  if (func > 3) {
    Serial.println("Invalid function. Valid: 0-3");
    return;
  }
  uint8_t cmd = CMD_SET_FUNCTION | (func & 0x03);
  spiTransferByte(cmd);
}

void setInputA(uint8_t a) {
  if (a > 3) {
    Serial.println("Invalid input A. Valid: 0-3");
    return;
  }
  currentInputA = a;
  uint8_t cmd = CMD_SET_INPUT_A | (a & 0x03);
  spiTransferByte(cmd);
}

void setInputB(uint8_t b) {
  if (b > 3) {
    Serial.println("Invalid input B. Valid: 0-3");
    return;
  }
  currentInputB = b;
  uint8_t cmd = CMD_SET_INPUT_B | (b & 0x03);
  spiTransferByte(cmd);
}

uint8_t readResult() {
  uint8_t resp = spiTransferByte(CMD_READ_RESULT);
  return resp;
}

void demoSequence() {
  Serial.println("Running automatic demo sequence...");
  setInputA(3);  // binary 11
  setInputB(2);  // binary 10

  for (int f = 0; f <= 3; f++) {
    setLogicFunction(f);
    delay(200);
    uint8_t res = (readResult() >> 2) & 0x03;
    
    Serial.print("[Uplink] Function: ");
    Serial.print(functionNames[f]);
    Serial.print(" | A=3, B=2 | [Downlink] Result = ");
    if (res < 2) Serial.print('0');
    Serial.println(res, BIN);
    delay(800);
  }
  Serial.println("Demo complete. Enter commands to control the FPGA.");
}

void handleSerialInput() {
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();

    if (cmd.length() == 0)
      return;

    char c = cmd.charAt(0);
    String arg = cmd.substring(1);

    if (c == 'f') {
      int f = arg.toInt();
      if (f >= 0 && f <= 3) {
        setLogicFunction(f);
        Serial.print("[Uplink] Set function: ");
        Serial.println(functionNames[f]);
      } else {
        Serial.println("Invalid function number. Use 0-3.");
      }
    }
    else if (c == 'a') {
      int a = arg.toInt();
      if (a >= 0 && a <= 3) {
        setInputA(a);
        Serial.print("[Uplink] Set input A: ");
        Serial.println(a);
      } else {
        Serial.println("Invalid input A. Use 0-3.");
      }
    }
    else if (c == 'b') {
      int b = arg.toInt();
      if (b >= 0 && b <= 3) {
        setInputB(b);
        Serial.print("[Uplink] Set input B: ");
        Serial.println(b);
      } else {
        Serial.println("Invalid input B. Use 0-3.");
      }
    }
    else if (c == 'r') {
      uint8_t resultBits = (readResult() >> 2) & 0x03;
      Serial.print("[Downlink] Current result: ");
      if (resultBits < 2) Serial.print('0');
      Serial.println(resultBits, BIN);
    }
    else {
      Serial.println("Unknown command. Use f<0-3>, a<0-3>, b<0-3>, or r");
    }
  }
}

void houskeeping() {
  uint8_t error_flag = readResult() & 0x01;
  if (error_flag == 0x01 & err_disp == false) {
    Serial.println("[Downlink] Housekeeping: Subsystem Error Detected");
    Serial.println("[Downlink] Housekeeping: Reconfiguration Done");
    err_disp = true;
  }
  else if (error_flag == 0x00 & err_disp == true)
    err_disp = false;
}