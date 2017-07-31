# Functors

*[2017-07-22 00:59]*

Intentaré diseñar la máquina usando el mecanismo que usa Ocaml, [está explicado aquí](http://caml.inria.fr/pub/docs/manual-ocaml/moduleexamples.html). Empezaré con un ejemplo de cómo podría ser en cobre.

~~~

signature List [type T] {
  type List;

  List empty;
  List append (List, T);

  T head (List);
  List tail (List);
}

module List [type T] : List {
  type List = Nil | List T List;

  List empty = Nil;

  List append (List l, T t) {
    return List t l;
  };

  T head (List l) {
    match l {
      case Nil: error;
      case List t _: return t;
    }
  }

  List tail (List l) {
    match l {
      case Nil: error;
      case List _ tl: return tl;
    }
  }
}

interface Order { type T; bool lt (T, T); }
signature Sort (Order order) {
  alias List = List[order.T].List;
  List order (List);
}

interface Hash { type T; int hash (T); }
interface Eq { type T; bool eq (T, T); }
signature HashMap (Hash H, Eq E, type V) {
  
  // Aquí se establece la relacion. No importa si el alias no se usa.
  alias K = H.T = E.T;

  type Map;
  void set (Map, K, V);
  V get (Map, K);
  void remove (Map, K);
}
~~~

~~~
module List {
  params:
    type T;
  public:
    type List;

    List empty;
    List append (List, T);

    T head (List);
    List tail (List);
  body:
    type List = Nil | List T List;

    List empty = Nil;

    List append (List l, T t) {
      return List t l;
    };

    T head (List l) {
      match l {
        case Nil: error;
        case List t _: return t;
      }
    }

    List tail (List l) {
      match l {
        case Nil: error;
        case List _ tl: return tl;
      }
    }
}

module Sort {
  params:
    type T;
  public:
    List order (List);
  body:
    List order (List input) { /* ... */ }
}
~~~

Módulos en árbol

~~~
module AnyList {
  module ListM = import List(T = Any);

  type List = ListM.List;

  module head (TypeT typet) {
    alias T = typet.T;
    module typett { type T = T; }
    module Anyas = import Any.as(typett);

    T head (List ls) {
      Any any = ListM.head(ls);
      return Anyas.as(any);
    }
  }

  module cons (TypeT typet) {
    alias T = typet.T;
    module typett { type T = T; }
    module Anyfrom = import Any.from(typett);

    void cons (List ls, T value) {
      Any any = Anyfrom.from(value);
      ListM.cons(ls, any);
    }
  }
}
~~~

Representación *[2017-07-25 13:00]*

~~~
"AnyList" ;name
0 ;defs
  import "Any" ;0
  use $0 "Any" ;1
  import "List" ;2
  use $2 "_functor" ;3
  instance $3 ;4
    1 ;params
    "T" $1
  use $4 "List" ;5
  functor ;6
    7 ;defs
      param "T" ;0
      import "Any" ;1
      use $1 "as" ;2
      instance $2 ;3
        1 ;params
        "T" $0
      parent $4 ;4
      use $4 "head" ;5
      parent $5 ;6
      rutine ;7
        1 ;ins
          $6
        1 ;outs
          $0
        0 ;instructions
    1 ;exports
      "head" $7
  functor ;7
    0 ;defs
      param "T" ;0
      import "Any" ;1
      use $1 "from" ;2
      instance $2 ;3
        1 ;params
        "T" $0
      parent $4 ;4
      use $4 "cons" ;5
      parent $5 ;6
      rutine ;7
        2 ;ins
          $6 $0
        0 ;outs
        body ...
    1 ;exports
      "cons" $7
3 ;exports
  ;2
~~~

# Muchas Caracteristicas

*[2017-07-25 15:30]*

~~~ culang
module List {
  extern type T;

  struct Nil {};
  struct Cns { T t; Ls l; };
  union Ls { Nil; Cns };

  type List = Ls;

  List cons (List l, T t) {
    return List(Cns(t, l as Ls)) as List;
  };

  T head (List _l) {
    Ls l = _l as Ls;
    with (c = l as Cns) { return c.t; }
    else { error(); }
  }

  List tail (List l) {
    Ls l = _l as Ls;
    with (c = l as Cns) { return c.l as List; }
    else { error; }
  }

  export List as T, cons, head;
}

module AnyList {
  import List (T = Any) {
    type T as List;
  }

  type Ls = List;
  Ls from (List ls) { return ls as Ls; }
  List to (Ls ls) { return ls as List; }

  partial import _head (List = List, ls_to = to) as head;
  partial import _cons (List = List, ls_from = from, ls_to = to) as cons;

  export List as T, head, cons;
}

module _head {
  import List (T = Any) {
    type T as List;
    Any head (List);
  }

  extern type T;
  extern type Ls;
  extern List ls_to (Ls);

  import Any.`as` (T = T) { T `as` (Any); }

  T _head (Ls _ls) {
    List ls = ls_to(_ls);
    Any any = head(ls);
    return `as`(any);
  }

  export _head as head;
}

module _cons {
  import List (T = Any) {
    type T as List;
    Any cons (List);
  }

  extern type T;
  extern type Ls;
  extern List ls_to (Ls);
  extern Ls ls_from (List);

  import Any.from (T = T) { Any from (T); }

  Ls _cons (Ls _ls, T t) {
    Any any = from(t);
    List l = ls_to(ls);
    List l2 = cons(l, any);
    return ls_from(l2);
  }

  export _cons as cons;
}
~~~

# Lua Example

*[2017-07-26 18:59]*

~~~ lua
function f (a, b) return a+b end
print( f(1,2) )
~~~

## Por secciones

El problema con las secciones es que la implementación tiene que armar un árbol complicado, porque muchos items salen de los módulos, pero al mismo tiempo los módulos tienen items como parámetros, así que todas las secciones tependen unas de las otras.

~~~ cuasm
; Las líneas con "¡Círculo!" al final, indican que usan
; información que está más adelante en el módulo.

0 ;modules
  require "Any" ;0
    0 ;params
  import $0 "from" ;1
    1 ;params
    type[0] ; ¡Círculo!
  require "Lua" ;2
    0 ;params
0 ;types
  import module[0] "Any" ;0
  import 
  function ;1
0 ;rutines
~~~

## Todo es un item

La alternativa es que todo sea un item, y están definidos en el módulo en orden, de modo que un item simplemente no puede usar items que no se han definido. Esto es un problema para las funciones y tipos recursivos, que son definitivamente muy importantes en muchas circumstancias.

~~~ cuasm
0 ;items
  import "Any" ;0
  use $1 "Any" ;1

~~~

## Cobre

~~~ cobre
module main {
  import Any {
    type Any;
    module from as Any_from_mod;
  }

  #define lua_f function Args (Args);

  import Any_from_mod (T = lua_f) {
    Any from (lua_f);
  }

  import lua {
    type Args;
    Args print (Args);
    Any add (Any, Any);
    void arg_push (Args, Any);
    Any arg_get (Args);
    Args arg_new ();
    Args call (Any, Args);
  }

  Args f (Args args) {
    Any a = arg_get(args);
    Any b = arg_get(args);
    Any r = add(a, b);
    Args result = arg_new();
    arg_push(result, r);
    return result;
  }

  void main () {
    Args _a = arg_new();
    arg_push(_a, )
    print(call(f,))
  }
}
~~~

# Recursión

*[2017-07-28 10:16]*

## En tipos y funciones

~~~ cobre
struct Nil {}
struct Cons { Any t; List ls; }
union List { Nil nil; Cons cons; }

Any last (List ls) {
  with (Cons cons = ls.cons) {
    with (Nil nil = cons.ls.nil) {
      return cons.t;
    } else {
      return last(cons.ls);
    }
  } else { error; }
}
~~~

~~~ cuasm
4 ;types
  unit ;0 Nil
  any  ;1
  struct ;2 Cons
    2 ;fields
    type[1] ;0 t
    type[3] ;1 ls
  union ;3 List
    2 ;variants
    type[0] ;0 nil
    type[2] ;1 cons
1 ;rutines
  def ;0 last
    1 ;ins
      type[3] ;List ls
    1 ;outs
      type[1] ;Any
;code
  0 ;instructions, for $0
    ...
;total 17 bytes

04 16 17 18  02 01 03 19
02 00 02 01  03 01 03 01
01 ...
~~~

*[2017-07-28 15:31]*

~~~ cuasm
4 ;modules
  require "cobre.core" ;0
    0 ;params ;13 bytes
  require "cobre.product" ;1
    1 ;params
    "0" const[7] ;19 bytes
  require "cobre.array" ;2
    1 ;params
    "0" const[0] ;17 bytes
  require "cobre.sum" ;3
    1 ;params
    "0" const[8] ;15 bytes
  ;65 bytes
9 ;types
  use module[0] "type" ;0
  use module[0] "array" ;1
  use module[2] "T" ;2 cobre.array<type>.T
  use module[1] "T" ;3 struct Cons
  use module[0] "unit" ;4
  typedef type[4] ;5 Nil
  use module[0] "any" ;6
  use module[3] "T" ;7 union{Nil, Cons}
  typedef type[7] ;8 List
  ;45 bytes
1 ;rutines
  import module[2] "build" ;0
    1 ;ins
      type[1]
    1 ;outs
      type[2]
  ;13 bytes
9 ;consts
  type type[0] ;0 cobre.core.type
  array ;1
    2 ;items
    const[3] const[4]
  array ;2
    2 ;items
    const[5] const[6]
  type type[6] ;3 Any
  type type[8] ;4 List
  type type[5] ;5 Nil
  type type[3] ;6 Cons
  rutine[0] ;7 array<type>.build
    const[1]
  rutine[0] ;8 array<type>.build
    const[2]
  ;23 bytes
;total = 146 bytes
;sin arrays, hubiera salvado 34 bytes = 112 bytes

04 01 10 'c  'o 'b 'r 'e
'. 'c 'o 'r  'e 00 01 13
'c 'o 'b 'r  'e '. 'p 'r
'o 'd 'u 'c  't 01 01 '0
07 01 11 'c  'o 'b 'r 'e
'. 'a 'r 'r  'a 'y 01 01
'0 00 01 'c  'o 'b 'r 'e
'. 's 'u 'm  01 01 '0 08;
09 01 00 04  't 'y 'p 'e
01 00 05 'a  'r 'r 'a 'y
01 02 01 'T  01 01 01 'T
01 00 04 'u  'n 'i 't 02
04 01 01 00  03 'a 'n 'y
01 03 01 't  02 07;01 01
02 05 'b 'u  'i 'l 'd 01
01 01 02;09  01 00 04 02
03 04 04 02  05 06 01 06
01 08 01 05  01 03 16 01
16 02;
~~~

## Struct modules

*[2017-07-29 02:07]*

~~~
2 imports
  "cobre.core" ;0
    0 ;params
  "cobre.struct" ;1
    1 ;params
    const[1]
2 types
  import import[0] "any" ;0
  import import[1] "T" ;1
2 consts
  type type[0] ;0
  array ;1
    2 ;items
    const[0] const[0]
;21 bytes por struct + 3 por campo
~~~

## Struct builtin

~~~
2 types
  any ;0
  struct ;1
    2 ;fields
    type[0] type[0]
;2 bytes por struct + 1 por campo
~~~

## En modulos

~~~ cobre
module parent {
  include child {
    type Child;
  }

  struct Parent {
    string name;
    Child child;
  }

  export Parent;
}

module child {
  include parent {
    type Parent;
  }

  struct Child {
    string name;
    Parent parent;
  }

  export Child;
}
~~~
