# 🔌 Smart Lock Arduino Circuit & Wiring Guide

This document details the hardware connections between the **Arduino Uno / Nano**, sensors, actuators, and the laptop.

---

## 📋 Pinout Mapping Table

| Component | Component Pin | Arduino Pin | Notes |
| :--- | :--- | :--- | :--- |
| **PIR Sensor** | VCC | 5V | Powers the motion sensor |
| | GND | GND | Ground connection |
| | OUT (Signal) | **Digital Pin 2** | Digital logic input (HIGH = Motion) |
| **Servo Motor** (Door Lock) | VCC (Red) | 5V / Ext 5V | Power for motor (use external 5V if servo jitters) |
| | GND (Brown/Black)| GND | Common Ground |
| | PWM (Orange/Yellow)| **Digital Pin 9** | Servo signal (0° = Locked, 90° = Unlocked) |
| **Green LED** (Authorized) | Anode (+) | **Digital Pin 5** | Use 220Ω resistor in series |
| | Cathode (-) | GND | Ground |
| **Red LED** (Locked/Alert) | Anode (+) | **Digital Pin 6** | Use 220Ω resistor in series |
| | Cathode (-) | GND | Ground |
| **Blue LED** (Motion Active)| Anode (+) | **Digital Pin 7** | Use 220Ω resistor in series |
| | Cathode (-) | GND | Ground |
| **Buzzer** (Audio Feedback)| Positive (+) | **Digital Pin 8** | Tones for unlock, lock, & intruder alarm |
| | Negative (-) | GND | Ground |
| **Push Button** (Interior) | Pin 1 | **Digital Pin 3** | Uses Arduino internal `INPUT_PULLUP` |
| | Pin 2 | GND | Pressing pulls pin to LOW |

---

## ⚡ Power Supply Recommendation
- While developing, Arduino USB power can handle a small micro-servo (e.g., SG90 or MG90S).
- For high-torque standard servos (e.g. MG995 / MG996R), connect an external 5V 2A power adapter to the servo's power lines, and **ensure common GND** is shared between the external power supply and Arduino.

---

## 📡 Serial Communication Protocol (115200 Baud)

The Arduino communicates with the Laptop Edge Hub via USB Serial at **115200 baud**. Every command is terminated by `\n`.

### From Arduino ➔ Laptop:
- `EVENT:PIR_MOTION` - Triggered the moment someone enters sensor range. Initiates Face Recognition on laptop.
- `EVENT:PIR_IDLE` - Triggered when the PIR field is clear. Face Recognition switches off to save power.
- `EVENT:MANUAL_BUTTON_PRESSED` - Indoor physical button pressed.
- `EVENT:AUTO_LOCK_TRIGGERED` - Door automatically re-locked after 10-second timer.
- `STATUS:DOOR:LOCKED` - Door bolt is engaged.
- `STATUS:DOOR:UNLOCKED` - Door bolt is disengaged.
- `STATUS:ALERT_STARTED` - Audible intruder alert activated.
- `PONG` - Health check reply.

### From Laptop ➔ Arduino:
- `CMD:UNLOCK` - Triggers servo to rotate to 90°, plays unlock chime, turns on Green LED.
- `CMD:LOCK` - Triggers servo to rotate to 0°, turns on Red LED.
- `CMD:ALERT` - Triggers flashing red strobe and siren buzzer.
- `CMD:STATUS` - Queries current sensor & door state.
- `CMD:PING` - Heartbeat query.
