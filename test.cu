
import cobre.system {
  void println (string);
  void error (string);
}

void f (string x) {
  //error("foo");
  string y;
  println(x + y);
  y = "lol";
}

void main () {
  string x = "Hola" + "!";
  f(x);
}
