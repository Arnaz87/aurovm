# Cobre VM

Cobre is an abstract machine specification, simple enough to make easy writing a complete implementation from scratch, and versatile enough to represent a wide range of languages and paradigms.

Ideally, Cobre would be a platform in which a developer can write in any language and can interact easily with modules written in any other, which can run in a lot of different platforms, like different OS's, the web, the JVM or embedded in games and applications.

It's intended that many features available in many programming languages or elsewhere, like OOP, dynamic dispatch, object serializing, etc. be implemented in standard libraries and conventions, instead of on Cobre itself.

This project holds the design and an implementation written in Nim. The main documentation is in [docs/Module Format.md](docs/Module Format.md).

There is an [alternative implementation](https://github.com/Arnaz87/cobreweb) based on Javascript, and there's also a [Lua implementation](https://github.com/Arnaz87/culua) on Cobre. You can see both of them in action [here](http://arnaud.com.ve/cobre/).

**Note**: The main documentation is in english, but files in notes and a few source comments here and there are in spanish. I'm working on translating the important stuff to english.

**License**: This project is open source software, distributed under the MIT license.

# Motivations

I like the web, but I don't like Javascript. I like to write small scripts and programs, and I like Python's and Java's libraries, but I don't like Python nor Java. I love Scala, but I don't like big and fat JVM. I like scripting my games, but I get tired of Lua. I sometimes want to go functional, but Scheme implementations are too incomplete and GHC is another big and fat.

I want to develop in any platform, in any language I want, with the libraries I like.

*I also want all of my programs to be **as fast as Cee**. One can only dream, right?*

# How to use

To install cobre, you need the Nim language. Run `make install` as the superuser, then you can run any cobre module with `cobre <module_name>`, the module has to be in the working directory or installed in the system. To install a cobre module run `cobre --install <file>`, the file has to have the module name.

To execute a Cobre module, use `cobre <modulefile>`. To create module files, you can use [Culang](https://github.com/Arnaz87/culang) or [CuLua](https://github.com/Arnaz87/culua). To see the contents of a compiled module, you can use [cobredump](https://github.com/Arnaz87/cobredump). You can also compile a Cobre module to Javascript with [cobreweb](https://github.com/Arnaz87/cobreweb).

# Similar projects

- __JVM__: The most popular and the main example of a virtual machine. It has a big ecosystem of libraries, frameworks and amazing languages like Scala and Clojure. The problem is that it's very big and complex and making a compilant implementation is very very difficult, and another is that it's built specifically around the Java language and any Language implementation must adapt to the Java way to interoperate with the ecosystem.
- __CLI/.Net__: Microsoft's Java, and as such just as inadequate. The first difference is that the main imlementation (and because of the complexity almost the only one) is Windows specific, which strongly conflicts with Cobre's multiplatforms objective. The other difference is that it's designed to be more language neutral, and that's good but it's not enough to compensate the downsides.
- __Parrot__: Mainly designed to support many dynamic languages, and although simpler than the JVM and the CLI, it's still too complex to understand all a once.
- __LLVM__: It's actually a compiler intermediate representation, not by itself a compilation target. LLVM IR files are not really distributable, so one has to distribute either the source code and expect everyone to have the language's compiler installed, or the machine code and expect everyone to have the same architecture and OS, or distribute many diferent binaries for each system flavour (potentially **a lot**).
- __MuVM__, __WebAssembly__: The designers of these projects share a lot of Cobre's objectives, but their approach abstracts very lightly a physical machine, so compiling to them is similar to compiling to x86. I believe a simpler, higher level design is better to mantain the health of the project and it's ecosystem, compiling for physical machines is hard, that's why scripting languages are far more popular.
- __Lua__, __Scheme__: These are not as similar to the other projects, but they are included as examples of how a very simple and straightforward design welcomes involvement and progress. Scheme for example has a lot of fully compilant implementations, and Lua has one of the (if not *the*) fastest scripting languages implementations, written by a single person.
- __Javascript__: Javascript is also very different from these projects in design, but it's currently most popular software distribution format for many languages and projects, by necessity, which hurts the web ecosystem because it wasn't designed for that. Trying to implement a compilant Javascript engine is very complicated.

**TLDR**: Most of the existing projects are too big and complex for one single person to understand, and those that aren't (like Lua and WebAssembly), are not versatile enough.

# Tasks

Things that need to be done

- Closures, they are ubiquitous and too hard for language implementors
- Module level code and parametric modules are ugly: modules are duck typed maps and type/function to value and vice versa is ugly
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
  + Module manipulation
- Figure out concurrency and memory safety
- Scheme on cobre
- Make the cobre module dumper in a cobre language
- Make a static analysis tool

# Wishlist

Some things I wish existed, created with or on top of Cobre

- A better app centric web.
- A Unity or Godot level game engine scripted with Cobre.
- Cobre cross language libraries on top of various protocols, like DBus, Ajax, REST Apis.

