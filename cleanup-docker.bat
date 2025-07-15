@echo off
REM Docker Cleanup Script for Stereo Video Generator Client
REM This script helps maintain optimal Docker disk usage

echo ======================================================================
echo  🧹 Docker Cleanup for Stereo Video Generator Client
echo ======================================================================
echo.

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not running. Please start Docker Desktop and try again.
    pause
    exit /b 1
)

echo [INFO] Current Docker disk usage:
docker system df
echo.

echo [INFO] Available cleanup options:
echo 1. Light cleanup (remove stopped containers and dangling images)
echo 2. Medium cleanup (also remove unused networks and volumes)
echo 3. Deep cleanup (remove all unused images - may require re-downloading)
echo 4. Show current images and containers
echo 5. Exit
echo.

set /p CHOICE="Select cleanup level (1-5): "

if "%CHOICE%"=="1" goto light_cleanup
if "%CHOICE%"=="2" goto medium_cleanup
if "%CHOICE%"=="3" goto deep_cleanup
if "%CHOICE%"=="4" goto show_status
if "%CHOICE%"=="5" goto exit
echo [ERROR] Invalid choice. Please select 1-5.
pause
goto exit

:light_cleanup
echo.
echo [INFO] Performing light cleanup...
docker container prune -f
docker image prune -f
echo [SUCCESS] Light cleanup completed
goto show_results

:medium_cleanup
echo.
echo [INFO] Performing medium cleanup...
docker container prune -f
docker image prune -f
docker network prune -f
docker volume prune -f
echo [SUCCESS] Medium cleanup completed
goto show_results

:deep_cleanup
echo.
echo [WARNING] Deep cleanup will remove ALL unused images.
echo This may require re-downloading images when you next run the application.
set /p CONFIRM="Are you sure? (y/n): "
if /i not "%%CONFIRM%%"=="y" goto exit

echo [INFO] Performing deep cleanup...
docker system prune -a -f --volumes
echo [SUCCESS] Deep cleanup completed
goto show_results

:show_status
echo.
echo [INFO] Current containers:
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
echo.
echo [INFO] Current images:
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
goto show_results

:show_results
echo.
echo [INFO] Updated Docker disk usage:
docker system df
echo.
echo 💡 Tips:
echo    - Run 'docker-compose pull' to update to latest images
echo    - Use 'docker-compose down' to stop services before cleanup
echo    - Regular cleanup helps maintain optimal performance

:exit
echo.
pause
