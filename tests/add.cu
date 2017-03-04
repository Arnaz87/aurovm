void main () {
  Int a = 5;
  Int b = 6;
  Int c = mult(a, b);
  String str = itos(c);
  print(str);
}

Int mult (Int n, Int m) {
  Int r = 0;
  while ( gtz(m) ) {
    r = add(r, n);
    m = dec(m);
  }
  return r;
}

Int add (Int n, Int m) {
  while ( gtz(m) ) {
    n = inc(n);
    m = dec(m);
  }
  return n;
}
