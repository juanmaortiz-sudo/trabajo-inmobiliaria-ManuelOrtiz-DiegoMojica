# AGENTS.md

JSP web app for XAMPP/Tomcat (inmobiliaria "parcial-1"). Raw JSPs deployed directly under
`C:\xampp\tomcat\webapps\parcial-1` — no build, no WAR, no Maven/Gradle. JSPs are compiled
and served by Tomcat at runtime.

## Running / verifying
- Deploy: just edit the `.jsp` files in place; Tomcat hot-reloads them. No compile/build step.
- DB is MariaDB (`inmobiliaria_db`) on `localhost:3306`, user `root`, empty password — set in `conexion.jspf`.
- JDBC driver: `WEB-INF/lib/mysql-connector-j-9.6.0.jar` (already present). Don't add another connector.
- Schema to re-import: `basededatos/inmobiliaria_db.sql` (MariaDB/phpMyAdmin dump).
- Profile photos upload to `/uploads` (created at runtime by `completar_registro.jsp`).

## Architecture / connections
- Every page that needs the DB starts with `<%@ include file="conexion.jspf" %>`. This fragment
  declares a local `Connection conexion` (and `java.sql.*` imports) driven by `request`. The
  including JSP must close `conexion` itself before output completes.
- DB-driven forms/selects are populated inline in the JSP with `PreparedStatement`/`Statement`.
- Passwords are SHA-256 hashed via a `hashSHA256()` JSP-declared method (both `registro.jsp` and `login.jsp` duplicate it; there is no shared module).
- `completar_registro.jsp` implements manual multipart/form-data parsing (no Servlet API helper) to handle photo uploads; saves files to `/uploads` and stores relative URL in `perfil.foto_url`.

## Auth / real flow (keep consistent)
- `registro.jsp` inserts `usuario` + `usuario_rol`, then redirects to `index.jsp` (login) or `completar_registro.jsp` if role is `cliente`.
- `login.jsp` validates against `usuario`/`rol` and stores session attributes `id_usuario`, `correo`, `rol`.
- `index.jsp` includes `conexion.jspf` and fetches `perfil` data for logged-in user.
- `cerrar_sesion.jsp` registers `CIERRA_SESION` audit event (via `funciones.jspf`) then invalidates session and redirects to `login.jsp`.
- Core tables: `usuario`, `rol`, `usuario_rol`, `perfil` (holds `nombres`, `apellidos`, `documento`,
  `telefono`, `direccion`, `foto_url`). `perfil.id_usuario` is unique per user.
- Role names are stored lowercase in DB but compared as uppercase strings in code (e.g. `"ACTIVO"`,
  `"SIN_ROL"`); the role select in `registro.jsp` excludes `administrador` via `LOWER(nombre) <> 'administrador'`.
- `usuario.estado` is an enum: `'ACTIVO'`, `'INACTIVO'`, `'BLOQUEADO'`; login checks for `'ACTIVO'`.

## Shared fragments
- `conexion.jspf` — opens `Connection conexion` per request (root/empty password, `inmobiliaria_db`).
  IMPORTANT: declares `String url` at method scope; do NOT redeclare a local `url` in any page that
  includes it (JPG compile error "Duplicate local variable url"). Use a distinct name (e.g. `urlImagen`).
- `funciones.jspf` — `registrarAuditoria(Connection, Integer idUsuario, String evento, String tabla, String detalle)`
  (never throws, so it can't break the main operation) and `escaparHtml(String)`.
- `navbar.jspf` — role-based menu; must receive `request.setAttribute("seccionActiva", "...")` before `<%@ include file="navbar.jspf" %>`.

## Database schema (full)
The SQL dump defines 16 tables. Auth-relevant: `usuario`, `rol`, `usuario_rol`, `perfil`.
Domain tables (wired in JSPs): `propiedad`, `ciudad`, `tipo_propiedad`, `inmobiliaria`,
`caracteristica`, `propiedad_caracteristica`, `imagen_propiedad`, `solicitud`,
`documento_solicitud`, `cita`, `favorito`, `auditoria`.
Real role for admin in DB is marked `admin` (id_rol 4); code accepts `admin` or `administrador`
via `equalsIgnoreCase`. Admin account in DB: `admin@admin.com` / password `admin`. Do not rename
or remove it; do not let public `registro.jsp` assign `admin`/`visitante`.

## Feature pages (all use conexion.jspf + funciones.jspf + navbar.jspf)
- Role access is checked per page: `CLIENTE` for favoritos/citas/solicitudes de cliente,
  `"admin"/"administrador"` for `roles.jsp`, `reporte_propiedades.jsp`, `auditoria.jsp`.
- `favorito_toggle.jsp` (CLIENTE only), `favoritos.jsp` (CLIENTE only).
- `cita_nueva.jsp` (CLIENTE): future date, no booking clash on the property (`estado IN ('PENDIENTE','CONFIRMADA')`)
  nor the client's own agenda; inserts `PENDIENTE`. `citas.jsp`: client sees own, inmobiliaria/admin see all
  and can confirm/mark REALIZADA; both can CANCELAR.
- `solicitud_nueva.jsp` (CLIENTE): manual multipart parser (helpers `leerCuerpo`/`separarPartes`/`findIndex`)
  like `completar_registro.jsp`; document names come from the multipart body, NOT `request.getParameter`
  (does not work for `multipart/form-data`); saves docs to `/uploads` as `doc_solic_<prop>_<ts>_<n>.ext`;
  requires >=1 document; inserts `EN_REVISION`; transaction + auditoría.
- `solicitudes.jsp`, `solicitud_ver.jsp` (inmobiliaria/admin approve/reject states `APROBADA`/`RECHAZADA`).
- `roles.jsp` (admin): assigns/revokes user roles; cannot revoke own admin role.
- `reporte_propiedades.jsp` (admin): aggregation KPIs + GROUP BY (ciudad,estado) / tipo_oferta /
  ciudad MIN-MAX-AVG / solicitudes y citas por estado.
- `auditoria.jsp` (admin): read-only log with filters correo/tabla, most recent 300.

## Testing
- `pruebas/PruebasInmobiliaria.java` — standalone Java harness (no framework), read-only SELECTs against the
  real DB. Compile/run with `pruebas\ejecutar_pruebas.cmd` or javac/direct javac/java using
  `WEB-INF\lib\mysql-connector-j-9.6.0.jar`. Correlate with `reporte_propiedades.jsp` queries when edited.

## Property CRUD
- `propiedades.jsp` — list with filters, links to create/view/edit/delete
- `propiedad_nueva.jsp` — create property with images (1:N via `imagen_propiedad`) and characteristics (N:M via `propiedad_caracteristica`); manual multipart parsing like `completar_registro.jsp`
- `propiedad_ver.jsp` — detail view with carousel for images, characteristics grid
- `propiedad_editar.jsp` — edit property, replace/delete images, update characteristics
- `propiedad_eliminar.jsp` — soft delete (sets `baja_logica=1`), removes images/files and relations
- All property pages require login (session `id_usuario`), use `conexion.jspf`, follow same patterns as auth pages

## Gotchas
- `assets/css/style.css` is referenced in the `<head>` of every page, but no `assets/` folder exists — it 404s silently. Bootstrap 4.6 and Font Awesome 5.15 come from CDN, not vendored.
- `insertar.jsp`, `actualizar.jsp`, `eliminar.jsp`, `modificar.jsp` are demo/CRUD stubs:
  - `insertar.jsp` references a non-existent `usuarios` table and `mostrar.jsp` — not part of the real flow. Don't model new code on it. Also has a syntax bug: missing `try` block opening brace.
  - `actualizar.jsp`, `eliminar.jsp`, `modificar.jsp` are 0-byte placeholders.
- No `WEB-INF/web.xml`; all routing is filename-based.
- Connections are not pooled; each request opens/closes its own via `conexion.jspf`.
- No centralized error handling or logging — exceptions are printed inline in HTML.
- Duplicate `hashSHA256()` method in `registro.jsp` and `login.jsp`; keep in sync if changed.
- Pages including `conexion.jspf` must NOT declare a local `String url` (JSP compile error). `propiedad_editar.jsp`
  and `propiedad_eliminar.jsp` use `urlImagen` for this reason.
- `reporte_propiedades.jsp` requires the `propiedad` table (currently 1 row in dev DB); the admin dashboard
  renders fine with near-empty data because of `COALESCE`/`GROUP BY`.
- `completar_registro.jsp` uses MySQL-specific `ON DUPLICATE KEY UPDATE` syntax for upsert.
- `perfil.direccion` column exists in DB but is not used in any JSP.
- `foto_url` in `perfil` table is nullable; profile photo is optional.