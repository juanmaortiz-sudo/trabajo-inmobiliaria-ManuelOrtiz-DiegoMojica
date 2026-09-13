<%@ page import="java.sql.Connection"%>
<%@ page import="java.sql.PreparedStatement"%>
<%@ page import="java.sql.ResultSet"%>
<%@ page import="java.sql.SQLException"%>
<%@ page import="java.sql.Timestamp"%>
<%@ page import="java.sql.Statement"%>
<%@ page import="java.text.SimpleDateFormat"%>
<%@ page import="java.util.Date"%>
<!DOCTYPE html>
<html lang="es">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.6.0/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
    <link rel="stylesheet" href="assets/css/style.css">
    <title>Agendar Cita</title>
</head>

<body>

<%@ include file="conexion.jspf" %>
<%@ include file="funciones.jspf" %>

<%
    Integer idUsuarioSesion = (Integer) session.getAttribute("id_usuario");
    String rolSesion = (String) session.getAttribute("rol");
    boolean esCliente = "cliente".equalsIgnoreCase(rolSesion);

    if (idUsuarioSesion == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    String idParam = request.getParameter("id");
    int idPropiedad = 0;
    try { idPropiedad = Integer.parseInt(idParam); } catch (NumberFormatException e) { idPropiedad = 0; }

    String tituloPropiedad = "";
    String tipoOfertaPropiedad = "";
    String ciudadPropiedad = "";
    String precioPropiedad = "";

    if (conexion != null && idPropiedad > 0) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conexion.prepareStatement("SELECT p.titulo, p.tipo_oferta, p.precio, c.nombre AS ciudad " +
                                           "FROM propiedad p LEFT JOIN ciudad c ON p.id_ciudad = c.id_ciudad " +
                                           "WHERE p.id_propiedad = ? AND p.baja_logica = 0");
            ps.setInt(1, idPropiedad);
            rs = ps.executeQuery();
            if (rs.next()) {
                tituloPropiedad = rs.getString("titulo");
                tipoOfertaPropiedad = rs.getString("tipo_oferta");
                ciudadPropiedad = rs.getString("ciudad") != null ? rs.getString("ciudad") : "---";
                precioPropiedad = rs.getString("precio");
            } else {
                response.sendRedirect("propiedades.jsp");
                return;
            }
        } catch (Exception e) { } finally {
            if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
            if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
        }
    }

    String mensajeError = null;
    String mensajeExito = null;

    if ("POST".equalsIgnoreCase(request.getMethod()) && idPropiedad > 0) {
        String fecha = request.getParameter("fecha") != null ? request.getParameter("fecha").trim() : "";
        String hora = request.getParameter("hora") != null ? request.getParameter("hora").trim() : "";
        String observaciones = request.getParameter("observaciones") != null ? request.getParameter("observaciones").trim() : "";

        if (fecha.isEmpty() || hora.isEmpty()) {
            mensajeError = "Debe seleccionar fecha y hora para la cita.";
        } else {
            Timestamp fechaHora = null;
            try {
                String[] partes = hora.split(":");
                String horaSeg = partes[0] + ":" + partes[1] + ":00";
                fechaHora = Timestamp.valueOf(fecha + " " + horaSeg);
            } catch (Exception e) {
                fechaHora = null;
            }

            if (fechaHora == null) {
                mensajeError = "La fecha u hora ingresada no es válida.";
            } else if (!fechaHora.after(new Date())) {
                mensajeError = "La cita debe programarse en una fecha y hora futura.";
            } else {
                PreparedStatement ps = null;
                ResultSet rs = null;
                PreparedStatement psInsert = null;
                try {
                    conexion.setAutoCommit(false);

                    ps = conexion.prepareStatement("SELECT COUNT(*) FROM cita WHERE id_propiedad = ? AND fecha_hora = ?");
                    ps.setInt(1, idPropiedad);
                    ps.setTimestamp(2, fechaHora);
                    rs = ps.executeQuery();
                    rs.next();
                    int ocupadas = rs.getInt(1);
                    rs.close();
                    rs = null;
                    ps.close();
                    ps = null;

                    if (ocupadas > 0) {
                        mensajeError = "Ya existe una cita para esta propiedad en ese horario. Seleccione otro horario.";
                    } else {
                        ps = conexion.prepareStatement("SELECT COUNT(*) FROM cita WHERE id_cliente = ? AND fecha_hora = ? AND estado IN ('PENDIENTE','CONFIRMADA')");
                        ps.setInt(1, idUsuarioSesion);
                        ps.setTimestamp(2, fechaHora);
                        rs = ps.executeQuery();
                        rs.next();
                        int propias = rs.getInt(1);
                        rs.close();
                        rs = null;
                        ps.close();
                        ps = null;

                        if (propias > 0) {
                            mensajeError = "Ya tiene una cita programada para ese horario. No puede cruzar sus agendas.";
                        } else {
                            psInsert = conexion.prepareStatement("INSERT INTO cita (id_propiedad, id_cliente, fecha_hora, estado, observaciones) VALUES (?, ?, ?, 'PENDIENTE', ?)");
                            psInsert.setInt(1, idPropiedad);
                            psInsert.setInt(2, idUsuarioSesion);
                            psInsert.setTimestamp(3, fechaHora);
                            psInsert.setString(4, observaciones);
                            psInsert.executeUpdate();

                            registrarAuditoria(conexion, idUsuarioSesion, "CREA_CITA", "cita",
                                    "id_propiedad=" + idPropiedad + ", fecha_hora=" + fechaHora);

                            conexion.commit();
                            mensajeExito = "Cita solicitada correctamente. Queda pendiente de confirmación.";
                        }
                    }
                } catch (SQLException e) {
                    mensajeError = "Error al guardar la cita: " + e.getMessage();
                    try { if (conexion != null) conexion.rollback(); } catch (SQLException ex) { }
                } catch (Exception e) {
                    mensajeError = "Error: " + e.getMessage();
                    try { if (conexion != null) conexion.rollback(); } catch (SQLException ex) { }
                } finally {
                    if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
                    if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
                    if (psInsert != null) { try { psInsert.close(); } catch (SQLException e) { } }
                    if (conexion != null) { try { conexion.setAutoCommit(true); } catch (SQLException e) { } }
                }
            }
        }
    }

    request.setAttribute("seccionActiva", "citas");

    SimpleDateFormat sdfFecha = new SimpleDateFormat("yyyy-MM-dd");
    String hoy = sdfFecha.format(new Date());
%>
<%@ include file="navbar.jspf" %>

    <div class="container mt-4">
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h2><i class="fas fa-calendar-plus"></i> Agendar Cita</h2>
            <a href="propiedad_ver.jsp?id=<%= idPropiedad %>" class="btn btn-secondary">Volver a la propiedad</a>
        </div>

        <% if (mensajeError != null) { %>
        <div class="alert alert-danger"><%= mensajeError %></div>
        <% } %>
        <% if (mensajeExito != null) { %>
        <div class="alert alert-success">
            <%= mensajeExito %>
            <div class="mt-2">
                <a href="citas.jsp" class="btn btn-primary btn-sm">Ver mis citas</a>
                <a href="propiedades.jsp" class="btn btn-outline-secondary btn-sm">Buscar otra propiedad</a>
            </div>
        </div>
        <% } else { %>

        <div class="card mb-4">
            <div class="card-header bg-success text-white">
                <h5 class="mb-0">Propiedad seleccionada</h5>
            </div>
            <div class="card-body">
                <div class="d-flex justify-content-between align-items-center">
                    <div>
                        <h5 class="mb-1"><%= tituloPropiedad %></h5>
                        <span class="text-muted"><i class="fas fa-map-marker-alt"></i> <%= ciudadPropiedad %> &nbsp;|&nbsp; <%= tipoOfertaPropiedad %></span>
                    </div>
                    <div class="h4 text-success font-weight-bold">$<%= precioPropiedad %></div>
                </div>
            </div>
        </div>

        <div class="card">
            <div class="card-header">
                <h5 class="mb-0">Disponibilidad</h5>
            </div>
            <div class="card-body">
                <% if (esCliente) { %>
                <div class="alert alert-info">
                    <i class="fas fa-info-circle"></i> La cita se crea como <strong>PENDIENTE</strong> y debe ser confirmada por la inmobiliaria.
                </div>
                <% } %>
                <form method="post" action="cita_nueva.jsp?id=<%= idPropiedad %>">
                    <div class="row">
                        <div class="col-md-4 mb-3">
                            <label>Fecha *</label>
                            <input type="date" class="form-control" name="fecha" min="<%= hoy %>" required>
                        </div>
                        <div class="col-md-4 mb-3">
                            <label>Hora *</label>
                            <input type="time" class="form-control" name="hora" required>
                        </div>
                        <div class="col-md-4 mb-3">
                            <label>Observaciones</label>
                            <input type="text" class="form-control" name="observaciones" maxlength="200" placeholder="Ej: Estoy disponible por la tarde">
                        </div>
                    </div>
                    <button type="submit" class="btn btn-success btn-lg">
                        <i class="fas fa-calendar-check"></i> Solicitar cita
                    </button>
                </form>
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