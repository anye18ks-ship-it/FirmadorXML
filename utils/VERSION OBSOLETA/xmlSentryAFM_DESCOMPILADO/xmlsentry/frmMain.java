/*
 * Decompiled with CFR 0.152.
 */
package xmlsentry;

import Controls.SbDataGridView;
import java.awt.Color;
import java.awt.Dimension;
import java.awt.EventQueue;
import java.awt.Font;
import java.awt.Frame;
import java.awt.Insets;
import java.awt.Point;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.MouseAdapter;
import java.awt.event.MouseEvent;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.io.StringReader;
import java.io.StringWriter;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.swing.BorderFactory;
import javax.swing.JButton;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JMenuItem;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JPopupMenu;
import javax.swing.JScrollPane;
import javax.swing.JTextPane;
import javax.swing.UIManager;
import javax.swing.UnsupportedLookAndFeelException;
import javax.swing.table.DefaultTableModel;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import javax.xml.xpath.XPath;
import javax.xml.xpath.XPathFactory;
import org.w3c.dom.Document;
import org.xml.sax.InputSource;
import xmlsentry.DBConnection;
import xmlsentry.LabelCellRendererCounterECFLights;
import xmlsentry.SignXML;
import xmlsentry.StyleClass;
import xmlsentry.frmChangeCertificate;
import xmlsentry.frmXSD;
import xmlsentry.getXmlRequest;
import xmlsentry.xmlCreator;

public class frmMain
extends JFrame {
    String sqlTest = "";
    String xmlSeed = "";
    byte[] xmlSeedFile = null;
    InputStream xmlSeedData = null;
    String xmlSeedSigned = "";
    String xmlToken = "";
    String vTokenBearer = "";
    String vTokenValidFrom = "";
    String vTokenValidTo = "";
    String vAPI = "";
    String vToken = "";
    String sqlInsertToken = "";
    String sqlDeactivateOldTokens = "";
    String sqlGetToken = "";
    String vUrlStatusECF = "";
    String sqlGetAPI = "";
    String sqlGetUrlAPI = "";
    String vURL = "";
    String vUrlECF = "";
    String sqlGetStatusECF = "";
    String sqlGetDbTime = "";
    Map<String, Object> vResultDbTime = null;
    LocalDateTime vTimeNow = null;
    String sqlGetTokenConfigParams = "";
    int vTokenRefreshBeforeExpire = 0;
    int vTokenRequestMaxAttempts = 0;
    Map<String, Object> vResultTokenConfigParams = null;
    String sqlGetTokenInfo = "";
    Map<String, Object> vResultTokenInfo = null;
    String sqlCheckStatusECF = "";
    String sqlCheckTokenECF = "";
    String sqlGetAPIForStatusECF = "";
    String sqlGetURLForStatusECF = "";
    String vTrackIDCheckStatusECF = "";
    String vRecordIDCheckStatusECF = "";
    String vGetURLForStatusECF = "";
    String vTokenForStatusECF = "";
    String vStatusCodeCheckECF = "";
    String vStatusNameCheckECF = "";
    String xmlCheckStatusECF = "";
    String vStatusUsedSeqCheckECF = "";
    Map<String, List<Object>> vResultCheckStatusECF = null;
    Map<String, Object> vResultCheckTokenECF = null;
    int vRowCount = 0;
    String sqlGetECF = "";
    String vStatusMessage = "";
    String vStEmisorRNC = "";
    String vStENCF = "";
    String vStSecurityCode = "";
    String sqlXDS = "";
    Map<String, Object> vResultXSD = null;
    String vXSD = "";
    String vXMLIntegrity = "";
    DocumentBuilderFactory factory = null;
    DocumentBuilder builder = null;
    Document docStatusECF = null;
    XPath xPathStatusECF = null;
    String vModRecordID = "";
    String vvModECF = "";
    boolean vIsRunning = true;
    private ScheduledExecutorService schEcfGridRefresh;
    DBConnection dbConn = null;
    Connection connection = null;
    private JButton btnChangeCert;
    private JButton btnChangeCert1;
    private JButton btnChangeCert2;
    private JButton btnChangeCert3;
    private JButton btnLoadXSD;
    private JButton btnService;
    private SbDataGridView gridCertificate;
    private SbDataGridView gridCounterECF;
    private SbDataGridView gridECF;
    private SbDataGridView gridToken;
    private JLabel jLabel10;
    private JLabel jLabel11;
    private JLabel jLabel12;
    private JLabel jLabel3;
    private JLabel jLabel4;
    private JLabel jLabel5;
    private JLabel jLabel6;
    private JLabel jLabel7;
    private JLabel jLabel8;
    private JLabel jLabel9;
    private JMenuItem jMenuItem2;
    private JMenuItem jMenuItem3;
    private JMenuItem jMenuItem4;
    private JMenuItem jMenuItem5;
    private JPanel jPanel1;
    private JPanel jPanel2;
    private JPanel jPanel3;
    private JPanel jPanel4;
    private JPanel jPanel5;
    private JPanel jPanel7;
    private JScrollPane jScrollPane1;
    private JScrollPane jScrollPane2;
    private JScrollPane jScrollPane3;
    private JScrollPane jScrollPane4;
    private JScrollPane jScrollPane5;
    private JPopupMenu.Separator jSeparator1;
    private JPopupMenu.Separator jSeparator2;
    private JLabel lblTokenMessage;
    private JPopupMenu ppmOptionPane;
    private JTextPane txtApiMessage;

    public frmMain() {
        this.initComponents();
        this.setTitle("Sentry <AGROFEM SRL> (e-CF) v0.985.990");
        try {
            this.dbConn = DBConnection.getInstance();
            this.connection = this.dbConn.getConnection();
        }
        catch (SQLException e) {
            e.printStackTrace();
        }
        try {
            this.factory = DocumentBuilderFactory.newInstance();
            this.builder = this.factory.newDocumentBuilder();
        }
        catch (ParserConfigurationException ex) {
            Logger.getLogger(frmMain.class.getName()).log(Level.SEVERE, null, ex);
        }
        StyleClass.setGridModelCertificate(this.gridCertificate);
        StyleClass.setGridModelToken(this.gridToken);
        this.getCertificateFromDB();
        this.startTokenRefreshTask();
        this.startTokenGridRefreshTask();
        this.startUpdateStatusECFRefreshTask();
        this.SignECFTask();
        this.UploadECFTask();
        this.startECFRefreshTask();
        this.getCounterECF();
        this.startCounterECFRefreshTask();
    }

    private void initComponents() {
        this.ppmOptionPane = new JPopupMenu();
        this.jMenuItem5 = new JMenuItem();
        this.jSeparator2 = new JPopupMenu.Separator();
        this.jMenuItem2 = new JMenuItem();
        this.jMenuItem3 = new JMenuItem();
        this.jSeparator1 = new JPopupMenu.Separator();
        this.jMenuItem4 = new JMenuItem();
        this.jPanel3 = new JPanel();
        this.jPanel1 = new JPanel();
        this.jLabel3 = new JLabel();
        this.jLabel4 = new JLabel();
        this.jScrollPane2 = new JScrollPane();
        this.gridCertificate = new SbDataGridView();
        this.btnChangeCert = new JButton();
        this.btnChangeCert3 = new JButton();
        this.jPanel2 = new JPanel();
        this.jLabel5 = new JLabel();
        this.jLabel6 = new JLabel();
        this.jScrollPane3 = new JScrollPane();
        this.gridToken = new SbDataGridView();
        this.btnChangeCert1 = new JButton();
        this.lblTokenMessage = new JLabel();
        this.jPanel4 = new JPanel();
        this.jLabel7 = new JLabel();
        this.jLabel8 = new JLabel();
        this.btnChangeCert2 = new JButton();
        this.jScrollPane4 = new JScrollPane();
        this.gridECF = new SbDataGridView();
        this.btnLoadXSD = new JButton();
        this.btnService = new JButton();
        this.jPanel5 = new JPanel();
        this.jLabel9 = new JLabel();
        this.jLabel10 = new JLabel();
        this.jScrollPane1 = new JScrollPane();
        this.txtApiMessage = new JTextPane();
        this.jPanel7 = new JPanel();
        this.jLabel11 = new JLabel();
        this.jLabel12 = new JLabel();
        this.jScrollPane5 = new JScrollPane();
        this.gridCounterECF = new SbDataGridView();
        this.ppmOptionPane.setForeground(new Color(74, 74, 74));
        this.ppmOptionPane.setBorder(BorderFactory.createLineBorder(new Color(132, 132, 132)));
        this.ppmOptionPane.setLabel("Opciones");
        this.jMenuItem5.setBackground(new Color(244, 244, 244));
        this.jMenuItem5.setFont(new Font("Tahoma", 0, 13));
        this.jMenuItem5.setForeground(new Color(74, 74, 74));
        this.jMenuItem5.setText("Copiar C\u00f3digo QR");
        this.jMenuItem5.setName("4");
        this.jMenuItem5.setOpaque(true);
        this.jMenuItem5.addActionListener(new ActionListener(){

            @Override
            public void actionPerformed(ActionEvent evt) {
                frmMain.this.jMenuItem5ActionPerformed(evt);
            }
        });
        this.ppmOptionPane.add(this.jMenuItem5);
        this.jSeparator2.setForeground(new Color(132, 132, 132));
        this.jSeparator2.setOpaque(true);
        this.ppmOptionPane.add(this.jSeparator2);
        this.jMenuItem2.setBackground(new Color(244, 244, 244));
        this.jMenuItem2.setFont(new Font("Tahoma", 0, 13));
        this.jMenuItem2.setForeground(new Color(74, 74, 74));
        this.jMenuItem2.setText("<html>Marcar como&nbsp;<b><font color=\"#4890E6\">(N)</font>&nbsp;No Procesado</b></html>");
        this.jMenuItem2.setName("4");
        this.jMenuItem2.setOpaque(true);
        this.jMenuItem2.addActionListener(new ActionListener(){

            @Override
            public void actionPerformed(ActionEvent evt) {
                frmMain.this.jMenuItem2ActionPerformed(evt);
            }
        });
        this.ppmOptionPane.add(this.jMenuItem2);
        this.jMenuItem3.setBackground(new Color(244, 244, 244));
        this.jMenuItem3.setFont(new Font("Tahoma", 0, 13));
        this.jMenuItem3.setForeground(new Color(74, 74, 74));
        this.jMenuItem3.setText("<html>Marcar como&nbsp;<b><font color=\"#5DAB19\">(F)</font>&nbsp;Firmado</b></html>");
        this.jMenuItem3.setName("4");
        this.jMenuItem3.setOpaque(true);
        this.jMenuItem3.addActionListener(new ActionListener(){

            @Override
            public void actionPerformed(ActionEvent evt) {
                frmMain.this.jMenuItem3ActionPerformed(evt);
            }
        });
        this.ppmOptionPane.add(this.jMenuItem3);
        this.jSeparator1.setForeground(new Color(132, 132, 132));
        this.jSeparator1.setOpaque(true);
        this.ppmOptionPane.add(this.jSeparator1);
        this.jMenuItem4.setBackground(new Color(244, 244, 244));
        this.jMenuItem4.setFont(new Font("Tahoma", 0, 13));
        this.jMenuItem4.setForeground(new Color(74, 74, 74));
        this.jMenuItem4.setText("<html>Marcar como&nbsp;<b><font color=\"#E64F48\">(N)</font>&nbsp;No Procesado y Generar Secuencia</b></html>");
        this.jMenuItem4.setName("4");
        this.jMenuItem4.setOpaque(true);
        this.jMenuItem4.addActionListener(new ActionListener(){

            @Override
            public void actionPerformed(ActionEvent evt) {
                frmMain.this.jMenuItem4ActionPerformed(evt);
            }
        });
        this.ppmOptionPane.add(this.jMenuItem4);
        this.setDefaultCloseOperation(3);
        this.setPreferredSize(new Dimension(993, 812));
        this.getContentPane().setLayout(null);
        this.jPanel3.setMinimumSize(new Dimension(1043, 812));
        this.jPanel3.setPreferredSize(new Dimension(1043, 812));
        this.jPanel3.setLayout(null);
        this.jPanel1.setLayout(null);
        this.jLabel3.setBackground(new Color(19, 109, 172));
        this.jLabel3.setFont(new Font("Segoe UI", 1, 13));
        this.jLabel3.setForeground(new Color(255, 255, 255));
        this.jLabel3.setHorizontalAlignment(0);
        this.jLabel3.setText("Informaci\u00f3n Certificado");
        this.jLabel3.setOpaque(true);
        this.jPanel1.add(this.jLabel3);
        this.jLabel3.setBounds(0, 0, 294, 20);
        this.jLabel4.setBackground(new Color(202, 202, 202));
        this.jLabel4.setOpaque(true);
        this.jPanel1.add(this.jLabel4);
        this.jLabel4.setBounds(0, 20, 294, 5);
        this.jScrollPane2.setHorizontalScrollBarPolicy(31);
        this.jScrollPane2.setVerticalScrollBarPolicy(21);
        this.gridCertificate.setBackground(new Color(255, 255, 255));
        this.gridCertificate.setForeground(new Color(60, 63, 65));
        this.gridCertificate.setModel(new DefaultTableModel(new Object[0][], new String[]{"", "", "", ""}){
            Class[] types;
            {
                this.types = new Class[]{Integer.class, String.class, String.class, Integer.class};
            }

            public Class getColumnClass(int columnIndex) {
                return this.types[columnIndex];
            }
        });
        this.gridCertificate.setFocusable(false);
        this.gridCertificate.setFont(new Font("Segoe UI", 0, 12));
        this.gridCertificate.setGridColor(new Color(242, 242, 242));
        this.gridCertificate.setRequestFocusEnabled(false);
        this.gridCertificate.setRowHeight(20);
        this.gridCertificate.setRowSelectionAllowed(false);
        this.gridCertificate.setSbBackground(new Color(255, 255, 255));
        this.gridCertificate.setSbHeaderBackground(new Color(255, 255, 255));
        this.gridCertificate.setSbHeaderFont(new Font("Segoe UI", 1, 13));
        this.gridCertificate.setSbHeaderForeground(new Color(19, 109, 172));
        this.gridCertificate.setShowHorizontalLines(true);
        this.gridCertificate.setShowVerticalLines(true);
        this.jScrollPane2.setViewportView(this.gridCertificate);
        if (this.gridCertificate.getColumnModel().getColumnCount() > 0) {
            this.gridCertificate.getColumnModel().getColumn(0).setMinWidth(35);
            this.gridCertificate.getColumnModel().getColumn(0).setPreferredWidth(35);
            this.gridCertificate.getColumnModel().getColumn(0).setMaxWidth(35);
            this.gridCertificate.getColumnModel().getColumn(1).setMinWidth(85);
            this.gridCertificate.getColumnModel().getColumn(1).setPreferredWidth(85);
            this.gridCertificate.getColumnModel().getColumn(1).setMaxWidth(85);
            this.gridCertificate.getColumnModel().getColumn(2).setMinWidth(85);
            this.gridCertificate.getColumnModel().getColumn(2).setPreferredWidth(85);
            this.gridCertificate.getColumnModel().getColumn(2).setMaxWidth(85);
            this.gridCertificate.getColumnModel().getColumn(3).setMinWidth(70);
            this.gridCertificate.getColumnModel().getColumn(3).setPreferredWidth(70);
            this.gridCertificate.getColumnModel().getColumn(3).setMaxWidth(70);
        }
        this.jPanel1.add(this.jScrollPane2);
        this.jScrollPane2.setBounds(0, 25, 294, 48);
        this.btnChangeCert.setText("Cambiar");
        this.btnChangeCert.addActionListener(new ActionListener(){

            @Override
            public void actionPerformed(ActionEvent evt) {
                frmMain.this.btnChangeCertActionPerformed(evt);
            }
        });
        this.jPanel1.add(this.btnChangeCert);
        this.btnChangeCert.setBounds(48, 76, 75, 22);
        this.btnChangeCert3.setText("Actualizar");
        this.btnChangeCert3.setMargin(new Insets(2, 5, 2, 5));
        this.btnChangeCert3.addActionListener(new ActionListener(){

            @Override
            public void actionPerformed(ActionEvent evt) {
                frmMain.this.btnChangeCert3ActionPerformed(evt);
            }
        });
        this.jPanel1.add(this.btnChangeCert3);
        this.btnChangeCert3.setBounds(171, 76, 75, 22);
        this.jPanel3.add(this.jPanel1);
        this.jPanel1.setBounds(3, 3, 294, 100);
        this.jPanel2.setLayout(null);
        this.jLabel5.setBackground(new Color(64, 64, 64));
        this.jLabel5.setFont(new Font("Segoe UI", 1, 13));
        this.jLabel5.setForeground(new Color(255, 255, 255));
        this.jLabel5.setHorizontalAlignment(0);
        this.jLabel5.setText("Informaci\u00f3n del Token");
        this.jLabel5.setOpaque(true);
        this.jPanel2.add(this.jLabel5);
        this.jLabel5.setBounds(0, 0, 674, 20);
        this.jLabel6.setBackground(new Color(202, 202, 202));
        this.jLabel6.setOpaque(true);
        this.jPanel2.add(this.jLabel6);
        this.jLabel6.setBounds(0, 20, 674, 5);
        this.jScrollPane3.setHorizontalScrollBarPolicy(31);
        this.jScrollPane3.setVerticalScrollBarPolicy(21);
        this.gridToken.setBackground(new Color(255, 255, 255));
        this.gridToken.setForeground(new Color(60, 63, 65));
        this.gridToken.setModel(new DefaultTableModel(new Object[0][], new String[]{"", "", "", "", ""}){
            Class[] types;
            {
                this.types = new Class[]{Integer.class, String.class, String.class, String.class, Integer.class};
            }

            public Class getColumnClass(int columnIndex) {
                return this.types[columnIndex];
            }
        });
        this.gridToken.setFocusable(false);
        this.gridToken.setFont(new Font("Segoe UI", 0, 12));
        this.gridToken.setGridColor(new Color(242, 242, 242));
        this.gridToken.setRequestFocusEnabled(false);
        this.gridToken.setRowHeight(20);
        this.gridToken.setRowSelectionAllowed(false);
        this.gridToken.setSbBackground(new Color(255, 255, 255));
        this.gridToken.setSbHeaderBackground(new Color(255, 255, 255));
        this.gridToken.setSbHeaderFont(new Font("Segoe UI", 1, 13));
        this.gridToken.setSbHeaderForeground(new Color(19, 109, 172));
        this.gridToken.setShowHorizontalLines(true);
        this.gridToken.setShowVerticalLines(true);
        this.jScrollPane3.setViewportView(this.gridToken);
        if (this.gridToken.getColumnModel().getColumnCount() > 0) {
            this.gridToken.getColumnModel().getColumn(0).setMinWidth(35);
            this.gridToken.getColumnModel().getColumn(0).setPreferredWidth(35);
            this.gridToken.getColumnModel().getColumn(0).setMaxWidth(35);
            this.gridToken.getColumnModel().getColumn(1).setMinWidth(380);
            this.gridToken.getColumnModel().getColumn(1).setPreferredWidth(380);
            this.gridToken.getColumnModel().getColumn(1).setMaxWidth(380);
            this.gridToken.getColumnModel().getColumn(2).setMinWidth(85);
            this.gridToken.getColumnModel().getColumn(2).setPreferredWidth(85);
            this.gridToken.getColumnModel().getColumn(2).setMaxWidth(85);
            this.gridToken.getColumnModel().getColumn(3).setMinWidth(85);
            this.gridToken.getColumnModel().getColumn(3).setPreferredWidth(85);
            this.gridToken.getColumnModel().getColumn(3).setMaxWidth(85);
            this.gridToken.getColumnModel().getColumn(4).setMinWidth(70);
            this.gridToken.getColumnModel().getColumn(4).setPreferredWidth(70);
            this.gridToken.getColumnModel().getColumn(4).setMaxWidth(70);
        }
        this.jPanel2.add(this.jScrollPane3);
        this.jScrollPane3.setBounds(0, 25, 674, 48);
        this.btnChangeCert1.setText("Cambiar");
        this.btnChangeCert1.addActionListener(new ActionListener(){

            @Override
            public void actionPerformed(ActionEvent evt) {
                frmMain.this.btnChangeCert1ActionPerformed(evt);
            }
        });
        this.jPanel2.add(this.btnChangeCert1);
        this.btnChangeCert1.setBounds(599, 76, 75, 22);
        this.lblTokenMessage.setFont(new Font("Segoe UI", 1, 13));
        this.jPanel2.add(this.lblTokenMessage);
        this.lblTokenMessage.setBounds(0, 76, 594, 20);
        this.jPanel3.add(this.jPanel2);
        this.jPanel2.setBounds(300, 3, 674, 100);
        this.jPanel4.setLayout(null);
        this.jLabel7.setBackground(new Color(255, 87, 51));
        this.jLabel7.setFont(new Font("Segoe UI", 1, 13));
        this.jLabel7.setForeground(new Color(255, 255, 255));
        this.jLabel7.setHorizontalAlignment(0);
        this.jLabel7.setText("e-CF Pendientes");
        this.jLabel7.setOpaque(true);
        this.jPanel4.add(this.jLabel7);
        this.jLabel7.setBounds(0, 0, 971, 20);
        this.jLabel8.setBackground(new Color(202, 202, 202));
        this.jLabel8.setOpaque(true);
        this.jPanel4.add(this.jLabel8);
        this.jLabel8.setBounds(0, 20, 971, 5);
        this.btnChangeCert2.setText("Procesar");
        this.btnChangeCert2.addActionListener(new ActionListener(){

            @Override
            public void actionPerformed(ActionEvent evt) {
                frmMain.this.btnChangeCert2ActionPerformed(evt);
            }
        });
        this.jPanel4.add(this.btnChangeCert2);
        this.btnChangeCert2.setBounds(896, 328, 75, 22);
        this.jScrollPane4.setHorizontalScrollBarPolicy(31);
        this.gridECF.setBackground(new Color(255, 255, 255));
        this.gridECF.setForeground(new Color(60, 63, 65));
        this.gridECF.setModel(new DefaultTableModel(new Object[0][], new String[]{"", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""}){
            Class[] types;
            boolean[] canEdit;
            {
                this.types = new Class[]{Integer.class, Integer.class, String.class, String.class, String.class, String.class, String.class, String.class, String.class, String.class, String.class, String.class, String.class, String.class, String.class, String.class};
                this.canEdit = new boolean[]{false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false};
            }

            public Class getColumnClass(int columnIndex) {
                return this.types[columnIndex];
            }

            @Override
            public boolean isCellEditable(int rowIndex, int columnIndex) {
                return this.canEdit[columnIndex];
            }
        });
        this.gridECF.setComponentPopupMenu(this.ppmOptionPane);
        this.gridECF.setFont(new Font("Segoe UI", 0, 12));
        this.gridECF.setGridColor(new Color(242, 242, 242));
        this.gridECF.setRequestFocusEnabled(false);
        this.gridECF.setSbBackground(new Color(255, 255, 255));
        this.gridECF.setSbHeaderBackground(new Color(255, 255, 255));
        this.gridECF.setSbHeaderFont(new Font("Segoe UI", 1, 13));
        this.gridECF.setSbHeaderForeground(new Color(19, 109, 172));
        this.gridECF.setShowHorizontalLines(true);
        this.gridECF.setShowVerticalLines(true);
        this.gridECF.getTableHeader().setReorderingAllowed(false);
        this.gridECF.addMouseListener(new MouseAdapter(){

            @Override
            public void mouseClicked(MouseEvent evt) {
                frmMain.this.gridECFMouseClicked(evt);
            }

            @Override
            public void mousePressed(MouseEvent evt) {
                frmMain.this.gridECFMousePressed(evt);
            }
        });
        this.jScrollPane4.setViewportView(this.gridECF);
        if (this.gridECF.getColumnModel().getColumnCount() > 0) {
            this.gridECF.getColumnModel().getColumn(0).setResizable(false);
            this.gridECF.getColumnModel().getColumn(0).setPreferredWidth(65);
            this.gridECF.getColumnModel().getColumn(1).setResizable(false);
            this.gridECF.getColumnModel().getColumn(1).setPreferredWidth(65);
            this.gridECF.getColumnModel().getColumn(2).setResizable(false);
            this.gridECF.getColumnModel().getColumn(2).setPreferredWidth(85);
            this.gridECF.getColumnModel().getColumn(3).setResizable(false);
            this.gridECF.getColumnModel().getColumn(3).setPreferredWidth(85);
            this.gridECF.getColumnModel().getColumn(4).setResizable(false);
            this.gridECF.getColumnModel().getColumn(4).setPreferredWidth(70);
            this.gridECF.getColumnModel().getColumn(5).setResizable(false);
            this.gridECF.getColumnModel().getColumn(6).setResizable(false);
            this.gridECF.getColumnModel().getColumn(7).setResizable(false);
            this.gridECF.getColumnModel().getColumn(8).setResizable(false);
            this.gridECF.getColumnModel().getColumn(9).setResizable(false);
            this.gridECF.getColumnModel().getColumn(10).setResizable(false);
            this.gridECF.getColumnModel().getColumn(11).setResizable(false);
            this.gridECF.getColumnModel().getColumn(12).setResizable(false);
            this.gridECF.getColumnModel().getColumn(13).setResizable(false);
            this.gridECF.getColumnModel().getColumn(14).setResizable(false);
            this.gridECF.getColumnModel().getColumn(15).setResizable(false);
        }
        this.jPanel4.add(this.jScrollPane4);
        this.jScrollPane4.setBounds(0, 25, 971, 300);
        this.btnLoadXSD.setText("Load XSD");
        this.btnLoadXSD.setMargin(new Insets(2, 2, 2, 2));
        this.btnLoadXSD.addActionListener(new ActionListener(){

            @Override
            public void actionPerformed(ActionEvent evt) {
                frmMain.this.btnLoadXSDActionPerformed(evt);
            }
        });
        this.jPanel4.add(this.btnLoadXSD);
        this.btnLoadXSD.setBounds(819, 328, 75, 22);
        this.btnService.setBackground(new Color(51, 153, 0));
        this.btnService.setForeground(new Color(255, 255, 255));
        this.btnService.setText("Running...");
        this.btnService.setActionCommand("");
        this.btnService.setMargin(new Insets(2, 2, 2, 2));
        this.btnService.addActionListener(new ActionListener(){

            @Override
            public void actionPerformed(ActionEvent evt) {
                frmMain.this.btnServiceActionPerformed(evt);
            }
        });
        this.jPanel4.add(this.btnService);
        this.btnService.setBounds(742, 328, 75, 22);
        this.jPanel3.add(this.jPanel4);
        this.jPanel4.setBounds(3, 104, 971, 353);
        this.jPanel5.setLayout(null);
        this.jLabel9.setBackground(new Color(19, 109, 172));
        this.jLabel9.setFont(new Font("Segoe UI", 1, 13));
        this.jLabel9.setForeground(new Color(255, 255, 255));
        this.jLabel9.setHorizontalAlignment(0);
        this.jLabel9.setText("Mensaje WebAPI DGII");
        this.jLabel9.setOpaque(true);
        this.jPanel5.add(this.jLabel9);
        this.jLabel9.setBounds(0, 0, 600, 20);
        this.jLabel10.setBackground(new Color(202, 202, 202));
        this.jLabel10.setOpaque(true);
        this.jPanel5.add(this.jLabel10);
        this.jLabel10.setBounds(0, 20, 600, 5);
        this.txtApiMessage.setFont(new Font("Consolas", 0, 12));
        this.jScrollPane1.setViewportView(this.txtApiMessage);
        this.jPanel5.add(this.jScrollPane1);
        this.jScrollPane1.setBounds(0, 25, 600, 280);
        this.jPanel3.add(this.jPanel5);
        this.jPanel5.setBounds(3, 458, 600, 325);
        this.jPanel7.setLayout(null);
        this.jLabel11.setBackground(new Color(64, 64, 64));
        this.jLabel11.setFont(new Font("Segoe UI", 1, 13));
        this.jLabel11.setForeground(new Color(255, 255, 255));
        this.jLabel11.setHorizontalAlignment(0);
        this.jLabel11.setText("e-CF-Counter");
        this.jLabel11.setOpaque(true);
        this.jPanel7.add(this.jLabel11);
        this.jLabel11.setBounds(0, 0, 372, 20);
        this.jLabel12.setBackground(new Color(202, 202, 202));
        this.jLabel12.setOpaque(true);
        this.jPanel7.add(this.jLabel12);
        this.jLabel12.setBounds(0, 20, 372, 5);
        this.jScrollPane5.setHorizontalScrollBarPolicy(31);
        this.gridCounterECF.setBackground(new Color(255, 255, 255));
        this.gridCounterECF.setForeground(new Color(60, 63, 65));
        this.gridCounterECF.setModel(new DefaultTableModel(new Object[0][], new String[]{"", "", "", "", "", ""}){
            Class[] types;
            boolean[] canEdit;
            {
                this.types = new Class[]{Integer.class, String.class, String.class, Integer.class, Integer.class, Integer.class};
                this.canEdit = new boolean[]{false, false, false, false, false, false};
            }

            public Class getColumnClass(int columnIndex) {
                return this.types[columnIndex];
            }

            @Override
            public boolean isCellEditable(int rowIndex, int columnIndex) {
                return this.canEdit[columnIndex];
            }
        });
        this.gridCounterECF.setFont(new Font("Segoe UI", 0, 13));
        this.gridCounterECF.setGridColor(new Color(242, 242, 242));
        this.gridCounterECF.setRequestFocusEnabled(false);
        this.gridCounterECF.setSbBackground(new Color(255, 255, 255));
        this.gridCounterECF.setSbHeaderBackground(new Color(255, 255, 255));
        this.gridCounterECF.setSbHeaderFont(new Font("Segoe UI", 1, 13));
        this.gridCounterECF.setSbHeaderForeground(new Color(19, 109, 172));
        this.gridCounterECF.setShowHorizontalLines(true);
        this.gridCounterECF.setShowVerticalLines(true);
        this.gridCounterECF.getTableHeader().setReorderingAllowed(false);
        this.gridCounterECF.addMouseListener(new MouseAdapter(){

            @Override
            public void mouseClicked(MouseEvent evt) {
                frmMain.this.gridCounterECFMouseClicked(evt);
            }
        });
        this.jScrollPane5.setViewportView(this.gridCounterECF);
        if (this.gridCounterECF.getColumnModel().getColumnCount() > 0) {
            this.gridCounterECF.getColumnModel().getColumn(0).setResizable(false);
            this.gridCounterECF.getColumnModel().getColumn(0).setPreferredWidth(65);
            this.gridCounterECF.getColumnModel().getColumn(1).setResizable(false);
            this.gridCounterECF.getColumnModel().getColumn(1).setPreferredWidth(85);
            this.gridCounterECF.getColumnModel().getColumn(2).setResizable(false);
            this.gridCounterECF.getColumnModel().getColumn(2).setPreferredWidth(85);
            this.gridCounterECF.getColumnModel().getColumn(3).setResizable(false);
            this.gridCounterECF.getColumnModel().getColumn(3).setPreferredWidth(70);
            this.gridCounterECF.getColumnModel().getColumn(4).setResizable(false);
            this.gridCounterECF.getColumnModel().getColumn(5).setResizable(false);
        }
        this.jPanel7.add(this.jScrollPane5);
        this.jScrollPane5.setBounds(0, 25, 372, 280);
        this.jPanel3.add(this.jPanel7);
        this.jPanel7.setBounds(602, 458, 372, 325);
        this.getContentPane().add(this.jPanel3);
        this.jPanel3.setBounds(0, 0, 990, 790);
        this.pack();
    }

    private void btnChangeCertActionPerformed(ActionEvent evt) {
        frmChangeCertificate changeCert = new frmChangeCertificate((Frame)this, true);
        changeCert.setSize(700, 385);
        changeCert.setLocationRelativeTo(null);
        changeCert.setVisible(true);
    }

    private void btnChangeCert1ActionPerformed(ActionEvent evt) {
        this.insertTestData();
    }

    private void btnChangeCert2ActionPerformed(ActionEvent evt) {
    }

    private void btnChangeCert3ActionPerformed(ActionEvent evt) {
        this.getCertificateFromDB();
    }

    private void gridECFMouseClicked(MouseEvent evt) {
        int vSelRow;
        if (this.gridECF.getRowCount() > 0 && (vSelRow = this.gridECF.getSelectedRow()) >= 0 && !this.gridECF.getValueAt(vSelRow, 14).toString().isEmpty()) {
            this.vStatusMessage = this.gridECF.getValueAt(vSelRow, 10).toString();
            StyleClass.colorXMLInTextPane(this.txtApiMessage, this.vStatusMessage);
        }
    }

    public String getSeq(String pSeqType) {
        String vResult = null;
        String vSql = " MERGE " + DBConnection.getDBName() + ".dbo.secuencia WITH (SERIALIZABLE) AS T  USING (VALUES ('" + pSeqType + "')) AS U (tipo)     ON U.tipo = T.tipo  WHEN MATCHED THEN      UPDATE SET T.secuencia = secuencia + 1  WHEN NOT MATCHED THEN     INSERT (secuencia, tipo)     VALUES (1, U.tipo) \tOUTPUT $action, inserted.*; ";
        Map<String, Object> vResultGetSeq = this.dbConn.getSelectAssocFirstRow(vSql);
        if (!vResultGetSeq.isEmpty()) {
            vResult = vResultGetSeq.get("secuencia").toString();
        }
        return vResult;
    }

    private void btnLoadXSDActionPerformed(ActionEvent evt) {
        frmXSD loadXSD = new frmXSD((Frame)this, true);
        loadXSD.setSize(700, 550);
        loadXSD.setLocationRelativeTo(null);
        loadXSD.setVisible(true);
    }

    private void btnServiceActionPerformed(ActionEvent evt) {
        String vServiceFontColor = "";
        String vServiceBgColor = "";
        String vServiceText = "";
        boolean bl = this.vIsRunning = !this.vIsRunning;
        if (this.vIsRunning) {
            this.startECFRefreshTask();
        }
        vServiceBgColor = this.vIsRunning ? "#339900" : "#bb1824";
        vServiceText = this.vIsRunning ? "Running..." : "Stopped.";
        this.btnService.setText(vServiceText);
        this.btnService.setBackground(Color.decode(vServiceBgColor));
    }

    private void jMenuItem2ActionPerformed(ActionEvent evt) {
        String sqlCheckPreviousStatus;
        Map<String, Object> vResultCheckPreviousStatus;
        if (!(this.vModRecordID.isEmpty() || this.vvModECF.isEmpty() || (vResultCheckPreviousStatus = this.dbConn.getSelectAssocFirstRow(sqlCheckPreviousStatus = "SELECT [id_record], [ecf], [xml_ecf_status_code],UPPER([xml_ecf_status_name]) AS [xml_ecf_status_name], [C_Posted] FROM " + DBConnection.getDBName() + ".[dbo].[ecf_xml_invoice] WHERE id_record = " + this.vModRecordID)).isEmpty())) {
            String[] sBoton = new String[]{"NO", "SI"};
            Object[] oBoton = new Object[]{"NO", "SI"};
            String vMessage = "<html>Est\u00e1 seguro que desea cambiar el estado del<br><b><font size=6>ECF:</font> <font color='#0077be' size=6>" + this.vvModECF + " </font></b><br>Con respuesta de la DGII:<br><b><font color = '#008000' size=4>" + vResultCheckPreviousStatus.get("xml_ecf_status_code").toString() + "&lt;" + vResultCheckPreviousStatus.get("xml_ecf_status_name").toString() + "&gt;</font></b><br>al nuevo estado<br><b><font size=6 color='#d40000'>(N)&nbsp;</font><font size=6>No Enviado?</font></b></html>";
            int vOption = JOptionPane.showOptionDialog(this, vMessage, "Aviso de cambio de estado", 1, 1, null, oBoton, sBoton[0]);
            if (vOption == 1) {
                try {
                    this.setNStateECF(vResultCheckPreviousStatus.get("id_record").toString());
                }
                catch (SQLException ex) {
                    Logger.getLogger(frmMain.class.getName()).log(Level.SEVERE, null, ex);
                }
            }
        }
    }

    private void gridCounterECFMouseClicked(MouseEvent evt) {
    }

    private void jMenuItem3ActionPerformed(ActionEvent evt) {
        String sqlCheckPreviousStatus;
        Map<String, Object> vResultCheckPreviousStatus;
        if (!(this.vModRecordID.isEmpty() || this.vvModECF.isEmpty() || (vResultCheckPreviousStatus = this.dbConn.getSelectAssocFirstRow(sqlCheckPreviousStatus = "SELECT [id_record], [ecf], [xml_ecf_status_code],UPPER([xml_ecf_status_name]) AS [xml_ecf_status_name], [C_Posted] FROM " + DBConnection.getDBName() + ".[dbo].[ecf_xml_invoice] WHERE id_record = " + this.vModRecordID)).isEmpty())) {
            String[] sBoton = new String[]{"NO", "SI"};
            Object[] oBoton = new Object[]{"NO", "SI"};
            String vMessage = "<html>Est\u00e1 seguro que desea cambiar el estado del<br><b><font size=6>ECF:</font> <font color='#0077be' size=6>" + this.vvModECF + " </font></b><br>Con respuesta de la DGII:<br><b><font color = '#008000' size=4>" + vResultCheckPreviousStatus.get("xml_ecf_status_code").toString() + "&lt;" + vResultCheckPreviousStatus.get("xml_ecf_status_name").toString() + "&gt;</font></b><br>al nuevo estado<br><b><font size=6 color='#d40000'>(F)&nbsp;</font><font size=6>Firmado?</font></b></html>";
            int vOption = JOptionPane.showOptionDialog(this, vMessage, "Aviso de cambio de estado", 1, 1, null, oBoton, sBoton[0]);
            if (vOption == 1) {
                try {
                    this.RollBackQuantumStateECF(vResultCheckPreviousStatus.get("id_record").toString());
                }
                catch (SQLException ex) {
                    Logger.getLogger(frmMain.class.getName()).log(Level.SEVERE, null, ex);
                }
            }
        }
    }

    private void jMenuItem4ActionPerformed(ActionEvent evt) {
    }

    private void gridECFMousePressed(MouseEvent evt) {
        Point point = evt.getPoint();
        if (this.gridECF.getRowCount() > 0) {
            int currentRow = this.gridECF.rowAtPoint(point);
            this.gridECF.setRowSelectionInterval(currentRow, currentRow);
            this.vModRecordID = this.gridECF.getValueAt(currentRow, 0).toString();
            this.vvModECF = this.gridECF.getValueAt(currentRow, 3).toString();
        }
    }

    private void jMenuItem5ActionPerformed(ActionEvent evt) {
        String sqlCopyQR;
        Map<String, Object> vResultCheckPreviousStatus;
        if (!(this.vModRecordID.isEmpty() || this.vvModECF.isEmpty() || (vResultCheckPreviousStatus = this.dbConn.getSelectAssocFirstRow(sqlCopyQR = "SELECT [id_record], [ecf], [xml_ecf_status_code],UPPER([xml_ecf_status_name]) AS [xml_ecf_status_name], [C_Posted] FROM " + DBConnection.getDBName() + ".[dbo].[ecf_xml_invoice] WHERE id_record = " + this.vModRecordID)).isEmpty())) {
            String[] sBoton = new String[]{"NO", "SI"};
            Object[] oBoton = new Object[]{"NO", "SI"};
            String vMessage = "<html>Est\u00e1 seguro que desea cambiar el estado del<br><b><font size=6>ECF:</font> <font color='#0077be' size=6>" + this.vvModECF + " </font></b><br>Con respuesta de la DGII:<br><b><font color = '#008000' size=4>" + vResultCheckPreviousStatus.get("xml_ecf_status_code").toString() + "&lt;" + vResultCheckPreviousStatus.get("xml_ecf_status_name").toString() + "&gt;</font></b><br>al nuevo estado<br><b><font size=6 color='#d40000'>(N)&nbsp;</font><font size=6>No Enviado?</font></b></html>";
            int vOption = JOptionPane.showOptionDialog(this, vMessage, "Aviso de cambio de estado", 1, 1, null, oBoton, sBoton[0]);
            if (vOption == 1) {
                try {
                    this.setNStateECF(vResultCheckPreviousStatus.get("id_record").toString());
                }
                catch (SQLException ex) {
                    Logger.getLogger(frmMain.class.getName()).log(Level.SEVERE, null, ex);
                }
            }
        }
    }

    public static void main(String[] args) {
        try {
            for (UIManager.LookAndFeelInfo info : UIManager.getInstalledLookAndFeels()) {
                if (!"Nimbus".equals(info.getName())) continue;
                UIManager.setLookAndFeel(info.getClassName());
                break;
            }
        }
        catch (ClassNotFoundException ex) {
            Logger.getLogger(frmMain.class.getName()).log(Level.SEVERE, null, ex);
        }
        catch (InstantiationException ex) {
            Logger.getLogger(frmMain.class.getName()).log(Level.SEVERE, null, ex);
        }
        catch (IllegalAccessException ex) {
            Logger.getLogger(frmMain.class.getName()).log(Level.SEVERE, null, ex);
        }
        catch (UnsupportedLookAndFeelException ex) {
            Logger.getLogger(frmMain.class.getName()).log(Level.SEVERE, null, ex);
        }
        EventQueue.invokeLater(new Runnable(){

            @Override
            public void run() {
                frmMain mainWindow = new frmMain();
                mainWindow.setVisible(true);
            }
        });
    }

    public void insertTestData() {
        String sqlGetCertificate = "";
        Object sqlGetCertFile = "";
        byte[] certFile = null;
        String certKey = "";
        ByteArrayInputStream certData = null;
        Document doc = null;
        XPath xPath = null;
        try {
            this.sqlGetAPI = "SELECT config_value FROM " + DBConnection.getDBName() + ".dbo.ecf_global_config WHERE config_name = 'API' AND active = 'Y'";
            Map<String, Object> vResultAPI = this.dbConn.getSelectAssocFirstRow(this.sqlGetAPI);
            if (!vResultAPI.isEmpty()) {
                this.vAPI = vResultAPI.get("config_value").toString();
                this.sqlGetUrlAPI = "SELECT url_api FROM " + DBConnection.getDBName() + ".dbo.ecf_url_api WHERE url_order = 1 AND active = 'Y'";
                Map<String, Object> vResultUrl = this.dbConn.getSelectAssocFirstRow(this.sqlGetUrlAPI);
                if (!vResultUrl.isEmpty()) {
                    this.vURL = vResultUrl.get("url_api").toString().replace("???", this.vAPI);
                    this.xmlSeed = this.formatXML(getXmlRequest.getXmlFromApi(this.vURL));
                    this.xmlSeedData = new ByteArrayInputStream(this.xmlSeed.getBytes());
                    sqlGetCertFile = "SELECT id_record AS [#], cert_name AS [path], cert_file, cert_key, cert_valid_from AS desde, cert_valid_to AS hasta, DATEDIFF(DAY, GETDATE(),cert_valid_to) AS faltante FROM " + DBConnection.getDBName() + ".dbo.ecf_certificate WHERE cert_valid_to > GETDATE() AND active = 'Y'";
                    Map<String, Object> vResultGetCertFile = this.dbConn.getSelectAssocFirstRow((String)sqlGetCertFile);
                    if (!vResultGetCertFile.isEmpty()) {
                        certFile = (byte[])vResultGetCertFile.get("cert_file");
                        certData = new ByteArrayInputStream(certFile);
                        certKey = vResultGetCertFile.get("cert_key").toString();
                        this.xmlSeedSigned = this.formatXML(SignXML.xmlToken(this.xmlSeedData, certData, certKey));
                        this.sqlGetUrlAPI = "SELECT url_api FROM " + DBConnection.getDBName() + ".dbo.ecf_url_api WHERE url_order = 2 AND active = 'Y'";
                        Map<String, Object> vResultUrlToken = this.dbConn.getSelectAssocFirstRow(this.sqlGetUrlAPI);
                        if (!vResultUrlToken.isEmpty()) {
                            this.vURL = vResultUrlToken.get("url_api").toString().replace("???", this.vAPI);
                            this.xmlToken = this.formatXML(getXmlRequest.getXmlTokenFromApi(this.vURL, this.xmlSeedSigned));
                            doc = this.builder.parse(new ByteArrayInputStream(this.xmlToken.getBytes()));
                            xPath = XPathFactory.newInstance().newXPath();
                            this.vToken = xPath.evaluate("/RespuestaAutenticacion/token", doc);
                            this.vTokenValidFrom = xPath.evaluate("/RespuestaAutenticacion/expedido", doc);
                            this.vTokenValidTo = xPath.evaluate("/RespuestaAutenticacion/expira", doc);
                            this.SaveTokenToDatabase(this.xmlSeed, this.xmlSeedSigned, this.xmlToken, this.vToken, this.vTokenValidFrom, this.vTokenValidTo);
                            this.getTokenFromDB();
                        }
                    }
                }
            }
        }
        catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void ecfGenerator() {
        Object sqlGetPendingInvoice = "";
        Map<String, List<Object>> vResultGetPendingInvoice = null;
        String vWorkingStatus = "";
        String vRecordID = "";
        String vDocID = "";
        String vEcfType = "";
        String vCatalogType = "";
        String vPrintPages = "";
        String vXMLFileName = "";
        String xmlFullString = "";
        String xmlFullSigned = "";
        String xmlCompactString = "";
        String xmlCompactSigned = "";
        ByteArrayInputStream xmlFull = null;
        ByteArrayInputStream xmlCompact = null;
        String xmlForWebApi = "";
        String vSecurityCode = "";
        String vSecretCode = "";
        Object sqlInvoiceTotal = "";
        String sqlGetCertificate = "";
        Object sqlGetCertFile = "";
        byte[] certFile = null;
        String certKey = "";
        ByteArrayInputStream certData = null;
        Map<String, Object> vResultGetCertFile = null;
        String sqlSignDateTime = "";
        Map<String, Object> vResultSignDateTime = null;
        String vSignDateTime = "";
        String vSignDateTimeXML = "";
        Object sqlGetUrlECF = "";
        Object vRNC_EMISOR = "";
        Object vRNC_COMPRADOR = "";
        Object vENCF = "";
        Object vFECHA_EMISION = "";
        Object vMONTO_TOTAL = "";
        Object vFECHA_FIRMA = "";
        Object vSECURITY_CODE = "";
        Object vSECURITY_CODE_COMPACT = "";
        String vQRCodeLong = "";
        String vQRCodeShort = "";
        String vQRCode = "";
        String sqlQRCode = "";
        Object sqlReplaceSpecialChars = "";
        Map<String, Object> vResultQRCode = null;
        Map<String, Object> vResultSpecialChars = null;
        String vSTATUS_CODE = "";
        String vSTATUS_NAME = "";
        Document doc = null;
        XPath xPath = null;
        try {
            sqlGetPendingInvoice = "  SELECT i.id_record,\n         i.doc_id,\n         i.NumAtCard,\n         i.ecf_type,\n         i.ecf,\n         i.ecf_vence,\n         i.ecf_print_pages,\n         i.xml_file_name,\n         i.xml_file,\n         i.xml_file_signed,\n         i.xml_security_code,\n         i.xml_file_compact,\n         i.xml_file_compact_signed,\n         i.xml_secret_code,\n         i.xml_response,\n         i.xml_track_id,\n         i.xml_track_response,\n         i.C_Posted\n    FROM " + DBConnection.getDBName() + ".dbo.ecf_xml_invoice i\n   WHERE i.C_Posted IN ('N') AND i.ecf_type IN (31,32,33,34,41,43,44,45,46,47) ORDER BY id_record";
            vResultGetPendingInvoice = this.dbConn.getSelectAssoc((String)sqlGetPendingInvoice);
            if (!vResultGetPendingInvoice.isEmpty()) {
                int rowCount = vResultGetPendingInvoice.values().iterator().next().size();
                for (int j = 0; j < rowCount; ++j) {
                    vWorkingStatus = vResultGetPendingInvoice.get("C_Posted").get(j).toString();
                    vRecordID = vResultGetPendingInvoice.get("id_record").get(j).toString();
                    vDocID = vResultGetPendingInvoice.get("doc_id").get(j).toString();
                    vEcfType = vResultGetPendingInvoice.get("ecf_type").get(j).toString();
                    vXMLFileName = vResultGetPendingInvoice.get("xml_file_name").get(j).toString();
                    vPrintPages = vResultGetPendingInvoice.get("ecf_print_pages").get(j).toString();
                    if (vWorkingStatus.equals("N")) {
                        vCatalogType = "ECF";
                        xmlFullString = this.formatXML(xmlCreator.getXMLFromDB(vDocID, vEcfType, vCatalogType, "0", "", vPrintPages));
                        if (!xmlFullString.isEmpty()) {
                            xmlFull = new ByteArrayInputStream(xmlFullString.getBytes());
                            sqlGetCertFile = "SELECT id_record AS [#], cert_name AS [path], cert_file, cert_key, cert_valid_from AS desde, cert_valid_to AS hasta, DATEDIFF(DAY, GETDATE(),cert_valid_to) AS faltante FROM " + DBConnection.getDBName() + ".dbo.ecf_certificate WHERE cert_valid_to > GETDATE() AND active = 'Y'";
                            vResultGetCertFile = this.dbConn.getSelectAssocFirstRow((String)sqlGetCertFile);
                            if (!vResultGetCertFile.isEmpty()) {
                                Map<String, Object> vResultGetTotal;
                                certFile = (byte[])vResultGetCertFile.get("cert_file");
                                certData = new ByteArrayInputStream(certFile);
                                certKey = vResultGetCertFile.get("cert_key").toString();
                                sqlSignDateTime = "DECLARE @pDateNow DATETIME = GETDATE()\nSELECT @pDateNow AS fecha_firma, FORMAT(@pDateNow,'dd-MM-yyyy HH:mm:ss') AS xmlfechafirma";
                                vResultSignDateTime = this.dbConn.getSelectAssocFirstRow(sqlSignDateTime);
                                if (!vResultSignDateTime.isEmpty()) {
                                    vSignDateTime = vResultSignDateTime.get("fecha_firma").toString();
                                    vSignDateTimeXML = vResultSignDateTime.get("xmlfechafirma").toString();
                                }
                                if (!(xmlFullSigned = this.formatXML(SignXML.xmlECF(xmlFull, certData, certKey, vCatalogType, vSignDateTimeXML))).isEmpty()) {
                                    xmlForWebApi = xmlFullSigned;
                                    sqlGetUrlECF = "SELECT url_api FROM " + DBConnection.getDBName() + ".dbo.ecf_url_api WHERE url_order = 3 AND active = 'Y'";
                                }
                                doc = this.builder.parse(new ByteArrayInputStream(xmlFullSigned.getBytes()));
                                xPath = XPathFactory.newInstance().newXPath();
                                vSecurityCode = xPath.evaluate("ECF/*[local-name()='Signature']/*[local-name()='SignatureValue']", doc).substring(0, 6);
                                vRNC_EMISOR = xPath.evaluate("ECF/Encabezado/Emisor/RNCEmisor", doc);
                                vRNC_COMPRADOR = xPath.evaluate("ECF/Encabezado/Comprador/RNCComprador", doc);
                                vENCF = xPath.evaluate("ECF/Encabezado/IdDoc/eNCF", doc);
                                vFECHA_EMISION = xPath.evaluate("ECF/Encabezado/Emisor/FechaEmision", doc);
                                vMONTO_TOTAL = xPath.evaluate("ECF/Encabezado/Totales/MontoTotal", doc);
                                vFECHA_FIRMA = xPath.evaluate("ECF/FechaHoraFirma", doc);
                                sqlReplaceSpecialChars = "SELECT [CMS].[dbo].[ReplaceCharsInURL]('" + vSecurityCode + "') AS security_code";
                                vResultSpecialChars = this.dbConn.getSelectAssocFirstRow((String)sqlReplaceSpecialChars);
                                if (!vResultSpecialChars.isEmpty()) {
                                    vSECURITY_CODE = vResultSpecialChars.get("security_code").toString();
                                    vSECURITY_CODE_COMPACT = vResultSpecialChars.get("security_code").toString();
                                }
                                if (!(vResultQRCode = this.dbConn.getSelectAssocFirstRow(sqlQRCode = "SELECT REPLACE(u.url_api,'???',c.config_value) AS qr \n       FROM cms.dbo.ecf_url_api u\n  LEFT JOIN cms.dbo.ecf_global_config c ON (config_name = 'API' AND c.active = 'Y')\n WHERE u.url_order = 7 AND u.active = 'Y'")).isEmpty()) {
                                    if (!((String)vRNC_EMISOR).isEmpty()) {
                                        vRNC_EMISOR = "RncEmisor=" + (String)vRNC_EMISOR;
                                    }
                                    if (!((String)vRNC_COMPRADOR).isEmpty()) {
                                        vRNC_COMPRADOR = "RncComprador=" + (String)vRNC_COMPRADOR;
                                    }
                                    if (!((String)vENCF).isEmpty()) {
                                        vENCF = "ENCF=" + (String)vENCF;
                                    }
                                    if (!((String)vFECHA_EMISION).isEmpty()) {
                                        vFECHA_EMISION = "FechaEmision=" + (String)vFECHA_EMISION;
                                    }
                                    if (!((String)vMONTO_TOTAL).isEmpty()) {
                                        vMONTO_TOTAL = "MontoTotal=" + (String)vMONTO_TOTAL;
                                    }
                                    if (!((String)vFECHA_FIRMA).isEmpty()) {
                                        vFECHA_FIRMA = "FechaFirma=" + ((String)vFECHA_FIRMA).replace(" ", "%20");
                                    }
                                    if (!((String)vSECURITY_CODE).isEmpty()) {
                                        vSECURITY_CODE = "CodigoSeguridad=" + (String)vSECURITY_CODE;
                                    }
                                    vQRCodeLong = vResultQRCode.get("qr").toString();
                                    vQRCodeLong = vQRCodeLong.replace("$RNC_EMISOR", (CharSequence)vRNC_EMISOR);
                                    vQRCodeLong = vQRCodeLong.replace("$RNC_COMPRADOR", (CharSequence)vRNC_COMPRADOR);
                                    vQRCodeLong = vQRCodeLong.replace("$ENCF", (CharSequence)vENCF);
                                    vQRCodeLong = vQRCodeLong.replace("$FECHA_EMISION", (CharSequence)vFECHA_EMISION);
                                    vQRCodeLong = vQRCodeLong.replace("$MONTO_TOTAL", (CharSequence)vMONTO_TOTAL);
                                    vQRCodeLong = vQRCodeLong.replace("$FECHA_FIRMA", (CharSequence)vFECHA_FIRMA);
                                    vQRCode = vQRCodeLong = vQRCodeLong.replace("$SECURITY_CODE", (CharSequence)vSECURITY_CODE);
                                }
                                if (Integer.parseInt(vEcfType) == 32 && !(vResultGetTotal = this.dbConn.getSelectAssocFirstRow((String)(sqlInvoiceTotal = "SELECT DocTotal FROM " + DBConnection.getDBName() + ".dbo.POSOINV WHERE C_DocEntry = " + vDocID))).isEmpty() && Double.parseDouble(vResultGetTotal.get("DocTotal").toString()) < 250000.0) {
                                    vCatalogType = "RFCE";
                                    xmlCompactString = this.formatXML(xmlCreator.getXMLFromDB(vDocID, vEcfType, vCatalogType, "1", vSecurityCode, vPrintPages));
                                    xmlCompact = new ByteArrayInputStream(xmlCompactString.getBytes());
                                    sqlGetCertFile = "SELECT id_record AS [#], cert_name AS [path], cert_file, cert_key, cert_valid_from AS desde, cert_valid_to AS hasta, DATEDIFF(DAY, GETDATE(),cert_valid_to) AS faltante FROM " + DBConnection.getDBName() + ".dbo.ecf_certificate WHERE cert_valid_to > GETDATE() AND active = 'Y'";
                                    vResultGetCertFile = this.dbConn.getSelectAssocFirstRow((String)sqlGetCertFile);
                                    if (!vResultGetCertFile.isEmpty()) {
                                        certFile = (byte[])vResultGetCertFile.get("cert_file");
                                        certData = new ByteArrayInputStream(certFile);
                                        xmlCompactSigned = this.formatXML(SignXML.xmlECF(xmlCompact, certData, certKey = vResultGetCertFile.get("cert_key").toString(), vCatalogType, ""));
                                        if (!xmlCompactSigned.isEmpty()) {
                                            xmlForWebApi = xmlCompactSigned;
                                            sqlGetUrlECF = "SELECT url_api FROM " + DBConnection.getDBName() + ".dbo.ecf_url_api WHERE url_order = 5 AND active = 'Y'";
                                        }
                                        doc = this.builder.parse(new ByteArrayInputStream(xmlCompactSigned.getBytes()));
                                        xPath = XPathFactory.newInstance().newXPath();
                                        vSecretCode = xPath.evaluate("RFCE/*[local-name()='Signature']/*[local-name()='SignatureValue']", doc).substring(0, 6);
                                        vRNC_EMISOR = xPath.evaluate("RFCE/Encabezado/Emisor/RNCEmisor", doc);
                                        vENCF = xPath.evaluate("RFCE/Encabezado/IdDoc/eNCF", doc);
                                        vMONTO_TOTAL = xPath.evaluate("RFCE/Encabezado/Totales/MontoTotal", doc);
                                        sqlQRCode = "SELECT REPLACE(u.url_api,'???',c.config_value) AS qr \n       FROM cms.dbo.ecf_url_api u\n  LEFT JOIN cms.dbo.ecf_global_config c ON (config_name = 'API' AND c.active = 'Y')\n WHERE u.url_order = 8 AND u.active = 'Y'";
                                        vResultQRCode = this.dbConn.getSelectAssocFirstRow(sqlQRCode);
                                        if (!vResultQRCode.isEmpty()) {
                                            if (!((String)vRNC_EMISOR).isEmpty()) {
                                                vRNC_EMISOR = "RncEmisor=" + (String)vRNC_EMISOR;
                                            }
                                            if (!((String)vENCF).isEmpty()) {
                                                vENCF = "ENCF=" + (String)vENCF;
                                            }
                                            if (!((String)vMONTO_TOTAL).isEmpty()) {
                                                vMONTO_TOTAL = "MontoTotal=" + (String)vMONTO_TOTAL;
                                            }
                                            if (!((String)vSECURITY_CODE_COMPACT).isEmpty()) {
                                                vSECURITY_CODE_COMPACT = "CodigoSeguridad=" + (String)vSECURITY_CODE_COMPACT;
                                            }
                                            vQRCodeShort = vResultQRCode.get("qr").toString();
                                            vQRCodeShort = vQRCodeShort.replace("$RNC_EMISOR", (CharSequence)vRNC_EMISOR);
                                            vQRCodeShort = vQRCodeShort.replace("$ENCF", (CharSequence)vENCF);
                                            vQRCodeShort = vQRCodeShort.replace("$MONTO_TOTAL", (CharSequence)vMONTO_TOTAL);
                                            vQRCode = vQRCodeShort = vQRCodeShort.replace("$SECURITY_CODE", (CharSequence)vSECURITY_CODE_COMPACT);
                                        }
                                    }
                                }
                                if (this.integrityVerifyXML(vCatalogType, vEcfType, xmlForWebApi)) {
                                    vSTATUS_CODE = "-100";
                                    vSTATUS_NAME = "Firmado";
                                    this.StoreECF(vRecordID, xmlFullString, xmlFullSigned, vSecurityCode, vSignDateTime, vQRCodeLong, xmlCompactString, xmlCompactSigned, vSecretCode, vQRCodeShort, vSTATUS_CODE, vSTATUS_NAME);
                                    xmlCompactString = "";
                                    xmlCompactSigned = "";
                                    vSecretCode = "";
                                    vQRCodeShort = "";
                                } else {
                                    vSTATUS_CODE = "-100";
                                    vSTATUS_NAME = "Firmado";
                                    this.StoreECF(vRecordID, xmlFullString, xmlFullSigned, vSecurityCode, vSignDateTime, vQRCodeLong, xmlCompactString, xmlCompactSigned, vSecretCode, vQRCodeShort, vSTATUS_CODE, vSTATUS_NAME);
                                    xmlCompactString = "";
                                    xmlCompactSigned = "";
                                    vSecretCode = "";
                                    vQRCodeShort = "";
                                }
                            }
                        } else {
                            this.setErrorStateECF(vRecordID);
                        }
                    }
                    try {
                        Thread.sleep(100L);
                        continue;
                    }
                    catch (InterruptedException e) {
                        e.printStackTrace();
                    }
                }
            }
        }
        catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void ecfUploader() {
        Object sqlGetSignedInvoice = "";
        Map<String, List<Object>> vResultGetSignedInvoice = null;
        String vXML_FILE_READY = "";
        String vXML_FILE_NAME = "";
        String vURL_API = "";
        String vURL_ORDER = "3";
        String vID_RECORD = "";
        String vECF_TYPE = "";
        Object sqlUploadAPI = "";
        Map<String, Object> vResultUploadAPI = null;
        Object sqlValidateToken = "";
        Map<String, Object> vResultValidateToken = null;
        String vTokenValidated = "";
        String xmlResponseECF = "";
        Document doc = null;
        XPath xPath = null;
        String vTrackID = "";
        String vXMLEcfStatusCode = "";
        String vXMLEcfStatusName = "";
        String vXMLEcfUsedSeq = "";
        String vXMLEcfStatusMessage = "";
        String vXMLEcfStatusMessageCode = "";
        String xmlStatusECF = "";
        Object sqlCatchError = "";
        Map<String, Object> vResultCatchError = null;
        try {
            sqlGetSignedInvoice = "  SELECT i.id_record,\n         i.doc_id,\n         i.NumAtCard,\n         i.ecf_type,\n         i.ecf,\n         i.ecf_vence,\n         i.ecf_print_pages,\n         i.xml_file_name,\n         i.xml_file,\n         i.xml_file_signed,\n         i.xml_security_code,\n         i.xml_file_compact,\n         i.xml_file_compact_signed,\n         i.xml_secret_code,\n         i.xml_response,\n         i.xml_track_id,\n         i.xml_track_response,\n         i.C_Posted\n    FROM " + DBConnection.getDBName() + ".dbo.ecf_xml_invoice i\n   WHERE i.C_Posted IN ('F') AND i.ecf_type IN (31,32,33,34,41,43,44,45,46,47) \n     AND COALESCE(i.ecf_invoice_date,CONVERT(DATE,GETDATE())) <= CONVERT(DATE,DATEADD(MINUTE,-10,GETDATE())) \n     AND CONVERT(DATE, GETDATE()) NOT IN ('2025-09-13','2025-09-14')ORDER BY id_record \nOFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY";
            vResultGetSignedInvoice = this.dbConn.getSelectAssoc((String)sqlGetSignedInvoice);
            if (!vResultGetSignedInvoice.isEmpty()) {
                int rowCount = vResultGetSignedInvoice.values().iterator().next().size();
                for (int i = 0; i < rowCount; ++i) {
                    vID_RECORD = vResultGetSignedInvoice.get("id_record").get(i).toString();
                    vXML_FILE_READY = vResultGetSignedInvoice.get("xml_file_signed").get(i).toString();
                    vXML_FILE_NAME = vResultGetSignedInvoice.get("xml_file_name").get(i).toString();
                    if (!vResultGetSignedInvoice.get("xml_file_compact").get(i).toString().isEmpty()) {
                        vURL_ORDER = "5";
                        vXML_FILE_READY = vResultGetSignedInvoice.get("xml_file_compact_signed").get(i).toString();
                    }
                    if (!((vResultUploadAPI = this.dbConn.getSelectAssocFirstRow((String)(sqlUploadAPI = "SELECT REPLACE(u.url_api,'???',c.config_value) AS url_api \n          FROM cms.dbo.ecf_url_api u\n     LEFT JOIN cms.dbo.ecf_global_config c ON (config_name = 'API' AND c.active = 'Y')\n         WHERE u.url_order = " + vURL_ORDER + " AND u.active = 'Y'"))).isEmpty() || (vURL_API = vResultUploadAPI.get("url_api").toString()).isEmpty() || (vResultValidateToken = this.dbConn.getSelectAssocFirstRow((String)(sqlValidateToken = "SELECT COALESCE(t.id_record,a.id_record) AS id_record, COALESCE(t.token_bearer,a.[token]) AS [token] FROM (SELECT 0 AS id_record, '' AS [token]) a LEFT JOIN " + DBConnection.getDBName() + ".dbo.ecf_xml_token t ON (1=1 AND t.token_valid_to > GETDATE() AND t.active = 'Y')"))).get("token").toString().isEmpty())) {
                        vTokenValidated = vResultValidateToken.get("token").toString();
                        this.setQuantumStateECF(vID_RECORD);
                        xmlResponseECF = this.formatXML(getXmlRequest.sendXmlECF(vURL_API, vXML_FILE_READY, vTokenValidated, vXML_FILE_NAME));
                        if (!xmlResponseECF.isEmpty()) {
                            doc = this.builder.parse(new ByteArrayInputStream(xmlResponseECF.getBytes()));
                            xPath = XPathFactory.newInstance().newXPath();
                            vTrackID = xPath.evaluate("/RespuestaRecepcion/TrackId", doc);
                            if (!vTrackID.isEmpty()) {
                                if (!vTrackID.isEmpty() && vTrackID.equals("00000000-0000-0000-0000-000000000000")) {
                                    vXMLEcfStatusCode = "-99";
                                    vXMLEcfStatusName = "Quantum";
                                    vXMLEcfUsedSeq = "false";
                                } else {
                                    vXMLEcfStatusCode = "-101";
                                    vXMLEcfStatusName = "Firmado y Enviado";
                                    vXMLEcfUsedSeq = "true";
                                }
                            } else {
                                vXMLEcfStatusName = xPath.evaluate("/Respuesta/Estado", doc);
                                vXMLEcfStatusMessageCode = xPath.evaluate("/Respuesta/Mensajes/MensajeRespuesta/Codigo", doc);
                                vXMLEcfStatusMessage = xPath.evaluate("/Respuesta/Mensajes/MensajeRespuesta/Valor", doc);
                                if (vXMLEcfStatusName.equalsIgnoreCase("No encontrado")) {
                                    vXMLEcfStatusCode = "0";
                                }
                                if (vXMLEcfStatusName.equalsIgnoreCase("Aceptado")) {
                                    vXMLEcfStatusCode = "1";
                                }
                                if (vXMLEcfStatusName.equalsIgnoreCase("Rechazado")) {
                                    vXMLEcfStatusCode = "2";
                                }
                                if (vXMLEcfStatusName.equalsIgnoreCase("En Proceso")) {
                                    vXMLEcfStatusCode = "3";
                                }
                                if (vXMLEcfStatusName.isEmpty()) {
                                    vXMLEcfStatusCode = "-99";
                                }
                                vXMLEcfUsedSeq = xPath.evaluate("/Respuesta/SecuenciaUtilizada", doc);
                                if (vXMLEcfStatusName.equalsIgnoreCase("Rechazado") && vXMLEcfStatusMessageCode.equalsIgnoreCase("004") && vXMLEcfStatusMessage.equalsIgnoreCase("Ha ocurrido un error validando en eCF, favor intentar nueva vez.") && vXMLEcfUsedSeq.equalsIgnoreCase("false")) {
                                    vXMLEcfStatusName = "Quantum";
                                    vXMLEcfStatusCode = "-99";
                                }
                                if (vXMLEcfStatusName.equalsIgnoreCase("Rechazado") && vXMLEcfStatusMessageCode.equalsIgnoreCase("75") && vXMLEcfStatusMessage.equalsIgnoreCase("El e-NCF de este Resumen de Factura de Consumo ya ha sido utilizado previamente.") && vXMLEcfUsedSeq.equalsIgnoreCase("false")) {
                                    vXMLEcfStatusName = "Aceptado";
                                    vXMLEcfStatusCode = "1";
                                }
                                if (vXMLEcfStatusName.equalsIgnoreCase("Rechazado") && vXMLEcfStatusMessageCode.equalsIgnoreCase("1209") && vXMLEcfStatusMessage.equalsIgnoreCase("Este n\u00famero de secuencia ya ha sido utilizado.") && vXMLEcfUsedSeq.equalsIgnoreCase("false")) {
                                    vXMLEcfStatusName = "Aceptado";
                                    vXMLEcfStatusCode = "1";
                                }
                            }
                            if (vXMLEcfStatusName.equalsIgnoreCase("Rechazado") && vXMLEcfStatusMessageCode.equalsIgnoreCase("1209") && vXMLEcfStatusMessage.equalsIgnoreCase("Este n\u00famero de secuencia ya ha sido utilizado.") && vXMLEcfUsedSeq.equalsIgnoreCase("false")) {
                                vXMLEcfStatusName = "Aceptado";
                                vXMLEcfStatusCode = "1";
                            }
                            this.StoreAPIResponse(vID_RECORD, xmlResponseECF, vTrackID, xmlStatusECF, vXMLEcfStatusCode, vXMLEcfStatusName, vXMLEcfUsedSeq);
                            vTrackID = "";
                            vXMLEcfStatusCode = "";
                            vXMLEcfStatusName = "";
                            vXMLEcfUsedSeq = "";
                            vXMLEcfStatusMessageCode = "";
                            vXMLEcfStatusMessage = "";
                        }
                    }
                    try {
                        Thread.sleep(100L);
                        continue;
                    }
                    catch (InterruptedException e) {
                        e.printStackTrace();
                    }
                }
            }
        }
        catch (Exception e) {
            try {
                if (!vID_RECORD.isEmpty() && !(vResultCatchError = this.dbConn.getSelectAssocFirstRow((String)(sqlCatchError = "SELECT [C_Posted] FROM " + DBConnection.getDBName() + ".[dbo].[ecf_xml_invoice] WHERE [id_record] = " + vID_RECORD))).isEmpty() && vResultCatchError.get("C_Posted").toString().equalsIgnoreCase("Q")) {
                    this.RollBackQuantumStateECF(vID_RECORD);
                }
            }
            catch (SQLException sQLException) {
                // empty catch block
            }
        }
    }

    public boolean integrityVerifyXML(String pCatalogType, String pEcfType, String pXML) {
        this.sqlXDS = "SELECT [id_record],\n       [ecf_type],\n       [doc_type],\n       [xsd_tag_type],\n       [xsd_filename],\n       [xsd_template],\n       [xsd_status],\n       [active]\n  FROM [" + DBConnection.getDBName() + "].[dbo].[ecf_xsd_template] \n WHERE [xsd_tag_type] = '" + pCatalogType + "' \n   AND [ecf_type] = '" + pEcfType + "' \n   AND [active] = 'Y' ";
        this.vResultXSD = this.dbConn.getSelectAssocFirstRow(this.sqlXDS);
        if (!this.vResultXSD.isEmpty()) {
            this.vXSD = this.vResultXSD.get("xsd_template").toString();
            this.vXMLIntegrity = xmlCreator.xmlIntegrityCheck(pXML.trim(), this.vXSD.trim());
            return this.vXMLIntegrity.equalsIgnoreCase("Pass");
        }
        return false;
    }

    public void StoreECF(String pIdRecord, String pXMLFile, String pXMLFileSigned, String pXMLSecuriyCode, String pSignDateTime, String pXMLFileQRCode, String pXMLFileCompact, String pXMLFileCompactSigned, String pXMLSecretCode, String pXMLFileCompactQRCode, String pXMLEcfStatusCode, String pXMLEcfStatusName) throws SQLException {
        Object sqlUPDATE_XML_SIGNED = "";
        String vUpdatePosted = "";
        if (Integer.parseInt(pXMLEcfStatusCode) == -100) {
            vUpdatePosted = ", C_Posted = 'F'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == -96) {
            vUpdatePosted = ", C_Posted = 'E'\n";
        }
        sqlUPDATE_XML_SIGNED = "UPDATE [" + DBConnection.getDBName() + "].[dbo].[ecf_xml_invoice]\n   SET [xml_file] = ?,\n       [xml_file_signed] = ?,\n       [xml_security_code] = ?,\n       [xml_file_sign_date] = ?,\n       [xml_file_qrcode] = ?,\n       [xml_file_compact] = ?,\n       [xml_file_compact_signed] = ?,\n       [xml_secret_code] = ?,\n       [xml_file_compact_qrcode] = ?,\n       [xml_ecf_status_code] = ?,\n       [xml_ecf_status_name] = ?\n" + vUpdatePosted + " WHERE id_record = " + pIdRecord;
        try (PreparedStatement pstmt = this.connection.prepareStatement((String)sqlUPDATE_XML_SIGNED);){
            pstmt.setString(1, pXMLFile);
            pstmt.setString(2, pXMLFileSigned);
            pstmt.setString(3, pXMLSecuriyCode);
            pstmt.setString(4, pSignDateTime);
            pstmt.setString(5, pXMLFileQRCode);
            pstmt.setString(6, pXMLFileCompact);
            pstmt.setString(7, pXMLFileCompactSigned);
            pstmt.setString(8, pXMLSecretCode);
            pstmt.setString(9, pXMLFileCompactQRCode);
            pstmt.setString(10, pXMLEcfStatusCode);
            pstmt.setString(11, pXMLEcfStatusName);
            pstmt.executeUpdate();
        }
    }

    public void setQuantumStateECF(String pIdRecord) throws SQLException {
        String sqlQuantumState = "UPDATE [" + DBConnection.getDBName() + "].[dbo].[ecf_xml_invoice]\n   SET [C_Posted] = 'Q'\n WHERE id_record = " + pIdRecord;
        try (PreparedStatement pstmt = this.connection.prepareStatement(sqlQuantumState);){
            pstmt.executeUpdate();
        }
    }

    public void RollBackQuantumStateECF(String pIdRecord) throws SQLException {
        String sqlQuantumState = "UPDATE [" + DBConnection.getDBName() + "].[dbo].[ecf_xml_invoice]\n   SET [C_Posted] = 'F'\n WHERE id_record = " + pIdRecord;
        try (PreparedStatement pstmt = this.connection.prepareStatement(sqlQuantumState);){
            pstmt.executeUpdate();
        }
    }

    public void setNStateECF(String pIdRecord) throws SQLException {
        String sqlSetNState = "UPDATE [" + DBConnection.getDBName() + "].[dbo].[ecf_xml_invoice]\n   SET [C_Posted] = 'N'\n WHERE id_record = " + pIdRecord;
        try (PreparedStatement pstmt = this.connection.prepareStatement(sqlSetNState);){
            pstmt.executeUpdate();
        }
    }

    public void setErrorStateECF(String pIdRecord) throws SQLException {
        String sqlQuantumState = "UPDATE [" + DBConnection.getDBName() + "].[dbo].[ecf_xml_invoice]\n   SET [C_Posted] = 'E', \n       [xml_ecf_status_code] = '-95', \n       [xml_ecf_status_name] = 'Empty XML' \n WHERE id_record = " + pIdRecord;
        try (PreparedStatement pstmt = this.connection.prepareStatement(sqlQuantumState);){
            pstmt.executeUpdate();
        }
    }

    public void StoreAPIResponse(String pIdRecord, String pXMLResponse, String pXMLTrackID, String pXMLTrackResponse, String pXMLEcfStatusCode, String pXMLEcfStatusName, String pXMLEcfUsedSeq) throws SQLException {
        Object sqlUpdateEcfXMLInvoice = "";
        String vUpdatePosted = "";
        if (Integer.parseInt(pXMLEcfStatusCode) == -101) {
            vUpdatePosted = ", C_Posted = 'S'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == -100) {
            vUpdatePosted = ", C_Posted = 'F'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == -99) {
            vUpdatePosted = ", C_Posted = 'F'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == -98) {
            vUpdatePosted = ", C_Posted = 'F'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == -96) {
            vUpdatePosted = ", C_Posted = 'E'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == 0) {
            vUpdatePosted = ", C_Posted = 'E'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == 1) {
            vUpdatePosted = ", C_Posted = 'Y'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == 2) {
            vUpdatePosted = ", C_Posted = 'R'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == 3) {
            vUpdatePosted = ", C_Posted = 'P'\n";
        }
        sqlUpdateEcfXMLInvoice = "UPDATE [" + DBConnection.getDBName() + "].[dbo].[ecf_xml_invoice]\n   SET [xml_response] = ?,\n       [xml_track_id] = ?,\n       [xml_track_response] = ?,\n       [xml_ecf_status_code] = ?,\n       [xml_ecf_status_name] = ?,\n       [xml_ecf_used_seq] = ?\n" + vUpdatePosted + " WHERE id_record = " + pIdRecord;
        try (PreparedStatement pstmt = this.connection.prepareStatement((String)sqlUpdateEcfXMLInvoice);){
            pstmt.setString(1, pXMLResponse);
            pstmt.setString(2, pXMLTrackID);
            pstmt.setString(3, pXMLTrackResponse);
            pstmt.setString(4, pXMLEcfStatusCode);
            pstmt.setString(5, pXMLEcfStatusName);
            pstmt.setString(6, pXMLEcfUsedSeq);
            pstmt.executeUpdate();
        }
    }

    public void checkStatusECF() {
        try {
            this.sqlCheckStatusECF = "  SELECT i.id_record,\n         i.doc_id,\n         i.ecf,\n         i.ecf_rnc_emisor,\n         i.ecf_rnc_comprador,\n         i.xml_security_code,\n         i.xml_track_id,\n         i.xml_secret_code,\n         i.C_Posted\n    FROM " + DBConnection.getDBName() + ".dbo.ecf_xml_invoice i\n   WHERE i.date_process >= GETDATE()-21 \n     AND i.C_Posted NOT IN ('N','Y','R','D','F','E','Q') \n     AND i.ecf_type IN (31,32,33,34,41,43,44,45,46,47)    ORDER BY id_record";
            this.vResultCheckStatusECF = this.dbConn.getSelectAssoc(this.sqlCheckStatusECF);
            if (!this.vResultCheckStatusECF.isEmpty()) {
                this.vRowCount = this.vResultCheckStatusECF.values().iterator().next().size();
                for (int i = 0; i < this.vRowCount; ++i) {
                    Map<String, Object> vResultGetStatusECF;
                    this.vRecordIDCheckStatusECF = this.vResultCheckStatusECF.get("id_record").get(i).toString();
                    this.vTrackIDCheckStatusECF = this.vResultCheckStatusECF.get("xml_track_id").get(i).toString();
                    this.vStEmisorRNC = this.vResultCheckStatusECF.get("ecf_rnc_emisor").get(i).toString();
                    this.vStENCF = this.vResultCheckStatusECF.get("ecf").get(i).toString();
                    this.vStSecurityCode = this.vResultCheckStatusECF.get("xml_security_code").get(i).toString();
                    this.sqlCheckTokenECF = "SELECT COALESCE(t.id_record,a.id_record) AS id_record, COALESCE(t.token_bearer,a.[token]) AS [token] FROM (SELECT 0 AS id_record, '' AS [token]) a LEFT JOIN " + DBConnection.getDBName() + ".dbo.ecf_xml_token t ON (1=1 AND t.token_valid_to > GETDATE() AND t.active = 'Y')";
                    this.vResultCheckTokenECF = this.dbConn.getSelectAssocFirstRow(this.sqlCheckTokenECF);
                    if (this.vResultCheckTokenECF.get("token").toString().isEmpty()) continue;
                    this.vTokenForStatusECF = this.vResultCheckTokenECF.get("token").toString();
                    this.sqlGetAPIForStatusECF = "SELECT config_value FROM " + DBConnection.getDBName() + ".dbo.ecf_global_config WHERE config_name = 'API' AND active = 'Y'";
                    Map<String, Object> vResultGetAPIForStatusECF = this.dbConn.getSelectAssocFirstRow(this.sqlGetAPIForStatusECF);
                    if (vResultGetAPIForStatusECF.isEmpty()) continue;
                    if (!this.vTrackIDCheckStatusECF.isEmpty() && this.vResultCheckStatusECF.get("xml_secret_code").get(i).toString().isEmpty()) {
                        this.sqlGetURLForStatusECF = "SELECT url_api FROM " + DBConnection.getDBName() + ".dbo.ecf_url_api WHERE url_order = 4 AND active = 'Y'";
                        vResultGetStatusECF = this.dbConn.getSelectAssocFirstRow(this.sqlGetURLForStatusECF);
                        if (vResultGetStatusECF.isEmpty()) continue;
                        this.vGetURLForStatusECF = vResultGetStatusECF.get("url_api").toString().replace("???", vResultGetAPIForStatusECF.get("config_value").toString());
                        this.xmlCheckStatusECF = this.formatXML(getXmlRequest.getStatusECF(this.vGetURLForStatusECF, this.vTokenForStatusECF, this.vTrackIDCheckStatusECF));
                        if (this.xmlCheckStatusECF.isEmpty()) continue;
                        this.docStatusECF = this.builder.parse(new ByteArrayInputStream(this.xmlCheckStatusECF.getBytes()));
                        this.xPathStatusECF = XPathFactory.newInstance().newXPath();
                        this.vStatusCodeCheckECF = this.xPathStatusECF.evaluate("/RespuestaConsultaTrackId/Codigo", this.docStatusECF);
                        this.vStatusNameCheckECF = this.xPathStatusECF.evaluate("/RespuestaConsultaTrackId/Estado", this.docStatusECF);
                        this.vStatusUsedSeqCheckECF = this.xPathStatusECF.evaluate("/RespuestaConsultaTrackId/SecuenciaUtilizada", this.docStatusECF);
                        String vStatusMessageCodeCheckECF = this.xPathStatusECF.evaluate("/RespuestaConsultaTrackId/Mensajes/Mensaje/Codigo", this.docStatusECF);
                        String vStatusMessageValueCheckECF = this.xPathStatusECF.evaluate("/RespuestaConsultaTrackId/Mensajes/Mensaje/Valor", this.docStatusECF);
                        if (this.vStatusCodeCheckECF.equalsIgnoreCase("2") && this.vStatusNameCheckECF.equalsIgnoreCase("Rechazado") && vStatusMessageCodeCheckECF.equalsIgnoreCase("1209") && vStatusMessageValueCheckECF.equalsIgnoreCase("Este n\u00famero de secuencia ya ha sido utilizado.")) {
                            this.vStatusCodeCheckECF = "1";
                            this.vStatusNameCheckECF = "Aceptado";
                        }
                        this.UpdateStatusECF(this.vRecordIDCheckStatusECF, this.xmlCheckStatusECF, this.vStatusCodeCheckECF, this.vStatusNameCheckECF, this.vStatusUsedSeqCheckECF);
                        continue;
                    }
                    this.sqlGetURLForStatusECF = "SELECT url_api FROM " + DBConnection.getDBName() + ".dbo.ecf_url_api WHERE url_order = 6 AND active = 'Y'";
                    vResultGetStatusECF = this.dbConn.getSelectAssocFirstRow(this.sqlGetURLForStatusECF);
                    if (vResultGetStatusECF.isEmpty()) continue;
                    this.vGetURLForStatusECF = vResultGetStatusECF.get("url_api").toString().replace("???", vResultGetAPIForStatusECF.get("config_value").toString());
                    this.vGetURLForStatusECF = this.vGetURLForStatusECF.replace("$EMISOR", this.vStEmisorRNC);
                    this.vGetURLForStatusECF = this.vGetURLForStatusECF.replace("$ECF", this.vStENCF);
                    this.vGetURLForStatusECF = this.vGetURLForStatusECF.replace("$SECURITYCODE", this.vStSecurityCode);
                    this.xmlCheckStatusECF = this.formatXML(getXmlRequest.getStatusRFCE(this.vGetURLForStatusECF, this.vTokenForStatusECF));
                    if (this.xmlCheckStatusECF.isEmpty()) continue;
                    this.docStatusECF = this.builder.parse(new ByteArrayInputStream(this.xmlCheckStatusECF.getBytes()));
                    this.xPathStatusECF = XPathFactory.newInstance().newXPath();
                    this.vStatusNameCheckECF = this.xPathStatusECF.evaluate("/Respuesta/Estado", this.docStatusECF);
                    if (this.vStatusNameCheckECF.equalsIgnoreCase("Quantum")) {
                        this.vStatusCodeCheckECF = "-99";
                    }
                    if (this.vStatusNameCheckECF.equalsIgnoreCase("Page Not Found")) {
                        this.vStatusCodeCheckECF = "-98";
                    }
                    if (this.vStatusNameCheckECF.equalsIgnoreCase("No encontrado")) {
                        this.vStatusCodeCheckECF = "0";
                    }
                    if (this.vStatusNameCheckECF.equalsIgnoreCase("Aceptado")) {
                        this.vStatusCodeCheckECF = "1";
                    }
                    if (this.vStatusNameCheckECF.equalsIgnoreCase("Rechazado")) {
                        this.vStatusCodeCheckECF = "2";
                    }
                    if (this.vStatusNameCheckECF.equalsIgnoreCase("En Proceso")) {
                        this.vStatusCodeCheckECF = "3";
                    }
                    this.vStatusUsedSeqCheckECF = this.xPathStatusECF.evaluate("/Respuesta/SecuenciaUtilizada", this.docStatusECF);
                    this.UpdateStatusECF(this.vRecordIDCheckStatusECF, this.xmlCheckStatusECF, this.vStatusCodeCheckECF, this.vStatusNameCheckECF, this.vStatusUsedSeqCheckECF);
                }
            }
        }
        catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void clearECFVariables() {
    }

    public void SaveTokenToDatabase(String pSeed, String pSignedSeed, String pToken, String pTokenBearer, String pTokenValidFrom, String pTokenValidTo) throws SQLException {
        this.sqlDeactivateOldTokens = "UPDATE " + DBConnection.getDBName() + ".dbo.ecf_xml_token SET active = 'N' WHERE active = 'Y'";
        try (PreparedStatement update_pstmt = this.connection.prepareStatement(this.sqlDeactivateOldTokens);){
            update_pstmt.executeUpdate();
        }
        this.sqlInsertToken = "INSERT INTO " + DBConnection.getDBName() + ".dbo.ecf_xml_token(seed_file, signed_seed_file, token_xml, token_bearer, token_valid_from, token_valid_to) VALUES(CONVERT(XML, CONVERT(TEXT, ?)),CONVERT(XML, CONVERT(TEXT, ?)),CONVERT(XML, CONVERT(TEXT, ?)),?,FORMAT(DATEADD(HOUR,-4,CONVERT(DATETIME,?)),'yyyy-MM-dd HH:mm:ss'),FORMAT(DATEADD(HOUR,-4,CONVERT(DATETIME,?)),'yyyy-MM-dd HH:mm:ss'))";
        try (PreparedStatement pstmt = this.connection.prepareStatement(this.sqlInsertToken);){
            pstmt.setString(1, pSeed);
            pstmt.setString(2, pSignedSeed);
            pstmt.setString(3, pToken);
            pstmt.setString(4, pTokenBearer);
            pstmt.setString(5, pTokenValidFrom);
            pstmt.setString(6, pTokenValidTo);
            pstmt.executeUpdate();
        }
    }

    public void SaveECFToDatabase(String pIdRecord, String pXMLFile, String pXMLFileSigned, String pXMLSecuriyCode, String pSignDateTime, String pXMLFileCompact, String pXMLFileCompactSigned, String pXMLSecretCode, String pXMLResponse, String pXMLTrackID, String pXMLTrackResponse, String pXMLEcfStatusCode, String pXMLEcfStatusName, String pXMLEcfUsedSeq) throws SQLException {
        Object sqlUpdateEcfXMLInvoice = "";
        String vUpdatePosted = "";
        if (Integer.parseInt(pXMLEcfStatusCode) == 1) {
            vUpdatePosted = ", C_Posted = 'Y'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == 2) {
            vUpdatePosted = ", C_Posted = 'R'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == 3) {
            vUpdatePosted = ", C_Posted = 'P'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == -99) {
            vUpdatePosted = ", C_Posted = 'E'\n";
        }
        sqlUpdateEcfXMLInvoice = "UPDATE [" + DBConnection.getDBName() + "].[dbo].[ecf_xml_invoice]\n   SET [xml_file] = ?,\n       [xml_file_signed] = ?,\n       [xml_security_code] = ?,\n       [xml_file_sign_date] = ?,\n       [xml_file_compact] = ?,\n       [xml_file_compact_signed] = ?,\n       [xml_secret_code] = ?,\n       [xml_response] = ?,\n       [xml_track_id] = ?,\n       [xml_track_response] = ?,\n       [xml_ecf_status_code] = ?,\n       [xml_ecf_status_name] = ?,\n       [xml_ecf_used_seq] = ?\n" + vUpdatePosted + " WHERE id_record = " + pIdRecord;
        try (PreparedStatement pstmt = this.connection.prepareStatement((String)sqlUpdateEcfXMLInvoice);){
            pstmt.setString(1, pXMLFile);
            pstmt.setString(2, pXMLFileSigned);
            pstmt.setString(3, pXMLSecuriyCode);
            pstmt.setString(4, pSignDateTime);
            pstmt.setString(5, pXMLFileCompact);
            pstmt.setString(6, pXMLFileCompactSigned);
            pstmt.setString(7, pXMLSecretCode);
            pstmt.setString(8, pXMLResponse);
            pstmt.setString(9, pXMLTrackID);
            pstmt.setString(10, pXMLTrackResponse);
            pstmt.setString(11, pXMLEcfStatusCode);
            pstmt.setString(12, pXMLEcfStatusName);
            pstmt.setString(13, pXMLEcfUsedSeq);
            pstmt.executeUpdate();
        }
    }

    public void UpdateStatusECF(String pIdRecord, String pXMLTrackResponse, String pXMLEcfStatusCode, String pXMLEcfStatusName, String pXMLEcfUsedSeq) throws SQLException {
        Object sqlUpdateEcfXMLInvoice = "";
        String vUpdatePosted = "";
        if (Integer.parseInt(pXMLEcfStatusCode) == -99) {
            vUpdatePosted = ", C_Posted = 'S'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == -98) {
            vUpdatePosted = ", C_Posted = 'S'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == 0) {
            vUpdatePosted = ", C_Posted = 'D'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == 1) {
            vUpdatePosted = ", C_Posted = 'Y'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == 2) {
            vUpdatePosted = ", C_Posted = 'R'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == 3) {
            vUpdatePosted = ", C_Posted = 'P'\n";
        }
        if (Integer.parseInt(pXMLEcfStatusCode) == 4) {
            vUpdatePosted = ", C_Posted = 'Y'\n";
        }
        sqlUpdateEcfXMLInvoice = "UPDATE [" + DBConnection.getDBName() + "].[dbo].[ecf_xml_invoice]\n   SET [xml_track_response] = ?,\n       [xml_ecf_status_code] = ?,\n       [xml_ecf_status_name] = ?,\n       [xml_ecf_used_seq] = ?\n" + vUpdatePosted + " WHERE id_record = " + pIdRecord;
        try (PreparedStatement pstmt = this.connection.prepareStatement((String)sqlUpdateEcfXMLInvoice);){
            pstmt.setString(1, pXMLTrackResponse);
            pstmt.setString(2, pXMLEcfStatusCode);
            pstmt.setString(3, pXMLEcfStatusName);
            pstmt.setString(4, pXMLEcfUsedSeq);
            pstmt.executeUpdate();
        }
    }

    public String formatXML(String xml) throws Exception {
        String vResult = "";
        if (!xml.isEmpty()) {
            DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
            DocumentBuilder db = dbf.newDocumentBuilder();
            Document doc = db.parse(new InputSource(new StringReader(xml)));
            TransformerFactory tf = TransformerFactory.newInstance();
            Transformer transformer = tf.newTransformer();
            transformer.setOutputProperty("indent", "yes");
            transformer.setOutputProperty("{http://xml.apache.org/xslt}indent-amount", "4");
            StringWriter writer = new StringWriter();
            transformer.transform(new DOMSource(doc), new StreamResult(writer));
            vResult = writer.toString();
        }
        return vResult;
    }

    public void getCertificateFromDB() {
        Object sqlGetCertificate = "";
        sqlGetCertificate = "SELECT id_record AS [#], FORMAT(cert_valid_from,'yyyy-MM-dd') AS desde, FORMAT(cert_valid_to,'yyyy-MM-dd') AS hasta, DATEDIFF(DAY, GETDATE(),cert_valid_to) AS restan FROM " + DBConnection.getDBName() + ".dbo.ecf_certificate WHERE cert_valid_to > GETDATE() AND active = 'Y'";
        this.gridCertificate._setSQLModel(this.dbConn.getConnection(), (String)sqlGetCertificate, false);
    }

    public void getTokenFromDB() {
        this.sqlGetToken = "SELECT id_record AS [#], RIGHT(token_bearer,50) AS [token], FORMAT(token_valid_from,'HH:mm:ss') AS desde, FORMAT(token_valid_to,'HH:mm:ss') AS hasta, DATEDIFF(MINUTE, GETDATE(),token_valid_to) AS restan FROM " + DBConnection.getDBName() + ".dbo.ecf_xml_token WHERE token_valid_to > GETDATE() AND active = 'Y'";
        this.gridToken._clear();
        this.gridToken._setSQLModel(this.dbConn.getConnection(), this.sqlGetToken, false);
    }

    public void getECFFromDB() {
        this.sqlGetECF = "       SELECT [id_record] AS [#],\n                      [doc_id] AS [id],\n                      [NumAtCard] AS ref,\n                      [ecf] AS ecf,\n                      [ecf_vence] AS [vence],\n                      [doc_type] AS dt,\n                      [ecf_print_pages] AS pp,\n                      [xml_security_code] [s.c.],\n                      FORMAT([xml_file_sign_date],'yyyy-MM-dd HH:mm:ss') AS [f.firma],\n                      [xml_track_id] AS [trackid],\n                      COALESCE(NULLIF([xml_track_response],''),[xml_response]) ,\n                      [xml_ecf_status_code] AS [</>],\n                      [xml_ecf_status_name] AS [api_msj],\n                      [C_Posted] [<S>],\n                      [date_process],\n                      [datetime_process]\n                 FROM [" + DBConnection.getDBName() + "].[dbo].[ecf_xml_invoice] i\n                WHERE i.active = 'Y'\n                  AND /*i.C_Posted NOT IN ('Y') AND*/ date_process = CONVERT(DATE, GETDATE())";
        this.gridECF._clear();
        this.gridECF._setSQLModel(this.dbConn.getConnection(), this.sqlGetECF, false);
        StyleClass.setGridModelECF(this.gridECF);
    }

    public void getCounterECF() {
        String sqlGetCounterECF = "";
        if (DBConnection.getDBName().equalsIgnoreCase("cms")) {
            sqlGetCounterECF = "         SELECT id_record,\n                           'E'+[ecf_type_id] AS [ecf],\n                           [ecf_type_alias] AS [nombre],\n                           COALESCE(a.disponibles,0) AS restan,\n                           ecf_type_min_yellow AS min_yellow,\n                           ecf_type_min_red AS min_red\n                      FROM [cms].[dbo].[ecf_type] t\n                 LEFT JOIN (SELECT c.serie,\n                                   SUM(c.disponibles) AS disponibles\n                              FROM (SELECT id_carga,\n                                           serie,\n                                           vencimiento,\n                                           contador,\n                                           final,\n                                           final - contador AS disponibles\n                                      FROM cms.dbo.carga_ncf\n                                     WHERE serie in ('E31','E32','E44','E45')\n                                       AND contador < final\n                                 UNION ALL\n                                    SELECT [Code] AS id_carga,\n                                           (U_SERIE + U_TIPO_COMPROBANTE) AS serie,\n                                           CONVERT(DATE, U_FechaValido) AS vencimiento,\n                                           U_Secuencial AS contador,\n                                           U_Final AS final,\n                                           U_Final - U_Secuencial AS disponibles\n                                      FROM SBO_AGROFEM.dbo.[@COMPROBANTES]\n                                     WHERE U_SERIE = 'E'\n                                       AND U_TIPO_COMPROBANTE IN (33,34,41,43)\n                                       AND U_Secuencial < U_Final\n                                   ) c\n                          GROUP BY c.serie\n                           ) a ON (a.serie = 'E'+[ecf_type_id])\n\n                     WHERE t.[active] = 'Y'\n                  ORDER BY t.[ecf_type_order]";
        }
        if (DBConnection.getDBName().equalsIgnoreCase("cms_mmf")) {
            sqlGetCounterECF = "                                 SELECT id_record,\n                                               'E'+[ecf_type_id] AS [ecf],\n                                               [ecf_type_alias] AS [nombre],\n                                               COALESCE(a.disponibles,0) AS restan,\n                                               ecf_type_min_yellow AS min_yellow,\n                                               ecf_type_min_red AS min_red                \n                                          FROM [CMS_MMF].[dbo].[ecf_type] t\n                                     LEFT JOIN (SELECT c.serie,\n                                                       SUM(c.disponibles) AS disponibles\n                                                  FROM (SELECT id_carga,\n                                                               serie,\n                                                               vencimiento,\n                                                               contador,\n                                                               final,\n                                                               (final - contador) AS disponibles\n                                                          FROM cms_mmf.dbo.carga_ncf\n                                                         WHERE serie in ('E31','E32','E34','E44','E45')\n                                                           AND contador < final\n                                                     UNION ALL\n                                                        SELECT [Code] AS id_carga,\n                                                               (U_SERIE + U_TIPO_COMPROBANTE) AS serie,\n                                                               CONVERT(DATE, U_FechaValido) AS vencimiento,\n                                                               U_Secuencial AS contador,\n                                                               U_Final AS final,\n                                                               U_Final - U_Secuencial AS disponibles\n                                                          FROM SBO_MERCA.dbo.[@COMPROBANTES]\n                                                         WHERE U_SERIE = 'E'\n                                                           AND U_TIPO_COMPROBANTE IN (33,41,43)\n                                                           AND U_Secuencial < U_Final\n                                                       ) c\n                                              GROUP BY c.serie\n                                               ) a ON (a.serie = 'E'+[ecf_type_id])\n                    \n                                         WHERE t.[active] = 'Y'\n                                      ORDER BY t.[ecf_type_order]";
        }
        this.gridCounterECF._clear();
        this.gridCounterECF.repaint();
        this.gridCounterECF._setSQLModel(this.dbConn.getConnection(), sqlGetCounterECF, false);
        StyleClass.setGridModelCounterECF(this.gridCounterECF);
        this.gridCounterECF.getColumnModel().getColumn(3).setCellRenderer(new LabelCellRendererCounterECFLights());
    }

    public LocalDateTime getCurrentDbTime() {
        try {
            this.sqlGetDbTime = "SELECT FORMAT(GETDATE(),'yyyy-MM-dd HH:mm:ss') AS timenow";
            this.vResultDbTime = this.dbConn.getSelectAssocFirstRow(this.sqlGetDbTime);
            if (!this.vResultDbTime.isEmpty()) {
                DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
                this.vTimeNow = LocalDateTime.parse(this.vResultDbTime.get("timenow").toString(), formatter);
                return this.vTimeNow;
            }
        }
        catch (Exception e) {
            return null;
        }
        return null;
    }

    public void getTokenParams() {
        try {
            this.vTokenRefreshBeforeExpire = 0;
            this.vTokenRequestMaxAttempts = 0;
            this.sqlGetTokenConfigParams = "SELECT config_value FROM " + DBConnection.getDBName() + ".dbo.ecf_global_config WHERE config_name = 'TokenRefreshBeforeExpire' AND active = 'Y'";
            this.vResultTokenConfigParams = this.dbConn.getSelectAssocFirstRow(this.sqlGetTokenConfigParams);
            if (!this.vResultTokenConfigParams.isEmpty()) {
                this.vTokenRefreshBeforeExpire = Integer.parseInt(this.vResultTokenConfigParams.get("config_value").toString());
            }
            this.sqlGetTokenConfigParams = "SELECT config_value FROM " + DBConnection.getDBName() + ".dbo.ecf_global_config WHERE config_name = 'TokenRequestMaxAttempts' AND active = 'Y'";
            this.vResultTokenConfigParams = this.dbConn.getSelectAssocFirstRow(this.sqlGetTokenConfigParams);
            if (!this.vResultTokenConfigParams.isEmpty()) {
                this.vTokenRequestMaxAttempts = Integer.parseInt(this.vResultTokenConfigParams.get("config_value").toString());
            }
        }
        catch (Exception e) {
            this.vTokenRefreshBeforeExpire = 0;
            this.vTokenRequestMaxAttempts = 0;
        }
    }

    public void startTokenRefreshTask() {
        ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
        scheduler.scheduleAtFixedRate(() -> {
            block9: {
                try {
                    this.getTokenParams();
                    this.sqlGetTokenInfo = "SELECT id_record AS [#], token_bearer AS [token], FORMAT(token_valid_from,'HH:mm:ss') AS desde, FORMAT(token_valid_to,'yyyy-MM-dd HH:mm:ss') AS hasta, DATEDIFF(MINUTE, GETDATE(),token_valid_to) AS faltante FROM " + DBConnection.getDBName() + ".dbo.ecf_xml_token WHERE token_valid_to > GETDATE() AND active = 'Y'";
                    this.vResultTokenInfo = this.dbConn.getSelectAssocFirstRow(this.sqlGetTokenInfo);
                    if (!this.vResultTokenInfo.isEmpty() && this.vTokenRefreshBeforeExpire > 0 && this.vTokenRequestMaxAttempts > 0) {
                        LocalDateTime now = this.getCurrentDbTime();
                        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
                        LocalDateTime vTokenValidToTemp = LocalDateTime.parse(this.vResultTokenInfo.get("hasta").toString(), formatter);
                        long minutesToExpire = ChronoUnit.MINUTES.between(now, vTokenValidToTemp);
                        if (minutesToExpire > (long)this.vTokenRefreshBeforeExpire) break block9;
                        for (int attempt = 1; attempt <= this.vTokenRequestMaxAttempts; ++attempt) {
                            try {
                                this.insertTestData();
                                break block9;
                            }
                            catch (Exception e) {
                                if (attempt != this.vTokenRequestMaxAttempts) continue;
                                this.lblTokenMessage.setText("Se han agoado los intentos para obtener un Token Valido...");
                                continue;
                            }
                        }
                        break block9;
                    }
                    for (int attempt = 1; attempt <= this.vTokenRequestMaxAttempts; ++attempt) {
                        try {
                            this.insertTestData();
                            break;
                        }
                        catch (Exception e) {
                            if (attempt != this.vTokenRequestMaxAttempts && this.vTokenRequestMaxAttempts != 0) continue;
                            this.lblTokenMessage.setText("Se han agoado los intentos para obtener un Token Valido...");
                            continue;
                        }
                    }
                }
                catch (Exception exception) {
                    // empty catch block
                }
            }
        }, 0L, 1L, TimeUnit.MINUTES);
    }

    public void startTokenGridRefreshTask() {
        ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
        scheduler.scheduleAtFixedRate(() -> {
            try {
                this.getTokenFromDB();
            }
            catch (Exception e) {
                e.printStackTrace();
            }
        }, 0L, 1L, TimeUnit.MINUTES);
    }

    public void startUpdateStatusECFRefreshTask() {
        ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
        scheduler.scheduleAtFixedRate(() -> {
            try {
                this.checkStatusECF();
            }
            catch (Exception e) {
                e.printStackTrace();
            }
        }, 0L, 3L, TimeUnit.SECONDS);
    }

    public void startECFRefreshTask() {
        this.schEcfGridRefresh = Executors.newScheduledThreadPool(1);
        this.schEcfGridRefresh.scheduleAtFixedRate(() -> {
            if (this.vIsRunning) {
                try {
                    this.getECFFromDB();
                }
                catch (Exception e) {
                    e.printStackTrace();
                }
            } else {
                this.stopECFRefreshTask();
            }
        }, 0L, 5L, TimeUnit.SECONDS);
    }

    public void stopECFRefreshTask() {
        if (this.schEcfGridRefresh != null && !this.schEcfGridRefresh.isShutdown()) {
            this.schEcfGridRefresh.shutdown();
        }
    }

    public void startCounterECFRefreshTask() {
        ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
        scheduler.scheduleAtFixedRate(() -> {
            try {
                this.getCounterECF();
            }
            catch (Exception e) {
                e.printStackTrace();
            }
        }, 0L, 1L, TimeUnit.MINUTES);
    }

    public void SignECFTask() {
        ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
        scheduler.scheduleAtFixedRate(() -> {
            try {
                this.ecfGenerator();
            }
            catch (Exception e) {
                e.printStackTrace();
            }
        }, 0L, 3L, TimeUnit.SECONDS);
    }

    public void UploadECFTask() {
        ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
        scheduler.scheduleAtFixedRate(() -> {
            try {
                this.ecfUploader();
            }
            catch (Exception e) {
                e.printStackTrace();
            }
        }, 0L, 5L, TimeUnit.SECONDS);
    }
}

