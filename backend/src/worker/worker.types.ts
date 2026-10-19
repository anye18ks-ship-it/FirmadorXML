export type EcfPostedStatus = 'N' | 'F' | 'Q' | 'P' | 'Y' | 'R' | 'S' | 'E';

export interface InvoiceRecord {
  id_record: number;
  doc_id: number;
  NumAtCard?: string;
  ecf_type: string; // '31', '32', '34', etc.
  ecf: string;
  ecf_vence?: Date;
  ecf_print_pages?: string;
  xml_file_name: string;
  xml_file?: string;
  xml_file_signed?: string;
  xml_security_code?: string;
  xml_file_compact?: string;
  xml_file_compact_signed?: string;
  xml_secret_code?: string;
  xml_response?: string;
  xml_track_id?: string;
  xml_track_response?: string;
  xml_ecf_status_code?: string;
  xml_ecf_status_name?: string;
  C_Posted: EcfPostedStatus;
  date_process?: Date;
  datetime_process?: Date;
}

export interface WorkerConfig {
  intervalMs: number; // Intervalo del loop principal (ej. 3000ms)
  batchSize: number; // Límite de facturas por ciclo (ej. 5)
  dryRun: boolean; // Si es true, NO modifica la BD de producción
  mockDgii: boolean; // Si es true, usa el cliente mock sin enviar a DGII
  backoffScheduleSec: number[]; // Secuencia de reintento en segundos: [5, 15, 30, 60]
}

export interface WorkerStats {
  isRunning: boolean;
  isPaused: boolean;
  totalCycles: number;
  totalSigned: number;
  totalSent: number;
  totalAccepted: number;
  totalRejected: number;
  totalErrors: number;
  lastCycleDurationMs: number;
  memoryUsageMb: {
    rss: number;
    heapUsed: number;
    heapTotal: number;
  };
  lastRunTimestamp: Date | null;
}
