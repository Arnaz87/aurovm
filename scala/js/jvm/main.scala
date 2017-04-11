package arnaud.cobre.backend.js

object Main {
  def main (args: Array[String]) {
    val filename = args(0)
    val src = scala.io.Source.fromFile(filename).mkString
    val ast = arnaud.culang.Parser.parse(src)
    val prg = arnaud.culang.Compiler(ast).program

    val program = Builder.build(prg)

    /*program.constants foreach println

    for ((i, rutine) <- program.rutines) {
      rutine match {
        case rutine: RutineDef =>
          println(rutine.name getOrElse s"#$i")
          println("  Vars:")
          for (v <- rutine.vars.set) {
          //  println(s"    #${v.index} ${v.name.getOrElse("")}")
          }
          println("  Stmts:")
          for (stmt <- rutine.stmts) {
            println(s"    ${stmt}")
          }
        case ImportRutine(mod, name) =>
          println(s"$mod.$name")
      }
    }*/

    program.rutines foreach {
      case rutine: RutineDef =>
        val t = new Transformer(rutine)
        t.applyAll()
      case _ =>
    }

    val writer = new Writer(program)
    writer.write()
    writer.lines foreach println
  }
}