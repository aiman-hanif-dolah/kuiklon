@echo off
REM One-click update + reinstall of Kuiklon (no installer wizard clicks).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\update-install.ps1"
if errorlevel 1 (
  echo.
  echo Update failed - see the error above.
  pause
)