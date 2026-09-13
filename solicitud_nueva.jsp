<%@ page import="java.sql.Connection"%>
<%@ page import="java.sql.PreparedStatement"%>
<%@ page import="java.sql.ResultSet"%>
<%@ page import="java.sql.SQLException"%>
<%@ page import="java.sql.Statement"%>
<%@ page import="java.io.File"%>
<%@ page import="java.io.InputStream"%>
<%@ page import="java.io.FileOutputStream"%>
<%@ page import="java.io.OutputStream"%>
<%@ page import="java.io.ByteArrayOutputStream"%>
<%@ page import="java.nio.charset.StandardCharsets"%>
<!DOCTYPE html>
<html lang="es">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.6.0/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
    <link rel="stylesheet" href="assets/css/style.css">
    <title>Radicar Solicitud</title>
</head>

<body>

<%@ include file="conexion.jspf" %>
<%@ include file="funciones.jspf" %>

<%
    Integer idUsuarioSesion = (Integer) session.getAttribute("id_usuario");
    String rolSesion = (String) session.getAttribute("rol");

    if (idUsuarioSesion == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    String idParam = request.getParameter("id");
    if (idParam == null) idParam = "0";
    int idPropiedad = 0;
    try { idPropiedad = Integer.parseInt(idParam); } catch (NumberFormatException e) { idPropiedad = 0; }

    String tituloPropiedad = "";
    String tipoOfertaPropiedad = "";
    String precioPropiedad = "";

    if (conexion != null && idPropiedad > 0) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conexion.prepareStatement("SELECT titulo, tipo_oferta, precio FROM propiedad WHERE id_propiedad = ? AND baja_logica = 0");
            ps.setInt(1, idPropiedad);
            rs = ps.executeQuery();
            if (rs.next()) {
                tituloPropiedad = rs.getString("titulo");
                tipoOfertaPropiedad = rs.getString("tipo_oferta");
                precioPropiedad = rs.getString("precio");
            } else {
                response.sendRedirect("propiedades.jsp");
                return;
            }
        } catch (Exception e) { } finally {
            if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
            if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
        }
    }

    String mensajeError = null;
    String mensajeExito = null;

    if ("POST".equalsIgnoreCase(request.getMethod()) && idPropiedad > 0) {
        String tipoSolicitud = "";
        String idPropiedadForm = "";
        java.util.List<String[]> documentos = new java.util.ArrayList<>();
        java.util.Map<String, String> nombresDocs = new java.util.HashMap<>();

        PreparedStatement sentenciaSolicitud = null;
        PreparedStatement sentenciaDocumento = null;
        ResultSet claves = null;

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
                mensajeError = "Formulario no es multipart.";
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

                    if (nombreCampo.startsWith("archivo_doc_")) {
                        String nro = nombreCampo.substring("archivo_doc_".length());
                        if (nombreArchivoOriginal != null && contenido.length > 0) {
                            String nombreDoc = nombresDocs.get(nro);
                            if (nombreDoc != null) {
                                int idx = nombreArchivoOriginal.lastIndexOf(".");
                                String ext = (idx >= 0) ? nombreArchivoOriginal.substring(idx) : "";
                                String nombreArchivo = "doc_solic_" + idPropiedad + "_" + System.currentTimeMillis() + "_" + nro + ext;

                                String directorio = application.getRealPath("/uploads");
                                File carpeta = new File(directorio);
                                if (!carpeta.exists()) {
                                    carpeta.mkdirs();
                                }

                                try (OutputStream salida = new FileOutputStream(new File(carpeta, nombreArchivo))) {
                                    salida.write(contenido);
                                }

                                documentos.add(new String[] { nombreDoc, "uploads/" + nombreArchivo });
                            }
                        }
                    } else {
                        String valor = new String(contenido, StandardCharsets.UTF_8);
                        if ("id_propiedad".equals(nombreCampo)) { idPropiedadForm = valor; }
                        else if ("tipo_solicitud".equals(nombreCampo)) { tipoSolicitud = valor; }
                        else if (nombreCampo.startsWith("nombre_doc_")) {
                            String nro = nombreCampo.substring("nombre_doc_".length());
                            if (!valor.trim().isEmpty()) {
                                nombresDocs.put(nro, valor.trim());
                            }
                        }
                    }
                }

                if (tipoSolicitud.isEmpty()) {
                    mensajeError = "Debe seleccionar el tipo de solicitud (compra o arriendo).";
                } else if (documentos.isEmpty()) {
                    mensajeError = "Debe adjuntar al menos un documento con su nombre.";
                } else {
                    conexion.setAutoCommit(false);

                    String sqlSolicitud = "INSERT INTO solicitud (id_propiedad, id_cliente, tipo_solicitud, estado) VALUES (?, ?, ?, 'EN_REVISION')";
                    sentenciaSolicitud = conexion.prepareStatement(sqlSolicitud, Statement.RETURN_GENERATED_KEYS);
                    sentenciaSolicitud.setInt(1, idPropiedad);
                    sentenciaSolicitud.setInt(2, idUsuarioSesion);
                    sentenciaSolicitud.setString(3, tipoSolicitud);
                    sentenciaSolicitud.executeUpdate();

                    claves = sentenciaSolicitud.getGeneratedKeys();
                    int idSolicitud = 0;
                    if (claves.next()) {
                        idSolicitud = claves.getInt(1);
                    }

                    String sqlDoc = "INSERT INTO documento_solicitud (id_solicitud, nombre_documento, url_archivo) VALUES (?, ?, ?)";
                    sentenciaDocumento = conexion.prepareStatement(sqlDoc);
                    for (String[] doc : documentos) {
                        sentenciaDocumento.setInt(1, idSolicitud);
                        sentenciaDocumento.setString(2, doc[0]);
                        sentenciaDocumento.setString(3, doc[1]);
                        sentenciaDocumento.addBatch();
                    }
                    sentenciaDocumento.executeBatch();

                    registrarAuditoria(conexion, idUsuarioSesion, "CREA_SOLICITUD", "solicitud",
                            "id_propiedad=" + idPropiedad + ", tipo=" + tipoSolicitud + ", documentos=" + documentos.size());

                    conexion.commit();
                    mensajeExito = "Solicitud radicada correctamente. Está en revisión.";
                }
            }
        } catch (SQLException e) {
            mensajeError = "Error SQL: " + e.getMessage();
            try { if (conexion != null) conexion.rollback(); } catch (SQLException ex) { }
        } catch (Exception e) {
            mensajeError = "Error: " + e.getMessage();
            try { if (conexion != null) conexion.rollback(); } catch (SQLException ex) { }
        } finally {
            if (claves != null) { try { claves.close(); } catch (SQLException e) { } }
            if (sentenciaDocumento != null) { try { sentenciaDocumento.close(); } catch (SQLException e) { } }
            if (sentenciaSolicitud != null) { try { sentenciaSolicitud.close(); } catch (SQLException e) { } }
            if (conexion != null) { try { conexion.setAutoCommit(true); } catch (SQLException e) { } }
        }
    }

    request.setAttribute("seccionActiva", "solicitudes");
%>
<%@ include file="navbar.jspf" %>

    <div class="container mt-4">
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h2><i class="fas fa-file-alt"></i> Radicar Solicitud</h2>
            <a href="propiedad_ver.jsp?id=<%= idPropiedad %>" class="btn btn-secondary">Volver a la propiedad</a>
        </div>

        <% if (mensajeError != null) { %>
        <div class="alert alert-danger"><%= mensajeError %></div>
        <% } %>
        <% if (mensajeExito != null) { %>
        <div class="alert alert-success">
            <%= mensajeExito %>
            <div class="mt-2">
                <a href="solicitudes.jsp" class="btn btn-primary btn-sm">Ver mis solicitudes</a>
                <a href="propiedades.jsp" class="btn btn-outline-secondary btn-sm">Buscar otra propiedad</a>
            </div>
        </div>
        <% } else { %>

        <div class="card mb-4">
            <div class="card-header bg-success text-white">
                <h5 class="mb-0">Propiedad</h5>
            </div>
            <div class="card-body">
                <div class="d-flex justify-content-between align-items-center">
                    <div>
                        <h5 class="mb-1"><%= tituloPropiedad %></h5>
                        <span class="text-muted">Oferta: <%= tipoOfertaPropiedad %></span>
                    </div>
                    <div class="h4 text-success font-weight-bold">$<%= precioPropiedad %></div>
                </div>
            </div>
        </div>

        <div class="card">
            <div class="card-header">
                <h5 class="mb-0">Datos de la solicitud</h5>
            </div>
            <div class="card-body">
                <form method="post" action="solicitud_nueva.jsp?id=<%= idPropiedad %>" enctype="multipart/form-data">
                    <input type="hidden" name="id_propiedad" value="<%= idPropiedad %>">
                    <div class="row">
                        <div class="col-md-6 mb-3">
                            <label>Tipo de solicitud *</label>
                            <select class="form-control" name="tipo_solicitud" required>
                                <option value="COMPRA" <%= "VENTA".equals(tipoOfertaPropiedad) ? "selected" : "" %>>Compra</option>
                                <option value="ARRIENDO" <%= "ARRIENDO".equals(tipoOfertaPropiedad) ? "selected" : "" %>>Arriendo</option>
                            </select>
                        </div>
                    </div>

                    <hr>
                    <h5>Documentos de soporte <small class="text-muted">(mínimo 1)</small></h5>
<%
    for (int i = 0; i < 4; i++) {
%>
                    <div class="row mb-3">
                        <div class="col-md-4">
                            <label>Nombre del documento (slot <%= i + 1 %>)</label>
                            <input type="text" class="form-control" name="nombre_doc_<%= i %>" placeholder="Ej: Cédula, Certificado laboral">
                        </div>
                        <div class="col-md-6">
                            <label>Archivo</label>
                            <input type="file" class="form-control-file" name="archivo_doc_<%= i %>" accept=".pdf,.jpg,.jpeg,.png,.txt">
                        </div>
                    </div>
<%
    }
%>
                    <button type="submit" class="btn btn-success btn-lg">
                        <i class="fas fa-paper-plane"></i> Radicar solicitud
                    </button>
                </form>
            </div>
        </div>
        <% } %>
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