void main () {
  int a = 5;
  int b = 6;
  int c = add(a, b);
  String str = itos(c);
  print(str);
}

int mult (int n, int m) {
  int r = 0;
  while (m > 0) {
    r = add(r, n);
    m = m - 1;
  }
  return r;
}

int add (int n, int m) {
  while (m > 0) {
    n = n + 1;
    m = m - 1;
  }
  return n;
}
