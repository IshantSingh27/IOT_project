import sys
import time
from pathlib import Path
from fastapi.testclient import TestClient

# Add backend to path
backend_path = Path(__file__).resolve().parent.parent / "backend"
sys.path.insert(0, str(backend_path))

from app.main import app

def run_tests():
    print("=" * 60)
    print(" Running Automated Smart Home Backend & Vision Hub Tests")
    print("=" * 60)

    with TestClient(app) as client:
        # 1. Health check
        print("[TEST 1] Checking Root Endpoint...")
        r = client.get("/")
        assert r.status_code == 200, f"Expected 200, got {r.status_code}"
        print(f"  --> PASS: {r.json()['system']} ({r.json()['status']})")

        # 2. Login with seeded admin
        print("\n[TEST 2] Verifying Admin Authentication...")
        r = client.post("/api/auth/login", json={"email": "admin@home.local", "password": "admin123"})
        assert r.status_code == 200, f"Login failed: {r.text}"
        token = r.json()["access_token"]
        user = r.json()["user"]
        print(f"  --> PASS: Authenticated as {user['full_name']} ({user['email']})")

        # 3. Check System Status
        print("\n[TEST 3] Reading IoT System Telemetry...")
        r = client.get("/api/door/status")
        assert r.status_code == 200
        telemetry = r.json()
        print(f"  --> PASS: Door Locked = {telemetry['door_locked']}, PIR = {telemetry['pir_active']}, Simulation = {telemetry['simulation_mode']}")

        # 4. Remote Door Unlock
        print("\n[TEST 4] Testing Remote Door Unlock...")
        r = client.post("/api/door/unlock", json={"action": "unlock", "reason": "Automated Unit Test"})
        assert r.status_code == 200
        assert r.json()["door_locked"] is False
        print("  --> PASS: Door unlocked successfully")

        # 5. Remote Door Lock
        print("\n[TEST 5] Testing Remote Door Lock...")
        r = client.post("/api/door/lock", json={"action": "lock", "reason": "Automated Unit Test"})
        assert r.status_code == 200
        assert r.json()["door_locked"] is True
        print("  --> PASS: Door locked successfully")

        # 6. Simulate PIR motion trigger
        print("\n[TEST 6] Testing PIR Motion Simulation (Triggering Face AI)...")
        r = client.post("/api/door/simulate-pir?active=true")
        assert r.status_code == 200
        assert r.json()["pir_active"] is True
        print("  --> PASS: PIR Motion trigger registered")

        # 7. Check Activity Logs
        print("\n[TEST 7] Fetching Security Activity Logs...")
        r = client.get("/api/logs")
        assert r.status_code == 200
        logs = r.json()
        print(f"  --> PASS: Fetched {len(logs)} security log events")

        # 8. Camera snapshot
        print("\n[TEST 8] Fetching Live Camera Snapshot...")
        r = client.get("/api/video/snapshot")
        assert r.status_code == 200
        assert r.headers["content-type"] == "image/jpeg"
        print(f"  --> PASS: Received JPEG frame ({len(r.content)} bytes)")

        print("\n" + "=" * 60)
        print(" ALL 8 BACKEND AND VISION HUB TESTS PASSED WITH 100% SUCCESS!")
        print("=" * 60)

if __name__ == "__main__":
    run_tests()
