package arnaud.myvm.lua

import fastparse.noApi._
object WsApi extends fastparse.WhitespaceApi.Wrapper(Lexical.wscomment)
import WsApi._
//import fastparse.all._

import Lexical.{kw => Kw}

object Ops {
  // "prec" es de "precedence" (precedencia)
  case class Prec (op: Ast.Op, prec: Int)
  def op(p: P[_], o: Ast.Op, prec: Int): P[Prec] = {
    val oprec = Prec(o, prec)
    p.map{ _ => oprec }
  }
  def op(s: String, o: Ast.Op, prec: Int): P[Prec] = { op(P(s), o, prec) }

  val NilOp = Prec(null, 0)

  // Ningún operador debe ser 0
  val Or  = op(Kw("or"), Ast.Or, 1)
  val And = op(Kw("and"), Ast.And, 2)
  val Lt = op("<", Ast.Lt, 3)
  val Gt = op(">", Ast.Gt, 3)
  val Lte = op("<=", Ast.Lte, 3)
  val Gte = op(">=", Ast.Gte, 3)
  val Eq = op("==", Ast.Eq, 3)
  val Neq = op("~=", Ast.Neq, 3)

  val App = op("..", Ast.App, 4)
  val Add = op("+", Ast.Add, 5)
  val Sub = op("-", Ast.Sub, 5)
  val Mul = op("*", Ast.Mul, 6)
  val Div = op("/", Ast.Div, 6)

  val ops = P( Or | And | Lt | Gt | Lte | Gte | Eq | Neq | App | Add | Sub | Mul | Div )

  def helper_with_state (firstValue: Ast.expr, pairs: Seq[(Prec, Ast.expr)]): Ast.expr = {
    import scala.collection.mutable.Stack
    val values = new Stack[Ast.expr]
    val ops = new Stack[Prec]
    values.push(firstValue)
    ops.push(NilOp)

    def push_op (op: Prec) {
      // Si el último operador no es importante no hay que calcular nada.
      // Si hay menos de dos valores, no se puede calcular nada.
      // La pila de operadores nunca estará vacía, siempre habrá un NilOp
      // porque tiene precedencia 0, así que no hay que preocuparse por eso.
      if (op.prec > ops.head.prec || values.length < 2) {
        ops.push(op)
      } else {
        val top = ops.pop().op
        val b = values.pop()
        val a = values.pop()
        values.push(Ast.Binop(a, b, top))
        // Repetir el proceso hasta que el último operador no sea importante.
        push_op(op)
      }
    }

    pairs.foreach{
      case(op, value) =>
        push_op(op)
        values.push(value)
    }
    push_op(NilOp)
    values.pop()
  }

  def expr (atom: P[Ast.expr]): P[Ast.expr] = {
    P(atom ~ (ops ~ atom).rep).map{
      case (a, bs) => helper_with_state(a, bs)
    }
  }
}

object Expressions {
  val variable = P(Lexical.name).map(Ast.Var)
  val const = P(Lexical.number | Lexical.const | Lexical.string)

  private object Prefix {
    sealed abstract class Suffix {
      def toExpr (l: Ast.expr): Ast.expr
    }
    case class Call (rs: Seq[Ast.expr]) extends Suffix {
      def toExpr (l: Ast.expr) = Ast.Call(l, rs)
    }
    case class Field (r: Ast.expr) extends Suffix {
      def toExpr (l: Ast.expr) = Ast.Field(l, r)
    }

    val $call = P("(" ~/ expr.rep(sep = ",").map(Call)  ~ ")")
    val $field = P("[" ~/ expr.map(Field) ~ "]")
    // El !".." es necesario aquí para no confundirlo con el operador de concatenación
    val $dot = P((!".." ~ ".") ~/ Lexical.name.map(Ast.Str).map(Field))
    val prefix =
      P(variable ~ ($call | $dot | $field).rep).map{ case (v, ss) =>
        ss.foldLeft[Ast.expr](v) { (nv, s) => s.toExpr(nv) }
      }
  }

  val prefix = Prefix.prefix
  val call =
    P(prefix.filter(_.isInstanceOf[Ast.Call])
            .map(_.asInstanceOf[Ast.Call]))
  val assignable =
    P(prefix.filter(_.isInstanceOf[Ast.assignable])
            .map(_.asInstanceOf[Ast.assignable]) )

  private val fieldsep = P(","|";")
  private val tablefield =
    P((("[" ~/ expr ~ "]" | Lexical.name.map(Ast.Str)) ~ "=").? ~ expr)
    .map(Ast.TableField.tupled)
  var table = P("{" ~/ tablefield.rep(sep=fieldsep) ~ "}").map(Ast.Table)

  var funcbody =
    P("(" ~ variable.rep(sep=",") ~ ")" ~
      Statements.block ~ Kw("end")).map(Ast.Function.tupled)
  var function = P(Kw("function") ~/ funcbody)

  val inparen = P("(" ~/ expr ~ ")")
  val atom = P( prefix | variable | const | inparen | table | function )
  val expr: P[Ast.expr] = Ops.expr(atom);
}

object Statements {
  import Expressions.expr

  val assign: P[Ast.Assign] =
    P( Expressions.assignable.rep(min=1, sep=",") ~ "=" ~/
       Expressions.expr.rep(min=1, sep=",")).map(Ast.Assign.tupled)
  val call: P[Ast.Call] = Expressions.call
  val doblock: P[Ast.Block] = P(Kw("do") ~/ block ~ Kw("end"))

  val ifstmt: P[Ast.If] =
    P(Kw("if") ~/ expr ~
      Kw("then") ~/ block ~
      (Kw("elseif") ~/ expr ~ Kw("then") ~ block).rep ~
      (Kw("else") ~/ block).? ~
      Kw("end")).map{
        case (cnd, blck, elss, els) =>
          val ifs = elss.map{ case (c,b) => Ast.IfBlock(c,b) } :+ Ast.IfBlock(cnd, blck)
          val orelse = els match {
            case Some(bl: Ast.Block) => bl
            case None => Ast.Block(Nil)
          }
          Ast.If(ifs, orelse)
      }

  val whilestmt: P[Ast.While] =
    P(Kw("while") ~/ expr ~ Kw("do") ~ block ~ Kw("end")).map(Ast.While.tupled)

  val function = P(Kw("function") ~/ Lexical.name ~ Expressions.funcbody).map{
    case (name, fun) => Ast.Assign(Seq(Ast.Var(name)), Seq(fun))
  }

  val block: P[Ast.Block] = P(stmt.rep(sep=P(";".?), min=1)).map(Ast.Block)

  val stmt: P[Ast.stmt] = P(assign | call | ifstmt | whilestmt | function)
}