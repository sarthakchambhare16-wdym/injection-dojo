@echo off
cd /d "%~dp0"
echo ========================================================
echo   Launching Injection Dojo Cloudflare Tunnel...
echo ========================================================
powershell -ExecutionPolicy Bypass -File "%~dp0start-tunnel.ps1"
pause
