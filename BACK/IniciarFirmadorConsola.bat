@echo off
title Sentry (e-CF) v2.0 - Consola del Firmador DGII
echo ==============================================================================
echo       Sentry (e-CF) v2.0 - CONSOLA EN TIEMPO REAL
echo       Agropecuaria Fernandez Munoz, S.R.L. (Ley 32-23)
echo ==============================================================================
echo.

set "BASE_DIR=%~dp0"
set "BACKEND_DIR=%BASE_DIR%backend"
set "PORT=5000"

:: Detectar navegador para modo Desktop
set "BROWSER_EXE="
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" (
    set "BROWSER_EXE=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
) else if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" (
    set "BROWSER_EXE=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
) else if exist "%LOCALAPPDATA%\Microsoft\Edge\Application\msedge.exe" (
    set "BROWSER_EXE=%LOCALAPPDATA%\Microsoft\Edge\Application\msedge.exe"
) else if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" (
    set "BROWSER_EXE=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
) else if exist "%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe" (
    set "BROWSER_EXE=%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"
)

:: Lanzar interfaz tras 2 segundos en paralelo
if defined BROWSER_EXE (
    start "" cmd /c "ping -n 3 127.0.0.1 >nul && start \"\" \"%BROWSER_EXE%\" --app=\"http://localhost:%PORT%\" --window-size=1280,820"
) else (
    start "" cmd /c "ping -n 3 127.0.0.1 >nul && start \"\" \"http://localhost:%PORT%\""
)

:: Iniciar Backend en primer plano mostrando logs
cd /d "%BACKEND_DIR%"
node dist/index.js
pause
