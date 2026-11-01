-- scripts/lab5/06-propuesta-companero.sql
-- Q16: Los cinco índices que propone un compañero
-- "para que todo vaya rápido".
--
-- Se crean para medir su coste.
-- 06-protocolo.sql los audita y 06-indices.sh
-- los elimina antes de aplicar V005.

WHENEVER SQLERROR EXIT FAILURE

SET FEEDBACK OFF
SET VERIFY OFF
SET SERVEROUTPUT ON

ALTER SESSION SET CONTAINER = FREEPDB1;

-- ------------------------------------------------------------
-- Limpieza de restos de una ejecución anterior
-- ------------------------------------------------------------

BEGIN
    -- Eliminar los cinco índices si ya existen.
    FOR i IN (
        SELECT index_name
        FROM dba_indexes
        WHERE owner = 'TIENDASUR'
          AND index_name IN (
              'IX_PED_ESTADO',
              'IX_PED_CANAL',
              'IX_PED_CLI_FEC',
              'IX_PED_FEC_CLI',
              'IX_PED_CP'
          )
    ) LOOP
        EXECUTE IMMEDIATE
            'DROP INDEX TIENDASUR.' || i.index_name;
    END LOOP;

    -- Restaurar IX_PED_IMPORTE si existe y está invisible.
    FOR i IN (
        SELECT index_name
        FROM dba_indexes
        WHERE owner = 'TIENDASUR'
          AND index_name = 'IX_PED_IMPORTE'
          AND visibility = 'INVISIBLE'
    ) LOOP
        EXECUTE IMMEDIATE
            'ALTER INDEX TIENDASUR.' || i.index_name || ' VISIBLE';
    END LOOP;
END;
/

-- ------------------------------------------------------------
-- Creación de los cinco índices propuestos
-- ------------------------------------------------------------

CREATE INDEX tiendasur.ix_ped_estado
    ON tiendasur.pedido (estado);

CREATE INDEX tiendasur.ix_ped_canal
    ON tiendasur.pedido (canal);

CREATE INDEX tiendasur.ix_ped_cli_fec
    ON tiendasur.pedido (id_cliente, fecha_pedido);

CREATE INDEX tiendasur.ix_ped_fec_cli
    ON tiendasur.pedido (fecha_pedido, id_cliente);

CREATE INDEX tiendasur.ix_ped_cp
    ON tiendasur.pedido (codigo_postal);

-- ------------------------------------------------------------
-- Comprobación de los índices creados
-- ------------------------------------------------------------

PROMPT
PROMPT ==========================================
PROMPT Propuesta del compañero creada correctamente
PROMPT ==========================================

SELECT index_name,
       table_name,
       status,
       visibility
FROM dba_indexes
WHERE owner = 'TIENDASUR'
  AND index_name IN (
      'IX_PED_ESTADO',
      'IX_PED_CANAL',
      'IX_PED_CLI_FEC',
      'IX_PED_FEC_CLI',
      'IX_PED_CP'
  )
ORDER BY index_name;

EXIT
