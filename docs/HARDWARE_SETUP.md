# 🛠️ Hardware Setup, Circuit & Mechanical Assembly Guide

This guide provides a comprehensive hardware blueprint for assembling the Smart Lock Edge Node using an **Arduino Uno / Nano**, **PIR Sensor**, **Servo Motor**, **Status Indicators**, and **Buzzer**.

---

## 1. Bill of Materials (BOM)

| # | Component | Model / Spec | Qty | Approx Cost (INR/USD) | Purpose |
| :- | :--- | :--- | :-: | :-: | :--- |
| 1 | **Microcontroller** | Arduino Uno R3 or Arduino Nano V3 (ATmega328P) | 1 | ₹350 - ₹500 ($5 - $7) | Reads sensors, controls servo, talks to Laptop over USB Serial |
| 2 | **Motion Sensor** | HC-SR501 or AM312 Pyroelectric PIR Sensor | 1 | ₹80 - ₹120 ($1 - $2) | Detects human infrared radiation & presence |
| 3 | **Door Actuator** | Micro Servo SG90 (Prototype) or MG996R Metal Gear (Production) | 1 | ₹120 - ₹350 ($2 - $5) | Rotates door lock tumbler / deadbolt |
| 4 | **Piezo Buzzer** | 5V Active or Passive Buzzer | 1 | ₹20 ($0.30) | Audio feedback for chimes and intruder alarm |
| 5 | **Status LEDs** | 5mm Diffused (1x Green, 1x Red, 1x Blue/Yellow) | 3 | ₹10 ($0.15) | Visual status indicators |
| 6 | **Resistors** | 220Ω 1/4W Resistors | 3 | ₹5 ($0.05) | Current limiting for LEDs |
| 7 | **Emergency Button**| 6x6mm Tactile Momentary Push Button | 1 | ₹5 ($0.05) | Interior emergency manual toggle |
| 8 | **Breadboard** | 400 or 830 Points Breadboard | 1 | ₹100 ($1.50) | Prototyping circuit connections |
| 9 | **Jumper Wires** | Male-to-Male & Male-to-Female Jumpers | 20 | ₹50 ($0.75) | Wire connections |
| 10 | **USB Cable** | USB Type-A to Type-B (Uno) or Mini-USB (Nano) | 1 | ₹80 ($1.00) | Connects Arduino to Laptop for power & Serial UART |

---

## 2. Complete Wiring & Pinout Table

| Peripheral | Component Pin | Arduino Pin | Notes |
| :--- | :--- | :--- | :--- |
| **PIR Sensor** | VCC | **5V** | Regulated 5V rail |
| | GND | **GND** | Ground rail |
| | OUT (Signal) | **Digital Pin 2** | Digital logic input (HIGH = Motion) |
| **Servo Motor** | VCC (Red wire) | **5V** (or Ext 5V) | Power supply (see Power Notes below) |
| | GND (Brown/Black wire)| **GND** | Common ground |
| | Signal (Orange/Yellow wire)| **Digital Pin 9** | Hardware PWM output |
| **Green LED** (Authorized)| Anode (+) (Long leg) | **Digital Pin 5** | Connect via 220Ω resistor |
| | Cathode (-) (Flat edge)| **GND** | Direct ground |
| **Red LED** (Locked / Alert)| Anode (+) (Long leg) | **Digital Pin 6** | Connect via 220Ω resistor |
| | Cathode (-) (Flat edge)| **GND** | Direct ground |
| **Blue LED** (Motion Active)| Anode (+) (Long leg) | **Digital Pin 7** | Connect via 220Ω resistor |
| | Cathode (-) (Flat edge)| **GND** | Direct ground |
| **Buzzer** | Positive (+) (Long leg) | **Digital Pin 8** | Tone generation pin |
| | Negative (-) | **GND** | Direct ground |
| **Manual Button** | Leg 1 | **Digital Pin 3** | Uses Arduino internal `INPUT_PULLUP` |
| | Leg 2 | **GND** | Short to GND when pressed |

---

## 3. Circuit Schematic Layout

```
                  ARDUINO UNO / NANO
               +----------------------+
               |                      |
               |                  5V  |-----> Breadboard 5V (+) Rail
               |                 GND  |-----> Breadboard GND (-) Rail
               |                      |
  [PIR OUT] -->| D2                   |
  [BTN PIN] -->| D3                   |
               |                      |
               |                  D5  |----[ 220Ω ]----(>|) GREEN LED ---> GND
               |                  D6  |----[ 220Ω ]----(>|) RED LED   ---> GND
               |                  D7  |----[ 220Ω ]----(>|) BLUE LED  ---> GND
               |                  D8  |----------------(+) BUZZER      ---> GND
               |                  D9  |----( PWM )----[ SERVO SIGNAL ]
               |                      |
               |             USB PORT |======== [ USB Cable to Laptop ]
               +----------------------+
```

---

## 4. Power & Electrical Best Practices

> [!CAUTION]
> **Servo Inductive Spikes & Brownout Protection**:
> A standard servo motor (like the MG996R) can draw between **500mA to 1.5A peak stall current** when initiating rotation. The Arduino onboard 5V regulator can supply only ~400mA from the USB port.
> - **For small SG90 Servos**: Direct USB 5V from Arduino is acceptable for desktop prototyping.
> - **For high-torque MG995/MG996R Servos**: Use an external 5V 2A DC adapter or 4x AA battery pack for the servo's VCC/GND, and **tie the external GND to Arduino GND (Common Ground)**.
> - **Decoupling Capacitor**: Placing a 100µF – 470µF electrolytic capacitor across the servo’s `+` and `-` rails prevents voltage dips that cause Arduino random resets.

---

## 5. HC-SR501 PIR Sensor Calibration

The standard HC-SR501 module has two orange potentiometers and a jumper:

1. **Sensitivity (Distance) Potentiometer**:
   - Turn clockwise to increase range (up to 7 meters).
   - Turn counter-clockwise to reduce range (recommended ~2-3 meters for doorways to prevent false triggers from passing hallway traffic).
2. **Time Delay Potentiometer**:
   - Turn fully counter-clockwise to minimize hardware hold time (approx. 2.5 - 3 seconds). The Arduino firmware has a built-in software debounce timer (`PIR_DEBOUNCE_MS = 2000`).
3. **Trigger Mode Jumper (L / H)**:
   - Set to **H (Repeatable Trigger)**: The output stays HIGH as long as someone is moving in front of the lens.

---

## 6. Mechanical Door Mounting & Linkage

For a physical door installation:
1. **Direct Bolt Linkage**: Attach a servo horn to a rigid metal or 3D-printed pushrod linked to an interior sliding latch or deadbolt cylinder.
2. **Angle Calibration**:
   - `0 Degrees`: Bolt fully extended into door jamb (Locked).
   - `90 Degrees`: Bolt retracted into housing (Unlocked).
   - Angles can be adjusted in [`arduino/smart_lock_controller.ino`](file:///D:/WEB_DEVELOPMENT_@_ISHANT/IOT_project/arduino/smart_lock_controller.ino):
     ```cpp
     const int SERVO_LOCKED_ANGLE   = 0;
     const int SERVO_UNLOCKED_ANGLE = 90;
     ```

---

## 7. Flashing the Firmware

1. Install the official [Arduino IDE](https://www.arduino.cc/en/software).
2. Connect your Arduino board to your laptop via USB.
3. In Arduino IDE:
   - Go to **Tools ➔ Board ➔ Arduino AVR Boards ➔ Arduino Uno** (or Nano).
   - Go to **Tools ➔ Port** and select the active COM port (e.g., `COM3` on Windows).
4. Open [`arduino/smart_lock_controller.ino`](file:///D:/WEB_DEVELOPMENT_@_ISHANT/IOT_project/arduino/smart_lock_controller.ino).
5. Click the **Upload** button (arrow icon).
6. Once uploaded, the Arduino will emit two short startup beeps, and the Red LED will light up (Secure Locked state).
