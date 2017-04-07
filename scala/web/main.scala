//import scala.scalajs.js.JSApp
import scala.scalajs.js
import scala.scalajs.js.annotation._

import scala.util.{Try, Success, Failure}

import arnaud.cobre.format
import arnaud.culang

/*
object TutorialApp extends JSApp {
  def main(): Unit = {
    val src = "void main () {}"
    val ast = culang.Parser.parse(src)
    println(src, " -> ", ast)
  }
}
*/

@js.native
@JSGlobal
object Terminal extends js.Object {
  def print (str: String): Unit = js.native
  def println(str: String): Unit = js.native
  def clear(): Unit = js.native
}

object TerminalStream extends java.io.Writer {
  override def close () {}
  override def flush () {}
  override def write(cbuf: Array[Char], off: Int, len: Int) {
    val str: String = cbuf.drop(off).take(len).mkString
    Terminal.print(str)
  }

  val printWriter = new java.io.PrintWriter(TerminalStream)
}

class Interpreter (program: format.Program) {

  import program._

  def log(objs: Any*) { println(objs map (_.toString) mkString " ") }

  val constants = new Array[Any](program.constants.size)
  for ((cns, i) <- program.constants.zipWithIndex) {
    constants(i) = cns match {
      case bin: BinConstant => bin
      case CallConstant(rut, _args) =>
        val args = _args map {a: Constant => constants(a.index)}
        val result = run(rut, args)
        result(0)
    }
  }

  def runDef(rut: RutineDef, args: Seq[Any]): Seq[Any] = {
    import rut._

    val regs = new Array[Any](inregs.size + outregs.size + rut.regs.size)
    for ((arg, i) <- args.zipWithIndex) {regs(i) = arg}

    var pc = 0

    def lblpc (l: Lbl) = pc = code indexWhere {
      case Ilbl(_l) => l == _l
      case _ => false
    }

    while (pc >= 0) {
      //log(pc, rut.code(pc))
      rut.code(pc) match {
        case End() => pc = -1
        case Cpy(a, b) => regs(a.index-1) = regs(b.index-1); pc+=1
        case Cns(a, b) => regs(a.index-1) = constants(b.index); pc+=1
        case Ilbl(l) => pc+=1
        case Jmp(l) => lblpc(l)
        case Ifj(l, a) => if (regs(a.index-1).asInstanceOf[Boolean]) lblpc(l) else pc+=1
        case Ifn(l, a) => if (!regs(a.index-1).asInstanceOf[Boolean]) lblpc(l) else pc+=1
        case Call(rut, _outs, _ins) =>
          val params = _ins map {r: Reg => regs(r.index-1)}
          val results = run(rut, params)
          for ((res, reg) <- results zip _outs) {
            regs(reg.index-1) = res
          }
          pc += 1
        //case _ => pc = -1
      }
    }

    regs.drop(inregs.size).take(outregs.size)
  }

  def run(rut: Rutine, args: Seq[Any]): Seq[Any] = {
    rut match {
      case rut: Module#Rutine =>
        /*if (rut.module.nm != "Prelude") {
          println(rut.toString)
          println(rut.module.nm, rut.module.params)
          throw new Exception(s"Unknown module: ${rut.module.nm}")
        }*/
        rut.name match {
          case "iadd" =>
            return List(args(0).asInstanceOf[Int] + args(1).asInstanceOf[Int])
          case "isub" =>
            return List(args(0).asInstanceOf[Int] - args(1).asInstanceOf[Int])
          case "gt" =>
            return List(args(0).asInstanceOf[Int] > args(1).asInstanceOf[Int])
          case "gte" =>
            return List(args(0).asInstanceOf[Int] >= args(1).asInstanceOf[Int])
          case "makeint" =>
            val bin = args(0).asInstanceOf[BinConstant].bytes
            val n = bin(3) | (bin(2)<<8) | bin(1)<<16 | bin(0)<<24
            return List(n)
          case "makestr" =>
            val bin = args(0).asInstanceOf[BinConstant]
            val str = bin.bytes.map(_.asInstanceOf[Char]).mkString
            return List(str)
          case "print" =>
            Terminal.println(args(0).asInstanceOf[String])
            return Nil
          case "concat" =>
            return List(args(0).asInstanceOf[String] + args(1).asInstanceOf[String])
          case "itos" =>
            return List(args(0).asInstanceOf[Int].toString)
          case nm => throw new Exception(s"Unknown rutine: Prelude.$nm")
        }
        return Nil
      case rut: RutineDef =>
        return runDef(rut, args)
    }
  }

  def runMain () {
    val main = rutines find {
      case rut: RutineDef => rut.name == "main"
      case _ => false
    } match {
      case Some(rut: RutineDef) => rut
      case None => throw new Exception("main rutine not found")
    }
    runDef(main, Nil)
  }
}

@JSExportTopLevel("Culang")
object Culang {
  type ModuleMap = js.Dictionary[js.Dictionary[js.Any]]

  @JSExport
  def programRepr (src: String) = {
    val ast = culang.Parser.parse(src)
    val program = culang.Compiler(ast).program
    program.toString
  }

  @JSExport
  def run (src: String) = {
    try {
      val ast = culang.Parser.parse(src)
      val program = culang.Compiler(ast).program

      val interp = new Interpreter(program)
      interp.runMain()

    } catch {
      case err: culang.ParseError => Terminal.println(err.getMessage)
      case err: culang.CompileError => Terminal.println(err.getMessage)
      case err: Throwable =>
        err.printStackTrace(TerminalStream.printWriter)
        throw err
    }
  }
}