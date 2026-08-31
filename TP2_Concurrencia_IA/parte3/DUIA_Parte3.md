# Declaración de Uso de IA (DUIA) - Parte 3 (Lectura Crítica)

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | Kiro (IDE con agente integrado) |
| **Spec o prompt utilizado** | "Completar el archivo ejercicio_lectura_critica.md agregando las secciones 6.1 (tabla de casos reales) y 6.2 (patrón común), tomando los casos directamente del enunciado del TP y conectando cada punto de falla con el paso del protocolo de seguridad que lo neutraliza." |
| **Qué generó** | La sección 6.1 con la tabla de los 4 casos reales (Replit, Google Gemini CLI, PocketOS, Confusión de entorno) y la sección 6.2 con el análisis del patrón común entre ellos. |
| **Qué se aceptó** | El contenido de los casos reales y la conexión entre puntos de falla y pasos del protocolo. |
| **Qué se modificó o descartó, y por qué** | El análisis de los dos scripts SQL (sección 6.3) ya estaba redactado previamente por el alumno y no fue tocado por la IA. Se verificó que lo generado en 6.1 y 6.2 coincidiera con el enunciado del TP antes de aceptarlo. |
| **Verificación realizada** | Se contrastó cada caso de 6.1 contra el enunciado original del TP. Se verificó que cada punto de falla de 6.2 tenga correspondencia directa con uno de los tres pasos del `protocolo_seguridad.md`. Para el 6.3, los scripts pertenecen al esquema genérico de cátedra (tablas `funcion` y `categoria`). Se verificó conceptualmente el efecto de cada uno: Script 1 sin WHERE actualiza todas las filas sin distinción; Script 2 con NOT IN falla silenciosamente ante valores NULL en la subconsulta. Ambos análisis se confirmaron contra el comportamiento estándar de SQL documentado. |
