import Prelude {
  //Void = Nil;
  print = print;
  gtz = gtz;
  dec = dec;
  add = add;
  concat = strcat;
  print = print;
  itos = itos;
  Any = Any;
}

proc MAIN () {
  Int a = 5;
  Int b = 6;
  Int c = mult(n=a, m=b).r;
  String str = itos(a=c).r;
  //String str = c;
  print(a=str);
}

proc mult (Int n, Int m, Int r) {
  r = 0;
  while (gtz(a=m).r) {
    r = add(a=r, b=n).r;
    m = dec(a=m).r;
  }
}