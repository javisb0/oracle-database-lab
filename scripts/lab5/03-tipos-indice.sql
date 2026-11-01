-- scripts/lab5/03-tipos-indice.sql
-- Cada tipo de indice frente a la consulta de TiendaSur para la que existe (Actividad 3.2).
-- Se ejecuta como SYSDBA: bash scripts/ops/sysdba.sh <este archivo> <evidencia>
-- Todo lo que crea se borra al final. Lo que se decida conservar entra por migracion V005, Parte G.

WHENEVER SQLERROR EXIT FAILURE

SET LINESIZE 250 PAGESIZE 100 FEEDBACK OFF VERIFY OFF TAB OFF
COLUMN index_name FORMAT A22
COLUMN index_type FORMAT A22

ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON FORMAT WRAPPED

-- Experimento previo a V005. Si V005 ya esta aplicada, se detiene.
-- Si una ejecucion anterior fallo a medias, se eliminan sus restos para poder repetirla.
DECLARE
    n NUMBER;

    PROCEDURE quitar(p_ddl VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_ddl;
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
BEGIN
    SELECT COUNT(*)
    INTO n
    FROM dba_indexes
    WHERE owner = 'TIENDASUR'
      AND index_name = 'IX_PED_CLIENTE';

    IF n = 0 THEN
        RAISE_APPLICATION_ERROR(
            -20005,
            'V005 ya esta aplicada: este experimento es anterior. Restaura la copia lab4-final y vuelve a la Parte B'
        );
    END IF;

    quitar('DROP INDEX tiendasur.ux_cli_dni');
    quitar('DROP INDEX tiendasur.ix_ped_cli_fec');
    quitar('DROP INDEX tiendasur.ix_ped_cli_fec_cub');
    quitar('DROP INDEX tiendasur.ix_cli_upper_email');
    quitar('DROP INDEX tiendasur.ix_ped_est_fec');
    quitar('DROP INDEX tiendasur.ix_ped_pendientes');
    quitar('ALTER TABLE tiendasur.pedido DROP COLUMN fecha_pendiente');
    quitar('DROP TABLE tiendasur.venta_hecho PURGE');
    quitar('DROP TABLE tiendasur.sesion_heap PURGE');
    quitar('DROP TABLE tiendasur.sesion_iot PURGE');
    quitar('DROP TABLE tiendasur.sesion_hash');
    quitar('DROP CLUSTER tiendasur.cl_sesion');
END;
/

COLUMN dni NEW_VALUE dni NOPRINT
SELECT dni FROM tiendasur.cliente WHERE id_cliente = 4711;

PROMPT
PROMPT ===== 1. UNICO (Q13, verificacion de identidad) =====

EXEC lab_tools.medir.consulta('Q13 sin indice', q'[SELECT id_cliente, nombre, apellidos FROM tiendasur.cliente WHERE dni = '&dni']')

CREATE UNIQUE INDEX tiendasur.ux_cli_dni
ON tiendasur.cliente (dni);

EXEC lab_tools.medir.consulta('Q13 con UNIQUE (dni)', q'[SELECT id_cliente, nombre, apellidos FROM tiendasur.cliente WHERE dni = '&dni']')

PROMPT -- La base de datos impide el duplicado (ORA-00001 esperado).

WHENEVER SQLERROR CONTINUE

INSERT INTO tiendasur.cliente
VALUES (999999, '&dni', 'otro@tiendasur.es', 'X', 'Y', NULL, 'ES', 'Lorca', SYSDATE);

WHENEVER SQLERROR EXIT FAILURE

PROMPT
PROMPT ===== 2. COMPUESTO Y REGLA DEL PREFIJO IZQUIERDO (Q6) =====

EXEC lab_tools.medir.consulta('Q6 solo ciudad', q'[SELECT id_cliente, nombre, apellidos FROM tiendasur.cliente WHERE ciudad = 'Lorca']')

EXEC lab_tools.medir.consulta('Q6 pais + ciudad', q'[SELECT id_cliente, nombre, apellidos FROM tiendasur.cliente WHERE pais = 'ES' AND ciudad = 'Lorca']')

PROMPT (Sin la primera columna, Oracle puede hacer SKIP SCAN. Funciona, pero no es el diseno ideal.)
PROMPT

PROMPT ===== 3. COMPUESTO Y CUBRIENTE (Q7, historial del cliente) =====

DEFINE q7 = "SELECT id_pedido, fecha_pedido, importe, estado FROM tiendasur.pedido WHERE id_cliente = 4711 AND fecha_pedido >= SYSDATE - 365 ORDER BY fecha_pedido DESC"

EXEC lab_tools.medir.consulta('Q7 con ix_ped_cliente', '&q7')

CREATE INDEX tiendasur.ix_ped_cli_fec
ON tiendasur.pedido (id_cliente, fecha_pedido);

EXEC lab_tools.medir.consulta('Q7 (id_cliente, fecha)', '&q7')

CREATE INDEX tiendasur.ix_ped_cli_fec_cub
ON tiendasur.pedido (id_cliente, fecha_pedido, importe, estado, id_pedido);

EXEC lab_tools.medir.consulta('Q7 cubriente', '&q7')

PROMPT (Igualdad primero, rango despues. El indice puede evitar el SORT y, si es cubriente, el acceso a la tabla.)
PROMPT (Oracle no tiene INCLUDE como SQL Server o PostgreSQL: las columnas adicionales se anaden al final de la clave.)
PROMPT

PROMPT ===== 4. FUNCIONAL (Q1, inicio de sesion con UPPER(email)) =====

EXEC lab_tools.medir.consulta('Q1 UPPER(email) tal cual', q'[SELECT id_cliente, nombre FROM tiendasur.cliente WHERE UPPER(email) = UPPER('Cliente4711@TiendaSur.es')]')

CREATE INDEX tiendasur.ix_cli_upper_email
ON tiendasur.cliente (UPPER(email));

EXEC lab_tools.medir.consulta('Q1 con indice funcional', q'[SELECT id_cliente, nombre FROM tiendasur.cliente WHERE UPPER(email) = UPPER('Cliente4711@TiendaSur.es')]')

PROMPT (El indice funcional puede ser util, pero tambien requiere mantenimiento.)
PROMPT

PROMPT ===== 5. PARCIAL A LA MANERA DE ORACLE (Q12, pedidos pendientes) =====

CREATE INDEX tiendasur.ix_ped_est_fec
ON tiendasur.pedido (estado, fecha_pedido);

ALTER TABLE tiendasur.pedido
ADD (fecha_pendiente AS (CASE WHEN estado = 'P' THEN fecha_pedido END));

CREATE INDEX tiendasur.ix_ped_pendientes
ON tiendasur.pedido (fecha_pendiente);

EXEC lab_tools.medir.consulta('Q12 (estado, fecha)', q'[SELECT id_pedido, id_cliente, fecha_pedido FROM tiendasur.pedido WHERE estado = 'P' ORDER BY fecha_pedido]')

EXEC lab_tools.medir.consulta('Q12 parcial', q'[SELECT id_pedido, id_cliente, fecha_pedido FROM tiendasur.pedido WHERE fecha_pendiente IS NOT NULL ORDER BY fecha_pendiente]')

SELECT index_name, leaf_blocks AS hojas, num_rows AS entradas
FROM dba_indexes
WHERE owner = 'TIENDASUR'
  AND index_name IN ('IX_PED_EST_FEC', 'IX_PED_PENDIENTES')
ORDER BY index_name;

PROMPT (Oracle no almacena claves totalmente NULL en un B-tree. El indice parcial solo contiene filas con fecha_pendiente.)
PROMPT

PROMPT ===== 6. BITMAP (Q14, almacen de datos) =====

CREATE TABLE tiendasur.venta_hecho NOLOGGING AS
SELECT ROWNUM AS id_venta,
       2021 + MOD(ORA_HASH(ROWNUM, 4294967295, 21), 5) AS anio,
       'R' || MOD(ORA_HASH(ROWNUM, 4294967295, 22), 6) AS region,
       SUBSTR('WAT', MOD(ORA_HASH(ROWNUM, 4294967295, 23), 3) + 1, 1) AS canal,
       'Cat' || MOD(ORA_HASH(ROWNUM, 4294967295, 24), 25) AS categoria,
       ROUND(MOD(ORA_HASH(ROWNUM, 4294967295, 25), 50000) / 100, 2) AS importe
FROM (SELECT 1 FROM dual CONNECT BY LEVEL <= 1000),
     (SELECT 1 FROM dual CONNECT BY LEVEL <= 1000);

CREATE INDEX tiendasur.ix_vh_region_btree
ON tiendasur.venta_hecho (region);

EXEC DBMS_STATS.GATHER_TABLE_STATS('TIENDASUR', 'VENTA_HECHO')

EXEC lab_tools.medir.consulta('Q14 sin bitmaps', q'[SELECT SUM(importe) FROM tiendasur.venta_hecho WHERE region = 'R1' AND canal = 'W' AND categoria = 'Cat7' AND anio = 2025]')

DROP INDEX tiendasur.ix_vh_region_btree;

CREATE BITMAP INDEX tiendasur.bx_vh_anio
ON tiendasur.venta_hecho (anio);

CREATE BITMAP INDEX tiendasur.bx_vh_region
ON tiendasur.venta_hecho (region);

CREATE BITMAP INDEX tiendasur.bx_vh_canal
ON tiendasur.venta_hecho (canal);

CREATE BITMAP INDEX tiendasur.bx_vh_categoria
ON tiendasur.venta_hecho (categoria);

EXEC lab_tools.medir.consulta('Q14 con 4 bitmaps', q'[SELECT SUM(importe) FROM tiendasur.venta_hecho WHERE region = 'R1' AND canal = 'W' AND categoria = 'Cat7' AND anio = 2025]')

CREATE INDEX tiendasur.ix_vh_region_btree
ON tiendasur.venta_hecho (region) INVISIBLE;

SELECT index_name, index_type, leaf_blocks AS hojas, distinct_keys AS claves
FROM dba_indexes
WHERE owner = 'TIENDASUR'
  AND table_name = 'VENTA_HECHO'
ORDER BY index_type, index_name;

PROMPT (Los bitmap son utiles para filtros combinados en almacenes de datos, pero pueden perjudicar escrituras concurrentes.)
PROMPT

PROMPT ===== 7. HASH E IOT (Q15, validar una sesion por su token) =====

CREATE TABLE tiendasur.sesion_heap (
    token CHAR(64) PRIMARY KEY,
    id_cliente NUMBER,
    caduca TIMESTAMP
);

CREATE TABLE tiendasur.sesion_iot (
    token CHAR(64) PRIMARY KEY,
    id_cliente NUMBER,
    caduca TIMESTAMP
) ORGANIZATION INDEX;

CREATE CLUSTER tiendasur.cl_sesion (token CHAR(64))
SIZE 100 SINGLE TABLE HASHKEYS 200000;

CREATE TABLE tiendasur.sesion_hash (
    token CHAR(64),
    id_cliente NUMBER,
    caduca TIMESTAMP
) CLUSTER tiendasur.cl_sesion (token);

INSERT INTO tiendasur.sesion_heap
SELECT STANDARD_HASH(TO_CHAR(LEVEL), 'SHA256'),
       MOD(LEVEL, 100000) + 1,
       SYSTIMESTAMP + MOD(LEVEL, 120) / 1440
FROM dual
CONNECT BY LEVEL <= 200000;

INSERT INTO tiendasur.sesion_iot
SELECT * FROM tiendasur.sesion_heap;

INSERT INTO tiendasur.sesion_hash
SELECT * FROM tiendasur.sesion_heap;

COMMIT;

COLUMN tok NEW_VALUE tok NOPRINT
SELECT RAWTOHEX(STANDARD_HASH('4711', 'SHA256')) AS tok FROM dual;

EXEC lab_tools.medir.consulta('Q15 monticulo + PK', q'[SELECT id_cliente FROM tiendasur.sesion_heap WHERE token = '&tok']')

EXEC lab_tools.medir.consulta('Q15 IOT', q'[SELECT id_cliente FROM tiendasur.sesion_iot WHERE token = '&tok']')

EXEC lab_tools.medir.consulta('Q15 cluster hash', q'[SELECT id_cliente FROM tiendasur.sesion_hash WHERE token = '&tok']')

EXEC lab_tools.medir.consulta('Q15 limpieza en hash', q'[SELECT COUNT(*) FROM tiendasur.sesion_hash WHERE caduca < SYSTIMESTAMP + 1/1440]')

PROMPT (Hash es adecuado para igualdad, pero no para rangos. IOT almacena la tabla como indice.)
PROMPT

PROMPT ===== 8. NINGUN INDICE ES GRATIS: espacio ocupado =====

SELECT s.segment_name AS index_name,
       i.index_type,
       ROUND(s.bytes / 1048576, 1) AS mb,
       i.leaf_blocks AS hojas
FROM dba_segments s
JOIN dba_indexes i
  ON i.owner = s.owner
 AND i.index_name = s.segment_name
WHERE s.owner = 'TIENDASUR'
  AND i.table_name IN ('CLIENTE', 'PEDIDO')
ORDER BY s.bytes DESC;

PROMPT

PROMPT ===== 9. LIMPIEZA: restaurar el estado inicial =====

DROP INDEX tiendasur.ux_cli_dni;
DROP INDEX tiendasur.ix_ped_cli_fec;
DROP INDEX tiendasur.ix_ped_cli_fec_cub;
DROP INDEX tiendasur.ix_cli_upper_email;
DROP INDEX tiendasur.ix_ped_est_fec;
DROP INDEX tiendasur.ix_ped_pendientes;

ALTER TABLE tiendasur.pedido DROP COLUMN fecha_pendiente;

DROP TABLE tiendasur.venta_hecho PURGE;
DROP TABLE tiendasur.sesion_heap PURGE;
DROP TABLE tiendasur.sesion_iot PURGE;
DROP TABLE tiendasur.sesion_hash;

DROP CLUSTER tiendasur.cl_sesion;

SELECT COUNT(*) AS indices_tiendasur
FROM dba_indexes
WHERE owner = 'TIENDASUR';

EXIT
