-- TP5 Parte A, Caso 3 (Q4): correlacion fisica de pedido.fecha_hora.
-- Sostiene el descarte del BRIN: un BRIN solo sirve si los valores estan
-- ordenados fisicamente como las paginas (correlacion cercana a 1 o -1).
-- El valor sale de una muestra y cambia con cada ANALYZE; lo que importa
-- es que sea cercano a 0.
-- Solo lectura: no modifica la base.
SELECT now() AS medido_el, tablename, attname, correlation
FROM pg_stats
WHERE tablename = 'pedido' AND attname = 'fecha_hora';
