package arnaud.myvm.codegen

import arnaud.myvm._

object Codegen {

  abstract class CodeGetter
  implicit class Simple(val i: Instruction) extends CodeGetter
  implicit class Promise(val f: () => Instruction) extends CodeGetter

  def makeModule (map: Map[String, Value], name: String) = {
    val struct = new Struct(
      map.keys.toArray.map{RegInfo(_, Structs.Any)},
      name + " Module Struct"
    )
    new Module(name + " Module", struct, map)
  }

  class StructBuilder {
    val buff = new collection.mutable.ArrayBuffer[String]
    var name: String = "Anonymous Struct"

    def += (s: String) = { buff += s; buff.length - 1 }

    def toStruct () = new Struct(buff.toArray.map{RegInfo(_, Structs.Any)}, name)
  }

  class State {
    import collection.mutable.ArrayBuffer
    import collection.mutable.Stack
    import collection.mutable.Map
    private class Counter (prefix: String) {
      private var count: Int = -1
      def apply (): String = { count = count+1; prefix + count }
      def last = count
      def total = count + 1
    }
    val code = new ArrayBuffer[CodeGetter]
    val module = Map[String, Any]()

    val m_struct = new StructBuilder
    m_struct.name = "Main Module"
    val r_struct = new StructBuilder
    m_struct.name = "Main Register"
    r_struct += "null"   // 0
    r_struct += "module" // 1
    r_struct += "args"   // 2
    r_struct += "return" // 3
    r_struct += "params" //? 4

    object scope {
      val stack = new Stack[Map[String, Key]]()
      def push () { stack.push( Map[String, Key]() ) }
      def pop () { stack.pop() }
      def apply (k: String): Option[Key] = {
        // Confío en que find empieza por la cima del stack y baja...
        stack.find{_.contains(k)}.map{_ apply k}
      }
      def update (k: String, v: Key) { stack.top(k) = v }
      object bottom {
        private def bt = stack.last
        def apply (k: String): Option[Key] = {
          if (bt.contains(k)) { Some(bt(k)) } else { None }
        }
        def update (k: String, v: Key) { bt(k) = v }
      }
      push()
    }

    val labels = Map[String, Int]()
    private val usedregcount = new Counter("")
    private val genregcount = new Counter("_var_")
    private val labelcount = new Counter("_label")
    private val constantcount = new Counter("_const_")

    def genreg (): Key = addreg(genregcount())
    def addreg (name: String): Key = {
      val value = r_struct += name
      scope(name) = value
      value
    }
    object global {
      def addreg (name: String): Key = {
        val value = r_struct += name
        scope.bottom(name) = value
        value
      }
    }

    def getlabel () = labelcount()
    def pushlabel (name: String) { labels(name) = code.length }

    // Este RKey no es para el registro, es para el objeto módulo.
    // El nodo es el responsable de generar código para extraer la constante
    // del módulo y meterla en un registro.
    def addconstant (value: Any): Key = {
      val name = constantcount()
      val m_key = m_struct += name
      module(name) = value
      m_key
    }

    def generate (ast: Node): Module = {
      ast.get(this)
      code += Instruction.End

      val mainKey = m_struct += "main"
      val _module = new Module("Generated Module", m_struct.toStruct, module)
      val insts = code.toArray[CodeGetter].map{
        case s:Simple => s.i
        case p:Promise => p.f()
      }
      val _code = new Code(insts, r_struct.toStruct, _module)
      _module.data(mainKey) = _code
      _module
    }
  }

  trait Node { def get(st: State): Key }
  object Nodes {
    case class VarDecl(k: String) extends Node {
      override def get(st: State) = st.addreg(k)
    }
    case class GlobalVarDecl(k: String) extends Node {
      override def get(st: State) = st.global.addreg(k)
    }
    case class DynVar(k: String) extends Node {
      override def get(st: State) = {
        st.scope(k) match {
          case Some(v) => v
          case None => st.addreg(k)
        }
      }
    }
    case class GlobalDynVar(k: String) extends Node {
      override def get(st: State) = {
        st.scope(k) match {
          case Some(v) => v
          case None => st.global.addreg(k)
        }
      }
    }
    case class Var(k: String) extends Node {
      override def get(st: State) = st.scope(k) match {
        case Some(v) => v
        case None => throw new Exception(s"Variable $k not found in current scope")
      }
    }
    case class Assign(l: Node, r: Node) extends Node {
      override def get(st: State) = {
        val $l = l.get(st)
        val $r = r.get(st)
        st.code += Instruction.Mov($l, $r)
        Machine.nullKey
      }
    }
    case class If(cond: Node, code: Node, orelse: Node) extends Node {
      override def get(st: State) = {
        val $else = st.getlabel()
        val $end  = st.getlabel()
        val $cond = cond.get(st)
        st.code += {() => Instruction.Ifn(st.labels($else), $cond)}
        code.get(st)
        st.code += {() => Instruction.Jmp(st.labels($end))}
        st.pushlabel($else)
        orelse.get(st)
        st.pushlabel($end)
        Machine.nullKey
      }
    }
    case class While(cond: Node, code: Node) extends Node {
      override def get(st: State) = {
        val $start = st.getlabel()
        val $end = st.getlabel()
        st.pushlabel($start)
        val $cond = cond.get(st)
        st.code += {() => Instruction.Ifn(st.labels($end), $cond)}
        code.get(st)
        st.code += {() => Instruction.Jmp(st.labels($start))}
        st.pushlabel($end)
        Machine.nullKey
      }
    }
    case class Constant(v: Any) extends Node {
      override def get(st: State) = {
        val m_key = st.addconstant(v)
        val r_key = st.genreg()
        st.code += Instruction.Get(r_key, Machine.moduleKey, m_key)
        r_key
      }
    }
    case class Block(xs: Seq[Node]) extends Node {
      override def get(st: State) = {
        st.scope.push()
        xs.foreach{ _.get(st) }
        st.scope.pop()
        Machine.nullKey
      }
    }
    case class Call(f: Node, args: Node) extends Node {
      override def get(st: State) = {
        val temp = st.genreg()
        val $f = f.get(st)
        val $a = args.get(st)
        st.code += Instruction.Call(temp, $f, $a)
        temp
      }
    }
    case class Mod(mod: String, name: String) extends Node {
      override def get(st: State) = {
        val temp = st.genreg()
        st.code += Instruction.Load(temp, mod, name)
        temp
      }
    }
    case class Bin(
        inst: (Key, Key, Key) => Instruction,
        a: Node, b: Node) extends Node {
      override def get(st: State) = {
        val $a = a.get(st)
        val $b = b.get(st)
        val temp = st.genreg()
        st.code += inst(temp, $a, $b)
        temp
      }
    }
    //=== Temporales ===//
    case class Print(a: Node) extends Node {
      override def get(st: State) = {
        val $a = a.get(st)
        st.code += Instruction.Print($a)
        Machine.nullKey
      }
    }
    case class Narr(xs: Seq[Node]) extends Node {
      override def get(st: State) = {
        val temp = st.genreg()
        st.code += Instruction.DynObj(temp)
        for (i <- 0 until xs.length) {
          st.code += Instruction.DynSet(temp, i.toString, xs(i).get(st))
        }
        temp
      }
    }
  }

  /*def main_no (args: Array[String]) {
    val st = new State()
    val ast = {
      import Nodes._
      Block(Array(
        VarDecl("a"),
        VarDecl("b"),
        VarDecl("c"),
        Assign(Var("a"), Constant(5.0)),
        Assign(Var("b"), Constant(6.0)),
        Assign(Var("c"), Bin(Machine.Add, Var("a"), Var("b"))),
        Print(Var("c"))
      ))
    }
    Machine.modules("Main") = Map("main" -> st.generate(ast))
    print(Machine.modules("Main")("main").asInstanceOf[Machine.Code].code)
    Machine.start()
  }*/
}