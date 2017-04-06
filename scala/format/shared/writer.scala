package arnaud.cobre.format

class Writer (buffer: scala.collection.mutable.Buffer[Int]) {
  def putByte (n: Int) { buffer += n & 0xFF }

  def putBytes(bs: TraversableOnce[Int]) {
    bs foreach (putByte _)
  }

  def %% (n: Int) {
    def helper(n: Int) {
      if (n > 0) {
        helper(n >> 7)
        buffer += (n & 0x7f) | 0x80
      }
    }
    helper(n >> 7)
    buffer += n & 0x7f
  }

  def %% (str: String) {
    val bytes = str.getBytes("UTF-8")
    %%(bytes.size)
    putBytes(bytes map (_.asInstanceOf[Int]))
  }

  def write (prg: Program) {
    ("Cobre ~1\0").getBytes("UTF-8").foreach {
      b: Byte => putByte(b.asInstanceOf[Int])
    }

    import prg._

    %%( modules.size)
    for (module <- prg.modules) {
      %%(module.nm)
      %%(module.params.size)
    }

    %%( types.size)
     types foreach {
      case tp: Module#Type =>
        %%(2) // Import Kind
        %%(tp.module.index + 1)
        %%(tp.nm)
    }

    %%( rutines.size)
    for (rutine <- prg.rutines) {
      %%(rutine.ins.size)
      for (tp <- rutine.ins) %%(tp.index + 1)

      %%(rutine.outs.size)
      for (tp <- rutine.outs) %%(tp.index + 1)
    }
    rutines foreach {
      case rutine: Module#Rutine =>
        %%(2) // Import Kind
        %%(rutine.module.index + 1)
        %%(rutine.name)
      case rutine: RutineDef =>
        import rutine._
        %%(1) // Internal Kind
        %%(name)

        %%(regs.size)
        for (reg <- regs) %%(reg.t.index + 1)

        %%(code.size)
        code foreach {
          case End() => %%(0)
          case Cpy(a, b) =>
            %%(1); %%(a.index); %%(b.index)
          case Cns(a, c) =>
            %%(2); %%(a.index); %%(c.index + 1)
          case Ilbl(l) =>
            %%(5); %%(l.index)
          case Jmp(l) =>
            %%(6); %%(l.index+1)
          case Ifj(l, a) =>
            %%(7); %%(l.index+1); %%(a.index)
          case Ifn(l, a) =>
            %%(8); %%(l.index+1); %%(a.index)
          case Call(f, os, is) =>
            %%(f.index + 16)
            for (r <- os) %%(r.index)
            for (r <- is) %%(r.index)
        }
    }

    %%(prg.constants.size)
    prg.constants foreach {
      case BinConstant(bytes) =>
        %%(1) // Binary Kind
        %%(bytes.size)
        bytes foreach putByte
      case CallConstant(rut, args) =>
        %%(rut.index + 16)
        for (arg <- args) %%(arg.index + 1)
    }

    // Metadatos
    putByte(0)
  }
}