import os
from pathlib import Path
from pydantic_settings import BaseSettings

BASE_DIR = Path(__file__).resolve().parent.parent

class Settings(BaseSettings):
    PROJECT_NAME: str = "Smart IoT Home Security System"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api"
    
    # Security / Auth
    SECRET_KEY: str = "smart-home-iot-super-secret-key-change-in-production-2026"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    
    # Serial / Hardware
    SERIAL_PORT: str = "COM3"  # Change to your Arduino COM port (e.g., COM3, COM4, /dev/ttyUSB0)
    SERIAL_BAUDRATE: int = 115200
    SIMULATION_MODE: bool = True  # Set to True when developing without physical Arduino
    
    # Camera & Vision
    CAMERA_INDEX: int = 0  # 0 for default laptop webcam
    FRAME_WIDTH: int = 640
    FRAME_HEIGHT: int = 480
    FACE_MATCH_TOLERANCE: float = 0.55
    RECORD_CONTINUOUSLY: bool = True
    
    # Storage Paths
    STATIC_DIR: Path = BASE_DIR / "static"
    SNAPSHOTS_DIR: Path = BASE_DIR / "static" / "snapshots"
    KNOWN_FACES_DIR: Path = BASE_DIR / "static" / "known_faces"
    
    # Database
    DATABASE_URL: str = f"sqlite:///{BASE_DIR}/security_hub.db"

    class Config:
        env_file = ".env"
        extra = "allow"

settings = Settings()

# Ensure directories exist
settings.SNAPSHOTS_DIR.mkdir(parents=True, exist_ok=True)
settings.KNOWN_FACES_DIR.mkdir(parents=True, exist_ok=True)
