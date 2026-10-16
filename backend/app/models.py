from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text
from app.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=True)
    is_admin = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class SecurityEvent(Base):
    __tablename__ = "security_events"

    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    event_type = Column(String(50), nullable=False, index=True) # MOTION, ACCESS_GRANTED, INTRUDER_ALERT, MANUAL_UNLOCK, DOOR_LOCKED
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    person_name = Column(String(100), nullable=True)
    snapshot_url = Column(String(500), nullable=True)
    is_critical = Column(Boolean, default=False)
    is_read = Column(Boolean, default=False)

class AuthorizedPerson(Base):
    __tablename__ = "authorized_persons"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, nullable=False, index=True)
    relationship = Column(String(50), default="Family") # Family, Friend, Staff, Resident
    photo_filename = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
