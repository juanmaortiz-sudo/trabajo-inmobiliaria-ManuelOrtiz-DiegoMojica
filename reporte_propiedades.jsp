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
    <title>Reporte de Propiedades</title>
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

    // Filtros opcionales
    String filtroCiudad = request.getParameter("id_ciudad") != null ? request.getParameter("id_ciudad") : "";
    String filtroEstado = request.getParameter("estado_publicacion") != null ? request.getParameter("estado_publicacion") : "";

    request.setAttribute("seccionActiva", "reportes");
%>
<%@ include file="navbar.jspf" %>

    <div class="container mt-4">
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h2><i class="fas fa-chart-bar"></i> Reporte de Propiedades</h2>
            <a href="reporte_propiedades.jsp" class="btn btn-outline-secondary btn-sm"><i class="fas fa-sync-alt"></i> Actualizar</a>
        </div>

        <!-- KPIs -->
        <%
            if (conexion != null) {
                PreparedStatement ps = null;
                ResultSet rs = null;
                int totalPropiedades = 0;
                int totalDisponibles = 0;
                double promedioGlobal = 0;
                try {
                    ps = conexion.prepareStatement("SELECT COUNT(*) AS t, COALESCE(SUM(CASE WHEN estado_publicacion='DISPONIBLE' THEN 1 ELSE 0 END),0) AS disp, COALESCE(AVG(precio),0) AS prom FROM propiedad WHERE baja_logica = 0");
                    rs = ps.executeQuery();
                    if (rs.next()) {
                        totalPropiedades = rs.getInt("t");
                        totalDisponibles = rs.getInt("disp");
                        promedioGlobal = rs.getDouble("prom");
                    }
                    rs.close();
                    ps.close();
        %>
        <div class="row mb-4">
            <div class="col-md-4">
                <div class="card text-white bg-primary mb-3">
                    <div class="card-body">
                        <h5 class="card-title"><i class="fas fa-home"></i> Total propiedades</h5>
                        <p class="display-4 mb-0"><%= totalPropiedades %></p>
                    </div>
                </div>
            </div>
            <div class="col-md-4">
                <div class="card text-white bg-success mb-3">
                    <div class="card-body">
                        <h5 class="card-title"><i class="fas fa-check-circle"></i> Disponibles</h5>
                        <p class="display-4 mb-0"><%= totalDisponibles %></p>
                    </div>
                </div>
            </div>
            <div class="col-md-4">
                <div class="card text-white bg-warning mb-3">
                    <div class="card-body">
                        <h5 class="card-title"><i class="fas fa-dollar-sign"></i> Precio promedio</h5>
                        <p class="h3 mb-0">$<%= String.format("%,.2f", promedioGlobal) %></p>
                    </div>
                </div>
            </div>
        </div>
        <%
                } catch (Exception e) { } finally {
                    if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
                    if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
                }
            }
        %>

        <!-- Filtros -->
        <div class="card mb-4">
            <div class="card-body">
                <form method="get" action="reporte_propiedades.jsp" class="row">
                    <div class="col-md-5 mb-2">
                        <label>Ciudad</label>
                        <select class="form-control" name="id_ciudad">
                            <option value="">Todas</option>
<%
    if (conexion != null) {
        PreparedStatement psC = null;
        ResultSet rsC = null;
        try {
            psC = conexion.prepareStatement("SELECT id_ciudad, nombre FROM ciudad ORDER BY nombre");
            rsC = psC.executeQuery();
            while (rsC.next()) {
%>
                            <option value="<%= rsC.getInt("id_ciudad") %>" <%= filtroCiudad.equals(String.valueOf(rsC.getInt("id_ciudad"))) ? "selected" : "" %>><%= rsC.getString("nombre") %></option>
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
                    <div class="col-md-5 mb-2">
                        <label>Estado de publicación</label>
                        <select class="form-control" name="estado_publicacion">
                            <option value="">Todos</option>
                            <option value="DISPONIBLE" <%= "DISPONIBLE".equals(filtroEstado) ? "selected" : "" %>>Disponible</option>
                            <option value="RESERVADO" <%= "RESERVADO".equals(filtroEstado) ? "selected" : "" %>>Reservado</option>
                            <option value="VENDIDO" <%= "VENDIDO".equals(filtroEstado) ? "selected" : "" %>>Vendido</option>
                            <option value="INACTIVO" <%= "INACTIVO".equals(filtroEstado) ? "selected" : "" %>>Inactivo</option>
                        </select>
                    </div>
                    <div class="col-md-2 mb-2 d-flex align-items-end">
                        <button type="submit" class="btn btn-primary btn-block"><i class="fas fa-filter"></i> Filtrar</button>
                    </div>
                </form>
            </div>
        </div>

        <div class="row">
            <!-- Reporte principal: por ciudad y estado (agregación) -->
            <div class="col-md-7">
                <div class="card mb-4">
                    <div class="card-header bg-success text-white">
                        <h5 class="mb-0"><i class="fas fa-table"></i> Propiedades por ciudad y estado</h5>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-striped table-hover">
                                <thead class="thead-dark">
                                    <tr>
                                        <th>Ciudad</th>
                                        <th>Estado</th>
                                        <th class="text-center">Total</th>
                                    </tr>
                                </thead>
                                <tbody>
<%
    if (conexion != null) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            StringBuilder sql = new StringBuilder();
            sql.append("SELECT c.nombre AS ciudad, p.estado_publicacion AS estado, COUNT(*) AS total ");
            sql.append("FROM propiedad p ");
            sql.append("JOIN ciudad c ON p.id_ciudad = c.id_ciudad ");
            sql.append("WHERE p.baja_logica = 0 ");
            if (!filtroCiudad.isEmpty()) {
                sql.append("AND p.id_ciudad = ? ");
            }
            if (!filtroEstado.isEmpty()) {
                sql.append("AND p.estado_publicacion = ? ");
            }
            sql.append("GROUP BY c.nombre, p.estado_publicacion ");
            sql.append("ORDER BY c.nombre, p.estado_publicacion");

            ps = conexion.prepareStatement(sql.toString());
            int idx = 1;
            if (!filtroCiudad.isEmpty()) { ps.setInt(idx++, Integer.parseInt(filtroCiudad)); }
            if (!filtroEstado.isEmpty()) { ps.setString(idx, filtroEstado); }
            rs = ps.executeQuery();
            int filas = 0;
            while (rs.next()) {
                filas++;
%>
                                    <tr>
                                        <td><%= rs.getString("ciudad") %></td>
                                        <td>
                                            <span class="badge badge-<%= "DISPONIBLE".equals(rs.getString("estado")) ? "success" : ("RESERVADO".equals(rs.getString("estado")) ? "warning" : "secondary") %>">
                                                <%= rs.getString("estado") %>
                                            </span>
                                        </td>
                                        <td class="text-center font-weight-bold"><%= rs.getInt("total") %></td>
                                    </tr>
<%
            }
            if (filas == 0) {
%>
                                    <tr><td colspan="3" class="text-center text-muted">Sin resultados para los filtros aplicados.</td></tr>
<%
            }
        } catch (Exception e) {
            out.println("<tr><td colspan='3' class='text-center text-danger'>Error: " + e.getMessage() + "</td></tr>");
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

            <!-- Columna derecha: otros agregados -->
            <div class="col-md-5">
                <div class="card mb-4">
                    <div class="card-header bg-success text-white">
                        <h5 class="mb-0"><i class="fas fa-tags"></i> Propiedades por tipo de oferta</h5>
                    </div>
                    <div class="card-body p-0">
                        <table class="table table-striped mb-0">
                            <tbody>
<%
    if (conexion != null) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conexion.prepareStatement("SELECT tipo_oferta, COUNT(*) AS total, COALESCE(AVG(precio),0) AS promedio FROM propiedad WHERE baja_logica = 0 GROUP BY tipo_oferta ORDER BY tipo_oferta");
            rs = ps.executeQuery();
            boolean hay = false;
            while (rs.next()) {
                hay = true;
%>
                                <tr>
                                    <td><span class="badge badge-info"><%= rs.getString("tipo_oferta") %></span></td>
                                    <td class="text-center"><%= rs.getInt("total") %> propiedades</td>
                                    <td class="text-right">prom. $<%= String.format("%,.2f", rs.getDouble("promedio")) %></td>
                                </tr>
<%
            }
            if (!hay) {
%>
                                <tr><td colspan="3" class="text-center text-muted">Sin datos.</td></tr>
<%
            }
        } catch (Exception e) { } finally {
            if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
            if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
        }
    }
%>
                            </tbody>
                        </table>
                    </div>
                </div>

                <div class="card mb-4">
                    <div class="card-header bg-success text-white">
                        <h5 class="mb-0"><i class="fas fa-phone"></i> Precio promedio por ciudad</h5>
                    </div>
                    <div class="card-body p-0">
                        <table class="table table-striped mb-0">
                            <tbody>
<%
    if (conexion != null) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conexion.prepareStatement("SELECT c.nombre AS ciudad, COUNT(*) AS total, MIN(p.precio) AS minimo, MAX(p.precio) AS maximo, ROUND(AVG(p.precio),2) AS promedio FROM propiedad p JOIN ciudad c ON p.id_ciudad = c.id_ciudad WHERE p.baja_logica = 0 GROUP BY c.nombre ORDER BY c.nombre");
            rs = ps.executeQuery();
            boolean hay = false;
            while (rs.next()) {
                hay = true;
%>
                                <tr>
                                    <td><%= rs.getString("ciudad") %></td>
                                    <td class="text-center"><%= rs.getInt("total") %></td>
                                    <td class="text-right">
                                        $<%= String.format("%,.2f", rs.getDouble("promedio")) %><br>
                                        <small class="text-muted">min $<%= String.format("%,.2f", rs.getDouble("minimo")) %> / max $<%= String.format("%,.2f", rs.getDouble("maximo")) %></small>
                                    </td>
                                </tr>
<%
            }
            if (!hay) {
%>
                                <tr><td colspan="3" class="text-center text-muted">Sin datos.</td></tr>
<%
            }
        } catch (Exception e) { } finally {
            if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
            if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
        }
    }
%>
                            </tbody>
                        </table>
                    </div>
                </div>

                <div class="card mb-4">
                    <div class="card-header bg-success text-white">
                        <h5 class="mb-0"><i class="fas fa-tasks"></i> Solicitudes y citas por estado</h5>
                    </div>
                    <div class="card-body p-0">
                        <table class="table table-striped mb-0">
                            <tbody>
                            <tr><td colspan="2" class="bg-light"><strong>Solicitudes</strong></td></tr>
<%
    if (conexion != null) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conexion.prepareStatement("SELECT estado, COUNT(*) AS total FROM solicitud GROUP BY estado ORDER BY estado");
            rs = ps.executeQuery();
            boolean hay = false;
            while (rs.next()) {
                hay = true;
%>
                                <tr>
                                    <td><span class="badge badge-<%= "APROBADA".equals(rs.getString("estado")) ? "success" : ("RECHAZADA".equals(rs.getString("estado")) ? "danger" : "warning") %>"><%= rs.getString("estado") %></span></td>
                                    <td class="text-right font-weight-bold"><%= rs.getInt("total") %></td>
                                </tr>
<%
            }
            if (!hay) {
%>
                                <tr><td colspan="2" class="text-center text-muted">Sin solicitudes.</td></tr>
<%
            }
        } catch (Exception e) { } finally {
            if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
            if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
        }
    }
%>
                            <tr><td colspan="2" class="bg-light"><strong>Citas</strong></td></tr>
<%
    if (conexion != null) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conexion.prepareStatement("SELECT estado, COUNT(*) AS total FROM cita GROUP BY estado ORDER BY estado");
            rs = ps.executeQuery();
            boolean hay = false;
            while (rs.next()) {
                hay = true;
%>
                                <tr>
                                    <td><span class="badge badge-secondary"><%= rs.getString("estado") %></span></td>
                                    <td class="text-right font-weight-bold"><%= rs.getInt("total") %></td>
                                </tr>
<%
            }
            if (!hay) {
%>
                                <tr><td colspan="2" class="text-center text-muted">Sin citas.</td></tr>
<%
            }
        } catch (Exception e) { } finally {
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