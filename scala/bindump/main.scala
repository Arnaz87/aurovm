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

  def typeIndex = typeBuffer.size + 1
  //def funcIndex = funcBuffer.size + 1

  var typeCount = 0
  var rutineCount = -1

  def nextRutine () = {
    rutineCount += 1
    rutines(rutineCount)
  }

  def getTypeName (i: Int) =
    if (i > typeBuffer.length) s"tipo[#$i]"
    else s"tipo[${typeBuffer(i-1).name}]"

  def print_basic () {
    this.typeCount = readInt()
    printData(s"${this.typeCount} Tipos")

    val rutCount = readInt()
    this.rutines = new Array(rutCount)
    printData(s"$rutCount Rutinas")

    val constCount = readInt()
    printData(s"$constCount Constantes")

    printData("")

    val paramCount = readInt()
    printData(s"$paramCount Parámetros")
    for (i <- 0 until paramCount) {
      val tp = readInt()
      printData(s"  ${getTypeName(tp)}")
    }
  }

  def print_exports () {
    val typeCount = readInt()
    printData(s"$typeCount Tipos Exportados")

    val routCount = readInt()
    printData(s"$routCount Rutinas Exportadas")
    for (i <- 0 until routCount) {
      val rt = readInt()
      val nm = readString()
      printData(s"  #$rt: $nm")
    }
  }

  def print_rutines () {
    printData("Prototipos")
    for (i <- 0 until this.rutines.size) {
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

      rutines(i) = rutine
    }
  }

  def print_modules () {

    val count = readInt()
    printData(s"$count Módulos")

    for (i <- 0 until count) {
      printText("")

      val modname = readString()
      printData(s"$modname:")

      val params = readInt()
      printData(s"$params Parámetros:")
      for (i <- 0 until params) {
        printData(s"  const_$readInt")
      }

      val types = readInt()
      printData(s"$types Tipos:")
      for (i <- 0 until types) {
        val name = readString()
        printData(s"  $name #$typeIndex")
        typeBuffer += Type(s"$modname.$name")
      }

      val funcs = readInt()
      printData(s"$funcs Rutinas:")
      for (i <- 0 until funcs) {
        val rutine = nextRutine
        val name = readString()
        rutine.name = s"$modname.$name"
        printData(s"  $name #${rutine.index}")
      }
    }
  }

  def print_structs () {
    val count = readInt()
    printData(s"$count Structs")

    for (i <- 0 until count) {
      val name = readString()
      printData(s"$name #$typeIndex")

      val fCount = readInt()
      printData(s"  $fCount campos:")

      for (i <- 1 to fCount) {
        var tp = readInt()

        val typename = getTypeName(tp)
        printData(s"    $typename #$i")
      }

      typeBuffer += Type(name)
    }
  }

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

  def print_constants () {
    val count = readInt()
    printData(s"$count Constantes")

    var i = 1;
    while (i <= count) {

      val fmt = readInt()

      val tp = getTypeName(readInt())

      def readi64: Int =
        readBytes(8).foldLeft(0){
          (acc: Int, x: Int) =>
            x | (acc << 8)
        }
      def readf64 = java.lang.Double.longBitsToDouble( readi64 )

      val line = if (fmt < 16) {
        val desc = fmt match {
          case 0 => "null"
          case 1 => s"int $readInt"
          case 2 => s"byte $readByte"
          case 3 => s"i64 $readi64"
          case 4 => s"f64 $readf64"
          case 5 => s"bin $readString"
          case 6 =>
            val n = readInt
            val vals = (1 to n) map {_ => s"const_$readInt"} mkString " "
            s"arr $n: $vals"
          case 7 => s"type ${getTypeName(readInt)}"
          case 8 => s"rut ${rutines(readInt - 1).name}"
          case _ => throw new Exception(s"Unknown format $fmt")
        }
        i = i+1

        s"#${i-1} $tp: $desc"
      } else {
        val rutine = rutines(fmt-16)

        val outs = (0 until rutine.outs).map{
          j => s"#${i + j}"
        }.mkString(" ")

        val ins = (1 to rutine.ins).map{
          _ => s"const_${readInt + 1}"
        }.mkString(" ")

        i = i+rutine.outs

        s"$outs: ${rutine.name} $ins"
      }

      printData(line)
    }
  }

  def print_garbage () {
    while (content.hasNext) {
      readByte()
    }

    printData("Basura Restante")
  }

  def readAll () {
    print_basic()
    printBar()

    print_exports()
    printBar()

    print_rutines()
    printBar()

    print_modules()
    printBar()


    // print_typeuse()

    print_structs()
    printBar()

    // print_rutineuse()

    print_code()
    printBar()

    print_constants()

    // TODO: Faltan typeuse, rutineuse, y constantes
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