package arnaud.cobre.format

class Program {
  import scala.collection.mutable.{Set, Buffer, ArrayBuffer}

  val modules: Buffer[Module] = new ArrayBuffer[Module]()
  val types: Buffer[Type] = new ArrayBuffer[Type]()
  val functions: Buffer[Function] = new ArrayBuffer[Function]()
  val statics = new ArrayBuffer[Static]()

  val metadata = new ArrayBuffer[meta.Node]()

  sealed abstract class Item { def index: Int }

  sealed abstract class Static extends Item {
    statics += this
    def index = statics indexOf this
  }

  sealed abstract class Type extends Item {
    types += this
    def index = types indexOf this
  }

  sealed abstract class Function(val ins: Seq[Type], val outs: Seq[Type]) extends Item {
    //def ins: Seq[Type]
    //def outs: Seq[Type]

    functions += this
    def index = functions indexOf this
    def signature = s"${ins mkString " "} -> ${outs mkString " "}"
  }

  sealed abstract class Module extends Item {
    modules += this
    def index = modules indexOf this

    case class Function (
      name: String,
      _ins: Seq[Program.this.Type],
      _outs: Seq[Program.this.Type])
      extends Program.this.Function(_ins, _outs) {
      val module = Module.this
      override def toString () = s"Function(${module}.$name, $signature)"
    }

    case class Type (nm: String)
      extends Program.this.Type {
      val module = Module.this
      override def toString () = s"Type(${module}.$nm)"
    }
  }

  // No puede ser object porque son lazy
  val Argument = new Module {}
  case class Import (name: String, functor: Boolean = false) extends Module
  case class ModuleBuild (base: Module, argument: Module) extends Module
  case class ModuleDef (var items: Map[String, Item]) extends Module
  val Exports = ModuleDef(Map())
  def export(name: String, item: Item) {
    Exports.items = Exports.items + (name -> item)
  }

  sealed trait Code {
    def outcount: Int

    val regs = new ArrayBuffer[Reg]()
    val code = new ArrayBuffer[Inst]()

    class Reg () {
      regs += this
      def index = regs indexOf this
    }

    case class Lbl () {
      var _index: Int = -1

      def index = {
        if (_index == -1)
          throw new Exception("Label not used")
        _index
      }

      def create () = {
        if (_index != -1)
          throw new Exception("Label already used")
        _index = code.size
      }
    }

    sealed abstract class Inst() {
      code += this
      def index = code indexOf this
      final override def equals (o: scala.Any) = o match {
        case o: Inst => this eq o
        case _ => false
      }
    }

    sealed abstract class RegInst extends Inst { val reg = new Reg() }

    case class End(args: Seq[Reg]) extends Inst {
      if (args.size != outcount) throw new Exception("result count mismatch")
    }
    case class Var() extends RegInst

    case class Dup(a: Reg) extends RegInst
    case class Set(b: Reg, a: Reg) extends Inst

    case class Sgt(c: Static) extends RegInst
    case class Sst(c: Static, a: Reg) extends Inst

    case class Jmp(l: Lbl) extends Inst
    case class Jif(l: Lbl, a: Reg) extends Inst
    case class Nif(l: Lbl, a: Reg) extends Inst
    case class Any(l: Lbl, a: Reg) extends RegInst

    case class Call(f: Function, args: Seq[Reg]) extends Inst {
      val regs = args map (_ => new Reg())
    }

  }

  case class FunctionDef(_ins: Seq[Type], _outs: Seq[Type])
    extends Function(_ins, _outs) with Code {

    val inregs = _ins.map(_ => new Reg())

    override def outcount = _outs.size
    override def toString () = s"CodeFunction($signature)"
  }

  object StaticCode extends Code {
    override def outcount = 0
    override def toString () = "Static"
  }

  case class IntStatic (int: Int) extends Static
  case class BinStatic (bytes: Array[Int]) extends Static {
    override def toString() = {
      val hexSeq = bytes map {b: Int => f"$b%02x"}
      s"BinStatic(${hexSeq mkString " "})"
    }
  }
  case class TypeStatic (tp: Type) extends Static
  case class FunctionStatic (tp: Function) extends Static

  case class NullStatic (tp: Type) extends Static
}