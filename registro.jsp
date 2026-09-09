<%@ page import="java.sql.Connection"%>
<%@ page import="java.sql.PreparedStatement"%>
<%@ page import="java.sql.Statement"%>
<%@ page import="java.sql.ResultSet"%>
<%@ page import="java.sql.DriverManager"%>
<%@ page import="java.sql.SQLException"%>
<%@ page import="java.security.MessageDigest"%>
<%@ page import="java.nio.charset.StandardCharsets"%>
<%@ include file="conexion.jspf" %>
<%@ include file="auth.jspf" %>

<%!
    private String hashSHA256(String dato) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] hash = digest.digest(dato.getBytes(StandardCharsets.UTF_8));
        StringBuilder sb = new StringBuilder();
        for (byte b : hash) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }
%>

<%
    String correo = request.getParameter("correo");
    String contrasena = request.getParameter("contrasena");
    String confirmar = request.getParameter("confirmar");
    String idRol = request.getParameter("id_rol");

    boolean hayError = false;

    if (conexion != null && correo != null && contrasena != null && idRol != null) {
        if (!contrasena.equals(confirmar)) {
            out.println("<div class='container'><div class='alert alert-danger'>Las contraseñas no coinciden.</div></div>");
            hayError = true;
        } else {
            PreparedStatement sentenciaUsuario = null;
            PreparedStatement sentenciaRol = null;
            PreparedStatement sentenciaNombre = null;
            ResultSet claves = null;
            ResultSet rsNombre = null;

            try {
                conexion.setAutoCommit(false);

                String contrasenaHash = hashSHA256(contrasena);

                String consultaUsuario = "INSERT INTO usuario (correo, contrasena, estado) VALUES (?, ?, 'ACTIVO')";
                sentenciaUsuario = conexion.prepareStatement(consultaUsuario, Statement.RETURN_GENERATED_KEYS);
                sentenciaUsuario.setString(1, correo);
                sentenciaUsuario.setString(2, contrasenaHash);
                sentenciaUsuario.executeUpdate();

                claves = sentenciaUsuario.getGeneratedKeys();
                int idUsuario = 0;
                if (claves.next()) {
                    idUsuario = claves.getInt(1);
                }

                String consultaRol = "INSERT INTO usuario_rol (id_usuario, id_rol) VALUES (?, ?)";
                sentenciaRol = conexion.prepareStatement(consultaRol);
                sentenciaRol.setInt(1, idUsuario);
                sentenciaRol.setInt(2, Integer.parseInt(idRol));
                sentenciaRol.executeUpdate();

                String consultaNombre = "SELECT nombre FROM rol WHERE id_rol = ?";
                sentenciaNombre = conexion.prepareStatement(consultaNombre);
                sentenciaNombre.setInt(1, Integer.parseInt(idRol));
                rsNombre = sentenciaNombre.executeQuery();

                String nombreRol = "";
                if (rsNombre.next()) {
                    nombreRol = rsNombre.getString("nombre");
                }

                conexion.commit();

                HttpSession sesion = request.getSession();
                sesion.setAttribute("id_usuario", Integer.valueOf(idUsuario));
                sesion.setAttribute("correo", correo);
                sesion.setAttribute("rol", nombreRol);

                if ("cliente".equalsIgnoreCase(nombreRol)) {
                    response.sendRedirect(request.getContextPath() + "/completar_registro.jsp");
                } else {
                    response.sendRedirect(request.getContextPath() + "/index.jsp");
                }
                return;

            } catch (NumberFormatException e) {
                out.println("<div class='container'><div class='alert alert-danger'>Rol inválido.</div></div>");
                try { conexion.rollback(); } catch (SQLException ex) { }
                hayError = true;
            } catch (SQLException e) {
                out.println("<div class='container'><div class='alert alert-danger'>Error SQL: " + e.getMessage() + "</div></div>");
                try { conexion.rollback(); } catch (SQLException ex) { }
                hayError = true;
            } catch (Exception e) {
                out.println("<div class='container'><div class='alert alert-danger'>Error: " + e.getMessage() + "</div></div>");
                try { conexion.rollback(); } catch (SQLException ex) { }
                hayError = true;
            } finally {
                if (rsNombre != null) {
                    try { rsNombre.close(); } catch (SQLException e) { }
                }
                if (sentenciaNombre != null) {
                    try { sentenciaNombre.close(); } catch (SQLException e) { }
                }
                if (sentenciaRol != null) {
                    try { sentenciaRol.close(); } catch (SQLException e) { }
                }
                if (sentenciaUsuario != null) {
                    try { sentenciaUsuario.close(); } catch (SQLException e) { }
                }
                if (claves != null) {
                    try { claves.close(); } catch (SQLException e) { }
                }
            }
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
    <title>Registro de Usuario</title>
</head>

<body>

<!-- Navbar unificado -->
<%@ include file="navbar.jspf" %>

<div class="container">
    <div class="jumbotron">
        <h1>Registro de Usuario</h1>
        <p class="lead">¿Quieres ser inmobiliaria? <a href="<%= request.getContextPath() %>/solicitar_inmobiliaria.jsp">Envía una solicitud</a> para que el administrador la revise.</p>
    </div>
    <form action="<%= request.getContextPath() %>/registro.jsp" method="post">
        <div class="form-group">
            <p><label>Correo:</label></p>
            <input type="email" class="form-control" id="correo" name="correo" required />
            <br>
            <p><label>Contraseña:</label></p>
            <input type="password" class="form-control" id="contrasena" name="contrasena" required />
            <br>
            <p><label>Confirmar Contraseña:</label></p>
            <input type="password" class="form-control" id="confirmar" name="confirmar" required />
            <br>
            <p><label>Rol:</label></p>
            <select class="form-control" id="id_rol" name="id_rol" required>
                <option value="">Seleccione un rol</option>
<%
                if (conexion != null) {
                    Statement stmtRoles = null;
                    ResultSet rsRoles = null;
                    try {
                        stmtRoles = conexion.createStatement();
                        rsRoles = stmtRoles.executeQuery("SELECT id_rol, nombre FROM rol WHERE LOWER(nombre) = 'cliente'");
                        while (rsRoles.next()) {
                            out.println("<option value='" + rsRoles.getInt("id_rol") + "'>" + rsRoles.getString("nombre") + "</option>");
                        }
                    } catch (Exception e) {
                        out.println("<option value=''>Error al cargar roles</option>");
                    } finally {
                        if (rsRoles != null) { try { rsRoles.close(); } catch (SQLException e) { } }
                        if (stmtRoles != null) { try { stmtRoles.close(); } catch (SQLException e) { } }
                    }
                } else {
                    out.println("<option value=''>No hay conexión</option>");
                }
%>
            </select>
            <br>
            <input type="submit" class="btn btn-primary" value="Registrar como Cliente" />
        </div>
    </form>
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