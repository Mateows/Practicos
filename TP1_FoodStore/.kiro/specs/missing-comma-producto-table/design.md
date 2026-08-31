# Missing Comma in `producto` Table Bugfix Design

## Overview

The `producto` table DDL in `schema.sql` is syntactically invalid because the `created_at` column definition is not followed by a comma before the first `CONSTRAINT` clause. PostgreSQL requires a comma separator between every column definition and every subsequent column or constraint in a `CREATE TABLE` statement. The fix is a single-character addition: appending `,` to the end of the `created_at` line.

## Glossary

- **Bug_Condition (C)**: The `CREATE TABLE producto` statement contains `created_at timestamp not null default current_timestamp` immediately followed by a constraint block without a separating comma.
- **Property (P)**: The `CREATE TABLE producto` statement must be syntactically valid PostgreSQL DDL that executes without error.
- **Preservation**: All other columns, constraints, indexes, and tables in `schema.sql` must remain byte-for-byte identical after the fix.
- **`schema.sql`**: The DDL script located at `TP1_FoodStore/schema.sql` that creates the full FoodStore database schema.
- **`created_at` column**: The last column definition in the `producto` table, declared as `timestamp not null default current_timestamp`.

## Bug Details

### Bug Condition

The bug manifests when PostgreSQL attempts to parse the `CREATE TABLE producto` statement. The parser expects either a comma or a closing parenthesis after each column or table-level constraint; it finds a `CONSTRAINT` keyword instead, causing a syntax error.

**Formal Specification:**
```
FUNCTION isBugCondition(ddlStatement)
  INPUT: ddlStatement of type String (a CREATE TABLE statement)
  OUTPUT: boolean

  RETURN ddlStatement CONTAINS column_definition
         AND column_definition ENDS_WITH "current_timestamp"  -- no trailing comma
         AND NEXT_TOKEN(column_definition) IS "constraint"
END FUNCTION
```

### Examples

- **Buggy**: `created_at timestamp not null default current_timestamp\n    constraint ck_precio_lista ...` — PostgreSQL raises `ERROR: syntax error at or near "constraint"`.
- **Fixed**: `created_at timestamp not null default current_timestamp,\n    constraint ck_precio_lista ...` — statement executes successfully.
- **Other tables** (`categoria`, `cliente`, `pedido`, `detalle_pedido`): not affected — their column lists are correctly comma-separated.

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- All other lines in `schema.sql` remain identical (no other edits).
- All other tables (`categoria`, `cliente`, `pedido`, `detalle_pedido`) continue to be created without modification.
- All indexes and the `enum_forma_pago` type remain unchanged.
- All existing constraints, foreign keys, and check constraints inside `producto` remain unchanged.

**Scope:**
Only the single character `,` is added at the end of the `created_at` column definition line. Every other byte in the file is preserved.

## Hypothesized Root Cause

1. **Manual Editing Omission**: The `created_at` column was the last column added to the table definition; the trailing comma that separates it from the constraint block was accidentally omitted during editing.
2. **No Automated Linting**: The DDL file is not run through a SQL formatter or linter in CI, so the syntax error was not caught before commit.
3. **No Local Execution Feedback**: The schema was not executed locally against a PostgreSQL instance to surface the error before it was stored.

## Correctness Properties

Property 1: Bug Condition - Syntax Validity of `CREATE TABLE producto`

_For any_ execution of `schema.sql` against a PostgreSQL instance, the fixed script SHALL parse and execute the `CREATE TABLE producto` statement without a syntax error, producing the `producto` table with all seven columns and all defined constraints.

**Validates: Requirements 2.1, 2.2**

Property 2: Preservation - All Other DDL Unchanged

_For any_ other statement in `schema.sql` (DROP TABLE, CREATE TYPE, CREATE TABLE for other tables, CREATE INDEX), the fixed script SHALL produce exactly the same result as the original script would produce if the comma were present, preserving all other schema objects.

**Validates: Requirements 3.1, 3.2**

## Fix Implementation

### Changes Required

**File**: `schema.sql`

**Location**: Inside `CREATE TABLE producto`, column `created_at`

**Specific Changes:**

1. **Add trailing comma**: Change the line
   ```sql
   created_at timestamp not null default current_timestamp
   ```
   to
   ```sql
   created_at timestamp not null default current_timestamp,
   ```
   This is the only change. No other lines are touched.

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, demonstrate the syntax error on the unfixed file, then verify the fixed file executes cleanly and all other objects are preserved.

### Exploratory Bug Condition Checking

**Goal**: Surface the counterexample that demonstrates the parse error BEFORE implementing the fix. Confirm the root cause.

**Test Plan**: Run `psql` (or `pg_dump --schema-only` dry-run) against the unfixed `schema.sql` and capture the error output.

**Test Cases:**
1. **Syntax Parse Test**: Execute `psql -f schema.sql` on unfixed file → expect `ERROR: syntax error at or near "constraint"` on the `ck_precio_lista` line. (fails on unfixed code)
2. **Table Creation Test**: Query `information_schema.tables` for `producto` after running unfixed script → table does not exist. (fails on unfixed code)

**Expected Counterexamples:**
- PostgreSQL reports a syntax error immediately when it reaches the `constraint` keyword after `created_at`.
- Possible cause: missing comma separator — confirmed as the sole root cause.

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed script produces the expected behavior.

**Pseudocode:**
```
FOR ALL ddlStatement WHERE isBugCondition(ddlStatement) DO
  result := execute_fixed(ddlStatement)
  ASSERT result.error IS NULL
  ASSERT tableExists("producto")
  ASSERT columnCount("producto") == 7
END FOR
```

### Preservation Checking

**Goal**: Verify that for all statements where the bug condition does NOT hold, the fixed script produces the same result as the original script.

**Pseudocode:**
```
FOR ALL statement WHERE NOT isBugCondition(statement) DO
  ASSERT execute_original(statement) == execute_fixed(statement)
END FOR
```

**Testing Approach**: Property-based testing is appropriate here because the set of other DDL statements is finite and enumerable; each can be checked individually.

**Test Plan**: Run the fixed `schema.sql` end-to-end and assert every expected object exists with the correct structure.

**Test Cases:**
1. **Other Tables Preservation**: Verify `categoria`, `cliente`, `pedido`, `detalle_pedido` all exist with correct columns after running fixed script.
2. **Constraints Preservation**: Verify all `CHECK` constraints and foreign keys on `producto` are present and enforce their rules.
3. **Indexes Preservation**: Verify `idx_pedido_cliente` and `idx_producto_categoria` exist with the correct definitions.

### Unit Tests

- Verify the fixed file contains exactly one more character than the original (the added comma).
- Verify `CREATE TABLE producto` contains seven column definitions.
- Verify all constraint names (`ck_precio_lista`, `ck_stock_actual`, `fk_producto_categoria`) are present.

### Property-Based Tests

- Generate random valid `precio_lista` values (including 0) and verify the `CHECK` constraint accepts non-negative values and rejects negatives.
- Generate random `stock_actual` values and verify the `CHECK` constraint accepts ≥ 0 and rejects < 0.
- Generate random product rows referencing valid and invalid `id_categoria` values and verify referential integrity is enforced.

### Integration Tests

- Execute the full `schema.sql` against a fresh PostgreSQL database and verify all five tables exist.
- Insert a complete test dataset (categoria → producto → cliente → pedido → detalle_pedido) and verify no constraint violations.
- Verify soft-delete behavior: setting `activo = false` on a product does not delete the row.
