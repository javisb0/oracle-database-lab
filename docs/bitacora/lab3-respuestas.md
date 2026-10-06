1. ¿Qué diferencia hay entre una imagen y un contenedor? Usa como ejemplo lo que hiciste en los ejercicios G2 y G4.
Una imagen es una plantilla de solo lectura y un contenedor es una instancia creada en ejecución a partir de una imagen. En el ejercicio G2 creamos un contenedor con la imagen hello-world y en el G4 creamos un contenedor llamado prueba para ejecutar una terminal de sh.
2. En el Ejercicio G5 el archivo nota.txt desapareció y en el G6 no. Explica por qué.
En el G5 nota.txt se guardó en el contenedor y luego se eliminó el mismo, en el G6 se guardó en un volumen gestionado por el Docker, y a pesar de borrar el contenedor sigue ahí guardado.
3. ¿Qué diferencia hay entre docker ps y docker ps -a, y qué significa STATUS = Exited (0)?
Docker ps muestra todos los contenedores en ejecución y docker ps -a muestra todos. STATUS Exited (0) significa que el contenedor finalizó sin errores.
4. En -p 8181:8181, ¿qué número corresponde a tu equipo y cuál al contenedor? ¿Qué pasaría con -p 80:8080 en el ejercicio de nginx?
El primer número corresponde a tu equipo y el segundo al contenedor.  En el ejercicio de nginx si se pone de esa manera, como nginx escucha por defecto en el puerto 80, le estarías diciendo que tu puerto es el 80 y el suyo el 8080, entonces la página web no cargaría.
5. ¿Por qué un contenedor de Oracle se queda en marcha y el de hello-world termina solo?
Porque un contenedor vive mientras viva su proceso principal, el proceso principal de hello-world es imprimir por pantalla, una vez haga eso finaliza el proceso y a su vez el contenedor.
6. ¿Qué es el digest de una imagen y por qué lo registramos si ya sabemos que usamos :latest?
Es una huella criptográfica única de la imagen, se registra porque el latest va cambiando, entonces el digest permite saber la versión de la imagen que se descargó e instalo.
7. ¿Qué comando borraría realmente los datos de Oracle? ¿Por qué docker rm oralab-26ai no lo hace?
docker volume rm oralab-26ai-data, porque docker rm oralab-26ai borra el contenedor pero no el volumen de datos gestionado fuera de él.
8. ¿Por qué este laboratorio se hace dentro del repositorio oracle-database-lab, con Issue, branch y Pull Request, en vez de en una carpeta aparte?
Porque así dejas evidencia de lo que has hecho para los revisores, si se trabajara en una carpeta aparte, se perdería la trazabilidad, el historial y la protección de la rama main configurada en repositorios de trabajo profesional.
9. ¿Qué diferencia hay entre source 00-config.sh y bash 00-config.sh? ¿Por qué usamos source?
Con bash se pierden las variables exportadas, con source no pasa esto, como 00-config.sh define variables de entorno entonces necesitamos que estas variables se guarden, por eso se usa source.
10. Explica cada parte del nombre 20260915T091230Z_02-docker.script.log.
20260915T091230Z es la fecha y hora universal (2026-09-15, 09:12:30, Z significa tiempo universal coordinado). 02 es el número del paso, Docker indica una descripción y script.log indica que es un log de lo que ha salido de la terminal al hacer un script.
11. ¿Para qué sirve .gitattributes y qué error evita?
Declara de forma explícita las reglas de normalización de finales de línea independientemente del sistema operativo, evita los fallos generados al editar archivos en Windows, que usa \r\n, mientras que Linux pide \n.
12. ¿Por qué en este Pull Request elegimos Create a merge commit en lugar de Squash and merge?
Porque merge commit conserva todo el historial completo de commits para seguir el flujo de trabajo y del desarrollo del proyecto que es justo lo que queremos.
13. Describe las cuatro capas de la estrategia de contraseñas (Parte D) y qué pasaría si te saltas la primera.
Capa 1: Indicar que git debe ignorar config/.env con .gitignore, capa 2: crear una plantilla sin las credenciales reales para copiarla, capa 3: crear el archivo local real config/.env con las contraseñas reales, capa 4: cargar las contraseñas en memoria con variables de entorno (source config/.env) para no escribirlas en texto plano en los comandos.
Si te saltas la primera será detectado por git y subido al repositorio, lo que provocará que tus contraseñas queden expuestas.
14. ¿Por qué no escribimos la contraseña directamente en el comando docker run, aunque el script no se suba a Git?
Porque todos los comandos ingresados en la terminal quedan guardados en un historial, esto significa que si escribes la contraseña todos con acceso a la maquina podrán consultarla.
15. Si descubres tu contraseña en un commit ya publicado, ¿basta con borrarla en un commit nuevo? ¿Qué debes hacer?
No basta, debes cambiar la contraseña y purgar el historial de git para eliminar el rastro del dato expuesto.
16. ¿Por qué no usamos SPOOL ni @archivo.sql con sqlplus dentro del contenedor, y qué hicimos en su lugar?
Sqlplus dentro del contenedor no tiene acceso directo al sistema de archivos local de tu máquina de trabajo para crear o leer directamente archivos locales de forma limpia. En su lugar ejecutamos los comandos o scripts pasando la entrada o redireccionando desde el anfitrión usando docker exec o herramientas externas que llevan las salidas de los comandos hacia los logs.
17. ¿Qué hace WHENEVER SQLERROR EXIT SQL.SQLCODE al inicio de V000 y V001, y qué pasaría sin esa línea?
Hace que ante cualquier error interrumpa el script y devuelva el código.
Sin esa línea se seguirá ejecutando el script aunque haya un fallo al inicio lo que podría ocasionar un fallo en cascada.
18. ¿Qué es una migración y por qué V000 y V001 no se deben editar una vez aplicadas?
Es un script de base de datos que aplica un cambio de estructura, esquemas o datos de manera controlada. Porque representan una versión que ya fue ejecutada previamente, por lo tanto, editarla podría llevar a que las auditorias precisas sean imposibles.
19. ¿Por qué en SQL Developer se usa el servicio FREEPDB1 y no FREE ni un SID?
Porque FREE es el contenedor raíz reservado para la administración global de la instancia, FREEPDB1 es la base de datos destinada específicamente a los objetos, tablas y esquemas de las aplicaciones de negocio.
20. ¿Qué aporta SQLcl frente a SQL*Plus, y por qué un DBA debe dominar ambas?
SQLcl es una interfaz de línea de comandos moderna basada en Java que aporta autocompletado con Tab, resaltado de sintaxis, formateo avanzado de salidas en JSON/CSV/HTML. Un administrador de base de datos debe dominar SQLplus porque es el estándar y es el cliente universal en cualquier instalación de servidor Oracle y también debe dominar SQLcl porque permite una productividad superior.
21. ¿Por qué el curso pasa de Git Bash a Ubuntu en WSL 2? Da al menos dos problemas concretos de Git Bash que desaparecen en Ubuntu.
El curso pasa de Git Bash a Ubuntu en WSL 2 porque Git Bash es únicamente un emulador limitado de la terminal Bash sobre Windows, mientras que WSL 2 ejecuta un kernel de Linux real sobre una máquina virtual ligera. 
22. ¿Por qué clonamos el repositorio en ~/oracle-database-lab y no trabajamos sobre la carpeta de Windows(/mnt/c/...)? ¿Y por qué recomendamos bash frente a zsh para los scripts del curso?
Acceder a la carpeta de Windows desde WSL 2 requiere pasar por una capa de traducción entre el sistema de archivos de Windows y el de Linux, haciendo que la velocidad de lectura y escritura en Git, Docker y operaciones de bases de datos sea menor.
Porque bash es el estándar en la mayoría de sistemas Linux, y además puedes ahorrarte errores involuntarios del intérprete de zsh utilizando bash.

