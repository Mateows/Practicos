# TP7 Parte B — Informe de auditoría (`foodstore_dev`, PostgreSQL 17.10)

Evidencia: `docs/log_auditoria_prueba.txt` (24 líneas de
`...\data\log\postgresql-2026-10-14_000000.log`); secuencia:
`sql/auditoria_test.sql`. Alcance: solo `foodstore_dev`
(`foodstore_copia_trabajo` sin tocar).

## 1. Configuración aplicada (Punto B.1)

 vía `ALTER SYSTEM SET` + `SELECT pg_reload_conf()` (parámetros SIGHUP,
 `source=configuration file`, sin reinicio; `logging_collector` ya estaba en
 `on`, por lo que `pg_current_logfile()` devolvió ruta activa).

| Parámetro | Valor previo | Valor nuevo | Qué aporta |
|---|---|---|---|
| `log_connections` | `off` | `on` | Registra cada intento de conexión (`conexión recibida`, autenticada y autorizada) y los fallidos con `FATAL` + regla `pg_hba` aplicada |
| `log_disconnections` | `off` | `on` | Registra fin de sesión con duración, usuario, base y origen (cierra la traza quién/cuándo) |
| `log_statement` | `none` | `all` | Registra el texto de cada sentencia (DDL, DML **y** `SELECT`); ver nota `mod` vs `all` abajo |
| `log_line_prefix` | `%t ` (solo hora) | `%m [%p] %u@%d %r %a ` | `%m` timestamp con ms, `%p` PID, `%u` usuario, `%d` base, `%r` host/IP origen, `%a` aplicación: el quién/cuándo/dónde de cada línea |
| `logging_collector` | `on` | `on` (sin cambio) | Sin colector no hay archivo (requiere reinicio si estuviera en `off`: contexto `postmaster`) |
| `log_destination` | `stderr` | `stderr` (sin cambio) | Destino archivo vía colector |
| `log_directory` / `log_filename` | `log` / `postgresql-%Y-%m-%d_%H%M%S.log` | sin cambio | Archivo activo: `log/postgresql-2026-10-14_000000.log` |

Nota `mod` vs `all` (decisión del equipo): el mínimo pedido era `mod`
(solo DDL + `INSERT/UPDATE/DELETE`), pero el Punto B.2 exige una lectura de
prueba visible en el log y con `mod` los `SELECT` no se auditan, por lo que
se fijó `all` para este laboratorio en desarrollo. Contrapartida: `all`
genera ruido excesivo (cada `SELECT` de la app, cada `REFRESH`, cada
verificación) y vuelca más datos sensibles al disco; en producción se
preferiría `mod` (o `pgaudit` con filtrado por objeto).

## 2. Análisis del fragmento capturado (Punto B.3)

Quién / qué / cuándo / desde dónde, con líneas concretas:

- **Intento fallido (quién-cuándo-dónde + qué):**
  `11:52:56.565 ... [4684] [desconocido]@[desconocido] ::1(62150)
  ... LOG: conexión recibida` → intento desde `::1` puerto 62150;
  `11:52:56.586 ... postgres@foodstore_dev ::1(62150) ... FATAL:
  la autentificación password falló para el usuario «postgres»` → **qué**:
  fallo de autenticación; **quién**: `postgres`; **cuándo**: timestamp con ms;
  **dónde**: `::1(62150)`; el `DETALLE` cita la regla aplicada
  (`pg_hba.conf línea 117 ... scram-sha-256`).
- **Conexión legítima:** `conexión autenticada: identidad=«postgres»
  método=scram-sha-256` + `conexión autorizada: usuario=postgres
  base_de_datos=foodstore_dev nombre_de_aplicación=psql` → quién, método,
  base y aplicación (`%a` = `psql`).
- **Sentencias:** cada una con prefijo completo, p. ej.
  `... [26120] postgres@foodstore_dev ::1(62151) psql LOG: sentencia:
  SELECT fn_autenticar('admin@foodstore.com', 'clave_erronea_test') ...`
  (nótese: el parámetro en **texto plano**, ver §3), el `INSERT`/`UPDATE` de
  `AuditoriaTestB2` y su `ROLLBACK`, y las marcas
  `AUDITORIA_TEST_INICIO_B2`/`FIN_B2` que delimitan el fragmento.
- **Cierre:** `desconexión: duración de sesión: 0:00:00.094
  usuario=postgres base=foodstore_dev host=::1 port=62151`
  (efecto directo de `log_disconnections = on`).

Fuera del alcance de este mecanismo nativo: con `log_statement = 'mod'` no
se auditan los `SELECT` (p. ej. una lectura masiva de `usuario` sería
invisible); con `'all'` todo queda registrado sin distinguir tablas
sensibles de inocuas (ruido y exposición); el log muestra el texto de la
sentencia pero **no** qué filas existían antes ni sus valores anteriores o
nuevos (no hay antes/después por fila); tampoco resuelve el interior de
funciones `SECURITY DEFINER` (solo se ve la llamada a `fn_autenticar`, no
sus comparaciones internas); y no permite auditar solo `usuario` o solo
`pedido`. Esa granularidad (filtro por objeto, detalle fila por fila) es la
que aportan la extensión `pgaudit` o triggers de auditoría a medida.

## 3. El archivo de log como activo sensible (Punto B.4)

El propio log es un activo altamente sensible porque conserva en texto
plano el contenido de las consultas: mails y parámetros de funciones
(el fragmento exhibe `fn_autenticar('admin@foodstore.com',
'clave_erronea_test')`), nombres de objetos y la estructura interna del
esquema, legibles por cualquiera con acceso al archivo. A nivel de sistema
operativo solo debe ser legible por la cuenta del servicio del motor y los
administradores: permisos `0600` o `0640` (`postgres:adm`) en Linux/POSIX,
o el equivalente ACL NTFS de Windows restringido exclusivamente a
`NT AUTHORITY\Servicio de red`, `SYSTEM` y `BUILTIN\Administradores`
(en producción deben removerse cuentas interactivas locales como
`MATEOWS\Mateows`, presente en este entorno de desarrollo). A nivel del
motor, el acceso debe restringirse a `SUPERUSER` o a miembros explícitos de
`pg_read_server_files`, nunca `app_web`, `rol_soporte` ni `PUBLIC`.
