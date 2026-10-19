import { DatabasePool } from '../config/database.js';
import { InvoiceRecord, EcfPostedStatus } from './worker.types.js';

export interface StoreSignedParams {
  idRecord: number;
  xmlFile: string;
  xmlFileSigned: string;
  securityCode: string;
  signDateTime: string;
  qrCodeUrl: string;
  xmlCompact?: string;
  xmlCompactSigned?: string;
  secretCode?: string;
  compactQrCodeUrl?: string;
  statusCode?: string;
  statusName?: string;
}

export interface StoreTrackParams {
  idRecord: number;
  xmlResponse: string;
  trackId: string;
  statusCode: string;
  statusName: string;
}

export interface StoreFinalStatusParams {
  idRecord: number;
  trackResponse: string;
  statusCode: string;
  statusName: string;
  finalPosted: 'Y' | 'R';
}

export class InvoiceRepository {
  private dryRun: boolean;

  constructor(dryRun = false) {
    this.dryRun = dryRun;
  }

  public setDryRun(value: boolean): void {
    this.dryRun = value;
  }

  /**
   * Obtiene facturas pendientes de firma (C_Posted = 'N') de las últimas 48h (consulta rápida y acotada)
   */
  public async getPendingToSign(limit = 5): Promise<InvoiceRecord[]> {
    const query = `
      SELECT TOP ${limit} 
             i.id_record,
             i.doc_id,
             i.NumAtCard,
             i.ecf_type,
             i.ecf,
             i.ecf_vence,
             i.ecf_print_pages,
             i.xml_file_name,
             i.C_Posted,
             i.date_process
        FROM cms.dbo.ecf_xml_invoice i
       WHERE i.active = 'Y'
         AND i.C_Posted = 'N'
         AND i.ecf_type IN (31, 32, 33, 34, 41, 43, 44, 45, 46, 47)
         AND i.date_process >= DATEADD(day, -2, GETDATE())
       ORDER BY i.id_record ASC
    `;
    return DatabasePool.query<InvoiceRecord>(query);
  }

  /**
   * Obtiene facturas firmadas listas para transmitir a DGII (C_Posted = 'F')
   */
  public async getSignedToUpload(limit = 5): Promise<InvoiceRecord[]> {
    const query = `
      SELECT TOP ${limit}
             i.id_record,
             i.doc_id,
             i.NumAtCard,
             i.ecf_type,
             i.ecf,
             i.ecf_vence,
             i.ecf_print_pages,
             i.xml_file_name,
             i.xml_file_signed,
             i.xml_file_compact,
             i.xml_file_compact_signed,
             i.C_Posted,
             i.date_process
        FROM cms.dbo.ecf_xml_invoice i
       WHERE i.active = 'Y'
         AND i.C_Posted = 'F'
         AND i.ecf_type IN (31, 32, 33, 34, 41, 43, 44, 45, 46, 47)
         AND i.date_process >= DATEADD(day, -2, GETDATE())
       ORDER BY i.id_record ASC
    `;
    return DatabasePool.query<InvoiceRecord>(query);
  }

  /**
   * Obtiene facturas en vuelo en DGII pendientes de dictamen (C_Posted = 'P')
   */
  public async getInFlightToPoll(limit = 10): Promise<InvoiceRecord[]> {
    const query = `
      SELECT TOP ${limit}
             i.id_record,
             i.doc_id,
             i.ecf_type,
             i.ecf,
             i.xml_track_id,
             i.C_Posted,
             i.date_process
        FROM cms.dbo.ecf_xml_invoice i
       WHERE i.active = 'Y'
         AND i.C_Posted = 'P'
         AND i.xml_track_id IS NOT NULL
         AND i.xml_track_id != '00000000-0000-0000-0000-000000000000'
         AND i.date_process >= DATEADD(day, -2, GETDATE())
       ORDER BY i.id_record ASC
    `;
    return DatabasePool.query<InvoiceRecord>(query);
  }

  /**
   * Verifica si una factura E32 califica como RFCE compacto (< RD$ 250,000)
   */
  public async isEligibleForRfce(docId: number): Promise<boolean> {
    const row = await DatabasePool.queryFirstRow<{ DocTotal: number }>(`
      SELECT DocTotal FROM cms.dbo.POSOINV WHERE C_DocEntry = ${docId}
    `);
    return row ? Number(row.DocTotal) < 250000.0 : false;
  }

  /**
   * Guarda los archivos XML firmados y actualiza el estado a 'F'
   */
  public async updateSigned(params: StoreSignedParams): Promise<void> {
    if (this.dryRun) {
      console.log(`[InvoiceRepository - DRY RUN]: Simulado updateSigned para id_record ${params.idRecord} (C_Posted = 'F')`);
      return;
    }

    const query = `
      UPDATE cms.dbo.ecf_xml_invoice
         SET xml_file = @xmlFile,
             xml_file_signed = @xmlFileSigned,
             xml_security_code = @securityCode,
             xml_file_sign_date = @signDateTime,
             xml_file_qrcode = @qrCodeUrl,
             xml_file_compact = @xmlCompact,
             xml_file_compact_signed = @xmlCompactSigned,
             xml_secret_code = @secretCode,
             xml_file_compact_qrcode = @compactQrCodeUrl,
             xml_ecf_status_code = @statusCode,
             xml_ecf_status_name = @statusName,
             C_Posted = 'F'
       WHERE id_record = @idRecord
    `;

    const pool = await DatabasePool.getPool();
    const req = pool.request();
    req.input('idRecord', params.idRecord);
    req.input('xmlFile', params.xmlFile);
    req.input('xmlFileSigned', params.xmlFileSigned);
    req.input('securityCode', params.securityCode);
    req.input('signDateTime', params.signDateTime);
    req.input('qrCodeUrl', params.qrCodeUrl);
    req.input('xmlCompact', params.xmlCompact || '');
    req.input('xmlCompactSigned', params.xmlCompactSigned || '');
    req.input('secretCode', params.secretCode || '');
    req.input('compactQrCodeUrl', params.compactQrCodeUrl || '');
    req.input('statusCode', params.statusCode || '-100');
    req.input('statusName', params.statusName || 'Firmado');
    await req.query(query);
  }

  /**
   * Aplica el bloqueo atómico transitorio Quantum ('Q') antes de transmitir a DGII
   */
  public async markQuantum(idRecord: number): Promise<void> {
    if (this.dryRun) {
      console.log(`[InvoiceRepository - DRY RUN]: Simulado markQuantum para id_record ${idRecord} (C_Posted = 'Q')`);
      return;
    }

    await DatabasePool.query(`
      UPDATE cms.dbo.ecf_xml_invoice
         SET C_Posted = 'Q',
             xml_ecf_status_code = '-99',
             xml_ecf_status_name = 'Quantum'
       WHERE id_record = ${idRecord}
    `);
  }

  /**
   * Guarda el TrackId recibido de la DGII y actualiza el estado a 'P' (En Proceso)
   */
  public async updateTrackId(params: StoreTrackParams): Promise<void> {
    if (this.dryRun) {
      console.log(`[InvoiceRepository - DRY RUN]: Simulado updateTrackId para id_record ${params.idRecord} (TrackId: ${params.trackId}, C_Posted = 'P')`);
      return;
    }

    const query = `
      UPDATE cms.dbo.ecf_xml_invoice
         SET xml_response = @xmlResponse,
             xml_track_id = @trackId,
             xml_ecf_status_code = @statusCode,
             xml_ecf_status_name = @statusName,
             C_Posted = 'P'
       WHERE id_record = @idRecord
    `;

    const pool = await DatabasePool.getPool();
    const req = pool.request();
    req.input('idRecord', params.idRecord);
    req.input('xmlResponse', params.xmlResponse);
    req.input('trackId', params.trackId);
    req.input('statusCode', params.statusCode);
    req.input('statusName', params.statusName);
    await req.query(query);
  }

  /**
   * Guarda el dictamen final de la DGII ('Y' para Aceptado, 'R' para Rechazado)
   */
  public async updateFinalStatus(params: StoreFinalStatusParams): Promise<void> {
    if (this.dryRun) {
      console.log(`[InvoiceRepository - DRY RUN]: Simulado updateFinalStatus para id_record ${params.idRecord} (C_Posted = '${params.finalPosted}', Código: ${params.statusCode})`);
      return;
    }

    const query = `
      UPDATE cms.dbo.ecf_xml_invoice
         SET xml_track_response = @trackResponse,
             xml_ecf_status_code = @statusCode,
             xml_ecf_status_name = @statusName,
             C_Posted = @finalPosted
       WHERE id_record = @idRecord
    `;

    const pool = await DatabasePool.getPool();
    const req = pool.request();
    req.input('idRecord', params.idRecord);
    req.input('trackResponse', params.trackResponse);
    req.input('statusCode', params.statusCode);
    req.input('statusName', params.statusName);
    req.input('finalPosted', params.finalPosted);
    await req.query(query);
  }
}
