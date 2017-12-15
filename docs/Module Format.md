# Module Format

*[2017-12-11 08:08]*

This version is a continuation of Cobre ~2, not related to Cobre ~3.

The file starts with the ascii string `Cobre ~4` followed by NUL.

A module file has 6 sections: Modules, Types, Functions, Values, Code and Metadata. The first four are item sections, each entry in those sections must have a kind id, which indicates how the item is defined, and in this specification each item kind will have it's id indicated in square brackets in it's title.

# Modules

A module is a structure containing items indexed by name. An item may be a type, function, value or another module, and each one of those sections can use items from a module

A functor is one whose its items cannot be accessed until another module is passed as a parameter to it. A functor's construction may fail if the module expects items not present in the argument or those items don't hold requirements made by the functor.

A module file has two special module indices: the module at index 0 is the module passed as a parameter to the file module, and the module at index 1 is the module that will be exported by the file. The modules declared in the module section start at index 1.

The module defined by a module file is put in the global module namespace by the implementation, and it's up to the implementation to decide what name to use, it may use file system information or metadata. I intend to define a standard mechanism to do determine the name of a module file in the global module namespace.

Each module defines it's arguemnt equivalence with other modules, if to the module eyes it's argument is equivalent to the argument of a previously built module, that module is returned instead. As most modules are defined by a module file, their arguments are by default equivalent if the items used from them are only types and they are equal, or if they don't use items from their arguments.

By convention, modules that don't use names in their arguments items expect those items to be named with their position in decimal starting at 0.

By convention, modules that have one main item export it with an empty string as the name, such as Java classes, Python modules or Java generic methods.

## Import [0]

    name: string

Gets a module from the global module namespace constructed with an empty module argument.

## Define [1]

    len: int
    items: {
        kind: int
        index: int
        name: string
    }[len]

Creates a module with the specified items. Each item is defined by a section (a number indicating which of the module[0], type[1], function[2] or value[3] section is the item from), an index to an item of said section, and a name with which the item will be accessed from the module.

## ImportFunctor [2]

    name: string

Gets a module from the global module namespace as a functor.

## Use [3]

    module: module_index
    name: string

Gets a functor imported from another module

## Build [4]

    functor: module_index
    argument: module_index

Applies an argument to a functor

# Types

In reality, types can only be created by a few selected core modules, so the only necessary type operation is to get it from a module. In the future there will be shortcuts for commonly used types, but for now it's not necessary

## Null [0]

A type that it's guaranteed to exist but it's not defined in this module, for example in documentation modules.

## Import [1]

    module: module_index
    name string

A type defined as an item of one of the modules.

# Functions

All functions item kinds define the form of the function:
    
    in_count: int
    in_types: type_index[in_count]
    out_count: int
    out_types: type_index[out_count]

## Null [0]

A function that is guaranteed to exist but isn't defined in the module file, for example in documentation modules.

## Import [1]

    module: module_index
    name: string

A function extracted from one of the modules. This is the only kind that has additional data, after the kind id but before the function form.

## Code [2]

A function whose code is defined in the code section.

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

# Core modules

Module `cobre.type` has operations to build types. Built types are aliases to another types but expanded with certain characteristics, like interfaces, which are functions bound to the types, and casts, which allow to convert types to other types at runtime.

Module `cobre.module` has tools to create and manipulate modules at runtime, which allow module files to compute modules at load time by setting their module #1 to a constructed module.

# Type shells

To build a functor, the implementation needs all the items in the argument that will be used defined, so a type (java syntax) `B<A>` cannot be created until `A` is completed, and recursive types like `B<B>` cannot be created, in most cases it doesn't make sense. Shell types however can be recursed, as a shell type internally is defined in a module that takes type arguments, but the type exported by the module doesn't depend on any of it's arguments and it's always different, only the functions on the shell type depend on the arguments.

Type shells are constructed in the module `cobre.type`. 
