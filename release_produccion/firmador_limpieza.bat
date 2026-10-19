@echo off
setlocal enabledelayedexpansion

:: ==============================================================================
:: SENTRY e-CF - LIMPIEZA PREVENTIVA Y ROTACION INTELIGENTE DE LOGS
:: Libera el puerto 5000 y rota logs si superan 5MB para evitar saturacion de disco.
:: ==============================================================================

set "BASE_DIR=%~dp0"
if "%BASE_DIR:~-1%"=="\" set "BASE_DIR=%BASE_DIR:~0,-1%"

set "LOGS_DIR=%BASE_DIR%\logs"
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"

set "TIMESTAMP=%DATE% %TIME%"

:: Rotacion si superan 5MB (5242880 bytes)
set "MAX_LOG_BYTES=5242880"

if exist "%LOGS_DIR%\firmador.log" (
    for %%F in ("%LOGS_DIR%\firmador.log") do (
        if %%~zF GTR %MAX_LOG_BYTES% (
            move /y "%LOGS_DIR%\firmador.log" "%LOGS_DIR%\firmador.old.log" >nul 2>&1
            echo [%TIMESTAMP%] [ROTACION] Log firmador.log rotado por tamano >> "%LOGS_DIR%\sistema.log"
        )
    )
)

:: Liberar procesos huerfanos en puerto 5000
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":5000" ^| findstr "LISTENING"') do (
    if not "%%p"=="" if not "%%p"=="0" (
        taskkill /F /PID %%p >nul 2>&1
        echo [%TIMESTAMP%] [LIMPIEZA] Proceso liberado en puerto 5000 - PID %%p >> "%LOGS_DIR%\sistema.log"
    )
)

exit /b 0
