package arnaud.myvm.lua

object Main {
  
  def parse_text (text: String): Ast.Node = {
    import fastparse.all._

    //Expressions.expr.parse(text)
    P(Statements.block ~ End).parse(text) match {
      case Parsed.Success(succ, _) => succ
      case fail: Parsed.Failure =>
        print(fail.extra.traced.trace)
        System.exit(0)
        ???
    }
  }

  def parse_file (name: String) = {
    parse_text(scala.io.Source.fromFile(name).mkString)
  }

  def manual (): Nothing = {
    println("Usage: (-i <code> | -f <filename>) [-o <filename>] [-print-parsed] [-print-binary]")
    System.exit(0) // System exit es de java, es Unit (void en Java)
    return ??? // ??? es de scala, es Nothing
  }

  class Params (input: List[String]) {
    val data = collection.mutable.Map[String, Option[String]]()
    private def helper (l: List[String]) {
      l match {
        case k::v::xs if
          (k startsWith "-") && !(v startsWith "-") =>
          data(k.tail) = Some(v); helper(xs)
        case k::xs if k startsWith "-" =>
          data(k.tail) = None; helper(xs)
        case Nil =>
        case _::xs => helper(xs)
      }
    }
    helper(input)

    def apply (k: String) = data(k).get
    def get (k: String, other: String) = data.getOrElse(k, None).getOrElse(other)
    def has (k: String) = data.contains(k)
  }

  def main (args: Array[String]) {

    val params = new Params(args.toList)
    val parsed =
      if (params.has("f"))
      { parse_file(params("f")) }
      else if (params.has("i"))
      { parse_text(params("i")) }
      else { manual() }
    if (params.has("print-parsed")) { println(parsed) }

    val compiler = new Compiler
    compiler %% parsed.asInstanceOf[Ast.Block]

    val binary = {
      val buf = new collection.mutable.ArrayBuffer[Int]
      val writer = new format.Writer(buf)
      writer.write(compiler.program)
      buf
    }

    if (params has "print-binary") {
      import arnaud.cobre.format
      println("== Compiled Binary ==")
      format.Main.printBinary(binary)
    }

    /*if (params.has("o")) {
      import java.io._
      val pw = new PrintWriter(new File(params("o")))
      pw.write(output)
      pw.close
    }*/
  }
}