package arnaud.culang

object Ast {
  sealed trait Node {
    var _srcpos: Option[(Int, Int)] = None
    def srcpos (ln: Int, cl: Int) { _srcpos = Some((ln, cl)) }
    def hasSrcpos = !_srcpos.isEmpty
    def line = _srcpos.get._1
    def column = _srcpos.get._2
  }
  sealed trait Expr extends Node
  sealed trait Stmt extends Node
  sealed trait Toplevel extends Node
  sealed trait Literal extends Expr

  sealed trait Imported extends Node
  sealed trait Member extends Node

  sealed abstract class Op
  case object Add extends Op
  case object Sub extends Op
  case object Mul extends Op
  case object Div extends Op
  case object Gt  extends Op
  case object Gte extends Op
  case object Lt  extends Op
  case object Lte extends Op
  case object Eq  extends Op
  case object Neq extends Op

  case class Type (expr: Expr)

  case class IntLit (n: Int) extends Literal
  case class FltLit (mag: Int, exp: Int) extends Literal
  case class Str (s: String) extends Literal
  case class Bool (b: Boolean) extends Literal
  case object Null extends Literal

  case class Var (name: String) extends Expr
  case class Field(expr: Expr, field: String) extends Expr
  case class Index(expr: Expr, field: Expr) extends Expr
  case class Binop (op: Op, a: Expr, b: Expr) extends Expr
  case class Call (func: Expr, args: Seq[Expr]) extends Expr with Stmt

  case class Array (tp: Expr) extends Expr
  case class New (tp: Type, args: Seq[Expr]) extends Expr

  case class DeclPart (nm: String, vl: Option[Expr])
  case class Decl (tp: Type, ps: Seq[DeclPart]) extends Stmt
  case class Assign (left: Expr, vl: Expr) extends Stmt
  case class Multi (ls: Seq[String], vl: Expr) extends Stmt

  case class Block (stmts: Seq[Stmt]) extends Stmt
  case class If (cond: Expr, body: Stmt, orelse: Option[Stmt]) extends Stmt
  case class While (cond: Expr, body: Stmt) extends Stmt

  case class Label (name: String) extends Stmt
  case class Goto (name: String) extends Stmt

  case class Return (expr: Seq[Expr]) extends Stmt
  case object Break extends Stmt
  case object Continue extends Stmt

  case class Const (tp: Type, name: String, value: Expr) extends Toplevel

  case class FieldMember (tp: Type, name: String) extends Member
  case class Constructor (ins: Seq[Type]) extends Member

  case class Function (
    outs: Seq[Type],
    name: String,
    ins: Seq[(Type, String)],
    alias: Option[String],
    body: Option[Block]
  ) extends Toplevel with Imported with Member

  case class Typedef (
    name: String,
    base: Option[Type],
    alias: Option[String],
    body: Option[Seq[Member]],
  ) extends Toplevel with Imported

  case class Struct (
    name: String,
    body: Option[Seq[Member]],
  ) extends Toplevel

  /*case class Method (outs: Seq[Type], name: String, )
  case class Struct (name: String, fields: Seq[(Type, String)]) extends Toplevel
  case class Proc (
    name: String,
    params: Seq[(Type, String)],
    returns: Seq[Type],
    body: Block
  ) extends Toplevel

  sealed abstract class ImportDef extends Node
  case class ImportType(name: String, methods: Seq[ImportRut], alias: Option[String]) extends ImportDef
  case class ImportRut(outs: Seq[Type], name: String, ins: Seq[Type], alias: Option[String]) extends ImportDef*/

  case class Import (
    module: String,
    params: Seq[Expr],
    alias: Option[String],
    defs: Seq[Imported]
  ) extends Toplevel

  case class Program (stmts: Seq[Toplevel])
}