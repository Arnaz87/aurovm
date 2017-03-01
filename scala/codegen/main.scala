package arnaud.myvm.codegen

import arnaud.sexpr.{Node => Sexpr}

object Main {
  def main (args: Array[String]) {
    
    val ast: Node = {
      import arnaud.myvm.codegen.Nodes._
      Block(Array(
        ImportType("Any", "Prelude", "Any"),
        ImportType("Int", "Prelude", "Int"),
        ImportProc("iadd", "Prelude", "add", 2, 1),
        ImportProc("itos", "Prelude", "itos", 1, 1),
        ImportProc("print", "Prelude", "print", 1, 0),
        Proc("Sum", Array("r"), Array("a", "b"), Block(Array(
          Scope(Block(Array(
            Declare("n" /*, "Int"*/),
            DeclareGlobal("g" /*, "Int"*/),
            Assign("n", Call("iadd", Array(Var("a"), Var("b")))),
            Assign("g", Call("imul", Array(Var("n"), Num(2.0)))),
            Call("print", Array(Call("itos", Array(Var("r")))))
          )))
        )))
      ))
    }

    println("AST:")
    println(Nodes.sexpr(ast).prettyRepr)

    val progstate = new ProgState()
    progstate %% ast

    println("Compiled Sexpr:")
    println(progstate.compileSexpr.prettyRepr)

    println("Compiled Binary:")
    val bindata = progstate.compileBinary
    new arnaud.myvm.bindump.Reader(bindata.toIterator).readAll

  }
}