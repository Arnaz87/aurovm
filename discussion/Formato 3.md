# Formato 3

Hay tres espacios básicos en un módulo: tipos, rutinas y valores, y dos espacios auxiliares: módulos y métodos.

Cada espacio tiene varias entradas, y cada entrada puede ser de un tipo de entrada, con cada espacio con sus propios tipos de entradas. Hay dos posibles maneras de codificar los tipos de las entradas:

Una sección diferente para cada tipo. Con este método todas las entradas del mismo tipo se agrupan y se pone al principio del grupo el número de entradas que contiene.

- Es fácil implementar el parser por secciones, cada una especializándose en el formato que usa el tipo específico.
- Es más amigable para comprimir, ya que la información en las secciones es similar
- Al añadir tipos nuevos y aún no hay soporte de ese tipo, es fácil simplemente leer el número de entradas y si hay más de cero abortar, aunque es igual de fácil leer un índice y si no está soportado abortar.
- Consume menos espacio, aunque sin mediciones este argumento nunca es sólido.
- No es claro en qué orden deberían estar los tipos, aunque tampoco es claro qué índice debería ser asignado a cada tipo con el otro método.

Preceder cada entrada con un índice del tipo.

- Si no se cambian los indices ya asignados, agregar nuevos tiposde entrada es compatible hacia atrás.
- Un buen compilaldor puede ordenar las entradas para que las más usadas tengan índices más pequeños.
- No es claro qué índice debería tener cada tipo, la decisión sería medio arbitraria.
- Ocupa más espacio, aunque faltan mediciones que soporten este argumento.

Por ahora me decido a usar prefijos de tipo.

Los prototipos no tienen que estar en una sección separada de las rutinas, cada rutina podría describir su propio prototipo, pero no sé cómo resolver lo de los métodos, ya que su prototipo es especial por tener argumentos genéricos.

Una posible solución a ese problema es que todas las rutinas tengan parámetros genéricos, y cualquier rutina puede ser una implementación de cualquier otra rutina.

Lo que sí es problemático con las rutinas es que no se puede definir el cuerpo de una hasta saber todos los prototipos del módulo, por lo que no se puede tener ambos el cuerpo de una rutina y el prototipo en la misma sección, deben estar en secciones separadas para que cuando se llegue a los cuerpos ya se hayan leído todos los prototipos, por lo tanto si se combinan los prototipos y las definiciones de las rutinas como se sugiere arriba, hay que separar el cuerpo de las rutinas a una sección diferente.

# Imports

    <name: string>
    <param_count: int>
    <param: val_index>[param_count]

# Types
    
## Import
    
    kind: 2
    <module: import_index>
    <name: string>

## Use

    kind: 3
    <const: const_index>

## Internal

    kind: 1
    <name: string>
    <field_count: int>
    <field: type_index>[field_count]

# Prototypes

    <in_count: int>
    <int_type: index>[in_count]
    <out_count: int>
    <out_type: index>[out_count]

# Methods

    ; Si el módulo es null, no es externo sino interno
    <module: import_index>
    <name: string>

    ; Los métodos tienen su propia lista, pero también se agregan al final
    ; de la lista derutinas al final de la lista, con cada genérico como
    ; una entrada de tipo Any
    <generic_count: int>
    <in_count: int>
    <int_type: index>[in_count]
    <out_count: int>
    <out_type: index>[out_count]

# Rutines

    <kind: int>
    <in_count: int>
    <int_type: index>[in_count]
    <out_count: int>
    <out_type: index>[out_count]
    <data: ...>

## Import

    kind: 2
    <module: import_index>
    <name: string>

## Use

    kind: 3
    <const: const_index>

## Internal
    
    kind: 1
    ; Si method no es cero, indica que esta rutina es una implementación de
    ; un método. El método es un índice en la tabla de métodos, no de rutinas.
    <name: string>
    <method: method_index>
    <reg_count: int>
    <reg: type_index>[reg_count]
    <inst_count: int>
    <inst: ...>[inst_count]

# Constants

## Binary

    kind: 1
    <type: type_index>
    <size: int>
    <data: byte>[size]

## Array

    kind: 2
    <type: type_index>
    <size: int>
    <values: const_index>[size]

## Type
    
    kind: 3
    <type: type_index>

## Rutine

    kind: 4
    <rutine: rutine_index>

## Call

    ; Se agregan tantos valores a la lista como resultados tenga la función
    ; rutine es índice-16, porque los primeros 16 números indican otros tipos
    ; de constantes
    <rutine: rut_index>
    <ins: const_index>[rutines[rut_index].in_count]

# Tipos Básicos

None, Unit, Any, Bool, Binary, Array, Type, Rutine

Sinónimos de tipo: tipo, clase, especie, modelo, patrón, figura, género, modo.
En inglés se usan type, class, kind.
