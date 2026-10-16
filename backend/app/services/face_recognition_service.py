import os
import cv2
import time
import asyncio
import logging
import threading
import numpy as np
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from datetime import datetime

from app.config import settings
from app.services.camera_service import camera_service
from app.services.serial_service import serial_service
from app.services.websocket_service import ws_manager
from app.database import SessionLocal
from app.models import SecurityEvent, AuthorizedPerson

logger = logging.getLogger("face_recognition_service")

# Try importing face_recognition (dlib-based); if unavailable, fall back cleanly to OpenCV
try:
    import face_recognition
    FACE_RECOGNITION_LIB_AVAILABLE = True
    logger.info("Using 'face_recognition' library (dlib backend) for face verification.")
except ImportError:
    face_recognition = None
    FACE_RECOGNITION_LIB_AVAILABLE = False
    logger.info("Using OpenCV Cascade & Feature Matcher for face verification fallback.")

class FaceRecognitionService:
    def __init__(self):
        self.is_running: bool = False
        self.is_pir_active: bool = False
        self.worker_thread: Optional[threading.Thread] = None
        
        # Haar cascade for fallback fast face detection
        cascade_path = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
        self.face_cascade = cv2.CascadeClassifier(cascade_path)
        
        # Known faces cache
        self.known_face_encodings: List[np.ndarray] = []
        self.known_face_names: List[str] = []
        self.known_face_histograms: Dict[str, np.ndarray] = {}
        
        # Cooldown & Debounce trackers
        self.last_unlock_time: float = 0.0
        self.last_intruder_alert_time: float = 0.0
        self.ACTION_COOLDOWN_SECONDS: float = 8.0 # Don't re-trigger actions within 8s
        
        self.unknown_face_counter: int = 0
        self.lock = threading.Lock()

    def start(self):
        self.is_running = True
        self.reload_known_faces()
        
        # Hook into serial service PIR triggers
        serial_service.register_pir_motion_callback(self.on_pir_motion_detected)
        serial_service.register_pir_idle_callback(self.on_pir_idle_detected)
        
        self.worker_thread = threading.Thread(target=self._processing_loop, daemon=True)
        self.worker_thread.start()
        logger.info("FaceRecognitionService started.")

    def stop(self):
        self.is_running = False
        if self.worker_thread and self.worker_thread.is_alive():
            self.worker_thread.join(timeout=2.0)

    def reload_known_faces(self):
        """Loads and encodes all images stored in static/known_faces directory."""
        with self.lock:
            self.known_face_encodings.clear()
            self.known_face_names.clear()
            self.known_face_histograms.clear()
            
            face_dir = settings.KNOWN_FACES_DIR
            if not face_dir.exists():
                return
                
            for img_path in face_dir.glob("*.*"):
                if img_path.suffix.lower() not in [".jpg", ".jpeg", ".png"]:
                    continue
                name = img_path.stem.replace("_", " ").title()
                
                # Load image
                image = cv2.imread(str(img_path))
                if image is None:
                    continue

                if FACE_RECOGNITION_LIB_AVAILABLE:
                    try:
                        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
                        encodings = face_recognition.face_encodings(rgb)
                        if encodings:
                            self.known_face_encodings.append(encodings[0])
                            self.known_face_names.append(name)
                            logger.info(f"Loaded face encoding for: {name}")
                    except Exception as e:
                        logger.warning(f"Error encoding {img_path.name}: {e}")
                
                # Also generate normalized face color/texture histogram for fallback
                gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
                faces = self.face_cascade.detectMultiScale(gray, 1.1, 4)
                if len(faces) > 0:
                    (x, y, w, h) = faces[0]
                    roi = gray[y:y+h, x:x+w]
                    roi_resized = cv2.resize(roi, (100, 100))
                    hist = cv2.calcHist([roi_resized], [0], None, [32], [0, 256])
                    cv2.normalize(hist, hist)
                    self.known_face_histograms[name] = hist
                    if not FACE_RECOGNITION_LIB_AVAILABLE:
                        self.known_face_names.append(name)
                        logger.info(f"Loaded OpenCV face histogram for: {name}")

    def on_pir_motion_detected(self):
        logger.info("PIR Triggered! Activating Face Recognition pipeline.")
        self.is_pir_active = True
        camera_service.set_face_recognition_state(True)
        
        # Broadcast motion event to Flutter app
        self._async_broadcast({
            "type": "PIR_MOTION",
            "title": "Motion Detected",
            "message": "PIR sensor detected someone in front of door.",
            "timestamp": datetime.now().isoformat()
        })
        
        # Log to DB
        self._log_event(
            event_type="MOTION",
            title="Motion Detected",
            description="PIR sensor triggered face recognition activation.",
            is_critical=False
        )

    def on_pir_idle_detected(self):
        logger.info("PIR Idle. Putting Face Recognition to sleep (zero ML overhead).")
        self.is_pir_active = False
        self.unknown_face_counter = 0
        camera_service.set_face_recognition_state(False)
        
        self._async_broadcast({
            "type": "PIR_IDLE",
            "title": "Area Clear",
            "message": "Front door area is clear.",
            "timestamp": datetime.now().isoformat()
        })

    def _processing_loop(self):
        while self.is_running:
            # ONLY run recognition when PIR sensor detects motion
            if not self.is_pir_active:
                time.sleep(0.1) # Sleep without model overhead
                continue

            frame = camera_service.get_latest_frame()
            if frame is None:
                time.sleep(0.1)
                continue

            # Process frame for faces
            self._recognize_faces(frame)
            time.sleep(0.15) # ~6-7 checks per second is ideal for real-time edge

    def _recognize_faces(self, frame: np.ndarray):
        hud_boxes = []
        recognized_person = None
        has_unrecognized_face = False
        
        # Approach 1: High-accuracy face_recognition (dlib)
        if FACE_RECOGNITION_LIB_AVAILABLE and len(self.known_face_encodings) > 0:
            rgb_small = cv2.resize(frame, (0, 0), fx=0.5, fy=0.5)
            rgb_small = cv2.cvtColor(rgb_small, cv2.COLOR_BGR2RGB)
            
            face_locations = face_recognition.face_locations(rgb_small)
            face_encodings = face_recognition.face_encodings(rgb_small, face_locations)
            
            for (top, right, bottom, left), face_encoding in zip(face_locations, face_encodings):
                # Scale back up
                top *= 2
                right *= 2
                bottom *= 2
                left *= 2
                w = right - left
                h = bottom - top
                
                matches = face_recognition.compare_faces(self.known_face_encodings, face_encoding, tolerance=settings.FACE_MATCH_TOLERANCE)
                name = "Unknown Intruder"
                color = (0, 0, 255) # Red
                
                face_distances = face_recognition.face_distance(self.known_face_encodings, face_encoding)
                if len(face_distances) > 0:
                    best_match_idx = np.argmin(face_distances)
                    if matches[best_match_idx]:
                        name = self.known_face_names[best_match_idx]
                        color = (0, 255, 0) # Green
                        recognized_person = name
                    else:
                        has_unrecognized_face = True
                else:
                    has_unrecognized_face = True
                    
                hud_boxes.append((left, top, w, h, name, color))
                
        else:
            # Approach 2: Robust OpenCV Haar Cascade + Histogram/Template Fallback
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces = self.face_cascade.detectMultiScale(gray, scaleFactor=1.2, minNeighbors=5, minSize=(60, 60))
            
            for (x, y, w, h) in faces:
                name = "Unknown Intruder"
                color = (0, 0, 255) # Red
                
                # If we have registered face histograms, compare correlation
                if self.known_face_histograms:
                    roi = gray[y:y+h, x:x+w]
                    roi_resized = cv2.resize(roi, (100, 100))
                    hist = cv2.calcHist([roi_resized], [0], None, [32], [0, 256])
                    cv2.normalize(hist, hist)
                    
                    best_score = -1.0
                    best_name = None
                    for k_name, k_hist in self.known_face_histograms.items():
                        score = cv2.compareHist(hist, k_hist, cv2.HISTCMP_CORREL)
                        if score > best_score:
                            best_score = score
                            best_name = k_name
                            
                    if best_score > 0.65 and best_name:
                        name = f"{best_name}"
                        color = (0, 255, 0) # Green
                        recognized_person = best_name
                    else:
                        has_unrecognized_face = True
                else:
                    # When no faces have been registered yet in a brand new installation
                    has_unrecognized_face = True
                    
                hud_boxes.append((x, y, w, h, name, color))

        # Update live camera HUD with bounding boxes
        camera_service.set_detected_boxes(hud_boxes)
        
        # Handle Security Triggers
        current_time = time.time()
        
        if recognized_person:
            self.unknown_face_counter = 0
            if current_time - self.last_unlock_time > self.ACTION_COOLDOWN_SECONDS:
                self.last_unlock_time = current_time
                self._handle_authorized_person(recognized_person)
                
        elif has_unrecognized_face:
            self.unknown_face_counter += 1
            # Require 3 consecutive frames with unknown person to avoid transient shadows
            if self.unknown_face_counter >= 3:
                if current_time - self.last_intruder_alert_time > self.ACTION_COOLDOWN_SECONDS:
                    self.last_intruder_alert_time = current_time
                    self._handle_intruder_detected()
        else:
            self.unknown_face_counter = 0

    def _handle_authorized_person(self, person_name: str):
        logger.info(f"Authorized person recognized: {person_name}! Unlocking door.")
        
        # 1. Trigger hardware unlock
        serial_service.unlock_door()
        
        # 2. Capture snapshot
        snapshot_file = camera_service.save_snapshot()
        snapshot_url = f"/static/snapshots/{snapshot_file}" if snapshot_file else None
        
        # 3. Save to database
        self._log_event(
            event_type="ACCESS_GRANTED",
            title=f"Welcome {person_name}!",
            description=f"Authorized face verified. Door automatically unlocked.",
            person_name=person_name,
            snapshot_url=snapshot_url,
            is_critical=False
        )
        
        # 4. Broadcast to Flutter app
        self._async_broadcast({
            "type": "ACCESS_GRANTED",
            "title": "Door Unlocked",
            "message": f"Welcome, {person_name}! Face verified.",
            "person": person_name,
            "door_locked": False,
            "snapshot_url": snapshot_url,
            "timestamp": datetime.now().isoformat()
        })

    def _handle_intruder_detected(self):
        logger.warning("Unrecognized face detected! Triggering security alert.")
        
        # 1. Trigger hardware buzzer & red strobe
        serial_service.trigger_alert()
        
        # 2. Capture snapshot
        snapshot_file = camera_service.save_snapshot()
        snapshot_url = f"/static/snapshots/{snapshot_file}" if snapshot_file else None
        
        # 3. Save to database
        self._log_event(
            event_type="INTRUDER_ALERT",
            title="Intruder Warning!",
            description="Unrecognized person detected lingering at the entrance.",
            person_name="Unknown Intruder",
            snapshot_url=snapshot_url,
            is_critical=True
        )
        
        # 4. Broadcast critical alert to Flutter app
        self._async_broadcast({
            "type": "INTRUDER_ALERT",
            "title": "Security Warning: Intruder Detected",
            "message": "Unrecognized individual spotted in front of the door camera.",
            "person": "Unknown Intruder",
            "door_locked": serial_service.is_door_locked,
            "snapshot_url": snapshot_url,
            "timestamp": datetime.now().isoformat()
        })

    def _log_event(self, event_type: str, title: str, description: str, person_name: Optional[str] = None, snapshot_url: Optional[str] = None, is_critical: bool = False):
        try:
            db = SessionLocal()
            event = SecurityEvent(
                event_type=event_type,
                title=title,
                description=description,
                person_name=person_name,
                snapshot_url=snapshot_url,
                is_critical=is_critical
            )
            db.add(event)
            db.commit()
            db.close()
        except Exception as e:
            logger.error(f"Failed to log security event: {e}")

    def _async_broadcast(self, payload: dict):
        # WebSocket broadcast loop
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                asyncio.run_coroutine_threadsafe(ws_manager.broadcast(payload), loop)
            else:
                asyncio.run(ws_manager.broadcast(payload))
        except Exception:
            try:
                new_loop = asyncio.new_event_loop()
                new_loop.run_until_complete(ws_manager.broadcast(payload))
                new_loop.close()
            except Exception as e:
                logger.error(f"Error broadcasting WebSocket message: {e}")

face_service = FaceRecognitionService()
