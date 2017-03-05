void main () {
  int bottles = 5;

  while (gtz(bottles)) {
    String plural = " bottles";
    if (eq(bottles, 1)) { plural = " bottle"; }

    print(concat(concat(bottles, plural), " of beer on the wall"));
    print(concat(concat(bottles, plural), " of beer"));
    print("Take one down, pass it around");
    bottles = dec(bottles);
    print(concat(concat(bottles, plural), " of beer on the wall"));
    print("");
  }
}