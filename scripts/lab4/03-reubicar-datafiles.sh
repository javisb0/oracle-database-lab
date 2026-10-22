#!/usr/bin/env bash
# scripts/lab4/03-reubicar-datafiles.sh — corrige el hallazgo del Lab 3: lleva los datafiles de negocio
# a la carpeta estándar de FREEPDB1, dentro del volumen, y les pone un techo de crecimiento (MAXSIZE).
# Método OFFLINE porque Oracle AI Database Free no incluye «Online Move Datafile» (ORA-00439).
# Idempotente: si no hay nada que mover, no hace nada.
set -euo pipefail
source scripts/deployment/env/00-config.sh
DESTDIR="$DATA_ROOT/FREE/FREEPDB1"
sysdba() { docker exec -i "$CONT_NAME" sqlplus -s -L / as sysdba; }
echo "== 1. Datafiles de negocio fuera de $DESTDIR =="
LISTA=$(sysdba <<'SQL' | grep '|' || true
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 400 TRIMOUT ON
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT tablespace_name || '|' || file_name FROM dba_data_files
WHERE tablespace_name LIKE 'TBS\_%' ESCAPE '\'
AND file_name NOT LIKE '/opt/oracle/oradata/FREE/FREEPDB1/%'
ORDER BY tablespace_name;
SQL
)
if [ -z "$LISTA" ]; then
echo "Nada que reubicar: ya están todos en $DESTDIR"
else
echo "$LISTA"
while IFS='|' read -r TBS ORIG; do
NUEVO="$DESTDIR/$(basename "$ORIG")"
echo "== 2. $TBS: $ORIG -> $NUEVO =="
echo " a) tablespace OFFLINE (checkpoint del tablespace: el archivo queda consistente)"
sysdba <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET FEEDBACK ON
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER TABLESPACE $TBS OFFLINE NORMAL;
SQL
echo " b) copia física conservando permisos (el original NO se borra todavía)"
docker exec "$CONT_NAME" cp -p "$ORIG" "$NUEVO"
echo " c) el control file apunta a la nueva ruta, tablespace ONLINE y techo de 1 GB"
sysdba <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET FEEDBACK ON
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER TABLESPACE $TBS RENAME DATAFILE '$ORIG' TO '$NUEVO';
ALTER TABLESPACE $TBS ONLINE;
ALTER DATABASE DATAFILE '$NUEVO' AUTOEXTEND ON NEXT 50M MAXSIZE 1G;
SQL
echo " d) ONLINE correcto (Oracle validó la cabecera del archivo): se borra el original"
docker exec "$CONT_NAME" rm -f "$ORIG"
done <<< "$LISTA"
fi
echo "== 3. Resultado =="
sysdba <<'SQL'
SET LINESIZE 200 PAGESIZE 50 FEEDBACK OFF
COLUMN tablespace_name FORMAT A14
COLUMN file_name FORMAT A50
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT tablespace_name, file_name, status, autoextensible,
ROUND(bytes / 1048576) AS mb, ROUND(maxbytes / 1048576) AS max_mb
FROM dba_data_files WHERE tablespace_name LIKE 'TBS\_%' ESCAPE '\' ORDER BY 1;
SQL
