<%@ page import="java.sql.Connection"%>
<%@ page import="java.sql.PreparedStatement"%>
<%@ page import="java.sql.ResultSet"%>
<%@ page import="java.sql.SQLException"%>
<%@ page import="java.io.File"%>
<%@ include file="conexion.jspf" %>
<%@ include file="auth.jspf" %>

<%
// Guardia: solo Inmobiliaria (dueño) y Admin pueden eliminar
if (!autenticado || (!esInmob && !esAdmin)) {
    response.sendRedirect(request.getContextPath() + "/index.jsp");
    return;
}

String idParam = request.getParameter("id");
int idPropiedad = 0;
try { idPropiedad = Integer.parseInt(idParam); } catch (NumberFormatException e) { idPropiedad = 0; }

if (idPropiedad == 0) {
    response.sendRedirect(request.getContextPath() + "/propiedades.jsp");
    return;
}

String titulo = "";
java.util.List<String> imagenes = new java.util.ArrayList<>();
int idInmobProp = 0;

if (conexion != null && idPropiedad > 0) {
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        ps = conexion.prepareStatement("SELECT titulo, id_inmobiliaria FROM propiedad WHERE id_propiedad = ? AND baja_logica = 0");
        ps.setInt(1, idPropiedad);
        rs = ps.executeQuery();
        if (rs.next()) {
            titulo = rs.getString("titulo");
            idInmobProp = rs.getInt("id_inmobiliaria");
        } else {
            response.sendRedirect(request.getContextPath() + "/propiedades.jsp");
            return;
        }
    } catch (Exception e) { } finally {
        if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
        if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
    }

    // Verificar ownership: inmobiliaria solo puede eliminar sus propias
    boolean esPropia = (idInmobiliariaUsuario != null && idInmobiliariaUsuario == idInmobProp);
    if (esInmob && !esPropia) {
        response.sendRedirect(request.getContextPath() + "/propiedades.jsp");
        return;
    }

    try {
        ps = conexion.prepareStatement("SELECT url_imagen FROM imagen_propiedad WHERE id_propiedad = ?");
        ps.setInt(1, idPropiedad);
        rs = ps.executeQuery();
        while (rs.next()) {
            imagenes.add(rs.getString("url_imagen"));
        }
    } catch (Exception e) { } finally {
        if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
        if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
    }
}

String mensajeError = null;

if ("POST".equalsIgnoreCase(request.getMethod()) && idPropiedad > 0) {
    PreparedStatement ps = null;
    try {
        conexion.setAutoCommit(false);

        // Eliminar archivos físicos
        for (String url : imagenes) {
            File f = new File(application.getRealPath("/" + url));
            if (f.exists()) f.delete();
        }

        // Eliminar relaciones
        ps = conexion.prepareStatement("DELETE FROM propiedad_caracteristica WHERE id_propiedad = ?");
        ps.setInt(1, idPropiedad);
        ps.executeUpdate();

        ps = conexion.prepareStatement("DELETE FROM imagen_propiedad WHERE id_propiedad = ?");
        ps.setInt(1, idPropiedad);
        ps.executeUpdate();

        // Baja lógica
        ps = conexion.prepareStatement("UPDATE propiedad SET baja_logica = 1 WHERE id_propiedad = ?");
        ps.setInt(1, idPropiedad);
        ps.executeUpdate();

        conexion.commit();
        response.sendRedirect(request.getContextPath() + "/propiedades.jsp");
        return;

    } catch (SQLException e) {
        mensajeError = "Error SQL: " + e.getMessage();
        try { if (conexion != null) conexion.rollback(); } catch (SQLException ex) { }
    } catch (Exception e) {
        mensajeError = "Error: " + e.getMessage();
        try { if (conexion != null) conexion.rollback(); } catch (SQLException ex) { }
    } finally {
        if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
        if (conexion != null) { try { conexion.setAutoCommit(true); } catch (SQLException e) { } }
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
    <title>Eliminar Propiedad</title>
</head>

<body>

<!-- Navbar unificado -->
<%@ include file="navbar.jspf" %>

<div class="container mt-4">
    <div class="d-flex justify-content-between align-items-center mb-3">
        <h2>Eliminar Propiedad</h2>
        <a href="<%= request.getContextPath() %>/propiedades.jsp" class="btn btn-secondary">Cancelar</a>
    </div>

    <% if (mensajeError != null) { %>
    <div class="alert alert-danger"><%= mensajeError %></div>
    <% } %>

    <div class="card">
        <div class="card-header bg-danger text-white">
            <h5 class="mb-0"><i class="fas fa-exclamation-triangle"></i> Confirmar Eliminación</h5>
        </div>
        <div class="card-body">
            <p class="lead">¿Está seguro de eliminar la propiedad <strong>"<%= titulo %>"</strong>?</p>
            <p class="text-muted">Esta acción no se puede deshacer. Se marcará como eliminada (baja lógica) y se borrarán sus imágenes y características asociadas.</p>

            <form method="post">
                <button type="submit" class="btn btn-danger btn-lg">
                    <i class="fas fa-trash"></i> Sí, Eliminar
                </button>
                <a href="<%= request.getContextPath() %>/propiedad_ver.jsp?id=<%= idPropiedad %>" class="btn btn-secondary btn-lg ml-2">No, Volver</a>
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