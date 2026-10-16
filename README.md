# 🛡️ Smart IoT Home Security & AI Edge Vision System

An end-to-end Smart Home Security and Automated Access Control System integrating an **Arduino Edge Hardware Node**, a **Laptop-hosted Edge AI Vision & FastAPI Hub**, and a **Flutter Mobile Application**.

---

## 📌 Architecture Overview

```
                      +-----------------------------+
                      |     Flutter Mobile App      |
                      | (iOS / Android / Web / Win) |
                      +--------------+--------------+
                                     |
               REST API (JWT) / WebSockets / MJPEG Stream (LAN / Wi-Fi)
                                     |
                                     v
                      +-----------------------------+
                      |     Laptop AI Hub &         |
                      |     FastAPI Backend         |
                      |                             |
                      |  * Laptop Webcam Stream     |
                      |  * Face Recognition Engine  |
                      |  * SQLite Event Database    |
                      |  * WebSockets Event Server  |
                      |  * MJPEG Video Broadcaster  |
                      +--------------+--------------+
                                     |
                     USB Serial UART (115200 Baud)
                                     |
                                     v
                      +-----------------------------+
                      |    Arduino Edge Controller  |
                      |                             |
                      |  * PIR Motion Sensor (Pin 2)|
                      |  * Servo Motor (Pin 9)      |
                      |  * Buzzer Alarm (Pin 8)     |
                      |  * Status LEDs (Pins 5,6,7) |
                      |  * Interior Button (Pin 3)  |
                      +-----------------------------+
```

---

## 📖 Complete Documentation Index

| Documentation Guide | Description |
| :--- | :--- |
| **[System Architecture & Data Flow](file:///D:/WEB_DEVELOPMENT_@_ISHANT/IOT_project/docs/ARCHITECTURE.md)** | Microcontroller-to-Edge AI topology, sequence diagrams, and SQLite schema |
| **[Hardware Setup & Assembly](file:///D:/WEB_DEVELOPMENT_@_ISHANT/IOT_project/docs/HARDWARE_SETUP.md)** | Bill of Materials (BOM), circuit schematics, pinout mapping, and mechanical mounting |
| **[REST API & WebSockets Reference](file:///D:/WEB_DEVELOPMENT_@_ISHANT/IOT_project/docs/API_REFERENCE.md)** | Complete HTTP endpoints, JWT authentication headers, and real-time WebSocket schemas |
| **[AI Edge Vision & Face Recognition](file:///D:/WEB_DEVELOPMENT_@_ISHANT/IOT_project/docs/AI_VISION_PIPELINE.md)** | PIR-gated computer vision, dual-tier embeddings/OpenCV fallback, and temporal filtering |
| **[Flutter App & Deployment Guide](file:///D:/WEB_DEVELOPMENT_@_ISHANT/IOT_project/docs/FLUTTER_APP_GUIDE.md)** | Cross-platform state management, low-latency MJPEG player, and Android APK compilation |
| **[Troubleshooting & FAQ](file:///D:/WEB_DEVELOPMENT_@_ISHANT/IOT_project/docs/TROUBLESHOOTING.md)** | COM port conflicts, camera permissions, LAN network discovery, and power fixes |
| **[Academic Report & Presentation](file:///D:/WEB_DEVELOPMENT_@_ISHANT/IOT_project/docs/PRESENTATION_PROJECT_REPORT.md)** | Comprehensive project report, benchmarks, cost analysis, and future roadmap |

---

## ⚡ The PIR-Gated Face Recognition Concept

Running heavy facial recognition models continuously on a laptop causes high CPU load, thermal throttling, and fan noise.

**Our Solution**:
1. **Standby Mode (0% AI Overhead)**: The laptop camera continuously captures/records the video feed and broadcasts it via MJPEG streaming, but the Face Recognition pipeline is **asleep**.
2. **Motion Triggered**: The **PIR Sensor** detects a human approaching the doorway and sends `EVENT:PIR_MOTION` to the laptop over USB Serial.
3. **AI Vision Active**: The laptop wakes up the Face Recognition engine for the active duration:
   - **Authorized Face Recognized**:
     - Sends `CMD:UNLOCK` to Arduino ➔ Servo unlocks door.
     - Saves snapshot image.
     - Pushes instant notification to Flutter app.
     - Starts auto-lock countdown (10s).
   - **Unknown Face / Intruder Detected**:
     - Sends `CMD:ALERT` to Arduino ➔ Sounds buzzer siren & flashes red strobe.
     - Saves snapshot image.
     - Pushes critical **INTRUDER WARNING** notification to Flutter app.
4. **Motion Clears**: When PIR returns to idle, Arduino emits `EVENT:PIR_IDLE`, and the Face AI immediately returns to sleep.

---

## 📁 Repository Directory Structure

```
IOT_project/
├── arduino/
│   ├── smart_lock_controller.ino     # Arduino C++ sketch (PIR, Servo, LEDs, Buzzer, Serial)
│   └── circuit_and_pinout.md         # Detailed hardware wiring & pinout diagrams
├── backend/
│   ├── app/
│   │   ├── auth/                     # JWT authentication & password hashing
│   │   ├── routers/                  # API routes (auth, door, stream, logs, faces)
│   │   ├── services/                 # Serial, Camera, Face AI, WebSockets services
│   │   ├── config.py                 # Configuration & environment settings
│   │   ├── database.py               # SQLite connection & sessionmaker
│   │   ├── models.py                 # SQLAlchemy ORM models
│   │   ├── schemas.py                # Pydantic validation schemas
│   │   └── main.py                   # FastAPI application & startup lifecycle
│   ├── static/
│   │   ├── snapshots/                # Captured motion & intruder photos
│   │   └── known_faces/              # Enrolled authorized member photos
│   ├── requirements.txt              # Python dependencies
│   ├── run.py                        # Uvicorn entrypoint
│   └── .env.example                  # Environment configuration template
├── flutter_app/
│   ├── lib/
│   │   ├── constants/                # App colors (dark security theme) & API routes
│   │   ├── models/                   # Dart models (User, Status, Event, Faces)
│   │   ├── services/                 # HTTP client, WebSockets, Storage persistence
│   │   ├── providers/                # State management (AuthProvider, SecurityProvider)
│   │   ├── screens/                  # Login, Register, Dashboard, LiveStream, Logs, Faces, Settings
│   │   ├── widgets/                  # MJPEG video player, 3D Glowing Lock Button, Badges, Event Tiles
│   │   └── main.dart                 # App entrypoint & auto-auth gate
│   └── pubspec.yaml                  # Flutter dependencies
└── scripts/
    ├── run_backend.bat               # 1-Click Windows backend launcher
    └── simulate_iot.py               # Interactive CLI hardware & scenario simulator
```

---

## 🔌 Hardware Wiring & Pinout Guide

| Device | Device Pin | Arduino Pin | Description |
| :--- | :--- | :--- | :--- |
| **PIR Sensor** | VCC | 5V | Sensor power |
| | GND | GND | Ground |
| | OUT | **Pin 2** | Digital HIGH on motion detection |
| **Servo Motor** | VCC | 5V (Ext) | Power (Use 5V 2A external for large servos) |
| | GND | GND | Shared Common Ground |
| | PWM (Signal) | **Pin 9** | 0° = Locked, 90° = Unlocked |
| **Buzzer** | Positive (+) | **Pin 8** | Chimes and alarm siren |
| | Negative (-) | GND | Ground |
| **Green LED** | Anode (+) | **Pin 5** | 220Ω series resistor (Door Unlocked) |
| **Red LED** | Anode (+) | **Pin 6** | 220Ω series resistor (Locked / Alarm) |
| **Blue LED** | Anode (+) | **Pin 7** | 220Ω series resistor (Motion / AI active) |
| **Emergency Button** | Pin 1 | **Pin 3** | Interior manual toggle (`INPUT_PULLUP`) |

---

## 🚀 Getting Started

### 1. Arduino Setup
1. Open the [Arduino IDE](https://www.arduino.cc/en/software).
2. Open [`arduino/smart_lock_controller.ino`](file:///D:/WEB_DEVELOPMENT_@_ISHANT/IOT_project/arduino/smart_lock_controller.ino).
3. Connect your Arduino via USB.
4. Select your Board (e.g., Arduino Uno) and COM Port.
5. Click **Upload**.

---

### 2. Backend & Vision Hub Setup

#### Quick Start (Windows):
Double click [`scripts/run_backend.bat`](file:///D:/WEB_DEVELOPMENT_@_ISHANT/IOT_project/scripts/run_backend.bat) or run:

```bash
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python run.py
```

- **Interactive API Docs (Swagger UI)**: `http://localhost:8000/docs`
- **Live Camera Stream**: `http://localhost:8000/api/video/feed`
- **Default Admin Account**: `admin@home.local` / `admin123`

> **Note on Simulation Mode**: If you do not have the Arduino plugged in yet, `SIMULATION_MODE=true` is enabled by default in `backend/app/config.py`. The backend will automatically simulate serial responses and generate a test camera card so you can develop and test without hardware!

---

### 3. Flutter App Setup

Run the mobile/desktop app on Android, Windows, or Web:

```bash
cd flutter_app
flutter pub get
flutter run
```

#### Connecting from Mobile / Emulator:
1. Open the Flutter app.
2. On the Login screen, tap the **Server Config icon** in the top-right corner.
3. Enter your laptop's Wi-Fi IP address (e.g., `http://192.168.1.15:8000`), or `http://10.0.2.2:8000` if using the Android Emulator.
4. Sign in with `admin@home.local` and `admin123` (or register a new user).

---

## 🛠️ Testing Without Hardware (Interactive Simulator)

With the backend running, open a new terminal:

```bash
python scripts/simulate_iot.py
```

This interactive terminal CLI lets you:
- Press `1` to trigger PIR motion (watches camera HUD switch to AI Active and alerts the app).
- Press `2` to clear motion.
- Press `3` and `4` to unlock and lock the door remotely.
- View real-time telemetry.
