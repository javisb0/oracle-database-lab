
    FOR i IN (
        SELECT index_name
        FROM dba_indexes
        WHERE owner = 'TIENDASUR'
          AND table_name = 'PEDIDO'
          AND index_name <> 'PK_PEDIDO'
    ) LOOP
        EXECUTE IMMEDIATE
            'ALTER INDEX tiendasur.' || i.index_name ||
            ' MONITORING USAGE';
    END LOOP;
END;
/

PROMPT Ejecutamos la carga habitual de TiendaSur.
PROMPT Consultas Q2, Q3, Q7, Q8, Q9 y Q12.

EXEC lab_tools.medir.consulta('Q2 ultimo mes', q'[SELECT id_pedido, importe FROM tiendasur.pedido WHERE fecha_pedido >= CURRENT_DATE - INTERVAL '30' DAY]')

EXEC lab_tools.medir.consulta('Q3 codigo postal', q'[SELECT id_pedido, estado FROM tiendasur.pedido WHERE codigo_postal = '30001']')

EXEC lab_tools.medir.consulta('Q7 historial', q'[SELECT id_pedido, fecha_pedido, importe, estado FROM tiendasur.pedido WHERE id_cliente = 4711 AND fecha_pedido >= SYSDATE - 365 ORDER BY fecha_pedido DESC]')

EXEC lab_tools.medir.consulta('Q8 contador', q'[SELECT COUNT(*) FROM tiendasur.pedido WHERE fecha_pedido >= TRUNC(SYSDATE, 'YYYY')]')

EXEC lab_tools.medir.consulta('Q9 ultimos 20', q'[SELECT * FROM tiendasur.pedido ORDER BY fecha_pedido DESC FETCH FIRST 20 ROWS ONLY]')

EXEC lab_tools.medir.consulta('Q12 pendientes', q'[SELECT id_pedido, id_cliente, fecha_pedido FROM tiendasur.pedido WHERE estado = 'P' ORDER BY fecha_pedido]')

PROMPT
PROMPT Resultado del uso de los indices:

SELECT index_name,
       used AS usado,
       monitoring
FROM dba_object_usage
WHERE owner = 'TIENDASUR'
  AND table_name = 'PEDIDO'
ORDER BY used, index_name;

PROMPT Desactivamos la monitorizacion.

BEGIN
    FOR i IN (
        SELECT index_name
        FROM dba_object_usage
        WHERE owner = 'TIENDASUR'
          AND monitoring = 'YES'
    ) LOOP
        EXECUTE IMMEDIATE
            'ALTER INDEX tiendasur.' || i.index_name ||
            ' NOMONITORING USAGE';
    END LOOP;
END;
/

PROMPT En produccion la observacion debe durar semanas.
PROMPT Hay que incluir cierres de mes e informes trimestrales.
PROMPT Oracle 23ai dispone tambien de estadisticas automaticas de uso.
PROMPT

PROMPT ===== PREGUNTA 2. VIABILIDAD: SELECTIVIDAD =====
PROMPT Comparamos la selectividad con el punto de equilibrio aproximado.

SELECT i.index_name,
       i.distinct_keys AS claves,
       ROUND(100 / NULLIF(i.distinct_keys, 0), 3) AS pct_por_valor_medio,
       CASE
           WHEN i.distinct_keys IS NULL OR i.distinct_keys = 0
               THEN 'SIN ESTADISTICAS'
           WHEN 100 / i.distinct_keys > 0.5
               THEN 'NO VIABLE: supera el 0,5 % por valor medio'
           ELSE 'VIABLE'
       END AS veredicto
FROM dba_indexes i
WHERE i.owner = 'TIENDASUR'
  AND i.table_name = 'PEDIDO'
ORDER BY i.distinct_keys;

PROMPT La selectividad depende de la distribucion real de los valores.
PROMPT Un valor poco frecuente puede justificar un indice.
PROMPT Un indice parcial puede ser mejor para estados poco frecuentes.
PROMPT

PROMPT ===== PREGUNTA 3. ESCRITURA: COSTE DE MANTENIMIENTO =====

PROMPT Cada indice adicional aumenta el trabajo de los INSERT.
PROMPT Tambien aumenta el trabajo de UPDATE y DELETE.
PROMPT Consulta las medidas de 06-medir-dml.sql para comparar escenarios.
PROMPT El coste depende del numero de indices y de su estructura.
PROMPT

PROMPT ===== PREGUNTA 4. REDUNDANCIA: PREFIJO IZQUIERDO =====
PROMPT Buscamos indices cuyas columnas sean prefijo de otros indices.

WITH c AS (
    SELECT i.index_name,
           i.table_name,
           i.uniqueness,
           COUNT(*) AS num_columnas,
           LISTAGG(ic.column_name, ', ')
               WITHIN GROUP (ORDER BY ic.column_position) AS cols
    FROM dba_indexes i
    JOIN dba_ind_columns ic
      ON ic.index_owner = i.owner
     AND ic.index_name = i.index_name
    WHERE i.owner = 'TIENDASUR'
    GROUP BY i.index_name,
             i.table_name,
             i.uniqueness
)
SELECT a.index_name AS redundante,
       a.cols AS columnas,
       b.index_name AS cubierto_por,
       b.cols AS columnas_del_otro
FROM c a
JOIN c b
  ON b.table_name = a.table_name
 AND b.index_name <> a.index_name
 AND b.num_columnas > a.num_columnas
WHERE a.uniqueness = 'NONUNIQUE'
  AND NOT EXISTS (
      SELECT 1
      FROM dba_ind_columns ca
      WHERE ca.index_owner = 'TIENDASUR'
        AND ca.index_name = a.index_name
        AND NOT EXISTS (
            SELECT 1
            FROM dba_ind_columns cb
            WHERE cb.index_owner = 'TIENDASUR'
              AND cb.index_name = b.index_name
              AND cb.column_position = ca.column_position
              AND cb.column_name = ca.column_name
        )
  )
ORDER BY a.index_name;

PROMPT Un indice UNIQUE puede garantizar una regla de negocio.
PROMPT No debe eliminarse solo porque sea prefijo de otro indice.
PROMPT La clave ajena id_cliente debe tener un indice que empiece por id_cliente.
PROMPT Sin el, un DELETE de un cliente puede provocar comprobaciones costosas.
PROMPT

PROMPT ===== PREGUNTA 5. CICLO DE VIDA: HACER INVISIBLE ANTES DE BORRAR =====
PROMPT Ocultamos temporalmente el indice IX_PED_IMPORTE.

ALTER INDEX tiendasur.ix_ped_importe INVISIBLE;

SELECT index_name,
       visibility,
       status
FROM dba_indexes
WHERE owner = 'TIENDASUR'
  AND index_name = 'IX_PED_IMPORTE';

EXEC lab_tools.medir.consulta('Q2 sin ix_ped_importe', q'[SELECT id_pedido, importe FROM tiendasur.pedido WHERE fecha_pedido >= CURRENT_DATE - INTERVAL '30' DAY]')

PROMPT Un indice invisible no es utilizado normalmente por el optimizador.
PROMPT Oracle sigue manteniendolo durante INSERT, UPDATE y DELETE.
PROMPT Si una consulta empeora, puede hacerse visible de nuevo.

PROMPT Para recuperarlo:
PROMPT ALTER INDEX tiendasur.ix_ped_importe VISIBLE;

PROMPT Si nadie lo necesita durante la observacion, puede eliminarse.
PROMPT La eliminacion definitiva se realizara mediante la migracion V005.

EXIT
