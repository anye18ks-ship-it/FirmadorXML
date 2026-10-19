/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  oracle.xml.parser.v2.DOMParser
 *  oracle.xml.parser.v2.XMLDocument
 */
package xmlsentry;

import java.io.InputStream;
import java.io.StringWriter;
import java.security.KeyStore;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Collections;
import javax.xml.crypto.dsig.Reference;
import javax.xml.crypto.dsig.SignedInfo;
import javax.xml.crypto.dsig.XMLSignature;
import javax.xml.crypto.dsig.XMLSignatureFactory;
import javax.xml.crypto.dsig.dom.DOMSignContext;
import javax.xml.crypto.dsig.keyinfo.KeyInfo;
import javax.xml.crypto.dsig.keyinfo.KeyInfoFactory;
import javax.xml.crypto.dsig.keyinfo.X509Data;
import javax.xml.crypto.dsig.spec.C14NMethodParameterSpec;
import javax.xml.crypto.dsig.spec.TransformParameterSpec;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import oracle.xml.parser.v2.DOMParser;
import oracle.xml.parser.v2.XMLDocument;
import org.w3c.dom.Element;
import org.w3c.dom.Node;

public class SignXML {
    private static final String algoritmoSignatureMethod = "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256";

    public static String xmlToken(InputStream streamXML, InputStream streamCerticate, String passwordCertificate) throws Exception {
        XMLSignatureFactory fac = XMLSignatureFactory.getInstance("DOM");
        Reference ref = fac.newReference("", fac.newDigestMethod("http://www.w3.org/2001/04/xmlenc#sha256", null), Collections.singletonList(fac.newTransform("http://www.w3.org/2000/09/xmldsig#enveloped-signature", (TransformParameterSpec)null)), null, null);
        SignedInfo si = fac.newSignedInfo(fac.newCanonicalizationMethod("http://www.w3.org/TR/2001/REC-xml-c14n-20010315", (C14NMethodParameterSpec)null), fac.newSignatureMethod(algoritmoSignatureMethod, null), Collections.singletonList(ref));
        KeyStore ks = KeyStore.getInstance("PKCS12");
        ks.load(streamCerticate, passwordCertificate.toCharArray());
        String param = ks.aliases().nextElement();
        KeyStore.PrivateKeyEntry keyEntry = (KeyStore.PrivateKeyEntry)ks.getEntry(param, new KeyStore.PasswordProtection(passwordCertificate.toCharArray()));
        X509Certificate cert = (X509Certificate)keyEntry.getCertificate();
        KeyInfoFactory kinfoFactory = fac.getKeyInfoFactory();
        ArrayList<X509Certificate> x509Content = new ArrayList<X509Certificate>();
        x509Content.add(cert);
        X509Data x509d = kinfoFactory.newX509Data(x509Content);
        KeyInfo kinfo = kinfoFactory.newKeyInfo(Collections.singletonList(x509d));
        DOMParser parser = new DOMParser();
        parser.setPreserveWhitespace(false);
        parser.parse(streamXML);
        XMLDocument xml = parser.getDocument();
        Element xmlRoot = xml.getDocumentElement();
        DOMSignContext dsc = new DOMSignContext(keyEntry.getPrivateKey(), (Node)xmlRoot);
        XMLSignature signature = fac.newXMLSignature(si, kinfo);
        signature.sign(dsc);
        TransformerFactory tf = TransformerFactory.newInstance();
        Transformer trans = tf.newTransformer();
        StringWriter writer = new StringWriter();
        trans.transform(new DOMSource((Node)xml), new StreamResult(writer));
        return writer.toString();
    }

    public static String xmlECF(InputStream streamXML, InputStream streamCerticate, String passwordCertificate, String pCatalogType, String pFechaHoraFirma) throws Exception {
        XMLSignatureFactory fac = XMLSignatureFactory.getInstance("DOM");
        Reference ref = fac.newReference("", fac.newDigestMethod("http://www.w3.org/2001/04/xmlenc#sha256", null), Collections.singletonList(fac.newTransform("http://www.w3.org/2000/09/xmldsig#enveloped-signature", (TransformParameterSpec)null)), null, null);
        SignedInfo si = fac.newSignedInfo(fac.newCanonicalizationMethod("http://www.w3.org/TR/2001/REC-xml-c14n-20010315", (C14NMethodParameterSpec)null), fac.newSignatureMethod(algoritmoSignatureMethod, null), Collections.singletonList(ref));
        KeyStore ks = KeyStore.getInstance("PKCS12");
        ks.load(streamCerticate, passwordCertificate.toCharArray());
        String param = ks.aliases().nextElement();
        KeyStore.PrivateKeyEntry keyEntry = (KeyStore.PrivateKeyEntry)ks.getEntry(param, new KeyStore.PasswordProtection(passwordCertificate.toCharArray()));
        X509Certificate cert = (X509Certificate)keyEntry.getCertificate();
        KeyInfoFactory kinfoFactory = fac.getKeyInfoFactory();
        ArrayList<X509Certificate> x509Content = new ArrayList<X509Certificate>();
        x509Content.add(cert);
        X509Data x509d = kinfoFactory.newX509Data(x509Content);
        KeyInfo kinfo = kinfoFactory.newKeyInfo(Collections.singletonList(x509d));
        DOMParser parser = new DOMParser();
        parser.setPreserveWhitespace(false);
        parser.parse(streamXML);
        XMLDocument xml = parser.getDocument();
        Element xmlRoot = xml.getDocumentElement();
        if (pCatalogType.equals("ECF")) {
            Element fechaHoraFirma = xml.createElement("FechaHoraFirma");
            fechaHoraFirma.setTextContent(pFechaHoraFirma);
            xmlRoot.appendChild(fechaHoraFirma);
        }
        DOMSignContext dsc = new DOMSignContext(keyEntry.getPrivateKey(), (Node)xmlRoot);
        XMLSignature signature = fac.newXMLSignature(si, kinfo);
        signature.sign(dsc);
        TransformerFactory tf = TransformerFactory.newInstance();
        Transformer trans = tf.newTransformer();
        StringWriter writer = new StringWriter();
        trans.transform(new DOMSource((Node)xml), new StreamResult(writer));
        return writer.toString();
    }
}

