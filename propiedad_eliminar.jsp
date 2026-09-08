<%@ page import="java.sql.Connection"%>
<%@ page import="java.sql.PreparedStatement"%>
<%@ page import="java.sql.ResultSet"%>
<%@ page import="java.sql.SQLException"%>
<%@ page import="java.io.File"%>
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

<%@ include file="conexion.jspf" %>

<%
    Integer idUsuarioSesion = (Integer) session.getAttribute("id_usuario");
    String rolSesion = (String) session.getAttribute("rol");

    if (idUsuarioSesion == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    String idParam = request.getParameter("id");
    int idPropiedad = 0;
    try { idPropiedad = Integer.parseInt(idParam); } catch (NumberFormatException e) { idPropiedad = 0; }

    String titulo = "";
    java.util.List<String> imagenes = new java.util.ArrayList<>();

    if (conexion != null && idPropiedad > 0) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conexion.prepareStatement("SELECT titulo FROM propiedad WHERE id_propiedad = ? AND baja_logica = 0");
            ps.setInt(1, idPropiedad);
            rs = ps.executeQuery();
            if (rs.next()) {
                titulo = rs.getString("titulo");
            } else {
                response.sendRedirect("propiedades.jsp");
                return;
            }
        } catch (Exception e) { } finally {
            if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
            if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
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
            response.sendRedirect("propiedades.jsp");
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

    <!-- Barra de navegación -->
    <nav class="navbar navbar-expand-lg navbar-dark bg-success">
        <div class="container">
            <a class="navbar-brand" href="index.jsp">Inmobiliaria</a>
            <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#barraNavegacion"
                aria-controls="barraNavegacion" aria-expanded="false" aria-label="Alternar navegación">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="barraNavegacion">
                <ul class="navbar-nav ml-auto">
                    <li class="nav-item"><a class="nav-link" href="index.jsp">Inicio</a></li>
                    <li class="nav-item active"><a class="nav-link" href="propiedades.jsp">Propiedades</a></li>
                    <li class="nav-item"><a class="nav-link" href="completar_registro.jsp">Mi perfil</a></li>
                    <li class="nav-item"><a class="nav-link" href="cerrar_sesion.jsp">Cerrar Sesión</a></li>
                </ul>
            </div>
        </div>
    </nav>

    <div class="container mt-4">
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h2>Eliminar Propiedad</h2>
            <a href="propiedades.jsp" class="btn btn-secondary">Cancelar</a>
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
                    <a href="propiedad_ver.jsp?id=<%= idPropiedad %>" class="btn btn-secondary btn-lg ml-2">No, Volver</a>
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