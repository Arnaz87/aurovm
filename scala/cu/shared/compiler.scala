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
    val constants = mutable.Map[String, ConstItem]()

    case class TypeItem (tp: program.Type) extends Item
    case class RutItem (rut: program.Function) extends Item
    case class ConstItem (cns: program.Static, tp: program.Type) extends Item

    case class Proto(ins: Seq[program.Type], outs: Seq[program.Type])

    def Module(name: String, params: Seq[Ast.Expr]) = {
      val mod = new Module(this, name, params)
      modules += mod; mod
    }

    // `object default` es Lazy, pero necesito que los módulos se evalúen
    val default = new Object {
      val prims = Module("cobre.prim", Nil)
      val core = Module("cobre.core", Nil)
      val strmod = Module("cobre.string", Nil)
      val sysmod = Module("cobre.system", Nil)

      val binaryType = core.types("bin")
      val boolType = core.types("bool")
      val intType = prims.types("int")
      val strType = strmod.types("string")

      prims.rutines ++= Map(
        "iadd" -> Proto( Array(intType, intType), Array(intType) ),
        "isub" -> Proto( Array(intType, intType), Array(intType) ),
        "ieq"  -> Proto( Array(intType, intType), Array(boolType) ),
        "igt"  -> Proto( Array(intType, intType), Array(boolType) ),
        "igte" -> Proto( Array(intType, intType), Array(boolType) )
      )

      def iadd = prims.rutines("iadd").get
      def isub = prims.rutines("isub").get
      def ieq  = prims.rutines("ieq").get
      def igt  = prims.rutines("igt").get
      def igte = prims.rutines("igte").get

      strmod.rutines ++= Map(
        "new" -> Proto( Array(binaryType), Array(strType) ),
        //"concat" -> Proto( Array(strType, strType), Array(strType) ),
        //"itos" -> Proto( Array(intType), Array(strType) )
      )

      def makestr = strmod.rutines("new").get
      //def concat = strmod.rutines("concat").get

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

      val srcpos = new ArrayBuffer[Meta.Node]()
      val srcnames = new ArrayBuffer[Meta.Node]()

      program.metadata += new Meta.SeqNode(srcpos)
      program.metadata += new Meta.SeqNode(srcnames)

      val srcmap = new ArrayBuffer[Meta.Node]()
      srcmap += "source map"
      val rutmap = new ArrayBuffer[Meta.Node]()
      rutmap += "rutines"
      srcmap += new Meta.SeqNode(rutmap)
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

      ( constants.get(name) orElse // Constantes
        rutines. // Rutinas de este módulo
          find(_.name == name).
          map(_.rdef).map(RutItem) orElse
        types.get(name).map(TypeItem) orElse // tipos de este módulo
        items.headOption orElse // rutinas o tipos en otros módulos
        modules.find(_.alias == name) orElse // modulos con el nombre
        default(name) ) // builtins (string, true, null, etc..)
    }

    def %% (node: Ast.Expr): Item = node match {
      case Ast.Num(dbl) =>
        val int = dbl.asInstanceOf[Int]
        val const = program.IntStatic(int)
        ConstItem(const, default.intType)
      case Ast.Str(str) =>
        val bytes = str.getBytes("UTF-8")
        val bin = program.BinStatic(
          bytes map (_.asInstanceOf[Int])
        )
        val const = program.NullStatic(default.strType)

        val reg = program.StaticCode.Sgt(bin).reg
        val call = program.StaticCode.Call(default.makestr, Array(reg))
        program.StaticCode.Sst(const, call.regs(0))

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

    def %%! (node: Ast.Expr): program.Static = {
      %%(node) match {
        case ConstItem(const, _) => const
        case TypeItem(tp) => program.TypeStatic(tp)
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
          val modname = names mkString "."//"\u001f"
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

      for (node@Ast.Const(Ast.Type(tpexp), name, expr) <- stmts) {
        val tp = %%(tpexp) match {
          case TypeItem(tp) => tp
          case _ => node.error("Not a type")
        }
        constants(name) = ConstItem(%%!(expr), tp)
      }

      //modules foreach (_.computeParams)

      // Solo compilar las rutinas después de haber creado todos los
      // items de alto nivel
      rutines foreach (_.compile)

      program.StaticCode.End(Nil)

      program.metadata += new format.meta.SeqNode(meta.srcmap)
    }
  }

  class Rutine [P <: Program] (val program: P, val node: Ast.Proc) {
    val name = node.name

    val rdef = program.program.FunctionDef(
      for ((tp, _) <- node.params) yield program.getType(tp),
      for (tp <- node.returns) yield program.getType(tp)
    )

    program.program.export(name, rdef)
    
    import rdef.Reg

    val outs = mutable.Buffer[Reg]()

    case class RegItem(reg: Reg) extends Item

    object srcinfo {
      import mutable.ArrayBuffer
      import format.{meta => Meta}
      import Meta.SeqNode
      import Meta.implicits._

      val buffer = new ArrayBuffer[Meta.Node]

      // Instruction Index => (Line, Column)
      val insts = mutable.Map[rdef.Inst, (Int, Int)]()

      // Register Index => (Line, Column, Name)
      val vars = mutable.Map[rdef.Reg, (Int, Int, String)]()

      def compile () {
        buffer += rdef.index
        buffer += SeqNode("name", name)
        buffer += SeqNode("line", node.line)
        buffer += SeqNode("column", node.column)

        buffer += new SeqNode(("regs": Meta.Node) +: vars.map{
          case (reg, (line, column, name)) =>
            SeqNode(reg.index, name, line, column)
        }.toSeq)
        buffer += new SeqNode(("insts": Meta.Node) +: insts.map{
          case (inst, (line, column)) =>
            SeqNode(inst.index, line, column)
        }.toSeq)
        program.meta.rutmap += new SeqNode(buffer)
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

      def getRutine (node: Ast.Expr, nargs: Int = -1): program.program.Function =
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
          val call = rdef.Call(rutine, args map (%%!(_)))
          val reg = call.regs(0)
          srcinfo.insts(call) = (node.line, node.column)
          RegItem(reg)
        case Ast.Binop(op, _a, _b) =>
          import program.default._
          val a = %%!(_a)
          val b = %%!(_b)
          val (rutine, rtp) = op match {
            case Ast.Add => (iadd, intType)
              /*(a.t, b.t) match {
                case (`intType`, `intType`) => (iadd, intType)
                case (`strType`, `strType`) => (concat, strType)
              }*/
            case Ast.Sub => (isub, intType)
            case Ast.Gt  => (igt, boolType)
            case Ast.Gte => (igte, boolType)
            case Ast.Eq  => (ieq, boolType)
            case _ => node.error(
              s"Unknown overload for $op" //"with ${a.t} and ${b.t}"
            )
          }
          //val reg = rdef.Reg(rtp)
          val call = rdef.Call(rutine, Array(a, b))
          val reg = call.regs(0)
          srcinfo.insts(call) = (node.line, node.column)
          RegItem(reg)
      }

      def %%! (node: Ast.Expr): Reg =
        %%(node) match {
          case RegItem(reg) => reg
          case program.ConstItem(const, tp) =>
            val sgt = rdef.Sgt(const)
            sgt.reg
          case _ => node.error("Unusable expression")
        }

      def %% (node: Ast.Stmt): Unit = node match {
        case Ast.Decl(Ast.Type(tpexp), parts) =>
          val tp = %%(tpexp) match {
            case program.TypeItem(tp) => tp
            case _ => node.error("Not a type")
          }
          for (decl@ Ast.DeclPart(nm, vl) <- parts) {
            val reg = rdef.Var().reg
            this(nm) = reg
            vl match {
              case Some(expr) =>
                val result = %%!(expr)
                rdef.Set(reg, result)
              case None =>
            }
            srcinfo.vars(reg) = (node.line, node.column, nm)
          }
        case Ast.Call(rutexpr, args) =>
          val rutine = getRutine(rutexpr, args.size)
          var call = rdef.Call(rutine, args map (%%!(_)))
          srcinfo.insts(call) = (node.line, node.column)
        case Ast.Assign(nm, expr) =>
          val reg = get(nm) match {
            case Some(RegItem(reg)) => reg
            case _ => node.error(s"$nm is not a variable")
          }
          val result = %%!(expr)
          val inst = rdef.Set(reg, result)
          srcinfo.insts(inst) = (node.line, node.column)
        case Ast.Multi(_ls, Ast.Call(rutexpr, args)) =>
          val rutine = getRutine(rutexpr, args.size)
          val ls = _ls map {nm => get(nm) match {
            case Some(RegItem(reg)) => reg
            case _ => node.error(s"$nm is not a variable")
          } }
          val rs = args map (%%!(_))
          var call = rdef.Call(rutine, rs)
          for (i <- 0 until args.size)
            rdef.Set(ls(i), call.regs(i))
          srcinfo.insts(call) = (node.line, node.column)
        case Ast.Multi(_, _) =>
          node.error("Multiple assignment only works with function calls")
        case Ast.Block(stmts) =>
          val scope = SubScope
          stmts foreach (scope %% _)
        case Ast.While(cond, body) =>
          val $start = rdef.Lbl()
          val $end = rdef.Lbl()

          $start.create()
          val $cond = %%!(cond)
          rdef.Nif($end, $cond)

          %%(body)

          rdef.Jmp($start)
          $end.create()
        case Ast.If(cond, body, orelse) =>
          val $else = rdef.Lbl()
          val $end  = rdef.Lbl()

          val $cond = %%!(cond)
          rdef.Nif($else, $cond)

          %%(body)

          rdef.Jmp($end)
          $else.create()
          orelse match {
            case Some(body) => %%(body)
            case None =>
          }
          $end.create()
        case Ast.Return(exprs) =>
          val outs = Rutine.this.outs
          if (exprs.size != outs.size) node.error(
            s"Expected ${outs.size} return values, found ${exprs.size}"
          )
          val args = for (expr <- exprs) yield %%!(expr)
          rdef.End(args)
      }
    }

    val topScope = new Scope

    /*for ((tp, name) <- node.params ) {
      val reg = rdef.InReg( program.getType(tp) )
      topScope(name) = reg
    }

    for (tp <- node.returns)
      outs += rdef.OutReg( program.getType(tp) )*/

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

    lazy val module = prg.Import(name, params.size > 0)

    // Scala no me deja!
    //import prg.{Function, Type}

    object rutines {
      val protos = mutable.Map[String, Proto]()
      val map = mutable.Map[String, prg.Function]()

      def apply (name: String): Option[prg.Function] =
        map get name match {
          case Some(rut) => Some(rut)
          case None => protos get name match {
            case Some(Proto(ins, outs)) =>
              val rut = module.Function(name, ins, outs)
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

    /*def computeParams () {
      for (p <- params) module.params += program %%! p
    }*/
  }

  def compile (prg: Ast.Program): format.Program = {
    val program = new Program
    //for (stmt <- prg.stmts) program %% stmt
    program.compile(prg.stmts)
    program.program
  }
}