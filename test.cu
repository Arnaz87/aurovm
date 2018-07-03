
import cobre.system {
  void println (string);
  void error (string);
}

import cobre.any { type any; }

import cobre.any (int) {
  any `new` (int) as anyInt;
  int? get (any) as getInt;
}

import cobre.any (string) {
  any `new` (string) as anyStr;
  string? get (any) as getStr;
}

void f (any a) {
  string? _s = getStr(a);
  if (_s.isnull()) println(":(");
  else println(_s.get());
}

void main () {
  f(anyStr("Hola!"));
  f(anyInt(4));
}
