import cobre.system;
import cobre.string;

void main () {
  saludar("Arnaud");
}

// Esta función esta definida después de ser usada
void saludar (string name) {
  print(concat("Hola, ", concat(name, "!")));
  //print("Hola " + name + "!");
}
