package arnaud.myvm.bindump

class Reader (_content: Iterator[Int]) {

  val RESET    = "\u001b[39m"
  val MODULE   = "\u001b[34m" // Blue
  val TYPE     = "\u001b[36m" // Cyan
  val FUNCTION = "\u001b[35m" // Magenta
  val STATIC   = "\u001b[33m" // Yellow
  val REG      = "\u001b[32m" // Green
  val INST     = "\u001b[34m" // Blue

  var no_metadata = false

  import scala.collection.mutable.ArrayBuffer

  def PByte (n: Int, color: String) = {
    val str = f"$n%3d"
    if (color == null) str
    else color+str+RESET
  }

  def PChar (b: Int) =
    if (b >= 0x20 && b <= 0x7e)
      f"\u001b[1;30m  $b%c\u001b[0;39m"
    else f"$b%3d"

  def F(str: String) = s"\u001b[1;30m${str}\u001b[0;39m"
  def F(i: Int, color: String) = color + i + RESET

  val content = new Iterator[Int] {
    var pos = 0;
    def hasNext = _content.hasNext
    def next() = {pos += 1; _content.next}
  }

  var pos = content.pos
  var buffer: ArrayBuffer[String] = new ArrayBuffer()

  //=== Print ===//
    val BAR = "\u001b[1;30m" + (" ."*39) + "\u001b[0;39m\n"
    def printBar  () { println(BAR) }
    def printText (text: String) { println(" "*40 + "| " + text) }
    def printData (text: String, empty: String = "") {

      // El iterador lee ocho bytes a la vez, cada chunk es un List
      val chuncked = buffer.iterator.grouped(8).map(_.toList)

      // Iterar sobre chunks de ocho bytes y líneas
      // Cuando los chunks se acaben, botar Nil
      // Cuando las líneas se acaben, botar texto vacío
      val zipped = chuncked.zipAll(text.lines, Nil, empty)

      // Contar de ocho en ocho, empezando desde pos
      val col = zipped.zipWithIndex.map{
        case ((a,b), i) => (a,b,i)
      }

      col foreach {
        // Si no hay bytes, solo imprimir el texto
        case (Nil, text, _) => printText(text)

        // Si sí hay bytes, imprimir todo bonito
        case (bytes, text, i) =>
          val pstr = if (i==0) f"${pos+(i*8)}%04x:" else " "*5

          val hexline = {
            // Llenar con espacios vacíos hasta llegar a ocho
            val padded = bytes.padTo(8, "   ")

            // Combinar los strings con espacios en medio
            padded.mkString(" ")
          }

          println(s"$pstr  $hexline  | $text")
      }

      this.pos = content.pos
      this.buffer.clear()
    }

  //=== Read ===//
    def readByte (color: String = null) = {
      val byte = content.next()
      this.buffer += PByte(byte, color)
      byte.asInstanceOf[Int]
    }

    def readBytes (n: Int) = {
      for (_ <- 1 to n) yield {
        val byte = content.next()
        this.buffer += PChar(byte)
        byte.asInstanceOf[Int]
      }
    }

    def readInt (color: String): Int = {
      var n = 0
      var byte = readByte(color)
      while ((byte & 0x80) > 0) {
        n = (n << 7) | (byte & 0x7f)
        byte = readByte(color)
      }
      (n << 7) | (byte & 0x7f)
    }
    def readInt (): Int = readInt(null)

    def readString (): String = {
      val size = readInt()
      val bts = readBytes(size)
      val bytes = bts.map(_.asInstanceOf[Byte]).toArray
      new String(bytes, "UTF-8")
    }

  //=== Content ===//

  case class Type (name: String)
  case class Func (index: Int, ins: Int, outs: Int) {
    var _name: Option[String] = None
    def name = _name match {
      case Some(nm) => nm
      case None => s"#$index"
    }
    def name_= (str: String) {_name = Some(str)}
    def hasName = !name.isEmpty
  }

  case class Function (ins: Int, outs: Int, isCode: Boolean)

  val typeBuffer = new ArrayBuffer[Type]()
  //val funcBuffer = new ArrayBuffer[Func]()

  var functions: Array[Function] = null
  var rutines: Array[Func] = null

  val importBuffer = new ArrayBuffer[String]()

  def typeIndex = typeBuffer.size + 1
  //def funcIndex = funcBuffer.size + 1

  var typeCount = 0
  var rutineCount = -1

  def nextRutine () = {
    rutineCount += 1
    rutines(rutineCount)
  }

  var paramCount = 0

  def getTypeName (i: Int) =
    if (i > typeBuffer.length) s"tipo[#$i]"
    else typeBuffer(i-1).name

  def print_signature () {
    val magic = "Cobre ~4\0"
    val data = readBytes(9)
    val valid = (magic zip data) forall {
      case (c: Char, d: Int) => (c == d)
    }
    if (!valid) {
      val bytes = data.map(_.asInstanceOf[Byte]).toArray
      val mag = new String(bytes, "UTF-8")

      throw new Exception(s"Invalid Singature $mag, expected Cobre ~4")
    }

    printData(F("Cobre ~4"))
  }

  def print_modules () {
    val count = readInt()
    printData(s"$count Modules")
    // Start from 1 because module 0 is the argument
    for (i <- 1 to count) {
      val ix = F(i, MODULE)
      readInt() match {
        case 0 =>
          val name = readString()
          printData(s"$ix: import ${F(name)}")
        case 1 =>
          val len = readInt()
          printData(s"$ix: define $len items")
          for (i <- 1 to len) {
            val (kname, color) = readInt() match {
              case 0 => ("module", MODULE)
              case 1 => ("type", TYPE)
              case 2 => ("function", FUNCTION)
              case 3 => ("value", STATIC)
            }
            val index = readInt(color)
            val name = readString()
            printData(s"  ${F(name)}: $kname ${F(index, color)}")
          }
        case 2 =>
          val name = readString()
          printData(s"$ix: import functor ${F(name)}")
        case 3 =>
          val mod = readInt(MODULE)
          val name = readString()
          printData(s"$ix: import ${F(name)} from ${F(mod, MODULE)}")
        case 4 =>
          val base = readInt(MODULE)
          val arg = readInt(MODULE)
          printData(s"$ix: build ${F(base, MODULE)} with ${F(arg, MODULE)}")
      }
    }
  }

  def print_types () {
    val count = readInt()
    printData(s"$count Tipos")

    for (i <- 0 until count) {
      val ix = F(i, TYPE)
      readInt() match {
        case 0 => printData(s"$ix: Null type")
        case 1 =>
          val mod = readInt(MODULE)
          val name = readString()
          printData(s"$ix: import ${F(name)} from ${F(mod, MODULE)}")
          typeBuffer += Type(name)
        case k => throw new Exception(s"Unknown type kind $k")
      }
    }
  }

  // 19 líneas
  def print_functions () {
    val count = readInt()
    printData(s"$count Functions")

    this.functions = new Array(count)

    for (i <- 0 until count) {
      val ix = F(i, FUNCTION)
      var isCode = false
      readInt() match {
        case 0 => printData(s"$ix: null")
        case 1 =>
          val mod = F(readInt(MODULE), MODULE)
          val name = F(readString())
          printData(s"$ix: import $name from $mod")
        case 2 =>
          printData(s"$ix: code")
          isCode = true
        case k =>
          throw new Exception(s"Unknown function kind $k")
      }

      val inCount = readInt()
      val ins = (for(_<- 1 to inCount) yield F(readInt(TYPE), TYPE)) mkString " "

      val outCount = readInt()
      val outs = (for(_<- 1 to outCount) yield F(readInt(TYPE), TYPE)) mkString " "

      printData(s"  $ins -> $outs")

      val fn = Function(inCount, outCount, isCode)
      this.functions(i) = fn
    }
  }

  def single_code (name: String, function: Function) {
    val count = readInt()
    printData(s"$count instructions for $name")

    var reg = function.ins

    def readReg () = F(readInt(REG), REG)
    def readInst () = F(readInt(INST), INST)

    def useRegs (n: Int) = {
      val regs = for (i <- 0 until n) yield F(reg+i, REG)
      reg += n
      s"[${regs mkString " "}]"
    }
    def useReg = useRegs(1)

    for (i <- 1 to count) {
      val inst = readInt()

      val desc = inst match {
        case 0 =>
          val outs = for (i <- 1 to function.outs) yield readReg()
          "end " + outs.mkString(" ")
        case 1 => s"$useReg var"
        case 2 => s"$useReg dup $readReg"
        case 3 => s"set $readReg = $readReg"
        case 4 => s"$useReg sgt ${F(readInt(STATIC), STATIC)}"
        case 5 => s"sst ${F(readInt(STATIC), STATIC)} = $readReg"
        case 6 => s"jmp $readInst"
        case 7 => s"jif $readInst if $readReg"
        case 8 => s"nif $readInst if not $readReg"
        case 9 => s"$useReg any $readInst if not $readReg"
        case inst if inst < 16 => throw new Exception(s"Unknown instruction $inst")
        case inst =>
          val ix = inst - 16
          val fn = functions(ix)
          val ins = for (_ <- 1 to fn.ins) yield readReg()
          s"${useRegs(fn.outs)} ${F(ix, FUNCTION)} ${ins mkString " "}"
      }

      printData(s"  ${F(i, INST)}: $desc")
    }
  }

  def print_code () {
    printData("Code")
    for ((fn, index) <- functions.zipWithIndex if fn.isCode) {
      single_code(F(index, FUNCTION), fn)
    }
    single_code("<static>", Function(0, 0, true))
  }

  def print_statics () {
    val count = readInt()
    printData(s"$count Statics")

    for (i <- 0 until count) {
      val ix = F(i, STATIC)
      readInt() match {
        case 0 => printData(s"$ix: null static")
        case 1 =>
          val mod = F(readInt(MODULE), MODULE)
          val name = F(readString())
          printData(s"$i: import $name from $mod")
        case 2 =>
          val int = readInt()
          printData(s"$ix: int $int")
        case 3 =>
          val size = readInt
          val bytes = readBytes(size)
          val isPrintable = bytes forall { c: Int => !Character.isISOControl(c) }
          val desc = if (isPrintable) {
            val bs = bytes map (_.asInstanceOf[Byte])
            F(new String(bs.toArray, "UTF-8"))
          } else { s"$size bytes" }
          printData(s"$ix: binary data: $desc")
        case 4 =>
          val tp = F(readInt(TYPE), TYPE)
          printData(s"$ix: type $tp")
        case 6 =>
          val fn = F(readInt(FUNCTION), FUNCTION)
          printData(s"$ix: function $fn")
        case k if k<16 => throw new Exception(s"Unknown static kind $k")
        case k =>
          val tp = F(k - 16, TYPE)
          printData(s"$ix: null $tp")
      }
    }
  }

  def print_metadata () {
    def print_item (ident1: String, ident2: String) {
      val n = readInt()
      if ((n & 1) == 1) {
        val int = n >> 1
        printData(ident1 + int)
      } else {
        val len = n >> 2
        if ((n & 2) == 0) {
          printData(ident1 + s"$len Items")
          if (len > 0) {
            for (i <- 1 to (len-1)) // All but last
              print_item(ident2 + "├╸", ident2 + "│ ")
            print_item(ident2 + "╰╸", ident2 + "  ")
          }
        } else {
          val bytes = readBytes(len) map (_.asInstanceOf[Byte])
          val str = new String(bytes.toArray, "UTF-8")
          printData(ident1 + F(str), ident2)
        }
      }
    }
    printData("Metadata")
    print_item("", "")
  }

  def readAll () {
    // 8 secciones

    print_signature()
    printBar()

    print_modules()
    printBar()

    print_types()
    printBar()

    print_functions()
    printBar()

    print_statics()
    printBar()

    print_code()
    printBar()

    if (!no_metadata) print_metadata()
  }
}

object Reader {
  def fromFile (filename: String) = {
    var iter = new Iterator[Int] {
      val stream = new java.io.FileInputStream(filename)
      var _next = getNext

      def getNext = stream.read() match {
        case -1 => None
        case n => Some(n)
      }

      override def hasNext () = !_next.isEmpty

      override def next () = {
        val ch = _next.get
        _next = getNext
        ch
      }
    }
    new Reader(iter)
  }
}

object Main {
  def main (args: Array[String]) {
    val nmd = args(0) == "--no-metadata"
    val reader = Reader.fromFile( if (nmd) args(1) else args(0) )
    reader.no_metadata = nmd
    reader.readAll()
  }
}

// Cuando vaya a escribir el formato binario, Pegar esto en una sesión de Scala
// para obtener la representación binaria de un texto. Solo funciona con
// strings de tamaño inferior a 128 bytes
// def bytes(str:String)={val bs=str.getBytes("UTF-8");f"${bs.size}%02x"+bs.map{b=>f"$b%02x"}.mkString}