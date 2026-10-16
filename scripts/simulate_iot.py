"""
=============================================================================
Smart IoT Home Security - Hardware & Scenario Simulator
=============================================================================
This interactive script allows testing the entire security ecosystem
without requiring physical Arduino hardware plugged in.
It can trigger:
1. PIR Motion Detection (Activates Face AI)
2. PIR Idle (Puts Face AI to sleep)
3. Remote Door Unlock / Lock
4. Capture Live Snapshot
5. Query Real-Time Telemetry
=============================================================================
"""

import sys
import time
import requests

BASE_URL = "http://127.0.0.1:8000"

def check_backend():
    try:
        r = requests.get(f"{BASE_URL}/", timeout=2)
        if r.status_code == 200:
            print(f"[OK] Backend Hub is online: {r.json().get('system')}")
            return True
    except Exception:
        print(f"[ERROR] Could not connect to backend at {BASE_URL}.")
        print("Please make sure the backend is running (python run.py in backend/).")
        return False

def trigger_pir(active: bool):
    state_str = "MOTION DETECTED" if active else "IDLE / CLEAR"
    print(f"\n[ACTION] Triggering PIR Sensor -> {state_str}...")
    try:
        r = requests.post(f"{BASE_URL}/api/door/simulate-pir?active={'true' if active else 'false'}")
        print(f"[REPLY] Status: {r.status_code}, Payload: {r.json()}")
    except Exception as e:
        print(f"[ERROR] {e}")

def toggle_door(action: str):
    print(f"\n[ACTION] Sending Door Command -> {action.upper()}...")
    try:
        r = requests.post(f"{BASE_URL}/api/door/{action}", json={"action": action, "reason": "Simulator Trigger"})
        print(f"[REPLY] Status: {r.status_code}, Payload: {r.json()}")
    except Exception as e:
        print(f"[ERROR] {e}")

def get_status():
    print("\n--- System Telemetry ---")
    try:
        r = requests.get(f"{BASE_URL}/api/door/status")
        data = r.json()
        for k, v in data.items():
            print(f"  * {k.ljust(26)}: {v}")
    except Exception as e:
        print(f"[ERROR] {e}")

def main():
    print("=" * 60)
    print(" Smart IoT Home Security - Hardware & Scenario Simulator")
    print("=" * 60)
    
    if not check_backend():
        sys.exit(1)

    while True:
        print("\nChoose an action:")
        print(" [1] Trigger PIR Motion (Wakes up Face Recognition)")
        print(" [2] Clear PIR Motion (Puts Face Recognition to Sleep)")
        print(" [3] Unlock Door (Servo -> 90°)")
        print(" [4] Lock Door (Servo -> 0°)")
        print(" [5] View Live System Telemetry")
        print(" [q] Quit")
        
        choice = input("\nEnter choice (1-5/q): ").strip()
        if choice == '1':
            trigger_pir(True)
        elif choice == '2':
            trigger_pir(False)
        elif choice == '3':
            toggle_door("unlock")
        elif choice == '4':
            toggle_door("lock")
        elif choice == '5':
            get_status()
        elif choice.lower() == 'q':
            print("Exiting simulator.")
            break
        else:
            print("Invalid choice, please select 1-5.")

if __name__ == "__main__":
    main()
