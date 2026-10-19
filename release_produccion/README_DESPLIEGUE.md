# 📦 Sentry (e-CF) v2.0 - Guía Operativa de Despliegue en Windows Server

**Agropecuaria Fernández Muñoz, S.R.L. (Agrofem)**  
**Estándar DGII de Facturación Electrónica (Ley 32-23)**

---

## 📋 1. Requisitos del Servidor

- **Sistema Operativo**: Windows Server 2016, 2019, 2022 o Windows 10/11 (64-bit).
- **Entorno de Ejecución**: Node.js v18.x o v20.x LTS instalado en el servidor y presente en la variable de entorno `PATH`.
- **Navegador**: Microsoft Edge o Google Chrome (para renderizado nativo de la interfaz de escritorio).
- **Red y Puertos**:
  - Salida TCP hacia servidor SQL Server `172.16.4.14:1433`.
  - Salida HTTPS (puerto 443) hacia `testecf.dgii.gov.do` (Ambiente Prueba) o `ecf.dgii.gov.do` (Ambiente Producción).
  - Puerto local TCP `5000` disponible en el servidor.

---

## 🚀 2. Métodos de Inicio

Esta carpeta distribuible incluye todo lo necesario para ejecutar el software de forma flexible:

### Opción A: Aplicación Nativa con Bandeja del Sistema (Recomendada para Operadores)
- **Haga doble clic en:** `SentryFirmador.exe`
- Se iniciará con su nombre corporativo en el **Administrador de Tareas** (`SentryFirmador.exe`), creará un icono en la **Bandeja del Sistema (System Tray)** y abrirá la ventana de escritorio.
- Al cerrar la ventana, el servicio continuará trabajando en segundo plano. Puede restaurar la ventana o gestionar el servicio haciendo clic derecho sobre el icono en la barra de tareas.

### Opción B: Panel de Control y Mantenimiento Técnico (Para Administradores)
- **Haga clic derecho y elija 'Ejecutar como administrador' en:** `iniciar_servidor_firmador.bat`
- Le presenta un menú interactivo con 9 opciones:
  1. Iniciar motor en segundo plano (Modo Silencioso).
  2. Abrir la interfaz desktop moderna.
  3. Detener servicios y liberar puerto 5000.
  4. Reiniciar servicios (con limpieza preventiva).
  5. **Instalar Tarea Programada en Windows (Arranque Automático con el Servidor).**
  6. **Configurar Reglas del Firewall de Windows.**
  7. Diagnóstico de salud y estado de puertos.
  8. Desinstalar Tarea Programada.
  9. Salir.

### Opción C: Apagado Rápido
- **Haga doble clic en:** `DetenerFirmador.bat` para terminar cualquier instancia activa en el puerto 5000.

---

## ⚙️ 3. Configuración del Archivo `.env`

Ubicado en `backend/.env`. Contiene los parámetros de conexión:

```ini
# Configuración del Servidor HTTP
PORT=5000
NODE_ENV=production

# Base de Datos SQL Server
DB_SERVER=172.16.4.14
DB_PORT=1433
DB_NAME=cms
DB_USER=sa
DB_PASSWORD=@Gr0f3m

# Entorno DGII: 'test' para Certificación / 'prod' para Emisión Real
DGII_ENV=test
DGII_RNC=102314675
DGII_URL_TEST=https://testecf.dgii.gov.do/testfe/
DGII_URL_PROD=https://ecf.dgii.gov.do/fe/

# Parámetros del Worker
WORKER_INTERVAL_MS=3000
WORKER_BATCH_SIZE=5

# Modo de Seguridad:
# - DRY_RUN=true: Simula la firma y no modifica la base de datos (desarrollo/pruebas).
# - DRY_RUN=false: MODO EN FIRME: Actualiza C_Posted='F', 'Q', 'P', 'Y' en SQL Server.
DRY_RUN=false
MOCK_DGII=false
```

---

## 🛡️ 4. Automatización con Windows Task Scheduler

Para garantizar que el firmador arranque automáticamente al reiniciar el servidor sin necesidad de que ningún usuario inicie sesión:

1. Ejecute `iniciar_servidor_firmador.bat` como **Administrador**.
2. Seleccione la opción **`[5] Instalar Tarea Programada en Windows`**.
3. El sistema registrará la tarea `Sentry_Firmador_DGII` bajo la cuenta `SYSTEM` con privilegios máximos (`HIGHEST`) activándose en el evento `ONSTART`.

Para comprobar el estado de la tarea en cualquier momento, puede hacerlo desde la opción `[7]` del menú o desde la interfaz web haciendo clic en el botón **⚙️ Configuración**.
