package arnaud.myvm.codegen

import arnaud.sexpr.{Node => Sexpr}

object Main {
  def main (args: Array[String]) {
    val text = """
    (
      (Import
        Prelude
      )
    )
    """

    val ast: Node = {
      import arnaud.myvm.codegen.Nodes._
      Block(Array(
        ImportProc("Any", "Prelude", "Any"),
        ImportProc("Int", "Prelude", "Int"),
        ImportProc("iadd", "Prelude", "add"),
        Proc("Sum", Array("r"), Array("a", "b"), Block(Array(
          Scope(Block(Array(
            //Declare("n", "Int"),
            Assign("r", Call("iadd", Array(Var("a"), Var("b"))))
          )))
        )))
      ))
    }

    println("AST:")
    println(Nodes.sexpr(ast).prettyRepr)

    val progstate = new ProgState()
    progstate %% ast

    println("Compiled:")
    println(progstate.compile.prettyRepr)
  }
}