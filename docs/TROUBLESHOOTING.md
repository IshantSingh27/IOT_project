# 🔧 Troubleshooting & FAQ Guide

This guide provides step-by-step solutions for common issues across the Arduino hardware, Python backend, and Flutter mobile application.

---

## 1. Arduino & Serial Interface Issues

### Issue 1.1: `SerialException: could not open port 'COM3'`
**Causes**:
1. The Arduino is assigned to a different COM port (e.g., `COM4` or `COM5`).
2. Another application (like the Arduino IDE Serial Monitor) has the port open.

**Fix**:
1. Close the Arduino IDE Serial Monitor window.
2. Open Windows Device Manager ➔ **Ports (COM & LPT)** to find the exact COM number.
3. Update `SERIAL_PORT` in `backend/app/config.py` or `.env`:
   ```ini
   SERIAL_PORT=COM4
   ```
4. Note: The backend includes automatic port scanning and will fall back to **Simulation Mode** if the hardware is not plugged in, so your testing is never blocked.

---

### Issue 1.2: Arduino Reboots or Resets When Servo Moves
**Cause**: The servo motor draws excessive current when starting rotation, causing the USB 5V rail to dip below 4.5V (Microcontroller Brownout Reset).

**Fix**:
1. Power the servo motor from an external 5V 2A power adapter or 4x AA battery pack.
2. **Important**: Connect the external power ground (-) to the Arduino **GND** pin (Common Ground).
3. Place a 100µF – 470µF electrolytic capacitor across the servo’s 5V and GND terminals.

---

### Issue 1.3: PIR Sensor Stays Constantly Active (Never Goes Idle)
**Causes**:
1. The HC-SR501 time delay potentiometer is turned too high.
2. Sensitivity is set too high, detecting warm air currents or motion far down the hallway.

**Fix**:
1. Turn the **Time Delay potentiometer** (marked 'Tx') all the way **counter-clockwise**.
2. Turn the **Sensitivity potentiometer** (marked 'Sx') counter-clockwise to reduce detection radius to ~2 meters.
3. Make sure the trigger jumper is set to **H (Repeatable Trigger)**.

---

## 2. Laptop Webcam & Vision Hub Issues

### Issue 2.1: Camera Frame is Black or Shows Error 503
**Causes**:
1. Another app (Zoom, Teams, Skype, Windows Camera app) has an exclusive lock on the webcam.
2. Windows Camera Privacy Settings are blocking desktop apps.

**Fix**:
1. Close any running video conferencing software.
2. In Windows Settings ➔ **Privacy & Security** ➔ **Camera**:
   - Turn ON **"Let apps access your camera"**.
   - Turn ON **"Let desktop apps access your camera"**.
3. Note: The backend includes an automated fallback mechanism: if the physical webcam is unavailable, it automatically serves a high-tech simulated security camera test card.

---

### Issue 2.2: Face Recognition Is Slow or Inaccurate
**Causes**:
1. Dim lighting in front of the camera.
2. Enrolled face photo was blurry or at an extreme angle.

**Fix**:
1. Enroll clear, well-lit frontal face photos in the app's **Authorized Faces** tab.
2. Adjust the matching threshold in `backend/app/config.py`:
   ```python
   # Lower = Stricter (less false accepts), Higher = More lenient (more false accepts)
   FACE_MATCH_TOLERANCE = 0.52
   ```

---

## 3. Flutter Mobile & Network Connectivity Issues

### Issue 3.1: Flutter App Shows `Connection Refused` or `SocketException`
**Causes**:
1. The phone is pointing to `localhost` (which refers to the phone itself, not the laptop!).
2. Laptop and mobile phone are on different Wi-Fi networks (e.g., Guest Wi-Fi with client isolation).
3. Windows Firewall is blocking inbound port 8000.

**Fix**:
1. **Find Laptop IP**: Run `ipconfig` in Windows Command Prompt and locate your IPv4 address (e.g., `192.168.1.15`).
2. **In Android Emulator**: Use `http://10.0.2.2:8000` (Android emulator's loopback alias for host machine).
3. **In Physical Phone**:
   - Tap the network icon on the Login screen (or open Settings).
   - Enter `http://192.168.1.15:8000`.
   - Tap **Test Ping**.
4. **Allow Windows Firewall**:
   Run in PowerShell as Administrator:
   ```powershell
   New-NetFirewallRule -DisplayName "FastAPI IoT Hub" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
   ```

---

### Issue 3.2: Live Video Stream Stutters or Freezes
**Causes**:
1. High network packet loss over congested 2.4 GHz Wi-Fi.

**Fix**:
1. In `flutter_app/lib/widgets/mjpeg_stream_view.dart`, tap the **Reconnect** button.
2. In `backend/app/config.py`, frame width and height can be tuned to 640x480 for lower bandwidth:
   ```python
   FRAME_WIDTH = 640
   FRAME_HEIGHT = 480
   ```
