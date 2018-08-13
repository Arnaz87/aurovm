
/*import cobre.system { void println (string); }

import cobre.utils.arraylist (string as `0`) {
  type `` as list {
    string get (int);
    void set (int, string);
    void push (string);
    void insert (string, int);
    void remove (int);
  }
  list `new` () as newList;
}

import cobre.utils.stringmap (string as `0`) {
  type `` as Map {
    string? get (string);
    void set (string, string);
  }
  Map `new` () as newMap;
}

void main () {
  list l = newList();
  l.push("hola");
  l.push("XD");
  l.push("mundo");
  l.remove(1);
  l.insert(" ", 1);
  println(l[0] + l[1] + l[2]);

  Map m = newMap();
  m["1"] = "uno";
  m["2"] = "dos";
  println(m["1"].get() + " " + m["2"].get());
}*/

import cobre.string { string slice (string, int, int); }

void main () { println(slice("Cobrevm-0.6", 0, 15)); }
