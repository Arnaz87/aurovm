package arnaud.myvm.codegen

import collection.mutable.{Map, Stack, Buffer, ArrayBuffer, Set}

abstract class Node {}
object Nodes {
  case class Num(n: Double) extends Node
  case class Str(s: String) extends Node
  case class Bool(b: Boolean) extends Node
  case object Nil extends Node

  // Usar una variable que ya esté declarada
  case class Var(name: String) extends Node
  case class Call(func: String, args: Seq[Node]) extends Node
  case class NmCall(func: String, args: Seq[(String, Node)], field: Option[String]) extends Node

  // Declarar una variable local, oculta a cualquiera que ya exista
  case class Declare(name: String) extends Node
  // Declarar una variable global, puede ser ocultada
  case class DeclareGlobal(name: String) extends Node

  // Ejecuta el nodo si el nombre no esta declarado
  // Útil para lenguajes dinámicos que no tienen declaraciones,
  // y solo tienen asignaciones
  case class Undeclared(name: String, nd: Node) extends Node

  // Asigna una variable, devuelve la variable asignada
  case class Assign(l: String, r: Node) extends Node

  // Ejecuta varios nodos en secuencia, devuelve el valor del último
  case class Block(nodes: Seq[Node]) extends Node

  // Crea un nuevo scope para el nodo interno
  case class Scope(block: Node) extends Node

  case class While(cond: Node, body: Node) extends Node
  case class If(cond: Node, body: Node, orelse: Node) extends Node

  case class Narr(body: Seq[Node]) extends Node

  case class TypeSet(name: String, nd: Node) extends Node
  case class Import(mod: String, field: String) extends Node
  case class Proc(params: Seq[String], body: Node) extends Node

  def sexpr (nd: Node): arnaud.sexpr.Node = {
    import arnaud.sexpr._
    import arnaud.sexpr.Implicits._
    type SNode = arnaud.sexpr.Node

    nd match {
      case Num(n) => ListNode("Num", n.toString)
      case Str(s) => ListNode("Str", s)
      case Bool(b) => ListNode("Bool", b.toString)
      case Nil => ListNode("Nil")

      case Var(nm) => ListNode("Var", nm)
      case NmCall(func, args, field) =>
        val nodes = new ArrayBuffer[SNode](8)
        nodes += "Call"
        nodes += func
        args foreach {
          case (nm, vl) =>
            nodes += ListNode(nm, sexpr(vl))
        }
        nodes += AtomNode(field getOrElse "nil")
        new ListNode(nodes)
      case Assign(nm, nd) => ListNode("Assign", nm, sexpr(nd))
      case Block(nds) => new ListNode(AtomNode("Block") +: (nds map (sexpr _)))
      case Scope(blck) => ListNode("Scope", sexpr(blck))
      case Declare(nm) => ListNode("Declare", nm)

      case TypeSet(nm, nd) => ListNode("TypeSet", nm, sexpr(nd))
      case Proc(ps, bd) => ListNode("Proc", new ListNode(ps map {new AtomNode(_)}), sexpr(bd))

      case While(cond, body) => ListNode("While", sexpr(cond), sexpr(body))
      case If(cond, body, orelse) => ListNode("If", sexpr(cond), sexpr(body), sexpr(orelse))

      case x => ListNode(x.toString)
    }
  }

  def get (st: State, nd: Node): RegInfo = {
    nd match {
      case Num(n) => st.addConstant(n)
      case Str(s) => st.addConstant(s)
      case Bool(b) => st.addConstant(b)
      case Declare(nm) =>
        val reg = st.newReg(nm)
        st.scopes(nm) = reg
        reg
      case DeclareGlobal(nm) =>
        val reg = st.newReg(nm)
        st.scopes.bottom(nm) = reg
        reg
      case Block(nodes) =>
        nodes.foreach( get(st, _) )
        RegInfo.nil
      case Assign(nm, _r) =>
        val l = st.scopes(nm)
        val r = get(st, _r)
        st.code += Inst.Cpy(l.realname, r.realname)
        l
      // Este call por ahora funciona, pero es incorrecto.
      // Las funciones no necesariamente van arecibir argumentos nombrados
      // con letras desde la 'a' ni van a devolver un solo resultado 'r'.
      case Call(func, args) =>
        var aChar = 'a'
        st.code += Inst.New(func)
        args.foreach{ _arg =>
          val arg = get(st, _arg)
          st.code += Inst.Set(func, aChar.toString, arg.realname)
          aChar = (aChar + 1).toChar
        }
        st.code += Inst.Call(func)
        val reg = st.newReg("r")
        st.code += Inst.Get(reg.realname, func, "r")
        reg
      case NmCall(func, args, field) =>
        st.code += Inst.New(func)
        args.foreach{ case (argnm, _arg) =>
          val arg = get(st, _arg)
          st.code += Inst.Set(func, argnm, arg.realname)
        }
        st.code += Inst.Call(func)
        RegInfo.nil
      case Var(nm) => st.scopes(nm)
      case Scope(block) =>
        st.scopes.push()
        get(st, block)
      case Undeclared(nm, node) =>
        st.scopes get nm match {
          case None => get(st, node)
          case _ => RegInfo.nil
        }
      case While(cond, body) =>
        val $start = st.getLabel()
        val $end = st.getLabel()
        st.code += Inst.Lbl($start)
        val $cond = get(st, cond)
        st.code += Inst.Ifn($end, $cond.realname)
        val $body = get(st, body)
        st.code += Inst.Jmp($start)
        st.code += Inst.Lbl($end)
        $body
      case If(cond, body, orelse) =>
        val $else = st.getLabel()
        val $end  = st.getLabel()
        val $cond = get(st, cond)
        st.code += Inst.Ifn($else, $cond.realname)
        get(st, body)
        st.code += Inst.Jmp($end)
        st.code += Inst.Lbl($else)
        get(st, orelse)
        st.code += Inst.Lbl($end)
        RegInfo.nil
      //case _ => RegInfo.nil
    }
  }
}

sealed abstract class Inst
object Inst {
  case class Cpy(a: String, b: String) extends Inst
  case class Get(a: String, o: String, k: String) extends Inst
  case class Set(o: String, k: String, b: String) extends Inst
  case class New(f: String) extends Inst
  case class Call(f: String) extends Inst

  case class Lbl(l: String) extends Inst
  case class Jmp(l: String) extends Inst
  case class If (l: String, a: String) extends Inst
  case class Ifn(l: String, a: String) extends Inst
}



class RegInfo (
  val realname: String,
  val regtype: RegType = RegInfo.Local
) {
  override def toString() = s"RegInfo($realname)"
}
// class ConstantReg(rnm: String) extends RegInfo(rnm)
// Para tipos: Constant, Local, Closure

sealed abstract class RegType
object RegInfo {
  case object Local extends RegType
  case object Constant extends RegType
  // TODO: Soporte para closuras
  //case object Closure extends RegType

  val nil= new RegInfo("$nil")
}

class State {
  object scopes {
    type Scope = Map[String, RegInfo]

    val stack: Stack[Scope] = Stack(Map())
    def push() { stack.push(Map()) }
    def pop() { stack.pop() }
    def get (k: String): Option[RegInfo] = {
      stack.find{_.contains(k)}.map{_ apply k}
    }
    def apply(k: String): RegInfo =
      get(k) match {
        case Some(reg) => reg
        case None => throw new java.util.NoSuchElementException(s"Reg $k not found")
      }
    def update(k: String, v: RegInfo) = { stack.top(k) = v; v }

    object bottom {
      private def bt = stack.last
      def get (k: String): Option[RegInfo] =
        if (bt.contains(k)) { Some(bt(k)) } else { None }
      def apply (k: String): RegInfo = get(k) match {
        case Some(reg) => reg
        case None => throw new java.util.NoSuchElementException(s"Bottom Reg $k not found")
      }
      def update (k: String, v: RegInfo) { bt(k) = v }
    }
  }
  val constants: Map[String, Any] = Map()

  val functions: Buffer[String] = new ArrayBuffer()
  val regs: Buffer[String] = new ArrayBuffer()
  val imports: Map[String, (String, String)] = Map()

  val varCounts: Map[String, Int] = Map()
  var constantCount: Int = 0
  var labelCount: Int = 0

  val code: Buffer[Inst] = new ArrayBuffer[Inst]()

  def addFunction(name: String) {
    functions += name
  }

  def addImport(name: String, module: String, field: String) = {
    imports(name) = (module, field)
  }

  def addConstant(value: Any): RegInfo = {
    constantCount += 1
    val nm = "$const$" + constantCount
    constants(nm) = value
    code += Inst.Get(nm, "SELF", nm)
    new RegInfo(nm)
  }
  def newReg(inm: String): RegInfo = {
    val count = varCounts get inm match {
      case Some(cnt) => { varCounts(inm) = cnt+1; cnt }
      case None => { varCounts(inm) = 0; 1 }
    }
    val nm = inm + "$" + count
    regs += nm
    new RegInfo(nm)
  }

  def getLabel(): String = {
    labelCount += 1
    "lbl_" + labelCount
  }

  def process(ast: Node) = {
    try {
      Nodes.get(this, ast)
    } catch {
      case e: Exception  =>
        e.printStackTrace()
        println("Current Scopes:")
        println(scopes.stack)
        println("Generated Code:")
        println(code)
        throw new Exception("Error processing the AST")
    }
  }


  def compile(): arnaud.sexpr.Node = {
    import arnaud.sexpr._
    import arnaud.sexpr.Implicits._
    type Node = arnaud.sexpr.Node

    // Estos dos tipos son necesarios por ahora...
    addImport("Any", "Prelude", "Any")
    addImport("Empty", "Prelude", "Empty")

    val mods: Set[String] = Set()
    val modules: Buffer[Node] = ArrayBuffer("Imports")
    val imported: Buffer[Node] = ArrayBuffer("Types")
    val constNode: Buffer[Node] = ArrayBuffer("Constants")

    val selfType: Buffer[Node] = ArrayBuffer("SELF")
    val regsType: Buffer[Node] = ArrayBuffer("main-regs")
    val codeNode: Buffer[Node] = ArrayBuffer("Code")

    // La máquina necesita que exportemos una función MAIN, y dentro del
    // módulo, esa función se llama MAIN
    selfType += ListNode("MAIN", "MAIN")

    // Para una función cualquiera, la máquina siempre asigna el módulo al
    // que pertenece la función a su registro SELF
    regsType += ListNode("SELF", "SELF")
    // Y al registro ARGS asigna los argumentos.
    // Por ahora, por simplicidad, la función MAIN no recibe argumentos,
    // por lo tanto recibe un Struct Vacío, definido en Prelude
    regsType += ListNode("ARGS", "Empty")

    imports.foreach{ case(k,(m, f)) =>
      imported += ListNode(k, m, f)
      mods += m
    }
    mods.foreach{modules += _}

    constants.foreach{case (k,v) =>
      selfType += ListNode(k, "Any")
      regsType += ListNode(k, "Any")
      val tp = v match {
        case _:String => "str"
        case _:Float => "num"
        case _:Double => "num"
        case _:Int => "num"
      }
      constNode += ListNode(k, tp, v.toString)
    }
    functions.foreach{fn => regsType += ListNode(fn, fn)}
    regs.foreach{rg => regsType += ListNode(rg, "Any")}

    code.foreach{inst =>
      codeNode += (inst match {
        case Inst.Cpy(a, b) => ListNode("cpy", a, b)
        case Inst.Get(a, b, c) => ListNode("get", a, b, c)
        case Inst.Set(a, b, c) => ListNode("set", a, b, c)
        case Inst.New(a) => ListNode("new", a)
        case Inst.Call(a) => ListNode("call", a)

        case Inst.Lbl(l) => ListNode("lbl", l)
        case Inst.Jmp(l) => ListNode("jmp", l)
        case Inst.If (l, a) => ListNode("if" , l, a)
        case Inst.Ifn(l, a) => ListNode("ifn", l, a)
      })
    }
    codeNode += ListNode("end")

    ListNode(
      modules,
      imported,
      ListNode("Structs", selfType, regsType),
      ListNode("Functions",
        ListNode("MAIN", "Empty", "main-regs", codeNode)
      ),
      constNode
    )
  }
}


object Main {
  def main (args: Array[String]) {
    val st = new State()
    val ast = {
      import Nodes._
      Block(Array(
        Declare("a"),
        Declare("b"),
        Declare("c"),
        Assign("a", Num(5.0)),
        Assign("b", Num(6.0)),
        Assign("c", Call(
          "$add", Array(
            Var("a"), Var("b")
          )
        )),
        Call("$print", Array(Var("c")))
      ))
    }
    println(ast)
    //println(Node.sexpr(ast).pretty)

    Nodes.get(st, ast)

    println(st.constants)
    println(st.code)
  }
}
