import Prelude.print;
import Prelude.itos;

import Prelude.gtz;
import Prelude.inc;
import Prelude.dec;

void main () {
  int a = 5;
  int b = 6;
  int c = mult(a, b);
  String str = itos(c);
  print(str);
}

int mult (int n, int m) {
  int r = 0;
  while ( gtz(m) ) {
    r = add(r, n);
    m = dec(m);
  }
  return r;
}

int add (int n, int m) {
  while ( gtz(m) ) {
    n = inc(n);
    m = dec(m);
  }
  return n;
}
