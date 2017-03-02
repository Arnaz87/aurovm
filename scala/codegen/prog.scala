package arnaud.myvm.codegen

import collection.mutable.{ArrayBuffer, Buffer, Map, Set, Stack}
import arnaud.myvm.codegen.{Nodes => ND}

class Import {
  val types: Map[String, String] = Map()
  val procs: Map[String, (String, Int, Int)] = Map()
}

class ProgState () {

  val imports: Map[String, Import] = Map()

  def getimport (nm: String) = {
    imports.get(nm) match {
      case None =>
        val imp = new Import()
        imports(nm) = imp
        imp
      case Some(imp) => imp
    }
  }

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

  def %% (tp: Node) {
    tp match {
      case ND.ImportType(name, module, field) =>
        getimport(module).types(name) = field
      case ND.ImportProc(name, module, field, ins, outs) =>
        getimport(module).procs(name) = (field, ins, outs)
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
      imports.map{ case(nm, imp) =>
        val types = imp.types.map{
          case (nm, field) => ListNode(nm, field)
        }
        val procs = imp.procs.map{
          case (nm, (field, ins, outs)) =>
            ListNode(nm, field, ins.toString, outs.toString)
        }
        ListNode(nm,
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

          case Inst.Call(nm, gs) => new ListNode((nm +: gs) map {new AtomNode(_)})
          case Inst.End => ListNode("end")
        }
        
        val regsNode = AtomNode("Regs") +: procst.regs.map{
          case (nm, tp) => ListNode(nm, tp)
        }

        val returns = new ListNode(("Out" +: procst.returns) map {new AtomNode(_)})
        val params  = new ListNode(("In" +: procst.params)  map {new AtomNode(_)})

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

  // Este Int representa un byte. No se supone que esté por encima de 255
  // Uso Int en vez de Byte porque en Java, Byte tiene signo.
  def compileBinary(): Traversable[Int] = {

    class IndexMap (mapName: String) {
      private val data: Map[String,Int] = Map()
      def add (name: String): Int = {
        if (data contains name) {
          throw new Exception(s"$name is already registered in $mapName")
        }
        val i = data.size + 1
        data(name) = i
        i
      }
      def apply (name: String): Int = {
        (data get name) match {
          case Some(i) => i
          case None => throw new java.util.NoSuchElementException(s"$name is not registered in $mapName")
        }
      }
    }

    val typeMap = new IndexMap("Types")
    val procMap = new IndexMap("Procs")

    def putByte (n: Int)(implicit buf: Buffer[Int]) { buf += n & 0xFF }
    def putInt (n: Int)(implicit buf: Buffer[Int]) {
      def helper(n: Int) {
        if (n > 0) {
          helper(n >> 7)
          buf += (n & 0x7f) | 0x80
        }
      }
      helper(n >> 7)
      buf += n & 0x7f
    }
    def putStr (str: String)(implicit buf: Buffer[Int]) {
      val bytes = str.getBytes("UTF-8")
      putInt(bytes.size)
      bytes foreach { c:Byte => putByte(c.asInstanceOf[Int] & 0xFF) }
    }

    {
      implicit val programBuffer: Buffer[Int] = new ArrayBuffer(512)

      putInt(imports.size)

      imports foreach {
        case (nm, imp) =>
          putStr(nm)

          putInt(imp.types.size)
          imp.types foreach {
            case (localName, origName) =>
              typeMap.add(localName)
              putStr(origName)
              putInt(0) // Field Count
          }

          putInt(imp.procs.size)
          imp.procs foreach {
            case (localName, (origName, ins, outs)) =>
              procMap.add(localName)
              putStr(origName)
              putInt(ins) // Params Count
              putInt(outs) // Results Count
          }
      }

      putInt(0) // 0 Tipos

      // Seq me garantiza que cada vez que lo recorra va a tener el mismo orden
      val procKeys = procs.keys.toSeq

      putInt(procKeys.size)

      // Asignarle un índice a cada función
      procKeys foreach (procMap.add(_))

      // Escribirlas, en el mismo orden
      procKeys foreach { name =>
        val proc = procs(name)

        putStr(name)

        def findReg (qnm: String) =
          (proc.regs indexWhere {
            case (nm, tp) => nm == qnm
          })+1

        putInt(proc.params.size)
        proc.params foreach {
          regname => putInt(findReg(regname))
        }

        putInt(proc.returns.size)
        proc.returns foreach {
          regname => putInt(findReg(regname))
        }

        putInt(proc.regs.size)
        proc.regs foreach {
          case (regname, typename) =>
            putInt(typeMap(typename))
        }

        val code = {
          implicit val codeBuffer = new ArrayBuffer[Int]()

          val labels = new IndexMap("Labels")

          proc.code foreach {
            case Inst.Lbl(lbl) => labels.add(lbl)
            case _ =>
          }

          def putReg(reg: String) = putInt(findReg(reg))
          def putLbl(reg: String) = putInt(labels(reg))

          def getField(o: String, k: String): Int = ???

          proc.code foreach {
            case Inst.End => putInt(0)
            case Inst.Cpy(a, b) => { putInt(1); putReg(a); putReg(b) }
            case Inst.Cns(a, b) => { putInt(2); putReg(a); putReg(b) }
            case Inst.Get(a, o, k) =>
              { putInt(3); putReg(a); putReg(o); putInt(getField(o, k)) }
            case Inst.Set(o, k, a) =>
              { putInt(4); putReg(o); putInt(getField(o, k)); putReg(a) }
            case Inst.New(a) =>
            case Inst.Lbl(l) => { putInt(5); putLbl(l) }
            case Inst.Jmp(l) => { putInt(6); putLbl(l) }
            case Inst.If (l, a) => { putInt(7); putLbl(l); putReg(a) }
            case Inst.Ifn(l, a) => { putInt(8); putLbl(l); putReg(a) }

            case Inst.Call(nm, gs) =>
              putInt(procMap(nm) + 15)
              gs foreach (putReg(_))
          }

          putInt(2017)
          putInt(3)
          putInt(1)
          putInt(16456)
          putInt(2)

          codeBuffer
        }

        putInt(code.size)
        programBuffer ++= code
      }

      programBuffer
    }
  }
}