void main () {
  int bottles = 5;

  while (gtz(bottles)) {
    String plural = " bottles";
    if (eq(bottles, 1)) { plural = " bottle"; }

    int bottle_s = itos(bottles);

    print(concat(concat(bottle_s, plural), " of beer on the wall"));
    print(concat(concat(bottle_s, plural), " of beer"));
    print("Take one down, pass it around");
    bottles = dec(bottles);
    print(concat(concat(itos(bottles), plural), " of beer on the wall"));
    print("");
  }
}