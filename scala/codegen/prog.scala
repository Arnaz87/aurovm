package arnaud.myvm.codegen

import collection.mutable.{ArrayBuffer, Buffer, Map, Set, Stack}
import arnaud.myvm.codegen.{Nodes => ND}

trait Signature { def ins: Seq[String]; def outs: Seq[String] }

class ProgState () {

  val imports: Map[String, Predefined.Module] = Map()

  val procs: Map[String, ProcState] = Map()

  val globals: Set[String] = Set()
  val constants: Map[String, Any] = Map()
  var constantCount: Int = 0
  def addConstant(value: Any): RegId = {
    constantCount += 1
    val nm = "$const$" + constantCount
    globals += nm
    constants(nm) = value
    RegId(nm)
  }

  def findProc (nm: String): Option[Signature] = {
    // Revisar si la rutina es del propio módulo
    (procs get nm) match {
      case Some(proc) => Some(proc)
      case None =>
        // Luego revisar entre los módulos importados
        imports.values find ( _.procs.contains(nm) ) match {
          case Some(module) =>
            Some( module.procs(nm) )
          case None => None
        }
    }
  }

  def %% (tp: Node) {
    tp match {
      case ND.Import(name) =>
        imports(name) = Predefined(name)
      case ND.Proc(name, returns, params, body) =>
        val proc = new ProcState(this)
        proc.setParams(params)
        proc.setReturns(returns)
        proc %% body
        proc.code +=  Inst.End
        procs(name) = proc
      case ND.Block(nds) =>
        nds foreach (%% _)
      case ND.Nil =>
      case other =>
        val name = other.getClass.getSimpleName
        throw new Exception(s"Node type '$name' is not a top-level node")
    }
  }

  def fixTypes () {
    procs.valuesIterator.foreach (_.fixTypes)
  }

  def compileSexpr(): arnaud.sexpr.Node = {
    import arnaud.sexpr._
    import arnaud.sexpr.Implicits._
    type Node = arnaud.sexpr.Node

    def NBuf(i: Int = 32): Buffer[Node] = new ArrayBuffer[Node](i)

    val selfnd = NBuf(64)
    val constnd = NBuf(16)

    selfnd += "SELF"
    selfnd += ListNode("MAIN", "MAIN")

    val imported = AtomNode("Imports") +:
      imports.map{ case(name, module) =>
        val types = module.types.map{ tp => ListNode(tp) }
        val procs = module.procs.map{
          case Predefined.Proc(name, ins, outs) =>
            ListNode(name, ins.size.toString, outs.size.toString)
        }
        ListNode(name,
          new ListNode(AtomNode("Types") +: types.toSeq),
          new ListNode(AtomNode("Procs") +: procs.toSeq)
        )
      }.toSeq

    val procnd = AtomNode("Functions") +:
      procs.map{ case(name, procst) =>
        val codeNode = AtomNode("Code") +: procst.code.map{
          case Inst.Cpy(a, b) => ListNode("cpy", a, b)
          case Inst.Cns(a, b) => ListNode("cns", a, b)
          case Inst.Get(a, b, c) => ListNode("get", a, b, c)
          case Inst.Set(a, b, c) => ListNode("set", a, b, c)
          case Inst.New(a) => ListNode("new", a)

          case Inst.Lbl(l) => ListNode("lbl", l)
          case Inst.Jmp(l) => ListNode("jmp", l)
          case Inst.If (l, a) => ListNode("if" , l, a)
          case Inst.Ifn(l, a) => ListNode("ifn", l, a)

          case Inst.Call(nm, rets, args) =>
            ListNode(nm,
              new ListNode(rets map {new AtomNode(_)}),
              new ListNode(args map {new AtomNode(_)})
            )

          case Inst.End => ListNode("end")
        }
        
        val regsNode = AtomNode("Regs") +: procst.regs.map{
          case Reg(nm, tp) => ListNode(nm, tp)
        }

        val returns = new ListNode(("Out" +: procst.outregs) map {new AtomNode(_)})
        val params  = new ListNode(("In" +: procst.inregs)  map {new AtomNode(_)})

        ListNode(name, regsNode, params, returns, codeNode)
      }.toSeq

    constnd += "Constants"
    globals.foreach{ name =>
      selfnd += ListNode(name, "Any")
    }
    constants.foreach{ case (name, v) =>
      //selfnd += ListNode(name, "Any")
      val tp = v match {
        case _:String => "str"
        case _:Float => "num"
        case _:Double => "num"
        case _:Int => "num"
      }
      constnd += ListNode(name, tp, v.toString)
    }

    val structnd = ListNode("Structs")

    ListNode( imported, structnd, procnd, constnd )
  }

  // Cada Int representa un byte. No se supone que estén por encima de 255
  // Uso Int en vez de Byte porque en Java, Byte tiene signo.
  def compileBinary(): Traversable[Int] = {
    val writer = new BinaryWriter(this)

    writer.writeImports()
    writer.writeTypes()
    writer.writeProcs()

    return writer.buf
  }
}