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
    <title>Usuarios y Roles</title>
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

    String mensajeError = null;
    String mensajeExito = null;

    String accion = request.getParameter("accion");
    String idUsuarioParam = request.getParameter("id_usuario");
    String idRolParam = request.getParameter("id_rol");

    if (accion != null && idUsuarioParam != null && conexion != null) {
        int idUsuarioObj = 0;
        int idRolObj = 0;
        try {
            idUsuarioObj = Integer.parseInt(idUsuarioParam);
            idRolObj = idRolParam != null ? Integer.parseInt(idRolParam) : 0;
        } catch (NumberFormatException e) {
            idUsuarioObj = 0;
        }

        if (idUsuarioObj > 0) {
            PreparedStatement ps = null;
            try {
                if ("asignar".equals(accion) && idRolObj > 0) {
                    ps = conexion.prepareStatement("INSERT INTO usuario_rol (id_usuario, id_rol) VALUES (?, ?) ON DUPLICATE KEY UPDATE fecha_asignacion = CURRENT_TIMESTAMP");
                    ps.setInt(1, idUsuarioObj);
                    ps.setInt(2, idRolObj);
                    ps.executeUpdate();
                    registrarAuditoria(conexion, idUsuarioSesion, "ASIGNA_ROL", "usuario_rol", "id_usuario=" + idUsuarioObj + ", id_rol=" + idRolObj);
                    mensajeExito = "Rol asignado correctamente.";
                } else if ("revocar".equals(accion) && idRolObj > 0) {
                    if (idUsuarioObj == idUsuarioSesion && idRolObj != 0) {
                        ResultSet rs = null;
                        try {
                            ps = conexion.prepareStatement("SELECT r.nombre FROM rol r WHERE r.id_rol = ?");
                            ps.setInt(1, idRolObj);
                            rs = ps.executeQuery();
                            String nombreRol = rs.next() ? rs.getString("nombre") : "";
                            boolean rolAdmin = "admin".equalsIgnoreCase(nombreRol) || "administrador".equalsIgnoreCase(nombreRol);
                            if (rolAdmin) {
                                mensajeError = "No puede revocar su propio rol de administrador.";
                            } else {
                                ps = conexion.prepareStatement("DELETE FROM usuario_rol WHERE id_usuario = ? AND id_rol = ?");
                                ps.setInt(1, idUsuarioObj);
                                ps.setInt(2, idRolObj);
                                ps.executeUpdate();
                                registrarAuditoria(conexion, idUsuarioSesion, "REVOCA_ROL", "usuario_rol", "id_usuario=" + idUsuarioObj + ", id_rol=" + idRolObj);
                                mensajeExito = "Rol revocado correctamente.";
                            }
                        } finally {
                            if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
                        }
                    } else {
                        ps = conexion.prepareStatement("DELETE FROM usuario_rol WHERE id_usuario = ? AND id_rol = ?");
                        ps.setInt(1, idUsuarioObj);
                        ps.setInt(2, idRolObj);
                        ps.executeUpdate();
                        registrarAuditoria(conexion, idUsuarioSesion, "REVOCA_ROL", "usuario_rol", "id_usuario=" + idUsuarioObj + ", id_rol=" + idRolObj);
                        mensajeExito = "Rol revocado correctamente.";
                    }
                }
            } catch (SQLException e) {
                mensajeError = "Error SQL: " + e.getMessage();
            } catch (Exception e) {
                mensajeError = "Error: " + e.getMessage();
            } finally {
                if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
            }
        }
    }

    request.setAttribute("seccionActiva", "roles");
%>
<%@ include file="navbar.jspf" %>

    <div class="container mt-4">
        <h2 class="mb-3"><i class="fas fa-user-shield"></i> Usuarios y Roles</h2>

        <% if (mensajeError != null) { %>
        <div class="alert alert-danger"><%= mensajeError %></div>
        <% } %>
        <% if (mensajeExito != null) { %>
        <div class="alert alert-success"><%= mensajeExito %></div>
        <% } %>

        <div class="card">
            <div class="card-header bg-success text-white">
                <h5 class="mb-0">Asignación de roles</h5>
            </div>
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-striped table-hover">
                        <thead class="thead-dark">
                            <tr>
                                <th>ID</th>
                                <th>Correo</th>
                                <th>Estado</th>
                                <th>Roles actuales</th>
                                <th>Asignar rol</th>
                            </tr>
                        </thead>
                        <tbody>
<%
    if (conexion != null) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conexion.prepareStatement("SELECT u.id_usuario, u.correo, u.estado FROM usuario u ORDER BY u.id_usuario");
            rs = ps.executeQuery();
            while (rs.next()) {
                int idUsr = rs.getInt("id_usuario");
                String correo = rs.getString("correo");
                String estado = rs.getString("estado");
%>
                            <tr>
                                <td><%= idUsr %></td>
                                <td><%= correo %></td>
                                <td>
                                    <span class="badge badge-<%= "ACTIVO".equals(estado) ? "success" : "secondary" %>"><%= estado %></span>
                                </td>
                                <td>
<%
                PreparedStatement psRol = null;
                ResultSet rsRol = null;
                try {
                    psRol = conexion.prepareStatement("SELECT r.nombre, ur.id_rol FROM usuario_rol ur JOIN rol r ON ur.id_rol = r.id_rol WHERE ur.id_usuario = ?");
                    psRol.setInt(1, idUsr);
                    rsRol = psRol.executeQuery();
                    boolean tieneRol = false;
                    while (rsRol.next()) {
                        tieneRol = true;
                        int idRolUsr = rsRol.getInt("id_rol");
                        String nombreRol = rsRol.getString("nombre");
%>
                                    <span class="badge badge-info"><%= nombreRol %></span>
                                    <a href="roles.jsp?accion=revocar&id_usuario=<%= idUsr %>&id_rol=<%= idRolUsr %>" class="text-danger ml-1" title="Revocar rol <%= nombreRol %>" onclick="return confirm('¿Revocar el rol <%= nombreRol %> al usuario <%= correo %>?')">
                                        <i class="fas fa-times-circle"></i>
                                    </a>
                                    <br>
<%
                    }
                    if (!tieneRol) {
%>
                                    <span class="text-muted">Sin rol</span>
<%
                    }
                } catch (Exception e) { } finally {
                    if (rsRol != null) { try { rsRol.close(); } catch (SQLException e) { } }
                    if (psRol != null) { try { psRol.close(); } catch (SQLException e) { } }
                }
%>
                                </td>
                                <td>
                                    <form method="post" action="roles.jsp" class="form-inline">
                                        <input type="hidden" name="accion" value="asignar">
                                        <input type="hidden" name="id_usuario" value="<%= idUsr %>">
                                        <select class="form-control form-control-sm mr-2" name="id_rol" required>
                                            <option value="">Seleccione...</option>
<%
                PreparedStatement psRoles = null;
                ResultSet rsRoles = null;
                try {
                    psRoles = conexion.prepareStatement("SELECT id_rol, nombre FROM rol ORDER BY nombre");
                    rsRoles = psRoles.executeQuery();
                    while (rsRoles.next()) {
%>
                                            <option value="<%= rsRoles.getInt("id_rol") %>"><%= rsRoles.getString("nombre") %></option>
<%
                    }
                } catch (Exception e) { } finally {
                    if (rsRoles != null) { try { rsRoles.close(); } catch (SQLException e) { } }
                    if (psRoles != null) { try { psRoles.close(); } catch (SQLException e) { } }
                }
%>
                                        </select>
                                        <button type="submit" class="btn btn-sm btn-primary"><i class="fas fa-plus"></i> Asignar</button>
                                    </form>
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