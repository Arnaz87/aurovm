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

Note: the code snippets are marked as C to take advantage of the syntax highlighter in sublime text, but it's actually Culang code.


# Imports

~~~c
// Imports the module "a.b", where '.' is replaced with the field separator
import a.b {
  // Imports the function "f" from the module, and makes
  // it accessible in the rest of the code as "f"
  void f (int);

  // The same as above, the argument names are ignored
  void f (int arg0);

  // The same but the function is instead refered with "ff"
  void f (int) as ff;

  // arguments and return types work as with regular functions
  int, char f2 (int, int);

  // Unlike non imported functions, the names can also have field
  // separatos like modules, and also metanames can be indicated
  // separated with ':', but they have to be aliased because regular
  // identifiers can't use those features.
  void f3.a:b () as f3;

  // This can be used with f4 as no other function has the same main name
  void f4:a ();

  // Imports the type t and is used with "t"
  type t;

  // Identifiers and aliases work like with imported functions
  type t2.a:b as t2;

  // Types can have bodies, alias is optional, cannot end in ';'
  type t as tt {
    // Functions imported inside type bodies are accessed as methods,
    // they are equivalent to a function imported normally but
    // with the type name added as a metaname:
    // void f1:t ();
    void f1 ();

    // Methods with the "get" and "set" metanames are accessed as fields,
    // they need not be aliased, if aliased they are used as methods.
    int x1:get ();
    void x1:set (int);

    // All methods, including fields are inferred to have a first argument
    // of type t, and is automatically named "this".
  }}
~~~

# Structs

~~~c
// Equivalent to:
// import cobre.record (A, B) { type `` as T; }
struct T {
  // A field. Imports from that same module the functions
  // get0 and set0, as if they were named a:get and a:set,
  // and if non private, they are exported as a:T:get and a:T:set
  A a;

  // The same as above, but because it is the second argument, the type B
  // is passed second in the module arguments, and the getters and
  // setters are get1 and set1 (index of the fields is 0 based)
  B b;

  // A method, receives an implicit first argument of type T named this,
  // and if exported, is exported with an aditional metaname "T"
  void f () {}

  // Setters and getters methods can act like fileds of that name
  int c:get () {return 1;}
  void c:set (int c) {}

  // All of these functions work with any struct declared in any other
  // module with the same types in the same order
}
~~~

# Types

~~~c
// The same as a struct, but creates a separate type not compatible with
// other equivalent structs or types. It's equivalent to:
// import cobre.record (A, B) { type `` as _T; }
// import cobre.typeshell (_T) { type `` as T; }
type T {
  // Fields and methods work the same as with structs
}

// A type with a base, creates a type MyInt that is not compatible with int
type MyInt (int) {
  // Fields do not work, only methods, including getters and setters
  int f:get () {
    // The as operator can convert a value of MyInt to an int.
    int x = this as int;
    return x;
  }
}
~~~

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

