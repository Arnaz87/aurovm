package arnaud.culang

object Ast {
  sealed trait Node
  sealed trait Expr extends Node
  sealed trait Stmt extends Node
  sealed trait Toplevel extends Node
  sealed trait Literal extends Expr

  case class Id (name: String)
  case class Type (name: String)

  case class Num (n: Double) extends Literal
  case class Str (s: String) extends Literal
  case class Bool (b: Boolean) extends Literal
  case object Null extends Literal

  case class Arg (name: Id, expr: Expr)

  case class Var (name: Id) extends Expr
  case class Call (func: Id, args: Seq[Arg], field: Option[Id]) extends Expr with Stmt

  case class DeclPart (nm: Id, vl: Option[Expr])
  case class Decl (tp: Type, ps: Seq[DeclPart]) extends Stmt
  case class Assign (nm: Id, vl: Expr) extends Stmt
  case class Block (stmts: Seq[Stmt]) extends Stmt
  case class If (cond: Expr, body: Block, orelse: Option[Block]) extends Stmt
  case class While (cond: Expr, body: Block) extends Stmt

  case class Return (expr: Option[Expr]) extends Stmt
  case object Break extends Stmt
  case object Continue extends Stmt

  case class ImportField (name: Id, imported: String)
  case class Import (module: String, fields: Seq[ImportField]) extends Toplevel
  case class Param (tp: Type, name: Id)
  case class Proc (name: Id, params: Seq[Param], body: Block) extends Toplevel

  case class Program (stmts: Seq[Toplevel])
}