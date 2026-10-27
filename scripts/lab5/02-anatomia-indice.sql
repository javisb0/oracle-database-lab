WHENEVER SQLERROR EXIT FAILURE

SET LINESIZE 170 PAGESIZE 100 FEEDBACK OFF VERIFY OFF TAB OFF
COLUMN index_name FORMAT A18
COLUMN table_name FORMAT A8
COLUMN payload FORMAT A110
COLUMN clave_en_hexadecimal FORMAT A20
COLUMN bloque_hex FORMAT A10

ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON FORMAT WRAPPED

PROMPT
PROMPT ===== 1. El diccionario: altura, hojas, claves distintas y factor de agrupamiento de cada indice de TiendaSur =====

SELECT i.table_name,
       i.index_name,
       i.uniqueness AS unico,
       i.blevel + 1 AS altura,
       i.leaf_blocks AS hojas,
       i.distinct_keys AS claves,
       i.num_rows AS entradas,
       i.clustering_factor AS cf,
       t.blocks AS bloques_tabla
FROM dba_indexes i
JOIN dba_tables t
  ON t.owner = i.table_owner
 AND t.table_name = i.table_name
WHERE i.owner = 'TIENDASUR'
ORDER BY i.table_name, i.index_name;

PROMPT (Altura = BLEVEL + 1: BLEVEL cuenta los niveles de ramas, sin las hojas)
PROMPT

PROMPT ===== 2. Por dentro: ANALYZE INDEX VALIDATE STRUCTURE llena INDEX_STATS =====

ANALYZE INDEX tiendasur.ix_ped_cliente VALIDATE STRUCTURE;

SELECT name AS index_name,
       height AS altura,
       lf_rows AS entradas_hoja,
       lf_blks AS hojas,
       br_rows AS entradas_rama,
       br_blks AS ramas,
       ROUND(lf_rows_len / NULLIF(lf_rows, 0), 1) AS bytes_por_entrada,
       lf_blk_len AS bytes_utiles_hoja,
       pct_used,
       del_lf_rows AS borradas
FROM index_stats;

DECLARE
    s index_stats%ROWTYPE;
    fo_real NUMBER;
    fo_max NUMBER;
    cap_hoja NUMBER;
    h NUMBER;
BEGIN
    SELECT *
    INTO s
    FROM index_stats;

    -- Hijos por bloque de rama, de media; la raiz tiene pocos.
    fo_real := (s.lf_blks + s.br_blks - 1) / NULLIF(s.br_blks, 0);

    -- Numero de entradas de rama que caben en un bloque.
    fo_max := FLOOR(s.br_blk_len / NULLIF(s.br_rows_len / NULLIF(s.br_rows, 0), 0));

    -- Numero de entradas de hoja que caben en un bloque.
    cap_hoja := FLOOR(s.lf_blk_len / NULLIF(s.lf_rows_len / NULLIF(s.lf_rows, 0), 0));

    DBMS_OUTPUT.PUT_LINE(
        'Factor de ramificacion real (fo) = (hojas + ramas - 1) / ramas = (' ||
        s.lf_blks || ' + ' || s.br_blks || ' - 1) / ' ||
        s.br_blks || ' = ' || ROUND(fo_real)
    );

    DBMS_OUTPUT.PUT_LINE(
        'Factor de ramificacion maximo = bytes utiles de rama / bytes por entrada de rama = ' ||
        s.br_blk_len || ' / ' ||
        ROUND(s.br_rows_len / NULLIF(s.br_rows, 0), 1) ||
        ' = ' || fo_max
    );

    DBMS_OUTPUT.PUT_LINE(
        'Entradas por hoja: medidas ' || ROUND(s.lf_rows / NULLIF(s.lf_blks, 0)) ||
        ', maximo ' || cap_hoja ||
        ' -> llenado ' ||
        ROUND(100 * s.lf_rows / NULLIF(s.lf_blks, 0) / NULLIF(cap_hoja, 0)) ||
        ' % (PCTFREE 10 deja el 10 % libre al crear)'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Altura comprobada: 1 + ceil(log_fo(hojas)) = 1 + ceil(log_' ||
        fo_max || '(' || s.lf_blks || ')) = ' ||
        (1 + CEIL(LN(s.lf_blks) / NULLIF(LN(fo_max), 0))) ||
        ' (INDEX_STATS dice ' || s.height || ')'
    );

    FOR r IN (
        SELECT COLUMN_VALUE AS filas
        FROM TABLE(sys.odcinumberlist(1e6, 2e7, 1e9, 1e11))
    ) LOOP
        h := 1 + CEIL(
            LN(CEIL(r.filas / NULLIF(cap_hoja, 0) / 0.9)) /
            NULLIF(LN(fo_max), 0)
        );

        DBMS_OUTPUT.PUT_LINE(
            'Con ' || LPAD(TO_CHAR(r.filas, 'FM999G999G999G999'), 15) ||
            ' filas -> ' ||
            LPAD(CEIL(r.filas / NULLIF(cap_hoja, 0) / 0.9), 9) ||
            ' hojas -> altura ' || h ||
            ' -> ' || (h + 1) ||
            ' lecturas para encontrar UNA fila (altura + tabla)'
        );
    END LOOP;
END;
/

PROMPT (La altura crece con el logaritmo: de un millon a cien mil millones de filas, solo uno o dos niveles mas)
PROMPT

PROMPT ===== 3. El entorno de medida: GATHER_PLAN_STATISTICS y DISPLAY_CURSOR =====

SET SERVEROUTPUT OFF

SELECT /*+ GATHER_PLAN_STATISTICS */
       id_pedido, importe
FROM tiendasur.pedido
WHERE id_pedido = 4711;

PROMPT (Primera ejecucion descartada; se mide la segunda, en caliente)

SELECT /*+ GATHER_PLAN_STATISTICS */
       id_pedido, importe
FROM tiendasur.pedido
WHERE id_pedido = 4711;

SELECT plan_table_output
FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'IOSTATS LAST'));

PROMPT (Buffers = lecturas logicas: altura del indice + 1 bloque de tabla)

PROMPT -- Si la consulta solo pide columnas que estan en el indice, no hace falta ir a la tabla.

SELECT /*+ GATHER_PLAN_STATISTICS */
       id_pedido
FROM tiendasur.pedido
WHERE id_pedido = 4711;

SELECT plan_table_output
FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'IOSTATS LAST -PREDICATE'))
WHERE plan_table_output LIKE '|%';

SET SERVEROUTPUT ON FORMAT WRAPPED
PROMPT

PROMPT ===== 4. Raiz, rama y hoja: volcado real de los bloques de PK_CLIENTE =====

COLUMN oid NEW_VALUE oid NOPRINT
COLUMN f NEW_VALUE f NOPRINT

SELECT TO_CHAR(object_id) AS oid
FROM dba_objects
WHERE owner = 'TIENDASUR'
  AND object_name = 'PK_CLIENTE';

SELECT TO_CHAR(file_id) AS f
FROM dba_data_files
WHERE tablespace_name = 'TBS_TIENDASUR';

ALTER SESSION SET tracefile_identifier = 'lab5_indice';
ALTER SESSION SET EVENTS 'immediate trace name treedump level &oid';

COLUMN tf NEW_VALUE tf NOPRINT

SELECT SUBSTR(value, INSTR(value, '/', -1) + 1) AS tf
FROM v$diag_info
WHERE name = 'Default Trace File';

PROMPT -- El treedump: la raiz (branch) y sus primeras hojas (leaf).

SET PAGESIZE 0

SELECT RTRIM(payload, CHR(10)) AS payload
FROM v$diag_trace_file_contents
WHERE trace_filename = '&tf'
  AND (payload LIKE '%branch: 0x%' OR payload LIKE '%leaf: 0x%')
  AND ROWNUM <= 4;

SET PAGESIZE 100

COLUMN raiz NEW_VALUE raiz NOPRINT
COLUMN hoja1 NEW_VALUE hoja1 NOPRINT

SELECT MAX(
           CASE
               WHEN payload LIKE '%branch: 0x%'
               THEN REGEXP_SUBSTR(
                   payload,
                   'branch: 0x[0-9a-f]+ ([0-9]+)',
                   1, 1, NULL, 1
               )
           END
       ) AS raiz,
       MIN(
           CASE
               WHEN payload LIKE '%leaf: 0x%'
                AND payload LIKE '%(-1:%'
               THEN REGEXP_SUBSTR(
                   payload,
                   'leaf: 0x[0-9a-f]+ ([0-9]+)',
                   1, 1, NULL, 1
               )
           END
       ) AS hoja1
FROM v$diag_trace_file_contents
WHERE trace_filename = '&tf'
  AND (payload LIKE '%branch: 0x%' OR payload LIKE '%leaf: 0x%');

ALTER SYSTEM DUMP DATAFILE &f BLOCK &raiz;
ALTER SYSTEM DUMP DATAFILE &f BLOCK &hoja1;

SET PAGESIZE 0

WITH t AS (
    SELECT line_number AS n, payload
    FROM v$diag_trace_file_contents
    WHERE trace_filename = '&tf'
),
m AS (
    SELECT MIN(
               CASE
                   WHEN payload LIKE 'Branch block dump%' THEN n
               END
           ) AS rama,
           MIN(
               CASE
                   WHEN payload LIKE 'Leaf block dump%' THEN n
               END
           ) AS hoja
    FROM t
)
SELECT CASE
           WHEN t.n = m.rama THEN
               CHR(10) ||
               '--- [A] RAIZ: kdxconro entradas; kdxbrlmc = hijo de la izquierda; cada row# = clave + dba del hijo ---' ||
               CHR(10)
           WHEN t.n = m.hoja THEN
               CHR(10) ||
               '--- [B] HOJA: kdxcoavs = bytes libres; kdxlenxt/kdxleprv = hojas vecinas; row# = ROWID + clave ---' ||
               CHR(10)
       END ||
       RTRIM(t.payload, CHR(10)) AS payload
FROM t, m
WHERE (
          t.n BETWEEN m.rama AND m.rama + 20
          AND (
              t.payload LIKE 'Branch%'
              OR t.payload LIKE 'kdxco%'
              OR t.payload LIKE 'kdxbr%'
              OR t.payload LIKE 'row#%'
              OR t.payload LIKE 'col %'
          )
      )
   OR (
          t.n BETWEEN m.hoja AND m.hoja + 23
          AND (
              t.payload LIKE 'Leaf%'
              OR t.payload LIKE 'kdxco%'
              OR t.payload LIKE 'kdxle%'
              OR t.payload LIKE 'row#%'
              OR t.payload LIKE 'col %'
          )
      )
ORDER BY t.n;

SET PAGESIZE 100

PROMPT
PROMPT -- Comprobacion: la primera entrada de la hoja apunta al ROWID del cliente 1.

SELECT id_cliente,
       DUMP(id_cliente, 16) AS clave_en_hexadecimal,
       DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID, 'BIGFILE') AS bloque,
       TO_CHAR(
           DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID, 'BIGFILE'),
           'FM0XXXXXXX'
       ) AS bloque_hex,
       DBMS_ROWID.ROWID_ROW_NUMBER(ROWID) AS ranura
FROM tiendasur.cliente
WHERE id_cliente = 1;

PROMPT (data:(6) de la entrada = 4 bytes de bloque + 2 de ranura: ROWID corto de un indice de tablespace bigfile)

EXIT
