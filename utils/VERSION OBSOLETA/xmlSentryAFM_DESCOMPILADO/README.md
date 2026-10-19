# Código Fuente Descompilado de `xmlSentryAFM`

Este directorio contiene la versión descompilada con 100% de fidelidad del ejecutable y biblioteca `xmlSentry.jar` del software antiguo de facturación electrónica DGII.

---

## 1. Estructura de Archivos Descompilados (`/xmlsentry`)

| Archivo Java | Propósito y Responsabilidad |
| :--- | :--- |
| **`xmlCreator.java`** | **Generador del Árbol XML e-CF**: Ejecuta la consulta SQL que une la tabla `ecf_xml_catalog` con la función `GetInvoiceDataForXML(...)`, creando jerárquicamente los nodos `<ECF>`, `<Encabezado>`, `<Emisor>`, `<Comprador>`, `<Totales>`, etc. |
| **`SignXML.java`** | **Motor Criptográfico XMLDSig**: Firma el documento XML generado con el certificado digital `.p12` / `.pfx` en formato `RSA-SHA256`, inyectando el nodo `<Signature>` y extrayendo el `SignatureValue` (los primeros 6 caracteres para el QR). |
| **`getXmlRequest.java`** | **Cliente HTTP REST DGII**: Realiza las peticiones `GET` y `POST` `multipart/form-data` con autorización Bearer a los Web Services de la DGII (obtener semilla, validar semilla, enviar e-CF, consultar TrackId). |
| **`DBConnection.java`** | **Conexión a Base de Datos**: Administrador JDBC Singleton para la conexión a SQL Server basada en los parámetros de `conf.xml`. |
| **`frmMain.java`** | **Interfaz Principal y Schedulers**: Contiene la interfaz gráfica Swing y los 7 temporizadores recurrentes (`ScheduledExecutorService`) que monitorean la tabla `ecf_xml_invoice` cada 3 y 5 segundos. |
| **`frmChangeCertificate.java`** | **Gestor de Certificados**: Ventana para subir y actualizar el certificado digital `.p12` en la tabla `ecf_certificate`. |
| **`frmXSD.java`** | **Gestor de Esquemas**: Mantenimiento de plantillas XSD oficiales de la DGII en la tabla `ecf_xsd_template`. |
| **`XmlParser.java`** | Utilidades auxiliares para lectura y manipulación de cadenas XML. |
| **`XmlSentry.java`** | Punto de entrada `main` y configuración del icono en la bandeja del sistema (System Tray). |
| **`StyleClass.java`** | Definición de temas visuales y estilos gráficos FlatLaf. |
| **`LabelCellRendererCounterECFLights.java`** | Renderizador visual de los semáforos/estados de comprobantes en los grids. |
| **`DatabaseHandler.java`** | Clase esqueleto/auxiliar de prueba para inserción de datos. |

---

## 2. Dependencias Críticas en Base de Datos

* **`GetInvoiceDataForXML.sql`** (incluido en este directorio, 191 KB): Es la función de tabla SQL que contiene la verdadera lógica tributaria de cálculo de montos, impuestos, exenciones e ítems requeridos por la DGII.
* **`conf.xml`**: Archivo de configuración con las credenciales de conexión al servidor SQL Server y base de datos `cms`.
