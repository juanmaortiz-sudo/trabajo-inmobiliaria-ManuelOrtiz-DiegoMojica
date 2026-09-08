<%@ page import="java.sql.Connection"%>
<%@ page import="java.sql.PreparedStatement"%>
<%@ page import="java.sql.ResultSet"%>
<%@ page import="java.sql.SQLException"%>
<!DOCTYPE html>
<html lang="es">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.6.0/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
    <link rel="stylesheet" href="assets/css/style.css">
    <title>Gestión de Propiedades</title>
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
            <h2>Propiedades</h2>
            <a href="propiedad_nueva.jsp" class="btn btn-success">
                <i class="fas fa-plus"></i> Nueva Propiedad
            </a>
        </div>

        <div class="card">
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-striped table-hover">
                        <thead class="thead-dark">
                            <tr>
                                <th>ID</th>
                                <th>Título</th>
                                <th>Tipo</th>
                                <th>Ciudad</th>
                                <th>Precio</th>
                                <th>Estado</th>
                                <th>Inmobiliaria</th>
                                <th>Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
<%
    if (conexion != null) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            String sql = "SELECT p.id_propiedad, p.matricula_inmobiliaria, p.titulo, p.precio, p.tipo_oferta, p.estado_publicacion, " +
                         "c.nombre AS ciudad, tp.nombre AS tipo_propiedad, i.nombre_comercial AS inmobiliaria " +
                         "FROM propiedad p " +
                         "LEFT JOIN ciudad c ON p.id_ciudad = c.id_ciudad " +
                         "LEFT JOIN tipo_propiedad tp ON p.id_tipo_propiedad = tp.id_tipo_propiedad " +
                         "LEFT JOIN inmobiliaria i ON p.id_inmobiliaria = i.id_inmobiliaria " +
                         "WHERE p.baja_logica = 0 ORDER BY p.fecha_creacion DESC";
            ps = conexion.prepareStatement(sql);
            rs = ps.executeQuery();
            while (rs.next()) {
%>
                            <tr>
                                <td><%= rs.getInt("id_propiedad") %></td>
                                <td><%= rs.getString("titulo") %></td>
                                <td><%= rs.getString("tipo_oferta") %></td>
                                <td><%= rs.getString("ciudad") != null ? rs.getString("ciudad") : "---" %></td>
                                <td>$<%= rs.getString("precio") %></td>
                                <td>
                                    <span class="badge badge-<%= "DISPONIBLE".equals(rs.getString("estado_publicacion")) ? "success" : ("RESERVADO".equals(rs.getString("estado_publicacion")) ? "warning" : "secondary") %>">
                                        <%= rs.getString("estado_publicacion") %>
                                    </span>
                                </td>
                                <td><%= rs.getString("inmobiliaria") != null ? rs.getString("inmobiliaria") : "---" %></td>
                                <td>
                                    <a href="propiedad_ver.jsp?id=<%= rs.getInt("id_propiedad") %>" class="btn btn-sm btn-info" title="Ver">
                                        <i class="fas fa-eye"></i>
                                    </a>
                                    <a href="propiedad_editar.jsp?id=<%= rs.getInt("id_propiedad") %>" class="btn btn-sm btn-warning" title="Editar">
                                        <i class="fas fa-edit"></i>
                                    </a>
                                    <a href="propiedad_eliminar.jsp?id=<%= rs.getInt("id_propiedad") %>" class="btn btn-sm btn-danger" title="Eliminar" onclick="return confirm('¿Eliminar esta propiedad?')">
                                        <i class="fas fa-trash"></i>
                                    </a>
                                </td>
                            </tr>
<%
            }
        } catch (Exception e) {
            out.println("<tr><td colspan='8' class='text-center text-danger'>Error: " + e.getMessage() + "</td></tr>");
        } finally {
            if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
            if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
        }
    }
%>
                        </tbody>
                    </table>
                </div>
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