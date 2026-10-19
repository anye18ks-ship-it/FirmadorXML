---
name: dgii-fiscal-ncf
description: Gestión integral de Comprobantes Fiscales de República Dominicana (NCF y e-CF) para el nuevo ERP. Carga y aprovisionamiento autónomo de secuencias por el cliente, algoritmo de asignación atómica thread-safe en PostgreSQL, semáforos de disponibilidad y validaciones RNC/Cédula en TypeScript.
---

# Gestión Fiscal de Comprobantes (NCF y e-CF)

Esta skill define la gestión de Comprobantes Fiscales de la **DGII (República Dominicana)** bajo la Ley 32-23 de Facturación Electrónica y la normativa de NCF tradicionales, adaptada a la arquitectura del nuevo ERP en **Node.js, TypeScript y PostgreSQL**.

---

## 1. Estructura y Tipos de Comprobantes Fiscales

### 1.1 Comprobantes Fiscales Electrónicos (e-CF - Longitud: 13 caracteres)
Inician con la letra `E` + 2 dígitos de tipo + 10 dígitos correlativos (ej: `E310000000001`):

| Prefijo | Tipo de e-CF | Aplicación Operativa |
| :--- | :--- | :--- |
| **E31** | Factura de Crédito Fiscal | Ventas con valor fiscal a empresas/profesionales (requiere RNC válido). Lotes ARS. |
| **E32** | Factura de Consumo | Ventas a consumidor final (pacientes particulares). |
| **E33** | Nota de Débito | Intereses de mora, penalidades o aumento de precio sobre un e-CF previo. |
| **E34** | Nota de Crédito | Anulaciones, descuentos posteriores o devoluciones sobre un e-CF previo. |
| **E44** | Regímenes Especiales | Ventas exentas a Zonas Francas, misiones diplomáticas, etc. |
| **E45** | Gubernamental | Facturación a entidades del Estado Dominicano (RNC gubernamental). |

> **Formateo TypeScript**:
> ```typescript
> export function formatECF(prefix: string, sequence: number): string {
>   return `${prefix.toUpperCase()}${sequence.toString().padStart(10, '0')}`;
>   // Retorna: E310000000042
> }
> ```

### 1.2 Comprobantes Tradicionales Serie B (Longitud: 11 caracteres)
Inician con la letra `B` + 2 dígitos de tipo + 8 dígitos correlativos:
- `B01`: Crédito Fiscal | `B02`: Consumo Final | `B03`: Nota de Débito | `B04`: Nota de Crédito | `B14`: Regímenes Especiales | `B15`: Gubernamental.

---

## 2. Aprovisionamiento Autónomo de NCF por el Cliente (Self-Service)

Bajo la filosofía **Zero-Contact**, el cliente (la clínica o consultorio) no depende del equipo de desarrollo para habilitar o renovar sus NCF. El ERP provee una interfaz para cargar sus secuencias autorizadas por la DGII:

### 2.1 Métodos de Carga
1. **Importación de Archivo DGII (TXT / CSV / XML)**:
   - El cliente descarga desde la Oficina Virtual de la DGII el archivo de autorización de secuencias.
   - El sistema es agnóstico al nombre del archivo; lee la estructura de columnas o tags:
     - `Tipo de Comprobante` (ej: `E31`, `E32`)
     - `Secuencia Desde` (ej: `1`)
     - `Secuencia Hasta` (ej: `5000`)
     - `Fecha de Vencimiento` (ej: `31/12/2026`)
2. **Entrada Manual de Rangos**:
   - Formulario rápido para ingresar la serie, rango inicial, rango final y fecha de vigencia con validación instantánea.

### 2.2 Modelo de Datos en PostgreSQL (`secuencias_ncf`)

```sql
CREATE TABLE secuencias_ncf (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo_ncf VARCHAR(5) NOT NULL,          -- 'E31', 'E32', 'E34', 'B01', etc.
    descripcion VARCHAR(100) NOT NULL,
    secuencia_inicial BIGINT NOT NULL,
    secuencia_actual BIGINT NOT NULL,
    secuencia_final BIGINT NOT NULL,
    fecha_vencimiento DATE NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_tipo_ncf_activo UNIQUE (tipo_ncf, activo)
);
```

---

## 3. Semáforo de Disponibilidad y Alertas Preventivas

El frontend y el dashboard de ventas presentan un indicador visual del estado de cada serie de comprobantes para evitar interrupciones de facturación:

| Estado Semáforo | Condición Operativa | Comportamiento del Sistema |
| :---: | :--- | :--- |
| 🟢 **Verde** (Normal) | Quedan **> 50** comprobantes y vencimiento > 15 días | Emisión regular sin avisos. |
| 🟡 **Amarillo** (Advertencia) | Quedan **<= 50** comprobantes o vence en **<= 15 días** | Notificación toast y badge en la pantalla de facturación: *"Quedan X comprobantes E31. Solicite renovación en la DGII"*. |
| 🔴 **Rojo** (Agotado / Crítico) | Quedan **0** comprobantes o **fecha vencida** | **Bloqueo preventivo de emisión** para ese tipo de comprobante con modal de solicitud de carga inmediata. |

### Cálculo en TypeScript:
```typescript
export interface NCFStatus {
  disponibles: number;
  diasParaVencer: number;
  estado: 'VERDE' | 'AMARILLO' | 'ROJO';
}

export function evaluateNCFStatus(actual: number, final: number, fechaVence: Date): NCFStatus {
  const disponibles = Math.max(0, final - actual);
  const hoy = new Date();
  const diffTime = fechaVence.getTime() - hoy.getTime();
  const diasParaVencer = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

  let estado: 'VERDE' | 'AMARILLO' | 'ROJO' = 'VERDE';
  if (disponibles === 0 || diasParaVencer <= 0) {
    estado = 'ROJO';
  } else if (disponibles <= 50 || diasParaVencer <= 15) {
    estado = 'AMARILLO';
  }

  return { disponibles, diasParaVencer, estado };
}
```

---

## 4. Asignación Atómica Thread-Safe en PostgreSQL

Para garantizar que múltiples cajas cobrando simultáneamente jamás obtengan el mismo número de NCF:

```typescript
export async function assignNextNCF(client: PoolClient, tipoNcf: string): Promise<{ ncf: string; fechaVence: Date }> {
  // 1. Bloqueo exclusivo a nivel de fila durante la transacción
  const query = `
    SELECT id, tipo_ncf, secuencia_actual, secuencia_final, fecha_vencimiento
    FROM secuencias_ncf
    WHERE tipo_ncf = $1 AND activo = true
    FOR UPDATE;
  `;
  const result = await client.query(query, [tipoNcf]);

  if (result.rows.length === 0) {
    throw new Error(`No hay secuencias configuradas para el comprobante ${tipoNcf}`);
  }

  const row = result.rows[0];
  const fechaVence = new Date(row.fecha_vencimiento);
  if (fechaVence < new Date()) {
    throw new Error(`La serie ${tipoNcf} está vencida desde ${fechaVence.toLocaleDateString()}`);
  }

  const nextSeq = Number(row.secuencia_actual) + 1;
  if (nextSeq > Number(row.secuencia_final)) {
    throw new Error(`Secuencia agotada para el comprobante ${tipoNcf}`);
  }

  // 2. Incrementar contador
  await client.query(
    `UPDATE secuencias_ncf SET secuencia_actual = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`,
    [nextSeq, row.id]
  );

  const isElectronic = tipoNcf.startsWith('E');
  const ncf = isElectronic 
    ? `${tipoNcf}${nextSeq.toString().padStart(10, '0')}`
    : `${tipoNcf}${nextSeq.toString().padStart(8, '0')}`;

  return { ncf, fechaVence };
}
```

---

## 5. Algoritmos de Validación Fiscal en TypeScript (Módulo 10 y Módulo 11)

### 5.1 Validación de Cédula de Identidad (11 dígitos - Algoritmo Módulo 10)
```typescript
export function validarCedula(cedula: string): boolean {
  const clean = cedula.replace(/[^0-9]/g, '');
  if (clean.length !== 11) return false;

  const weights = [1, 2, 1, 2, 1, 2, 1, 2, 1, 2];
  let sum = 0;

  for (let i = 0; i < 10; i++) {
    let prod = parseInt(clean[i], 10) * weights[i];
    if (prod >= 10) {
      prod = Math.floor(prod / 10) + (prod % 10);
    }
    sum += prod;
  }

  const verifier = (10 - (sum % 10)) % 10;
  return verifier === parseInt(clean[10], 10);
}
```

### 5.2 Validación de RNC (9 dígitos - Algoritmo Módulo 11)
```typescript
export function validarRNC(rnc: string): boolean {
  const clean = rnc.replace(/[^0-9]/g, '');
  if (clean.length !== 9) return false;

  const weights = [7, 9, 8, 6, 5, 4, 3, 2];
  let sum = 0;

  for (let i = 0; i < 8; i++) {
    sum += parseInt(clean[i], 10) * weights[i];
  }

  const remainder = sum % 11;
  let verifier = 0;
  if (remainder === 0) {
    verifier = 2;
  } else if (remainder === 1) {
    verifier = 1;
  } else {
    verifier = 11 - remainder;
  }

  return verifier === parseInt(clean[8], 10);
}
```

---

## 6. Reglas Fiscales Críticas de la DGII

1. **Umbral de Consumo RD$ 250,000**:
   - Facturas de Consumo (`E32` / `B02`) cuyo monto total sea $\ge \text{RD\$} 250,000.00$ **exigen obligatoriamente** la identificación del comprador con Cédula, RNC o Pasaporte registrado.
2. **Facturas a Aseguradoras (ARS)**:
   - Los lotes de reclamaciones médicas siempre deben emitirse con **Factura de Crédito Fiscal (`E31` o `B01`)** utilizando el RNC formal de la aseguradora.
3. **Notas de Crédito Fiscal (`E34` / `B04`)**:
   - Deben referenciar obligatoriamente el `ncf_modificado` del comprobante de venta original y el código de anulación estandarizado por DGII (devolución, error en texto, corrección de importes).
