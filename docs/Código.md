# Código

El código es una secuencia de instrucciones, que son las funciones definidas en el módulo, excepto por las primeras que son especiales. Cada instrucción ocupa un byte y está seguida por registros en donde guardar el resultado y registros de donde sacar los parámetros (primero los resultados y luego los parámetros), el número de parámetros y resultados depende de la instrucción.

Las instrucciones especiales son:

- **cpy** {r, a}: Copia el contenido del registro en *a* al registro en *r*.
- **cns** {r, c}: Copia el contenido de la constante en *c* al registro en *r*.
- **get** {r, a f}: Copia el contenido del campo *f* del registro en *a* al registro en *r*.
- **set** {a, f b}: Copia el contenido del registro en *b* al campo *f* del registro en *a*.
- **lbl** {l}: Marca esta instrucción con el nombre *l* para que otras instrucciones puedan saltar a esta en otro punto del código.
- **jmp** {l}: Salta a la instrucción con el nombre *l*.
- **jif** {l, a}: Salta a la instrucción con el nombre *l* sólo si el contenido del registro en *a* es vedadero.
- **end**: Termina la ejecución de la función.

(No hay razón por la que los nombres de las instrucciones tengan que ser de 3 letras, pero me gusta así, así que lo hice así a propósito)

Los registros están en la definición de la función en el módulo, es una lista de valores, cada uno con un tipo específico, y en el código se indican con el índice base 1
