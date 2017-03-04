package arnaud.myvm.codegen

import arnaud.sexpr.{Node => Sexpr}

object Main {
  def main (args: Array[String]) {
    
    val ast: Node = {
      import arnaud.myvm.codegen.Nodes._
      Block(Array(
        Import("Prelude"),
        Proc("Sum",
          Array(("r", "Int")),
          Array(("a", "Int"), ("b", "Int")), 
          Scope(Block(Array(
            Declare("n", "Int"),
            Assign("n", Call("iadd", Array(Var("a"), Var("b")))),
            Assign("r", Var("n")),
            Return
          )))
        ),
        Proc("Main",
          new Array[(String, String)](0),
          new Array[(String, String)](0),
          Scope(Block(Array(
            Call("print", Array(
              Call("itos", Array(
                Call("Sum", Array(
                  Num(2.0), Num(3.0)
                ))
              ))
            ))
          )))
        )
      ))
    }

    println("AST:")
    println(Nodes.sexpr(ast).prettyRepr)

    val progstate = new ProgState()
    progstate %% ast
    progstate.fixTypes()

    println("Compiled Sexpr:")
    println(progstate.compileSexpr.prettyRepr)

    println("Compiled Binary:")
    val bindata = progstate.compileBinary
    printBinary(bindata)
  }

  def printBinary(bindata: Traversable[Int]) {
    new arnaud.myvm.bindump.Reader(bindata.toIterator).readAll
  }
}