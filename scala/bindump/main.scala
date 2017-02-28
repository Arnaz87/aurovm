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

    bts.map(_.asInstanceOf[Char]).mkString
  }

  def print_modules () {

    val count = readInt()
    printData(s"$count Módulos")

    for (i <- 0 until count) {
      printText("")

      val name = readString()
      printData(s"$name:")

      val types = readInt()
      printData(s"$types Tipos:")
      for (i <- 0 until types) {
        val name = readString()
        printData(s"  $name")
        val fields = readInt()
        printData(s"  $fields campos:")

        for (i <- 0 until fields) {
          val name = readString()
          printData(s"    $name")
        }
      }

      val funcs = readInt()
      printData(s"$funcs Rutinas:")
      for (i <- 0 until funcs) {
        val name = readString()
        printData(s"  $name:")

        val ins = readInt()
        printData(s"    $ins entradas")

        val outs = readInt()
        printData(s"    $outs salidas")
      }
    }
  }

  def print_structs () {
    val count = readInt()
    printData(s"$count Structs")

    for (i <- 0 until count) {
      val name = readString()
      printData(s"$name:")
      val fCount = readInt()
      printData(s"  $fCount campos:")

      for (i <- 0 until fCount) {
        var tp = readInt()
        var name = readString()
        printData(s"    tipo#$tp, $name")
      }
    }
  }

  def print_funcs () {
    val count = readInt()
    printData(s"$count Rutinas")

    for (i <- 0 until count) {
      val name = readString()
      printData(name)

      val inCount = readInt()
      val ins = readBytes(inCount)
      printData(s"  $inCount entradas: ${ins.mkString(" ")}")

      val outCount = readInt()
      val outs = readBytes(outCount)
      printData(s"  $outCount salidas: ${outs.mkString(" ")}")

      val regCount = readInt()
      printData(s"  $regCount registros:")

      //val regs = readShorts(regCount)
      for (i <- 0 until regCount) {
        val r = readInt()
        printData(s"    tipo #$r")
      }

      val byteCount = readInt()
      printData(s"  $byteCount bytes de Instrucciones")

      val bytes = readBytes(byteCount)
      printData("")
    }
  }

  def readAll () {
    print_modules()
    printBar()
    print_structs()
    printBar()
    print_funcs()
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