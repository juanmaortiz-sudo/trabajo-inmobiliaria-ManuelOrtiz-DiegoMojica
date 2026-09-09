<%@ page import="java.sql.Connection"%>
<%@ page import="java.sql.PreparedStatement"%>
<%@ page import="java.sql.ResultSet"%>
<%@ page import="java.sql.DriverManager"%>
<%@ page import="java.sql.SQLException"%>
<%@ page import="java.io.File"%>
<%@ page import="java.io.InputStream"%>
<%@ page import="java.io.FileOutputStream"%>
<%@ page import="java.io.OutputStream"%>
<%@ page import="java.io.ByteArrayOutputStream"%>
<%@ page import="java.nio.charset.StandardCharsets"%>
<%@ include file="conexion.jspf" %>
<%@ include file="auth.jspf" %>

<%
// Guardia: requiere autenticación
if (!autenticado) {
    response.sendRedirect(request.getContextPath() + "/login.jsp");
    return;
}

String actualDocumento = "";
String actualNombres = "";
String actualApellidos = "";
String actualTelefono = "";
String actualFoto = "";

if (conexion != null) {
    PreparedStatement psExistente = null;
    ResultSet rsExistente = null;
    try {
        psExistente = conexion.prepareStatement("SELECT nombres, apellidos, documento, telefono, foto_url FROM perfil WHERE id_usuario = ?");
        psExistente.setInt(1, idUsuario);
        rsExistente = psExistente.executeQuery();
        if (rsExistente.next()) {
            actualNombres = rsExistente.getString("nombres");
            actualApellidos = rsExistente.getString("apellidos");
            actualDocumento = rsExistente.getString("documento");
            actualTelefono = rsExistente.getString("telefono");
            actualFoto = rsExistente.getString("foto_url");
        }
    } catch (Exception e) {
    } finally {
        if (rsExistente != null) { try { rsExistente.close(); } catch (SQLException e) { } }
        if (psExistente != null) { try { psExistente.close(); } catch (SQLException e) { } }
    }
}

String urlFoto = actualFoto; // mantener foto actual si no se sube nueva

if ("POST".equalsIgnoreCase(request.getMethod())) {
    String documento = "";
    String nombres = "";
    String apellidos = "";
    String telefono = "";

    PreparedStatement sentencia = null;

    try {
        String contentType = request.getContentType();
        String boundary = null;
        if (contentType != null && contentType.toLowerCase().startsWith("multipart/")) {
            int idxBoundary = contentType.indexOf("boundary=");
            if (idxBoundary >= 0) {
                boundary = contentType.substring(idxBoundary + "boundary=".length()).trim();
                if (boundary.startsWith("\"") && boundary.endsWith("\"")) {
                    boundary = boundary.substring(1, boundary.length() - 1);
                }
            }
        }

        if (boundary == null) {
            out.println("<div class='container'><div class='alert alert-danger'>Formulario no es multipart.</div></div>");
        } else {
            byte[] cuerpo = leerCuerpo(request.getInputStream());
            byte[] delim = ("--" + boundary).getBytes(StandardCharsets.ISO_8859_1);

            java.util.List<byte[]> partes = separarPartes(cuerpo, delim);
            for (byte[] parte : partes) {
                byte[] nombreCampoBytes = null;
                String nombreArchivoOriginal = null;

                int finCabeceras = findIndex(parte, "\r\n\r\n".getBytes(StandardCharsets.ISO_8859_1));
                if (finCabeceras < 0) continue;

                String cabeceras = new String(parte, 0, finCabeceras, StandardCharsets.ISO_8859_1);

                int idxName = cabeceras.indexOf("name=\"");
                if (idxName >= 0) {
                    int inicio = idxName + "name=\"".length();
                    int fin = cabeceras.indexOf("\"", inicio);
                    if (fin >= 0) {
                        nombreCampoBytes = cabeceras.substring(inicio, fin).getBytes(StandardCharsets.ISO_8859_1);
                    }
                }
                if (nombreCampoBytes == null) continue;
                String nombreCampo = new String(nombreCampoBytes, StandardCharsets.UTF_8);

                int idxFilename = cabeceras.toLowerCase().indexOf("filename=\"");
                if (idxFilename >= 0) {
                    int inicio = cabeceras.indexOf("\"", idxFilename) + 1;
                    int fin = cabeceras.indexOf("\"", inicio);
                    if (fin >= 0) {
                        nombreArchivoOriginal = cabeceras.substring(inicio, fin);
                    }
                }

                int inicioContenido = finCabeceras + 4;
                int finContenido = parte.length;
                if (finContenido - inicioContenido >= 2
                        && parte[finContenido - 2] == '\r' && parte[finContenido - 1] == '\n') {
                    finContenido -= 2;
                }
                byte[] contenido = new byte[finContenido - inicioContenido];
                System.arraycopy(parte, inicioContenido, contenido, 0, contenido.length);

                if ("foto".equals(nombreCampo)) {
                    if (nombreArchivoOriginal != null && contenido.length > 0) {
                        int idx = nombreArchivoOriginal.lastIndexOf(".");
                        String ext = (idx >= 0) ? nombreArchivoOriginal.substring(idx) : "";
                        String nombreArchivo = "foto_" + idUsuario + "_" + System.currentTimeMillis() + ext;

                        String directorio = application.getRealPath("/uploads");
                        File carpeta = new File(directorio);
                        if (!carpeta.exists()) {
                            carpeta.mkdirs();
                        }

                        try (OutputStream salida = new FileOutputStream(new File(carpeta, nombreArchivo))) {
                            salida.write(contenido);
                        }

                        urlFoto = "uploads/" + nombreArchivo;
                    }
                } else {
                    String valor = new String(contenido, StandardCharsets.UTF_8);
                    if ("documento".equals(nombreCampo)) { documento = valor; }
                    else if ("nombres".equals(nombreCampo)) { nombres = valor; }
                    else if ("apellidos".equals(nombreCampo)) { apellidos = valor; }
                    else if ("telefono".equals(nombreCampo)) { telefono = valor; }
                }
            }

            String consulta = "INSERT INTO perfil (id_usuario, nombres, apellidos, documento, telefono, foto_url) VALUES (?, ?, ?, ?, ?, ?) "
                            + "ON DUPLICATE KEY UPDATE nombres = ?, apellidos = ?, documento = ?, telefono = ?, foto_url = ?";
            sentencia = conexion.prepareStatement(consulta);
            sentencia.setInt(1, idUsuario);
            sentencia.setString(2, nombres);
            sentencia.setString(3, apellidos);
            sentencia.setString(4, documento);
            sentencia.setString(5, telefono);
            sentencia.setString(6, urlFoto);
            sentencia.setString(7, nombres);
            sentencia.setString(8, apellidos);
            sentencia.setString(9, documento);
            sentencia.setString(10, telefono);
            sentencia.setString(11, urlFoto);
            sentencia.executeUpdate();

            response.sendRedirect(request.getContextPath() + "/index.jsp");
            return;

        } catch (SQLException e) {
            out.println("<div class='container'><div class='alert alert-danger'>Error SQL: " + e.getMessage() + "</div></div>");
        } catch (Exception e) {
            out.println("<div class='container'><div class='alert alert-danger'>Error: " + e.getMessage() + "</div></div>");
        } finally {
            if (sentencia != null) {
                try { sentencia.close(); } catch (SQLException e) { }
            }
        }
    }
}
%>

<!DOCTYPE html>
<html lang="es">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.6.0/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
    <link rel="stylesheet" href="assets/css/style.css">
    <title>Completar Registro</title>
</head>

<body>

<!-- Navbar unificado -->
<%@ include file="navbar.jspf" %>

<div class="container">
    <div class="jumbotron">
        <h1>Completar Registro</h1>
        <p>Complete los datos de su perfil para terminar el registro.</p>
    </div>
    <form action="<%= request.getContextPath() %>/completar_registro.jsp" method="post" enctype="multipart/form-data">
        <div class="form-group">
            <div class="form-group">
<%          if (actualFoto != null && !actualFoto.isEmpty()) { %>
                <div class="mb-3">
                    <p><label>Foto actual:</label></p>
                    <img src="<%= request.getContextPath() %>/<%= actualFoto %>" alt="Foto actual" class="img-fluid rounded-circle" style="max-width: 120px;" />
                </div>
<%          } %>
                <p><label>Documento:</label></p>
                <input type="text" class="form-control" id="documento" name="documento" value="<%= actualDocumento %>" required />
                <br>
                <p><label>Nombre:</label></p>
                <input type="text" class="form-control" id="nombres" name="nombres" value="<%= actualNombres %>" required />
                <br>
                <p><label>Apellido:</label></p>
                <input type="text" class="form-control" id="apellidos" name="apellidos" value="<%= actualApellidos %>" required />
                <br>
                <p><label>Teléfono:</label></p>
                <input type="text" class="form-control" id="telefono" name="telefono" value="<%= actualTelefono %>" required />
                <br>
                <p><label>Foto:</label></p>
                <input type="file" class="form-control-file" id="foto" name="foto" accept="image/*" />
                <br>
                <input type="submit" class="btn btn-primary" value="Guardar" />
            </div>
        </form>
    </div>

    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.5.1/jquery.slim.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.16.1/umd/popper.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.6.0/js/bootstrap.min.js"></script>
<%
    if (conexion != null) {
        try { conexion.close(); } catch (SQLException e) { }
    }
%>
</body>

</html>

<%!
    private byte[] leerCuerpo(InputStream entrada) throws Exception {
        ByteArrayOutputStream acumulador = new ByteArrayOutputStream();
        byte[] buffer = new byte[8192];
        int leidos;
        while ((leidos = entrada.read(buffer)) != -1) {
            acumulador.write(buffer, 0, leidos);
        }
        return acumulador.toByteArray();
    }

    private java.util.List<byte[]> separarPartes(byte[] cuerpo, byte[] delim) {
        java.util.List<byte[]> resultado = new java.util.ArrayList<byte[]>();
        int inicio = 0;
        while (true) {
            int pos = findIndex(cuerpo, delim, inicio);
            if (pos < 0) break;
            int inicioContenido = pos + delim.length;
            if (inicioContenido < cuerpo.length && cuerpo[inicioContenido] == '-' && cuerpo[inicioContenido + 1] == '-') {
                break;
            }
            if (inicioContenido < cuerpo.length && (cuerpo[inicioContenido] == '\r' || cuerpo[inicioContenido] == '\n')) {
                int crlf = 0;
                if (cuerpo[inicioContenido] == '\r' && inicioContenido + 1 < cuerpo.length && cuerpo[inicioContenido + 1] == '\n') {
                    crlf = 2;
                } else {
                    crlf = 1;
                }
                int siguienteDelim = findIndex(cuerpo, delim, inicioContenido + crlf);
                if (siguienteDelim < 0) break;
                int finParte = siguienteDelim;
                if (finParte > inicioContenido + crlf && cuerpo[finParte - 1] == '\n') finParte--;
                if (finParte > inicioContenido + crlf && cuerpo[finParte - 1] == '\r') finParte--;
                byte[] parte = new byte[finParte - (inicioContenido + crlf)];
                System.arraycopy(cuerpo, inicioContenido + crlf, parte, 0, parte.length);
                resultado.add(parte);
                inicio = finParte;
            } else {
                inicio = inicioContenido;
            }
        }
        return resultado;
    }

    private int findIndex(byte[] datos, byte[] patron) {
        return findIndex(datos, patron, 0);
    }

    private int findIndex(byte[] datos, byte[] patron, int desde) {
        if (patron.length == 0) return -1;
        for (int i = desde; i <= datos.length - patron.length; i++) {
            boolean coincide = true;
            for (int j = 0; j < patron.length; j++) {
                if (datos[i + j] != patron[j]) {
                    coincide = false;
                    break;
                }
            }
            if (coincide) return i;
        }
        return -1;
    }
%>