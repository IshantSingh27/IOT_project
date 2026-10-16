/*
 * ==============================================================================
 * Smart Home Security System - Arduino Edge Node Controller
 * ==============================================================================
 * Hardware:
 *   - Arduino Uno / Nano
 *   - PIR Motion Sensor: Digital Pin 2
 *   - Servo Motor (Door Knob/Bolt): Digital Pin 9 (PWM)
 *   - Buzzer: Digital Pin 8
 *   - Status LEDs:
 *       - Green LED (Authorized / Unlocked): Digital Pin 5
 *       - Red LED (Locked / Intruder Alert): Digital Pin 6
 *       - Blue/Yellow LED (Motion Detected / Processing): Digital Pin 7
 *       - Manual Push Button (Interior Emergency Unlock): Digital Pin 3
 * 
 * Communication:
 *   - Serial via USB at 115200 baud
 *   - Simple, human-readable ASCII command protocol with newline delimiters
 * ==============================================================================
 */

#include <Servo.h>

// --- Pin Definitions ---
const int PIN_PIR       = 2;   // PIR Sensor Digital Output
const int PIN_BUTTON    = 3;   // Interior Manual Unlock Button
const int PIN_LED_GREEN = 5;   // Door Unlocked indicator
const int PIN_LED_RED   = 6;   // Door Locked / Intruder indicator
const int PIN_LED_BLUE  = 7;   // Motion Detected / Model Active indicator
const int PIN_BUZZER    = 8;   // Passive/Active Buzzer
const int PIN_SERVO     = 9;   // Servo Signal Pin

// --- Servo Configuration ---
Servo doorServo;
const int SERVO_LOCKED_ANGLE   = 0;    // Angle when door is locked
const int SERVO_UNLOCKED_ANGLE = 90;   // Angle when door is unlocked

// --- System State Variables ---
bool isDoorLocked = true;
bool lastPirState = false;
unsigned long pirMotionStartTime = 0;
const unsigned long PIR_DEBOUNCE_MS = 2000; // Hold motion state for at least 2s

// Auto-lock feature (locks automatically after N seconds when unlocked)
unsigned long unlockTimestamp = 0;
const unsigned long AUTO_LOCK_DELAY_MS = 10000; // 10 seconds auto-lock
bool autoLockEnabled = true;

// Alert state
bool isAlertActive = false;
unsigned long alertStartTime = 0;
const unsigned long ALERT_DURATION_MS = 4000;

// Serial Buffer
String inputString = "";
bool stringComplete = false;

// Forward declarations
void lockDoor(bool playSound = true);
void unlockDoor(bool playSound = true);
void triggerAlert();
void handleSerialCommand(String cmd);
void updateIndicators();
void beep(int frequency, int durationMs);

void setup() {
  // Initialize Serial
  Serial.begin(115200);
  inputString.reserve(64);

  // Initialize Pins
  pinMode(PIN_PIR, INPUT);
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  pinMode(PIN_LED_GREEN, OUTPUT);
  pinMode(PIN_LED_RED, OUTPUT);
  pinMode(PIN_LED_BLUE, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);

  // Attach Servo
  doorServo.attach(PIN_SERVO);
  
  // Start in secure locked state
  lockDoor(false);
  
  // Power-on startup melody
  beep(1000, 100);
  delay(100);
  beep(1500, 150);

  Serial.println("SYSTEM:READY");
  Serial.println("STATUS:DOOR:LOCKED");
}

void loop() {
  unsigned long currentMillis = millis();

  // 1. Process Incoming Serial Commands from Laptop
  if (stringComplete) {
    inputString.trim();
    if (inputString.length() > 0) {
      handleSerialCommand(inputString);
    }
    inputString = "";
    stringComplete = false;
  }

  // 2. Read PIR Motion Sensor
  int pirReading = digitalRead(PIN_PIR);
  if (pirReading == HIGH) {
    pirMotionStartTime = currentMillis;
    if (!lastPirState) {
      lastPirState = true;
      digitalWrite(PIN_LED_BLUE, HIGH);
      Serial.println("EVENT:PIR_MOTION");
    }
  } else {
    // Check if motion has cleared after debounce hold
    if (lastPirState && (currentMillis - pirMotionStartTime >= PIR_DEBOUNCE_MS)) {
      lastPirState = false;
      digitalWrite(PIN_LED_BLUE, LOW);
      Serial.println("EVENT:PIR_IDLE");
    }
  }

  // 3. Interior Emergency Manual Button Check (Active LOW)
  if (digitalRead(PIN_BUTTON) == LOW) {
    delay(50); // Debounce
    if (digitalRead(PIN_BUTTON) == LOW) {
      Serial.println("EVENT:MANUAL_BUTTON_PRESSED");
      if (isDoorLocked) {
        unlockDoor(true);
      } else {
        lockDoor(true);
      }
      delay(300); // Wait for release
    }
  }

  // 4. Handle Auto-Lock Timer
  if (!isDoorLocked && autoLockEnabled) {
    if (currentMillis - unlockTimestamp >= AUTO_LOCK_DELAY_MS) {
      Serial.println("EVENT:AUTO_LOCK_TRIGGERED");
      lockDoor(true);
    }
  }

  // 5. Handle Alert Flashing if Active
  if (isAlertActive) {
    if (currentMillis - alertStartTime < ALERT_DURATION_MS) {
      // Flash red LED and pulse buzzer
      bool flash = (currentMillis / 150) % 2 == 0;
      digitalWrite(PIN_LED_RED, flash ? HIGH : LOW);
      if (flash) {
        tone(PIN_BUZZER, 2200, 100);
      } else {
        noTone(PIN_BUZZER);
      }
    } else {
      isAlertActive = false;
      noTone(PIN_BUZZER);
      updateIndicators();
    }
  }
}

// --- Serial Event Callback ---
void serialEvent() {
  while (Serial.available()) {
    char inChar = (char)Serial.read();
    if (inChar == '\n' || inChar == '\r') {
      if (inputString.length() > 0) {
        stringComplete = true;
      }
    } else {
      inputString += inChar;
    }
  }
}

// --- Command Dispatcher ---
void handleSerialCommand(String cmd) {
  cmd.toUpperCase();

  if (cmd == "CMD:UNLOCK" || cmd == "UNLOCK") {
    unlockDoor(true);
  } else if (cmd == "CMD:LOCK" || cmd == "LOCK") {
    lockDoor(true);
  } else if (cmd == "CMD:ALERT" || cmd == "ALERT") {
    triggerAlert();
  } else if (cmd == "CMD:STATUS" || cmd == "STATUS") {
    Serial.print("STATUS:DOOR:");
    Serial.println(isDoorLocked ? "LOCKED" : "UNLOCKED");
    Serial.print("STATUS:PIR:");
    Serial.println(lastPirState ? "ACTIVE" : "IDLE");
  } else if (cmd == "CMD:PING" || cmd == "PING") {
    Serial.println("PONG");
  } else {
    Serial.print("ERROR:UNKNOWN_COMMAND:");
    Serial.println(cmd);
  }
}

// --- Hardware Actions ---
void unlockDoor(bool playSound) {
  isDoorLocked = false;
  doorServo.write(SERVO_UNLOCKED_ANGLE);
  unlockTimestamp = millis();
  updateIndicators();
  
  if (playSound) {
    beep(1200, 80);
    delay(50);
    beep(1800, 120);
  }
  Serial.println("STATUS:DOOR:UNLOCKED");
}

void lockDoor(bool playSound) {
  isDoorLocked = true;
  doorServo.write(SERVO_LOCKED_ANGLE);
  updateIndicators();
  
  if (playSound) {
    beep(800, 150);
  }
  Serial.println("STATUS:DOOR:LOCKED");
}

void triggerAlert() {
  isAlertActive = true;
  alertStartTime = millis();
  Serial.println("STATUS:ALERT_STARTED");
}

void updateIndicators() {
  if (isDoorLocked) {
    digitalWrite(PIN_LED_GREEN, LOW);
    digitalWrite(PIN_LED_RED, HIGH);
  } else {
    digitalWrite(PIN_LED_GREEN, HIGH);
    digitalWrite(PIN_LED_RED, LOW);
  }
}

void beep(int frequency, int durationMs) {
  tone(PIN_BUZZER, frequency, durationMs);
  delay(durationMs);
  noTone(PIN_BUZZER);
}
