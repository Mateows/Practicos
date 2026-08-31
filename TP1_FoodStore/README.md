# Trabajo Práctico N.º 1 - Base de Datos I (UTN FRM)
**Proyecto Integrador:** Food Store (Semana 1)
**Comisión:** 1PRO4
**Integrantes:**
- Lucas Avila
- Amanda Pagano
- Mateo Lautaro Liendo

---

## Contenido del Paquete de Entrega (`Grupo_Avila_Pagano_Liendo_TP1.zip`)

1. **`TP1_FoodStore_Grupo_Avila_Pagano_Liendo.pdf`**:
   Documento académico formal completo con:
   - Carátula institucional UTN FRM y datos del grupo.
   - **Parte 1 (MER):** Diccionario de entidades y atributos, cardinalidades, participaciones y respuestas a preguntas guía.
   - **Parte 2 (MR):** Reglas formales de pasaje, esquemas relacionales con PK/FK y respuestas a preguntas guía.
   - **Parte 3 (Normalización):** Determinación de clave candidata universal, lista de Dependencias Funcionales (DF1 a DF4), proceso paso a paso de 1FN, 2FN, 3FN y demostración rigurosa de BCNF, tablas finales y preguntas de integración.
   - **Parte 4 (DDL):** Explicación de decisiones de diseño en PostgreSQL, restricciones declarativas, justificación de los 3 índices y verificación DML.
   - **DUIA:** Declaración de Uso de Inteligencia Artificial según protocolo de la cátedra.

2. **`diagrama_er.png` / `diagrama_er.pdf`**:
   Diagrama Entidad-Relación visual de alta definición (300 DPI y vectorizado).

3. **`schema.sql`**:
   Script DDL completo, comentado y probado para PostgreSQL 14+, que incluye creación de tipos ENUM, tablas, claves primarias, claves foráneas (`ON DELETE RESTRICT`), restricciones `CHECK` y `UNIQUE`, columnas generadas (`STORED`), 3 índices B-Tree justificados y un conjunto de datos de prueba basado en la planilla original.

4. **`dbdiagram_code.dbml`**:
   Código fuente en formato DBML para importar o editar directamente en `dbdiagram.io`.

---

## Instrucciones de Ejecución del Script SQL

Para ejecutar y probar el script en una base de datos PostgreSQL:

```bash
psql -U postgres -d postgres -f schema.sql
```
