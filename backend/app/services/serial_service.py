import time
import threading
import logging
from typing import Callable, Optional
import serial
import serial.tools.list_ports
from app.config import settings

logger = logging.getLogger("serial_service")

class SerialService:
    def __init__(self):
        self.serial_conn: Optional[serial.Serial] = None
        self.is_connected: bool = False
        self.is_running: bool = False
        self.read_thread: Optional[threading.Thread] = None
        
        # State cached from Arduino
        self.is_door_locked: bool = True
        self.is_pir_active: bool = False
        
        # Event callbacks
        self.on_pir_motion_callbacks = []
        self.on_pir_idle_callbacks = []
        self.on_status_change_callbacks = []

    def register_pir_motion_callback(self, cb: Callable):
        self.on_pir_motion_callbacks.append(cb)

    def register_pir_idle_callback(self, cb: Callable):
        self.on_pir_idle_callbacks.append(cb)

    def register_status_callback(self, cb: Callable):
        self.on_status_change_callbacks.append(cb)

    def start(self):
        """Starts serial background listening thread."""
        self.is_running = True
        self.read_thread = threading.Thread(target=self._run_loop, daemon=True)
        self.read_thread.start()

    def stop(self):
        self.is_running = False
        if self.serial_conn and self.serial_conn.is_open:
            try:
                self.serial_conn.close()
            except Exception:
                pass
        self.is_connected = False

    def _find_arduino_port(self) -> Optional[str]:
        ports = serial.tools.list_ports.comports()
        for port in ports:
            # Common Arduino identifiers in descriptions or hardware IDs
            desc = (port.description or "").lower()
            hwid = (port.hwid or "").lower()
            if "arduino" in desc or "ch340" in desc or "cp210" in desc or "ftdi" in desc or "usb-serial" in desc:
                return port.device
        if ports:
            # Return first available port if configured port doesn't exist
            return ports[0].device
        return None

    def _connect(self) -> bool:
        if settings.SIMULATION_MODE:
            logger.info("SerialService: Running in SIMULATION MODE (No physical Arduino needed).")
            self.is_connected = False
            return False

        target_port = settings.SERIAL_PORT
        try:
            logger.info(f"Connecting to Arduino on {target_port} at {settings.SERIAL_BAUDRATE} baud...")
            self.serial_conn = serial.Serial(target_port, settings.SERIAL_BAUDRATE, timeout=1)
            time.sleep(2) # Wait for Arduino bootloader reset
            self.is_connected = True
            logger.info(f"Successfully connected to Arduino on {target_port}")
            self.send_command("CMD:STATUS")
            return True
        except Exception as e:
            logger.warning(f"Failed to open configured port {target_port}: {e}")
            alt_port = self._find_arduino_port()
            if alt_port and alt_port != target_port:
                try:
                    logger.info(f"Attempting connection to alternate detected port {alt_port}...")
                    self.serial_conn = serial.Serial(alt_port, settings.SERIAL_BAUDRATE, timeout=1)
                    time.sleep(2)
                    self.is_connected = True
                    logger.info(f"Connected to alternate port {alt_port}")
                    self.send_command("CMD:STATUS")
                    return True
                except Exception as err:
                    logger.error(f"Failed to connect to alternate port {alt_port}: {err}")
            
            logger.warning("No physical Arduino connected. Falling back to Simulation Mode.")
            self.is_connected = False
            return False

    def _run_loop(self):
        while self.is_running:
            if not self.is_connected and not settings.SIMULATION_MODE:
                self._connect()
                if not self.is_connected:
                    time.sleep(5)
                    continue

            if self.serial_conn and self.serial_conn.is_open:
                try:
                    line = self.serial_conn.readline().decode('utf-8', errors='ignore').strip()
                    if line:
                        self._process_incoming_line(line)
                except Exception as e:
                    logger.error(f"Serial communication error: {e}")
                    self.is_connected = False
                    if self.serial_conn:
                        try:
                            self.serial_conn.close()
                        except Exception:
                            pass
                    time.sleep(2)
            else:
                time.sleep(0.5)

    def _process_incoming_line(self, line: str):
        logger.info(f"Arduino -> {line}")
        line_clean = line.strip()

        if line_clean == "EVENT:PIR_MOTION":
            self.is_pir_active = True
            for cb in self.on_pir_motion_callbacks:
                try:
                    cb()
                except Exception as ex:
                    logger.error(f"Error in on_pir_motion callback: {ex}")

        elif line_clean == "EVENT:PIR_IDLE":
            self.is_pir_active = False
            for cb in self.on_pir_idle_callbacks:
                try:
                    cb()
                except Exception as ex:
                    logger.error(f"Error in on_pir_idle callback: {ex}")

        elif line_clean == "STATUS:DOOR:UNLOCKED":
            self.is_door_locked = False
            self._notify_status()

        elif line_clean == "STATUS:DOOR:LOCKED":
            self.is_door_locked = True
            self._notify_status()

        elif line_clean == "EVENT:AUTO_LOCK_TRIGGERED":
            self.is_door_locked = True
            self._notify_status()

    def _notify_status(self):
        for cb in self.on_status_change_callbacks:
            try:
                cb(self.is_door_locked, self.is_pir_active)
            except Exception as ex:
                logger.error(f"Error in status change callback: {ex}")

    def send_command(self, cmd: str) -> bool:
        """Sends command to Arduino or executes mock action in simulation mode."""
        cmd_clean = cmd.strip()
        logger.info(f"Laptop -> Arduino: {cmd_clean}")
        
        if self.serial_conn and self.serial_conn.is_open:
            try:
                self.serial_conn.write(f"{cmd_clean}\n".encode('utf-8'))
                self.serial_conn.flush()
                return True
            except Exception as e:
                logger.error(f"Failed to send serial command '{cmd_clean}': {e}")
                return False
        else:
            # Handle simulation response
            if cmd_clean in ["CMD:UNLOCK", "UNLOCK"]:
                self.is_door_locked = False
                self._notify_status()
            elif cmd_clean in ["CMD:LOCK", "LOCK"]:
                self.is_door_locked = True
                self._notify_status()
            return True

    def unlock_door(self) -> bool:
        return self.send_command("CMD:UNLOCK")

    def lock_door(self) -> bool:
        return self.send_command("CMD:LOCK")

    def trigger_alert(self) -> bool:
        return self.send_command("CMD:ALERT")

    # Simulation triggers for testing when hardware is not plugged in
    def simulate_pir_motion(self):
        logger.info("[SIMULATION] Simulated PIR Motion Triggered")
        self.is_pir_active = True
        for cb in self.on_pir_motion_callbacks:
            cb()
        self._notify_status()

    def simulate_pir_idle(self):
        logger.info("[SIMULATION] Simulated PIR Motion Ended (Idle)")
        self.is_pir_active = False
        for cb in self.on_pir_idle_callbacks:
            cb()
        self._notify_status()

serial_service = SerialService()
