# Cobre VM

Cobre is an abstract machine specification, simple enough to make it easy to write a complete implementation from scratch, and versatile enough to represent a wide range of languages and paradigms.

Ideally, Cobre would be a platform in which a developer can write in any language and can interact easily with modules written in any other, which can run in a lot of different platforms, like different OS's, the web, the JVM or embedded in games and applications.

This project has many things being developed in parallel: the design, an example interpreter, a few language implementations, and a special language for the machine.

The main documentation is in [docs/Module Format.md](docs/Module Format.md).

## nim

An example interpreter written in the Nim programming language. I choose Nim because it's low level enough so I can say how machine resources are managed, but it's also very easy to read and write.

## scala/codegen

This is the most important of the scala projects, it's a library that helps with code generation from other languages.

## scala/lua

Reads and compiles Lua code.

## scala/cu

Culang is a language like C that reflects Cobre's internals.

```
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

## scala/js

Compiles Cobre's instructions to Javascript code, so it can run in browsers.

# Proyectos Similares

(Too long to translate, TLDR in english)

- __JVM__: Este es el principal proyecto que me inspiró a iniciar el mío, me gusta mucho el ecosistema que se ha creado alrededor de él, como su inmensa cantidad de librerías y frameworks y, más que todo, los asombrosos lenguajes que se crearon para ella (Scala, Groovy, Jython, JRuby, Frege, Clojure), y que pueden trabajar fácilmente con lo que ya existe ahí, pero no me gusta que es muy específico de Java, la semántica de la JVM refleja a la del lenguaje Java, y más que todo lo complejo del proyecto, crear un lenguaje así o una implementación de la JVM es una misión imposible.
- __CLI/.Net__: Igual que la JVM, mejora lo referente a la semántica de la máquina, no está atada a ningún lenguaje en particular, y ofrece facilidades para la interacción entre lenguajes, pero sigue siendo muy grande y complejo, y es muy específico de Microsoft (No siento que Mono reciba tanta atención de la gente en general como lo hace .Net).
- __Parrot__: Está completamente diseñado para la interacción entre lenguajes y la facilidad para implementar lenguajes en Parrot, además le da mucho más énfasis a las características dinámicas, pero se mueve un poco lento y desordenado a mi parecer, no me gustan mucho algunas decisiones de diseño que tomaron, y en general sigue siendo un poco grande.
- __Webasm__: Aunque no tenga nada que ver, la descripción de Parrot lo describe bastante bien, la verdad. Pero confieso que a pesar de todo, este proyecto me emociona un poco.
- __Lua__: El tamaño y simplicidad de Lua es absolutamente perfecto, es justo lo que busco, pero es solo un lenguaje, con una semántica muy específica, por lo que no es tan fácil desarrollar paradigmas diferentes o lenguajes sobre Lua eficientemente.
- __LLVM__: Arquitectura virtual diseñada para parecerse mucho a cpus reales, está hecha como lenguaje intermedio en un compilador, por lo que está muy atado al mundo de los compiladores, no es muy bueno como representación portable de un programa ni es fácil de interpretar. Pnacl es un proyecto para hacer LLVM portable.

TLDR: Most of the existing projects are too big and complex for one single person to understand, and those that aren't (Lua), are not versatile enough.

# Tareas

Algunas de las cosas que necesito hacer para la máquina.

- Structs
- Arrays
- Cargar múltiples módulos
- Módulos paramétricos
- Uso de componentes como valores
- Uso de valores como componentes 
- Resolver si van a llamarse rutinas, procedures, funciones u operaciones...

## Terminadas

- Especificación de una librería estándar.
- Soporte para metadatos en todas mis herramientas. (Faltan la VM y Lua)
- Html con un editor de texto para correr código Cu.
- Compilador a Javascript, con código legible, ayudandose con metadatos.
- Constantes y parámetros import en Culang (Solo en el lenguaje, no en la VM).

## Secundarias

- Chequeo de tipos.
- Errores con posición en el código fuente para la máquina de nim. (Secundaria)
- Compilador Lua.
