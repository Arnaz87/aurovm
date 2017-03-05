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
    println("Usage: (-i <code> | -f <filename>) [-o <output filename>] [--print] [--print-(ast|codegen|sexpr|binary)]")
    System.exit(0)
    return ???
  }

  def main (_args: Array[String]) {
    import arnaud.myvm.codegen.ProgState
    import arnaud.sexpr.Node

    object args {
      import scala.collection.mutable.Set
      sealed abstract class Input
      case class File(filename: String) extends Input
      case class Code(code: String) extends Input
      case object INone extends Input

      val iter = _args.iterator

      var input: Input = INone
      var output: Option[String] = None
      var print: Set[String] = Set()
      var pipe = false

      while (iter.hasNext) {
        iter.next match {
          case "-i" => input = Code(iter.next)
          case "-f" => input = File(iter.next)
          case "-o" => output = Some(iter.next)
          case "--print" => print ++= Set("ast", "codegen", "sexpr", "binary")
          case "--print-ast" => print += "ast"
          case "--print-codegen" => print += "codegen"
          case "--print-sexpr" => print += "sexpr"
          case "--print-binary" => print += "binary"
          case "--pipe" => pipe = true
          case _ => manual()
        }
      }

    }

    def maybeExit () {
      if (args.print.isEmpty && args.output.isEmpty && !args.pipe) {
        System.exit(0)
      }
    }

    val parsed = args.input match {
      case args.File(file) => parse_file(file)
      case args.Code(code) => parse_text(code)
      case _ => manual()
    }

    if (args.print("ast")) {
      args.print -= "ast"
      println("=== AST ===")
      println(parsed)
      println()
    }
    maybeExit()

    val cgnode = CodeGen.program(parsed)

    if (args print "codegen") {
      args.print -= "codegen"
      println("=== Codegen AST ===")
      println(arnaud.myvm.codegen.Nodes.sexpr(cgnode).prettyRepr)
      println()
    }
    maybeExit()

    val progstate = new ProgState()
    progstate %% cgnode
    progstate.fixTypes()


    if (args print "sexpr") {
      args.print -= "sexpr"
      println("=== Compiled Sexpr ===")
      val compiled = progstate.compileSexpr()
      val output = compiled.prettyRepr
      println(output)
      println()
    }
    maybeExit()

    val binary = progstate.compileBinary()

    if (args print "binary") {
      args.print -= "binary"
      println("=== Compiled Binary ===")
      arnaud.myvm.codegen.Main.printBinary(binary)
    }
    maybeExit()

    if (args.pipe) {
      val stream = java.lang.System.out
      val bytes = new Array[Byte](binary.size)
      for ( (byte, i) <- binary.zipWithIndex ) {
        bytes(i) = byte.asInstanceOf[Byte]
      }
      stream.write(bytes, 0, bytes.size)
    }

    if (!args.output.isEmpty) {
      import java.io._
      val filename = args.output.get
      val stream = new FileOutputStream(new File(filename), false)
      binary foreach { byte: Int => stream.write(byte) }
      stream.close
      println(s"Binary data written to file $filename")
    }
  }
}