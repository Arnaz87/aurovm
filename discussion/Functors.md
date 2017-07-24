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
  module AnyT { type T = Any; }
  module ListM = import List(AnyT);

  interface TypeT { type T; }

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

  module push (TypeT typet) {
    alias T = typet.T;
    module typett { type T = T; }
    module Anyfrom = import Any.from(typett);

    void push (List ls, T value) {
      Any any = Anyfrom.from(value);
      ListM.push(ls, any);
    }
  }
}
~~~

Módulos aplanados #1

~~~
module AnyList {
  module AnyT { type T = Any; }
  module ListM = import List(AnyT);

  interface TypeT { type T; }

  alias List = ListM.List;

  module head (TypeT typet) {
    alias T = typet.T;
    module typett { type T = T; }
    module Anyas = import Any.as(typett);

    T head (List ls) {
      Any any = ListM.head(ls);
      return Anyas.as(any);
    }
  }

  module push (TypeT typet) {
    alias T = typet.T;
    module typett { type T = T; }
    module Anyfrom = import Any.from(typett);

    void push (List ls, T value) {
      Any any = Anyfrom.from(value);
      ListM.push(ls, any);
    }
  }
}
~~~
