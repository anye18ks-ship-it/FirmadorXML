/*
 * Decompiled with CFR 0.152.
 */
package xmlsentry;

import Controls.SbDataGridView;
import java.awt.Color;
import javax.swing.JTextPane;
import javax.swing.text.BadLocationException;
import javax.swing.text.Style;
import javax.swing.text.StyleConstants;
import javax.swing.text.StyledDocument;

public class StyleClass {
    public static void colorXMLInTextPane(JTextPane txtApiMessage, String pMessageXML) {
        StyledDocument doc = txtApiMessage.getStyledDocument();
        try {
            doc.remove(0, doc.getLength());
        }
        catch (BadLocationException e) {
            e.printStackTrace();
        }
        Style defaultStyle = txtApiMessage.addStyle("Default", null);
        StyleConstants.setForeground(defaultStyle, new Color(70, 130, 180));
        Style xmlDeclStyle = txtApiMessage.addStyle("XmlDecl", null);
        StyleConstants.setForeground(xmlDeclStyle, new Color(255, 87, 51));
        Style valueStyle = txtApiMessage.addStyle("Value", null);
        StyleConstants.setForeground(valueStyle, new Color(54, 69, 79));
        StyleConstants.setBold(valueStyle, true);
        Style quoteStyle = txtApiMessage.addStyle("Quote", null);
        StyleConstants.setForeground(quoteStyle, new Color(128, 0, 128));
        try {
            String[] lines;
            for (String line : lines = pMessageXML.split("\n")) {
                if (line.isEmpty()) {
                    doc.insertString(doc.getLength(), "\n", defaultStyle);
                    continue;
                }
                if (line.startsWith("<?xml")) {
                    doc.insertString(doc.getLength(), line + "\n", xmlDeclStyle);
                    continue;
                }
                int pos = 0;
                while (pos < line.length()) {
                    String valueText;
                    String tagText;
                    int quotePos;
                    int nextEvent;
                    int quoteStart = line.indexOf(34, pos);
                    int tagOpen = line.indexOf(60, pos);
                    int tagClose = line.indexOf(62, pos);
                    if (quoteStart == -1) {
                        quoteStart = line.length();
                    }
                    if (tagOpen == -1) {
                        tagOpen = line.length();
                    }
                    if (tagClose == -1) {
                        tagClose = line.length();
                    }
                    if (pos < (nextEvent = Math.min(quoteStart, Math.min(tagOpen, tagClose)))) {
                        doc.insertString(doc.getLength(), line.substring(pos, nextEvent), defaultStyle);
                        pos = nextEvent;
                    }
                    if (pos != tagOpen || pos >= line.length()) continue;
                    int nextClose = line.indexOf(62, pos + 1);
                    if (nextClose == -1) {
                        nextClose = line.length();
                    }
                    if ((quotePos = (tagText = line.substring(pos, nextClose + 1)).indexOf(34)) != -1) {
                        int tagStart = 0;
                        while (tagStart < tagText.length()) {
                            int qEnd;
                            int qStart = tagText.indexOf(34, tagStart);
                            if (qStart == -1) {
                                doc.insertString(doc.getLength(), tagText.substring(tagStart), defaultStyle);
                                break;
                            }
                            if (tagStart < qStart) {
                                doc.insertString(doc.getLength(), tagText.substring(tagStart, qStart), defaultStyle);
                            }
                            if ((qEnd = tagText.indexOf(34, qStart + 1)) == -1) {
                                qEnd = tagText.length();
                            }
                            doc.insertString(doc.getLength(), tagText.substring(qStart, qEnd + 1), quoteStyle);
                            tagStart = qEnd + 1;
                        }
                    } else {
                        doc.insertString(doc.getLength(), tagText, defaultStyle);
                    }
                    pos = nextClose + 1;
                    int nextOpen = line.indexOf(60, pos);
                    if (nextOpen == -1) {
                        nextOpen = line.length();
                    }
                    if (pos >= nextOpen || (valueText = line.substring(pos, nextOpen)).trim().isEmpty()) continue;
                    doc.insertString(doc.getLength(), valueText, valueStyle);
                    pos = nextOpen;
                }
                doc.insertString(doc.getLength(), "\n", defaultStyle);
            }
        }
        catch (BadLocationException e) {
            e.printStackTrace();
        }
    }

    public static void setGridModelECF(SbDataGridView pGrid) {
        pGrid.getColumnModel().getColumn(0).setMinWidth(0);
        pGrid.getColumnModel().getColumn(0).setMaxWidth(0);
        pGrid.getColumnModel().getColumn(0).setWidth(0);
        pGrid.getColumnModel().getColumn(1).setMinWidth(65);
        pGrid.getColumnModel().getColumn(1).setMaxWidth(65);
        pGrid.getColumnModel().getColumn(1).setWidth(65);
        pGrid.getColumnModel().getColumn(2).setMinWidth(70);
        pGrid.getColumnModel().getColumn(2).setMaxWidth(70);
        pGrid.getColumnModel().getColumn(2).setWidth(70);
        pGrid.getColumnModel().getColumn(3).setMinWidth(90);
        pGrid.getColumnModel().getColumn(3).setMaxWidth(90);
        pGrid.getColumnModel().getColumn(3).setWidth(90);
        pGrid.getColumnModel().getColumn(4).setMinWidth(70);
        pGrid.getColumnModel().getColumn(4).setMaxWidth(70);
        pGrid.getColumnModel().getColumn(4).setWidth(70);
        pGrid.getColumnModel().getColumn(5).setMinWidth(30);
        pGrid.getColumnModel().getColumn(5).setMaxWidth(30);
        pGrid.getColumnModel().getColumn(5).setWidth(30);
        pGrid.getColumnModel().getColumn(6).setMinWidth(30);
        pGrid.getColumnModel().getColumn(6).setMaxWidth(30);
        pGrid.getColumnModel().getColumn(6).setWidth(30);
        pGrid.getColumnModel().getColumn(7).setMinWidth(60);
        pGrid.getColumnModel().getColumn(7).setMaxWidth(60);
        pGrid.getColumnModel().getColumn(7).setWidth(60);
        pGrid.getColumnModel().getColumn(8).setMinWidth(122);
        pGrid.getColumnModel().getColumn(8).setMaxWidth(122);
        pGrid.getColumnModel().getColumn(8).setWidth(122);
        pGrid.getColumnModel().getColumn(9).setMinWidth(240);
        pGrid.getColumnModel().getColumn(9).setMaxWidth(240);
        pGrid.getColumnModel().getColumn(9).setWidth(240);
        pGrid.getColumnModel().getColumn(10).setMinWidth(0);
        pGrid.getColumnModel().getColumn(10).setMaxWidth(0);
        pGrid.getColumnModel().getColumn(10).setWidth(0);
        pGrid.getColumnModel().getColumn(11).setMinWidth(40);
        pGrid.getColumnModel().getColumn(11).setMaxWidth(40);
        pGrid.getColumnModel().getColumn(11).setWidth(40);
        pGrid.getColumnModel().getColumn(12).setMinWidth(100);
        pGrid.getColumnModel().getColumn(12).setMaxWidth(100);
        pGrid.getColumnModel().getColumn(12).setWidth(100);
        pGrid.getColumnModel().getColumn(13).setMinWidth(38);
        pGrid.getColumnModel().getColumn(13).setMaxWidth(38);
        pGrid.getColumnModel().getColumn(13).setWidth(38);
        pGrid.getColumnModel().getColumn(14).setMinWidth(0);
        pGrid.getColumnModel().getColumn(14).setMaxWidth(0);
        pGrid.getColumnModel().getColumn(14).setWidth(0);
        pGrid.getColumnModel().getColumn(15).setMinWidth(0);
        pGrid.getColumnModel().getColumn(15).setMaxWidth(0);
        pGrid.getColumnModel().getColumn(15).setWidth(0);
    }

    public static void setGridModelCounterECF(SbDataGridView pGrid) {
        pGrid.getColumnModel().getColumn(0).setMinWidth(0);
        pGrid.getColumnModel().getColumn(0).setMaxWidth(0);
        pGrid.getColumnModel().getColumn(0).setWidth(0);
        pGrid.getColumnModel().getColumn(1).setMinWidth(50);
        pGrid.getColumnModel().getColumn(1).setMaxWidth(50);
        pGrid.getColumnModel().getColumn(1).setWidth(50);
        pGrid.getColumnModel().getColumn(2).setMinWidth(230);
        pGrid.getColumnModel().getColumn(2).setMaxWidth(230);
        pGrid.getColumnModel().getColumn(2).setWidth(230);
        pGrid.getColumnModel().getColumn(3).setMinWidth(80);
        pGrid.getColumnModel().getColumn(3).setMaxWidth(80);
        pGrid.getColumnModel().getColumn(3).setWidth(80);
        pGrid.getColumnModel().getColumn(4).setMinWidth(0);
        pGrid.getColumnModel().getColumn(4).setMaxWidth(0);
        pGrid.getColumnModel().getColumn(4).setWidth(0);
        pGrid.getColumnModel().getColumn(5).setMinWidth(0);
        pGrid.getColumnModel().getColumn(5).setMaxWidth(0);
        pGrid.getColumnModel().getColumn(5).setWidth(0);
    }

    public static void setGridModelCertificate(SbDataGridView pGrid) {
        pGrid.getColumnModel().getColumn(0).setMinWidth(35);
        pGrid.getColumnModel().getColumn(0).setMaxWidth(35);
        pGrid.getColumnModel().getColumn(0).setWidth(35);
        pGrid.getColumnModel().getColumn(1).setMinWidth(85);
        pGrid.getColumnModel().getColumn(1).setMaxWidth(85);
        pGrid.getColumnModel().getColumn(1).setWidth(85);
        pGrid.getColumnModel().getColumn(2).setMinWidth(85);
        pGrid.getColumnModel().getColumn(2).setMaxWidth(85);
        pGrid.getColumnModel().getColumn(2).setWidth(85);
        pGrid.getColumnModel().getColumn(3).setMinWidth(70);
        pGrid.getColumnModel().getColumn(3).setMaxWidth(70);
        pGrid.getColumnModel().getColumn(3).setWidth(70);
    }

    public static void setGridModelToken(SbDataGridView pGrid) {
        pGrid.getColumnModel().getColumn(0).setMinWidth(35);
        pGrid.getColumnModel().getColumn(0).setMaxWidth(35);
        pGrid.getColumnModel().getColumn(0).setWidth(35);
        pGrid.getColumnModel().getColumn(1).setMinWidth(380);
        pGrid.getColumnModel().getColumn(1).setMaxWidth(380);
        pGrid.getColumnModel().getColumn(1).setWidth(380);
        pGrid.getColumnModel().getColumn(2).setMinWidth(85);
        pGrid.getColumnModel().getColumn(2).setMaxWidth(85);
        pGrid.getColumnModel().getColumn(2).setWidth(85);
        pGrid.getColumnModel().getColumn(3).setMinWidth(85);
        pGrid.getColumnModel().getColumn(3).setMaxWidth(85);
        pGrid.getColumnModel().getColumn(3).setWidth(85);
        pGrid.getColumnModel().getColumn(4).setMinWidth(70);
        pGrid.getColumnModel().getColumn(4).setMaxWidth(70);
        pGrid.getColumnModel().getColumn(4).setWidth(70);
    }
}

