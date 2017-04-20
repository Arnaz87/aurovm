package arnaud.myvm.lua

object Ast {
  sealed abstract class Op
  case object Or  extends Op
  case object And extends Op

  case object Add extends Op
  case object Sub extends Op
  case object Mul extends Op
  case object Div extends Op
  case object Mod extends Op

  case object Lt  extends Op
  case object Gt  extends Op
  case object Lte extends Op
  case object Gte extends Op
  case object Eq  extends Op
  case object Neq extends Op

  case object App extends Op
  case object Pow extends Op

  sealed trait Node
  sealed trait expr extends Node
  sealed trait stmt extends Node
  sealed trait literal extends expr
  sealed trait const extends literal
  sealed trait assignable extends Node

  case class Num (v: Double) extends const
  case class Str (v: String) extends const
  case class Bool (v: Boolean) extends const
  case object Nil extends const

  case object Varargs extends literal

  case class TableField (l: Option[expr], r: expr)
  case class Table (fields: Seq[TableField]) extends literal

  case class Function (params: Seq[Var], body: Block) extends literal

  case class Var (name: String) extends expr with assignable
  case class Field (l: expr, name: expr) extends expr with assignable
  case class Binop (l: expr, r: expr, op: Op) extends expr
  case class Call (l: expr, args: Seq[expr]) extends expr with stmt

  case class Block (stmts: Seq[stmt]) extends Node
  case class Assign (l: Seq[assignable], r: Seq[expr]) extends stmt
  case class IfBlock (cond: expr, block: Block)
  case class If (ifs: Seq[IfBlock], orelse: Block) extends stmt
  case class While (cond: expr, body: Block) extends stmt
}