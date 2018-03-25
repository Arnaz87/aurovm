# Cobre ~4

*[2018-03-23 05:23]*

The file starts with the ascii string `Cobre 0.5` followed by NUL.

A module file has 5 sections: Modules, Types, Functions, Code and Metadata. The first three are item sections, entries in the module and function sections must have a kind id, which indicates how the item is defined, and in this specification each item kind will have it's id indicated in square brackets in it's title.

# Modules

A module is a structure containing items indexed by name. An item may be a type, a function or another module, and each one of those sections can use items from a module.

A functor is one whose its items cannot be accessed until another module is passed as a parameter to it (the name is borrowed from ML). A functor's construction may fail if the module expects items not present in the argument or those items don't hold assumtions made by the functor.

A module file has two special module indices: the module at index 0 is the module passed as a parameter to the file module, and the module at index 1 is the module that will be exported by the file. The modules declared in the module section start at index 1.

The module defined by a module file is put in the global module namespace by the implementation, and it's up to the implementation to decide what name to use, it may use file system information or metadata. I intend to define a standard mechanism to do determine the name of a module file in the global module namespace.

Each module defines it's argument equivalence with other modules, if to the module eyes it's argument is equivalent to the argument of a previously built module, that module is returned instead. As most modules are defined by a module file, their arguments are by default equivalent if the items used from them are only types and they are equal, or if they don't use items from their arguments.

By convention, modules that don't use names in their arguments items expect those items to be named with their position in decimal notation starting at 0.

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

Creates a module with the specified items. Each item is defined by a section (a number indicating which of the module[0], type[1] or function[2] section is the item from), an index to an item of said section, and a name with which the item will be accessed from the module.

## ImportFunctor [2]

    name: string

Gets a module from the global module namespace as a functor without constructing it.

## Use [3]

    module: module_index
    name: string

Gets a functor imported from another module

## Build [4]

    functor: module_index
    argument: module_index

Applies an argument to a functor

# Types

    module: module_index
    name: string

Types do not have kinds, all types are always imported from a module, and the standard library provides certain special type creating modules. The type is imported from the module with index `module - 1`, if module is 0 the module the type is from is hidden, useful for documentation modules.

# Functions
    
    kind: int
    in_count: int
    in_types: type_index[in_count]
    out_count: int
    out_types: type_index[out_count]

## Null [0]

A function that is guaranteed to exist but isn't defined in the module file, for example in documentation modules.

## Code [1]

A function whose code is defined in the code section.

## Import

    name: string

If the kind is > 1, the function is extracted from the module with index `kind - 2`, and has an aditional string for the name after the usual ones.

# Constants

Defines functions that returns single constant values, and are added to the function list. In spite of these just being functions, they need to be separated from the main function section because to parse this section, all functions' inputs and outputs need to be known.

## Int [1]

    value: int

A value of type cobre.int (only positive numbers).

## Bin [2]

    size: int
    data: byte[size]

A fvalue of type cobre.core.bin.

## Call

Any item with kind > 15 is a function call, formated exactly like a regular function calls in code, but the arguments are indices to other functions (with exactly one result, if an argument function returns more than one, a constant for each result must be created beforehand). Each value the function returns is added independently as a constant. Constants are aware of each other, even if defined after, but circular calls are not allowed.

# Code

Each one of the blocks is linked to the code function declared with the same index, relative to the other code functions. The number of code items is implicit, counting the function items of kind Code.

## Bytecode

If an instruction index is less than 16 it's a basic instruction, otherwise is an index to an function. Each value that results of an instruction is assigned an index incrementally, the index of an instruction is not the same as the index of its values as some have many results and some none. If a value is used only once after it's created it's a temporary, if it's used more times or is reassigned later it becomes a variable, they should be treated differently by an optimal implementation because using a different memory location for each temporary is too inefficient.

The basic instructions are:

- `0 end`: Returns, taking all the result values as arguments.
- `1 hlt`: Halts the execution of the machine, "panics".
- `2 var`: Creates a null variable that must be assigned before used.
- `3 dup (a)`: Copies the value at *a* (*var+set?*).
- `4 set (b a)`: Assigns to the variable at *b* the value at *a*.
- `5 jmp (i)`: Jumps to the instruction with index *i*.
- `6 jif (i a)`: If the value at *a* is true, jumps to *i*.
- `7 nif (i a)`: If the value at *a* is false, jumps to *i*.

# Metadata

The metadata is structured like s-expressions with a custom binary encoding. Each element starts with a varint, the first bit indicates if the item is a list (0) or a string (1), and the rest of the bits indicate the number of subelements for lists or the number of characters for strings. The list bit is 0 so that the byte 0 represents an empty list, the closest value to nil.

# Core modules

This part is not definitive yet, it's more related to the standard library than to the module format.

Module `cobre.type` has operations to build types. Built types are aliases to other types but expanded with certain characteristics, like interfaces, which are functions bound to the types, and casts, which allow to convert types to other types at runtime.

Module `cobre.module` has tools to create and manipulate modules at runtime, which allow module files to compute modules at load time by setting their module #1 to a constructed module.
