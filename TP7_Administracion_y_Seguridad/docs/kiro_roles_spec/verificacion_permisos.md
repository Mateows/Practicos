# TP7 Parte A.3 — Verificación de permisos en `foodstore_dev`

**Fecha:** 2026-10-14 · **Motor:** PostgreSQL 17.10 · **Base:** `foodstore_dev`
(`foodstore_copia_trabajo` sin tocar) · **Script aplicado:**
`TP7_Administracion_y_Seguridad/sql/roles.sql` (incluye serie
`ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos`, salvedad D6).
**Spec:** `docs/kiro_roles_spec/requirements.md` (RF-01–RF-07) y `design.md`.

Notas de lectura:
- Mapeo de columnas vigente (decisión de equipo, bitácora fila 1):
  `id_usuario`→`id`, `email`→`mail`, `password_hash`→`contrasena`.
  Los literales del pedido con esos nombres fallan con
  `no existe la columna` (no es un tema de permisos).
- `information_schema.role_column_grants` SÍ existe en PG17 y se usa abajo.
- Las pruebas dinámicas corrieron en `BEGIN ... ROLLBACK` con `SAVEPOINT`
  por prueba (`ON_ERROR_STOP=0` para capturar los `ERROR` esperados);
  el conteo final de `pedido` quedó en 5: nada persistió.

## 1. Roles (`\du` equivalente)

```text
      rolname      | rolcanlogin
-------------------+-------------
 admin_datos       | t
 app_web           | t
 rol_app_escritura | f
 rol_app_lectura   | f
 rol_auditoria     | f
 rol_reportes      | f
 rol_soporte       | f
(7 filas)
```

## 2. `information_schema.role_table_grants` (roles TP7, schema `public`)

```text
      grantee      |        table_name         | privilege_type
-------------------+---------------------------+----------------
 admin_datos       | categoria                 | DELETE
 admin_datos       | categoria                 | INSERT
 admin_datos       | categoria                 | REFERENCES
 admin_datos       | categoria                 | SELECT
 admin_datos       | categoria                 | TRIGGER
 admin_datos       | categoria                 | TRUNCATE
 admin_datos       | categoria                 | UPDATE
 admin_datos       | cliente                   | DELETE
 admin_datos       | cliente                   | INSERT
 admin_datos       | cliente                   | REFERENCES
 admin_datos       | cliente                   | SELECT
 admin_datos       | cliente                   | TRIGGER
 admin_datos       | cliente                   | TRUNCATE
 admin_datos       | cliente                   | UPDATE
 admin_datos       | detalle_pedido            | DELETE
 admin_datos       | detalle_pedido            | INSERT
 admin_datos       | detalle_pedido            | REFERENCES
 admin_datos       | detalle_pedido            | SELECT
 admin_datos       | detalle_pedido            | TRIGGER
 admin_datos       | detalle_pedido            | TRUNCATE
 admin_datos       | detalle_pedido            | UPDATE
 admin_datos       | pedido                    | DELETE
 admin_datos       | pedido                    | INSERT
 admin_datos       | pedido                    | REFERENCES
 admin_datos       | pedido                    | SELECT
 admin_datos       | pedido                    | TRIGGER
 admin_datos       | pedido                    | TRUNCATE
 admin_datos       | pedido                    | UPDATE
 admin_datos       | producto                  | DELETE
 admin_datos       | producto                  | INSERT
 admin_datos       | producto                  | REFERENCES
 admin_datos       | producto                  | SELECT
 admin_datos       | producto                  | TRIGGER
 admin_datos       | producto                  | TRUNCATE
 admin_datos       | producto                  | UPDATE
 admin_datos       | usuario                   | DELETE
 admin_datos       | usuario                   | INSERT
 admin_datos       | usuario                   | REFERENCES
 admin_datos       | usuario                   | SELECT
 admin_datos       | usuario                   | TRIGGER
 admin_datos       | usuario                   | TRUNCATE
 admin_datos       | usuario                   | UPDATE
 admin_datos       | v_catalogo_productos      | DELETE
 admin_datos       | v_catalogo_productos      | INSERT
 admin_datos       | v_catalogo_productos      | REFERENCES
 admin_datos       | v_catalogo_productos      | SELECT
 admin_datos       | v_catalogo_productos      | TRIGGER
 admin_datos       | v_catalogo_productos      | TRUNCATE
 admin_datos       | v_catalogo_productos      | UPDATE
 admin_datos       | v_detalle_pedido_producto | DELETE
 admin_datos       | v_detalle_pedido_producto | INSERT
 admin_datos       | v_detalle_pedido_producto | REFERENCES
 admin_datos       | v_detalle_pedido_producto | SELECT
 admin_datos       | v_detalle_pedido_producto | TRIGGER
 admin_datos       | v_detalle_pedido_producto | TRUNCATE
 admin_datos       | v_detalle_pedido_producto | UPDATE
 admin_datos       | v_pedido_cliente          | DELETE
 admin_datos       | v_pedido_cliente          | INSERT
 admin_datos       | v_pedido_cliente          | REFERENCES
 admin_datos       | v_pedido_cliente          | SELECT
 admin_datos       | v_pedido_cliente          | TRIGGER
 admin_datos       | v_pedido_cliente          | TRUNCATE
 admin_datos       | v_pedido_cliente          | UPDATE
 admin_datos       | v_reporte_ventas_cliente  | DELETE
 admin_datos       | v_reporte_ventas_cliente  | INSERT
 admin_datos       | v_reporte_ventas_cliente  | REFERENCES
 admin_datos       | v_reporte_ventas_cliente  | SELECT
 admin_datos       | v_reporte_ventas_cliente  | TRIGGER
 admin_datos       | v_reporte_ventas_cliente  | TRUNCATE
 admin_datos       | v_reporte_ventas_cliente  | UPDATE
 admin_datos       | v_usuario_publico         | DELETE
 admin_datos       | v_usuario_publico         | INSERT
 admin_datos       | v_usuario_publico         | REFERENCES
 admin_datos       | v_usuario_publico         | SELECT
 admin_datos       | v_usuario_publico         | TRIGGER
 admin_datos       | v_usuario_publico         | TRUNCATE
 admin_datos       | v_usuario_publico         | UPDATE
 rol_app_escritura | categoria                 | INSERT
 rol_app_escritura | categoria                 | UPDATE
 rol_app_escritura | cliente                   | INSERT
 rol_app_escritura | cliente                   | UPDATE
 rol_app_escritura | detalle_pedido            | INSERT
 rol_app_escritura | detalle_pedido            | UPDATE
 rol_app_escritura | pedido                    | INSERT
 rol_app_escritura | pedido                    | UPDATE
 rol_app_escritura | producto                  | INSERT
 rol_app_escritura | producto                  | UPDATE
 rol_app_lectura   | categoria                 | SELECT
 rol_app_lectura   | cliente                   | SELECT
 rol_app_lectura   | detalle_pedido            | SELECT
 rol_app_lectura   | pedido                    | SELECT
 rol_app_lectura   | producto                  | SELECT
 rol_app_lectura   | v_catalogo_productos      | SELECT
 rol_app_lectura   | v_detalle_pedido_producto | SELECT
 rol_app_lectura   | v_pedido_cliente          | SELECT
 rol_reportes      | v_reporte_ventas_cliente  | SELECT
 rol_reportes      | v_usuario_publico         | SELECT
(97 filas)
```

`rol_soporte`, `rol_auditoria` y `app_web`: 0 filas a nivel tabla (correcto:
columnas / monitoreo / herencia). `PUBLIC` en tablas de `public`: **0 filas**.

## 3. `information_schema.role_column_grants` (`usuario`)

`rol_soporte` (RF-03 exacto, sin `contrasena`):

```text
   grantee   | table_name | column_name | privilege_type
-------------+------------+-------------+----------------
 rol_soporte | usuario    | apellido    | SELECT
 rol_soporte | usuario    | celular     | SELECT
 rol_soporte | usuario    | created_at  | SELECT
 rol_soporte | usuario    | eliminado   | SELECT
 rol_soporte | usuario    | eliminado   | UPDATE
 rol_soporte | usuario    | id          | SELECT
 rol_soporte | usuario    | mail        | SELECT
 rol_soporte | usuario    | nombre      | SELECT
 rol_soporte | usuario    | rol         | SELECT
(9 filas)
```

`admin_datos`: `INSERT/REFERENCES/SELECT/UPDATE` en las 9 columnas
(derivado de su `ALL`; el propietario `postgres` muestra las mismas filas).

## 4. Funciones (`role_routine_grants`, schema `public`)

```text
      grantee      |     routine_name     | privilege_type
-------------------+----------------------+----------------
 admin_datos       | fn_autenticar        | EXECUTE
 admin_datos       | fn_resetear_password | EXECUTE
 postgres          | fn_autenticar        | EXECUTE
 postgres          | fn_resetear_password | EXECUTE
 rol_app_escritura | fn_autenticar        | EXECUTE
 rol_soporte       | fn_resetear_password | EXECUTE
(6 filas)
```

(`postgres` = propietario.) `PUBLIC` en ambas funciones: **0 filas**.
Matriz RF-05 exacta; resto NINGUNO.

## 5. Membresías y controles complementarios

```text
  login  |    miembro_de
---------+-------------------
 app_web | rol_app_escritura
 app_web | rol_app_lectura
(2 filas)
```

`admin_datos`: sin herencia (permisos directos). Complementos:
`has_table_privilege('rol_reportes','mv_resumen_ventas_categoria_mes','SELECT')=t`
(la matview no figura en `role_table_grants` por construcción del catálogo),
`lectura` sobre la matview `=f`;
`rol_app_escritura`: `USAGE cliente_id_seq=t`, `SELECT pedido_id_seq=t`,
`USAGE usuario_id_seq=f`; `rol_auditoria` miembro de `pg_monitor`.

`pg_default_acl` en `public` (tras la serie D6):

```text
 para_objetos_de | tipo |                             defaclacl
-----------------+------+-------------------------------------------------------------------
 postgres        | S    | {rol_app_escritura=rU/postgres}
 postgres        | r    | {rol_app_lectura=r/postgres,rol_app_escritura=arw/postgres}
 admin_datos     | S    | {rol_app_escritura=rU/admin_datos}
 admin_datos     | r    | {rol_app_lectura=r/admin_datos,rol_app_escritura=arw/admin_datos}
(4 filas)
```

## 6. Pruebas dinámicas `SET ROLE` (`BEGIN ... ROLLBACK`)

### 6.1 `SET ROLE rol_soporte`

```text
BEGIN
SET
SAVEPOINT
ERROR:  no existe la columna «id_usuario»     -- literal pedido: columnas inexistentes
ROLLBACK
SAVEPOINT
 id | nombre |        mail
----+--------+---------------------
  1 | Admin  | admin@foodstore.com
(1 fila)                                       -- equivalente real: OK
ROLLBACK
SAVEPOINT
ERROR:  permiso denegado a la tabla usuario    -- SELECT *: denegado ✓
ROLLBACK
SAVEPOINT
ERROR:  permiso denegado a la tabla usuario    -- SELECT contrasena: denegado ✓
ROLLBACK
SAVEPOINT
ERROR:  no existe la columna «password_hash»  -- literal pedido: columna inexistente
ROLLBACK
RESET
ROLLBACK
```

### 6.2 `SET ROLE app_web`

```text
BEGIN
SET
SAVEPOINT
 id |   nombre
----+------------
  1 | Muzzarella
  2 | Napolitana
(2 filas)                                       -- lectura operativa: OK
ROLLBACK
SAVEPOINT
 id
----
  6
(1 fila)
INSERT 0 1                                      -- insert operativo: OK (revertido)
ROLLBACK
SAVEPOINT
 login_ok
----------
        1                                       -- fn_autenticar: OK
(1 fila)
ROLLBACK
SAVEPOINT
ERROR:  se ha denegado el permiso para otorgar el rol «admin_datos»
DETALLE:  Sólo los roles con la opción ADMIN en el rol «admin_datos» pueden otorgar este rol.
                                                -- escalamiento: FALLA ✓
ROLLBACK
SAVEPOINT
ERROR:  debe ser dueño de la tabla categoria   -- DROP TABLE: FALLA ✓
ROLLBACK
RESET
ROLLBACK
SELECT count(*) AS pedidos_tras_rollback FROM pedido;  -->  5 (nada persistió)
```

## 7. Contraste contra la spec y veredicto

| RF / diseño | Esperado | Observado | Estado |
|---|---|---|---|
| RF-01 tablas | lectura S×5; escritura IU×5 sin DELETE; admin ALL×6 | idéntico (§2) | ✅ |
| RF-02 vistas | lectura 3 operativas; reportes 2 + matview | idéntico (§2 + §5) | ✅ |
| RF-03 columnas | soporte 8 SELECT + UPDATE(eliminado), sin hash | idéntico (§3); `SELECT contrasena` denegado (§6.1) | ✅ |
| RF-04 secuencias | escritura USAGE,SELECT en 4 (sin usuario) | idéntico (§5) | ✅ |
| RF-05 funciones | escritura→autenticar, soporte→resetear, admin→ambas | idéntico (§4) | ✅ |
| RF-06 auditoría | `pg_monitor`, sin datos de negocio | miembro `pg_monitor`, 0 grants de negocio | ✅ |
| RF-07 defaults | herencia lectura/escritura en tablas y secuencias | 4 filas `pg_default_acl` (`postgres` + `admin_datos`) | ✅ |
| Restricciones §4 | sin DELETE/DDL en app; sin hash en soporte; sin herencia en admin | probado en §6.2/§6.1/§5 | ✅ |

**Veredicto: 100% "ni más, ni menos".** Salvedades documentadas:
(1) los literales `id_usuario/email/password_hash` no existen en el esquema
(mapeo vigente `id/mail/contrasena`, bitácora fila 1);
(2) `PUBLIC` conserva `EXECUTE` en builtins de `pg_catalog` (default del motor,
fuera del alcance; revocado en tablas/funciones de `public`).
