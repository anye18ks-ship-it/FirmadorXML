/*
 * Decompiled with CFR 0.152.
 */
package xmlsentry;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import org.w3c.dom.Document;

class DatabaseHandler {
    DatabaseHandler() {
    }

    public static void storeData(Document xmlDocument) throws Exception {
        String value = xmlDocument.getElementsByTagName("yourElement").item(0).getTextContent();
        String url = "jdbc:mysql://localhost:3306/yourDatabase";
        String user = "yourUsername";
        String password = "yourPassword";
        Connection conn = DriverManager.getConnection(url, user, password);
        String query = "INSERT INTO yourTable (columnName) VALUES (?)";
        PreparedStatement pstmt = conn.prepareStatement(query);
        pstmt.setString(1, value);
        pstmt.executeUpdate();
        pstmt.close();
        conn.close();
    }
}

