/*
 * Decompiled with CFR 0.152.
 */
package xmlsentry;

import java.io.File;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import org.w3c.dom.Document;

public class DBConnection {
    private static String dbServer;
    private static String dbPort;
    private static String dbName;
    private static String dbUserName;
    private static String dbUserPass;
    private static String URL;
    private static String USER;
    private static String PASSWORD;
    private static DBConnection instance;
    private Connection connection;

    private DBConnection() throws SQLException {
        try {
            this.readConfigFromXML();
            URL = "jdbc:sqlserver://" + dbServer + ":" + dbPort + ";databaseName=" + dbName + ";trustServerCertificate=true;";
            USER = dbUserName;
            PASSWORD = dbUserPass;
            Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
            this.connection = DriverManager.getConnection(URL, USER, PASSWORD);
        }
        catch (ClassNotFoundException | SQLException e) {
            e.printStackTrace();
            throw new SQLException(e);
        }
    }

    public Connection getConnection() {
        return this.connection;
    }

    private void readConfigFromXML() {
        try {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            DocumentBuilder builder = factory.newDocumentBuilder();
            File xmlFile = new File("conf.xml");
            Document doc = builder.parse(xmlFile);
            doc.getDocumentElement().normalize();
            dbServer = doc.getElementsByTagName("server").item(0).getTextContent();
            dbPort = doc.getElementsByTagName("port").item(0).getTextContent();
            dbName = doc.getElementsByTagName("bdscia").item(0).getTextContent();
            dbUserName = doc.getElementsByTagName("usersvr").item(0).getTextContent();
            dbUserPass = doc.getElementsByTagName("passsvr").item(0).getTextContent();
        }
        catch (Exception e) {
            e.printStackTrace();
            throw new RuntimeException("No se pudo leer el archivo de configuraci\u00f3n.", e);
        }
    }

    public static String getDBName() {
        return dbName;
    }

    public static DBConnection getInstance() throws SQLException {
        if (instance == null) {
            instance = new DBConnection();
        } else if (instance.getConnection().isClosed()) {
            instance = new DBConnection();
        }
        return instance;
    }

    public void closeConnection() {
        if (this.connection != null) {
            try {
                this.connection.close();
            }
            catch (SQLException e) {
                e.printStackTrace();
            }
        }
    }

    public void executeInsert(String query, Object ... parameters) throws SQLException {
        try (PreparedStatement pstmt = this.connection.prepareStatement(query);){
            for (int i = 0; i < parameters.length; ++i) {
                pstmt.setObject(i + 1, parameters[i]);
            }
            pstmt.executeUpdate();
        }
    }

    public Map<String, List<Object>> getSelectAssoc(String query) {
        HashMap<String, List<Object>> results = new HashMap<String, List<Object>>();
        try (Statement stmt = this.connection.createStatement();
             ResultSet rs = stmt.executeQuery(query);){
            int i;
            ResultSetMetaData metaData = rs.getMetaData();
            int columnCount = metaData.getColumnCount();
            for (i = 1; i <= columnCount; ++i) {
                results.put(metaData.getColumnName(i), new ArrayList());
            }
            while (rs.next()) {
                for (i = 1; i <= columnCount; ++i) {
                    String columnName = metaData.getColumnName(i);
                    Object value = rs.getObject(i);
                    ((List)results.get(columnName)).add(value == null ? "" : value);
                }
            }
        }
        catch (SQLException e) {
            System.err.println("Error executing query.");
            e.printStackTrace();
        }
        return results;
    }

    public Map<String, Object> getSelectAssocFirstRow(String query) {
        HashMap<String, Object> row = new HashMap<String, Object>();
        try (Statement stmt = this.connection.createStatement();
             ResultSet rs = stmt.executeQuery(query);){
            int columnCount = rs.getMetaData().getColumnCount();
            if (rs.next()) {
                for (int i = 1; i <= columnCount; ++i) {
                    row.put(rs.getMetaData().getColumnName(i), rs.getObject(i));
                }
            }
        }
        catch (SQLException e) {
            System.err.println("Error executing query.");
            e.printStackTrace();
        }
        return row;
    }

    static {
        URL = "";
        USER = "";
        PASSWORD = "";
    }
}

