package arnaud.culang

import arnaud.cobre.format
import collection.mutable


class CompileError(msg: String, node: Ast.Node) extends Exception (
  if (node.hasSrcpos) s"$msg. At line ${node.line + 1} column ${node.column}" else msg
)

package object compiler {
  implicit class NodeOps (node: Ast.Node) {
    def error(msg: String): Nothing = throw new CompileError(msg, node)
  }

  sealed abstract class Item

  class Program {
    type Module = compiler.Module[this.type]
    type Rutine = compiler.Rutine[this.type]

    val program = new format.Program()
    val modules = mutable.Set[Module]()
    val rutines = mutable.Set[Rutine]()
    val types = mutable.Map[String, program.Type]()

    case class TypeItem (tp: program.Type) extends Item
    case class RutItem (rut: program.Rutine) extends Item
    case class ConstItem (cns: program.Constant, tp: program.Type) extends Item

    case class Proto(ins: Seq[program.Type], outs: Seq[program.Type])

    def Module(name: String, params: Seq[Ast.Expr]) = {
      val mod = new Module(this, name, params)
      modules += mod; mod
    }

    // `object default` es Lazy, pero necesito que los módulos se evalúen
    val default = new Object {
      val prims = Module("cobre\u001fprim", Nil)
      val core = Module("cobre\u001fcore", Nil)
      val strmod = Module("cobre\u001fstring", Nil)
      val sysmod = Module("cobre\u001fsystem", Nil)

      val binaryType = core.types("binary")
      val boolType = core.types("bool")
      val intType = prims.types("int")
      val strType = strmod.types("string")

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

      val types = Map(
        "int" -> intType,
        "bool" -> boolType,
        "string" -> strType
      )

      def apply(nm: String) = types.get(nm) map TypeItem
    }

    object meta {
      import mutable.ArrayBuffer
      import format.{meta => Meta}
      import Meta.implicits._

      val srcpos = new ArrayBuffer[Meta.Item]()
      val srcnames = new ArrayBuffer[Meta.Item]()

      program.metadata += new Meta.SeqItem(srcpos)
      program.metadata += new Meta.SeqItem(srcnames)

      val srcmap = new ArrayBuffer[Meta.Item]()
      srcmap += "source map"
      val rutmap = new ArrayBuffer[Meta.Item]()
      rutmap += "rutines"
      srcmap += new Meta.SeqItem(rutmap)
    }

    def get (name: String): Option[Item] = {
      // Todos los items definidos en módulos en el scope
      lazy val items = for (
        mod <- modules if mod.inScope;
        item <- {
          def tp = mod.types.get(name).map(TypeItem)
          def rut = mod.rutines(name).map(RutItem)
          tp orElse rut
        }
      ) yield item

      ( rutines.
          find(_.name == name).
          map(_.rdef).map(RutItem) orElse
        types.get(name).map(TypeItem) orElse
        items.headOption orElse
        modules.find(_.alias == name) orElse
        default(name) )
    }

    def %% (node: Ast.Expr): Item = node match {
      case Ast.Num(dbl) =>
        val n = dbl.asInstanceOf[Int]
        val bytes = new Array[Int](4)
        bytes(0) = (n >> 24) & 0xFF
        bytes(1) = (n >> 16) & 0xFF
        bytes(2) = (n >> 8 ) & 0xFF
        bytes(3) = (n >> 0 ) & 0xFF
        val bin = program.BinConstant(bytes)
        val const = program.CallConstant(default.makeint, Array(bin))
        ConstItem(const, default.intType)
      case Ast.Str(str) =>
        val bytes = str.getBytes("UTF-8")
        val bin = program.BinConstant(
          bytes map (_.asInstanceOf[Int])
        )
        val const = program.CallConstant(default.makestr, Array(bin))
        ConstItem(const, default.strType)
      case Ast.Var(name) =>
        get(name) getOrElse node.error(s"$name is undefined")
      case Ast.Field(expr, name) =>
        %%(expr) match {
          case mod: Module =>
            mod.get(name) getOrElse node.error(
              s"$name not found in ${mod.name}"
            )
        }
    }

    def getType (node: Ast.Type): program.Type = %%(node.expr) match {
      case TypeItem(tp) => tp
      case _ => node.expr.error("Not a Type")
    }

    def compile (stmts: Seq[Ast.Toplevel]) {
      // El orden de estas operaciones importa, cada una depende de que
      // las anteriores estén definidas

      object mods {
        val types = mutable.Buffer[(Module, Ast.ImportType)]()
        val ruts  = mutable.Buffer[(Module, Ast.ImportRut)]()

        for (stmt@Ast.Import(names, params, alias, defs) <- stmts) {
          val modname = names mkString "\u001f"
          val hname = names mkString "."
          val module = modules find { module: Module =>
            (module.name == modname) && (module.params == params)
          } match {
            case None =>
              if (defs.size == 0)
                stmt.error(s"Unknown contents of module $hname")
              Module(modname, params)
            case Some(module) =>
              if (defs.size > 0)
                stmt.error(s"Module $hname cannot be redefined")
              module
          }

          if (alias.isEmpty) module.inScope = true
          else module.alias = alias.get

          defs foreach {
            case df: Ast.ImportType => types += ((module, df))
            case df: Ast.ImportRut  => ruts  += ((module, df))
          }
        }
      }

      for (( module, Ast.ImportType(name) ) <- mods.types)
        module.types(name)

      for (stmt@ Ast.Struct(name, fields) <- stmts)
        stmt.error("Structs not yet supported")

      for (( module, node@Ast.ImportRut(name, ins, outs) ) <- mods.ruts)
        module.rutines(name) = Proto(
          ins map {tp: Ast.Type => getType(tp)},
          outs map {tp: Ast.Type => getType(tp)}
        )

      rutines ++= stmts collect {
        case node: Ast.Proc =>
          new Rutine(this, node)
      }

      // Solo compilar las rutinas después de haber creado todos los
      // items de alto nivel
      rutines foreach (_.compile)

      program.metadata += new format.meta.SeqItem(meta.srcmap)
    }
  }

  class Rutine [P <: Program] (val program: P, val node: Ast.Proc) {
    val name = node.name
    val rdef = program.program.Rutine(name)
    import rdef.Reg

    val outs = mutable.Buffer[Reg]()

    case class RegItem(reg: Reg) extends Item

    object srcinfo {
      import mutable.ArrayBuffer
      import format.{meta => Meta}
      import Meta.SeqItem
      import Meta.implicits._

      val buffer = new ArrayBuffer[Meta.Item]

      // Instruction Index => (Line, Column)
      val insts = mutable.Map[rdef.Inst, (Int, Int)]()

      // Register Index => (Line, Column, Name)
      val vars = mutable.Map[rdef.Reg, (Int, Int, String)]()

      def compile () {
        buffer += rdef.index
        buffer += SeqItem("name", name)
        buffer += SeqItem("line", node.line)
        buffer += SeqItem("column", node.column)

        buffer += new SeqItem(("regs": Meta.Item) +: vars.map{
          case (reg, (line, column, name)) =>
            SeqItem(reg.index, name, line, column)
        }.toSeq)
        buffer += new SeqItem(("insts": Meta.Item) +: insts.map{
          case (inst, (line, column)) =>
            SeqItem(inst.index, line, column)
        }.toSeq)
        program.meta.rutmap += new SeqItem(buffer)
      }
    }

    class Scope {
      val map = mutable.Map[String, Reg]()

      def get (k: String): Option[Item] =
        map.get(k) map RegItem orElse program.get(k)

      def update (k: String, reg: Reg) { map(k) = reg }

      class SubScope (val parent: Scope) extends Scope {
        override def get (k: String): Option[Item] =
          map.get(k).map(RegItem) orElse parent.get(k)
      }

      def SubScope = new SubScope(this)

      def getRutine (node: Ast.Expr, nargs: Int = -1): program.program.Rutine =
        %%(node) match {
          case program.RutItem(rut) =>
            if (nargs >= 0 && nargs != rut.ins.size)
              node.error(s"Expected ${rut.ins.size} arguments, found $nargs")
            rut
          case _ => node.error("Not a function")
        }

      def %% (node: Ast.Expr): Item = node match {
        case lit: Ast.Literal => program %% lit
        case Ast.Var(nm) => get(nm) getOrElse node.error(s"$nm is undefined")
        case Ast.Field(expr, field) =>
          %%(expr) match {
            case mod: program.Module =>
              mod.get(field) getOrElse node.error(
                s"$field not found in ${mod.name}"
              )
          }
        case Ast.Call(rutexpr, args) =>
          val rutine = getRutine(rutexpr)
          if (rutine.outs.size < 0) node.error("Expresions cannot be void")
          val reg = rdef.Reg(rutine.outs(0))
          val call = rdef.Call(rutine, Array(reg), args map (%%!(_)))
          srcinfo.insts(call) = (node.line, node.column)
          RegItem(reg)
        case Ast.Binop(op, _a, _b) =>
          import program.default._
          val a = %%!(_a)
          val b = %%!(_b)
          val (rutine, rtp) = op match {
            case Ast.Add => 
              (a.t, b.t) match {
                case (`intType`, `intType`) => (iadd, intType)
                case (`strType`, `strType`) => (concat, strType)
              }
            case Ast.Sub => (isub, intType)
            case Ast.Gt  => (igt, boolType)
            case Ast.Gte => (igte, boolType)
            case Ast.Eq  => (ieq, boolType)
            case _ => node.error(
              s"Unknown overload for $op with ${a.t} and ${b.t}"
            )
          }
          val reg = rdef.Reg(rtp)
          val call = rdef.Call(rutine, Array(reg), Array(a, b))
          srcinfo.insts(call) = (node.line, node.column)
          RegItem(reg)
      }

      def %%! (node: Ast.Expr): Reg =
        %%(node) match {
          case RegItem(reg) => reg
          case program.ConstItem(const, tp) =>
            val reg = Reg(tp)
            rdef.Cns(reg, const)
            reg
          case _ => node.error("Unusable expression")
        }

      def %% (node: Ast.Stmt): Unit = node match {
        case Ast.Decl(Ast.Type(tpexp), parts) =>
          val tp = %%(tpexp) match {
            case program.TypeItem(tp) => tp
            case _ => node.error("Not a type")
          }
          for (decl@ Ast.DeclPart(nm, vl) <- parts) {
            val reg = Reg(tp)
            this(nm) = reg
            vl match {
              case Some(expr) =>
                val result = %%!(expr)
                rdef.Cpy(reg, result)
              case None =>
            }
            srcinfo.vars(reg) = (node.line, node.column, nm)
          }
        case Ast.Call(rutexpr, args) =>
          val rutine = getRutine(rutexpr, args.size)
          var call = rdef.Call(rutine, Nil, args map (%%!(_)))
          srcinfo.insts(call) = (node.line, node.column)
        case Ast.Assign(nm, expr) =>
          val reg = get(nm) match {
            case Some(RegItem(reg)) => reg
            case _ => node.error(s"$nm is not a variable")
          }
          val result = %%!(expr)
          val inst = rdef.Cpy(reg, result)
          srcinfo.insts(inst) = (node.line, node.column)
        case Ast.Multi(_ls, Ast.Call(rutexpr, args)) =>
          val rutine = getRutine(rutexpr, args.size)
          val ls = _ls map {nm => get(nm) match {
            case Some(RegItem(reg)) => reg
            case _ => node.error(s"$nm is not a variable")
          } }
          val rs = args map (%%!(_))
          var call = rdef.Call(rutine, ls, rs)
          srcinfo.insts(call) = (node.line, node.column)
        case Ast.Multi(_, _) =>
          node.error("Multiple assignment only works with function calls")
        case Ast.Block(stmts) =>
          val scope = SubScope
          stmts foreach (scope %% _)
        case Ast.While(cond, body) =>
          val $start = rdef.Lbl
          val $end = rdef.Lbl

          rdef.Ilbl($start)
          val $cond = %%!(cond)
          rdef.Ifn($end, $cond)

          %%(body)

          rdef.Jmp($start)
          rdef.Ilbl($end)
        case Ast.If(cond, body, orelse) =>
          val $else = rdef.Lbl
          val $end  = rdef.Lbl

          val $cond = %%!(cond)
          rdef.Ifn($else, $cond)

          %%(body)

          rdef.Jmp($end)
          rdef.Ilbl($else)
          orelse match {
            case Some(body) => %%(body)
            case None =>
          }
          rdef.Ilbl($end)
        case Ast.Return(exprs) =>
          val outs = Rutine.this.outs
          if (exprs.size != outs.size) node.error(
            s"Expected ${outs.size} return values, found ${exprs.size}"
          )
          for ( (reg, expr) <- outs zip exprs ) {
            val result = %%!(expr)
            rdef.Cpy(reg, result)
          }
          rdef.End()
      }
    }

    val topScope = new Scope

    for ((tp, name) <- node.params ) {
      val reg = rdef.InReg( program.getType(tp) )
      topScope(name) = reg
    }

    for (tp <- node.returns)
      outs += rdef.OutReg( program.getType(tp) )

    def compile () {
      node.body.stmts map (topScope %% _)
      srcinfo.compile()
    }
  }

  class Module [P <: Program] (
    val program: P,
    val name: String,
    val params: Seq[Ast.Expr])
    extends Item {

    import program.{Proto, program => prg}

    var alias = ""
    var inScope = false

    lazy val module = prg.Module(name, Nil)

    // Scala no me deja!
    //import prg.{Rutine, Type}

    object rutines {
      val protos = mutable.Map[String, Proto]()
      val map = mutable.Map[String, prg.Rutine]()

      def apply (name: String): Option[prg.Rutine] =
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
      val map = mutable.Map[String, prg.Type]()

      def get (name: String) = map get name
      def apply (name: String) = map get name match {
        case Some(tp) => tp
        case None =>
          val tp = module.Type(name)
          map(name) = tp; tp
      }
    }

    def get (k: String): Option[Item] =
      rutines(k).map(program.RutItem) orElse
      types.get(k).map(program.TypeItem)
  }

  def compile (prg: Ast.Program): format.Program = {
    val program = new Program
    //for (stmt <- prg.stmts) program %% stmt
    program.compile(prg.stmts)
    program.program
  }
}