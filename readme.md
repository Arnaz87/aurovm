# Cobre VM

Cobre is an abstract machine specification, simple enough to make easy writing a complete implementation from scratch, and versatile enough to represent a wide range of languages and paradigms.

Ideally, Cobre would be a platform in which a developer can write in any language and can interact easily with modules written in any other, which can run in a lot of different platforms, like different OS's, the web, the JVM or embedded in games and applications.

It's intended that many features available in many programming languages or elsewhere, like OOP, dynamic dispatch, object serializing, etc. be implemented in standard libraries and conventions, instead of on Cobre itself.

This project has many things being developed in parallel: the design, an example interpreter, a few language implementations, and a high level language with feature parity with Cobre.

The main documentation is in [docs/Module Format.md](docs/Module Format.md).

**Note**: The main documentation is in english, but files in notes and a few source comments here and there are in spanish. I'm working on translating the important stuff to english.

**License**: This project is open source software, distributed under the MIT license.

# Motivations

I like the web, but I don't like Javascript. I like to write small scripts and programs, and I like Python's and Java's libraries, but I don't like Python nor Java. I love Scala, but I don't like big and fat JVM. I like scripting my games, but I get tired of Lua. I sometimes want to go functional, but Scheme implementations are too incomplete and GHC is another big and fat.

I want to develop in any platform, in any language I want, with the libraries I like.

*I also want all of my programs to be **as fast as Cee**. One can only dream, right?*

# How to use

To install cobre, you need the Nim language. Run `make install` as the superuser, then you can run any cobre module with `cobre <module_name>`, the module has to be in the working directory or installed in the system. To install a cobre module run `cobre --install <file>`, the file has to have the module name.

To compile a Cu language source file into a Cobre module, you need scala and sbt. Eenter the *scala* directory and run
`sbt "cuJVM/run -f ../tests/pimontecarlo.cu -o out"`, which compiles the source code at *tests/pimontecarlo.cu* into a cobre module named *out* in the scala directory.

To execute that, exit the scala directory and run `cobre out`. You should see something like the following output:

`2000 samples, PI=3.144 in 7.575521s`

If you want to see the contents of a module instead of just runing it, enter the scala directory and run `sbt "bindump/run ../out"`.

**Warning**: Sbt is very slow and memory heavy.

# Project structure

## nim

An example interpreter written in the Nim programming language. I choose Nim because it's low level enough so I can say how machine resources are managed, but it's also very easy to read and write.

## scala/cobre

A scala interface for working with Cobre modules.

## scala/cu

Culang is a language like C that reflects Cobre's internals.

```
import cobre.system {
  void print(string);
}

int, int sumsub (int a, int b) {
  return a+b, a-b;
}

void main () {
  int r = sumsub(5, 6);
  string s = itos(r);
  print(s);
}
```

## scala/bindump

Parses and prints the contents of a Cobre module.

## scala/js (inactive)

Compiles Cobre modules to Javascript, so it can run in browsers.

# Similar projects

<<<<<<< HEAD
- __JVM__: The main proyect that inspired me to begin mine, I like a lot the ecosystem created around it, like it's inmense amount of libraries, frameworks, and mainly the awesome languages that run on top of it (Scala, Groovy, Jython, JRuby, Closure, Frege), and that works so easily with what it's already in the Java ecosystem. But the problems are that is very Java specific, the JVM reflects the Java language, not viceversa, and so other projects must adapt to the *Java Way*. But worst than that is the extreme scope and complexity of the JVM, creating roll off your own implementation of the JVM is very difficult if you are not a big team (IBM, GNU, etc.).
- __CLI/.Net__: Microsoft's approach to Java, and it has alost all of it's flaws. The only significant improvement is it's language independence, now the building blocks are more general and friendlier to different paradigms, but the biggest problem is still there, it's size and complexity, and in spite of it's platform independence, very few people have actually succesfully implemented Net and the Microsoft's default implementation doesn't care about other platforms, so it's only good for big standalone windows-only applications, and a bad fit for anything else.
=======
- __JVM__: The main proyect that inspired me to begin mine, I like a lot the ecosystem created around it, like it's inmense amount of libraries, frameworks, and mainly the awesome languages that run on top of it (Scala, Groovy, Jython, JRuby, Closure, Frege), and that works so easily with what it's already in the Java ecosystem. But the problems are that is very Java specific, the JVM reflects the Java language, not viceversa, and so other projects must adapt to the *Java Way*. But worst than that is the extreme scope and complexity of the JVM, creating a language for it or roll off your own implementation of the JVM is close to imposible if you are not a BIG team (IBM, GNU, etc.).
- __CLI/.Net__: Microsoft's approach to Java, and it has almost all of its flaws. The only significant improvement is it's language independence, now the building blocks are more general and friendlier to different paradigms, but the biggest problem is still there, it's size and complexity, and in spite of it's platform independence, very few people have actually succesfully implemented Net and the Microsoft's default implementation doesn't care about other platforms, so it's only good for big standalone windows-only applications, and a bad fit for anything else.
>>>>>>> d5d4ee84d181ae7fc1d595802167bf621fc2be7a
- __Parrot__: Completely designed to support a wide variety of programming languages, focusing mostly on dynamic typing. A significant improvement to above's problems, but doesn't get there yet, although smaller is still a big proyect hard to understand all at once.
- __WebAssembly__: A very simple virtual machine, designed to run many languages anywhere, but is simple by being very low level, compiling to Webasm is like compiling for an x86 processor, and there is a reason why scripting languages are more popular than compiled ones (because they are more and healthier because they are easier to implement). The designers actually want a lot of the things I want, but their priority is C++ on the browser (that's why they target C++ compilers, not developers), so it doesn't align completely with Cobre's intent.
- __Lua__: Perfect simplicity, the design is very straightforward and **so simple**, so much in fact, that one man alone created the fastest scripting language imlplementation so far (LuaJIT, if not the fastest at least definitely up there). The problem is that, like Java, is very language specific, basically the only languages one can implement on top of it are Lua-like (ie. moonscript, just like with Javascript). If one desired LuaJIT to script a project, because of it's size and speed, one has to stick with Lua, which a lot of people don't like.
- __LLVM__: It's actually a compiler intermediate representation, not by itself a compilation target, LLVM IR files are not really distributable. One has to distribute either the source code and expect everyone to have that language's compiler installed, or the machine code and expect everyone to have the same architecture and OS, or distribute many diferent binaries for each flavour (potentially **a lot**).
- __Javascript__: errr... Javascript is actually a pretty messy scripting language, not a clean compilation target. The reason everyone wants to compile to Javascript is because it is **Everywhere**, but not for it's positive qualities as a language, it is everywhere because everyone has a browser and it became popular in browsers long ago (at the beggining there was nothing else), but the only reason browsers can implement modern Javascript is because browser vendors are **Big Corporate Monsters** that have the manpower to implement modern Javascript completely, and because of that they also want to be in every person's computer and they also have the power to attempt that (and succeed). A better alternative is actually WebAssembly, a modern attempt which actually may be well designed this time, but I already mentioned it's problems. I would like Cobre to be everywhere, but for different reasons as Javascript.

**TLDR**: Most of the existing projects are too big and complex for one single person to understand, and those that aren't (Lua, WebAssembly), are not versatile enough.

# Tasks

Things that need to be done

- Load multiple modules
- Finish the standard library. It must have:
  + Structs
  + Arrays
  + Variants / Unions (possibly with Any)
  + Any type
  + Dynamic language tables
  + Functors
  + Shell type (Alias)
  + OOP Class type
  + IO
  + FFI
  + Threads?
  + Ownership Model? (Simplified?)
- Implement Lua
  + Lua library in Cu
  + Lua compiler in Lua
- Full support for cobre modules in Culang

# Wishlist

Some things I wish existed, created with or on top of Cobre

- A better app centric web.
- A Unity or Godot level game engine scripted with Cobre.
- Cobre cross language libraries on top of various protocols, like DBus, Ajax, REST Apis.

