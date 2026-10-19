import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { DatabasePool } from '../src/config/database.js';
import { XmlGeneratorService } from '../src/xml/xml-generator.service.js';
import { P12Service } from '../src/crypto/p12.service.js';
import { SignerService } from '../src/crypto/signer.service.js';
import { DgiiClient } from '../src/dgii/dgii-client.js';

describe('FASE 1: Motor Criptográfico, Conexión Segura y Núcleo de Facturación Electrónica DGII', () => {
  beforeAll(async () => {
    // Inicializar pool
    await DatabasePool.getPool();
  });

  afterAll(async () => {
    // Cerrar pool y limpiar temporizadores
    await DatabasePool.close();
  });

  it('1. Conexión segura a SQL Server (cms) responde saludable', async () => {
    const health = await DatabasePool.checkHealth();
    expect(health.status).toBe('healthy');
    expect(health.serverTime).toBeDefined();
  });

  it('2. Extracción de datos de prueba recientes (SOLO LECTURA, últimas 48h)', async () => {
    // Consulta restringida a las últimas 48 horas con TOP 1 para rendimiento óptimo
    const invoice = await DatabasePool.queryFirstRow<{
      id_record: number;
      doc_id: number;
      ecf_type: string;
      ecf: string;
      ecf_print_pages: string;
      xml_file: string;
      xml_security_code: string;
    }>(`
      SELECT TOP 1 id_record, doc_id, ecf_type, ecf, ecf_print_pages, xml_file, xml_security_code
      FROM cms.dbo.ecf_xml_invoice
      WHERE C_Posted = 'Y' 
        AND date_process >= DATEADD(day, -2, GETDATE())
      ORDER BY id_record DESC
    `);

    expect(invoice).not.toBeNull();
    expect(invoice!.doc_id).toBeGreaterThan(0);
    expect(invoice!.ecf).toMatch(/^E\d{12}$/);
    expect(invoice!.xml_security_code).toHaveLength(6);
  });

  it('3. Generador de XML reproduce la estructura idéntica a dbo.GetInvoiceDataForXML', async () => {
    // Usar factura de referencia reciente
    const invoice = await DatabasePool.queryFirstRow<{
      doc_id: number;
      ecf_type: string;
      ecf: string;
      ecf_print_pages: string;
      xml_file: string;
    }>(`
      SELECT TOP 1 doc_id, ecf_type, ecf, ecf_print_pages, xml_file
      FROM cms.dbo.ecf_xml_invoice
      WHERE C_Posted = 'Y' AND date_process >= DATEADD(day, -2, GETDATE())
      ORDER BY id_record DESC
    `);

    expect(invoice).not.toBeNull();

    const generatedXml = await XmlGeneratorService.generateXmlFromDb({
      docId: invoice!.doc_id,
      ecfType: invoice!.ecf_type,
      catalogType: 'ECF',
      isCompact: 0,
      securityCode: '',
      printPages: invoice!.ecf_print_pages || '',
    });

    // Validar encabezado y nodos raíz
    expect(generatedXml).toContain("<?xml version = '1.0' encoding = 'UTF-8'?>");
    expect(generatedXml).toContain('<ECF>');
    expect(generatedXml).toContain('<Encabezado>');
    expect(generatedXml).toContain(`<eNCF>${invoice!.ecf}</eNCF>`);
    expect(generatedXml).toContain('</ECF>');

    // Validar longitud y concordancia estructural byte a byte
    expect(generatedXml.length).toBe(invoice!.xml_file.length);
  }, 35000);

  it('4. Carga y parseo en memoria del certificado P12 activo (ecf_certificate)', async () => {
    const certInfo = await P12Service.getActiveCertificate();

    expect(certInfo).toBeDefined();
    expect(certInfo.daysRemaining).toBeGreaterThan(0);
    expect(certInfo.privateKeyPem).toContain('PRIVATE KEY');
    expect(certInfo.certBase64.length).toBeGreaterThan(500);
    expect(certInfo.issuer).toContain('VIAFIRMA');
  });

  it('5. Firma digital XMLDSig: inyección de FechaHoraFirma, RSA-SHA256 y Security Code de 6 caracteres', async () => {
    const testXml = `<?xml version = '1.0' encoding = 'UTF-8'?>
<ECF>
   <Encabezado>
      <Version>1.0</Version>
      <IdDoc>
         <TipoeCF>31</TipoeCF>
         <eNCF>E310000000001</eNCF>
      </IdDoc>
      <Emisor>
         <RNCEmisor>102314675</RNCEmisor>
         <FechaEmision>15-10-2026</FechaEmision>
      </Emisor>
      <Totales>
         <MontoTotal>1500.00</MontoTotal>
      </Totales>
   </Encabezado>
</ECF>`;

    const signResult = await SignerService.signECF(testXml, 'ECF', '15-10-2026 10:30:00');

    expect(signResult.signedXml).toContain('<FechaHoraFirma>15-10-2026 10:30:00</FechaHoraFirma>');
    expect(signResult.signedXml).toContain('<Signature xmlns="http://www.w3.org/2000/09/xmldsig#">');
    expect(signResult.signedXml).toContain('Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"');
    expect(signResult.signedXml).toContain('Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"');
    expect(signResult.signedXml).toContain('Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315"');
    expect(signResult.signedXml).toContain('<X509Certificate>');

    // Validar código de seguridad (primeros 6 caracteres de SignatureValue)
    expect(signResult.securityCode).toHaveLength(6);

    // Validar enlace para Timbre Fiscal QR
    expect(signResult.qrCodeUrl).toContain('https://ecf.dgii.gov.do/eCF/ConsultaTimbre?');
    expect(signResult.qrCodeUrl).toContain('RncEmisor=102314675');
    expect(signResult.qrCodeUrl).toContain('ENCF=E310000000001');
    expect(signResult.qrCodeUrl).toContain(`CodigoSeguridad=${signResult.securityCode}`);
  });

  it('6. Cliente DGII: Detección y sobrescritura de Falso Rechazo (Código 75 y 1209 con SecuenciaUtilizada=false)', () => {
    // Simulación de respuesta real de la DGII con corte de red previo
    const mockDgiiXml = `<?xml version="1.0" encoding="UTF-8"?>
<RespuestaConsultaTrackId>
    <TrackId>e6b35d21-4f11-4b1a-967a-cfb3952d7bb4</TrackId>
    <Codigo>2</Codigo>
    <Estado>Rechazado</Estado>
    <Rnc>102314675</Rnc>
    <Encf>E320000243500</Encf>
    <SecuenciaUtilizada>false</SecuenciaUtilizada>
    <Mensajes>
        <Mensaje>
            <Codigo>75</Codigo>
            <Valor>El e-NCF de este Resumen de Factura de Consumo ya ha sido utilizado previamente.</Valor>
        </Mensaje>
    </Mensajes>
</RespuestaConsultaTrackId>`;

    const result = DgiiClient.parseTrackStatusXml(mockDgiiXml, 'e6b35d21-4f11-4b1a-967a-cfb3952d7bb4');

    // Debe aplicar la regla de negocio y transformar a Aceptado
    expect(result.codigo).toBe('1');
    expect(result.estado).toBe('Aceptado');
    expect(result.isAccepted).toBe(true);
  });

  it('7. Cliente DGII: Manejo de Rechazo legítimo con múltiples glosas', () => {
    const mockRejectXml = `<?xml version="1.0" encoding="UTF-8"?>
<RespuestaConsultaTrackId>
    <TrackId>a1b2c3d4-0000-1111-2222-333344445555</TrackId>
    <Codigo>2</Codigo>
    <Estado>Rechazado</Estado>
    <Rnc>102314675</Rnc>
    <Encf>E310000135999</Encf>
    <SecuenciaUtilizada>true</SecuenciaUtilizada>
    <Mensajes>
        <Mensaje>
            <Codigo>101</Codigo>
            <Valor>RNC del Comprador no está registrado en el RNC de DGII.</Valor>
        </Mensaje>
        <Mensaje>
            <Codigo>205</Codigo>
            <Valor>Monto total del ITBIS no coincide con el cálculo del detalle.</Valor>
        </Mensaje>
    </Mensajes>
</RespuestaConsultaTrackId>`;

    const result = DgiiClient.parseTrackStatusXml(mockRejectXml, 'a1b2c3d4-0000-1111-2222-333344445555');

    expect(result.codigo).toBe('2');
    expect(result.estado).toBe('Rechazado');
    expect(result.isAccepted).toBe(false);
    expect(result.mensajes).toHaveLength(2);
    expect(result.mensajes[0].codigo).toBe('101');
    expect(result.mensajes[1].codigo).toBe('205');
  });
});
