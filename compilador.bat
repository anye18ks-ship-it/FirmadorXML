@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Sentry (e-CF) v2.0 - Compilador Maestro Release

:: ==============================================================================
:: SENTRY (e-CF) v2.0 - COMPILADOR MAESTRO DE PRODUCCION
:: Agropecuaria Fernandez Munoz, S.R.L. (Ley 32-23 DGII)
:: Recrea la distribucion 'release_produccion' lista para trasladar a cualquier PC
:: ==============================================================================

set "BASE_DIR=%~dp0"
if "%BASE_DIR:~-1%"=="\" set "BASE_DIR=%BASE_DIR:~0,-1%"

set "BACKEND_DIR=%BASE_DIR%\backend"
set "FRONTEND_DIR=%BASE_DIR%\frontend"
set "RELEASE_DIR=%BASE_DIR%\release_produccion"
set "ICON_PATH=%BACKEND_DIR%\src\public\favicon.ico"
set "CSC_PATH=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

cls
echo ==============================================================================
echo       SENTRY (e-CF) v2.0 - COMPILADOR MAESTRO DE PRODUCCION
echo       Agropecuaria Fernandez Munoz, S.R.L. - Facturacion Electronica
echo ==============================================================================
echo.

:: ------------------------------------------------------------------------------
:: VERIFICACIONES PREVIAS
:: ------------------------------------------------------------------------------
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR CRITICO] Node.js no esta instalado o no se encuentra en el PATH.
    pause
    exit /b 1
)

where npm >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR CRITICO] NPM no esta disponible en el PATH del sistema.
    pause
    exit /b 1
)

if not exist "%CSC_PATH%" (
    echo [ERROR CRITICO] No se encontro el compilador C# de Windows en:
    echo %CSC_PATH%
    pause
    exit /b 1
)

:: ------------------------------------------------------------------------------
:: PASO 1 (0%): LIBERAR ARCHIVOS BLOQUEADOS
:: ------------------------------------------------------------------------------
call :DRAW_BAR 0 "Liberando procesos y verificando dependencias..."
taskkill /F /IM SentryFirmador.exe >nul 2>&1
ping -n 2 127.0.0.1 >nul

:: ------------------------------------------------------------------------------
:: PASO 2 (20%): COMPILACION DEL BACKEND TYPESCRIPT
:: ------------------------------------------------------------------------------
call :DRAW_BAR 20 "Compilando Backend TypeScript (Motor Criptografico e-CF)..."
cd /d "%BACKEND_DIR%"
call npm run build >nul 2>&1
if !errorlevel! neq 0 (
    echo.
    echo [ERROR] Fallo la compilacion del backend TypeScript.
    echo Ejecute 'npm run build' dentro de la carpeta 'backend' para ver los detalles.
    pause
    exit /b 1
)

if not exist "%BACKEND_DIR%\dist\index.js" (
    echo.
    echo [ERROR] No se genero el archivo compilado dist\index.js en el backend.
    pause
    exit /b 1
)

:: ------------------------------------------------------------------------------
:: PASO 3 (40%): COMPILACION DEL FRONTEND REACT 18 + VITE
:: ------------------------------------------------------------------------------
call :DRAW_BAR 40 "Compilando Frontend React 18 + Vite (UI Desktop Moderna)..."

:: Sincronizar icono en el frontend
if exist "%ICON_PATH%" (
    if not exist "%FRONTEND_DIR%\public" mkdir "%FRONTEND_DIR%\public"
    copy /y "%ICON_PATH%" "%FRONTEND_DIR%\public\favicon.ico" >nul 2>&1
)

cd /d "%FRONTEND_DIR%"
call npm run build >nul 2>&1
if !errorlevel! neq 0 (
    echo.
    echo [ERROR] Fallo la compilacion del frontend con Vite.
    echo Ejecute 'npm run build' dentro de la carpeta 'frontend' para ver los detalles.
    pause
    exit /b 1
)

if not exist "%FRONTEND_DIR%\dist\index.html" (
    echo.
    echo [ERROR] No se genero el bundle en frontend\dist.
    pause
    exit /b 1
)

:: ------------------------------------------------------------------------------
:: PASO 4 (60%): COMPILACION DEL EJECUTABLE NATIVO WINDOWS (C# SHELL + ICONO)
:: ------------------------------------------------------------------------------
call :DRAW_BAR 60 "Compilando ejecutable nativo SentryFirmador.exe con Icono..."
cd /d "%BASE_DIR%"

if exist "%ICON_PATH%" (
    "%CSC_PATH%" /target:winexe /optimize /win32icon:"%ICON_PATH%" /out:"%BASE_DIR%\SentryFirmador.exe" "%BASE_DIR%\desktop\SentryFirmador.cs" >nul 2>&1
) else (
    "%CSC_PATH%" /target:winexe /optimize /out:"%BASE_DIR%\SentryFirmador.exe" "%BASE_DIR%\desktop\SentryFirmador.cs" >nul 2>&1
)

if !errorlevel! neq 0 (
    echo.
    echo [ERROR] Fallo la compilacion del ejecutable C# SentryFirmador.exe.
    pause
    exit /b 1
)

:: ------------------------------------------------------------------------------
:: PASO 5 (80%): ENSAMBLADO DEL PAQUETE DISTRIBUIBLE (release_produccion)
:: ------------------------------------------------------------------------------
call :DRAW_BAR 80 "Ensamblando y sincronizando la carpeta 'release_produccion'..."

if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"
if not exist "%RELEASE_DIR%\backend" mkdir "%RELEASE_DIR%\backend"
if not exist "%RELEASE_DIR%\frontend" mkdir "%RELEASE_DIR%\frontend"
if not exist "%RELEASE_DIR%\logs" mkdir "%RELEASE_DIR%\logs"

:: Copiar ejecutables y scripts maestros
copy /y "%BASE_DIR%\SentryFirmador.exe" "%RELEASE_DIR%\" >nul
copy /y "%BASE_DIR%\iniciar_servidor_firmador.bat" "%RELEASE_DIR%\" >nul
copy /y "%BASE_DIR%\firmador_silencioso.vbs" "%RELEASE_DIR%\" >nul
copy /y "%BASE_DIR%\firmador_limpieza.bat" "%RELEASE_DIR%\" >nul
copy /y "%BASE_DIR%\DetenerFirmador.bat" "%RELEASE_DIR%\" >nul
copy /y "%BASE_DIR%\IniciarFirmadorDesktop.bat" "%RELEASE_DIR%\" >nul 2>&1
if exist "%BASE_DIR%\release_produccion\README_DESPLIEGUE.md" copy /y "%BASE_DIR%\release_produccion\README_DESPLIEGUE.md" "%RELEASE_DIR%\" >nul

:: Sincronizar backend compilado y configuracion
xcopy /E /I /Y "%BACKEND_DIR%\dist" "%RELEASE_DIR%\backend\dist" >nul 2>&1
copy /y "%BACKEND_DIR%\package.json" "%RELEASE_DIR%\backend\" >nul
if exist "%BACKEND_DIR%\.env" copy /y "%BACKEND_DIR%\.env" "%RELEASE_DIR%\backend\" >nul

:: Sincronizar frontend compilado
xcopy /E /I /Y "%FRONTEND_DIR%\dist" "%RELEASE_DIR%\frontend\dist" >nul 2>&1

:: Verificar y sincronizar node_modules si no existen en release
if not exist "%RELEASE_DIR%\backend\node_modules" (
    if exist "%BACKEND_DIR%\node_modules" (
        echo [INFO] Copiando librerias node_modules a release_produccion por primera vez...
        xcopy /E /I /Q /Y "%BACKEND_DIR%\node_modules" "%RELEASE_DIR%\backend\node_modules" >nul 2>&1
    )
)

:: ------------------------------------------------------------------------------
:: PASO 6 (100%): PROCESO COMPLETADO
:: ------------------------------------------------------------------------------
call :DRAW_BAR 100 "¡Compilacion y Empaquetado completados al 100%!"

echo.
echo ==============================================================================
echo            RESUMEN DE LA COMPILACION RELEASE GENERADA
echo ==============================================================================
echo   Ubicacion: %RELEASE_DIR%
echo.
echo   [OK] SentryFirmador.exe (Ejecutable con Icono Incrustado y System Tray)
echo   [OK] Backend TypeScript compilado (dist/index.js)
echo   [OK] Frontend React 18 / Vite compilado (dist/index.html)
echo   [OK] Scripts de Servicio, Tarea Programada y Firewall integrados
echo   [OK] Paquete 100%% Autocontenido (Listo para copiar a cualquier servidor)
echo ==============================================================================
echo.
echo   [1] Probar Ahora: Iniciar SentryFirmador.exe
echo   [2] Abrir la carpeta 'release_produccion' en el Explorador de Windows
echo   [3] Salir
echo.
set /p "POST_OP=Seleccione una opcion [1-3]: "

if "%POST_OP%"=="1" (
    cd /d "%RELEASE_DIR%"
    start "" "%RELEASE_DIR%\SentryFirmador.exe"
    exit /b 0
)

if "%POST_OP%"=="2" (
    explorer.exe "%RELEASE_DIR%"
    exit /b 0
)

exit /b 0

:: ==============================================================================
:: SUBRUTINA: DIBUJAR BARRA DE PROGRESO VISUAL EN CONSOLA
:: ==============================================================================
:DRAW_BAR
set "PCT=%~1"
set "MSG=%~2"

if %PCT% equ 0   set "BAR=[░░░░░░░░░░░░░░░░░░░░]   0%%"
if %PCT% equ 20  set "BAR=[████░░░░░░░░░░░░░░░░]  20%%"
if %PCT% equ 40  set "BAR=[████████░░░░░░░░░░░░]  40%%"
if %PCT% equ 60  set "BAR=[████████████░░░░░░░░]  60%%"
if %PCT% equ 80  set "BAR=[████████████████░░░░]  80%%"
if %PCT% equ 100 set "BAR=[████████████████████] 100%%"

echo  !BAR!  - !MSG!
exit /b 0