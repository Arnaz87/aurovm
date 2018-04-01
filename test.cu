
import cobre.function () {
  type `` as Fn;
  module closure;
  void apply (Fn);
}

import module closure (f as `0`) {
  Fn `new` (string) as fnew;
}

import cobre.system { void print (string); }
private void f (string msg) { print(msg + "!"); }

void main () {
  Fn g = fnew("Closura");
  apply(g);
}
