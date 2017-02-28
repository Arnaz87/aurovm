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
  // No puedo tener ambos, NmCall y Call. Uno de los dos debe ser el principal
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
  case object Return extends Node

  case class Narr(body: Seq[Node]) extends Node

  case class ImportType(name: String, mod: String, field: String) extends Node
  case class ImportProc(name: String, mod: String, field: String) extends Node
  case class Proc(name: String, rets: Seq[String], params: Seq[String], body: Node) extends Node

  // TODO: Definir el nodo de estructuras y de importar tipos
  // case class Struct

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
      case Call(func, args) => ListNode("Call", func, new ListNode(args map (sexpr _)))
      case Assign(nm, nd) => ListNode("Assign", nm, sexpr(nd))
      case Block(nds) => new ListNode(AtomNode("Block") +: (nds map (sexpr _)))
      case Scope(blck) => ListNode("Scope", sexpr(blck))
      case Declare(nm) => ListNode("Declare", nm)
      case DeclareGlobal(nm) => ListNode("DeclareGlobal", nm)
      case Undeclared(nm, nd) => ListNode("Undeclared", nm, sexpr(nd))

      case Proc(nm, rs, ps, bd) => ListNode(
        "Proc", nm,
        new ListNode(rs map {new AtomNode(_)}),
        new ListNode(ps map {new AtomNode(_)}),
        sexpr(bd))
      case ImportType(name, mod, field) => ListNode("ImportType", name, mod, field)
      case ImportProc(name, mod, field) => ListNode("ImportProc", name, mod, field)

      case While(cond, body) => ListNode("While", sexpr(cond), sexpr(body))
      case If(cond, body, orelse) => ListNode("If", sexpr(cond), sexpr(body), sexpr(orelse))
      case Return => ListNode("Return")

      case x => ListNode(x.toString)
    }
  }
}

sealed abstract class Inst
object Inst {
  case class Cpy(a: String, b: String) extends Inst
  case class Cns(a: String, b: String) extends Inst
  case class Get(a: String, o: String, k: String) extends Inst
  case class Set(o: String, k: String, b: String) extends Inst
  case class New(f: String) extends Inst

  case class Lbl(l: String) extends Inst
  case class Jmp(l: String) extends Inst
  case class If (l: String, a: String) extends Inst
  case class Ifn(l: String, a: String) extends Inst

  case class Call(f: String, args: Seq[String]) extends Inst

  case object End extends Inst
}

case class RegId(name: String)

sealed abstract class VarInfo
case class RegVar(val reg: RegId) extends VarInfo
case class ConstVar(val reg: RegId) extends VarInfo
case class FieldVar(val obj: RegId, val field: RegId) extends VarInfo