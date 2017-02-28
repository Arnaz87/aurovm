package arnaud.myvm.codegen

import arnaud.sexpr.{Node => Sexpr}

object Main {
  def main (args: Array[String]) {
    
    val ast: Node = {
      import arnaud.myvm.codegen.Nodes._
      Block(Array(
        ImportType("Any", "Prelude", "Any"),
        ImportType("Int", "Prelude", "Int"),
        ImportProc("iadd", "Prelude", "add"),
        ImportProc("itos", "Prelude", "itos"),
        ImportProc("print", "Prelude", "print"),
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
    //println(progstate.compileBinary.toIterator.grouped(8).map{_.map{b => f"$b%02x"}.mkString(" ")}.mkString("\n"))

    new arnaud.myvm.bindump.Reader(progstate.compileBinary.toIterator).readAll

  }
}