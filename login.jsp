<%@ page import="java.sql.Connection"%>
<%@ page import="java.sql.PreparedStatement"%>
<%@ page import="java.sql.ResultSet"%>
<%@ page import="java.sql.DriverManager"%>
<%@ page import="java.sql.SQLException"%>
<%@ page import="java.security.MessageDigest"%>
<%@ page import="java.nio.charset.StandardCharsets"%>
<!DOCTYPE html>
<html lang="es">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.6.0/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
    <link rel="stylesheet" href="assets/css/style.css">
    <title>Iniciar Sesión</title>
</head>

<body>

<%@ include file="conexion.jspf" %>

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

    if (conexion != null && correo != null && contrasena != null) {
        PreparedStatement sentenciaUsuario = null;
        PreparedStatement sentenciaRol = null;
        ResultSet rsUsuario = null;
        ResultSet rsRol = null;

        try {
            String consultaUsuario = "SELECT id_usuario, correo, contrasena, estado FROM usuario WHERE correo = ?";
            sentenciaUsuario = conexion.prepareStatement(consultaUsuario);
            sentenciaUsuario.setString(1, correo);
            rsUsuario = sentenciaUsuario.executeQuery();

            if (!rsUsuario.next()) {
                out.println("<div class='container'><div class='alert alert-danger'>Usuario no encontrado.</div></div>");
            } else {
                String estado = rsUsuario.getString("estado");
                if (!"ACTIVO".equals(estado)) {
                    out.println("<div class='container'><div class='alert alert-warning'>Cuenta inactiva o bloqueada.</div></div>");
                } else {
                    String hashAlmacenado = rsUsuario.getString("contrasena");
                    String hashIngresado = hashSHA256(contrasena);

                    if (!hashAlmacenado.equals(hashIngresado)) {
                        out.println("<div class='container'><div class='alert alert-danger'>Contraseña incorrecta.</div></div>");
                    } else {
                        int idUsuario = rsUsuario.getInt("id_usuario");

                        String consultaRol = "SELECT r.nombre FROM rol r INNER JOIN usuario_rol ur ON r.id_rol = ur.id_rol WHERE ur.id_usuario = ?";
                        sentenciaRol = conexion.prepareStatement(consultaRol);
                        sentenciaRol.setInt(1, idUsuario);
                        rsRol = sentenciaRol.executeQuery();

                        String rol = "SIN_ROL";
                        if (rsRol.next()) {
                            rol = rsRol.getString("nombre");
                        }

                        HttpSession sesion = request.getSession();
                        sesion.setAttribute("id_usuario", Integer.valueOf(idUsuario));
                        sesion.setAttribute("correo", correo);
                        sesion.setAttribute("rol", rol);

                        response.sendRedirect(request.getContextPath() + "/index.jsp");
                        return;
                    }
                }
            }

        } catch (ClassNotFoundException e) {
            out.println("<div class='container'><div class='alert alert-danger'>Error accediendo a la Base de Datos: " + e.getMessage() + "</div></div>");
        } catch (SQLException e) {
            out.println("<div class='container'><div class='alert alert-danger'>Error SQL: " + e.getMessage() + "</div></div>");
        } catch (Exception e) {
            out.println("<div class='container'><div class='alert alert-danger'>Error: " + e.getMessage() + "</div></div>");
        } finally {
            if (rsRol != null) {
                try { rsRol.close(); } catch (SQLException e) { }
            }
            if (rsUsuario != null) {
                try { rsUsuario.close(); } catch (SQLException e) { }
            }
            if (sentenciaRol != null) {
                try { sentenciaRol.close(); } catch (SQLException e) { }
            }
            if (sentenciaUsuario != null) {
                try { sentenciaUsuario.close(); } catch (SQLException e) { }
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
    <title>Iniciar Sesión</title>
</head>

<body>

<!-- Navbar unificado -->
<%@ include file="navbar.jspf" %>

<div class="container">
    <div class="jumbotron">
        <h1>Iniciar Sesión</h1>
    </div>
    <form action="<%= request.getContextPath() %>/login.jsp" method="post">
        <div class="form-group">
            <p><label>Correo:</label></p>
            <input type="email" class="form-control" id="correo" name="correo" required />
            <br>
            <p><label>Contraseña:</label></p>
            <input type="password" class="form-control" id="contrasena" name="contrasena" required />
            <br>
            <input type="submit" class="btn btn-primary" value="Ingresar" />
            <br><br>
            <p><a href="<%= request.getContextPath() %>/registro.jsp">¿No tienes cuenta? Regístrate</a></p>
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