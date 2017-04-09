package arnaud.myvm.bindump

class Reader (_content: Iterator[Int]) {
  import scala.collection.mutable.ArrayBuffer

  val content = new Iterator[Int] {
    var pos = 0;
    def hasNext = _content.hasNext
    def next() = {pos += 1; _content.next}
  }

  var pos = content.pos
  var buffer: ArrayBuffer[Int] = new ArrayBuffer()

  //=== Print ===//
    def printBar  () { println("- "*20) }
    def printText (text: String) { println(" "*32 + "| " + text) }
    def printData (text: String) {

      // El iterador lee ocho bytes a la vez, cada chunk es un List
      val chuncked = buffer.iterator.grouped(8).map(_.toList)

      // Iterar sobre chunks de ocho bytes y líneas
      // Cuando los chunks se acaben, botar Nil
      // Cuando las líneas se acaben, botar texto vacío
      val zipped = chuncked.zipAll(text.lines, Nil, "")

      // Contar de ocho en ocho, empezando desde pos
      val col = zipped.zipWithIndex.map{
        case ((a,b), i) => (a,b,i)
      }

      col foreach {
        // Si no hay bytes, solo imprimir el texto
        case (Nil, text, _) => printText(text)

        // Si sí hay bytes, imprimir todo bonito
        case (chars, text, i) =>
          val pstr = if (i==0) f"${pos+(i*8)}%04x:" else " "*5

          val hexline = {
            // Convertir cada byte en su representación
            val hexes = chars.map{ c: Int => f"$c%02x" }

            // Llenar con espacios vacíos hasta llegar a ocho
            val padded = hexes.padTo(8, "  ")

            // Combinar los strings con espacios en medio
            padded.mkString(" ")
          }

          println(s"$pstr  $hexline  | $text")
      }

      this.pos = content.pos
      this.buffer.clear()
    }

  //=== Read ===//
    def readByte () = {
      val byte = content.next()
      this.buffer += byte
      byte.asInstanceOf[Int]
    }

    def readBytes (n: Int) = (1 to n).map{_=>readByte()}

    def readShort () = ((readByte << 8) | readByte)

    def readInt () = {
      var n = 0
      var byte = readByte()
      while ((byte & 0x80) > 0) {
        n = (n << 7) | (byte & 0x7f)
        byte = readByte()
      }
      (n << 7) | (byte & 0x7f)
    }

    def readString (): String = {
      val size = readInt()

      val bts = content.take(size).toSeq
      buffer ++= bts

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

  val typeBuffer = new ArrayBuffer[Type]()
  //val funcBuffer = new ArrayBuffer[Func]()

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

  def print_magic () {
    val magic = "Cobre ~1\0"
    val data = readBytes(9)
    val valid = (magic zip data) forall {
      case (c: Char, d: Int) => (c == d)
    }
    if (!valid) {
      val bytes = data.map(_.asInstanceOf[Byte]).toArray
      val mag = new String(bytes, "UTF-8")

      throw new Exception(s"Invalid Magic Number $mag")
    }

    printData("Magic: \"Cobre ~1\\0\"")
  }

  def print_imports () {
    val count = readInt()
    printData(s"$count Dependencias")
    for (i <- 1 to count) {
      val name = readString()
      printData(s"#$i $name")
      val paramCount = readInt()
      printData(s"$paramCount parámetros")
      for (j <- 1 to paramCount) {
        val cns = readInt()
        printData(s"  const_$cns")
      }
      importBuffer += name
    }
  }

  def print_types () {
    val count = readInt()
    printData(s"$count Tipos")

    for (i <- 1 to count) {
      readInt() match {
        case 0 => throw new Exception(s"Null type kind")
        case 1 => throw new Exception("Internal type kind not yet supported")
        case 2 =>
          val imp = importBuffer(readInt() - 1)
          val name = s"$imp.$readString"

          printData(s"#$i Importado $name")

          typeBuffer += Type(name)
        case 3 => throw new Exception("Use type kind not yet supported")
        case k => throw new Exception(s"Unknown type kind $k")
      }
    }
  }

  // 18 líneas
  def print_basic () {
    this.typeCount = readInt()
    printData(s"${this.typeCount} Tipos")

    val rutCount = readInt()
    this.rutines = new Array(rutCount)
    printData(s"$rutCount Rutinas")

    val constCount = readInt()
    printData(s"$constCount Constantes")

    printData("")

    this.paramCount = readInt()
    printData(s"${this.paramCount} Parámetros")
    for (i <- 1 to this.paramCount) {
      val tp = readInt()
      printData(s"  #$i ${getTypeName(tp)}")
    }
  }

  // 19 líneas
  def print_prototypes () {
    printData("Prototipos")
    val count = readInt()
    printData(s"$count Rutinas")

    this.rutines = new Array(count)

    for (i <- 0 until count) {
      val inCount = readInt()
      val ins = (1 to inCount) map { _: Int =>
        val tp = readInt()
        getTypeName(tp)
      } mkString " "

      val outCount = readInt()
      val outs = (1 to outCount) map { _: Int =>
        val tp = readInt()
        getTypeName(tp)
      } mkString " "

      val rutine = Func(i+1, inCount, outCount)
      printData(s"#${rutine.index} $ins -> $outs")

      this.rutines(i) = rutine
    }
  }

  def print_rutines () {
    printData("Definiciones de rutinas")
    for (rutine <- this.rutines) {
      readInt() match {
        case 0 => throw new Exception("Null rutine kind")
        case 2 =>
          val imp = importBuffer(readInt()-1)
          val name = readString()
          rutine.name = s"$imp.$name"
          printData(s"#${rutine.index} Importada: ${rutine.name}")
        case 1 =>
          val name = readString()
          rutine.name = name
          printData(s"#${rutine.index} Interna $name")

          val regCount = readInt()
          printData(s"  $regCount registros")

          for (i <- 1 to regCount) {
            val tp = readInt()
            val typename = getTypeName(tp)
            val _i = i + rutine.ins + rutine.outs
            printData(s"    $typename #$i")
          }

          val instCount = readInt()
          printData(s"  $instCount Instrucciones")

          for (i <- 1 to instCount) {
            val inst = readInt()

            def readReg() = {
              val ins = rutine.ins
              val inouts = rutine.ins + rutine.outs

              readInt match {
                case j if j <= ins => s"in_$j"
                case j if j <= inouts => s"out_${j-ins}"
                case j => s"reg[${j - inouts}]"
              }
            }

            val desc = inst match {
              case 0 => "%end"
              case 1 => s"%cpy $readReg $readReg"
              case 2 => s"%cns $readReg const_$readInt"
              case 3 => s"%get $readReg $readReg field[$readInt]"
              case 4 => s"%set $readReg field[$readInt] $readReg"
              case 5 => s"%lbl lbl_$readInt"
              case 6 => s"%jmp lbl_$readInt"
              case 7 => s"%jif lbl_$readInt $readReg"
              case 8 => s"%ifn lbl_$readInt $readReg"
              case inst if inst < 16 => s"unknown $inst"
              case inst =>
                val rutine = rutines(inst-16)
                val outs = (1 to rutine.outs).map{_ => readReg}.mkString(" ")
                val ins = (1 to rutine.ins).map{_ => readReg}.mkString(" ")
                s"${rutine.name} $outs <- $ins"
            }

            printData(s"    $desc")
          }
        case 3 => throw new Exception(s"Use rutine kind not yet supported")
        case k => throw new Exception(s"Unknown rutine kind $k")
      }
    }
  }

  // 55 líneas
  def print_code () {
    val rutCount = readInt()
    printData(s"$rutCount Rutinas")

    for (i <- 1 to rutCount) {
      val rutine = nextRutine()
      printData(s"Rutina ${rutine.name}")

      val regCount = readInt()
      printData(s"  $regCount registros")

      for (i <- 1 to regCount) {
        val tp = readInt()
        val typename = getTypeName(tp)
        val _i = i + rutine.ins + rutine.outs
        printData(s"    $typename #$i")
      }

      val instCount = readInt()
      printData(s"  $instCount Instrucciones")

      for (i <- 1 to instCount) {
        val inst = readInt()

        def readReg() = {
          val ins = rutine.ins
          val inouts = rutine.ins + rutine.outs

          readInt match {
            case j if j <= ins => s"in_$j"
            case j if j <= inouts => s"out_${j-ins}"
            case j => s"reg[${j - inouts}]"
          }
        }

        val desc = inst match {
          case 0 => "%end"
          case 1 => s"%cpy $readReg $readReg"
          case 2 => s"%cns $readReg const_$readInt"
          case 3 => s"%get $readReg $readReg field[$readInt]"
          case 4 => s"%set $readReg field[$readInt] $readReg"
          case 5 => s"%lbl lbl_$readInt"
          case 6 => s"%jmp lbl_$readInt"
          case 7 => s"%jif lbl_$readInt $readReg"
          case 8 => s"%ifn lbl_$readInt $readReg"
          case inst if inst < 16 => s"unknown $inst"
          case inst =>
            val rutine = rutines(inst-16)
            val outs = (1 to rutine.outs).map{_ => readReg}.mkString(" ")
            val ins = (1 to rutine.ins).map{_ => readReg}.mkString(" ")
            s"${rutine.name} $outs <- $ins"
        }

        printData(s"    $desc")
      }
    }
  }

  // 54 líneas
  def print_constants () {
    val _count = readInt()
    printData(s"${_count} Constantes")

    val count = _count + this.paramCount;

    var i = this.paramCount + 1;
    while (i <= count) {
      readInt() match {
        case 0 => throw new Exception("Null constant kind")
        case 1 =>
          val size = readInt
          val bytes = readBytes(size)
          val isPrintable = bytes forall { c: Int => !Character.isISOControl(c) }
          val msg = if (isPrintable) {
            "\"" + (
              new String(bytes.map{b => b.asInstanceOf[Byte]}.toArray, "UTF-8")
            ) + "\""
          } else { s"$size bytes" }
          printData(s"#$i Binario: $msg")
          i += 1
        case 2 =>
          val size = readInt
          val vals = (1 to size) map {_ => readInt()}
          val txt = vals map {v => s"const_$v"} mkString " "
          printData(s"#$i Arreglo: $txt")
          i += 1
        case k if k<16 => throw new Exception(s"Unknown Kind $k")
        case j =>
          val rutine = rutines(j-16)

          val outs = (0 until rutine.outs).map{
            j => s"#${i + j}"
          }.mkString(" ")

          val ins = (1 to rutine.ins).map{
            _ => s"const_$readInt"
          }.mkString(" ")

          i = i+rutine.outs

          printData(s"$outs <- ${rutine.name} $ins")
      }
    }
  }

  def print_metadata () {
    def print_item (ident: String) {
      val n = readInt()
      val len = n>>1
      if ((n & 1) == 0) {
        printData(ident + s"$len Items")
        for (i <- 1 to len) print_item(ident + "  ")
      } else {
        val bytes = readBytes(len) map (_.asInstanceOf[Byte])
        val str = new String(bytes.toArray, "UTF-8")
        printData(ident + str)
      }
    }
    printData("Metadatos")
    print_item("")
  }

  def readAll () {
    // 8 secciones

    print_magic()
    printBar()

    print_imports()
    printBar()

    print_types()
    printBar()

    print_prototypes()
    printBar()

    print_rutines()
    printBar()

    print_constants()
    printBar()

    print_metadata()
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
    val reader = Reader.fromFile( args(0) )

    reader.readAll()
  }
}

// Cuando vaya a escribir el formato binario, Pegar esto en una sesión de Scala
// para obtener la representación binaria de un texto. Solo funciona con
// strings de tamaño inferior a 128 bytes
// def bytes(str:String)={val bs=str.getBytes("UTF-8");f"${bs.size}%02x"+bs.map{b=>f"$b%02x"}.mkString}