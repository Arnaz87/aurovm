package arnaud.myvm.codegen

class Writer {
  val buffer = new scala.collection.mutable.ArrayBuffer[Int]()

  def putByte (n: Int) { buffer += n & 0xFF }

  def put (bs: TraversableOnce[Int]) {
    bs foreach (putByte _)
  }

  def %% (n: Int) {
    def helper(n: Int) {
      if (n > 0) {
        helper(n >> 7)
        buffer += (n & 0x7f) | 0x80
      }
    }
    helper(n >> 7)
    buffer += n & 0x7f
  }

  def %% (str: String) {
    val bytes = str.getBytes("UTF-8")
    this %% bytes.size
    this.put(bytes map (_.asInstanceOf[Int]))
  }
}

trait Writable {
  def write (writer: Writer)
}

class Program extends Writable {
  import scala.collection.mutable.{Set, Buffer, ArrayBuffer}

  val modules: Buffer[Module] = new ArrayBuffer[Module]()
  val types: Buffer[Type] = new ArrayBuffer[Type]()
  val rutines: Buffer[Rutine] = new ArrayBuffer[Rutine]()
  val constants = new ArrayBuffer[Constant]()

  sealed abstract class Constant extends Writable {
    constants += this
    def index = (constants indexOf this)+1
  }
  sealed abstract class Type extends Writable {
    types += this
    def index = (types indexOf this)+1
  }
  sealed abstract class Rutine extends Writable {
    def ins: Seq[Type]
    def outs: Seq[Type]
    rutines += this
    def index = (rutines indexOf this) + 16

    def writeProto (w: Writer) {
      w %% ins.size
      ins foreach {t: Type => w %% t.index}

      w %% outs.size
      outs foreach {t: Type => w %% t.index}
    }
  }

  case class Module (nm: String, params: Seq[Constant])
    extends Writable {
    modules += this

    def index = (modules indexOf this)+1

    case class Rutine (nm: String, ins: Seq[Type], outs: Seq[Type])
      extends Program.this.Rutine {
      def write (w: Writer) {
        w %% 2 // Import Kind
        w %% Module.this.index
        w %% this.nm
      }
    }

    case class Type (nm: String) extends Program.this.Type {
      def write (w: Writer) {
        w %% 2 // Import Kind
        w %% Module.this.index
        w %% this.nm
      }
    }

    def write (w: Writer) {
      w %% this.nm
      w %% this.params.size
    }
  }

  class RutineDef(nm: String, _ins: Seq[Type], _outs: Seq[Type])
    extends Rutine {
    def ins = _ins
    def outs = _outs

    val regs = new ArrayBuffer[Reg]()
    val code = new ArrayBuffer[Inst]()

    val lbls = new ArrayBuffer[Lbl]()

    case class Lbl() {
      lbls += this
      def index = (lbls indexOf this)+1
    }
    case class Reg(t: Type) {
      regs += this;
      def index = (regs indexOf this)+1
    }

    sealed abstract class Inst() { code += this }

    case class Cpy(a: Reg, b: Reg) extends Inst
    case class Cns(a: Reg, b: Constant) extends Inst

    case class Ilbl(l: Lbl) extends Inst
    case class Jmp(l: Lbl) extends Inst
    case class Ifj(l: Lbl, a: Reg) extends Inst
    case class Ifn(l: Lbl, a: Reg) extends Inst

    case class Call(f: Rutine, outs: Seq[Reg], ins: Seq[Reg]) extends Inst

    case class End() extends Inst

    def write (w: Writer) {
      w %% 1 // Internal Kind
      w %% nm

      w %% regs.size
      regs foreach {r: Reg => w %% r.t.index}

      w %% code.size
      code foreach {
        case End() => w %% 0
        case Cpy(a, b) =>
          w %% 1; w %% a.index; w %% b.index
        case Cns(a, b) =>
          w %% 2; w %% a.index; w %% 0
        case Ilbl(l) =>
          w %% 5; w %% l.index
        case Jmp(l) =>
          w %% 6; w %% l.index
        case Ifj(l, a) =>
          w %% 7; w %% l.index; w %% a.index
        case Ifn(l, a) =>
          w %% 8; w %% l.index; w %% a.index
        case Call(f, os, is) =>
          w %% f.index
          os foreach {r: Reg => w %% r.index}
          is foreach {r: Reg => w %% r.index}
      }
    }
  }

  def Rutine(nm: String, ins: Seq[Type], outs: Seq[Type]): RutineDef =
    new RutineDef(nm, ins, outs)

  case class BinConstant (bytes: Array[Byte]) extends Constant {
    def write (w: Writer) {
      w %% 1 // Binary Kind
      w %% bytes.size
      bytes foreach {b: Byte =>
        w.putByte( b.asInstanceOf[Int] )
      }
    }
  }
  case class CallConstant (rut: Rutine, args: Seq[Constant]) extends Constant {
    def write (w: Writer) {
      w %% rut.index
      args foreach {c: Constant => w %% c.index}
    }
  }

  def write (w: Writer) {
    ("Cobre ~1\0").getBytes("UTF-8").foreach {
      b: Byte => w putByte b.asInstanceOf[Int]
    }

    w %% modules.size
    modules foreach (_ write w)

    w %% types.size
    types foreach (_ write w)

    w %% rutines.size
    rutines foreach (_ writeProto w)
    rutines foreach (_ write w)

    w %% constants.size
    constants foreach (_ write w)

    // Metadatos
    w putByte 0
  }
}

object Main {
  def main (args: Array[String]) {
    val program = new Program()

    val prelude = program.Module("Prelude", Nil)

    val binType = prelude.Type("Binary")
    val strType = prelude.Type("String")
    val print = prelude.Rutine("print", Nil, Array(strType))
    val mkstr = prelude.Rutine("mkstr", Array(binType), Array(strType))

    val main = program.Rutine("main", Nil, Nil)

    val bindata = {
      val str = "Hola Mundo!"
      val bytes = str.getBytes("UTF-8")
      program.BinConstant(bytes)
    }

    val const_0 = program.CallConstant(mkstr, Array(bindata))

    val reg_0 = main.Reg(strType)
    main.Cns(reg_0, const_0)
    main.Call(print, Array(reg_0), Nil)
    main.End()

    val writer = new Writer()

    program.write(writer)

    printBinary(writer.buffer)
  }

  def printBinary(bindata: Traversable[Int]) {
    new arnaud.myvm.bindump.Reader(bindata.toIterator).readAll
  }
}