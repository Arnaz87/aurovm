# Cobre VM

Mi modelo de la máquina virtual. Aquí tengo una implementación básica de la máquina y algunos lenguajes de prueba.

El nombre no es definitivo, por mucho tiempo se llamó Palo pero Cobre es mucho mejor, y aún quiero un nombre más bonito.

El proyecto es medio grande, así que lo separé en varios subproyectos.

## nim

Por ahora la carpeta está desordenada, pero ahí está la implementación de la máquina virtual y algunas cosas necesarias para eso (como el parser de S-Expressions).

La máquina estaba hecha al principio en Scala, pero debido a que es una máquina virtual, creo que es conveniente saber exactamente como se están representando y procesando los datos en la máquina real, por eso necesito un lenguaje de sistemas en vez de un lenguaje que corre sobre otra máquina virtual. Pero tampoco me gusta C por su simplicidad extrema (lo cual es bueno y me gusta, pero no para este proyecto), ni C++ por lo feo, por eso decidí usar Nim.

## scala/sxpr

Una pequeña librería para manejar S-Expressions, ese es el formato de representación que estoy usando en todo el proyecto.

## scala/codegen

Esta es el más importante de Scala, aquí defino un AST agnóstico, y procedimientos que lo transforman y compilan al formato con el que trabaja la máquina virtual, con la ayuda de __scala/sxpr__.

## scala/lua

Lee y analiza código Lua, y con la ayuda de __scala/codegen__ lo compila. No lo ejecuta, el archivo generado tiene que ejecutarse por separado.

## scala/cu

Cu es un lenguaje tipo C o Java para Cobre, lo estoy haciendo para probar las características básicas de la máquina virtual.

```java
import Prelude;
proc sum (Int a, Int b) Int {
  return a+b;
}

proc main () void {
  Int r = 5+6;
  String s = itos(r);
  Prelude.print(s);
}
```
