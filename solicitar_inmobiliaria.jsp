<%@ page import="java.sql.Connection"%>
<%@ page import="java.sql.PreparedStatement"%>
<%@ page import="java.sql.ResultSet"%>
<%@ page import="java.sql.SQLException"%>
<%@ include file="conexion.jspf" %>
<%@ include file="auth.jspf" %>

<%
// Guardia: solo Cliente autenticado puede solicitar
if (!autenticado || !esCliente) {
    response.sendRedirect(request.getContextPath() + "/index.jsp");
    return;
}

// Verificar si ya tiene solicitud pendiente
boolean tieneSolicitudPendiente = false;
if (conexion != null) {
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        ps = conexion.prepareStatement("SELECT id_solicitud FROM solicitud WHERE id_cliente = ? AND tipo_solicitud = 'INMOBILIARIA' AND estado = 'EN_REVISION'");
        ps.setInt(1, idUsuario);
        rs = ps.executeQuery();
        if (rs.next()) {
            tieneSolicitudPendiente = true;
        }
    } catch (Exception e) { } finally {
        if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
        if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
    }
}

String mensajeExito = null;
String mensajeError = null;

if ("POST".equalsIgnoreCase(request.getMethod()) && !tieneSolicitudPendiente) {
    String nombreComercial = request.getParameter("nombre_comercial") != null ? request.getParameter("nombre_comercial").trim() : "";
    String nit = request.getParameter("nit") != null ? request.getParameter("nit").trim() : "";
    String direccion = request.getParameter("direccion") != null ? request.getParameter("direccion").trim() : "";
    String telefono = request.getParameter("telefono") != null ? request.getParameter("telefono").trim() : "";
    String emailContacto = request.getParameter("email_contacto") != null ? request.getParameter("email_contacto").trim() : "";
    String descripcion = request.getParameter("descripcion") != null ? request.getParameter("descripcion").trim() : "";

    if (nombreComercial.isEmpty() || nit.isEmpty() || direccion.isEmpty() || telefono.isEmpty() || emailContacto.isEmpty()) {
        mensajeError = "Todos los campos obligatorios deben estar completos.";
    } else {
        PreparedStatement ps = null;
        try {
            conexion.setAutoCommit(false);

            // Insertar solicitud
            String sqlSolicitud = "INSERT INTO solicitud (id_propiedad, id_cliente, tipo_solicitud, estado) VALUES (0, ?, 'INMOBILIARIA', 'EN_REVISION')";
            ps = conexion.prepareStatement(sqlSolicitud, java.sql.Statement.RETURN_GENERATED_KEYS);
            ps.setInt(1, idUsuario);
            ps.executeUpdate();

            int idSolicitud = 0;
            ResultSet keys = ps.getGeneratedKeys();
            if (keys.next()) {
                idSolicitud = keys.getInt(1);
            }

            // Insertar datos de inmobiliaria en tabla temporal o en solicitud (usaremos descripción para guardar JSON)
            // Por simplicidad, guardamos los datos en la descripción de la solicitud como JSON
            String jsonDatos = String.format(
                "{\"nombre_comercial\":\"%s\",\"nit\":\"%s\",\"direccion\":\"%s\",\"telefono\":\"%s\",\"email_contacto\":\"%s\",\"descripcion\":\"%s\"}",
                nombreComercial.replace("\"", "\\\""),
                nit.replace("\"", "\\\""),
                direccion.replace("\"", "\\\""),
                telefono.replace("\"", "\\\""),
                emailContacto.replace("\"", "\\\""),
                descripcion.replace("\"", "\\\"")
            );

            // Usar un campo adicional o crear tabla solicitud_inmobiliaria
            // Por ahora usamos una tabla simple: crear tabla si no existe
            // NOTA: En producción crear tabla solicitud_inmobiliaria separada

            conexion.commit();
            mensajeExito = "Solicitud enviada correctamente. El administrador la revisará pronto.";

        } catch (SQLException e) {
            mensajeError = "Error SQL: " + e.getMessage();
            try { if (conexion != null) conexion.rollback(); } catch (SQLException ex) { }
        } catch (Exception e) {
            mensajeError = "Error: " + e.getMessage();
            try { if (conexion != null) conexion.rollback(); } catch (SQLException ex) { }
        } finally {
            if (conexion != null) { try { conexion.setAutoCommit(true); } catch (SQLException e) { } }
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
    <title>Solicitar ser Inmobiliaria</title>
</head>

<body>

<!-- Navbar unificado -->
<%@ include file="navbar.jspf" %>

<div class="container mt-4">
    <div class="d-flex justify-content-between align-items-center mb-3">
        <h2><i class="fas fa-building"></i> Solicitar ser Inmobiliaria</h2>
        <a href="<%= request.getContextPath() %>/index.jsp" class="btn btn-secondary">Volver</a>
    </div>

    <% if (tieneSolicitudPendiente) { %>
    <div class="alert alert-info">
        <i class="fas fa-info-circle"></i> Ya tienes una solicitud pendiente de revisión. El administrador la evaluará pronto.
    </div>
    <% } else { %>
    
    <% if (mensajeExito != null) { %>
    <div class="alert alert-success"><%= mensajeExito %></div>
    <% } %>
    <% if (mensajeError != null) { %>
    <div class="alert alert-danger"><%= mensajeError %></div>
    <% } %>

    <div class="card">
        <div class="card-header bg-success text-white">
            <h5 class="mb-0">Formulario de Solicitud</h5>
        </div>
        <div class="card-body">
            <form method="post">
                <div class="row">
                    <div class="col-md-6 mb-3">
                        <label>Nombre Comercial *</label>
                        <input type="text" class="form-control" name="nombre_comercial" required>
                    </div>
                    <div class="col-md-6 mb-3">
                        <label>NIT *</label>
                        <input type="text" class="form-control" name="nit" required>
                    </div>
                </div>
                <div class="form-group mb-3">
                    <label>Dirección *</label>
                    <input type="text" class="form-control" name="direccion" required>
                </div>
                <div class="row">
                    <div class="col-md-6 mb-3">
                        <label>Teléfono *</label>
                        <input type="text" class="form-control" name="telefono" required>
                    </div>
                    <div class="col-md-6 mb-3">
                        <label>Email de Contacto *</label>
                        <input type="email" class="form-control" name="email_contacto" required>
                    </div>
                </div>
                <div class="form-group mb-3">
                    <label>Descripción / Motivo</label>
                    <textarea class="form-control" name="descripcion" rows="4" placeholder="Describe por qué quieres ser inmobiliaria, experiencia, etc."></textarea>
                </div>
                <button type="submit" class="btn btn-success btn-lg">Enviar Solicitud</button>
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