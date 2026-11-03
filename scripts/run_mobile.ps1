# Set Java Home to Android Studio's bundled OpenJDK
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$adb = "C:\Users\Ishant\AppData\Local\Android\Sdk\platform-tools\adb.exe"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Connecting Mobile Device & Launching Smart Home App" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Check connected device
$devices = & $adb devices
Write-Host "`nConnected Devices:" -ForegroundColor Yellow
Write-Host $devices

if ($devices -notmatch '(?m)^\S+\s+device$') {
    Write-Host "`n[!] No authorized Android device detected." -ForegroundColor Red
    Write-Host "Please ensure:" -ForegroundColor Yellow
    Write-Host " 1. USB Debugging is ENABLED in Developer Options on your phone."
    Write-Host " 2. Phone screen is UNLOCKED."
    Write-Host " 3. You tapped 'Allow' on the 'Allow USB debugging?' popup.`n"
    Pause
    exit 1
}

# Reverse forward port 8000 over USB cable
Write-Host "`n[+] Enabling USB Reverse Port Forwarding for port 8000..." -ForegroundColor Green
& $adb reverse tcp:8000 tcp:8000

# Run Flutter App
Write-Host "`n[+] Launching Flutter App on your mobile device..." -ForegroundColor Green
Set-Location -Path "$PSScriptRoot\..\flutter_app"
flutter run
