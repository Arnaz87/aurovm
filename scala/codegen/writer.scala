
package arnaud.myvm.codegen

import collection.mutable.{ArrayBuffer, Buffer, Map, Set, Stack}

class IndexMap (mapName: String) extends Traversable[String] {
  private val data = new ArrayBuffer[String](32)
  def add (name: String): Int = {
    if (data contains name) {
      throw new Exception(s"$name is already registered in $mapName")
    }
    data += name
    data.size
  }
  def apply (name: String): Int = {
    (data indexOf name) match {
      case -1 => throw new java.util.NoSuchElementException(s"$name is not registered in $mapName")
      case i => i + 1
    }
  }
  override def foreach[T] (f: String => T) = data.foreach(f)
  override def size = data.size
}

class BinaryWriter(prog: ProgState) {

  val typeMap = new IndexMap("Types")
  val procMap = new IndexMap("Procs")
  val constMap = new IndexMap("Constants")

  val buf = new ArrayBuffer[Int](512)

  def putByte (n: Int) { buf += n & 0xFF }
  def putInt (n: Int) {
    def helper(n: Int) {
      if (n > 0) {
        helper(n >> 7)
        buf += (n & 0x7f) | 0x80
      }
    }
    helper(n >> 7)
    buf += n & 0x7f
  }
  def putStr (str: String) {
    val bytes = str.getBytes("UTF-8")
    putInt(bytes.size)
    bytes foreach { c:Byte => putByte(c.asInstanceOf[Int] & 0xFF) }
  }

  def prepareData () {
    prog.constants foreach { case (name, value) => constMap.add(name) }

    prog.imports foreach { case (nm, imp) =>
      imp.procs foreach {proc =>
        procMap.add(proc.name)
      }
    }
    prog.procs foreach {case (name, proc) => procMap.add(name)}

    prog.imports foreach { case (nm, imp) =>
      imp.types foreach {name => typeMap.add(name) }
    }
  }

  def writeBasics () {
    val typeCount = prog.imports.map{
      case (nm, imp) => imp.types.size
    }.foldLeft(0)(_+_)

    putInt(typeCount)

    val rutCount = prog.imports.map{
      case (nm, imp) => imp.procs.size
    }.foldLeft(prog.procs.size)(_+_)

    putInt(rutCount)

    putInt(constMap.size)

    // Params
    putInt(0)

    // Tipos Exportados
    putInt(0)

    // Rutinas Exportadas
    putInt(0)
  }

  def writeRutines () {
    def writeRutine (rut: Signature) {
      putInt(rut.ins.size)
      rut.ins foreach {typenm =>
        putInt(typeMap(typenm))
      }

      putInt(rut.outs.size)
      rut.outs foreach {typenm =>
        putInt(typeMap(typenm))
      }
    }

    prog.imports foreach { case (nm, imp) =>
      imp.procs foreach (writeRutine _)
    }

    prog.procs foreach {case (name, proc) => writeRutine(proc)}
  }

  def writeImports () {
    putInt(prog.imports.size)

    prog.imports foreach {
      case (nm, imp) =>
        putStr(nm)

        // Parámetros
        putInt(0)

        putInt(imp.types.size)
        imp.types foreach { name =>
          putStr(name)
        }

        putInt(imp.procs.size)
        imp.procs foreach { proc =>
          putStr(proc.name)
        }
    }
  }
  
  def writeTypes () {
    // TODO: Terminar esto
    putInt(0)
  }

  private def findReg (regName: String, proc: ProcState) =
    (proc.regs indexWhere { _.nm == regName }) + 1

  def writeCode () {
    putInt(prog.procs.size)

    prog.procs foreach { case (name, proc) =>
      putInt(proc.regs.size)
      proc.regs foreach {
        case Reg(regname, typename) =>
          putInt(typeMap(typename))
      }

      def findReg (regName: String) =
        (proc.regs indexWhere { _.nm == regName }) + 1

      val labels = new IndexMap("Labels")

      proc.code foreach {
        case Inst.Lbl(lbl) => labels.add(lbl)
        case _ =>
      }

      def putReg(reg: String) = putInt(findReg(reg))
      def putLbl(reg: String) = putInt(labels(reg))

      def getField(o: String, k: String): Int = ???

      putInt(proc.code.size)

      proc.code foreach {
        case Inst.End => putInt(0)
        case Inst.Cpy(a, b) => { putInt(1); putReg(a); putReg(b) }
        case Inst.Cns(a, b) => { putInt(2); putReg(a); putInt(constMap(b)) }
        case Inst.Get(a, o, k) =>
          { putInt(3); putReg(a); putReg(o); putInt(getField(o, k)) }
        case Inst.Set(o, k, a) =>
          { putInt(4); putReg(o); putInt(getField(o, k)); putReg(a) }
        case Inst.New(a) =>
        case Inst.Lbl(l) => { putInt(5); putLbl(l) }
        case Inst.Jmp(l) => { putInt(6); putLbl(l) }
        case Inst.If (l, a) => { putInt(7); putLbl(l); putReg(a) }
        case Inst.Ifn(l, a) => { putInt(8); putLbl(l); putReg(a) }

        // Aqui hay que asegurarse de que los números de entradas y salidas
        // usadas son los mismos que los que la rutina espera.
        case Inst.Call(nm, rs, gs) =>
          putInt(procMap(nm) + 15)

          val (rsnum, gsnum) = prog.findProc(nm) match {
            case Some(proc) => (proc.outs.size, proc.ins.size)
            case None => throw new Exception(s"Use of nonexisting proc $nm")
          }

          if (rs.size > rsnum) {
            throw new Exception(s"expected $rsnum or less results for $nm, got ${rs.size}")
          }
          rs foreach (putReg(_))
          // Si no hay suficientes resultados, llenar con ceros.
          // Eso es váido, significa que se descartan los resultados.
          (1 to (rsnum - rs.size)) foreach {_ => putInt(0)}

          if (gs.size != gsnum) {
            throw new Exception(s"expected $gsnum arguments for $nm, got ${gs.size}")
          }
          gs foreach (putReg(_))
      }
    }
  }

  def writeConstants () {
    putInt(constMap.size)

    def putFullInt (i: Int) {
      putByte(0)
      putByte(0)
      putByte(0)
      putByte(0)
      putByte((i >> 24) & 0xFF)
      putByte((i >> 16) & 0xFF)
      putByte((i >> 8 ) & 0xFF)
      putByte((i >> 0 ) & 0xFF)
    }

    constMap foreach { name =>
      prog.constants(name) match {
        case i: Int =>
          putInt(3)
          putInt(typeMap("Int"))
          putFullInt(i)
        case n: Float =>
          putInt(3)
          putInt(typeMap("Int"))
          putFullInt(n.asInstanceOf[Int])
        case n: Double =>
          putInt(3)
          putInt(typeMap("Int"))
          putFullInt(n.asInstanceOf[Int])
        case s: String =>
          putInt(5)
          putInt(typeMap("String"))
          putStr(s)
      }
    }
  }

  def writeAll () {
    prepareData()

    writeBasics()
    writeRutines()
    writeImports()
    writeTypes()
    writeCode()

    // writeUses()
    putInt(0)
    putInt(0)

    writeConstants()
  }
}