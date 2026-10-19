/*
 * Decompiled with CFR 0.152.
 */
package xmlsentry;

import Controls.SbDataGridView;
import Controls.SbDatePicker;
import java.awt.Color;
import java.awt.EventQueue;
import java.awt.Font;
import java.awt.Frame;
import java.awt.Insets;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.swing.BorderFactory;
import javax.swing.JButton;
import javax.swing.JDialog;
import javax.swing.JFileChooser;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JScrollPane;
import javax.swing.JTextField;
import javax.swing.UIManager;
import javax.swing.UnsupportedLookAndFeelException;
import javax.swing.filechooser.FileNameExtensionFilter;
import javax.swing.table.DefaultTableModel;
import xmlsentry.DBConnection;

public class frmChangeCertificate
extends JDialog {
    DBConnection dbConn = null;
    Connection connection = null;
    String vCertPath = "";
    String vCertName = "";
    String vCertKey = "";
    String vDateFrom = "";
    String vDateTo = "";
    String sqlGetCertificate = "";
    byte[] fileContent = null;
    private JTextField edCertKey;
    private JTextField edFileLocation;
    private SbDatePicker fecha1;
    private SbDatePicker fecha2;
    private SbDataGridView gridCertificate;
    private JButton jButton1;
    private JButton jButton2;
    private JLabel jLabel1;
    private JLabel jLabel2;
    private JLabel jLabel3;
    private JLabel jLabel4;
    private JLabel jLabel5;
    private JScrollPane jScrollPane2;

    public frmChangeCertificate(Frame parent, boolean modal) {
        super(parent, modal);
        this.initComponents();
        try {
            this.dbConn = DBConnection.getInstance();
            this.connection = this.dbConn.getConnection();
        }
        catch (SQLException e) {
            e.printStackTrace();
        }
        this.geCertificateFromDB();
    }

    private void initComponents() {
        this.jLabel1 = new JLabel();
        this.edFileLocation = new JTextField();
        this.fecha1 = new SbDatePicker();
        this.jLabel2 = new JLabel();
        this.jLabel3 = new JLabel();
        this.jButton1 = new JButton();
        this.fecha2 = new SbDatePicker();
        this.jLabel4 = new JLabel();
        this.jScrollPane2 = new JScrollPane();
        this.gridCertificate = new SbDataGridView();
        this.jLabel5 = new JLabel();
        this.edCertKey = new JTextField();
        this.jButton2 = new JButton();
        this.setDefaultCloseOperation(2);
        this.setTitle("Agrega un Nuevo Certificado");
        this.setResizable(false);
        this.getContentPane().setLayout(null);
        this.jLabel1.setFont(new Font("Segoe UI", 0, 13));
        this.jLabel1.setHorizontalAlignment(11);
        this.jLabel1.setText("Valido Hasta: ");
        this.getContentPane().add(this.jLabel1);
        this.jLabel1.setBounds(5, 102, 85, 22);
        this.edFileLocation.setEditable(false);
        this.getContentPane().add(this.edFileLocation);
        this.edFileLocation.setBounds(88, 30, 530, 22);
        this.fecha1.setBackground(new Color(60, 63, 65));
        this.fecha1.setBorder(BorderFactory.createLineBorder(new Color(60, 63, 65)));
        this.fecha1.setForeground(new Color(60, 63, 65));
        this.fecha1.setFont(new Font("Segoe UI", 1, 13));
        this.fecha1.setSbRequired(Boolean.TRUE);
        this.getContentPane().add(this.fecha1);
        this.fecha1.setBounds(88, 78, 206, 23);
        this.jLabel2.setFont(new Font("Segoe UI", 0, 13));
        this.jLabel2.setHorizontalAlignment(11);
        this.jLabel2.setText("Ruta Cert: ");
        this.getContentPane().add(this.jLabel2);
        this.jLabel2.setBounds(5, 30, 84, 22);
        this.jLabel3.setFont(new Font("Segoe UI", 0, 13));
        this.jLabel3.setHorizontalAlignment(11);
        this.jLabel3.setText("Valido Desde: ");
        this.jLabel3.setToolTipText("");
        this.getContentPane().add(this.jLabel3);
        this.jLabel3.setBounds(5, 78, 85, 22);
        this.jButton1.setText("Abrir");
        this.jButton1.setMargin(new Insets(2, 2, 2, 2));
        this.jButton1.addActionListener(new ActionListener(){

            @Override
            public void actionPerformed(ActionEvent evt) {
                frmChangeCertificate.this.jButton1ActionPerformed(evt);
            }
        });
        this.getContentPane().add(this.jButton1);
        this.jButton1.setBounds(620, 30, 60, 20);
        this.fecha2.setBackground(new Color(60, 63, 65));
        this.fecha2.setBorder(BorderFactory.createLineBorder(new Color(60, 63, 65)));
        this.fecha2.setForeground(new Color(60, 63, 65));
        this.fecha2.setFont(new Font("Segoe UI", 1, 13));
        this.fecha2.setSbRequired(Boolean.TRUE);
        this.getContentPane().add(this.fecha2);
        this.fecha2.setBounds(88, 102, 206, 23);
        this.jLabel4.setFont(new Font("Segoe UI", 1, 13));
        this.jLabel4.setForeground(new Color(19, 109, 172));
        this.jLabel4.setHorizontalAlignment(0);
        this.jLabel4.setText("AGREGAR CERTIFICADO");
        this.getContentPane().add(this.jLabel4);
        this.jLabel4.setBounds(5, 5, 674, 18);
        this.gridCertificate.setBackground(new Color(255, 255, 255));
        this.gridCertificate.setForeground(new Color(60, 63, 65));
        this.gridCertificate.setModel(new DefaultTableModel(new Object[0][], new String[]{"", "", "", "", ""}){
            Class[] types;
            {
                this.types = new Class[]{Integer.class, String.class, String.class, String.class, Integer.class};
            }

            public Class getColumnClass(int columnIndex) {
                return this.types[columnIndex];
            }
        });
        this.gridCertificate.setFont(new Font("Segoe UI", 0, 12));
        this.gridCertificate.setGridColor(new Color(242, 242, 242));
        this.gridCertificate.setSbHeaderBackground(new Color(255, 255, 255));
        this.gridCertificate.setSbHeaderForeground(new Color(19, 109, 172));
        this.gridCertificate.setSelectionBackground(new Color(80, 83, 85));
        this.gridCertificate.setShowHorizontalLines(true);
        this.gridCertificate.setShowVerticalLines(true);
        this.jScrollPane2.setViewportView(this.gridCertificate);
        if (this.gridCertificate.getColumnModel().getColumnCount() > 0) {
            this.gridCertificate.getColumnModel().getColumn(0).setMinWidth(35);
            this.gridCertificate.getColumnModel().getColumn(0).setPreferredWidth(35);
            this.gridCertificate.getColumnModel().getColumn(0).setMaxWidth(35);
            this.gridCertificate.getColumnModel().getColumn(1).setMinWidth(380);
            this.gridCertificate.getColumnModel().getColumn(1).setPreferredWidth(380);
            this.gridCertificate.getColumnModel().getColumn(1).setMaxWidth(380);
            this.gridCertificate.getColumnModel().getColumn(2).setMinWidth(85);
            this.gridCertificate.getColumnModel().getColumn(2).setPreferredWidth(85);
            this.gridCertificate.getColumnModel().getColumn(2).setMaxWidth(85);
            this.gridCertificate.getColumnModel().getColumn(3).setMinWidth(85);
            this.gridCertificate.getColumnModel().getColumn(3).setPreferredWidth(85);
            this.gridCertificate.getColumnModel().getColumn(3).setMaxWidth(85);
            this.gridCertificate.getColumnModel().getColumn(4).setMinWidth(70);
            this.gridCertificate.getColumnModel().getColumn(4).setPreferredWidth(70);
            this.gridCertificate.getColumnModel().getColumn(4).setMaxWidth(70);
        }
        this.getContentPane().add(this.jScrollPane2);
        this.jScrollPane2.setBounds(5, 134, 674, 230);
        this.jLabel5.setFont(new Font("Segoe UI", 0, 13));
        this.jLabel5.setHorizontalAlignment(11);
        this.jLabel5.setText("Key Cert: ");
        this.getContentPane().add(this.jLabel5);
        this.jLabel5.setBounds(5, 54, 84, 22);
        this.getContentPane().add(this.edCertKey);
        this.edCertKey.setBounds(88, 54, 280, 22);
        this.jButton2.setText("Guardar");
        this.jButton2.setMargin(new Insets(2, 2, 2, 2));
        this.jButton2.addActionListener(new ActionListener(){

            @Override
            public void actionPerformed(ActionEvent evt) {
                frmChangeCertificate.this.jButton2ActionPerformed(evt);
            }
        });
        this.getContentPane().add(this.jButton2);
        this.jButton2.setBounds(620, 54, 60, 20);
        this.pack();
    }

    private void jButton1ActionPerformed(ActionEvent evt) {
        JFileChooser fileChooser = new JFileChooser();
        FileNameExtensionFilter filter = new FileNameExtensionFilter("P12 files", "p12");
        fileChooser.setFileFilter(filter);
        int returnValue = fileChooser.showOpenDialog(null);
        if (returnValue == 0) {
            File file = fileChooser.getSelectedFile();
            try {
                this.fileContent = frmChangeCertificate.readFileContent(file);
                this.vCertName = file.getName();
                this.vCertPath = file.getAbsolutePath();
                this.edFileLocation.setText(this.vCertPath);
            }
            catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    private void jButton2ActionPerformed(ActionEvent evt) {
        this.vDateFrom = this.fecha1._getDate("yyyy-MM-dd");
        this.vDateTo = this.fecha2._getDate("yyyy-MM-dd");
        if (!(this.fileContent.toString().isEmpty() || this.edFileLocation.getText().isEmpty() || this.edCertKey.getText().isEmpty())) {
            this.vCertKey = this.edCertKey.getText();
            if (!this.vDateFrom.isEmpty() && !this.vDateTo.isEmpty()) {
                try {
                    this.storeP12FileInDatabase(this.fileContent, this.vCertName, this.vCertPath, this.vCertKey, this.vDateFrom, this.vDateTo);
                    this.geCertificateFromDB();
                }
                catch (Exception e) {
                    e.printStackTrace();
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

    public void storeP12FileInDatabase(byte[] fileContent, String fileName, String fileLocation, String keyPassword, String expeditionDate, String expirationDate) throws SQLException {
        Connection connection = this.dbConn.getConnection();
        String query = "INSERT INTO " + DBConnection.getDBName() + ".dbo.ecf_certificate (cert_file, cert_name, cert_description, cert_key, cert_valid_from, cert_valid_to) VALUES (?, ?, ?, ?, ?, ?)";
        try (PreparedStatement pstmt = connection.prepareStatement(query);){
            pstmt.setBytes(1, fileContent);
            pstmt.setString(2, fileName);
            pstmt.setString(3, fileLocation);
            pstmt.setString(4, keyPassword);
            pstmt.setString(5, expeditionDate);
            pstmt.setString(6, expirationDate);
            pstmt.executeUpdate();
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
            Logger.getLogger(frmChangeCertificate.class.getName()).log(Level.SEVERE, null, ex);
        }
        catch (InstantiationException ex) {
            Logger.getLogger(frmChangeCertificate.class.getName()).log(Level.SEVERE, null, ex);
        }
        catch (IllegalAccessException ex) {
            Logger.getLogger(frmChangeCertificate.class.getName()).log(Level.SEVERE, null, ex);
        }
        catch (UnsupportedLookAndFeelException ex) {
            Logger.getLogger(frmChangeCertificate.class.getName()).log(Level.SEVERE, null, ex);
        }
        EventQueue.invokeLater(new Runnable(){

            @Override
            public void run() {
                frmChangeCertificate dialog = new frmChangeCertificate((Frame)new JFrame(), true);
                dialog.addWindowListener(new WindowAdapter(){

                    @Override
                    public void windowClosing(WindowEvent e) {
                        System.exit(0);
                    }
                });
                dialog.setVisible(true);
            }
        });
    }

    public void geCertificateFromDB() {
        this.sqlGetCertificate = "SELECT id_record AS [#], cert_name AS [path], cert_valid_from AS desde, cert_valid_to AS hasta, DATEDIFF(DAY, GETDATE(),cert_valid_to) AS faltante FROM " + DBConnection.getDBName() + ".dbo.ecf_certificate WHERE cert_valid_to > GETDATE() AND active = 'Y'";
        this.gridCertificate._setSQLModel(this.dbConn.getConnection(), this.sqlGetCertificate, false);
    }
}

