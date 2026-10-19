' ==============================================================================
' SENTRY e-CF - EJECUTOR MAESTRO SILENCIOSO EN SEGUNDO PLANO (VBScript)
' Inicia el motor de facturacion electronica en un proceso completamente oculto
' (WindowStyle = 0) sin ventanas de consola, con minimo consumo de CPU/RAM.
' ==============================================================================
Option Explicit

Dim WshShell, FSO, strBaseDir, strBackendDir, strLogsDir, strCleanupBat
Dim objLogFile

Set WshShell = CreateObject("WScript.Shell")
Set FSO = CreateObject("Scripting.FileSystemObject")

strBaseDir = FSO.GetParentFolderName(WScript.ScriptFullName)
strBackendDir = strBaseDir & "\backend"
strLogsDir = strBaseDir & "\logs"

If Not FSO.FolderExists(strLogsDir) Then
    FSO.CreateFolder(strLogsDir)
End If

' 1. Ejecutar limpieza preventiva de sockets y rotacion de logs (sincrono, oculto)
strCleanupBat = strBaseDir & "\firmador_limpieza.bat"
If FSO.FileExists(strCleanupBat) Then
    WshShell.Run "cmd.exe /c """ & strCleanupBat & """", 0, True
End If

' Pausa breve de 1 segundo para asegurar liberacion de sockets
WScript.Sleep 1000

' 2. Lanzar Motor Backend Node.js (0 = Oculto, False = Asincrono / No bloqueante)
If FSO.FileExists(strBackendDir & "\dist\index.js") Then
    WshShell.CurrentDirectory = strBackendDir
    WshShell.Run "node dist/index.js", 0, False
End If

' 3. Registrar arranque en logs\sistema.log
Set objLogFile = FSO.OpenTextFile(strLogsDir & "\sistema.log", 8, True)
objLogFile.WriteLine "[" & Now & "] [SILENCIOSO] Motor e-CF desplegado en segundo plano (Puerto 5000)."
objLogFile.Close
Set objLogFile = Nothing

Set WshShell = Nothing
Set FSO = Nothing
