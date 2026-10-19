import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { ApiServer } from '../src/api/server.js';
import { EcfWorkerService } from '../src/worker/ecf-worker.service.js';
import { DatabasePool } from '../src/config/database.js';
import { request } from 'undici';

describe('FASE 3: Servidor API REST y Entrega de la Interfaz Desktop', () => {
  let server: ApiServer;
  let worker: EcfWorkerService;
  const testPort = 5055;

  beforeAll(async () => {
    await DatabasePool.getPool();
    worker = new EcfWorkerService({
      intervalMs: 5000,
      dryRun: true,
      mockDgii: true,
    });
    server = new ApiServer(worker, testPort);
    await server.start();
  });

  afterAll(async () => {
    worker.stop();
    await server.stop();
    await DatabasePool.close();
  });

  it('1. GET /api/status retorna el estado del worker y métricas de memoria', async () => {
    const res = await request(`http://localhost:${testPort}/api/status`);
    expect(res.statusCode).toBe(200);
    const json = (await res.body.json()) as any;
    expect(json.success).toBe(true);
    expect(json.data.memoryUsageMb.heapUsed).toBeDefined();
    expect(json.data.memoryUsageMb.heapUsed).toBeLessThan(80);
  });

  it('2. GET /api/certificate retorna la información del certificado activo', async () => {
    const res = await request(`http://localhost:${testPort}/api/certificate`);
    expect(res.statusCode).toBe(200);
    const json = (await res.body.json()) as any;
    expect(json.success).toBe(true);
    expect(json.data.name).toBeDefined();
    expect(json.data.restan).toBeGreaterThan(0);
  });

  it('3. GET /api/token retorna la información del token vigente', async () => {
    const res = await request(`http://localhost:${testPort}/api/token`);
    expect(res.statusCode).toBe(200);
    const json = (await res.body.json()) as any;
    expect(json.success).toBe(true);
    expect(json.data.tokenShort).toBeDefined();
  });

  it('4. GET /api/invoices retorna facturas recientes (SOLO LECTURA, últimas 48h)', async () => {
    const res = await request(`http://localhost:${testPort}/api/invoices?limit=10`);
    expect(res.statusCode).toBe(200);
    const json = (await res.body.json()) as any;
    expect(json.success).toBe(true);
    expect(Array.isArray(json.data)).toBe(true);
    expect(json.data.length).toBeLessThanOrEqual(10);
  });

  it('5. GET /api/counter retorna conteos de secuencias y niveles de alerta', async () => {
    const res = await request(`http://localhost:${testPort}/api/counter`);
    expect(res.statusCode).toBe(200);
    const json = (await res.body.json()) as any;
    expect(json.success).toBe(true);
    expect(Array.isArray(json.data)).toBe(true);
    expect(json.data.length).toBeGreaterThan(0);
    expect(json.data[0].alertLevel).toMatch(/green|yellow|red/);
  });

  it('6. GET / sirve el index.html del frontend desktop con 200 OK', async () => {
    const res = await request(`http://localhost:${testPort}/`);
    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toContain('text/html');
    const html = await res.body.text();
    expect(html).toContain('Sentry &lt;SCEYE&gt; (e-CF)');
  });
});
