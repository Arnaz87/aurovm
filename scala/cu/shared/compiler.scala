package arnaud.culang

import arnaud.cobre
import collection.mutable


class CompileError(msg: String, node: Ast.Node) extends Exception (
  if (node.hasSrcpos) s"$msg. At line ${node.line + 1} column ${node.column}" else msg
)

package object compiler {
  implicit class NodeOps (node: Ast.Node) {
    def error(msg: String): Nothing = throw new CompileError(msg, node)
  }

  sealed abstract class Item

  class Program (filename: String) {
    type Module = compiler.Module[this.type]
    type Rutine = compiler.Rutine[this.type]

    val program = new cobre.Program()
    val modules = mutable.Set[Module]()
    val rutines = mutable.Set[Rutine]()
    //val types = mutable.Map[String, program.Type]()
    val constants = mutable.Map[String, ConstItem]()
    val aliases = mutable.Map[String, Item]()

    val methods = mutable.Map[(program.Type, String), program.Function]()
    val getters = mutable.Map[(program.Type, String), program.Function]()
    val setters = mutable.Map[(program.Type, String), program.Function]()
    val casts = mutable.Map[(program.Type, program.Type), program.Function]()

    sealed abstract class TypeItem extends Item { def tp: program.Type }
    case class RawTypeItem (tp: program.Type) extends TypeItem
    class ModTypeItem (module: Module, name: String) extends TypeItem {
      def tp: program.Type = module.types(name)
    }
    object TypeItem {
      def apply (tp: program.Type): TypeItem = RawTypeItem(tp)
      def unapply (item: TypeItem): Option[program.Type] = Some(item.tp)
    }

    case class RutItem (rut: program.Function) extends Item
    case class ConstItem (cns: program.Static, tp: program.Type) extends Item
    //abstract class PromiseItem extends Item { def get(): Item }

    case class Proto(ins: Seq[program.Type], outs: Seq[program.Type])

    def Module(name: String, params: Seq[Ast.Expr]) = {
      val mod = new Module(this, name, params)
      modules += mod; mod
    }

    // `object default` es Lazy, pero necesito que los módulos se evalúen
    val default = new Object {
      val intmod = Module("cobre.int", Nil)
      val core = Module("cobre.core", Nil)
      val strmod = Module("cobre.string", Nil)
      val fltmod = Module("cobre.float", Nil)
      //val sysmod = Module("cobre.system", Nil)

      val binaryType = core.types("bin")
      val boolType = core.types("bool")
      val intType = intmod.types("int")
      val fltType = fltmod.types("float")
      val strType = strmod.types("string")
      val charType = strmod.types("char")

      intmod.rutines ++= Map(
        "neg" -> Proto( Array(intType), Array(intType) ),
        "signed" -> Proto( Array(intType), Array(intType) ),
        "add" -> Proto( Array(intType, intType), Array(intType) ),
        "sub" -> Proto( Array(intType, intType), Array(intType) ),
        "mul" -> Proto( Array(intType, intType), Array(intType) ),
        "div" -> Proto( Array(intType, intType), Array(intType) ),
        "eq"  -> Proto( Array(intType, intType), Array(boolType) ),
        "gt"  -> Proto( Array(intType, intType), Array(boolType) ),
        "gte" -> Proto( Array(intType, intType), Array(boolType) ),
        "lt"  -> Proto( Array(intType, intType), Array(boolType) ),
        "lte" -> Proto( Array(intType, intType), Array(boolType) ),
      )

      fltmod.rutines ++= Map(
        "add" -> Proto( Array(fltType, fltType), Array(fltType) ),
        "sub" -> Proto( Array(fltType, fltType), Array(fltType) ),
        "mul" -> Proto( Array(fltType, fltType), Array(fltType) ),
        "div" -> Proto( Array(fltType, fltType), Array(fltType) ),
        "eq"  -> Proto( Array(fltType, fltType), Array(boolType) ),
        "gt"  -> Proto( Array(fltType, fltType), Array(boolType) ),
        "gte" -> Proto( Array(fltType, fltType), Array(boolType) ),
        "lt"  -> Proto( Array(fltType, fltType), Array(boolType) ),
        "lte" -> Proto( Array(fltType, fltType), Array(boolType) ),
        "itof"-> Proto( Array(intType), Array(fltType) ),
        "decimal" -> Proto( Array(intType, intType), Array(fltType) ),
      )

      def ineg = intmod.rutines("neg").get
      def iadd = intmod.rutines("add").get
      def isub = intmod.rutines("sub").get
      def imul = intmod.rutines("mul").get
      def idiv = intmod.rutines("div").get
      def ieq  = intmod.rutines("eq").get
      def igt  = intmod.rutines("gt").get
      def igte = intmod.rutines("gte").get
      def ilt  = intmod.rutines("lt").get
      def ilte = intmod.rutines("lte").get
      def isigned = intmod.rutines("signed").get

      def fadd = fltmod.rutines("add").get
      def fsub = fltmod.rutines("sub").get
      def fmul = fltmod.rutines("mul").get
      def fdiv = fltmod.rutines("div").get
      def feq  = fltmod.rutines("eq").get
      def fgt  = fltmod.rutines("gt").get
      def fgte = fltmod.rutines("gte").get
      def flt  = fltmod.rutines("lt").get
      def flte = fltmod.rutines("lte").get
      def fdecimal = fltmod.rutines("decimal").get

      strmod.rutines ++= Map(
        "new" -> Proto( Array(binaryType), Array(strType) ),
        "concat" -> Proto( Array(strType, strType), Array(strType) ),
        "eq" -> Proto( Array(strType, strType), Array(boolType) ),
      )

      def newstr = strmod.rutines("new").get
      def concat = strmod.rutines("concat").get
      def streq  = strmod.rutines("eq").get

      /*sysmod.rutines ++= Map(
        "print" -> Proto( Array(strType), Nil ),
        "clock" -> Proto( Nil, Array(fltType) )
      )*/

      val types = Map(
        "int" -> intType,
        "float" -> fltType,
        "bool" -> boolType,
        "string" -> strType,
        "char" -> charType,
      )

      def apply(nm: String) = types.get(nm) map (TypeItem(_))
    }

    object meta {
      import mutable.ArrayBuffer
      import cobre.{meta => Meta}
      import Meta.implicits._

      val srcmap = ArrayBuffer[Meta.Node](
        "source map", Meta.SeqNode("file", filename)
      )
    }

    def get (name: String): Option[Item] = {
      // Todos los items definidos en módulos en el scope
      lazy val items = for (
        mod <- modules if mod.inScope;
        item <- {
          def tp = mod.types.get(name).map(TypeItem(_))
          def rut = mod.rutines(name).map(RutItem)
          tp orElse rut
        }
      ) yield item

      ( constants.get(name) orElse // Constantes
        rutines. // Rutinas de este módulo
          find(_.name == name).
          map(_.rdef).map(RutItem) orElse
        //types.get(name).map(TypeItem) orElse // tipos de este módulo
        aliases.get(name) orElse // rutinas o tipos con alias
        items.headOption orElse // rutinas o tipos en otros módulos
        modules.find(_.alias == name) orElse // modulos con el nombre
        default(name) ) // builtins (string, true, null, etc..)
    }

    def %% (node: Ast.Expr): Item = node match {
      case Ast.IntLit(int) =>
        val base = program.IntStatic(int.abs)
        val const = if (int >= 0) base else {
          val const = program.NullStatic(default.intType)
          val reg = program.StaticCode.Sgt(base).reg
          val call = program.StaticCode.Call(default.ineg, Array(reg))
          program.StaticCode.Sst(const, call.regs(0))
          const
        }
        ConstItem(const, default.intType)
      case Ast.FltLit(mag, exp) =>
        val magst = program.IntStatic(mag.abs)
        val expst = program.IntStatic(exp.abs)
        val const = program.NullStatic(default.fltType)

        val magreg = {
          val reg = program.StaticCode.Sgt(magst).reg
          if (mag<0)
            program.StaticCode.Call(default.ineg, Array(reg)).regs(0)
          else reg
        }

        val expreg = {
          val reg = program.StaticCode.Sgt(expst).reg
          if (exp<0)
            program.StaticCode.Call(default.ineg, Array(reg)).regs(0)
          else reg
        }

        val call = program.StaticCode.Call(default.fdecimal, Array(magreg, expreg))
        program.StaticCode.Sst(const, call.regs(0))

        ConstItem(const, default.fltType)
      case Ast.Str(str) =>
        val bytes = str.getBytes("UTF-8")
        val bin = program.BinStatic(
          bytes map (_.asInstanceOf[Int])
        )
        val const = program.NullStatic(default.strType)

        val reg = program.StaticCode.Sgt(bin).reg
        val call = program.StaticCode.Call(default.newstr, Array(reg))
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
        val types = mutable.Buffer[(Module, Ast.Typedef)]()
        val funcs = mutable.Buffer[(Module, Ast.Function)]()

        for (stmt@Ast.Import(names, params, alias, defs) <- stmts) {
          val modname = names// mkString "."//"\u001f"
          val hname = names// mkString "."
          val module = modules find { module: Module =>
            (module.name == modname) && (module.params == params)
          } match {
            case None =>
              if (defs.size == 0)
                stmt.error(s"Unknown contents of module $hname")
              Module(modname, params)
            case Some(module) => module
          }

          if (alias.isEmpty) module.inScope = true
          else module.alias = alias.get

          defs foreach {
            case node: Ast.Typedef   => types += ((module, node))
            case node: Ast.Function  => funcs += ((module, node))
          }
        }
      }

      val meths = mutable.Buffer[Rutine]()
      val tps = mutable.Buffer[(Module, Ast.Node)]()

      /*final class Unbased (
        basemod: Module,
        shellmod: Module,
        fields: Seq[Ast.Member],
        name: String
      ) {
        def compile () {
          val tp = shellmod.types("")
          program.export(name, tp)

          val base = basemod.types("")

          var i = 0
          for (Ast.FieldMember(tpexpr, nm) <- fields) {
            val tpfield = getType(tpexpr)
            module.rutines("get" + i) = Proto(Array(base), Array(tpfield))
            module.rutines("set" + i) = Proto(Array(base, tpfield), Nil)
            val getter = module.rutines("get" + i).get
            val setter = module.rutines("set" + i).get
            this.getters((base, nm)) = getter
            this.setters((base, nm)) = setter
            program.export(s"$nm:get:$name", getter)
            program.export(s"$nm:set:$name", setter)
            i += 1
          }

          for (node <- fields) {
            node match {
              case node:Ast.Function =>
                val rut = new Rutine(this, node, true)
                meths += rut
                this.methods((tp, node.name)) = rut.rdef
                program.export(s"${node.name}:$name", rut.rdef)
              case _ =>
            }
          }

          val args = for (Ast.FieldMember(tp, _) <- fields) yield getType(tp)
          module.rutines("new") = Proto(args, Array(tp))
          this.methods((tp, "new")) = module.rutines("new").get
        }
      }
      val unbased = mutable.Buffer[Unbased]*/

      // First of all, internal types
      for (stmt@ Ast.Typedef(name, base, alias, somefields) <- stmts) {
        if (base.isEmpty && somefields.isEmpty) stmt.error("Unbased-type fields are required")

        base match {
          case Some(base) =>
            val params = Array(base.expr)
            val module = Module("cobre.typeshell", params)

            val tItem = new ModTypeItem(module, "")
            aliases(name) = tItem

            tps += ((module, stmt))
          case None => stmt.error("Unbased-types not yet supported")
        }
      }


      for (stmt@ Ast.Struct(name, somefields) <- stmts) {
        if (somefields.isEmpty) stmt.error("Struct fields are required")
        val fields = somefields.get

        val params = for (Ast.FieldMember(Ast.Type(expr), nm) <- fields) yield expr
        val module = Module("cobre.record", params)

        val tItem = new ModTypeItem(module, "")
        aliases(name) = tItem

        tps += ((module, stmt))
      }

      // Imported types
      for (( module, node@Ast.Typedef(name, base, alias, body) ) <- mods.types) {
        if (!base.isEmpty) node.error("Imported types cannot have base types")

        alias match {
          case Some(alias) => aliases(alias) = new ModTypeItem(module, name)
          case None =>
        }
      }

      // Compile internal types
      for ((module, stmt) <- tps) {
        stmt match {
          case Ast.Struct(name, Some(fields)) =>
            val tp = module.types("")
            program.export(name, tp)

            var i = 0
            for (Ast.FieldMember(tpexpr, nm) <- fields) {
              val tpfield = getType(tpexpr)
              module.rutines("get" + i) = Proto(Array(tp), Array(tpfield))
              module.rutines("set" + i) = Proto(Array(tp, tpfield), Nil)
              val getter = module.rutines("get" + i).get
              val setter = module.rutines("set" + i).get
              this.getters((tp, nm)) = getter
              this.setters((tp, nm)) = setter
              program.export(s"$nm:get:$name", getter)
              program.export(s"$nm:set:$name", setter)
              i += 1
            }

            for (node <- fields) {
              node match {
                case node:Ast.Function =>
                  val rut = new Rutine(this, node, true)
                  meths += rut
                  this.methods((tp, node.name)) = rut.rdef
                  program.export(s"${node.name}:$name", rut.rdef)
                case _ =>
              }
            }

            val args = for (Ast.FieldMember(tp, _) <- fields) yield getType(tp)
            module.rutines("new") = Proto(args, Array(tp))
            this.methods((tp, "new")) = module.rutines("new").get
          case Ast.Typedef(name, Some(base), alias, somefields) =>
            val baseT = getType(base)
            val tp = module.types("")

            module.rutines("new") = Proto(Array(baseT), Array(tp))
            module.rutines("get") = Proto(Array(tp), Array(baseT))
            this.casts((baseT, tp)) = module.rutines("new").get
            this.casts((tp, baseT)) = module.rutines("get").get

            if (!somefields.isEmpty)
              stmt.error("Based-type fields not yet supported")
          case _ => ???
        }
      }


      // Imported functions
      for (( module, node@Ast.Function(outs, name, ins, alias, body) ) <- mods.funcs) {
        if (!body.isEmpty) node.error("Imported functions cannot have bodies")

        module.rutines(name) = Proto(
          ins map {case (tp: Ast.Type, nm: String) => getType(tp)},
          outs map {tp: Ast.Type => getType(tp)}
        )
        alias match {
          case Some(alias) => aliases(alias) = RutItem(module.rutines(name).get)
          case _ =>
        }
      }

      // Imported Methods
      for (( module, Ast.Typedef(tpname, _, _, Some(body)) ) <- mods.types) {

        val tp = module.types(tpname)
        val suffix = if (tpname == "") "" else s":$tpname"

        def getnames (basename: String, alias: Option[String]): (String, String) = (
          alias getOrElse basename.split(":")(0),
          basename + suffix
        )

        for (node <- body) node match {
          case Ast.Function(outs, basename, _ins, alias, body) =>
            if (!body.isEmpty) node.error("Imported functions cannot have bodies")
            val ins = tp +: (_ins map {case (tp, _) => getType(tp)})
            val (here, there) = getnames(basename, alias)
            module.rutines(there) = Proto( ins,
              outs map {tp: Ast.Type => getType(tp)}
            )
            val rut = module.rutines(there).get

            if (there.contains(":get:"))
              this.getters((tp, here)) = rut
            else if (there.contains(":set:"))
              this.setters((tp, here)) = rut
            else
              this.methods((tp, here)) = rut
          case Ast.FieldMember(tpexpr, here) =>
            val tpfield = getType(tpexpr)
            val getnm = s"$here:get$suffix"
            val setnm = s"$here:set$suffix"
            module.rutines(getnm) = Proto(Array(tpfield), Array(tp))
            module.rutines(setnm) = Proto(Nil, Array(tp, tpfield))
            this.getters((tp, here)) = module.rutines(getnm).get
            this.setters((tp, here)) = module.rutines(setnm).get
          case Ast.Constructor(args) =>
            module.rutines("new"+suffix) = Proto(args map (getType(_)), Array(tp))
            this.methods((tp, "new")) = module.rutines("new"+suffix).get
        }
      }

      rutines ++= stmts collect {
        case node: Ast.Function =>
          new Rutine(this, node)
      }

      for (node@Ast.Const(Ast.Type(tpexp), name, expr) <- stmts) {
        val tp = %%(tpexp) match {
          case TypeItem(tp) => tp
          case _ => node.error("Not a type")
        }
        constants(name) = ConstItem(%%!(expr), tp)
      }

      modules foreach (_.computeArguments)

      // Solo compilar las rutinas después de haber creado todos los
      // items de alto nivel
      rutines foreach (_.compile)
      meths foreach (_.compile)

      program.StaticCode.End(Nil)

      program.metadata += new cobre.meta.SeqNode(meta.srcmap)
    }
  }

  class Rutine [P <: Program] (val program: P, val node: Ast.Function, val priv:Boolean = false) {
    val name = node.name

    if (node.body.isEmpty) node.error("Function needs a body")

    val rdef = program.program.FunctionDef(
      for ((tp, _) <- node.ins) yield program.getType(tp),
      for (tp <- node.outs) yield program.getType(tp)
    )

    if (!priv) program.program.export(name, rdef)

    import rdef.Reg

    case class RegItem(reg: Reg, tp: program.program.Type) extends Item
    case class MethodItem(reg: Reg, fn: program.program.Function) extends Item

    object srcinfo {
      import mutable.ArrayBuffer
      import cobre.{meta => Meta}
      import Meta.SeqNode
      import Meta.implicits._

      // Instruction Index => (Line, Column)
      val insts = mutable.Map[rdef.Inst, (Int, Int)]()

      // Register Index => (Line, Column, Name)
      val vars = mutable.Map[rdef.Reg, (Int, Int, String)]()

      def compile () {
        val buffer = new ArrayBuffer[Meta.Node]
        buffer += "function"
        buffer += rdef.index
        buffer += SeqNode("name", name)
        buffer += SeqNode("line", node.line)
        buffer += SeqNode("column", node.column)

        buffer += new SeqNode(("regs": Meta.Node) +: vars.map{
          case (reg, (line, column, name)) =>
            SeqNode(reg.index, name, line, column)
        }.toSeq)
        buffer += new SeqNode(("code": Meta.Node) +: insts.map{
          case (inst, (line, column)) =>
            SeqNode(inst.index, line, column)
        }.toSeq)
        program.meta.srcmap += new SeqNode(buffer)
      }
    }

    val labels = mutable.Map[String, rdef.Lbl]()
    def label(name: String) = {
      labels.get(name) match {
        case Some(lbl) => lbl
        case _ =>
          val lbl = rdef.Lbl()
          labels(name) = lbl
          lbl
      }
    }

    class Scope {
      val map = mutable.Map[String, RegItem]()

      def get (k: String): Option[Item] =
        map.get(k) orElse program.get(k)

      def update (k: String, reg: RegItem) { map(k) = reg }

      class SubScope (val parent: Scope) extends Scope {
        override def get (k: String): Option[Item] =
          map.get(k) orElse parent.get(k)
      }

      def SubScope = new SubScope(this)

      def makeCall (fnode: Ast.Expr, args: Seq[Ast.Expr]): (rdef.Call, Seq[program.program.Type]) =
        %%(fnode) match {
          case program.RutItem(fn) =>
            if (args.size != fn.ins.size)
              node.error(s"Expected ${fn.ins.size} arguments, found ${args.size}")
            val regargs = args map (%%!(_).reg)
            (rdef.Call(fn, regargs), fn.outs)
          case MethodItem(self, fn) =>
            if (args.size != fn.ins.size-1)
              node.error(s"Expected ${fn.ins.size-1} arguments, found ${args.size}")
            val regargs = args map (%%!(_).reg)
            (rdef.Call(fn, self +: regargs), fn.outs)
          case _ => node.error("Not a function or method")
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
            case RegItem(reg, tp) =>
              program.getters.get(tp, field) match {
                case Some(fn) =>
                  val call = rdef.Call(fn, Array(reg))
                  srcinfo.insts(call) = (node.line, node.column)
                  RegItem(call.regs(0), fn.outs(0))
                case None =>
                  program.methods.get(tp, field) match {
                    case Some(fn) => MethodItem(reg, fn)
                    case None => node.error(s"$field method/getter not found")
                  }
              }
            case _ => node.error("Expression is neither a module, method or field")
          }
        case Ast.Cast(_expr, tpexpr) =>
          val expr = %%!(_expr)
          val source = expr.tp
          val target = program.getType(tpexpr)
          program.casts.get(source, target) match {
            case Some(fn) =>
              val call = rdef.Call(fn, Array(expr.reg))
              srcinfo.insts(call) = (node.line, node.column)
              RegItem(call.regs(0), target)
          }
        case Ast.Index(basexp, iexpr) =>
          var index = %%!(iexpr)
          var base = %%!(basexp)
          program.methods.get(base.tp, "get") match {
            case Some(fn) =>
              val call = rdef.Call(fn, Array(base.reg, index.reg))
              srcinfo.insts(call) = (node.line, node.column)
              RegItem(call.regs(0), fn.outs(0))
            case None => basexp.error("get method not found")
          }
        case Ast.New(expr, args) =>
          val tp = program.getType(expr)
          program.methods.get(tp, "new") match {
            case Some(fn) =>
              val call = rdef.Call(fn, args map (%%!(_).reg))
              srcinfo.insts(call) = (node.line, node.column)
              RegItem(call.regs(0), fn.outs(0))
            case None => node.error("new method not found")
          }
        case Ast.Call(rutexpr, args) =>
          val (call, outs) = makeCall(rutexpr, args)
          if (outs.size < 1) node.error("Expresions cannot be void")
          srcinfo.insts(call) = (node.line, node.column)
          RegItem(call.regs(0), outs(0))
        case Ast.Binop(op, _a, _b) =>
          import program.default._
          val a = %%!(_a)
          val b = %%!(_b)
          val (rutine, rtp) = (op, a.tp, b.tp) match {
            case (Ast.Add, `intType`, `intType`) => (iadd, intType)
            case (Ast.Add, `fltType`, `fltType`) => (fadd, fltType)
            case (Ast.Add, `strType`, `strType`) => (concat, strType)
            case (Ast.Sub, `intType`, `intType`) => (isub, intType)
            case (Ast.Sub, `fltType`, `fltType`) => (fsub, fltType)
            case (Ast.Mul, `intType`, `intType`) => (imul, intType)
            case (Ast.Mul, `fltType`, `fltType`) => (fmul, fltType)
            case (Ast.Div, `intType`, `intType`) => (idiv, intType)
            case (Ast.Div, `fltType`, `fltType`) => (fdiv, fltType)
            case (Ast.Gt , `intType`, `intType`) => (igt, boolType)
            case (Ast.Gt , `fltType`, `fltType`) => (fgt, boolType)
            case (Ast.Gte, `intType`, `intType`) => (igte, boolType)
            case (Ast.Gte, `fltType`, `fltType`) => (fgte, boolType)
            case (Ast.Lt , `intType`, `intType`) => (ilt, boolType)
            case (Ast.Lt , `fltType`, `fltType`) => (flt, boolType)
            case (Ast.Lte, `intType`, `intType`) => (ilte, boolType)
            case (Ast.Lte, `fltType`, `fltType`) => (flte, boolType)
            case (Ast.Eq , `intType`, `intType`) => (ieq, boolType)
            case (Ast.Eq , `fltType`, `fltType`) => (feq, boolType)
            case (Ast.Eq , `strType`, `strType`) => (streq, boolType)
            case (op, at, bt) => node.error(
              s"Unknown overload for $op"// with ${at} and ${bt}"
            )
          }
          //val reg = rdef.Reg(rtp)
          val call = rdef.Call(rutine, Array(a.reg, b.reg))
          val reg = call.regs(0)
          srcinfo.insts(call) = (node.line, node.column)
          RegItem(reg, rtp)
      }

      def %%! (node: Ast.Expr): RegItem =
        %%(node) match {
          case reg: RegItem => reg
          case program.ConstItem(const, tp) =>
            val sgt = rdef.Sgt(const)
            RegItem(sgt.reg, tp)
          case _ => node.error("Unusable expression")
        }

      def %% (node: Ast.Stmt): Unit = node match {
        case Ast.Decl(Ast.Type(tpexp), parts) =>
          val tp = %%(tpexp) match {
            case program.TypeItem(tp) => tp
            case _ => node.error("Not a type")
          }
          for (decl@ Ast.DeclPart(nm, vl) <- parts) {
            val item = vl match {
              case Some(expr) => %%!(expr)
              case None =>
                val reg = rdef.Var().reg
                RegItem(reg, tp)
            }
            this(nm) = item
            srcinfo.vars(item.reg) = (node.line, node.column, nm)
          }
        case Ast.Call(rutexpr, args) =>
          var (call, _) = makeCall(rutexpr, args)
          srcinfo.insts(call) = (node.line, node.column)
        case Ast.Assign(left, expr) =>
          val result = %%!(expr)
          left match {
            case Ast.Field(basexp, field) =>
              %%!(basexp) match {
                case RegItem(reg, tp) =>
                  program.setters.get(tp, field) match {
                    case Some(fn) =>
                      val call = rdef.Call(fn, Array(reg, result.reg))
                      srcinfo.insts(call) = (node.line, node.column)
                    case None => node.error(s"$field setter not found")
                  }
              }
            case Ast.Index(basexp, iexpr) =>
              val index = %%!(iexpr)
              val base = %%!(basexp)
              program.methods.get(base.tp, "set") match {
                case Some(fn) =>
                  val call = rdef.Call(fn, Array(base.reg, index.reg, result.reg))
                  srcinfo.insts(call) = (node.line, node.column)
                case None => basexp.error("set method not found")
              }
            case Ast.Var(nm) =>
              val reg = get(nm) match {
                case Some(RegItem(reg, _)) => reg
                case _ => node.error(s"$nm is not a variable")
              }
              val inst = rdef.Set(reg, result.reg)
              srcinfo.insts(inst) = (node.line, node.column)
          }
        case Ast.Multi(_ls, Ast.Call(rutexpr, args)) =>
          val (call, outs) = makeCall(rutexpr, args)
          if (_ls.size != outs.size)
            node.error(s"Expected ${_ls.size} results, got ${outs.size}")
          val ls = _ls map {nm => get(nm) match {
            case Some(RegItem(reg, _)) => reg
            case _ => node.error(s"$nm is not a variable")
          } }
          for (i <- 0 until outs.size)
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
          rdef.Nif($end, $cond.reg)

          %%(body)

          rdef.Jmp($start)
          $end.create()
        case Ast.If(cond, body, orelse) =>
          val $else = rdef.Lbl()
          val $end  = rdef.Lbl()

          val $cond = %%!(cond)
          rdef.Nif($else, $cond.reg)

          %%(body)

          rdef.Jmp($end)
          $else.create()
          orelse match {
            case Some(body) => %%(body)
            case None =>
          }
          $end.create()
        case Ast.Label(name) => label(name).create()
        case Ast.Goto(name) => rdef.Jmp(label(name))
        case Ast.Return(exprs) =>
          val retcount = Rutine.this.node.outs.size
          if (exprs.size != retcount) node.error(
            s"Expected ${retcount} return values, found ${exprs.size}"
          )
          val args = for (expr <- exprs) yield %%!(expr).reg
          rdef.End(args)
      }
    }

    val topScope = new Scope

    for (i <- 0 until node.ins.size)
      topScope(node.ins(i)._2) = RegItem(rdef.inregs(i), rdef.ins(i))

    def compile () {
      node.body.get.stmts map (topScope %% _)
      srcinfo.compile()

      // Implicit return for void functions
      if (node.outs.size == 0)
        rdef.End(Nil)

      //println(rdef.regs mkString " ")
      //for (inst <- rdef.code)
      //  println(inst)
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

    var argument: Option[prg.ModuleDef] = None

    lazy val module = {
      val base = prg.Import(name, params.size > 0)
      if (params.size > 0) {
        val arg = prg.ModuleDef(Map())
        argument = Some(arg)
        prg.ModuleBuild(base, arg)
      } else base
    }

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
      types.get(k).map(program.TypeItem(_))

    def computeArguments () {
      argument match {
        case Some(arg) =>
          var items = mutable.Map[String, prg.Item]()
          for (i <- 0 until params.size)
            items(i.toString) = (program %% params(i)) match {
              case program.TypeItem(tp) => tp
              case program.RutItem(fn) => fn
              case program.ConstItem(cns, tp) => cns
            }
          arg.items = items.toMap
        case None =>
      }
    }
  }

  def compile (prg: Ast.Program, filename: String): cobre.Program = {
    val program = new Program(filename)
    //for (stmt <- prg.stmts) program %% stmt
    program.compile(prg.stmts)
    program.program
  }
}