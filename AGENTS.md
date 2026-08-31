# Agent Guidelines — Base de Datos II (UTN FRM)

## Repository Structure & Scope
- **Domain:** PostgreSQL relational database coursework (`foodstore` schema).
- **`TP1_FoodStore/`**: Base DDL (`schema.sql`), DBML, ER diagrams, and academic documentation.
- **`TP2_Concurrencia_IA/`**: Working folder for TP2 concurrency experiments, SQL scripts, and backup dumps.

## Safety & Database Protocol (`protocolo_seguridad.md`)
> **CRITICAL RULE:** AI agents propose/write scripts, but MUST NEVER apply unverified changes or target the primary `foodstore_dev` database.

### 1. Target Database Isolation
- **Base DB:** `foodstore_dev` (never execute tests directly here).
- **Work DB:** `foodstore_copia_trabajo` (used for all experimental queries and tests).
- **Create work copy:**
  ```bash
  createdb -U postgres -T foodstore_dev foodstore_copia_trabajo
  ```
- **Reset dirty work copy:**
  ```bash
  dropdb -U postgres foodstore_copia_trabajo && createdb -U postgres -T foodstore_dev foodstore_copia_trabajo
  ```

### 2. Mandatory Transactional Execution
- All DML (`INSERT`, `UPDATE`, `DELETE`) and DDL MUST run inside explicit transaction blocks:
  ```sql
  BEGIN;
  -- Run script/query
  -- Verification (SELECT / \d)
  ROLLBACK; -- Default for validation; COMMIT only upon explicit user approval
  ```
- **Connect string:** `psql -U postgres -d foodstore_copia_trabajo`

### 3. DDL Backup Workflow
- Prior to running DDL changes (`ALTER TABLE`, `DROP`, `CREATE INDEX`, etc.), export a backup inside `TP2_Concurrencia_IA/`:
  ```bash
  pg_dump -U postgres -d foodstore_copia_trabajo -f TP2_Concurrencia_IA/respaldo_foodstore_copia_trabajo.sql
  ```
- **Restore from backup:**
  ```bash
  dropdb -U postgres foodstore_copia_trabajo && createdb -U postgres foodstore_copia_trabajo && psql -U postgres -d foodstore_copia_trabajo -f TP2_Concurrencia_IA/respaldo_foodstore_copia_trabajo.sql
  ```

## Key Schema & SQL Conventions
- **PostgreSQL Version:** 14+ (Targeting PostgreSQL 17 on Windows / Git Bash).
- **Initial Dev Schema Load:** `psql -U postgres -d foodstore_dev -f TP1_FoodStore/schema.sql`
- **Soft Deletes:** `activo = false` used for logical deletion; foreign keys enforce `ON DELETE RESTRICT`.
- **Generated Columns:** `detalle_pedido.subtotal` is `GENERATED ALWAYS AS (cantidad * precio_unitario) STORED`.
