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

echo ✅ Stereo Video Generator started successfully
echo 🌐 Frontend: http://localhost:3000
echo 📚 API Docs: http://localhost:8000/docs
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
pause
