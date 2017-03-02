package arnaud.myvm.codegen

import collection.mutable.{ArrayBuffer, Buffer, Map, Set, Stack}
import arnaud.myvm.codegen.{Nodes => ND}

class ProcState (val prog: ProgState) {
  object scopes {
    type Scope = Map[String, VarInfo]

    val stack: Stack[Scope] = Stack(Map())
    def push() { stack.push(Map()) }
    def pop() { stack.pop() }
    def get (k: String): Option[VarInfo] = {
      stack find {_.contains(k)} map {_ apply k} match {
        case Some(v) => Some(v)
        case None =>
          if (prog.globals contains k)
            Some(FieldVar(RegId("SELF"), RegId(k)))
          else None
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
  val params = new ArrayBuffer[String](4)
  val returns = new ArrayBuffer[String](4)

  val regs: Buffer[(String, String)] = new ArrayBuffer()

  val varCounts: Map[String, Int] = Map()
  var labelCount: Int = 0

  def regName(inm: String): String = {
    val count = varCounts get inm match {
      case Some(cnt) => { varCounts(inm) = cnt+1; cnt }
      case None => { varCounts(inm) = 1; 0 }
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
    val nm = const.name
    regs += ((nm, "Any"))
    code += Inst.Cns(nm, nm)
    RegId(nm)
  }

  def declGlobal (nm: String) {
    prog.globals += nm
  }

  def setParams (params: Seq[String]) {
    params foreach {p =>
      val reg = newReg(p)
      this.params += reg.name
      scopes(p) = RegVar(reg)
    }
  }

  def setReturns (params: Seq[String]) {
    params foreach {p =>
      val reg = newReg(p)
      this.returns += reg.name
      scopes(p) = RegVar(reg)
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
            code += Inst.Get(tmp.name, obj.name, f.name)
            tmp
        }
      case Scope(block) =>
        scopes.push()
        %%(block)
      case Block(nodes) =>
        nodes.foreach(%% _)
        RegId("$nil")
      case Call(func, gs) =>
        // TODO: Aquí se asume que todas las funciones devuelven exactamente
        // un resultado, lo cual, por supuesto, no es cierto.
        val tmp = newTemp()
        val args = tmp +: (gs map %%)
        code += Inst.Call(func, args map (_.name))
        tmp
      case Declare(nm) => // (nm, tp)
        val reg = newReg(nm)
        scopes(nm) = RegVar(reg)
        reg
      case DeclareGlobal(nm) =>
        prog.globals += nm
        RegId("$nil")
      case Undeclared(nm, nd) =>
        scopes get nm match {
          case None => %%(nd)
          case _ => RegId("$nil")
        }
      case Assign(nm, vnd) =>
        val v = %%(vnd)
        scopes(nm) match {
          case RegVar(l) =>
            code += Inst.Cpy(l.name, v.name)
            l
          case FieldVar(obj, f) =>
            code += Inst.Set(obj.name, f.name, v.name)
            obj
        }
      case While(cond, body) =>
        val $start = getLabel()
        val $end = getLabel()
        code += Inst.Lbl($start)
        val $cond = %%(cond)
        code += Inst.Ifn($end, $cond.name)
        val $body = %%(body)
        code += Inst.Jmp($start)
        code += Inst.Lbl($end)
        $body
      case If(cond, body, orelse) =>
        val $else = getLabel()
        val $end  = getLabel()
        val $cond = %%(cond)
        code += Inst.Ifn($else, $cond.name)
        %%(body)
        code += Inst.Jmp($end)
        code += Inst.Lbl($else)
        %%(orelse)
        code += Inst.Lbl($end)
        RegId("$nil")
      case Return =>
        code += Inst.End
        RegId("$nil")
      case Nil => RegId("$nil")
      //case _ => RegId("$nil")
    }
  }
}