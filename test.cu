
import cobre.system {
  void println (string);
  void error (string);
}

import cobre.any { type any; }

import cobre.any (int) {
  any `new` (int) as anyInt;
  int get (any) as getInt;
  bool test (any) as testInt;
}

import cobre.any (string) {
  any `new` (string) as anyStr;
  string get (any) as getStr;
  bool test (any) as testStr;
}

void f (any a) {
  if (!testStr(a)) println(":(");
  else println(getStr(a));
}

void main () {
  f(anyStr("Hola!"));
  f(anyInt(4));
}
