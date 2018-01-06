package arnaud.cobre

object Main {
  def main (args: Array[String]) {
    val program = new Program()

    val core = program.Import("cobre.core")
    val strmod = program.Import("cobre.string")
    val sysmod = program.Import("cobre.system")

    val binType = core.Type("bin")
    val strType = strmod.Type("string")
    val sysprint = sysmod.Function("print", Array(strType), Nil)
    val newstr = strmod.Function("new", Array(binType), Array(strType))

    val bindata = {
      val str = "Hola Mundo!"
      val bytes = str.getBytes("UTF-8")
      program.BinStatic(
        bytes map (_.asInstanceOf[Int])
      )
    }
    val const_0 = program.NullStatic(strType)
    val binreg = program.StaticCode.Sgt(bindata).reg
    val strval = program.StaticCode.Call(newstr, Array(binreg)).regs(0)
    program.StaticCode.Sst(const_0, strval)
    program.StaticCode.End(Nil)

    val myprint = program.FunctionDef(Array(strType), Nil)
    val in_0 = myprint.inregs(0)
    myprint.Call(sysprint, Array(in_0))
    myprint.End(Nil)

    val mainf = program.FunctionDef(Nil, Nil)
    val reg_0 = mainf.Sgt(const_0).reg
    mainf.Call(sysprint, Array(reg_0))
    mainf.End(Nil)

    program.export("main", mainf)

    program.metadata += meta.SeqNode(
      meta.StrNode("some data"),
      meta.IntNode(42)
    )

    val buffer = new scala.collection.mutable.ArrayBuffer[Int]()
    val writer = new Writer(buffer)
    writer.write(program)

    writer.print()

    val file = new java.io.File("out")
    writer.writeToFile(file)
    println(s"Binary data written to ${file.getCanonicalPath}")

  }
}