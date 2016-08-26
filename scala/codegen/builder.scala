package arnaud.myvm.codegen.builder

import collection.mutable.{Buffer, ArrayBuffer, Map, Set}
import arnaud.sexpr._
import arnaud.sexpr.Implicits._
import arnaud.sexpr.{Node => SNode}

class Module {
  var types: Buffer[Type] = new ArrayBuffer[Type]
  var constants: Map[String, Any] = Map()

  def update(nm: String, tp: Type) {
    tp.name = nm
    types += tp
  }

  def apply(nm: String): Type =
    types.find{_.name == nm}.get

  def toSexpr(): SNode = {
    val mods: Set[String] = Set()

    val imported = new ArrayBuffer[SNode]
    val structs = new ArrayBuffer[SNode]
    val functions = new ArrayBuffer[Function]
    imported += "Types"
    structs += "Structs"

    types.foreach{(tp: Type) =>
      tp match {
        case mp: Imported =>
          imported += mp.toSexpr
          mods += mp.module
        case st: Struct =>
          structs += st.toSexpr
        case _ =>
      }
    }

    val modules = new ArrayBuffer[SNode]
    modules += "Imports"
    mods.foreach{md => modules += md}

    val consts = new ArrayBuffer[SNode]
    consts += "Constants"
    constants.foreach{case (nm, value) =>
      val tp = value match {
        case _:String => "str"
        case _:Float => "num"
        case _:Double => "num"
        case _:Int => "num"
      }
      consts += ListNode(nm, tp, value.toString)
    }


    ListNode(modules, imported, structs, consts)
  }
}

sealed abstract class Type {
  var name: String = null
  def toSexpr(): SNode = ???
}
class Imported (
  val module: String,
  val field: String) extends Type {

  override def toSexpr() = {
    ListNode(name, module, field)
  }
}
class Struct (
  var fields: Map[String, Type] = null) extends Type {

  override def toSexpr () = {
    val nds = new ArrayBuffer[SNode]
    nds += name
    fields.foreach{case (k, tp) => nds += ListNode(k, tp.name)}
    new ListNode(nds)
  }
}
class Function extends Type {
  var args: Type = null
  var regs: Type = null
  var code: Code = null
}

class Code {
  var code: Seq[Inst] = null
}

abstract class Inst {}
object Inst {
  type Key = String
  case class Cpy(a: Key, b: Key) extends Inst
  case class Get(a: Key, b: Key, c: Key) extends Inst
  case class Set(a: Key, b: Key, c: Key) extends Inst
  case class New (a: Key) extends Inst
  case class Call(a: Key) extends Inst
  case class Lbl(l: Key) extends Inst
  case class Jmp(l: Key) extends Inst
  case class If (l: Key, a: Key) extends Inst
  case class Ifn(l: Key, a: Key) extends Inst
  case object End extends Inst
}

/*
object Main {
  def main (args: Array[String]) {
    val module = new Module

    def preludeImport(nm: String) {
      module(nm) = new Imported("Prelude", nm)
    }
    preludeImport("Num")
    preludeImport("Bool")
    preludeImport("String")
    preludeImport("CmdArgs")

    preludeImport("add")
    preludeImport("gtz")
    preludeImport("dec")
    preludeImport("print")
    preludeImport("itos")

    module("SELF") = new Struct(Map(
      "a" -> module("Num"),
      "b" -> module("Num"),
      "zero" -> module("Num")
    ))

    module.constants("a") = 5
    module.constants("b") = 3
    module.constants("zero") = 0

    println(module.toSexpr)
  }
}
*/