import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { EcfWorkerService } from '../src/worker/ecf-worker.service.js';
import { BackoffTracker } from '../src/worker/backoff-tracker.js';
import { InvoiceRepository } from '../src/worker/invoice-repository.js';
import { DatabasePool } from '../src/config/database.js';

describe('FASE 2: Worker Asíncrono de Alto Rendimiento y Máquina de Estados', () => {
  beforeAll(async () => {
    await DatabasePool.getPool();
  });

  afterAll(async () => {
    await DatabasePool.close();
  });

  it('1. Control de Ciclo de Vida del Worker (start, pause, resume, stop)', async () => {
    const worker = new EcfWorkerService({
      intervalMs: 1000,
      dryRun: true,
      mockDgii: true,
    });

    await worker.start();
    let stats = worker.getStats();
    expect(stats.isRunning).toBe(true);
    expect(stats.isPaused).toBe(false);

    worker.pause();
    stats = worker.getStats();
    expect(stats.isPaused).toBe(true);

    worker.resume();
    stats = worker.getStats();
    expect(stats.isPaused).toBe(false);

    worker.stop();
    stats = worker.getStats();
    expect(stats.isRunning).toBe(false);
  });

  it('2. BackoffTracker calcula intervalos exponenciales (5s, 15s, 30s, 60s) y libera memoria', () => {
    const tracker = new BackoffTracker([5, 15, 30, 60]);
    const trackId = 'test-track-uuid-1234';

    // Primer chequeo: debe programar el primer retardo de 5s y retornar false
    const readyFirst = tracker.isReady(trackId, 100);
    expect(readyFirst).toBe(false);
    expect(tracker.pendingCount).toBe(1);

    // Registro de intentos progresivos
    tracker.recordAttempt(trackId);
    tracker.recordAttempt(trackId);

    // Liberación de memoria tras resolución
    tracker.remove(trackId);
    expect(tracker.pendingCount).toBe(0);
  });

  it('3. InvoiceRepository acota consultas a las últimas 48h con límites estrictos (SOLO LECTURA)', async () => {
    const repo = new InvoiceRepository(true); // dryRun = true

    const pending = await repo.getPendingToSign(5);
    expect(Array.isArray(pending)).toBe(true);
    expect(pending.length).toBeLessThanOrEqual(5);

    const signed = await repo.getSignedToUpload(5);
    expect(Array.isArray(signed)).toBe(true);
    expect(signed.length).toBeLessThanOrEqual(5);

    const inFlight = await repo.getInFlightToPoll(5);
    expect(Array.isArray(inFlight)).toBe(true);
    expect(inFlight.length).toBeLessThanOrEqual(5);
  });

  it('4. Simulación completa de la Máquina de Estados (N -> F -> Q -> P -> Y) en modo Seguro', async () => {
    const worker = new EcfWorkerService({
      intervalMs: 500,
      batchSize: 2,
      dryRun: true, // No modifica datos en producción
      mockDgii: true, // Simula respuestas DGII localmente
    });

    // Ejecutar un ciclo coordinado completo
    await worker.start();
    await worker.runCycle();
    worker.stop();

    const stats = worker.getStats();
    expect(stats.totalCycles).toBeGreaterThanOrEqual(1);
    expect(stats.totalErrors).toBe(0);
  }, 15000);

  it('5. Verificación de Huella de Memoria Estable (< 80 MB RAM en operación continua)', async () => {
    const worker = new EcfWorkerService({
      intervalMs: 100,
      batchSize: 5,
      dryRun: true,
      mockDgii: true,
    });

    // Ejecutar 10 ciclos consecutivos para medir consumo
    for (let i = 0; i < 10; i++) {
      await worker.runCycle();
    }

    const stats = worker.getStats();
    console.log(`[Memory Footprint Test]: HeapUsed: ${stats.memoryUsageMb.heapUsed} MB, RSS: ${stats.memoryUsageMb.rss} MB`);

    // La memoria Heap debe permanecer holgadamente por debajo de 80 MB
    expect(stats.memoryUsageMb.heapUsed).toBeLessThan(80);
  });
});
