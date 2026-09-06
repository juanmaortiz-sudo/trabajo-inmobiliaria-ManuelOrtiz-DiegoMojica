# AGENTS.md

JSP web app for XAMPP/Tomcat (inmobiliaria "parcial-1"). Raw JSPs deployed directly under
`C:\xampp\tomcat\webapps\parcial-1` — no build, no WAR, no Maven/Gradle. JSPs are compiled
and served by Tomcat at runtime.

## Running / verifying
- Deploy: just edit the `.jsp` files in place; Tomcat hot-reloads them. No compile/build step.
- DB is MariaDB (`inmobiliaria_db`) on `localhost:3306`, user `root`, empty password — set in `conexion.jspf`.
- JDBC driver: `WEB-INF/lib/mysql-connector-j-9.6.0.jar` (already present). Don't add another connector.
- Schema to re-import: `basededatos/inmobiliaria_db.sql` (MariaDB/phpMyAdmin dump).

## Architecture / connections
- Every page that needs the DB starts with `<%@ include file="conexion.jspf" %>`. This fragment
  declares a local `Connection conexion` (and `java.sql.*` imports) driven by `request`. The
  including JSP must close `conexion` itself before output completes.
- DB-driven forms/selects are populated inline in the JSP with `PreparedStatement`/`Statement`.
- Passwords are SHA-256 hashed via a `hashSHA256()` JSP-declared method (both `registro.jsp` and `login.jsp` duplicate it; there is no shared module).

## Auth / real flow (keep consistent)
- `registro.jsp` inserts `usuario` + `usuario_rol`, then redirects to `index.jsp` (login).
- `login.jsp` validates against `usuario`/`rol` and stores session attributes `id_usuario`, `correo`, `rol`.
- Core tables: `usuario`, `rol`, `usuario_rol`, `perfil` (holds `nombres`, `apellidos`, `documento`,
  `telefono`, `direccion`, `foto_url`). `perfil.id_usuario` is unique per user.
- Role names are stored lowercase in DB but compared as uppercase strings in code (e.g. `"ACTIVO"`,
  `"SIN_ROL"`); the role select in `registro.jsp` excludes `administrador` via `LOWER(nombre) <> 'administrador'`.

## Gotchas
- `assets/css/style.css` is referenced in the `<head>` of every page, but no `assets/` folder exists — it 404s silently. Bootstrap 4.6 and Font Awesome 5.15 come from CDN, not vendored.
- `insertar.jsp`, `actualizar.jsp`, `eliminar.jsp`, `modificar.jsp` are demo/CRUD stubs:
  - `insertar.jsp` references a non-existent `usuarios` table and `mostrar.jsp` — not part of the real flow. Don't model new code on it.
  - `actualizar.jsp`, `eliminar.jsp`, `modificar.jsp` are 0-byte placeholders.
- No `WEB-INF/web.xml`; all routing is filename-based.
