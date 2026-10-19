' ==============================================================================
' AGROFEM - EJECUTOR MAESTRO SILENCIOSO EN SEGUNDO PLANO (VBScript)
' Inicia el backend (PHP) y frontend (Web) en procesos completamente ocultos
' (WindowStyle = 0) sin ventanas de consola, con minimo consumo de CPU/RAM.
' ==============================================================================
Option Explicit

Dim WshShell, FSO, strApiDir, strLogsDir, strCleanupBat, strBackendBat, strFrontendBat
Dim objLogFile

Set WshShell = CreateObject("WScript.Shell")
Set FSO = CreateObject("Scripting.FileSystemObject")

strApiDir = FSO.GetParentFolderName(WScript.ScriptFullName)
strLogsDir = strApiDir & "\logs"

If Not FSO.FolderExists(strLogsDir) Then
    FSO.CreateFolder(strLogsDir)
End If

' 1. Ejecutar limpieza preventiva de puertos y rotacion de logs (sincrono, oculto)
strCleanupBat = strApiDir & "\agrofem_limpieza.bat"
If FSO.FileExists(strCleanupBat) Then
    WshShell.Run "cmd.exe /c """ & strCleanupBat & """", 0, True
End If

' Pausa breve de 1 segundo para asegurar liberacion de sockets
WScript.Sleep 1000

' 2. Lanzar Backend PHP (0 = Oculto, False = Asincrono / No bloqueante)
strBackendBat = strApiDir & "\run_backend.bat"
If FSO.FileExists(strBackendBat) Then
    WshShell.Run "cmd.exe /c """ & strBackendBat & """", 0, False
End If

' 3. Lanzar Frontend Web (0 = Oculto, False = Asincrono / No bloqueante)
strFrontendBat = strApiDir & "\run_frontend.bat"
If FSO.FileExists(strFrontendBat) Then
    WshShell.Run "cmd.exe /c """ & strFrontendBat & """", 0, False
End If

' 4. Registrar arranque en sistema.log
Set objLogFile = FSO.OpenTextFile(strLogsDir & "\sistema.log", 8, True)
objLogFile.WriteLine "[" & Now & "] [SILENCIOSO] Backend y Web desplegados en segundo plano."
objLogFile.Close
Set objLogFile = Nothing

Set WshShell = Nothing
Set FSO = Nothing
