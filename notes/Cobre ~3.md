# Cobre ~3

*[2017-10-29 16:23]*

# Items

Everything is an item, and each item can or not be at the same time a value at runtime. There are operations that takes items and can return other items, and operantions designed to be used at runtime can be used with items as well, as values can be represented by an item and some items may use those values, but with the restriction that those calculations cannot have side effects, every operation has to be pure.

Circular dependencies are allowed, except for these situations:

- An item cannot be the result of a computation that uses itself
- A module cannot have as parameters items that depend on its contents

This is probably very incomplete, with use I will fix this list, which will very likely be converted to a list of situations in which circular dependencies ARE allowed.

Following is a list of the posible item instructions, the name of the item/instruction is followed by its ID, which is used in the binary format of a module.

## Import [0]

    name: string

Imports a module that doesn't have parameters. A shortcut for partial import and then instatiating the module with empty parameters.

## Partial Import [1]

    name: string
    params: item

Imports a module that receives parameters as a kind of function that, when invoked, returns the fully loaded module with that parameter. The type of the parameter is specified in the params field.

## Use type [2]

    module: item
    name: string

Uses a type item from the module. Values can only be of types imported this way because two types are equal only if they both come from the same module, so type checking only makes sense when all types are imported directly from a module, and not built by some procedure.

## Use op [3]

    module: item
    name: string
    in: item
    out: item

Uses an op item from the module, with the indicated type argument and result

## Define op [4]

    in: item
    out: item

Creates an operation, it's body is defined in the bodies list

## Int [5]

    value: int

Create a value for cobre.core.nat

## Binary [6]

    length: int
    data: byte[length]

Create a value for cobre.core.bin

## Array [7]

    type: item
    length: int
    items: item[length]

Create a value for cobre.array(type)

## Tuple [8]

    length: int
    items: item[length]

Create a value for cobre.product with the types of each item

## Builtins [14, 15]

These two ids are reserved for shortcuts of commonly used types and operations in the standard library. As they are not essential, they are left unspecified for now. Probably useful will be the types unit, nullable, product, sum, any, type, array; and the operations that work with these types.

## Call [>15]

    in: item

Calls an operation or a partial module and saves the result as an item. This instruction doesn't have a specific ID, as any ID above 15 is a call, the ID is actually used to determine the operation used, which is the one with the index `ID - 15`

# Code

Each *define op* item is associated with its body in this section in order of declaration. The number of blocks is the same as the number of *define op* items in the module.

## Bytecode

If an instruction index is less than 16 it's a builtin instruction, otherwise is call shortcut. Each value that results of an instruction is assigned an index incrementally, the index of an instruction is not the same as the index of its values as some have many results and some none. If a value is used only once after it's created it's a temporary, if it's used more times or is reassigned later it becomes a variable, they must be treated differently by an optimal implementation because using a register for each temporary is too inefficient.

The builtin instructions are:

- `0 end`: Returns, taking all the result values as arguments
- `1 var`: Creates a null variable that must be assigned before used
- `2 dup (a)`: Copies the value at *a*
- `3 set (b a)`: Assigns to the variable at *b* the value at *a*
- `4 sgt (c)`: Gets the item at index *c*
- `5 sst (c a)`: Sets to the item at *c* the value at *a*
- `6 jmp (i)`: Jumps to the instruction with index *i*
- `7 jif (i a)`: If the value at *a* is true, jumps to *i*
- `8 nif (i a)`: If the value at *a* is false, jumps to *i*
- `9 any (i a)`: If the value at *a* is null, jumps to *i*, otherwise unboxes the value

The instruction 15 is a special instruction to build a tuple, it's first argument is an index to the tuple type, and after that as many arguments as fields has the tuple type.

Instructions 16 onwards are shortcuts to function calls, they receive

# Update *[2017-12-11 07:44]*

I wont be using this proposal anymore, the module will have different sections: modules, types, functions and values, and there will be operations for moving items into different sections.