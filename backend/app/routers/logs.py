from typing import List, Optional
from datetime import datetime, date
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.database import get_db
from app.models import SecurityEvent
from app.schemas import SecurityEventResponse

router = APIRouter(prefix="/logs", tags=["Activity Logs & Alerts"])

@router.get("", response_model=List[SecurityEventResponse])
def get_logs(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    critical_only: bool = Query(False),
    event_type: Optional[str] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(SecurityEvent)
    if critical_only:
        query = query.filter(SecurityEvent.is_critical == True)
    if event_type:
        query = query.filter(SecurityEvent.event_type == event_type)
        
    return query.order_by(SecurityEvent.timestamp.desc()).offset(offset).limit(limit).all()

@router.get("/stats")
def get_log_stats(db: Session = Depends(get_db)):
    today_start = datetime.combine(date.today(), datetime.min.time())
    
    total_events = db.query(SecurityEvent).count()
    events_today = db.query(SecurityEvent).filter(SecurityEvent.timestamp >= today_start).count()
    intruders_count = db.query(SecurityEvent).filter(SecurityEvent.event_type == "INTRUDER_ALERT").count()
    access_granted_count = db.query(SecurityEvent).filter(SecurityEvent.event_type == "ACCESS_GRANTED").count()
    
    return {
        "total_events": total_events,
        "events_today": events_today,
        "intruders_detected": intruders_count,
        "authorized_unlocks": access_granted_count
    }

@router.put("/{event_id}/read")
def mark_as_read(event_id: int, db: Session = Depends(get_db)):
    event = db.query(SecurityEvent).filter(SecurityEvent.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    event.is_read = True
    db.commit()
    return {"status": "ok"}
