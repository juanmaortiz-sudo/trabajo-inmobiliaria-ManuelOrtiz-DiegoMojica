<%@ page import="java.sql.Connection"%>
<%@ page import="java.sql.PreparedStatement"%>
<%@ page import="java.sql.ResultSet"%>
<%@ page import="java.sql.SQLException"%>

<%@ include file="conexion.jspf" %>
<%@ include file="funciones.jspf" %>

<%
    Integer idUsuarioSesion = (Integer) session.getAttribute("id_usuario");
    String rolSesion = (String) session.getAttribute("rol");

    if (idUsuarioSesion == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    if (rolSesion == null || !"CLIENTE".equalsIgnoreCase(rolSesion)) {
        response.sendRedirect("propiedades.jsp");
        return;
    }

    String idParam = request.getParameter("id");
    int idPropiedad = 0;
    try { idPropiedad = Integer.parseInt(idParam); } catch (NumberFormatException e) { idPropiedad = 0; }
    String accion = request.getParameter("accion") != null ? request.getParameter("accion") : "agregar";

    String volver = request.getParameter("volver");
    String destino = (volver != null && "favoritos".equals(volver)) ? "favoritos.jsp" : "propiedad_ver.jsp?id=" + idPropiedad;

    if (idPropiedad > 0 && conexion != null) {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conexion.prepareStatement("SELECT id_propiedad FROM propiedad WHERE id_propiedad = ? AND baja_logica = 0");
            ps.setInt(1, idPropiedad);
            rs = ps.executeQuery();
            if (rs.next()) {
                if ("quitar".equals(accion)) {
                    ps = conexion.prepareStatement("DELETE FROM favorito WHERE id_usuario = ? AND id_propiedad = ?");
                    ps.setInt(1, idUsuarioSesion);
                    ps.setInt(2, idPropiedad);
                    ps.executeUpdate();
                    registrarAuditoria(conexion, idUsuarioSesion, "QUITA_FAVORITO", "favorito", "id_propiedad=" + idPropiedad);
                } else {
                    ps = conexion.prepareStatement("INSERT INTO favorito (id_usuario, id_propiedad) VALUES (?, ?) ON DUPLICATE KEY UPDATE fecha_guardado = CURRENT_TIMESTAMP");
                    ps.setInt(1, idUsuarioSesion);
                    ps.setInt(2, idPropiedad);
                    ps.executeUpdate();
                    registrarAuditoria(conexion, idUsuarioSesion, "AGREGA_FAVORITO", "favorito", "id_propiedad=" + idPropiedad);
                }
            }
        } catch (SQLException e) {
        } finally {
            if (rs != null) { try { rs.close(); } catch (SQLException e) { } }
            if (ps != null) { try { ps.close(); } catch (SQLException e) { } }
        }
    }

    response.sendRedirect(destino);
%>