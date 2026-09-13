# Inmobiliaria — parcial-1

Aplicación web Java/JSP para una inmobiliaria, desplegada directamente en
XAMPP/Tomcat (sin Maven/Gradle ni WAR). Backend: JSP clásicos (scriptlets) +
MariaDB. Frontend: Bootstrap 4.6 y Font Awesome 5.15 vía CDN.

## Requisitos

- XAMPP con Tomcat 8.5 y MariaDB 10.4+ en `localhost:3306`, usuario `root` sin clave.
- JSPs desplegados bajo `C:\xampp\tomcat\webapps\parcial-1` (recarga en caliente).
- Driver: `WEB-INF/lib/mysql-connector-j-9.6.0.jar` (incluido).

## Instalación

1. Copiar la carpeta a `C:\xampp\tomcat\webapps\parcial-1`.
2. Importar la base de datos desde `basededatos/inmobiliaria_db.sql` (phpMyAdmin o
   `mysql -uroot < basededatos/inmobiliaria_db.sql`). Se usa la BD `inmobiliaria_db`.
3. Arrancar Tomcat y MariaDB (XAMPP Control Panel).
4. Acceder a `http://localhost:8080/parcial-1/login.jsp`.

## Cuentas de acceso (ya existentes en la BD)

| Rol          | Correo                    | Contraseña |
|--------------|---------------------------|------------|
| Administrador | admin@admin.com           | admin      |
| Cliente      | damojica@uts.edu.co       | (contraseña del usuario; ver BD) |
| Inmobiliaria  | manuelhernadez814@gmail.com | (contraseña del usuario; ver BD) |

Nota: las contraseñas se almacenan como SHA-256 en `usuario.contrasena`. El
registro público (`registro.jsp`) permite crear clientes nuevos; el rol
`administrador` no puede autoasignarse desde el registro.

## Funcionalidades implementadas

- **Autenticación**: `login.jsp`, `registro.jsp` (con verificación de rol),
  `completar_registro.jsp` (datos del perfil + foto), `cerrar_sesion.jsp`.
- **Propiedades**: `propiedades.jsp` (listado/filtros), `propiedad_nueva.jsp`,
  `propiedad_ver.jsp`, `propiedad_editar.jsp`, `propiedad_eliminar.jsp`
  (baja lógica `baja_logica=1`). Imágenes 1:N y características N:M.
- **Favoritos (cliente)**: `favorito_toggle.jsp`, `favoritos.jsp`.
- **Citas (cliente)**: `cita_nueva.jsp`, `citas.jsp`. Flujo de estados
  `PENDIENTE → CONFIRMADA → REALIZADA / CANCELADA`; valida que la fecha sea
  futura y que no haya choque de agenda (misma propiedad/horario o cita propia).
- **Solicitudes y documentos (cliente)**: `solicitud_nueva.jsp` (subida de
  documentos por multipart manual), `solicitudes.jsp`, `solicitud_ver.jsp`
  (inmobiliaria/admin aprueban o rechazan). Estado `EN_REVISION`.
- **Administración de roles**: `roles.jsp` (asignar/revocar roles; el admin no
  puede autocambiarse).
- **Reportes (admin)**: `reporte_propiedades.jsp` — agregaciones con
  `COUNT/GROUP BY`, `SUM`, `AVG`, `MIN`, `MAX` por ciudad/estado/tipo de oferta,
  KPIs y estados de solicitudes/citas.
- **Auditoría (admin)**: `auditoria.jsp` — bitácora `auditoria` de todos los
  eventos (login, alta de propiedades, citas, solicitudes, favoritos, etc.) con
  filtros por correo/tabla. Registrada por `funciones.jspf#registrarAuditoria`.

## Estructura

- `conexion.jspf` — conexión JDBC compartida (root, sin clave, BD `inmobiliaria_db`).
- `funciones.jspf` — `registrarAuditoria(...)` y `escaparHtml(...)`.
- `navbar.jspf` — menú por rol (cliente / inmobiliaria / administrador / anónimo).
- `uploads/` — fotos de perfil, imágenes de propiedades y documentos de solicitudes.
- `pruebas/` — harness de pruebas unitarias (Java standalone).

## Pruebas unitarias

Harness Java standalone en `pruebas/PruebasInmobiliaria.java` (16 casos), contra
la BD real y solo con consultas `SELECT` (no modifica datos). Verifica: algoritmo
SHA-256, conexión, login del admin, consultas de agregación del reporte y
reglas de negocio de citas/solicitudes.

Ejecutar:

```
cd C:\xampp\tomcat\webapps\parcial-1
pruebas\ejecutar_pruebas.cmd
```

Requiere que Tomcat/MariaDB estén corriendo y el JAR del conector en
`WEB-INF/lib`.