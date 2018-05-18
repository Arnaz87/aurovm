
import cobre.system { void print (string); }

import A (string, f) {
  type T as T1;
  T1 make (string) as make1;
}

// This is a second import, but because the type argument is the same, counts
// as the same module
import A (string, f) {
  // type T as T2; // this is T1
  string get (T1) as get1;
}

void f () {}

void main () {
  string x = get1(make1("Hola"));
  print(x);
}
