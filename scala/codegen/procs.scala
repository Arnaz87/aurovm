package arnaud.myvm.codegen

import collection.mutable.{ArrayBuffer, Buffer, Map, Set, Stack}
import arnaud.myvm.codegen.{Nodes => ND}

class ProcState (val prog: ProgState) extends Signature {
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
  val inregs = new ArrayBuffer[String](4)
  val outregs = new ArrayBuffer[String](4)

  val regs: Buffer[Reg] = new ArrayBuffer()

  def ins = inregs map {
    regname => (regs find {
      reg => reg.nm == regname
    }).get.tp
  }

  def outs = outregs map {
    regname => (regs find {
      reg => reg.nm == regname
    }).get.tp
  }

  val varCounts: Map[String, Int] = Map()
  var labelCount: Int = 0

  def regName(inm: String): String = {
    val count = varCounts get inm match {
      case Some(cnt) => { varCounts(inm) = cnt+1; cnt }
      case None => { varCounts(inm) = 1; 0 }
    }
    inm + "$" + count
  }

  def newReg(inm: String, tp: String): RegId = {
    val nm = regName(inm)
    regs += Reg(nm, tp)
    RegId(nm)
  }

  def newTemp(tp: String): RegId = newReg("$temp", tp)

  def getLabel(): String = {
    labelCount += 1
    "lbl_" + labelCount
  }

  def addConstant (v: Any): RegId = {
    val const = prog.addConstant(v)
    val nm = const.name
    regs += Reg(nm, "")
    code += Inst.Cns(nm, nm)
    RegId(nm)
  }

  def declGlobal (nm: String) {
    prog.globals += nm
  }

  def setParams (params: Seq[(String, String)]) {
    params foreach {case (p, tp) =>
      val reg = newReg(p, tp)
      this.inregs += reg.name
      scopes(p) = RegVar(reg)
    }
  }

  def setReturns (params: Seq[(String, String)]) {
    params foreach {case (p, tp) =>
      val reg = newReg(p, tp)
      this.outregs += reg.name
      scopes(p) = RegVar(reg)
    }
  }

  def %% (nd: Node, n: Int): RegId = {
    import Nodes._
    nd match {
      case Call(func, gs) =>
        val temps = (1 to n) map {_ => newTemp("")}
        val tnames = temps map (_.name)
        val args = (gs map %%) map (_.name)
        code += Inst.Call(func, tnames, args)
        RegId(tnames)
      case _ if n==1 || n==0 => %%(nd)
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
          case FieldVar(obj, f) => ???
            /*val tmp = newTemp()
            code += Inst.Get(tmp.name, obj.name, f.name)
            tmp*/
        }
      case Scope(block) =>
        scopes.push()
        %%(block)
      case Block(nodes) =>
        nodes.foreach(%%(_, 0))
        RegId()
      case Declare(nm, tp) => // (nm, tp)
        val reg = newReg(nm, tp)
        scopes(nm) = RegVar(reg)
        reg
      case DeclareGlobal(nm) =>
        prog.globals += nm
        RegId()
      case Undeclared(nm, nd) =>
        scopes get nm match {
          case None => %%(nd)
          case _ => RegId()
        }
      case Assign(nm, vnd) =>
        val v = %%(vnd, 1)
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
        RegId()
      case Return =>
        code += Inst.End
        RegId()
      case Nil => RegId()
      case _: Call => %%(nd, 1)
    }
  }

  // Algunos registros quedan sin tipo después de la generación de código,
  // hay que inferir sus tipos basados en las instrucciones con las que
  // interactúan
  def fixTypes () {

    var lastSize = 0
    var unsolved = regs filter {_.tp == ""}

    do {
      lastSize = unsolved.size

      unsolved = unsolved filter { reg =>
        import Inst._
        val iter = code.iterator
        var cont = true

        def setType (tp: String) {
          reg.tp = tp
          cont = false
        }

        def typeFrom(otherName: String) {
          // Si una instrucción usó este registro, debe existir
          val other = regs.find(_.nm == otherName).get
          if (other.tp != "") { setType(other.tp) }
        }

        while (cont && iter.hasNext) {
          iter.next match {
            case Cpy(reg.nm, other) => typeFrom(other)
            case Cpy(other, reg.nm) => typeFrom(other)
            case Call(func, outs, ins)
              if outs contains reg.nm =>
              val index = outs indexOf reg.nm
              prog.findProc(func) match {
                case None =>
                case Some(proc) =>
                  setType(proc.outs(index))
              }
            case Call(func, outs, ins)
              if ins contains reg.nm =>
              val index = ins indexOf reg.nm
              prog.findProc(func) match {
                case None =>
                case Some(proc) =>
                  setType(proc.ins(index))
              }
            case _ =>
          }
        }

        // Esta es la última expresion de filter
        // Si sigue sin tipo devolver verdadero, así sigue en la lista
        // y se puede intentar de nuevo en la siguiente iteración.
        (reg.tp == "")
      }

    // Cada iteración se revisa la condición. Si el tamaño de la lista
    // cambio estamos avanzando, pero si no estamos atorados.
    } while (lastSize != unsolved.size)
  }

}