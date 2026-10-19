import { DOMImplementation, XMLSerializer, type Document, type Element } from '@xmldom/xmldom';
import { DatabasePool } from '../config/database.js';

export interface XmlGeneratorOptions {
  docId: number | string;
  ecfType: string; // '31', '32', '34', etc.
  catalogType?: 'ECF' | 'RFCE'; // Default 'ECF'
  isCompact?: number; // 0 para completo, 1 para compacto
  securityCode?: string;
  printPages?: string;
}

export interface BridgeRow {
  id_record: number;
  grand_parent: string | null;
  parent: string | null;
  tag_parent_id: number;
  tag_parent_name: string;
  tag_type_id: number;
  tag_type_name: string;
  tag_number: number;
  tag_name: string;
  tag_to_remove: string | null;
  xmlTag: string;
  m_id_record: number;
  xml_value: string | null;
}

export class XmlGeneratorService {
  /**
   * Genera el documento XML e-CF consumiendo dbo.GetInvoiceDataForXML y ecf_xml_catalog.
   * Reproduce fielmente la reconstrucción jerárquica de nodos y la política de limpieza tag_to_remove.
   */
  public static async generateXmlFromDb(options: XmlGeneratorOptions): Promise<string> {
    const {
      docId,
      ecfType,
      catalogType = 'ECF',
      isCompact = 0,
      securityCode = '',
      printPages = '',
    } = options;

    // Consulta puente idéntica a xmlCreator.java (SOLO LECTURA)
    const sqlQuery = `
      SELECT x.id_record,
             (SELECT TOP 1 tag_parent_name 
                FROM cms.dbo.ecf_xml_catalog 
               WHERE tag_name = y.tag_parent_name AND catalog_type = y.catalog_type) AS grand_parent,
             y.tag_parent_name AS parent,
             x.tag_parent_id,
             x.tag_parent_name,
             x.tag_type_id,
             x.tag_type_name,
             x.tag_number,
             x.tag_name,
             x.tag_to_remove,
             m.xmlTag,
             m.id_record AS m_id_record,
             CASE WHEN m.xmlTag = 'eCF' THEN NULL ELSE m.xml_value END AS xml_value
        FROM cms.dbo.ecf_xml_catalog x
   LEFT JOIN cms.dbo.ecf_xml_catalog y 
          ON (y.tag_name = x.tag_parent_name AND y.tag_group_id = x.tag_group_id AND y.catalog_type = x.catalog_type)
   LEFT JOIN cms.dbo.GetInvoiceDataForXML(${docId}, '${ecfType}', ${isCompact}, '${securityCode}', '${printPages}') m 
          ON (m.xmlTag = x.tag_name AND m.group_id = x.tag_group_id)
       WHERE x.active = 'Y'
         AND COALESCE(m.id_record, 0) > 0
         AND COALESCE(NULLIF(m.xml_value, '#e'), '') != ''
         AND x.catalog_type = '${catalogType}'
       ORDER BY m.id_record
    `;

    const rows = await DatabasePool.query<BridgeRow>(sqlQuery);
    if (!rows || rows.length === 0) {
      throw new Error(`No se encontraron datos para generar XML (DocID: ${docId}, Tipo: ${ecfType})`);
    }

    return this.buildXmlDocument(rows);
  }

  /**
   * Construye el documento DOM XML y lo serializa a string formateado
   */
  public static buildXmlDocument(rows: BridgeRow[]): string {
    const impl = new DOMImplementation();
    const doc = impl.createDocument('', '', null);
    const elementMap = new Map<string, Element>();

    for (const row of rows) {
      const grandParent = (row.grand_parent || '').trim();
      const parent = (row.parent || '').trim();
      const parentElementName = (row.tag_parent_name || '').trim();
      const elementName = (row.tag_name || '').trim();
      const elementValue = row.xml_value !== null && row.xml_value !== undefined ? String(row.xml_value) : '';
      const tagToRemove = (row.tag_to_remove || '').trim();

      let superParent: Element | null = null;

      // 1. Manejo de Gran Padre (GrandParent)
      if (grandParent !== '') {
        let grandElement = elementMap.get(grandParent) || null;
        if (!grandElement) {
          grandElement = this.createOrGetNode(doc, null, grandParent, '');
          elementMap.set(grandParent, grandElement);
        }
        superParent = grandElement;
      }

      // 2. Manejo de Padre Superior (Parent)
      if (parent !== '') {
        let parentElement = elementMap.get(parent) || null;
        if (!parentElement) {
          parentElement = this.createOrGetNode(doc, superParent, parent, '');
          elementMap.set(parent, parentElement);
        }
        superParent = parentElement;
      }

      // 3. Manejo de Padre Directo (tag_parent_name)
      if (parentElementName !== '') {
        let tagParentElement = elementMap.get(parentElementName) || null;
        if (!tagParentElement) {
          tagParentElement = this.createOrGetNode(doc, superParent, parentElementName, '');
          elementMap.set(parentElementName, tagParentElement);
        }
        superParent = tagParentElement;
      }

      // 4. Creación del nodo hoja o contenedor actual (tag_name)
      if (elementName !== '') {
        const newElement = this.createOrGetNode(doc, superParent, elementName, elementValue);
        elementMap.set(elementName, newElement);
      }

      // 5. Manejo de limpieza de nodos repetibles (tag_to_remove)
      // Permite que múltiples ítems, formas de pago, etc. instancien nuevos elementos
      if (tagToRemove !== '') {
        const tags = tagToRemove.split(':');
        for (const tag of tags) {
          const trimmedTag = tag.trim();
          if (trimmedTag && elementMap.has(trimmedTag)) {
            elementMap.delete(trimmedTag);
          }
        }
      }
    }

    const serializer = new XMLSerializer();
    const rawXml = serializer.serializeToString(doc);

    // Formatear con declaración XML estándar UTF-8 e indentación de 3 espacios (idéntico a Java Transformer)
    return this.formatXml(rawXml);
  }

  private static createOrGetNode(doc: Document, parent: Element | null, tagName: string, value: string): Element {
    const element = doc.createElement(tagName);
    if (value !== '') {
      element.appendChild(doc.createTextNode(value));
    }

    if (parent === null) {
      if (!doc.documentElement) {
        doc.appendChild(element);
      } else {
        doc.documentElement.appendChild(element);
      }
    } else {
      parent.appendChild(element);
    }

    return element;
  }

  /**
   * Formateador XML determinista con indentación limpia (3 espacios)
   */
  public static formatXml(xmlString: string): string {
    const PADDING = '   '; // 3 espacios, idéntico al Transformer de Java
    const reg = /(>)(<)(\/*)/g;
    let formatted = '';
    let pad = 0;

    // Asegurar que no tenga declaración duplicada
    const cleanXml = xmlString.replace(/<\?xml[^>]*\?>\s*/i, '').trim();
    const xmlWithNewlines = cleanXml.replace(reg, '$1\r\n$2$3');
    const lines = xmlWithNewlines.split('\r\n');

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed) continue;

      let indent = 0;
      if (trimmed.match(/.+<\/\w[^>]*>$/)) {
        // Tag que abre y cierra en la misma línea: <Tag>Valor</Tag>
        indent = 0;
      } else if (trimmed.match(/^<\/\w/)) {
        // Tag de cierre: </Tag>
        if (pad !== 0) {
          pad -= 1;
        }
      } else if (trimmed.match(/^<\w[^>]*[^\/]>.*$/)) {
        // Tag de apertura: <Tag>
        indent = 1;
      } else {
        indent = 0;
      }

      formatted += PADDING.repeat(pad) + trimmed + '\r\n';
      pad += indent;
    }

    return `<?xml version = '1.0' encoding = 'UTF-8'?>\r\n${formatted.trimEnd()}`;
  }
}
