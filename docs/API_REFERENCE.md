# 📚 REST API & WebSocket Reference Manual

This document provides a comprehensive API specification for the **Smart Home Security Edge Server**.

- **Base URL**: `http://<laptop-ip>:8000`
- **Interactive Documentation**: `http://<laptop-ip>:8000/docs` (Swagger UI) or `/redoc`
- **Default Authentication Scheme**: JWT Bearer Token (`Authorization: Bearer <token>`)

---

## 1. Authentication Endpoints

### 1.1 Register New User
Creates a new administrative or household account.

- **Method**: `POST`
- **Path**: `/api/auth/register`
- **Request Headers**: `Content-Type: application/json`
- **Request Body**:
  ```json
  {
    "email": "ishant@home.local",
    "password": "SecretPassword123",
    "full_name": "Ishant Sharma"
  }
  ```
- **Response** (`201 Created`):
  ```json
  {
    "id": 2,
    "email": "ishant@home.local",
    "full_name": "Ishant Sharma",
    "is_admin": true,
    "created_at": "2026-10-16T22:30:00"
  }
  ```

---

### 1.2 User Login
Authenticates an existing user and returns a signed JWT access token.

- **Method**: `POST`
- **Path**: `/api/auth/login`
- **Request Headers**: `Content-Type: application/json`
- **Request Body**:
  ```json
  {
    "email": "admin@home.local",
    "password": "admin123"
  }
  ```
- **Response** (`200 OK`):
  ```json
  {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "token_type": "bearer",
    "user": {
      "id": 1,
      "email": "admin@home.local",
      "full_name": "Ishant (Home Owner)",
      "is_admin": true,
      "created_at": "2026-10-16T22:00:00"
    }
  }
  ```

---

### 1.3 Get Current User Profile
- **Method**: `GET`
- **Path**: `/api/auth/me`
- **Request Headers**: `Authorization: Bearer <token>`
- **Response** (`200 OK`):
  ```json
  {
    "id": 1,
    "email": "admin@home.local",
    "full_name": "Ishant (Home Owner)",
    "is_admin": true,
    "created_at": "2026-10-16T22:00:00"
  }
  ```

---

## 2. Door Control & System Telemetry

### 2.1 Get System Telemetry & Status
Returns real-time status of the door bolt, PIR sensor, face AI loop, and serial connection.

- **Method**: `GET`
- **Path**: `/api/door/status`
- **Response** (`200 OK`):
  ```json
  {
    "door_locked": true,
    "pir_active": false,
    "face_recognition_active": false,
    "camera_online": true,
    "serial_connected": true,
    "simulation_mode": false,
    "timestamp": "2026-10-16T22:55:00.123456"
  }
  ```

---

### 2.2 Remote Door Unlock
Transmits `CMD:UNLOCK` to the Arduino to retract the deadbolt.

- **Method**: `POST`
- **Path**: `/api/door/unlock`
- **Request Body** (Optional):
  ```json
  {
    "action": "unlock",
    "reason": "Remote unlock from Mobile App"
  }
  ```
- **Response** (`200 OK`):
  ```json
  {
    "status": "success",
    "message": "Door unlocked successfully",
    "door_locked": false
  }
  ```

---

### 2.3 Remote Door Lock
Transmits `CMD:LOCK` to the Arduino to engage the deadbolt.

- **Method**: `POST`
- **Path**: `/api/door/lock`
- **Request Body** (Optional):
  ```json
  {
    "action": "lock",
    "reason": "Remote lock from Mobile App"
  }
  ```
- **Response** (`200 OK`):
  ```json
  {
    "status": "success",
    "message": "Door locked successfully",
    "door_locked": true
  }
  ```

---

### 2.4 Simulate PIR Trigger (Testing Helper)
Simulates a physical PIR state change to test the Face AI pipeline without hardware.

- **Method**: `POST`
- **Path**: `/api/door/simulate-pir?active=true`
- **Response** (`200 OK`):
  ```json
  {
    "status": "ok",
    "pir_active": true
  }
  ```

---

## 3. Video Surveillance & Snapshot API

### 3.1 Live Camera MJPEG Stream
Provides an ongoing multipart JPEG stream directly from the laptop webcam with real-time HUD overlays.

- **Method**: `GET`
- **Path**: `/api/video/feed`
- **Response Headers**: `Content-Type: multipart/x-mixed-replace; boundary=frame`
- **Usage in Web/Flutter**:
  ```dart
  // In Flutter:
  MjpegStreamView(streamUrl: "http://192.168.1.15:8000/api/video/feed")
  
  // In HTML:
  <img src="http://192.168.1.15:8000/api/video/feed" width="640" height="480" />
  ```

---

### 3.2 Capture High-Resolution Snapshot
Captures and returns the latest video frame as a standalone JPEG.

- **Method**: `GET`
- **Path**: `/api/video/snapshot`
- **Response Headers**: `Content-Type: image/jpeg`
- **Response Body**: Binary JPEG image.

---

## 4. Security Activity Logs

### 4.1 Fetch Activity Logs
Returns chronologically ordered security events with pagination and filtering.

- **Method**: `GET`
- **Path**: `/api/logs?limit=50&offset=0&critical_only=false`
- **Query Parameters**:
  - `limit` (int, default 50, max 200)
  - `offset` (int, default 0)
  - `critical_only` (bool, default false)
  - `event_type` (string, optional: `MOTION`, `ACCESS_GRANTED`, `INTRUDER_ALERT`, `MANUAL_UNLOCK`, `DOOR_LOCKED`)
- **Response** (`200 OK`):
  ```json
  [
    {
      "id": 14,
      "timestamp": "2026-10-16T22:31:05.123456",
      "event_type": "ACCESS_GRANTED",
      "title": "Welcome Ishant!",
      "description": "Authorized face verified. Door automatically unlocked.",
      "person_name": "Ishant",
      "snapshot_url": "/static/snapshots/snap_20261016_223105.jpg",
      "is_critical": false,
      "is_read": true
    },
    {
      "id": 13,
      "timestamp": "2026-10-16T22:28:12.654321",
      "event_type": "INTRUDER_ALERT",
      "title": "Intruder Warning!",
      "description": "Unrecognized person detected lingering at the entrance.",
      "person_name": "Unknown Intruder",
      "snapshot_url": "/static/snapshots/snap_20261016_222812.jpg",
      "is_critical": true,
      "is_read": false
    }
  ]
  ```

---

### 4.2 Activity Log Statistics
Returns daily and aggregate security metrics.

- **Method**: `GET`
- **Path**: `/api/logs/stats`
- **Response** (`200 OK`):
  ```json
  {
    "total_events": 48,
    "events_today": 12,
    "intruders_detected": 2,
    "authorized_unlocks": 10
  }
  ```

---

## 5. Authorized Faces Management

### 5.1 List Authorized Faces
- **Method**: `GET`
- **Path**: `/api/faces`
- **Response** (`200 OK`):
  ```json
  [
    {
      "id": 1,
      "name": "Ishant",
      "relationship": "Family",
      "photo_filename": "ishant.jpg",
      "is_active": true,
      "created_at": "2026-10-16T22:15:00"
    }
  ]
  ```

---

### 5.2 Enroll New Authorized Face
Uploads a photo of a family member, generates face encodings, and triggers real-time hot-reloading in the vision service.

- **Method**: `POST`
- **Path**: `/api/faces`
- **Content-Type**: `multipart/form-data`
- **Form Fields**:
  - `name`: string (e.g., `"Pooja"`)
  - `relationship`: string (e.g., `"Family"`, `"Friend"`, `"Staff"`)
  - `photo`: binary file (JPEG or PNG)
- **Response** (`200 OK`):
  ```json
  {
    "id": 2,
    "name": "Pooja",
    "relationship": "Family",
    "photo_filename": "pooja.jpg",
    "is_active": true,
    "created_at": "2026-10-16T22:45:00"
  }
  ```

---

### 5.3 Delete Authorized Face
- **Method**: `DELETE`
- **Path**: `/api/faces/{person_id}`
- **Response** (`200 OK`):
  ```json
  {
    "status": "ok",
    "message": "Person deleted successfully"
  }
  ```

---

## 6. Real-Time WebSockets Event Stream

- **Endpoint**: `ws://<laptop-ip>:8000/ws/events`
- **Heartbeat**: Send `"ping"` every 25 seconds; server replies with `{"type": "pong"}`.

### Event Message Schemas

#### Event: PIR Motion Detected
```json
{
  "type": "PIR_MOTION",
  "title": "Motion Detected",
  "message": "PIR sensor detected someone in front of door.",
  "timestamp": "2026-10-16T22:30:00.000000"
}
```

#### Event: Area Clear (PIR Idle)
```json
{
  "type": "PIR_IDLE",
  "title": "Area Clear",
  "message": "Front door area is clear.",
  "timestamp": "2026-10-16T22:30:08.000000"
}
```

#### Event: Access Granted (Face Verified)
```json
{
  "type": "ACCESS_GRANTED",
  "title": "Door Unlocked",
  "message": "Welcome, Ishant! Face verified.",
  "person": "Ishant",
  "door_locked": false,
  "snapshot_url": "/static/snapshots/snap_20261016_223005.jpg",
  "timestamp": "2026-10-16T22:30:05.123456"
}
```

#### Event: Intruder Warning
```json
{
  "type": "INTRUDER_ALERT",
  "title": "Security Warning: Intruder Detected",
  "message": "Unrecognized individual spotted in front of the door camera.",
  "person": "Unknown Intruder",
  "door_locked": true,
  "snapshot_url": "/static/snapshots/snap_20261016_223120.jpg",
  "timestamp": "2026-10-16T22:31:20.654321"
}
```

#### Event: Door State Changed
```json
{
  "type": "DOOR_STATE_CHANGED",
  "door_locked": false,
  "message": "Door unlocked remotely from app",
  "timestamp": "2026-10-16T22:35:00.000000"
}
```
