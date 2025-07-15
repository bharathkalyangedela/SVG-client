@echo off
setlocal enabledelayedexpansion
echo 🔄 Checking for Stereo Video Generator updates...

REM Create restore point
set RESTORE_POINT=20251507_155606
set RESTORE_POINT= =0
echo [INFO] Creating restore point: 

REM Backup entire current state
if exist "docker-compose.yml" (
    copy docker-compose.yml docker-compose.yml.restore. >nul
    echo [SUCCESS] Configuration backed up
)
if exist "version-info.json" (
    copy version-info.json version-info.json.restore. >nul
)

REM Store current running containers for rollback
docker-compose ps > running-services.restore. 2>nul

REM Check if git is available for configuration updates
git --version >nul 2>&1
if errorlevel 1 (
    echo [INFO] Git not available, using Docker-only update...
    goto docker_update_only
)
if not exist ".git" (
    echo [INFO] Not a git repository, using Docker-only update...
    goto docker_update_only
)

REM Get current version
set CURRENT_VERSION=unknown
if exist "version-info.json" (
    for /f "tokens=2 delims=:, " %%a in ('findstr "version" version-info.json') do (
        set CURRENT_VERSION=%%a
        set CURRENT_VERSION="=
    )
)
echo [INFO] Current version: 

REM Fetch and check for updates
echo [INFO] Checking for configuration updates from GitHub...
git fetch origin 2>nul
if errorlevel 1 (
    echo [WARNING] Could not fetch from GitHub, using Docker-only update
    goto docker_update_only
)

for /f "tokens=*" %%a in ('git describe --tags origin/main 2>nul') do set LATEST_VERSION=%%a
if ""=="" set LATEST_VERSION=
echo [INFO] Latest version available: 

if ""=="" (
    echo [INFO] ✅ Configuration is up to date
    goto docker_update_only
)

echo [INFO] 🆕 New configuration version available: 
echo [INFO] Updating configuration files...

REM Update configuration with validation
git reset --hard origin/main 2>nul
if errorlevel 1 goto rollback_config

REM Validate new configuration
echo [INFO] Validating new configuration...
docker-compose config >nul 2>&1
if errorlevel 1 (
    echo [ERROR] New configuration is invalid
    goto rollback_config
)

echo [SUCCESS] Configuration updated and validated
goto docker_update_only

:rollback_config
echo [ERROR] Configuration update failed, rolling back...
if exist "docker-compose.yml.restore." (
    copy docker-compose.yml.restore. docker-compose.yml >nul
    echo [SUCCESS] Configuration rolled back to restore point
) else (
    echo [WARNING] No restore point available
)

:docker_update_only
REM Pull latest Docker images
echo [INFO] Pulling latest Docker images from Docker Hub...
docker-compose pull
if errorlevel 1 (
    echo [ERROR] Failed to pull latest images
    goto show_rollback_options
)

REM Restart services with rollback support
echo [INFO] Restarting services with updates...
docker-compose down
docker-compose up -d
if errorlevel 1 (
    echo [ERROR] Failed to start services with new configuration
    goto rollback_services
)

REM Verify services are healthy
echo [INFO] Verifying services are running...
timeout /t 15 /nobreak >nul
docker-compose ps | findstr "Up" >nul
if errorlevel 1 (
    echo [WARNING] Some services may not be running properly
    goto show_rollback_options
)

echo ✅ Update completed successfully
echo 🌐 Frontend: http://localhost:3000
echo 📚 API Docs: http://localhost:8000/docs
echo.
REM Cleanup old restore points after successful update (keep last 3)
echo [INFO] Cleaning up old restore points...
set COUNT=0
for /f "skip=3" %%f in ('dir /b /o-d *.restore.* 2>nul') do (
    del "%%f" 2>nul
    set /a COUNT+=1
)
if  gtr 0 echo [INFO] Cleaned up  old restore points
goto end

:rollback_services
echo [ERROR] Service startup failed, attempting rollback...
if exist "docker-compose.yml.restore." (
    echo [INFO] Rolling back to previous configuration...
    copy docker-compose.yml.restore. docker-compose.yml >nul
    docker-compose down
    docker-compose up -d
    if errorlevel 1 (
        echo [ERROR] Rollback also failed - manual intervention required
        goto show_rollback_options
    ) else (
        echo [SUCCESS] Successfully rolled back to previous version
        echo [INFO] System is running with previous configuration
    )
) else (
    echo [ERROR] No restore point available for rollback
)
goto show_rollback_options

:show_rollback_options

echo 🛠️  ROLLBACK OPTIONS:
echo.
echo Available restore points:
dir /b *.restore.* 2>nul || echo   No restore points found

echo Manual rollback commands:
echo   1. Configuration rollback:
echo      copy docker-compose.yml.restore. docker-compose.yml
echo      docker-compose down && docker-compose up -d
echo.
echo   2. Version rollback (if git available):
echo      git checkout v1.0.0  (replace with desired version)
echo      docker-compose down && docker-compose up -d
echo.
echo   3. Return to latest:
echo      git checkout main
echo      docker-compose down && docker-compose up -d
echo.
echo   4. Complete reset:
echo      git reset --hard origin/main
echo      docker-compose down && docker-compose up -d
echo.
:end
pause
