/*
 * Decompiled with CFR 0.152.
 */
package xmlsentry;

import java.io.StringReader;
import java.io.StringWriter;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import javax.xml.validation.Schema;
import javax.xml.validation.SchemaFactory;
import javax.xml.validation.Validator;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.xml.sax.ErrorHandler;
import org.xml.sax.SAXException;
import org.xml.sax.SAXParseException;
import xmlsentry.DBConnection;

public class xmlCreator {
    public static String getXMLFromDB(String pDocID, String pTypeECF, String pTypeXML, String pIsCompactXML, String pSecurityCode, String pPrintPages) {
        Object sqlXML = "";
        String vCatalogType = "";
        String vCatalogTable = "";
        HashMap<String, Object> elementMap = new HashMap<String, Object>();
        String vGrandParent = "";
        String vParent = "";
        String vParentElementName = "";
        String vElementName = "";
        String vElementValue = "";
        String vTagToRemove = "";
        String vCurrentSample = "";
        Element vElementToRemove = null;
        Element vGrandElement = null;
        Object newGrandParent = null;
        Element vParentElement = null;
        Object newParentElement = null;
        Element vTagParentElement = null;
        Object newTagParentElement = null;
        StringWriter writer = null;
        DBConnection dbConn = null;
        Connection connection = null;
        try {
            dbConn = DBConnection.getInstance();
            connection = dbConn.getConnection();
        }
        catch (SQLException sQLException) {
            // empty catch block
        }
        elementMap.clear();
        sqlXML = "     SELECT x.id_record,\n            (SELECT TOP 1 tag_parent_name FROM " + DBConnection.getDBName() + ".dbo.ecf_xml_catalog WHERE tag_name = y.tag_parent_name AND catalog_type = y.catalog_type) AS grand_parent,\n            y.tag_parent_name AS parent,\n            x.tag_parent_id,\n            x.tag_parent_name,\n            x.tag_type_id,\n            x.tag_type_name,\n            x.tag_number,\n            x.tag_name,\n            x.tag_to_remove,\n            m.xmlTag,\n            m.id_record,\n            CASE WHEN m.xmlTag = 'eCF' THEN NULL ELSE m.xml_value END AS xml_value\n       FROM " + DBConnection.getDBName() + ".dbo.ecf_xml_catalog x\n  LEFT JOIN " + DBConnection.getDBName() + ".dbo.ecf_xml_catalog y ON (y.tag_name = x.tag_parent_name AND y.tag_group_id = x.tag_group_id AND y.catalog_type = x.catalog_type)\n  LEFT JOIN " + DBConnection.getDBName() + ".dbo.GetInvoiceDataForXML(" + pDocID + ",'" + pTypeECF + "'," + pIsCompactXML + ",'" + pSecurityCode + "','" + pPrintPages + "') m ON (m.xmlTag = x.tag_name AND m.group_id = x.tag_group_id)\n      WHERE x.active = 'Y'\n        AND COALESCE(m.id_record,0) > 0\n        AND COALESCE(NULLIF(m.xml_value,'#e'),'') != ''\n        AND x.catalog_type = '" + pTypeXML + "'\n      ORDER BY m.id_record";
        Map<String, List<Object>> vResultXML = dbConn.getSelectAssoc((String)sqlXML);
        if (!vResultXML.isEmpty() && !vResultXML.values().stream().allMatch(List::isEmpty)) {
            try {
                DocumentBuilderFactory docFactory = DocumentBuilderFactory.newInstance();
                DocumentBuilder docBuilder = docFactory.newDocumentBuilder();
                Document doc = docBuilder.newDocument();
                for (int j = 0; j < vResultXML.get("tag_name").size(); ++j) {
                    String[] vTagToRemoveArray;
                    vGrandParent = vResultXML.get("grand_parent").get(j).toString();
                    vParent = vResultXML.get("parent").get(j).toString();
                    vParentElementName = vResultXML.get("tag_parent_name").get(j).toString();
                    vElementName = vResultXML.get("tag_name").get(j).toString();
                    vElementValue = vResultXML.get("xml_value").get(j).toString();
                    vTagToRemove = vResultXML.get("tag_to_remove").get(j).toString();
                    Element vSuperParent = null;
                    Element element = vGrandElement = vGrandParent.isEmpty() ? null : (Element)elementMap.get(vGrandParent);
                    if (!vGrandParent.isEmpty() && vGrandElement == null) {
                        vSuperParent = xmlCreator.CreateOrGetNodes(doc, null, vGrandParent, "");
                        elementMap.put(vGrandParent, vSuperParent);
                    } else {
                        vSuperParent = vGrandElement;
                    }
                    Element element2 = vParentElement = vParent.isEmpty() ? null : (Element)elementMap.get(vParent);
                    if (!vParent.isEmpty() && vParentElement == null) {
                        vSuperParent = xmlCreator.CreateOrGetNodes(doc, vSuperParent, vParent, "");
                        elementMap.put(vParent, vSuperParent);
                    } else {
                        vSuperParent = vParentElement;
                    }
                    Element element3 = vTagParentElement = vParentElementName.isEmpty() ? null : (Element)elementMap.get(vParentElementName);
                    if (!vParentElementName.isEmpty() && vTagParentElement == null) {
                        vSuperParent = xmlCreator.CreateOrGetNodes(doc, vSuperParent, vParentElementName, "");
                        elementMap.put(vParentElementName, vSuperParent);
                    } else {
                        vSuperParent = vTagParentElement;
                    }
                    if (!vElementName.isEmpty()) {
                        String[] newElement = xmlCreator.CreateOrGetNodes(doc, vSuperParent, vElementName, vElementValue);
                        elementMap.put(vElementName, newElement);
                    }
                    if (vTagToRemove.isEmpty()) continue;
                    for (String vRemoveTag : vTagToRemoveArray = vTagToRemove.split(":")) {
                        vElementToRemove = (Element)elementMap.get(vRemoveTag);
                        if (vElementToRemove == null) continue;
                        elementMap.remove(vRemoveTag, vElementToRemove);
                    }
                }
                TransformerFactory transformerFactory = TransformerFactory.newInstance();
                Transformer transformer = transformerFactory.newTransformer();
                DOMSource source = new DOMSource(doc);
                writer = new StringWriter();
                StreamResult result = new StreamResult(writer);
                transformer.transform(source, result);
                return writer.toString();
            }
            catch (Exception e) {
                return "";
            }
        }
        return "";
    }

    public static Element CreateOrGetNodes(Document doc, Element parent, String tagName, String value) {
        Element element = doc.createElement(tagName);
        if (!value.isEmpty()) {
            element.appendChild(doc.createTextNode(value));
        }
        if (parent == null) {
            doc.appendChild(element);
        } else {
            parent.appendChild(element);
        }
        return element;
    }

    public static String validateXmlAgainstXsd(String xsdString, String xmlString) {
        final StringBuilder result = new StringBuilder();
        try {
            SchemaFactory factory = SchemaFactory.newInstance("http://www.w3.org/2001/XMLSchema");
            StreamSource xsdSource = new StreamSource(new StringReader(xsdString));
            Schema schema = factory.newSchema(xsdSource);
            Validator validator = schema.newValidator();
            validator.setErrorHandler(new ErrorHandler(){

                @Override
                public void warning(SAXParseException exception) {
                    result.append(String.format("Warning at Line %d, Column %d: %s%n", exception.getLineNumber(), exception.getColumnNumber(), exception.getMessage()));
                }

                @Override
                public void error(SAXParseException exception) {
                    result.append(String.format("Error at Line %d, Column %d: %s%n", exception.getLineNumber(), exception.getColumnNumber(), exception.getMessage()));
                }

                @Override
                public void fatalError(SAXParseException exception) {
                    result.append(String.format("Fatal Error at Line %d, Column %d: %s%n", exception.getLineNumber(), exception.getColumnNumber(), exception.getMessage()));
                }
            });
            StreamSource xmlSource = new StreamSource(new StringReader(xmlString));
            validator.validate(xmlSource);
            if (result.length() == 0) {
                return "XML is valid according to the provided XSD.";
            }
            return "XML validation failed:\n" + result.toString();
        }
        catch (SAXParseException e) {
            return "Validation error: " + e.getMessage() + " (Line: " + e.getLineNumber() + ", Column: " + e.getColumnNumber() + ")";
        }
        catch (SAXException e) {
            return "Schema error: " + e.getMessage();
        }
        catch (Exception e) {
            return "Unexpected error: " + e.getMessage();
        }
    }

    public static String xmlIntegrityCheck(String pXML, String pXSD) {
        try {
            SchemaFactory factory = SchemaFactory.newInstance("http://www.w3.org/2001/XMLSchema");
            Schema schema = factory.newSchema(new StreamSource(new StringReader(pXSD)));
            Validator validator = schema.newValidator();
            validator.validate(new StreamSource(new StringReader(pXML)));
            return "Pass";
        }
        catch (SAXException e) {
            return "Validation error: " + e.getMessage();
        }
        catch (Exception e) {
            return "Unexpected error during validation: " + e.getMessage();
        }
    }
}

