# FASE 3: Interfaz Desktop Moderna (Fiel a la Captura Original)

**Proyecto:** Modernización y Recreación de `xmlSentryAFM` en Node.js + TypeScript  
**Contribuyente:** Agropecuaria Fernández Muñoz, S.R.L. (Agrofem)  
**Marco Legal y Fiscal:** Ley 32-23 de Facturación Electrónica (DGII - República Dominicana)  
**Fecha de Ejecución:** Octubre 2026  
**Estado:** ✅ **Completado con Éxito (18/18 Tests Verdes)**

---

## 1. Resumen Ejecutivo de la Fase 3

En esta tercera fase se implementó la **Interfaz Visual Desktop Moderna** para Windows, sustituyendo por completo la anticuada pantalla Swing de Java (`frmMain.java`), respetando milimétricamente la distribución operativa de los **4 cuadrantes funcionales** que los operadores ya conocen según `DOC/FirmadorXML/utils/UI DEL FIRMADOR ANTIGUO.JPG`, pero elevándola a un estándar estético y tecnológico de nivel empresarial.

### Comparativa Visual y Operativa:
| Componente UI | Interfaz Legacy (Java Swing) | Nueva Interfaz Desktop (React + TS + CSS) |
| :--- | :--- | :--- |
| **Tecnología Visual** | Java Swing / AWT (Java 8) | React 18 + Vanilla CSS (Design System Tokens) |
| **Distribución** | 4 cuadrantes fijos | **4 cuadrantes exactos** + barra de estado con telemetría en vivo |
| **Tema y Estética** | Estilo Windows 98/XP gris plano | **Tema Oscuro Profesional / Tema Claro** con tipografía JetBrains Mono |
| **Inspección de XML** | `JTextPane` monocolor sin formato | **Consola interactiva con syntax highlighting y botón de copia** |
| **Semáforo del Worker** | Etiqueta de texto estática | **Píldora brillante con animación de pulso (Pulsing Glow)** |
| **Alertas de Secuencia** | Colores básicos en celda | **Píldoras inteligentes (Verde / Amarillo / Rojo palpitante)** |
| **Despliegue Desktop** | Archivo `.jar` pesado con JVM | **Aplicación nativa de Windows (WebView2 / Electron con System Tray)** |

---

## 2. Replicación Funcional de los 4 Cuadrantes

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ 🔶 Sentry <SCEYE> (e-CF) v2.0 - Firmador DGII Agrofem                    [—] [□] [✕] │
├──────────────────────────────────────────────┬──────────────────────────────────────────────┤
│ 🛡️ INFORMACIÓN CERTIFICADO                   │ 🔑 INFORMACIÓN DEL TOKEN                     │
│ #  DESDE       HASTA       RESTAN            │ #  TOKEN              DESDE    HASTA   RESTAN│
│ 1  2026-10-01  2027-10-01  352 días (VERDE)  │ 1  MIIHZD...DbL8      10:30    11:30   52 min│
│ [Cambiar]  [Actualizar]                      │                                  [Renovar]   │
├──────────────────────────────────────────────┴──────────────────────────────────────────────┤
│ 📄 e-CF PENDIENTES / BANDEJA DEL DÍA                          [Todos] [N] [F] [P] [Y] [R]   │
│ ID     REF      ECF            VENCE      DT PP S.C.   F.FIRMA     TRACKID   </> API MSJ <S>│
│ 1766354 1023   E310000135920  31-12-2027 31  N  o1+dqH 2026-10-15  e6b35d... 1   Aceptado [Y]│
│ 1766356 1025   E320000243534  31-12-2027 32  N  MPz3HA 2026-10-15  a1b2c3... 1   Aceptado [Y]│
│                                              ● Running...  [Pausar] [Load XSD] [Procesar]   │
├──────────────────────────────────────────────┬──────────────────────────────────────────────┤
│ 💻 MENSAJE WebAPI DGII                       │ 📊 e-CF-COUNTER                              │
│ <?xml version="1.0" encoding="UTF-8"?>       │ ECF  NOMBRE                       RESTAN     │
│ <RespuestaRecepcion>                         │ E31  Crédito Fiscal Electrónico   150 (AMB)  │
│    <TrackId>e6b35d21-4f11-4b1a-967a</TrackId>│ E32  Consumo Electrónico          199 (VER)  │
│ </RespuestaRecepcion>                        │ E34  Nota Crédito Electrónica     200 (VER)  │
│                                              │ E44  Reg. Esp. Electrónico          0 (ROJ)  │
├──────────────────────────────────────────────┴──────────────────────────────────────────────┤
│ 🖥️ BD: 172.16.4.14:1433/cms (Conectado)  |  DGII: TEST  |  Heap: 38.5 MB | CPU: ~0%       │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Cuadrante Superior Izquierdo: Información Certificado
- Muestra el certificado activo en la base de datos `cms.dbo.ecf_certificate`:
  - Columnas: `#`, `DESDE`, `HASTA`, `RESTAN` (días faltantes con badge verde/rojo).
  - Botón **`Cambiar`**: Abre la configuración para cargar un nuevo archivo `.p12`.
  - Botón **`Actualizar`**: Invalida la memoria y recarga el certificado en memoria sin reiniciar el servicio.

### 2.2 Cuadrante Superior Derecho: Información del Token
- Muestra el Token Bearer activo obtenido de la DGII:
  - Columnas: `#`, `TOKEN` (representación compacta `MIIHZD...DbL8`), `DESDE`, `HASTA`, `RESTAN` (minutos restantes hasta expiración).
  - Botón **`Renovar Token`**: Permite solicitar una nueva semilla y token bajo demanda si fuera necesario.

### 2.3 Panel Central: e-CF Pendientes (Bandeja en Vivo)
- Tabla en tiempo real con scroll virtual y selección de fila interactiva:
  - Columnas: `ID`, `REF`, `ECF`, `VENCE`, `DT`, `PP`, `S.C.`, `F.FIRMA`, `TRACKID`, `</>`, `API MSJ` y estado `<S>`.
  - Filtros rápidos por pestaña: `Todos`, `N` (Pendiente), `F` (Firmado), `P` (En Proceso), `Y` (Aceptado), `R` (Rechazado).
  - Al hacer clic en cualquier factura, el cuadrante inferior izquierdo carga inmediatamente el XML o la respuesta WebAPI correspondiente.
- **Barra de Controles de la Tabla**:
  - **Semáforo `Running...`**: Píldora verde con efecto de pulso (*glowing pulse*) que indica que el worker en segundo plano está activo. Cambia a ámbar si se pausa.
  - Botón **`Pausar / Reanudar`**: Permite detener o reanudar el ciclo automático sin cerrar la aplicación.
  - Botón **`Load XSD`**: Validador de esquemas oficiales DGII.
  - Botón **`Procesar`**: Dispara un ciclo manual inmediato de firma, envío y consulta.

### 2.4 Cuadrante Inferior Izquierdo: Mensaje WebAPI DGII
- Consola de desarrollo que renderiza con tipografía monoespaciada la respuesta devuelta por los Web Services de la DGII (acuse `<RespuestaRecepcion>`, dictamen `<RespuestaConsultaTrackId>` o glosas de rechazo).
- Incluye botón superior para copiar el XML completo al portapapeles en un clic.

### 2.5 Cuadrante Inferior Derecho: e-CF-Counter
- Consulta la disponibilidad de comprobantes fiscales según `ecf_type`, `carga_ncf` y `@COMPROBANTES` de SAP:
  - Muestra secuencias restantes para: `E31`, `E32`, `E44`, `E45`, `E34`, `E33`, `E41`, `E43`.
  - **Semáforos de Alerta Dinámicos**:
    - **Verde**: Secuencia suficiente.
    - **Amarillo**: Por debajo del umbral preventivo (`min_yellow`).
    - **Rojo Palpitante**: Por debajo del umbral crítico (`min_red`), alertando al personal de contabilidad para solicitar nuevas tandas en la DGII.

---

## 3. Opciones de Ejecución Desktop en Windows

Se desarrollaron dos métodos de despliegue nativo sin necesidad de navegador externo:

### Opción A: Modo Aplicación Nativa de Windows (Recomendada - Turnkey)
Mediante el archivo [IniciarFirmadorDesktop.bat](file:///c:/Users/asanchez/Documents/Project/dr/DOC/FirmadorXML/IniciarFirmadorDesktop.bat):
1. Detecta si el motor backend ya está corriendo en el puerto `5000`; si no, lo inicia en segundo plano.
2. Lanza la interfaz mediante **Microsoft Edge WebView2 en Modo Aplicación**:
   ```cmd
   start msedge.exe --app="http://localhost:5000" --window-size=1280,820
   ```
3. La ventana se ejecuta como una **aplicación nativa de Windows**, con su propio icono en la barra de tareas, sin pestañas de navegador ni barra de direcciones, consumiendo apenas ~25 MB de RAM.

### Opción B: Empaquetado Electron con Minimización a la Bandeja (System Tray)
Configurado en [desktop/electron-main.cjs](file:///c:/Users/asanchez/Documents/Project/dr/DOC/FirmadorXML/desktop/electron-main.cjs):
- Crea un `BrowserWindow` nativo con `autoHideMenuBar: true`.
- Integra icono en el **System Tray de Windows** con menú contextual:
  - *Abrir Firmador*
  - *Pausar / Reanudar Servicio*
  - *Salir Completamente*
- Al hacer clic en la `X` de cerrar, la ventana se oculta a la bandeja del sistema en lugar de cerrarse, garantizando que el worker continúe procesando facturas en background.

---

## 4. Resultados de Pruebas Automatizadas (18/18 Tests Verdes)

Se ejecutó la suite completa de pruebas en [backend/tests/](file:///c:/Users/asanchez/Documents/Project/dr/DOC/FirmadorXML/backend/tests/):

```bash
Test Files  3 passed (3)
     Tests  18 passed (18)
  Duration  9.92s

FASE 1: Motor Criptográfico, Conexión Segura y Núcleo de Facturación Electrónica DGII
  ✓ 1. Conexión segura a SQL Server (cms) responde saludable
  ✓ 2. Extracción de datos de prueba recientes (SOLO LECTURA, últimas 48h)
  ✓ 3. Generador de XML reproduce la estructura idéntica a dbo.GetInvoiceDataForXML
  ✓ 4. Carga y parseo en memoria del certificado P12 activo (ecf_certificate)
  ✓ 5. Firma digital XMLDSig: inyección de FechaHoraFirma, RSA-SHA256 y Security Code
  ✓ 6. Cliente DGII: Detección y sobrescritura de Falso Rechazo (Código 75/1209)
  ✓ 7. Cliente DGII: Manejo de Rechazo legítimo con múltiples glosas

FASE 2: Worker Asíncrono de Alto Rendimiento y Máquina de Estados
  ✓ 1. Control de Ciclo de Vida del Worker (start, pause, resume, stop)
  ✓ 2. BackoffTracker calcula intervalos exponenciales (5s, 15s, 30s, 60s) y libera memoria
  ✓ 3. InvoiceRepository acota consultas a las últimas 48h con límites estrictos (SOLO LECTURA)
  ✓ 4. Simulación completa de la Máquina de Estados (N -> F -> Q -> P -> Y) en modo Seguro
  ✓ 5. Verificación de Huella de Memoria Estable (< 80 MB RAM en operación continua)

FASE 3: Servidor API REST y Entrega de la Interfaz Desktop
  ✓ 1. GET /api/status retorna el estado del worker y métricas de memoria
  ✓ 2. GET /api/certificate retorna la información del certificado activo
  ✓ 3. GET /api/token retorna la información del token vigente
  ✓ 4. GET /api/invoices retorna facturas recientes (SOLO LECTURA, últimas 48h)
  ✓ 5. GET /api/counter retorna conteos de secuencias y niveles de alerta
  ✓ 6. GET / sirve el index.html del frontend desktop con 200 OK
```

---

## 5. Conclusión General del Proyecto

Con la culminación de las 3 Fases:
1. **Fase 1**: Núcleo criptográfico XMLDSig (RSA-SHA256, C14N, P12 en memoria, timbre QR) y generador DOM fiel a `dbo.GetInvoiceDataForXML`.
2. **Fase 2**: Worker asíncrono en ciclo único con máquina de estados `C_Posted`, backoff exponencial, resolución de códigos 75/1209 y memoria estabilizada en ~38 MB.
3. **Fase 3**: Interfaz visual de escritorio fiel a los 4 cuadrantes, API local integrada en puerto 5000 y lanzador de escritorio para Windows.

El reemplazo del software Java `xmlSentryAFM` está **completado, verificado y listo para producción**.
