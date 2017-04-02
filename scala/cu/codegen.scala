package arnaud.culang
import scala.collection.mutable.{ArrayBuffer, Map}
//import arnaud.myvm.codegen.{Nodes => CG, Node => CGNode}
import arnaud.myvm.codegen.{Program => CGProgram}

class CodeGen {
  import Ast._

  val program = new CGProgram()

  val modules = Map[String, program.Module]()
  val types = Map[String, program.Type]()
  val rutines = Map[String, program.Rutine]()

  val rutine_defs = Map[String, Scope]()

  val prelude: program.Module = program.Module("Prelude", Nil)

  val binaryType = prelude.Type("Binary")
  val intType = prelude.Type("Int")
  val strType = prelude.Type("String")
  val boolType = prelude.Type("Bool")
  types("String") = strType
  types("Int") = intType
  types("Bool") = boolType

  val makeint = prelude.Rutine("makeint",
    Array(binaryType),
    Array(intType)
  )
  val makestr = prelude.Rutine("makestr",
    Array(binaryType),
    Array(strType)
  )

  val iadd = prelude.Rutine("iadd",
    Array(intType, intType), Array(intType)
  )

  val isub = prelude.Rutine("isub",
    Array(intType, intType), Array(intType)
  )

  val igt = prelude.Rutine("gt",
    Array(intType, intType), Array(boolType)
  )

  val ieq = prelude.Rutine("eq",
    Array(intType, intType), Array(boolType)
  )

  val concat = prelude.Rutine("concat",
    Array(strType, strType), Array(strType)
  )

  rutines("itos") = prelude.Rutine("itos",
    Array(types("Int")),
    Array(types("String"))
  )
  rutines("print") = prelude.Rutine("print",
    Array(types("String")),
    Nil
  )

  class Scope (val rutine: program.RutineDef) {
    type Reg = rutine.Reg

    val map = Map[String, Reg]()

    val outs = ArrayBuffer[Reg]()

    def apply (k: String) = map(k)
    def update (k: String, v: Reg) = map(k) = v

    class SubScope(parent: Scope) extends Scope(rutine) {
      override def apply (k: String) = this.map get k match {
        case Some(v) => v
        case None => parent(k).asInstanceOf[this.rutine.Reg]
      }
    }

    def Scope = new SubScope(this)
  }

  def genSyms (stmt: Toplevel) { stmt match {
    case Import(modname) => 
    case Proc(Id(name), params, rets, body) =>
      val scope = new Scope(program.Rutine(name))
      for ( (Id(ident), Type(tp)) <- params ) {
        scope(ident) = scope.rutine.InReg(types(tp))
      }
      for (Type(tp) <- rets) {
        scope.outs += scope.rutine.OutReg(types(tp))
      }
      rutine_defs(name) = scope
      rutines(name) = scope.rutine
  } }

  def %% (node: Expr, scope: Scope): scope.rutine.Reg = node match {
    case Var(Id(nm)) => scope(nm)
    case Num(dbl) =>
      val n = dbl.asInstanceOf[Int]
      val bytes = new Array[Int](4)
      bytes(0) = (n >> 24) & 0xFF
      bytes(1) = (n >> 16) & 0xFF
      bytes(2) = (n >> 8 ) & 0xFF
      bytes(3) = (n >> 0 ) & 0xFF
      val bin = program.BinConstant(bytes)
      val const = program.CallConstant(makeint, Array(bin))

      val reg = scope.rutine.Reg(intType)
      scope.rutine.Cns(reg, const)
      reg
    case Str(str) =>
      val bytes = str.getBytes("UTF-8")
      val bin = program.BinConstant(
        bytes map (_.asInstanceOf[Int])
      )
      val const = program.CallConstant(makestr, Array(bin))

      val reg = scope.rutine.Reg(strType)
      scope.rutine.Cns(reg, const)
      reg
    case Call(Id(fname), args) =>
      val rutine = rutines(fname)
      if (args.size != rutine.ins.size) throw new Exception(
        s"Expected ${rutine.ins.size} arguments, found ${args.size}"
      )
      val reg = scope.rutine.Reg(rutine.outs(0))

      scope.rutine.Call( rutine, Array(reg), args map (%%(_, scope)) )
      reg
    case Binop(op, _a, _b) =>
      val a = %%(_a, scope)
      val b = %%(_b, scope)
      val (rutine, rtp) = op match {
        case Add => 
          (a.t, b.t) match {
            case (`intType`, `intType`) => (iadd, intType)
            case (`strType`, `strType`) => (concat, strType)
          }
        case Sub => (isub, intType)
        case Gt  => (igt, boolType)
        case Eq  => (ieq, boolType)
      }
      val reg = scope.rutine.Reg(rtp)
      scope.rutine.Call(rutine, Array(reg), Array(a, b))
      reg
    //case _ => scope.rutine.Reg(types("Int"))
  }

  def %% (node: Stmt, scope: Scope) { node match {
    case Decl(Type(_tp), ps) =>
      val tp = types(_tp)
      for ( DeclPart(Id(nm), vl) <- ps ) {
        val reg = scope.rutine.Reg(tp)
        scope(nm) = reg
        vl match {
          case Some(expr) =>
            val result = %%(expr, scope)
            scope.rutine.Cpy(reg, result)
          case None =>
        }
      }
    case Call(Id(fname), args) =>
      val rutine = rutines(fname)
      if (args.size != rutine.ins.size) throw new Exception(
        s"Expected ${rutine.ins.size} arguments, found ${args.size}"
      )
      scope.rutine.Call( rutine, Nil, args map (%%(_, scope)) )
    case While(cond, Block(stmts)) =>
      val $start = scope.rutine.Lbl
      val $end = scope.rutine.Lbl

      scope.rutine.Ilbl($start)
      val $cond = %%(cond, scope)
      scope.rutine.Ifn($end, $cond)

      val scoped = scope.Scope
      for (stmt <- stmts) { %%(stmt, scoped) }

      scope.rutine.Jmp($start)
      scope.rutine.Ilbl($end)
    case If(cond, Block(stmts), orelse) =>
      val $else = scope.rutine.Lbl
      val $end  = scope.rutine.Lbl

      val $cond = %%(cond, scope)
      scope.rutine.Ifn($else, $cond)

      val scoped = scope.Scope
      for (stmt <- stmts) { %%(stmt, scoped) }
      scope.rutine.Jmp($end)
      scope.rutine.Ilbl($else)
      orelse match {
        case Some(Block(stmts)) =>
          val scoped = scope.Scope
          for (stmt <- stmts) { %%(stmt, scoped) }
        case None =>
      }
      scope.rutine.Ilbl($end)
    case Assign(Id(nm), expr) =>
      val reg = scope(nm)
      val result = %%(expr, scope)
      scope.rutine.Cpy(reg, result)
    case Return(exprs) =>
      if (exprs.size != scope.outs.size) throw new Exception(
        s"Expected ${scope.outs.size} return values, found ${exprs.size}"
      )
      for ( (reg, expr) <- scope.outs zip exprs ) {
        val result = %%(expr, scope)
        scope.rutine.Cpy(reg, result)
      }
      scope.rutine.End()
    //case _ =>
  } }

  def %% (node: Toplevel) { node match {
    case Import(modname) => 
    case Proc(Id(name), params, rets, body) =>
      val scope = rutine_defs(name)
      //body.stmts foreach println
      for (stmt <- body.stmts) { %%(stmt, scope) }
      scope.rutine.End()
  } }

  def binary: Seq[Int] = program.compileBinary()
}

object CodeGen {
  def apply (prg: Ast.Program): CodeGen = {
    val codegen = new CodeGen

    prg.stmts foreach (codegen.genSyms(_))

    for (stmt <- prg.stmts) {
      codegen %% stmt
    }
    //prg.stmts foreach codegen.genSyms
    //CG.Block(CG.Import("Prelude") +: prg.stmts.map(codegen.gen _))
    return codegen
  }
}