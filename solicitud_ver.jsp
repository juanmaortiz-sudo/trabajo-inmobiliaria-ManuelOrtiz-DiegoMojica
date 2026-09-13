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
    <title>Ver Solicitud</title>
</head>

<body>

<%@ include file="conexion.jspf" %>
<%@ include file="funciones.jspf" %>

<%
    Integer idUsuarioSesion = (Integer) session.getAttribute("id_usuario");
    String rolSesion = (String) session.getAttribute("rol");
    boolean esInmobiliaria = "inmobiliaria".equalsIgnoreCase(rolSesion);
    boolean esAdministrador = "admin".equalsIgnoreCase(rolSesion) || "administrador".equalsIgnoreCase(rolSesion);
    boolean puedeGestionar = esInmobiliaria || esAdministrador;

    if (idUsuarioSesion == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    String idParam = request.getParameter("id");
    int idSolicitud = 0;
    try { idSolicitud = Integer.parseInt(idParam); } catch (NumberFormatException e) { idSolicitud = 0; }

    if (idSolicitud == 0) {
        response.sendRedirect("solicitudes.jsp");
        return;
    }

    String mensajeExito = null;
    String mensajeError = null;
    String accion = request.getParameter("accion");

    if (accion != null && ("APROBAR".equals(accion) || "RECHAZAR".equals(accion)) && puedeGestionar && conexion != null) {
        PreparedStatement ps = null;
        try {
            String nuevoEstado = "APROBAR".equals(accion) ? "APROBADA" : "RECHAZADA";
            ps = conexion.prepareStatement("UPDATE solicitud SET estado = ? WHERE id_solicitud = ?");
            ps.setString(1, nuevoEstado);
            ps.setInt(2, idSolicitud);
            ps.executeUpdate();
            registrarAuditoria(conexion, idUsuarioSesion, "APROBAR".equals(accion) ? "APRUEBA_SOLICITUD" : "RECHAZA_SOLICITUD",
                    "solicitud", "id_solicitud=" + idSolicitud + ", estado=" + nuevoEstado);
            mensajeExito = "Solicitud " + ( "APROBAR".equals(accion) ? "aprobada" : "rechazada") + " correctamente.";
        } catch (Exception e) {
            mensajeError = "Error: " + e.getMessage();
        } finally {
            if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
        }
    }

    String estadoActual = "";
    String tipoSolicitud = "";
    String fechaSolicitud = "";
    String tituloPropiedad = "";
    String direccionPropiedad = "";
    int idPropiedad = 0;
    String nombreCliente = "---";
    String correoCliente = "---";
    java.util.List<String[]> documentos = new java.util.ArrayList<>();

    if (conexion != null) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conexion.prepareStatement(
                "SELECT s.estado, s.tipo_solicitud, s.fecha_solicitud, s.id_propiedad, p.titulo, p.direccion, " +
                "u.correo, per.nombres, per.apellidos " +
                "FROM solicitud s " +
                "JOIN propiedad p ON s.id_propiedad = p.id_propiedad " +
                "JOIN usuario u ON s.id_cliente = u.id_usuario " +
                "LEFT JOIN perfil per ON s.id_cliente = per.id_usuario " +
                "WHERE s.id_solicitud = ?");
            ps.setInt(1, idSolicitud);
            rs = ps.executeQuery();
            if (rs.next()) {
                estadoActual = rs.getString("estado");
                tipoSolicitud = rs.getString("tipo_solicitud");
                fechaSolicitud = rs.getString("fecha_solicitud");
                idPropiedad = rs.getInt("id_propiedad");
                tituloPropiedad = rs.getString("titulo");
                direccionPropiedad = rs.getString("direccion") != null ? rs.getString("direccion") : "---";
                correoCliente = rs.getString("correo") != null ? rs.getString("correo") : "---";
                if (rs.getString("nombres") != null) {
                    nombreCliente = rs.getString("nombres") + " " + rs.getString("apellidos");
                }
            } else {
                response.sendRedirect("solicitudes.jsp");
                return;
            }
            rs.close();
            ps.close();

            ps = conexion.prepareStatement("SELECT nombre_documento, url_archivo FROM documento_solicitud WHERE id_solicitud = ? ORDER BY id_documento");
            ps.setInt(1, idSolicitud);
            rs = ps.executeQuery();
            while (rs.next()) {
                documentos.add(new String[] { rs.getString("nombre_documento"), rs.getString("url_archivo") });
            }
        } catch (Exception e) {
            mensajeError = "Error: " + e.getMessage();
        } finally {
            if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
            if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
        }
    }

    request.setAttribute("seccionActiva", "solicitudes");
%>
<%@ include file="navbar.jspf" %>

    <div class="container mt-4">
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h2><i class="fas fa-file-contract"></i> Solicitud #<%= idSolicitud %></h2>
            <a href="solicitudes.jsp" class="btn btn-secondary">Volver</a>
        </div>

        <% if (mensajeExito != null) { %>
        <div class="alert alert-success"><%= mensajeExito %></div>
        <% } %>
        <% if (mensajeError != null) { %>
        <div class="alert alert-danger"><%= mensajeError %></div>
        <% } %>

        <div class="row">
            <div class="col-md-6">
                <div class="card mb-4">
                    <div class="card-header bg-success text-white">
                        <h5 class="mb-0">Información de la solicitud</h5>
                    </div>
                    <div class="card-body">
                        <table class="table table-borderless mb-0">
                            <tr><th width="35%">Estado:</th><td>
                                <span class="badge badge-<%= "APROBADA".equals(estadoActual) ? "success" : ("RECHAZADA".equals(estadoActual) ? "danger" : "warning") %>">
                                    <%= estadoActual %>
                                </span>
                            </td></tr>
                            <tr><th>Tipo:</th><td><span class="badge badge-info"><%= tipoSolicitud %></span></td></tr>
                            <tr><th>Fecha:</th><td><%= fechaSolicitud %></td></tr>
                            <tr><th>Propiedad:</th><td><a href="propiedad_ver.jsp?id=<%= idPropiedad %>"><%= tituloPropiedad %></a></td></tr>
                            <tr><th>Dirección:</th><td><%= direccionPropiedad %></td></tr>
                            <tr><th>Cliente:</th><td><%= nombreCliente %></td></tr>
                            <tr><th>Correo:</th><td><%= correoCliente %></td></tr>
                        </table>
                    </div>
                </div>
            </div>

            <div class="col-md-6">
                <div class="card mb-4">
                    <div class="card-header bg-success text-white">
                        <h5 class="mb-0">Documentos radicados (<%= documentos.size() %>)</h5>
                    </div>
                    <div class="card-body">
                        <% if (documentos.isEmpty()) { %>
                        <p class="text-muted mb-0">No hay documentos adjuntos.</p>
                        <% } else { %>
                        <div class="list-group">
                            <% for (String[] doc : documentos) { %>
                            <div class="list-group-item d-flex justify-content-between align-items-center">
                                <span><i class="fas fa-paperclip text-muted"></i> <%= doc[0] %></span>
                                <a href="<%= doc[1] %>" target="_blank" class="btn btn-sm btn-outline-primary">
                                    <i class="fas fa-download"></i> Ver
                                </a>
                            </div>
                            <% } %>
                        </div>
                        <% } %>

                        <% if (puedeGestionar && "EN_REVISION".equals(estadoActual)) { %>
                        <hr>
                        <p class="text-muted">Decida si la solicitud se aprueba (pasa a negociación) o se rechaza:</p>
                        <div class="d-flex">
                            <form method="post" action="solicitud_ver.jsp?id=<%= idSolicitud %>" class="mr-2">
                                <input type="hidden" name="accion" value="APROBAR">
                                <button type="submit" class="btn btn-success">
                                    <i class="fas fa-check"></i> Aprobar
                                </button>
                            </form>
                            <form method="post" action="solicitud_ver.jsp?id=<%= idSolicitud %>">
                                <input type="hidden" name="accion" value="RECHAZAR">
                                <button type="submit" class="btn btn-danger" onclick="return confirm('¿Rechazar esta solicitud?')">
                                    <i class="fas fa-times"></i> Rechazar
                                </button>
                            </form>
                        </div>
                        <% } else if (puedeGestionar) { %>
                        <div class="alert alert-info mt-3 mb-0">
                            <i class="fas fa-info-circle"></i> Esta solicitud ya fue resuelta (estado <%= estadoActual %>).
                        </div>
                        <% } %>
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