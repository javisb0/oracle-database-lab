-- scripts/lab5/06-medir-dml.sql
-- Q16: Medición del coste de escritura en PEDIDO.
--
-- Este script recibe la variable escenario desde 06-indices.sh.
-- Todas las operaciones se deshacen mediante ROLLBACK
-- dentro del paquete LAB_TOOLS.MEDIR.

WHENEVER SQLERROR EXIT FAILURE

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF
SET VERIFY OFF
SET TAB OFF

COLUMN indices FORMAT A110 WORD_WRAPPED

ALTER SESSION SET CONTAINER = FREEPDB1;

SET SERVEROUTPUT ON FORMAT WRAPPED

PROMPT
PROMPT ==========================================
PROMPT Escenario: &escenario
PROMPT ==========================================

-- ------------------------------------------------------------
-- Índices existentes
-- ------------------------------------------------------------

SELECT COUNT(*) AS indices_en_pedido,
       LISTAGG(index_name, ', ')
           WITHIN GROUP (ORDER BY index_name) AS indices
FROM dba_indexes
WHERE owner = 'TIENDASUR'
  AND table_name = 'PEDIDO';

-- ------------------------------------------------------------
-- 2000 INSERT
-- ------------------------------------------------------------

BEGIN
    lab_tools.medir.dml(
        '&escenario: 2000 INSERT',
        q'~BEGIN
            FOR i IN 1 .. 2000 LOOP
                INSERT INTO tiendasur.pedido (
                    id_pedido,
                    id_cliente,
                    fecha_pedido,
                    estado,
                    importe,
                    canal,
                    codigo_postal
                )
                VALUES (
                    2000000 + i,
                    MOD(i * 7919, 100000) + 1,
                    SYSTIMESTAMP,
                    'P',
                    10 + MOD(i, 90),
                    'W',
                    TO_CHAR(25000 + MOD(i * 31, 11000))
                );
            END LOOP;
        END;~',
        2000
    );
END;
/

-- ------------------------------------------------------------
-- 2000 UPDATE de estado
-- ------------------------------------------------------------

BEGIN
    lab_tools.medir.dml(
        '&escenario: 2000 UPDATE estado',
        q'~BEGIN
            FOR i IN 980001 .. 982000 LOOP
                UPDATE tiendasur.pedido
                SET estado = 'E'
                WHERE id_pedido = i;
            END LOOP;
        END;~',
        2000
    );
END;
/

-- ------------------------------------------------------------
-- 2000 UPDATE de importe
-- ------------------------------------------------------------

BEGIN
    lab_tools.medir.dml(
        '&escenario: 2000 UPDATE importe',
        q'~BEGIN
            FOR i IN 980001 .. 982000 LOOP
                UPDATE tiendasur.pedido
                SET importe = importe + 1
                WHERE id_pedido = i;
            END LOOP;
        END;~',
        2000
    );
END;
/

-- ------------------------------------------------------------
-- 2000 DELETE
-- ------------------------------------------------------------

BEGIN
    lab_tools.medir.dml(
        '&escenario: 2000 DELETE',
        q'~BEGIN
            FOR i IN 1 .. 2000 LOOP
                DELETE FROM tiendasur.pedido
                WHERE id_pedido = i;
            END LOOP;
        END;~',
        2000
    );
END;
/

EXIT
