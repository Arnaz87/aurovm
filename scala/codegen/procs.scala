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
        case None => if (prog.globals contains k)
          { Some(RegVar(RegId(prog.globals(k).name))) }
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
    val nm = const.name
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
            code += Inst.Get(tmp.name, obj.name, f.name)
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
          code += Inst.Set(func, argnm, arg.name)
        }
        code += Inst.Call(func)
        field match {
          case Some(f) =>
            val tmp = newTemp()
            code += Inst.Get(tmp.name, func, f)
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
            code += Inst.Cpy(l.name, v.name)
          case FieldVar(obj, f) =>
            code += Inst.Set(obj.name, f.name, v.name)
        }
        RegId("$nil")
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
      /*
      case DeclareGlobal(nm) =>
        val reg = st.newReg(nm)
        st.scopes.bottom(nm) = reg
        reg
      case Assign(nm, _r) =>
        val l = st.scopes(nm)
        val r = %%(st, _r)
        st.code += Inst.Cpy(l.name, r.name)
        l
      // Este call por ahora funciona, pero es incorrecto.
      // Las funciones no necesariamente van arecibir argumentos nombrados
      // con letras desde la 'a' ni van a devolver un solo resultado 'r'.
      case Call(func, args) =>
        var aChar = 'a'
        st.code += Inst.New(func)
        args.foreach{ _arg =>
          val arg = %%(st, _arg)
          st.code += Inst.Set(func, aChar.toString, arg.name)
          aChar = (aChar + 1).toChar
        }
        st.code += Inst.Call(func)
        val reg = st.newReg("r")
        st.code += Inst.Get(reg.name, func, "r")
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
        st.code += Inst.Ifn($else, $cond.name)
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