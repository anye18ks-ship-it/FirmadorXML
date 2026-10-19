@echo off
setlocal enabledelayedexpansion
title Sentry (e-CF) v2.0 - Administrador de Servidor Local

:: ==============================================================================
:: SISTEMA SENTRY (e-CF) v2.0 - CONTROL DE SERVIDOR LOCAL Y SERVICIOS
:: Agropecuaria Fernandez Munoz, S.R.L. (Ley 32-23)
:: Disenado para Windows Server / Windows 10/11 con ejecucion en segundo plano,
:: reglas de firewall, limpieza inteligente de puertos y bajo consumo de recursos.
:: ==============================================================================

set "BASE_DIR=%~dp0"
if "%BASE_DIR:~-1%"=="\" set "BASE_DIR=%BASE_DIR:~0,-1%"

set "BACKEND_DIR=%BASE_DIR%\backend"
set "LOGS_DIR=%BASE_DIR%\logs"
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"

set "PORT=5000"

:: ------------------------------------------------------------------------------
:: DETECCION DE PRIVILEGIOS DE ADMINISTRADOR
:: ------------------------------------------------------------------------------
net session >nul 2>&1
if %errorLevel% equ 0 (
    set "IS_ADMIN=1"
    set "ADMIN_LABEL=ADMINISTRADOR (Acceso Total)"
) else (
    set "IS_ADMIN=0"
    set "ADMIN_LABEL=USUARIO ESTANDAR (Opciones 5, 6 y 8 requieren Administrador)"
)

:: ------------------------------------------------------------------------------
:: PROCESAMIENTO DE ARGUMENTOS CLI
:: ------------------------------------------------------------------------------
if /i "%~1"=="--status" goto :CMD_STATUS
if /i "%~1"=="--start" goto :CMD_START
if /i "%~1"=="--stop" goto :CMD_STOP
if /i "%~1"=="--restart" goto :CMD_RESTART
if /i "%~1"=="--install-task" goto :CMD_INSTALL_TASK
if /i "%~1"=="--uninstall-task" goto :CMD_UNINSTALL_TASK

:: ------------------------------------------------------------------------------
:: MENU PRINCIPAL INTERACTIVO
:: ------------------------------------------------------------------------------
:MAIN_MENU
cls
echo ==============================================================================
echo       Sentry (e-CF) v2.0 - CONTROL DE SERVIDOR LOCAL Y SERVICIOS
echo       Agropecuaria Fernandez Munoz, S.R.L. (Ley 32-23 DGII)
echo ==============================================================================
echo   Ubicacion Base:     %BASE_DIR%
echo   Puerto Asignado:    Puerto HTTP :%PORT% (API + Web Desktop)
echo   Nivel de Permisos:  %ADMIN_LABEL%
echo ==============================================================================
echo.
echo   [1] Iniciar Motor de Facturacion en Segundo Plano (Silencioso)
echo   [2] Abrir Interfaz Desktop Moderna (Ventana Nativa)
echo   [3] Detener Servicios y Liberar Puerto %PORT% (Cierre Limpio)
echo   [4] Reiniciar Servicios (Limpieza Preventiva y Re-arranque)
echo   [5] Instalar Tarea Programada en Windows (Arranque con el Servidor)
echo   [6] Configurar / Verificar Reglas del Firewall de Windows
echo   [7] Ver Estado de Puertos y Diagnostico de Salud
echo   [8] Desinstalar Tarea Programada y Remover Regla de Firewall
echo   [9] Salir
echo.
echo ==============================================================================
set /p "OPCION=Seleccione una opcion [1-9]: "

if "%OPCION%"=="1" goto :MENU_START
if "%OPCION%"=="2" goto :MENU_OPEN_UI
if "%OPCION%"=="3" goto :MENU_STOP
if "%OPCION%"=="4" goto :MENU_RESTART
if "%OPCION%"=="5" goto :MENU_INSTALL_TASK
if "%OPCION%"=="6" goto :MENU_FIREWALL
if "%OPCION%"=="7" goto :MENU_STATUS
if "%OPCION%"=="8" goto :MENU_UNINSTALL_TASK
if "%OPCION%"=="9" exit /b 0

echo Opcion invalida.
ping -n 2 127.0.0.1 >nul
goto :MAIN_MENU

:: ------------------------------------------------------------------------------
:: ACCIONES INTERACTIVAS
:: ------------------------------------------------------------------------------
:MENU_START
call :START_ALL
echo.
pause
goto :MAIN_MENU

:MENU_OPEN_UI
call :LAUNCH_DESKTOP_UI
goto :MAIN_MENU

:MENU_STOP
call :STOP_ALL
echo.
pause
goto :MAIN_MENU

:MENU_RESTART
call :STOP_ALL
ping 127.0.0.1 -n 2 >nul 2>&1
call :START_ALL
echo.
pause
goto :MAIN_MENU

:MENU_INSTALL_TASK
if "%IS_ADMIN%"=="0" (
    call :REQUIRE_ADMIN
    pause
    goto :MAIN_MENU
)
call :SETUP_FIREWALL
call :CREATE_SCHEDULED_TASK
echo.
pause
goto :MAIN_MENU

:MENU_FIREWALL
if "%IS_ADMIN%"=="0" (
    call :REQUIRE_ADMIN
    pause
    goto :MAIN_MENU
)
call :SETUP_FIREWALL
echo.
pause
goto :MAIN_MENU

:MENU_STATUS
call :CHECK_STATUS
echo.
pause
goto :MAIN_MENU

:MENU_UNINSTALL_TASK
if "%IS_ADMIN%"=="0" (
    call :REQUIRE_ADMIN
    pause
    goto :MAIN_MENU
)
call :REMOVE_SCHEDULED_TASK
call :REMOVE_FIREWALL
echo.
pause
goto :MAIN_MENU

:: ------------------------------------------------------------------------------
:: ACCIONES CLI DIRECTAS
:: ------------------------------------------------------------------------------
:CMD_START
call :START_ALL
exit /b 0

:CMD_STOP
call :STOP_ALL
exit /b 0

:CMD_RESTART
call :STOP_ALL
ping 127.0.0.1 -n 2 >nul 2>&1
call :START_ALL
exit /b 0

:CMD_INSTALL_TASK
if "%IS_ADMIN%"=="0" (
    call :REQUIRE_ADMIN
    exit /b 1
)
call :SETUP_FIREWALL
call :CREATE_SCHEDULED_TASK
exit /b 0

:CMD_UNINSTALL_TASK
if "%IS_ADMIN%"=="0" (
    call :REQUIRE_ADMIN
    exit /b 1
)
call :REMOVE_SCHEDULED_TASK
call :REMOVE_FIREWALL
exit /b 0

:CMD_STATUS
call :CHECK_STATUS
exit /b 0

:: ==============================================================================
:: SUBRUTINAS PRINCIPALES
:: ==============================================================================

:REQUIRE_ADMIN
echo.
echo ==============================================================================
echo  [PERMISO DENEGADO] Se requieren permisos de Administrador para esta accion.
echo  Haga clic derecho sobre este script y elija:
echo  'Ejecutar como administrador' (Run as administrator).
echo ==============================================================================
echo.
exit /b 0

:START_ALL
echo.
echo [*] Iniciando motor Sentry e-CF en segundo plano...
wscript.exe "%BASE_DIR%\firmador_silencioso.vbs"
echo [*] Verificando activacion del puerto de red (%PORT%)...
set "WAIT_ATTEMPTS=0"

:WAIT_LOOP
set /a WAIT_ATTEMPTS+=1
ping 127.0.0.1 -n 2 >nul 2>&1
set "P5000="
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":%PORT%" ^| findstr "LISTENING"') do set "P5000=%%p"
if defined P5000 goto :WAIT_DONE
if !WAIT_ATTEMPTS! lss 10 goto :WAIT_LOOP

:WAIT_DONE
if defined P5000 (
    echo [OK] Motor e-CF en linea y respondiendo en el puerto %PORT% [PID: !P5000!].
) else (
    echo [ERROR] No se pudo verificar la apertura del puerto %PORT%.
)
exit /b 0

:STOP_ALL
echo.
echo [*] Deteniendo servicios y liberando puerto %PORT%...
set "FOUND=0"
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":%PORT%" ^| findstr "LISTENING"') do (
    if not "%%p"=="" if not "%%p"=="0" (
        taskkill /F /PID %%p >nul 2>&1
        echo [OK] Proceso en puerto %PORT% finalizado [PID: %%p].
        set "FOUND=1"
    )
)
if "%FOUND%"=="0" (
    echo [INFO] No habia procesos activos en el puerto %PORT%.
) else (
    echo [OK] Puerto %PORT% liberado completamente.
)
exit /b 0

:LAUNCH_DESKTOP_UI
echo [*] Desplegando interfaz visual de escritorio...
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

if defined BROWSER_EXE (
    start "" "%BROWSER_EXE%" --app="http://localhost:%PORT%" --window-size=1280,820 --app-id="FirmadorDGIIAgrofem"
) else (
    start "" "http://localhost:%PORT%"
)
exit /b 0

:SETUP_FIREWALL
echo.
echo [*] Verificando regla en el Firewall de Windows...
netsh advfirewall firewall show rule name="Sentry_Firmador_DGII_5000" >nul 2>&1
if !errorLevel! neq 0 (
    echo [+] Creando regla de Firewall para Sentry e-CF [Puerto TCP %PORT%]...
    netsh advfirewall firewall add rule name="Sentry_Firmador_DGII_5000" dir=in action=allow protocol=TCP localport=%PORT% profile=any description="Permitir conexion al Firmador Electronico DGII" >nul 2>&1
    if !errorLevel! equ 0 (
        echo [OK] Regla de Firewall creada exitosamente.
    ) else (
        echo [ERROR] No se pudo crear la regla en el Firewall.
    )
) else (
    echo [OK] Regla de Firewall para puerto %PORT% ya existe y esta activa.
)
exit /b 0

:REMOVE_FIREWALL
echo.
echo [*] Removiendo regla de Firewall de Sentry e-CF...
netsh advfirewall firewall delete rule name="Sentry_Firmador_DGII_5000" >nul 2>&1
echo [OK] Regla de Firewall removida.
exit /b 0

:CREATE_SCHEDULED_TASK
echo.
echo [*] Configurando Tarea Programada de Windows [Sentry_Firmador_DGII]...

schtasks /query /tn "Sentry_Firmador_DGII" >nul 2>&1
if !errorLevel! equ 0 (
    echo [*] Actualizando tarea programada existente...
    schtasks /delete /tn "Sentry_Firmador_DGII" /f >nul 2>&1
)

:: Crear la tarea con arranque del sistema y privilegios maximos
schtasks /create /tn "Sentry_Firmador_DGII" /tr "wscript.exe \"%BASE_DIR%\firmador_silencioso.vbs\"" /sc ONSTART /ru "SYSTEM" /rl HIGHEST /f >nul 2>&1

if !errorLevel! neq 0 (
    echo [!] Aviso: No se pudo registrar bajo cuenta SYSTEM, registrando con cuenta de inicio de sesion...
    schtasks /create /tn "Sentry_Firmador_DGII" /tr "wscript.exe \"%BASE_DIR%\firmador_silencioso.vbs\"" /sc ONLOGON /rl HIGHEST /f >nul 2>&1
)

if !errorLevel! equ 0 (
    echo [OK] Tarea Programada 'Sentry_Firmador_DGII' creada con exito.
    echo      El firmador iniciara automaticamente con el servidor en segundo plano.
) else (
    echo [ERROR] Error al crear la tarea programada en Windows.
)
exit /b 0

:REMOVE_SCHEDULED_TASK
echo.
echo [*] Eliminando Tarea Programada 'Sentry_Firmador_DGII'...
schtasks /delete /tn "Sentry_Firmador_DGII" /f >nul 2>&1
if !errorLevel! equ 0 (
    echo [OK] Tarea programada eliminada de Windows.
) else (
    echo [INFO] La tarea programada no existia.
)
exit /b 0

:CHECK_STATUS
echo.
echo ==============================================================================
echo                         ESTADO ACTUAL DEL SISTEMA
echo ==============================================================================

set "PORT5000_PID="
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":%PORT%" ^| findstr "LISTENING"') do set "PORT5000_PID=%%p"

if defined PORT5000_PID (
    echo  [ONLINE]  Motor Sentry e-CF  - Puerto %PORT% - PID: !PORT5000_PID!
) else (
    echo  [OFFLINE] Motor Sentry e-CF  - Puerto %PORT% [Detenido]
)

echo.
schtasks /query /tn "Sentry_Firmador_DGII" >nul 2>&1
if !errorLevel! equ 0 (
    echo  [PROGRAMADA] Tarea 'Sentry_Firmador_DGII' registrada en Windows Task Scheduler.
) else (
    echo  [NO PROGRAMADA] Tarea 'Sentry_Firmador_DGII' aun no registrada en el inicio.
)

echo ==============================================================================
exit /b 0
