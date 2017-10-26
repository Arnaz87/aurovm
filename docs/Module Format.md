# Module Format

*Ya no voy a documentar los diferentes formatos en discussion, ahí solo voy a hablar de mis ideas. Ahora el formato estará documentado solamente aquí. Si el formato siguiente sigue en desarrollo el documento lo dirá.*

Second version, in development.

Simplifies the lastest. Removes module parameters and defines some primitives. The idea is that in future versions there will be no primitives, only modules, or at least as much as possible, so that any language and platform can define their own.

Each section starts with a number of items, and then defines one by one. Each item start with a kind, except where specified.

# Signature

An ascii string indicating the version of the module and if it's even a module. For this version is `Cobre ~2` followed by NUL, 9 bytes in total.

# Imports

Imports don't have kinds, for now. Circular dependencies are not allowed.

    <name: string>

# Types

The machine also has special support for some types in *cobre.core*, specifically *any*, a Sum of all possible types.

## Null

Used when the module can't provide a definition but it's garanteed there is one, for example for platform specific types or documentation modules.

    kind: 0

## Import

Uses a type defined in an imported module.

    kind: 1
    <module: import_index>
    <name: string>

## Alias

A box of another type that can't be used when the boxed type is expected, instead it has to be explicitly casted.

    kind: 2
    <type: type_index>

## Nullable

It's like an alias but the value can be absent. It requires a special instruction to check if the value exists.

    kind: 3
    <type: type_index>

## Product

Equivalent to tuples in functional languages, or C structs without field names.

    kind: 4
    <field_count: int>
    <field: type_index>[field_count]

## Sum

Equivalent to variants in functional languages, or C unions but tagged and without field names, but not type unions as multiple fields can have the same type.

    kind: 5
    <field_count: int>
    <field: type_index>[field_count]

## Function

Runtime function.

    kind: 6
    <in_count: int>
    <ins: type_index>[in_count]
    <out_count: int>
    <outs: type_index>[out_count]

# Functions

## Null

    kind: 0

## Import

    kind: 1
    <module: import_index>
    <name: string>
    <in_count: int>
    <int_type: type_index>[in_count]
    <out_count: int>
    <out_type: type_index>[out_count]

## Code

Each one is linked to it's corresponding code block in the order they are declared in the file.

    kind: 2
    <in_count: int>
    <int_type: type_index>[in_count]
    <out_count: int>
    <out_type: type_index>[out_count]

## Unbox

Extracts from a box type the boxed value, valid for alias and nullable types. Error if the value is null.

    kind: 4
    <type: type_index>

## Box

Creates a boxed value for alias and nullables. For product types takes all the field values as parameters and builds the product value.

    kind: 5
    <type: type_index>

## Get

This is the way to access the field of product and sum types. With sum types, the result is a nullable version of the field's type.

    kind: 6
    <type: type_index>
    <field: index>

## Set

With product types works like a regular setter, for sum types this creates a new value because sum values cannot be directly changed.

    kind: 7
    <type: type_index>
    <field: index>

## Anyunbox

Extracts the value from an Any to a nullable of the target type.

    kind: 8
    <type: type_index>

## Anybox

Converts a value to an Any.

    kind: 9
    <type: type_index>

## Call

Receives a function value with arguments and calls the function, returning the results.

    kind: 10
    <type: type_index>

# Statics

## Null

This kind is reserved and must not be used.

    kind: 0

## Import

Reserved for import, but it's disabled because module statics can change in mid program, modules should use functions instead to request other modules' statics.

    kind: 1
    <module: module_index>
    <name: string>

## Int

A value of type `cobre.core.int`.

    kind: 2
    <value: int>

## Binary

Binary data, the value has type `cobre.core.bin`.

    kind: 3
    <length: int>
    <bytes: byte>[length]

## Type

    kind: 4
    <type: type_index>

## Function

    kind: 5
    <type: op_index>

## Null

Any kind greater than 15 represents an uninitialized static, the type is the one with index `kind - 15`. If the type is nullable the value is a valid null, otherwise the value must be set statically. If there is at least one control path in the static code in which a non-nullable null static isn't set, the whole module is invalid.

    kind > 15

# Exports

Kind indicates what type of item to use, either a type (1) or an function (2).

    <kind: int>
    <index: int>
    <name: string>

# Code

Each one of the blocks is linked to the code function declared with the same index, relative to the other code functions. Code has no kind, and no count as it's implicit by the number of code functions declared.

Appart from the implicit blocks for each code-kind function, there is the static block that's added at the end.

## Bytecode

If an instruction index is less than 16 it's a builtin instruction, otherwise is an index to an function. Each value that results of an instruction is assigned an index incrementally, the index of an instruction is not the same as the index of its values as some have many results and some none. If a value is used only once after it's created it's a temporary, if it's used more times or is reassigned later it becomes a variable, they must be treated differently by an optimal implementation because using a register for each temporary is too inefficient.

The builtin instructions are:

- `0 end`: Returns, taking all the result values as arguments.
- `1 var`: Creates a null variable that must be assigned before used.
- `2 dup (a)`: Copies the value at *a*.
- `3 set (b a)`: Assigns to the variable at *b* the value at *a*.
- `4 sgt (c)`: Gets the static with index *c*.
- `5 sst (c a)`: Sets to the static at *c* the value at *a*.
- `6 jmp (i)`: Jumps to the instruction with index *i*.
- `7 jif (i a)`: If the value at *a* is true, jumps to *i*.
- `8 nif (i a)`: If the value at *a* is false, jumps to *i*.
- `9 any (i a)`: If the value at *a* is null, jumps to *i*, otherwise unboxes the value.

# Metadata

The metadata is structured like s-expressions with a custom binary encoding. Each element starts with a varint, the first bit indicates if the item is a list (0) or a string (1), and the rest of the bits indicate the number of subelements for lists or the number of characters for strings. The list bit is 0 so that the byte 0 represents an empty list, the closest value to nil.
