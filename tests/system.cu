
import cobre.system {
  void print(string);
  string read();
  int, string cmd(string);
}

void main () {
  print("What's your name?");
  string name = read();

  int code;
  string msg;
  code, msg = cmd("echo Hello " + name + "! | cat");
  print(msg);
}