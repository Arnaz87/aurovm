
struct Pair { string k; string v; }

import cobre.utils.stringmap (string as `0`) {
  type `` as Map {
    string? get (string);
    void set (string, string);
  }
  Map `new` () as newMap;

  type iterator {
    Pair? next ();
  }
  iterator `new\x1diterator` (Map) as newIter;
}

void main () {
  Map m = newMap();
  m["1"] = "uno";
  m["2"] = "dos";
  println(m["1"].get() + " " + m["2"].get());

  iterator iter = newIter(m);
  repeat:
    Pair? _n = iter.next();
    if (_n.isnull()) return;
    Pair n = _n.get();
    println(n.k + ": " + n.v);
    goto repeat;
  end:
}