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

String filtroEstado = request.getParameter("estado") != null ? request.getParameter("estado") : "";
String accion = request.getParameter("accion");
String idSolicitudParam = request.getParameter("id_solicitud");

if ("POST".equalsIgnoreCase(request.getMethod()) && accion != null && idSolicitudParam != null) {
    int idSolicitud = 0;
    try { idSolicitud = Integer.parseInt(idSolicitudParam); } catch (NumberFormatException e) { idSolicitud = 0; }
    
    if (idSolicitud > 0) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            conexion.setAutoCommit(false);
            
            // Obtener datos de la solicitud
            ps = conexion.prepareStatement("SELECT id_cliente FROM solicitud WHERE id_solicitud = ? AND tipo_solicitud = 'INMOBILIARIA'");
            ps.setInt(1, idSolicitud);
            rs = ps.executeQuery();
            
            if (rs.next()) {
                int idCliente = rs.getInt("id_cliente");
                String nuevoEstado = "APROBADA".equals(accion) ? "APROBADA" : "RECHAZADA";
                
                // Actualizar estado de solicitud
                ps = conexion.prepareStatement("UPDATE solicitud SET estado = ? WHERE id_solicitud = ?");
                ps.setString(1, nuevoEstado);
                ps.setInt(2, idSolicitud);
                ps.executeUpdate();
                
                if ("APROBADA".equals(nuevoEstado)) {
                    // TODO: Crear registro en tabla inmobiliaria con los datos del cliente
                    // Por ahora solo cambiamos el rol del usuario
                    // Obtener id_rol de inmobiliaria
                    int idRolInmob = 0;
                    ps = conexion.prepareStatement("SELECT id_rol FROM rol WHERE nombre = 'inmobiliaria'");
                    rs = ps.executeQuery();
                    if (rs.next()) {
                        idRolInmob = rs.getInt("id_rol");
                    }
                    
                    if (idRolInmob > 0) {
                        // Cambiar rol del usuario
                        ps = conexion.prepareStatement("DELETE FROM usuario_rol WHERE id_usuario = ?");
                        ps.setInt(1, idCliente);
                        ps.executeUpdate();
                        
                        ps = conexion.prepareStatement("INSERT INTO usuario_rol (id_usuario, id_rol) VALUES (?, ?)");
                        ps.setInt(1, idCliente);
                        ps.setInt(2, idRolInmob);
                        ps.executeUpdate();
                        
                        // Crear registro en tabla inmobiliaria (datos básicos)
                        ps = conexion.prepareStatement("INSERT INTO inmobiliaria (id_usuario, nombre_comercial, nit, direccion, telefono, email_contacto) VALUES (?, 'Por completar', 'Por completar', 'Por completar', 'Por completar', 'Por completar')");
                        ps.setInt(1, idCliente);
                        ps.executeUpdate();
                    }
                }
                
                conexion.commit();
            }
        } catch (Exception e) {
            try { if (conexion != null) conexion.rollback(); } catch (SQLException ex) { }
        } finally {
            if (conexion != null) { try { conexion.setAutoCommit(true); } catch (SQLException e) { } }
        }
    }
    
    response.sendRedirect(request.getContextPath() + "/admin_solicitudes.jsp");
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
    <title>Admin - Solicitudes</title>
</head>

<body>

<!-- Navbar unificado -->
<%@ include file="navbar.jspf" %>

<div class="container mt-4">
    <div class="d-flex justify-content-between align-items-center mb-3">
        <h2><i class="fas fa-clipboard-check"></i> Solicitudes de Inmobiliaria</h2>
    </div>

    <div class="card mb-4">
        <div class="card-header bg-light">
            <h5 class="mb-0"><i class="fas fa-filter"></i> Filtrar</h5>
        </div>
        <div class="card-body">
            <form method="get" action="<%= request.getContextPath() %>/admin_solicitudes.jsp" class="row">
                <div class="col-md-3 mb-3">
                    <label>Estado</label>
                    <select class="form-control" name="estado">
                        <option value="">Todos</option>
                        <option value="EN_REVISION" <%= "EN_REVISION".equals(filtroEstado) ? "selected" : "" %>>En Revisión</option>
                        <option value="APROBADA" <%= "APROBADA".equals(filtroEstado) ? "selected" : "" %>>Aprobada</option>
                        <option value="RECHAZADA" <%= "RECHAZADA".equals(filtroEstado) ? "selected" : "" %>>Rechazada</option>
                    </select>
                </div>
                <div class="col-md-2 mb-3 d-flex align-items-end">
                    <button type="submit" class="btn btn-primary btn-block"><i class="fas fa-search"></i> Filtrar</button>
                </div>
                <div class="col-md-12">
                    <a href="<%= request.getContextPath() %>/admin_solicitudes.jsp" class="btn btn-outline-secondary btn-sm"><i class="fas fa-times"></i> Limpiar</a>
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
                            <th>Cliente (Correo)</th>
                            <th>Fecha</th>
                            <th>Estado</th>
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
            sql.append("SELECT s.id_solicitud, s.fecha_solicitud, s.estado, u.correo, u.id_usuario ");
            sql.append("FROM solicitud s ");
            sql.append("JOIN usuario u ON s.id_cliente = u.id_usuario ");
            sql.append("WHERE s.tipo_solicitud = 'INMOBILIARIA' ");

            java.util.List<Object> params = new java.util.ArrayList<>();

            if (!filtroEstado.isEmpty()) {
                sql.append("AND s.estado = ? ");
                params.add(filtroEstado);
            }

            sql.append("ORDER BY s.fecha_solicitud DESC");

            ps = conexion.prepareStatement(sql.toString());
            for (int i = 0; i < params.size(); i++) {
                ps.setString(i + 1, (String) params.get(i));
            }
            rs = ps.executeQuery();
            while (rs.next()) {
%>
                            <tr>
                                <td><%= rs.getInt("id_solicitud") %></td>
                                <td><%= rs.getString("correo") %></td>
                                <td><%= rs.getTimestamp("fecha_solicitud") %></td>
                                <td>
                                    <span class="badge badge-<%= "EN_REVISION".equals(rs.getString("estado")) ? "warning" : ("APROBADA".equals(rs.getString("estado")) ? "success" : "danger") %>">
                                        <%= rs.getString("estado") %>
                                    </span>
                                </td>
                                <td>
                                    <% if ("EN_REVISION".equals(rs.getString("estado"))) { %>
                                    <form method="post" style="display:inline;" onsubmit="return confirm('¿Aprobar esta solicitud? Se creará la inmobiliaria y se cambiará el rol del usuario.');">
                                        <input type="hidden" name="accion" value="APROBADA">
                                        <input type="hidden" name="id_solicitud" value="<%= rs.getInt("id_solicitud") %>">
                                        <button type="submit" class="btn btn-sm btn-success"><i class="fas fa-check"></i> Aprobar</button>
                                    </form>
                                    <form method="post" style="display:inline;" onsubmit="return confirm('¿Rechazar esta solicitud?');">
                                        <input type="hidden" name="accion" value="RECHAZADA">
                                        <input type="hidden" name="id_solicitud" value="<%= rs.getInt("id_solicitud") %>">
                                        <button type="submit" class="btn btn-sm btn-danger ml-1"><i class="fas fa-times"></i> Rechazar</button>
                                    </form>
                                    <% } else { %>
                                    <span class="text-muted">Procesada</span>
                                    <% } %>
                                </td>
                            </tr>
<%
            }
        } catch (Exception e) {
            out.println("<tr><td colspan='5' class='text-center text-danger'>Error: " + e.getMessage() + "</td></tr>");
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