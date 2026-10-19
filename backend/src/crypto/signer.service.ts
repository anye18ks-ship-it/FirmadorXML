import { SignedXml } from 'xml-crypto';
import { DOMParser, XMLSerializer, type Document } from '@xmldom/xmldom';
import { P12Service, CertificateInfo } from './p12.service.js';
import { XmlGeneratorService } from '../xml/xml-generator.service.js';

export interface SignResult {
  signedXml: string;
  securityCode: string;
  fechaHoraFirma: string;
  qrCodeUrl: string;
}

export class SignerService {
  /**
   * Firma digitalmente un e-CF o RFCE bajo el estándar oficial DGII (XMLDSig RSA-SHA256 con Digest SHA-256 y C14N)
   */
  public static async signECF(
    xmlContent: string,
    catalogType: 'ECF' | 'RFCE' = 'ECF',
    fechaHoraFirmaParam?: string,
    customCert?: CertificateInfo
  ): Promise<SignResult> {
    const certInfo = customCert || (await P12Service.getActiveCertificate());

    // 1. Obtener o calcular FechaHoraFirma
    const fechaHoraFirma = fechaHoraFirmaParam || this.formatCurrentDateForDGII();

    // 2. Parsear XML para inyectar <FechaHoraFirma> si es ECF
    const parser = new DOMParser();
    const doc = parser.parseFromString(xmlContent, 'text/xml');
    const root = doc.documentElement;
    if (!root) {
      throw new Error('Estructura XML inválida: no se encontró el elemento raíz');
    }

    if (catalogType === 'ECF') {
      const fechaNode = doc.createElement('FechaHoraFirma');
      fechaNode.appendChild(doc.createTextNode(fechaHoraFirma));
      root.appendChild(fechaNode);
    }

    const serializer = new XMLSerializer();
    const xmlToSign = serializer.serializeToString(doc);

    // 3. Configurar XMLDSig con especificaciones oficiales DGII
    const sig = new SignedXml({
      privateKey: certInfo.privateKeyPem,
      signatureAlgorithm: 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256',
      canonicalizationAlgorithm: 'http://www.w3.org/TR/2001/REC-xml-c14n-20010315',
      getKeyInfoContent: () => `<X509Data><X509Certificate>${certInfo.certBase64}</X509Certificate></X509Data>`,
    });

    sig.addReference({
      xpath: '/*',
      transforms: ['http://www.w3.org/2000/09/xmldsig#enveloped-signature'],
      digestAlgorithm: 'http://www.w3.org/2001/04/xmlenc#sha256',
      isEmptyUri: true,
    });

    sig.computeSignature(xmlToSign, {
      location: {
        reference: '/*',
        action: 'append',
      },
    });

    const rawSignedXml = sig.getSignedXml();
    const formattedSignedXml = XmlGeneratorService.formatXml(rawSignedXml);

    // 4. Extraer primeros 6 caracteres de <SignatureValue> como Código de Seguridad DGII
    const signatureMatch = rawSignedXml.match(/<SignatureValue>([^<]+)<\/SignatureValue>/);
    const signatureValue = signatureMatch ? signatureMatch[1].replace(/\s+/g, '') : '';
    const securityCode = signatureValue.substring(0, 6);

    // 5. Construir enlace para el Timbre Fiscal QR
    const qrCodeUrl = this.buildQrUrl(doc, securityCode, fechaHoraFirma, catalogType);

    return {
      signedXml: formattedSignedXml,
      securityCode,
      fechaHoraFirma,
      qrCodeUrl,
    };
  }

  /**
   * Firma la Semilla DGII para autenticación
   */
  public static async signSeed(seedXml: string, customCert?: CertificateInfo): Promise<string> {
    const certInfo = customCert || (await P12Service.getActiveCertificate());

    const sig = new SignedXml({
      privateKey: certInfo.privateKeyPem,
      signatureAlgorithm: 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256',
      canonicalizationAlgorithm: 'http://www.w3.org/TR/2001/REC-xml-c14n-20010315',
      getKeyInfoContent: () => `<X509Data><X509Certificate>${certInfo.certBase64}</X509Certificate></X509Data>`,
    });

    sig.addReference({
      xpath: '/*',
      transforms: ['http://www.w3.org/2000/09/xmldsig#enveloped-signature'],
      digestAlgorithm: 'http://www.w3.org/2001/04/xmlenc#sha256',
      isEmptyUri: true,
    });

    sig.computeSignature(seedXml, {
      location: {
        reference: '/*',
        action: 'append',
      },
    });

    return XmlGeneratorService.formatXml(sig.getSignedXml());
  }

  /**
   * Construye la URL del timbre fiscal QR
   */
  private static buildQrUrl(doc: Document, securityCode: string, fechaHoraFirma: string, catalogType: string): string {
    const getNodeValue = (xpathName: string): string => {
      const parts = xpathName.split('/');
      let curr: any = doc.documentElement;
      for (const p of parts) {
        if (!curr) return '';
        const found = Array.from(curr.childNodes).find((c: any) => c.nodeName === p);
        curr = found || null;
      }
      return curr && curr.textContent ? curr.textContent.trim() : '';
    };

    if (catalogType === 'RFCE') {
      const rncEmisor = getNodeValue('Encabezado/Emisor/RNCEmisor');
      const encf = getNodeValue('Encabezado/IdDoc/eNCF');
      const montoTotal = getNodeValue('Encabezado/Totales/MontoTotal');
      return `https://fc.dgii.gov.do/eCF/ConsultaTimbreFC?RncEmisor=${rncEmisor}&ENCF=${encf}&MontoTotal=${montoTotal}&CodigoSeguridad=${securityCode}`;
    }

    const rncEmisor = getNodeValue('Encabezado/Emisor/RNCEmisor');
    const rncComprador = getNodeValue('Encabezado/Comprador/RNCComprador');
    const encf = getNodeValue('Encabezado/IdDoc/eNCF');
    const fechaEmision = getNodeValue('Encabezado/Emisor/FechaEmision');
    const montoTotal = getNodeValue('Encabezado/Totales/MontoTotal');
    const fechaFirmaEncoded = encodeURIComponent(fechaHoraFirma);

    let url = `https://ecf.dgii.gov.do/eCF/ConsultaTimbre?RncEmisor=${rncEmisor}`;
    if (rncComprador) url += `&RncComprador=${rncComprador}`;
    url += `&ENCF=${encf}&FechaEmision=${fechaEmision}&MontoTotal=${montoTotal}&FechaFirma=${fechaFirmaEncoded}&CodigoSeguridad=${securityCode}`;

    return url;
  }

  /**
   * Formatea la fecha y hora actual según el estándar DGII: dd-MM-yyyy HH:mm:ss
   */
  public static formatCurrentDateForDGII(date = new Date()): string {
    const pad = (n: number) => String(n).padStart(2, '0');
    const day = pad(date.getDate());
    const month = pad(date.getMonth() + 1);
    const year = date.getFullYear();
    const hours = pad(date.getHours());
    const minutes = pad(date.getMinutes());
    const seconds = pad(date.getSeconds());
    return `${day}-${month}-${year} ${hours}:${minutes}:${seconds}`;
  }
}
