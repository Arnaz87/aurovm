
class Reader (filename: String) {
  import scala.collection.mutable.ArrayBuffer
  import java.io.FileInputStream

  val content = new Iterator[Int] {
    val stream = new java.io.FileInputStream(filename)
    var _next = getNext

    def getNext = stream.read() match {
      case -1 => None
      case n => Some(n)
    }

    var pos = 0

    override def hasNext () = !_next.isEmpty

    override def next () = {
      val ch = _next.get
      _next = getNext
      pos += 1
      ch
    }
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

  def readString (): String = {
    val size = readByte()

    val bts = content.take(size).toSeq
    buffer ++= bts

    bts.map(_.asInstanceOf[Char]).mkString
  }

  def print_modules () {

    val count = readShort()
    printData(s"$count Módulos")

    for (i <- 0 until count) {
      printText("")

      val name = readString()
      printData(s"$name:")

      val types = readShort()
      printData(s"$types Tipos:")
      for (i <- 0 until types) {
        val name = readString()
        printData(s"  $name")
        val fields = readShort()
        printData(s"  $fields campos:")

        for (i <- 0 until fields) {
          val name = readString()
          printData(s"    $name")
        }
      }

      val funcs = readShort()
      printData(s"$funcs Rutinas:")
      for (i <- 0 until funcs) {
        val name = readString()
        printData(s"  $name:")

        val ins = readByte()
        printData(s"    $ins entradas")

        val outs = readByte()
        printData(s"    $outs salidas")
      }
    }
  }

  def print_structs () {
    val count = readShort()
    printData(s"$count Structs")

    for (i <- 0 until count) {
      val name = readString()
      printData(s"$name:")
      val fCount = readShort()
      printData(s"  $fCount campos:")

      for (i <- 0 until fCount) {
        var tp = readShort()
        var name = readString()
        printData(s"    tipo#$tp, $name")
      }
    }
  }

  def print_funcs () {
    val count = readShort()
    printData(s"$count Rutinas")

    for (i <- 0 until count) {
      val name = readString()
      printData(name)

      val inCount = readByte()
      val ins = readBytes(inCount)
      printData(s"  $inCount entradas: ${ins.mkString(" ")}")

      val outCount = readByte()
      val outs = readBytes(outCount)
      printData(s"  $outCount salidas: ${outs.mkString(" ")}")

      val regCount = readShort()
      printData(s"  $regCount registros:")

      //val regs = readShorts(regCount)
      for (i <- 0 until regCount) {
        val r = readShort()
        printData(s"    tipo #$r")
      }

      val byteCount = readShort()
      printData(s"  $byteCount bytes de Instrucciones")

      val bytes = readBytes(byteCount)
      printData("")
    }
  }

}

object Main {
  def main (args: Array[String]) {
    val reader = new Reader( args(0) )

    reader.print_modules()
    reader.printBar()
    reader.print_structs()
    reader.printBar()
    reader.print_funcs()
  }
}