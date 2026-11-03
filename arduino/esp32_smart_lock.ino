/*
 * ==============================================================================
 * Smart Home Security System - ESP32 Edge Node Controller
 * ==============================================================================
 * Target Board: ESP32 DevKit V1 (30-Pin)
 * 
 * Hardware Connections (Safe ESP32 GPIOs):
 *   - PIR Motion Sensor (HC-SR501 / AM312) : GPIO 13 (OUT)
 *   - Push Button (Interior Emergency)     : GPIO 14 (Uses INPUT_PULLUP)
 *   - Green LED (Authorized / Unlocked)    : GPIO 18 (with 220Ω resistor)
 *   - Red LED (Locked / Intruder Alert)    : GPIO 19 (with 220Ω resistor)
 *   - Blue LED (Motion Detected / AI Active): GPIO 21 (with 220Ω resistor)
 *   - Buzzer (5V Active or Passive)        : GPIO 22
 *   - Servo Motor (SG90 Micro Servo)       : GPIO 23 (PWM Signal)
 *   - Power:
 *       - ESP32 VIN & SG90 VCC (Red)       : 5V Rail (from USB)
 *       - All GND Pins                     : Common GND Rail
 * 
 * Required Arduino IDE Library:
 *   - "ESP32Servo" by Kevin Harrington (Install via Arduino Library Manager)
 * 
 * Communication:
 *   - Serial via USB at 115200 baud
 *   - Communicates directly with FastAPI Laptop Backend
 * ==============================================================================
 */

#include <ESP32Servo.h>

// --- ESP32 Safe Pin Definitions ---
const int PIN_PIR       = 13;  // PIR Sensor Digital Output
const int PIN_BUTTON    = 14;  // Interior Manual Unlock Button (Active LOW)
const int PIN_LED_GREEN = 18;  // Door Unlocked indicator
const int PIN_LED_RED   = 19;  // Door Locked / Intruder indicator
const int PIN_LED_BLUE  = 21;  // Motion Detected indicator
const int PIN_BUZZER    = 22;  // Buzzer Pin
const int PIN_SERVO     = 23;  // SG90 Servo Signal Pin

// --- Servo Configuration ---
Servo doorServo;
const int SERVO_LOCKED_ANGLE   = 0;    // Angle when door is locked
const int SERVO_UNLOCKED_ANGLE = 90;   // Angle when door is unlocked

// --- System State Variables ---
bool isDoorLocked = true;
bool lastPirState = false;
unsigned long pirMotionStartTime = 0;
const unsigned long PIR_DEBOUNCE_MS = 2000; // Hold motion state for at least 2s

// Auto-lock feature (locks automatically after 10s when unlocked)
unsigned long unlockTimestamp = 0;
const unsigned long AUTO_LOCK_DELAY_MS = 10000;
bool autoLockEnabled = true;

// Alert state
bool isAlertActive = false;
unsigned long alertStartTime = 0;
const unsigned long ALERT_DURATION_MS = 4000;

// Serial Buffer
String inputString = "";

// Forward declarations
void lockDoor(bool playSound = true);
void unlockDoor(bool playSound = true);
void triggerAlert();
void handleSerialCommand(String cmd);
void updateIndicators();
void beep(int frequency, int durationMs);

void setup() {
  // Initialize USB Serial to communicate with Laptop Python Backend
  Serial.begin(115200);
  inputString.reserve(64);

  // Initialize GPIO Pins
  pinMode(PIN_PIR, INPUT);
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  pinMode(PIN_LED_GREEN, OUTPUT);
  pinMode(PIN_LED_RED, OUTPUT);
  pinMode(PIN_LED_BLUE, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);

  // Configure ESP32 Timers for Servo
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  ESP32PWM::allocateTimer(2);
  ESP32PWM::allocateTimer(3);
  doorServo.setPeriodHertz(50); // Standard 50Hz servo
  doorServo.attach(PIN_SERVO, 500, 2400); // Standard SG90 pulse width

  // Start in secure locked state
  lockDoor(false);

  // Power-on startup chime
  beep(1000, 100);
  delay(100);
  beep(1500, 150);

  Serial.println("SYSTEM:READY");
  Serial.println("STATUS:DOOR:LOCKED");
}

void loop() {
  unsigned long currentMillis = millis();

  // 1. Process Incoming Serial Commands from Laptop Backend
  while (Serial.available()) {
    char inChar = (char)Serial.read();
    if (inChar == '\n' || inChar == '\r') {
      inputString.trim();
      if (inputString.length() > 0) {
        handleSerialCommand(inputString);
      }
      inputString = "";
    } else {
      inputString += inChar;
    }
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
      digitalWrite(PIN_BUZZER, flash ? HIGH : LOW);
    } else {
      isAlertActive = false;
      digitalWrite(PIN_BUZZER, LOW);
      updateIndicators();
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
  // Works with both Active Buzzers and basic frequency tones
  digitalWrite(PIN_BUZZER, HIGH);
  delay(durationMs);
  digitalWrite(PIN_BUZZER, LOW);
}
