# Cobre VM

Cobre es una especificación de una máquina virtual, diseñada para ser simple y muy limpia en su diseño, tal que sea fácil escribir una implementación completa, interpretada, compilada o jit, pero también versátil y poderosa como para poder representar fácilmente muchas ideas diferentes de diversos lenguajes y paradigmas de programación.

Idealmente sería una plataforma en la que se puede escribir con cualquier lenguaje, cada uno interactuando fácilmente con los demás, y que pueda correr en muchas plataformas diferentes, como nativo en diferentes sistemas operativos, la web, la JVM, o embedido en juegos y aplicaciones.

Este proyecto en particular tiene varias cosas desarrollándose en paralelo, que son la especificación, discusiones de diseño, un intérprete de la máquina, implementaciones de algunos lenguajes, y un lenguaje especial que refleja el diseño de Cobre.

## nim

Por ahora la carpeta está desordenada, pero ahí está la implementación de la máquina virtual y algunas cosas necesarias para eso (como el parser de S-Expressions).

La máquina estaba hecha al principio en Scala, pero debido a que es una máquina virtual, es mejor si el lenguaje de la implementación no tiene un runtime muy pesado, por eso necesito un lenguaje de sistemas. Escojo Nim sobre C y C++ porque es más rápido escribir programas en Nim y es más fácil de leer.

## scala/sexpr

Una pequeña librería para manejar S-Expressions, ese es el formato de representación que estoy usando en todo el proyecto.

Aunque para este punto ya me estoy independizando de este formato para trabajar con el binario.

## scala/codegen

Esta es el más importante de Scala, aquí defino un AST agnóstico, y procedimientos que lo transforman y compilan al formato con el que trabaja la máquina virtual, con la ayuda de __scala/sxpr__.

## scala/lua

Lee y analiza código Lua, y con la ayuda de __scala/codegen__ lo compila. No lo ejecuta, el archivo generado tiene que ejecutarse por separado.

## scala/cu

Cu es un lenguaje tipo C o Java para Cobre, lo estoy haciendo para probar las características básicas de la máquina virtual.

```java
import void Prelude.print(String);

int, int sumsub (int a, int b) {
  return a+b, a-b;
}

void main () {
  int r = sumsub(5, 6);
  String s = itos(r);
  print(s);
}
```

# Proyectos Similares

- __JVM__: Este es el principal proyecto que me inspiró a iniciar el mío, me gusta mucho el ecosistema que se ha creado alrededor de él, como su inmensa cantidad de librerías y frameworks y, más que todo, los asombrosos lenguajes que se crearon para ella (Scala, Groovy, Jython, JRuby, Frege, Clojure), y que pueden trabajar fácilmente con lo que ya existe ahí, pero no me gusta que es muy específico de Java, la semántica de la JVM refleja a la del lenguaje Java, y más que todo lo complejo del proyecto, crear un lenguaje así o una implementación de la JVM es una misión imposible.
- __CLI/.Net__: Igual que la JVM, mejora lo referente a la semántica de la máquina, no está atada a ningún lenguaje en particular, y ofrece facilidades para la interacción entre lenguajes, pero sigue siendo muy grande y complejo, y es muy específico de Microsoft (No siento que Mono reciba tanta atención de la gente en general como lo hace .Net).
- __Parrot__: Está completamente diseñado para la interacción entre lenguajes y la facilidad para implementar lenguajes en Parrot, además le da mucho más énfasis a las características dinámicas, pero se mueve un poco lento y desordenado a mi parecer, no me gustan mucho algunas decisiones de diseño que tomaron, y en general sigue siendo un poco grande.
- __Webasm__: Aunque no tenga nada que ver, la descripción de Parrot lo describe bastante bien, la verdad. Pero confieso que a pesar de todo, este proyecto me emociona un poco.
- __Lua__: El tamaño y simplicidad de Lua es absolutamente perfecto, es justo lo que busco, pero es solo un lenguaje, con una semántica muy específica, por lo que no es tan fácil desarrollar paradigmas diferentes o lenguajes sobre Lua eficientemente.
- __LLVM__: Arquitectura virtual diseñada para parecerse mucho a cpus reales, está hecha como lenguaje intermedio en un compilador, por lo que está muy atado al mundo de los compiladores, no es muy bueno como representación portable de un programa ni es fácil de interpretar. Pnacl es un proyecto para hacer LLVM portable.

TLDR: Casi todos los proyectos existentes son demasiado grandes y complejos como para que una persona los entienda, y los que no, no son suficientemente versátiles.

# Tareas

Algunas de las cosas que necesito hacer para la máquina.

- Especificación de una librería estándar.
- Soporte para metadatos en todas mis herramientas.
- Errores con posición en el código fuente para la máquina de nim.
- Compilador a Javascript, con código legible, ayudandose con metadatos.
- Html con un editor de texto para correr código Cu.
- Compilador Lua.

