-- scripts/lab5/04-agrupamiento-equilibrio.sql
-- Factor de agrupamiento (clustering factor) y punto de equilibrio
-- entre el uso de un indice y el recorrido completo de la tabla.
-- Se ejecuta como SYSDBA:
-- bash scripts/ops/sysdba.sh <este archivo> <evidencia>
-- Solo lee. Mide el coste de utilizar indices y recorrer la tabla entera.

WHENEVER SQLERROR EXIT FAILURE

SET LINESIZE 170 PAGESIZE 100 FEEDBACK OFF VERIFY OFF TAB OFF

COLUMN index_name FORMAT A16
COLUMN veredicto FORMAT A52

ALTER SESSION SET CONTAINER = FREEPDB1;

SET SERVEROUTPUT ON FORMAT WRAPPED

PROMPT
PROMPT ===== 1. FACTOR DE AGRUPAMIENTO SEGUN EL DICCIONARIO =====
PROMPT Compara el CF con los bloques y las filas de la tabla.

SELECT i.index_name,
       i.clustering_factor AS cf,
       t.blocks AS bloques_tabla,
       t.num_rows AS filas_tabla,
       CASE
           WHEN i.clustering_factor < 2 * t.blocks
               THEN 'BUENO: filas vecinas en el indice y en disco'
           WHEN i.clustering_factor > 0.5 * t.num_rows
               THEN 'MALO: casi cada entrada salta a otro bloque'
           ELSE 'INTERMEDIO'
       END AS veredicto
FROM dba_indexes i
JOIN dba_tables t
  ON t.owner = i.table_owner
 AND t.table_name = i.table_name
WHERE i.owner = 'TIENDASUR'
  AND i.table_name = 'PEDIDO'
ORDER BY i.clustering_factor;

PROMPT
PROMPT ===== 2. CALCULO MANUAL DEL FACTOR DE AGRUPAMIENTO =====
PROMPT Cuenta cuantas veces cambia el bloque al recorrer las filas.

SELECT 'IX_PED_FECHA' AS index_name,
       SUM(cambia) AS cf_calculado
FROM (
    SELECT CASE
               WHEN DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID) =
                    LAG(DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID))
                    OVER (ORDER BY fecha_pedido, ROWID)
                   THEN 0
               ELSE 1
           END AS cambia
    FROM tiendasur.pedido
)
UNION ALL
SELECT 'IX_PED_CLIENTE',
       SUM(cambia)
FROM (
    SELECT CASE
               WHEN DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID) =
                    LAG(DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID))
                    OVER (ORDER BY id_cliente, ROWID)
                   THEN 0
               ELSE 1
           END AS cambia
    FROM tiendasur.pedido
);

PROMPT El calculo manual aproxima el CF contando los cambios de bloque.
PROMPT El orden de recorrido debe coincidir con el de cada indice.

PROMPT
PROMPT ===== 3. CURVA DEL PUNTO DE EQUILIBRIO =====
PROMPT Mide las lecturas logicas para sumar el importe de distintos porcentajes.

DECLARE
    b NUMBER;
    r NUMBER;
    v NUMBER;
    ini DATE;
    idx_bueno NUMBER;
    idx_malo NUMBER;
    completo NUMBER;
    elige VARCHAR2(30);

    FUNCTION estad(p VARCHAR2) RETURN NUMBER IS
        x NUMBER;
    BEGIN
        SELECT m.value
        INTO x
        FROM v$mystat m
        JOIN v$statname s
          ON s.statistic# = m.statistic#
        WHERE s.name = p;

        RETURN x;
    END;

    FUNCTION lecturas(q VARCHAR2) RETURN NUMBER IS
        x NUMBER;
    BEGIN
        -- Primera ejecucion para calentar la consulta.
        EXECUTE IMMEDIATE q INTO v;

        x := estad('session logical reads');

        -- Segunda ejecucion para medir las lecturas.
        EXECUTE IMMEDIATE q INTO v;

        RETURN estad('session logical reads') - x;
    END;

    FUNCTION optimizador(q VARCHAR2) RETURN VARCHAR2 IS
        x VARCHAR2(30);
    BEGIN
        DELETE FROM plan_table
        WHERE statement_id = 'lab5';

        EXECUTE IMMEDIATE
            'EXPLAIN PLAN SET STATEMENT_ID = ''lab5'' FOR ' || q;

        SELECT MAX(
            CASE
                WHEN operation = 'TABLE ACCESS'
                 AND options = 'FULL'
                    THEN 'recorrido completo'
                WHEN operation = 'INDEX'
                    THEN 'indice'
            END
        )
        INTO x
        FROM plan_table
        WHERE statement_id = 'lab5';

        RETURN x;
    END;

BEGIN
    SELECT blocks, num_rows
    INTO b, r
    FROM dba_tables
    WHERE owner = 'TIENDASUR'
      AND table_name = 'PEDIDO';

    SELECT MIN(fecha_pedido)
    INTO ini
    FROM tiendasur.pedido;

    DBMS_OUTPUT.PUT_LINE(
        'b = ' || b ||
        ' bloques, r = ' || r ||
        ' filas, bfr = ' || ROUND(r / b)
    );

    DBMS_OUTPUT.PUT_LINE(
        RPAD('k %', 8) ||
        LPAD('filas', 9) ||
        LPAD('indice CF bueno', 18) ||
        LPAD('indice CF malo', 17) ||
        LPAD('tabla entera', 15) ||
        ' optimizador (CF malo)'
    );

    completo := lecturas(
        'SELECT /*+ FULL(p) */ SUM(importe) ' ||
        'FROM tiendasur.pedido p'
    );

    FOR f IN (
        SELECT COLUMN_VALUE AS pct
        FROM TABLE(
            sys.odcinumberlist(
                0.01, 0.05, 0.1, 0.2, 0.5,
                1, 2, 5, 10, 20, 50, 100
            )
        )
    ) LOOP

        idx_bueno := lecturas(
            'SELECT /*+ INDEX(p ix_ped_fecha) */ SUM(importe) ' ||
            'FROM tiendasur.pedido p ' ||
            'WHERE fecha_pedido < TIMESTAMP ''' ||
            TO_CHAR(
                ini + 3 * 365 * f.pct / 100,
                'YYYY-MM-DD HH24:MI:SS'
            ) || ''''
        );

        idx_malo := lecturas(
            'SELECT /*+ INDEX(p ix_ped_cliente) */ SUM(importe) ' ||
            'FROM tiendasur.pedido p ' ||
            'WHERE id_cliente <= ' || ROUND(1000 * f.pct)
        );

        elige := optimizador(
            'SELECT SUM(importe) ' ||
            'FROM tiendasur.pedido p ' ||
            'WHERE id_cliente <= ' || ROUND(1000 * f.pct)
        );

        DBMS_OUTPUT.PUT_LINE(
            RPAD(f.pct || ' %', 8) ||
            LPAD(ROUND(r * f.pct / 100), 9) ||
            LPAD(idx_bueno, 18) ||
            LPAD(idx_malo, 17) ||
            LPAD(completo, 15) ||
            ' ' || elige ||
            CASE
                WHEN idx_bueno > completo
                    THEN ' <- el indice bueno pierde'
                WHEN idx_malo > completo
                    THEN ' <- el indice malo lee mas que la tabla'
                ELSE ''
            END
        );

    END LOOP;

    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE(
        'Teoria (Unidad 3, 3.1.8): con CF malo, cada fila puede ' ||
        'provocar una lectura aleatoria. El indice compensa si ' ||
        'k/r < (1/bfr) * (c_sec/c_aleat).'
    );

    DBMS_OUTPUT.PUT_LINE(
        'En lecturas logicas (c_sec = c_aleat): k/r < 1/' ||
        ROUND(r / b) || ' = ' ||
        ROUND(100 * b / r, 2) || ' %.'
    );

    DBMS_OUTPUT.PUT_LINE(
        'En disco, con c_sec/c_aleat = 1/5: k/r < ' ||
        ROUND(100 * b / r / 5, 2) ||
        ' %. La lectura aleatoria es mas costosa.'
    );

    ROLLBACK;
END;
/

PROMPT
PROMPT Con CF BUENO, el indice puede leer menos bloques de tabla.
PROMPT El CF depende del orden fisico de las filas respecto al indice.
PROMPT Reconstruir el indice NO garantiza mejorar el CF.
PROMPT Reordenar fisicamente la tabla puede mejorarlo.

EXIT
