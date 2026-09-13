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
    <title>Auditoría del Sistema</title>
</head>

<body>

<%@ include file="conexion.jspf" %>
<%@ include file="funciones.jspf" %>

<%
    Integer idUsuarioSesion = (Integer) session.getAttribute("id_usuario");
    String rolSesion = (String) session.getAttribute("rol");
    boolean esAdministrador = "admin".equalsIgnoreCase(rolSesion) || "administrador".equalsIgnoreCase(rolSesion);

    if (idUsuarioSesion == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    if (!esAdministrador) {
        response.sendRedirect("index.jsp");
        return;
    }

    String filtroCorreo = request.getParameter("correo") != null ? request.getParameter("correo").trim() : "";
    String filtroTabla = request.getParameter("tabla_afectada") != null ? request.getParameter("tabla_afectada").trim() : "";

    request.setAttribute("seccionActiva", "auditoria");
%>
<%@ include file="navbar.jspf" %>

    <div class="container mt-4">
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h2><i class="fas fa-clipboard-list"></i> Auditoría de Accesos y Cambios</h2>
            <a href="auditoria.jsp" class="btn btn-outline-secondary btn-sm"><i class="fas fa-sync-alt"></i> Actualizar</a>
        </div>

        <div class="card mb-4">
            <div class="card-body">
                <form method="get" action="auditoria.jsp" class="row">
                    <div class="col-md-5 mb-2">
                        <label>Correo de usuario</label>
                        <input type="text" class="form-control" name="correo" value="<%= filtroCorreo %>" placeholder="Ej: admin@admin.com">
                    </div>
                    <div class="col-md-5 mb-2">
                        <label>Tabla afectada</label>
                        <select class="form-control" name="tabla_afectada">
                            <option value="">Todas</option>
<%
    if (conexion != null) {
        PreparedStatement psT = null;
        ResultSet rsT = null;
        try {
            psT = conexion.prepareStatement("SELECT DISTINCT tabla_afectada FROM auditoria ORDER BY tabla_afectada");
            rsT = psT.executeQuery();
            while (rsT.next()) {
%>
                            <option value="<%= rsT.getString("tabla_afectada") %>" <%= filtroTabla.equals(rsT.getString("tabla_afectada")) ? "selected" : "" %>><%= rsT.getString("tabla_afectada") %></option>
<%
            }
        } catch (Exception e) { } finally {
            if (rsT != null) { try { rsT.close(); } catch (SQLException e) { } }
            if (psT != null) { try { psT.close(); } catch (SQLException e) { } }
        }
    }
%>
                        </select>
                    </div>
                    <div class="col-md-2 mb-2 d-flex align-items-end">
                        <button type="submit" class="btn btn-primary btn-block"><i class="fas fa-filter"></i> Filtrar</button>
                    </div>
                </form>
            </div>
        </div>

        <div class="card">
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-striped table-hover">
                        <thead class="thead-dark">
                            <tr>
                                <th>ID</th>
                                <th>Fecha y hora</th>
                                <th>Usuario</th>
                                <th>Acción</th>
                                <th>Tabla</th>
                                <th>Detalles</th>
                            </tr>
                        </thead>
                        <tbody>
<%
    if (conexion != null) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            StringBuilder sql = new StringBuilder();
            sql.append("SELECT a.id_auditoria, a.accion, a.tabla_afectada, a.detalles, a.fecha_hora, u.correo ");
            sql.append("FROM auditoria a LEFT JOIN usuario u ON a.id_usuario = u.id_usuario ");
            sql.append("WHERE 1=1 ");
            if (!filtroCorreo.isEmpty()) {
                sql.append("AND u.correo LIKE ? ");
            }
            if (!filtroTabla.isEmpty()) {
                sql.append("AND a.tabla_afectada = ? ");
            }
            sql.append("ORDER BY a.fecha_hora DESC, a.id_auditoria DESC LIMIT 300");

            ps = conexion.prepareStatement(sql.toString());
            int idx = 1;
            if (!filtroCorreo.isEmpty()) { ps.setString(idx++, "%" + filtroCorreo + "%"); }
            if (!filtroTabla.isEmpty()) { ps.setString(idx, filtroTabla); }
            rs = ps.executeQuery();
            int filas = 0;
            while (rs.next()) {
                filas++;
%>
                            <tr>
                                <td><%= rs.getInt("id_auditoria") %></td>
                                <td><%= rs.getString("fecha_hora") %></td>
                                <td><%= rs.getString("correo") != null ? rs.getString("correo") : "—" %></td>
                                <td><span class="badge badge-primary"><%= rs.getString("accion") %></span></td>
                                <td><%= rs.getString("tabla_afectada") %></td>
                                <td class="text-muted small"><%= rs.getString("detalles") != null ? rs.getString("detalles") : "" %></td>
                            </tr>
<%
            }
            if (filas == 0) {
%>
                            <tr><td colspan="6" class="text-center text-muted">No hay registros de auditoría con los filtros aplicados.</td></tr>
<%
            }
        } catch (Exception e) {
            out.println("<tr><td colspan='6' class='text-center text-danger'>Error: " + e.getMessage() + "</td></tr>");
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