/*
 * Decompiled with CFR 0.152.
 */
package xmlsentry;

import com.formdev.flatlaf.FlatLaf;
import com.formdev.flatlaf.FlatLightLaf;
import java.awt.AWTException;
import java.awt.Color;
import java.awt.Image;
import java.awt.Insets;
import java.awt.MenuItem;
import java.awt.PopupMenu;
import java.awt.SystemTray;
import java.awt.Toolkit;
import java.awt.TrayIcon;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.Collections;
import javax.swing.ImageIcon;
import javax.swing.UIManager;
import xmlsentry.DBConnection;
import xmlsentry.frmMain;

public class XmlSentry {
    public static void main(String[] args) {
        try {
            DBConnection dbConn = DBConnection.getInstance();
            Connection connection = dbConn.getConnection();
        }
        catch (SQLException e) {
            e.printStackTrace();
        }
        FlatLaf.setGlobalExtraDefaults(Collections.singletonMap("@accentColor", "#4b6eaf"));
        FlatLightLaf.setup();
        UIManager.put("Button.arc", 20);
        UIManager.put("TabbedPane.selectedBackground", Color.decode("#136dac"));
        UIManager.put("TabbedPane.background", Color.decode("#136dac"));
        UIManager.put("TabbedPane.hoverColor", Color.decode("#136dac"));
        UIManager.put("TabbedPane.tabInsets", new Insets(2, 2, 2, 2));
        UIManager.put("TabbedPane.tabHeight", 10);
        UIManager.put("MenuItem.background", Color.decode("#f4f4f4"));
        UIManager.put("MenuItem.foreground", Color.decode("#4a4a4a"));
        UIManager.put("MenuItem.selectionBackground", Color.decode("#d3d3d3"));
        UIManager.put("MenuItem.selectionForeground", Color.decode("#4a4a4a"));
        UIManager.put("MenuItem.roundedSelection", true);
        if (!SystemTray.isSupported()) {
            System.out.println("System tray is not supported !!! ");
            return;
        }
        SystemTray systemTray = SystemTray.getSystemTray();
        Image image = Toolkit.getDefaultToolkit().getImage("img/SentryAFM.png");
        PopupMenu trayPopupMenu = new PopupMenu();
        MenuItem action = new MenuItem("Config");
        action.addActionListener(new ActionListener(){

            @Override
            public void actionPerformed(ActionEvent e) {
                frmMain jrmTrayTest = new frmMain();
                jrmTrayTest.setLocationRelativeTo(null);
                ImageIcon icon = new ImageIcon("img/SentryAFM.png");
                jrmTrayTest.setIconImage(icon.getImage());
                jrmTrayTest.setVisible(true);
            }
        });
        trayPopupMenu.add(action);
        MenuItem close = new MenuItem("Close");
        close.addActionListener(new ActionListener(){

            @Override
            public void actionPerformed(ActionEvent e) {
                System.exit(0);
            }
        });
        trayPopupMenu.add(close);
        TrayIcon trayIcon = new TrayIcon(image, "Sentry", trayPopupMenu);
        trayIcon.setImageAutoSize(true);
        try {
            systemTray.add(trayIcon);
        }
        catch (AWTException awtException) {
            awtException.printStackTrace();
        }
    }
}

