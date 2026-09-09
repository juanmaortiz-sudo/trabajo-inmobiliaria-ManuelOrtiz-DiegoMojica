<%@ page import="javax.servlet.http.HttpSession" %>
<%
    HttpSession sesion = request.getSession(false);
    if (sesion != null) {
        sesion.invalidate();
    }
    response.sendRedirect(request.getContextPath() + "/login.jsp");
%>