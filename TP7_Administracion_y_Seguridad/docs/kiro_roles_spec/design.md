# TP7 — Diseño técnico: modelo de roles PostgreSQL

**Proyecto:** FoodStore — Base de Datos II (UTN FRM)
**Alumnos:** Lucas Avila · Amanda Pagano · Mateo Lautaro Liendo
**Motor:** PostgreSQL 17
**Base de destino:** `foodstore_dev`
**Documento complementario:** `requirements.md` (misma carpeta)
**Script implementado:** `TP7_Administracion_y_Seguridad/sql/roles.sql`
**Última revisión:** 2026-10-14

---

## 1. Modelo de herencia de roles

```
              ┌──────────────────────────────────────────┐
              │          postgres (superusuario)          │
              │  crea roles + ejecuta ALTER DEFAULT PRIV  │
              └──────────┬──────────────┬────────────────┘
                         │              │
          ┌──────────────▼──┐    ┌──────▼──────────────────────────┐
          │  rol_app_lectura │    │          admin_datos             │
          │   (NOLOGIN)      │    │  (LOGIN, permisos directos ALL)  │
          └──────────┬───────┘    └──────────────────────────────────┘
                     │
          ┌──────────▼──────────┐
          │   rol_app_escritura  │
          │     (NOLOGIN)        │
          └──────────┬───────────┘
                     │
          ┌──────────▼───────────────┐
          │         app_web           │
          │  (LOGIN, hereda lectura   │
          │       + escritura)        │
          └───────────────────────────┘

          ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
          │  rol_soporte  │   │ rol_reportes  │   │rol_auditoria │
          │  (NOLOGIN)    │   │  (NOLOGIN)    │   │  (NOLOGIN)   │
          └──────────────┘   └──────────────┘   └──────────────┘
          (sin roles de login asignados en esta especificación;
           se asignarán a roles de login específicos cuando se creen)
```

`app_web` hereda la unión de permisos de `rol_app_lectura` y `rol_app_escritura`. Todos los permisos se administran en los roles de grupo; nunca se otorgan directamente sobre `app_web`.

---

## 2. Secuencia de implementación del script `roles.sql`

El script divide su contenido en 12 secciones ejecutables en una sola pasada:

| § | Contenido |
|---|---|
| 0 | Assert de base de destino: aborta si `current_database() ≠ 'foodstore_dev'` |
| 1 | `REVOKE` de `PUBLIC` sobre schema, tablas, secuencias y funciones |
| 2 | Creación idempotente de todos los roles (grupos y login) con `DO/EXCEPTION` |
| 3 | `GRANT USAGE ON SCHEMA public` a roles de grupo + login; `GRANT CREATE` solo a `admin_datos` |
| 4 | `GRANT` de tabla a nivel de tabla (RF-01) |
| 5 | `GRANT` de columna sobre `usuario` para `rol_soporte` (RF-03) + `REVOKE ALL` previo |
| 6 | `GRANT` de secuencia (RF-04) |
| 7 | `GRANT` de vistas y vista materializada (RF-02) |
| 8 | `GRANT EXECUTE` de funciones con bloques condicionales `to_regprocedure` (RF-05) |
| 9 | `GRANT pg_monitor` + catálogos para `rol_auditoria` (RF-06) |
| 10 | `ALTER DEFAULT PRIVILEGES` (RF-07) |
| 11 | `GRANT rol_app_lectura, rol_app_escritura TO app_web` (membresías) |
| 12 | Consultas de verificación (comentadas; ejecutar manualmente con autorización) |

---

## 3. DDL completo por sección

### § 0 — Assert de base de destino

```sql
DO $$
BEGIN
    IF current_database() <> 'foodstore_dev' THEN
        RAISE EXCEPTION
            'roles.sql abortado: base actual=%, se esperaba foodstore_dev.',
            current_database();
    END IF;
END $$;
```

### § 1 — Revocación de PUBLIC

```sql
-- Sentencias del enunciado (no remover):
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;

-- Endurecimiento complementario:
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

-- Defensa en profundidad (explícito sobre objetos conocidos):
REVOKE ALL ON TABLE
    categoria, cliente, producto, pedido, detalle_pedido, usuario
FROM PUBLIC;
REVOKE ALL ON SEQUENCE
    categoria_id_seq, cliente_id_seq, producto_id_seq,
    pedido_id_seq, usuario_id_seq
FROM PUBLIC;
```

### § 2 — Creación idempotente de roles

```sql
-- Roles de grupo
DO $$ BEGIN CREATE ROLE rol_app_lectura  NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE rol_app_escritura NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE rol_soporte      NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE rol_reportes     NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE rol_auditoria    NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Roles de login (passwords: placeholders; gestionar con Vault / env vars)
DO $$ BEGIN
    CREATE ROLE app_web LOGIN PASSWORD 'CAMBIAR_POR_VAULT' CONNECTION LIMIT 20;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE ROLE admin_datos LOGIN PASSWORD 'CAMBIAR_POR_VAULT' CONNECTION LIMIT 5;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
```

### § 3 — Schema

```sql
GRANT USAGE ON SCHEMA public TO
    rol_app_lectura, rol_app_escritura, rol_soporte,
    rol_reportes, rol_auditoria, app_web, admin_datos;

-- DDL controlado: solo admin_datos crea objetos en el schema del proyecto.
GRANT CREATE ON SCHEMA public TO admin_datos;
```

### § 4 — Tablas (nivel de tabla, RF-01)

```sql
-- rol_app_lectura: catálogo de negocio, solo lectura
GRANT SELECT ON TABLE
    categoria, cliente, producto, pedido, detalle_pedido
TO rol_app_lectura;

-- rol_app_escritura: operaciones transaccionales; sin DELETE (D1)
GRANT INSERT, UPDATE ON TABLE
    cliente, pedido, detalle_pedido, categoria, producto
TO rol_app_escritura;

-- admin_datos: administración completa (único ALL sobre tablas)
GRANT ALL ON TABLE
    categoria, cliente, producto, pedido, detalle_pedido, usuario
TO admin_datos;
```

`rol_soporte`, `rol_reportes` y `rol_auditoria` no reciben permisos a nivel de tabla completa.

### § 5 — Columnas de `usuario` (RF-03)

```sql
-- Garantiza mínimo privilegio incluso en re-ejecuciones:
REVOKE ALL ON TABLE usuario FROM rol_soporte;

GRANT SELECT (id, nombre, apellido, mail, celular, rol, eliminado, created_at)
    ON TABLE usuario TO rol_soporte;

GRANT UPDATE (eliminado)
    ON TABLE usuario TO rol_soporte;
```

`contrasena` (= `password_hash` del enunciado) queda excluida. Intento de `SELECT contrasena FROM usuario` bajo `rol_soporte` → `ERROR: permission denied for column contrasena`.

### § 6 — Secuencias (RF-04)

```sql
-- rol_app_escritura: USAGE + SELECT para las 4 tablas con INSERT (§4)
GRANT USAGE, SELECT ON SEQUENCE
    cliente_id_seq, pedido_id_seq,
    categoria_id_seq, producto_id_seq
TO rol_app_escritura;

-- admin_datos: control total
GRANT ALL ON SEQUENCE
    categoria_id_seq, cliente_id_seq, producto_id_seq,
    pedido_id_seq, usuario_id_seq
TO admin_datos;
```

`usuario_id_seq` excluida de `rol_app_escritura`: ningún rol operativo puede registrar usuarios directamente.

### § 7 — Vistas (RF-02)

```sql
-- rol_app_lectura: vistas operativas
GRANT SELECT ON
    v_catalogo_productos, v_pedido_cliente, v_detalle_pedido_producto
TO rol_app_lectura;

-- rol_reportes: vistas de análisis
GRANT SELECT ON
    v_reporte_ventas_cliente,
    v_usuario_publico,                  -- excluye contrasena por construcción
    mv_resumen_ventas_categoria_mes
TO rol_reportes;

-- admin_datos: administración total de vistas
GRANT ALL ON
    v_usuario_publico, v_reporte_ventas_cliente,
    v_catalogo_productos, v_detalle_pedido_producto,
    v_pedido_cliente, mv_resumen_ventas_categoria_mes
TO admin_datos;
```

### § 8 — Funciones (RF-05)

Los bloques son condicionales vía `to_regprocedure`; si una función no existe emiten `NOTICE` en lugar de abortar, lo que hace a `roles.sql` ejecutable tanto antes como después de crear las funciones.

```sql
-- Revocar de PUBLIC (condicional):
DO $$ BEGIN
    IF to_regprocedure('public.fn_autenticar(varchar, varchar)') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL ON FUNCTION public.fn_autenticar(VARCHAR, VARCHAR) FROM PUBLIC';
    ELSE RAISE NOTICE 'fn_autenticar no existe aún; REVOKE omitido.'; END IF;
END $$;

DO $$ BEGIN
    IF to_regprocedure('public.fn_resetear_password(bigint, varchar)') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL ON FUNCTION public.fn_resetear_password(BIGINT, VARCHAR) FROM PUBLIC';
    ELSE RAISE NOTICE 'fn_resetear_password no existe aún; REVOKE omitido.'; END IF;
END $$;

-- fn_autenticar → rol_app_escritura (login de la app web)
DO $$ BEGIN
    IF to_regprocedure('public.fn_autenticar(varchar, varchar)') IS NOT NULL THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.fn_autenticar(VARCHAR, VARCHAR) TO rol_app_escritura';
    ELSE RAISE NOTICE 'Pendiente GRANT fn_autenticar → rol_app_escritura.'; END IF;
END $$;

-- fn_resetear_password → rol_soporte (restablecimiento de credenciales)
DO $$ BEGIN
    IF to_regprocedure('public.fn_resetear_password(bigint, varchar)') IS NOT NULL THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.fn_resetear_password(BIGINT, VARCHAR) TO rol_soporte';
    ELSE RAISE NOTICE 'Pendiente GRANT fn_resetear_password → rol_soporte.'; END IF;
END $$;

-- Ambas → admin_datos (administración)
DO $$ BEGIN
    IF to_regprocedure('public.fn_autenticar(varchar, varchar)') IS NOT NULL
       AND to_regprocedure('public.fn_resetear_password(bigint, varchar)') IS NOT NULL THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION
                     public.fn_autenticar(VARCHAR, VARCHAR),
                     public.fn_resetear_password(BIGINT, VARCHAR)
                 TO admin_datos';
    ELSE RAISE NOTICE 'Pendiente GRANT ambas funciones → admin_datos.'; END IF;
END $$;
```

### § 9 — Monitoreo para `rol_auditoria` (RF-06)

```sql
GRANT pg_monitor TO rol_auditoria;
GRANT SELECT ON ALL TABLES IN SCHEMA information_schema TO rol_auditoria;
GRANT SELECT ON ALL TABLES IN SCHEMA pg_catalog         TO rol_auditoria;
```

### § 10 — ALTER DEFAULT PRIVILEGES (RF-07)

```sql
-- Ejecutar conectado como admin_datos (ver D6).
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_app_lectura;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT INSERT, UPDATE ON TABLES TO rol_app_escritura;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO rol_app_escritura;
```

### § 11 — Membresías

```sql
GRANT rol_app_lectura  TO app_web;
GRANT rol_app_escritura TO app_web;
-- admin_datos no hereda roles de grupo; sus permisos son directos (§§4–8).
```

---

## 4. Matrices de privilegios completas

### 4.1 Tablas de negocio

| Rol | `categoria` | `cliente` | `producto` | `pedido` | `detalle_pedido` |
|---|---|---|---|---|---|
| `rol_app_lectura` | S | S | S | S | S |
| `rol_app_escritura` | IU | IU | IU | IU | IU |
| `rol_soporte` | — | — | — | — | — |
| `rol_reportes` | — | — | — | — | — |
| `rol_auditoria` | — | — | — | — | — |
| `admin_datos` | ALL | ALL | ALL | ALL | ALL |
| `app_web` *(efectivo)* | S·IU | S·IU | S·IU | S·IU | S·IU |

S = SELECT · I = INSERT · U = UPDATE · D = DELETE (nunca otorgado a roles operativos)

### 4.2 Tabla `usuario` — nivel de columna

| Rol | `id` | `nombre` | `apellido` | `mail` | `celular` | `rol` | `eliminado` | `created_at` | `contrasena` |
|---|---|---|---|---|---|---|---|---|---|
| `rol_soporte` | S | S | S | S | S | S | S · U | S | **✗ denegado** |
| `rol_reportes` | — | — | — | — | — | — | — | — | — |
| `rol_auditoria` | — | — | — | — | — | — | — | — | — |
| `admin_datos` | ALL | ALL | ALL | ALL | ALL | ALL | ALL | ALL | ALL |

`rol_reportes` accede a `usuario` solo vía `v_usuario_publico`; esa vista excluye `contrasena` por su definición en `vistas.sql`.

### 4.3 Vistas

| Rol | `v_catalogo_productos` | `v_pedido_cliente` | `v_detalle_pedido_producto` | `v_reporte_ventas_cliente` | `v_usuario_publico` | `mv_resumen_ventas_categoria_mes` |
|---|---|---|---|---|---|---|
| `rol_app_lectura` | S | S | S | — | — | — |
| `rol_reportes` | — | — | — | S | S | S |
| `rol_auditoria` | — | — | — | — | — | — |
| `admin_datos` | ALL | ALL | ALL | ALL | ALL | ALL |

### 4.4 Secuencias

| Rol | `categoria_id_seq` | `cliente_id_seq` | `producto_id_seq` | `pedido_id_seq` | `usuario_id_seq` |
|---|---|---|---|---|---|
| `rol_app_escritura` | USAGE, SELECT | USAGE, SELECT | USAGE, SELECT | USAGE, SELECT | — |
| `admin_datos` | ALL | ALL | ALL | ALL | ALL |
| Resto | — | — | — | — | — |

### 4.5 Funciones

| Rol | `fn_autenticar(VARCHAR,VARCHAR)` | `fn_resetear_password(BIGINT,VARCHAR)` |
|---|---|---|
| `rol_app_escritura` | EXECUTE | — |
| `rol_soporte` | — | EXECUTE |
| `admin_datos` | EXECUTE | EXECUTE |
| Resto | — | — |

---

## 5. Decisiones de diseño

### D1 — Sin DELETE para `rol_app_escritura`
R7 del proyecto establece baja lógica (`UPDATE activo = FALSE` / `UPDATE eliminado = TRUE`). Omitir `DELETE` de `rol_app_escritura` hace que un bug de aplicación que genere un `DELETE` sea rechazado por el motor antes de tocar datos históricos. Registrado también en BITACORA.md fila 2 (propuesta amplia rechazada).

### D2 — Separación lectura / escritura en dos roles de grupo
Aunque `app_web` hereda ambos, la separación permite crear en el futuro un rol de login de solo lectura (API pública, informes en tiempo real) sin modificar el modelo existente.

### D3 — `rol_auditoria` con `pg_monitor` en lugar de GRANTs individuales
`GRANT pg_monitor` es el mecanismo declarativo recomendado por PostgreSQL desde v10 para acceso de lectura a estadísticas del motor. Reduce superficie de configuración manual y se actualiza automáticamente con nuevas vistas de sistema en versiones futuras del motor.

### D4 — Permisos de columna para `rol_soporte` en lugar de vista adicional
Se podría haber creado una vista `v_usuario_soporte` que excluya `contrasena`. La decisión de usar `GRANT ON COLUMN` es intencional: ejercita la característica de seguridad a nivel de columna como objetivo pedagógico del TP7, y evita añadir vistas al schema. La restricción es más directa: `SELECT contrasena FROM usuario` falla con `permission denied` independientemente de cómo se llame a la tabla. Registrado en BITACORA.md fila 3 (propuesta de `GRANT SELECT ON usuario TO rol_soporte` rechazada).

### D5 — Bloques condicionales en §8 para las funciones
`fn_autenticar` y `fn_resetear_password` fueron creadas durante el punto de partida del TP7 (`sql/fn_autenticar.sql`, `sql/fn_resetear_password.sql`). Los bloques `to_regprocedure` en `roles.sql §8` permiten re-ejecutar el script en cualquier estado: si las funciones existen aplica los `GRANT`; si no, emite `NOTICE` sin abortar. Esto preserva la idempotencia del script completo.

### D6 — `ALTER DEFAULT PRIVILEGES` se ejecuta como `admin_datos`
`ALTER DEFAULT PRIVILEGES` aplica a los objetos creados por el rol que ejecuta la sentencia. El contrato de mantenimiento del proyecto debe garantizar que toda migración DDL futura se ejecute como `admin_datos`. Si el superusuario crea una tabla nueva directamente, los privilegios heredados no aplican sobre ella; se requeriría `ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos` o un `GRANT` explícito posterior.

### D7 — `CONNECTION LIMIT` como defensa en profundidad
`CONNECTION LIMIT 20` para `app_web` y `5` para `admin_datos` no es un control de seguridad primario, pero previene que un bug de conexión o un ataque de agotamiento de recursos monopolice `max_connections` de la instancia.

### D8 — `password_hash` vs columna real `contrasena`
El enunciado usa el nombre genérico `password_hash`. La columna física es `usuario.contrasena VARCHAR(255)` (definida en `TP5_Indices_Vistas/Parte_B_Vistas/usuarios.sql`). La propuesta de renombrarla o crear una tabla alternativa con columna `password_hash` fue rechazada por el equipo (BITACORA.md fila 1) porque rompería `vistas.sql`, `roles.sql §5` y RF-03. En toda la implementación, `password_hash == contrasena`.

---

## 6. Archivos del TP7

| Archivo | Estado | Propósito |
|---|---|---|
| `sql/fn_autenticar.sql` | Creado | `fn_autenticar(VARCHAR, VARCHAR) RETURNS BIGINT` — autenticación bcrypt con SECURITY DEFINER |
| `sql/fn_resetear_password.sql` | Creado | `fn_resetear_password(BIGINT, VARCHAR) RETURNS BOOLEAN` — reseteo bcrypt con SECURITY DEFINER |
| `sql/roles.sql` | Creado y auditado | Implementación completa §§0–12 del modelo de roles |
| `docs/kiro_roles_spec/requirements.md` | Este documento | Requisitos funcionales RF-01 a RF-07 |
| `docs/kiro_roles_spec/design.md` | Este documento | Diseño técnico, DDL de referencia y matrices |
| `BITACORA.md` | Activo | Registro de interacciones IA / decisiones del equipo |

---

## 7. Consultas de verificación

Ejecutar manualmente tras aplicar `roles.sql`, con autorización explícita del grupo.

```sql
-- 7.1 Permisos de tabla otorgados a los roles de TP7
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN (
    'rol_app_lectura', 'rol_app_escritura', 'rol_soporte',
    'rol_reportes', 'rol_auditoria', 'app_web', 'admin_datos'
)
ORDER BY grantee, table_name, privilege_type;

-- 7.2 Permisos a nivel de columna sobre usuario para rol_soporte
SELECT grantee, column_name, privilege_type
FROM information_schema.column_privileges
WHERE table_name = 'usuario'
  AND grantee = 'rol_soporte'
ORDER BY column_name;

-- 7.3 Confirmar que rol_soporte no puede leer contrasena (debe retornar ERROR)
SET ROLE rol_soporte;
SELECT contrasena FROM usuario LIMIT 1;  -- esperado: ERROR permission denied for column contrasena
RESET ROLE;

-- 7.4 Membresías de app_web
SELECT
    r.rolname AS login_role,
    m.rolname AS member_of
FROM pg_auth_members am
JOIN pg_roles r ON r.oid = am.member
JOIN pg_roles m ON m.oid = am.roleid
WHERE r.rolname = 'app_web';

-- 7.5 Verificar EXECUTE en funciones
SELECT routine_name, grantee, privilege_type
FROM information_schema.role_routine_grants
WHERE routine_name IN ('fn_autenticar', 'fn_resetear_password')
ORDER BY routine_name, grantee;

-- 7.6 Confirmar que PUBLIC no tiene acceso a las tablas
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'PUBLIC'
  AND table_schema = 'public'
ORDER BY table_name;
```
