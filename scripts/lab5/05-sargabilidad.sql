-- scripts/lab5/05-sargabilidad.sql
-- Reglas de oro de la sargabilidad: consulta rota frente a consulta reescrita.
-- Ronda 1 de la Actividad 3.2.
-- Se ejecuta como SYSDBA:
-- bash scripts/ops/sysdba.sh <este archivo> <evidencia>
-- La columna indexada debe quedar desnuda a un lado del operador.
-- Los indices temporales de esta parte se borran al final.

WHENEVER SQLERROR EXIT FAILURE

SET LINESIZE 200 PAGESIZE 100 FEEDBACK OFF VERIFY OFF TAB OFF

ALTER SESSION SET CONTAINER = FREEPDB1;

SET SERVEROUTPUT ON FORMAT WRAPPED

-- Comprobacion previa a V005.
-- Si V005 ya esta aplicada, se detiene para no borrar sus indices.
-- Si una ejecucion anterior fallo, se eliminan los indices temporales.

DECLARE
    n NUMBER;

    PROCEDURE quitar(p_ddl VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_ddl;
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
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
            'V005 ya esta aplicada: este experimento es anterior. ' ||
            'Restaura la copia lab4-final y vuelve a la Parte B.'
        );
    END IF;

    quitar('DROP INDEX tiendasur.ix_ped_cp');
    quitar('DROP INDEX tiendasur.ix_cli_apellidos');
    quitar('DROP INDEX tiendasur.ix_cli_telefono');
END;
/

-- Recuperamos el email y el telefono del cliente de prueba.
COLUMN tel NEW_VALUE tel NOPRINT
COLUMN email NEW_VALUE email NOPRINT

SELECT telefono AS tel,
       email AS email
FROM tiendasur.cliente
WHERE id_cliente = 4711;

-- Indices temporales para los experimentos.
CREATE INDEX tiendasur.ix_ped_cp
ON tiendasur.pedido (codigo_postal);

CREATE INDEX tiendasur.ix_cli_apellidos
ON tiendasur.cliente (apellidos);

PROMPT
PROMPT ===== REGLA 1. FUNCION SOBRE LA COLUMNA =====
PROMPT Q1: inicio de sesion mediante email.

EXEC lab_tools.medir.consulta('Q1 rota', q'[SELECT id_cliente, nombre FROM tiendasur.cliente WHERE UPPER(email) = UPPER('Cliente4711@TiendaSur.es')]')

EXEC lab_tools.medir.consulta('Q1 reescrita', q'[SELECT id_cliente, nombre FROM tiendasur.cliente WHERE email = LOWER('Cliente4711@TiendaSur.es')]')

PROMPT La funcion se aplica al dato de entrada y no a la columna.
PROMPT El email ya se guarda en minusculas.
PROMPT

PROMPT ===== REGLA 2. ARITMETICA SOBRE LA COLUMNA =====
PROMPT Q2: pedidos del ultimo mes.

EXEC lab_tools.medir.consulta('Q2 rota', q'[SELECT id_pedido, importe FROM tiendasur.pedido WHERE fecha_pedido + INTERVAL '30' DAY >= CURRENT_DATE]')

EXEC lab_tools.medir.consulta('Q2 reescrita', q'[SELECT id_pedido, importe FROM tiendasur.pedido WHERE fecha_pedido >= CURRENT_DATE - INTERVAL '30' DAY]')

PROMPT Se despeja la columna como en una ecuacion.
PROMPT La suma de 30 dias pasa al otro lado como una resta.
PROMPT

PROMPT ===== REGLA 3. CONVERSION IMPLICITA DE TIPOS =====
PROMPT Q3: envios por codigo postal.
PROMPT Se compara una columna VARCHAR2 con un numero.

EXEC lab_tools.medir.consulta('Q3 rota', q'[SELECT id_pedido, estado FROM tiendasur.pedido WHERE codigo_postal = 30001]')

EXEC lab_tools.medir.consulta('Q3 reescrita', q'[SELECT id_pedido, estado FROM tiendasur.pedido WHERE codigo_postal = '30001']')

PROMPT Comprobacion del predicado en el plan de ejecucion.

SET SERVEROUTPUT OFF

SELECT /*+ GATHER_PLAN_STATISTICS */ COUNT(estado)
FROM tiendasur.pedido
WHERE codigo_postal = 30001;

SELECT plan_table_output
FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'BASIC +PREDICATE'))
WHERE plan_table_output LIKE '%filter%'
   OR plan_table_output LIKE '%access%';

SET SERVEROUTPUT ON FORMAT WRAPPED

PROMPT Oracle puede convertir implicitamente la columna de texto a numero.
PROMPT Esto puede impedir el uso eficiente del indice.
PROMPT La comparacion correcta utiliza una cadena entre comillas.
PROMPT

PROMPT ===== REGLA 4. COMODIN A LA IZQUIERDA =====
PROMPT Q4: buscador de atencion al cliente.

EXEC lab_tools.medir.consulta('Q4a LIKE %ez', q'[SELECT * FROM tiendasur.cliente WHERE apellidos LIKE '%ez']')

EXEC lab_tools.medir.consulta('Q4b LIKE Gonz%', q'[SELECT * FROM tiendasur.cliente WHERE apellidos LIKE 'Gonz%']')

PROMPT Un indice B-tree esta ordenado por el principio de la cadena.
PROMPT Gonz% permite buscar un rango; %ez no tiene un prefijo conocido.
PROMPT Para buscar por el final puede utilizarse Oracle Text o una columna invertida con indice.
PROMPT

PROMPT ===== REGLA 5. OR CON UNA COLUMNA SIN INDICE =====
PROMPT Q5: identificar a un cliente por email o telefono.

EXEC lab_tools.medir.consulta('Q5 OR sin indice en telefono', q'[SELECT * FROM tiendasur.cliente WHERE email = '&email' OR telefono = '&tel']')

CREATE INDEX tiendasur.ix_cli_telefono
ON tiendasur.cliente (telefono);

EXEC lab_tools.medir.consulta('Q5 OR con los dos indices', q'[SELECT * FROM tiendasur.cliente WHERE email = '&email' OR telefono = '&tel']')

EXEC lab_tools.medir.consulta('Q5 como UNION', q'[SELECT * FROM tiendasur.cliente WHERE email = '&email' UNION SELECT * FROM tiendasur.cliente WHERE telefono = '&tel']')

PROMPT Un OR puede utilizar indices si cada rama tiene su propio indice.
PROMPT UNION permite ejecutar las dos busquedas por separado.
PROMPT

PROMPT ===== BONUS. Q11: REESCRIBIR NO OBLIGA A USAR EL INDICE =====
PROMPT Busqueda de pedidos de un año concreto.

EXEC lab_tools.medir.consulta('Q11 rota EXTRACT', q'[SELECT SUM(importe) FROM tiendasur.pedido WHERE EXTRACT(YEAR FROM fecha_pedido) = 2025]')

EXEC lab_tools.medir.consulta('Q11 reescrita rango', q'[SELECT SUM(importe) FROM tiendasur.pedido WHERE fecha_pedido >= DATE '2025-01-01' AND fecha_pedido < DATE '2026-01-01']')

PROMPT Un año puede representar una parte importante de todos los pedidos.
PROMPT El recorrido completo puede ser la mejor opcion en este caso.
PROMPT La version con rango permite al optimizador estimar mejor las filas.
PROMPT Sargable no significa necesariamente que se utilice el indice.
PROMPT

PROMPT ===== LIMPIEZA DE LOS INDICES TEMPORALES =====

DROP INDEX tiendasur.ix_ped_cp;
DROP INDEX tiendasur.ix_cli_apellidos;
DROP INDEX tiendasur.ix_cli_telefono;

SELECT COUNT(*) AS indices_tiendasur
FROM dba_indexes
WHERE owner = 'TIENDASUR';

EXIT
