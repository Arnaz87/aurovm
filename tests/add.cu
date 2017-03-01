import void Prelude.print(String);
import String Prelude.itos(int);

import bool Prelude.gtz(int);
import int Prelude.inc(int);
import int Prelude.dec(int);

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
