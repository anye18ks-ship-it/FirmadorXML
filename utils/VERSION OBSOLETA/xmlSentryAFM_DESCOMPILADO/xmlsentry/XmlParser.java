/*
 * Decompiled with CFR 0.152.
 */
package xmlsentry;

import java.io.ByteArrayInputStream;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import org.w3c.dom.Document;

class XmlParser {
    XmlParser() {
    }

    public static Document parseXml(String xmlContent) throws Exception {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        DocumentBuilder builder = factory.newDocumentBuilder();
        ByteArrayInputStream input = new ByteArrayInputStream(xmlContent.getBytes("UTF-8"));
        return builder.parse(input);
    }
}

