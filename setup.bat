@echo off
echo Setting up Stereo Video Generator Client...

REM Check Docker Desktop status
echo Checking Docker Desktop status...
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker Desktop is not running. Please start Docker Desktop and try again.
    pause
    exit /b 1
)

REM Pull latest images
echo Pulling latest images from Docker Hub...
docker-compose pull
if errorlevel 1 (
    echo [ERROR] Failed to pull images
    pause
    exit /b 1
)

REM Start services
echo Starting services...
docker-compose up -d
if errorlevel 1 (
    echo [ERROR] Failed to start services
    pause
    exit /b 1
)

REM Get local IP address for network access
echo Detecting network IP address...
    for /f "tokens=1" %%b in ("%%a") do (
        set LOCAL_IP=%%b
        goto :found_ip
    )
)
:found_ip
if "%%LOCAL_IP%%"=="" set LOCAL_IP=localhost

echo ✅ Stereo Video Generator started successfully
echo.
echo 🌐 Access URLs:
echo    Frontend: http://%%LOCAL_IP%%:3000
echo    API Docs: http://%%LOCAL_IP%%:8000/docs
echo    Local access: http://localhost:3000
echo.
echo 🛠️  Available Scripts:
echo    - setup.bat: Initial setup and start services
echo    - update.bat: Update to latest version
echo    - cleanup-docker.bat: Free up disk space
echo.
echo 🔧 Useful Commands:
echo Run 'docker-compose ps' to check service status
echo Run 'docker-compose logs -f' to view logs
echo Run 'docker-compose down' to stop services
echo.
echo 💡 Note: Using host network mode for seamless LAN access
pause
