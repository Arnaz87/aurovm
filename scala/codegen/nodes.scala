package arnaud.myvm.codegen

abstract class Node {}
object Nodes {
  case class Num(n: Double) extends Node
  case class Str(s: String) extends Node
  case class Bool(b: Boolean) extends Node
  case object Nil extends Node

  case class Ident(name: String) extends Node
  case class Call(func: Node, args: Seq[Node]) extends Node

  // Declarar una variable local, oculta a cualquiera que ya exista
  case class Declare(name: Node) extends Node
  // Declarar una variable global, puede ser ocultada
  case class DeclareGlobal(name: Node) extends Node

  // Ejecuta el nodo si el nombre no esta declarado
  // Útil para lenguajes dinámicos que no tienen declaraciones,
  // y solo tienen asignaciones
  case class Undeclared(name: Node, nd: Node) extends Node

  case class Assign(l: Node, r: Node) extends Node
  case class Block(nodes: Seq[Node]) extends Node

  case class While(cond: Node, body: Node) extends Node
  case class If(cond: Node, body: Node, orelse: Node) extends Node

  case class Narr(body: Seq[Node]) extends Node
}