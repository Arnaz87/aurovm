import cobre.system;

int LOL = 4;

import cobre.array (string) str_arr {
  struct array;
  void set (str_arr.array, int, string);
  string get (str_arr.array, int);
}

void main (str_arr.array args) {
  print( str_arr.get(args, LOL) );
}