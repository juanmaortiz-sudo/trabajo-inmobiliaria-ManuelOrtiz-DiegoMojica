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
    <title>Ver Propiedad</title>
</head>

<body>

<%@ include file="conexion.jspf" %>

<%
    Integer idUsuarioSesion = (Integer) session.getAttribute("id_usuario");
    String rolSesion = (String) session.getAttribute("rol");
    boolean esInmobiliaria = "inmobiliaria".equalsIgnoreCase(rolSesion);

    if (idUsuarioSesion == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    String idParam = request.getParameter("id");
    int idPropiedad = 0;
    try { idPropiedad = Integer.parseInt(idParam); } catch (NumberFormatException e) { idPropiedad = 0; }

    String titulo = "", descripcion = "", precio = "", tipoOferta = "", estadoPublicacion = "", direccion = "";
    String ciudad = "", tipoPropiedad = "", inmobiliaria = "", matricula = "";
    java.util.List<String> imagenes = new java.util.ArrayList<>();
    java.util.Map<String, String> caracteristicas = new java.util.LinkedHashMap<>();

    if (conexion != null && idPropiedad > 0) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            String sql = "SELECT p.*, c.nombre AS ciudad, c.departamento, tp.nombre AS tipo_propiedad, i.nombre_comercial AS inmobiliaria " +
                         "FROM propiedad p " +
                         "LEFT JOIN ciudad c ON p.id_ciudad = c.id_ciudad " +
                         "LEFT JOIN tipo_propiedad tp ON p.id_tipo_propiedad = tp.id_tipo_propiedad " +
                         "LEFT JOIN inmobiliaria i ON p.id_inmobiliaria = i.id_inmobiliaria " +
                         "WHERE p.id_propiedad = ? AND p.baja_logica = 0";
            ps = conexion.prepareStatement(sql);
            ps.setInt(1, idPropiedad);
            rs = ps.executeQuery();
            if (rs.next()) {
                titulo = rs.getString("titulo");
                descripcion = rs.getString("descripcion");
                precio = rs.getString("precio");
                tipoOferta = rs.getString("tipo_oferta");
                estadoPublicacion = rs.getString("estado_publicacion");
                direccion = rs.getString("direccion");
                ciudad = rs.getString("ciudad") != null ? rs.getString("ciudad") + " (" + rs.getString("departamento") + ")" : "---";
                tipoPropiedad = rs.getString("tipo_propiedad") != null ? rs.getString("tipo_propiedad") : "---";
                inmobiliaria = rs.getString("inmobiliaria") != null ? rs.getString("inmobiliaria") : "---";
                matricula = rs.getString("matricula_inmobiliaria");
            } else {
                response.sendRedirect("propiedades.jsp");
                return;
            }
        } catch (Exception e) { } finally {
            if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
            if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
        }

        try {
            ps = conexion.prepareStatement("SELECT url_imagen FROM imagen_propiedad WHERE id_propiedad = ? ORDER BY es_principal DESC, id_imagen");
            ps.setInt(1, idPropiedad);
            rs = ps.executeQuery();
            while (rs.next()) {
                imagenes.add(rs.getString("url_imagen"));
            }
        } catch (Exception e) { } finally {
            if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
            if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
        }

        try {
            String sqlCarac = "SELECT c.nombre, pc.valor FROM propiedad_caracteristica pc " +
                              "JOIN caracteristica c ON pc.id_caracteristica = c.id_caracteristica " +
                              "WHERE pc.id_propiedad = ? ORDER BY c.nombre";
            ps = conexion.prepareStatement(sqlCarac);
            ps.setInt(1, idPropiedad);
            rs = ps.executeQuery();
            while (rs.next()) {
                caracteristicas.put(rs.getString("nombre"), rs.getString("valor"));
            }
        } catch (Exception e) { } finally {
            if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
            if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
        }
    }
%>

    <!-- Barra de navegación -->
    <nav class="navbar navbar-expand-lg navbar-dark bg-success">
        <div class="container">
            <a class="navbar-brand" href="index.jsp">Inmobiliaria</a>
            <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#barraNavegacion"
                aria-controls="barraNavegacion" aria-expanded="false" aria-label="Alternar navegación">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="barraNavegacion">
                <ul class="navbar-nav ml-auto">
                    <li class="nav-item"><a class="nav-link" href="index.jsp">Inicio</a></li>
                    <% if (esInmobiliaria) { %>
                    <li class="nav-item active"><a class="nav-link" href="propiedades.jsp">Propiedades</a></li>
                    <% } %>
                    <li class="nav-item"><a class="nav-link" href="completar_registro.jsp">Mi perfil</a></li>
                    <li class="nav-item"><a class="nav-link" href="cerrar_sesion.jsp">Cerrar Sesión</a></li>
                </ul>
            </div>
        </div>
    </nav>

    <div class="container mt-4">
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h2><%= titulo %></h2>
            <div>
                <a href="propiedad_editar.jsp?id=<%= idPropiedad %>" class="btn btn-warning mr-2"><i class="fas fa-edit"></i> Editar</a>
                <a href="propiedades.jsp" class="btn btn-secondary">Volver</a>
            </div>
        </div>

        <div class="row">
            <div class="col-md-6">
                <% if (!imagenes.isEmpty()) { %>
                <div id="carouselPropiedad" class="carousel slide" data-ride="carousel">
                    <div class="carousel-inner">
                        <% for (int i = 0; i < imagenes.size(); i++) { %>
                        <div class="carousel-item <%= i == 0 ? "active" : "" %>">
                            <img src="<%= imagenes.get(i) %>" class="d-block w-100" alt="Imagen <%= i + 1 %>" style="max-height: 400px; object-fit: cover;">
                        </div>
                        <% } %>
                    </div>
                    <% if (imagenes.size() > 1) { %>
                    <a class="carousel-control-prev" href="#carouselPropiedad" role="button" data-slide="prev">
                        <span class="carousel-control-prev-icon" aria-hidden="true"></span>
                        <span class="sr-only">Anterior</span>
                    </a>
                    <a class="carousel-control-next" href="#carouselPropiedad" role="button" data-slide="next">
                        <span class="carousel-control-next-icon" aria-hidden="true"></span>
                        <span class="sr-only">Siguiente</span>
                    </a>
                    <% } %>
                </div>
                <% } else { %>
                <div class="text-center text-muted py-5">Sin imágenes</div>
                <% } %>
            </div>
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header bg-success text-white">
                        <h5 class="mb-0">Información</h5>
                    </div>
                    <div class="card-body">
                        <table class="table table-borderless mb-0">
                            <tr><th width="30%">Matrícula:</th><td><%= matricula %></td></tr>
                            <tr><th>Tipo:</th><td><%= tipoOferta %></td></tr>
                            <tr><th>Precio:</th><td class="text-success font-weight-bold h5">$<%= precio %></td></tr>
                            <tr><th>Estado:</th><td>
                                <span class="badge badge-<%= "DISPONIBLE".equals(estadoPublicacion) ? "success" : ("RESERVADO".equals(estadoPublicacion) ? "warning" : "secondary") %>">
                                    <%= estadoPublicacion %>
                                </span>
                            </td></tr>
                            <tr><th>Dirección:</th><td><%= direccion %></td></tr>
                            <tr><th>Ciudad:</th><td><%= ciudad %></td></tr>
                            <tr><th>Tipo Propiedad:</th><td><%= tipoPropiedad %></td></tr>
                            <tr><th>Inmobiliaria:</th><td><%= inmobiliaria %></td></tr>
                        </table>
                    </div>
                </div>

                <% if (!descripcion.isEmpty()) { %>
                <div class="card mt-3">
                    <div class="card-header">Descripción</div>
                    <div class="card-body">
                        <p class="mb-0"><%= descripcion %></p>
                    </div>
                </div>
                <% } %>
            </div>
        </div>

        <% if (!caracteristicas.isEmpty()) { %>
        <div class="card mt-4">
            <div class="card-header bg-success text-white">
                <h5 class="mb-0">Características</h5>
            </div>
            <div class="card-body">
                <div class="row">
                    <% for (java.util.Map.Entry<String, String> entry : caracteristicas.entrySet()) { %>
                    <div class="col-md-4 mb-2">
                        <strong><%= entry.getKey() %>:</strong> <%= entry.getValue() %>
                    </div>
                    <% } %>
                </div>
            </div>
        </div>
        <% } %>
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