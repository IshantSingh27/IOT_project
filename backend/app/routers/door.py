from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import SecurityEvent, User
from app.schemas import SystemStatusResponse, DoorCommand
from app.services.serial_service import serial_service
from app.services.camera_service import camera_service
from app.services.websocket_service import ws_manager
from app.config import settings

router = APIRouter(prefix="/door", tags=["Door Control & Telemetry"])

@router.get("/status", response_model=SystemStatusResponse)
def get_system_status():
    return {
        "door_locked": serial_service.is_door_locked,
        "pir_active": serial_service.is_pir_active,
        "face_recognition_active": camera_service.face_recognition_active,
        "camera_online": camera_service.is_running,
        "serial_connected": serial_service.is_connected,
        "simulation_mode": settings.SIMULATION_MODE,
        "timestamp": datetime.utcnow()
    }

@router.post("/unlock")
async def unlock_door(cmd: DoorCommand = DoorCommand(action="unlock"), db: Session = Depends(get_db)):
    success = serial_service.unlock_door()
    if not success:
        raise HTTPException(status_code=500, detail="Failed to transmit unlock command to Arduino.")
    
    # Log manual unlock event
    event = SecurityEvent(
        event_type="MANUAL_UNLOCK",
        title="Door Unlocked Remotely",
        description=cmd.reason or "Unlocked via Mobile App",
        is_critical=False
    )
    db.add(event)
    db.commit()

    # Broadcast state update to all connected Flutter apps
    await ws_manager.broadcast({
        "type": "DOOR_STATE_CHANGED",
        "door_locked": False,
        "message": "Door unlocked remotely from app",
        "timestamp": datetime.utcnow().isoformat()
    })

    return {"status": "success", "message": "Door unlocked successfully", "door_locked": False}

@router.post("/lock")
async def lock_door(cmd: DoorCommand = DoorCommand(action="lock"), db: Session = Depends(get_db)):
    success = serial_service.lock_door()
    if not success:
        raise HTTPException(status_code=500, detail="Failed to transmit lock command to Arduino.")
    
    event = SecurityEvent(
        event_type="DOOR_LOCKED",
        title="Door Locked Remotely",
        description=cmd.reason or "Locked via Mobile App",
        is_critical=False
    )
    db.add(event)
    db.commit()

    await ws_manager.broadcast({
        "type": "DOOR_STATE_CHANGED",
        "door_locked": True,
        "message": "Door locked remotely from app",
        "timestamp": datetime.utcnow().isoformat()
    })

    return {"status": "success", "message": "Door locked successfully", "door_locked": True}

@router.post("/simulate-pir")
async def simulate_pir(active: bool = True):
    """Developer helper: trigger mock PIR motion or idle state to test Face Recognition."""
    if active:
        serial_service.simulate_pir_motion()
    else:
        serial_service.simulate_pir_idle()
    return {"status": "ok", "pir_active": active}
