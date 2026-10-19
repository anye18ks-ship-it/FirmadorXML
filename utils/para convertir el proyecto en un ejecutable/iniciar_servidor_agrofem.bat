@echo off
setlocal enabledelayedexpansion
title Agrofem - Administrador de Servidor Local

:: ==============================================================================
:: SISTEMA AGROFEM - SERVIDOR LOCAL Y GESTION DE TAREA PROGRAMADA
:: Disenado para Windows Server / Windows 10/11 con ejecucion en segundo plano,
:: reglas de firewall, limpieza inteligente de puertos y bajo consumo de recursos.
:: ==============================================================================

:: Rutas base relativas
set "API_DIR=%~dp0"
if "%API_DIR:~-1%"=="\" set "API_DIR=%API_DIR:~0,-1%"

pushd "%API_DIR%\..\frontend"
set "FRONTEND_DIR=%CD%"
popd

set "LOGS_DIR=%API_DIR%\logs"
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"

:: ------------------------------------------------------------------------------
:: DETECCION DE PRIVILEGIOS DE ADMINISTRADOR
:: ------------------------------------------------------------------------------
net session >nul 2>&1
if %errorLevel% equ 0 (
    set "IS_ADMIN=1"
    set "ADMIN_LABEL=ADMINISTRADOR (Acceso Total)"
) else (
    set "IS_ADMIN=0"
    set "ADMIN_LABEL=USUARIO ESTANDAR (Opciones 4, 5 y 7 requieren Administrador)"
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
:: MENU PRINCIPAL INTERACTIVO (PERMANECE ABIERTO)
:: ------------------------------------------------------------------------------
:MAIN_MENU
cls
echo ==============================================================================
echo                AGROFEM - CONTROL DE SERVIDOR LOCAL Y SERVICIOS
echo ==============================================================================
echo   Ubicacion API:      %API_DIR%
echo   Ubicacion Frontend: %FRONTEND_DIR%
echo   Puertos Asignados:  Backend :5000  ^|  Frontend Web :5173
echo   Nivel de Permisos:  %ADMIN_LABEL%
echo ==============================================================================
echo.
echo   [1] Iniciar Servicios AHORA en Segundo Plano (PHP + Web)
echo   [2] Detener Servicios y Liberar Puertos (Cierre Limpio)
echo   [3] Reiniciar Servicios (Limpieza Preventiva y Renovacion)
echo   [4] Instalar Tarea Programada en Windows (Arranque Automatico con Servidor)
echo   [5] Configurar / Verificar Reglas del Firewall de Windows
echo   [6] Ver Estado de Puertos y Diagnostico de Salud
echo   [7] Desinstalar Tarea Programada y Remover Reglas de Firewall
echo   [8] Salir
echo.
echo ==============================================================================
set /p "OPCION=Seleccione una opcion [1-8]: "

if "%OPCION%"=="1" goto :MENU_START
if "%OPCION%"=="2" goto :MENU_STOP
if "%OPCION%"=="3" goto :MENU_RESTART
if "%OPCION%"=="4" goto :MENU_INSTALL_TASK
if "%OPCION%"=="5" goto :MENU_FIREWALL
if "%OPCION%"=="6" goto :MENU_STATUS
if "%OPCION%"=="7" goto :MENU_UNINSTALL_TASK
if "%OPCION%"=="8" exit /b 0

echo Opcion invalida.
timeout /t 2 >nul
goto :MAIN_MENU

:: ------------------------------------------------------------------------------
:: ACCIONES INTERACTIVAS
:: ------------------------------------------------------------------------------
:MENU_START
call :START_ALL
echo.
pause
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
echo  Por favor haga clic derecho sobre 'iniciar_servidor_agrofem.bat' o sobre
echo  'IniciarServidorAgrofem.exe' y seleccione:
echo  'Ejecutar como administrador' (Run as administrator).
echo ==============================================================================
echo.
exit /b 0

:START_ALL
echo.
echo [*] Iniciando servicios en segundo plano...
wscript.exe "%API_DIR%\agrofem_silencioso.vbs"
echo [*] Verificando activacion de puertos de red (5000 y 5173)...
set "WAIT_ATTEMPTS=0"
:WAIT_LOOP
set /a WAIT_ATTEMPTS+=1
ping 127.0.0.1 -n 2 >nul 2>&1
set "P5000="
set "P5173="
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":5000" ^| findstr "LISTENING"') do set "P5000=%%p"
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":5173" ^| findstr "LISTENING"') do set "P5173=%%p"
if defined P5000 if defined P5173 goto :WAIT_DONE
if !WAIT_ATTEMPTS! lss 6 goto :WAIT_LOOP
:WAIT_DONE
echo [OK] Peticion de arranque procesada.
call :CHECK_STATUS
exit /b 0

:STOP_ALL
echo.
echo [*] Deteniendo servicios y liberando puertos 5000 y 5173...
set "FOUND=0"
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":5000" ^| findstr "LISTENING"') do (
    if not "%%p"=="" if not "%%p"=="0" (
        taskkill /F /PID %%p >nul 2>&1
        echo [OK] Proceso en puerto 5000 finalizado [PID: %%p].
        set "FOUND=1"
    )
)
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":5173" ^| findstr "LISTENING"') do (
    if not "%%p"=="" if not "%%p"=="0" (
        taskkill /F /PID %%p >nul 2>&1
        echo [OK] Proceso en puerto 5173 finalizado [PID: %%p].
        set "FOUND=1"
    )
)
if "%FOUND%"=="0" (
    echo [INFO] No habia procesos activos en los puertos 5000 o 5173.
) else (
    echo [OK] Puertos liberados completamente.
)
exit /b 0

:SETUP_FIREWALL
echo.
echo [*] Verificando reglas en el Firewall de Windows...

netsh advfirewall firewall show rule name="Agrofem_Backend_API_5000" >nul 2>&1
if !errorLevel! neq 0 (
    echo [+] Creando regla de Firewall para Backend API [Puerto TCP 5000]...
    netsh advfirewall firewall add rule name="Agrofem_Backend_API_5000" dir=in action=allow protocol=TCP localport=5000 profile=any description="Permitir conexion entrante a API Agrofem" >nul 2>&1
    if !errorLevel! equ 0 (
        echo [OK] Regla Agrofem_Backend_API_5000 creada exitosamente.
    ) else (
        echo [ERROR] No se pudo crear la regla para el puerto 5000.
    )
) else (
    echo [OK] Regla de Firewall para puerto 5000 ya existe y esta activa.
)

netsh advfirewall firewall show rule name="Agrofem_Frontend_Web_5173" >nul 2>&1
if !errorLevel! neq 0 (
    echo [+] Creando regla de Firewall para Frontend Web [Puerto TCP 5173]...
    netsh advfirewall firewall add rule name="Agrofem_Frontend_Web_5173" dir=in action=allow protocol=TCP localport=5173 profile=any description="Permitir conexion entrante a Web Agrofem" >nul 2>&1
    if !errorLevel! equ 0 (
        echo [OK] Regla Agrofem_Frontend_Web_5173 creada exitosamente.
    ) else (
        echo [ERROR] No se pudo crear la regla para el puerto 5173.
    )
) else (
    echo [OK] Regla de Firewall para puerto 5173 ya existe y esta activa.
)
exit /b 0

:REMOVE_FIREWALL
echo.
echo [*] Removiendo reglas de Firewall de Agrofem...
netsh advfirewall firewall delete rule name="Agrofem_Backend_API_5000" >nul 2>&1
netsh advfirewall firewall delete rule name="Agrofem_Frontend_Web_5173" >nul 2>&1
echo [OK] Reglas de firewall removidas.
exit /b 0

:CREATE_SCHEDULED_TASK
echo.
echo [*] Configurando Tarea Programada de Windows [Agrofem_Servidor_Local]...

:: Eliminar tarea previa si existe
schtasks /query /tn "Agrofem_Servidor_Local" >nul 2>&1
if !errorLevel! equ 0 (
    echo [*] Actualizando tarea programada existente...
    schtasks /delete /tn "Agrofem_Servidor_Local" /f >nul 2>&1
)

:: Crear la tarea con arranque al iniciar el sistema [ONSTART] y privilegios maximos [HIGHEST]
:: Se ejecuta como SYSTEM para que corra 100% en segundo plano sin importar que usuario inicie sesion
schtasks /create /tn "Agrofem_Servidor_Local" /tr "wscript.exe \"%API_DIR%\agrofem_silencioso.vbs\"" /sc ONSTART /ru "SYSTEM" /rl HIGHEST /f >nul 2>&1

if !errorLevel! neq 0 (
    echo [!] Aviso: No se pudo registrar bajo cuenta SYSTEM, registrando con cuenta de inicio de sesion...
    schtasks /create /tn "Agrofem_Servidor_Local" /tr "wscript.exe \"%API_DIR%\agrofem_silencioso.vbs\"" /sc ONLOGON /rl HIGHEST /f >nul 2>&1
)

if !errorLevel! equ 0 (
    echo [OK] Tarea Programada 'Agrofem_Servidor_Local' creada con exito.
    echo      Iniciara automaticamente con el servidor en segundo plano sin ventanas.
) else (
    echo [ERROR] Error al crear la tarea programada en Windows.
)
exit /b 0

:REMOVE_SCHEDULED_TASK
echo.
echo [*] Eliminando Tarea Programada 'Agrofem_Servidor_Local'...
schtasks /delete /tn "Agrofem_Servidor_Local" /f >nul 2>&1
if !errorLevel! equ 0 (
    echo [OK] Tarea programada eliminada de Windows.
) else (
    echo [INFO] La tarea programada no existia.
)
exit /b 0

:CHECK_STATUS
echo.
echo ==============================================================================
echo                         ESTADO ACTUAL DE LOS SERVICIOS
echo ==============================================================================

set "PORT5000_PID="
set "PORT5173_PID="

for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":5000" ^| findstr "LISTENING"') do set "PORT5000_PID=%%p"
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":5173" ^| findstr "LISTENING"') do set "PORT5173_PID=%%p"

if defined PORT5000_PID (
    echo  [ONLINE]  Backend PHP API    - Puerto 5000 - PID: !PORT5000_PID!
) else (
    echo  [OFFLINE] Backend PHP API    - Puerto 5000 [No activo]
)

if defined PORT5173_PID (
    echo  [ONLINE]  Frontend Web Vite  - Puerto 5173 - PID: !PORT5173_PID!
) else (
    echo  [OFFLINE] Frontend Web Vite  - Puerto 5173 [No activo]
)

echo.
schtasks /query /tn "Agrofem_Servidor_Local" >nul 2>&1
if !errorLevel! equ 0 (
    echo  [PROGRAMADA] Tarea 'Agrofem_Servidor_Local' registrada en Windows Task Scheduler.
) else (
    echo  [NO PROGRAMADA] Tarea 'Agrofem_Servidor_Local' aun no registrada.
)

echo ==============================================================================
exit /b 0
