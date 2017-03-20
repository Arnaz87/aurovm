# Formato 3

Hay tres espacios básicos en un módulo: tipos, rutinas y valores, y dos espacios auxiliares: módulos y métodos.

Cada espacio tiene varias entradas, y cada entrada puede ser de un tipo de entrada, con cada espacio con sus propios tipos de entradas. Hay dos posibles maneras de codificar los tipos de las entradas:

Una sección diferente para cada tipo. Con este método todas las entradas del mismo tipo se agrupan y se pone al principio del grupo el número de entradas que contiene.

- Es fácil implementar el parser por secciones, cada una especializándose en el formato que usa el tipo específico.
- Al añadir tipos nuevos y aún no hay soporte de ese tipo, es fácil simplemente leer el número de entradas y si hay más de cero abortar, aunque es igual de fácil leer un índice y si no está soportado abortar.
- Consume menos espacio, aunque sin mediciones los argumentos de este tipo no son sólidos.
- No es claro en qué orden deberían estar los tipos, aunque tampoco es claro qué índice debería ser asignado a cada tipo con el otro método.

Preceder cada entrada con un índice del tipo.

- Si no se cambian los indices ya asignados, agregar nuevos tipos es compatible hacia atrás.
- Un buen compilaldor puede ordenar las entradas para que las más usadas tengan índices más pequeños.
- No es claro qué índice debería tener cada tipo, la decisión sería medio arbitraria.
- Ocupa más espacio, aunque faltan mediciones que soporten este argumento.

Dados los argumentos de arriba, parece que la mejor opción es usar prefijos de tipo, a diferencia de secciones de tipo.

# Imports

    <name: string>
    <param_count: int>
    <param: val_index>[param_count]

# Types
    
## Import
    
    <module: import_index>
    <name: string>

## Use

    <const: const_index>

## Internal
    
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

## Import

    <module: import_index>
    <name: string>

## Use

    <const: const_index>

## Internal
    
    ; Si method no es cero, indica que esta rutina es una implementación de
    ; un método. El método es un índice en la tabla de métodos, no de rutinas.
    <name: string>
    <method: method_index>
    <reg_count: int>
    <reg: type_index>[reg_count]
    <inst_count: int>
    <inst: ...>[inst_count]

# Constants

## Type

    <type: type_index>

## Rutine

    <rutine: rutine_index>

## Binary

    <size: int>
    <data: byte>[size]

## Array

    <size: int>
    <values: const_index>[size]

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
