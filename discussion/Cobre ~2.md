# Cobre ~2

*[2017-07-08]*

Propuestas para un rediseño de Cobre

# Constantes

Ahora todo es un valor, lo que quiere decir que un módulo ya no tiene espacios diferentes para tipos, rutinas y valores (no sé si incluir los módulos también), por lo que todo podría usarse como valor y todos los valores podrían usarse como tipos o rutinas. ~1 ya puede hacerlo, pero este método lo hace mucho más evidente, simplifica el formato binario y hace más fácil generar un módulo binario porque no hay que estar pendiente de hacer las conversiones, aunque esto pasa a ser trabajo de las implementaciones.

# Prototipos de rutinas

Hay una tabla para las rutinas, sus entradas tienen el índice de la constante de la rutina y el prototipo, el cuál a su vez usa como tipos indices a las constantes de los tipos.

# Cuerpo de las rutinas

Una tabla con el cuerpo de las rutinas, las constantes que crean rutinas tienen el índice de una entrada de esta tabla.

# Instrucciones

En ~1 la lista de registros es muy grande por todos los registros temporales, si uso SSA todos los registros intermedios serían implícitos. 

Una implementación que se me ocurre para implementar SSA es que está dividido en Nodos (lo que en ~1 son los labels), y cada nodo lista los nodos anteriores (nodos que pueden saltar a este nodo) y el nodo dominante más cercano. Al haber un salto, los registros de los nodos no dominantes se eliminan, pero el del nodo dominante permanece, y las funciones phi sirven para evitar que valores de nodos no dominantes se eliminen. Debe haber un nodo de entrada que no pueda ser objetivo de ningún salto, así no hay ciclos de nodos dominantes porque una de las entradas a un ciclo siempre va a ser desde el nodo de entrada y la otra desde el nodo que salta hacia atrás.

El problema con este método es que los registros temporales de los nodos dominantes van a seguir siendo guardados, a pesar de que no se van a usar en otros nodos más adelante. Esto se resuelve haciendo un análisis y comprimiendo los registros de los nodos al salir, dejando solo los que podrían usarse en otros nodos.

Otro método que se me ocurre es permitir una instrucción para asignar registros que ya se asignaron. Esto ya no es SSA, pero ahorra el espacio de las instrucciones phi y de la declaración de nodos predecesores, el problema es que analizar el código buscando los registros que prevalecen no es trivial y ahora es obligatorio, porque crear un registro por cada instrucción no es factible.

Otra opción es declarar una tabla de variables y organizar el código por nodos, parecido al primer método, un registro indicaría un índice a una variable si es inferior al tamaño de la tabla de variables o un temporal si es mayor. Esto prácticamente es una máquina de pila.

Parece que SSA produce los binarios más grandes, porque por ejemplo en un bucle, al principio del bucle debe declararse otra vez todas las variables que se usen en el bloque (aunque en cantidad de información, es lo mismo que asignar variables, porque cada bloque debe generar una instrucción por cada asignación, pero es más complicado)

### Pensando un poco sobre las instrucciones

*[2017-07-10]*

Hay que recordar el objetivo de este formato, no es una representación intermedia para compiladores, ni un bytecode para intérpretes, lo más importante es que sea muy simple, de alto nivel, que se entromezca lo menos posible en la semántica de un lenguaje y que sea fácil de analizar, y en menor medida que sea fácil de generar. Por lo tanto, el caso ideal es que a medida que se lea, se pueda recopilar suficiente información para que la implementación genere lo que sea que use internamente, sin necesidad de ocupar mucha memoria en el proceso, y que el producto sea código eficiente.

En base a esta esto, creo que lo mejor es un formato que indique las variables al principio y que acepte temporales, pero que de algún modo sepa cuánto van a durar para no malgastar memoria en valores que no se usarán.

Casi todas las opciones que di arriba fallan porque requieren un análisis para saber cuáles temporales hay que mantener. Entonces tengo dos opciones: eliminar el análisis poniendo esa información en la representación, o aprovechar el análisis al máximo y en cambio hacer el formato compacto.

Una propuesta que es parte de la segunda segunda opción es tener SSA y locales al mismo tiempo. A diferencia del otro SSA los bloques no tienen una lista de bloques anteriores. Las funciones phi solo incluyen los valores que van a usar, así el algoritmo para leer el código va así:

1. Cada vez que se entre a un bloque
  - Guardar en una variable el bloque actual
  - Resetear el contador de instrucciones
2. Cada vez que se lea una instrucción, incrementar el contador de instrucciones
3. Cada vez que se cree un valor
  1. Asociarle el bloque en el que se creó
  2. Asociarle el índice de la instrucción actual
  3. Crear una lista vacía de bloques en los que se ha usado el valor
  4. Crear una variable con el número de instrucciones en el que este valor permanece vivo
4. Cada vez que se use un valor
  1. Si está en el bloque actual, cambiarle la variable de vida, se hace restandole el índice de instrucción actual el del valor.
  2. Si está en otro bloque, agregar el bloque actual a la lista de bloques que usan ese valor.
  3. Si está en el bloque actual pero se generó en una instrucción de más adelante, significa que el bloque actual se ejecuta varias veces, y se considera como otro bloque.
5. Cada vez que se lea un salto

# Prototipo

*[2017-07-20 12:17]*

__Magic Number__: "Cobre ~2\0"

## Modules

~~~
<module_count: varint>
{
  <module_name: string>
  <param_count: string>
  <param: item_index>[param_count]
}[module_count]
~~~

## Functions

~~~
<prototype_count: varint>
{
  <item: item_index> # Item defining the function
  <in_count: varint>
  <in_type: item_index>[in_count]
  <out_count: varint>
  <out_type: item_index>[out_count]
}[prototype_count]
~~~

## Items

~~~
<param_count: varint>
<param_type: item_index>[param_count]

<item_count: varint>
{
  <type: varint>
  <data: ...>
}[item_count]
~~~

### Import

~~~
type: 1
<module: module_index>
<item_name: string>
~~~

### Struct Def

~~~
type: 2
<field_count: varint>
<field_type: item_index>[field_count]
~~~

### Rutine Def

~~~
type: 3
<code: code_index>
~~~

### Binary

~~~
type: 4
<size: varint>
<data: byte>[size]
~~~

### Array

~~~
type: 5
<size: varint>
<item: item_index>[size]
~~~

### Call

Any type above 15. The index of the rutine is the type minus sixteen. It defines as many items as outputs has the rutine, and the parameters are the inputs of the rutine.

~~~
type > 15
<params: item_index>[ rutines[type-16].in_count ]
~~~

## Code

~~~
<in_count: varint>
<out_count: varint>
<length: varint>
{
  <type: varint>
  <data: ...>[if type<16]
  <arg: reg_index>[ rutines[type-16].in_count if type>15 ]
}[length]

type[0]: nul {}
type[1]: ret { src_reg[out_count] }
type[2]: cpy {dst_reg src_reg}
type[3]: jmp {dst_inst}
type[4]: jif {dst_inst cond_reg}
type[5]: nif {dst_inst cond_reg}
~~~
