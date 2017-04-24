
import cobre.utils.box (int) ibox {
  struct Box;
  ibox.Box new (int);
  int get (ibox.Box);
  void put (ibox.Box, int);
}

import cobre.utils.box (string) sbox {
  struct Box;
  sbox.Box new (string);
}

void main () {
  ibox.Box bx = ibox.new(5);
  int x = ibox.get(bx);
  sbox.Box sbx = sbox.new("5");
}