# AGENTS.md

JSP web app for XAMPP/Tomcat (inmobiliaria). The deployed webapp is `C:\xampp\tomcat\webapps\trabajo`,
served at context path `/trabajo`; this repo folder is nested inside it at
`webapps\trabajo\trabajo-inmobiliaria-ManuelOrtiz-DiegoMojica` (its docroot is `webapps\trabajo`, NOT this folder).
No build, no WAR, no Maven/Gradle — JSPs are compiled and served by Tomcat at runtime.

## Running / verifying
- Deploy: just edit the `.jsp` files in place; Tomcat hot-reloads them. No compile/build step.
- Real URL to reach the app: `http://localhost:8080/trabajo/trabajo-inmobiliaria-ManuelOrtiz-DiegoMojica/` (`/trabajo/` alone 404s because no `index.jsp` sits at the docroot).
- DB is MariaDB (`inmobiliaria_db`) on `localhost:3306`, user `root`, empty password — set in `conexion.jspf`.
- JDBC driver: `WEB-INF/lib/mysql-connector-j-9.6.0.jar` (already present). Don't add another connector.
- Schema to re-import: `basededatos/inmobiliaria_db.sql` (MariaDB/phpMyAdmin dump).
- Photos/images upload to `/uploads` created at runtime; the physical dir is `webapps\trabajo\uploads`.

## Architecture / connections
- Every page that needs the DB starts with `<%@ include file="conexion.jspf" %>`. This fragment
  declares a local `Connection conexion` (and `java.sql.*` imports) driven by `request`. The
  including JSP must close `conexion` itself before output completes.
- DB-driven forms/selects are populated inline in the JSP with `PreparedStatement`/`Statement`.
- Passwords are SHA-256 hashed via a `hashSHA256()` JSP-declared method (both `registro.jsp` and `login.jsp` duplicate it; there is no shared module).
- `completar_registro.jsp` implements manual multipart/form-data parsing (no Servlet API helper) to handle photo uploads; saves files via `application.getRealPath("/uploads")` and stores `uploads/<file>` in `perfil.foto_url`.

## Auth / real flow (keep consistent)
- `registro.jsp` inserts `usuario` + `usuario_rol` (solo rol `cliente`); redirige a `completar_registro.jsp`.
- Para ser `inmobiliaria`: usuario se registra como `cliente` y luego usa `solicitar_inmobiliaria.jsp` → admin aprueba en `admin_solicitudes.jsp` → se cambia rol y se crea registro en `inmobiliaria`.
- `login.jsp` valida contra `usuario`/`rol` y guarda en sesión `id_usuario`, `correo`, `rol`.
- `index.jsp` usa `auth.jspf` y muestra dashboard según rol.
- `cerrar_sesion.jsp` invalida sesión y redirige a `login.jsp`.
- Core tables: `usuario`, `rol`, `usuario_rol`, `perfil` (holds `nombres`, `apellidos`, `documento`,
  `telefono`, `direccion`, `foto_url`). `perfil.id_usuario` es único por usuario.
- Role names en DB son lowercase; en código se comparan case-insensitive. `usuario.estado` enum: `'ACTIVO'`, `'INACTIVO'`, `'BLOQUEADO'`.

## Fragmentos reutilizables (nuevos)
- `auth.jspf` — helper centralizado: lee sesión, expone `idUsuario`, `rol`, `autenticado`, `esAdmin`, `esInmob`, `esCliente`, `esVisitante`, `idInmobiliariaUsuario`. Incluir en TODAS las páginas que necesiten auth.
- `navbar.jspf` — navbar unificado con menú dinámico según rol. Incluye `auth.jspf` internamente.

## Database schema (full)
El dump SQL define 16 tablas. Auth-relevantes: `usuario`, `rol`, `usuario_rol`, `perfil`.
Tablas dominio (cableadas en JSPs): `propiedad`, `ciudad`, `tipo_propiedad`, `inmobiliaria`,
`caracteristica`, `propiedad_caracteristica`, `imagen_propiedad`.
Otras tablas dominio (no cableadas aún): `solicitud` (ahora con `tipo_solicitud` = `INMOBILIARIA`), `documento_solicitud`, `cita`, `favorito`, `auditoria`.

**Cambio BD requerido:** `ALTER TABLE solicitud MODIFY tipo_solicitud ENUM('COMPRA','ARRIENDO','INMOBILIARIA');` (ver `basededatos/add_inmobiliaria_solicitud.sql`).

## Roles y permisos (matriz)

| Funcionalidad              | Visitante | Cliente | Inmobiliaria | Administrador |
|----------------------------|-----------|---------|--------------|---------------|
| Ver propiedades (lista/detalle) | ✅        | ✅       | ✅            | ✅             |
| Filtros búsqueda           | ❌ (form disabled) | ✅       | ✅            | ✅             |
| Crear propiedad            | ❌        | ❌       | ✅ (auto su inmob) | ✅ (elige inmob) |
| Editar propiedad           | ❌        | ❌       | ✅ (solo propias) | ✅ (todas)     |
| Eliminar propiedad         | ❌        | ❌       | ✅ (solo propias) | ✅ (todas)     |
| Ver/editar perfil          | ❌        | ✅       | ✅            | ✅             |
| Solicitar ser Inmobiliaria | ❌        | ✅       | —            | ✅ aprueba     |
| Gestionar usuarios         | ❌        | ❌       | ❌            | ✅             |
| Asignar roles              | ❌        | ❌       | ❌            | ✅             |
| Ver/gestionar solicitudes  | ❌        | ❌       | ❌            | ✅             |

## Property CRUD (actualizado)
- `propiedades.jsp` — lista con filtros; Visitante ve solo lectura (filtros disabled), Cliente ve todos, Inmobiliaria ve todos (según decisión), Admin ve todos. Acciones Editar/Eliminar solo dueño o admin.
- `propiedad_nueva.jsp` — solo Inmobiliaria/Admin. Inmobiliaria: `id_inmobiliaria` automático (hidden). Admin: dropdown para elegir.
- `propiedad_ver.jsp` — detalle con carousel; botones Editar/Eliminar solo dueño o admin.
- `propiedad_editar.jsp` — edita propiedad; Inmobiliaria no puede cambiar `id_inmobiliaria` (hidden). Admin puede.
- `propiedad_eliminar.jsp` — baja lógica; solo dueño o admin.
- Todas requieren login (`auth.jspf`), usan `navbar.jspf`, siguen patrones de auth.

## Nuevos JSPs (Admin + Solicitudes)
- `admin_usuarios.jsp` — lista usuarios con filtros, link a editar.
- `admin_usuario_editar.jsp` — cambia rol (dropdown), estado (ACTIVO/INACTIVO/BLOQUEADO), reset password.
- `solicitar_inmobiliaria.jsp` — Cliente envía solicitud (datos de inmobiliaria); guarda en `solicitud` con `tipo_solicitud='INMOBILIARIA'`, `estado='EN_REVISION'`.
- `admin_solicitudes.jsp` — Admin ve solicitudes `INMOBILIARIA` pendientes; botones Aprobar/Rechazar. Al aprobar: crea registro en `inmobiliaria` (datos por completar), cambia rol usuario a `inmobiliaria`.
- `registro.jsp` — ahora solo permite registrar como `cliente`. Enlace a `solicitar_inmobiliaria.jsp` para ser inmobiliaria.

## Gotchas (actualizados)
- `assets/css/style.css` referenciado en `<head>` de cada página, pero no existe carpeta `assets/` — 404 silencioso. Bootstrap 4.6 y Font Awesome 5.15 vienen de CDN.
- `insertar.jsp`, `actualizar.jsp`, `eliminar.jsp`, `modificar.jsp` son stubs demo/CRUD: no modelar código nuevo en ellos. `insertar.jsp` tiene bug sintáctico (falta `{` de `try`).
- No `WEB-INF/web.xml`; routing por nombre de archivo.
- Conexiones no pooled; cada request abre/cierra su propia vía `conexion.jspf`.
- Sin manejo centralizado de errores/logging — excepciones se imprimen inline en HTML.
- Duplicate `hashSHA256()` en `registro.jsp` y `login.jsp`; mantener sincronizados si cambia.
- `completar_registro.jsp` usa `ON DUPLICATE KEY UPDATE` (MySQL-specific) para upsert.
- `perfil.direccion` existe en BD pero no se usa en JSPs.
- `foto_url` en `perfil` es nullable; foto de perfil opcional.
- **Rutas de imagen/web deben ser context-rooted.** Páginas se sirven en `/trabajo/trabajo-inmobiliaria-ManuelOrtiz-DiegoMojica/...`, archivos en disco en docroot `webapps\trabajo\uploads`. Un `src="uploads/foo.png"` relativo resuelve a URL errónea (subcarpeta, no docroot `uploads/`) y da 404 — navegador muestra `alt`. Todo `<img>` para `foto_url`/`url_imagen` debe usar `src="<%= request.getContextPath() %>/<%= url %>"` (da `/trabajo/uploads/foo.png`). Guardar (vía `getRealPath("/uploads")`) y borrar (vía `getRealPath("/" + url)`) ya resuelven al físico correcto — solo rutas de display necesitan el prefijo. Ver `index.jsp:87`, `completar_registro.jsp:265`, `propiedad_ver.jsp:140`, `propiedad_editar.jsp:477`.
- **Inputs de archivo vacíos.** En `completar_registro.jsp` el formulario de edición mantiene la foto actual solo si se sube archivo nuevo; inicializar `urlFoto = actualFoto` (no `null`) para que un submit sin foto no borre `foto_url` con NULL. También validar null antes de llamar método String (ej. `if (actualFoto != null && !actualFoto.isEmpty())`, no `!actualFoto.isEmpty()`), sino `NULL` `foto_url` lanza NPE y falla la página de edición.
- **Choque de variable `url` en `propiedad_editar.jsp`.** `conexion.jspf` declara `String url` (JDBC URL) y se inyecta vía `<%@ include %>` en el mismo método `_jspService`. No declarar otra variable `url` en el mismo ámbito — usar `urlImagen` u otro nombre. Ver fix en línea 251.
- **Guards de autorización:** cada JSP protegido debe incluir `auth.jspf` al inicio y verificar `autenticado` + roles requeridos antes de cualquier lógica. Usar `esAdmin`, `esInmob`, `esCliente`, `esVisitante` del helper. Ver `propiedad_nueva.jsp`, `propiedad_editar.jsp`, `propiedad_eliminar.jsp`, `admin_*.jsp`.
- **Ownership en propiedad:** Inmobiliaria solo edita/elimina sus propiedades (`id_inmobiliaria` match). Admin edita/elimina todas. Ver `propiedad_editar.jsp` (línea ~50) y `propiedad_eliminar.jsp` (línea ~30).

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
- **Image/web paths must be context-rooted.** Pages are served at `/trabajo/trabajo-inmobiliaria-ManuelOrtiz-DiegoMojica/...`, but files live on disk at the docroot `webapps\trabajo\uploads`. So a relative `src="uploads/foo.png"` resolves to the wrong URL (the subfolder, not the docroot `uploads/`) and 404s — the browser shows the `alt` text. Every `<img>` for `foto_url`/`url_imagen` must use `src="<%= request.getContextPath() %>/<%= url %>"` (gives `/trabajo/uploads/foo.png`). Save (via `getRealPath("/uploads")`) and delete (via `getRealPath("/" + url)`) already resolve to the correct physical spot — only display paths need the prefix. See `index.jsp:87`, `completar_registro.jsp:265`, `propiedad_ver.jsp:140`, `propiedad_editar.jsp:477`.
- **Empty/missing file inputs.** In `completar_registro.jsp` the edit form keeps the current photo only if a new file is uploaded; initialize `urlFoto = actualFoto` (not `null`) so a photo-less submit doesn't wipe `foto_url` with NULL. Also guard null before calling a String method (e.g. `if (actualFoto != null && !actualFoto.isEmpty())`, not `!actualFoto.isEmpty()`), else a NULL `foto_url` throws NPE and the whole edit page fails.