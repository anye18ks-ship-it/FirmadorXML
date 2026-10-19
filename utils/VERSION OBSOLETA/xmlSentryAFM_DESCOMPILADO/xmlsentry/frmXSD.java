/*
 * Decompiled with CFR 0.152.
 */
package xmlsentry;

import Controls.SbDataGridView;
import java.awt.Color;
import java.awt.Dimension;
import java.awt.Font;
import java.awt.Frame;
import java.awt.Insets;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.StringReader;
import java.io.StringWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import javax.swing.JButton;
import javax.swing.JDialog;
import javax.swing.JFileChooser;
import javax.swing.JLabel;
import javax.swing.JScrollPane;
import javax.swing.JTextField;
import javax.swing.filechooser.FileNameExtensionFilter;
import javax.swing.table.DefaultTableModel;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import org.w3c.dom.Document;
import org.xml.sax.InputSource;
import xmlsentry.DBConnection;

public class frmXSD
extends JDialog {
    DBConnection dbConn = null;
    Connection connection = null;
    String vEcfType = "";
    String vDocType = "";
    String vTagType = "";
    String vXsdPath = "";
    String vXsdName = "";
    String sqlXSD = "";
    String content = null;
    private JTextField edDocType;
    private JTextField edEcfType;
    private JTextField edFileLocation;
    private JTextField edTagType;
    private SbDataGridView gridXSD;
    private JButton jButton1;
    private JButton jButton2;
    private JLabel jLabel1;
    private JLabel jLabel2;
    private JLabel jLabel3;
    private JLabel jLabel4;
    private JLabel jLabel5;
    private JScrollPane jScrollPane2;

    public frmXSD(Frame parent, boolean modal) {
        super(parent, modal);
        this.initComponents();
        try {
            this.dbConn = DBConnection.getInstance();
            this.connection = this.dbConn.getConnection();
        }
        catch (SQLException e) {
            e.printStackTrace();
        }
        this.getXSDFromDB();
    }

    private void initComponents() {
        this.jLabel1 = new JLabel();
        this.edFileLocation = new JTextField();
        this.jLabel2 = new JLabel();
        this.jLabel3 = new JLabel();
        this.jButton1 = new JButton();
        this.jLabel4 = new JLabel();
        this.jScrollPane2 = new JScrollPane();
        this.gridXSD = new SbDataGridView();
        this.jLabel5 = new JLabel();
        this.edEcfType = new JTextField();
        this.jButton2 = new JButton();
        this.edDocType = new JTextField();
        this.edTagType = new JTextField();
        this.setDefaultCloseOperation(2);
        this.setPreferredSize(new Dimension(700, 550));
        this.getContentPane().setLayout(null);
        this.jLabel1.setFont(new Font("Segoe UI", 0, 13));
        this.jLabel1.setHorizontalAlignment(4);
        this.jLabel1.setText("Tag Type: ");
        this.getContentPane().add(this.jLabel1);
        this.jLabel1.setBounds(5, 102, 84, 22);
        this.edFileLocation.setEditable(false);
        this.getContentPane().add(this.edFileLocation);
        this.edFileLocation.setBounds(88, 30, 530, 22);
        this.jLabel2.setFont(new Font("Segoe UI", 0, 13));
        this.jLabel2.setHorizontalAlignment(4);
        this.jLabel2.setText("Ruta XSD: ");
        this.getContentPane().add(this.jLabel2);
        this.jLabel2.setBounds(5, 30, 84, 22);
        this.jLabel3.setFont(new Font("Segoe UI", 0, 13));
        this.jLabel3.setHorizontalAlignment(4);
        this.jLabel3.setText("Doc Type: ");
        this.jLabel3.setToolTipText("");
        this.getContentPane().add(this.jLabel3);
        this.jLabel3.setBounds(5, 78, 84, 22);
        this.jButton1.setText("Abrir");
        this.jButton1.setMargin(new Insets(2, 2, 2, 2));
        this.jButton1.addActionListener(new ActionListener(){

            @Override
            public void actionPerformed(ActionEvent evt) {
                frmXSD.this.jButton1ActionPerformed(evt);
            }
        });
        this.getContentPane().add(this.jButton1);
        this.jButton1.setBounds(620, 30, 60, 20);
        this.jLabel4.setFont(new Font("Segoe UI", 1, 13));
        this.jLabel4.setForeground(new Color(19, 109, 172));
        this.jLabel4.setHorizontalAlignment(0);
        this.jLabel4.setText("AGREGAR XSDs");
        this.getContentPane().add(this.jLabel4);
        this.jLabel4.setBounds(5, 5, 674, 18);
        this.gridXSD.setBackground(new Color(255, 255, 255));
        this.gridXSD.setForeground(new Color(60, 63, 65));
        this.gridXSD.setModel(new DefaultTableModel(new Object[0][], new String[]{"", "", "", "", ""}){
            Class[] types;
            {
                this.types = new Class[]{Integer.class, String.class, String.class, String.class, String.class};
            }

            public Class getColumnClass(int columnIndex) {
                return this.types[columnIndex];
            }
        });
        this.gridXSD.setFont(new Font("Segoe UI", 0, 12));
        this.gridXSD.setGridColor(new Color(242, 242, 242));
        this.gridXSD.setSbHeaderBackground(new Color(255, 255, 255));
        this.gridXSD.setSbHeaderForeground(new Color(19, 109, 172));
        this.gridXSD.setSelectionBackground(new Color(80, 83, 85));
        this.gridXSD.setShowHorizontalLines(true);
        this.gridXSD.setShowVerticalLines(true);
        this.jScrollPane2.setViewportView(this.gridXSD);
        if (this.gridXSD.getColumnModel().getColumnCount() > 0) {
            this.gridXSD.getColumnModel().getColumn(0).setMinWidth(30);
            this.gridXSD.getColumnModel().getColumn(0).setPreferredWidth(30);
            this.gridXSD.getColumnModel().getColumn(0).setMaxWidth(30);
        }
        this.getContentPane().add(this.jScrollPane2);
        this.jScrollPane2.setBounds(5, 134, 674, 360);
        this.jLabel5.setFont(new Font("Segoe UI", 0, 13));
        this.jLabel5.setHorizontalAlignment(4);
        this.jLabel5.setText("ECF Type: ");
        this.getContentPane().add(this.jLabel5);
        this.jLabel5.setBounds(5, 54, 84, 22);
        this.getContentPane().add(this.edEcfType);
        this.edEcfType.setBounds(88, 54, 280, 22);
        this.jButton2.setText("Guardar");
        this.jButton2.setMargin(new Insets(2, 2, 2, 2));
        this.jButton2.addActionListener(new ActionListener(){

            @Override
            public void actionPerformed(ActionEvent evt) {
                frmXSD.this.jButton2ActionPerformed(evt);
            }
        });
        this.getContentPane().add(this.jButton2);
        this.jButton2.setBounds(620, 54, 60, 20);
        this.getContentPane().add(this.edDocType);
        this.edDocType.setBounds(88, 78, 280, 22);
        this.getContentPane().add(this.edTagType);
        this.edTagType.setBounds(88, 102, 280, 22);
        this.pack();
    }

    private void jButton1ActionPerformed(ActionEvent evt) {
        JFileChooser fileChooser = new JFileChooser();
        FileNameExtensionFilter filter = new FileNameExtensionFilter("XSD files", "xsd");
        fileChooser.setFileFilter(filter);
        int returnValue = fileChooser.showOpenDialog(null);
        if (returnValue == 0) {
            File file = fileChooser.getSelectedFile();
            System.out.println(file.length());
            try {
                String rawContent;
                byte[] bytes = Files.readAllBytes(file.toPath());
                this.content = rawContent = new String(bytes, StandardCharsets.UTF_8);
                this.vXsdName = file.getName();
                this.vXsdPath = file.getAbsolutePath();
                this.edFileLocation.setText(this.vXsdPath);
            }
            catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    private String readFileContentWithUTF8(File file) throws IOException {
        StringBuilder content = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader((InputStream)new FileInputStream(file), StandardCharsets.UTF_8));){
            String line;
            while ((line = reader.readLine()) != null) {
                content.append(line).append("\n");
            }
        }
        return content.toString();
    }

    private void jButton2ActionPerformed(ActionEvent evt) {
        if (!(this.content.toString().isEmpty() || this.edFileLocation.getText().isEmpty() || this.edEcfType.getText().isEmpty())) {
            this.vEcfType = this.edEcfType.getText();
            if (!this.edDocType.getText().isEmpty()) {
                this.vDocType = this.edDocType.getText();
                if (!this.edTagType.getText().isEmpty()) {
                    this.vTagType = this.edTagType.getText();
                    try {
                        this.storeXSDFileInDatabase(this.content, this.vXsdName, this.vEcfType, this.vDocType, this.vTagType);
                        this.getXSDFromDB();
                    }
                    catch (Exception e) {
                        e.printStackTrace();
                    }
                }
            }
        }
    }

    public static byte[] readFileContent(File file) throws IOException {
        try (FileInputStream fis = new FileInputStream(file);){
            byte[] fileContent = new byte[(int)file.length()];
            fis.read(fileContent);
            byte[] byArray = fileContent;
            return byArray;
        }
    }

    public void getXSDFromDB() {
        this.sqlXSD = "SELECT id_record, ecf_type, doc_type, xsd_tag_type, xsd_filename FROM " + DBConnection.getDBName() + ".dbo.ecf_xsd_template WHERE active = 'Y'";
        this.gridXSD._setSQLModel(this.dbConn.getConnection(), this.sqlXSD, false);
    }

    public void storeXSDFileInDatabase(String fileContent, String fileName, String pEcfType, String pDocType, String pTagType) throws SQLException {
        Connection connection = this.dbConn.getConnection();
        String query = "INSERT INTO " + DBConnection.getDBName() + ".dbo.ecf_xsd_template(xsd_template, xsd_filename, ecf_type, doc_type, xsd_tag_type) VALUES (?, ?, ?, ?, ?)";
        try (PreparedStatement pstmt = connection.prepareStatement(query);){
            pstmt.setString(1, fileContent);
            pstmt.setString(2, fileName);
            pstmt.setString(3, pEcfType);
            pstmt.setString(4, pDocType);
            pstmt.setString(5, pTagType);
            pstmt.executeUpdate();
        }
    }

    public String formatXML(String xml) throws Exception {
        DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
        DocumentBuilder db = dbf.newDocumentBuilder();
        Document doc = db.parse(new InputSource(new StringReader(xml)));
        TransformerFactory tf = TransformerFactory.newInstance();
        Transformer transformer = tf.newTransformer();
        transformer.setOutputProperty("indent", "yes");
        transformer.setOutputProperty("{http://xml.apache.org/xslt}indent-amount", "4");
        StringWriter writer = new StringWriter();
        transformer.transform(new DOMSource(doc), new StreamResult(writer));
        return writer.toString();
    }

    public String formatXSD(String xsd) throws Exception {
        DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
        dbf.setNamespaceAware(true);
        dbf.setIgnoringComments(true);
        DocumentBuilder db = dbf.newDocumentBuilder();
        Document doc = db.parse(new InputSource(new StringReader(xsd)));
        TransformerFactory tf = TransformerFactory.newInstance();
        Transformer transformer = tf.newTransformer();
        transformer.setOutputProperty("indent", "yes");
        transformer.setOutputProperty("{http://xml.apache.org/xslt}indent-amount", "4");
        StringWriter writer = new StringWriter();
        transformer.transform(new DOMSource(doc), new StreamResult(writer));
        return writer.toString();
    }
}

