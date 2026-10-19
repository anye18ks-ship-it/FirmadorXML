/*
 * Decompiled with CFR 0.152.
 * 
 * Could not load the following classes:
 *  org.json.JSONObject
 */
package xmlsentry;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.DataOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import org.json.JSONObject;

class getXmlRequest {
    getXmlRequest() {
    }

    public static String getXmlFromApi(String pUrlApi) throws Exception {
        URL url = new URL(pUrlApi);
        HttpURLConnection connection = (HttpURLConnection)url.openConnection();
        connection.setRequestMethod("GET");
        int responseCode = connection.getResponseCode();
        if (responseCode == 200) {
            String inputLine;
            BufferedReader in = new BufferedReader(new InputStreamReader(connection.getInputStream()));
            StringBuilder response = new StringBuilder();
            while ((inputLine = in.readLine()) != null) {
                response.append(inputLine);
            }
            in.close();
            return response.toString();
        }
        throw new RuntimeException("Failed: HTTP error code: " + responseCode);
    }

    public static String getXmlTokenFromApi(String pUrlApi, String xmlContent) throws Exception {
        URL url = new URL(pUrlApi);
        HttpURLConnection connection = (HttpURLConnection)url.openConnection();
        try {
            connection.setRequestMethod("POST");
            connection.setRequestProperty("Accept", "application/xml");
            connection.setRequestProperty("Cache-Control", "no-cache");
            connection.setRequestProperty("Connection", "keep-alive");
            connection.setDoOutput(true);
            connection.setDoInput(true);
            String boundary = "----WebKitFormBoundary" + Long.toHexString(System.currentTimeMillis());
            connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=" + boundary);
            try (DataOutputStream outputStream = new DataOutputStream(connection.getOutputStream());){
                outputStream.writeBytes("--" + boundary + "\r\n");
                outputStream.writeBytes("Content-Disposition: form-data; name=\"xml\"; filename=\"Sem.xml\"\r\n");
                outputStream.writeBytes("Content-Type: application/xml\r\n\r\n");
                outputStream.write(xmlContent.getBytes("UTF-8"));
                outputStream.writeBytes("\r\n");
                outputStream.writeBytes("--" + boundary + "--\r\n");
                outputStream.flush();
            }
            int responseCode = connection.getResponseCode();
            if (responseCode == 200) {
                StringBuilder response = new StringBuilder();
                try (Object reader = new BufferedReader(new InputStreamReader(connection.getInputStream(), "UTF-8"));){
                    String line;
                    while ((line = ((BufferedReader)reader).readLine()) != null) {
                        response.append(line);
                    }
                }
                reader = response.toString();
                return reader;
            }
            StringBuilder errorResponse = new StringBuilder();
            try (BufferedReader errorReader = new BufferedReader(new InputStreamReader(connection.getErrorStream(), "UTF-8"));){
                String line;
                while ((line = errorReader.readLine()) != null) {
                    errorResponse.append(line);
                }
            }
            throw new Exception("HTTP error code: " + responseCode + ", Response: " + errorResponse.toString());
        }
        finally {
            connection.disconnect();
        }
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public static String sendXmlECF(String pUrlApi, String xmlContent, String bearerToken, String pFileName) {
        HttpURLConnection connection = null;
        String vDefaultResponse = "<?xml version = '1.0' encoding = 'UTF-8'?>\n<RespuestaRecepcion xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">\n   <TrackId>00000000-0000-0000-0000-000000000000</TrackId>\n</RespuestaRecepcion>";
        try {
            URL url = new URL(pUrlApi);
            connection = (HttpURLConnection)url.openConnection();
            connection.setRequestMethod("POST");
            connection.setRequestProperty("Accept", "application/xml");
            connection.setRequestProperty("Cache-Control", "no-cache");
            connection.setRequestProperty("Connection", "keep-alive");
            connection.setRequestProperty("Authorization", "Bearer " + bearerToken);
            connection.setDoOutput(true);
            connection.setDoInput(true);
            String boundary = "----WebKitFormBoundary" + Long.toHexString(System.currentTimeMillis());
            connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=" + boundary);
            try (DataOutputStream outputStream = new DataOutputStream(connection.getOutputStream());){
                outputStream.writeBytes("--" + boundary + "\r\n");
                outputStream.writeBytes("Content-Disposition: form-data; name=\"xml\"; filename=\"" + pFileName + ".xml\"\r\n");
                outputStream.writeBytes("Content-Type: application/xml\r\n\r\n");
                outputStream.write(xmlContent.getBytes("UTF-8"));
                outputStream.writeBytes("\r\n");
                outputStream.writeBytes("--" + boundary + "--\r\n");
                outputStream.flush();
            }
            int responseCode = connection.getResponseCode();
            if (responseCode == 200) {
                StringBuilder response = new StringBuilder();
                try (Object reader = new BufferedReader(new InputStreamReader(connection.getInputStream(), "UTF-8"));){
                    String line;
                    while ((line = ((BufferedReader)reader).readLine()) != null) {
                        response.append(line);
                    }
                }
                reader = response.toString();
                return reader;
            }
            StringBuilder errorResponse = new StringBuilder();
            try (BufferedReader errorReader = new BufferedReader(new InputStreamReader(connection.getErrorStream(), "UTF-8"));){
                String line;
                while ((line = errorReader.readLine()) != null) {
                    errorResponse.append(line);
                }
            }
            String string = errorResponse.toString();
            return string;
        }
        catch (Exception e) {
            String string = vDefaultResponse;
            return string;
        }
        finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    public static void writeToFile(String fileName, String content) {
        try (BufferedWriter writer = new BufferedWriter(new FileWriter(fileName));){
            writer.write(content);
        }
        catch (IOException e) {
            e.printStackTrace();
        }
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public static String getStatusECF(String pUrlApi, String bearerToken, String trackId) throws Exception {
        String vDefaultResponse = "<?xml version = '1.0' encoding = 'UTF-8'?>\n<RespuestaConsultaTrackId xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">\n    <TrackId>00000000-0000-0000-0000-000000000000</TrackId>\n    <Codigo>-99</Codigo>\n    <Estado>WebServiceError</Estado>\n    <Rnc>000000000</Rnc>\n    <Encf>E000000000000</Encf>\n    <SecuenciaUtilizada>false</SecuenciaUtilizada>\n    <FechaRecepcion>0/00/0000 00:00:00 PM</FechaRecepcion>\n     <Mensajes>\n        <Mensaje>\n            <Valor/>\n            <Codigo>0</Codigo>\n        </Mensaje>\n    </Mensajes>\n</RespuestaConsultaTrackId>";
        String vPageNotFoundResponse = "<?xml version = '1.0' encoding = 'UTF-8'?>\n<RespuestaConsultaTrackId xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">\n    <TrackId>00000000-0000-0000-0000-000000000000</TrackId>\n    <Codigo>-99</Codigo>\n    <Estado>WebServiceError</Estado>\n    <Rnc>000000000</Rnc>\n    <Encf>E000000000000</Encf>\n    <SecuenciaUtilizada>false</SecuenciaUtilizada>\n    <FechaRecepcion>0/00/0000 00:00:00 PM</FechaRecepcion>\n     <Mensajes>\n        <Mensaje>\n            <Valor/>\n            <Codigo>0</Codigo>\n        </Mensaje>\n    </Mensajes>\n</RespuestaConsultaTrackId>";
        String fullUrl = pUrlApi + trackId;
        URL url = new URL(fullUrl);
        HttpURLConnection connection = (HttpURLConnection)url.openConnection();
        try {
            connection.setRequestMethod("GET");
            connection.setRequestProperty("Accept", "application/xml");
            connection.setRequestProperty("Authorization", "Bearer " + bearerToken);
            connection.setDoInput(true);
            int responseCode = connection.getResponseCode();
            if (responseCode == 200) {
                StringBuilder response = new StringBuilder();
                try (Object reader = new BufferedReader(new InputStreamReader(connection.getInputStream(), "UTF-8"));){
                    String line;
                    while ((line = ((BufferedReader)reader).readLine()) != null) {
                        response.append(line);
                    }
                }
                if (response.toString().equalsIgnoreCase("{\"codigo\":5000002,\"estado\":\"No encontrado.\"}")) {
                    reader = vDefaultResponse;
                    return reader;
                }
                reader = response.toString();
                return reader;
            }
            StringBuilder errorResponse = new StringBuilder();
            try (BufferedReader errorReader = new BufferedReader(new InputStreamReader(connection.getErrorStream(), "UTF-8"));){
                String line;
                while ((line = errorReader.readLine()) != null) {
                    errorResponse.append(line);
                }
            }
            String string = vDefaultResponse;
            return string;
        }
        catch (Exception e) {
            String string = vDefaultResponse;
            return string;
        }
        finally {
            connection.disconnect();
        }
    }

    /*
     * WARNING - Removed try catching itself - possible behaviour change.
     */
    public static String getStatusRFCE(String pUrlApi, String bearerToken) {
        String vDefaultResponse = "<?xml version = '1.0' encoding = 'UTF-8'?><Respuesta xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><Codigo>-99</Codigo><Estado>WebServiceError</Estado><Encf>E000000000000</Encf><SecuenciaUtilizada>false</SecuenciaUtilizada></Respuesta>";
        String vPageNotFoundResponse = "<?xml version = '1.0' encoding = 'UTF-8'?><Respuesta xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><Codigo>-98</Codigo><Estado>Page Not Found</Estado><Encf>E000000000000</Encf><SecuenciaUtilizada>false</SecuenciaUtilizada></Respuesta>";
        String vErr404 = "<html><head><title>MY NS HOME PAGE</title></head><body>404 Not Found.The Page that you have requested could not be found.</body></html>";
        HttpURLConnection connection = null;
        try {
            String fullUrl = pUrlApi;
            URL url = new URL(fullUrl);
            connection = (HttpURLConnection)url.openConnection();
            connection.setRequestMethod("GET");
            connection.setRequestProperty("Accept", "application/xml");
            connection.setRequestProperty("Authorization", "Bearer " + bearerToken);
            connection.setDoInput(true);
            int responseCode = connection.getResponseCode();
            if (responseCode == 200) {
                StringBuilder response = new StringBuilder();
                try (Object reader = new BufferedReader(new InputStreamReader(connection.getInputStream(), "UTF-8"));){
                    String line;
                    while ((line = ((BufferedReader)reader).readLine()) != null) {
                        response.append(line);
                    }
                }
                if (response.toString().equals(vErr404)) {
                    reader = vPageNotFoundResponse;
                    return reader;
                }
                reader = response.toString();
                return reader;
            }
            StringBuilder errorResponse = new StringBuilder();
            try (BufferedReader errorReader = new BufferedReader(new InputStreamReader(connection.getErrorStream(), "UTF-8"));){
                String line;
                while ((line = errorReader.readLine()) != null) {
                    errorResponse.append(line);
                }
            }
            String string = vDefaultResponse;
            return string;
        }
        catch (Exception e) {
            String string = vDefaultResponse;
            return string;
        }
        finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    public static String extractTrackId(String jsonResponse) {
        JSONObject jsonObject = new JSONObject(jsonResponse);
        return jsonObject.getString("trackId");
    }
}

