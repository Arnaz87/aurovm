package arnaud.cobre.backend.js

import scala.collection.mutable.{Map, Buffer}

abstract class Constant
object Constant {
  //case class Bin (bytes: Seq[Int]) extends Constant(_i)
  case class Str (str: String) extends Constant
  case class Num (num: Int) extends Constant
}

class Register (
  val index: Int,
  var name: Option[String] = None
) {
  override def toString () = s"Register(${name getOrElse s"#$index"})"
}

abstract class Expr
object Expr {
  case class Var(reg: Register) extends Expr
  case class Cns(cns: Constant) extends Expr
  case class Call(rut: Rutine, args: Seq[Expr]) extends Expr

  case class Not(expr: Expr) extends Expr
  case object True extends Expr
}

abstract class Stmt
object Stmt {
  case class Assign (reg: Register, expr: Expr) extends Stmt
  case class Call(rut: Rutine, args: Seq[Expr]) extends Stmt

  case class MultiCall(rut: Rutine, regs: Seq[Register], exprs: Seq[Expr]) extends Stmt

  case class Lbl (id: Int) extends Stmt
  case class Jmp (id: Int, expr: Expr) extends Stmt
  case object End extends Stmt

  case class Continue (cond: Expr) extends Stmt
  case class Break (cond: Expr) extends Stmt

  case class While (cond: Expr, stmts: Seq[Stmt]) extends Stmt
  case class DoWhile (cond: Expr, stmts: Seq[Stmt]) extends Stmt
  case class If(cond: Expr, body: Seq[Stmt], ebody: Seq[Stmt]) extends Stmt
}

abstract class Rutine
case class ImportRutine(module: String, name: String) extends Rutine
class RutineDef (
  var name: Option[String] = None
) extends Rutine {
  object vars {
    import scala.collection.mutable.Set

    var ins = Set[Register]()
    var outs = Set[Register]()

    var set = Set[Register]()

    def all = ins ++ outs ++ set

    def apply (key: String): Register = all.find(_.name == key).get
    def apply (i: Int): Register = all.find(_.index == i).get
    def += (reg: Register) = set += reg
  }

  var stmts = Buffer[Stmt]()
}

class Program (
  var rutines: Buffer[Rutine] = Buffer(),
  var constants: Buffer[Constant] = Buffer()
) {}

object Compiler {
  def compile (prg: arnaud.cobre.format.Program) = {
    val program = Builder.build(prg)

    program.rutines foreach {
      case rutine: RutineDef =>
        val t = new Transformer(rutine)
        t.applyAll()
      case _ =>
    }

    val writer = new Writer(program)
    writer.write()
    
    writer.lines mkString "\n"
  }
}