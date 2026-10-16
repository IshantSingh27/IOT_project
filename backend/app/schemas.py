from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel

# Auth Schemas
class UserBase(BaseModel):
    email: str
    full_name: Optional[str] = None

class UserCreate(UserBase):
    password: str

class UserLogin(BaseModel):
    email: str
    password: str

class UserResponse(UserBase):
    id: int
    is_admin: bool
    created_at: datetime

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse

class TokenData(BaseModel):
    email: Optional[str] = None

# Security Events Schemas
class SecurityEventCreate(BaseModel):
    event_type: str
    title: str
    description: Optional[str] = None
    person_name: Optional[str] = None
    snapshot_url: Optional[str] = None
    is_critical: bool = False

class SecurityEventResponse(BaseModel):
    id: int
    timestamp: datetime
    event_type: str
    title: str
    description: Optional[str] = None
    person_name: Optional[str] = None
    snapshot_url: Optional[str] = None
    is_critical: bool
    is_read: bool

    class Config:
        from_attributes = True

# Door & System Status
class DoorCommand(BaseModel):
    action: str # "unlock" or "lock"
    reason: Optional[str] = "Manual remote trigger"

class SystemStatusResponse(BaseModel):
    door_locked: bool
    pir_active: bool
    face_recognition_active: bool
    camera_online: bool
    serial_connected: bool
    simulation_mode: bool
    timestamp: datetime

# Authorized Person
class AuthorizedPersonCreate(BaseModel):
    name: str
    relationship: str = "Family"

class AuthorizedPersonResponse(BaseModel):
    id: int
    name: str
    relationship: str
    photo_filename: Optional[str]
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True
