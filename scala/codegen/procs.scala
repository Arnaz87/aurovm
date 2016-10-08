package arnaud.myvm.codegen

import collection.mutable.{ArrayBuffer, Buffer, Map, Set, Stack}
import arnaud.myvm.codegen.{Nodes => ND}

case class RegId(realname: String)

sealed abstract class VarInfo
case class RegVar(val reg: RegId) extends VarInfo
case class FieldVar(val obj: RegId, val field: RegId) extends VarInfo

class ProcState (val prog: ProgState) {
  object scopes {
    type Scope = Map[String, VarInfo]

    val stack: Stack[Scope] = Stack(Map())
    def push() { stack.push(Map()) }
    def pop() { stack.pop() }
    def get (k: String): Option[VarInfo] = {
      stack find {_.contains(k)} map {_ apply k} match {
        case Some(v) => Some(v)
        case None => if (prog.globals contains k)
          { Some(RegVar(RegId(prog.globals(k).realname))) }
          else { None }
      }
    }
    def apply(k: String): VarInfo =
      get(k) match {
        case Some(reg) => reg
        case None => throw new java.util.NoSuchElementException(s"Reg $k not found")
      }
    def update(k: String, v: VarInfo) = { stack.top(k) = v; v }
  }

  val code: Buffer[Inst] = new ArrayBuffer[Inst](64)
  val params = new ArrayBuffer[(String, String)](4)

  val regs: Buffer[(String, String)] = new ArrayBuffer()

  val varCounts: Map[String, Int] = Map()
  var labelCount: Int = 0

  def regName(inm: String): String = {
    val count = varCounts get inm match {
      case Some(cnt) => { varCounts(inm) = cnt+1; cnt }
      case None => { varCounts(inm) = 0; 1 }
    }
    inm + "$" + count
  }

  def newReg(inm: String): RegId = {
    val nm = regName(inm)
    regs += ((nm, "Any"))
    RegId(nm)
  }

  def newTemp(): RegId = newReg("$temp")

  def getLabel(): String = {
    labelCount += 1
    "lbl_" + labelCount
  }

  def addConstant (v: Any): RegId = {
    val const = prog.addConstant(v)
    val nm = const.realname
    regs += ((nm, "Any"))
    code += Inst.Get(nm, "SELF", nm)
    RegId(nm)
  }

  def setParams (params: Seq[String]) {
    params foreach {p =>
      val r = FieldVar(RegId("ARGS"), RegId(p))
      scopes(p) = r
      this.params += ((p, "Any"))
    }
  }
  
  def %% (nd: Node): RegId = {
    import Nodes._
    nd match {
      case Num(n) => addConstant(n)
      case Str(s) => addConstant(s)
      case Bool(b) => addConstant(b)
      case Var(nm) =>
        scopes(nm) match {
          case RegVar(reg) => reg
          case FieldVar(obj, f) =>
            val tmp = newTemp()
            code += Inst.Get(tmp.realname, obj.realname, f.realname)
            tmp
        }
      case Scope(block) =>
        scopes.push()
        %%(block)
      case Block(nodes) =>
        nodes.foreach(%% _)
        RegId("$nil")
      case NmCall(func, args, field) =>
        regs += ((func, func))
        code += Inst.New(func)
        args.foreach{ case (argnm, _arg) =>
          val arg = %%(_arg)
          code += Inst.Set(func, argnm, arg.realname)
        }
        code += Inst.Call(func)
        field match {
          case Some(f) =>
            val tmp = newTemp()
            code += Inst.Get(tmp.realname, func, f)
            tmp
          case None => RegId("$nil")
        }
      case Declare(nm) => // (nm, tp)
        val reg = newReg(nm)
        scopes(nm) = RegVar(reg)
        reg
      case Assign(nm, vnd) =>
        val v = %%(vnd)
        scopes(nm) match {
          case RegVar(l) =>
            code += Inst.Cpy(l.realname, v.realname)
          case FieldVar(obj, f) =>
            code += Inst.Set(obj.realname, f.realname, v.realname)
        }
        RegId("$nil")
      case While(cond, body) =>
        val $start = getLabel()
        val $end = getLabel()
        code += Inst.Lbl($start)
        val $cond = %%(cond)
        code += Inst.Ifn($end, $cond.realname)
        val $body = %%(body)
        code += Inst.Jmp($start)
        code += Inst.Lbl($end)
        $body
      /*
      case DeclareGlobal(nm) =>
        val reg = st.newReg(nm)
        st.scopes.bottom(nm) = reg
        reg
      case Assign(nm, _r) =>
        val l = st.scopes(nm)
        val r = %%(st, _r)
        st.code += Inst.Cpy(l.realname, r.realname)
        l
      // Este call por ahora funciona, pero es incorrecto.
      // Las funciones no necesariamente van arecibir argumentos nombrados
      // con letras desde la 'a' ni van a devolver un solo resultado 'r'.
      case Call(func, args) =>
        var aChar = 'a'
        st.code += Inst.New(func)
        args.foreach{ _arg =>
          val arg = %%(st, _arg)
          st.code += Inst.Set(func, aChar.toString, arg.realname)
          aChar = (aChar + 1).toChar
        }
        st.code += Inst.Call(func)
        val reg = st.newReg("r")
        st.code += Inst.Get(reg.realname, func, "r")
        reg
      case Undeclared(nm, node) =>
        st.scopes %% nm match {
          case None => %%(st, node)
          case _ => RegInfo.nil
        }
      case If(cond, body, orelse) =>
        val $else = st.getLabel()
        val $end  = st.getLabel()
        val $cond = %%(st, cond)
        st.code += Inst.Ifn($else, $cond.realname)
        %%(st, body)
        st.code += Inst.Jmp($end)
        st.code += Inst.Lbl($else)
        %%(st, orelse)
        st.code += Inst.Lbl($end)
        RegInfo.nil
      //case _ => RegInfo.nil
      */
      case _ => RegId("$nil")
    }
  }
}

class ProgState () {

  val imports: Map[String, (String, String)] = Map()
  val procs: Map[String, ProcState] = Map()

  val constants: Map[String, Any] = Map()
  var constantCount: Int = 0
  def addConstant(value: Any): RegInfo = {
    constantCount += 1
    val nm = "$const$" + constantCount
    constants(nm) = value
    new RegInfo(nm)
  }

  val globals: Map[String, RegInfo] = Map()

  def %% (tp: Node) {
    tp match {
      case ND.TypeSet(name, vl) =>
        vl match {
          case ND.Import(module, field) =>
            imports(name) = (module, field)
          case ND.Proc(params, body) =>
            val proc = new ProcState(this)
            proc.setParams(params)
            procs(name) = proc
            proc %% body
          // case _ => THROW_EXCEPTION
        }
      case ND.Block(nds) =>
        nds foreach (%% _)
      // case _ => THROW_EXCEPTION
    }
  }

  def compile(): arnaud.sexpr.Node = {
    import arnaud.sexpr._
    import arnaud.sexpr.Implicits._
    type Node = arnaud.sexpr.Node

    def NBuf(i: Int = 32): Buffer[Node] = new ArrayBuffer[Node](i)

    val mods: Set[String] = Set()
    val modules: Buffer[Node] = new ArrayBuffer[Node](8)
    val imported: Buffer[Node] = new ArrayBuffer[Node](32)
    val procnd: Buffer[Node] = new ArrayBuffer[Node](16)
    val structnd: Buffer[Node] = new ArrayBuffer[Node](32)
    val selfnd = NBuf(64)
    val constnd = NBuf(16)

    selfnd += "SELF"
    selfnd += ListNode("MAIN", "MAIN")


    imported += "Types"
    imports.foreach{ case(k,(m, f)) =>
      imported += ListNode(k, m, f)
      mods += m
    }

    modules += "Imports"
    mods.foreach{ modules += _ }

    structnd += "Structs"
    procnd += "Functions"
    procs.foreach{ case(name, procst) =>
      val regsnm = name + "$regs"
      val argsnm = name + "$args"

      val codeNode = new ArrayBuffer[Node](128)
      val regsNode = new ArrayBuffer[Node](128)
      regsNode += regsnm

      codeNode += "Code"
      procst.code.foreach{inst =>
        codeNode += (inst match {
          case Inst.Cpy(a, b) => ListNode("cpy", a, b)
          case Inst.Get(a, b, c) => ListNode("get", a, b, c)
          case Inst.Set(a, b, c) => ListNode("set", a, b, c)
          case Inst.New(a) => ListNode("new", a)
          case Inst.Call(a) => ListNode("call", a)

          case Inst.Lbl(l) => ListNode("lbl", l)
          case Inst.Jmp(l) => ListNode("jmp", l)
          case Inst.If (l, a) => ListNode("if" , l, a)
          case Inst.Ifn(l, a) => ListNode("ifn", l, a)
        })
      }
      codeNode += ListNode("end")

      regsNode += ListNode("SELF", "SELF")
      regsNode += ListNode("ARGS", argsnm)
      procst.regs.foreach{case (nm, tp) => regsNode += ListNode(nm, tp)}

      structnd += regsNode

      val argsNode = new ArrayBuffer[Node](8)
      argsNode += argsnm
      procst.params foreach {
        case (nm, tp) => argsNode += ListNode(nm, tp)
      }
      structnd += argsNode

      procnd += ListNode(name, argsnm, regsnm, codeNode)
    }

    constnd += "Constants"
    globals.foreach{ case(name, reg) => 
      selfnd += ListNode(reg.realname, "Any")
    }
    constants.foreach{ case (name, v) =>
      selfnd += ListNode(name, "Any")
      val tp = v match {
        case _:String => "str"
        case _:Float => "num"
        case _:Double => "num"
        case _:Int => "num"
      }
      constnd += ListNode(name, tp, v.toString)
    }

    structnd += selfnd

    ListNode( modules, imported, structnd, procnd, constnd )
  }
}