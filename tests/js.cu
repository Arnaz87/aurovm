import cobre.system;

import js.window {
  void alert (string);
  string prompt (string);
}

import js.element {
  struct Element;
  void appendChild (Element, Element);
  string getTextContent (Element);
  string getAttribute (Element);
  string getStyle (Element, string);
  void setTextContent (Element, string);
  void setAttribute (Element, string);
  void setStyle (Element, string, string);
}

import js.document {
  Element body ();
  Element createElement (string);
  Element getElementById (string);
}

void main () {
  string name = prompt("¿Cómo te llamas?");
  string msg = "Hola " + name + "!";
  Element span = createElement("span");
  setTextContent(span, msg);
  appendChild(body(), span);
}