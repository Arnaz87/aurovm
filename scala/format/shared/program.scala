package arnaud.cobre.format

class Program {
  import scala.collection.mutable.{Set, Buffer, ArrayBuffer}

  val modules: Buffer[Module] = new ArrayBuffer[Module]()
  val types: Buffer[Type] = new ArrayBuffer[Type]()
  val rutines: Buffer[Rutine] = new ArrayBuffer[Rutine]()
  val constants = new ArrayBuffer[Constant]()

  val metadata = new ArrayBuffer[meta.Item]()

  sealed abstract class Constant {
    constants += this
    def index = constants indexOf this
  }
  sealed abstract class Type {
    types += this
    def index = types indexOf this
  }
  sealed abstract class Rutine {
    def ins: Seq[Type]
    def outs: Seq[Type]
    rutines += this
    def index = rutines indexOf this
    def signature = s"${ins mkString " "} -> ${outs mkString " "}"
  }

  case class Module (nm: String, params: Seq[Constant]) {
    modules += this

    def index = modules indexOf this

    case class Rutine (
      name: String,
      ins: Seq[Program.this.Type],
      outs: Seq[Program.this.Type])
      extends Program.this.Rutine {
      val module = Module.this
      override def toString () = s"Rutine(${module.nm}.$name, $signature)"
    }

    case class Type (nm: String)
      extends Program.this.Type {
      val module = Module.this
      override def toString () = s"Type(${module.nm}.$nm)"
    }
  }

  class RutineDef(_name: String)
    extends Rutine {
    def ins = inregs map {reg: Reg => reg.t}
    def outs = outregs map {reg: Reg => reg.t}

    def name = _name

    val inregs = new ArrayBuffer[Reg]()
    val outregs = new ArrayBuffer[Reg]()
    val regs = new ArrayBuffer[Reg]()
    val code = new ArrayBuffer[Inst]()

    val lbls = new ArrayBuffer[Lbl]()

    abstract class Reg (val t: Type) { def index: Int }

    class InReg (_t: Type) extends Reg(_t) {
      inregs += this
      def index = (inregs indexOf this)+1
    }

    class OutReg (_t: Type) extends Reg(_t) {
      outregs += this
      def index = inregs.size + (outregs indexOf this) + 1
    }

    class RegDef (_t: Type) extends Reg(_t) {
      regs += this
      def index =
        inregs.size + outregs.size +
        (regs indexOf this) + 1
    }

    def InReg (t: Type) = new InReg(t)
    def OutReg (t: Type) = new OutReg(t)
    def Reg (t: Type) = new RegDef(t)

    class Lbl () {
      lbls += this
      def index = lbls indexOf this
    }

    def Lbl = new Lbl()

    sealed abstract class Inst() {
      code += this
      def index = code indexOf this
      final override def equals (o: Any) = o match {
        case o: Inst => this eq o
        case _ => false
      }
    }

    case class Cpy(a: Reg, b: Reg) extends Inst
    case class Cns(a: Reg, b: Constant) extends Inst

    case class Ilbl(l: Lbl) extends Inst
    case class Jmp(l: Lbl) extends Inst
    case class Ifj(l: Lbl, a: Reg) extends Inst
    case class Ifn(l: Lbl, a: Reg) extends Inst

    case class Call(f: Rutine, outs: Seq[Reg], ins: Seq[Reg]) extends Inst

    case class End() extends Inst

    override def toString () = s"Rutine($name, $signature)"
  }

  def Rutine(name: String): RutineDef = new RutineDef(name)

  case class BinConstant (bytes: Array[Int]) extends Constant {
    override def toString() = {
      val hexSeq = bytes map {b: Int => f"$b%02x"}
      s"BinConstant(${hexSeq mkString " "})"
    }
  }
  case class CallConstant (rut: Rutine, args: Seq[Constant]) extends Constant {
    override def toString() = s"CallConstant($rut, ${args mkString ", "})"
  }
}