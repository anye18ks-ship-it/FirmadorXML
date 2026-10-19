@echo off
setlocal
title Sentry (e-CF) v2.0 - Firmador DGII Agrofem

:: ==============================================================================
:: LANZADOR DE SOFTWARE DESKTOP NATIVO - FIRMADOR DGII (e-CF)
:: Agropecuaria Fernandez Munoz, S.R.L. (Ley 32-23)
:: ==============================================================================

set "BASE_DIR=%~dp0"
set "BACKEND_DIR=%BASE_DIR%backend"
set "PORT=5000"

echo ==============================================================================
echo       Sentry (e-CF) v2.0 - FIRMADOR ELECTRONICO DGII
echo       Agropecuaria Fernandez Munoz, S.R.L. (Ley 32-23)
echo ==============================================================================
echo.

:: 1. Validar que Node.js este instalado
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Node.js no esta instalado o no se encuentra en el PATH del sistema.
    echo Por favor instale Node.js v18 o superior para ejecutar el firmador.
    echo.
    pause
    exit /b 1
)

:: 2. Validar que el archivo compilado exista
if not exist "%BACKEND_DIR%\dist\index.js" (
    echo [INFO] Compilando backend TypeScript por primera vez...
    cd /d "%BACKEND_DIR%"
    call npm run build
    if not exist "%BACKEND_DIR%\dist\index.js" (
        echo [ERROR] Fallo la compilacion del backend.
        pause
        exit /b 1
    )
)

:: 3. Verificar si el backend ya esta escuchando en el puerto 5000
netstat -ano | findstr /R /C:":%PORT% .*LISTENING" >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] El motor backend ya se encuentra activo en el puerto %PORT%.
    goto :LAUNCH_UI
)

echo [INFO] Iniciando motor de procesamiento Node.js en segundo plano...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'node' -ArgumentList 'dist/index.js' -WorkingDirectory '%BACKEND_DIR%' -WindowStyle Hidden"

echo [INFO] Conectando con base de datos y cargando certificados...
set /a RETRIES=0

:WAIT_PORT
ping -n 2 127.0.0.1 >nul
netstat -ano | findstr /R /C:":%PORT% .*LISTENING" >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Motor backend iniciado y respondiendo en el puerto %PORT%.
    goto :LAUNCH_UI
)

set /a RETRIES+=1
if %RETRIES% lss 20 goto :WAIT_PORT

echo.
echo [ERROR] El motor backend no pudo inicializarse tras 20 segundos.
echo Revise que SQL Server (172.16.4.14:1433) este accesible y el archivo .env configurado.
echo.
pause
exit /b 1

:LAUNCH_UI
:: 4. Detectar navegador para modo Aplicacion Desktop Nativa
set "BROWSER_EXE="

if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" (
    set "BROWSER_EXE=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
) else if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" (
    set "BROWSER_EXE=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
) else if exist "%LOCALAPPDATA%\Microsoft\Edge\Application\msedge.exe" (
    set "BROWSER_EXE=%LOCALAPPDATA%\Microsoft\Edge\Application\msedge.exe"
) else if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" (
    set "BROWSER_EXE=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
) else if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" (
    set "BROWSER_EXE=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
) else if exist "%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe" (
    set "BROWSER_EXE=%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"
)

:: 5. Lanzar la interfaz visual como Software de Escritorio Windows
echo [INFO] Desplegando interfaz desktop moderna...

if defined BROWSER_EXE (
    start "" "%BROWSER_EXE%" --app="http://localhost:%PORT%" --window-size=1280,820 --app-id="FirmadorDGIIAgrofem"
) else (
    start "" "http://localhost:%PORT%"
)

echo.
echo [LISTO] Firmador Electronico DGII desplegado correctamente.
ping -n 2 127.0.0.1 >nul
exit /b 0
