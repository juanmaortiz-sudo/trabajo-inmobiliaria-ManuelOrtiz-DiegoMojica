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
    <title>Mis Favoritos</title>
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

    if (rolSesion == null || !"CLIENTE".equalsIgnoreCase(rolSesion)) {
        response.sendRedirect("propiedades.jsp");
        return;
    }

    request.setAttribute("seccionActiva", "favoritos");
%>
<%@ include file="navbar.jspf" %>

    <div class="container mt-4">
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h2><i class="fas fa-heart text-danger"></i> Mis Favoritos</h2>
            <a href="propiedades.jsp" class="btn btn-primary">
                <i class="fas fa-search"></i> Buscar propiedades
            </a>
        </div>

        <div class="card">
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-striped table-hover">
                        <thead class="thead-dark">
                            <tr>
                                <th>Imagen</th>
                                <th>Título</th>
                                <th>Ciudad</th>
                                <th>Tipo</th>
                                <th>Precio</th>
                                <th>Estado</th>
                                <th>Guardado</th>
                                <th>Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
<%
    int total = 0;
    if (conexion != null) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            String sql = "SELECT f.fecha_guardado, p.id_propiedad, p.titulo, p.precio, p.estado_publicacion, " +
                         "p.tipo_oferta, c.nombre AS ciudad, tp.nombre AS tipo_propiedad, " +
                         "(SELECT ip.url_imagen FROM imagen_propiedad ip WHERE ip.id_propiedad = p.id_propiedad ORDER BY ip.es_principal DESC, ip.id_imagen LIMIT 1) AS imagen " +
                         "FROM favorito f " +
                         "JOIN propiedad p ON f.id_propiedad = p.id_propiedad AND p.baja_logica = 0 " +
                         "LEFT JOIN ciudad c ON p.id_ciudad = c.id_ciudad " +
                         "LEFT JOIN tipo_propiedad tp ON p.id_tipo_propiedad = tp.id_tipo_propiedad " +
                         "WHERE f.id_usuario = ? " +
                         "ORDER BY f.fecha_guardado DESC";
            ps = conexion.prepareStatement(sql);
            ps.setInt(1, idUsuarioSesion);
            rs = ps.executeQuery();
            while (rs.next()) {
                total++;
                String imagen = rs.getString("imagen");
%>
                            <tr>
                                <td>
<%                  if (imagen != null) { %>
                                    <img src="<%= imagen %>" alt="Imagen" style="width: 70px; height: 50px; object-fit: cover; border-radius: 4px;">
<%                  } else { %>
                                    <span class="text-muted"><i class="fas fa-home fa-2x"></i></span>
<%                  } %>
                                </td>
                                <td><a href="propiedad_ver.jsp?id=<%= rs.getInt("id_propiedad") %>"><%= rs.getString("titulo") %></a></td>
                                <td><%= rs.getString("ciudad") != null ? rs.getString("ciudad") : "---" %></td>
                                <td><%= rs.getString("tipo_propiedad") != null ? rs.getString("tipo_propiedad") : "---" %></td>
                                <td>$<%= rs.getString("precio") %></td>
                                <td>
                                    <span class="badge badge-<%= "DISPONIBLE".equals(rs.getString("estado_publicacion")) ? "success" : ("RESERVADO".equals(rs.getString("estado_publicacion")) ? "warning" : "secondary") %>">
                                        <%= rs.getString("estado_publicacion") %>
                                    </span>
                                </td>
                                <td><%= rs.getString("fecha_guardado") %></td>
                                <td class="text-nowrap">
                                    <a href="propiedad_ver.jsp?id=<%= rs.getInt("id_propiedad") %>" class="btn btn-sm btn-info" title="Ver">
                                        <i class="fas fa-eye"></i>
                                    </a>
                                    <a href="favorito_toggle.jsp?id=<%= rs.getInt("id_propiedad") %>&accion=quitar&volver=favoritos" class="btn btn-sm btn-danger" title="Quitar de favoritos">
                                        <i class="fas fa-heart-broken"></i>
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
    if (total == 0) {
%>
                            <tr>
                                <td colspan="8" class="text-center text-muted py-4">
                                    <i class="fas fa-heart-broken fa-2x mb-2 d-block"></i>
                                    Aún no has guardado propiedades favoritas.
                                </td>
                            </tr>
<%
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