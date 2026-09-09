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
- `cerrar_sesion.jsp` invalidates session and redirects to `login.jsp`.
- Core tables: `usuario`, `rol`, `usuario_rol`, `perfil` (holds `nombres`, `apellidos`, `documento`,
  `telefono`, `direccion`, `foto_url`). `perfil.id_usuario` is unique per user.
- Role names are stored lowercase in DB but compared as uppercase strings in code (e.g. `"ACTIVO"`,
  `"SIN_ROL"`); the role select in `registro.jsp` excludes `administrador` via `LOWER(nombre) <> 'administrador'`.
- `usuario.estado` is an enum: `'ACTIVO'`, `'INACTIVO'`, `'BLOQUEADO'`; login checks for `'ACTIVO'`.

## Database schema (full)
The SQL dump defines 16 tables. Auth-relevant: `usuario`, `rol`, `usuario_rol`, `perfil`.
Domain tables (now wired in JSPs): `propiedad`, `ciudad`, `tipo_propiedad`, `inmobiliaria`,
`caracteristica`, `propiedad_caracteristica`, `imagen_propiedad`.
Other domain tables (not yet wired): `solicitud`, `documento_solicitud`, `cita`, `favorito`, `auditoria`.

## Property CRUD (new)
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
- `completar_registro.jsp` uses MySQL-specific `ON DUPLICATE KEY UPDATE` syntax for upsert.
- `perfil.direccion` column exists in DB but is not used in any JSP.
- `foto_url` in `perfil` table is nullable; profile photo is optional.