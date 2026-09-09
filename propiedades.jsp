<%@ page import="java.sql.Connection"%>
<%@ page import="java.sql.PreparedStatement"%>
<%@ page import="java.sql.ResultSet"%>
<%@ page import="java.sql.SQLException"%>
<%@ include file="conexion.jspf" %>
<%@ include file="auth.jspf" %>

<%
// Guardia de autenticación - Visitante puede ver pero sin filtros
if (!autenticado) {
    // Visitante: redirigir a index.jsp con ancla a propiedades o permitir vista de solo lectura
    // Por ahora permitimos vista de solo lectura sin filtros
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
    <title>Gestión de Propiedades</title>
</head>

<body>

<!-- Navbar unificado -->
<%@ include file="navbar.jspf" %>

<div class="container mt-4">
    <div class="d-flex justify-content-between align-items-center mb-3">
        <h2>Propiedades</h2>
        <% if (esInmob || esAdmin) { %>
        <a href="<%= request.getContextPath() %>/propiedad_nueva.jsp" class="btn btn-success">
            <i class="fas fa-plus"></i> Nueva Propiedad
        </a>
        <% } %>
    </div>

    <!-- Filtros y búsqueda -->
    <div class="card mb-4">
        <div class="card-header bg-light">
            <h5 class="mb-0"><i class="fas fa-filter"></i> Buscar y Filtrar</h5>
        </div>
        <div class="card-body">
            <form method="get" action="<%= request.getContextPath() %>/propiedades.jsp" class="row">
                <div class="col-md-4 mb-3">
                    <label>Buscar (título o matrícula)</label>
                    <input type="text" class="form-control" name="busqueda" value="<%= busqueda %>" placeholder="Ej: Casa en el centro, matrícula 123..." <%= esVisitante ? "disabled" : "" %>>
                </div>
                <div class="col-md-2 mb-3">
                    <label>Tipo de Oferta</label>
                    <select class="form-control" name="tipo_oferta" <%= esVisitante ? "disabled" : "" %>>
                        <option value="">Todos</option>
                        <option value="VENTA" <%= "VENTA".equals(filtroTipoOferta) ? "selected" : "" %>>Venta</option>
                        <option value="ARRIENDO" <%= "ARRIENDO".equals(filtroTipoOferta) ? "selected" : "" %>>Arriendo</option>
                    </select>
                </div>
                <div class="col-md-3 mb-3">
                    <label>Ciudad</label>
                    <select class="form-control" name="id_ciudad" <%= esVisitante ? "disabled" : "" %>>
                        <option value="">Todas</option>
<%
    if (conexion != null) {
        PreparedStatement psC = null;
        ResultSet rsC = null;
        try {
            psC = conexion.prepareStatement("SELECT id_ciudad, nombre, departamento FROM ciudad ORDER BY nombre");
            rsC = psC.executeQuery();
            while (rsC.next()) {
%>
                        <option value="<%= rsC.getInt("id_ciudad") %>" <%= filtroCiudad.equals(String.valueOf(rsC.getInt("id_ciudad"))) ? "selected" : "" %>><%= rsC.getString("nombre") %> (<%= rsC.getString("departamento") %>)</option>
<%
            }
        } catch (Exception e) { } finally {
            if (rsC != null) { try { rsC.close(); } catch (SQLException e) { } }
            if (psC != null) { try { psC.close(); } catch (SQLException e) { } }
        }
    }
%>
                    </select>
                </div>
                <div class="col-md-2 mb-3">
                    <label>Estado</label>
                    <select class="form-control" name="estado_publicacion" <%= esVisitante ? "disabled" : "" %>>
                        <option value="">Todos</option>
                        <option value="DISPONIBLE" <%= "DISPONIBLE".equals(filtroEstado) ? "selected" : "" %>>Disponible</option>
                        <option value="RESERVADO" <%= "RESERVADO".equals(filtroEstado) ? "selected" : "" %>>Reservado</option>
                        <option value="VENDIDO" <%= "VENDIDO".equals(filtroEstado) ? "selected" : "" %>>Vendido</option>
                        <option value="INACTIVO" <%= "INACTIVO".equals(filtroEstado) ? "selected" : "" %>>Inactivo</option>
                    </select>
                </div>
                <div class="col-md-1 mb-3 d-flex align-items-end">
                    <button type="submit" class="btn btn-primary btn-block" <%= esVisitante ? "disabled" : "" %>><i class="fas fa-search"></i> Filtrar</button>
                </div>
                <div class="col-md-12">
                    <a href="<%= request.getContextPath() %>/propiedades.jsp" class="btn btn-outline-secondary btn-sm" <%= esVisitante ? "disabled" : "" %>><i class="fas fa-times"></i> Limpiar filtros</a>
                </div>
            </form>
            <% if (esVisitante) { %>
            <div class="alert alert-info mt-3 mb-0">
                <i class="fas fa-info-circle"></i> Inicia sesión para usar los filtros de búsqueda.
            </div>
            <% } %>
        </div>
    </div>

    <div class="card">
        <div class="card-body">
            <div class="table-responsive">
                <table class="table table-striped table-hover">
                    <thead class="thead-dark">
                        <tr>
                            <th>ID</th>
                            <th>Título</th>
                            <th>Tipo</th>
                            <th>Ciudad</th>
                            <th>Precio</th>
                            <th>Estado</th>
                            <th>Inmobiliaria</th>
                            <th>Acciones</th>
                        </tr>
                    </thead>
                    <tbody>
<%
    // Parámetros de búsqueda y filtros
    String busqueda = request.getParameter("busqueda") != null ? request.getParameter("busqueda").trim() : "";
    String filtroTipoOferta = request.getParameter("tipo_oferta") != null ? request.getParameter("tipo_oferta") : "";
    String filtroCiudad = request.getParameter("id_ciudad") != null ? request.getParameter("id_ciudad") : "";
    String filtroEstado = request.getParameter("estado_publicacion") != null ? request.getParameter("estado_publicacion") : "";

    // Para visitante, ignorar filtros
    if (esVisitante) {
        busqueda = "";
        filtroTipoOferta = "";
        filtroCiudad = "";
        filtroEstado = "";
    }

    if (conexion != null) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            StringBuilder sql = new StringBuilder();
            sql.append("SELECT p.id_propiedad, p.matricula_inmobiliaria, p.titulo, p.precio, p.tipo_oferta, p.estado_publicacion, ");
            sql.append("c.nombre AS ciudad, tp.nombre AS tipo_propiedad, i.nombre_comercial AS inmobiliaria, p.id_inmobiliaria ");
            sql.append("FROM propiedad p ");
            sql.append("LEFT JOIN ciudad c ON p.id_ciudad = c.id_ciudad ");
            sql.append("LEFT JOIN tipo_propiedad tp ON p.id_tipo_propiedad = tp.id_tipo_propiedad ");
            sql.append("LEFT JOIN inmobiliaria i ON p.id_inmobiliaria = i.id_inmobiliaria ");
            
            // Filtro base: solo propiedades no dadas de baja lógicamente
            sql.append("WHERE p.baja_logica = 0 ");
            
            // Inmobiliaria ve todas (según decisión), admin ve todas
            // Si se quisiera filtrar por inmobiliaria del usuario: 
            // if (esInmob && idInmobiliariaUsuario != null) { sql.append("AND p.id_inmobiliaria = ? "); }
            
            java.util.List<Object> params = new java.util.ArrayList<>();

            if (!busqueda.isEmpty()) {
                sql.append("AND (p.titulo LIKE ? OR p.matricula_inmobiliaria LIKE ?) ");
                params.add("%" + busqueda + "%");
                params.add("%" + busqueda + "%");
            }
            if (!filtroTipoOferta.isEmpty()) {
                sql.append("AND p.tipo_oferta = ? ");
                params.add(filtroTipoOferta);
            }
            if (!filtroCiudad.isEmpty()) {
                sql.append("AND p.id_ciudad = ? ");
                params.add(Integer.parseInt(filtroCiudad));
            }
            if (!filtroEstado.isEmpty()) {
                sql.append("AND p.estado_publicacion = ? ");
                params.add(filtroEstado);
            }

            sql.append("ORDER BY p.fecha_creacion DESC");

            ps = conexion.prepareStatement(sql.toString());
            for (int i = 0; i < params.size(); i++) {
                if (params.get(i) instanceof Integer) {
                    ps.setInt(i + 1, (Integer) params.get(i));
                } else {
                    ps.setString(i + 1, (String) params.get(i));
                }
            }
            rs = ps.executeQuery();
            while (rs.next()) {
                int idProp = rs.getInt("id_propiedad");
                int idInmobProp = rs.getInt("id_inmobiliaria");
                boolean esPropia = (idInmobiliariaUsuario != null && idInmobiliariaUsuario == idInmobProp);
%>
                            <tr>
                                <td><%= idProp %></td>
                                <td><%= rs.getString("titulo") %></td>
                                <td><%= rs.getString("tipo_oferta") %></td>
                                <td><%= rs.getString("ciudad") != null ? rs.getString("ciudad") : "---" %></td>
                                <td>$<%= rs.getString("precio") %></td>
                                <td>
                                    <span class="badge badge-<%= "DISPONIBLE".equals(rs.getString("estado_publicacion")) ? "success" : ("RESERVADO".equals(rs.getString("estado_publicacion")) ? "warning" : "secondary") %>">
                                        <%= rs.getString("estado_publicacion") %>
                                    </span>
                                </td>
                                <td><%= rs.getString("inmobiliaria") != null ? rs.getString("inmobiliaria") : "---" %></td>
                                <td>
                                    <a href="<%= request.getContextPath() %>/propiedad_ver.jsp?id=<%= idProp %>" class="btn btn-sm btn-info" title="Ver">
                                        <i class="fas fa-eye"></i>
                                    </a>
                                    <% 
                                        boolean puedeEditar = esAdmin || (esInmob && esPropia);
                                        boolean puedeEliminar = esAdmin || (esInmob && esPropia);
                                    %>
                                    <% if (puedeEditar) { %>
                                    <a href="<%= request.getContextPath() %>/propiedad_editar.jsp?id=<%= idProp %>" class="btn btn-sm btn-warning" title="Editar">
                                        <i class="fas fa-edit"></i>
                                    </a>
                                    <% } %>
                                    <% if (puedeEliminar) { %>
                                    <a href="<%= request.getContextPath() %>/propiedad_eliminar.jsp?id=<%= idProp %>" class="btn btn-sm btn-danger" title="Eliminar" onclick="return confirm('¿Eliminar esta propiedad?')">
                                        <i class="fas fa-trash"></i>
                                    </a>
                                    <% } %>
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