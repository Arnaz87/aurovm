package arnaud.myvm.lua

import arnaud.cobre.format
import collection.mutable

class Compiler {
  def error(msg: String): Nothing = throw new Exception(msg)

  val program = new format.Program()

  lazy val core = program.Module("cobre\u001fcore", Nil)
  lazy val prim = program.Module("cobre\u001fprim", Nil)
  lazy val dyn = program.Module("cobre\u001fdynamic", Nil)
  lazy val strmod = program.Module("cobre\u001fstring", Nil)

  lazy val binType = core.Type("bin")
  lazy val intType = prim.Type("int")
  lazy val boolType = core.Type("bool")
  lazy val strType = prim.Type("int")

  lazy val makeint = prim.Rutine("bintoi", Array(binType), Array(intType))
  lazy val makestr = strmod.Rutine("bintos", Array(binType), Array(strType))

  lazy val any = dyn.Type("any")

  object lua {
    val luamod = program.Module("lua", Nil)

    lazy val list = luamod.Type("list")

    lazy val call = luamod.Rutine("call", Array(any, list), Array(any))
    lazy val print = luamod.Rutine("print", Array(list), Array(list))
    lazy val bool = luamod.Rutine("bool", Array(any), Array(boolType))

    lazy val new_list = luamod.Rutine("new_list", Nil, Array(list))
    lazy val list_add = luamod.Rutine("list_add", Array(list, any), Nil)
    lazy val list_get = luamod.Rutine("list_add", Array(list), List(any))

    lazy val eq  = luamod.Rutine("eq" , Array(any, any), Array(any))
    lazy val gt  = luamod.Rutine("gt" , Array(any, any), Array(any))
    lazy val gte = luamod.Rutine("gte", Array(any, any), Array(any))
    lazy val add = luamod.Rutine("add", Array(any, any), Array(any))
    lazy val sub = luamod.Rutine("sub", Array(any, any), Array(any))
    lazy val append = luamod.Rutine("append", Array(any, any), Array(any))

    lazy val ftype = {
      val l_const = program.TypeConstant(list)
      val l_arr = program.ArrayConstant(Array(l_const))
      val fmod = program.Module("cobre.rutine", Array(l_arr, l_arr))
      fmod.Type("rutine")
    }
  }

  val funmap = mutable.Map[String, program.Rutine](
    "print" -> lua.print
  )

  object funconsts {
    val map = mutable.Map[String, program.Constant]()

    def apply (k: String) = map.get(k) match {
      case None =>
        funmap.get(k) match {
          case None => None
          case Some(f) =>
            val const = program.RutineConstant(f)
            map(k) = const
            Some(const)
        }
      case somereg => somereg
    }
  }

  val main = program.Rutine("main")

  import main.Reg;

  class Scope () {
    val map = mutable.Map[String, Reg]()

    def global = this

    def get (k: String) = map.get(k) match {
      case None =>
        funconsts(k) match {
          case Some(const) =>
            val reg = main.Reg(lua.ftype)
            map(k) = reg
            main.Cns(reg, const)
            Some(reg)
          case None => None
        }
      case somereg => somereg
    }

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

  def make_call (fx: Ast.expr, args: Seq[Ast.expr], scope: Scope) = {
    val list = main.Reg(lua.list)
    main.Call(lua.new_list, Array(list), Nil)
    for (_arg <- args) {
      val arg = %%(_arg, scope)
      main.Call(lua.list_add, Nil, Array(list, arg))
    }
    val result = main.Reg(lua.list)
    fx match {
      case Ast.Var(nm) if funmap.contains(nm) =>
        val f = funmap(nm)
        main.Call(f, Array(result), Array(list))
      case _ =>
        val f = %%(fx, scope)
        main.Call(lua.call, Array(result), Array(f, list))
    }
    result
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
      }
      main.Call(f, List(result), Array(l, r))
      result
    case Ast.Call(fx, args) => make_call(fx, args, scope)
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
    case Ast.Call(fx, args) => make_call(fx, args, scope)
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
