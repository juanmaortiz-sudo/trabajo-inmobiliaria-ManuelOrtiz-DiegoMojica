<!DOCTYPE html>
<html lang="es">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <meta name="Description" content="Plataforma inmobiliaria - landing page" />
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.6.0/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
    <link rel="stylesheet" href="assets/css/style.css">
    <title>Inmobiliaria</title>
</head>

<body>

<%@ include file="conexion.jspf" %>
<%@ include file="auth.jspf" %>

<!-- Navbar unificado -->
<%@ include file="navbar.jspf" %>

<!-- Sección principal (Hero) -->
<header id="inicio" class="jumbotron jumbotron-fluid bg-light mb-0">
    <div class="container text-center">
<%
    String perfilNombres = null;
    String perfilApellidos = null;
    String perfilDocumento = null;
    String perfilTelefono = null;
    String perfilFoto = null;

    if (autenticado && conexion != null) {
        PreparedStatement psPerfil = null;
        ResultSet rsPerfil = null;
        try {
            psPerfil = conexion.prepareStatement("SELECT nombres, apellidos, documento, telefono, foto_url FROM perfil WHERE id_usuario = ?");
            psPerfil.setInt(1, idUsuario);
            rsPerfil = psPerfil.executeQuery();
            if (rsPerfil.next()) {
                perfilNombres = rsPerfil.getString("nombres");
                perfilApellidos = rsPerfil.getString("apellidos");
                perfilDocumento = rsPerfil.getString("documento");
                perfilTelefono = rsPerfil.getString("telefono");
                perfilFoto = rsPerfil.getString("foto_url");
            }
        } catch (Exception e) {
        } finally {
            if (rsPerfil != null) { try { rsPerfil.close(); } catch (SQLException e) { } }
            if (psPerfil != null) { try { psPerfil.close(); } catch (SQLException e) { } }
        }
    }

    if (autenticado) {
%>
        <h1 class="display-4">Bienvenido<% if (perfilNombres != null) { %>, <%= perfilNombres %> <%= perfilApellidos %> <% } %></h1>
        <% if (perfilFoto != null) { %>
        <img src="<%= request.getContextPath() %>/<%= perfilFoto %>" alt="Foto de perfil" class="img-fluid rounded-circle mb-3" style="max-width: 150px;" />
        <% } %>
        <hr>
        <div class="row justify-content-center">
            <div class="col-md-6">
                <ul class="list-group text-left">
                    <li class="list-group-item d-flex justify-content-between"><span>Documento:</span><strong><%= perfilDocumento != null ? perfilDocumento : "---" %></strong></li>
                    <li class="list-group-item d-flex justify-content-between"><span>Nombre:</span><strong><%= perfilNombres != null ? perfilNombres + " " + perfilApellidos : "---" %></strong></li>
                    <li class="list-group-item d-flex justify-content-between"><span>Apellido:</span><strong><%= perfilApellidos != null ? perfilApellidos : "---" %></strong></li>
                    <li class="list-group-item d-flex justify-content-between"><span>Teléfono:</span><strong><%= perfilTelefono != null ? perfilTelefono : "---" %></strong></li>
                </ul>
                <div class="mt-4">
                    <a class="btn btn-success btn-lg mr-2" href="<%= request.getContextPath() %>/completar_registro.jsp">Completar / Editar perfil</a>
<%
    if (esAdmin) {
%>
                    <a class="btn btn-outline-primary btn-lg mr-2" href="<%= request.getContextPath() %>/admin_usuarios.jsp"><i class="fas fa-users-cog"></i> Admin Usuarios</a>
                    <a class="btn btn-outline-primary btn-lg mr-2" href="<%= request.getContextPath() %>/admin_solicitudes.jsp"><i class="fas fa-clipboard-check"></i> Solicitudes</a>
<%
    }
    if (esInmob) {
%>
                    <a class="btn btn-outline-primary btn-lg mr-2" href="<%= request.getContextPath() %>/propiedad_nueva.jsp"><i class="fas fa-plus"></i> Nueva Propiedad</a>
                    <a class="btn btn-outline-primary btn-lg mr-2" href="<%= request.getContextPath() %>/propiedades.jsp"><i class="fas fa-home"></i> Ver Propiedades</a>
<%
    }
    if (esCliente) {
%>
                    <a class="btn btn-outline-primary btn-lg mr-2" href="<%= request.getContextPath() %>/propiedades.jsp"><i class="fas fa-home"></i> Ver Propiedades</a>
                    <a class="btn btn-outline-primary btn-lg mr-2" href="<%= request.getContextPath() %>/solicitar_inmobiliaria.jsp"><i class="fas fa-building"></i> Ser Inmobiliaria</a>
<%
    }
%>
                </div>
            </div>
        </div>
<%
    } else {
%>
        <h1 class="display-4">Bienvenido a tu plataforma inmobiliaria</h1>
        <p class="lead">Gestión de propiedades, citas, solicitudes y usuarios en un solo lugar.</p>
        <div class="mt-3">
            <a class="btn btn-success btn-lg mr-2" href="<%= request.getContextPath() %>/registro.jsp">Crear cuenta</a>
            <a class="btn btn-outline-primary btn-lg" href="<%= request.getContextPath() %>/propiedades.jsp"><i class="fas fa-home"></i> Ver Propiedades</a>
        </div>
<%
    }
%>
    </div>
</header>

<!-- Sección de características (plantilla) -->
<section id="caracteristicas" class="py-5">
    <div class="container">
        <h2 class="text-center mb-4">Características</h2>
        <div class="row">
            <div class="col-md-4 text-center mb-4">
                <i class="fas fa-home fa-3x text-success mb-3"></i>
                <h5>Propiedades</h5>
                <p class="text-muted">Publica y gestiona propiedades en venta o arriendo.</p>
            </div>
            <div class="col-md-4 text-center mb-4">
                <i class="fas fa-calendar-check fa-3x text-success mb-3"></i>
                <h5>Citas</h5>
                <p class="text-muted">Agenda y administra citas con clientes interesados.</p>
            </div>
            <div class="col-md-4 text-center mb-4">
                <i class="fas fa-users fa-3x text-success mb-3"></i>
                <h5>Usuarios y Roles</h5>
                <p class="text-muted">Control de acceso con roles para cada tipo de usuario.</p>
            </div>
        </div>
    </div>
</section>

<!-- Sección de contacto (plantilla) -->
<section id="contacto" class="bg-dark text-white py-5">
    <div class="container text-center">
        <h2>Contacto</h2>
        <p class="text-muted">Información de contacto de ejemplo.</p>
        <a class="btn btn-outline-light" href="<%= request.getContextPath() %>/login.jsp">Iniciar Sesión</a>
    </div>
</section>

<!-- Pie de página -->
<footer class="bg-secondary text-white py-3">
    <div class="container text-center">
        <small>&copy; 2026 Plataforma Inmobiliaria. Todos los derechos reservados.</small>
    </div>
</footer>

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