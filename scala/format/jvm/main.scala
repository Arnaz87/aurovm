package arnaud.cobre.format

object Main {
  def main (args: Array[String]) {
    val program = new Program()

    val prelude = program.Module("Prelude", Nil)

    val binType = prelude.Type("Binary")
    val strType = prelude.Type("String")
    val print = prelude.Rutine("print", Nil, Array(strType))
    val mkstr = prelude.Rutine("mkstr", Array(binType), Array(strType))

    val plint = program.Rutine("plint")
    val in_0 = plint.InReg(strType)
    plint.Call(print, Array(in_0), Nil)

    val main = program.Rutine("main")
    val bindata = {
      val str = "Hola Mundo!"
      val bytes = str.getBytes("UTF-8")
      program.BinConstant(
        bytes map (_.asInstanceOf[Int])
      )
    }

    val const_0 = program.CallConstant(mkstr, Array(bindata))
    val reg_0 = main.Reg(strType)
    main.Cns(reg_0, const_0)
    main.Call(plint, Array(reg_0), Nil)
    main.End()

    program.metadata += meta.StrItem("Hola Mundo!")

    val buffer = new scala.collection.mutable.ArrayBuffer[Int]()
    val writer = new Writer(buffer)
    writer.write(program)
    printBinary(buffer)
  }

  def printBinary(bindata: Traversable[Int]) {
    new arnaud.myvm.bindump.Reader(bindata.toIterator).readAll
  }
}