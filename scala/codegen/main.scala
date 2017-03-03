package arnaud.myvm.codegen

import arnaud.sexpr.{Node => Sexpr}

object Main {
  def main (args: Array[String]) {
    
    val ast: Node = {
      import arnaud.myvm.codegen.Nodes._
      Block(Array(
        ImportType("Int", "Prelude", "Int"),
        ImportType("String", "Prelude", "String"),
        ImportProc("iadd", "Prelude", "add", 2, 1),
        ImportProc("itos", "Prelude", "itos", 1, 1),
        ImportProc("print", "Prelude", "print", 1, 0),
        Proc("Sum",
          Array(("r", "Int")),
          Array(("a", "Int"), ("b", "Int")), 
          Scope(Block(Array(
            Declare("n", "Int"),
            //DeclareGlobal("g" /*, "Int"*/),
            Assign("n", Call("iadd", Array(Var("a"), Var("b")))),
            //Assign("g", Call("iadd", Array(Var("n"), Num(2.0)))),
            Call("print", Array(Call("itos", Array(Var("r")))))
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