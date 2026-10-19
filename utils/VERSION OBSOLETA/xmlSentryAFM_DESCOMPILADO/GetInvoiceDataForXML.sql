









CREATE FUNCTION [dbo].[GetInvoiceDataForXML](@InvoiceID INT, @eCFType NVARCHAR(20), @Resumen INT, @pSecurityCode NVARCHAR(50) = '', @pPrintPages NVARCHAR(1) = '')
RETURNS TABLE
AS
RETURN (  

        --PARA COMPROBANTES FISCALES ELECTRONICOS COMPLETOS @Resumen = 0
     SELECT ecf.*
       FROM ( 
  
             --Encabezado
             SELECT ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'ECF' THEN 'ECF'
                        WHEN 'Version' THEN '1.0' 
                        WHEN 'TipoeCF' THEN i.ecf_type
                        WHEN 'eNCF' THEN i.ecf
                        WHEN 'FechaVencimientoSecuencia' THEN COALESCE(NULLIF(FORMAT(i.ecf_vence,'dd-MM-yyyy'),'01-01-1900'),'#e')
                        WHEN 'IndicadorNotaCredito' THEN '#e' --LOGICA PARA NOTA DE CREDITO
                        WHEN 'IndicadorMontoGravado' THEN CASE WHEN @eCFType IN (31,32,33,34,41,45) THEN '0' ELSE '#e' END -- (0) EL DEALLE DE LOS ITEM NO INCLUYE EL ITBIS
                        WHEN 'TipoIngresos' THEN CASE WHEN @eCFType IN (31,32,33,34,44,45,46) THEN '01' ELSE '#e' END -- (01) Ingresos por operaciones (No financieros).
                        WHEN 'TipoPago' THEN CAST(CASE WHEN F.ExtraDays <= 1 THEN 1 ELSE 2 END AS NVARCHAR(MAX)) -- 1:Contado | 2:Credio | 3:Gratuito
                        WHEN 'FechaLimitePago' THEN CASE WHEN F.ExtraDays > 1 THEN CASE WHEN @eCFType = 43 THEN '#e' ELSE FORMAT(f.DocDueDate,'dd-MM-yyyy') END ELSE '#e' END
                        WHEN 'TerminoPago' THEN CASE WHEN F.ExtraDays > 1 THEN CASE WHEN @eCFType IN ('31','32','33','41','44','45','46','47') THEN REPLACE(g.PymntGroup,'C - ','') ELSE '#e' END ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSOINV f
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = f.C_DocEntry AND i.ecf_type IN (31,32,44,45)) 
          LEFT JOIN cms.dbo.POSOCTG g ON (g.ExtraDays = f.ExtraDays /*AND g.ListNum = 2*/)
        CROSS APPLY (VALUES (1,'ECF'), (2,'Version'), (3,'TipoeCF'),(4,'eNCF'), (5,'FechaVencimientoSecuencia'),(6,'IndicadorNotaCredito'),(7,'IndicadorMontoGravado'),(8,'TipoIngresos'),(9,'TipoPago'),(10,'FechaLimitePago'),(11,'TerminoPago')) c (columnOrder,ColumnName)
              WHERE f.C_DocEntry = @InvoiceID
UNION ALL     --FORMAS DE PAGO
             SELECT 20 + ROW_NUMBER() OVER (ORDER BY s.id_diario_caja_det, c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                         WHEN 'FormaPago' THEN CAST(t.ecf_payform_id AS NVARCHAR(MAX))
                         WHEN 'MontoPago' THEN FORMAT(s.monto_caja,'0.00')
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSOINV f
         INNER JOIN cms.dbo.diario_caja_det s ON (s.id_documento = f.C_DocEntry AND s.docType = 'P')
          LEFT JOIN cms.dbo.ecf_payment_forms t ON (t.ecf_payform_sap = s.id_tipo_movimiento)
        CROSS APPLY (VALUES (1,'FormaPago'), (2,'MontoPago')) c (columnOrder,ColumnName)
              WHERE f.C_DocEntry = @InvoiceID
                AND @eCFType IN ('31','32','33','41','44','45','46','47')
UNION ALL    --TOTAL DE PAGINAS
             SELECT 40 + ROW_NUMBER() OVER (ORDER BY p.pages) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    'TotalPaginas' AS xmlTag,
                    FORMAT(p.pages,'0') AS xml_value
               FROM (SELECT CEILING(COUNT(d.C_Id) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS pages
                       FROM cms.dbo.POSINV1 d
                 INNER JOIN cms.dbo.POSOINV f ON (f.C_DocEntry = d.C_DocEntry)
                      WHERE d.C_DocEntry = @InvoiceID
                      GROUP BY f.C_DocEntry
                    ) p
              WHERE p.pages > 1
UNION ALL    --EMISOR & COMPRADOR
             SELECT 50 + ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'RNCEmisor' THEN d.RNC --PARA QUE SIEMPRE ENVIE EL RNC DE AGROFEM
                        WHEN 'RazonSocialEmisor' THEN razon_social
                        WHEN 'NombreComercial' THEN UPPER(CAST(d.descripcion AS NVARCHAR(100)))
                        WHEN 'DireccionEmisor' THEN d.direccion
                        WHEN 'TelefonoEmisor' THEN d.telefono1
                        WHEN 'CorreoEmisor' THEN d.email
                        WHEN 'WebSite' THEN d.web
                        WHEN 'NumeroFacturaInterna' THEN f.NumAtCard
                        WHEN 'FechaEmision' THEN FORMAT(f.DocDate,'dd-MM-yyyy')
                        WHEN 'RNCComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('31','32','33','34','41','44','45','46') THEN f.U_FacNit ELSE '#e' END ELSE CASE WHEN F.U_TNegocio = 3 THEN CASE WHEN @eCFType IN ('31','32','33','34','41','44','45','46') THEN '00000000000' ELSE '#e' END ELSE '#e' END END
                        WHEN 'RazonSocialComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('31','32','33','34','41','44','45','46') THEN f.CardName ELSE '#e' END ELSE CASE WHEN F.U_TNegocio = 3 THEN CASE WHEN @eCFType IN ('31','32','33','34','41','44','45','46') THEN f.CardName ELSE '#e' END ELSE '#e' END END 
                        WHEN 'DireccionComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('31','32','33','34','44','45','46') THEN SUBSTRING(COALESCE(NULLIF(f.Address2,''),'#e'),1,100) ELSE '#e' END ELSE '#e' END 
                        WHEN 'TelefonoAdicional' THEN '#e' --CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('31','32','33','34','44','45','46') THEN COALESCE(l.Cellular,l.phone1,l.phone2,'#e') ELSE '#e' END ELSE '#e' END 
                        WHEN 'CodigoInternoComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('31','32','33','34','44','45','46') THEN f.CardCode ELSE '#e' END ELSE '#e' END 
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.division d
	     INNER JOIN cms.dbo.serie s ON (s.id_division = d.id_division)
         INNER JOIN cms.dbo.POSOINV f ON (f.U_SCIASerie  = s.id_serie AND f.C_DocEntry = @InvoiceID)
          LEFT JOIN cms.dbo.POSOCRD l ON (l.CardCode = f.CardCode)
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = f.C_DocEntry AND i.ecf_type IN (31,32,44,45))
        CROSS APPLY (VALUES (1,'RNCEmisor'), (2,'RazonSocialEmisor'),(3,'NombreComercial'),(4,'DireccionEmisor'),(5,'TelefonoEmisor'),(6,'CorreoEmisor'),(7,'WebSite'),(8,'NumeroFacturaInterna'),(9,'FechaEmision'),(10,'RNCComprador'),(11,'RazonSocialComprador'),(12,'DireccionComprador'),(13,'TelefonoAdicional'),(14,'CodigoInternoComprador')) c (columnOrder,ColumnName)
UNION ALL    --TOTALES
             SELECT 100 + ROW_NUMBER() OVER (ORDER BY c.columnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'MontoGravadoTotal' THEN CASE WHEN a.monto_grabado > 0 THEN FORMAT(a.monto_grabado,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END END
                        WHEN 'MontoGravadoI1' THEN CASE WHEN a.monto_grabadoI1 > 0 THEN FORMAT(a.monto_grabadoI1,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI2' THEN CASE WHEN a.monto_grabadoI2 > 0 THEN FORMAT(a.monto_grabadoI2,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI3' THEN CASE WHEN a.monto_grabadoI3 > 0 THEN FORMAT(a.monto_grabadoI3,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END END
                        WHEN 'MontoExento' THEN CASE WHEN (a.monto_exento > 0 AND @eCFType IN ('31','32','33','34','41','43','44','45','47')) THEN FORMAT(a.monto_exento,'0.00') ELSE '#e' END
                        WHEN 'ITBIS1' THEN CASE WHEN a.itbis1 > 0 THEN FORMAT(a.itbis1,'00') ELSE '#e' END
                        WHEN 'ITBIS2' THEN CASE WHEN a.itbis2 > 0 THEN FORMAT(a.itbis2,'00') ELSE '#e' END
                        WHEN 'ITBIS3' THEN CASE WHEN a.itbis3 > 0 THEN FORMAT(a.itbis3,'0') ELSE CASE WHEN @eCFType IN ('46') THEN '0' ELSE '#e' END END
                        WHEN 'TotalITBIS' THEN CASE WHEN a.total_itbis > 0 THEN FORMAT(a.total_itbis,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN '0.00' ELSE '#e' END END
                        WHEN 'TotalITBIS1' THEN CASE WHEN a.total_itbis1 > 0 THEN FORMAT(a.total_itbis1,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS2' THEN CASE WHEN a.total_itbis2 > 0 THEN FORMAT(a.total_itbis2,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS3' THEN CASE WHEN a.total_itbis3 > 0 THEN FORMAT(a.total_itbis3,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN '0.00' ELSE '#e' END END
                        WHEN 'MontoTotal' THEN CASE WHEN a.monto_total > 0 THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END
                        WHEN 'TotalITBISRetenido' THEN CASE WHEN @eCFType IN ('41') THEN FORMAT(0,'0.00') ELSE '#e' END
                        WHEN 'TotalISRRetencion' THEN CASE WHEN @eCFType IN ('41','47') THEN FORMAT(0,'0.00') ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM (SELECT CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabado,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (4) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_exento,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (1) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis1,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (2) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis2,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (3) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis3,
                            CAST(SUM(d.LineTotal+d.VatSum) AS NUMERIC(12,2)) AS monto_total
                       FROM cms.dbo.POSOINV f
                 INNER JOIN cms.dbo.POSINV1 d ON (d.C_DocEntry = f.C_DocEntry)
                 INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
                      WHERE f.C_DocEntry = @InvoiceID
                    ) a
        CROSS APPLY (VALUES (1,'MontoGravadoTotal'), (2,'MontoGravadoI1'), (3,'MontoGravadoI2'),(4,'MontoGravadoI3'), (5,'MontoExento'),(6,'ITBIS1'),(7,'ITBIS2'),(8,'ITBIS3'),(9,'TotalITBIS'),(10,'TotalITBIS1'),(11,'TotalITBIS2'),(12,'TotalITBIS3'),(13,'MontoTotal'),(14,'TotalITBISRetenido'),(15,'TotalISRRetencion')) c (columnOrder,ColumnName)
UNION ALL
         --2 - DetallesItems
         SELECT 1000 + ROW_NUMBER() OVER (ORDER BY d.LineNum, c.ColumnOrder) AS id_record,
                2 AS group_id,
                'DetallesItem' AS group_name,
                c.ColumnName AS xmlTag,
                CAST(CASE c.ColumnName
                    WHEN 'NumeroLinea' THEN CAST(d.LineNum+1 AS NVARCHAR(MAX))
                    WHEN 'IndicadorFacturacion' THEN CAST( CASE WHEN @eCFType IN ('46') THEN 3 ELSE t.taxecf_id END AS NVARCHAR(MAX))
                    WHEN 'IndicadorAgenteRetencionoPercepcion' THEN CAST(CASE WHEN @eCFType IN ('41','47') THEN '1' ELSE '#e' END AS NVARCHAR(MAX))
                    WHEN 'MontoITBISRetenido' THEN CASE WHEN @eCFType IN ('41') THEN '0.00' ELSE '#e' END
                    WHEN 'MontoISRRetenido' THEN CASE WHEN @eCFType IN ('41','47') THEN '0.00' ELSE '#e' END
                    WHEN 'NombreItem' THEN CAST(d.Dscription AS NVARCHAR(MAX))
                    WHEN 'IndicadorBienoServicio' THEN CAST(CASE WHEN @eCFType IN ('41','47','43') THEN 2 ELSE CASE WHEN f.DocType = 'S' THEN 2 ELSE 1 END END AS NVARCHAR(MAX))
                    WHEN 'CantidadItem' THEN FORMAT(d.Quantity,'0.00')
                    WHEN 'UnidadMedida' THEN CAST(u.ecfunit_id AS NVARCHAR(MAX))
                    WHEN 'PrecioUnitarioItem' THEN FORMAT(d.PriceBefDi,'0.00')
                    WHEN 'DescuentoMonto' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT((d.PriceBefDi*(d.DiscPrcnt/100))*d.Quantity,'0.00') ELSE '#e' END
                    WHEN 'TipoSubDescuento' THEN CASE WHEN d.DiscPrcnt > 0 THEN '%' ELSE '#e' END
                    WHEN 'SubDescuentoPorcentaje' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT(d.DiscPrcnt,'0.00') ELSE '#e' END
                    WHEN 'MontoSubDescuento' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT((d.PriceBefDi*(d.DiscPrcnt/100))*d.Quantity,'0.00') ELSE '#e' END
                    WHEN 'MontoItem' THEN FORMAT(d.LineTotal,'0.00')
                END AS NVARCHAR(MAX)) AS xml_value
           FROM cms.dbo.POSOINV f 
     INNER JOIN cms.dbo.POSINV1 d ON (d.C_DocEntry = f.C_DocEntry)
     INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
     INNER JOIN cms.dbo.ecf_units u ON (u.ecfsapunit_name = d.unitMsr)
    CROSS APPLY (VALUES (1,'NumeroLinea'), (2,'IndicadorFacturacion'), (3,'IndicadorAgenteRetencionoPercepcion'), (4,'MontoITBISRetenido'), (4,'MontoISRRetenido'), (5,'NombreItem'),(6,'IndicadorBienoServicio'), (7,'CantidadItem'),(8,'UnidadMedida'),(9,'PrecioUnitarioItem'),(10,'DescuentoMonto'),(11,'TipoSubDescuento'),(12,'SubDescuentoPorcentaje'),(13,'MontoSubDescuento'),(14,'MontoItem')) c (columnOrder,ColumnName)
          WHERE f.C_DocEntry = @InvoiceID
UNION ALL
             --PAGINACION
             SELECT 100000+ROW_NUMBER() OVER (ORDER BY a.pagina_numero, c.columnOrder) AS id_record,
                    5 AS group_id,
                    'Paginacion' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'PaginaNo' THEN CAST(pagina_numero AS NVARCHAR(MAX))
                        WHEN 'NoLineaDesde' THEN CAST(linea_desde AS NVARCHAR(MAX))
                        WHEN 'NoLineaHasta' THEN CAST(linea_hasa AS NVARCHAR(MAX))
                        WHEN 'SubtotalMontoGravadoPagina' THEN CASE WHEN a.monto_grabado > 0 THEN FORMAT(a.monto_grabado,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado1Pagina' THEN CASE WHEN a.monto_grabadoI1 > 0 THEN FORMAT(a.monto_grabadoI1,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado2Pagina' THEN CASE WHEN a.monto_grabadoI2 > 0 THEN FORMAT(a.monto_grabadoI2,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado3Pagina' THEN CASE WHEN a.monto_grabadoI3 > 0 THEN FORMAT(a.monto_grabadoI3,'0.00') ELSE '#e' END
                        WHEN 'SubtotalExentoPagina' THEN CASE WHEN a.monto_exento > 0 THEN FORMAT(a.monto_exento,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbisPagina' THEN CASE WHEN a.total_itbis > 0 THEN FORMAT(a.total_itbis,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis1Pagina' THEN CASE WHEN a.total_itbis1 > 0 THEN FORMAT(a.total_itbis1,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis2Pagina' THEN CASE WHEN a.total_itbis2 > 0 THEN FORMAT(a.total_itbis2,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis3Pagina' THEN CASE WHEN a.total_itbis3 > 0 THEN FORMAT(a.total_itbis3,'0.00') ELSE '#e' END
                        WHEN 'MontoSubtotalPagina' THEN CASE WHEN a.monto_total > 0 THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM (SELECT group_id AS pagina_numero,
                            MIN(w.numero_linea) AS linea_desde,
                            MAX(w.numero_linea) AS linea_hasa,
                            CAST(SUM(monto_grabado) AS NUMERIC(12,2)) AS monto_grabado,
                            CAST(SUM(monto_grabadoI1) AS NUMERIC(12,2)) AS monto_grabadoI1,
                            CAST(SUM(monto_grabadoI2) AS NUMERIC(12,2)) AS monto_grabadoI2,
                            CAST(SUM(monto_grabadoI3) AS NUMERIC(12,2)) AS monto_grabadoI3,
                            CAST(SUM(monto_exento) AS NUMERIC(12,2)) AS monto_exento,
                            CAST(SUM(total_itbis) AS NUMERIC(12,2)) AS total_itbis,
                            CAST(SUM(total_itbis1) AS NUMERIC(12,2)) AS total_itbis1,
                            CAST(SUM(total_itbis2) AS NUMERIC(12,2)) AS total_itbis2,
                            CAST(SUM(total_itbis3) AS NUMERIC(12,2)) AS total_itbis3,
                            CAST(SUM(monto_total) AS NUMERIC(12,2)) AS monto_total
                       FROM (SELECT (d.linenum+1) AS numero_linea,
                                    CEILING(ROW_NUMBER() OVER(ORDER BY d.linenum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS group_id,
                                    SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.LineTotal ELSE 0 END) AS monto_grabado,
                                    SUM(CASE WHEN t.taxecf_id IN (1) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI1,
                                    SUM(CASE WHEN t.taxecf_id IN (2) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI2,
                                    SUM(CASE WHEN t.taxecf_id IN (3) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI3,
                                    SUM(CASE WHEN t.taxecf_id IN (4) THEN d.LineTotal ELSE 0 END) AS monto_exento,
                                    MAX(CASE WHEN t.taxecf_id IN (1) THEN d.VatPrcnt ELSE 0 END) AS itbis1,
                                    MAX(CASE WHEN t.taxecf_id IN (2) THEN d.VatPrcnt ELSE 0 END) AS itbis2,
                                    MAX(CASE WHEN t.taxecf_id IN (3) THEN d.VatPrcnt ELSE 0 END) AS itbis3,
                                    SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.VatSum ELSE 0 END) AS total_itbis,
                                    SUM(CASE WHEN t.taxecf_id IN (1) THEN d.VatSum ELSE 0 END) AS total_itbis1,
                                    SUM(CASE WHEN t.taxecf_id IN (2) THEN d.VatSum ELSE 0 END) AS total_itbis2,
                                    SUM(CASE WHEN t.taxecf_id IN (3) THEN d.VatSum ELSE 0 END) AS total_itbis3,
                                    SUM(d.LineTotal+d.VatSum) AS monto_total
                               FROM cms.dbo.POSOINV f
                         INNER JOIN cms.dbo.POSINV1 d ON (d.C_DocEntry = f.C_DocEntry)
                         INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
                              WHERE f.C_DocEntry = @InvoiceID
                              GROUP BY d.linenum
                            ) w
                      GROUP BY w.group_id
                    ) a
        CROSS APPLY (VALUES (1,'PaginaNo'), (2,'NoLineaDesde'), (3,'NoLineaHasta'),(4,'SubtotalMontoGravadoPagina'), (5,'SubtotalMontoGravado1Pagina'),(6,'SubtotalMontoGravado2Pagina'),(7,'SubtotalMontoGravado3Pagina'),(8,'SubtotalExentoPagina'),(9,'SubtotalItbisPagina'),(10,'SubtotalItbis1Pagina'),(11,'SubtotalItbis2Pagina'),(12,'SubtotalItbis3Pagina'),(13,'MontoSubtotalPagina')) c (columnOrder,ColumnName)
              WHERE (SELECT CEILING(COUNT(d.C_Id) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS pages FROM cms.dbo.POSINV1 d WHERE d.C_DocEntry = @InvoiceID) > 1
                AND @pPrintPages = 'Y'
            ) ecf 
        WHERE @Resumen = 0 AND @eCFType IN ('31','32','44','45')
          

UNION ALL 

        --PARA COMPROBANTES FISCALES ELECTRONICOS DE CONSUMO (FORMATO COMPACTO) @Resumen = 1
     SELECT ecf.*
       FROM ( 
  
             --Encabezado
             SELECT ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'RFCE' THEN 'RFCE'
                        WHEN 'Version' THEN '1.0' 
                        WHEN 'TipoeCF' THEN i.ecf_type
                        WHEN 'eNCF' THEN i.ecf
                        WHEN 'TipoIngresos' THEN '01' -- (01) Ingresos por operaciones (No financieros).
                        WHEN 'TipoPago' THEN CAST(CASE WHEN F.ExtraDays <= 1 THEN 1 ELSE 2 END AS NVARCHAR(MAX)) -- 1:Contado | 2:Credio | 3:Gratuito
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSOINV f
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = f.C_DocEntry AND i.ecf_type IN (31,32,44,45)) 
          LEFT JOIN cms.dbo.POSOCTG g ON (g.ExtraDays = f.ExtraDays /*AND g.ListNum = 2*/)
        CROSS APPLY (VALUES (1,'RFCE'), (2,'Version'), (3,'TipoeCF'),(4,'eNCF'),(5,'TipoIngresos'),(6,'TipoPago')) c (columnOrder,ColumnName)
              WHERE f.C_DocEntry = @InvoiceID
UNION ALL     --FORMAS DE PAGO
             SELECT 20 + ROW_NUMBER() OVER (ORDER BY s.id_diario_caja_det, c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                         WHEN 'FormaPago' THEN CAST(t.ecf_payform_id AS NVARCHAR(MAX))
                         WHEN 'MontoPago' THEN FORMAT(s.monto_caja,'0.00')
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSOINV f
         INNER JOIN cms.dbo.diario_caja_det s ON (s.id_documento = f.C_DocEntry AND s.docType = 'P')
          LEFT JOIN cms.dbo.ecf_payment_forms t ON (t.ecf_payform_sap = s.id_tipo_movimiento)
        CROSS APPLY (VALUES (1,'FormaPago'), (2,'MontoPago')) c (columnOrder,ColumnName)
              WHERE f.C_DocEntry = @InvoiceID
UNION ALL    --EMISOR & COMPRADOR
             SELECT 50 + ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'RNCEmisor' THEN d.RNC --PARA QUE SIEMPRE ENVIE EL RNC DE AGROFEM
                        WHEN 'RazonSocialEmisor' THEN razon_social
                        WHEN 'FechaEmision' THEN FORMAT(f.DocDate,'dd-MM-yyyy')
                        WHEN 'RNCComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN f.U_FacNit ELSE CASE WHEN F.U_TNegocio = 3 THEN '00000000000' ELSE '#e' END END
                        WHEN 'RazonSocialComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN f.CardName ELSE CASE WHEN F.U_TNegocio = 3 THEN f.CardName ELSE '#e' END END 
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.division d
	     INNER JOIN cms.dbo.serie s ON (s.id_division = d.id_division)
         INNER JOIN cms.dbo.POSOINV f ON (f.U_SCIASerie = s.id_serie AND f.C_DocEntry = @InvoiceID)
          LEFT JOIN cms.dbo.POSOCRD l ON (l.CardCode = f.CardCode)
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = f.C_DocEntry AND i.ecf_type IN (31,32,44,45))
        CROSS APPLY (VALUES (1,'RNCEmisor'), (2,'RazonSocialEmisor'),(3,'FechaEmision'),(4,'RNCComprador'),(5,'RazonSocialComprador')) c (columnOrder,ColumnName)
UNION ALL    --TOTALES
             SELECT 100 + ROW_NUMBER() OVER (ORDER BY c.columnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'MontoGravadoTotal' THEN CASE WHEN a.monto_grabado > 0 THEN FORMAT(a.monto_grabado,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI1' THEN CASE WHEN a.monto_grabadoI1 > 0 THEN FORMAT(a.monto_grabadoI1,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI2' THEN CASE WHEN a.monto_grabadoI2 > 0 THEN FORMAT(a.monto_grabadoI2,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI3' THEN CASE WHEN a.monto_grabadoI3 > 0 THEN FORMAT(a.monto_grabadoI3,'0.00') ELSE '#e' END
                        WHEN 'MontoExento' THEN CASE WHEN a.monto_exento > 0 THEN FORMAT(a.monto_exento,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS' THEN CASE WHEN a.total_itbis > 0 THEN FORMAT(a.total_itbis,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS1' THEN CASE WHEN a.total_itbis1 > 0 THEN FORMAT(a.total_itbis1,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS2' THEN CASE WHEN a.total_itbis2 > 0 THEN FORMAT(a.total_itbis2,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS3' THEN CASE WHEN a.total_itbis3 > 0 THEN FORMAT(a.total_itbis3,'0.00') ELSE '#e' END
                        WHEN 'MontoTotal' THEN CASE WHEN a.monto_total > 0 THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM (SELECT CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabado,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (4) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_exento,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (1) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis1,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (2) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis2,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (3) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis3,
                            CAST(SUM(d.LineTotal+d.VatSum) AS NUMERIC(12,2)) AS monto_total
                       FROM cms.dbo.POSOINV f
                 INNER JOIN cms.dbo.POSINV1 d ON (d.C_DocEntry = f.C_DocEntry)
                 INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
                      WHERE f.C_DocEntry = @InvoiceID
                    ) a
        CROSS APPLY (VALUES (1,'MontoGravadoTotal'), (2,'MontoGravadoI1'), (3,'MontoGravadoI2'),(4,'MontoGravadoI3'), (5,'MontoExento'),(6,'TotalITBIS'),(7,'TotalITBIS1'),(8,'TotalITBIS2'),(9,'TotalITBIS3'),(10,'MontoTotal')) c (columnOrder,ColumnName)
UNION ALL
         --1 - CodigoSeguridadeCF
             SELECT 200 AS id_record, --199 + ROW_NUMBER() OVER (ORDER BY i.id_record) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    'CodigoSeguridadeCF' AS xmlTag,
                    COALESCE(NULLIF(@pSecurityCode,''),'#e') AS xml_value
--               FROM cms.dbo.ecf_xml_invoice i
--              WHERE i.doc_id = @InvoiceID
            ) ecf 
        WHERE @Resumen = 1 AND @eCFType IN ('32')


UNION ALL

--NOTA DE CREDITO AGROFEM DESDE VENTAS
     SELECT ecf.*
       FROM ( 
  
             --Encabezado
             SELECT ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'ECF' THEN 'ECF'
                        WHEN 'Version' THEN '1.0' 
                        WHEN 'TipoeCF' THEN i.ecf_type
                        WHEN 'eNCF' THEN UPPER(i.ecf)
                        WHEN 'FechaVencimientoSecuencia' THEN COALESCE(NULLIF(FORMAT(i.ecf_vence,'dd-MM-yyyy'),'01-01-1900'),'#e')
                        WHEN 'IndicadorNotaCredito' THEN CASE WHEN DATEDIFF(DAY,t.U_FacFecha,f.DocDate) <= 30 THEN '0' ELSE '1' END --'#e' --LOGICA PARA NOTA DE CREDITO
                        WHEN 'IndicadorMontoGravado' THEN CASE WHEN @eCFType IN ('31','32','33','34','41','45') THEN '0' ELSE '#e' END -- (0) EL DEALLE DE LOS ITEM NO INCLUYE EL ITBIS
                        WHEN 'TipoIngresos' THEN CASE WHEN @eCFType IN ('31','32','33','34','44','45','46') THEN '01' ELSE '#e' END -- (01) Ingresos por operaciones (No financieros).
                        WHEN 'TipoPago' THEN CAST(CASE WHEN F.ExtraDays <= 1 THEN 1 ELSE 2 END AS NVARCHAR(MAX)) -- 1:Contado | 2:Credio | 3:Gratuito
                        WHEN 'FechaLimitePago' THEN CASE WHEN F.ExtraDays > 1 THEN CASE WHEN @eCFType IN ('43') THEN '#e' ELSE FORMAT(f.DocDueDate,'dd-MM-yyyy') END ELSE '#e' END
                        WHEN 'TerminoPago' THEN CASE WHEN F.ExtraDays > 1 THEN CASE WHEN @eCFType IN ('31','32','33','41','44','45','46','47') THEN REPLACE(g.PymntGroup,'C - ','') ELSE '#e' END ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSORIN f
         INNER JOIN cms.dbo.POSOINV t ON (t.U_FACNUM = f.U_NCO AND t.CANCELED = 'N')
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = f.C_DocEntry AND i.ecf_type IN (34)) 
          LEFT JOIN CMS.dbo.POSOCTG g ON (g.ExtraDays = f.ExtraDays /*AND g.ListNum = 2*/)
        CROSS APPLY (VALUES (1,'ECF'), (2,'Version'), (3,'TipoeCF'),(4,'eNCF'), (5,'FechaVencimientoSecuencia'),(6,'IndicadorNotaCredito'),(7,'IndicadorMontoGravado'),(8,'TipoIngresos'),(9,'TipoPago'),(10,'FechaLimitePago'),(11,'TerminoPago')) c (columnOrder,ColumnName)
              WHERE f.C_DocEntry = @InvoiceID 
UNION ALL     --FORMAS DE PAGO
             SELECT 20 + ROW_NUMBER() OVER (ORDER BY s.id_diario_caja_det, c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                         WHEN 'FormaPago' THEN CAST(t.ecf_payform_id AS NVARCHAR(MAX))
                         WHEN 'MontoPago' THEN FORMAT(s.monto_caja,'0.00')
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSOINV f
         INNER JOIN cms.dbo.diario_caja_det s ON (s.id_documento = f.C_DocEntry AND s.docType = 'P')
          LEFT JOIN cms.dbo.ecf_payment_forms t ON (t.ecf_payform_sap = s.id_tipo_movimiento)
        CROSS APPLY (VALUES (1,'FormaPago'), (2,'MontoPago')) c (columnOrder,ColumnName)
              WHERE f.C_DocEntry = @InvoiceID
                AND @eCFType IN ('31','32','33','41','44','45','46','47')
                AND f.C_Posted IN ('Y','N')
UNION ALL    --TOTAL DE PAGINAS
             SELECT 40 + ROW_NUMBER() OVER (ORDER BY p.pages) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    'TotalPaginas' AS xmlTag,
                    FORMAT(p.pages,'0') AS xml_value
               FROM (SELECT CEILING(COUNT(d.LineNum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS pages
                       FROM cms.dbo.POSRIN1 d
                 INNER JOIN cms.dbo.POSORIN f ON (f.C_DocEntry = d.C_DocEntry)
                      WHERE d.C_DocEntry = @InvoiceID
                      GROUP BY f.DocEntry 
                    ) p
              WHERE p.pages > 1
UNION ALL    --EMISOR & COMPRADOR
             SELECT 50 + ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'RNCEmisor' THEN d.RNC --PARA QUE SIEMPRE ENVIE EL RNC DE AGROFEM
                        WHEN 'RazonSocialEmisor' THEN razon_social
                        WHEN 'NombreComercial' THEN UPPER(CAST(d.descripcion AS NVARCHAR(100)))
                        WHEN 'DireccionEmisor' THEN d.direccion
                        WHEN 'TelefonoEmisor' THEN d.telefono1
                        WHEN 'CorreoEmisor' THEN d.email
                        WHEN 'WebSite' THEN d.web
                        WHEN 'NumeroFacturaInterna' THEN COALESCE(o.NumAtCard,'#e')
                        WHEN 'FechaEmision' THEN FORMAT(o.DocDate,'dd-MM-yyyy')
                        --WHEN 'RNCComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('34') OR (@eCFType IN ('34') AND f.DocTotal >= 250000) THEN f.U_FacNit ELSE '#e' END ELSE CASE WHEN F.U_TNegocio = 3 THEN CASE WHEN @eCFType IN ('34') OR (@eCFType IN ('34') AND f.DocTotal >= 250000) THEN '00000000000' ELSE '#e' END ELSE '#e' END END
                        WHEN 'RNCComprador' THEN CASE WHEN LEN(f.U_FacNit) IN (9,11) AND PATINDEX('%[^0-9]%', f.U_FacNit) = 0 THEN o.U_FacNit ELSE CASE WHEN f.U_TNegocio = 3 THEN '00000000000' ELSE '#e' END END
                        --WHEN 'RazonSocialComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('34') OR (@eCFType IN ('34') AND f.DocTotal >= 250000) THEN f.CardName ELSE '#e' END ELSE CASE WHEN F.U_TNegocio = 3 THEN CASE WHEN @eCFType IN ('34') OR (@eCFType IN ('34') AND f.DocTotal >= 250000) THEN f.CardName ELSE '#e' END ELSE '#e' END END 
                        WHEN 'RazonSocialComprador' THEN CASE WHEN LEN(f.U_FacNit) IN (9,11) AND PATINDEX('%[^0-9]%', f.U_FacNit) = 0 THEN o.CardName ELSE CASE WHEN f.U_TNegocio = 3 THEN o.CardName ELSE '#e' END END
                        WHEN 'DireccionComprador' THEN '#e' 
                        WHEN 'TelefonoAdicional' THEN '#e' 
                        WHEN 'CodigoInternoComprador' THEN CASE WHEN LEN(f.U_FacNit) IN (9,11) AND PATINDEX('%[^0-9]%', f.U_FacNit) = 0 THEN o.CardCode ELSE CASE WHEN f.U_TNegocio = 3 THEN o.CardCode ELSE '#e' END END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSORIN o
         INNER JOIN cms.dbo.POSOINV f ON (f.U_FACNUM = o.U_NCO AND f.CANCELED = 'N')
	     INNER JOIN cms.dbo.serie s ON (s.id_serie = f.U_SCIASerie)
         INNER JOIN cms.dbo.division d ON (d.id_division = s.id_division) 
          LEFT JOIN cms.dbo.POSOCRD l ON (l.CardCode = f.CardCode)
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = o.C_DocEntry AND i.ecf_type IN (34))
        CROSS APPLY (VALUES (1,'RNCEmisor'), (2,'RazonSocialEmisor'),(3,'NombreComercial'),(4,'DireccionEmisor'),(5,'TelefonoEmisor'),(6,'CorreoEmisor'),(7,'WebSite'),(8,'NumeroFacturaInterna'),(9,'FechaEmision'),(10,'RNCComprador'),(11,'RazonSocialComprador'),(12,'DireccionComprador'),(13,'TelefonoAdicional'),(14,'CodigoInternoComprador')) c (columnOrder,ColumnName)
              WHERE o.C_DocEntry = @InvoiceID
UNION ALL    --TOTALES
             SELECT 100 + ROW_NUMBER() OVER (ORDER BY c.columnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'MontoGravadoTotal' THEN CASE WHEN a.monto_grabado > 0 THEN FORMAT(a.monto_grabado,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END END
                        WHEN 'MontoGravadoI1' THEN CASE WHEN a.monto_grabadoI1 > 0 THEN FORMAT(a.monto_grabadoI1,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI2' THEN CASE WHEN a.monto_grabadoI2 > 0 THEN FORMAT(a.monto_grabadoI2,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI3' THEN CASE WHEN a.monto_grabadoI3 > 0 THEN FORMAT(a.monto_grabadoI3,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END END
                        WHEN 'MontoExento' THEN CASE WHEN (a.monto_exento > 0 AND @eCFType IN ('31','32','33','34','41','43','44','45','47')) THEN FORMAT(a.monto_exento,'0.00') ELSE '#e' END
                        WHEN 'ITBIS1' THEN CASE WHEN a.itbis1 > 0 THEN FORMAT(a.itbis1,'00') ELSE '#e' END
                        WHEN 'ITBIS2' THEN CASE WHEN a.itbis2 > 0 THEN FORMAT(a.itbis2,'00') ELSE '#e' END
                        WHEN 'ITBIS3' THEN CASE WHEN a.itbis3 > 0 THEN FORMAT(a.itbis3,'0') ELSE CASE WHEN @eCFType IN ('46') THEN '0' ELSE '#e' END END
                        WHEN 'TotalITBIS' THEN CASE WHEN a.total_itbis > 0 THEN FORMAT(a.total_itbis,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN '0.00' ELSE '#e' END END
                        WHEN 'TotalITBIS1' THEN CASE WHEN a.total_itbis1 > 0 THEN FORMAT(a.total_itbis1,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS2' THEN CASE WHEN a.total_itbis2 > 0 THEN FORMAT(a.total_itbis2,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS3' THEN CASE WHEN a.total_itbis3 > 0 THEN FORMAT(a.total_itbis3,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN '0.00' ELSE '#e' END END
                        WHEN 'MontoTotal' THEN CASE WHEN a.monto_total > 0 THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END
                        WHEN 'TotalITBISRetenido' THEN CASE WHEN @eCFType IN ('41') THEN FORMAT(0,'0.00') ELSE '#e' END
                        WHEN 'TotalISRRetencion' THEN CASE WHEN @eCFType IN ('41','47') THEN FORMAT(0,'0.00') ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM (SELECT CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabado,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (4) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_exento,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (1) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis1,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (2) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis2,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (3) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis3,
                            CAST(SUM(d.LineTotal+d.VatSum) AS NUMERIC(12,2)) AS monto_total
                       FROM cms.dbo.POSORIN f
                 INNER JOIN cms.dbo.POSRIN1 d ON (d.C_DocEntry = f.C_DocEntry)
                 INNER JOIN cms.dbo.POSOINV o ON (o.U_FACNUM = f.U_NCO AND o.CANCELED = 'N')
                 INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
                      WHERE f.C_DocEntry = @InvoiceID
                        --AND DATEDIFF(DAY, o.U_FacFecha,f.DocDate) <= 30
                    ) a
        CROSS APPLY (VALUES (1,'MontoGravadoTotal'), (2,'MontoGravadoI1'), (3,'MontoGravadoI2'),(4,'MontoGravadoI3'), (5,'MontoExento'),(6,'ITBIS1'),(7,'ITBIS2'),(8,'ITBIS3'),(9,'TotalITBIS'),(10,'TotalITBIS1'),(11,'TotalITBIS2'),(12,'TotalITBIS3'),(13,'MontoTotal'),(14,'TotalITBISRetenido'),(15,'TotalISRRetencion')) c (columnOrder,ColumnName)
UNION ALL
         --2 - DetallesItems
         SELECT 1000 + ROW_NUMBER() OVER (ORDER BY d.LineNum, c.ColumnOrder) AS id_record,
                2 AS group_id,
                'DetallesItem' AS group_name,
                c.ColumnName AS xmlTag,
                CAST(CASE c.ColumnName
                    WHEN 'NumeroLinea' THEN CAST(DENSE_RANK() OVER(PARTITION BY d.C_DocEntry ORDER BY d.LineNum) AS NVARCHAR(MAX)) --CAST(d.LineNum+1 AS NVARCHAR(MAX))
                    WHEN 'IndicadorFacturacion' THEN CAST( CASE WHEN @eCFType IN ('46') THEN 3 ELSE t.taxecf_id END AS NVARCHAR(MAX))
                    WHEN 'IndicadorAgenteRetencionoPercepcion' THEN CAST(CASE WHEN @eCFType IN ('41','47') THEN '1' ELSE '#e' END AS NVARCHAR(MAX))
                    WHEN 'MontoITBISRetenido' THEN CASE WHEN @eCFType IN ('41') THEN '0.00' ELSE '#e' END
                    WHEN 'MontoISRRetenido' THEN CASE WHEN @eCFType IN ('41','47') THEN '0.00' ELSE '#e' END
                    WHEN 'NombreItem' THEN CAST(COALESCE(d.Dscription,f.comments) AS NVARCHAR(MAX))
                    WHEN 'IndicadorBienoServicio' THEN CAST(CASE WHEN @eCFType IN ('41','47','43') THEN 2 ELSE  CASE WHEN f.DocType = 'S' THEN 2 ELSE 1 END END AS NVARCHAR(MAX))
                    WHEN 'CantidadItem' THEN FORMAT(COALESCE(NULLIF(d.Quantity,0),1),'0.00')
                    WHEN 'UnidadMedida' THEN COALESCE(CAST(u.ecfunit_id AS NVARCHAR(MAX)),'#e')
                    WHEN 'PrecioUnitarioItem' THEN FORMAT(d.PriceBefDi,'0.00')
                    WHEN 'DescuentoMonto' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT((d.PriceBefDi*(d.DiscPrcnt/100))*d.Quantity,'0.00') ELSE '#e' END
                    WHEN 'TipoSubDescuento' THEN CASE WHEN d.DiscPrcnt > 0 THEN '%' ELSE '#e' END
                    WHEN 'SubDescuentoPorcentaje' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT(d.DiscPrcnt,'0.00') ELSE '#e' END
                    WHEN 'MontoSubDescuento' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT((d.PriceBefDi*(d.DiscPrcnt/100))*d.Quantity,'0.00') ELSE '#e' END
                    WHEN 'MontoItem' THEN FORMAT(d.LineTotal,'0.00')
                END AS NVARCHAR(MAX)) AS xml_value
           FROM cms.dbo.POSRIN1 d
     INNER JOIN cms.dbo.POSORIN f ON (f.C_DocEntry = d.C_DocEntry)
     INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
      LEFT JOIN cms.dbo.ecf_units u ON (u.ecfsapunit_name = d.unitMsr)
    CROSS APPLY (VALUES (1,'NumeroLinea'), (2,'IndicadorFacturacion'), (3,'IndicadorAgenteRetencionoPercepcion'), (4,'MontoITBISRetenido'), (4,'MontoISRRetenido'), (5,'NombreItem'),(6,'IndicadorBienoServicio'), (7,'CantidadItem'),(8,'UnidadMedida'),(9,'PrecioUnitarioItem'),(10,'DescuentoMonto'),(11,'TipoSubDescuento'),(12,'SubDescuentoPorcentaje'),(13,'MontoSubDescuento'),(14,'MontoItem')) c (columnOrder,ColumnName)
          WHERE d.C_DocEntry = @InvoiceID
UNION ALL
             --PAGINACION
             SELECT 100000+ROW_NUMBER() OVER (ORDER BY a.pagina_numero, c.columnOrder) AS id_record,
                    5 AS group_id,
                    'Paginacion' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'PaginaNo' THEN CAST(pagina_numero AS NVARCHAR(MAX))
                        WHEN 'NoLineaDesde' THEN CAST(linea_desde AS NVARCHAR(MAX))
                        WHEN 'NoLineaHasta' THEN CAST(linea_hasa AS NVARCHAR(MAX))
                        WHEN 'SubtotalMontoGravadoPagina' THEN CASE WHEN a.monto_grabado > 0 THEN FORMAT(a.monto_grabado,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado1Pagina' THEN CASE WHEN a.monto_grabadoI1 > 0 THEN FORMAT(a.monto_grabadoI1,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado2Pagina' THEN CASE WHEN a.monto_grabadoI2 > 0 THEN FORMAT(a.monto_grabadoI2,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado3Pagina' THEN CASE WHEN a.monto_grabadoI3 > 0 THEN FORMAT(a.monto_grabadoI3,'0.00') ELSE '#e' END
                        WHEN 'SubtotalExentoPagina' THEN CASE WHEN a.monto_exento > 0 THEN FORMAT(a.monto_exento,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbisPagina' THEN CASE WHEN a.total_itbis > 0 THEN FORMAT(a.total_itbis,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis1Pagina' THEN CASE WHEN a.total_itbis1 > 0 THEN FORMAT(a.total_itbis1,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis2Pagina' THEN CASE WHEN a.total_itbis2 > 0 THEN FORMAT(a.total_itbis2,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis3Pagina' THEN CASE WHEN a.total_itbis3 > 0 THEN FORMAT(a.total_itbis3,'0.00') ELSE '#e' END
                        WHEN 'MontoSubtotalPagina' THEN CASE WHEN a.monto_total > 0 THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM (SELECT group_id AS pagina_numero,
                            MIN(w.numero_linea) AS linea_desde,
                            MAX(w.numero_linea) AS linea_hasa,
                            CAST(SUM(monto_grabado) AS NUMERIC(12,2)) AS monto_grabado,
                            CAST(SUM(monto_grabadoI1) AS NUMERIC(12,2)) AS monto_grabadoI1,
                            CAST(SUM(monto_grabadoI2) AS NUMERIC(12,2)) AS monto_grabadoI2,
                            CAST(SUM(monto_grabadoI3) AS NUMERIC(12,2)) AS monto_grabadoI3,
                            CAST(SUM(monto_exento) AS NUMERIC(12,2)) AS monto_exento,
                            CAST(SUM(total_itbis) AS NUMERIC(12,2)) AS total_itbis,
                            CAST(SUM(total_itbis1) AS NUMERIC(12,2)) AS total_itbis1,
                            CAST(SUM(total_itbis2) AS NUMERIC(12,2)) AS total_itbis2,
                            CAST(SUM(total_itbis3) AS NUMERIC(12,2)) AS total_itbis3,
                            CAST(SUM(monto_total) AS NUMERIC(12,2)) AS monto_total
                       FROM (SELECT (d.linenum+1) AS numero_linea,
                                    CEILING(ROW_NUMBER() OVER(ORDER BY d.linenum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS group_id,
                                    SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.LineTotal ELSE 0 END) AS monto_grabado,
                                    SUM(CASE WHEN t.taxecf_id IN (1) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI1,
                                    SUM(CASE WHEN t.taxecf_id IN (2) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI2,
                                    SUM(CASE WHEN t.taxecf_id IN (3) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI3,
                                    SUM(CASE WHEN t.taxecf_id IN (4) THEN d.LineTotal ELSE 0 END) AS monto_exento,
                                    MAX(CASE WHEN t.taxecf_id IN (1) THEN d.VatPrcnt ELSE 0 END) AS itbis1,
                                    MAX(CASE WHEN t.taxecf_id IN (2) THEN d.VatPrcnt ELSE 0 END) AS itbis2,
                                    MAX(CASE WHEN t.taxecf_id IN (3) THEN d.VatPrcnt ELSE 0 END) AS itbis3,
                                    SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.VatSum ELSE 0 END) AS total_itbis,
                                    SUM(CASE WHEN t.taxecf_id IN (1) THEN d.VatSum ELSE 0 END) AS total_itbis1,
                                    SUM(CASE WHEN t.taxecf_id IN (2) THEN d.VatSum ELSE 0 END) AS total_itbis2,
                                    SUM(CASE WHEN t.taxecf_id IN (3) THEN d.VatSum ELSE 0 END) AS total_itbis3,
                                    SUM(d.LineTotal+d.VatSum) AS monto_total
                               FROM cms.dbo.POSORIN f
                         INNER JOIN cms.dbo.POSRIN1 d ON (d.C_DocEntry = f.C_DocEntry)
                         INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
                              WHERE f.C_DocEntry = @InvoiceID
                              GROUP BY d.linenum
                            ) w
                      GROUP BY w.group_id
                    ) a
        CROSS APPLY (VALUES (1,'PaginaNo'), (2,'NoLineaDesde'), (3,'NoLineaHasta'),(4,'SubtotalMontoGravadoPagina'), (5,'SubtotalMontoGravado1Pagina'),(6,'SubtotalMontoGravado2Pagina'),(7,'SubtotalMontoGravado3Pagina'),(8,'SubtotalExentoPagina'),(9,'SubtotalItbisPagina'),(10,'SubtotalItbis1Pagina'),(11,'SubtotalItbis2Pagina'),(12,'SubtotalItbis3Pagina'),(13,'MontoSubtotalPagina')) c (columnOrder,ColumnName)
              WHERE (SELECT CEILING(COUNT(d.LineNum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS pages FROM cms.dbo.POSRIN1 d WHERE d.C_DocEntry = @InvoiceID) > 1
                AND @pPrintPages = 'Y'
UNION ALL
             SELECT 500000 + ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    6 AS group_id,
                    'InformacionReferencia' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'NCFModificado' THEN UPPER(o.U_NCO)
                        WHEN 'FechaNCFModificado' THEN FORMAT(f.DocDate,'dd-MM-yyyy')
                        --WHEN 'CodigoModificacion' THEN CAST(3 AS NVARCHAR(1))
                        --SI EL MONTO DE LA NC ES IGUAL AL THE DE FACTURA ENTONCES ES PARA ANULAR FACTURA (1) DE LO CONTRARIO ES PARA MODIFICAR (3)
                        WHEN 'CodigoModificacion' THEN CAST(CASE WHEN (f.DocTotal-o.DocTotal) = 0 THEN 1 ELSE 3 END AS NVARCHAR(1))
                        WHEN 'RazonModificacion' THEN SUBSTRING(o.Comments,1,90) 
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSORIN o
          LEFT JOIN cms.dbo.POSOINV f ON (f.U_FACNUM = o.U_NCO AND f.CANCELED = 'N')
        CROSS APPLY (VALUES (1,'NCFModificado'), (2,'FechaNCFModificado'),(3,'CodigoModificacion'),(4,'RazonModificacion')) c (columnOrder,ColumnName)
              WHERE O.C_DocEntry = @InvoiceID
               
            ) ecf 
        WHERE @Resumen = 0 AND @eCFType IN ('34')
          AND (SELECT COUNT(n.C_DocEntry) FROM cms.dbo.POSORIN n INNER JOIN cms.dbo.POSOINV i ON (i.U_FACNUM = n.U_NCO AND SUBSTRING(i.U_FACNUM,1,3) IN ('E31','E32','E44','E45','B01','B02','B14','B15')) WHERE n.C_DocEntry = @InvoiceID AND n.DocDate > '2024-01-01') > 0
/*
UNION ALL

--NOTA DE CREDITO AGROFEM DESDE COMPRAS
     SELECT ecf.*
       FROM ( 
  
             --Encabezado
             SELECT ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'ECF' THEN 'ECF'
                        WHEN 'Version' THEN '1.0' 
                        WHEN 'TipoeCF' THEN i.ecf_type
                        WHEN 'eNCF' THEN UPPER(i.ecf)
                        WHEN 'FechaVencimientoSecuencia' THEN COALESCE(NULLIF(FORMAT(i.ecf_vence,'dd-MM-yyyy'),'01-01-1900'),'#e')
                        WHEN 'IndicadorNotaCredito' THEN CASE WHEN DATEDIFF(DAY,t.U_FacFecha,f.DocDate) <= 30 THEN '0' ELSE '1' END --'#e' --LOGICA PARA NOTA DE CREDITO
                        WHEN 'IndicadorMontoGravado' THEN CASE WHEN @eCFType IN ('31','32','33','34','41','45') THEN '0' ELSE '#e' END -- (0) EL DEALLE DE LOS ITEM NO INCLUYE EL ITBIS
                        WHEN 'TipoIngresos' THEN CASE WHEN @eCFType IN ('31','32','33','34','44','45','46') THEN '01' ELSE '#e' END -- (01) Ingresos por operaciones (No financieros).
                        WHEN 'TipoPago' THEN CAST(CASE WHEN F.ExtraDays <= 1 THEN 1 ELSE 2 END AS NVARCHAR(MAX)) -- 1:Contado | 2:Credio | 3:Gratuito
                        WHEN 'FechaLimitePago' THEN CASE WHEN F.ExtraDays > 1 THEN CASE WHEN @eCFType IN ('43') THEN '#e' ELSE FORMAT(f.DocDueDate,'dd-MM-yyyy') END ELSE '#e' END
                        WHEN 'TerminoPago' THEN CASE WHEN F.ExtraDays > 1 THEN CASE WHEN @eCFType IN ('31','32','33','41','44','45','46','47') THEN REPLACE(g.PymntGroup,'C - ','') ELSE '#e' END ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM SBO_AGROFEM.dbo.ORPC f
         INNER JOIN SBO_AGROFEM.dbo.OPCH t ON (t.U_FACNUM = f.U_NCO AND t.CANCELED = 'N')
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = f.DocEntry AND i.ecf_type IN (34)) 
          LEFT JOIN SBO_AGROFEM.dbo.OCTG g ON (g.ExtraDays = f.ExtraDays /*AND g.ListNum = 2*/)
        CROSS APPLY (VALUES (1,'ECF'), (2,'Version'), (3,'TipoeCF'),(4,'eNCF'), (5,'FechaVencimientoSecuencia'),(6,'IndicadorNotaCredito'),(7,'IndicadorMontoGravado'),(8,'TipoIngresos'),(9,'TipoPago'),(10,'FechaLimitePago'),(11,'TerminoPago')) c (columnOrder,ColumnName)
              WHERE f.DocEntry = @InvoiceID
UNION ALL     --FORMAS DE PAGO
             SELECT 20 + ROW_NUMBER() OVER (ORDER BY s.id_diario_caja_det, c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                         WHEN 'FormaPago' THEN CAST(t.ecf_payform_id AS NVARCHAR(MAX))
                         WHEN 'MontoPago' THEN FORMAT(s.monto_caja,'0.00')
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSOINV f
         INNER JOIN cms.dbo.diario_caja_det s ON (s.id_documento = f.C_DocEntry AND s.docType = 'P')
          LEFT JOIN cms.dbo.ecf_payment_forms t ON (t.ecf_payform_sap = s.id_tipo_movimiento)
        CROSS APPLY (VALUES (1,'FormaPago'), (2,'MontoPago')) c (columnOrder,ColumnName)
              WHERE f.C_DocEntry = @InvoiceID
                AND @eCFType IN ('31','32','33','41','44','45','46','47')
UNION ALL    --TOTAL DE PAGINAS
             SELECT 40 + ROW_NUMBER() OVER (ORDER BY p.pages) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    'TotalPaginas' AS xmlTag,
                    FORMAT(p.pages,'0') AS xml_value
               FROM (SELECT CEILING(COUNT(d.LineNum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS pages
                       FROM SBO_AGROFEM.dbo.RPC1 d
                 INNER JOIN SBO_AGROFEM.dbo.ORPC f ON (f.DocEntry = d.DocEntry)
                      WHERE d.DocEntry = @InvoiceID
                      GROUP BY f.DocEntry 
                    ) p
              WHERE p.pages > 1
UNION ALL    --EMISOR & COMPRADOR
             SELECT 50 + ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'RNCEmisor' THEN d.RNC --PARA QUE SIEMPRE ENVIE EL RNC DE AGROFEM
                        WHEN 'RazonSocialEmisor' THEN razon_social
                        WHEN 'NombreComercial' THEN UPPER(CAST(d.descripcion AS NVARCHAR(100)))
                        WHEN 'DireccionEmisor' THEN d.direccion
                        WHEN 'TelefonoEmisor' THEN d.telefono1
                        WHEN 'CorreoEmisor' THEN d.email
                        WHEN 'WebSite' THEN d.web
                        WHEN 'NumeroFacturaInterna' THEN COALESCE(o.NumAtCard,'#e')
                        WHEN 'FechaEmision' THEN FORMAT(o.DocDate,'dd-MM-yyyy')
                        --WHEN 'RNCComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('34') OR (@eCFType IN ('34') AND f.DocTotal >= 250000) THEN f.U_FacNit ELSE '#e' END ELSE CASE WHEN F.U_TNegocio = 3 THEN CASE WHEN @eCFType IN ('34') OR (@eCFType IN ('34') AND f.DocTotal >= 250000) THEN '00000000000' ELSE '#e' END ELSE '#e' END END
                        WHEN 'RNCComprador' THEN CASE WHEN LEN(f.U_FacNit) IN (9,11) AND PATINDEX('%[^0-9]%', f.U_FacNit) = 0 THEN o.U_FacNit ELSE CASE WHEN f.U_TNegocio = 3 THEN '00000000000' ELSE '#e' END END
                        --WHEN 'RazonSocialComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('34') OR (@eCFType IN ('34') AND f.DocTotal >= 250000) THEN f.CardName ELSE '#e' END ELSE CASE WHEN F.U_TNegocio = 3 THEN CASE WHEN @eCFType IN ('34') OR (@eCFType IN ('34') AND f.DocTotal >= 250000) THEN f.CardName ELSE '#e' END ELSE '#e' END END 
                        WHEN 'RazonSocialComprador' THEN CASE WHEN LEN(f.U_FacNit) IN (9,11) AND PATINDEX('%[^0-9]%', f.U_FacNit) = 0 THEN o.CardName ELSE CASE WHEN f.U_TNegocio = 3 THEN o.CardName ELSE '#e' END END
                        WHEN 'DireccionComprador' THEN '#e' 
                        WHEN 'TelefonoAdicional' THEN '#e' 
                        WHEN 'CodigoInternoComprador' THEN CASE WHEN LEN(f.U_FacNit) IN (9,11) AND PATINDEX('%[^0-9]%', f.U_FacNit) = 0 THEN o.CardCode ELSE CASE WHEN f.U_TNegocio = 3 THEN o.CardCode ELSE '#e' END END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM SBO_AGROFEM.dbo.ORPC o
         INNER JOIN SBO_AGROFEM.dbo.OPCH f ON (f.U_FACNUM = o.U_NCO AND f.CANCELED = 'N')
	     --INNER JOIN cms.dbo.serie s ON (s.id_serie = f.U_SCIASerie)
          LEFT JOIN cms.dbo.division d ON (d.id_division = 1) 
          LEFT JOIN SBO_AGROFEM.dbo.OCRD l ON (l.CardCode = f.CardCode)
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = o.DocEntry AND i.ecf_type IN (34))
        CROSS APPLY (VALUES (1,'RNCEmisor'), (2,'RazonSocialEmisor'),(3,'NombreComercial'),(4,'DireccionEmisor'),(5,'TelefonoEmisor'),(6,'CorreoEmisor'),(7,'WebSite'),(8,'NumeroFacturaInterna'),(9,'FechaEmision'),(10,'RNCComprador'),(11,'RazonSocialComprador'),(12,'DireccionComprador'),(13,'TelefonoAdicional'),(14,'CodigoInternoComprador')) c (columnOrder,ColumnName)
              WHERE o.DocEntry = @InvoiceID
UNION ALL    --TOTALES
             SELECT 100 + ROW_NUMBER() OVER (ORDER BY c.columnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'MontoGravadoTotal' THEN CASE WHEN a.monto_grabado > 0 THEN FORMAT(a.monto_grabado,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END END
                        WHEN 'MontoGravadoI1' THEN CASE WHEN a.monto_grabadoI1 > 0 THEN FORMAT(a.monto_grabadoI1,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI2' THEN CASE WHEN a.monto_grabadoI2 > 0 THEN FORMAT(a.monto_grabadoI2,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI3' THEN CASE WHEN a.monto_grabadoI3 > 0 THEN FORMAT(a.monto_grabadoI3,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END END
                        WHEN 'MontoExento' THEN CASE WHEN (a.monto_exento > 0 AND @eCFType IN ('31','32','33','34','41','43','44','45','47')) THEN FORMAT(a.monto_exento,'0.00') ELSE '#e' END
                        WHEN 'ITBIS1' THEN CASE WHEN a.itbis1 > 0 THEN FORMAT(a.itbis1,'00') ELSE '#e' END
                        WHEN 'ITBIS2' THEN CASE WHEN a.itbis2 > 0 THEN FORMAT(a.itbis2,'00') ELSE '#e' END
                        WHEN 'ITBIS3' THEN CASE WHEN a.itbis3 > 0 THEN FORMAT(a.itbis3,'0') ELSE CASE WHEN @eCFType IN ('46') THEN '0' ELSE '#e' END END
                        WHEN 'TotalITBIS' THEN CASE WHEN a.total_itbis > 0 THEN FORMAT(a.total_itbis,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN '0.00' ELSE '#e' END END
                        WHEN 'TotalITBIS1' THEN CASE WHEN a.total_itbis1 > 0 THEN FORMAT(a.total_itbis1,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS2' THEN CASE WHEN a.total_itbis2 > 0 THEN FORMAT(a.total_itbis2,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS3' THEN CASE WHEN a.total_itbis3 > 0 THEN FORMAT(a.total_itbis3,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN '0.00' ELSE '#e' END END
                        WHEN 'MontoTotal' THEN CASE WHEN a.monto_total > 0 THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END
                        WHEN 'TotalITBISRetenido' THEN CASE WHEN @eCFType IN ('41') THEN FORMAT(0,'0.00') ELSE '#e' END
                        WHEN 'TotalISRRetencion' THEN CASE WHEN @eCFType IN ('41','47') THEN FORMAT(0,'0.00') ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM (SELECT CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabado,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (4) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_exento,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (1) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis1,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (2) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis2,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (3) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis3,
                            CAST(SUM(d.LineTotal+d.VatSum) AS NUMERIC(12,2)) AS monto_total
                       FROM SBO_AGROFEM.dbo.ORPC f
                 INNER JOIN SBO_AGROFEM.dbo.RPC1 d ON (d.DocEntry = f.DocEntry)
                 INNER JOIN SBO_AGROFEM.dbo.OPCH o ON (o.U_FACNUM = f.U_NCO AND o.CANCELED = 'N')
                 INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
                      WHERE f.DocEntry = @InvoiceID
                        --AND DATEDIFF(DAY, o.U_FacFecha,f.DocDate) <= 30
                    ) a
        CROSS APPLY (VALUES (1,'MontoGravadoTotal'), (2,'MontoGravadoI1'), (3,'MontoGravadoI2'),(4,'MontoGravadoI3'), (5,'MontoExento'),(6,'ITBIS1'),(7,'ITBIS2'),(8,'ITBIS3'),(9,'TotalITBIS'),(10,'TotalITBIS1'),(11,'TotalITBIS2'),(12,'TotalITBIS3'),(13,'MontoTotal'),(14,'TotalITBISRetenido'),(15,'TotalISRRetencion')) c (columnOrder,ColumnName)
UNION ALL
         --2 - DetallesItems
         SELECT 1000 + ROW_NUMBER() OVER (ORDER BY d.LineNum, c.ColumnOrder) AS id_record,
                2 AS group_id,
                'DetallesItem' AS group_name,
                c.ColumnName AS xmlTag,
                CAST(CASE c.ColumnName
                    WHEN 'NumeroLinea' THEN CAST(DENSE_RANK() OVER(PARTITION BY d.DocEntry ORDER BY d.LineNum) AS NVARCHAR(MAX)) --CAST(d.LineNum+1 AS NVARCHAR(MAX))
                    WHEN 'IndicadorFacturacion' THEN CAST( CASE WHEN @eCFType IN ('46') THEN 3 ELSE t.taxecf_id END AS NVARCHAR(MAX))
                    WHEN 'IndicadorAgenteRetencionoPercepcion' THEN CAST(CASE WHEN @eCFType IN ('41','47') THEN '1' ELSE '#e' END AS NVARCHAR(MAX))
                    WHEN 'MontoITBISRetenido' THEN CASE WHEN @eCFType IN ('41') THEN '0.00' ELSE '#e' END
                    WHEN 'MontoISRRetenido' THEN CASE WHEN @eCFType IN ('41','47') THEN '0.00' ELSE '#e' END
                    WHEN 'NombreItem' THEN CAST(COALESCE(d.Dscription,f.comments) AS NVARCHAR(MAX))
                    WHEN 'IndicadorBienoServicio' THEN CAST(CASE WHEN @eCFType IN ('41','47','43') THEN 2 ELSE  CASE WHEN f.DocType = 'S' THEN 2 ELSE 1 END END AS NVARCHAR(MAX))
                    WHEN 'CantidadItem' THEN FORMAT(COALESCE(NULLIF(d.Quantity,0),1),'0.00')
                    WHEN 'UnidadMedida' THEN COALESCE(CAST(u.ecfunit_id AS NVARCHAR(MAX)),'#e')
                    WHEN 'PrecioUnitarioItem' THEN FORMAT(d.PriceBefDi,'0.00')
                    WHEN 'DescuentoMonto' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT((d.PriceBefDi*(d.DiscPrcnt/100))*d.Quantity,'0.00') ELSE '#e' END
                    WHEN 'TipoSubDescuento' THEN CASE WHEN d.DiscPrcnt > 0 THEN '%' ELSE '#e' END
                    WHEN 'SubDescuentoPorcentaje' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT(d.DiscPrcnt,'0.00') ELSE '#e' END
                    WHEN 'MontoSubDescuento' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT((d.PriceBefDi*(d.DiscPrcnt/100))*d.Quantity,'0.00') ELSE '#e' END
                    WHEN 'MontoItem' THEN FORMAT(d.LineTotal,'0.00')
                END AS NVARCHAR(MAX)) AS xml_value
           FROM SBO_AGROFEM.dbo.RPC1 d
     INNER JOIN SBO_AGROFEM.dbo.ORPC f ON (f.DocEntry = d.DocEntry)
     INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
      LEFT JOIN cms.dbo.ecf_units u ON (u.ecfsapunit_name = d.unitMsr)
    CROSS APPLY (VALUES (1,'NumeroLinea'), (2,'IndicadorFacturacion'), (3,'IndicadorAgenteRetencionoPercepcion'), (4,'MontoITBISRetenido'), (4,'MontoISRRetenido'), (5,'NombreItem'),(6,'IndicadorBienoServicio'), (7,'CantidadItem'),(8,'UnidadMedida'),(9,'PrecioUnitarioItem'),(10,'DescuentoMonto'),(11,'TipoSubDescuento'),(12,'SubDescuentoPorcentaje'),(13,'MontoSubDescuento'),(14,'MontoItem')) c (columnOrder,ColumnName)
          WHERE d.DocEntry = @InvoiceID
UNION ALL
             --PAGINACION
             SELECT 100000+ROW_NUMBER() OVER (ORDER BY a.pagina_numero, c.columnOrder) AS id_record,
                    5 AS group_id,
                    'Paginacion' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'PaginaNo' THEN CAST(pagina_numero AS NVARCHAR(MAX))
                        WHEN 'NoLineaDesde' THEN CAST(linea_desde AS NVARCHAR(MAX))
                        WHEN 'NoLineaHasta' THEN CAST(linea_hasa AS NVARCHAR(MAX))
                        WHEN 'SubtotalMontoGravadoPagina' THEN CASE WHEN a.monto_grabado > 0 THEN FORMAT(a.monto_grabado,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado1Pagina' THEN CASE WHEN a.monto_grabadoI1 > 0 THEN FORMAT(a.monto_grabadoI1,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado2Pagina' THEN CASE WHEN a.monto_grabadoI2 > 0 THEN FORMAT(a.monto_grabadoI2,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado3Pagina' THEN CASE WHEN a.monto_grabadoI3 > 0 THEN FORMAT(a.monto_grabadoI3,'0.00') ELSE '#e' END
                        WHEN 'SubtotalExentoPagina' THEN CASE WHEN a.monto_exento > 0 THEN FORMAT(a.monto_exento,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbisPagina' THEN CASE WHEN a.total_itbis > 0 THEN FORMAT(a.total_itbis,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis1Pagina' THEN CASE WHEN a.total_itbis1 > 0 THEN FORMAT(a.total_itbis1,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis2Pagina' THEN CASE WHEN a.total_itbis2 > 0 THEN FORMAT(a.total_itbis2,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis3Pagina' THEN CASE WHEN a.total_itbis3 > 0 THEN FORMAT(a.total_itbis3,'0.00') ELSE '#e' END
                        WHEN 'MontoSubtotalPagina' THEN CASE WHEN a.monto_total > 0 THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM (SELECT group_id AS pagina_numero,
                            MIN(w.numero_linea) AS linea_desde,
                            MAX(w.numero_linea) AS linea_hasa,
                            CAST(SUM(monto_grabado) AS NUMERIC(12,2)) AS monto_grabado,
                            CAST(SUM(monto_grabadoI1) AS NUMERIC(12,2)) AS monto_grabadoI1,
                            CAST(SUM(monto_grabadoI2) AS NUMERIC(12,2)) AS monto_grabadoI2,
                            CAST(SUM(monto_grabadoI3) AS NUMERIC(12,2)) AS monto_grabadoI3,
                            CAST(SUM(monto_exento) AS NUMERIC(12,2)) AS monto_exento,
                            CAST(SUM(total_itbis) AS NUMERIC(12,2)) AS total_itbis,
                            CAST(SUM(total_itbis1) AS NUMERIC(12,2)) AS total_itbis1,
                            CAST(SUM(total_itbis2) AS NUMERIC(12,2)) AS total_itbis2,
                            CAST(SUM(total_itbis3) AS NUMERIC(12,2)) AS total_itbis3,
                            CAST(SUM(monto_total) AS NUMERIC(12,2)) AS monto_total
                       FROM (SELECT (d.linenum+1) AS numero_linea,
                                    CEILING(ROW_NUMBER() OVER(ORDER BY d.linenum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS group_id,
                                    SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.LineTotal ELSE 0 END) AS monto_grabado,
                                    SUM(CASE WHEN t.taxecf_id IN (1) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI1,
                                    SUM(CASE WHEN t.taxecf_id IN (2) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI2,
                                    SUM(CASE WHEN t.taxecf_id IN (3) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI3,
                                    SUM(CASE WHEN t.taxecf_id IN (4) THEN d.LineTotal ELSE 0 END) AS monto_exento,
                                    MAX(CASE WHEN t.taxecf_id IN (1) THEN d.VatPrcnt ELSE 0 END) AS itbis1,
                                    MAX(CASE WHEN t.taxecf_id IN (2) THEN d.VatPrcnt ELSE 0 END) AS itbis2,
                                    MAX(CASE WHEN t.taxecf_id IN (3) THEN d.VatPrcnt ELSE 0 END) AS itbis3,
                                    SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.VatSum ELSE 0 END) AS total_itbis,
                                    SUM(CASE WHEN t.taxecf_id IN (1) THEN d.VatSum ELSE 0 END) AS total_itbis1,
                                    SUM(CASE WHEN t.taxecf_id IN (2) THEN d.VatSum ELSE 0 END) AS total_itbis2,
                                    SUM(CASE WHEN t.taxecf_id IN (3) THEN d.VatSum ELSE 0 END) AS total_itbis3,
                                    SUM(d.LineTotal+d.VatSum) AS monto_total
                               FROM SBO_AGROFEM.dbo.ORPC f
                         INNER JOIN SBO_AGROFEM.dbo.RPC1 d ON (d.DocEntry = f.DocEntry)
                         INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
                              WHERE f.DocEntry = @InvoiceID
                              GROUP BY d.linenum
                            ) w
                      GROUP BY w.group_id
                    ) a
        CROSS APPLY (VALUES (1,'PaginaNo'), (2,'NoLineaDesde'), (3,'NoLineaHasta'),(4,'SubtotalMontoGravadoPagina'), (5,'SubtotalMontoGravado1Pagina'),(6,'SubtotalMontoGravado2Pagina'),(7,'SubtotalMontoGravado3Pagina'),(8,'SubtotalExentoPagina'),(9,'SubtotalItbisPagina'),(10,'SubtotalItbis1Pagina'),(11,'SubtotalItbis2Pagina'),(12,'SubtotalItbis3Pagina'),(13,'MontoSubtotalPagina')) c (columnOrder,ColumnName)
              WHERE (SELECT CEILING(COUNT(d.LineNum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS pages FROM SBO_AGROFEM.dbo.RPC1 d WHERE d.DocEntry = @InvoiceID) > 1
                AND @pPrintPages = 'Y'
UNION ALL
             SELECT 500000 + ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    6 AS group_id,
                    'InformacionReferencia' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'NCFModificado' THEN UPPER(o.U_NCO)
                        WHEN 'FechaNCFModificado' THEN FORMAT(f.U_FacFecha,'dd-MM-yyyy')
                        --WHEN 'CodigoModificacion' THEN CAST(3 AS NVARCHAR(1))
                        --SI EL MONTO DE LA NC ES IGUAL AL THE DE FACTURA ENTONCES ES PARA ANULAR FACTURA (1) DE LO CONTRARIO ES PARA MODIFICAR (3)
                        WHEN 'CodigoModificacion' THEN CAST(CASE WHEN (f.DocTotal-o.DocTotal) = 0 THEN 1 ELSE 3 END AS NVARCHAR(1))
                        WHEN 'RazonModificacion' THEN SUBSTRING(o.Comments,1,90) 
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM SBO_AGROFEM.dbo.ORPC o
          LEFT JOIN SBO_AGROFEM.dbo.OPCH f ON (f.U_FACNUM = o.U_NCO AND f.CANCELED = 'N')
        CROSS APPLY (VALUES (1,'NCFModificado'), (2,'FechaNCFModificado'),(3,'CodigoModificacion'),(4,'RazonModificacion')) c (columnOrder,ColumnName)
              WHERE O.DocEntry = @InvoiceID
               
            ) ecf 
        WHERE @Resumen = 0 AND @eCFType IN ('34')
          AND (SELECT COUNT(n.DocEntry) FROM SBO_AGROFEM.dbo.ORPC n INNER JOIN SBO_AGROFEM.dbo.OPCH i ON (i.U_FACNUM = n.U_NCO  AND i.CANCELED = 'N' AND SUBSTRING(i.U_FACNUM,1,3) IN ('E41','E43')) WHERE n.DocEntry = @InvoiceID) > 0

UNION ALL

/*NOTA DE CREDITO ESPECIAL TIPO 50 SOLO PARA CORREGIR ENVIADOS POR ERROR*/

     SELECT ecf.*
       FROM ( 
  
             --Encabezado
             SELECT ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'ECF' THEN 'ECF'
                        WHEN 'Version' THEN '1.0' 
                        WHEN 'TipoeCF' THEN i.ecf_type
                        WHEN 'eNCF' THEN i.ecf
                        WHEN 'FechaVencimientoSecuencia' THEN '#e' --COALESCE(NULLIF(FORMAT(i.ecf_vence,'dd-MM-yyyy'),'01-01-1900'),'#e')
                        WHEN 'IndicadorNotaCredito' THEN CASE WHEN DATEDIFF(DAY,t.U_FacFecha,f.DocDate) <= 30 THEN '0' ELSE '1' END --'#e' --LOGICA PARA NOTA DE CREDITO
                        WHEN 'IndicadorMontoGravado' THEN CASE WHEN @eCFType IN ('50') THEN '0' ELSE '#e' END -- (0) EL DEALLE DE LOS ITEM NO INCLUYE EL ITBIS
                        WHEN 'TipoIngresos' THEN CASE WHEN @eCFType IN ('50') THEN '01' ELSE '#e' END -- (01) Ingresos por operaciones (No financieros).
                        WHEN 'TipoPago' THEN CAST(CASE WHEN F.ExtraDays <= 1 THEN 1 ELSE 2 END AS NVARCHAR(MAX)) -- 1:Contado | 2:Credio | 3:Gratuito
                        WHEN 'FechaLimitePago' THEN CASE WHEN F.ExtraDays > 1 THEN CASE WHEN @eCFType IN ('43') THEN '#e' ELSE FORMAT(f.DocDueDate,'dd-MM-yyyy') END ELSE '#e' END
                        WHEN 'TerminoPago' THEN CASE WHEN F.ExtraDays > 1 THEN CASE WHEN @eCFType IN ('31','32','33','41','44','45','46','47') THEN REPLACE(g.PymntGroup,'C - ','') ELSE '#e' END ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSOINV f
         INNER JOIN cms.dbo.POSOINV t ON (t.U_FACNUM = f.U_FACNUM)
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = f.C_DocEntry) 
          LEFT JOIN SBO_AGROFEM.dbo.OCTG g ON (g.ExtraDays = f.ExtraDays AND g.ListNum = 2)
        CROSS APPLY (VALUES (1,'ECF'), (2,'Version'), (3,'TipoeCF'),(4,'eNCF'), (5,'FechaVencimientoSecuencia'),(6,'IndicadorNotaCredito'),(7,'IndicadorMontoGravado'),(8,'TipoIngresos'),(9,'TipoPago'),(10,'FechaLimitePago'),(11,'TerminoPago')) c (columnOrder,ColumnName)
              WHERE f.C_DocEntry = @InvoiceID
UNION ALL     --FORMAS DE PAGO
             SELECT 20 + ROW_NUMBER() OVER (ORDER BY s.id_diario_caja_det, c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                         WHEN 'FormaPago' THEN CAST(t.ecf_payform_id AS NVARCHAR(MAX))
                         WHEN 'MontoPago' THEN FORMAT(s.monto_caja,'0.00')
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSOINV f
         INNER JOIN cms.dbo.diario_caja_det s ON (s.id_documento = f.C_DocEntry AND s.docType = 'P')
          LEFT JOIN cms.dbo.ecf_payment_forms t ON (t.ecf_payform_sap = s.id_tipo_movimiento)
        CROSS APPLY (VALUES (1,'FormaPago'), (2,'MontoPago')) c (columnOrder,ColumnName)
              WHERE f.C_DocEntry = @InvoiceID
                AND @eCFType IN ('31','32','33','41','44','45','46','47')
UNION ALL    --TOTAL DE PAGINAS
             SELECT 40 + ROW_NUMBER() OVER (ORDER BY p.pages) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    'TotalPaginas' AS xmlTag,
                    FORMAT(p.pages,'0') AS xml_value
               FROM (SELECT CEILING(COUNT(d.LineNum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS pages
                       FROM cms.dbo.POSINV1 d
                 INNER JOIN cms.dbo.POSOINV f ON (f.C_DocEntry = d.C_DocEntry)
                      WHERE d.DocEntry = @InvoiceID
                      GROUP BY f.C_DocEntry 
                    ) p
              WHERE p.pages > 1 AND @pPrintPages = 'Y'
UNION ALL    --EMISOR & COMPRADOR
             SELECT 50 + ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'RNCEmisor' THEN d.RNC --PARA QUE SIEMPRE ENVIE EL RNC DE AGROFEM
                        WHEN 'RazonSocialEmisor' THEN razon_social
                        WHEN 'NombreComercial' THEN UPPER(d.nombre)
                        WHEN 'DireccionEmisor' THEN d.direccion
                        WHEN 'TelefonoEmisor' THEN d.telefono1
                        WHEN 'CorreoEmisor' THEN d.email
                        WHEN 'WebSite' THEN d.web
                        WHEN 'NumeroFacturaInterna' THEN f.NumAtCard
                        WHEN 'FechaEmision' THEN FORMAT(o.DocDate,'dd-MM-yyyy')
                        --WHEN 'RNCComprador' THEN CASE WHEN ((LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) AND PATINDEX('%[^0-9]%', f.U_FacNit) = 0) THEN CASE WHEN @eCFType IN ('34') OR (@eCFType IN ('34') AND f.DocTotal >= 250000) THEN f.U_FacNit ELSE '#e' END ELSE CASE WHEN F.U_TNegocio = 3 THEN CASE WHEN @eCFType IN ('31') OR (@eCFType IN ('32') AND f.DocTotal >= 250000) THEN '00000000000' ELSE '00000000000' END ELSE '#e' END END
                        WHEN 'RNCComprador' THEN CASE WHEN LEN(f.U_FacNit) IN (9,11) AND PATINDEX('%[^0-9]%', f.U_FacNit) = 0 THEN o.U_FacNit ELSE CASE WHEN f.U_TNegocio = 3 THEN '00000000000' ELSE '#e' END END
                        --WHEN 'RazonSocialComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('34') OR (@eCFType IN ('34') AND f.DocTotal >= 250000) THEN f.CardName ELSE '#e' END ELSE CASE WHEN F.U_TNegocio = 3 THEN CASE WHEN @eCFType IN ('31') OR (@eCFType IN ('32') AND f.DocTotal >= 250000) THEN f.CardName ELSE f.CardName END ELSE '#e' END END 
                        WHEN 'RazonSocialComprador' THEN CASE WHEN LEN(f.U_FacNit) IN (9,11) AND PATINDEX('%[^0-9]%', f.U_FacNit) = 0 THEN o.CardName ELSE CASE WHEN f.U_TNegocio = 3 THEN o.CardName ELSE '#e' END END
                        WHEN 'DireccionComprador' THEN '#e' --CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('31') OR (@eCFType IN ('32') AND f.DocTotal >= 250000) THEN COALESCE(NULLIF(f.Address2,''),'#e') ELSE '#e' END ELSE '#e' END 
                        WHEN 'TelefonoAdicional' THEN '#e'
                        --WHEN 'TelefonoAdicional' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('31') OR (@eCFType IN ('32') AND f.DocTotal >= 250000) THEN COALESCE(l.Cellular,l.phone1,l.phone2,'#e') ELSE '#e' END ELSE '#e' END 
                        --WHEN 'CodigoInternoComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('31') OR (@eCFType IN ('32') AND f.DocTotal >= 250000) THEN f.CardCode ELSE '#e' END ELSE '#e' END 
                        WHEN 'CodigoInternoComprador' THEN CASE WHEN LEN(f.U_FacNit) IN (9,11) AND PATINDEX('%[^0-9]%', f.U_FacNit) = 0 THEN o.CardCode ELSE CASE WHEN f.U_TNegocio = 3 THEN o.CardCode ELSE '#e' END END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSOINV o
         INNER JOIN cms.dbo.POSOINV f ON (f.U_FACNUM = o.U_FACNUM)
	     INNER JOIN cms.dbo.serie s ON (s.id_serie = f.U_SCIASerie)
         INNER JOIN cms.dbo.division d ON (d.id_division = s.id_division) 
          LEFT JOIN SBO_AGROFEM.dbo.OCRD l ON (l.CardCode = f.CardCode)
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = o.C_DocEntry)
        CROSS APPLY (VALUES (1,'RNCEmisor'), (2,'RazonSocialEmisor'),(3,'NombreComercial'),(4,'DireccionEmisor'),(5,'TelefonoEmisor'),(6,'CorreoEmisor'),(7,'WebSite'),(8,'NumeroFacturaInterna'),(9,'FechaEmision'),(10,'RNCComprador'),(11,'RazonSocialComprador'),(12,'DireccionComprador'),(13,'TelefonoAdicional'),(14,'CodigoInternoComprador')) c (columnOrder,ColumnName)
              WHERE o.C_DocEntry = @InvoiceID
UNION ALL    --TOTALES
             SELECT 100 + ROW_NUMBER() OVER (ORDER BY c.columnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'MontoGravadoTotal' THEN CASE WHEN a.monto_grabado > 0 THEN FORMAT(a.monto_grabado,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END END
                        WHEN 'MontoGravadoI1' THEN CASE WHEN a.monto_grabadoI1 > 0 THEN FORMAT(a.monto_grabadoI1,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI2' THEN CASE WHEN a.monto_grabadoI2 > 0 THEN FORMAT(a.monto_grabadoI2,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI3' THEN CASE WHEN a.monto_grabadoI3 > 0 THEN FORMAT(a.monto_grabadoI3,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END END
                        WHEN 'MontoExento' THEN CASE WHEN (a.monto_exento > 0 AND @eCFType IN ('50')) THEN FORMAT(a.monto_exento,'0.00') ELSE '#e' END
                        WHEN 'ITBIS1' THEN CASE WHEN a.itbis1 > 0 THEN FORMAT(a.itbis1,'00') ELSE '#e' END
                        WHEN 'ITBIS2' THEN CASE WHEN a.itbis2 > 0 THEN FORMAT(a.itbis2,'00') ELSE '#e' END
                        WHEN 'ITBIS3' THEN CASE WHEN a.itbis3 > 0 THEN FORMAT(a.itbis3,'0') ELSE CASE WHEN @eCFType IN ('46') THEN '0' ELSE '#e' END END
                        WHEN 'TotalITBIS' THEN CASE WHEN a.total_itbis > 0 THEN FORMAT(a.total_itbis,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN '0.00' ELSE '#e' END END
                        WHEN 'TotalITBIS1' THEN CASE WHEN a.total_itbis1 > 0 THEN FORMAT(a.total_itbis1,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS2' THEN CASE WHEN a.total_itbis2 > 0 THEN FORMAT(a.total_itbis2,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS3' THEN CASE WHEN a.total_itbis3 > 0 THEN FORMAT(a.total_itbis3,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN '0.00' ELSE '#e' END END
                        WHEN 'MontoTotal' THEN CASE WHEN a.monto_total > 0 THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END
                        WHEN 'TotalITBISRetenido' THEN CASE WHEN @eCFType IN ('41') THEN FORMAT(0,'0.00') ELSE '#e' END
                        WHEN 'TotalISRRetencion' THEN CASE WHEN @eCFType IN ('41','47') THEN FORMAT(0,'0.00') ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM (SELECT CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabado,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (4) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_exento,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (1) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis1,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (2) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis2,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (3) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis3,
                            CAST(SUM(d.LineTotal+d.VatSum) AS NUMERIC(12,2)) AS monto_total
                       FROM cms.dbo.POSOINV f
                 INNER JOIN cms.dbo.POSINV1 d ON (d.C_DocEntry = f.C_DocEntry)
                 INNER JOIN SBO_AGROFEM.dbo.OINV o ON (o.U_FACNUM = f.U_FACNUM)
                 INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
                      WHERE f.C_DocEntry = @InvoiceID
                        --AND DATEDIFF(DAY, o.U_FacFecha,f.DocDate) <= 30
                    ) a
        CROSS APPLY (VALUES (1,'MontoGravadoTotal'), (2,'MontoGravadoI1'), (3,'MontoGravadoI2'),(4,'MontoGravadoI3'), (5,'MontoExento'),(6,'ITBIS1'),(7,'ITBIS2'),(8,'ITBIS3'),(9,'TotalITBIS'),(10,'TotalITBIS1'),(11,'TotalITBIS2'),(12,'TotalITBIS3'),(13,'MontoTotal'),(14,'TotalITBISRetenido'),(15,'TotalISRRetencion')) c (columnOrder,ColumnName)
UNION ALL
         --2 - DetallesItems
         SELECT 1000 + ROW_NUMBER() OVER (ORDER BY d.LineNum, c.ColumnOrder) AS id_record,
                2 AS group_id,
                'DetallesItem' AS group_name,
                c.ColumnName AS xmlTag,
                CAST(CASE c.ColumnName
                    WHEN 'NumeroLinea' THEN CAST(DENSE_RANK() OVER(PARTITION BY d.DocEntry ORDER BY d.LineNum) AS NVARCHAR(MAX)) --CAST(d.LineNum+1 AS NVARCHAR(MAX))
                    WHEN 'IndicadorFacturacion' THEN CAST( CASE WHEN @eCFType IN ('46') THEN 3 ELSE t.taxecf_id END AS NVARCHAR(MAX))
                    WHEN 'IndicadorAgenteRetencionoPercepcion' THEN CAST(CASE WHEN @eCFType IN ('41','47') THEN '1' ELSE '#e' END AS NVARCHAR(MAX))
                    WHEN 'MontoITBISRetenido' THEN CASE WHEN @eCFType IN ('41') THEN '0.00' ELSE '#e' END
                    WHEN 'MontoISRRetenido' THEN CASE WHEN @eCFType IN ('41','47') THEN '0.00' ELSE '#e' END
                    WHEN 'NombreItem' THEN CAST(d.Dscription AS NVARCHAR(MAX))
                    WHEN 'IndicadorBienoServicio' THEN CAST(CASE WHEN @eCFType IN ('41','47','43') THEN 2 ELSE  CASE WHEN f.DocType = 'S' THEN 2 ELSE 1 END END AS NVARCHAR(MAX))
                    WHEN 'CantidadItem' THEN FORMAT(COALESCE(NULLIF(d.Quantity,0),1),'0.00')
                    WHEN 'UnidadMedida' THEN CAST(u.ecfunit_id AS NVARCHAR(MAX))
                    WHEN 'PrecioUnitarioItem' THEN FORMAT(d.PriceBefDi,'0.00')
                    WHEN 'DescuentoMonto' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT((d.PriceBefDi*(d.DiscPrcnt/100))*d.Quantity,'0.00') ELSE '#e' END
                    WHEN 'TipoSubDescuento' THEN CASE WHEN d.DiscPrcnt > 0 THEN '%' ELSE '#e' END
                    WHEN 'SubDescuentoPorcentaje' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT(d.DiscPrcnt,'0.00') ELSE '#e' END
                    WHEN 'MontoSubDescuento' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT((d.PriceBefDi*(d.DiscPrcnt/100))*d.Quantity,'0.00') ELSE '#e' END
                    WHEN 'MontoItem' THEN FORMAT(d.LineTotal,'0.00')
                END AS NVARCHAR(MAX)) AS xml_value
           FROM cms.dbo.POSINV1 d
     INNER JOIN cms.dbo.POSOINV f ON (f.C_DocEntry = d.C_DocEntry)
     INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
      LEFT JOIN cms.dbo.ecf_units u ON (u.ecfsapunit_namemf = d.unitMsr)
    CROSS APPLY (VALUES (1,'NumeroLinea'), (2,'IndicadorFacturacion'), (3,'IndicadorAgenteRetencionoPercepcion'), (4,'MontoITBISRetenido'), (4,'MontoISRRetenido'), (5,'NombreItem'),(6,'IndicadorBienoServicio'), (7,'CantidadItem'),(8,'UnidadMedida'),(9,'PrecioUnitarioItem'),(10,'DescuentoMonto'),(11,'TipoSubDescuento'),(12,'SubDescuentoPorcentaje'),(13,'MontoSubDescuento'),(14,'MontoItem')) c (columnOrder,ColumnName)
          WHERE d.C_DocEntry = @InvoiceID
UNION ALL
             --PAGINACION
             SELECT 100000+ROW_NUMBER() OVER (ORDER BY a.pagina_numero, c.columnOrder) AS id_record,
                    5 AS group_id,
                    'Paginacion' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'PaginaNo' THEN CAST(pagina_numero AS NVARCHAR(MAX))
                        WHEN 'NoLineaDesde' THEN CAST(linea_desde AS NVARCHAR(MAX))
                        WHEN 'NoLineaHasta' THEN CAST(linea_hasa AS NVARCHAR(MAX))
                        WHEN 'SubtotalMontoGravadoPagina' THEN CASE WHEN a.monto_grabado > 0 THEN FORMAT(a.monto_grabado,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado1Pagina' THEN CASE WHEN a.monto_grabadoI1 > 0 THEN FORMAT(a.monto_grabadoI1,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado2Pagina' THEN CASE WHEN a.monto_grabadoI2 > 0 THEN FORMAT(a.monto_grabadoI2,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado3Pagina' THEN CASE WHEN a.monto_grabadoI3 > 0 THEN FORMAT(a.monto_grabadoI3,'0.00') ELSE '#e' END
                        WHEN 'SubtotalExentoPagina' THEN CASE WHEN a.monto_exento > 0 THEN FORMAT(a.monto_exento,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbisPagina' THEN CASE WHEN a.total_itbis > 0 THEN FORMAT(a.total_itbis,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis1Pagina' THEN CASE WHEN a.total_itbis1 > 0 THEN FORMAT(a.total_itbis1,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis2Pagina' THEN CASE WHEN a.total_itbis2 > 0 THEN FORMAT(a.total_itbis2,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis3Pagina' THEN CASE WHEN a.total_itbis3 > 0 THEN FORMAT(a.total_itbis3,'0.00') ELSE '#e' END
                        WHEN 'MontoSubtotalPagina' THEN CASE WHEN a.monto_total > 0 THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM (SELECT group_id AS pagina_numero,
                            MIN(w.numero_linea) AS linea_desde,
                            MAX(w.numero_linea) AS linea_hasa,
                            CAST(SUM(monto_grabado) AS NUMERIC(12,2)) AS monto_grabado,
                            CAST(SUM(monto_grabadoI1) AS NUMERIC(12,2)) AS monto_grabadoI1,
                            CAST(SUM(monto_grabadoI2) AS NUMERIC(12,2)) AS monto_grabadoI2,
                            CAST(SUM(monto_grabadoI3) AS NUMERIC(12,2)) AS monto_grabadoI3,
                            CAST(SUM(monto_exento) AS NUMERIC(12,2)) AS monto_exento,
                            CAST(SUM(total_itbis) AS NUMERIC(12,2)) AS total_itbis,
                            CAST(SUM(total_itbis1) AS NUMERIC(12,2)) AS total_itbis1,
                            CAST(SUM(total_itbis2) AS NUMERIC(12,2)) AS total_itbis2,
                            CAST(SUM(total_itbis3) AS NUMERIC(12,2)) AS total_itbis3,
                            CAST(SUM(monto_total) AS NUMERIC(12,2)) AS monto_total
                       FROM (SELECT (d.linenum+1) AS numero_linea,
                                    CEILING(ROW_NUMBER() OVER(ORDER BY d.linenum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms_mmf.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS group_id,
                                    SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.LineTotal ELSE 0 END) AS monto_grabado,
                                    SUM(CASE WHEN t.taxecf_id IN (1) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI1,
                                    SUM(CASE WHEN t.taxecf_id IN (2) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI2,
                                    SUM(CASE WHEN t.taxecf_id IN (3) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI3,
                                    SUM(CASE WHEN t.taxecf_id IN (4) THEN d.LineTotal ELSE 0 END) AS monto_exento,
                                    MAX(CASE WHEN t.taxecf_id IN (1) THEN d.VatPrcnt ELSE 0 END) AS itbis1,
                                    MAX(CASE WHEN t.taxecf_id IN (2) THEN d.VatPrcnt ELSE 0 END) AS itbis2,
                                    MAX(CASE WHEN t.taxecf_id IN (3) THEN d.VatPrcnt ELSE 0 END) AS itbis3,
                                    SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.VatSum ELSE 0 END) AS total_itbis,
                                    SUM(CASE WHEN t.taxecf_id IN (1) THEN d.VatSum ELSE 0 END) AS total_itbis1,
                                    SUM(CASE WHEN t.taxecf_id IN (2) THEN d.VatSum ELSE 0 END) AS total_itbis2,
                                    SUM(CASE WHEN t.taxecf_id IN (3) THEN d.VatSum ELSE 0 END) AS total_itbis3,
                                    SUM(d.LineTotal+d.VatSum) AS monto_total
                               FROM cms.dbo.POSOINV f
                         INNER JOIN cms.dbo.POSINV1 d ON (d.C_DocEntry = f.C_DocEntry)
                         INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
                              WHERE f.C_DocEntry = @InvoiceID
                              GROUP BY d.linenum
                            ) w
                      GROUP BY w.group_id
                    ) a
        CROSS APPLY (VALUES (1,'PaginaNo'), (2,'NoLineaDesde'), (3,'NoLineaHasta'),(4,'SubtotalMontoGravadoPagina'), (5,'SubtotalMontoGravado1Pagina'),(6,'SubtotalMontoGravado2Pagina'),(7,'SubtotalMontoGravado3Pagina'),(8,'SubtotalExentoPagina'),(9,'SubtotalItbisPagina'),(10,'SubtotalItbis1Pagina'),(11,'SubtotalItbis2Pagina'),(12,'SubtotalItbis3Pagina'),(13,'MontoSubtotalPagina')) c (columnOrder,ColumnName)
              WHERE (SELECT CEILING(COUNT(d.LineNum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS pages FROM cms.dbo.POSINV1 d WHERE d.C_DocEntry = @InvoiceID) > 1
                AND @pPrintPages = 'Y'
UNION ALL
             SELECT 500000 + ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    6 AS group_id,
                    'InformacionReferencia' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'NCFModificado' THEN o.U_FACNUM 
                        WHEN 'FechaNCFModificado' THEN FORMAT(f.DocDate,'dd-MM-yyyy')
                        WHEN 'CodigoModificacion' THEN CAST(CASE WHEN (f.DocTotal-o.DocTotal) = 0 THEN 1 ELSE 3 END AS NVARCHAR(1)) --CAST(1 AS NVARCHAR(1))
                        WHEN 'RazonModificacion' THEN SUBSTRING('ANULAR '+f.U_FACNUM,1,90)
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSOINV o
          LEFT JOIN cms.dbo.POSOINV f ON (f.U_FACNUM = o.U_FACNUM)
        CROSS APPLY (VALUES (1,'NCFModificado'), (2,'FechaNCFModificado'),(3,'CodigoModificacion'),(4,'RazonModificacion')) c (columnOrder,ColumnName)
              WHERE o.C_DocEntry = @InvoiceID
               
            ) ecf 
        WHERE @Resumen = 0 AND @eCFType IN ('50')
*/
UNION ALL

--NOTA DE DEBITO AGROFEM DESDE VENTAS
     SELECT ecf.*
       FROM ( 
  
             --Encabezado
             SELECT ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'ECF' THEN 'ECF'
                        WHEN 'Version' THEN '1.0' 
                        WHEN 'TipoeCF' THEN i.ecf_type
                        WHEN 'eNCF' THEN UPPER(i.ecf)
                        WHEN 'FechaVencimientoSecuencia' THEN COALESCE(NULLIF(FORMAT(i.ecf_vence,'dd-MM-yyyy'),'01-01-1900'),'#e')
                        WHEN 'IndicadorNotaCredito' THEN '#e' --LOGICA PARA NOTA DE CREDITO
                        WHEN 'IndicadorMontoGravado' THEN CASE WHEN @eCFType IN (33) THEN '0' ELSE '#e' END -- (0) EL DEALLE DE LOS ITEM NO INCLUYE EL ITBIS
                        WHEN 'TipoIngresos' THEN CASE WHEN @eCFType IN (33) THEN '01' ELSE '#e' END -- (01) Ingresos por operaciones (No financieros).
                        WHEN 'TipoPago' THEN CAST(CASE WHEN F.ExtraDays <= 1 THEN 1 ELSE 2 END AS NVARCHAR(MAX)) -- 1:Contado | 2:Credio | 3:Gratuito
                        WHEN 'FechaLimitePago' THEN CASE WHEN F.ExtraDays > 1 THEN CASE WHEN @eCFType = 43 THEN '#e' ELSE FORMAT(f.DocDueDate,'dd-MM-yyyy') END ELSE '#e' END
                        WHEN 'TerminoPago' THEN CASE WHEN F.ExtraDays > 1 THEN CASE WHEN @eCFType IN ('33') THEN REPLACE(g.PymntGroup,'C - ','') ELSE '#e' END ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSODIN f
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = f.C_DocEntry AND i.ecf_type IN (33)) 
          LEFT JOIN cms.dbo.POSOCTG g ON (g.ExtraDays = f.ExtraDays /*AND g.ListNum = 2*/)
        CROSS APPLY (VALUES (1,'ECF'), (2,'Version'), (3,'TipoeCF'),(4,'eNCF'), (5,'FechaVencimientoSecuencia'),(6,'IndicadorNotaCredito'),(7,'IndicadorMontoGravado'),(8,'TipoIngresos'),(9,'TipoPago'),(10,'FechaLimitePago'),(11,'TerminoPago')) c (columnOrder,ColumnName)
              WHERE f.DocEntry = @InvoiceID
                --AND f.DocSubType = 'DN' //NO NECESSARY ANYMORE
UNION ALL     --FORMAS DE PAGO
             SELECT 20 + ROW_NUMBER() OVER (ORDER BY s.id_diario_caja_det, c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                         WHEN 'FormaPago' THEN CAST(t.ecf_payform_id AS NVARCHAR(MAX))
                         WHEN 'MontoPago' THEN FORMAT(s.monto_caja,'0.00')
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSOINV f
         INNER JOIN cms.dbo.diario_caja_det s ON (s.id_documento = f.C_DocEntry AND s.docType = 'P')
          LEFT JOIN cms.dbo.ecf_payment_forms t ON (t.ecf_payform_sap = s.id_tipo_movimiento)
        CROSS APPLY (VALUES (1,'FormaPago'), (2,'MontoPago')) c (columnOrder,ColumnName)
              WHERE f.C_DocEntry = @InvoiceID
                AND @eCFType IN ('31','32')
UNION ALL    --TOTAL DE PAGINAS
             SELECT 40 + ROW_NUMBER() OVER (ORDER BY p.pages) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    'TotalPaginas' AS xmlTag,
                    FORMAT(p.pages,'0') AS xml_value
               FROM (SELECT CEILING(COUNT(d.LineNum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS pages
                       FROM cms.dbo.POSDIN1 d
                 INNER JOIN cms.dbo.POSODIN f ON (f.C_DocEntry = d.C_DocEntry /*AND f.DocSubType = 'DN'*/)
                      WHERE d.C_DocEntry = @InvoiceID
                      GROUP BY f.C_DocEntry
                    ) p
              WHERE p.pages > 1
UNION ALL    --EMISOR & COMPRADOR
             SELECT 50 + ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'RNCEmisor' THEN d.RNC --PARA QUE SIEMPRE ENVIE EL RNC DE AGROFEM
                        WHEN 'RazonSocialEmisor' THEN razon_social
                        WHEN 'NombreComercial' THEN UPPER(CAST(d.descripcion AS NVARCHAR(100)))
                        WHEN 'DireccionEmisor' THEN d.direccion
                        WHEN 'TelefonoEmisor' THEN d.telefono1
                        WHEN 'CorreoEmisor' THEN d.email
                        WHEN 'WebSite' THEN d.web
                        WHEN 'NumeroFacturaInterna' THEN COALESCE(o.NumAtCard,'#e')
                        WHEN 'FechaEmision' THEN FORMAT(o.DocDate,'dd-MM-yyyy')
                        --WHEN 'RNCComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('33') OR (@eCFType IN ('33') AND f.DocTotal >= 250000) THEN o.U_FacNit ELSE '#e' END ELSE CASE WHEN F.U_TNegocio = 3 THEN CASE WHEN @eCFType IN ('33') OR (@eCFType IN ('33') AND f.DocTotal >= 250000) THEN '00000000000' ELSE '#e' END ELSE '#e' END END
                        --WHEN 'RazonSocialComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('31','33') OR (@eCFType IN ('32') AND f.DocTotal >= 250000) THEN f.CardName ELSE '#e' END ELSE CASE WHEN F.U_TNegocio = 3 THEN CASE WHEN @eCFType IN ('31') OR (@eCFType IN ('32') AND f.DocTotal >= 250000) THEN f.CardName ELSE '#e' END ELSE '#e' END END 
                        WHEN 'RNCComprador' THEN CASE WHEN LEN(f.U_FacNit) IN (9,11) AND PATINDEX('%[^0-9]%', f.U_FacNit) = 0 THEN o.U_FacNit ELSE CASE WHEN f.U_TNegocio = 3 THEN '00000000000' ELSE '#e' END END
                        WHEN 'RazonSocialComprador' THEN CASE WHEN LEN(f.U_FacNit) IN (9,11) AND PATINDEX('%[^0-9]%', f.U_FacNit) = 0 THEN o.CardName ELSE CASE WHEN f.U_TNegocio = 3 THEN o.CardName ELSE '#e' END END
                        WHEN 'DireccionComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('31','33') OR (@eCFType IN ('32') AND f.DocTotal >= 250000) THEN SUBSTRING(COALESCE(NULLIF(f.Address2,''),'#e'),1,100) ELSE '#e' END ELSE '#e' END 
                        WHEN 'TelefonoAdicional' THEN '#e' --CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('31','33') OR (@eCFType IN ('32') AND f.DocTotal >= 250000) THEN COALESCE(l.Cellular,l.phone1,l.phone2,'#e') ELSE '#e' END ELSE '#e' END 
                        --WHEN 'CodigoInternoComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('31','33') OR (@eCFType IN ('32') AND f.DocTotal >= 250000) THEN f.CardCode ELSE '#e' END ELSE '#e' END 
                        WHEN 'CodigoInternoComprador' THEN CASE WHEN LEN(f.U_FacNit) IN (9,11) AND PATINDEX('%[^0-9]%', f.U_FacNit) = 0 THEN o.CardCode ELSE CASE WHEN f.U_TNegocio = 3 THEN o.CardCode ELSE '#e' END END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSODIN o
         INNER JOIN cms.dbo.POSOINV f ON (f.U_FACNUM = o.U_NCO)
	     INNER JOIN cms.dbo.serie s ON (s.id_serie = f.U_SCIASerie)
         INNER JOIN cms.dbo.division d ON (d.id_division = s.id_division) 
          LEFT JOIN cms.dbo.POSOCRD l ON (l.CardCode = f.CardCode)
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = o.DocEntry AND i.ecf_type IN (33))
        CROSS APPLY (VALUES (1,'RNCEmisor'), (2,'RazonSocialEmisor'),(3,'NombreComercial'),(4,'DireccionEmisor'),(5,'TelefonoEmisor'),(6,'CorreoEmisor'),(7,'WebSite'),(8,'NumeroFacturaInterna'),(9,'FechaEmision'),(10,'RNCComprador'),(11,'RazonSocialComprador'),(12,'DireccionComprador'),(13,'TelefonoAdicional'),(14,'CodigoInternoComprador')) c (columnOrder,ColumnName)
              WHERE o.C_DocEntry = @InvoiceID
                --AND o.DocSubType = 'DN'
UNION ALL    --TOTALES
             SELECT 100 + ROW_NUMBER() OVER (ORDER BY c.columnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'MontoGravadoTotal' THEN CASE WHEN a.monto_grabado > 0 THEN FORMAT(a.monto_grabado,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END END
                        WHEN 'MontoGravadoI1' THEN CASE WHEN a.monto_grabadoI1 > 0 THEN FORMAT(a.monto_grabadoI1,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI2' THEN CASE WHEN a.monto_grabadoI2 > 0 THEN FORMAT(a.monto_grabadoI2,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI3' THEN CASE WHEN a.monto_grabadoI3 > 0 THEN FORMAT(a.monto_grabadoI3,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END END
                        WHEN 'MontoExento' THEN CASE WHEN (a.monto_exento > 0 AND @eCFType IN ('31','32','33','34','41','43','44','45','47')) THEN FORMAT(a.monto_exento,'0.00') ELSE '#e' END
                        WHEN 'ITBIS1' THEN CASE WHEN a.itbis1 > 0 THEN FORMAT(a.itbis1,'00') ELSE '#e' END
                        WHEN 'ITBIS2' THEN CASE WHEN a.itbis2 > 0 THEN FORMAT(a.itbis2,'00') ELSE '#e' END
                        WHEN 'ITBIS3' THEN CASE WHEN a.itbis3 > 0 THEN FORMAT(a.itbis3,'0') ELSE CASE WHEN @eCFType IN ('46') THEN '0' ELSE '#e' END END
                        WHEN 'TotalITBIS' THEN CASE WHEN a.total_itbis > 0 THEN FORMAT(a.total_itbis,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN '0.00' ELSE '#e' END END
                        WHEN 'TotalITBIS1' THEN CASE WHEN a.total_itbis1 > 0 THEN FORMAT(a.total_itbis1,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS2' THEN CASE WHEN a.total_itbis2 > 0 THEN FORMAT(a.total_itbis2,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS3' THEN CASE WHEN a.total_itbis3 > 0 THEN FORMAT(a.total_itbis3,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN '0.00' ELSE '#e' END END
                        WHEN 'MontoTotal' THEN CASE WHEN a.monto_total > 0 THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END
                        WHEN 'TotalITBISRetenido' THEN CASE WHEN @eCFType IN ('41') THEN FORMAT(0,'0.00') ELSE '#e' END
                        WHEN 'TotalISRRetencion' THEN CASE WHEN @eCFType IN ('41','47') THEN FORMAT(0,'0.00') ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM (SELECT CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabado,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (4) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_exento,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (1) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis1,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (2) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis2,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (3) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis3,
                            CAST(SUM(d.LineTotal+d.VatSum) AS NUMERIC(12,2)) AS monto_total
                       FROM cms.dbo.POSODIN f
                 INNER JOIN cms.dbo.POSDIN1 d ON (d.C_DocEntry = f.C_DocEntry)
                 INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
                      WHERE f.C_DocEntry = @InvoiceID
                        --AND f.DocSubType = 'DN'
                    ) a
        CROSS APPLY (VALUES (1,'MontoGravadoTotal'), (2,'MontoGravadoI1'), (3,'MontoGravadoI2'),(4,'MontoGravadoI3'), (5,'MontoExento'),(6,'ITBIS1'),(7,'ITBIS2'),(8,'ITBIS3'),(9,'TotalITBIS'),(10,'TotalITBIS1'),(11,'TotalITBIS2'),(12,'TotalITBIS3'),(13,'MontoTotal'),(14,'TotalITBISRetenido'),(15,'TotalISRRetencion')) c (columnOrder,ColumnName)
UNION ALL
         --2 - DetallesItems
         SELECT 1000 + ROW_NUMBER() OVER (ORDER BY d.LineNum, c.ColumnOrder) AS id_record,
                2 AS group_id,
                'DetallesItem' AS group_name,
                c.ColumnName AS xmlTag,
                CAST(CASE c.ColumnName
                    WHEN 'NumeroLinea' THEN CAST(DENSE_RANK() OVER(PARTITION BY d.C_DocEntry ORDER BY d.LineNum) AS NVARCHAR(MAX)) --CAST(d.LineNum+1 AS NVARCHAR(MAX))
                    WHEN 'IndicadorFacturacion' THEN CAST( CASE WHEN @eCFType IN ('46') THEN 3 ELSE t.taxecf_id END AS NVARCHAR(MAX))
                    WHEN 'IndicadorAgenteRetencionoPercepcion' THEN CAST(CASE WHEN @eCFType IN ('41','47') THEN '1' ELSE '#e' END AS NVARCHAR(MAX))
                    WHEN 'MontoITBISRetenido' THEN CASE WHEN @eCFType IN ('41') THEN '0.00' ELSE '#e' END
                    WHEN 'MontoISRRetenido' THEN CASE WHEN @eCFType IN ('41','47') THEN '0.00' ELSE '#e' END
                    WHEN 'NombreItem' THEN CAST(d.Dscription AS NVARCHAR(MAX))
                    WHEN 'IndicadorBienoServicio' THEN CAST(CASE WHEN @eCFType IN ('41','47','43') THEN 2 ELSE  CASE WHEN o.DocType = 'S' THEN 2 ELSE 1 END END AS NVARCHAR(MAX))
                    WHEN 'CantidadItem' THEN FORMAT(COALESCE(NULLIF(d.Quantity,0),1),'0.00') --PARA FORZAR LA CANTIDAD A 1 EN CASO DE NOTA DE CREDITO O DEBITO
                    WHEN 'UnidadMedida' THEN CAST(COALESCE(FORMAT(u.ecfunit_id,'0'),'#e') AS NVARCHAR(MAX))
                    WHEN 'PrecioUnitarioItem' THEN FORMAT(d.PriceBefDi,'0.00')
                    WHEN 'DescuentoMonto' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT((d.PriceBefDi*(d.DiscPrcnt/100))*d.Quantity,'0.00') ELSE '#e' END
                    WHEN 'TipoSubDescuento' THEN CASE WHEN d.DiscPrcnt > 0 THEN '%' ELSE '#e' END
                    WHEN 'SubDescuentoPorcentaje' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT(d.DiscPrcnt,'0.00') ELSE '#e' END
                    WHEN 'MontoSubDescuento' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT((d.PriceBefDi*(d.DiscPrcnt/100))*d.Quantity,'0.00') ELSE '#e' END
                    WHEN 'MontoItem' THEN FORMAT(d.LineTotal,'0.00')
                END AS NVARCHAR(MAX)) AS xml_value
           FROM cms.dbo.POSODIN o
     INNER JOIN cms.dbo.POSDIN1 d ON (d.C_DocEntry = o.C_DocEntry)
     INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
      LEFT JOIN cms.dbo.ecf_units u ON (u.ecfsapunit_name = d.unitMsr)
    CROSS APPLY (VALUES (1,'NumeroLinea'), (2,'IndicadorFacturacion'), (3,'IndicadorAgenteRetencionoPercepcion'), (4,'MontoITBISRetenido'), (4,'MontoISRRetenido'), (5,'NombreItem'),(6,'IndicadorBienoServicio'), (7,'CantidadItem'),(8,'UnidadMedida'),(9,'PrecioUnitarioItem'),(10,'DescuentoMonto'),(11,'TipoSubDescuento'),(12,'SubDescuentoPorcentaje'),(13,'MontoSubDescuento'),(14,'MontoItem')) c (columnOrder,ColumnName)
          WHERE o.C_DocEntry = @InvoiceID
            --AND o.DocSubType = 'DN'
UNION ALL
             --PAGINACION
             SELECT 100000+ROW_NUMBER() OVER (ORDER BY a.pagina_numero, c.columnOrder) AS id_record,
                    5 AS group_id,
                    'Paginacion' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'PaginaNo' THEN CAST(pagina_numero AS NVARCHAR(MAX))
                        WHEN 'NoLineaDesde' THEN CAST(linea_desde AS NVARCHAR(MAX))
                        WHEN 'NoLineaHasta' THEN CAST(linea_hasa AS NVARCHAR(MAX))
                        WHEN 'SubtotalMontoGravadoPagina' THEN CASE WHEN a.monto_grabado > 0 THEN FORMAT(a.monto_grabado,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado1Pagina' THEN CASE WHEN a.monto_grabadoI1 > 0 THEN FORMAT(a.monto_grabadoI1,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado2Pagina' THEN CASE WHEN a.monto_grabadoI2 > 0 THEN FORMAT(a.monto_grabadoI2,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado3Pagina' THEN CASE WHEN a.monto_grabadoI3 > 0 THEN FORMAT(a.monto_grabadoI3,'0.00') ELSE '#e' END
                        WHEN 'SubtotalExentoPagina' THEN CASE WHEN a.monto_exento > 0 THEN FORMAT(a.monto_exento,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbisPagina' THEN CASE WHEN a.total_itbis > 0 THEN FORMAT(a.total_itbis,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis1Pagina' THEN CASE WHEN a.total_itbis1 > 0 THEN FORMAT(a.total_itbis1,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis2Pagina' THEN CASE WHEN a.total_itbis2 > 0 THEN FORMAT(a.total_itbis2,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis3Pagina' THEN CASE WHEN a.total_itbis3 > 0 THEN FORMAT(a.total_itbis3,'0.00') ELSE '#e' END
                        WHEN 'MontoSubtotalPagina' THEN CASE WHEN a.monto_total > 0 THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM (SELECT group_id AS pagina_numero,
                            MIN(w.numero_linea) AS linea_desde,
                            MAX(w.numero_linea) AS linea_hasa,
                            CAST(SUM(monto_grabado) AS NUMERIC(12,2)) AS monto_grabado,
                            CAST(SUM(monto_grabadoI1) AS NUMERIC(12,2)) AS monto_grabadoI1,
                            CAST(SUM(monto_grabadoI2) AS NUMERIC(12,2)) AS monto_grabadoI2,
                            CAST(SUM(monto_grabadoI3) AS NUMERIC(12,2)) AS monto_grabadoI3,
                            CAST(SUM(monto_exento) AS NUMERIC(12,2)) AS monto_exento,
                            CAST(SUM(total_itbis) AS NUMERIC(12,2)) AS total_itbis,
                            CAST(SUM(total_itbis1) AS NUMERIC(12,2)) AS total_itbis1,
                            CAST(SUM(total_itbis2) AS NUMERIC(12,2)) AS total_itbis2,
                            CAST(SUM(total_itbis3) AS NUMERIC(12,2)) AS total_itbis3,
                            CAST(SUM(monto_total) AS NUMERIC(12,2)) AS monto_total
                       FROM (SELECT (d.linenum+1) AS numero_linea,
                                    CEILING(ROW_NUMBER() OVER(ORDER BY d.linenum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS group_id,
                                    SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.LineTotal ELSE 0 END) AS monto_grabado,
                                    SUM(CASE WHEN t.taxecf_id IN (1) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI1,
                                    SUM(CASE WHEN t.taxecf_id IN (2) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI2,
                                    SUM(CASE WHEN t.taxecf_id IN (3) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI3,
                                    SUM(CASE WHEN t.taxecf_id IN (4) THEN d.LineTotal ELSE 0 END) AS monto_exento,
                                    MAX(CASE WHEN t.taxecf_id IN (1) THEN d.VatPrcnt ELSE 0 END) AS itbis1,
                                    MAX(CASE WHEN t.taxecf_id IN (2) THEN d.VatPrcnt ELSE 0 END) AS itbis2,
                                    MAX(CASE WHEN t.taxecf_id IN (3) THEN d.VatPrcnt ELSE 0 END) AS itbis3,
                                    SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.VatSum ELSE 0 END) AS total_itbis,
                                    SUM(CASE WHEN t.taxecf_id IN (1) THEN d.VatSum ELSE 0 END) AS total_itbis1,
                                    SUM(CASE WHEN t.taxecf_id IN (2) THEN d.VatSum ELSE 0 END) AS total_itbis2,
                                    SUM(CASE WHEN t.taxecf_id IN (3) THEN d.VatSum ELSE 0 END) AS total_itbis3,
                                    SUM(d.LineTotal+d.VatSum) AS monto_total
                               FROM cms.dbo.POSODIN f
                         INNER JOIN cms.dbo.POSDIN1 d ON (d.C_DocEntry = f.C_DocEntry)
                         INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
                              WHERE f.C_DocEntry = @InvoiceID
                                --AND f.DocSubType = 'DN'
                              GROUP BY d.linenum
                            ) w
                      GROUP BY w.group_id
                    ) a
        CROSS APPLY (VALUES (1,'PaginaNo'), (2,'NoLineaDesde'), (3,'NoLineaHasta'),(4,'SubtotalMontoGravadoPagina'), (5,'SubtotalMontoGravado1Pagina'),(6,'SubtotalMontoGravado2Pagina'),(7,'SubtotalMontoGravado3Pagina'),(8,'SubtotalExentoPagina'),(9,'SubtotalItbisPagina'),(10,'SubtotalItbis1Pagina'),(11,'SubtotalItbis2Pagina'),(12,'SubtotalItbis3Pagina'),(13,'MontoSubtotalPagina')) c (columnOrder,ColumnName)
              WHERE (SELECT CEILING(COUNT(d.LineNum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS pages FROM  cms.dbo.POSODIN o INNER JOIN cms.dbo.POSDIN1 d ON (d.C_DocEntry = o.C_DocEntry) WHERE o.C_DocEntry = @InvoiceID /*AND o.DocSubType = 'DN'*/) > 1
                AND @pPrintPages = 'Y'
UNION ALL
             SELECT 500000 + ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    6 AS group_id,
                    'InformacionReferencia' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'NCFModificado' THEN UPPER(o.U_NCO)
                        WHEN 'FechaNCFModificado' THEN FORMAT(f.DocDate,'dd-MM-yyyy')
                        --WHEN 'CodigoModificacion' THEN CAST(1 AS NVARCHAR(1))
                        --SI EL MONTO DE LA NC ES IGUAL AL THE DE FACTURA ENTONCES ES PARA ANULAR FACTURA (1) DE LO CONTRARIO ES PARA MODIFICAR (3)
                        WHEN 'CodigoModificacion' THEN CAST(CASE WHEN (f.DocTotal-o.DocTotal) = 0 THEN 3 ELSE 3 END AS NVARCHAR(1))
                        WHEN 'RazonModificacion' THEN o.Comments
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSODIN o
         INNER JOIN cms.dbo.POSOINV f ON (f.U_FACNUM = o.U_NCO)
        CROSS APPLY (VALUES (1,'NCFModificado'), (2,'FechaNCFModificado'),(3,'CodigoModificacion'),(4,'RazonModificacion')) c (columnOrder,ColumnName)
              WHERE o.C_DocEntry = @InvoiceID
                --AND O.DocSubType = 'DN'

            ) ecf 
        WHERE @Resumen = 0 AND @eCFType IN ('33')
          --PARA CUANDO LA NOTA DE DEBITO SE LE HACE A UNA FACTURA
          AND (SELECT COUNT(i.C_DocEntry) FROM cms.dbo.POSOINV i INNER JOIN (SELECT n.U_NCO FROM cms.dbo.POSODIN n WHERE n.C_DocEntry = @InvoiceID /*AND n.DocSubType = 'DN'*/)  a ON (a.U_NCO = i.U_FACNUM)) > 0 
          --AND (SELECT COUNT(n.DocEntry) FROM SBO_AGROFEM.dbo.OINV n INNER JOIN SBO_AGROFEM.dbo.OINV i ON (i.U_FACNUM = n.U_NCO) WHERE n.DocEntry = @InvoiceID) > 0 --

		  /*
UNION ALL

--NOTA DE DEBITO AGROFEM DESDE NOTAS DE CREDITO
     SELECT ecf.*
       FROM ( 
  
             --Encabezado
             SELECT ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'ECF' THEN 'ECF'
                        WHEN 'Version' THEN '1.0' 
                        WHEN 'TipoeCF' THEN i.ecf_type
                        WHEN 'eNCF' THEN UPPER(i.ecf)
                        WHEN 'FechaVencimientoSecuencia' THEN COALESCE(NULLIF(FORMAT(i.ecf_vence,'dd-MM-yyyy'),'01-01-1900'),'#e')
                        WHEN 'IndicadorNotaCredito' THEN '#e' --LOGICA PARA NOTA DE CREDITO
                        WHEN 'IndicadorMontoGravado' THEN CASE WHEN @eCFType IN (33) THEN '0' ELSE '#e' END -- (0) EL DEALLE DE LOS ITEM NO INCLUYE EL ITBIS
                        WHEN 'TipoIngresos' THEN CASE WHEN @eCFType IN (33) THEN '01' ELSE '#e' END -- (01) Ingresos por operaciones (No financieros).
                        WHEN 'TipoPago' THEN CAST(CASE WHEN F.ExtraDays <= 1 THEN 1 ELSE 2 END AS NVARCHAR(MAX)) -- 1:Contado | 2:Credio | 3:Gratuito
                        WHEN 'FechaLimitePago' THEN CASE WHEN F.ExtraDays > 1 THEN CASE WHEN @eCFType = 43 THEN '#e' ELSE FORMAT(f.DocDueDate,'dd-MM-yyyy') END ELSE '#e' END
                        WHEN 'TerminoPago' THEN CASE WHEN F.ExtraDays > 1 THEN CASE WHEN @eCFType IN ('33') THEN REPLACE(g.PymntGroup,'C - ','') ELSE '#e' END ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM SBO_AGROFEM.dbo.OINV f
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = f.DocEntry AND i.ecf_type IN (33)) 
          LEFT JOIN SBO_AGROFEM.dbo.OCTG g ON (g.ExtraDays = f.ExtraDays /*AND g.ListNum = 2*/)
        CROSS APPLY (VALUES (1,'ECF'), (2,'Version'), (3,'TipoeCF'),(4,'eNCF'), (5,'FechaVencimientoSecuencia'),(6,'IndicadorNotaCredito'),(7,'IndicadorMontoGravado'),(8,'TipoIngresos'),(9,'TipoPago'),(10,'FechaLimitePago'),(11,'TerminoPago')) c (columnOrder,ColumnName)
              WHERE f.DocEntry = @InvoiceID
                AND f.DocSubType = 'DN'
UNION ALL     --FORMAS DE PAGO
             SELECT 20 + ROW_NUMBER() OVER (ORDER BY s.id_diario_caja_det, c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                         WHEN 'FormaPago' THEN CAST(t.ecf_payform_id AS NVARCHAR(MAX))
                         WHEN 'MontoPago' THEN FORMAT(s.monto_caja,'0.00')
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSOINV f
         INNER JOIN cms.dbo.diario_caja_det s ON (s.id_documento = f.C_DocEntry AND s.docType = 'P')
          LEFT JOIN cms.dbo.ecf_payment_forms t ON (t.ecf_payform_sap = s.id_tipo_movimiento)
        CROSS APPLY (VALUES (1,'FormaPago'), (2,'MontoPago')) c (columnOrder,ColumnName)
              WHERE f.C_DocEntry = @InvoiceID
                AND @eCFType IN ('31','32')
UNION ALL    --TOTAL DE PAGINAS
             SELECT 40 + ROW_NUMBER() OVER (ORDER BY p.pages) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    'TotalPaginas' AS xmlTag,
                    FORMAT(p.pages,'0') AS xml_value
               FROM (SELECT CEILING(COUNT(d.LineNum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS pages
                       FROM SBO_AGROFEM.dbo.INV1 d
                 INNER JOIN SBO_AGROFEM.dbo.OINV f ON (f.DocEntry = d.DocEntry AND f.DocSubType = 'DN')
                      WHERE d.DocEntry = @InvoiceID
                      GROUP BY f.DocEntry
                    ) p
              WHERE p.pages > 1
UNION ALL    --EMISOR & COMPRADOR
             SELECT 50 + ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'RNCEmisor' THEN d.RNC --PARA QUE SIEMPRE ENVIE EL RNC DE AGROFEM
                        WHEN 'RazonSocialEmisor' THEN razon_social
                        WHEN 'NombreComercial' THEN UPPER(CAST(d.descripcion AS NVARCHAR(100)))
                        WHEN 'DireccionEmisor' THEN d.direccion
                        WHEN 'TelefonoEmisor' THEN d.telefono1
                        WHEN 'CorreoEmisor' THEN d.email
                        WHEN 'WebSite' THEN d.web
                        WHEN 'NumeroFacturaInterna' THEN COALESCE(o.NumAtCard,'#e')
                        WHEN 'FechaEmision' THEN FORMAT(o.DocDate,'dd-MM-yyyy')
                        --WHEN 'RNCComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('31','33') OR (@eCFType IN ('32') AND f.DocTotal >= 250000) THEN f.U_FacNit ELSE '#e' END ELSE CASE WHEN F.U_TNegocio = 3 THEN CASE WHEN @eCFType IN ('31') OR (@eCFType IN ('32') AND f.DocTotal >= 250000) THEN '00000000000' ELSE '#e' END ELSE '#e' END END
                        --WHEN 'RazonSocialComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('31','33') OR (@eCFType IN ('32') AND f.DocTotal >= 250000) THEN f.CardName ELSE '#e' END ELSE CASE WHEN F.U_TNegocio = 3 THEN CASE WHEN @eCFType IN ('31') OR (@eCFType IN ('32') AND f.DocTotal >= 250000) THEN f.CardName ELSE '#e' END ELSE '#e' END END 
                        WHEN 'RNCComprador' THEN CASE WHEN LEN(f.U_FacNit) IN (9,11) AND PATINDEX('%[^0-9]%', f.U_FacNit) = 0 THEN o.U_FacNit ELSE CASE WHEN f.U_TNegocio = 3 THEN '00000000000' ELSE '#e' END END
                        WHEN 'RazonSocialComprador' THEN CASE WHEN LEN(f.U_FacNit) IN (9,11) AND PATINDEX('%[^0-9]%', f.U_FacNit) = 0 THEN o.CardName ELSE CASE WHEN f.U_TNegocio = 3 THEN o.CardName ELSE '#e' END END
                        WHEN 'DireccionComprador' THEN '#e' --CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('31','33') OR (@eCFType IN ('32') AND f.DocTotal >= 250000) THEN SUBSTRING(COALESCE(NULLIF(f.Address2,''),'#e'),1,100) ELSE '#e' END ELSE '#e' END 
                        WHEN 'TelefonoAdicional' THEN '#e' --CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('31','33') OR (@eCFType IN ('32') AND f.DocTotal >= 250000) THEN COALESCE(l.Cellular,l.phone1,l.phone2,'#e') ELSE '#e' END ELSE '#e' END 
                        --WHEN 'CodigoInternoComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType IN ('31','33') OR (@eCFType IN ('32') AND f.DocTotal >= 250000) THEN f.CardCode ELSE '#e' END ELSE '#e' END 
                        WHEN 'CodigoInternoComprador' THEN CASE WHEN LEN(f.U_FacNit) IN (9,11) AND PATINDEX('%[^0-9]%', f.U_FacNit) = 0 THEN o.CardCode ELSE CASE WHEN f.U_TNegocio = 3 THEN o.CardCode ELSE '#e' END END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM SBO_AGROFEM.dbo.OINV o
         INNER JOIN SBO_AGROFEM.dbo.ORIN f ON (f.U_FACNUM = o.U_NCO)
	     --INNER JOIN cms.dbo.serie s ON (s.id_serie = f.U_SCIASerie)
         INNER JOIN cms.dbo.division d ON (d.id_division = 1) 
          LEFT JOIN SBO_AGROFEM.dbo.OCRD l ON (l.CardCode = f.CardCode)
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = o.DocEntry)
        CROSS APPLY (VALUES (1,'RNCEmisor'), (2,'RazonSocialEmisor'),(3,'NombreComercial'),(4,'DireccionEmisor'),(5,'TelefonoEmisor'),(6,'CorreoEmisor'),(7,'WebSite'),(8,'NumeroFacturaInterna'),(9,'FechaEmision'),(10,'RNCComprador'),(11,'RazonSocialComprador'),(12,'DireccionComprador'),(13,'TelefonoAdicional'),(14,'CodigoInternoComprador')) c (columnOrder,ColumnName)
              WHERE o.DocEntry = @InvoiceID
                AND o.DocSubType = 'DN'
UNION ALL    --TOTALES
             SELECT 100 + ROW_NUMBER() OVER (ORDER BY c.columnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'MontoGravadoTotal' THEN CASE WHEN a.monto_grabado > 0 THEN FORMAT(a.monto_grabado,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END END
                        WHEN 'MontoGravadoI1' THEN CASE WHEN a.monto_grabadoI1 > 0 THEN FORMAT(a.monto_grabadoI1,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI2' THEN CASE WHEN a.monto_grabadoI2 > 0 THEN FORMAT(a.monto_grabadoI2,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI3' THEN CASE WHEN a.monto_grabadoI3 > 0 THEN FORMAT(a.monto_grabadoI3,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END END
                        WHEN 'MontoExento' THEN CASE WHEN (a.monto_exento > 0 AND @eCFType IN ('31','32','33','34','41','43','44','45','47')) THEN FORMAT(a.monto_exento,'0.00') ELSE '#e' END
                        WHEN 'ITBIS1' THEN CASE WHEN a.itbis1 > 0 THEN FORMAT(a.itbis1,'00') ELSE '#e' END
                        WHEN 'ITBIS2' THEN CASE WHEN a.itbis2 > 0 THEN FORMAT(a.itbis2,'00') ELSE '#e' END
                        WHEN 'ITBIS3' THEN CASE WHEN a.itbis3 > 0 THEN FORMAT(a.itbis3,'0') ELSE CASE WHEN @eCFType IN ('46') THEN '0' ELSE '#e' END END
                        WHEN 'TotalITBIS' THEN CASE WHEN a.total_itbis > 0 THEN FORMAT(a.total_itbis,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN '0.00' ELSE '#e' END END
                        WHEN 'TotalITBIS1' THEN CASE WHEN a.total_itbis1 > 0 THEN FORMAT(a.total_itbis1,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS2' THEN CASE WHEN a.total_itbis2 > 0 THEN FORMAT(a.total_itbis2,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS3' THEN CASE WHEN a.total_itbis3 > 0 THEN FORMAT(a.total_itbis3,'0.00') ELSE CASE WHEN @eCFType IN ('46') THEN '0.00' ELSE '#e' END END
                        WHEN 'MontoTotal' THEN CASE WHEN a.monto_total > 0 THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END
                        WHEN 'TotalITBISRetenido' THEN CASE WHEN @eCFType IN ('41') THEN FORMAT(0,'0.00') ELSE '#e' END
                        WHEN 'TotalISRRetencion' THEN CASE WHEN @eCFType IN ('41','47') THEN FORMAT(0,'0.00') ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM (SELECT CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabado,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (4) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_exento,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (1) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis1,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (2) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis2,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (3) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis3,
                            CAST(SUM(d.LineTotal+d.VatSum) AS NUMERIC(12,2)) AS monto_total
                       FROM SBO_AGROFEM.dbo.OINV f
                 INNER JOIN SBO_AGROFEM.dbo.INV1 d ON (d.DocEntry = f.DocEntry)
                 INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
                      WHERE f.DocEntry = @InvoiceID
                        AND f.DocSubType = 'DN'
                    ) a
        CROSS APPLY (VALUES (1,'MontoGravadoTotal'), (2,'MontoGravadoI1'), (3,'MontoGravadoI2'),(4,'MontoGravadoI3'), (5,'MontoExento'),(6,'ITBIS1'),(7,'ITBIS2'),(8,'ITBIS3'),(9,'TotalITBIS'),(10,'TotalITBIS1'),(11,'TotalITBIS2'),(12,'TotalITBIS3'),(13,'MontoTotal'),(14,'TotalITBISRetenido'),(15,'TotalISRRetencion')) c (columnOrder,ColumnName)
UNION ALL
         --2 - DetallesItems
         SELECT 1000 + ROW_NUMBER() OVER (ORDER BY d.LineNum, c.ColumnOrder) AS id_record,
                2 AS group_id,
                'DetallesItem' AS group_name,
                c.ColumnName AS xmlTag,
                CAST(CASE c.ColumnName
                    WHEN 'NumeroLinea' THEN CAST(DENSE_RANK() OVER(PARTITION BY d.DocEntry ORDER BY d.LineNum) AS NVARCHAR(MAX)) --CAST(d.LineNum+1 AS NVARCHAR(MAX))
                    WHEN 'IndicadorFacturacion' THEN CAST( CASE WHEN @eCFType IN ('46') THEN 3 ELSE t.taxecf_id END AS NVARCHAR(MAX))
                    WHEN 'IndicadorAgenteRetencionoPercepcion' THEN CAST(CASE WHEN @eCFType IN ('41','47') THEN '1' ELSE '#e' END AS NVARCHAR(MAX))
                    WHEN 'MontoITBISRetenido' THEN CASE WHEN @eCFType IN ('41') THEN '0.00' ELSE '#e' END
                    WHEN 'MontoISRRetenido' THEN CASE WHEN @eCFType IN ('41','47') THEN '0.00' ELSE '#e' END
                    WHEN 'NombreItem' THEN CAST(d.Dscription AS NVARCHAR(MAX))
                    WHEN 'IndicadorBienoServicio' THEN CAST(CASE WHEN @eCFType IN ('41','47','43') THEN 2 ELSE  CASE WHEN o.DocType = 'S' THEN 2 ELSE 1 END END AS NVARCHAR(MAX))
                    WHEN 'CantidadItem' THEN FORMAT(COALESCE(NULLIF(d.Quantity,0),1),'0.00') --PARA FORZAR LA CANTIDAD A 1 EN CASO DE NOTA DE CREDITO O DEBITO
                    WHEN 'UnidadMedida' THEN CAST(COALESCE(FORMAT(u.ecfunit_id,'0'),'#e') AS NVARCHAR(MAX))
                    WHEN 'PrecioUnitarioItem' THEN FORMAT(d.PriceBefDi,'0.00')
                    WHEN 'DescuentoMonto' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT((d.PriceBefDi*(d.DiscPrcnt/100))*d.Quantity,'0.00') ELSE '#e' END
                    WHEN 'TipoSubDescuento' THEN CASE WHEN d.DiscPrcnt > 0 THEN '%' ELSE '#e' END
                    WHEN 'SubDescuentoPorcentaje' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT(d.DiscPrcnt,'0.00') ELSE '#e' END
                    WHEN 'MontoSubDescuento' THEN CASE WHEN d.DiscPrcnt > 0 THEN FORMAT((d.PriceBefDi*(d.DiscPrcnt/100))*d.Quantity,'0.00') ELSE '#e' END
                    WHEN 'MontoItem' THEN FORMAT(d.LineTotal,'0.00')
                END AS NVARCHAR(MAX)) AS xml_value
           FROM SBO_AGROFEM.dbo.OINV o
     INNER JOIN SBO_AGROFEM.dbo.INV1 d ON (d.DocEntry = o.DocEntry)
     INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
      LEFT JOIN cms.dbo.ecf_units u ON (u.ecfsapunit_name = d.unitMsr)
    CROSS APPLY (VALUES (1,'NumeroLinea'), (2,'IndicadorFacturacion'), (3,'IndicadorAgenteRetencionoPercepcion'), (4,'MontoITBISRetenido'), (4,'MontoISRRetenido'), (5,'NombreItem'),(6,'IndicadorBienoServicio'), (7,'CantidadItem'),(8,'UnidadMedida'),(9,'PrecioUnitarioItem'),(10,'DescuentoMonto'),(11,'TipoSubDescuento'),(12,'SubDescuentoPorcentaje'),(13,'MontoSubDescuento'),(14,'MontoItem')) c (columnOrder,ColumnName)
          WHERE o.DocEntry = @InvoiceID
            AND o.DocSubType = 'DN'
UNION ALL
             --PAGINACION
             SELECT 100000+ROW_NUMBER() OVER (ORDER BY a.pagina_numero, c.columnOrder) AS id_record,
                    5 AS group_id,
                    'Paginacion' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'PaginaNo' THEN CAST(pagina_numero AS NVARCHAR(MAX))
                        WHEN 'NoLineaDesde' THEN CAST(linea_desde AS NVARCHAR(MAX))
                        WHEN 'NoLineaHasta' THEN CAST(linea_hasa AS NVARCHAR(MAX))
                        WHEN 'SubtotalMontoGravadoPagina' THEN CASE WHEN a.monto_grabado > 0 THEN FORMAT(a.monto_grabado,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado1Pagina' THEN CASE WHEN a.monto_grabadoI1 > 0 THEN FORMAT(a.monto_grabadoI1,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado2Pagina' THEN CASE WHEN a.monto_grabadoI2 > 0 THEN FORMAT(a.monto_grabadoI2,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado3Pagina' THEN CASE WHEN a.monto_grabadoI3 > 0 THEN FORMAT(a.monto_grabadoI3,'0.00') ELSE '#e' END
                        WHEN 'SubtotalExentoPagina' THEN CASE WHEN a.monto_exento > 0 THEN FORMAT(a.monto_exento,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbisPagina' THEN CASE WHEN a.total_itbis > 0 THEN FORMAT(a.total_itbis,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis1Pagina' THEN CASE WHEN a.total_itbis1 > 0 THEN FORMAT(a.total_itbis1,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis2Pagina' THEN CASE WHEN a.total_itbis2 > 0 THEN FORMAT(a.total_itbis2,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis3Pagina' THEN CASE WHEN a.total_itbis3 > 0 THEN FORMAT(a.total_itbis3,'0.00') ELSE '#e' END
                        WHEN 'MontoSubtotalPagina' THEN CASE WHEN a.monto_total > 0 THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM (SELECT group_id AS pagina_numero,
                            MIN(w.numero_linea) AS linea_desde,
                            MAX(w.numero_linea) AS linea_hasa,
                            CAST(SUM(monto_grabado) AS NUMERIC(12,2)) AS monto_grabado,
                            CAST(SUM(monto_grabadoI1) AS NUMERIC(12,2)) AS monto_grabadoI1,
                            CAST(SUM(monto_grabadoI2) AS NUMERIC(12,2)) AS monto_grabadoI2,
                            CAST(SUM(monto_grabadoI3) AS NUMERIC(12,2)) AS monto_grabadoI3,
                            CAST(SUM(monto_exento) AS NUMERIC(12,2)) AS monto_exento,
                            CAST(SUM(total_itbis) AS NUMERIC(12,2)) AS total_itbis,
                            CAST(SUM(total_itbis1) AS NUMERIC(12,2)) AS total_itbis1,
                            CAST(SUM(total_itbis2) AS NUMERIC(12,2)) AS total_itbis2,
                            CAST(SUM(total_itbis3) AS NUMERIC(12,2)) AS total_itbis3,
                            CAST(SUM(monto_total) AS NUMERIC(12,2)) AS monto_total
                       FROM (SELECT (d.linenum+1) AS numero_linea,
                                    CEILING(ROW_NUMBER() OVER(ORDER BY d.linenum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS group_id,
                                    SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.LineTotal ELSE 0 END) AS monto_grabado,
                                    SUM(CASE WHEN t.taxecf_id IN (1) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI1,
                                    SUM(CASE WHEN t.taxecf_id IN (2) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI2,
                                    SUM(CASE WHEN t.taxecf_id IN (3) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI3,
                                    SUM(CASE WHEN t.taxecf_id IN (4) THEN d.LineTotal ELSE 0 END) AS monto_exento,
                                    MAX(CASE WHEN t.taxecf_id IN (1) THEN d.VatPrcnt ELSE 0 END) AS itbis1,
                                    MAX(CASE WHEN t.taxecf_id IN (2) THEN d.VatPrcnt ELSE 0 END) AS itbis2,
                                    MAX(CASE WHEN t.taxecf_id IN (3) THEN d.VatPrcnt ELSE 0 END) AS itbis3,
                                    SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.VatSum ELSE 0 END) AS total_itbis,
                                    SUM(CASE WHEN t.taxecf_id IN (1) THEN d.VatSum ELSE 0 END) AS total_itbis1,
                                    SUM(CASE WHEN t.taxecf_id IN (2) THEN d.VatSum ELSE 0 END) AS total_itbis2,
                                    SUM(CASE WHEN t.taxecf_id IN (3) THEN d.VatSum ELSE 0 END) AS total_itbis3,
                                    SUM(d.LineTotal+d.VatSum) AS monto_total
                               FROM SBO_AGROFEM.dbo.OINV f
                         INNER JOIN SBO_AGROFEM.dbo.INV1 d ON (d.DocEntry = f.DocEntry)
                         INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
                              WHERE f.DocEntry = @InvoiceID
                                AND f.DocSubType = 'DN'
                              GROUP BY d.linenum
                            ) w
                      GROUP BY w.group_id
                    ) a
        CROSS APPLY (VALUES (1,'PaginaNo'), (2,'NoLineaDesde'), (3,'NoLineaHasta'),(4,'SubtotalMontoGravadoPagina'), (5,'SubtotalMontoGravado1Pagina'),(6,'SubtotalMontoGravado2Pagina'),(7,'SubtotalMontoGravado3Pagina'),(8,'SubtotalExentoPagina'),(9,'SubtotalItbisPagina'),(10,'SubtotalItbis1Pagina'),(11,'SubtotalItbis2Pagina'),(12,'SubtotalItbis3Pagina'),(13,'MontoSubtotalPagina')) c (columnOrder,ColumnName)
              WHERE (SELECT CEILING(COUNT(d.LineNum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS pages FROM  SBO_AGROFEM.dbo.OINV o INNER JOIN SBO_AGROFEM.dbo.INV1 d ON (d.DocEntry = o.DocEntry) WHERE o.DocEntry = @InvoiceID AND o.DocSubType = 'DN') > 1
                AND @pPrintPages = 'Y'
UNION ALL
             SELECT 500000 + ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    6 AS group_id,
                    'InformacionReferencia' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'NCFModificado' THEN UPPER(o.U_NCO)
                        WHEN 'FechaNCFModificado' THEN FORMAT(f.DocDate,'dd-MM-yyyy')
                        --WHEN 'CodigoModificacion' THEN CAST(1 AS NVARCHAR(1))
                        --SI EL MONTO DE LA NC ES IGUAL AL THE DE FACTURA ENTONCES ES PARA ANULAR FACTURA (1) DE LO CONTRARIO ES PARA MODIFICAR (3)
                        WHEN 'CodigoModificacion' THEN CAST(CASE WHEN (f.DocTotal-o.DocTotal) = 0 THEN 1 ELSE 3 END AS NVARCHAR(1))
                        WHEN 'RazonModificacion' THEN o.Comments
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM SBO_AGROFEM.dbo.OINV o
         INNER JOIN SBO_AGROFEM.dbo.ORIN f ON (f.U_FACNUM = o.U_NCO)
        CROSS APPLY (VALUES (1,'NCFModificado'), (2,'FechaNCFModificado'),(3,'CodigoModificacion'),(4,'RazonModificacion')) c (columnOrder,ColumnName)
              WHERE o.DocEntry = @InvoiceID
                AND O.DocSubType = 'DN'

            ) ecf 
        WHERE @Resumen = 0 AND @eCFType IN ('33')
          --PARA CUANDO LA NOTA DE DEBITO SE LE HACE A UNA NOTA DE CREDITO
          --
          AND (SELECT COUNT(i.DocEntry) FROM SBO_AGROFEM.dbo.ORIN i INNER JOIN (SELECT n.U_NCO FROM SBO_AGROFEM.dbo.OINV n WHERE n.DocEntry = @InvoiceID AND n.DocSubType = 'DN')  a ON (a.U_NCO = i.U_FACNUM)) > 0 
          --AND (SELECT COUNT(n.DocEntry) FROM SBO_AGROFEM.dbo.OINV n INNER JOIN SBO_AGROFEM.dbo.ORIN i ON (i.U_FACNUM = n.U_NCO) WHERE n.DocEntry = @InvoiceID) > 0 

UNION ALL

--------------------41 - COMPRAS ELECTRONICO
     SELECT ecf.*
       FROM ( 
  
             --Encabezado
             SELECT ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'ECF' THEN 'ECF'
                        WHEN 'Version' THEN '1.0' 
                        WHEN 'TipoeCF' THEN i.ecf_type
                        WHEN 'eNCF' THEN i.ecf
                        WHEN 'FechaVencimientoSecuencia' THEN COALESCE(NULLIF(FORMAT(i.ecf_vence,'dd-MM-yyyy'),'01-01-1900'),'#e')
                        WHEN 'IndicadorNotaCredito' THEN '#e' --LOGICA PARA NOTA DE CREDITO
                        WHEN 'IndicadorMontoGravado' THEN CASE WHEN @eCFType   IN (41) THEN '0' ELSE '#e' END -- (0) EL DEALLE DE LOS ITEM NO INCLUYE EL ITBIS
                        WHEN 'TipoIngresos' THEN CASE WHEN @eCFType   IN (31,32,33,34,44,45,46) THEN '01' ELSE '#e' END -- (01) Ingresos por operaciones (No financieros).
                        WHEN 'TipoPago' THEN CAST(CASE WHEN f.ExtraDays <= 1 THEN 1 ELSE 2 END AS NVARCHAR(MAX)) -- 1:Contado | 2:Credio | 3:Gratuito
                        WHEN 'FechaLimitePago' THEN CASE WHEN f.ExtraDays > 1 THEN CASE WHEN @eCFType   = 43 THEN '#e' ELSE FORMAT(f.DocDueDate,'dd-MM-yyyy') END ELSE '#e' END
                        WHEN 'TerminoPago' THEN '#e' --CASE WHEN F.ExtraDays > 1 THEN CASE WHEN @eCFType   IN ('31','32','33','41','44','45','46','47') THEN REPLACE(g.PymntGroup,'P - ','') ELSE '#e' END ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM SBO_AGROFEM.dbo.OPCH f
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = f.DocEntry AND i.ecf_type IN (41)) 
          LEFT JOIN SBO_AGROFEM.dbo.OCTG g ON (g.ExtraDays = f.ExtraDays)
        CROSS APPLY (VALUES (1,'ECF'), (2,'Version'), (3,'TipoeCF'),(4,'eNCF'), (5,'FechaVencimientoSecuencia'),(6,'IndicadorNotaCredito'),(7,'IndicadorMontoGravado'),(8,'TipoIngresos'),(9,'TipoPago'),(10,'FechaLimitePago'),(11,'TerminoPago')) c (columnOrder,ColumnName)
              WHERE f.DocEntry = @InvoiceID
UNION ALL     --FORMAS DE PAGO
             SELECT 20 + ROW_NUMBER() OVER (ORDER BY s.id_diario_caja_det, c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                         WHEN 'FormaPago' THEN CAST(t.ecf_payform_id AS NVARCHAR(MAX))
                         WHEN 'MontoPago' THEN FORMAT(s.monto_caja,'0.00')
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSOINV f
         INNER JOIN cms.dbo.diario_caja_det s ON (s.id_documento = f.C_DocEntry AND s.docType = 'P')
          LEFT JOIN cms.dbo.ecf_payment_forms t ON (t.ecf_payform_sap = s.id_tipo_movimiento)
        CROSS APPLY (VALUES (1,'FormaPago'), (2,'MontoPago')) c (columnOrder,ColumnName)
              WHERE f.C_DocEntry = @InvoiceID
                AND @eCFType   IN ('31','32','33','44','45','46','47')
UNION ALL    --TOTAL DE PAGINAS
             SELECT 40 + ROW_NUMBER() OVER (ORDER BY p.pages) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    'TotalPaginas' AS xmlTag,
                    FORMAT(p.pages,'0') AS xml_value
               FROM (SELECT CEILING(COUNT(d.LineNum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS pages
                       FROM SBO_AGROFEM.dbo.PCH1 d
                 INNER JOIN SBO_AGROFEM.dbo.OPCH f ON (f.DocEntry = d.DocEntry)
                      WHERE d.DocEntry = @InvoiceID
                      GROUP BY f.DocEntry
                    ) p
              WHERE p.pages > 1 AND 'N' /*@pPrintPages*/ = 'Y'
UNION ALL    --EMISOR & COMPRADOR
             SELECT 50 + ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'RNCEmisor' THEN d.RNC --PARA QUE SIEMPRE ENVIE EL RNC DE AGROFEM
                        WHEN 'RazonSocialEmisor' THEN razon_social
                        WHEN 'NombreComercial' THEN UPPER(CAST(d.descripcion AS NVARCHAR(100)))
                        WHEN 'DireccionEmisor' THEN d.direccion
                        WHEN 'TelefonoEmisor' THEN d.telefono1
                        WHEN 'CorreoEmisor' THEN d.email
                        WHEN 'WebSite' THEN d.web
                        WHEN 'NumeroFacturaInterna' THEN COALESCE(NULLIF(f.NumAtCard,''),'#e')
                        WHEN 'FechaEmision' THEN FORMAT(f.DocDate,'dd-MM-yyyy')
                        WHEN 'RNCComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType   IN ('31','32','33','34','41','44','45','46') THEN f.U_FacNit ELSE '#e' END ELSE CASE WHEN F.U_TNegocio = 3 THEN CASE WHEN @eCFType   IN ('31','32','33','34','41','44','45','46') THEN '00000000000' ELSE '#e' END ELSE '#e' END END
                        WHEN 'RazonSocialComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType   IN ('31','32','33','34','41','44','45','46') THEN f.CardName ELSE '#e' END ELSE CASE WHEN F.U_TNegocio = 3 THEN CASE WHEN @eCFType   IN ('31','32','33','34','41','44','45','46') THEN f.CardName ELSE '#e' END ELSE '#e' END END 
                        WHEN 'DireccionComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType   IN ('31','32','33','34','44','45','46') THEN SUBSTRING(COALESCE(NULLIF(f.Address2,''),'#e'),1,100) ELSE '#e' END ELSE '#e' END 
                        WHEN 'TelefonoAdicional' THEN '#e'  
                        --WHEN 'TelefonoAdicional' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType   IN ('31','32','33','34','44','45','46') THEN COALESCE(l.Cellular,l.phone1,l.phone2,'#e') ELSE '#e' END ELSE '#e' END 
                        WHEN 'CodigoInternoComprador' THEN CASE WHEN (LEN(f.U_FacNit) = 9 OR LEN(f.U_FacNit) = 11) THEN CASE WHEN @eCFType   IN ('31','32','33','34','44','45','46') THEN f.CardCode ELSE '#e' END ELSE '#e' END 
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.division d
          LEFT JOIN SBO_AGROFEM.dbo.OPCH f ON (f.DocEntry = @InvoiceID)
          LEFT JOIN SBO_AGROFEM.dbo.OCRD l ON (l.CardCode = f.CardCode)
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = f.DocEntry AND i.ecf_type IN (41))
        CROSS APPLY (VALUES (1,'RNCEmisor'), (2,'RazonSocialEmisor'),(3,'NombreComercial'),(4,'DireccionEmisor'),(5,'TelefonoEmisor'),(6,'CorreoEmisor'),(7,'WebSite'),(8,'NumeroFacturaInterna'),(9,'FechaEmision'),(10,'RNCComprador'),(11,'RazonSocialComprador'),(12,'DireccionComprador'),(13,'TelefonoAdicional'),(14,'CodigoInternoComprador')) c (columnOrder,ColumnName)
              WHERE d.id_division = 1 --FIJO PORQUE LAS COMPRAS IMFORMALES SOLO SE HACEN EL MF INDUSTRIAL
UNION ALL    --TOTALES
             SELECT 100 + ROW_NUMBER() OVER (ORDER BY c.columnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'MontoGravadoTotal' THEN CASE WHEN a.monto_grabado > 0 THEN FORMAT(a.monto_grabado,'0.00') ELSE CASE WHEN @eCFType   IN ('46') THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END END
                        WHEN 'MontoGravadoI1' THEN CASE WHEN a.monto_grabadoI1 > 0 THEN FORMAT(a.monto_grabadoI1,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI2' THEN CASE WHEN a.monto_grabadoI2 > 0 THEN FORMAT(a.monto_grabadoI2,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI3' THEN CASE WHEN a.monto_grabadoI3 > 0 THEN FORMAT(a.monto_grabadoI3,'0.00') ELSE CASE WHEN @eCFType   IN ('46') THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END END
                        WHEN 'MontoExento' THEN CASE WHEN (a.monto_exento > 0 AND @eCFType   IN ('31','32','33','34','41','43','44','45','47')) THEN FORMAT(a.monto_exento,'0.00') ELSE '#e' END
                        WHEN 'ITBIS1' THEN CASE WHEN a.itbis1 > 0 THEN FORMAT(a.itbis1,'00') ELSE '#e' END
                        WHEN 'ITBIS2' THEN CASE WHEN a.itbis2 > 0 THEN FORMAT(a.itbis2,'00') ELSE '#e' END
                        WHEN 'ITBIS3' THEN CASE WHEN a.itbis3 > 0 THEN FORMAT(a.itbis3,'0') ELSE CASE WHEN @eCFType   IN ('46') THEN '0' ELSE '#e' END END
                        WHEN 'TotalITBIS' THEN CASE WHEN a.total_itbis > 0 THEN FORMAT(a.total_itbis,'0.00') ELSE CASE WHEN @eCFType   IN ('46') THEN '0.00' ELSE '#e' END END
                        WHEN 'TotalITBIS1' THEN CASE WHEN a.total_itbis1 > 0 THEN FORMAT(a.total_itbis1,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS2' THEN CASE WHEN a.total_itbis2 > 0 THEN FORMAT(a.total_itbis2,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS3' THEN CASE WHEN a.total_itbis3 > 0 THEN FORMAT(a.total_itbis3,'0.00') ELSE CASE WHEN @eCFType   IN ('46') THEN '0.00' ELSE '#e' END END
                        WHEN 'MontoTotal' THEN CASE WHEN a.monto_total > 0 THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END
                        WHEN 'TotalITBISRetenido' THEN CASE WHEN @eCFType   IN ('41') THEN FORMAT(a.retitbis,'0.00') ELSE '#e' END
                        WHEN 'TotalISRRetencion' THEN CASE WHEN @eCFType   IN ('41','47') THEN FORMAT(a.retirs,'0.00') ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM (SELECT CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabado,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (4) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_exento,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (1) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis1,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (2) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis2,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (3) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis3,
                            CAST(SUM(d.VatSum) * MAX(COALESCE(n.retitbis,0)) AS NUMERIC(12,2)) AS retitbis,
                            CAST(SUM(d.LineTotal) * MAX(COALESCE(n.retirs,0)) AS NUMERIC(12,2)) AS retirs,
                            CAST(SUM(d.LineTotal+d.VatSum) AS NUMERIC(12,2)) AS monto_total
                       FROM SBO_AGROFEM.dbo.OPCH f
                 INNER JOIN SBO_AGROFEM.dbo.PCH1 d ON (d.DocEntry = f.DocEntry)
                 INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
                  LEFT JOIN (SELECT r.AbsEntry,
                                    CAST(SUM(CASE WHEN t.U_TIPO = 'I' THEN r.Rate ELSE 0 END) / 100 AS NUMERIC(10,4)) AS retitbis,
                                    CAST(SUM(CASE WHEN t.U_TIPO = 'R' THEN r.Rate ELSE 0 END) / 100 AS NUMERIC(10,4)) AS retirs
                               FROM SBO_AGROFEM.DBO.PCH5 r
                          LEFT JOIN SBO_AGROFEM.DBO.OWHT t ON (t.WTCode = r.WTCode)
                              WHERE r.AbsEntry = @InvoiceID
                           GROUP BY r.AbsEntry) n ON (n.AbsEntry = f.DocEntry)
                      WHERE f.DocEntry = @InvoiceID
                    ) a
        CROSS APPLY (VALUES (1,'MontoGravadoTotal'), (2,'MontoGravadoI1'), (3,'MontoGravadoI2'),(4,'MontoGravadoI3'), (5,'MontoExento'),(6,'ITBIS1'),(7,'ITBIS2'),(8,'ITBIS3'),(9,'TotalITBIS'),(10,'TotalITBIS1'),(11,'TotalITBIS2'),(12,'TotalITBIS3'),(13,'MontoTotal'),(14,'TotalITBISRetenido'),(15,'TotalISRRetencion')) c (columnOrder,ColumnName)
UNION ALL
         --2 - DetallesItems
         SELECT 1000 + ROW_NUMBER() OVER (ORDER BY a.LineNum, c.ColumnOrder) AS id_record,
                2 AS group_id,
                'DetallesItem' AS group_name,
                c.ColumnName AS xmlTag,
                CAST(CASE c.ColumnName
                    WHEN 'NumeroLinea' THEN CAST(a.LineNum+1 AS NVARCHAR(MAX))
                    WHEN 'IndicadorFacturacion' THEN CAST( CASE WHEN @eCFType   IN ('46') THEN 3 ELSE a.taxecf_id END AS NVARCHAR(MAX))
                    WHEN 'IndicadorAgenteRetencionoPercepcion' THEN CAST(CASE WHEN @eCFType   IN ('41','47') THEN '1' ELSE '#e' END AS NVARCHAR(MAX))
                    WHEN 'MontoITBISRetenido' THEN CASE WHEN @eCFType   IN ('41') THEN FORMAT(a.retitbis,'0.00') ELSE '#e' END
                    WHEN 'MontoISRRetenido' THEN CASE WHEN @eCFType   IN ('41','47') THEN FORMAT(a.retirs,'0.00') ELSE '#e' END
                    WHEN 'NombreItem' THEN CAST(SUBSTRING(a.Dscription,1,80) AS NVARCHAR(MAX))
                    WHEN 'IndicadorBienoServicio' THEN CAST(CASE WHEN @eCFType   IN ('41','47','43') THEN 2 ELSE CASE WHEN a.DocType = 'S' THEN 2 ELSE 1 END END AS NVARCHAR(MAX))
                    WHEN 'CantidadItem' THEN FORMAT(a.Quantity,'0.00')
                    WHEN 'UnidadMedida' THEN CAST(a.ecfunit_id AS NVARCHAR(MAX))
                    WHEN 'PrecioUnitarioItem' THEN FORMAT(a.PriceBefDi,'0.00')
                    WHEN 'DescuentoMonto' THEN CASE WHEN a.DiscPrcnt > 0 THEN FORMAT((a.PriceBefDi*(a.DiscPrcnt/100))*a.Quantity,'0.00') ELSE '#e' END
                    WHEN 'TipoSubDescuento' THEN CASE WHEN a.DiscPrcnt > 0 THEN '%' ELSE '#e' END
                    WHEN 'SubDescuentoPorcentaje' THEN CASE WHEN a.DiscPrcnt > 0 THEN FORMAT(a.DiscPrcnt,'0.00') ELSE '#e' END
                    WHEN 'MontoSubDescuento' THEN CASE WHEN a.DiscPrcnt > 0 THEN FORMAT((a.PriceBefDi*(a.DiscPrcnt/100))*a.Quantity,'0.00') ELSE '#e' END
                    WHEN 'MontoItem' THEN FORMAT(a.LineTotal,'0.00')
                END AS NVARCHAR(MAX)) AS xml_value
           FROM (
                SELECT ROW_NUMBER() OVER(ORDER BY d.Dscription)-1 AS LineNum,
                       t.taxecf_id,
                       d.Dscription,
                       f.DocType,
                       COALESCE(u.ecfunit_id,43) AS ecfunit_id, --PARA FORZAR UNIDAD SI ESTE LLEGA VACIA
                       COALESCE(NULLIF(d.Quantity,0),1) AS Quantity, --PARA USAR 1 EN CASO DE SERVICIO
                       d.PriceBefDi AS PriceBefDi,
                       d.DiscPrcnt AS DiscPrcnt,
                       d.LineTotal AS LineTotal,
                       CAST(d.VatSum * COALESCE(n.retitbis,0) AS NUMERIC(12,2)) AS retitbis,
                       CAST(d.LineTotal * COALESCE(n.retirs,0) AS NUMERIC(12,2)) AS retirs

                  FROM SBO_AGROFEM.dbo.OPCH f 
            INNER JOIN SBO_AGROFEM.dbo.PCH1 d ON (d.DocEntry = f.DocEntry AND d.PriceBefDi > 0)
            INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
             LEFT JOIN cms.dbo.ecf_units u ON (u.ecfsapunit_namemf = d.unitMsr)
             LEFT JOIN (SELECT r.AbsEntry,
                               CAST(SUM(CASE WHEN t.U_TIPO = 'I' THEN r.Rate ELSE 0 END) / 100 AS NUMERIC(10,4)) AS retitbis,
                               CAST(SUM(CASE WHEN t.U_TIPO = 'R' THEN r.Rate ELSE 0 END) / 100 AS NUMERIC(10,4)) AS retirs
                          FROM SBO_AGROFEM.DBO.PCH5 r
                     LEFT JOIN SBO_AGROFEM.DBO.OWHT t ON (t.WTCode = r.WTCode)
                         WHERE r.AbsEntry = @InvoiceID
                      GROUP BY r.AbsEntry) n ON (n.AbsEntry = f.DocEntry)
                WHERE f.DocEntry = @InvoiceID
                   

                ) a
    CROSS APPLY (VALUES (1,'NumeroLinea'), (2,'IndicadorFacturacion'), (3,'IndicadorAgenteRetencionoPercepcion'), (4,'MontoITBISRetenido'), (4,'MontoISRRetenido'), (5,'NombreItem'),(6,'IndicadorBienoServicio'), (7,'CantidadItem'),(8,'UnidadMedida'),(9,'PrecioUnitarioItem'),(10,'DescuentoMonto'),(11,'TipoSubDescuento'),(12,'SubDescuentoPorcentaje'),(13,'MontoSubDescuento'),(14,'MontoItem')) c (columnOrder,ColumnName)

UNION ALL
             --PAGINACION
             SELECT 100000+ROW_NUMBER() OVER (ORDER BY a.pagina_numero, c.columnOrder) AS id_record,
                    5 AS group_id,
                    'Paginacion' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'PaginaNo' THEN CAST(pagina_numero AS NVARCHAR(MAX))
                        WHEN 'NoLineaDesde' THEN CAST(linea_desde AS NVARCHAR(MAX))
                        WHEN 'NoLineaHasta' THEN CAST(linea_hasa AS NVARCHAR(MAX))
                        WHEN 'SubtotalMontoGravadoPagina' THEN CASE WHEN a.monto_grabado > 0 THEN FORMAT(a.monto_grabado,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado1Pagina' THEN CASE WHEN a.monto_grabadoI1 > 0 THEN FORMAT(a.monto_grabadoI1,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado2Pagina' THEN CASE WHEN a.monto_grabadoI2 > 0 THEN FORMAT(a.monto_grabadoI2,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado3Pagina' THEN CASE WHEN a.monto_grabadoI3 > 0 THEN FORMAT(a.monto_grabadoI3,'0.00') ELSE '#e' END
                        WHEN 'SubtotalExentoPagina' THEN CASE WHEN a.monto_exento > 0 THEN FORMAT(a.monto_exento,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbisPagina' THEN CASE WHEN a.total_itbis > 0 THEN FORMAT(a.total_itbis,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis1Pagina' THEN CASE WHEN a.total_itbis1 > 0 THEN FORMAT(a.total_itbis1,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis2Pagina' THEN CASE WHEN a.total_itbis2 > 0 THEN FORMAT(a.total_itbis2,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis3Pagina' THEN CASE WHEN a.total_itbis3 > 0 THEN FORMAT(a.total_itbis3,'0.00') ELSE '#e' END
                        WHEN 'MontoSubtotalPagina' THEN CASE WHEN a.monto_total > 0 THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM (SELECT group_id AS pagina_numero,
                            MIN(w.numero_linea) AS linea_desde,
                            MAX(w.numero_linea) AS linea_hasa,
                            CAST(SUM(monto_grabado) AS NUMERIC(12,2)) AS monto_grabado,
                            CAST(SUM(monto_grabadoI1) AS NUMERIC(12,2)) AS monto_grabadoI1,
                            CAST(SUM(monto_grabadoI2) AS NUMERIC(12,2)) AS monto_grabadoI2,
                            CAST(SUM(monto_grabadoI3) AS NUMERIC(12,2)) AS monto_grabadoI3,
                            CAST(SUM(monto_exento) AS NUMERIC(12,2)) AS monto_exento,
                            CAST(SUM(total_itbis) AS NUMERIC(12,2)) AS total_itbis,
                            CAST(SUM(total_itbis1) AS NUMERIC(12,2)) AS total_itbis1,
                            CAST(SUM(total_itbis2) AS NUMERIC(12,2)) AS total_itbis2,
                            CAST(SUM(total_itbis3) AS NUMERIC(12,2)) AS total_itbis3,
                            CAST(SUM(monto_total) AS NUMERIC(12,2)) AS monto_total
                       FROM (SELECT (d.linenum+1) AS numero_linea,
                                    CEILING(ROW_NUMBER() OVER(ORDER BY d.linenum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS group_id,
                                    SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.LineTotal ELSE 0 END) AS monto_grabado,
                                    SUM(CASE WHEN t.taxecf_id IN (1) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI1,
                                    SUM(CASE WHEN t.taxecf_id IN (2) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI2,
                                    SUM(CASE WHEN t.taxecf_id IN (3) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI3,
                                    SUM(CASE WHEN t.taxecf_id IN (4) THEN d.LineTotal ELSE 0 END) AS monto_exento,
                                    MAX(CASE WHEN t.taxecf_id IN (1) THEN d.VatPrcnt ELSE 0 END) AS itbis1,
                                    MAX(CASE WHEN t.taxecf_id IN (2) THEN d.VatPrcnt ELSE 0 END) AS itbis2,
                                    MAX(CASE WHEN t.taxecf_id IN (3) THEN d.VatPrcnt ELSE 0 END) AS itbis3,
                                    SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.VatSum ELSE 0 END) AS total_itbis,
                                    SUM(CASE WHEN t.taxecf_id IN (1) THEN d.VatSum ELSE 0 END) AS total_itbis1,
                                    SUM(CASE WHEN t.taxecf_id IN (2) THEN d.VatSum ELSE 0 END) AS total_itbis2,
                                    SUM(CASE WHEN t.taxecf_id IN (3) THEN d.VatSum ELSE 0 END) AS total_itbis3,
                                    SUM(d.LineTotal+d.VatSum) AS monto_total
                               FROM SBO_AGROFEM.dbo.OPCH f
                         INNER JOIN SBO_AGROFEM.dbo.PCH1 d ON (d.DocEntry = f.DocEntry)
                         INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
                              WHERE f.DocEntry = @InvoiceID
                              GROUP BY d.linenum
                            ) w
                      GROUP BY w.group_id
                    ) a
        CROSS APPLY (VALUES (1,'PaginaNo'), (2,'NoLineaDesde'), (3,'NoLineaHasta'),(4,'SubtotalMontoGravadoPagina'), (5,'SubtotalMontoGravado1Pagina'),(6,'SubtotalMontoGravado2Pagina'),(7,'SubtotalMontoGravado3Pagina'),(8,'SubtotalExentoPagina'),(9,'SubtotalItbisPagina'),(10,'SubtotalItbis1Pagina'),(11,'SubtotalItbis2Pagina'),(12,'SubtotalItbis3Pagina'),(13,'MontoSubtotalPagina')) c (columnOrder,ColumnName)
              WHERE (SELECT CEILING(COUNT(d.LineNum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS pages FROM SBO_AGROFEM.dbo.PCH1 d WHERE d.DocEntry = @InvoiceID) > 1
                AND @pPrintPages = 'Y'
            ) ecf 
        WHERE @Resumen = 0 AND @eCFType   IN ('41')


UNION ALL

--------------------43 - GASTOS MENORES ELECTRONICOS
     SELECT ecf.*
       FROM ( 
  
             --Encabezado
             SELECT ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'ECF' THEN 'ECF'
                        WHEN 'Version' THEN '1.0' 
                        WHEN 'TipoeCF' THEN i.ecf_type
                        WHEN 'eNCF' THEN i.ecf
                        WHEN 'FechaVencimientoSecuencia' THEN COALESCE(NULLIF(FORMAT(i.ecf_vence,'dd-MM-yyyy'),'01-01-1900'),'#e')
                        WHEN 'IndicadorNotaCredito' THEN '#e' --LOGICA PARA NOTA DE CREDITO
                        WHEN 'IndicadorMontoGravado' THEN CASE WHEN @eCFType   IN (41) THEN '0' ELSE '#e' END -- (0) EL DEALLE DE LOS ITEM NO INCLUYE EL ITBIS
                        WHEN 'TipoIngresos' THEN CASE WHEN @eCFType   IN (31,32,33,34,44,45,46) THEN '01' ELSE '#e' END -- (01) Ingresos por operaciones (No financieros).
                        WHEN 'TipoPago' THEN CAST(CASE WHEN f.ExtraDays <= 1 THEN 1 ELSE 2 END AS NVARCHAR(MAX)) -- 1:Contado | 2:Credio | 3:Gratuito
                        WHEN 'FechaLimitePago' THEN CASE WHEN f.ExtraDays > 1 THEN CASE WHEN @eCFType = 43 THEN '#e' ELSE FORMAT(f.DocDueDate,'dd-MM-yyyy') END ELSE '#e' END
                        WHEN 'TerminoPago' THEN CASE WHEN F.ExtraDays > 1 THEN CASE WHEN @eCFType   IN ('31','32','33','41','44','45','46','47') THEN REPLACE(g.PymntGroup,'P - ','') ELSE '#e' END ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM SBO_AGROFEM.dbo.OPCH f
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = f.DocEntry AND i.ecf_type IN (43)) 
          LEFT JOIN SBO_AGROFEM.dbo.OCTG g ON (g.ExtraDays = f.ExtraDays)
        CROSS APPLY (VALUES (1,'ECF'), (2,'Version'), (3,'TipoeCF'),(4,'eNCF'), (5,'FechaVencimientoSecuencia'),(6,'IndicadorNotaCredito'),(7,'IndicadorMontoGravado'),(8,'TipoIngresos'),(9,'TipoPago'),(10,'FechaLimitePago'),(11,'TerminoPago')) c (columnOrder,ColumnName)
              WHERE f.DocEntry = @InvoiceID
UNION ALL     --FORMAS DE PAGO
             SELECT 20 + ROW_NUMBER() OVER (ORDER BY s.id_diario_caja_det, c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                         WHEN 'FormaPago' THEN CAST(t.ecf_payform_id AS NVARCHAR(MAX))
                         WHEN 'MontoPago' THEN FORMAT(s.monto_caja,'0.00')
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.POSOINV f
         INNER JOIN cms.dbo.diario_caja_det s ON (s.id_documento = f.C_DocEntry AND s.docType = 'P')
          LEFT JOIN cms.dbo.ecf_payment_forms t ON (t.ecf_payform_sap = s.id_tipo_movimiento)
        CROSS APPLY (VALUES (1,'FormaPago'), (2,'MontoPago')) c (columnOrder,ColumnName)
              WHERE f.C_DocEntry = @InvoiceID
                AND @eCFType   IN ('31','32','33','44','45','46','47')
UNION ALL    --TOTAL DE PAGINAS
             SELECT 40 + ROW_NUMBER() OVER (ORDER BY p.pages) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    'TotalPaginas' AS xmlTag,
                    FORMAT(p.pages,'0') AS xml_value
               FROM (SELECT CEILING(COUNT(d.LineNum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS pages
                       FROM SBO_AGROFEM.dbo.PCH1 d
                 INNER JOIN SBO_AGROFEM.dbo.OPCH f ON (f.DocEntry = d.DocEntry)
                      WHERE d.DocEntry = @InvoiceID
                      GROUP BY f.DocEntry
                    ) p
              WHERE p.pages > 1 AND @pPrintPages = 'Y'
UNION ALL    --EMISOR & COMPRADOR
             SELECT 50 + ROW_NUMBER() OVER (ORDER BY c.ColumnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'RNCEmisor' THEN d.RNC --PARA QUE SIEMPRE ENVIE EL RNC DE AGROFEM
                        WHEN 'RazonSocialEmisor' THEN razon_social
                        WHEN 'NombreComercial' THEN UPPER(CAST(d.descripcion AS NVARCHAR(100)))
                        WHEN 'DireccionEmisor' THEN d.direccion
                        WHEN 'TelefonoEmisor' THEN d.telefono1
                        WHEN 'CorreoEmisor' THEN d.email
                        WHEN 'WebSite' THEN d.web
                        WHEN 'NumeroFacturaInterna' THEN COALESCE(NULLIF(f.NumAtCard,''),'#e')
                        WHEN 'FechaEmision' THEN FORMAT(f.DocDate,'dd-MM-yyyy')
                        WHEN 'RNCComprador' THEN '#e'
                        WHEN 'RazonSocialComprador' THEN '#e'
                        WHEN 'DireccionComprador' THEN '#e'
                        WHEN 'TelefonoAdicional' THEN '#e'  
                        WHEN 'CodigoInternoComprador' THEN '#e'
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM cms.dbo.division d
          LEFT JOIN SBO_AGROFEM.dbo.OPCH f ON (f.DocEntry = @InvoiceID)
          LEFT JOIN SBO_AGROFEM.dbo.OCRD l ON (l.CardCode = f.CardCode)
         INNER JOIN cms.dbo.ecf_xml_invoice i ON (i.doc_id = f.DocEntry AND i.ecf_type IN (43))
        CROSS APPLY (VALUES (1,'RNCEmisor'), (2,'RazonSocialEmisor'),(3,'NombreComercial'),(4,'DireccionEmisor'),(5,'TelefonoEmisor'),(6,'CorreoEmisor'),(7,'WebSite'),(8,'NumeroFacturaInterna'),(9,'FechaEmision'),(10,'RNCComprador'),(11,'RazonSocialComprador'),(12,'DireccionComprador'),(13,'TelefonoAdicional'),(14,'CodigoInternoComprador')) c (columnOrder,ColumnName)
              WHERE d.id_division = 1 --FIJO PORQUE LAS COMPRAS IMFORMALES SOLO SE HACEN EL MF INDUSTRIAL
UNION ALL    --TOTALES
             SELECT 100 + ROW_NUMBER() OVER (ORDER BY c.columnOrder) AS id_record,
                    1 AS group_id,
                    'Encabezado' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'MontoGravadoTotal' THEN '#e' --CASE WHEN a.monto_grabado > 0 THEN FORMAT(a.monto_grabado,'0.00') ELSE CASE WHEN @eCFType   IN ('46') THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END END
                        WHEN 'MontoGravadoI1' THEN '#e' --CASE WHEN a.monto_grabadoI1 > 0 THEN FORMAT(a.monto_grabadoI1,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI2' THEN '#e' --CASE WHEN a.monto_grabadoI2 > 0 THEN FORMAT(a.monto_grabadoI2,'0.00') ELSE '#e' END
                        WHEN 'MontoGravadoI3' THEN '#e' --CASE WHEN a.monto_grabadoI3 > 0 THEN FORMAT(a.monto_grabadoI3,'0.00') ELSE CASE WHEN @eCFType   IN ('46') THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END END
                        WHEN 'MontoExento' THEN CASE WHEN (a.monto_exento > 0 AND @eCFType   IN ('31','32','33','34','41','43','44','45','47')) THEN FORMAT(a.monto_exento,'0.00') ELSE '#e' END
                        WHEN 'ITBIS1' THEN '#e' --CASE WHEN a.itbis1 > 0 THEN FORMAT(a.itbis1,'00') ELSE '#e' END
                        WHEN 'ITBIS2' THEN '#e' --CASE WHEN a.itbis2 > 0 THEN FORMAT(a.itbis2,'00') ELSE '#e' END
                        WHEN 'ITBIS3' THEN '#e' --CASE WHEN a.itbis3 > 0 THEN FORMAT(a.itbis3,'0') ELSE CASE WHEN @eCFType   IN ('46') THEN '0' ELSE '#e' END END
                        WHEN 'TotalITBIS' THEN '#e' --CASE WHEN a.total_itbis > 0 THEN FORMAT(a.total_itbis,'0.00') ELSE CASE WHEN @eCFType   IN ('46') THEN '0.00' ELSE '#e' END END
                        WHEN 'TotalITBIS1' THEN '#e' --CASE WHEN a.total_itbis1 > 0 THEN FORMAT(a.total_itbis1,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS2' THEN '#e' --CASE WHEN a.total_itbis2 > 0 THEN FORMAT(a.total_itbis2,'0.00') ELSE '#e' END
                        WHEN 'TotalITBIS3' THEN '#e' --CASE WHEN a.total_itbis3 > 0 THEN FORMAT(a.total_itbis3,'0.00') ELSE CASE WHEN @eCFType   IN ('46') THEN '0.00' ELSE '#e' END END
                        WHEN 'MontoTotal' THEN CASE WHEN a.monto_total > 0 THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END
                        WHEN 'TotalITBISRetenido' THEN '#e' --CASE WHEN @eCFType   IN ('41') THEN FORMAT(a.retitbis,'0.00') ELSE '#e' END
                        WHEN 'TotalISRRetencion' THEN '#e' --CASE WHEN @eCFType   IN ('41','47') THEN FORMAT(a.retirs,'0.00') ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM (SELECT CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabado,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_grabadoI3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (4) THEN d.LineTotal ELSE 0 END) AS NUMERIC(12,2)) AS monto_exento,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (1) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis1,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (2) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis2,
                            CAST(MAX(CASE WHEN t.taxecf_id IN (3) THEN d.VatPrcnt ELSE 0 END) AS NUMERIC(12,2)) AS itbis3,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (1) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis1,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (2) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis2,
                            CAST(SUM(CASE WHEN t.taxecf_id IN (3) THEN d.VatSum ELSE 0 END) AS NUMERIC(12,2)) AS total_itbis3,
                            CAST(SUM(d.VatSum) * MAX(COALESCE(n.retitbis,0)) AS NUMERIC(12,2)) AS retitbis,
                            CAST(SUM(d.LineTotal) * MAX(COALESCE(n.retirs,0)) AS NUMERIC(12,2)) AS retirs,
                            CAST(SUM(d.LineTotal+d.VatSum) AS NUMERIC(12,2)) AS monto_total
                       FROM SBO_AGROFEM.dbo.OPCH f
                 INNER JOIN SBO_AGROFEM.dbo.PCH1 d ON (d.DocEntry = f.DocEntry)
                 INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
                  LEFT JOIN (SELECT r.AbsEntry,
                                    CAST(SUM(CASE WHEN t.U_TIPO = 'I' THEN r.Rate ELSE 0 END) / 100 AS NUMERIC(10,4)) AS retitbis,
                                    CAST(SUM(CASE WHEN t.U_TIPO = 'R' THEN r.Rate ELSE 0 END) / 100 AS NUMERIC(10,4)) AS retirs
                               FROM SBO_AGROFEM.DBO.PCH5 r
                          LEFT JOIN SBO_AGROFEM.DBO.OWHT t ON (t.WTCode = r.WTCode)
                              WHERE r.AbsEntry = @InvoiceID
                           GROUP BY r.AbsEntry) n ON (n.AbsEntry = f.DocEntry)
                      WHERE f.DocEntry = @InvoiceID
                    ) a
        CROSS APPLY (VALUES (1,'MontoGravadoTotal'), (2,'MontoGravadoI1'), (3,'MontoGravadoI2'),(4,'MontoGravadoI3'), (5,'MontoExento'),(6,'ITBIS1'),(7,'ITBIS2'),(8,'ITBIS3'),(9,'TotalITBIS'),(10,'TotalITBIS1'),(11,'TotalITBIS2'),(12,'TotalITBIS3'),(13,'MontoTotal'),(14,'TotalITBISRetenido'),(15,'TotalISRRetencion')) c (columnOrder,ColumnName)
UNION ALL
         --2 - DetallesItems
         SELECT 1000 + ROW_NUMBER() OVER (ORDER BY a.LineNum, c.ColumnOrder) AS id_record,
                2 AS group_id,
                'DetallesItem' AS group_name,
                c.ColumnName AS xmlTag,
                CAST(CASE c.ColumnName
                    WHEN 'NumeroLinea' THEN CAST(a.LineNum+1 AS NVARCHAR(MAX))
                    WHEN 'IndicadorFacturacion' THEN CAST( CASE WHEN @eCFType IN ('46') THEN 3 ELSE a.taxecf_id END AS NVARCHAR(MAX))
                    WHEN 'IndicadorAgenteRetencionoPercepcion' THEN '#e' --CAST(CASE WHEN @eCFType   IN ('41','47') THEN '1' ELSE '#e' END AS NVARCHAR(MAX))
                    WHEN 'MontoITBISRetenido' THEN '#e' --CASE WHEN @eCFType   IN ('41') THEN FORMAT(a.retitbis,'0.00') ELSE '#e' END
                    WHEN 'MontoISRRetenido' THEN '#e' --CASE WHEN @eCFType   IN ('41','47') THEN FORMAT(a.retirs,'0.00') ELSE '#e' END
                    WHEN 'NombreItem' THEN CAST(SUBSTRING(a.Dscription,1,80) AS NVARCHAR(MAX))
                    WHEN 'IndicadorBienoServicio' THEN CAST(CASE WHEN @eCFType   IN ('41','47','43') THEN 2 ELSE CASE WHEN a.DocType = 'S' THEN 2 ELSE 1 END END AS NVARCHAR(MAX))
                    WHEN 'CantidadItem' THEN FORMAT(a.Quantity,'0.00')
                    WHEN 'UnidadMedida' THEN CAST(a.ecfunit_id AS NVARCHAR(MAX))
                    WHEN 'PrecioUnitarioItem' THEN FORMAT(a.PriceBefDi,'0.00')
                    WHEN 'DescuentoMonto' THEN CASE WHEN a.DiscPrcnt > 0 THEN FORMAT((a.PriceBefDi*(a.DiscPrcnt/100))*a.Quantity,'0.00') ELSE '#e' END
                    WHEN 'TipoSubDescuento' THEN CASE WHEN a.DiscPrcnt > 0 THEN '%' ELSE '#e' END
                    WHEN 'SubDescuentoPorcentaje' THEN CASE WHEN a.DiscPrcnt > 0 THEN FORMAT(a.DiscPrcnt,'0.00') ELSE '#e' END
                    WHEN 'MontoSubDescuento' THEN CASE WHEN a.DiscPrcnt > 0 THEN FORMAT((a.PriceBefDi*(a.DiscPrcnt/100))*a.Quantity,'0.00') ELSE '#e' END
                    WHEN 'MontoItem' THEN FORMAT(a.LineTotal,'0.00')
                END AS NVARCHAR(MAX)) AS xml_value
           FROM (
                SELECT ROW_NUMBER() OVER(ORDER BY d.Dscription)-1 AS LineNum,
                       t.taxecf_id,
                       d.Dscription,
                       f.DocType,
                       COALESCE(u.ecfunit_id,43) AS ecfunit_id, --PARA FORZAR UNIDAD SI ESTE LLEGA VACIA
                       COALESCE(NULLIF(d.Quantity,0),1) AS Quantity, --PARA USAR 1 EN CASO DE SERVICIO
                       d.PriceBefDi AS PriceBefDi,
                       d.DiscPrcnt AS DiscPrcnt,
                       d.LineTotal AS LineTotal
                  FROM SBO_AGROFEM.dbo.OPCH f 
            INNER JOIN SBO_AGROFEM.dbo.PCH1 d ON (d.DocEntry = f.DocEntry)
            INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
             LEFT JOIN cms.dbo.ecf_units u ON (u.ecfsapunit_namemf = d.unitMsr)
                WHERE f.DocEntry = @InvoiceID

                ) a
    CROSS APPLY (VALUES (1,'NumeroLinea'), (2,'IndicadorFacturacion'), (3,'IndicadorAgenteRetencionoPercepcion'), (4,'MontoITBISRetenido'), (4,'MontoISRRetenido'), (5,'NombreItem'),(6,'IndicadorBienoServicio'), (7,'CantidadItem'),(8,'UnidadMedida'),(9,'PrecioUnitarioItem'),(10,'DescuentoMonto'),(11,'TipoSubDescuento'),(12,'SubDescuentoPorcentaje'),(13,'MontoSubDescuento'),(14,'MontoItem')) c (columnOrder,ColumnName)

UNION ALL
             --PAGINACION
             SELECT 100000+ROW_NUMBER() OVER (ORDER BY a.pagina_numero, c.columnOrder) AS id_record,
                    5 AS group_id,
                    'Paginacion' AS group_name,
                    c.ColumnName AS xmlTag,
                    CAST(CASE c.ColumnName
                        WHEN 'PaginaNo' THEN CAST(pagina_numero AS NVARCHAR(MAX))
                        WHEN 'NoLineaDesde' THEN CAST(linea_desde AS NVARCHAR(MAX))
                        WHEN 'NoLineaHasta' THEN CAST(linea_hasa AS NVARCHAR(MAX))
                        WHEN 'SubtotalMontoGravadoPagina' THEN CASE WHEN a.monto_grabado > 0 THEN FORMAT(a.monto_grabado,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado1Pagina' THEN CASE WHEN a.monto_grabadoI1 > 0 THEN FORMAT(a.monto_grabadoI1,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado2Pagina' THEN CASE WHEN a.monto_grabadoI2 > 0 THEN FORMAT(a.monto_grabadoI2,'0.00') ELSE '#e' END
                        WHEN 'SubtotalMontoGravado3Pagina' THEN CASE WHEN a.monto_grabadoI3 > 0 THEN FORMAT(a.monto_grabadoI3,'0.00') ELSE '#e' END
                        WHEN 'SubtotalExentoPagina' THEN CASE WHEN a.monto_exento > 0 THEN FORMAT(a.monto_exento,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbisPagina' THEN CASE WHEN a.total_itbis > 0 THEN FORMAT(a.total_itbis,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis1Pagina' THEN CASE WHEN a.total_itbis1 > 0 THEN FORMAT(a.total_itbis1,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis2Pagina' THEN CASE WHEN a.total_itbis2 > 0 THEN FORMAT(a.total_itbis2,'0.00') ELSE '#e' END
                        WHEN 'SubtotalItbis3Pagina' THEN CASE WHEN a.total_itbis3 > 0 THEN FORMAT(a.total_itbis3,'0.00') ELSE '#e' END
                        WHEN 'MontoSubtotalPagina' THEN CASE WHEN a.monto_total > 0 THEN FORMAT(a.monto_total,'0.00') ELSE '#e' END
                    END AS NVARCHAR(MAX)) AS xml_value
               FROM (SELECT group_id AS pagina_numero,
                            MIN(w.numero_linea) AS linea_desde,
                            MAX(w.numero_linea) AS linea_hasa,
                            CAST(SUM(monto_grabado) AS NUMERIC(12,2)) AS monto_grabado,
                            CAST(SUM(monto_grabadoI1) AS NUMERIC(12,2)) AS monto_grabadoI1,
                            CAST(SUM(monto_grabadoI2) AS NUMERIC(12,2)) AS monto_grabadoI2,
                            CAST(SUM(monto_grabadoI3) AS NUMERIC(12,2)) AS monto_grabadoI3,
                            CAST(SUM(monto_exento) AS NUMERIC(12,2)) AS monto_exento,
                            CAST(SUM(total_itbis) AS NUMERIC(12,2)) AS total_itbis,
                            CAST(SUM(total_itbis1) AS NUMERIC(12,2)) AS total_itbis1,
                            CAST(SUM(total_itbis2) AS NUMERIC(12,2)) AS total_itbis2,
                            CAST(SUM(total_itbis3) AS NUMERIC(12,2)) AS total_itbis3,
                            CAST(SUM(monto_total) AS NUMERIC(12,2)) AS monto_total
                       FROM (SELECT (d.linenum+1) AS numero_linea,
                                    CEILING(ROW_NUMBER() OVER(ORDER BY d.linenum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS group_id,
                                    SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.LineTotal ELSE 0 END) AS monto_grabado,
                                    SUM(CASE WHEN t.taxecf_id IN (1) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI1,
                                    SUM(CASE WHEN t.taxecf_id IN (2) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI2,
                                    SUM(CASE WHEN t.taxecf_id IN (3) THEN d.LineTotal ELSE 0 END) AS monto_grabadoI3,
                                    SUM(CASE WHEN t.taxecf_id IN (4) THEN d.LineTotal ELSE 0 END) AS monto_exento,
                                    MAX(CASE WHEN t.taxecf_id IN (1) THEN d.VatPrcnt ELSE 0 END) AS itbis1,
                                    MAX(CASE WHEN t.taxecf_id IN (2) THEN d.VatPrcnt ELSE 0 END) AS itbis2,
                                    MAX(CASE WHEN t.taxecf_id IN (3) THEN d.VatPrcnt ELSE 0 END) AS itbis3,
                                    SUM(CASE WHEN t.taxecf_id IN (1,2,3) THEN d.VatSum ELSE 0 END) AS total_itbis,
                                    SUM(CASE WHEN t.taxecf_id IN (1) THEN d.VatSum ELSE 0 END) AS total_itbis1,
                                    SUM(CASE WHEN t.taxecf_id IN (2) THEN d.VatSum ELSE 0 END) AS total_itbis2,
                                    SUM(CASE WHEN t.taxecf_id IN (3) THEN d.VatSum ELSE 0 END) AS total_itbis3,
                                    SUM(d.LineTotal+d.VatSum) AS monto_total
                               FROM SBO_AGROFEM.dbo.OPCH f
                         INNER JOIN SBO_AGROFEM.dbo.PCH1 d ON (d.DocEntry = f.DocEntry)
                         INNER JOIN cms.dbo.ecf_tax_config t ON (t.taxsap_name = d.TaxCode)
                              WHERE f.DocEntry = @InvoiceID
                              GROUP BY d.linenum
                            ) w
                      GROUP BY w.group_id
                    ) a
        CROSS APPLY (VALUES (1,'PaginaNo'), (2,'NoLineaDesde'), (3,'NoLineaHasta'),(4,'SubtotalMontoGravadoPagina'), (5,'SubtotalMontoGravado1Pagina'),(6,'SubtotalMontoGravado2Pagina'),(7,'SubtotalMontoGravado3Pagina'),(8,'SubtotalExentoPagina'),(9,'SubtotalItbisPagina'),(10,'SubtotalItbis1Pagina'),(11,'SubtotalItbis2Pagina'),(12,'SubtotalItbis3Pagina'),(13,'MontoSubtotalPagina')) c (columnOrder,ColumnName)
              WHERE (SELECT CEILING(COUNT(d.LineNum) / (SELECT CAST(config_value AS NUMERIC(5,1)) FROM cms.dbo.ecf_global_config WHERE config_name = 'ITEMSPERPAGE')) AS pages FROM SBO_AGROFEM.dbo.PCH1 d WHERE d.DocEntry = @InvoiceID) > 1
                AND @pPrintPages = 'Y'
            ) ecf 
        WHERE @Resumen = 0 AND @eCFType   IN ('43')
--------------------
*/
);
