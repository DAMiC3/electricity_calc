@echo off
REM Converts the Excel tariffs file to JSON (default paths)
REM Prereq (first time):
REM   py -m pip install --upgrade pip
REM   py -m pip install pandas openpyxl

setlocal
cd /d %~dp0

py convert.py
if errorlevel 1 (
  echo Failed. If this is the first run, install deps:
  echo   py -m pip install pandas openpyxl
  exit /b 1
)

echo.
echo Done. Output: ..\..\docs\tariffs.json
endlocal

