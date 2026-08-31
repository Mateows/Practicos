# Bugfix Requirements Document

## Introduction

The `producto` table definition in `schema.sql` is missing a comma after the `created_at` column definition, immediately before the constraint block. This single-character omission causes a PostgreSQL syntax error when the DDL script is executed, preventing the entire schema from being created.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the `schema.sql` script is executed in PostgreSQL AND the `producto` table definition contains `created_at timestamp not null default current_timestamp` without a trailing comma before the constraint block THEN the system raises a syntax error and aborts schema creation.

1.2 WHEN any downstream table (`pedido`, `detalle_pedido`) or index creation statement is reached THEN the system fails to execute them because the earlier syntax error halted the script.

### Expected Behavior (Correct)

2.1 WHEN the `schema.sql` script is executed in PostgreSQL AND the `created_at` column definition ends with a trailing comma (`created_at timestamp not null default current_timestamp,`) THEN the system SHALL parse the `producto` table definition without syntax errors.

2.2 WHEN the full `schema.sql` script is executed THEN the system SHALL successfully create all tables (`categoria`, `cliente`, `producto`, `pedido`, `detalle_pedido`), constraints, and indexes without errors.

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the `producto` table is created with the corrected script THEN the system SHALL CONTINUE TO enforce all existing check constraints (`ck_precio_lista`, `ck_stock_actual`) and the foreign key `fk_producto_categoria` exactly as defined.

3.2 WHEN a product row is inserted with a non-negative `precio_lista` and non-negative `stock_actual` THEN the system SHALL CONTINUE TO accept the row without error.

3.3 WHEN a product row is inserted with a negative `precio_lista` or negative `stock_actual` THEN the system SHALL CONTINUE TO reject the row with a check constraint violation.

3.4 WHEN all other tables (`categoria`, `cliente`, `pedido`, `detalle_pedido`) and indexes are created by the same script THEN the system SHALL CONTINUE TO apply their constraints and behaviors unchanged.
