import cobre.system {
  void print(string);
}

import cobre.array (string) {
  struct array;
  array new (string, int);
  string get (array, int);
  void set (array, int, string);
}

void main () {
  array arr = new("a", 3);
  set(arr, 1, "b");
  print( get(arr, 0) + get(arr, 1) );
}