package arnaud.culang

object Main {

  def parse_text (text: String) = {
    Parser.parse(text)
    /*try { Parser.parse(text) }
    catch { case e: ParseError =>
      println(e.getMessage)
      //println(e.trace)
      System.exit(1)
      ???
    }*/
  }

  def parse_file (name: String) = {
    parse_text(scala.io.Source.fromFile(name).mkString)
  }

  def manual (): Nothing = {
    println("Usage: (-i <code> | -f <filename>) [-o <output filename>] [--pipe] [--print-ast]")
    System.exit(0)
    return ???
  }

  def main (_args: Array[String]) {
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
          case "--print" => print ++= Set("ast", "binary")
          case "--print-ast" => print += "ast"
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

    val (filename, parsed) = args.input match {
      case args.File(file) => (file, parse_file(file))
      case args.Code(code) => ("<string>", parse_text(code))
      case _ => manual()
    }

    if (args.print("ast")) {
      args.print -= "ast"
      println("=== AST ===")
      println(parsed)
      println()
    }
    maybeExit()
    
    val program = compiler.compile(parsed, filename)

    val buffer = new collection.mutable.ArrayBuffer[Int]()
    val writer = new arnaud.cobre.format.Writer(buffer)
    writer.write(program)

    if (args print "binary") {
      args.print -= "binary"
      println("=== Compiled Binary ===")
      writer.print()
    }
    maybeExit()

    if (args.pipe) {
      val stream = java.lang.System.out
      val bytes = new Array[Byte](buffer.size)
      for ( (byte, i) <- buffer.zipWithIndex ) {
        bytes(i) = byte.asInstanceOf[Byte]
      }
      stream.write(bytes, 0, bytes.size)
    }

    if (!args.output.isEmpty) {
      val filename = args.output.get
      writer.writeToFile(new java.io.File(filename))
      println(s"Binary data written to file $filename")
    }
  }
}