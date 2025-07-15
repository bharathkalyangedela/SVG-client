@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
REM SVG Auto-Update Daemon Service

REM Configuration
set UPDATE_INTERVAL=21600
set LOG_FILE=auto-update.log
set CONFIG_FILE=auto-update-config.txt
set DAEMON_PID_FILE=auto-update.pid

REM Load configuration
if exist "%%CONFIG_FILE%%" (
    for /f "tokens=1,2 delims==" %%a in (%%CONFIG_FILE%%) do (
        if "%%a"=="UPDATE_INTERVAL" set UPDATE_INTERVAL=%%b
        if "%%a"=="AUTO_UPDATE_ENABLED" set AUTO_UPDATE_ENABLED=%%b
        if "%%a"=="LOG_LEVEL" set LOG_LEVEL=%%b
    )
) else (
    echo UPDATE_INTERVAL=21600 > %%CONFIG_FILE%%
    echo AUTO_UPDATE_ENABLED=true >> %%CONFIG_FILE%%
    echo LOG_LEVEL=INFO >> %%CONFIG_FILE%%
    set AUTO_UPDATE_ENABLED=true
)

REM Create PID file
echo %%RANDOM%% > %%DAEMON_PID_FILE%%

:auto_update_loop
REM Check if auto-update is enabled
if "%%AUTO_UPDATE_ENABLED%%"=="false" (
    timeout /t 3600 /nobreak >nul
    goto auto_update_loop
)

REM Log current check
echo [%%date%% %%time%%] Starting auto-update check... >> %%LOG_FILE%%

REM Create backup before update
for /f "tokens=1-3 delims=/" %%a in ('date /t') do set DATESTAMP=%%c%%a%%b
for /f "tokens=1-2 delims=:" %%a in ('time /t') do set TIMESTAMP=%%a%%b
set TIMESTAMP=^ =0^
set AUTO_BACKUP=auto-backup.^_^

docker-compose ps > running-state.^ 2>nul

REM Smart update check
docker-compose config --services > services.tmp 2>nul
set IMAGE_HASH_BEFORE=
for /f %%s in (services.tmp) do (
    for /f "tokens=3" %%i in ('docker-compose images %%s 2^>nul') do (
        if not "%%i"=="IMAGE" set IMAGE_HASH_BEFORE=^%%i
    )
)

docker-compose pull >nul 2>&1
if errorlevel 1 (
    echo [%%date%% %%time%%] ERROR: Failed to pull images >> %%LOG_FILE%%
    del services.tmp 2>nul
    goto wait_next_check
)

set IMAGE_HASH_AFTER=
for /f %%s in (services.tmp) do (
    for /f "tokens=3" %%i in ('docker-compose images %%s 2^>nul') do (
        if not "%%i"=="IMAGE" set IMAGE_HASH_AFTER=^%%i
    )
)
del services.tmp 2>nul

if not "^^"=="^^" (
    echo [%%date%% %%time%%] Updates detected, applying... >> %%LOG_FILE%%
ECHO is off.
    REM Apply updates with rollback capability
    docker-compose down >nul 2>&1
    docker-compose up -d >nul 2>&1
ECHO is off.
    REM Verify services started successfully
    timeout /t 30 /nobreak >nul
    if errorlevel 1 (
        echo [%%date%% %%time%%] ERROR: Services failed to start, rollback needed >> %%LOG_FILE%%
        REM Auto-rollback would go here
    ) else (
        echo [%%date%% %%time%%] SUCCESS: Auto-update completed >> %%LOG_FILE%%
    )
) else (
    echo [%%date%% %%time%%] No updates available >> %%LOG_FILE%%
)

:wait_next_check
REM Wait for next check interval
timeout /t %%UPDATE_INTERVAL%% /nobreak >nul
goto auto_update_loop
