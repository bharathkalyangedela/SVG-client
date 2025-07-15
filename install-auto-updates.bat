@echo off
chcp 65001 >nul 2>&1
echo 🚀 SVG Auto-Update System Installer
echo ====================================
echo.
echo This installer will set up automatic updates for SVG.
echo.
echo Features:
echo   ✅ Automatic Docker image updates
echo   ✅ Smart restart only when needed  
echo   ✅ Configurable update intervals
echo   ✅ Automatic rollback on failures
echo   ✅ Windows Service integration
echo   ✅ Easy control panel
echo.
set /p confirm="Install auto-update system? (y/n): "
if /i not "%%confirm%%"=="y" exit /b

echo 📝 Setting up configuration...
echo AUTO_UPDATE_ENABLED=true > auto-update-config.txt
echo UPDATE_INTERVAL=21600 >> auto-update-config.txt
echo LOG_LEVEL=INFO >> auto-update-config.txt
echo ✅ Configuration created

echo 🎛️  Would you like to:
echo 1) Run as background process (manual start/stop)
echo 2) Install as Windows Service (automatic startup)
echo.
set /p mode="Select mode (1 or 2): "

if "%%mode%%"=="1" (
    echo 🚀 Starting background daemon...
    start "" /min "auto-update-daemon.bat"
    timeout /t 3 /nobreak >nul
    echo ✅ Auto-update daemon started
    echo ℹ️  Use 'auto-update-control.bat' to manage the service
)

if "%%mode%%"=="2" (
    echo 🔧 Installing Windows Service...
    sc create "SVG-AutoUpdate" binPath= "cmd /c \"%%~dp0auto-update-daemon.bat\"" start= auto DisplayName= "SVG Auto-Update Service" 2>nul
    if not errorlevel 1 (
        sc start "SVG-AutoUpdate" 2>nul
        echo ✅ Service installed and started successfully
        echo ℹ️  Service will start automatically on system boot
    ) else (
        echo ❌ Service installation failed. Try running as Administrator.
        echo 💡 Falling back to background process...
        start "" /min "auto-update-daemon.bat"
        echo ✅ Background daemon started instead
    )
)

echo 🎉 Installation complete
echo.
echo 📋 Available commands:
echo   • auto-update-control.bat  - Control panel
echo   • update.bat              - Manual update
echo   • View auto-update.log    - Check activity
echo.
echo 🔍 Default settings:
echo   • Update check: Every 6 hours
echo   • Smart updates: Only restart when needed
echo   • Auto-rollback: Enabled on failures
echo.
pause
