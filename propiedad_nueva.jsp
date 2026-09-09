<%@ page import="java.sql.Connection"%>
<%@ page import="java.sql.PreparedStatement"%>
<%@ page import="java.sql.ResultSet"%>
<%@ page import="java.sql.DriverManager"%>
<%@ page import="java.sql.SQLException"%>
<%@ page import="java.sql.Statement"%>
<%@ page import="java.io.File"%>
<%@ page import="java.io.InputStream"%>
<%@ page import="java.io.FileOutputStream"%>
<%@ page import="java.io.OutputStream"%>
<%@ page import="java.io.ByteArrayOutputStream"%>
<%@ page import="java.nio.charset.StandardCharsets"%>
<%@ include file="conexion.jspf" %>
<%@ include file="auth.jspf" %>

<%
// Guardia: solo Inmobiliaria y Admin pueden crear propiedades
if (!autenticado || (!esInmob && !esAdmin)) {
    response.sendRedirect(request.getContextPath() + "/index.jsp");
    return;
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
    <title>Nueva Propiedad</title>
</head>

<body>

<!-- Navbar unificado -->
<%@ include file="navbar.jspf" %>

<%
    String mensajeExito = null;
    String mensajeError = null;

    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String matricula = "";
        String titulo = "";
        String descripcion = "";
        String precio = "";
        String tipoOferta = "";
        String estadoPublicacion = "DISPONIBLE";
        String direccion = "";
        String idCiudad = "";
        String idTipoPropiedad = "";
        String idInmobiliaria = "";
        java.util.List<String> imagenes = new java.util.ArrayList<>();
        java.util.Map<Integer, String> caracteristicas = new java.util.HashMap<>();

        PreparedStatement sentenciaPropiedad = null;
        PreparedStatement sentenciaImagen = null;
        PreparedStatement sentenciaCarac = null;
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

                    if (nombreCampo.startsWith("imagen_")) {
                        if (nombreArchivoOriginal != null && contenido.length > 0) {
                            int idx = nombreArchivoOriginal.lastIndexOf(".");
                            String ext = (idx >= 0) ? nombreArchivoOriginal.substring(idx) : "";
                            String nombreArchivo = "prop_" + System.currentTimeMillis() + "_" + imagenes.size() + ext;

                            String directorio = application.getRealPath("/uploads");
                            File carpeta = new File(directorio);
                            if (!carpeta.exists()) {
                                carpeta.mkdirs();
                            }

                            try (OutputStream salida = new FileOutputStream(new File(carpeta, nombreArchivo))) {
                                salida.write(contenido);
                            }

                            imagenes.add("uploads/" + nombreArchivo);
                        }
                    } else if (nombreCampo.startsWith("carac_")) {
                        String valor = new String(contenido, StandardCharsets.UTF_8).trim();
                        if (!valor.isEmpty()) {
                            int idCarac = Integer.parseInt(nombreCampo.substring("carac_".length()));
                            caracteristicas.put(idCarac, valor);
                        }
                    } else {
                        String valor = new String(contenido, StandardCharsets.UTF_8);
                        switch (nombreCampo) {
                            case "matricula": matricula = valor; break;
                            case "titulo": titulo = valor; break;
                            case "descripcion": descripcion = valor; break;
                            case "precio": precio = valor; break;
                            case "tipo_oferta": tipoOferta = valor; break;
                            case "estado_publicacion": estadoPublicacion = valor; break;
                            case "direccion": direccion = valor; break;
                            case "id_ciudad": idCiudad = valor; break;
                            case "id_tipo_propiedad": idTipoPropiedad = valor; break;
                            case "id_inmobiliaria": idInmobiliaria = valor; break;
                        }
                    }
                }

                // Para inmobiliaria: usar su inmobiliaria automáticamente
                if (esInmob && idInmobiliariaUsuario != null) {
                    idInmobiliaria = String.valueOf(idInmobiliariaUsuario);
                }
                
                // Admin puede elegir inmobiliaria (validar que se envió)
                if (esAdmin && idInmobiliaria.isEmpty()) {
                    mensajeError = "Debe seleccionar una inmobiliaria.";
                }

                if (matricula.isEmpty() || titulo.isEmpty() || precio.isEmpty() || tipoOferta.isEmpty() || direccion.isEmpty() || idCiudad.isEmpty() || idTipoPropiedad.isEmpty() || idInmobiliaria.isEmpty()) {
                    mensajeError = "Todos los campos obligatorios deben estar completos.";
                } else {
                    conexion.setAutoCommit(false);

                    String sqlPropiedad = "INSERT INTO propiedad (matricula_inmobiliaria, titulo, descripcion, precio, tipo_oferta, estado_publicacion, direccion, id_ciudad, id_tipo_propiedad, id_inmobiliaria) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
                    sentenciaPropiedad = conexion.prepareStatement(sqlPropiedad, Statement.RETURN_GENERATED_KEYS);
                    sentenciaPropiedad.setString(1, matricula);
                    sentenciaPropiedad.setString(2, titulo);
                    sentenciaPropiedad.setString(3, descripcion);
                    sentenciaPropiedad.setBigDecimal(4, new java.math.BigDecimal(precio));
                    sentenciaPropiedad.setString(5, tipoOferta);
                    sentenciaPropiedad.setString(6, estadoPublicacion);
                    sentenciaPropiedad.setString(7, direccion);
                    sentenciaPropiedad.setInt(8, Integer.parseInt(idCiudad));
                    sentenciaPropiedad.setInt(9, Integer.parseInt(idTipoPropiedad));
                    sentenciaPropiedad.setInt(10, Integer.parseInt(idInmobiliaria));
                    sentenciaPropiedad.executeUpdate();

                    claves = sentenciaPropiedad.getGeneratedKeys();
                    int idPropiedad = 0;
                    if (claves.next()) {
                        idPropiedad = claves.getInt(1);
                    }

                    if (!imagenes.isEmpty()) {
                        String sqlImagen = "INSERT INTO imagen_propiedad (id_propiedad, url_imagen, es_principal) VALUES (?, ?, ?)";
                        sentenciaImagen = conexion.prepareStatement(sqlImagen);
                        for (int i = 0; i < imagenes.size(); i++) {
                            sentenciaImagen.setInt(1, idPropiedad);
                            sentenciaImagen.setString(2, imagenes.get(i));
                            sentenciaImagen.setInt(3, i == 0 ? 1 : 0);
                            sentenciaImagen.addBatch();
                        }
                        sentenciaImagen.executeBatch();
                    }

                    if (!caracteristicas.isEmpty()) {
                        String sqlCarac = "INSERT INTO propiedad_caracteristica (id_propiedad, id_caracteristica, valor) VALUES (?, ?, ?)";
                        sentenciaCarac = conexion.prepareStatement(sqlCarac);
                        for (java.util.Map.Entry<Integer, String> entry : caracteristicas.entrySet()) {
                            sentenciaCarac.setInt(1, idPropiedad);
                            sentenciaCarac.setInt(2, entry.getKey());
                            sentenciaCarac.setString(3, entry.getValue());
                            sentenciaCarac.addBatch();
                        }
                        sentenciaCarac.executeBatch();
                    }

                    conexion.commit();
                    mensajeExito = "Propiedad creada correctamente.";
                }
            }
        } catch (NumberFormatException e) {
            mensajeError = "Datos numéricos inválidos.";
            try { if (conexion != null) conexion.rollback(); } catch (SQLException ex) { }
        } catch (SQLException e) {
            mensajeError = "Error SQL: " + e.getMessage();
            try { if (conexion != null) conexion.rollback(); } catch (SQLException ex) { }
        } catch (Exception e) {
            mensajeError = "Error: " + e.getMessage();
            try { if (conexion != null) conexion.rollback(); } catch (SQLException ex) { }
        } finally {
            if (claves != null) { try { claves.close(); } catch (SQLException e) { } }
            if (sentenciaCarac != null) { try { sentenciaCarac.close(); } catch (SQLException e) { } }
            if (sentenciaImagen != null) { try { sentenciaImagen.close(); } catch (SQLException e) { } }
            if (sentenciaPropiedad != null) { try { sentenciaPropiedad.close(); } catch (SQLException e) { } }
            if (conexion != null) { try { conexion.setAutoCommit(true); } catch (SQLException e) { } }
        }

        if (mensajeExito != null) {
            response.sendRedirect(request.getContextPath() + "/propiedades.jsp");
            return;
        }
    }
%>

<div class="container mt-4">
    <div class="d-flex justify-content-between align-items-center mb-3">
        <h2>Nueva Propiedad</h2>
        <a href="<%= request.getContextPath() %>/propiedades.jsp" class="btn btn-secondary">Volver</a>
    </div>

    <% if (mensajeError != null) { %>
    <div class="alert alert-danger"><%= mensajeError %></div>
    <% } %>

    <div class="card">
        <div class="card-body">
            <form action="<%= request.getContextPath() %>/propiedad_nueva.jsp" method="post" enctype="multipart/form-data">
                <div class="row">
                    <div class="col-md-6 mb-3">
                        <label>Matrícula Inmobiliaria *</label>
                        <input type="text" class="form-control" name="matricula" required>
                    </div>
                    <div class="col-md-6 mb-3">
                        <label>Título *</label>
                        <input type="text" class="form-control" name="titulo" required>
                    </div>
                </div>
                <div class="form-group mb-3">
                    <label>Descripción</label>
                    <textarea class="form-control" name="descripcion" rows="3"></textarea>
                </div>
                <div class="row">
                    <div class="col-md-4 mb-3">
                        <label>Precio *</label>
                        <input type="number" step="0.01" class="form-control" name="precio" required>
                    </div>
                    <div class="col-md-4 mb-3">
                        <label>Tipo de Oferta *</label>
                        <select class="form-control" name="tipo_oferta" required>
                            <option value="VENTA">Venta</option>
                            <option value="ARRIENDO">Arriendo</option>
                        </select>
                    </div>
                    <div class="col-md-4 mb-3">
                        <label>Estado</label>
                        <select class="form-control" name="estado_publicacion">
                            <option value="DISPONIBLE">Disponible</option>
                            <option value="RESERVADO">Reservado</option>
                            <option value="VENDIDO">Vendido</option>
                            <option value="INACTIVO">Inactivo</option>
                        </select>
                    </div>
                </div>
                <div class="form-group mb-3">
                    <label>Dirección *</label>
                    <input type="text" class="form-control" name="direccion" required>
                </div>
                <div class="row">
                    <div class="col-md-4 mb-3">
                        <label>Ciudad *</label>
                        <select class="form-control" name="id_ciudad" required>
                            <option value="">Seleccione...</option>
<%
    if (conexion != null) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conexion.prepareStatement("SELECT id_ciudad, nombre, departamento FROM ciudad ORDER BY nombre");
            rs = ps.executeQuery();
            while (rs.next()) {
%>
                            <option value="<%= rs.getInt("id_ciudad") %>"><%= rs.getString("nombre") %> (<%= rs.getString("departamento") %>)</option>
<%
            }
        } catch (Exception e) { } finally {
            if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
            if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
        }
    }
%>
                        </select>
                    </div>
                    <div class="col-md-4 mb-3">
                        <label>Tipo de Propiedad *</label>
                        <select class="form-control" name="id_tipo_propiedad" required>
                            <option value="">Seleccione...</option>
<%
    if (conexion != null) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conexion.prepareStatement("SELECT id_tipo_propiedad, nombre FROM tipo_propiedad ORDER BY nombre");
            rs = ps.executeQuery();
            while (rs.next()) {
%>
                            <option value="<%= rs.getInt("id_tipo_propiedad") %>"><%= rs.getString("nombre") %></option>
<%
            }
        } catch (Exception e) { } finally {
            if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
            if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
        }
    }
%>
                        </select>
                    </div>
                    <div class="col-md-4 mb-3">
                        <label>Inmobiliaria *</label>
<%
    if (esInmob && idInmobiliariaUsuario != null) {
        // Inmobiliaria: campo oculto + texto informativo
%>
                        <input type="hidden" name="id_inmobiliaria" value="<%= idInmobiliariaUsuario %>">
                        <select class="form-control" disabled>
                            <option value="<%= idInmobiliariaUsuario %>" selected>Mi inmobiliaria (automático)</option>
                        </select>
<%
    } else {
        // Admin: dropdown para elegir
%>
                        <select class="form-control" name="id_inmobiliaria" required>
                            <option value="">Seleccione...</option>
<%
        if (conexion != null) {
            PreparedStatement ps = null;
            ResultSet rs = null;
            try {
                ps = conexion.prepareStatement("SELECT id_inmobiliaria, nombre_comercial FROM inmobiliaria ORDER BY nombre_comercial");
                rs = ps.executeQuery();
                while (rs.next()) {
%>
                            <option value="<%= rs.getInt("id_inmobiliaria") %>"><%= rs.getString("nombre_comercial") %></option>
<%
                }
            } catch (Exception e) { } finally {
                if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
                if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
            }
        }
    }
%>
                        </select>
                    </div>
                </div>

                <hr>
                <h5>Imágenes (máximo 5)</h5>
                <div class="row">
<%
    for (int i = 0; i < 5; i++) {
%>
                    <div class="col-md-4 mb-3">
                        <label>Imagen <%= (i + 1) %> <%= i == 0 ? "(Principal)" : "" %></label>
                        <input type="file" class="form-control-file" name="imagen_<%= i %>" accept="image/*">
                    </div>
<%
    }
%>
                </div>

                <hr>
                <h5>Características</h5>
                <div class="row">
<%
    if (conexion != null) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conexion.prepareStatement("SELECT id_caracteristica, nombre FROM caracteristica ORDER BY nombre");
            rs = ps.executeQuery();
            int col = 0;
            while (rs.next()) {
                if (col % 3 == 0 && col > 0) {
%>
                    </div><div class="row">
<%
                }
%>
                        <div class="col-md-4 mb-3">
                            <label><%= rs.getString("nombre") %></label>
                            <input type="text" class="form-control" name="carac_<%= rs.getInt("id_caracteristica") %>" placeholder="Valor">
                        </div>
<%
                col++;
            }
        } catch (Exception e) { } finally {
            if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
            if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
        }
    }
%>
                </div>

                <button type="submit" class="btn btn-success btn-lg">Guardar Propiedad</button>
            </form>
        </div>
    </div>
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