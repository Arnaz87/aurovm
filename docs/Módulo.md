# Modulo

*Como el formato cambia tan frecuentemente, la definición del formato ahora está en* `discussion/Formato N` *. El formato que describe este archivo es el 2, pero voy a empezar a implementar el Formato 3.*

Un módulo tiene tres clases de componentes: tipo, rutina y valor. Cada clase está definida en su propia sección. Cada sección está compuesta de la siguiente manera: primero el número de componentes que contiene, y luego cada uno de esos componentes. Cada tipo de componente tiene además varios formatos posibles, y cada uno de los componentes listados en una sección esta precedido por un número que lo indica y luego los datos del componente, los cuales dependen del subtipo del componente. Hay además tres secciones extras que no se componen de componentes del módulo, son las dependencias, los prototipos y los metadatos.

# Magic

Un texto ascii que corrobora que se va a leer un módulo de cobre e indica la versión, seguido de un caracter null. Para esta versión, el número mágico es
`Cobre ~1\0`, 9 bytes en total.

# Imports

No hay subclases de dependencias (todavía), así que no estan precedidas por el número que indica la subclase.

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

# Rutines

El número de rutinas es el mismo que el número de prototipos, así que no se escribe.

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
    <reg_count: int>
    <reg: type_index>[reg_count]
    <inst_count: int>
    <inst: ...>[inst_count]

# Constants

Los módulos además pueden recibir parámetros, que son valores y se guardan al principio de la lista de constantes.

    <params>

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

# Metadatos

Los metadatos son s-expressions. Uso una codificación binaria especial, en vez de la representación canónica, para hacerlo más parecido a las demás secciones, y así aprovechar carácteristicas que probablemente ya están presentes en el lector del formato.

Cada elemento empieza con un varint, el primer bit de ese varint indica si es una lista (0) o un string (1), y el resto de los bits indican el tamaño. El tamaño representa el número de bytes si es un string, o el número de subelementos si es una lista.

El motivo de que el bit de una lista sea 0 y el de un string sea 1, es que de este modo, un byte `0x00` representa el número 0 codificado como varint, y esto a su vez representa una lista vacía, que es más o menos equivalente a null, o al menos lo hace en más contextos que el string vacío.