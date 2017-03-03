
package arnaud.myvm.codegen

import collection.mutable.{ArrayBuffer, Buffer, Map, Set, Stack}

class IndexMap (mapName: String) {
  private val data: Map[String,Int] = Map()
  def add (name: String): Int = {
    if (data contains name) {
      throw new Exception(s"$name is already registered in $mapName")
    }
    val i = data.size + 1
    data(name) = i
    i
  }
  def apply (name: String): Int = {
    (data get name) match {
      case Some(i) => i
      case None => throw new java.util.NoSuchElementException(s"$name is not registered in $mapName")
    }
  }
}

class BinaryWriter(prog: ProgState) {

  val typeMap = new IndexMap("Types")
  val procMap = new IndexMap("Procs")

  val buf: Buffer[Int] = new ArrayBuffer(512)

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


  def writeImports () {
    putInt(prog.imports.size)

    prog.imports foreach {
      case (nm, imp) =>
        putStr(nm)

        putInt(imp.types.size)
        imp.types foreach {
          case (localName, origName) =>
            typeMap.add(localName)
            putStr(origName)
            putInt(0) // Field Count
        }

        putInt(imp.procs.size)
        imp.procs foreach {
          case (localName, (origName, ins, outs)) =>
            procMap.add(localName)
            putStr(origName)
            putInt(ins) // Params Count
            putInt(outs) // Results Count
        }
    }
  }
  
  def writeTypes () {
    // TODO: Terminar esto
    putInt(0)
  }

  private def findReg (regName: String, proc: ProcState) =
    (proc.regs indexWhere { _.nm == regName }) + 1

  def writeProcs () {
    // Seq me garantiza que cada vez que lo recorra será en el mismo orden
    val procs = prog.procs.toSeq

    putInt(procs.size)

    // Asignarle un índice a cada función
    procs foreach {case (name, proc) => procMap.add(name)}

    // Escribir los prototipos
    procs foreach { case (name, proc) =>
      putStr(name)

      putInt(proc.params.size)
      proc.params foreach {
        regname => putInt(findReg(regname, proc))
      }

      putInt(proc.returns.size)
      proc.returns foreach {
        regname => putInt(findReg(regname, proc))
      }

      putInt(proc.regs.size)
      proc.regs foreach {
        case Reg(regname, typename) =>
          putInt(typeMap(typename))
      }
    }

    procs foreach { case (name, proc) => writeCode(proc) }
  }

  def writeCode (proc: ProcState) {

    val labels = new IndexMap("Labels")

    proc.code foreach {
      case Inst.Lbl(lbl) => labels.add(lbl)
      case _ =>
    }

    def putReg(reg: String) = putInt(findReg(reg, proc))
    def putLbl(reg: String) = putInt(labels(reg))

    def getField(o: String, k: String): Int = ???

    putInt(proc.code.size)

    proc.code foreach {
      case Inst.End => putInt(0)
      case Inst.Cpy(a, b) => { putInt(1); putReg(a); putReg(b) }
      case Inst.Cns(a, b) => { putInt(2); putReg(a); putReg(b) }
      case Inst.Get(a, o, k) =>
        { putInt(3); putReg(a); putReg(o); putInt(getField(o, k)) }
      case Inst.Set(o, k, a) =>
        { putInt(4); putReg(o); putInt(getField(o, k)); putReg(a) }
      case Inst.New(a) =>
      case Inst.Lbl(l) => { putInt(5); putLbl(l) }
      case Inst.Jmp(l) => { putInt(6); putLbl(l) }
      case Inst.If (l, a) => { putInt(7); putLbl(l); putReg(a) }
      case Inst.Ifn(l, a) => { putInt(8); putLbl(l); putReg(a) }

      // Esto está todo loco porque hay mucho trabajo para asegurarse
      // de que el número de argumentos y resultados usados son los mismos
      // que los que la función espera. Esto es importante porque el
      // parser depende de esto, y si sale mal el código ni siquiera se
      // va a poder leer.

      // TODO: Nada en este bloque es legible
      case Inst.Call(nm, rs, gs) =>
        putInt(procMap(nm) + 15)

        // WTF ???
        val (rsnum, gsnum) = {
          (prog.procs get nm) match {
            case Some(prc) => (prc.returns.size, prc.params.size)
            case None =>
              (prog.imports find {
                case (_, imp) => imp.procs contains nm
              }) match {
                case Some((_, imp)) =>
                  imp.procs(nm) match {
                    case (_, gs, rs) => (rs, gs)
                  }
                case None => throw new Exception(s"Unrecognized proc $nm")
              }
          }
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