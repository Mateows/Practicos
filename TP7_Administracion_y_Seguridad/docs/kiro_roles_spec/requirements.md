# TP7 — Requisitos de seguridad: modelo de roles PostgreSQL

**Proyecto:** FoodStore — Base de Datos II (UTN FRM)
**Alumnos:** Lucas Avila · Amanda Pagano · Mateo Lautaro Liendo
**Motor:** PostgreSQL 17
**Base de destino:** `foodstore_dev`
**Script de implementación:** `TP7_Administracion_y_Seguridad/sql/roles.sql`
**Última revisión:** 2026-10-14

---

## 1. Esquema real de foodstore_dev

Este documento se basa en el esquema instalado en `foodstore_dev` al cierre del punto de partida (Clases 1 y 2 del TP7). Todo lo que aquí se especifica refiere a nombres de objetos reales, no supuestos.

### 1.1 Tablas y columnas relevantes para la política de roles

**`categoria`** — `id, nombre, descripcion, activo, created_at`
**`cliente`** — `id, nombre_completo, email, telefono, direccion, created_at`
**`producto`** — `id, id_categoria, nombre, descripcion, precio_lista, stock, activo, created_at`
**`pedido`** — `id, id_cliente, fecha_hora, forma_pago, estado, observaciones`
**`detalle_pedido`** — `id_pedido (PK), id_producto (PK), cantidad, precio_unitario, subtotal` (sin secuencia propia)
**`usuario`** — `id, nombre, apellido, mail, celular, contrasena, rol, eliminado, created_at`

> **Nota sobre `password_hash` vs `contrasena`:** el enunciado del TP usa el nombre genérico `password_hash`. La columna real en `foodstore_dev` es `usuario.contrasena VARCHAR(255)`, que almacena un hash bcrypt generado con pgcrypto. Esta decisión fue validada por el equipo y registrada en `BITACORA.md` (fila 1): renombrarla a `password_hash` rompería `vistas.sql`, `roles.sql §5` y RF-03. En toda la especificación, `password_hash` y `contrasena` son sinónimos que nombran la misma columna física.

### 1.2 Vistas instaladas

| Vista | Tipo | Propósito |
|---|---|---|
| `v_catalogo_productos` | Regular | Productos y categorías activas (`activo = TRUE`) |
| `v_pedido_cliente` | Regular | Cabecera de pedido con datos del cliente |
| `v_detalle_pedido_producto` | Regular | Detalle de pedido con nombre del producto |
| `v_reporte_ventas_cliente` | Regular | Ventas agregadas por cliente (excluye CANCELADOS) |
| `v_usuario_publico` | Regular | Usuarios activos; **excluye `contrasena` por construcción** |
| `mv_resumen_ventas_categoria_mes` | Materializada | Facturación por categoría y mes; soporta REFRESH CONCURRENTLY |

### 1.3 Funciones instaladas

| Función | Firma | Retorno | Propósito |
|---|---|---|---|
| `fn_autenticar` | `(p_email VARCHAR, p_password VARCHAR)` | `BIGINT` | Verifica credenciales contra `usuario.contrasena` (bcrypt). Devuelve `id` si autentica o `NULL` si falla. No revela si el usuario existe. Respeta baja lógica (`eliminado = FALSE`). |
| `fn_resetear_password` | `(p_id_usuario BIGINT, p_nueva_password VARCHAR)` | `BOOLEAN` | Actualiza `usuario.contrasena` con un nuevo hash bcrypt. Requiere `≥ 8 caracteres`. Solo opera sobre usuarios con `eliminado = FALSE`. Devuelve `TRUE` si actualizó exactamente 1 fila. |

Ambas funciones se definen con `SECURITY DEFINER` y `REVOKE ALL FROM PUBLIC` desde su creación (`fn_autenticar.sql`, `fn_resetear_password.sql`). El acceso se otorga exclusivamente vía `roles.sql §8`.

### 1.4 Secuencias implícitas (GENERATED ALWAYS AS IDENTITY)

`categoria_id_seq`, `cliente_id_seq`, `producto_id_seq`, `pedido_id_seq`, `usuario_id_seq`.
`detalle_pedido` no genera secuencia (PK compuesta).

### 1.5 Superficie de ataque que la política cierra

| Objeto sensible | Riesgo sin control |
|---|---|
| `usuario.contrasena` | Hash bcrypt expuesto a cualquier rol con `SELECT` genérico sobre la tabla |
| `fn_autenticar` | Invocable por cualquier rol sin restricción; abusable para enumeración de cuentas |
| `fn_resetear_password` | Modifica credenciales; acceso no controlado habilita cambio masivo de contraseñas |
| Secuencias `*_id_seq` | `USAGE` sin control permite reservar o adelantar IDs, corrompiendo la lógica de negocio |
| Tablas base vs. vistas | Acceso directo a tablas expone columnas no publicadas en vistas; las vistas son la interfaz segura |

---

## 2. Roles requeridos

### 2.1 Roles de grupo (NOLOGIN)

| Rol | Justificación — qué operación habilita y por qué solo esa |
|---|---|
| `rol_app_lectura` | Habilita `SELECT` sobre las cinco tablas de negocio y las vistas operativas porque la capa de consulta de la aplicación necesita leer el catálogo y el historial de pedidos, y no necesita escribir ni acceder a datos de usuarios. |
| `rol_app_escritura` | Habilita `INSERT` y `UPDATE` sobre las tablas transaccionales (`cliente`, `pedido`, `detalle_pedido`, `categoria`, `producto`) y `USAGE, SELECT` sobre sus secuencias, porque la capa de negocio debe crear pedidos y mantener el catálogo sin poder borrar registros históricos (baja lógica, R7) ni tocar credenciales. |
| `rol_soporte` | Habilita `SELECT` sobre las columnas de identificación y estado de `usuario` y `UPDATE (eliminado)` para gestionar altas y bajas lógicas de cuentas, y `EXECUTE` sobre `fn_resetear_password` para restablecer contraseñas, porque el equipo de soporte gestiona cuentas de usuarios sin necesitar jamás leer ni escribir `contrasena`. |
| `rol_reportes` | Habilita `SELECT` sobre las vistas de agregación (`v_reporte_ventas_cliente`, `v_usuario_publico`, `mv_resumen_ventas_categoria_mes`) porque los analistas de negocio necesitan reportes de facturación y de usuarios activos sin acceder a tablas base, datos individuales de pedidos ni credenciales. |
| `rol_auditoria` | Habilita lectura de las vistas de estadísticas del motor vía el rol predefinido `pg_monitor` y de los catálogos `information_schema` / `pg_catalog`, porque el rol de auditoría necesita verificar el estado operativo de la instancia y los metadatos del esquema sin ningún contacto con datos transaccionales ni credenciales. |

### 2.2 Roles de login (LOGIN)

| Rol | Hereda de | Justificación |
|---|---|---|
| `app_web` | `rol_app_lectura`, `rol_app_escritura` | Es el usuario de conexión de la aplicación web; hereda lectura para el catálogo y escritura para las operaciones transaccionales sin privilegios DDL ni acceso a la tabla `usuario`. |
| `admin_datos` | *(sin herencia de roles de grupo)* | Es el usuario de administración controlada; recibe permisos directos de DDL sobre el schema `public` y acceso completo a todas las tablas —incluyendo `usuario.contrasena`— para operaciones de mantenimiento, pero sin atributo `SUPERUSER`. |

---

## 3. Requisitos funcionales

### RF-01 — Permisos de tabla (nivel de tabla)

| Rol | `categoria` | `cliente` | `producto` | `pedido` | `detalle_pedido` | `usuario` |
|---|---|---|---|---|---|---|
| `rol_app_lectura` | SELECT | SELECT | SELECT | SELECT | SELECT | — |
| `rol_app_escritura` | INSERT, UPDATE | INSERT, UPDATE | INSERT, UPDATE | INSERT, UPDATE | INSERT, UPDATE | — |
| `rol_soporte` | — | — | — | — | — | *ver RF-03* |
| `rol_reportes` | — | — | — | — | — | — |
| `rol_auditoria` | — | — | — | — | — | — |
| `admin_datos` | ALL | ALL | ALL | ALL | ALL | ALL |

`rol_reportes` y `rol_auditoria` no reciben permisos directos sobre tablas; operan exclusivamente a través de vistas (RF-02) o catálogos del sistema (RF-06).

### RF-02 — Permisos de vista

| Rol | `v_catalogo_productos` | `v_pedido_cliente` | `v_detalle_pedido_producto` | `v_reporte_ventas_cliente` | `v_usuario_publico` | `mv_resumen_ventas_categoria_mes` |
|---|---|---|---|---|---|---|
| `rol_app_lectura` | SELECT | SELECT | SELECT | — | — | — |
| `rol_reportes` | — | — | — | SELECT | SELECT | SELECT |
| `rol_auditoria` | — | — | — | — | — | — |
| `admin_datos` | ALL | ALL | ALL | ALL | ALL | ALL |

`v_usuario_publico` excluye `contrasena` por construcción (definida en `vistas.sql`); otorgar `SELECT` sobre ella a `rol_reportes` no expone el hash.

### RF-03 — Permisos a nivel de columna sobre `usuario` (mínimo privilegio estricto)

`rol_soporte` no recibe `GRANT SELECT ON TABLE usuario` ni `GRANT UPDATE ON TABLE usuario`. Recibe exclusivamente permisos de columna:

```sql
GRANT SELECT (id, nombre, apellido, mail, celular, rol, eliminado, created_at)
    ON TABLE usuario TO rol_soporte;

GRANT UPDATE (eliminado)
    ON TABLE usuario TO rol_soporte;
```

La columna `contrasena` (= `password_hash` del enunciado) queda **excluida de todos los permisos de `rol_soporte`**. Un `SELECT contrasena FROM usuario` bajo ese rol debe retornar `ERROR: permission denied for column contrasena`.

Ningún otro rol de grupo recibe acceso directo a `usuario.contrasena`. El único rol que puede leerla o modificarla es `admin_datos`.

### RF-04 — Permisos de secuencia

| Secuencia | `rol_app_escritura` | `admin_datos` | Resto |
|---|---|---|---|
| `cliente_id_seq` | USAGE, SELECT | ALL | — |
| `pedido_id_seq` | USAGE, SELECT | ALL | — |
| `categoria_id_seq` | USAGE, SELECT | ALL | — |
| `producto_id_seq` | USAGE, SELECT | ALL | — |
| `usuario_id_seq` | — | ALL | — |

`detalle_pedido` no tiene secuencia propia. `usuario_id_seq` queda exclusivamente bajo `admin_datos` porque ningún rol operativo puede registrar usuarios directamente.

### RF-05 — Permisos de ejecución de funciones

| Función | Firma real | `rol_app_escritura` | `rol_soporte` | `admin_datos` | Resto |
|---|---|---|---|---|---|
| `fn_autenticar` | `(VARCHAR, VARCHAR) → BIGINT` | EXECUTE | — | EXECUTE | — |
| `fn_resetear_password` | `(BIGINT, VARCHAR) → BOOLEAN` | — | EXECUTE | EXECUTE | — |

`fn_autenticar` la invoca la aplicación web en cada login, por lo que corresponde a `rol_app_escritura` (que hereda `app_web`).
`fn_resetear_password` modifica credenciales; solo `rol_soporte` (atención al usuario) y `admin_datos` (administración) pueden ejecutarla.

### RF-06 — Permisos de monitoreo para `rol_auditoria`

```sql
GRANT pg_monitor TO rol_auditoria;
GRANT SELECT ON ALL TABLES IN SCHEMA information_schema TO rol_auditoria;
GRANT SELECT ON ALL TABLES IN SCHEMA pg_catalog         TO rol_auditoria;
```

`pg_monitor` es un rol predefinido de PostgreSQL (disponible desde v10) que agrupa `pg_read_all_stats`, `pg_stat_scan_tables` y `pg_read_all_settings`. Da acceso de solo lectura a `pg_stat_activity`, `pg_locks`, `pg_stat_user_tables`, `pg_stat_user_indexes`, etc., sin exponer datos de negocio de ninguna base.

### RF-07 — Política de ALTER DEFAULT PRIVILEGES

Las tablas y secuencias creadas en el futuro en el schema `public` heredan la misma política sin intervención manual. Las sentencias se ejecutan conectado como `admin_datos` (o el superusuario que creará los objetos futuros):

```sql
-- Tablas futuras: lectura para rol_app_lectura
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_app_lectura;

-- Tablas futuras: escritura para rol_app_escritura
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT INSERT, UPDATE ON TABLES TO rol_app_escritura;

-- Secuencias futuras: uso para rol_app_escritura
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO rol_app_escritura;
```

`rol_soporte`, `rol_reportes` y `rol_auditoria` no reciben privilegios heredados sobre tablas nuevas. Si en el futuro se añade una tabla con datos sensibles (p. ej. `auditoria_accesos`), requiere una revisión manual antes de que `rol_app_escritura` pueda escribir en ella.

---

## 4. Restricciones explícitas (lo que cada rol NO puede hacer)

| Rol | Restricción crítica |
|---|---|
| `rol_app_lectura` | Sin INSERT, UPDATE ni DELETE sobre ningún objeto |
| `rol_app_escritura` | Sin DELETE sobre ninguna tabla (la baja lógica usa `UPDATE activo = FALSE` / `UPDATE eliminado = TRUE`, R7) |
| `rol_soporte` | Sin leer ni escribir `usuario.contrasena` bajo ninguna circunstancia; sin acceso a tablas de negocio |
| `rol_reportes` | Sin acceso directo a tablas base; sin acceso a `usuario.contrasena` (la vista `v_usuario_publico` la excluye) |
| `rol_auditoria` | Sin acceso a datos transaccionales ni a credenciales; solo catálogos y estadísticas del motor |
| `app_web` | Sin privilegios DDL; no puede crear, alterar ni borrar objetos del esquema |
| `admin_datos` | Sin atributo `SUPERUSER`; sus privilegios se limitan al schema `public` de `foodstore_dev` |

---

## 5. Glosario

| Término | Definición en este documento |
|---|---|
| `password_hash` | Nombre genérico del enunciado; columna real: `usuario.contrasena VARCHAR(255)` con hash bcrypt |
| Rol de grupo | Rol PostgreSQL `NOLOGIN`; se asigna a roles de login con `GRANT` |
| Rol de login | Rol PostgreSQL `LOGIN`; se conecta a la base y hereda permisos de sus roles de grupo |
| Baja lógica | `UPDATE activo = FALSE` o `UPDATE eliminado = TRUE` en lugar de `DELETE` físico (R7) |
| Permisos de columna | `GRANT privilege (col1, col2) ON TABLE t TO rol`; más restrictivo que el nivel de tabla |
| `ALTER DEFAULT PRIVILEGES` | Instrucción que aplica `GRANT`s automáticamente a los objetos futuros de un schema |
| `SECURITY DEFINER` | Atributo de función que la ejecuta con los privilegios del propietario, no del invocador |
| `pg_monitor` | Rol predefinido de PostgreSQL ≥10 que agrupa acceso de lectura a estadísticas del motor |
