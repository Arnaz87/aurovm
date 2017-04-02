void main () {
  int bottles = 5;

  while (bottles > 0) {
    string plural = " bottles";
    if (bottles == 1) { plural = " bottle"; }

    string bottle_s = itos(bottles);

    // Uso ++ porque por ahora los operadores solo traducen a una rutina,
    // pero deberían resultar en diferentes rutinas dependiendo de los tipos
    // de los operandos.
    print(bottle_s + plural + " of beer on the wall");
    print(bottle_s + plural + " of beer");
    print("Take one down, pass it around");
    bottles = bottles - 1;
    print(itos(bottles) + plural + " of beer on the wall");
    print("");
  }
}