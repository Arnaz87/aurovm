package arnaud.culang

import fastparse.noApi._
import WsApi._

object Main {

  def parse_text (text: String) = {
    P(Toplevel.program ~ End).parse(text) match {
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
    println("Usage: (-i <code> | -f <filename>) [-o <output filename>]")
    System.exit(0)
    return ???
  }

  def main (args: Array[String]) {
    import arnaud.myvm.codegen.ProgState
    import arnaud.sexpr.Node

    val parsed = args(0) match {
      case "-f" => parse_file(args(1))
      case "-i" => parse_text(args(1))
      case _ => manual()
    }
    println(parsed)

    println()

    val cgnode = CodeGen.program(parsed)
    println(arnaud.myvm.codegen.Nodes.sexpr(cgnode).prettyRepr)

    val progstate = new ProgState()
    progstate %% cgnode
    val compiled = progstate.compile()
    val output = compiled.prettyRepr
    println(output)

    if (args.length >= 4 && args(2) == "-o") {
      import java.io._
      val outname = args(3)
      val pw = new PrintWriter(new File(outname))
      pw.write(output)
      pw.close
      println(s"File $outname saved")
    }
  }
}