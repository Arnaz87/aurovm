package arnaud.cobre

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

  def %%(item: Program#Item) { %%(item.index) }
  def %%(reg: Program#Code#Reg) { %%(reg.index) }
  def %%(lbl: Program#Code#Lbl) { %%(lbl.index) }

  def write (prg: Program) {
    ("Cobre ~4\0").getBytes("UTF-8").foreach {
      b: Byte => putByte(b.asInstanceOf[Int])
    }

    import prg._

    %%(modules.size - 1) // -1 to not count Argument
    modules foreach {
      case `Argument` => // Skip this one, is implicit
      case Import(name, functor) =>
        %%(if (functor) 2 else 0)
        %%(name)
      case ModuleBuild(base, argument) =>
        %%(4)
        %%(base.index)
        %%(argument.index)
      case ModuleDef(items) =>
        %%(1)
        %%(items.size)
        for ((name, item) <- items) {
          %%(item match {
            case _: Module => 0
            case _: Type => 1
            case _: Function => 2
            case _: Static => 3
          })
          %%(item.index)
          %%(name)
        }
    }

    %%(types.size)
     types foreach {
      case tp: Module#Type =>
        %%(1) // Import Kind
        %%(tp.module.index)
        %%(tp.nm)
    }

    %%(functions.size)
    for (function <- prg.functions) {
      function match {
        case function: Module#Function =>
          %%(1) // Import Kind
          %%(function.module.index)
          %%(function.name)
        case _: FunctionDef =>
          %%(2)
      }

      %%(function.ins.size)
      for (tp <- function.ins) %%(tp.index)
      %%(function.outs.size)
      for (tp <- function.outs) %%(tp.index)
    }

    %%(statics.size)
    statics foreach {
      case IntStatic(i) =>
        %%(2)
        %%(i)
      case BinStatic(bytes) =>
        %%(3)
        %%(bytes.size)
        bytes foreach putByte
      case TypeStatic(tp) =>
        %%(4)
        %%(tp.index)
      case FunctionStatic(fun) =>
        %%(5)
        %%(fun.index)
      case NullStatic(tp) =>
        %%(16 + tp.index)
    }

    def writeCode (base: Code) {
      import base._

      %%(code.size)
      code foreach {
        case End(args) => %%(0); args foreach %%
        case Var()     => %%(1);
        case Dup(a)    => %%(2); %%(a)
        case Set(b, a) => %%(3); %%(b); %%(a)
        case Sgt(c)    => %%(4); %%(c)
        case Sst(c, a) => %%(5); %%(c); %%(a)
        case Jmp(l)    => %%(6); %%(l)
        case Jif(l, a) => %%(7); %%(l); %%(a)
        case Nif(l, a) => %%(8); %%(l); %%(a)
        case Any(l, a) => %%(9); %%(l); %%(a)
        case Call(f, args) =>
          %%(f.index + 16)
          args foreach %%
      }
    }

    functions foreach {
      case code: Code => writeCode(code)
      case _ => // Skip
    }
    writeCode(StaticCode)

    def writeNode (node: meta.Node) { node match {
      case meta.IntNode(n) =>
        %%((n << 1) | 1)
      case meta.SeqNode(seq) =>
        %%(seq.size << 2)
        for (itm <- seq) writeNode(itm)
      case meta.StrNode(str) =>
        val bytes = str.getBytes("UTF-8")
        %%((bytes.size << 2) | 2)
        putBytes(bytes map (_.asInstanceOf[Int]))
    } }
    writeNode(new meta.SeqNode(metadata))
  }

  def print () {
    val lines = buffer.iterator.grouped(16)
    for (line <- lines) {
      scala.Predef.print("  ")
      for (b <- line) {
        if (b >= 0x20 && b <= 0x7e) {
          // Print gray in the terminal
          scala.Predef.print(f"\u001b[1;30m$b%c\u001b[0;39m  ")
        } else {
          scala.Predef.print(f"$b%-3d")
        }
      }
      println()
    }
  }

  import java.io._
  def writeToFile (file: File) {
    val stream = new FileOutputStream(file, false)
    buffer foreach { byte: Int => stream.write(byte) }
    stream.close
  }
}