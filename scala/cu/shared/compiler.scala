package arnaud.culang

import arnaud.cobre.format
import collection.mutable

class CompileError(msg: String, node: Ast.Node) extends Exception (
  if (node.hasSrcpos) msg + s". At line ${node.line + 1} column ${node.column}" else msg
)

class Compiler {
  import scala.collection.mutable.{ArrayBuffer, Map}
  import format.{Program => CGProgram, meta => Meta}
  import Meta.implicits._
  import Ast._

  def error(_msg: String)(implicit node: Node): Nothing =
    throw new CompileError(_msg, node)

  val program = new CGProgram()

  val modules = mutable.Set[Module]()

  case class Proto(ins: Seq[program.Type], outs: Seq[program.Type])

  class Module (val name: String) {
    //val types: Set[String]) {

    modules += this

    var inScope = false

    var _module: Option[program.Module] = None
    def module = _module match {
      case Some(mod) => mod
      case None =>
        val mod = program.Module(name, Nil)
        _module = Some(mod)
        mod
    }
    //val module = program.Module(names mkString "\u001F", Nil)

    def used = !(_module.isEmpty)

    import program.{Rutine, Type}

    object rutines {
      val protos = Map[String, Proto]()
      val map = Map[String, Rutine]()

      def apply (name: String): Option[Rutine] =
        map get name match {
          case Some(rut) => Some(rut)
          case None => protos get name match {
            case Some(Proto(ins, outs)) =>
              val rut = module.Rutine(name, ins, outs)
              map(name) = rut
              Some(rut)
            case None => None
          }
        }

      def update (name: String, proto: Proto) { protos(name) = proto }

      def ++= (mp: Map[String, Proto]) { protos ++= mp }
    }

    object types {
      val map = Map[String, Type]()

      def apply (name: String) = map get name match {
        case Some(tp) => tp
        case None =>
          val tp = module.Type(name)
          map(name) = tp; tp
      }
    }

    /*def rutine(name: String): Option[Rutine] = rutines get name

    def addRutine(name: String,
      ins: Seq[program.Type],
      outs: Seq[program.Type]) = {
      val rutine = Rutine(name, ins, outs)
      rutines(name) = rutine
      rutine
    }*/

    //def tp(name: String): Option[Type] = ???
  }

  object rutines {
    val defs = Map[String, Scope]()
    def apply(name: String)(implicit node: Node): program.Rutine =
      defs get name match {
        case Some(scope) => scope.rutine
        case None =>
          ((modules.toSeq.filter(_.inScope) map {
            mod: Module => mod.rutines(name)
          }) collect {
            case Some(rut) => rut
          }).headOption match {
            case Some(rut) => rut
            case None => error(s"Rutine ${name} not found")
          }
      }
    def update(name: String, scope: Scope) = defs(name) = scope
  }

  val types = Map[String, program.Type]()

  val rutine_defs = Map[String, Scope]()

  object meta {
    val srcpos = new ArrayBuffer[Meta.Item]()
    val srcnames = new ArrayBuffer[Meta.Item]()

    program.metadata += new Meta.SeqItem(srcpos)
    program.metadata += new Meta.SeqItem(srcnames)
  }

  val prims = new Module("cobre\u001fprim")
  val core = new Module("cobre\u001fcore")
  val strmod = new Module("cobre\u001fstring")
  val sysmod = new Module("cobre\u001fsystem")

  val binaryType = core.types("binary")
  val boolType = core.types("bool")
  val intType = prims.types("int")
  val strType = strmod.types("string")

  types("int") = intType
  types("bool") = boolType
  types("string") = strType

  prims.rutines ++= Map(
    "bintoi" -> Proto( Array(binaryType), Array(intType) ),
    "iadd" -> Proto( Array(intType, intType), Array(intType) ),
    "isub" -> Proto( Array(intType, intType), Array(intType) ),
    "ieq"  -> Proto( Array(intType, intType), Array(boolType) ),
    "igt"  -> Proto( Array(intType, intType), Array(boolType) ),
    "igte" -> Proto( Array(intType, intType), Array(boolType) )
  )

  def makeint = prims.rutines("bintoi").get
  def iadd = prims.rutines("iadd").get
  def isub = prims.rutines("isub").get
  def ieq  = prims.rutines("ieq").get
  def igt  = prims.rutines("igt").get
  def igte = prims.rutines("igte").get

  strmod.rutines ++= Map(
    "bintos" -> Proto( Array(binaryType), Array(strType) ),
    "concat" -> Proto( Array(strType, strType), Array(strType) ),
    "itos" -> Proto( Array(intType), Array(strType) )
  )

  def makestr = strmod.rutines("bintos").get
  def concat = strmod.rutines("concat").get

  sysmod.rutines ++= Map(
    "print" -> Proto( Array(strType), Nil )
  )


  /*
  prims.rutines("bintoi") = Proto(
    Array(binaryType),
    Array(intType)
  )
  def makeint = prims.rutines("bintoi")


  val makestr = strmod.Rutine("bintos",
    Array(binaryType),
    Array(strType)
  )

  val iadd = prims.Rutine("iadd",
    Array(intType, intType), Array(intType)
  )

  val isub = prims.Rutine("isub",
    Array(intType, intType), Array(intType)
  )

  val igt = prims.Rutine("igt",
    Array(intType, intType), Array(boolType)
  )

  val igte = prims.Rutine("igte",
    Array(intType, intType), Array(boolType)
  )

  val ieq = prims.Rutine("ieq",
    Array(intType, intType), Array(boolType)
  )

  val concat = strmod.Rutine("concat",
    Array(strType, strType), Array(strType)
  )*/

  /*rutines("itos") = prelude.Rutine("itos",
    Array(types("Int")),
    Array(types("String"))
  )
  rutines("print") = prelude.Rutine("print",
    Array(types("String")),
    Nil
  )*/

  val srcmap = new ArrayBuffer[Meta.Item]()
  srcmap += "source map"
  val rutmap = new ArrayBuffer[Meta.Item]()
  rutmap += "rutines"
  srcmap += new Meta.SeqItem(rutmap)

  class SrcInfo (val rutine: program.RutineDef, name: String, line: Int, column: Int) {
    val buffer = new ArrayBuffer[Meta.Item]
    import Meta._

    // Instruction Index => (Line, Column)
    val insts = Map[rutine.Inst, (Int, Int)]()

    // Register Index => Name
    val vars = Map[rutine.Reg, (Int, Int, String)]()

    def build () {
      import arnaud.cobre.format.meta.implicits._
      buffer += rutine.index
      buffer += SeqItem("name", name)
      buffer += SeqItem("line", line)
      buffer += SeqItem("column", column)

      buffer += new SeqItem(("regs":Item) +: vars.map{
        case (reg, (line, column, name)) =>
          SeqItem(reg.index, name, line, column)
      }.toSeq)
      buffer += new SeqItem(("insts":Item) +: insts.map{
        case (inst, (line, column)) =>
          SeqItem(inst.index, line, column)
      }.toSeq)
      rutmap += new SeqItem(buffer)
    }
  }

  class Scope (val rutine: program.RutineDef, val srcinfo: SrcInfo) {
    type Reg = rutine.Reg

    val map = Map[String, Reg]()

    val outs = ArrayBuffer[Reg]()

    def get (k: String) = map.get(k)
    def update (k: String, v: Reg) = map(k) = v

    class SubScope(parent: Scope) extends Scope(rutine, srcinfo) {
      override def get (k: String) = this.map get k match {
        case None => parent.get(k).asInstanceOf[Option[this.rutine.Reg]]
        case somereg => somereg
      }
    }

    def apply (k: String)(implicit node: Node) = get(k) match {
      case Some(reg) => reg
      case None => error(s"Variable $k not in scope")
    }

    def Scope = new SubScope(this)
  }

  def genSyms (stmt: Toplevel) { stmt match {
    case Import(names, defs) =>
      val modname = names mkString "\u001f"
      modules find (_.name == modname) match {
        case Some(module) =>
          if (defs.size > 0) {
            error(s"Module ${names mkString "."} cannot be redefined")(stmt)
          }
          module.inScope = true
        case None =>
          val module = new Module(modname)
          for (ImportRut(Id(name), ins, outs) <- defs) {
            module.rutines(name) = Proto(
              ins map {case Type(tp) => types(tp)},
              outs map {case Type(tp) => types(tp)}
            )
          }
          module.inScope = true
      }
    case node@Proc(Id(name), params, rets, body) =>
      val rutine = program.Rutine(name)
      val srcInfo = new SrcInfo(rutine, name, node.line, node.column)
      val scope = new Scope(rutine, srcInfo)
      for ( (Id(ident), Type(tp)) <- params ) {
        val reg = scope.rutine.InReg(types(tp))
        scope(ident) = reg
        scope.srcinfo.vars(reg.asInstanceOf[scope.srcinfo.rutine.Reg]) =
          (node.line, node.column, ident)
      }
      for (Type(tp) <- rets) {
        scope.outs += scope.rutine.OutReg(types(tp))
      }
      rutines(name) = scope
  } }

  def %% (node: Expr, scope: Scope): scope.rutine.Reg = {
    implicit val _node = node
    node match {
    case Var(Id(nm)) => scope(nm)
    case Num(dbl) =>
      val n = dbl.asInstanceOf[Int]
      val bytes = new Array[Int](4)
      bytes(0) = (n >> 24) & 0xFF
      bytes(1) = (n >> 16) & 0xFF
      bytes(2) = (n >> 8 ) & 0xFF
      bytes(3) = (n >> 0 ) & 0xFF
      val bin = program.BinConstant(bytes)
      val const = program.CallConstant(makeint, Array(bin))

      val reg = scope.rutine.Reg(intType)
      scope.rutine.Cns(reg, const)
      reg
    case Str(str) =>
      val bytes = str.getBytes("UTF-8")
      val bin = program.BinConstant(
        bytes map (_.asInstanceOf[Int])
      )
      val const = program.CallConstant(makestr, Array(bin))

      val reg = scope.rutine.Reg(strType)
      scope.rutine.Cns(reg, const)
      reg
    case Call(Id(fname), args) =>
      val rutine = rutines(fname)
      if (args.size != rutine.ins.size) error(
        s"Expected ${rutine.ins.size} arguments, found ${args.size}"
      )
      val reg = scope.rutine.Reg(rutine.outs(0))

      val call = scope.rutine.Call(rutine, Array(reg), args map (%%(_, scope)))

      scope.srcinfo.insts(call.asInstanceOf[scope.srcinfo.rutine.Inst]) =
        (node.line, node.column)
      reg
    case Binop(op, _a, _b) =>
      val a = %%(_a, scope)
      val b = %%(_b, scope)
      val (rutine, rtp) = op match {
        case Add => 
          (a.t, b.t) match {
            case (`intType`, `intType`) => (iadd, intType)
            case (`strType`, `strType`) => (concat, strType)
          }
        case Sub => (isub, intType)
        case Gt  => (igt, boolType)
        case Gte => (igte, boolType)
        case Eq  => (ieq, boolType)
        case _ => error(s"Unknown overload for $op with types")
      }
      val reg = scope.rutine.Reg(rtp)
      val call = scope.rutine.Call(rutine, Array(reg), Array(a, b))

      scope.srcinfo.insts(call.asInstanceOf[scope.srcinfo.rutine.Inst]) =
        (node.line, node.column)

      reg
  } }

  def %% (node: Stmt, scope: Scope) {
    implicit val _node = node;
    node match {
    case Decl(Type(_tp), ps) =>
      val tp = types(_tp)
      for ( decl@DeclPart(Id(nm), vl) <- ps ) {
        val reg = scope.rutine.Reg(tp)
        scope(nm) = reg
        vl match {
          case Some(expr) =>
            val result = %%(expr, scope)
            scope.rutine.Cpy(reg, result)
          case None =>
        }

        scope.srcinfo.vars(reg.asInstanceOf[scope.srcinfo.rutine.Reg]) =
          (node.line, node.column, nm)
      }
    case Call(Id(fname), args) =>
      val rutine = rutines(fname)
      if (args.size != rutine.ins.size) error(
        s"Expected ${rutine.ins.size} arguments, found ${args.size}"
      )
      var call = scope.rutine.Call(rutine, Nil, args map (%%(_, scope)))

      scope.srcinfo.insts(call.asInstanceOf[scope.srcinfo.rutine.Inst]) =
        (node.line, node.column)
    case While(cond, Block(stmts)) =>
      val $start = scope.rutine.Lbl
      val $end = scope.rutine.Lbl

      scope.rutine.Ilbl($start)
      val $cond = %%(cond, scope)
      scope.rutine.Ifn($end, $cond)

      val scoped = scope.Scope
      for (stmt <- stmts) { %%(stmt, scoped) }

      scope.rutine.Jmp($start)
      scope.rutine.Ilbl($end)
    case If(cond, Block(stmts), orelse) =>
      val $else = scope.rutine.Lbl
      val $end  = scope.rutine.Lbl

      val $cond = %%(cond, scope)
      scope.rutine.Ifn($else, $cond)

      val scoped = scope.Scope
      for (stmt <- stmts) { %%(stmt, scoped) }
      scope.rutine.Jmp($end)
      scope.rutine.Ilbl($else)
      orelse match {
        case Some(Block(stmts)) =>
          val scoped = scope.Scope
          for (stmt <- stmts) { %%(stmt, scoped) }
        case None =>
      }
      scope.rutine.Ilbl($end)
    case Assign(Id(nm), expr) =>
      val reg = scope(nm)
      val result = %%(expr, scope)
      val inst = scope.rutine.Cpy(reg, result)

      scope.srcinfo.insts(inst.asInstanceOf[scope.srcinfo.rutine.Inst]) =
        (node.line, node.column)
    case Multi(ls, Call(Id(fname), args)) =>
      val rutine = rutines(fname)
      if (args.size != rutine.ins.size) error(
        s"Expected ${rutine.ins.size} arguments, found ${args.size}"
      )
      var call = scope.rutine.Call(
        rutine,
        ls map {case Id(nm) => scope(nm)},
        args map (%%(_, scope))
      )
      scope.srcinfo.insts(call.asInstanceOf[scope.srcinfo.rutine.Inst]) =
        (node.line, node.column)
    case Return(exprs) =>
      if (exprs.size != scope.outs.size) error(
        s"Expected ${scope.outs.size} return values, found ${exprs.size}"
      )
      for ( (reg, expr) <- scope.outs zip exprs ) {
        val result = %%(expr, scope)
        scope.rutine.Cpy(reg, result)
      }
      scope.rutine.End()
  } }

  def %% (node: Toplevel) { node match {
    case Import(names, ruts) => 
    case Proc(Id(name), params, rets, body) =>
      val scope = rutines.defs(name)
      for (stmt <- body.stmts) { %%(stmt, scope) }
      scope.rutine.End()
      scope.srcinfo.build()
  } }

  def binary: Seq[Int] = {
    val buffer = new ArrayBuffer[Int]()
    val writer = new arnaud.cobre.format.Writer(buffer)
    writer.write(program)
    buffer
  }

  def writeMetadata () {
    program.metadata += new Meta.SeqItem(srcmap)
  }
}

object Compiler {
  def apply (prg: Ast.Program): Compiler = {
    val compiler = new Compiler

    prg.stmts foreach (compiler.genSyms(_))

    for (stmt <- prg.stmts) {
      compiler %% stmt
    }
    compiler.writeMetadata()
    return compiler
  }
}