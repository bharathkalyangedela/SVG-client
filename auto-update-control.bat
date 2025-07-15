@echo off
chcp 65001 >nul 2>&1
echo 🔧 SVG Auto-Update Control Panel
echo ====================================
echo.
echo Current Status:
if exist "auto-update.pid" (
    echo    🟢 Daemon: RUNNING
) else (
    echo    🔴 Daemon: STOPPED
)

if exist "auto-update-config.txt" (
    for /f "tokens=1,2 delims==" %%a in (auto-update-config.txt) do (
        if "%%a"=="AUTO_UPDATE_ENABLED" (
            if "%%b"=="true" (
                echo    ✅ Auto-Updates: ENABLED
            ) else (
                echo    ❌ Auto-Updates: DISABLED
            )
        )
        if "%%a"=="UPDATE_INTERVAL" echo    ⏰ Check Interval: %%b seconds
    )
) else (
    echo    ⚠️  Configuration: NOT FOUND
)

echo ====================================
echo.
echo 1) 🟢 Enable Auto-Updates
echo 2) 🔴 Disable Auto-Updates  
echo 3) ⏰ Set Update Interval
echo 4) 📋 View Update Log
echo 5) 🚀 Start Daemon
echo 6) 🛑 Stop Daemon
echo 7) 🔧 Install as Windows Service
echo 8) 🗑️  Uninstall Service
echo 9) 📊 Show System Status
echo 0) ❌ Exit
echo.
set /p choice="Select option (0-9): "

if "%%choice%%"=="1" (
    echo AUTO_UPDATE_ENABLED=true > auto-update-config.txt
    echo UPDATE_INTERVAL=21600 >> auto-update-config.txt
    echo LOG_LEVEL=INFO >> auto-update-config.txt
    echo ✅ [SUCCESS] Auto-updates enabled
)
if "%%choice%%"=="2" (
    echo AUTO_UPDATE_ENABLED=false > auto-update-config.txt  
    echo ❌ [SUCCESS] Auto-updates disabled
)
if "%%choice%%"=="3" (
    echo.
    echo Preset intervals:
    echo   1 hour   = 3600
    echo   6 hours  = 21600 (default)
    echo   12 hours = 43200
    echo   24 hours = 86400
    echo.
    set /p interval="Enter update interval in seconds: "
    if defined interval (
        echo AUTO_UPDATE_ENABLED=true > auto-update-config.txt
        echo UPDATE_INTERVAL=^ >> auto-update-config.txt
        echo LOG_LEVEL=INFO >> auto-update-config.txt
        echo ⏰ [SUCCESS] Update interval set to ^ seconds
    )
)
if "%%choice%%"=="4" (
    echo.
    echo 📋 Recent Update Log:
    echo ========================
    if exist "auto-update.log" (
        REM Show last 20 lines of log file
        powershell -command "Get-Content auto-update.log -Tail 20" 2^>nul
        if errorlevel 1 type auto-update.log
    ) else (
        echo No log file found. Daemon may not have run yet.
    )
)
if "%%choice%%"=="5" (
    if exist "auto-update.pid" (
        echo ⚠️  Daemon appears to be already running
    ) else (
        echo 🚀 Starting auto-update daemon...
        start "" /min "auto-update-daemon.bat"
        timeout /t 2 /nobreak >nul
        if exist "auto-update.pid" (
            echo ✅ [SUCCESS] Daemon started successfully
        ) else (
            echo ❌ [ERROR] Failed to start daemon
        )
    )
)
if "%%choice%%"=="6" (
    echo 🛑 Stopping auto-update daemon...
    taskkill /f /im cmd.exe /fi "WINDOWTITLE eq auto-update-daemon*" 2>nul
    del auto-update.pid 2>nul
    echo ✅ [SUCCESS] Daemon stopped
)
if "%%choice%%"=="7" (
    echo 🔧 Installing as Windows Service...
    sc create "SVG-AutoUpdate" binPath= "cmd /c \"%%~dp0auto-update-daemon.bat\"" start= auto DisplayName= "SVG Auto-Update Service" 2>nul
    if not errorlevel 1 (
        sc start "SVG-AutoUpdate" 2>nul
        echo ✅ [SUCCESS] Service installed and started
        echo ℹ️  Service will run automatically on system startup
    ) else (
        echo ❌ [ERROR] Failed to install service. Run as Administrator.
    )
)
if "%%choice%%"=="8" (
    echo 🗑️  Uninstalling Windows Service...
    sc stop "SVG-AutoUpdate" 2>nul
    sc delete "SVG-AutoUpdate" 2>nul
    echo ✅ [SUCCESS] Service uninstalled
)
if "%%choice%%"=="9" (
    echo.
    echo 📊 System Status:
    echo ==================
    echo Docker Status:
    docker info ^>nul 2^>^&1 ^&^& echo "   Docker: Running" ^|^| echo "   Docker: Not running"
    echo.
    echo SVG Services:
    docker-compose ps ^>nul 2^>^&1 ^&^& docker-compose ps ^|^| echo "   No services found"
    echo.
    echo System Resources:
    echo CPU Usage: 
    for /f "skip=1" %%p in ('wmic cpu get loadpercentage /format:value 2^>nul ^| findstr "LoadPercentage"') do echo    %%p
    echo.
    echo Memory Usage:
    for /f "skip=1" %%m in ('wmic OS get FreePhysicalMemory /format:value 2^>nul ^| findstr "FreePhysicalMemory"') do echo    %%m
)

if not "%%choice%%"=="0" (
    echo.
    pause
    cls
    goto :eof
)
