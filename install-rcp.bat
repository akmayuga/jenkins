@echo off
set "DOWNLOAD_URL=https://downloads.nicecloudsvc.com/8.0/rcp-installer-8.0.4.0.exe"
set "DEST_FOLDER=D:\test proj"
set "INSTALLER=%DEST_FOLDER%\rcp-installer-8.0.4.0.exe"

echo [*] Creating destination folder if it doesn't exist...
if not exist "%DEST_FOLDER%" (
    mkdir "%DEST_FOLDER%"
)

echo [*] Downloading installer to %DEST_FOLDER%...
powershell -Command "Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%INSTALLER%'"

if exist "%INSTALLER%" (
    echo [*] Download complete: %INSTALLER%
    echo [*] Running installer...
    start "" "%INSTALLER%"
) else (
    echo [!] Download failed.
    pause
    exit /b 1
)

pause
