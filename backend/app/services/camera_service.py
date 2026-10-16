import cv2
import time
import threading
import logging
import numpy as np
from datetime import datetime
from pathlib import Path
from typing import Optional, Tuple, List
from app.config import settings

logger = logging.getLogger("camera_service")

class CameraService:
    def __init__(self):
        self.cap: Optional[cv2.VideoCapture] = None
        self.is_running: bool = False
        self.thread: Optional[threading.Thread] = None
        
        # Frame storage
        self.latest_raw_frame: Optional[np.ndarray] = None
        self.latest_display_frame: Optional[np.ndarray] = None
        self.lock = threading.Lock()
        
        # Overlay flags / metadata
        self.active_status_text: str = "SYSTEM SECURE"
        self.detected_boxes: List[Tuple[int, int, int, int, str, Tuple[int, int, int]]] = [] # (x, y, w, h, label, color)
        self.face_recognition_active: bool = False
        
        # Simulated camera state
        self.use_simulation: bool = False
        self.sim_frame_count: int = 0

    def start(self):
        self.is_running = True
        self._init_camera()
        self.thread = threading.Thread(target=self._capture_loop, daemon=True)
        self.thread.start()

    def stop(self):
        self.is_running = False
        if self.thread and self.thread.is_alive():
            self.thread.join(timeout=2.0)
        if self.cap:
            try:
                self.cap.release()
            except Exception:
                pass

    def _init_camera(self):
        logger.info(f"Attempting to open camera index {settings.CAMERA_INDEX}...")
        try:
            # On Windows, cv2.CAP_DSHOW can provide faster startup
            self.cap = cv2.VideoCapture(settings.CAMERA_INDEX, cv2.CAP_DSHOW)
            if not self.cap.isOpened():
                self.cap = cv2.VideoCapture(settings.CAMERA_INDEX)
                
            if self.cap.isOpened():
                self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, settings.FRAME_WIDTH)
                self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, settings.FRAME_HEIGHT)
                self.use_simulation = False
                logger.info("Successfully initialized hardware webcam.")
            else:
                logger.warning("Could not open hardware webcam. Initializing high-tech Simulated Feed.")
                self.use_simulation = True
        except Exception as e:
            logger.warning(f"Error accessing webcam: {e}. Switching to simulation feed.")
            self.use_simulation = True

    def _create_simulated_frame(self) -> np.ndarray:
        """Generates dynamic security camera test card when webcam is unavailable."""
        self.sim_frame_count += 1
        h, w = settings.FRAME_HEIGHT, settings.FRAME_WIDTH
        
        # Dark tech background with subtle grid
        frame = np.zeros((h, w, 3), dtype=np.uint8)
        frame[:] = (18, 20, 24)
        
        # Draw grid lines
        for y in range(0, h, 40):
            cv2.line(frame, (0, y), (w, y), (30, 34, 42), 1)
        for x in range(0, w, 40):
            cv2.line(frame, (x, 0), (x, h), (30, 34, 42), 1)
            
        # Draw simulated front porch / door outline
        cv2.rectangle(frame, (w//4, h//4), (3*w//4, 7*h//8), (45, 55, 72), 2)
        cv2.rectangle(frame, (w//4 + 20, h//4 + 20), (3*w//4 - 20, 7*h//8), (35, 42, 54), -1)
        cv2.circle(frame, (3*w//4 - 35, 9*h//16), 6, (200, 200, 200), -1) # Door handle
        
        # Simulated scanline
        scan_y = int((self.sim_frame_count * 3) % h)
        cv2.line(frame, (0, scan_y), (w, scan_y), (0, 180, 120), 1)
        
        return frame

    def _capture_loop(self):
        while self.is_running:
            raw = None
            if not self.use_simulation and self.cap and self.cap.isOpened():
                ret, frame = self.cap.read()
                if ret and frame is not None:
                    raw = frame
                else:
                    logger.warning("Camera read returned empty frame. Falling back to simulated feed.")
                    self.use_simulation = True
            
            if self.use_simulation or raw is None:
                raw = self._create_simulated_frame()
                time.sleep(0.04) # ~25 fps

            # Prepare annotated frame for stream
            display = raw.copy()
            self._render_hud(display)

            with self.lock:
                self.latest_raw_frame = raw
                self.latest_display_frame = display

    def _render_hud(self, frame: np.ndarray):
        h, w, _ = frame.shape
        now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # Camera Feed Title & Timestamp
        cv2.putText(frame, "CAM 01 - FRONT DOOR", (15, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (220, 220, 220), 2)
        cv2.putText(frame, now_str, (w - 220, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (180, 180, 180), 1)
        
        # Motion / ML Status Pill
        if self.face_recognition_active:
            status_color = (0, 140, 255) # Orange
            status_text = "[ PIR ACTIVE: FACE RECOGNITION RUNNING ]"
        else:
            status_color = (0, 220, 100) # Green
            status_text = "[ STANDBY: CONTINUOUS RECORDING (0% ML LOAD) ]"
            
        cv2.putText(frame, status_text, (15, h - 15), cv2.FONT_HERSHEY_SIMPLEX, 0.5, status_color, 2)
        
        # Draw bounding boxes (from face recognition)
        for (x, y, bw, bh, label, color) in self.detected_boxes:
            cv2.rectangle(frame, (x, y), (x + bw, y + bh), color, 2)
            # Label background badge
            cv2.rectangle(frame, (x, y - 25), (x + bw, y), color, -1)
            cv2.putText(frame, label, (x + 6, y - 7), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

    def set_detected_boxes(self, boxes: List[Tuple[int, int, int, int, str, Tuple[int, int, int]]]):
        self.detected_boxes = boxes

    def clear_detected_boxes(self):
        self.detected_boxes = []

    def set_face_recognition_state(self, active: bool):
        self.face_recognition_active = active
        if not active:
            self.clear_detected_boxes()

    def get_latest_frame(self) -> np.ndarray:
        with self.lock:
            if self.latest_raw_frame is not None:
                return self.latest_raw_frame.copy()
            return self._create_simulated_frame()

    def save_snapshot(self, custom_filename: Optional[str] = None) -> Optional[str]:
        """Saves current frame to snapshots directory and returns filename."""
        frame = self.get_latest_frame()
        if frame is None:
            return None
            
        if not custom_filename:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
            custom_filename = f"snap_{timestamp}.jpg"
            
        out_path = settings.SNAPSHOTS_DIR / custom_filename
        cv2.imwrite(str(out_path), frame)
        logger.info(f"Saved snapshot to {out_path}")
        return custom_filename

    def generate_mjpeg_stream(self):
        """Yields MJPEG stream for HTTP streaming."""
        while self.is_running:
            with self.lock:
                if self.latest_display_frame is None:
                    time.sleep(0.04)
                    continue
                frame = self.latest_display_frame.copy()

            ret, buffer = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 75])
            if not ret:
                time.sleep(0.04)
                continue

            frame_bytes = buffer.tobytes()
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
            time.sleep(0.04) # ~25 fps throttle

camera_service = CameraService()
