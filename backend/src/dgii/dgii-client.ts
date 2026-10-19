import { request, FormData } from 'undici';
import { XMLParser } from 'fast-xml-parser';

export interface SeedResponse {
  rawXml: string;
  valor: string;
  fecha: string;
}

export interface TokenResponse {
  rawXml: string;
  token: string;
  expedido: string;
  expira: string;
  isValid: boolean;
}

export interface SendEcfResponse {
  rawXml: string;
  trackId: string;
  isSuccess: boolean;
  statusCode: string;
  statusName: string;
  error?: string;
}

export interface TrackStatusResponse {
  rawXml: string;
  trackId: string;
  codigo: string; // '1' = Aceptado, '2' = Rechazado, '3' = En Proceso, '0' = No encontrado, '-99' = Error red
  estado: string; // 'Aceptado', 'Rechazado', 'En Proceso'
  rnc: string;
  encf: string;
  secuenciaUtilizada: boolean;
  mensajes: Array<{ codigo: string; valor: string }>;
  isAccepted: boolean;
}

export class DgiiClient {
  private static parser = new XMLParser({
    ignoreAttributes: false,
    attributeNamePrefix: '@_',
  });

  /**
   * Obtiene la Semilla de autenticación desde el Web Service de la DGII
   * Endpoint: GET {baseUrl}/autenticacion/api/semilla
   */
  public static async getSeed(baseUrl: string): Promise<SeedResponse> {
    const url = this.normalizeUrl(baseUrl, 'autenticacion/api/Autenticacion/Semilla');
    try {
      const response = await request(url, {
        method: 'GET',
        headers: {
          'Accept': 'application/xml',
          'Cache-Control': 'no-cache',
        },
        headersTimeout: 15000,
        bodyTimeout: 15000,
      });

      if (response.statusCode !== 200) {
        throw new Error(`Error obteniendo semilla: HTTP ${response.statusCode}`);
      }

      const rawXml = await response.body.text();
      const parsed = this.parser.parse(rawXml);
      const root = parsed.SemillaModel || parsed.semilla || parsed;

      return {
        rawXml,
        valor: String(root.valor || ''),
        fecha: String(root.fecha || ''),
      };
    } catch (err: any) {
      console.error(`[DgiiClient.getSeed Error]:`, err.message);
      throw err;
    }
  }

  /**
   * Valida la semilla firmada para obtener el Token Bearer de sesión
   * Endpoint: POST {baseUrl}/autenticacion/api/validarsemilla (multipart/form-data)
   */
  public static async validateSeed(baseUrl: string, signedSeedXml: string): Promise<TokenResponse> {
    const url = this.normalizeUrl(baseUrl, 'autenticacion/api/Autenticacion/ValidarSemilla');
    try {
      const form = new FormData();
      const blob = new Blob([signedSeedXml], { type: 'application/xml' });
      form.append('xml', blob, 'Sem.xml');

      const response = await request(url, {
        method: 'POST',
        headers: {
          'Accept': 'application/xml',
          'Cache-Control': 'no-cache',
        },
        body: form,
        headersTimeout: 20000,
        bodyTimeout: 20000,
      });

      const rawXml = await response.body.text();
      const parsed = this.parser.parse(rawXml);
      const root = parsed.RespuestaAutenticacion || parsed;

      const token = String(root.token || '');
      const expedido = String(root.expedido || '');
      const expira = String(root.expira || '');

      return {
        rawXml,
        token,
        expedido,
        expira,
        isValid: token.length > 0 && response.statusCode === 200,
      };
    } catch (err: any) {
      console.error(`[DgiiClient.validateSeed Error]:`, err.message);
      throw err;
    }
  }

  /**
   * Transmite el e-CF firmado a los servidores de recepción de la DGII
   * Endpoint: POST {baseUrl}/recepcion/api/facturaselectronicas
   */
  public static async sendECF(
    baseUrl: string,
    signedXml: string,
    bearerToken: string,
    fileName: string
  ): Promise<SendEcfResponse> {
    const url = this.normalizeUrl(baseUrl, 'recepcion/api/facturaselectronicas');
    try {
      const form = new FormData();
      const blob = new Blob([signedXml], { type: 'application/xml' });
      form.append('xml', blob, `${fileName}.xml`);

      const response = await request(url, {
        method: 'POST',
        headers: {
          'Accept': 'application/xml',
          'Authorization': `Bearer ${bearerToken}`,
          'Cache-Control': 'no-cache',
        },
        body: form,
        headersTimeout: 30000,
        bodyTimeout: 30000,
      });

      const rawXml = await response.body.text();
      const parsed = this.parser.parse(rawXml);
      const root = parsed.RespuestaRecepcion || parsed;

      const trackId = String(root.TrackId || '');
      const isSuccess = response.statusCode === 200 && trackId.length > 0 && trackId !== '00000000-0000-0000-0000-000000000000';

      return {
        rawXml,
        trackId: trackId || '00000000-0000-0000-0000-000000000000',
        isSuccess,
        statusCode: isSuccess ? '-101' : '-99',
        statusName: isSuccess ? 'Firmado y Enviado' : 'Quantum',
      };
    } catch (err: any) {
      console.error(`[DgiiClient.sendECF Error]:`, err.message);
      return {
        rawXml: '',
        trackId: '00000000-0000-0000-0000-000000000000',
        isSuccess: false,
        statusCode: '-99',
        statusName: 'WebServiceError',
        error: err.message,
      };
    }
  }

  /**
   * Consulta el estatus del e-CF por TrackId con aplicación de reglas de negocio oficiales
   * Endpoint: GET {baseUrl}/ConsultaResultado/api/Consultas/Estado?TrackId={trackId}
   */
  public static async getTrackStatus(baseUrl: string, trackId: string, bearerToken: string): Promise<TrackStatusResponse> {
    const url = this.normalizeUrl(baseUrl, `ConsultaResultado/api/Consultas/Estado?TrackId=${trackId}`);
    try {
      const response = await request(url, {
        method: 'GET',
        headers: {
          'Accept': 'application/xml',
          'Authorization': `Bearer ${bearerToken}`,
          'Cache-Control': 'no-cache',
        },
        headersTimeout: 15000,
        bodyTimeout: 15000,
      });

      const rawXml = await response.body.text();
      return this.parseTrackStatusXml(rawXml, trackId);
    } catch (err: any) {
      console.error(`[DgiiClient.getTrackStatus Error]:`, err.message);
      return {
        rawXml: '',
        trackId,
        codigo: '-99',
        estado: 'WebServiceError',
        rnc: '',
        encf: '',
        secuenciaUtilizada: false,
        mensajes: [{ codigo: '-99', valor: err.message }],
        isAccepted: false,
      };
    }
  }

  /**
   * Parsea la respuesta XML de TrackId y aplica las reglas de negocio DGII (ej. Códigos 75 y 1209)
   */
  public static parseTrackStatusXml(rawXml: string, trackId: string): TrackStatusResponse {
    try {
      const parsed = this.parser.parse(rawXml);
      const root = parsed.RespuestaConsultaTrackId || parsed.Respuesta || parsed;

      let codigo = String(root.Codigo || '-99');
      let estado = String(root.Estado || 'WebServiceError');
      const rnc = String(root.Rnc || '');
      const encf = String(root.Encf || '');
      const secuenciaUtilizadaStr = String(root.SecuenciaUtilizada || 'false').toLowerCase();
      const secuenciaUtilizada = secuenciaUtilizadaStr === 'true';

      const mensajes: Array<{ codigo: string; valor: string }> = [];
      const msjRoot = root.Mensajes?.Mensaje || root.Mensajes?.MensajeRespuesta;
      if (Array.isArray(msjRoot)) {
        for (const m of msjRoot) {
          mensajes.push({ codigo: String(m.Codigo || ''), valor: String(m.Valor || '') });
        }
      } else if (msjRoot) {
        mensajes.push({ codigo: String(msjRoot.Codigo || ''), valor: String(msjRoot.Valor || '') });
      }

      // =========================================================================
      // REGLA CRÍTICA DGII: Sobrescritura de Falso Rechazo (Códigos 75 y 1209)
      // Si la DGII responde Rechazado pero SecuenciaUtilizada = false con código 75 o 1209,
      // significa que ya fue procesada previamente con éxito durante una caída transitoria de red.
      // Se fuerza a Aceptado (Código 1, C_Posted = 'Y').
      // =========================================================================
      const hasDuplicateSequenceError = mensajes.some(
        (m) => (m.codigo === '75' || m.codigo === '1209') && !secuenciaUtilizada
      );

      if (hasDuplicateSequenceError) {
        console.warn(`[DgiiClient]: Sobrescritura de Falso Rechazo detectada para eNCF ${encf} (Código 75/1209). Forzando a ACEPTADO.`);
        codigo = '1';
        estado = 'Aceptado';
      }

      return {
        rawXml,
        trackId,
        codigo,
        estado,
        rnc,
        encf,
        secuenciaUtilizada,
        mensajes,
        isAccepted: codigo === '1' || estado.toLowerCase() === 'aceptado',
      };
    } catch (err: any) {
      return {
        rawXml,
        trackId,
        codigo: '-99',
        estado: 'ParseError',
        rnc: '',
        encf: '',
        secuenciaUtilizada: false,
        mensajes: [{ codigo: '-99', valor: 'Error parseando XML de respuesta DGII' }],
        isAccepted: false,
      };
    }
  }

  private static normalizeUrl(baseUrl: string, endpoint: string): string {
    const cleanBase = baseUrl.endsWith('/') ? baseUrl : `${baseUrl}/`;
    return `${cleanBase}${endpoint.startsWith('/') ? endpoint.slice(1) : endpoint}`;
  }
}
