using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;

[assembly: AssemblyTitle("Sentry e-CF - Firmador Electrónico DGII")]
[assembly: AssemblyDescription("Servicio Desktop y Motor de Facturación Electrónica DGII")]
[assembly: AssemblyCompany("Agropecuaria Fernández Muñoz, S.R.L.")]
[assembly: AssemblyProduct("Sentry e-CF v2.0")]
[assembly: AssemblyCopyright("Copyright © Agrofem 2026")]
[assembly: AssemblyVersion("2.0.0.0")]
[assembly: AssemblyFileVersion("2.0.0.0")]

namespace SentryFirmador
{
    static class Program
    {
        private static NotifyIcon trayIcon;
        private static ContextMenu trayMenu;
        private static Process backendProcess = null;
        private static Process browserProcess = null;
        private static int port = 5000;
        private static string appUrl = "http://localhost:5000";
        private static string baseDir = "";
        private static string backendDir = "";
        private static bool isExiting = false;

        [STAThread]
        static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            baseDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
            if (baseDir.EndsWith("desktop", StringComparison.OrdinalIgnoreCase))
            {
                baseDir = Directory.GetParent(baseDir).FullName;
            }
            backendDir = Path.Combine(baseDir, "backend");

            // 1. Asegurar arranque del Backend
            EnsureBackendRunning();

            // 2. Configurar System Tray
            ConfigureTray();

            // 3. Abrir la interfaz al iniciar a menos que se invoque con --silent
            bool isSilent = false;
            foreach (string arg in args)
            {
                if (arg.Equals("--silent", StringComparison.OrdinalIgnoreCase) ||
                    arg.Equals("-s", StringComparison.OrdinalIgnoreCase))
                {
                    isSilent = true;
                    break;
                }
            }

            if (!isSilent)
            {
                OpenBrowserApp();
            }
            else
            {
                trayIcon.ShowBalloonTip(3000, "Sentry e-CF en Segundo Plano",
                    "El motor de facturación electrónica DGII se encuentra activo y procesando comprobantes.",
                    ToolTipIcon.Info);
            }

            // Loop de mensajes de Windows
            Application.Run();
        }

        private static bool IsPortListening(int targetPort)
        {
            try
            {
                using (TcpClient client = new TcpClient())
                {
                    var result = client.BeginConnect("127.0.0.1", targetPort, null, null);
                    bool success = result.AsyncWaitHandle.WaitOne(500);
                    if (success)
                    {
                        client.EndConnect(result);
                        return true;
                    }
                    return false;
                }
            }
            catch
            {
                return false;
            }
        }

        private static void EnsureBackendRunning()
        {
            if (IsPortListening(port))
            {
                return;
            }

            string backendEntry = Path.Combine(backendDir, "dist", "index.js");
            if (!File.Exists(backendEntry))
            {
                MessageBox.Show("No se encontró el archivo compilado del backend: " + backendEntry +
                    "\nPor favor ejecute 'npm run build' en la carpeta backend.",
                    "Error de Inicialización - Sentry e-CF", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            try
            {
                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "node";
                psi.Arguments = "dist/index.js";
                psi.WorkingDirectory = backendDir;
                psi.WindowStyle = ProcessWindowStyle.Hidden;
                psi.CreateNoWindow = true;
                psi.UseShellExecute = false;

                backendProcess = Process.Start(psi);

                // Esperar hasta que el puerto esté activo
                int retries = 0;
                while (retries < 25)
                {
                    Thread.Sleep(500);
                    if (IsPortListening(port)) break;
                    retries++;
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show("Error al iniciar el motor Node.js: " + ex.Message,
                    "Error - Sentry e-CF", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private static void ConfigureTray()
        {
            trayMenu = new ContextMenu();
            trayMenu.MenuItems.Add("🖥️ Abrir Firmador Desktop", (s, e) => OpenBrowserApp());
            trayMenu.MenuItems.Add("-");
            trayMenu.MenuItems.Add("⏸️ / ▶️ Pausar o Reanudar", (s, e) => ToggleWorker());
            trayMenu.MenuItems.Add("🔄 Forzar Ciclo Manual", (s, e) => TriggerManualCycle());
            trayMenu.MenuItems.Add("🩺 Diagnóstico de Salud", (s, e) => ShowHealthStatus());
            trayMenu.MenuItems.Add("-");
            trayMenu.MenuItems.Add("❌ Salir Completamente", (s, e) => ExitApplication());

            // Extraer icono corporativo incrustado en el ejecutable
            Icon appIcon = null;
            try
            {
                appIcon = Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location);
            }
            catch
            {
                appIcon = SystemIcons.Shield;
            }
            if (appIcon == null) appIcon = SystemIcons.Shield;

            trayIcon = new NotifyIcon();
            trayIcon.Text = "Sentry e-CF - Firmador DGII (Agrofem)";
            trayIcon.Icon = appIcon;
            trayIcon.ContextMenu = trayMenu;
            trayIcon.Visible = true;

            trayIcon.DoubleClick += (s, e) => OpenBrowserApp();
        }

        private static void OpenBrowserApp()
        {
            string browserExe = FindBrowserExe();
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo();
                if (!string.IsNullOrEmpty(browserExe))
                {
                    psi.FileName = browserExe;
                    psi.Arguments = string.Format("--app=\"{0}\" --window-size=1280,820 --app-id=\"FirmadorDGIIAgrofem\"", appUrl);
                }
                else
                {
                    psi.FileName = appUrl;
                    psi.UseShellExecute = true;
                }
                browserProcess = Process.Start(psi);
            }
            catch (Exception ex)
            {
                Process.Start(appUrl);
            }
        }

        private static string FindBrowserExe()
        {
            string[] candidates = new string[]
            {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"Microsoft\Edge\Application\msedge.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"Microsoft\Edge\Application\msedge.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Microsoft\Edge\Application\msedge.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"Google\Chrome\Application\chrome.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"Google\Chrome\Application\chrome.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Google\Chrome\Application\chrome.exe")
            };

            foreach (string p in candidates)
            {
                if (File.Exists(p)) return p;
            }
            return null;
        }

        private static void ToggleWorker()
        {
            try
            {
                using (WebClient wc = new WebClient())
                {
                    string statusJson = wc.DownloadString(appUrl + "/api/status");
                    bool isPaused = statusJson.Contains("\"isPaused\":true");
                    string endpoint = isPaused ? "/api/worker/resume" : "/api/worker/pause";
                    wc.UploadString(appUrl + endpoint, "POST", "{}");
                    trayIcon.ShowBalloonTip(2000, "Sentry e-CF",
                        isPaused ? "Motor Reanudado - Procesando comprobantes." : "Motor Pausado temporalmente.",
                        ToolTipIcon.Info);
                }
            }
            catch { }
        }

        private static void TriggerManualCycle()
        {
            try
            {
                using (WebClient wc = new WebClient())
                {
                    wc.UploadString(appUrl + "/api/worker/process-now", "POST", "{}");
                    trayIcon.ShowBalloonTip(2000, "Sentry e-CF", "Ciclo manual de facturación ejecutado.", ToolTipIcon.Info);
                }
            }
            catch { }
        }

        private static void ShowHealthStatus()
        {
            try
            {
                using (WebClient wc = new WebClient())
                {
                    string json = wc.DownloadString(appUrl + "/api/status");
                    MessageBox.Show("Telemetría en Vivo de Sentry e-CF:\n\n" + json,
                        "Diagnóstico de Salud - Sentry e-CF", MessageBoxButtons.OK, MessageBoxIcon.Information);
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show("No se pudo conectar con el motor local: " + ex.Message,
                    "Alerta de Conexión", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private static void ExitApplication()
        {
            if (isExiting) return;
            isExiting = true;

            trayIcon.Visible = false;
            trayIcon.Dispose();

            // Matar procesos hijos si es necesario
            try
            {
                if (backendProcess != null && !backendProcess.HasExited)
                {
                    backendProcess.Kill();
                }
            }
            catch { }

            Application.Exit();
        }
    }
}
