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
    <title>Mis Solicitudes</title>
</head>

<body>

<%@ include file="conexion.jspf" %>
<%@ include file="funciones.jspf" %>

<%
    Integer idUsuarioSesion = (Integer) session.getAttribute("id_usuario");
    String rolSesion = (String) session.getAttribute("rol");
    boolean esCliente = "cliente".equalsIgnoreCase(rolSesion);

    if (idUsuarioSesion == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    request.setAttribute("seccionActiva", "solicitudes");
%>
<%@ include file="navbar.jspf" %>

    <div class="container mt-4">
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h2><i class="fas fa-file-contract"></i> Solicitudes</h2>
            <% if (esCliente) { %>
            <a href="propiedades.jsp" class="btn btn-success">
                <i class="fas fa-plus"></i> Radicar nueva solicitud
            </a>
            <% } %>
        </div>

        <div class="card">
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-striped table-hover">
                        <thead class="thead-dark">
                            <tr>
                                <th>ID</th>
                                <th>Propiedad</th>
                                <th><%= esCliente ? "" : "Cliente" %></th>
                                <th>Tipo</th>
                                <th>Estado</th>
                                <th>Fecha</th>
                                <th>Documentos</th>
                                <th>Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
<%
    if (conexion != null) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            StringBuilder sql = new StringBuilder();
            sql.append("SELECT s.id_solicitud, s.tipo_solicitud, s.estado, s.fecha_solicitud, p.titulo AS propiedad, p.id_propiedad, ");
            sql.append("per.nombres, per.apellidos, ");
            sql.append("(SELECT COUNT(*) FROM documento_solicitud d WHERE d.id_solicitud = s.id_solicitud) AS num_docs ");
            sql.append("FROM solicitud s ");
            sql.append("JOIN propiedad p ON s.id_propiedad = p.id_propiedad AND p.baja_logica = 0 ");
            sql.append("LEFT JOIN perfil per ON s.id_cliente = per.id_usuario ");
            sql.append("WHERE 1=1 ");
            if (esCliente) {
                sql.append("AND s.id_cliente = ? ");
            }
            sql.append("ORDER BY s.fecha_solicitud DESC");

            ps = conexion.prepareStatement(sql.toString());
            if (esCliente) {
                ps.setInt(1, idUsuarioSesion);
            }
            rs = ps.executeQuery();
            while (rs.next()) {
                String estado = rs.getString("estado");
                String nombreC = rs.getString("nombres") != null ? rs.getString("nombres") + " " + rs.getString("apellidos") : "---";
%>
                            <tr>
                                <td><%= rs.getInt("id_solicitud") %></td>
                                <td><a href="propiedad_ver.jsp?id=<%= rs.getInt("id_propiedad") %>"><%= rs.getString("propiedad") %></a></td>
                                <% if (!esCliente) { %><td><%= nombreC %></td><% } %>
                                <td><span class="badge badge-info"><%= rs.getString("tipo_solicitud") %></span></td>
                                <td>
                                    <span class="badge badge-<%= "APROBADA".equals(estado) ? "success" : ("RECHAZADA".equals(estado) ? "danger" : "warning") %>">
                                        <%= estado %>
                                    </span>
                                </td>
                                <td><%= rs.getString("fecha_solicitud") %></td>
                                <td class="text-center"><span class="badge badge-secondary"><%= rs.getInt("num_docs") %></span></td>
                                <td>
                                    <a href="solicitud_ver.jsp?id=<%= rs.getInt("id_solicitud") %>" class="btn btn-sm btn-info" title="Ver solicitud">
                                        <i class="fas fa-eye"></i>
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