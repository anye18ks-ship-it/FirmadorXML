const { app, BrowserWindow, Tray, Menu, nativeImage, ipcMain } = require('electron');
const path = require('path');
const { spawn } = require('child_process');

let mainWindow = null;
let tray = null;
let isQuitting = false;
let backendProcess = null;

const PORT = 5000;
const APP_URL = `http://localhost:${PORT}`;

// Iniciar proceso backend de Node.js si no está corriendo
function startBackend() {
  const backendEntry = path.join(__dirname, '..', 'backend', 'dist', 'index.js');
  backendProcess = spawn('node', [backendEntry], {
    cwd: path.join(__dirname, '..', 'backend'),
    stdio: 'ignore',
    detached: true,
  });
  backendProcess.unref();
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 820,
    minWidth: 1024,
    minHeight: 700,
    title: 'Sentry <SCEYE> (e-CF) v2.0 - Firmador DGII',
    backgroundColor: '#0b0f17',
    autoHideMenuBar: true,
    show: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
    },
  });

  mainWindow.loadURL(APP_URL);

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  // Minimizar al System Tray en lugar de cerrar (comportamiento esperado por los operadores)
  mainWindow.on('close', (event) => {
    if (!isQuitting) {
      event.preventDefault();
      mainWindow.hide();
      if (tray) {
        tray.displayBalloon?.({
          title: 'Firmador e-CF en segundo plano',
          content: 'El servicio continúa procesando comprobantes fiscales en la bandeja.',
        });
      }
    }
  });
}

function createTray() {
  // Crear icono en el System Tray
  const icon = nativeImage.createFromBuffer(
    Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAA7SURBVDhPY/wPBAwUACYGzIAwA0jVAMLAwMhAGhi1gFEzGLWAYTQDYDTuRk7gP/r/n1QMwMAAohgA2i8f1cZ9zFwAAAAASUVORK5CYII=',
      'base64'
    )
  );

  tray = new Tray(icon);
  tray.setToolTip('Sentry <SCEYE> (e-CF) v2.0 - Firmador DGII');

  const contextMenu = Menu.buildFromTemplate([
    {
      label: 'Abrir Firmador',
      click: () => {
        if (mainWindow) {
          mainWindow.show();
          mainWindow.focus();
        }
      },
    },
    { type: 'separator' },
    {
      label: 'Pausar / Reanudar Servicio',
      click: async () => {
        try {
          const http = require('http');
          http.get(`${APP_URL}/api/status`, (res) => {
            let data = '';
            res.on('data', (c) => (data += c));
            res.on('end', () => {
              const status = JSON.parse(data);
              const endpoint = status.data.isPaused ? '/api/worker/resume' : '/api/worker/pause';
              const req = http.request(`${APP_URL}${endpoint}`, { method: 'POST' });
              req.end();
            });
          });
        } catch (e) {}
      },
    },
    { type: 'separator' },
    {
      label: 'Salir Completamente',
      click: () => {
        isQuitting = true;
        app.quit();
      },
    },
  ]);

  tray.setContextMenu(contextMenu);
  tray.on('double-click', () => {
    if (mainWindow) {
      mainWindow.show();
      mainWindow.focus();
    }
  });
}

// Inicialización de la aplicación Desktop
app.whenReady().then(() => {
  createTray();
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('before-quit', () => {
  isQuitting = true;
});
