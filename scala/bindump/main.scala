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

  case class Type (name: String, fields: Array[String])
  case class Func (name: String, ins: Int, outs: Int)

  val typeBuffer = new ArrayBuffer[Type]()
  val funcBuffer = new ArrayBuffer[Func]()

  def typeIndex = typeBuffer.size + 1
  def funcIndex = funcBuffer.size + 1

  def getTypeName (i: Int) =
    if (i > typeBuffer.length) "unknown"
    else s"tipo[${typeBuffer(i-1).name}]"

  def getFuncName (i: Int) =
    if (i > funcBuffer.length) "unknown"
    else funcBuffer(i-1).name

  var funcStart: Int = 0;
  var funcCount: Int = 0;

  def print_modules () {

    val count = readInt()
    printData(s"$count Módulos")

    for (i <- 0 until count) {
      printText("")

      val modname = readString()
      printData(s"$modname:")

      val types = readInt()
      printData(s"$types Tipos:")
      for (i <- 0 until types) {
        val name = readString()
        printData(s"  $name #$typeIndex")
        val fields = readInt()
        printData(s"    $fields campos")

        val fieldArray = new Array[String](fields)
        for (i <- 0 until fields) {
          val name = readString()
          printData(s"    $name")

          fieldArray(i) = name
        }

        typeBuffer += Type(s"$modname.$name", fieldArray)
      }

      val funcs = readInt()
      printData(s"$funcs Rutinas:")
      for (i <- 0 until funcs) {
        val name = readString()
        printData(s"  $name #$funcIndex")

        val ins = readInt()
        printData(s"    $ins entradas")

        val outs = readInt()
        printData(s"    $outs salidas")

        funcBuffer += Func(s"$modname.$name", ins, outs)
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

      val fieldArray = new Array[String](fCount)

      for (i <- 0 until fCount) {
        var tp = readInt()
        var name = readString()

        val typename = getTypeName(tp)
        printData(s"    $typename $name")

        fieldArray(i) = name
      }

      typeBuffer += Type(name, fieldArray)
    }
  }

  def print_funcs () {
    val count = readInt()
    printData(s"$count Rutinas")

    this.funcCount = count
    this.funcStart = funcIndex

    for (i <- 0 until count) {
      val name = readString()
      printData(s"$name #$funcIndex")

      val inCount = readInt()
      val ins = readBytes(inCount)
      printData(s"  $inCount entradas: ${ins.mkString(" ")}")

      val outCount = readInt()
      val outs = readBytes(outCount)
      printData(s"  $outCount salidas: ${outs.mkString(" ")}")

      val regCount = readInt()
      printData(s"  $regCount registros:")

      for (i <- 1 to regCount) {
        val r = readInt()
        val typename = getTypeName(r)
        printData(s"    $typename #$i")
      }

      funcBuffer += Func(name, inCount, outCount)
    }
  }

  def print_code () {
    for (i <- 0 until funcCount) {

      val funcName = getFuncName(i + funcStart)
      printData(s"Código para $funcName")

      val instCount = readInt()
      printData(s"$instCount Instrucciones")

      for (i <- 1 to instCount) {
        val inst = readInt()

        def readReg() = {
          val reg = readInt
          s"reg[$reg]"
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
          case inst =>
            if (inst >= 16) {
              val func = funcBuffer(inst-16)
              val outs = (1 to func.outs).map{_ => readReg}.mkString(" ")
              val ins = (1 to func.ins).map{_ => readReg}.mkString(" ")
              s"${func.name} $outs <- $ins"
            } else s"unknown $inst"
        }

        printData(s"  $desc")
      }
    }
  }

  def print_constants () {
    val count = readInt()
    printData(s"$count Constantes")

    for (i <- 1 to count) {
      val tp_i = readInt()

      val tp = typeBuffer(tp_i-1)
      printData(s"tipo[${tp.name}] #$i")

      val size = readInt()

      if (tp.fields.size > 0) {
        printData(s"  $size Campos")
        for (i <- 1 to size) {
          val f = readInt()
          printData(s"  const_$f #field[$i]")
        }
      } else {
        printData(s"  $size bytes:")
        readBytes(size)
        printData("")
      }
    }
  }

  def print_garbage () {
    while (content.hasNext) {
      readByte()
    }

    printData("Basura Restante")
  }

  def readAll () {
    print_modules()
    printBar()
    print_structs()
    printBar()
    print_funcs()
    printBar()
    print_code()
    printBar()
    print_constants()
    //print_garbage()
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