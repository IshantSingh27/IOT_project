from fastapi import APIRouter, Response
from fastapi.responses import StreamingResponse
import cv2
from app.services.camera_service import camera_service

router = APIRouter(prefix="/video", tags=["Video Stream & Surveillance"])

@router.get("/feed")
def get_live_video_feed():
    """
    Live low-latency MJPEG video feed.
    Can be directly embedded in Flutter using standard Image.network or flutter_mjpeg widget.
    """
    return StreamingResponse(
        camera_service.generate_mjpeg_stream(),
        media_type="multipart/x-mixed-replace; boundary=frame"
    )

@router.get("/snapshot")
def get_snapshot():
    """Returns a single live frame as image/jpeg."""
    frame = camera_service.get_latest_frame()
    if frame is None:
        return Response(status_code=503, content="Camera frame unavailable")
    
    ret, buffer = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 90])
    if not ret:
        return Response(status_code=500, content="Failed to encode frame")
    
    return Response(content=buffer.tobytes(), media_type="image/jpeg")
