# Tipos Principales


# Array

~~~
int[] arr;
arr[0];
~~~

Builtin

~~~
2 tipos
  int: import cobre.prim int
  IArr: array int
2 inst
  0: const 0 // int 0
  1: arr_get ? 0
~~~

Cobre ~1

~~~
imports:
  0: "cobre.prim"
  1: "cobre.array" (const[0])
types:
  0: import imports[0] "int"
  1: import imports[1] "array"
consts:
  0: type types[0]
~~~

# Tuple

~~~ cobre
(string, int) record;
record.0;
~~~

Builtin

~~~
3 tipos
  int: import cobre.prim int
  string: import cobre.string string
  tpl: tuple 2 string int
1 insts
  0: get ? 0
~~~

Cobre ~1

~~~
imports:
  0: "cobre.string"
  1: "cobre.prim"
  2: "cobre.tuple" (const[0])
types:
  0: import imports[0] "string"
  1: import imports[1] "int"
  2: import imports[2] "tuple"
rutines:
  0: t2 -> t0 : import imports[2] "0"
  0: -> : internal
    0: r0 ?
consts:
  0: arr (consts[1], consts[2]) // No tipado
  1: type t0
  2: type t1
~~~

# Function

~~~ cobre
int(string) fun;
fun("");
~~~

Builtin

~~~
3 tipos
  int: import cobre.prim int
  string: import cobre.string string
  fun: function 1 int 1 string
2 insts
  0: const 0 // ""
  1: call ? 0
~~~

Cobre ~1

~~~
imports:
  0: "cobre.string" ()
  1: "cobre.function" (consts[1] consts[2])
  2: "cobre.core" ()
types:
  0: import imports[0] "string"
  1: import imports[1] "function"
  2: import imports[2] "bin"
rutines:
  0: t0 -> : import imports[1] "call"
  1: t2 -> t0 : import imports[0] "bintos"
  2: -> : internal
    0: const c4 // ""
    1: r0 ? 0
consts:
  0: type types[0]
  1: arr ()
  2: arr (consts[0])
  3: bin ()
  4: r1 3 // ""
~~~

# Traits

~~~ cobre

~~~


