1. ¿Por qué la copia de la Parte B es consistente? ¿Qué pasaría si se tomara con la base abierta?
Es consistente porque el archivo backup-estado.sh hace un shutdown immediate y después Docker stop -t 120, este cierre hace que se fuerce un checkpoint, y hace que los archivos queden sin transacciones a medias.
Si se tomara con la base abierta sería inconsistente, mientras tar lee los archivos, DBWR sigue escribiendo bloques y los datafiles se copian en momentos distintos, con SCN diferentes. Al restaurarla, la base no abriría.
2. ¿Para qué sirven manifiesto.txt y SHA256SUMS? ¿Qué comprueba restaurar-estado.sh antes de tocar nada?
Manifiesto.txt describe la copia: etiqueta, fecha UTC, contenedor, volumen, imagen, commit de Git,y cuántos archivos estaban fuera del volumen. Dice qué es y de cuándo, sin abrirla.
SHA256SUMS guarda la huella SHA-256 de cada archivo de la copia. Sirve para detectar corrupción o modificación para que la información sea fiable (En caso de que no se pueda detectar su modificación o corrupción entonces no sería fiable)
Lo primero que hace restaurar-estado.sh es sha256sum --check --quiet SHA256SUMS, si falla se detiene sin tocar nada.
3. Define RPO y RTO con los datos de tu propia copia.
RPO son la cantidad de datos que puedo permitirme perder, en este laboratorio creamos una copia llamada lab3-final y se tomó antes de la parte C, por lo tanto, si se restaura se recuperarán los datos hasta esa parte y se perderán los de partes posteriores.
RTO es cuánto tarda en volver a dar servicio. Aquí es lo que tarda restaurar-estado.sh (comprobar hashes, parar, restaurar el volumen, arrancar y esperar a healthy).
4. ¿Dónde creó Oracle los datafiles de V000 y por qué? ¿Qué parámetro habría evitado el problema?
V000 hizo CREATE TABLESPACE TBS_ACADEMIA DATAFILE 'academia01.dbf', con ruta relativa. Como no había destino por defecto para archivos nuevos Oracle usó la ruta $ORACLE_HOME/dbs.
Lo habría evitado DB_CREATE_FILE_DEST apuntando al volumen (OMF) o también se podría haber hecho uso de la ruta absoluta.
5. ¿Por qué ALTER TABLESPACE ... RENAME DATAFILE no basta para mover un archivo?
Porque este comando no mueve nada, solo cambia la ruta que guarda el control file. Habría que usar el comando cp para copiarlo antes con el sistema operativo.
6. ¿Por qué no se edita V000 y se crea V003? ¿Por qué invalidar una contraseña es mejor que borrarla del archivo?
Porque V000 ya se ha aplicado, y su borrado haría que se perdiese la trazabilidad.
Como ya esta hecha la migración, borrar la contraseña del archivo sería inútil porque ya esta guardada en los registros de los commits, es necesario invalidarla porque cualquiera que pueda ver los registros tendrá acceso a la contraseña.
7. ¿Qué demuestra la prueba de persistencia y por qué se ejecuta después de reubicar?
Esta prueba demuestra que la base sobrevive al contenedor, se ejecuta después de reubicar porque si los datafiles siguieran fuera del volumen, el docker rm los destruiría.
8. Con tus evidencias: tres datos que pertenecen a la instancia y tres que pertenecen a la base de datos.
Instancia:
STARTUP_TIME en v$instance, cambia en cada arranque.
HOST_NAME (el id del contenedor): cambia si recreo el contenedor.
La SGA y los procesos de background (db_pmon_FREE, db_lgwr_FREE).

Base de datos:
DBID en v$database: identifica a la base y no cambia nunca.
CREATED, la fecha de construcción de la imagen, distinta de la de arranque.
Los archivos: 16 datafiles (3441 MB), 2 control files, 2 miembros de redo, y log_mode = NOARCHIVELOG.
9. ¿Qué lee Oracle en NOMOUNT, en MOUNT y en OPEN? Relaciónalo con ORA-01507 y ORA-01219.
NOMOUNT lee el SPFILE y lee los procesos, v$database -> ORA-01507 (database not mounted): lee el control file, aún cerrado.
MOUNT abre los control files, dba_tables -> ORA-01219 (database not open): el diccionario vive en SYSTEM, un datafile aún cerrado. Solo funcionan las vistas fijas
OPEN abre datafiles y redo online.
10. ¿Por qué FREEPDB1 se abre sola tras ALTER DATABASE OPEN? ¿Qué harías si no lo hiciera?
Porque la imagen ejecutó en su día ALTER PLUGGABLE DATABASE FREEPDB1 SAVE STATE, y dba_pdb_saved_states lo recuerda. Sin estado guardado la PDB quedaría en MOUNTED tras cada arranque.
Si no se abriera comprobaría SELECT name, open_mode FROM v$pdbs y la abriría con ALTER PLUGGABLE DATABASE FREEPDB1 OPEN.
11. Clasifica ORA-00800 y ORA-20013 del alert log: ¿alerta real o ruido conocido? Justifícalo.
Las dos son ruido conocido, ORA-00800 salta cuando Oracle quiere subir la prioridad de esos procesos y Docker no se lo permite, indica que la base funciona.
ORA-20013 indica que un inventario de parches no se leer dentro de la imagen de un contenedor, no afecta al funcionamiento.
12. Diferencia entre v$parameter y v$spparameter con el ejemplo de db_files de tu evidencia.
v$parameter: el valor efectivo en la instancia en ejecución.
v$spparameter: lo que hay escrito en el SPFILE (solo los parámetros especificados, isspecified = 'TRUE').
En 07-parametros-cambios db_files es estático. Con ALTER SYSTEM SET db_files 300 SCOPE = SPFILE, v$parameter sigue en 200 y v$spparameter muestra 300. Tras ALTER SYSTEM RESET db_files SCOPE = SPFILE, queda 200 en memoria y (no especificado) en el SPFILE, y vuelve a su valor por defecto.
13. ¿Qué hace SCOPE=BOTH y cuál es el SCOPE por defecto con SPFILE?
SCOPE=BOTH aplica el cambio ahora, en memoria, y lo escribe en el SPFILE, así que sobrevive al reinicio.
El SCOPE por defecto con SPFILE es BOTH.
14. ¿Por qué PROCESSES rechaza el cambio en memoria aunque v$parameter lo marque IMMEDIATE?
Porque PROCESSES dimensiona estructuras de la SGA que se reservan al arrancar, así que en la práctica es estático. En la evidencia, ALTER SYSTEM SET processes = 250 SCOPE = MEMORY falla con ORA-02095.
15. ¿Para qué sirve versionar el PFILE? Explica "configuration drift".
Sirve para generar una copia legible de la configuración, versionarla en git sirve para ver cuando y quien hizo los cambios.
Configuration drift es que la configuración real se va separando de la documentada porque se hacen cambios silenciosos sin llevar registro de ellos.
16. ¿Qué modelo de gestión de memoria usa tu instancia? Justifícalo con tres parámetros.
ASMM (Automatic Shared Memory Management):
memory_target = 0 y memory_size = 0 
sga_target = 1536M (con sga_max_size = 1536M)  Oracle reparte los 1536 MB entre buffer cache, shared pool, large pool y java pool.
pga_aggregate_target = 512M (límite duro pga_aggregate_limit = 2G)
17. Explica las cifras de tu experimento de caché: lecturas lógicas, físicas y tasa de acierto.
Con la caché fría hace 247 lecturas lógicas y 245 lecturas físicas teniendo una tasa de acierto de 1 – (245/247) = 0.8%
Con la caché caliente hace 247 lecturas lógicas y 0 físicas, teniendo una tasa de acierto de 1 – (0/247) = 100%
18. ¿Por qué no se suma el RSS de los procesos para saber la memoria de la instancia?
Porque cada proceso muestra entre 80 y 200 MB de RSS, pero casi todo es la SGA compartida, contada de nuevo en cada proceso. 
Sumar el RSS de más o menos 54 procesos daría más de 5 GB en un contenedor que usa unos 2 GB.
19. Relaciona el SPID de LGWR de v$process con el PID de /proc. ¿Por qué docker top muestra otro número?
El SPID de LGWR es el PID de dentro del contenedor, por ejemplo en el archivo 09-procesos-so.sh hace /proc dentro del contenedor y muestra el mismo número que el SPID de LGWR en v$process.
Docker top muestra el PID del anfitrión, son el mismo proceso visto desde dos espacios de nombres distintos.
20. ¿Qué hace PMON y qué hace SMON? Pon un ejemplo de cada uno.
PMON: Limpia los procesos de usuario caídos, deshace su transacción con el undo y libera sus bloqueos. Ejemplo: el portátil de un usuario se apaga en mitad de un UPDATE, PMON detecta el proceso servidor huérfano, hace rollback y libera los bloqueos de las filas.
SMON: Hace la recuperación de instancia al arrancar y limpia segmentos temporales. Ejemplo: tras un SHUTDOWN ABORT (sin checkpoint), en el siguiente arranque SMON aplica el redo necesario para dejar la base consistente.
21. ¿Por qué C##OPS_RO y no SYSTEM para observar? ¿Qué no puede hacer C##OPS_RO?
Por mínimo privilegio, esto significa que para mirar no hace falta poder modificar, y un error de consulta no puede romper nada.
C##OPS_RO no puede escribir ni modificar nada, cambiar parámetros o parar o arrancar la instancia.
22. ¿Qué dos vías de exposición de contraseñas corrige este laboratorio respecto al Lab 3?
Contraseñas literales en el repositorio: Quedaban para siempre en el historial de Git. Se corrige invalidándolas con V003 y las contraseñas nuevas viven en config/.env.
sys/<contraseña> en la línea de comandos: Visible con ps -ef, en el historial de la shell y en los eventos del demonio Docker. Se corrige con 08 v2, que usa / as sysdba y con ro.sh, que pasa la contraseña por la entrada estándar.

PREGUNTAS DE EXAMEN:
P1:
A, D. Tras SHUTDOWN IMMEDIATE hay checkpoint final: los archivos son consistentes, no necesitan redo y se abren directamente con STARTUP.

P2:
B. En Standard Edition no hay online move: se hace OFFLINE -> copia con el SO -> RENAME DATAFILE -> ONLINE

P3:
A, C. STARTUP_TIME es de la instancia y cambia en cada arranque, CREATED es de la base y no cambia al arrancar.

P4:
A, C. En NOMOUNT solo está la instancia y el SPFILE, se puede consultar v$parameter y recrear el control file con CREATE CONTROLFILE.

P5:
B. ALTER DATABASE ARCHIVELOG exige la base montada, no abierta: se leen los control files pero los datafiles están cerrados.

P6:
B. Con SPFILE, el SCOPE por defecto es BOTH: cambia en memoria y en el SPFILE.

P7:
C. PROCESSES es un parámetro de instancia, eso significa que no se puede cambiar desde una PDB y da error ORA-65040.

P8:
A, C. STARTUP PFILE='…' arranca con la copia buena y CREATE SPFILE FROM PFILE='…' repara el SPFILE

P9:
B. On MEMORY_TARGET = 0 y SGA_TARGET fijado, la SGA la gestiona ASMM, los parámetros fijados como DB_CACHE_SIZE actúan como mínimos, así que el buffer cache no bajará de 512 MB.

P10:
A, D. En servidor dedicado, la PGA contiene el área de ordenación (ORDER BY) y la memoria de sesión.

P11:
C. COMMIT espera a que LGWR escriba el redo en los redo logs online, DBWn escribe los bloques sucios después.

P12:
B, D. PMON y SMON son obligatorios en toda instancia.

