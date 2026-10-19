/*
 * Decompiled with CFR 0.152.
 */
package xmlsentry;

import java.awt.Component;
import java.awt.Font;
import java.text.DecimalFormat;
import java.text.NumberFormat;
import java.util.Locale;
import javax.swing.JLabel;
import javax.swing.JTable;
import javax.swing.table.DefaultTableCellRenderer;

class LabelCellRendererCounterECFLights
extends DefaultTableCellRenderer {
    LabelCellRendererCounterECFLights() {
    }

    @Override
    public Component getTableCellRendererComponent(JTable table, Object value, boolean isSelected, boolean hasFocus, int row, int column) {
        JLabel c = (JLabel)super.getTableCellRendererComponent(table, value, isSelected, hasFocus, row, column);
        Object vTextHTML = "";
        int vMinYellow = 0;
        int vMinRed = 0;
        if (value != null) {
            NumberFormat mnf = DecimalFormat.getInstance(Locale.ENGLISH);
            DecimalFormat decimalFormatter = (DecimalFormat)mnf;
            decimalFormatter.applyPattern("###,###,##0");
            int myVal = (Integer)value;
            vMinYellow = Integer.parseInt(table.getValueAt(row, 4).toString());
            vMinRed = Integer.parseInt(table.getValueAt(row, 5).toString());
            c.setHorizontalAlignment(4);
            if (myVal <= vMinYellow) {
                c.setFont(new Font(table.getFont().getFamily(), 1, table.getFont().getSize()));
                vTextHTML = "<html><font color=\"#ED7D31\">" + decimalFormatter.format(myVal) + "</font></html>";
            }
            if (myVal <= vMinRed) {
                c.setFont(new Font(table.getFont().getFamily(), 1, table.getFont().getSize()));
                vTextHTML = "<html><font color=\"#FF4500\">" + decimalFormatter.format(myVal) + "</font></html>";
            }
            if (myVal > vMinYellow) {
                c.setFont(new Font(table.getFont().getFamily(), 1, table.getFont().getSize()));
                vTextHTML = "<html><font color=\"#666666\">" + decimalFormatter.format(myVal) + "</font></html>";
            }
            c.setText((String)vTextHTML);
        }
        return c;
    }
}

