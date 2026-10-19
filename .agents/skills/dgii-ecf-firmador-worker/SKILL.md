---
name: dgii-ecf-firmador-worker
description: Arquitectura, protocolos criptográficos (XMLDSig RSA-SHA256), comunicación con DGII (e-CF), manejo de tokens, estados C_Posted y worker de colas en Node.js/TypeScript sin fugas de memoria para el nuevo ERP.
---

# Microservicio Firmador de Facturación Electrónica DGII (e-CF)

Esta skill define la implementación del microservicio / worker en segundo plano encargado de la firma criptográfica y la transmisión de Comprobantes Fiscales Electrónicos (e-CF) hacia los servidores de la **DGII (República Dominicana)** bajo la Ley 32-23.

---

## 1. Arquitectura del Worker (Zero-Leak en Node.js)

A diferencia de implementaciones legadas con fugas de memoria por schedulers infinitos, el nuevo ERP utiliza una arquitectura **Event-Driven basada en colas**:

```
[ Facturación ERP ] ──(inserta factura)──> [ Job Queue (BullMQ / pg-boss) ]
                                                        │
                                                        ▼
                                          [ Worker: dgii-firmador ]
                                          1. Construye XML (DOM)
                                          2. Inyecta <FechaHoraFirma>
                                          3. Firma con Certificado P12 (XMLDSig)
                                          4. Obtiene Token Bearer (si expiró)
                                          5. Envía a DGII (POST multipart)
                                          6. Almacena TrackId y programa consulta
```

* **Caché en Memoria**: El certificado digital `.p12` se descifra y mantiene en memoria segura, evitando releer el archivo binario de la base de datos en cada comprobante.
* **Gestión Eficiente del Token**: El Token Bearer de la DGII dura ~1 hora; se almacena en memoria y se renueva automáticamente 5 minutos antes de su vencimiento (`expira - 5 min`).
* **Liberación V8**: Los streams y buffers XML se manejan en el scope local de cada job para ser recolectados inmediatamente por el Garbage Collector.

---

## 2. Protocolo Criptográfico de Firma (XMLDSig)

El firmado de facturas y de semillas de autenticación debe cumplir estrictamente con los estándares oficiales de la DGII:

* **Formato de Certificado**: `PKCS#12` (`.p12` / `.pfx`) con clave privada y cadena X.509.
* **Algoritmo de Firma**: `http://www.w3.org/2001/04/xmldsig-more#rsa-sha256` (RSA-SHA256).
* **Método de Digest**: `http://www.w3.org/2001/04/xmlenc#sha256` (SHA-256).
* **Método de Canonicalización**: `http://www.w3.org/TR/2001/REC-xml-c14n-20010315` (C14N).
* **Tipo de Transformación**: `http://www.w3.org/2000/09/xmldsig#enveloped-signature` (Firma Envuelta).
* **Timestamp Obligatorio**: Inyectar como último nodo hijo de `<ECF>` antes de firmar:
  ```xml
  <FechaHoraFirma>dd-MM-yyyy HH:mm:ss</FechaHoraFirma>
  ```
* **Extracción de Código de Seguridad**:
  El valor de `xml_security_code` (impreso en la factura física y en el Código QR) son **los primeros 6 caracteres** del texto dentro del nodo `<SignatureValue>`:
  ```typescript
  const securityCode = signatureValue.trim().substring(0, 6);
  ```

---

## 3. Ciclo de Autenticación con la DGII (Handshake de Semilla)

```
1. GET  {BASE_URL}/autenticacion/api/semilla 
   ──> Retorna XML con <Semilla>
2. Firma Digital de la Semilla con el Certificado P12 (mismo estándar XMLDSig)
3. POST {BASE_URL}/autenticacion/api/validarsemilla
   ──> Headers: Content-Type: multipart/form-data; boundary=...
   ──> Body: name="xml", filename="Sem.xml", content={semillaFirmadaXML}
4. DGII valida la firma contra el RNC autorizado
   ──> Retorna XML <RespuestaAutenticacion>:
       - <token>: Bearer Token (string JWT/hash)
       - <expedido>: Fecha UTC
       - <expira>: Fecha UTC (~60 min de vigencia)
```

---

## 4. Transmisión del e-CF y Consulta de Estatus

### 4.1 Envío del Comprobante
* **Endpoint**: `POST {BASE_URL}/recepcion/api/ecf` (o `/rfce` si es resumen de consumo < 250k).
* **Headers**:
  - `Authorization: Bearer {token}`
  - `Accept: application/xml`
  - `Content-Type: multipart/form-data; boundary=...`
* **Form-Data**:
  - `name="xml"`, `filename="{eNCF}.xml"`, content={xmlFirmado}
* **Respuesta Inmediata**:
  - XML `<RespuestaRecepcion>` con `<TrackId>` (UUID de rastreo).

### 4.2 Consulta Asíncrona por TrackId
* **Endpoint**: `GET {BASE_URL}/consultaresultado/api/consultatrackid?trackid={TrackId}`
* **Headers**: `Authorization: Bearer {token}`, `Accept: application/xml`
* **Respuesta**: `<RespuestaConsultaTrackId>` con:
  - `<Codigo>`: `1` = Aceptado, `2` = Rechazado, `3` = En Proceso, `0` = No encontrado.
  - `<Estado>`: 'Aceptado', 'Rechazado', 'En Proceso'.
  - `<SecuenciaUtilizada>`: 'true' / 'false'.
  - `<Mensajes><Mensaje><Codigo/><Valor/></Mensajes>`.

---

## 5. Máquina de Estados del Documento (`C_Posted`)

| Estado | Nombre Operativo | Descripción y Transición |
| :---: | :--- | :--- |
| **`'N'`** | **Nuevo (Pending)** | Factura creada por el ERP. Esperando procesamiento por el worker. |
| **`'F'`** | **Firmado Localmente** | XML firmado digitalmente y validado contra el XSD. Listo para subir. |
| **`'Q'`** | **Quantum (En Vuelo)** | Bloqueo atómico transitorio durante la llamada HTTP. Previene duplicados. |
| **`'P'`** | **En Proceso en DGII** | DGII entregó el `TrackId`. Esperando aprobación en la consulta periódica. |
| **`'Y'`** | **Aceptado / Aprobado** | Factura fiscal aprobada con éxito por la DGII (Código 1). Estado final. |
| **`'R'`** | **Rechazado** | Factura rechazada por la DGII (Código 2) con glosas registradas. |
| **`'S'`** | **Error de WebService** | Fallo temporal de red (-99/-98). Programada para reintento con backoff. |
| **`'E'`** | **Error de Integridad** | Falló la validación del esquema XSD interno antes de enviar. |

---

## 6. Reglas de Negocio Críticas y Casos Especiales

1. **Sobrescritura de Falsos Rechazos (Códigos DGII 75 y 1209)**:
   Si la DGII responde *"Rechazado"* con código `75` o `1209` (*"Este número de secuencia ya ha sido utilizado"*), pero el parámetro retornado `SecuenciaUtilizada == "false"`, significa que la DGII ya la había procesado exitosamente en un intento anterior donde se interrumpió la red. **El worker debe forzar el estado a `Aceptado` (Código 1, `C_Posted = 'Y'`)**.
2. **Facturas de Consumo (E32) < RD$ 250,000**:
   Se genera y envía adicionalmente el archivo compacto **RFCE** (`vCatalogType = "RFCE"`), firmado independientemente y consultado a través del endpoint `/consultarfce`.
3. **Generación de URL para Código QR**:
   ```
   https://ecf.dgii.gov.do/consultatimbrefiscal?RncEmisor={rnc}&RncComprador={rnc}&ENCF={encf}&FechaEmision={fecha}&MontoTotal={total}&FechaFirma={fechaFirma}&CodigoSeguridad={securityCode}
   ```
4. **Módulo de Carga Agnóstica de Certificados (Plug & Play)**:
   El backend provee un endpoint para que el cliente cargue su archivo `.p12` (sin importar el nombre del archivo) junto con la contraseña. El backend valida el certificado en memoria abriendo el almacén `PKCS#12`, extrae vigencia y RNC, y lo guarda cifrado en reposo para su uso por el worker.
