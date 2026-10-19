import { InvoiceRepository } from './invoice-repository.js';
import { BackoffTracker } from './backoff-tracker.js';
import { WorkerConfig, WorkerStats, InvoiceRecord } from './worker.types.js';
import { XmlGeneratorService } from '../xml/xml-generator.service.js';
import { SignerService } from '../crypto/signer.service.js';
import { P12Service } from '../crypto/p12.service.js';
import { DgiiClient } from '../dgii/dgii-client.js';
import { TokenManagerService } from '../dgii/token-manager.service.js';
import { config } from '../config/env.js';

export class EcfWorkerService {
  private repo: InvoiceRepository;
  private backoff: BackoffTracker;
  private workerConfig: WorkerConfig;
  private timer: NodeJS.Timeout | null = null;
  private isProcessing = false;

  private stats: WorkerStats = {
    isRunning: false,
    isPaused: false,
    totalCycles: 0,
    totalSigned: 0,
    totalSent: 0,
    totalAccepted: 0,
    totalRejected: 0,
    totalErrors: 0,
    lastCycleDurationMs: 0,
    memoryUsageMb: {
      rss: 0,
      heapUsed: 0,
      heapTotal: 0,
    },
    lastRunTimestamp: null,
  };

  constructor(options?: Partial<WorkerConfig>) {
    this.workerConfig = {
      intervalMs: options?.intervalMs ?? 3000,
      batchSize: options?.batchSize ?? 5,
      dryRun: options?.dryRun ?? false,
      mockDgii: options?.mockDgii ?? false,
      backoffScheduleSec: options?.backoffScheduleSec ?? [5, 15, 30, 60],
    };

    this.repo = new InvoiceRepository(this.workerConfig.dryRun);
    this.backoff = new BackoffTracker(this.workerConfig.backoffScheduleSec);
  }

  /**
   * Arranca el ciclo único del Worker reactivo
   */
  public async start(): Promise<void> {
    if (this.stats.isRunning) return;

    console.log('[EcfWorker]: Iniciando Worker asíncrono e-CF...');
    console.log(`[EcfWorker Config]: Intervalo: ${this.workerConfig.intervalMs}ms, Lote: ${this.workerConfig.batchSize}, DryRun: ${this.workerConfig.dryRun}, MockDGII: ${this.workerConfig.mockDgii}`);

    // Precargar el certificado digital en memoria una sola vez al arrancar
    try {
      const cert = await P12Service.getActiveCertificate();
      console.log(`[EcfWorker]: Certificado precargado en memoria: ${cert.certName} (${cert.daysRemaining} días restantes)`);
    } catch (err: any) {
      console.warn(`[EcfWorker Advertencia]: No se pudo precargar el certificado en arranque:`, err.message);
    }

    this.stats.isRunning = true;
    this.stats.isPaused = false;
    this.scheduleNextTick(0);
  }

  /**
   * Detiene el Worker de forma limpia liberando memoria y temporizadores
   */
  public stop(): void {
    console.log('[EcfWorker]: Deteniendo Worker...');
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
    this.stats.isRunning = false;
    this.stats.isPaused = false;
    this.isProcessing = false;
  }

  public pause(): void {
    this.stats.isPaused = true;
    console.log('[EcfWorker]: Worker pausado.');
  }

  public resume(): void {
    if (this.stats.isPaused) {
      this.stats.isPaused = false;
      console.log('[EcfWorker]: Worker reanudado.');
      this.scheduleNextTick(0);
    }
  }

  public getConfig(): WorkerConfig {
    return { ...this.workerConfig };
  }

  public updateConfig(newConfig: Partial<WorkerConfig>): void {
    if (newConfig.intervalMs !== undefined && newConfig.intervalMs >= 1000) {
      this.workerConfig.intervalMs = newConfig.intervalMs;
    }
    if (newConfig.batchSize !== undefined && newConfig.batchSize >= 1) {
      this.workerConfig.batchSize = newConfig.batchSize;
    }
    if (newConfig.dryRun !== undefined) {
      this.workerConfig.dryRun = newConfig.dryRun;
      this.repo = new InvoiceRepository(this.workerConfig.dryRun);
    }
    if (newConfig.mockDgii !== undefined) {
      this.workerConfig.mockDgii = newConfig.mockDgii;
    }
    console.log(`[EcfWorker Config Actualizado]:`, this.workerConfig);
  }

  public getStats(): WorkerStats {
    const mem = process.memoryUsage();
    this.stats.memoryUsageMb = {
      rss: Math.round((mem.rss / 1024 / 1024) * 100) / 100,
      heapUsed: Math.round((mem.heapUsed / 1024 / 1024) * 100) / 100,
      heapTotal: Math.round((mem.heapTotal / 1024 / 1024) * 100) / 100,
    };
    return { ...this.stats };
  }

  private scheduleNextTick(delayMs: number): void {
    if (!this.stats.isRunning) return;
    this.timer = setTimeout(async () => {
      await this.runCycle();
    }, delayMs);
  }

  /**
   * Ejecuta un ciclo coordinado completo (Firma ➔ Envío ➔ Consulta)
   * Diseñado con un solo hilo de ejecución cooperativo, previniendo carreras y fugas
   */
  public async runCycle(): Promise<void> {
    if (!this.stats.isRunning || this.stats.isPaused || this.isProcessing) {
      return;
    }

    this.isProcessing = true;
    const cycleStart = performance.now();
    this.stats.totalCycles += 1;
    this.stats.lastRunTimestamp = new Date();

    try {
      // 1. Etapa de Firma: Procesar comprobantes nuevos ('N' -> 'F')
      await this.processPendingStep();

      // 2. Etapa de Transmisión: Enviar comprobantes firmados ('F' -> 'Q' -> 'P')
      await this.processSignedStep();

      // 3. Etapa de Consulta: Polling con Backoff Exponencial ('P' -> 'Y' / 'R')
      await this.processInFlightStep();

      // Limpieza periódica de huérfanos de backoff
      if (this.stats.totalCycles % 100 === 0) {
        this.backoff.pruneOldEntries();
      }
    } catch (err: any) {
      this.stats.totalErrors += 1;
      console.error('[EcfWorker Ciclo Error]:', err.message);
    } finally {
      this.stats.lastCycleDurationMs = Math.round(performance.now() - cycleStart);
      this.isProcessing = false;
      this.scheduleNextTick(this.workerConfig.intervalMs);
    }
  }

  /**
   * ETAPA 1: Generación y Firma Digital (C_Posted = 'N' -> 'F')
   */
  public async processPendingStep(): Promise<number> {
    const pendingList = await this.repo.getPendingToSign(this.workerConfig.batchSize);
    if (pendingList.length === 0) return 0;

    let processed = 0;
    for (const item of pendingList) {
      try {
        await this.signInvoiceItem(item);
        this.stats.totalSigned += 1;
        processed += 1;
      } catch (err: any) {
        this.stats.totalErrors += 1;
        console.error(`[EcfWorker Firma Error - Factura ${item.doc_id}]:`, err.message);
      }
    }
    return processed;
  }

  private async signInvoiceItem(item: InvoiceRecord): Promise<void> {
    const docId = item.doc_id;
    const ecfType = item.ecf_type;

    // 1. Generar XML completo estándar
    const xmlFull = await XmlGeneratorService.generateXmlFromDb({
      docId,
      ecfType,
      catalogType: 'ECF',
      isCompact: 0,
      securityCode: '',
      printPages: item.ecf_print_pages || '',
    });

    // 2. Firmar digitalmente con XMLDSig
    const signResult = await SignerService.signECF(xmlFull, 'ECF');

    // 3. Manejo de RFCE compacto para facturas E32 < 250k
    let xmlCompact = '';
    let xmlCompactSigned = '';
    let secretCode = '';
    let compactQrCodeUrl = '';

    if (ecfType === '32') {
      const isRfce = await this.repo.isEligibleForRfce(docId);
      if (isRfce) {
        xmlCompact = await XmlGeneratorService.generateXmlFromDb({
          docId,
          ecfType,
          catalogType: 'RFCE',
          isCompact: 1,
          securityCode: signResult.securityCode,
          printPages: item.ecf_print_pages || '',
        });

        const rfceSignResult = await SignerService.signECF(xmlCompact, 'RFCE');
        xmlCompactSigned = rfceSignResult.signedXml;
        secretCode = rfceSignResult.securityCode;
        compactQrCodeUrl = rfceSignResult.qrCodeUrl;
      }
    }

    // 4. Guardar en base de datos y cambiar estado a 'F'
    await this.repo.updateSigned({
      idRecord: item.id_record,
      xmlFile: xmlFull,
      xmlFileSigned: signResult.signedXml,
      securityCode: signResult.securityCode,
      signDateTime: signResult.fechaHoraFirma,
      qrCodeUrl: signResult.qrCodeUrl,
      xmlCompact,
      xmlCompactSigned,
      secretCode,
      compactQrCodeUrl,
      statusCode: '-100',
      statusName: 'Firmado',
    });
  }

  /**
   * ETAPA 2: Transmisión Segura a DGII (C_Posted = 'F' -> 'Q' -> 'P')
   */
  public async processSignedStep(): Promise<number> {
    const signedList = await this.repo.getSignedToUpload(this.workerConfig.batchSize);
    if (signedList.length === 0) return 0;

    let processed = 0;
    for (const item of signedList) {
      try {
        await this.uploadInvoiceItem(item);
        this.stats.totalSent += 1;
        processed += 1;
      } catch (err: any) {
        this.stats.totalErrors += 1;
        console.error(`[EcfWorker Transmisión Error - Factura ${item.doc_id}]:`, err.message);
      }
    }
    return processed;
  }

  private async uploadInvoiceItem(item: InvoiceRecord): Promise<void> {
    const idRecord = item.id_record;
    const xmlToSend = item.xml_file_compact_signed || item.xml_file_signed || '';
    if (!xmlToSend) {
      throw new Error(`Factura ${item.doc_id} no tiene XML firmado disponible.`);
    }

    // 1. Obtener Token Bearer activo desde la memoria
    let token = '';
    if (!this.workerConfig.mockDgii) {
      token = await TokenManagerService.getActiveToken();
      if (!token) {
        console.warn(`[EcfWorker]: No se pudo obtener Token Bearer de la DGII. Pospone envío de factura ${item.doc_id}.`);
        return;
      }
    } else {
      token = 'mock-bearer-token-12345';
    }

    // 2. Bloqueo atómico transitorio Quantum ('Q')
    await this.repo.markQuantum(idRecord);

    // 3. Enviar a DGII
    let response;
    if (this.workerConfig.mockDgii) {
      // Modo Mock seguro para pruebas
      response = {
        rawXml: `<RespuestaRecepcion><TrackId>mock-track-${Date.now()}-${idRecord}</TrackId></RespuestaRecepcion>`,
        trackId: `mock-track-${Date.now()}-${idRecord}`,
        isSuccess: true,
        statusCode: '-101',
        statusName: 'Firmado y Enviado',
      };
    } else {
      const baseUrl = config.dgii.activeBaseUrl;
      const fileName = item.xml_file_name || `${item.ecf}`;
      response = await DgiiClient.sendECF(baseUrl, xmlToSend, token, fileName);
    }

    // 4. Actualizar TrackId y pasar a 'P'
    if (response.isSuccess && response.trackId !== '00000000-0000-0000-0000-000000000000') {
      await this.repo.updateTrackId({
        idRecord,
        xmlResponse: response.rawXml,
        trackId: response.trackId,
        statusCode: response.statusCode,
        statusName: response.statusName,
      });
    } else {
      // Revertir a 'F' o marcar error temporal de WebService
      console.warn(`[EcfWorker]: Recepción fallida en DGII para factura ${item.doc_id}. Reintentará en el próximo ciclo.`);
    }
  }

  /**
   * ETAPA 3: Consulta Asíncrona con Backoff Exponencial (C_Posted = 'P' -> 'Y' / 'R')
   */
  public async processInFlightStep(): Promise<number> {
    const inFlightList = await this.repo.getInFlightToPoll(this.workerConfig.batchSize);
    if (inFlightList.length === 0) return 0;

    let processed = 0;
    for (const item of inFlightList) {
      const trackId = item.xml_track_id;
      if (!trackId) continue;

      // Evaluar si es elegible según el cronograma de backoff exponencial
      if (!this.backoff.isReady(trackId, item.id_record)) {
        continue;
      }

      try {
        await this.pollTrackStatusItem(item, trackId);
        processed += 1;
      } catch (err: any) {
        this.stats.totalErrors += 1;
        console.error(`[EcfWorker Polling Error - TrackId ${trackId}]:`, err.message);
      }
    }
    return processed;
  }

  private async pollTrackStatusItem(item: InvoiceRecord, trackId: string): Promise<void> {
    this.backoff.recordAttempt(trackId);

    let statusResult;
    if (this.workerConfig.mockDgii) {
      statusResult = {
        rawXml: `<RespuestaConsultaTrackId><Codigo>1</Codigo><Estado>Aceptado</Estado></RespuestaConsultaTrackId>`,
        trackId,
        codigo: '1',
        estado: 'Aceptado',
        rnc: '102314675',
        encf: item.ecf,
        secuenciaUtilizada: true,
        mensajes: [],
        isAccepted: true,
      };
    } else {
      const token = await TokenManagerService.getActiveToken();
      statusResult = await DgiiClient.getTrackStatus(config.dgii.activeBaseUrl, trackId, token);
    }

    if (statusResult.isAccepted) {
      // ÉXITO: Factura Aceptada por la DGII ('Y')
      await this.repo.updateFinalStatus({
        idRecord: item.id_record,
        trackResponse: statusResult.rawXml,
        statusCode: statusResult.codigo,
        statusName: statusResult.estado,
        finalPosted: 'Y',
      });
      this.backoff.remove(trackId);
      this.stats.totalAccepted += 1;
      console.log(`[EcfWorker]: ✅ Factura ${item.ecf} (DocID ${item.doc_id}) ACEPTADA por DGII.`);
    } else if (statusResult.codigo === '2' || statusResult.estado.toLowerCase() === 'rechazado') {
      // RECHAZO: Factura Rechazada por la DGII ('R')
      await this.repo.updateFinalStatus({
        idRecord: item.id_record,
        trackResponse: statusResult.rawXml,
        statusCode: statusResult.codigo,
        statusName: statusResult.estado,
        finalPosted: 'R',
      });
      this.backoff.remove(trackId);
      this.stats.totalRejected += 1;
      console.warn(`[EcfWorker]: ❌ Factura ${item.ecf} (DocID ${item.doc_id}) RECHAZADA por DGII. Glosas registradas.`);
    } else {
      // Sigue 'En Proceso' (Código 3) o WebServiceError: el tracker incrementa el backoff delay
      console.log(`[EcfWorker]: ⏳ Factura ${item.ecf} aún En Proceso en DGII (TrackId ${trackId}). Próxima consulta programada con backoff.`);
    }
  }
}
