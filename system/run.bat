@echo off
cd /d %~dp0
echo ========================================
echo   echo_8051 Peripheral Demo
echo ========================================
pip install flask -q 2>nul
echo Starting at http://127.0.0.1:5000
echo.
python server.py
pause
