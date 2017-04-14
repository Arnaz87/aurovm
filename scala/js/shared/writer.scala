package arnaud.cobre.backend.js

import scala.collection.mutable.Buffer

object Macros {
  val prim = "cobre\u001fprim"
  val str = "cobre\u001fstring"

  def binop (op: String)(args: Seq[String]) =
    if (args.size != 2) { throw new Exception(
      s"Binop Macro $op expects exactly 2 arguments, found (${args mkString ", "})"
    )} else s"(${args(0)} $op ${args(1)})"

  val map = Map[(String, String), Seq[String]=>String](
    (prim, "iadd") -> binop("+"),
    (prim, "isub") -> binop("-"),
    (prim, "imul") -> binop("*"),
    (prim, "ieq") -> binop("=="),
    (prim, "igt") -> binop(">"),
    (prim, "igte") -> binop(">="),
    (prim, "ilt") -> binop("<"),
    (prim, "ilte") -> binop("<="),
    (str, "concat") -> binop("+")
  )

  def apply(mod: String, rut: String) = map.get((mod, rut))
}

class Writer (program: Program) {
  val lines = Buffer[String]()
  var identation = 0
  def line(str: String) = lines += (("  "*identation) + str)
  def ident () { identation += 1 }
  def dedent () { identation -= 1 }

  def quote (str: String) = "\"" + str.
    replace("\\", "\\\\").
    replace("\"", "\\\"").
    replace("\n", "\\n").
    replace("\t", "\\t").
    replace("\u001f", "\\x1f") + "\""

  val imports: Map[(String, String), String] = (program.rutines flatMap {
    case ImportRutine(mod, name)
      if Macros(mod, name).isEmpty => {
      var endname = ((mod split "\u001f") :+ name) mkString "$"
      line(s"var $endname = $$modules[${quote(mod)}][${quote(name)}];")
      Some(((mod, name), endname))
    }
    case _ => None
  }).toMap

  def writeRutine (rutine: RutineDef) {

    def regName (r: Register) = {
      r.name match {
        case Some(nm) => nm
        case None => "$" + Integer.toString(r.index, 36)
      }
    }

    def repr (expr: Expr): String = expr match {
      case Expr.Cns(Constant.Num(num)) => num.toString
      case Expr.Cns(Constant.Str(str)) => quote(str)
      case Expr.Var(reg) => regName(reg)
      case Expr.Call(rut, rs) => callRepr(rut, rs)
      case Expr.Not(expr) => s"!${repr(expr)}"
      case Expr.True => "true"
      //case _ => s"null /*$expr*/"
    }

    def callRepr (rut: Rutine, rs: Seq[Expr]): String = {
      val args = rs map repr
      val argstr = args mkString ", "
      rut match {
        case ImportRutine(mod, name) =>
          Macros(mod, name) match {
            case Some(func) => func(args)
            case None =>
              val fname = imports((mod, name))
              s"$fname($argstr)"
          }
        case rut: RutineDef => s"${rut.name.get}($argstr)"
      }
    }

    val args = rutine.vars.ins map regName
    line(s"function ${rutine.name.get} (${args mkString ", "}) {")
    ident()

    if (rutine.stmts exists (_.isInstanceOf[Stmt.MultiCall])) {
      line("var $result;")
    }

    val temps = ((rutine.vars.set filter {_.name.isEmpty}) ++ rutine.vars.outs) map regName
    if (!temps.isEmpty)
      line(s"var ${temps mkString ","};")

    val vars = rutine.vars.set filter {!_.name.isEmpty} map regName
    if (!vars.isEmpty)
      line(s"var ${vars mkString ", "};")

    val endLine = {
      val outs = rutine.vars.outs map regName
      outs.size match {
        case 0 => "return;"
        case 1 => s"return ${outs.head};"
        case _ => s"return [${outs mkString ", "}];"
      }
    }

    def writeStmts (stmts: Seq[Stmt]) {
      stmts foreach {
        case Stmt.End => line(endLine)
        case Stmt.Assign(a, expr) =>
          line(s"${regName(a)} = ${repr(expr)};" )
        case Stmt.MultiCall(rut, ls, rs) =>
          line(s"$$result = ${callRepr(rut, rs)};")
          for ((nm, i) <- (ls map regName).zipWithIndex)
            line(s"$nm = $$result[$i];")
        case Stmt.Call(rut, rs) =>
          line(callRepr(rut, rs) + ";")
        case Stmt.While(cond, stmts) =>
          line(s"while (${repr(cond)}) {")
          ident()
          writeStmts(stmts)
          dedent()
          line("}")
        case Stmt.DoWhile(cond, stmts) =>
          line("do {")
          ident()
          writeStmts(stmts)
          dedent()
          line(s"} while (${repr(cond)})")
        case Stmt.If(cond, body, ebody) =>
          line(s"if (${repr(cond)}) {")
          ident()
          writeStmts(body)
          dedent()
          if (!ebody.isEmpty) {
            line("} else {")
            ident()
            writeStmts(ebody)
            dedent()
          }
          line("}")
        case Stmt.Break(cond) =>
          line(s"if (${repr(cond)}) break;")
        case Stmt.Continue(cond) =>
          line(s"if (${repr(cond)}) continue;")

        /*case Stmt.Lbl(lbl) =>
          line(s"// lbl: $lbl")
        case Stmt.Jmp(lbl, expr) =>
          line(s"// goto: $lbl if ${repr(expr)}")
        case stmt => line("// " + stmt.toString)*/
      }
    }

    writeStmts(rutine.stmts)

    dedent()
    line("}")
  }

  def write () {
    program.rutines foreach {
      case r: RutineDef => writeRutine(r)
      case _ =>
    }
  }
}