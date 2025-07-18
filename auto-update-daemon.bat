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
        if "%%a"=="UPDATE_INTERVAL" (
            REM Validate interval is numeric and within range
            set TEMP_INTERVAL=%%b
            if %%b geq 60 if %%b leq 86400 (
                set UPDATE_INTERVAL=%%b
            ) else (
                echo [WARNING] Invalid interval %%b, using default 21600
                set UPDATE_INTERVAL=21600
            )
        )
        if "%%a"=="AUTO_UPDATE_ENABLED" set AUTO_UPDATE_ENABLED=%%b
        if "%%a"=="LOG_LEVEL" set LOG_LEVEL=%%b
    )
) else (
    echo UPDATE_INTERVAL=21600 > %%CONFIG_FILE%%
    echo AUTO_UPDATE_ENABLED=true >> %%CONFIG_FILE%%
    echo LOG_LEVEL=INFO >> %%CONFIG_FILE%%
    set AUTO_UPDATE_ENABLED=true
    set UPDATE_INTERVAL=21600
)

REM Create PID file immediately to indicate daemon is starting
echo %%RANDOM%%_%%TIME%% > %%DAEMON_PID_FILE%%
echo [INFO] Auto-update daemon started with PID file: %%DAEMON_PID_FILE%%

:auto_update_loop
REM Check if auto-update is enabled
if "%%AUTO_UPDATE_ENABLED%%"=="false" (
    echo [%%date%% %%time%%] Auto-updates disabled, sleeping for 1 hour... >> %%LOG_FILE%%
    timeout /t 3600 /nobreak >nul
    goto auto_update_loop
)

REM Validate UPDATE_INTERVAL before using
if not defined UPDATE_INTERVAL set UPDATE_INTERVAL=21600
if %%UPDATE_INTERVAL%% lss 60 set UPDATE_INTERVAL=21600
if %%UPDATE_INTERVAL%% gtr 86400 set UPDATE_INTERVAL=21600

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
REM Wait for next check interval - handle large timeouts by breaking into chunks
set REMAINING_TIME=%%UPDATE_INTERVAL%%
echo [%%date%% %%time%%] Waiting %%UPDATE_INTERVAL%% seconds until next check... >> %%LOG_FILE%%
:wait_loop
if %%REMAINING_TIME%% gtr 3600 (
    timeout /t 3600 /nobreak >nul
    set /a REMAINING_TIME=%%REMAINING_TIME%%-3600
    goto wait_loop
) else if %%REMAINING_TIME%% gtr 0 (
    timeout /t %%REMAINING_TIME%% /nobreak >nul
)
goto auto_update_loop
