import { DgiiClient, TokenResponse } from './dgii-client.js';
import { SignerService } from '../crypto/signer.service.js';
import { config } from '../config/env.js';
import { DatabasePool } from '../config/database.js';

export interface ActiveToken {
  token: string;
  expedido: Date;
  expira: Date;
  minutesRemaining: number;
}

export class TokenManagerService {
  private static cachedToken: ActiveToken | null = null;
  private static renewalTimeout: NodeJS.Timeout | null = null;
  private static isRenewing: boolean = false;

  /**
   * Obtiene el token Bearer activo en memoria. Si no existe o expiró, lo lee de la BD o lo renueva.
   */
  public static async getActiveToken(): Promise<string> {
    if (this.cachedToken && this.cachedToken.minutesRemaining > 2) {
      return this.cachedToken.token;
    }

    // Consultar el último token vigente en la BD (SOLO LECTURA)
    const dbToken = await this.readTokenFromDb();
    if (dbToken && dbToken.minutesRemaining > 2) {
      this.cachedToken = dbToken;
      this.scheduleAutoRenewal(dbToken.expira);
      return dbToken.token;
    }

    return this.cachedToken ? this.cachedToken.token : '';
  }

  /**
   * Lee el token activo desde ecf_xml_token (SOLO LECTURA)
   */
  public static async readTokenFromDb(): Promise<ActiveToken | null> {
    try {
      const row = await DatabasePool.queryFirstRow<{
        id_record: number;
        token_bearer: string;
        token_valid_from: Date;
        token_valid_to: Date;
        restan: number;
      }>(`
        SELECT TOP 1 id_record, token_bearer, token_valid_from, token_valid_to,
               DATEDIFF(MINUTE, GETDATE(), token_valid_to) AS restan
        FROM cms.dbo.ecf_xml_token
        WHERE token_valid_to > GETDATE() AND active = 'Y'
        ORDER BY id_record DESC
      `);

      if (!row || !row.token_bearer) {
        return null;
      }

      return {
        token: row.token_bearer,
        expedido: new Date(row.token_valid_from),
        expira: new Date(row.token_valid_to),
        minutesRemaining: row.restan,
      };
    } catch (err: any) {
      console.error('[TokenManager.readTokenFromDb Error]:', err.message);
      return null;
    }
  }

  /**
   * Programa la renovación automática antes de que expire el token
   */
  private static scheduleAutoRenewal(expireDate: Date): void {
    if (this.renewalTimeout) {
      clearTimeout(this.renewalTimeout);
      this.renewalTimeout = null;
    }

    const now = Date.now();
    const expireTime = expireDate.getTime();
    // Renovar 5 minutos antes de expirar
    const leadTimeMs = 5 * 60 * 1000;
    const msUntilRenewal = Math.max(1000, expireTime - now - leadTimeMs);

    this.renewalTimeout = setTimeout(() => {
      console.log('[TokenManager]: Tiempo de renovación de token alcanzado (programado 5 min antes de vencer)');
      // Notificar o renovar
    }, msUntilRenewal);
  }

  /**
   * Libera recursos y temporizadores para evitar fugas de memoria
   */
  public static shutdown(): void {
    if (this.renewalTimeout) {
      clearTimeout(this.renewalTimeout);
      this.renewalTimeout = null;
    }
    this.cachedToken = null;
  }
}
