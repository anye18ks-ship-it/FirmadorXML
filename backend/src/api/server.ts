import http from 'http';
import fs from 'fs';
import path from 'path';
import { exec } from 'child_process';
import util from 'util';
import { DatabasePool } from '../config/database.js';
import { P12Service } from '../crypto/p12.service.js';
import { TokenManagerService } from '../dgii/token-manager.service.js';
import { EcfWorkerService } from '../worker/ecf-worker.service.js';
import { config } from '../config/env.js';

const execAsync = util.promisify(exec);

export class ApiServer {
  private server: http.Server | null = null;
  private worker: EcfWorkerService;
  private port: number;
  private frontendDistPath: string;

  constructor(worker: EcfWorkerService, port = 5000) {
    this.worker = worker;
    this.port = port;
    this.frontendDistPath = path.resolve(process.cwd(), '../frontend/dist');
  }

  public start(): Promise<void> {
    return new Promise((resolve) => {
      this.server = http.createServer(async (req, res) => {
        // Habilitar CORS para el frontend (puerto 5173 o local)
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

        if (req.method === 'OPTIONS') {
          res.writeHead(204);
          res.end();
          return;
        }

        const url = new URL(req.url || '/', `http://localhost:${this.port}`);
        const pathname = url.pathname;

        try {
          // 1. Estatus del Worker y Métricas de Rendimiento
          if (req.method === 'GET' && pathname === '/api/status') {
            const stats = this.worker.getStats();
            this.sendJson(res, 200, { success: true, data: stats });
            return;
          }

          // 2. Control del Worker (Start, Pause, Resume, Process Manual)
          if (req.method === 'POST' && pathname === '/api/worker/start') {
            await this.worker.start();
            this.sendJson(res, 200, { success: true, message: 'Worker iniciado', stats: this.worker.getStats() });
            return;
          }

          if (req.method === 'POST' && pathname === '/api/worker/pause') {
            this.worker.pause();
            this.sendJson(res, 200, { success: true, message: 'Worker pausado', stats: this.worker.getStats() });
            return;
          }

          if (req.method === 'POST' && pathname === '/api/worker/resume') {
            this.worker.resume();
            this.sendJson(res, 200, { success: true, message: 'Worker reanudado', stats: this.worker.getStats() });
            return;
          }

          if (req.method === 'POST' && pathname === '/api/worker/process-now') {
            // Ejecución manual de un ciclo
            await this.worker.runCycle();
            this.sendJson(res, 200, { success: true, message: 'Ciclo manual ejecutado', stats: this.worker.getStats() });
            return;
          }

          // 2.1 Configuración Dinámica del Worker y del Sistema
          if (req.method === 'GET' && pathname === '/api/config') {
            const workerConfig = this.worker.getConfig();
            const taskStatus = await this.checkScheduledTaskStatus();
            this.sendJson(res, 200, {
              success: true,
              data: {
                ...workerConfig,
                port: this.port,
                dgiiEnv: config.dgii.env,
                dgiiBaseUrl: config.dgii.activeBaseUrl,
                dbServer: config.database.server,
                dbDatabase: config.database.database,
                isTaskScheduled: taskStatus,
              },
            });
            return;
          }

          if (req.method === 'POST' && pathname === '/api/config') {
            const body = await this.parseJsonBody(req);
            this.worker.updateConfig(body);
            this.sendJson(res, 200, {
              success: true,
              message: 'Configuración del firmador actualizada correctamente',
              data: this.worker.getConfig(),
            });
            return;
          }

          // 2.2 Gestión de Tarea Programada de Windows (Task Scheduler)
          if (req.method === 'GET' && pathname === '/api/service/task-status') {
            const isInstalled = await this.checkScheduledTaskStatus();
            this.sendJson(res, 200, { success: true, isInstalled });
            return;
          }

          if (req.method === 'POST' && pathname === '/api/service/install-task') {
            const result = await this.installScheduledTask();
            this.sendJson(res, result.success ? 200 : 500, result);
            return;
          }

          if (req.method === 'POST' && pathname === '/api/service/uninstall-task') {
            const result = await this.uninstallScheduledTask();
            this.sendJson(res, result.success ? 200 : 500, result);
            return;
          }

          // 3. Cuadrante Superior Izquierdo: Información del Certificado
          if (req.method === 'GET' && pathname === '/api/certificate') {
            const cert = await P12Service.getActiveCertificate();
            this.sendJson(res, 200, {
              success: true,
              data: {
                id: cert.idRecord,
                name: cert.certName,
                desde: cert.validFrom.toISOString().split('T')[0],
                hasta: cert.validTo.toISOString().split('T')[0],
                restan: cert.daysRemaining,
                subject: cert.subject,
                issuer: cert.issuer,
              },
            });
            return;
          }

          if (req.method === 'POST' && pathname === '/api/certificate/reload') {
            P12Service.clearCache();
            const cert = await P12Service.getActiveCertificate(true);
            this.sendJson(res, 200, { success: true, message: 'Certificado recargado en memoria', data: cert });
            return;
          }

          // 4. Cuadrante Superior Derecho: Información del Token DGII
          if (req.method === 'GET' && pathname === '/api/token') {
            const tokenInfo = await TokenManagerService.readTokenFromDb();
            this.sendJson(res, 200, {
              success: true,
              data: tokenInfo
                ? {
                    token: tokenInfo.token,
                    tokenShort: `${tokenInfo.token.substring(0, 15)}...${tokenInfo.token.substring(tokenInfo.token.length - 15)}`,
                    desde: tokenInfo.expedido.toTimeString().split(' ')[0],
                    hasta: tokenInfo.expira.toTimeString().split(' ')[0],
                    restan: tokenInfo.minutesRemaining,
                    isValid: tokenInfo.minutesRemaining > 0,
                  }
                : {
                    token: 'Sin token activo',
                    tokenShort: '---',
                    desde: '--:--:--',
                    hasta: '--:--:--',
                    restan: 0,
                    isValid: false,
                  },
            });
            return;
          }

          // 5. Cuadrante Central: Facturas e-CF (Bandeja en Vivo de las últimas 48h)
          if (req.method === 'GET' && pathname === '/api/invoices') {
            const limit = parseInt(url.searchParams.get('limit') || '50', 10);
            const statusFilter = url.searchParams.get('status');

            let whereClause = "WHERE i.active = 'Y' AND i.date_process >= DATEADD(day, -2, GETDATE())";
            if (statusFilter && statusFilter !== 'ALL') {
              whereClause += ` AND i.C_Posted = '${statusFilter}'`;
            }

            const invoices = await DatabasePool.query(`
              SELECT TOP ${limit}
                     i.id_record,
                     i.doc_id,
                     i.NumAtCard AS ref,
                     i.ecf,
                     FORMAT(i.ecf_vence, 'yyyy-MM-dd') AS vence,
                     i.ecf_type AS dt,
                     i.ecf_print_pages AS pp,
                     COALESCE(i.xml_security_code, '') AS security_code,
                     FORMAT(i.xml_file_sign_date, 'yyyy-MM-dd HH:mm:ss') AS sign_date,
                     COALESCE(i.xml_track_id, '') AS track_id,
                     COALESCE(NULLIF(i.xml_track_response, ''), i.xml_response, '') AS api_response,
                     COALESCE(i.xml_ecf_status_code, '') AS status_code,
                     COALESCE(i.xml_ecf_status_name, '') AS status_name,
                     i.C_Posted,
                     FORMAT(i.datetime_process, 'yyyy-MM-dd HH:mm:ss') AS datetime_process
                FROM cms.dbo.ecf_xml_invoice i
               ${whereClause}
               ORDER BY i.id_record DESC
            `);

            this.sendJson(res, 200, { success: true, count: invoices.length, data: invoices });
            return;
          }

          // 6. Detalle XML de una factura específica
          if (req.method === 'GET' && pathname.startsWith('/api/invoices/') && pathname.endsWith('/xml')) {
            const parts = pathname.split('/');
            const idRecord = parts[3];

            const row = await DatabasePool.queryFirstRow(`
              SELECT id_record, doc_id, ecf, xml_file, xml_file_signed, xml_file_compact, xml_file_compact_signed,
                     xml_security_code, xml_file_qrcode, xml_track_response, xml_response
                FROM cms.dbo.ecf_xml_invoice
               WHERE id_record = ${idRecord}
            `);

            if (!row) {
              this.sendJson(res, 404, { success: false, message: 'Factura no encontrada' });
              return;
            }

            this.sendJson(res, 200, { success: true, data: row });
            return;
          }

          // 7. Cuadrante Inferior Derecho: e-CF Counter (Secuencias y Semáforos)
          if (req.method === 'GET' && pathname === '/api/counter') {
            const counters = await DatabasePool.query(`
              SELECT t.id_record,
                     'E' + t.ecf_type_id AS ecf,
                     t.ecf_type_alias AS nombre,
                     COALESCE(a.disponibles, 0) AS restan,
                     t.ecf_type_min_yellow AS min_yellow,
                     t.ecf_type_min_red AS min_red
                FROM cms.dbo.ecf_type t
           LEFT JOIN (SELECT c.serie, SUM(c.disponibles) AS disponibles
                        FROM (SELECT id_carga, serie, final - contador AS disponibles
                                FROM cms.dbo.carga_ncf
                               WHERE serie IN ('E31','E32','E44','E45')
                                 AND contador < final
                           UNION ALL
                              SELECT [Code] AS id_carga,
                                     (U_SERIE + U_TIPO_COMPROBANTE) AS serie,
                                     U_Final - U_Secuencial AS disponibles
                                FROM SBO_AGROFEM.dbo.[@COMPROBANTES]
                               WHERE U_SERIE = 'E'
                                 AND U_TIPO_COMPROBANTE IN (33, 34, 41, 43)
                                 AND U_Secuencial < U_Final
                             ) c
                    GROUP BY c.serie
                     ) a ON (a.serie = 'E' + t.ecf_type_id)
               WHERE t.active = 'Y'
               ORDER BY t.ecf_type_order
            `);

            // Mapear alertas visuales (green, yellow, red)
            const processedCounters = counters.map((c: any) => {
              const restan = Number(c.restan);
              const minYellow = Number(c.min_yellow);
              const minRed = Number(c.min_red);

              let alertLevel: 'green' | 'yellow' | 'red' = 'green';
              if (restan <= minRed) {
                alertLevel = 'red';
              } else if (restan <= minYellow) {
                alertLevel = 'yellow';
              }

              return {
                id: c.id_record,
                ecf: c.ecf,
                nombre: c.nombre,
                restan,
                minYellow,
                minRed,
                alertLevel,
              };
            });

            this.sendJson(res, 200, { success: true, data: processedCounters });
            return;
          }

          // Servir archivos estáticos del Frontend (UI Desktop)
          if (!pathname.startsWith('/api/')) {
            const served = await this.serveStaticFile(pathname, res);
            if (served) return;
          }

          // Ruta no encontrada
          this.sendJson(res, 404, { success: false, message: `Ruta ${pathname} no encontrada` });
        } catch (err: any) {
          console.error(`[ApiServer Error en ${pathname}]:`, err.message);
          this.sendJson(res, 500, { success: false, error: err.message });
        }
      });

      this.server.listen(this.port, () => {
        console.log(`[ApiServer]: Servidor HTTP local escuchando en http://localhost:${this.port}`);
        resolve();
      });
    });
  }

  public stop(): Promise<void> {
    return new Promise((resolve) => {
      if (this.server) {
        this.server.close(() => {
          console.log('[ApiServer]: Servidor HTTP detenido.');
          resolve();
        });
      } else {
        resolve();
      }
    });
  }

  private async serveStaticFile(reqPath: string, res: http.ServerResponse): Promise<boolean> {
    try {
      const normalizedPath = reqPath === '/' ? '/index.html' : reqPath;
      const filePath = path.join(this.frontendDistPath, normalizedPath);

      if (!filePath.startsWith(this.frontendDistPath)) {
        return false; // Prevenir path traversal
      }

      if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
        const ext = path.extname(filePath).toLowerCase();
        const mimeTypes: Record<string, string> = {
          '.html': 'text/html; charset=utf-8',
          '.js': 'application/javascript; charset=utf-8',
          '.css': 'text/css; charset=utf-8',
          '.json': 'application/json',
          '.png': 'image/png',
          '.jpg': 'image/jpeg',
          '.svg': 'image/svg+xml',
          '.ico': 'image/x-icon',
          '.woff': 'font/woff',
          '.woff2': 'font/woff2',
        };
        const contentType = mimeTypes[ext] || 'application/octet-stream';
        const fileContent = fs.readFileSync(filePath);
        res.writeHead(200, { 'Content-Type': contentType });
        res.end(fileContent);
        return true;
      }

      // SPA fallback a index.html
      const indexPath = path.join(this.frontendDistPath, 'index.html');
      if (fs.existsSync(indexPath)) {
        const indexContent = fs.readFileSync(indexPath);
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(indexContent);
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  private parseJsonBody<T = any>(req: http.IncomingMessage): Promise<T> {
    return new Promise((resolve, reject) => {
      let body = '';
      req.on('data', (chunk) => (body += chunk));
      req.on('end', () => {
        try {
          resolve(body ? JSON.parse(body) : ({} as T));
        } catch {
          reject(new Error('Formato JSON inválido'));
        }
      });
      req.on('error', reject);
    });
  }

  private async checkScheduledTaskStatus(): Promise<boolean> {
    try {
      const { stdout } = await execAsync('schtasks /query /tn "Sentry_Firmador_DGII"');
      return stdout.includes('Sentry_Firmador_DGII');
    } catch {
      return false;
    }
  }

  private async installScheduledTask(): Promise<{ success: boolean; message: string }> {
    try {
      const baseDir = path.resolve(process.cwd(), '..');
      const vbsPath = path.join(baseDir, 'firmador_silencioso.vbs');
      const cmd = `schtasks /create /tn "Sentry_Firmador_DGII" /tr "wscript.exe \\"${vbsPath}\\"" /sc ONLOGON /rl HIGHEST /f`;
      await execAsync(cmd);
      return { success: true, message: 'Tarea de inicio automático programada con éxito en Windows Task Scheduler' };
    } catch (err: any) {
      return { success: false, message: `Error al registrar tarea: ${err.message}` };
    }
  }

  private async uninstallScheduledTask(): Promise<{ success: boolean; message: string }> {
    try {
      await execAsync('schtasks /delete /tn "Sentry_Firmador_DGII" /f');
      return { success: true, message: 'Tarea programada eliminada de Windows' };
    } catch (err: any) {
      return { success: false, message: `Error al eliminar tarea: ${err.message}` };
    }
  }

  private sendJson(res: http.ServerResponse, status: number, data: any): void {
    res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(data));
  }
}
