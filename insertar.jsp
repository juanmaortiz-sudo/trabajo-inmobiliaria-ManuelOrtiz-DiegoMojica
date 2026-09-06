<%@ page import="java.sql.Connection"%>
<%@ page import="java.sql.Statement"%>
<%@ page import="java.sql.DriverManager"%>
<%@ page import="java.sql.SQLException"%>

<%
String nombre = request.getParameter("nombre");
// Cambiar int por String para evitar problemas con números largos
String telefono = request.getParameter("telefono"); 

Connection conexion = null;
Statement sentencia = null;

int filas = 0;

<%-- Se incluye la lógica de conexión --%>
    <%@ include file="conexion.jspf" %>

    sentencia = conexion.createStatement();

    String consultaSQL = "INSERT INTO usuarios (nombre, telefono) VALUES ";
    consultaSQL += "('" + nombre + "', '" + telefono + "')";

    filas = sentencia.executeUpdate(consultaSQL);

    response.sendRedirect("mostrar.jsp");

} catch (ClassNotFoundException e) {
    out.println("Error accediendo a la Base de Datos: " + e.getMessage());
} catch (SQLException e) {
    out.println("Error SQL: " + e.getMessage());
} finally {
    if (sentencia != null) {
        try { sentencia.close(); }
        catch (SQLException e) {
            out.println("Error cerrando la sentencia: " + e.getMessage());
        }
    }
    if (conexion != null) {
        try { conexion.close(); }
        catch (SQLException e) {
            out.println("Error cerrando la conexión: " + e.getMessage());
        }
    }
}
%>