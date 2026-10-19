export interface TrackEntry {
  trackId: string;
  invoiceId: number;
  attempts: number;
  lastAttemptTime: number;
  nextAttemptTime: number;
}

export class BackoffTracker {
  private entries = new Map<string, TrackEntry>();
  private scheduleSec: number[];

  constructor(scheduleSec: number[] = [5, 15, 30, 60]) {
    this.scheduleSec = scheduleSec;
  }

  /**
   * Determina si un TrackId es elegible para ser consultado en este ciclo
   */
  public isReady(trackId: string, invoiceId: number): boolean {
    const now = Date.now();
    let entry = this.entries.get(trackId);

    if (!entry) {
      // Primera consulta inmediata o con retardo inicial (ej. 5s)
      entry = {
        trackId,
        invoiceId,
        attempts: 0,
        lastAttemptTime: now,
        nextAttemptTime: now + this.scheduleSec[0] * 1000,
      };
      this.entries.set(trackId, entry);
      return false; // Esperar al menos el primer intervalo para que DGII procese
    }

    return now >= entry.nextAttemptTime;
  }

  /**
   * Registra un intento de consulta y programa el siguiente intervalo con backoff
   */
  public recordAttempt(trackId: string): void {
    const entry = this.entries.get(trackId);
    if (!entry) return;

    entry.attempts += 1;
    entry.lastAttemptTime = Date.now();

    // Obtener retraso del schedule o usar el último valor como tope máximo
    const delaySec = entry.attempts < this.scheduleSec.length
      ? this.scheduleSec[entry.attempts]
      : this.scheduleSec[this.scheduleSec.length - 1];

    entry.nextAttemptTime = entry.lastAttemptTime + delaySec * 1000;
  }

  /**
   * Remueve un comprobante resuelto (Aceptado o Rechazado) para liberar memoria
   */
  public remove(trackId: string): void {
    this.entries.delete(trackId);
  }

  /**
   * Limpia entradas huérfanas de más de 24 horas para garantizar Zero-Leak
   */
  public pruneOldEntries(): void {
    const now = Date.now();
    const maxAgeMs = 24 * 60 * 60 * 1000;

    for (const [key, entry] of this.entries.entries()) {
      if (now - entry.lastAttemptTime > maxAgeMs) {
        this.entries.delete(key);
      }
    }
  }

  public get pendingCount(): number {
    return this.entries.size;
  }
}
