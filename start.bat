@echo off
REM Double-click this file to set up and run the Grocery Inventory System.
REM It checks the .NET SDK, Node.js and PostgreSQL, installs the Angular packages
REM the first time, then starts the API and the web app and opens the browser.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*

if errorlevel 1 (
    echo.
    echo Setup stopped before everything was running. Read the message above.
)

echo.
pause
