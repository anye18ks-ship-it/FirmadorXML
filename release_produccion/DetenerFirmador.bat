@echo off
title Detener Firmador e-CF DGII
echo ==============================================================================
echo       DETENER FIRMADOR ELECTRONICO DGII
echo       Agropecuaria Fernandez Munoz, S.R.L.
echo ==============================================================================
echo.

set "PORT=5000"
set "FOUND=0"

echo [INFO] Buscando procesos activos en el puerto %PORT%...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr /R /C:":%PORT% .*LISTENING"') do (
    set "FOUND=1"
    echo [INFO] Terminando proceso PID: %%a...
    taskkill /F /PID %%a >nul 2>&1
)

if %FOUND% equ 1 (
    echo [OK] El motor del Firmador ha sido detenido correctamente.
) else (
    echo [INFO] No habia ningun motor del Firmador activo en el puerto %PORT%.
)

echo.
ping -n 2 127.0.0.1 >nul
exit /b 0
