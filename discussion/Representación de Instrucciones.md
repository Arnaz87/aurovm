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
