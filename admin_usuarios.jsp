<%@ page import="java.sql.Connection"%>
<%@ page import="java.sql.PreparedStatement"%>
<%@ page import="java.sql.ResultSet"%>
<%@ page import="java.sql.SQLException"%>
<%@ include file="conexion.jspf" %>
<%@ include file="auth.jspf" %>

<%
// Guardia: solo Admin
if (!autenticado || !esAdmin) {
    response.sendRedirect(request.getContextPath() + "/index.jsp");
    return;
}

String busqueda = request.getParameter("busqueda") != null ? request.getParameter("busqueda").trim() : "";
String filtroRol = request.getParameter("rol") != null ? request.getParameter("rol") : "";
String filtroEstado = request.getParameter("estado") != null ? request.getParameter("estado") : "";
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
    <title>Admin - Gestión de Usuarios</title>
</head>

<body>

<!-- Navbar unificado -->
<%@ include file="navbar.jspf" %>

<div class="container mt-4">
    <div class="d-flex justify-content-between align-items-center mb-3">
        <h2><i class="fas fa-users-cog"></i> Gestión de Usuarios</h2>
    </div>

    <!-- Filtros -->
    <div class="card mb-4">
        <div class="card-header bg-light">
            <h5 class="mb-0"><i class="fas fa-filter"></i> Buscar y Filtrar</h5>
        </div>
        <div class="card-body">
            <form method="get" action="<%= request.getContextPath() %>/admin_usuarios.jsp" class="row">
                <div class="col-md-4 mb-3">
                    <label>Buscar (correo)</label>
                    <input type="text" class="form-control" name="busqueda" value="<%= busqueda %>" placeholder="Filtrar por correo...">
                </div>
                <div class="col-md-3 mb-3">
                    <label>Rol</label>
                    <select class="form-control" name="rol">
                        <option value="">Todos</option>
<%
    if (conexion != null) {
        PreparedStatement psR = null;
        ResultSet rsR = null;
        try {
            psR = conexion.prepareStatement("SELECT nombre FROM rol ORDER BY nombre");
            rsR = psR.executeQuery();
            while (rsR.next()) {
%>
                        <option value="<%= rsR.getString("nombre") %>" <%= filtroRol.equals(rsR.getString("nombre")) ? "selected" : "" %>><%= rsR.getString("nombre") %></option>
<%
            }
        } catch (Exception e) { } finally {
            if (rsR != null) { try { rsR.close(); } catch (SQLException e) { } }
            if (psR != null) { try { psR.close(); } catch (SQLException e) { } }
        }
    }
%>
                    </select>
                </div>
                <div class="col-md-3 mb-3">
                    <label>Estado</label>
                    <select class="form-control" name="estado">
                        <option value="">Todos</option>
                        <option value="ACTIVO" <%= "ACTIVO".equals(filtroEstado) ? "selected" : "" %>>Activo</option>
                        <option value="INACTIVO" <%= "INACTIVO".equals(filtroEstado) ? "selected" : "" %>>Inactivo</option>
                        <option value="BLOQUEADO" <%= "BLOQUEADO".equals(filtroEstado) ? "selected" : "" %>>Bloqueado</option>
                    </select>
                </div>
                <div class="col-md-2 mb-3 d-flex align-items-end">
                    <button type="submit" class="btn btn-primary btn-block"><i class="fas fa-search"></i> Filtrar</button>
                </div>
                <div class="col-md-12">
                    <a href="<%= request.getContextPath() %>/admin_usuarios.jsp" class="btn btn-outline-secondary btn-sm"><i class="fas fa-times"></i> Limpiar</a>
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
                            <th>Correo</th>
                            <th>Rol</th>
                            <th>Estado</th>
                            <th>Fecha Registro</th>
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
            sql.append("SELECT u.id_usuario, u.correo, u.estado, u.fecha_registro, r.nombre AS rol ");
            sql.append("FROM usuario u ");
            sql.append("LEFT JOIN usuario_rol ur ON u.id_usuario = ur.id_usuario ");
            sql.append("LEFT JOIN rol r ON ur.id_rol = r.id_rol ");
            sql.append("WHERE 1=1 ");

            java.util.List<Object> params = new java.util.ArrayList<>();

            if (!busqueda.isEmpty()) {
                sql.append("AND u.correo LIKE ? ");
                params.add("%" + busqueda + "%");
            }
            if (!filtroRol.isEmpty()) {
                sql.append("AND r.nombre = ? ");
                params.add(filtroRol);
            }
            if (!filtroEstado.isEmpty()) {
                sql.append("AND u.estado = ? ");
                params.add(filtroEstado);
            }

            sql.append("ORDER BY u.fecha_registro DESC");

            ps = conexion.prepareStatement(sql.toString());
            for (int i = 0; i < params.size(); i++) {
                ps.setString(i + 1, (String) params.get(i));
            }
            rs = ps.executeQuery();
            while (rs.next()) {
%>
                            <tr>
                                <td><%= rs.getInt("id_usuario") %></td>
                                <td><%= rs.getString("correo") %></td>
                                <td><%= rs.getString("rol") != null ? rs.getString("rol") : "SIN_ROL" %></td>
                                <td>
                                    <span class="badge badge-<%= "ACTIVO".equals(rs.getString("estado")) ? "success" : ("INACTIVO".equals(rs.getString("estado")) ? "warning" : "danger") %>">
                                        <%= rs.getString("estado") %>
                                    </span>
                                </td>
                                <td><%= rs.getTimestamp("fecha_registro") %></td>
                                <td>
                                    <a href="<%= request.getContextPath() %>/admin_usuario_editar.jsp?id=<%= rs.getInt("id_usuario") %>" class="btn btn-sm btn-warning" title="Editar">
                                        <i class="fas fa-edit"></i>
                                    </a>
                                </td>
                            </tr>
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