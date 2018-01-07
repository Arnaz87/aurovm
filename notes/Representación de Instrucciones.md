# Representación de Instrucciones

*[2016-10-13 12:57]*

El método de llamar las funciones es con un objeto intermedio que sirve para pasar argumentos y devolver valores. La alternativa que usan prácticamente todos los demás proyectos como el mío es tener una instrucción con número variable de argumentos para llamar una función, pero el problema con esto es que no me gustan los argumentos variables, y es un poco menos conveniente chequear los tipos con este método.

Como quiero tener una máquina muy minimalista, tengo un conjunto de instrucciones extremadamente pequeño, las operaciones aritméticas y de ese tipo están implementadas como funciones, no como instrucciones.

- `cpy dest src`
- `get reg obj field`
- `set obj field reg`
- `new reg` (El constructor está implícito en el tipo del registro)
- `call reg` (Solo funciona con tipos función)
- `jmp addr`
- `if addr cond`
- `end`

Un bloque de código es simplemente una lista de estas instrucciones. Para representarlo en binario tengo dos alternativas. Una es que cada instrucción ocupe espacio para ella y para tres argumentos, y solo use los que necesite.

La otra es que las instrucciones sean de tamaño variable, que aprovecha mejor el espacio, pero es un poco menos conveniente de manejar. Basado en este método, se me ocurrió una ideota.

## Propuesta

*[2016-10-13 13:20]*

En vez de tratar a las funciones como objetos especiales, se pueden tratar como instrucciones. Esto soluciona los inconvenientes de usar un objeto intermedio, como la posibilidad de que el objeto salga del entorno de la función invocada y la que la invocó, o que no se sepa el orden de los argumentos ni cuáles son de entrada o de salida.

El problema es que, el diseño actual es bastante bueno en cuanto a simplicidad, y el cambio de este método posiblemente inspire muchos otros cambios, como la fragmentación del uso de structs como elemento básico, o posiblemente la inclusión del modelo de ejecución *SSA tipado*, cambios que en conjunto podrían hacer mucho más complejo el diseño de la máquina.

Todos estos son cambios muy atractivos que quiero hacer, pero tengo que evaluar bien si valen la pena y compararlo con el diseño actual. Tengo pensado hacer un fork para implementar estos cambios.

*Nota*: Con seguridad de tipos, me refiero a que para comprobarla, se hace un cálculo trivial con pocas variables, independientes de todo el contexto, Por ejemplo.

`cpy rega regb` es trivial de analizar porque solo hay que comprobar que el tipo de rega y regb son el mismo.

`set obj field reg` es un poco menos trivial porque hay que incluir el tipo de obj y sus campos, pero luego es trivial comparar reg con obj.field.

`pusharg rega, pusharg regb, call func` es mucho más complicado, porque hay que revisar todas las rutas que el programa puede tomar hasta llegar a call, y por cada ruta, revisar una por una que cada pusharg concuerde con el tipo del argumento cuya posición es la misma que la del pusharg relativa a call.


### Estilo Objeto

**Ventajas**

- El mecanismo de pasar argumentos y devolver valores es el mismo que el de modificar objetos
- Integra los conceptos de función y objeto, que simplifica el diseño
- Tiene seguridad de tipos incluida
- La máquina no tiene que preocuparse por mover los resultados al sitio

**Desventajas**

- El objeto de argumentos se puede escapar de las funciones principales
- Siempre debe haber un registro reservado para la función
- No se sabe como pasar los argumentos posicionalmente
- Toma muchas instrucciones

### Estilo Instrucción

**Ventajas**

- Se maneja como si fuera una instrucción adicional
- No hay que hacer un Struct separado para los argumentos
- Las funciones son separadas de los objetos, que es más intuitivo
- Requiere una sola instrucción

**Desventajas**

- Para una función importada, sin incluir al modulo externo, es dificil averiguar las propiedades de sus argumentos
- Es dificil indicar elegantemente cuántos argumentos debe consumir la función-instrucción
- Requiere que la máquina mantenga los registros para los resultados, cuyo tamaño además cambia con la función (aunque eso no afecta si se guardan en la función invocada en vez de la invocadora)

### Estilo Perfecto

- Es simple y/o conveniente en diseño
- Tiene seguridad de tipos incluida
- Requiere de pocas instrucciones
- Es fácil indicar las propiedades de los argumentos
- Es fácil averiguar la representación posicional
- Solo las dos funciones involucradas pueden acceder a los argumentos
- No requiere registros extras
- Crea pocos objetos intermedios
- En general, requiere el menor trabajo posible para la máquina

### Alternativas externas

#### x86
Usar un stack de argumentos externo a los registros. Typechecking muy complejo.

#### Java
Usar un stack en vez de registros, y pasar todos los últimos n valores.
No es posible en una arquitectura basada en registros.

#### Parrot
Usar funciones de primera clase con `invoke func`, pero antes usando la instrucción de tamaño variable `setargs arg1 arg2 ...` para guardarlos en espacio externo. Typecheck más fácil que x86, pero complejo porque las instrucciones pueden estar arbitrariamente separadas.

#### Lua, Dalvik
Pasar un grupo de registros, indicando en la instrucción el primer registro para pasar, y cuantos contar en adelante. Posible en una máquina de registros sin tipo, inconveniente en una tipada, y muy inflexible.

## Propuesta 2

*[2017-02-15 07:54]*

Solo existen structs, pero algunos structs tienen código asociado, esos son funciones cuyos registros son los campos del struct. Las propiedades de los parámetros se determinan con anotaciones. Las ventajas son la simplificación del diseño por combinar los conceptos de tipo y función, y comparado con el otro método propuesto, no hay instrucciones de tamaño variable ni tengo que tener acceso a la lista de funciones para saber el tamaño de la instrucción, lo cual es MUY conveniente. Las desventajas son que ahora el invocador tiene acceso a todos los registros de la función, el objeto de la función puede salir del scope del invocador, pero estas cosas se pueden restringir con anotaciones.

Es inválido acceder a un campo de un objeto función que no está marcado explícitamente como resultado, o establecer uno que no es parámetro. Es inválido mover una función entre scopes. Es inválido invocar una función sin haber establecido todos los parámetros.

Esto es muy parecido a mi primera idea, pero antes las funciones eran separadas de los objetos, como un objeto especial, y se usaba un objeto extra para los registros, en cambio en esta propuesta el objeto en sí es la función. Eso simplifica el diseño comparado con la anterior.

Una gran desventaja de esta idea es la cantidad de instrucciones y bytes que requiere invocar una función. Una suma simple, con la propuesta anterior es:
`add r a b` 8 bytes, más un poco más para indicar la cantidad de parámetros y resultados (o se deduce del contexto), en cambio con esta propuesta:
`set add a a; set add b b; call add; get r add r`, 24 bytes, mas el registro extra para almacenar el objeto función
