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
    <title>Gestión de Citas</title>
</head>

<body>

<%@ include file="conexion.jspf" %>
<%@ include file="funciones.jspf" %>

<%
    Integer idUsuarioSesion = (Integer) session.getAttribute("id_usuario");
    String rolSesion = (String) session.getAttribute("rol");
    boolean esCliente = "cliente".equalsIgnoreCase(rolSesion);
    boolean esInmobiliaria = "inmobiliaria".equalsIgnoreCase(rolSesion);
    boolean esAdministrador = "admin".equalsIgnoreCase(rolSesion) || "administrador".equalsIgnoreCase(rolSesion);

    if (idUsuarioSesion == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    String mensajeError = null;

    String accion = request.getParameter("accion");
    String idCitaParam = request.getParameter("id_cita");
    int idCita = 0;
    try { idCita = Integer.parseInt(idCitaParam); } catch (NumberFormatException e) { idCita = 0; }

    if (accion != null && idCita > 0 && conexion != null) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            String nuevoEstado = null;
            String accionAuditoria = null;

            ps = conexion.prepareStatement("SELECT id_cliente, estado FROM cita WHERE id_cita = ?");
            ps.setInt(1, idCita);
            rs = ps.executeQuery();
            if (rs.next()) {
                int idCliente = rs.getInt("id_cliente");
                String estadoActual = rs.getString("estado");
                rs.close();
                rs = null;
                ps.close();
                ps = null;

                boolean puedeGestionar = esInmobiliaria || esAdministrador;
                boolean esPropia = (esCliente && idCliente == idUsuarioSesion) || (!esCliente && esAdministrador || esInmobiliaria);

                if ("CANCELAR".equals(accion) && (esPropia || puedeGestionar) && !"REALIZADA".equals(estadoActual) && !"CANCELADA".equals(estadoActual)) {
                    nuevoEstado = "CANCELADA";
                    accionAuditoria = "CANCELA_CITA";
                } else if ("CONFIRMAR".equals(accion) && puedeGestionar && "PENDIENTE".equals(estadoActual)) {
                    nuevoEstado = "CONFIRMADA";
                    accionAuditoria = "CONFIRMA_CITA";
                } else if ("REALIZADA".equals(accion) && puedeGestionar && ("PENDIENTE".equals(estadoActual) || "CONFIRMADA".equals(estadoActual))) {
                    nuevoEstado = "REALIZADA";
                    accionAuditoria = "REALIZA_CITA";
                } else {
                    mensajeError = "No es posible aplicar esa acción al estado actual de la cita.";
                }

                if (nuevoEstado != null) {
                    ps = conexion.prepareStatement("UPDATE cita SET estado = ? WHERE id_cita = ?");
                    ps.setString(1, nuevoEstado);
                    ps.setInt(2, idCita);
                    ps.executeUpdate();
                    registrarAuditoria(conexion, idUsuarioSesion, accionAuditoria, "cita", "id_cita=" + idCita + ", estado=" + nuevoEstado);
                }
            } else {
                mensajeError = "La cita no existe.";
            }
        } catch (SQLException e) {
            mensajeError = "Error SQL: " + e.getMessage();
        } catch (Exception e) {
            mensajeError = "Error: " + e.getMessage();
        } finally {
            if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
            if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
        }
    }

    request.setAttribute("seccionActiva", "citas");
%>
<%@ include file="navbar.jspf" %>

    <div class="container mt-4">
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h2><i class="fas fa-calendar-alt"></i> Citas</h2>
            <a href="propiedades.jsp" class="btn btn-success">
                <i class="fas fa-plus"></i> Agendar nueva cita
            </a>
        </div>

        <% if (mensajeError != null) { %>
        <div class="alert alert-danger"><%= mensajeError %></div>
        <% } %>

        <div class="card">
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-striped table-hover">
                        <thead class="thead-dark">
                            <tr>
                                <th>ID</th>
                                <th>Propiedad</th>
                                <% if (!esCliente) { %><th>Cliente</th><% } %>
                                <th>Fecha y Hora</th>
                                <th>Estado</th>
                                <th>Observaciones</th>
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
            sql.append("SELECT c.id_cita, c.fecha_hora, c.estado, c.observaciones, p.id_propiedad, p.titulo AS propiedad, ");
            sql.append("per.nombres, per.apellidos ");
            sql.append("FROM cita c ");
            sql.append("JOIN propiedad p ON c.id_propiedad = p.id_propiedad AND p.baja_logica = 0 ");
            sql.append("LEFT JOIN perfil per ON c.id_cliente = per.id_usuario ");
            sql.append("WHERE 1=1 ");
            if (esCliente) {
                sql.append("AND c.id_cliente = ? ");
            }
            sql.append("ORDER BY c.fecha_hora DESC");

            ps = conexion.prepareStatement(sql.toString());
            if (esCliente) {
                ps.setInt(1, idUsuarioSesion);
            }
            rs = ps.executeQuery();
            while (rs.next()) {
                String nombreC = rs.getString("nombres") != null ? rs.getString("nombres") + " " + rs.getString("apellidos") : "---";
                String estado = rs.getString("estado");
%>
                            <tr>
                                <td><%= rs.getInt("id_cita") %></td>
                                <td><a href="propiedad_ver.jsp?id=<%= rs.getInt("id_propiedad") %>"><%= rs.getString("propiedad") %></a></td>
                                <% if (!esCliente) { %><td><%= nombreC %></td><% } %>
                                <td><%= rs.getString("fecha_hora") %></td>
                                <td>
                                    <span class="badge badge-<%= "CONFIRMADA".equals(estado) ? "success" : ("PENDIENTE".equals(estado) ? "warning" : ("CANCELADA".equals(estado) ? "danger" : "info")) %>">
                                        <%= estado %>
                                    </span>
                                </td>
                                <td><%= rs.getString("observaciones") != null ? rs.getString("observaciones") : "—" %></td>
                                <td class="text-nowrap">
<%                  if (!"CANCELADA".equals(estado) && !"REALIZADA".equals(estado)) { %>
                                    <a href="citas.jsp?accion=CANCELAR&id_cita=<%= rs.getInt("id_cita") %>" class="btn btn-sm btn-danger" title="Cancelar" onclick="return confirm('¿Cancelar esta cita?')">
                                        <i class="fas fa-times"></i>
                                    </a>
<%                  } %>
<%                  if ((esInmobiliaria || esAdministrador) && "PENDIENTE".equals(estado)) { %>
                                    <a href="citas.jsp?accion=CONFIRMAR&id_cita=<%= rs.getInt("id_cita") %>" class="btn btn-sm btn-success" title="Confirmar">
                                        <i class="fas fa-check"></i>
                                    </a>
<%                  } %>
<%                  if ((esInmobiliaria || esAdministrador) && ("PENDIENTE".equals(estado) || "CONFIRMADA".equals(estado))) { %>
                                    <a href="citas.jsp?accion=REALIZADA&id_cita=<%= rs.getInt("id_cita") %>" class="btn btn-sm btn-primary" title="Marcar realizada">
                                        <i class="fas fa-flag-checkered"></i>
                                    </a>
<%                  } %>
                                </td>
                            </tr>
<%
            }
        } catch (Exception e) {
            out.println("<tr><td colspan='7' class='text-center text-danger'>Error: " + e.getMessage() + "</td></tr>");
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