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

  val regs: Buffer[Reg] = new ArrayBuffer()

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
      this.params += reg.name
      scopes(p) = RegVar(reg)
    }
  }

  def setReturns (params: Seq[(String, String)]) {
    params foreach {case (p, tp) =>
      val reg = newReg(p, tp)
      this.returns += reg.name
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
        RegId("$nil")
      case Declare(nm, tp) => // (nm, tp)
        val reg = newReg(nm, tp)
        scopes(nm) = RegVar(reg)
        reg
      case DeclareGlobal(nm) =>
        prog.globals += nm
        RegId("$nil")
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
        RegId("$nil")
      case Return =>
        code += Inst.End
        RegId()
      case Nil => RegId()
      case _: Call => %%(nd, 1)
      //case _ => RegId("$nil")
    }
  }

  // A veces algunos registros quedan sin tipos, porque los nodos no saben
  // el tipo de los nodos hijos, así que luego de haber generado el código,
  // se debe llenar los tipos que faltan, ayudándose de la información del
  // resto del código, como con qué registros interactúa.
  def fixTypes () {
    regs foreach {
      case reg@Reg(name, "") =>
        import Inst._
        val iter = code.toIterator
        var cont = true

        def typeFrom(onm: String, proc: ProcState) {
          proc.regs find (_.nm == onm) match {
            case Some(other) =>
              reg.tp = other.tp
              cont = false
            case None =>
          }
        }

        while (cont && iter.hasNext) {
          iter.next match {
            case Cpy("", _) =>
            case Cpy(_, "") =>
            case Cpy(`name`, other) => typeFrom(other, this)
            case Cpy(other, `name`) => typeFrom(other, this)
            case Call(func, outs, ins) if outs contains name =>
              val index = outs indexOf name
              (prog.procs get func) match {
                case Some(proc) =>
                  val procreg = proc.returns(index)
                  typeFrom(procreg, proc)
                case None =>
                  (prog.imports find (_._2.procs contains func)) match {
                    case Some((imp, _)) =>
                      reg.tp = Predefined(imp).procs(func).outs(index)
                      cont = false
                    case None =>
                  }
              }
            case Call(func, outs, ins) if ins contains name =>
              val index = ins indexOf name
              (prog.procs get func) match {
                case Some(proc) =>
                  val procreg = proc.params(index)
                  typeFrom(procreg, proc)
                case None =>
                  (prog.imports find (_._2.procs contains func)) match {
                    case Some((impName, _)) =>
                      reg.tp = Predefined(impName).procs(func).ins(index)
                      cont = false
                    case None =>
                  }
              }
            case _ =>
          }
        }
      case _ =>
    }
  }

}