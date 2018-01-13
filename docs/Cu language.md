# Cu

*[2018-01-09 16:45]*

The Cu language is a thin layer on top of the Cobre module format similar to C.

# Lexical

Lexically Cu is the same as C with the following remarks:

- There is no octal integer literal
- There is no pointer related syntax, but there is array syntax
- A quoted identifier is like a string but delimited with \` instead of " and has the same meaning as a regular identifier
- String literals have type `string` instead of `char[]`
- The reserved keywords are different than C's:
  + true, false, void, if, else, while, return, continue, break, goto, type, module, import, as, extern
- Default types are not keywords but implicitly imported types:
  + bool, int, float, string


# Import statement

Is marked with the `import` keyword, followed by the global module name, optionally followed by the keyword `as` and an alias for the module, followed by the imported items, enclosed in brackets and separated by semicolons. An imported item can be:

- a type, indicated by the `type` keyword followed by the name with which the type was exported
- a function, indicated by the return types separated by commas, or void if it doesn't return anything, followed by the name with which the function was exported, and the parameter type list, enclosed in parenthesis and separated with commas
- a constant, indicated by the type of the constant followed by the name with which the constant was exported

Items can optionally be aliased if they are followed by the keyword `as` and an identifier. Every imported item must finish with a semicolon, the alias must precede it.

If the entire module is aliased, none of it's items can be used directly, they have to be preceded by the module alias and `.`.

If the compiler has access to the imported module, the imported item list can be omitted and the statement must end with a semicolon. In that case, unless the import is aliased, all items are imported.

# Type statement

Declares an external type.

# Function statement

Cu functions are just as C functions, but can return multiple results, in which case each of it's types is listed before the function name separated with commas, and the return statement in the function body must also have a comma separated list of expressions matching the result types.

Parameters don't need a name, only the parameter types are required, but without a name there is no way to use them.

If the function has no body, it's external, and the statement must end in with a semicolon.

## Control flow

Control flow is also like C's, but there are no switch, for loops nor do while loops. There are labels and goto statements, and loops can be labeled so that break and continue statements can refer to outer loops. It is legal to jump out of loops and into them.

## Multiple assignment

Multiple assignment in declaration statements works like in C, but multiple variables can be assigned at once in a single statement when the assigned expression is a call to a function with multiple results. In this situation, the left side of the statement can have multiple variables separated by commas, and each one must match the function return types. But it must not be a declaration, as that would only assign the last variable and the rest would be uninitialized, like in C.

# Statics

Statics are like module level variables, they have the same syntax and behave the same as regular variables in function bodies, with the exception that they must be initialized immediately when declared.

Use them sparingly, as statics very likely to change in Cobre.

# Expressions

Expressions can be unary operations, binary operations and function calls.

Arithmetic operations are overloaded for int and float, the addition operation is also overloadod for string. Logical operations are short circuited.

Cu doesn't cast expressions implicitly, nor does an explicit cast expression exists, if casting is desired it must be trough library functions.

Function calls that return multiple values, when used in expressions an not in multi assignments, only use the first result and discard the rest.

