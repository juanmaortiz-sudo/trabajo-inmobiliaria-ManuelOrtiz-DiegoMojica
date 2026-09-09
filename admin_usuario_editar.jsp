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

String idParam = request.getParameter("id");
int idUsuario = 0;
try { idUsuario = Integer.parseInt(idParam); } catch (NumberFormatException e) { idUsuario = 0; }

if (idUsuario == 0) {
    response.sendRedirect(request.getContextPath() + "/admin_usuarios.jsp");
    return;
}

String correo = "";
String estado = "ACTIVO";
String rolActual = "";
String mensajeExito = null;
String mensajeError = null;

if (conexion != null) {
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        ps = conexion.prepareStatement("SELECT u.correo, u.estado, r.nombre AS rol FROM usuario u LEFT JOIN usuario_rol ur ON u.id_usuario = ur.id_usuario LEFT JOIN rol r ON ur.id_rol = r.id_rol WHERE u.id_usuario = ?");
        ps.setInt(1, idUsuario);
        rs = ps.executeQuery();
        if (rs.next()) {
            correo = rs.getString("correo");
            estado = rs.getString("estado");
            rolActual = rs.getString("rol") != null ? rs.getString("rol") : "";
        } else {
            response.sendRedirect(request.getContextPath() + "/admin_usuarios.jsp");
            return;
        }
    } catch (Exception e) { } finally {
        if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
        if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
    }
}

if ("POST".equalsIgnoreCase(request.getMethod())) {
    String nuevoEstado = request.getParameter("estado");
    String nuevoRol = request.getParameter("rol");
    String nuevaContrasena = request.getParameter("nueva_contrasena");
    String confirmarContrasena = request.getParameter("confirmar_contrasena");

    PreparedStatement ps = null;
    try {
        conexion.setAutoCommit(false);

        // Actualizar estado
        ps = conexion.prepareStatement("UPDATE usuario SET estado = ? WHERE id_usuario = ?");
        ps.setString(1, nuevoEstado);
        ps.setInt(2, idUsuario);
        ps.executeUpdate();

        // Actualizar rol
        // Primero obtener id_rol
        int idRol = 0;
        ps = conexion.prepareStatement("SELECT id_rol FROM rol WHERE nombre = ?");
        ps.setString(1, nuevoRol);
        rs = ps.executeQuery();
        if (rs.next()) {
            idRol = rs.getInt("id_rol");
        }
        
        // Eliminar rol anterior
        ps = conexion.prepareStatement("DELETE FROM usuario_rol WHERE id_usuario = ?");
        ps.setInt(1, idUsuario);
        ps.executeUpdate();
        
        // Insertar nuevo rol
        if (idRol > 0) {
            ps = conexion.prepareStatement("INSERT INTO usuario_rol (id_usuario, id_rol) VALUES (?, ?)");
            ps.setInt(1, idUsuario);
            ps.setInt(2, idRol);
            ps.executeUpdate();
        }

        // Actualizar contraseña si se proporcionó
        if (nuevaContrasena != null && !nuevaContrasena.isEmpty()) {
            if (!nuevaContrasena.equals(confirmarContrasena)) {
                mensajeError = "Las contraseñas no coinciden.";
            } else {
                // Hash SHA-256
                java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
                byte[] hash = digest.digest(nuevaContrasena.getBytes(java.nio.charset.StandardCharsets.UTF_8));
                StringBuilder sb = new StringBuilder();
                for (byte b : hash) {
                    sb.append(String.format("%02x", b));
                }
                String contrasenaHash = sb.toString();
                
                ps = conexion.prepareStatement("UPDATE usuario SET contrasena = ? WHERE id_usuario = ?");
                ps.setString(1, contrasenaHash);
                ps.setInt(2, idUsuario);
                ps.executeUpdate();
            }
        }

        if (mensajeError == null) {
            conexion.commit();
            mensajeExito = "Usuario actualizado correctamente.";
        } else {
            conexion.rollback();
        }

    } catch (Exception e) {
        mensajeError = "Error: " + e.getMessage();
        try { if (conexion != null) conexion.rollback(); } catch (SQLException ex) { }
    } finally {
        if (conexion != null) { try { conexion.setAutoCommit(true); } catch (SQLException e) { } }
    }

    if (mensajeExito != null) {
        // Recargar datos
        estado = nuevoEstado;
        rolActual = nuevoRol;
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
    <title>Editar Usuario</title>
</head>

<body>

<!-- Navbar unificado -->
<%@ include file="navbar.jspf" %>

<div class="container mt-4">
    <div class="d-flex justify-content-between align-items-center mb-3">
        <h2><i class="fas fa-user-edit"></i> Editar Usuario: <%= correo %></h2>
        <a href="<%= request.getContextPath() %>/admin_usuarios.jsp" class="btn btn-secondary">Volver</a>
    </div>

    <% if (mensajeExito != null) { %>
    <div class="alert alert-success"><%= mensajeExito %></div>
    <% } %>
    <% if (mensajeError != null) { %>
    <div class="alert alert-danger"><%= mensajeError %></div>
    <% } %>

    <div class="row">
        <div class="col-md-6">
            <div class="card">
                <div class="card-header bg-success text-white">
                    <h5 class="mb-0">Información del Usuario</h5>
                </div>
                <div class="card-body">
                    <form method="post">
                        <div class="form-group">
                            <label>Correo</label>
                            <input type="email" class="form-control" value="<%= correo %>" disabled>
                            <small class="form-text text-muted">El correo no se puede modificar.</small>
                        </div>
                        <div class="form-group">
                            <label>Estado</label>
                            <select class="form-control" name="estado">
                                <option value="ACTIVO" <%= "ACTIVO".equals(estado) ? "selected" : "" %>>Activo</option>
                                <option value="INACTIVO" <%= "INACTIVO".equals(estado) ? "selected" : "" %>>Inactivo</option>
                                <option value="BLOQUEADO" <%= "BLOQUEADO".equals(estado) ? "selected" : "" %>>Bloqueado</option>
                            </select>
                        </div>
                        <div class="form-group">
                            <label>Rol</label>
                            <select class="form-control" name="rol">
<%
    if (conexion != null) {
        PreparedStatement psR = null;
        ResultSet rsR = null;
        try {
            psR = conexion.prepareStatement("SELECT nombre FROM rol ORDER BY nombre");
            rsR = psR.executeQuery();
            while (rsR.next()) {
                String r = rsR.getString("nombre");
%>
                                <option value="<%= r %>" <%= r.equals(rolActual) ? "selected" : "" %>><%= r %></option>
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
                        <hr>
                        <h6>Cambiar Contraseña (opcional)</h6>
                        <div class="form-group">
                            <label>Nueva Contraseña</label>
                            <input type="password" class="form-control" name="nueva_contrasena" placeholder="Dejar vacío para no cambiar">
                        </div>
                        <div class="form-group">
                            <label>Confirmar Contraseña</label>
                            <input type="password" class="form-control" name="confirmar_contrasena" placeholder="Confirmar">
                        </div>
                        <button type="submit" class="btn btn-success btn-lg">Guardar Cambios</button>
                    </form>
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