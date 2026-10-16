# 🏛️ System Architecture & Data Flow

This document details the architectural design, inter-component communication protocols, sequence diagrams, and database schema for the **Smart Home IoT & Edge AI Security System**.

---

## 1. System Topology Overview

The architecture distributes computing loads between an ultra-low-power micro-controller (Arduino), an Edge AI Server (Laptop), and a Client Controller (Flutter Mobile/Desktop Application).

```mermaid
flowchart TD
    subgraph Edge Hardware Node [Arduino Controller]
        PIR["PIR Motion Sensor (Pin 2)"]
        Servo["Door Lock Servo (Pin 9)"]
        Buzzer["Audio Buzzer (Pin 8)"]
        LEDs["Status LEDs (Pins 5, 6, 7)"]
        Btn["Manual Unlock Button (Pin 3)"]
    end

    subgraph Edge AI Host [Laptop Host]
        Webcam["Laptop Integrated / USB Camera"]
        SerialSvc["Serial Bridge (PySerial 115200 Baud)"]
        CameraSvc["Camera & MJPEG Stream Engine"]
        FaceAI["PIR-Gated Face Recognition Service"]
        FastAPI["FastAPI REST & WebSocket Server"]
        SQLite[("SQLite Event & Auth Database")]
    end

    subgraph Client Application [Flutter Application]
        UI["Flutter UI (Dashboard / Live Feed / Logs)"]
        WSClient["WebSocket Client (Auto-Reconnect)"]
        HTTPClient["HTTP REST Client (JWT Bearer)"]
        StreamPlayer["MJPEG Stream Reader"]
    end

    %% Hardware to Laptop Connections
    PIR -->|Digital Pulse| SerialSvc
    SerialSvc -->|PWM Command| Servo
    SerialSvc -->|Tone Trigger| Buzzer
    SerialSvc -->|Status Level| LEDs
    Btn -->|Interrupt| SerialSvc

    %% Internal Laptop Inter-service
    SerialSvc <-->|Events & Commands| FastAPI
    Webcam -->|Video Frames| CameraSvc
    CameraSvc -->|Raw Frames on PIR Active| FaceAI
    FaceAI -->|Auto-Unlock / Alert| SerialSvc
    FaceAI -->|Log Activity & Save Snapshot| SQLite
    FastAPI <-->|Read / Write| SQLite

    %% Laptop to Flutter Connections
    CameraSvc -->|MJPEG Multipart HTTP| StreamPlayer
    FastAPI -->|Real-time JSON Alerts| WSClient
    HTTPClient <-->|REST Endpoints: Auth, Logs, Control| FastAPI
```

---

## 2. Event Sequence Workflows

### Sequence 1: PIR-Gated Face Recognition & Authorized Access

When PIR detects motion, Face Recognition wakes up, verifies the face against enrolled embeddings, and opens the door.

```mermaid
sequenceDiagram
    autonumber
    actor Person as Resident / Visitor
    participant PIR as PIR Sensor
    participant Arduino as Arduino Node
    participant Serial as Serial Service
    participant FaceAI as Face Recognition Engine
    participant Camera as Camera Service
    participant DB as SQLite DB
    participant WS as WebSocket Hub
    participant Flutter as Flutter App

    Person->>PIR: Enters doorway
    PIR->>Arduino: Output goes HIGH
    Arduino->>Serial: Sends "EVENT:PIR_MOTION"
    Serial->>FaceAI: Trigger on_pir_motion_detected()
    FaceAI->>Camera: Set Face Recognition Active (Status: Active)
    FaceAI->>WS: Broadcast {"type": "PIR_MOTION"}
    WS->>Flutter: Update UI: Motion Detected (Pill turns Amber)
    
    loop Real-time Frame Analysis (6-7 FPS)
        FaceAI->>Camera: Fetch get_latest_frame()
        Camera-->>FaceAI: Return Frame
        FaceAI->>FaceAI: Run Face Detection & Match Encodings
    end

    Note over FaceAI: Match Found! Name: "Ishant"
    FaceAI->>Serial: send_command("CMD:UNLOCK")
    Serial->>Arduino: Transmit "CMD:UNLOCK\n"
    Arduino->>Arduino: Rotate Servo to 90° (Unlock)
    Arduino->>Arduino: Play 2-tone Chime & Green LED
    Arduino-->>Serial: "STATUS:DOOR:UNLOCKED"
    
    FaceAI->>Camera: save_snapshot()
    Camera-->>FaceAI: Saved "snap_20261016_223000.jpg"
    FaceAI->>DB: Log ACCESS_GRANTED Event
    FaceAI->>WS: Broadcast {"type": "ACCESS_GRANTED", "person": "Ishant"}
    WS->>Flutter: Show Toast Notification & Update Door to Unlocked
    
    Note over Arduino: 10s Auto-Lock Timer Expires
    Arduino->>Arduino: Rotate Servo to 0° (Locked)
    Arduino->>Serial: "EVENT:AUTO_LOCK_TRIGGERED"
    Serial->>WS: Broadcast {"type": "DOOR_STATE_CHANGED", "locked": true}
    WS->>Flutter: Update Door Widget: Locked
```

---

### Sequence 2: Unrecognized Intruder Alert Pipeline

```mermaid
sequenceDiagram
    autonumber
    actor Intruder as Unknown Person
    participant Arduino as Arduino Node
    participant FaceAI as Face Recognition Engine
    participant Camera as Camera Service
    participant DB as SQLite DB
    participant WS as WebSocket Hub
    participant Flutter as Flutter App

    Intruder->>Arduino: PIR Motion Triggered
    Arduino->>FaceAI: Wakes up Face Recognition
    loop 3 Consecutive Frames
        FaceAI->>Camera: Fetch Frame
        FaceAI->>FaceAI: Detect face -> Compare with Known Encodings
        Note over FaceAI: Distance > 0.55 (No match found)
    end

    Note over FaceAI: Intruder Confirmed (3 frames threshold)
    FaceAI->>Arduino: send_command("CMD:ALERT")
    Arduino->>Arduino: Pulse Buzzer Siren & Flash Red Strobe
    FaceAI->>Camera: save_snapshot()
    Camera-->>FaceAI: Saved "snap_intruder_xxx.jpg"
    FaceAI->>DB: Log INTRUDER_ALERT (is_critical = True)
    FaceAI->>WS: Broadcast {"type": "INTRUDER_ALERT", "title": "Intruder Warning!"}
    WS->>Flutter: Show Persistent Red Alert Banner & Snapshot Preview
```

---

### Sequence 3: Manual Door Control via Mobile App

```mermaid
sequenceDiagram
    autonumber
    actor User as Mobile App User
    participant Flutter as Flutter App
    participant FastAPI as Backend Router
    participant Serial as Serial Service
    participant Arduino as Arduino Controller
    participant WS as WebSocket Hub

    User->>Flutter: Taps Glowing Door Lock Button
    Flutter->>FastAPI: POST /api/door/unlock (with JWT Header)
    FastAPI->>Serial: unlock_door()
    Serial->>Arduino: Transmit "CMD:UNLOCK\n"
    Arduino->>Arduino: Rotate Servo to 90°
    Arduino-->>Serial: Confirm "STATUS:DOOR:UNLOCKED"
    FastAPI->>WS: Broadcast {"type": "DOOR_STATE_CHANGED", "door_locked": false}
    WS-->>Flutter: Sync State Across All Active Mobile Clients
    FastAPI-->>Flutter: HTTP 200 OK {"door_locked": false}
```

---

## 3. Database Entity-Relationship Diagram (ERD)

The system utilizes an embedded, zero-configuration SQLite database (`security_hub.db`) managed through SQLAlchemy ORM.

```mermaid
erDiagram
    USERS {
        int id PK
        string email UK
        string hashed_password
        string full_name
        boolean is_admin
        datetime created_at
    }

    SECURITY_EVENTS {
        int id PK
        datetime timestamp
        string event_type
        string title
        text description
        string person_name
        string snapshot_url
        boolean is_critical
        boolean is_read
    }

    AUTHORIZED_PERSONS {
        int id PK
        string name UK
        string relationship
        string photo_filename
        boolean is_active
        datetime created_at
    }

    USERS ||--o{ SECURITY_EVENTS : reviews
    AUTHORIZED_PERSONS ||--o{ SECURITY_EVENTS : triggers
```

---

## 4. Communication Protocol Specifications

### 4.1. USB Serial UART Protocol
- **Baud Rate**: `115200`
- **Data Bits**: `8`
- **Stop Bits**: `1`
- **Parity**: `None`
- **Line Ending**: `\n` (ASCII)

| Direction | Command / Message | Description |
| :--- | :--- | :--- |
| Arduino ➔ Laptop | `EVENT:PIR_MOTION` | PIR digital output went HIGH (Motion detected) |
| Arduino ➔ Laptop | `EVENT:PIR_IDLE` | PIR output cleared to LOW (Area is clear) |
| Arduino ➔ Laptop | `EVENT:MANUAL_BUTTON_PRESSED` | Physical indoor button toggled |
| Arduino ➔ Laptop | `EVENT:AUTO_LOCK_TRIGGERED` | Hardware auto-lock timer (10s) locked the bolt |
| Arduino ➔ Laptop | `STATUS:DOOR:LOCKED` | Door bolt confirmed in locked position (0°) |
| Arduino ➔ Laptop | `STATUS:DOOR:UNLOCKED` | Door bolt confirmed in unlocked position (90°) |
| Laptop ➔ Arduino | `CMD:UNLOCK` | Move servo to 90°, play chime, enable green LED |
| Laptop ➔ Arduino | `CMD:LOCK` | Move servo to 0°, enable red LED |
| Laptop ➔ Arduino | `CMD:ALERT` | Trigger buzzer siren and strobe red LED |
| Laptop ➔ Arduino | `CMD:STATUS` | Request immediate state report |
| Laptop ➔ Arduino | `CMD:PING` | Connectivity heartbeat (Arduino replies with `PONG`) |

---

### 4.2. Live MJPEG Streaming Protocol
The laptop webcam is served over standard HTTP using the `multipart/x-mixed-replace` MIME type:
- **Endpoint**: `GET /api/video/feed`
- **Content-Type**: `multipart/x-mixed-replace; boundary=frame`
- **Boundary Header**:
  ```http
  --frame
  Content-Type: image/jpeg
  Content-Length: <size>

  <JPEG binary payload>
  ```
- **Frame Rate**: ~25 FPS throttled.
- **Benefits**: Supported natively by web browsers and parsed with zero-latency in Flutter without requiring heavy FFmpeg native libraries or RTSP setup.
