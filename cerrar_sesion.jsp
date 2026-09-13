<%@ page import="javax.servlet.http.HttpSession" %>
<%@ include file="conexion.jspf" %>
<%@ include file="funciones.jspf" %>
<%
    Integer idUsuario = (Integer) session.getAttribute("id_usuario");
    if (conexion != null) {
        registrarAuditoria(conexion, idUsuario, "CIERRA_SESION", "usuario", "sesion_cerrada");
    }
    if (conexion != null) {
        try { conexion.close(); } catch (SQLException e) { }
    }
    HttpSession sesion = request.getSession(false);
    if (sesion != null) {
        sesion.invalidate();
    }
    response.sendRedirect("login.jsp");
%>