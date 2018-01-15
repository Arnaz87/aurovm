import cobre.system {
  void print(string);
}

import cobre.array (string) str_arr {
  struct array;
  str_arr.array new (string, int);
  string get (str_arr.array, int);
  void set (str_arr.array, int, string);
}

void main () {
  str_arr.array arr = str_arr.new("a", 3);
  str_arr.set(arr, 1, "b");
  print( str_arr.get(arr, 0) + str_arr.get(arr, 1) );
}