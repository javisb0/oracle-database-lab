PREGUNTAS DE COMPROBACIÓN
P1: La diferencia demuestra que el laboratorio ha evolucionado y que la copia lab4-final incorpora cambios y mejoras respecto a lab3-final. Hay que indicar los valores concretos del paso 6 de ambas copias.

P2: 

P3: Porque la primera ejecución incluye el coste del análisis y la preparación de la sentencia. La segunda se ejecuta en caliente y permite medir mejor su rendimiento.

P4: Altura: 3, hojas: 2216, factor de ramificación real: 2216 (Bloques de hojas) / 6 (Bloques de rama) = 369. La altura con mil millones sería 4, en el nivel 1 almacenas los 2216000 bloques hoja (1000000000/451.26), en el nivel 2 necesitas 2216000/369 = 6000 bloques de rama, nivel 3 6000/369 = 17 bloques de rama, y en el nivel 4 tenemos el bloque raíz.

P5: El ROWID identifica el objeto mediante el bloque y la posición de la fila dentro del bloque. No aparece el número de archivo porque el volcado muestra la información del ROWID en el formato utilizado por Oracle para localizar la fila.

P6: 

P7: IX_PED_FECHA tiene un clustering factor bajo porque las filas suelen estar agrupadas físicamente por fecha. IX_PED_CLIENTE tiene uno cercano al número de filas porque están dispersas. Un REBUILD no soluciona el problema, ya que no reorganiza físicamente la tabla.

P8: 

P9: Porque Gonz% permite utilizar el índice al no comenzar el patrón con %, pero puede devolver tantas filas que el acceso posterior a la tabla genere más lecturas que un recorrido completo.

P10: Rechazados: IX_CLI_PAIS_CIUDAD, PK_CLIENTE, UX_CLI_DNI, UX_CLI_EMAIL, IX_PED_CLI_FEC_CUB, IX_PED_CP, IX_PED_FECHA, IX_PED_PENDIENTES, PK_PEDIDO

P11: En una división 50/50, el bloque se divide aproximadamente por la mitad; en una 90/10, la división es muy desigual; y en el patrón cola, las eliminaciones dejan hojas vacías o poco ocupadas en una zona del índice.

P12: Elegiría COALESCE, porque permite combinar hojas parcialmente vacías y recuperar espacio sin necesitar una reconstrucción completa del índice.
8.1.4. SCN, control files, redo y FRA (I a L)
P13: Oracle compara los SCN de los encabezados de los datafiles con la información de checkpoint almacenada en el control file para determinar si necesita recuperación.

P14: La multiplexación en el mismo volumen protege frente al fallo o corrupción de un control file, pero no frente a la pérdida del volumen completo. En producción se guardarían copias en discos o ubicaciones físicas diferentes.

P15: CURRENT es el grupo de redo que Oracle está utilizando; ACTIVE contiene información necesaria para la recuperación de la instancia; e INACTIVE ya no es necesario para esa recuperación. Oracle rechaza los borrados cuando afectan a grupos necesarios o dejan un número insuficiente de grupos.

P16: La FRA alcanza un nivel elevado de ocupación y Oracle avisa mediante ORA-19815. Si sigue llenándose, no puede archivar los redo logs. Finalmente, se bloquea el cambio de grupo y aparecen esperas como log file switch (archiving needed), impidiendo aceptar nuevos cambios.

P17: Los lectores utilizan UNDO para consultar una versión anterior y consistente de los datos mientras otra sesión realiza modificaciones. Así, las lecturas no necesitan bloquear a los escritores.

P18: Un DELETE genera más UNDO porque debe guardar información para poder recuperar las filas eliminadas. El ROLLBACK también genera REDO porque modifica bloques de UNDO y esos cambios deben poder recuperarse.

P19: Justo después del COMMIT, la durabilidad está garantizada por el REDO escrito en los online redo logs mediante LGWR. Después del checkpoint, los cambios también se han escrito en los datafiles mediante DBWn.

P20: En el roll forward, Oracle aplica REDO para recuperar los cambios confirmados. En el roll back, deshace las transacciones que no llegaron a confirmarse, como muestra la recuperación de las filas 102 y 103.

P21: En el simulacro C se restaura la base completa desde una copia en frío, por lo que el RTO es mayor y el RPO depende del tiempo transcurrido desde esa copia. En el simulacro D se recupera el datafile afectado mediante RMAN y ARCHIVELOG, con un RTO menor y un RPO de 0.

P22: (No me salen los errores debido a que mi Docker esta unhealthy todo el rato, te he mandado un correo para solucionarlo)

SIMULACRO DE EXAMEN
S1: B, El clustering factor indica lo ordenadas que están las filas de la tabla respecto al índice.

S2: A, C, Las funciones sobre columnas pueden impedir el uso de un índice normal; un índice funcional puede solucionarlo.

S3: B, Las conversiones implícitas pueden impedir el uso eficiente de un índice.

S4: B, Los índices bitmap son adecuados para columnas con baja cardinalidad.

S5: B, El Index Skip Scan permite utilizar un índice aunque no se filtre por su primera columna.

S6: B, Los índices invisibles permiten probar su efecto sin eliminarlos ni utilizarlos normalmente.

S7: A, C, Permiten reducir el espacio ocupado por los índices sin recurrir a una reconstrucción convencional.

S8: B, Los índices Reverse Key ayudan a distribuir las inserciones y reducir la contención en bloques.

S9: C, Los índices mejoran las consultas, pero aumentan el coste de las operaciones de escritura.

S10: B, Los índices B-tree utilizan una estructura equilibrada para localizar rápidamente los registros.

S11: A, C, Las tablas organizadas por índice almacenan los datos siguiendo la estructura del índice.

S12: B, El SCN identifica el punto de consistencia de la base de datos.

S13: C, El proceso CKPT actualiza la información de los checkpoints.

S14: B, E, En estado NOMOUNT se pueden consultar vistas de instancia y parámetros, pero no información que requiere montar o abrir la base de datos.

S15: B, ARCHIVELOG permite conservar copias de los redo logs para recuperar la base de datos.

S16: B, Se puede limpiar un grupo de redo log inactivo y archivado mediante CLEAR LOGFILE.

S17: A, C, UNDO permite mantener lecturas consistentes y recuperar versiones anteriores de los datos.

S18: B, Las operaciones sobre UNDO también generan información REDO.

S19: A, COMMIT garantiza que los cambios queden registrados en los online redo logs.

S20: A, FAST_START_MTTR_TARGET ayuda a reducir el tiempo de recuperación de una instancia.

S21: B, Una FRA llena puede impedir el archivado y provocar esperas por el cambio de redo log.

S22: B, Un datafile de una tablespace de aplicación puede ponerse OFFLINE para mantener el resto de la base de datos disponible.

S23: B, Si se pierde un datafile de SYSTEM, hay que restaurarlo y recuperarlo con la base de datos en MOUNT.

S24: B, En NOARCHIVELOG se necesita una copia en frío y se pueden perder los cambios posteriores a esa copia.

S25: B, D, Aumentar el espacio o la retención de UNDO ayuda a evitar errores ORA-01555.

S26: A, V$RECOVERY_AREA_USAGE permite consultar el uso de la Fast Recovery Area.
