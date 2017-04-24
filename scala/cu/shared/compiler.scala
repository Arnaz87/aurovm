package arnaud.culang

import arnaud.cobre.format
import collection.mutable

// TODO: Este archivo es demasiado grande. Hay que dividirlo en varios archivos.

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

  class Module (val name: String, val params: Seq[Ast.Entity] = Nil) {
    modules += this

    var alias = ""
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

      def get (name: String) = map get name
      def apply (name: String) = map get name match {
        case Some(tp) => tp
        case None =>
          val tp = module.Type(name)
          map(name) = tp; tp
      }
    }
  }

  object rutines {
    val defs = Map[String, Scope]()
    def apply(entity: Ast.Entity)(implicit node: Node): program.Rutine = {
      entity.namespace match {
        case None =>
          val name = entity.name
          defs get name match {
            case Some(scope) => scope.rutine
            case None =>
              // De todos los módulos que esten en scope, buscar alguno que
              // tenga la rutina con el nombre y usarla.
              ((modules.toSeq.filter(_.inScope) map {
                mod: Module => mod.rutines(name)
              }) collect {
                case Some(rut) => rut
              }).headOption match {
                case Some(rut) => rut
                case None => error(s"Rutine $name not found")
              }
          }
        case Some(space) =>
          modules.find(_.alias == space) match {
            case Some(mod) =>
              mod.rutines(entity.name) match {
                case Some(rut) => rut
                case None =>
                  error(s"Rutine ${entity.name} not found in $space")
              }
            case None => error(s"Import $space not found")
          }
      }
    }
    def update(name: String, scope: Scope) = defs(name) = scope
  }

  object types {
    val default = Map[String, program.Type]()
    val arrs = Map[Ast.Type, Module]()

    def apply(tp: Ast.Type)(implicit node: Node): program.Type = {
      tp match {
        case Ast.Type.Simple(entity) =>
          entity.namespace match {
            case None =>
              default.get(entity.name) match {
                case Some(tp) => tp
                case None => error(s"Type ${entity.name} not found")
              }
            case Some(space) =>
              modules.find(_.alias == space) match {
                case Some(mod) =>
                  mod.types.get(entity.name) match {
                    case Some(tp) => tp
                    case None =>
                      error(s"Type ${entity.name} not found in $space")
                  }
                case None => error(s"Import $space not found")
              }
          }
        case Ast.Type.Array(_tp) =>
          arrs.get(_tp) match {
            case Some(mod) => mod.types("array")
            case None =>
              val tp = apply(_tp)
              ???
          }
      }
    }
  }

  val _topvars = Map[Ast.Entity, program.Constant]()
  def topvar (entity: Ast.Entity)(implicit node: Ast.Node): Option[program.Constant] = {
    import scala.util.{Try, Success, Failure}
    _topvars get entity match {
      case None =>
        val tp = Ast.Type.Simple(entity)
        Try(types(tp)) match {
          case Success(tp) =>
            val cns = program.TypeConstant(tp)
            _topvars(entity) = cns
            Some(cns)
          case Failure(_) =>
            None
        }
      case Some(cns) => Some(cns)
    }
  }

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

  types.default("int") = intType
  types.default("bool") = boolType
  types.default("string") = strType

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

    // Register Index => (Line, Column, Name)
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

  def genSyms (stmts: Seq[Toplevel]) {
    object mods {
      val types = mutable.Buffer[(Module, Ast.ImportType)]()
      val ruts  = mutable.Buffer[(Module, Ast.ImportRut)]()

      for (stmt@Import(names, params, alias, defs) <- stmts) {
        val modname = names mkString "\u001f"
        val module = modules find { module: Module =>
          (module.name == modname) && (module.params == params)
        } match {
          case None => new Module(modname, params)
          case Some(module) =>
            if (defs.size > 0)
              error(s"Module ${names mkString "."} cannot be redefined")(stmt)
            module
        }

        if (alias.isEmpty) module.inScope = true
        else module.alias = alias.get

        defs foreach {
          case df: ImportType => types += ((module, df))
          case df: ImportRut  => ruts  += ((module, df))
        }
      }
    }

    for (( module, ImportType(Id(name)) ) <- mods.types)
      module.types(name)

    for (node@ Struct(Id(name), fields) <- stmts)
      error("Structs not yet supported")(node)

    for (( module, node@ImportRut(Id(name), ins, outs) ) <- mods.ruts)
      module.rutines(name) = Proto(
        ins map {tp: Type => types(tp)(node)},
        outs map {tp: Type => types(tp)(node)}
      )

    for (node@ Proc(Id(name), params, rets, body) <- stmts) {
      val rutine = program.Rutine(name)
      val srcInfo = new SrcInfo(rutine, name, node.line, node.column)
      val scope = new Scope(rutine, srcInfo)
      for ( (Id(ident), tp) <- params ) {
        val reg = scope.rutine.InReg( types(tp)(node) )
        scope(ident) = reg
        scope.srcinfo.vars(reg.asInstanceOf[scope.srcinfo.rutine.Reg]) =
          (node.line, node.column, ident)
      }
      for (tp <- rets) {
        scope.outs += scope.rutine.OutReg( types(tp)(node) )
      }
      rutines(name) = scope
    }
  }

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
    case Call(fname, args) =>
      val rutine = rutines(fname)
      if (rutine.outs.size < 0) error("Expresions cannot return void")
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
    case Decl(_tp, ps) =>
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
    case Call(fname, args) =>
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

      if (reg.t != result.t) error(s"Cannot assign a ${result.t} to a ${reg.t}")

      val inst = scope.rutine.Cpy(reg, result)

      scope.srcinfo.insts(inst.asInstanceOf[scope.srcinfo.rutine.Inst]) =
        (node.line, node.column)
    case Multi(_ls, Call(fname, args)) =>
      val rutine = rutines(fname)
      if (args.size != rutine.ins.size) error(
        s"Expected ${rutine.ins.size} arguments, found ${args.size}"
      )
      val ls = _ls map {case Id(nm) => scope(nm)}
      val rs = args map (%%(_, scope))

      for ( ((l, r), i) <- (ls zip rs).zipWithIndex ) {
        if (l.t != r.t) error(s"Cannot assign a ${r.t} to a ${l.t}")
      }

      var call = scope.rutine.Call(rutine, ls, rs)
      
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
    case Proc(Id(name), params, rets, body) =>
      val scope = rutines.defs(name)
      for (stmt <- body.stmts) { %%(stmt, scope) }
      scope.rutine.End()
      scope.srcinfo.build()
    case _ =>
  } }

  def importParams () {
    for (module <- modules) {
      module._module match {
        case Some(mod) =>
          for (entity <- module.params)
            // TODO: ¿qué onda con este null y el get? Esto pide error a gritos
            mod.params += topvar(entity)(null).get
        case None =>
      }
    }
  }

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

    compiler.genSyms(prg.stmts)
    for (stmt <- prg.stmts) {
      compiler %% stmt
    }
    compiler.importParams()

    compiler.writeMetadata()
    return compiler
  }
}