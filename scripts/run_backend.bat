@echo off
echo ==========================================================
echo Starting Smart IoT Home Security Backend & Vision Hub...
echo ==========================================================
cd /d "%~dp0\..\backend"

if not exist "venv" (
    echo Creating Python virtual environment...
    python -m venv venv
)

echo Activating virtual environment...
call venv\Scripts\activate.bat

echo Installing dependencies...
pip install -r requirements.txt

echo.
echo Launching FastAPI Server on 0.0.0.0:8000...
echo Swagger UI docs available at: http://localhost:8000/docs
echo Live Camera Stream: http://localhost:8000/api/video/feed
echo.
python run.py
pause
