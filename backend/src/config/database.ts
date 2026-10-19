import sql from 'mssql';
import { config } from './env.js';

export class DatabasePool {
  private static pool: sql.ConnectionPool | null = null;
  private static isConnecting: boolean = false;

  public static async getPool(): Promise<sql.ConnectionPool> {
    if (this.pool && this.pool.connected) {
      return this.pool;
    }

    if (this.isConnecting) {
      // Esperar hasta que se complete la conexión si ya está en progreso
      while (this.isConnecting) {
        await new Promise((resolve) => setTimeout(resolve, 50));
      }
      if (this.pool && this.pool.connected) {
        return this.pool;
      }
    }

    this.isConnecting = true;
    try {
      const sqlConfig: sql.config = {
        server: config.database.server,
        port: config.database.port,
        user: config.database.user,
        password: config.database.password,
        database: config.database.database,
        options: {
          encrypt: config.database.options.encrypt,
          trustServerCertificate: config.database.options.trustServerCertificate,
          enableArithAbort: config.database.options.enableArithAbort,
          requestTimeout: 30000,
          connectTimeout: 15000,
        },
        pool: {
          max: config.database.pool.max,
          min: config.database.pool.min,
          idleTimeoutMillis: config.database.pool.idleTimeoutMillis,
          acquireTimeoutMillis: config.database.pool.acquireTimeoutMillis,
        },
      };

      const pool = new sql.ConnectionPool(sqlConfig);

      pool.on('error', (err) => {
        console.error('[SQL Server Pool Error]:', err.message);
      });

      await pool.connect();
      this.pool = pool;
      console.log(`[SQL Server]: Conexión exitosa a ${config.database.server}:${config.database.port}/${config.database.database}`);
      return this.pool;
    } catch (error) {
      console.error('[SQL Server Connection Failed]:', error);
      throw error;
    } finally {
      this.isConnecting = false;
    }
  }

  public static async query<T = any>(queryText: string, params?: Record<string, { type: sql.ISqlType; value: any }>): Promise<T[]> {
    const pool = await this.getPool();
    const request = pool.request();

    if (params) {
      for (const [key, param] of Object.entries(params)) {
        request.input(key, param.type, param.value);
      }
    }

    const result = await request.query<T>(queryText);
    return result.recordset;
  }

  public static async queryFirstRow<T = any>(queryText: string, params?: Record<string, { type: sql.ISqlType; value: any }>): Promise<T | null> {
    const rows = await this.query<T>(queryText, params);
    return rows.length > 0 ? rows[0] : null;
  }

  public static async checkHealth(): Promise<{ status: 'healthy' | 'unhealthy'; serverTime?: Date; error?: string }> {
    try {
      const row = await this.queryFirstRow<{ alive: number; serverTime: Date }>('SELECT 1 AS alive, GETDATE() AS serverTime');
      if (row && row.alive === 1) {
        return { status: 'healthy', serverTime: row.serverTime };
      }
      return { status: 'unhealthy', error: 'No se obtuvo respuesta válida' };
    } catch (err: any) {
      return { status: 'unhealthy', error: err.message };
    }
  }

  public static async close(): Promise<void> {
    if (this.pool) {
      try {
        await this.pool.close();
        this.pool = null;
        console.log('[SQL Server]: Pool de conexiones cerrado correctamente');
      } catch (err) {
        console.error('[SQL Server]: Error al cerrar el pool:', err);
      }
    }
  }
}
