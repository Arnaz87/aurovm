# Scala-Palo

This is an implementation in Scala of my Virtual Machine design. The first language I am building in the machine is Lua, because of its simplicity.

Sbt and Scala are required.

To test the machine run: `sbt "lua/run -f test.lua"`, for instruction simply run `sbt lua/run`. It's also possible to run only the machine with `sbt run`, but it's not very useful because it can't accept input, for now this machine only works as a library and not standalone.

Currently this Lua implementation only supports assignment, function calls, the operators "+ - * / == < > ..", the while and if statements (with else, and a broken elseif), and the standard function print. Syntactically it supports much more but is not able to execute it.

I am now implementing the machine in the language Nim.
I like Scala a lot, but the JVM is very big, slow to start and memory consuming, that's why I'm making the change.
The Lua compiler will probably stay in Scala, but I'm considering implement it in Haskell.