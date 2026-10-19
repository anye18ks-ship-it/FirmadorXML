import forge from 'node-forge';
import { DatabasePool } from '../config/database.js';

export interface CertificateInfo {
  idRecord: number;
  certName: string;
  privateKeyPem: string;
  certPem: string;
  certBase64: string; // Base64 del certificado X.509 sin headers PEM (para <X509Certificate>)
  validFrom: Date;
  validTo: Date;
  daysRemaining: number;
  subject: string;
  issuer: string;
}

export class P12Service {
  private static cachedCert: CertificateInfo | null = null;
  private static lastLoadTime: number = 0;
  private static readonly CACHE_TTL_MS = 60 * 60 * 1000; // 1 hora de caché en memoria

  /**
   * Carga el certificado activo desde la base de datos (SOLO LECTURA) y lo mantiene en memoria segura.
   * Evita releer el binario en cada factura, eliminando sobrecarga de CPU y fugas de memoria.
   */
  public static async getActiveCertificate(forceReload = false): Promise<CertificateInfo> {
    const now = Date.now();
    if (!forceReload && this.cachedCert && now - this.lastLoadTime < this.CACHE_TTL_MS) {
      return this.cachedCert;
    }

    const row = await DatabasePool.queryFirstRow<{
      id_record: number;
      cert_name: string;
      cert_file: Buffer;
      cert_key: string;
      cert_valid_from: Date;
      cert_valid_to: Date;
    }>(`
      SELECT TOP 1 id_record, cert_name, cert_file, cert_key, cert_valid_from, cert_valid_to
      FROM cms.dbo.ecf_certificate
      WHERE active = 'Y' AND cert_valid_to > GETDATE()
      ORDER BY id_record DESC
    `);

    if (!row) {
      throw new Error('No se encontró ningún certificado digital activo y vigente en la tabla ecf_certificate');
    }

    const certInfo = this.parseP12(row.cert_file, row.cert_key, row.id_record, row.cert_name);
    this.cachedCert = certInfo;
    this.lastLoadTime = now;
    console.log(`[P12Service]: Certificado digital cargado y cacheado en memoria: "${certInfo.certName}" (Expira: ${certInfo.validTo.toISOString().split('T')[0]}, Días restantes: ${certInfo.daysRemaining})`);
    return certInfo;
  }

  /**
   * Parsea un buffer PKCS#12 (.p12 / .pfx) utilizando node-forge de forma agnóstica
   */
  public static parseP12(p12Buffer: Buffer, password: string, idRecord = 0, certName = 'manual.p12'): CertificateInfo {
    const p12Der = forge.util.createBuffer(p12Buffer.toString('binary'));
    const p12Asn1 = forge.asn1.fromDer(p12Der);
    const p12 = forge.pkcs12.pkcs12FromAsn1(p12Asn1, password);

    // 1. Extraer la Llave Privada
    let privateKeyPem = '';
    const keyBags = p12.getBags({ bagType: forge.pki.oids.pkcs8ShroudedKeyBag });
    const keyBag = keyBags[forge.pki.oids.pkcs8ShroudedKeyBag]?.[0];
    if (keyBag && keyBag.key) {
      privateKeyPem = forge.pki.privateKeyToPem(keyBag.key);
    } else {
      // Intentar con keyBag normal
      const normalKeyBags = p12.getBags({ bagType: forge.pki.oids.keyBag });
      const normalKeyBag = normalKeyBags[forge.pki.oids.keyBag]?.[0];
      if (normalKeyBag && normalKeyBag.key) {
        privateKeyPem = forge.pki.privateKeyToPem(normalKeyBag.key);
      }
    }

    if (!privateKeyPem) {
      throw new Error('No se pudo extraer la clave privada RSA del contenedor PKCS#12');
    }

    // 2. Extraer el Certificado X.509
    const certBags = p12.getBags({ bagType: forge.pki.oids.certBag });
    const certBagList = certBags[forge.pki.oids.certBag];
    if (!certBagList || certBagList.length === 0) {
      throw new Error('No se encontró ningún certificado X.509 en el contenedor PKCS#12');
    }

    // El primer certBag generalmente corresponde al certificado del emisor
    const primaryCert = certBagList[0].cert;
    if (!primaryCert) {
      throw new Error('Estructura de certificado inválida en certBag');
    }

    const certPem = forge.pki.certificateToPem(primaryCert);
    const certDer = forge.asn1.toDer(forge.pki.certificateToAsn1(primaryCert)).getBytes();
    const certBase64 = forge.util.encode64(certDer);

    const validFrom = primaryCert.validity.notBefore;
    const validTo = primaryCert.validity.notAfter;
    const now = new Date();
    const diffTime = validTo.getTime() - now.getTime();
    const daysRemaining = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

    // Formatear subject e issuer
    const subject = primaryCert.subject.attributes.map((a: any) => `${a.shortName || a.name}=${a.value}`).join(', ');
    const issuer = primaryCert.issuer.attributes.map((a: any) => `${a.shortName || a.name}=${a.value}`).join(', ');

    return {
      idRecord,
      certName,
      privateKeyPem,
      certPem,
      certBase64,
      validFrom,
      validTo,
      daysRemaining,
      subject,
      issuer,
    };
  }

  /**
   * Limpia la caché en memoria cuando el usuario actualiza o cambia el certificado
   */
  public static clearCache(): void {
    this.cachedCert = null;
    this.lastLoadTime = 0;
    console.log('[P12Service]: Caché de certificado invalidada');
  }
}
