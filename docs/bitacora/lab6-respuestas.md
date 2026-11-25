# Lab 6 · Respuestas a las preguntas de comprobación

1. Mi alert log tenía 15 errores ORA- en 24 h, en 01-turno.script.log. Se debían a los simulacros de fallos del Lab 5 que provocaron errores reales a propósito. Ese número no es una alarma por sí solo porque sin un registro no significa nada, si por ejemplo otro día se triplica el número de errores entonces si sería una alarma.

2. La ventana de los miércoles empieza a las 22:00 y dura 4 horas, según 01-automatizacion.spool.log. Corren tres tareas automáticas (AutoTask): auto optimizer stats collection, auto space advisor y sql tuning advisor.

3. Tras `ALTER SYSTEM SET db_files = 250 SCOPE = SPFILE`, V$SPPARAMETER (el archivo) mostraba 250, ISSPECIFIED = TRUE y V$PARAMETER (la memoria en uso) seguía en 200. El cambio queda pendiente porque db_files es estático. Sin el RESET, en el siguiente reinicio la instancia habría arrancado con 250.

4. `db_files` no estaba fijado en el SPFILE, así que RESET elimina la línea y devuelve el parámetro a su valor por defecto (Su estado anterior). RESET no deshace sino que devuelve al valor por defecto. Con `processes` no habría servido porque sí estaba fijado en el SPFILE, y mi PFILE lo demuestra con la línea `*.processes=<tu valor>` (PDF: 200). Un RESET lo habría cambiado en el próximo arranque, y la vuelta atrás correcta es volver a poner el valor guardado.

5. C##OPS_RO obtuvo ORA-01109. La instancia decía "Database opened" porque eso se refiere al CDB raíz, mientras que FREEPDB1 quedó en MOUNTED tras DISCARD STATE, que borró el estado guardado.

6. Mi sesión de la aplicación tenía SID 21, SPID 2070 y evento PL/SQL lock timer, porque estaba en DBMS_SESSION.SLEEP. MODULE (matriculas), ACTION (cierre-periodo) y CLIENT_IDENTIFIER (ana.garcia@ucam) me dicen qué hace la sesión y para quién, mientras que USERNAME dice APP_ACADEMIA para todas las sesiones de la aplicación y no distingue nada.

7. Tras CANCEL SQL quedaba 1 transacción abierta: cae la llamada en curso (ORA-01013), pero no la transacción ni la sesión. Tras KILL SESSION había 0 sesiones vivas y la fila 101 quedó en ACTIVO (PDF), porque Oracle deshizo el UPDATE sin confirmar (rollback). Terminar una sesión nunca confirma su trabajo.

8. `common_user_prefix` vale vacío en mi imagen. En la imagen oficial es C##, y obliga a que los usuarios comunes empiecen así (por eso C##OPS_RO). Si está vacío, Oracle no exige ese prefijo en esta imagen.

9. Tabla de las tres miradas (04-tres-miradas.script.log):

| Vista | C##OPS_RO en raíz | C##OPS_RO en FREEPDB1 | APP_ACADEMIA |
| ALL_TABLES de ADMIN_ACADEMIA | 0| 0 | 1 |
| DBA_USERS | 37 | 47 | ORA-00942 |
| CDB_USERS | 47 | 47 | ORA-00942 |
| V$DATAFILE | 17 | 10 | ORA-00942 |

10. En 04-deltas.script.log salieron 5388 lecturas lógicas por recorrido y la carga costó 0,51 s de DB time. DB CPU 0.43 indica que la carga no esperó nada: todo fue CPU. Si DB time fuera mucho mayor, la diferencia serían esperas (E/S, bloqueos...).

11. Antes de la carga, TBS_ACADEMIA_HIST tenía asignado 23 MB, libre 7 MB y máximo 30 MB. Para alertar usaría el % sobre el máximo (DBA_TABLESPACE_USAGE_METRICS, 15,16 %), porque mide contra lo que el tablespace puede llegar a crecer. Asignado y libre no cuentan lo que aún puede crecer con AUTOEXTEND.

12. Insertó SYS, pero "pagó" CARGA_HIST, porque la cuota la paga el dueño del segmento: de ahí el ORA-01950 (sin cuota). El ORA-01536 (cuota de 2 MB excedida) no se resuelve ampliando el tablespace, porque tenía sitio de sobra (2,4 MB libres). Lo que faltaba era permiso, es decir, ampliar la cuota del dueño.

13. La carga estuvo suspendida desde las 19:46:07 hasta 19:46:22, un total de 15 s. El alert log dejó dos líneas: "statement in resumable session 'carga-historico' was suspended due to ORA-01536" y "was resumed". CDB_RESUMABLE mostró status SUSPENDED con el error ORA-01536.

14. Filas, bloques y cuota consumida: antes del DELETE 20000 filas, 2944 bloques, 23 MB, tras el DELETE 2000 filas, 2944 bloques, 23 MB y tras el SHRINK 2000 filas, 304 bloques, 2.4 MB. El DELETE no devolvió espacio porque los bloques quedan por debajo de la marca de agua alta medio vacíos, y un recorrido completo los sigue leyendo.

15. Mi perfil DEFAULT tenía FAILED_LOGIN_ATTEMPTS UNLIMITED, PASSWORD_LIFE_TIME UNLIMITED, PASSWORD_LOCK_TIME 1, PASSWORD_GRACE_TIME 7, INACTIVE_ACCOUNT_TIME 365, PASSWORD_REUSE_MAX/TIME PDF: UNLIMITED y PASSWORD_VERIFY_FUNCTION PDF: NULL. Dos límites de PRF_PERSONAS para una persona de secretaría: FAILED_LOGIN_ATTEMPTS 3 (una persona puede equivocarse, pero tres fallos seguidos cortan un intento de adivinar la contraseña) y PASSWORD_LIFE_TIME 90 (las contraseñas de personas deben rotar, mientras que una cuenta de aplicación no). También ORA12C_VERIFY_FUNCTION, que rechazó "corta" con ORA-28003.

16. Ana pudo leer ACA_MATRICULAS: 60 000 porque tiene ROL_SECRETARIA_ACADEMIA, que incluye ROL_LECTURA_ACADEMIA, y este tiene `SELECT ANY TABLE ON SCHEMA admin_academia`: lee todas las tablas del esquema, también las futuras. Al cambiar el nombre de un alumno obtuvo ORA-41900, porque solo tiene UPDATE sobre la columna ESTADO.

17. En 07-objetos.script.log: con la columna nueva (telefono) no se invalidó nada, porque Oracle registra dependencias de grano fino (por columna) y nadie la usaba. Al ampliar email_institucional se invalidó solo V_CONTACTO_LAB6 (la única que la usa). Al ampliar nombres se invalidaron V_ACTIVOS_LAB6 y, en cascada, F_TOTAL_ACTIVOS_LAB6, porque la función depende de la vista (DBA_DEPENDENCIES muestra la cadena).

18. Según V$SGA_TARGET_ADVICE, duplicar la SGA (factor 2, 3072 MB) deja el DB time estimado en factor 1, sin cambio, con 21386 lecturas físicas estimadas. No mejoraría, así que no compensa. En V$PGA_TARGET_ADVICE hay sobreasignaciones por debajo de 512 MB, que es el tamaño actual, con 384 MB ya hay 1.

19. La consulta de la aplicación necesitó 247 lecturas lógicas para devolver 1 fila. Lo dice la línea FETCH #138033542938200:c=2964,e=2507,p=0,cr=247,cu=0,mis=0,r=1,dep=0,og=1,plh=3163684005,tim=463885567 de la traza (cr = lecturas lógicas) y la columna `query` de la fila Fetch en tkprof.

20.
- **INC-601:** evidencia clave: sesión de ANA_GARCIA esperando enq: TX con bloqueador `<sid>` (sección 1 de 08-diagnostico). Intervención: `ALTER SYSTEM KILL SESSION '<sid>,<serial#>' IMMEDIATE;`. Validación: Ana guardó la ficha y el alumno 101 quedó ACTIVO.
- **INC-602:** evidencia clave: academia_app con `arrancado = NO` en la sección 6 (existe, pero el listener no lo anuncia). Intervención: `EXEC DBMS_SERVICE.START_SERVICE('academia_app');`. Validación: `arrancado = SI`, lsnrctl lo anuncia y app.sh conecta.
- **INC-603:** evidencia clave: APP_ACADEMIA en estado LOCKED (no LOCKED(TIMED)) con lock_date coincidente con el script de bajas de la sección 7. Intervención: `ALTER USER app_academia ACCOUNT UNLOCK;`. Validación: la sección 7 ya no la lista y app.sh entra sin ORA-28000.

PREGUNTAS DE EXAMEN
Pregunta 1, B, se puede encontrar en las partes B y F
Pregunta 2, C, se puede encontrar en la parte C
Pregunta 3, B, se puede encontrar en la parte C
Pregunta 4, A y C, se puede encontrar en la parte C
Pregunta 5, C, se puede encontrar en la parte C
Pregunta 6, B, se puede encontrar en la parte C
Pregunta 7, A, se puede encontrar en la parte D
Pregunta 8, B, se puede encontrar en la parte D
Pregunta 9, C, se puede encontrar en la parte D
Pregunta 10, C, se puede encontrar en la parte D
Pregunta 11, B, se puede encontrar en la parte E
Pregunta 12, A y C, se puede encontrar en la parte E
Pregunta 13, B, se puede encontrar en la parte F
Pregunta 14, A y C, se puede encontrar en la parte F
Pregunta 15, A y C, se puede encontrar en la parte F
Pregunta 16, B, se puede encontrar en la parte F
Pregunta 17, B, se puede encontrar en la parte G
Pregunta 18, B, se puede encontrar en la parte G
Pregunta 19, A y B, se puede encontrar en la parte H
Pregunta 20, B, se puede encontrar en la parte H
Pregunta 21, C, se puede encontrar en la parte H
Pregunta 22, C, se puede encontrar en la parte I
