import { config } from './config/env.js';
import { DatabasePool } from './config/database.js';
import { P12Service } from './crypto/p12.service.js';
import { TokenManagerService } from './dgii/token-manager.service.js';
import { EcfWorkerService } from './worker/ecf-worker.service.js';
import { ApiServer } from './api/server.js';

let apiServer: ApiServer | null = null;
let worker: EcfWorkerService | null = null;

async function bootstrap() {
  console.log('================================================================');
  console.log('   FIRMADOR ELECTRONICO DGII (e-CF) - MOTOR NODE.JS / TYPESCRIPT ');
  console.log('   Ley 32-23 - Agrofem Modern Core                               ');
  console.log('================================================================');
  console.log(`[Config]: Entorno DGII: ${config.dgii.env.toUpperCase()} (${config.dgii.activeBaseUrl})`);
  console.log(`[Config]: Servidor BD: ${config.database.server}:${config.database.port}/${config.database.database}`);

  // 1. Probar conexión a la base de datos (SOLO LECTURA)
  const health = await DatabasePool.checkHealth();
  if (health.status !== 'healthy') {
    console.error('[Bootstrap Error]: No se pudo conectar a la base de datos:', health.error);
    process.exit(1);
  }
  console.log(`[Bootstrap]: Base de datos conectada correctamente. Hora del servidor: ${health.serverTime?.toISOString()}`);

  // 2. Precargar certificado en memoria
  try {
    const cert = await P12Service.getActiveCertificate();
    console.log(`[Bootstrap]: Certificado digital precargado: ${cert.certName} (${cert.daysRemaining} días restantes)`);
  } catch (err: any) {
    console.warn(`[Bootstrap Advertencia]: No se pudo precargar el certificado:`, err.message);
  }

  // 3. Consultar token vigente
  try {
    const token = await TokenManagerService.getActiveToken();
    if (token) {
      console.log(`[Bootstrap]: Token DGII activo detectado en memoria/BD.`);
    } else {
      console.log(`[Bootstrap]: No hay token vigente. Se solicitará bajo demanda.`);
    }
  } catch (err: any) {
    console.warn(`[Bootstrap Advertencia]:`, err.message);
  }

  // 4. Inicializar Worker (Modo Seguro DryRun para no alterar producción en pruebas)
  worker = new EcfWorkerService({
    intervalMs: 3000,
    batchSize: 5,
    dryRun: true, // Seguro para desarrollo
    mockDgii: true, // Seguro para desarrollo
  });
  await worker.start();

  // 5. Iniciar Servidor API Local en puerto 5000
  apiServer = new ApiServer(worker, config.server.port);
  await apiServer.start();

  console.log('================================================================');
  console.log(`[Firmador e-CF]: Listo y operativo en http://localhost:${config.server.port}`);
  console.log('================================================================');
}

// Manejo de apagado elegante (Graceful shutdown)
async function shutdown() {
  console.log('\n[Process]: Cerrando servicios con apagado elegante...');
  if (worker) worker.stop();
  TokenManagerService.shutdown();
  if (apiServer) await apiServer.stop();
  await DatabasePool.close();
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

if (process.env.NODE_ENV !== 'test') {
  bootstrap().catch((err) => {
    console.error('[Fatal Bootstrap Error]:', err);
    process.exit(1);
  });
}
