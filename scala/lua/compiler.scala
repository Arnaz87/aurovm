package arnaud.myvm.lua

import arnaud.cobre.format
import collection.mutable

class Compiler {
  def error(msg: String): Nothing = throw new Exception(msg)

  val program = new format.Program()

  val core = program.Module("cobre\u001fcore", Nil)
  val prim = program.Module("cobre\u001fprim", Nil)
  val dyn = program.Module("cobre\u001fdynamic", Nil)
  val strmod = program.Module("cobre\u001fstring", Nil)

  val binType = core.Type("bin")
  val intType = prim.Type("int")
  val boolType = core.Type("bool")
  val strType = prim.Type("int")

  val makeint = prim.Rutine("bintoi", Array(binType), Array(intType))
  val makestr = strmod.Rutine("bintos", Array(binType), Array(strType))

  val any = dyn.Type("any")
  val varargs = dyn.Type("varargs")

  object lua {
    val luamod = program.Module("lua", Nil)
    val call = luamod.Rutine("call", Array(varargs), Array(any))
    val print = luamod.Rutine("print", Array(any), Nil)
    val bool = luamod.Rutine("bool", Array(any), Array(boolType))

    val eq  = luamod.Rutine("eq" , Array(any, any), Array(any))
    val gt  = luamod.Rutine("gt" , Array(any, any), Array(any))
    val gte = luamod.Rutine("gte", Array(any, any), Array(any))
    val add = luamod.Rutine("add", Array(any, any), Array(any))
    val sub = luamod.Rutine("sub", Array(any, any), Array(any))
    val append = luamod.Rutine("append", Array(any, any), Array(any))
  }

  val main = program.Rutine("main")

  import main.Reg;

  class Scope () {
    val map = mutable.Map[String, Reg]()

    def global = this

    def get (k: String) = map.get(k)

    class SubScope(parent: Scope) extends Scope {
      override def get (k: String) = this.map get k match {
        case None => parent.get(k)
        case somereg => somereg
      }
      override def global = parent.global
    }

    def apply (k: String) = get(k) match {
      case Some(reg) => reg
      case None =>
        val reg = main.Reg(any)
        global.map(k) = reg; reg
    }

    // Lo que hubiere antes en este scope se pierde.
    def local (k: String) = {
      val reg = main.Reg(any)
      map(k) = reg; reg
    }

    def Scope = new SubScope(this)
  }

  def %% (node: Ast.expr, scope: Scope): Reg = { node match {
    case Ast.Num(dbl) =>
      val n = dbl.asInstanceOf[Int]
      val bytes = new Array[Int](4)
      bytes(0) = (n >> 24) & 0xFF
      bytes(1) = (n >> 16) & 0xFF
      bytes(2) = (n >> 8 ) & 0xFF
      bytes(3) = (n >> 0 ) & 0xFF
      val bin = program.BinConstant(bytes)
      val const = program.CallConstant(makeint, Array(bin))

      val reg = main.Reg(intType)
      main.Cns(reg, const)
      reg
    case Ast.Str(str) =>
      val bytes = str.getBytes("UTF-8")
      val bin = program.BinConstant(
        bytes map (_.asInstanceOf[Int])
      )
      val const = program.CallConstant(makestr, Array(bin))

      val reg = main.Reg(strType)
      main.Cns(reg, const)
      reg
    case Ast.Var(name) => scope(name)
    case Ast.Binop(_l, _r, op) =>
      val result = main.Reg(any)
      val l = %%(_l, scope)
      val r = %%(_r, scope)
      val f = op match {
        case Ast.App => lua.append
        case Ast.Add => lua.add
        case Ast.Sub => lua.sub
        case Ast.Eq  => lua.eq
        case Ast.Gt  => lua.gt
        case Ast.Gte => lua.gte
        case _ => error(s"Unsupported operation: $op")
      }
      main.Call(f, List(result), Array(l, r))
      result
    case _ => ???
  } }

  def %% (node: Ast.stmt, scope: Scope) { node match {
    case Ast.Assign(ls, rs) =>
      ls.head match {
        case Ast.Var(nm) =>
          val reg = scope(nm)
          val value = %%(rs.head, scope)
          main.Cpy(reg, value)
        case _:Ast.Field =>
          error("Field assignment not yet supported")
      }
    case Ast.Call(f, vs) =>
      f match {
        case Ast.Var("print") =>
          val arg = %%(vs.head, scope)
          main.Call(lua.print, Nil, List(arg))
        case _ => error("Arbitrary function call not yet supported")
      }
    case Ast.If(ifs, els) =>
      if (ifs.isEmpty) error(throw new Exception("Empty if list"))
      val $end  = main.Lbl
      for (Ast.IfBlock(cond, body) <- ifs) {
        val $else = main.Lbl

        val $cond = %%(cond, scope)
        main.Ifn($else, $cond)

        %%(body, scope)
        main.Jmp($end)

        main.Ilbl($else)
      }
      %%(els, scope)
      main.Ilbl($end)
    case Ast.While(cond, body) =>
      val $start = main.Lbl
      val $end = main.Lbl

      main.Ilbl($start)
      val $cond = %%(cond, scope)
      main.Ifn($end, $cond)

      %%(body, scope)

      main.Jmp($start)
      main.Ilbl($end)
  } }

  def %% (block: Ast.Block, _scope: Scope = new Scope) {
    val scope = _scope.Scope
    for (stmt <- block.stmts) {
      %%(stmt, scope)
    }
  }
}
