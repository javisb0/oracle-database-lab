## INC-601 · Pantalla de secretaría colgada por un bloqueo de fila
- Detección: 15:33 UTC · Ana García (secretaría) avisó por ticket: al guardar la ficha del alumno 101 la pantalla se quedaba colgada.
- Impacto: secretaría no pudo guardar la ficha del alumno 101 durante <minutos>. Reiniciar su ordenador dos veces no sirvió porque el problema no estaba en su equipo.
- Diagnóstico: en 08-diagnostico.sql, sección 1, la sesión de ANA_GARCIA (sid <sid>) esperaba el evento `enq: TX - row lock contention` con `bloqueador = <sid_bloqueador>`. La sección 2 mostró la fila bloqueada (tabla <tabla>, fila <fila>), y la sección 3 mostró que el bloqueador tenía el TX (lmode 6, block 1) y Ana lo pedía (request 6). La sección 4 indicó que el bloqueador (módulo <módulo>) tenía una transacción abierta con used_urec = <n>, es decir, poco trabajo que deshacer.
- Causa raíz: una sesión de la aplicación (APP_ACADEMIA) modificó la fila del alumno 101 y dejó la transacción abierta sin COMMIT ni ROLLBACK. No se trata de un fallo de la base de datos, sino de una sesión que esperaba a otra, y nada limitaba cuánto tiempo podía estar abierta una transacción inactiva.
- Intervención: una sola sentencia como SYSDBA en FREEPDB1, `ALTER SYSTEM KILL SESSION '<sid>,<serial#>' IMMEDIATE;`. Es la mínima porque afecta solo a la sesión bloqueadora, no a la instancia ni a las demás sesiones.
- Validación: por el camino del consumidor, la sesión de Ana guardó la ficha y el alumno 101 quedó ACTIVO. Después volví a ejecutar 08-diagnostico.sql y las secciones 1 y 3 ya no mostraban esperas ni bloqueos.
- Acción preventiva: (1) alerta cuando una sesión espere `enq: TX` más de <N> segundos, usando V$SESSION o ASH; (2) revisar con el equipo de aplicación que cada operación cierre su transacción (COMMIT/ROLLBACK en bloque `finally`); (3) valorar un límite de inactividad (`IDLE_TIME`) en el perfil de la cuenta de aplicación.

## INC-602 · La aplicación no conecta: ORA-12514
- Detección: 15:33 UTC · el equipo de matrículas avisó por ticket de que ninguna instancia de la aplicación conectaba y preguntó si la base estaba caída.
- Impacto: aplicación de matrículas completamente inaccesible durante <minutos>. Prioridad crítica.
- Diagnóstico: la base no estaba caída, porque la lista de turno la mostraba abierta y ORA-12514 lo devuelve el listener, no la base. En 08-diagnostico.sql, sección 6, el servicio `academia_app` aparecía con `arrancado = NO`, es decir, existía en CDB_SERVICES pero no en V$ACTIVE_SERVICES. `lsnrctl status` tampoco lo anunciaba.
- Causa raíz: el servicio `academia_app` existía pero estaba parado, y el listener no puede enrutar a un servicio que no se anuncia. No había ningún mecanismo que garantizara que el servicio arrancara solo tras un reinicio o una parada.
- Intervención: una sola sentencia como SYSDBA, conectado a FREEPDB1, `EXEC DBMS_SERVICE.START_SERVICE('academia_app');`. Es la mínima porque no reinicia ni la instancia ni la PDB ni el listener, y solo arranca el servicio que faltaba.
- Validación: la sección 6 mostró `arrancado = SI`, `lsnrctl status` volvió a anunciar el servicio y `app.sh` conectó por el servicio.
- Acción preventiva: (1) guardar el estado de la PDB con `ALTER PLUGGABLE DATABASE FREEPDB1 SAVE STATE;` (Parte C) y asegurar el arranque automático del servicio tras un reinicio (por ejemplo, con un trigger AFTER STARTUP); (2) añadir a la validación de arranque la comprobación de que los servicios existentes están activos; (3) alerta de monitorización sobre `arrancado = NO`.

## INC-603 · La aplicación no entra: ORA-28000
- Detección: 15:33 UTC · el equipo de matrículas avisó por ticket de que, tras el despliegue de las 21:00, la aplicación no entraba con ORA-28000 sin haber cambiado la contraseña. El turno de tarde anotó que se había ejecutado el script trimestral de bajas.
- Impacto: aplicación de matrículas sin acceso a la base durante <minutos>.
- Diagnóstico: en 08-diagnostico.sql, sección 7, la cuenta APP_ACADEMIA figuraba con `account_status = LOCKED` (no `LOCKED(TIMED)`) y `lock_date = <fecha y hora>`, coincidente con la ejecución del script de bajas. El perfil <perfil> tiene `FAILED_LOGIN_ATTEMPTS = <valor>`, pero el estado `LOCKED` sin `(TIMED)` indica un bloqueo manual o por script, no por intentos fallidos.
- Causa raíz: el script trimestral de bajas bloquea cuentas sin distinguir entre cuentas de personas y cuentas de aplicación, y alcanzó a APP_ACADEMIA. Que la cuenta estuviera bloqueada es el efecto, no la causa.
- Intervención: una sola sentencia como SYSDBA en FREEPDB1, `ALTER USER app_academia ACCOUNT UNLOCK;`. Es la mínima porque no cambia la contraseña ni el perfil ni los privilegios, y solo revierte el bloqueo.
- Validación: la sección 7 ya no listaba la cuenta, `app.sh` entró sin ORA-28000 y la aplicación recuperó el acceso.
- Acción preventiva: (1) modificar el script de bajas para que excluya las cuentas de aplicación (por perfil, rol o convención de nombres) y que acepte solo una lista explícita de cuentas nominales; (2) añadir un modo de simulación que liste las cuentas afectadas antes de bloquear; (3) alerta cuando una cuenta de aplicación pase a un estado distinto de OPEN.
