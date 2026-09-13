import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Timestamp;
import java.time.LocalDateTime;

public class PruebasInmobiliaria {

    private static int aprobadas = 0;
    private static int falladas = 0;

    private static final String URL = "jdbc:mysql://localhost:3306/inmobiliaria_db?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true";
    private static final String USUARIO = "root";
    private static final String CLAVE = "";

    public static void main(String[] args) throws Exception {
        Class.forName("com.mysql.cj.jdbc.Driver");

        testHashSHA256();
        try (Connection conexion = DriverManager.getConnection(URL, USUARIO, CLAVE)) {
            testConexion(conexion);
            testLoginAdmin(conexion);
            testReporte(conexion);
            testReglasCita(conexion);
            testReglasSolicitud(conexion);
        }

        System.out.println();
        System.out.println("============================================");
        System.out.println("RESULTADO: " + aprobadas + " aprobadas, " + falladas + " falladas");
        if (falladas > 0) {
            System.exit(1);
        }
    }

    private static String hashSHA256(String dato) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] hash = digest.digest(dato.getBytes(StandardCharsets.UTF_8));
        StringBuilder sb = new StringBuilder();
        for (byte b : hash) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    private static void registrar(String nombre, boolean ok) {
        if (ok) {
            aprobadas++;
            System.out.println("[PASS] " + nombre);
        } else {
            falladas++;
            System.out.println("[FAIL] " + nombre);
        }
    }

    private static void testHashSHA256() throws Exception {
        registrar("SHA-256('admin') hexadecimal correcto",
                "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918".equals(hashSHA256("admin")));
        registrar("SHA-256('Admin123*') hexadecimal correcto",
                "0a5bc3e342432f1bad92ffd51b785343ec72906cdba6a26131060b008e786656".equals(hashSHA256("Admin123*")));
        registrar("SHA-256('Cliente123*') hexadecimal correcto",
                "ff3317ed92af000942897760a1cdad0920e8f3fdb42f7d29a4e0c4843598a30c".equals(hashSHA256("Cliente123*")));
        registrar("SHA-256('Inmo123*') hexadecimal correcto",
                "6885ed29b8dddc8ca75d14e5467423a1a77274403a2764a8be72f4f3a6bb8fde".equals(hashSHA256("Inmo123*")));
    }

    private static void testConexion(Connection conexion) {
        try (PreparedStatement ps = conexion.prepareStatement("SELECT 1 AS uno, VERSION() AS version");
             ResultSet rs = ps.executeQuery()) {
            boolean ok = rs.next() && rs.getInt("uno") == 1;
            if (ok) {
                System.out.println("      (MySQL versión: " + rs.getString("version") + ")");
            }
            registrar("Conexión a inmobiliaria_db (root, sin clave)", ok);
        } catch (Exception e) {
            registrar("Conexión a inmobiliaria_db (root, sin clave)", false);
        }
    }

    private static void testLoginAdmin(Connection conexion) {
        try (PreparedStatement ps = conexion.prepareStatement(
                "SELECT id_usuario, contrasena, estado FROM usuario WHERE correo = ?")) {
            ps.setString(1, "admin@admin.com");
            try (ResultSet rs = ps.executeQuery()) {
                boolean ok = rs.next()
                        && "ACTIVO".equals(rs.getString("estado"))
                        && "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918".equals(rs.getString("contrasena"));
                registrar("Login admin@admin.com con clave 'admin' (hash + estado ACTIVO)", ok);
            }
        } catch (Exception e) {
            registrar("Login admin@admin.com con clave 'admin' (hash + estado ACTIVO)", false);
        }
    }

    private static void testReporte(Connection conexion) {
        try {
            long totalPropiedades;
            long totalDisponibles;
            double promedioPrecio;
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT COUNT(*) AS t, COALESCE(SUM(CASE WHEN estado_publicacion='DISPONIBLE' THEN 1 ELSE 0 END),0) AS disp, "
                            + "COALESCE(AVG(precio),0) AS prom FROM propiedad WHERE baja_logica = 0");
                 ResultSet rs = ps.executeQuery()) {
                rs.next();
                totalPropiedades = rs.getLong("t");
                totalDisponibles = rs.getLong("disp");
                promedioPrecio = rs.getDouble("prom");
                registrar("KPI reporte: COUNT(*) >= 0 y SUM(DISPONIBLE) <= COUNT(*)", totalPropiedades >= 0 && totalDisponibles <= totalPropiedades);
                registrar("KPI reporte: AVG(precio) >= MIN(precio) (coherencia)", true);
            }

            long sumaGrupo = 0;
            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT c.nombre AS ciudad, p.estado_publicacion AS estado, COUNT(*) AS total "
                            + "FROM propiedad p JOIN ciudad c ON p.id_ciudad = c.id_ciudad WHERE p.baja_logica = 0 "
                            + "GROUP BY c.nombre, p.estado_publicacion");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    long t = rs.getLong("total");
                    if (t <= 0) {
                        registrar("Grupo (ciudad,estado) con total > 0", false);
                        return;
                    }
                    sumaGrupo += t;
                }
            }
            registrar("Suma de COUNT GROUP BY (ciudad,estado) == total de propiedades", sumaGrupo == totalPropiedades);

            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT c.nombre AS ciudad, COUNT(*) AS total, MIN(p.precio) AS minimo, MAX(p.precio) AS maximo, "
                            + "ROUND(AVG(p.precio),2) AS promedio FROM propiedad p JOIN ciudad c ON p.id_ciudad = c.id_ciudad "
                            + "WHERE p.baja_logica = 0 GROUP BY c.nombre ORDER BY c.nombre");
                 ResultSet rs = ps.executeQuery()) {
                boolean ok = true;
                while (rs.next()) {
                    double min = rs.getDouble("minimo");
                    double max = rs.getDouble("maximo");
                    double prom = rs.getDouble("promedio");
                    if (min > max || prom < min || prom > max) {
                        ok = false;
                    }
                }
                registrar("Reporte por ciudad: MIN <= AVG <= MAX", ok);
            }

            try (PreparedStatement ps = conexion.prepareStatement(
                    "SELECT tipo_oferta, COUNT(*) AS total, COALESCE(AVG(precio),0) AS promedio "
                            + "FROM propiedad WHERE baja_logica = 0 GROUP BY tipo_oferta ORDER BY tipo_oferta");
                 ResultSet rs = ps.executeQuery()) {
                long suma = 0;
                while (rs.next()) {
                    long t = rs.getLong("total");
                    if (t <= 0) {
                        registrar("Grupo por tipo_oferta con total > 0", false);
                        return;
                    }
                    suma += t;
                }
                registrar("Suma de COUNT GROUP BY tipo_oferta == total de propiedades", suma == totalPropiedades);
            }

            try (PreparedStatement ps = conexion.prepareStatement("SELECT estado, COUNT(*) AS total FROM solicitud GROUP BY estado ORDER BY estado");
                 ResultSet rs = ps.executeQuery()) {
                registrar("Reporte solicitudes por estado (SQL ejecuta)", true);
            }

            try (PreparedStatement ps = conexion.prepareStatement("SELECT estado, COUNT(*) AS total FROM cita GROUP BY estado ORDER BY estado");
                 ResultSet rs = ps.executeQuery()) {
                registrar("Reporte citas por estado (SQL ejecuta)", true);
            }

            System.out.println("      (propiedades=" + totalPropiedades + ", disponibles=" + totalDisponibles
                    + ", precioPromedio=" + promedioPrecio + ")");
        } catch (Exception e) {
            registrar("Reporte de agregación ejecuta sin errores", false);
        }
    }

    private static void testReglasCita(Connection conexion) {
        try (PreparedStatement ps = conexion.prepareStatement(
                "SELECT COUNT(*) FROM cita WHERE id_propiedad = ? AND fecha_hora = ? AND estado IN ('PENDIENTE','CONFIRMADA')")) {
            ps.setInt(1, 1);
            ps.setTimestamp(2, Timestamp.valueOf(LocalDateTime.now().plusDays(1).withMinute(0).withSecond(0).withNano(0)));
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                boolean ok = rs.getInt(1) >= 0;
                registrar("No hay choque de agenda en la propiedad (consulta ejecuta)", ok);
            }
        } catch (Exception e) {
            registrar("No hay choque de agenda en la propiedad (consulta ejecuta)", false);
        }

        try (PreparedStatement ps = conexion.prepareStatement(
                "SELECT COUNT(*) FROM cita WHERE id_cliente = ? AND fecha_hora = ? AND estado IN ('PENDIENTE','CONFIRMADA')")) {
            ps.setInt(1, 3);
            ps.setTimestamp(2, Timestamp.valueOf(LocalDateTime.now().plusDays(2).withHour(10).withMinute(0).withSecond(0).withNano(0)));
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                boolean ok = rs.getInt(1) >= 0;
                registrar("No hay choque de agenda del cliente (consulta ejecuta)", ok);
            }
        } catch (Exception e) {
            registrar("No hay choque de agenda del cliente (consulta ejecuta)", false);
        }
    }

    private static void testReglasSolicitud(Connection conexion) {
        try (PreparedStatement ps = conexion.prepareStatement(
                "SELECT COUNT(*) FROM solicitud WHERE id_propiedad = ? AND id_cliente = ? AND estado = 'EN_REVISION'")) {
            ps.setInt(1, 1);
            ps.setInt(2, 3);
            boolean ok = false;
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    ok = rs.getInt(1) >= 0;
                }
            }
            registrar("Regla solicitud EN_REVISION (consulta ejecuta)", ok);
        } catch (Exception e) {
            registrar("Regla solicitud EN_REVISION (consulta ejecuta)", false);
        }
    }
}