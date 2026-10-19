@echo off
setlocal enabledelayedexpansion

:: ==============================================================================
:: AGROFEM - LIMPIEZA PREVENTIVA Y ROTACION INTELIGENTE
:: Libera puertos 5000 y 5173 y rota logs si exceden 5MB.
:: ==============================================================================

set "API_DIR=%~dp0"
if "%API_DIR:~-1%"=="\" set "API_DIR=%API_DIR:~0,-1%"

set "LOGS_DIR=%API_DIR%\logs"
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"

set "TIMESTAMP=%DATE% %TIME%"

:: Rotacion si superan 5MB (5242880 bytes)
set "MAX_LOG_BYTES=5242880"

if exist "%LOGS_DIR%\backend.log" (
    for %%F in ("%LOGS_DIR%\backend.log") do (
        if %%~zF GTR %MAX_LOG_BYTES% (
            move /y "%LOGS_DIR%\backend.log" "%LOGS_DIR%\backend.old.log" >nul 2>&1
            echo [%TIMESTAMP%] [ROTACION] Log backend rotado por tamano >> "%LOGS_DIR%\sistema.log"
        )
    )
)

if exist "%LOGS_DIR%\frontend.log" (
    for %%F in ("%LOGS_DIR%\frontend.log") do (
        if %%~zF GTR %MAX_LOG_BYTES% (
            move /y "%LOGS_DIR%\frontend.log" "%LOGS_DIR%\frontend.old.log" >nul 2>&1
            echo [%TIMESTAMP%] [ROTACION] Log frontend rotado por tamano >> "%LOGS_DIR%\sistema.log"
        )
    )
)

:: Liberar procesos en puerto 5000
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":5000" ^| findstr "LISTENING"') do (
    if not "%%p"=="" if not "%%p"=="0" (
        taskkill /F /PID %%p >nul 2>&1
        echo [%TIMESTAMP%] [LIMPIEZA] Proceso liberado en puerto 5000 - PID %%p >> "%LOGS_DIR%\sistema.log"
    )
)

:: Liberar procesos en puerto 5173
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":5173" ^| findstr "LISTENING"') do (
    if not "%%p"=="" if not "%%p"=="0" (
        taskkill /F /PID %%p >nul 2>&1
        echo [%TIMESTAMP%] [LIMPIEZA] Proceso liberado en puerto 5173 - PID %%p >> "%LOGS_DIR%\sistema.log"
    )
)

exit /b 0
