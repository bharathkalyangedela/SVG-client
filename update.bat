@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
echo 🔄 Checking for Stereo Video Generator updates...

REM Create restore point with proper timestamp
for /f "tokens=1-3 delims=/" %%a in ('date /t') do set DATESTAMP=%%c%%a%%b
for /f "tokens=1-2 delims=:" %%a in ('time /t') do set TIMESTAMP=%%a%%b
set TIMESTAMP=^ =0^
set RESTORE_POINT=^_^
echo [INFO] Creating restore point: ^

REM Backup entire current state
if exist "docker-compose.yml" (
    copy docker-compose.yml docker-compose.yml.restore.^ >nul 2>&1
    echo [SUCCESS] Configuration backed up
)
if exist "version-info.json" (
    copy version-info.json version-info.json.restore.^ >nul 2>&1
)

REM Store current running containers for rollback
docker-compose ps > running-services.restore.^ 2>nul

REM Check if git is available for configuration updates
git --version >nul 2>&1
if errorlevel 1 (
    echo [INFO] Git not available, using Docker-only update...
    goto smart_docker_update
)
if not exist ".git" (
    echo [INFO] Not a git repository, using Docker-only update...
    goto smart_docker_update
)

REM Get current version
set CURRENT_VERSION=unknown
if exist "version-info.json" (
    for /f "tokens=2 delims=:, " %%a in ('findstr "version" version-info.json') do (
        set CURRENT_VERSION=%%a
        set CURRENT_VERSION=^"=^^
    )
)
echo [INFO] Current version: ^

REM Fetch and check for updates
echo [INFO] Checking for configuration updates from GitHub...
git fetch origin >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Could not fetch from GitHub, using Docker-only update
    goto smart_docker_update
)

REM Get latest version from GitHub
set LATEST_VERSION=unknown
for /f "tokens=*" %%a in ('git describe --tags origin/main 2^>nul') do set LATEST_VERSION=%%a
if "^^"=="unknown" set LATEST_VERSION=^
echo [INFO] Latest version available: ^

if "^^"=="^^" (
    echo [INFO] ✅ Configuration is up to date
    goto smart_docker_update
)

echo [INFO] 🆕 New configuration version available: ^
echo [INFO] Updating configuration files...

REM Update configuration with validation
git reset --hard origin/main >nul 2>&1
if errorlevel 1 goto rollback_config

REM Validate new configuration
echo [INFO] Validating new configuration...
docker-compose config >nul 2>&1
if errorlevel 1 (
    echo [ERROR] New configuration is invalid^
    goto rollback_config
)

echo [SUCCESS] Configuration updated and validated
goto smart_docker_update

:rollback_config
echo [ERROR] Configuration update failed, rolling back...
if exist "docker-compose.yml.restore.^^" (
    copy docker-compose.yml.restore.^ docker-compose.yml >nul 2>&1
    echo [SUCCESS] Configuration rolled back to restore point
) else (
    echo [WARNING] No restore point available
)

:smart_docker_update
REM Smart Docker update - only restart if images changed
echo [INFO] Checking for Docker image updates...
set IMAGES_UPDATED=false

REM Get current image info before pull
docker-compose config --services > services.tmp 2>nul
set IMAGE_HASH_BEFORE=
for /f %%s in (services.tmp) do (
    for /f "tokens=3" %%i in ('docker-compose images %%s 2^>nul') do (
        if not "%%i"=="IMAGE" set IMAGE_HASH_BEFORE=^%%i
    )
)

REM Pull latest Docker images
echo [INFO] Pulling latest Docker images from Docker Hub...
docker-compose pull
if errorlevel 1 (
    echo [ERROR] Failed to pull latest images
    del services.tmp 2>nul
    goto show_rollback_options
)

REM Check if images were actually updated
set IMAGE_HASH_AFTER=
for /f %%s in (services.tmp) do (
    for /f "tokens=3" %%i in ('docker-compose images %%s 2^>nul') do (
        if not "%%i"=="IMAGE" set IMAGE_HASH_AFTER=^%%i
    )
)

del services.tmp 2>nul

if not "^^"=="^^" (
    set IMAGES_UPDATED=true
    echo [INFO] 🆕 New Docker images detected, restart required
) else (
    echo [INFO] ✅ Docker images are up to date, no restart needed
)

REM Only restart if images were actually updated
if "^^"=="true" (
    echo [INFO] Restarting services with updates...
    docker-compose down
    docker-compose up -d
    if errorlevel 1 (
        echo [ERROR] Failed to start services
        goto rollback_services
    )

    REM Verify services are healthy
    echo [INFO] Verifying services are running...
    timeout /t 15 /nobreak >nul
    docker-compose ps ^| findstr "Up" ^>nul
    if errorlevel 1 (
        echo [WARNING] Some services may not be running properly
        goto show_rollback_options
    )

    echo ✅ Update completed successfully^
) else (
    echo ✅ System is already up to date - no restart needed^
)

echo 🌐 Frontend: http://localhost:3000
echo 📚 API Docs: http://localhost:8000/docs
echo.

REM Cleanup old restore points (keep last 3) - FIXED VERSION
echo [INFO] Cleaning up old restore points...
set CLEANUP_COUNT=0
for /f "skip=3" %%f in ('dir /b /o-d *.restore.* 2^>nul') do (
    del "%%f" 2^>nul
    set /a CLEANUP_COUNT=%%CLEANUP_COUNT%%+1
)
if %%CLEANUP_COUNT%% gtr 0 echo [INFO] Cleaned up %%CLEANUP_COUNT%% old restore points
goto end

:rollback_services
echo [ERROR] Service startup failed, attempting rollback...
if exist "docker-compose.yml.restore.^^" (
    echo [INFO] Rolling back to previous configuration...
    copy docker-compose.yml.restore.^ docker-compose.yml >nul 2>&1
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
echo.
echo 🛠️  ROLLBACK OPTIONS:
echo.
echo Available restore points:
dir /b *.restore.* 2>nul ^|^| echo   No restore points found
echo.
echo Manual rollback commands:
echo   1. Configuration rollback:
echo      copy docker-compose.yml.restore.^ docker-compose.yml
echo      docker-compose down ^&^& docker-compose up -d
echo.
echo   2. Version rollback (if git available):
echo      git checkout v1.0.0  (replace with desired version)
echo      docker-compose down ^&^& docker-compose up -d
echo.
echo   3. Return to latest:
echo      git checkout main
echo      docker-compose down ^&^& docker-compose up -d
echo.
echo   4. Complete reset:
echo      git reset --hard origin/main
echo      docker-compose down ^&^& docker-compose up -d
echo.
:end
pause
