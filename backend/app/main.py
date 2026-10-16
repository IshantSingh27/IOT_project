import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.database import engine, Base, SessionLocal
from app.models import User
from app.auth.security import get_password_hash
from app.services.camera_service import camera_service
from app.services.serial_service import serial_service
from app.services.face_recognition_service import face_service
from app.services.websocket_service import ws_manager

from app.routers import auth, door, stream, logs, faces

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("main")

def init_db_and_seed():
    """Create database tables and seed default admin user."""
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        admin = db.query(User).filter(User.email == "admin@home.local").first()
        if not admin:
            admin = User(
                email="admin@home.local",
                hashed_password=get_password_hash("admin123"),
                full_name="Ishant (Home Owner)",
                is_admin=True
            )
            db.add(admin)
            db.commit()
            logger.info("Default admin user created: admin@home.local / admin123")
    finally:
        db.close()

# Ensure tables and seed user are always created
try:
    init_db_and_seed()
except Exception as e:
    logger.warning(f"Initial DB seed error: {e}")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup sequence
    logger.info("Initializing Smart Home Security System...")
    init_db_and_seed()
    
    # Start hardware and vision edge threads
    camera_service.start()
    serial_service.start()
    face_service.start()
    
    logger.info(f"System ready! API docs available at http://localhost:8000/docs")
    yield
    
    # Shutdown sequence
    logger.info("Shutting down background services...")
    face_service.stop()
    serial_service.stop()
    camera_service.stop()
    logger.info("System shutdown complete.")

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    lifespan=lifespan
)

# Enable CORS for Flutter mobile, web, and emulator clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve static files (snapshots & face images)
app.mount("/static", StaticFiles(directory=str(settings.STATIC_DIR)), name="static")

# Mount API Routers
app.include_router(auth.router, prefix=settings.API_V1_STR)
app.include_router(door.router, prefix=settings.API_V1_STR)
app.include_router(stream.router, prefix=settings.API_V1_STR)
app.include_router(logs.router, prefix=settings.API_V1_STR)
app.include_router(faces.router, prefix=settings.API_V1_STR)

# Real-time WebSocket endpoint for instant Flutter push updates
@app.websocket("/ws/events")
async def websocket_endpoint(websocket: WebSocket):
    await ws_manager.connect(websocket)
    try:
        while True:
            # Keep-alive ping loop
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text('{"type": "pong"}')
    except WebSocketDisconnect:
        ws_manager.disconnect(websocket)
    except Exception as e:
        logger.warning(f"WebSocket error: {e}")
        ws_manager.disconnect(websocket)

@app.get("/")
def root():
    return {
        "system": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "docs_url": "/docs",
        "live_stream": "/api/video/feed",
        "status": "Operational"
    }
