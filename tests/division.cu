void main () {
  // División con restas sucesivas.
  int num = 0;
  int denom = 3;
  
  if (denom == 0) {
    print("División por Cero!");
    return;
  }
  
  // TODO: Agregar resultados múltiples,
  // y hacer esto una rutina.
  
  int resto = num;
  int resul = 0;
  
  // while (resto >= denom) {
  while (resto+1 > denom) {
    resto = resto-denom;
    resul = resul+1;
  }
  
  print(
    itos(num) + "/" + itos(denom)
    + " = " +
    itos(resul) + "%" + itos(resto)
  );
}