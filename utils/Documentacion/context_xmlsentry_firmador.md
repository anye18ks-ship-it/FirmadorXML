# Contexto Técnico y Especificación de Ingeniería Inversa: Firmador e-CF DGII (`xmlSentryAFM`)

Este documento constituye la **guía técnica maestra** obtenida mediante la ingeniería inversa y descompilación estática del ejecutable compilado `xmlSentryAFM` (`xmlSentry.jar`). Contiene la arquitectura completa, el flujo criptográfico de autenticación y firma, los protocolos de comunicación con la **DGII (Dirección General de Impuestos Internos de República Dominicana)**, la investigación sobre los requisitos y naturaleza de los Web Services, el diagnóstico de fugas de recursos y la especificación para su réplica moderna en **Node.js, Next.js, PostgreSQL y React**.

> **Nota de Seguridad y Auditoría**: Este documento combina la descompilación estática de los binarios Java (`xmlSentry.jar`) con la **inspección directa y autorizada del catálogo de objetos en la base de datos SQL Server (`cms`)**. Se extrajo la definición completa de la función generadora `GetInvoiceDataForXML` (191 KB) y las tablas del esquema `ecf_`, garantizando un conocimiento 100% fidedigno para la recreación del software sin alterar datos transaccionales.

---

## 1. ¿Qué es `xmlSentryAFM` y Cuál es su Función?

**`xmlSentryAFM`** es un servicio desacoplado que actúa como intermediario (middleware) entre el sistema ERP local y los servidores de la DGII para dar cumplimiento a la **Ley 32-23 de Facturación Electrónica** en la República Dominicana.

### Responsabilidades del Sistema:
1. **Detección de Documentos**: Monitorea la bandeja transaccional de facturación electrónica (`ecf_xml_invoice`).
2. **Construcción del XML e-CF**: Genera la estructura XML jerárquica con encabezados, emisor, comprador, detalle de ítems, subtotales, impuestos y totales.
3. **Firma Digital (XMLDSig)**: Aplica una firma digital criptográfica sobre el XML usando el certificado digital comercial del contribuyente (`.p12` / `.pfx`), inyectando el timestamp `<FechaHoraFirma>`.
4. **Validación XSD**: Valida la conformidad estructural del XML contra los esquemas XSD oficiales provistos por la DGII antes de cualquier transmisión.
5. **Autenticación con DGII**: Solicita semillas aleatorias a la DGII, las firma y obtiene Tokens Bearer de sesión temporal.
6. **Transmisión Segura**: Envía los e-CF firmados mediante peticiones HTTP `POST multipart/form-data` con autorización Bearer.
7. **Consulta Asíncrona de Aprobación**: Hace seguimiento del `TrackId` recibido hasta que la DGII emita su dictamen (`Aceptado` o `Rechazado`).
8. **Manejo de Facturas de Consumo (RFCE)**: Para facturas `E32` de consumo menores a RD$ 250,000, genera y transmite el **Resumen de Factura de Consumo Electrónica (RFCE)** de forma compacta.

---

## 2. Investigación: ¿Los Web Services de la DGII son Públicos o se Requiere Autorización?

Uno de los puntos clave al diseñar el nuevo servicio es entender cómo opera la DGII a nivel de acceso de red y seguridad:

### 2.1 ¿Son Públicos los Endpoints?
* **A nivel de red / Internet**: Las URLs y endpoints de la DGII **son públicos y accesibles vía HTTPS** (no requieren VPN privada ni IP fija dedicada).
* **A nivel de autenticación y uso**: **NO son de uso libre ni anónimo**. Aunque cualquier cliente HTTP pueda alcanzar la URL, el servicio exige **autenticación criptográfica obligatoria basada en certificados digitales validados contra el Registro Nacional de Contribuyentes (RNC)**.
* **No se puede consumir el Web Service sin autorización tributaria previa**: Si intentas solicitar un token con un certificado digital que no está autorizado y vinculado al RNC en la Oficina Virtual (OFV), la DGII rechazará inmediatamente la validación de la semilla.

### 2.2 Requisitos Obligatorios para Poder Conectarse a la DGII
Para que una empresa (emisor) pueda comunicarse efectivamente con estos Web Services bajo la Ley 32-23 y el Decreto 587-24, debe completar el siguiente proceso administrativo y técnico:

1. **RNC Activo y al Día**: Contar con obligaciones tributarias activas y no tener bloqueos en DGII.
2. **Alta de Comprobantes Fiscales**: Tener habilitada la emisión de comprobantes en la Oficina Virtual (OFV).
3. **Certificado Digital de Procedimientos Tributarios**:
   - Debe ser un certificado cualificado emitido por una Prestadora de Servicios de Confianza autorizada por el **INDOTEL** en República Dominicana (ej. *Avansi, VíaFirma, DigiFirma BHD, Certicámara*).
   - Formato estándar de archivo: `PKCS#12` (`.p12` o `.pfx`) que contiene la llave privada y la cadena de confianza pública (X.509).
4. **Solicitud de Postulación como Emisor Electrónico**:
   - Se tramita en la Oficina Virtual de la DGII mediante el **Formulario FI-GDF-016**.
   - Se carga el certificado digital para que la DGII registre la clave pública vinculada a ese RNC.
5. **Aprobación del Set de Pruebas (Ambiente de Certificación)**:
   - La DGII otorga credenciales para el portal de pruebas y el contribuyente debe emitir exitosamente un set de pruebas exigido (facturas con diferentes tipos de impuestos, notas de crédito, notas de débito, resúmenes RFCE y simulaciones de rechazo).
6. **Resolución de Autorización y Pase a Producción**:
   - Al aprobar el set de pruebas, la DGII emite la resolución formal de **Emisor Electrónico Autorizado** y habilita el RNC en el ambiente de producción oficial.

### 2.3 Ambientes Oficiales y URLs de la DGII

La DGII dispone de tres ambientes con la misma estructura de rutas pero diferentes dominios base:

| Ambiente | Dominio Base | Propósito |
| :--- | :--- | :--- |
| **Pruebas / Sandbox (Test)** | `https://testecf.dgii.gov.do/testfe/` | Desarrollo inicial, pruebas de integración de software y ensayos libres. |
| **Certificación Oficial** | `https://certifecf.dgii.gov.do/certecf/` | Ejecución del set de pruebas formal supervisado por técnicos de la DGII. |
| **Producción** | `https://ecf.dgii.gov.do/fe/` | Operación real de la empresa con validez fiscal tributaria. |

#### Catálogo de Endpoints de la DGII:
- **Obtener Semilla (Seed)**: `GET {BASE_URL}autenticacion/api/semilla`
- **Validar Semilla y Obtener Token**: `POST {BASE_URL}autenticacion/api/validarsemilla` (Multipart/form-data con archivo `Sem.xml`)
- **Recepción de Facturas e-CF**: `POST {BASE_URL}recepcion/api/ecf` (Header `Authorization: Bearer {token}`, Multipart con `{nombre_archivo}.xml`)
- **Consulta de Estatus por TrackId**: `GET {BASE_URL}consultaresultado/api/consultatrackid?trackid={uuid}`
- **Recepción de Resumen RFCE (Consumo < 250k)**: `POST {BASE_URL}recepcion/api/rfce`
- **Consulta de Estatus de RFCE**: `GET {BASE_URL}consultaresultado/api/consultarfce?rncemisor={rnc}&encf={encf}&codigoseguridad={secCode}`
- **Consulta Timbre Fiscal (QR)**: `https://ecf.dgii.gov.do/consultatimbrefiscal?RncEmisor={...}&RncComprador={...}&ENCF={...}&FechaEmision={...}&MontoTotal={...}&FechaFirma={...}&CodigoSeguridad={...}`

---

### 2.4 Rol del Desarrollador vs. Rol del Cliente (Empresa Contribuyente)

> **Principio Fundamental de Arquitectura:**
> Como **desarrollador de software**, tú **NO necesitas registrarte ante la DGII como emisor electrónico a tu nombre personal, ni comprar certificados digitales, ni solicitar NCFs**.
> 
> La obligación tributaria y legal (Ley 32-23) recae exclusivamente sobre el **Contribuyente (el Cliente / la Empresa que factura)**.

#### Separación de Responsabilidades:

| Responsabilidad | ¿Quién la Asume? | Detalle Operativo |
| :--- | :---: | :--- |
| **Comprar Certificado Digital (.p12)** | **El Cliente** | Lo contrata a su nombre o razón social en *Avansi, VíaFirma o DigiFirma* con su propio RNC. |
| **Solicitar Autorización en DGII (OFV)** | **El Cliente** | Llena el formulario FI-GDF-016 en la Oficina Virtual de la DGII y registra su certificado. |
| **Comprar / Solicitar Secuencias e-NCF** | **El Cliente** | Solicita las tandas de comprobantes fiscales electrónicos (`E31`, `E32`, etc.) en la DGII. |
| **Desarrollo del Software y Firmador** | **El Desarrollador** | Construye el ERP, el algoritmo de firma XMLDSig y la integración con la API de la DGII. |
| **Carga de Credenciales (Plug & Play)** | **El Sistema** | Provee una interfaz para que el cliente cargue su `.p12`, su contraseña y su RNC. |

---

## 3. Arquitectura Interna en Base de Datos: El Verdadero Motor del e-CF

La descompilación de `xmlSentry.jar` reveló un descubrimiento de vital importancia: **Java NO contiene la lógica de negocio ni el mapeo de campos de la DGII**. Java actúa únicamente como un "consumidor ciego".

La totalidad de las reglas tributarias de la DGII, los cálculos de ITBIS, exenciones, subtotales, encabezados y detalles residen en una **función de tabla en SQL Server de 191 KB** denominada **`[dbo].[GetInvoiceDataForXML]`**, complementada por un diccionario relacional de tags en la tabla **`ecf_xml_catalog`**.

### 3.1 La Consulta Puente Ejecutada por el Firmador (`xmlCreator.java`)

En `xmlCreator.java`, el método `getXMLFromDB()` ejecuta la siguiente consulta SQL unificada contra la base de datos `cms`:

```sql
SELECT x.id_record,
       (SELECT TOP 1 tag_parent_name 
          FROM cms.dbo.ecf_xml_catalog 
         WHERE tag_name = y.tag_parent_name AND catalog_type = y.catalog_type) AS grand_parent,
       y.tag_parent_name AS parent,
       x.tag_parent_id,
       x.tag_parent_name,
       x.tag_type_id,
       x.tag_type_name,
       x.tag_number,
       x.tag_name,
       x.tag_to_remove,
       m.xmlTag,
       m.id_record,
       CASE WHEN m.xmlTag = 'eCF' THEN NULL ELSE m.xml_value END AS xml_value
  FROM cms.dbo.ecf_xml_catalog x
  LEFT JOIN cms.dbo.ecf_xml_catalog y 
         ON (y.tag_name = x.tag_parent_name AND y.tag_group_id = x.tag_group_id AND y.catalog_type = x.catalog_type)
  LEFT JOIN cms.dbo.GetInvoiceDataForXML(@InvoiceID, @eCFType, @Resumen, @pSecurityCode, @pPrintPages) m 
         ON (m.xmlTag = x.tag_name AND m.group_id = x.tag_group_id)
 WHERE x.active = 'Y'
   AND COALESCE(m.id_record, 0) > 0
   AND COALESCE(NULLIF(m.xml_value, '#e'), '') != ''
   AND x.catalog_type = @CatalogType
 ORDER BY m.id_record;
```

### 3.2 La Función Maestra: `dbo.GetInvoiceDataForXML` (191,494 bytes)

Esta función es el **núcleo fiscal de todo el sistema de facturación electrónica**. Sus parámetros de entrada son:
* `@InvoiceID` (INT): Identificador de la factura en el ERP (`doc_id` / `C_DocEntry` en `POSOINV` o `POSORIN`).
* `@eCFType` (NVARCHAR(20)): Tipo de comprobante fiscal (`'31'`, `'32'`, `'34'`, `'44'`, `'45'`, etc.).
* `@Resumen` (INT): `0` para el e-CF estándar completo; `1` para el Resumen de Facturas de Consumo (RFCE).
* `@pSecurityCode` (NVARCHAR(50)): Los primeros 6 caracteres de la firma digital (`SignatureValue`), inyectados para el timbre fiscal QR.
* `@pPrintPages` (NVARCHAR(1)): Flag de paginación (`'Y'` / `'N'`).

**Estructura y Mapeo que Realiza la Función:**
1. **Encabezado (`group_id = 1`)**:
   - `Version`: `'1.0'`
   - `IdDoc`: `TipoeCF`, `eNCF`, `FechaVencimientoSecuencia`, `IndicadorNotaCredito`, `IndicadorEnvioDiferido`, `IndicadorMontoGravado`, `TipoIngresos`, `FechaEmision`.
   - `Emisor`: `RNCEmisor`, `RazonSocialEmisor`, `NombreComercial`, `Sucursal`, `DireccionEmisor`, `Municipio`, `Provincia`, `TelefonoEmisor`, `CorreoEmisor`, `FechaInicioOperaciones`.
   - `Comprador`: `RNCComprador`, `IdentificadorExtranjero`, `RazonSocialComprador`, `DireccionComprador`, `MunicipioComprador`, `ProvinciaComprador`, `CorreoComprador`.
   - `Totales`: `MontoGravadoTotal`, `MontoGravadoI1` (18%), `MontoGravadoI2` (16%), `MontoGravadoI3` (0%), `MontoExento`, `TotalITBIS`, `TotalITBIS1`, `MontoTotal`.
2. **Detalles de Líneas de Ítems (`group_id = 2`)**:
   - Itera sobre las líneas de la factura (`POSINV1` / `POSRIN1`).
   - Mapea: `NumeroLinea`, `TablaCodigosItem` (`CodigoItem`), `IndicadorFacturacion` (1: Gravado 18%, 2: Gravado 16%, 3: Exento), `NombreItem`, `IndicadorBienoServicio` (1: Bien, 2: Servicio), `CantidadItem`, `UnidadMedida`, `PrecioUnitarioItem`, `DescuentoMonto`, `MontoItem`.
3. **Subtotales y Retenciones (`group_id = 3` a `6`)**:
   - Si existen retenciones de ITBIS o ISR del Estado o ARS, genera la tabla `<Subtotales>` y `<Retenciones>`.
4. **Información de Referencia (Notas de Crédito `E34` / Débito `E33`)**:
   - Mapea el comprobante modificado `<NCFModificado>`, la `<FechaNCFModificado>` y el `<CodigoModificacion>` (1: Anula, 2: Corrige texto, 3: Corrige montos).
5. **Timbre Fiscal QR (`group_id = 9`)**:
   - Construye la URL oficial del timbre QR con los parámetros validados por la DGII.

### 3.3 Catálogo Completo de Tablas en la Base de Datos (`cms`)

El ecosistema de `xmlSentryAFM` en SQL Server está conformado por 15 tablas maestras y transaccionales:

| Tabla | Tipo | Propósito |
| :--- | :---: | :--- |
| **`ecf_xml_catalog`** | Catálogo | Estructura jerárquica del XML oficial DGII (`Root`, `Container`, `Item`), tags padres y grupos. |
| **`ecf_xml_invoice`** | Transaccional | Bandeja de procesamiento de facturas, cola de salida y máquina de estados (`C_Posted`). |
| **`ecf_certificate`** | Seguridad | Almacena el certificado digital comercial en binario (`cert_file` en `VARBINARY(MAX)`), contraseña (`cert_key`) y vigencia. |
| **`ecf_xml_token`** | Seguridad | Almacena las semillas recibidas, semillas firmadas y el Token Bearer activo con su fecha de expiración (`token_valid_to`). |
| **`ecf_global_config`** | Configuración | Parámetros del firmador: `API` (`testfe`/`fe`), `TokenRefreshBeforeExpire`, `TokenRequestMaxAttempts`. |
| **`ecf_url_api`** | Integración | URLs de los servicios REST de la DGII (Semilla, Validación, Recepción e-CF, Consulta TrackId, RFCE, Timbre QR). |
| **`ecf_xsd_template`** | Validación | Almacena las plantillas XSD oficiales de la DGII (`VARBINARY`/`TEXT`) para validación de esquemas previa a la firma. |
| **`ecf_type`** | Maestro | Catálogo de tipos de e-CF (`E31` Factura Crédito Fiscal, `E32` Consumo, `E34` Nota Crédito, etc.) y límites de alerta. |
| **`ecf_payment_forms`** | Catálogo | Mapeo de formas de pago DGII (1: Efectivo, 2: Cheque/Transferencia, 3: Tarjeta Débito/Crédito, 4: Venta a Crédito). |
| **`ecf_tax_config`** | Configuración | Configuración de tasas de impuestos (ITBIS 18%, 16%, exento). |
| **`ecf_units`** | Catálogo | Unidades de medida estandarizadas por la DGII (UND, SER, etc.). |
| **`ecf_emisor2`** | Configuración | Datos fiscales del emisor (RNC, Razón Social, Dirección, Sucursales). |
| **`ecf_url_chars`** | Utilidad | Caracteres de escape y reemplazo en URLs. |
| **`ecf_bad`** | Auditoría | Registro de facturas con errores de estructura o caídas de procesamiento. |

---

## 4. Flujo Criptográfico y Operativo Paso a Paso

El siguiente diagrama detalla la interacción paso a paso entre el ERP, el firmador y los servidores de la DGII:

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│                                CICLO DE EMISIÓN DE FACTURA e-CF                              │
└──────────────────────────────────────────────────────────────────────────────────────────────┘

1. ERP emite factura  ──> Guarda en tabla 'ecf_xml_invoice' con C_Posted = 'N'
2. Firmador lee 'N'   ──> Construye XML jerárquico según catálogo de tags
3. Inyección Fecha    ──> Inserta nodo <FechaHoraFirma>dd-MM-yyyy HH:mm:ss</FechaHoraFirma>
4. Firma Digital      ──> XMLDSig RSA-SHA256 con Certificado P12 (Almacena en C_Posted = 'F')
5. Código Seguridad   ──> Extrae primeros 6 caracteres de <SignatureValue> para QR Code

┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│                              AUTENTICACIÓN CON DGII (HANDSHAKE)                              │
└──────────────────────────────────────────────────────────────────────────────────────────────┘

6. Solicitar Semilla  ──> GET /autenticacion/api/semilla
7. DGII entrega XML   ──> Recibe XML con <Semilla> y fecha de generación
8. Firma de Semilla   ──> Firma digital de la Semilla con el Certificado P12
9. Enviar Semilla     ──> POST /autenticacion/api/validarsemilla (archivo 'Sem.xml')
10. Token de Sesión   ──> DGII valida firma y entrega XML con <token>, <expedido> y <expira>
                          (Token Bearer con validez de aprox. 1 hora)

┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│                              TRANSMISIÓN Y RECEPCIÓN DE LA FACTURA                           │
└──────────────────────────────────────────────────────────────────────────────────────────────┘

11. Bloqueo In-Flight ──> Marca C_Posted = 'Q' (Quantum) para evitar duplicidad de envíos
12. Envío de e-CF     ──> POST /recepcion/api/ecf
                          Headers:
                            - Authorization: Bearer {token}
                            - Content-Type: multipart/form-data; boundary=----WebKit...
                          Body:
                            - name="xml", filename="{eNCF}.xml"
13. Acuse de Recibo   ──> DGII devuelve XML <RespuestaRecepcion> con <TrackId>
                          (UUID único de seguimiento)
14. Guarda TrackId    ──> Actualiza C_Posted = 'P' (En Proceso)

┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│                              CONSULTA ASÍNCRONA DEL ESTADO                                   │
└──────────────────────────────────────────────────────────────────────────────────────────────┘

15. Polling Estatus   ──> GET /consultaresultado/api/consultatrackid?trackid={TrackId}
                          Header: Authorization: Bearer {token}
16. Dictamen Final    ──> DGII responde <RespuestaConsultaTrackId>:
                          - Si <Estado> == 'Aceptado' (Código 1)  ──> C_Posted = 'Y' (ÉXITO)
                          - Si <Estado> == 'Rechazado' (Código 2) ──> C_Posted = 'R' (RECHAZADO con glosas)
                          - Si <Estado> == 'En Proceso' (Código 3)──> Mantiene C_Posted = 'P' (reintentar)
```

---

## 4. Diagnóstico Detallado del Problema de Rendimiento y Memoria en `xmlSentryAFM`

El análisis estático del código Java descompilado reveló las causas exactas por las cuales el sistema actual abre hilos indiscriminadamente hasta congelar o saturar la memoria RAM del servidor:

### 4.1 Fuga Descontrolada de Hilos (`ScheduledExecutorService` Leak)
En `frmMain.java` se descubrieron **7 schedulers concurrentes** programados con intervalos agresivos:
- `startTokenRefreshTask()`: Corre cada 1 minuto.
- `startTokenGridRefreshTask()`: Corre cada 1 minuto.
- `startUpdateStatusECFRefreshTask()`: Corre cada **3 segundos**.
- `SignECFTask()`: Corre cada **3 segundos**.
- `UploadECFTask()`: Corre cada **5 segundos**.
- `startECFRefreshTask()`: Corre cada **5 segundos**.
- `startCounterECFRefreshTask()`: Corre cada 1 minuto.

**La Fuga:**
Cada uno de estos métodos instancia su temporizador en una variable local sin guardar la referencia en la clase y sin llamar nunca a `shutdown()`:
```java
public void SignECFTask() {
    ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
    scheduler.scheduleAtFixedRate(() -> { ... }, 0L, 3L, TimeUnit.SECONDS);
}
```
**El Desencadenante Fatal:**
En `XmlSentry.java`, la acción del menú del System Tray ejecuta:
```java
action.addActionListener(e -> {
    frmMain jrmTrayTest = new frmMain(); // ¡Instancia una nueva ventana completa!
    jrmTrayTest.setVisible(true);
});
```
Cada vez que el usuario abre la pantalla de configuración desde la barra de tareas o la ventana se recarga, **se vuelven a instanciar los 7 schedulers**. Al cabo de varias semanas, el proceso de Java mantiene cientos de hilos concurrentes activos en background, compitiendo por CPU, bloqueando la base de datos y agotando la memoria Heap de Java.

### 4.2 Colisión en Conexión JDBC (Race Condition)
- `DBConnection.java` implementa un Singleton rudimentario que entrega una única instancia de `java.sql.Connection` compartida entre todos los hilos.
- Múltiples hilos concurrentes intentan ejecutar sentencias SQL cada 3 y 5 segundos sobre el mismo socket de red. En SQL Server JDBC, esto genera contención interna de bloqueos (`Deadlocks` de conexión), buffers no liberados y degradación masiva.

### 4.3 Carga Reiterada de Certificados P12 en Cada Iteración
- En lugar de mantener el certificado digital en memoria, en cada ciclo de 3 segundos el código descarga el archivo binario completo desde la tabla `ecf_certificate` (`cert_file` en formato `byte[]`) y reconstruye el objeto `KeyStore.getInstance("PKCS12")` una y otra vez para cada factura individual, generando una presión inmanejable sobre el Garbage Collector.

---

## 5. Máquina de Estados del Documento en Base de Datos (`C_Posted`)

La columna `C_Posted` en la tabla **`ecf_xml_invoice`** actúa como la máquina de estados determinista de cada comprobante fiscal:

| Estado | Nombre Operativo | Descripción y Transición |
| :---: | :--- | :--- |
| **`'N'`** | **Nuevo (Pending)** | Factura recién creada por el ERP. En espera de generación de XML y firma. |
| **`'F'`** | **Firmado Localmente** | XML generado, firmado con XMLDSig y validado contra el esquema XSD. Listo para enviar. |
| **`'Q'`** | **Quantum (En Vuelo)** | Bloqueo atómico transitorio durante la llamada HTTP a DGII para evitar duplicidad de envíos. Si la conexión falla, hace rollback automático a `'F'`. |
| **`'P'`** | **En Proceso en DGII** | DGII aceptó la recepción del XML y devolvió un `TrackId`. Esperando resolución en consulta periódica. |
| **`'Y'`** | **Aceptado / Aprobado** | Factura fiscal aprobada oficialmente por DGII (Código de respuesta 1). Estado final exitoso. |
| **`'R'`** | **Rechazado** | Factura rechazada por DGII (Código 2). Se guardan las glosas de error en `xml_track_response`. |
| **`'S'`** | **Error de WebService** | Fallo temporal de red (-99 WebServiceError / -98 Page Not Found). Programada para reintento. |
| **`'D'`** | **No Encontrado** | DGII devolvió código 0 (documento aún no indexado en sus servidores). |
| **`'E'`** | **Error de Integridad** | Falló la validación del esquema XSD interno antes de enviar. |

---

## 6. Reglas de Negocio Críticas Detectadas en el Código

1. **Sobrescritura de Falsos Rechazos (Códigos DGII 75 y 1209)**:
   Si DGII devuelve estado **Rechazado** con código `75` o `1209` (*"Este número de secuencia ya ha sido utilizado"*), pero el parámetro retornado `SecuenciaUtilizada == "false"`, el firmador reconoce que el e-CF fue procesado con éxito en un intento previo donde se interrumpió la respuesta de red. **El sistema fuerza automáticamente el estado a `Aceptado` (Código 1, `C_Posted = 'Y'`)**.
2. **Extracción del Código de Seguridad para el Código QR**:
   El código de seguridad impreso en la factura y enviado en el enlace del QR (`vSecurityCode`) **corresponde a los primeros 6 caracteres del nodo `<SignatureValue>`** de la firma digital XMLDSig.
3. **Resumen de Facturas de Consumo (RFCE)**:
   Para comprobantes `E32` con montos menores a RD$ 250,000, la DGII no exige el e-CF completo inmediato en su consulta unitaria; se genera adicionalmente un archivo compacto `RFCE` (`vCatalogType = "RFCE"`), firmado independientemente y consultado a través del endpoint `/consultarfce`.

---

## 7. Especificación para Replicar el Servicio en Node.js / Next.js / PostgreSQL

Para el nuevo ERP, este módulo debe implementarse como un **microservicio o worker en segundo plano desacoplado y ultra-eficiente**.

### 7.1 Stack Tecnológico Recomendado
* **Runtime**: Node.js (v20+ LTS) con TypeScript.
* **Base de Datos**: PostgreSQL con pool de conexiones administrado (`pg.Pool` con límite de 10-20 conexiones).
* **Gestor de Colas (Job Worker)**: `BullMQ` (con Redis) o `pg-boss` (basado en tablas nativas de PostgreSQL sin Redis).
* **Firma Digital XMLDSig**:
  - `@xmldsig/client` o biblioteca combinada `node-forge` + `xml-crypto`.
  - Debe soportar:
    - Algoritmo de firma: `http://www.w3.org/2001/04/xmldsig-more#rsa-sha256`
    - Método de Digest: `http://www.w3.org/2001/04/xmlenc#sha256`
    - Método de Canonicalización: `http://www.w3.org/TR/2001/REC-xml-c14n-20010315` (C14N)
    - Transformación: `http://www.w3.org/2000/09/xmldsig#enveloped-signature`
* **Parser y DOM**: `@xmldom/xmldom` o `fast-xml-parser`.
* **Validación XSD**: `libxmljs2` (binding C++ de alto rendimiento).
* **Cliente HTTP**: `undici` o `axios` configurado con streaming multipart para evitar retención de strings en memoria.

### 7.2 Arquitectura del Worker (Solución a las Fugas de Memoria)
1. **Event-Driven en lugar de Polling Ciego**:
   - En lugar de 7 timers consultando la BD cada 3 segundos, cuando el backend del ERP registra una factura emite un evento/job a la cola:
     ```typescript
     await invoiceQueue.add('sign-and-send', { invoiceId: docId });
     ```
2. **Caché en Memoria del Certificado y Token**:
   - El certificado digital `.p12` se descifra **una sola vez** al arrancar el servicio y se mantiene en memoria privada.
   - El Token Bearer de la DGII se almacena en memoria con un temporizador único programado para renovarse automáticamente 5 minutos antes de su vencimiento (`expira - 5 min`).
3. **Reintentos con Backoff Exponencial**:
   - Las consultas de `TrackId` se encolan con retrasos progresivos (5s, 15s, 30s, 60s), eliminando el bombardeo continuo a los servidores de la DGII y liberando el CPU del servidor.
4. **Liberación Inmediata de Memoria (Zero-Leak)**:
   - Todo el procesamiento de buffers y XML se ejecuta dentro del alcance de funciones asíncronas limpias, permitiendo que el motor V8 de Node.js recolecte la memoria de inmediato.

---

### 8. Esquema de Variables de Entorno para el Nuevo Servicio (`.env`)

```env
# Entorno DGII (test | cert | prod)
DGII_ENV=test
DGII_RNC_EMISOR=131XXXXXX

# URLs Oficiales DGII
DGII_TEST_URL=https://testecf.dgii.gov.do/testfe/
DGII_CERT_URL=https://certifecf.dgii.gov.do/certecf/
DGII_PROD_URL=https://ecf.dgii.gov.do/fe/

# Certificado Digital
CERT_P12_PATH=./certs/certificado_tributario.p12
CERT_PASSWORD=TuPasswordSeguro123

# Base de Datos PostgreSQL
DATABASE_URL=postgresql://usuario:password@localhost:5432/erp_clinica?sslmode=disable
```
