package arnaud.culang

class Parser (text: String) {

  val lines: Seq[Int] = 0 +: text.zipWithIndex.filter(_._1 == '\n').map(_._2 + 1)

  def srcPosFor (nodepos: Int) = {
    val line = lines lastIndexWhere {linestart => linestart<=nodepos}
    val linestart = lines(line)
    val column = nodepos - linestart
    (line, column)
  }

  object Lexical {
    import fastparse.all._
    val number = {
      sealed abstract class Sign
      case object Positive extends Sign
      case object Negative extends Sign
      def divideTens (n: Double, i: Int): Double =
        if (i < 1) {n} else { divideTens(n/10, i-1) }
      def multiplyTens (n: Double, i: Int): Double =
        if (i < 1) {n} else { multiplyTens(n*10, i-1) }
      val digits = P( CharIn('0' to '9').rep(1).! )
      val sign = P(("+"|"-").!.? map {
        case Some("+") => Positive
        case Some("-") => Negative
        case None => Positive
        case _ => ???
      })
      val intpart = P(sign ~ digits) map {
        case (Positive, digits) => digits.toInt
        case (Negative, digits) => -(digits.toInt)
      }
      /*val realpart =
        P(intpart ~ ("." ~ digits).?).map(_ match {
          case (intpart, None) => intpart.toDouble
          case (intpart, Some(fracpart)) =>
            intpart.toDouble + divideTens(fracpart.toDouble, fracpart.length)
        })
      P( realpart ~ (("e"|"E") ~ sign ~ digits ).?).map(
        _ match {
          case (realpart, None) => realpart
          case (realpart, Some((Positive, expdigits))) =>
            multiplyTens(realpart, expdigits.toInt)
          case (realpart, Some((Negative, expdigits))) =>
            divideTens(realpart, expdigits.toInt)
        }
      ).map(Ast.Num)*/

      P(intpart ~ ("." ~ digits).? ~ (("e"|"E") ~ sign ~ digits ).? ) map {
        case (intpart, None, None) => Ast.IntLit(intpart)
        case (intpart, fracpart, exppart) =>
          var mag = intpart
          var exp = exppart match {
            case Some((Positive, digits)) => digits.toInt
            case Some((Negative, digits)) => -(digits.toInt)
            case _ => 0
          }

          fracpart match {
            case Some(digits) =>
              var mult = 1
              for (_ <- 0 until digits.length)
                mult = mult*10
              mag = mag * mult + digits.toInt
              exp -= digits.length
            case _ =>
          }

          Ast.FltLit(mag, exp)
      }
    }

    def quoted (lim: String) = {
      val validChars = P(!("\\" | lim) ~ AnyChar.!)
      val uescape = P("\\u" ~/ AnyChar.rep(min=4,max=4).!).map( _.toInt.toChar)
      val xescape = P("\\x" ~/ AnyChar.rep(min=2,max=2).!).map( _.toInt.toChar)
      val escape = P("\\" ~ !("u"|"x"|"z") ~ AnyChar.!).map(_ match {
        case "n" => "\n"
        case "t" => "\t"
        case c => c
      })
      P(lim ~/ (validChars|uescape|xescape|escape).rep.map(_.mkString) ~ lim)
    }

    val string = quoted("\"").map(Ast.Str)

    val const = P(
      kw("true").map( _ => Ast.Bool(true)) |
      kw("false").map(_ => Ast.Bool(false)) |
      kw("null").map( _ => Ast.Null)
    )

    val keywords: Set[String] =
      "true false null if else while return continue break goto import type void as".
      split(' ').toSet

    val namechar = CharIn('a' to 'z', 'A' to 'Z', '0' to '9', "_")
    val firstchar = CharIn('a' to 'z', 'A' to 'Z', "_")
    val name = P(
      (firstchar ~ namechar.rep).!.filter(!keywords.contains(_))
      | quoted("`")
    ).opaque("identifier")

    def kw (str: String) = P(str ~ !(namechar))

    val lineComment = P("//" ~ CharsWhile(_ != '\n'))
    val multiComment = P("/*" ~ (!("*/") ~ AnyChar).rep ~ "*/")
    //val ws = P(CharsWhile(_.isSpaceChar))
    val ws = P(CharsWhile(" \n\t".toSet))
    val wscomment = P( (ws|lineComment|multiComment).rep )
  }

  // Lee un nodo del Ast y lo ubica en el código
  def setSrcPos[T <: Ast.Node] (nodepos: Int, node: T) = {
    val (line, column) = srcPosFor(nodepos)
    node.srcpos(line, column)
    node
  }

  implicit class NodeOps[T <: Ast.Node] (node: T) {
    def setSrcPos (nodepos: Int) = {
      val (line, column) = srcPosFor(nodepos)
      node.srcpos(line, column)
      node
    }
  }

  import fastparse.{all => FPA}
  def IP[T <: Ast.Node](p: FPA.P[T]): FPA.P[T] = {
    import FPA._
    (Index ~ p) map { (setSrcPos[T] _).tupled }
  }

  import fastparse.noApi._
  object WsApi extends fastparse.WhitespaceApi.Wrapper(Lexical.wscomment)
  import WsApi._

  import Lexical.{kw => Kw}

  object Expressions {

    object Ops {
      import scala.collection.mutable.{Stack, ListMap}

      val precedences = ListMap[Ast.Op,Int]()

      def op (s: String, o: Ast.Op, prec: Int): P[(Int, Ast.Op)] = {
        precedences(o) = prec
        P(Index ~ s.!) map {case (i, _) => (i, o)}
      }

      val ops = P(
        op(">=", Ast.Gte, 2) |
        op(">" , Ast.Gt , 2) |
        op("<=", Ast.Lte, 2) |
        op("<" , Ast.Lt , 2) |
        op("==", Ast.Eq , 2) |
        op("!=", Ast.Neq, 2) |
        op("+" , Ast.Add, 3) |
        op("-" , Ast.Sub, 3) |
        op("*" , Ast.Mul, 4) |
        op("/" , Ast.Div, 4)
      ).opaque("operator")

      def helper (first: Ast.Expr, pairs: Seq[(Int, Ast.Op, Ast.Expr)]): Ast.Expr = {
        val values = new Stack[Ast.Expr]
        val ops = new Stack[(Int, Ast.Op)]

        def unfold_until (prec: Int) {
          while (
            values.size >= 2 &&
            ops.size > 0 &&
            precedences(ops.head._2) >= prec
          ) {
            val (index, top) = ops.pop()
            val b = values.pop()
            val a = values.pop()
            values push setSrcPos(index, Ast.Binop(top, a, b))
          }
        }

        values.push(first)
        for ( (index, op, value) <- pairs ) {
          unfold_until( precedences(op) )
          ops.push((index, op))
          values.push(value)
        }
        unfold_until(0)
        values.pop()
      }

      def expr (atom: P[Ast.Expr]): P[Ast.Expr] = {
        P(atom ~ (ops ~ atom).rep).map{
          case (a, bs) => helper(a, bs)
        }
      }
    }

    val atom = {
      sealed abstract class Op
      object Op {
        case class Field (i: Int, nm: String) extends Op
        case class Index (i: Int, field: Ast.Expr) extends Op
        case class Call (i: Int, args: Seq[Ast.Expr]) extends Op
        case class New (i: Int, vals: Seq[Ast.Expr]) extends Op
      }

      val field = P(Index ~ "." ~/ Lexical.name) map Op.Field.tupled
      val index = P(Index ~ "[" ~/ expr ~ "]") map Op.Index.tupled
      val call = P(Index ~ "(" ~/ expr.rep(sep=",") ~ ")") map Op.Call.tupled
      val `new` = P(Index ~ "{" ~/ expr.rep(sep=",") ~ "}") map Op.New.tupled

      P(IP(Lexical.name.map(Ast.Var)) ~ (field | index | call | `new`).rep ) map {
        case (expr, ops) => ops.foldLeft[Ast.Expr](expr) {
          case (expr, Op.Field(i, nm)) => Ast.Field(expr, nm).setSrcPos(i)
          case (expr, Op.Index(i, field)) => Ast.Index(expr, field).setSrcPos(i)
          case (expr, Op.Call(i, args)) => Ast.Call(expr, args).setSrcPos(i)
          case (expr, Op.New(i, vals)) => Ast.New(expr, vals).setSrcPos(i)
        }
      }
    }

    val const = P(Lexical.number | Lexical.const | Lexical.string)
    val inparen = P("(" ~/ expr ~ ")")
    val expr: P[Ast.Expr] = Ops.expr(IP(const | inparen | atom))
    val `type` = expr map Ast.Type
  }

  import Expressions.{`type` => etype, expr}

  object Statements {
    private val declpart = P(Lexical.name ~ ("=" ~ expr).?) map Ast.DeclPart.tupled

    val $call = NoCut(expr)
      .filter(_.isInstanceOf[Ast.Call])
      .map(_.asInstanceOf[Ast.Call])

    val decl = P(NoCut(etype) ~ declpart.rep(sep=",", min=1) ~ ";") map Ast.Decl.tupled
    val assign = P(Lexical.name ~ "=" ~/ expr ~ ";").map(Ast.Assign.tupled)
    val multi = P(Lexical.name.rep(sep=",", min=2) ~ "=" ~/ $call ~ ";") map Ast.Multi.tupled
    val call = $call ~ ";"

    val block = P("{" ~ stmt.rep ~ "}").map(Ast.Block)

    val cond = P("(" ~ expr ~ ")")

    val ifstmt = P(Kw("if") ~/ cond ~ stmt ~ (Kw("else") ~ stmt).?).map(Ast.If.tupled)
    val whilestmt = P(Kw("while") ~/ cond ~ stmt).map(Ast.While.tupled)

    val retstmt = P(Kw("return") ~/ expr.rep(sep=",") ~ ";").map(Ast.Return)
    val breakstmt = P(Kw("break") ~ ";").map(_ => Ast.Break)
    val continuestmt = P(Kw("continue") ~ ";").map(_ => Ast.Continue)
    val label = P(Lexical.name ~ ":").map(Ast.Label)
    val goto = P(Kw("goto") ~ Lexical.name ~ ";").map(Ast.Goto)

    val stmt: P[Ast.Stmt] =
      IP(label | call | assign | multi | decl |
        block | ifstmt | whilestmt |
        retstmt | continuestmt | breakstmt | goto)
  }

  object Toplevel {
    val moduleName = P(CharIn('a' to 'z', 'A' to 'Z').rep.!)

    private val param = P(etype ~ Lexical.name)
    private val params = P("(" ~ param.rep(sep = ",")  ~ ")")

    private val procType: P[Seq[Ast.Type]] =
      P(Kw("void").map(_ => Nil) | etype.rep(sep=",", min=1))

    val proc = P(procType ~ Lexical.name ~ params ~/ Statements.block)
    .map {case (tps, nm, pms, body) => Ast.Proc(nm, pms, tps, body)}

    val importstmt = {
      val alias = (Kw("as") ~/ Lexical.name).?
      val tpdef = P(Kw("type") ~/ Lexical.name ~ alias ~ ";") map Ast.ImportType.tupled
      val rut = P(procType ~ Lexical.name ~ "(" ~/ etype.rep(sep=",") ~ ")" ~ alias ~ ";") map Ast.ImportRut.tupled

      val defs = P(
        ("{" ~ IP(tpdef | rut).rep(min=1) ~ "}")
        | P(";").map(_ => Nil)
      )
      val params = P("(" ~/ expr.rep(sep=",") ~ ")").? map (_ getOrElse Nil)

      P(Kw("import") ~/
        Lexical.name.rep(sep=".", min=1) ~
        params ~ alias ~ defs
      ) map Ast.Import.tupled
    }

    val struct = P(
      Kw("struct") ~/ Lexical.name ~ "{" ~
      (etype ~ Lexical.name ~ ";").rep
      ~ "}") map Ast.Struct.tupled

    val constant = P(etype ~ Lexical.name ~ "=" ~/ expr ~ ";") map Ast.Const.tupled

    val toplevel: P[Ast.Toplevel] = IP(importstmt | struct | proc | constant)

    // El espacio en blanco solo sale en ~ y rep, por eso están los Pass, para
    // poder seguirlos con ~ y aceptar espacios al inicio y final
    val program: P[Ast.Program] = P(Pass ~ toplevel.rep ~ End).map(Ast.Program)
  }

  def parse = Toplevel.program.parse(text)
}

class ParseError(fail: fastparse.all.Parsed.Failure)
  extends fastparse.all.ParseError(fail) {
  // Información específica de como ocurrió el error
  def trace = fail.extra.traced.trace
}

object Parser {
  import fastparse.all.Parsed

  def parse (text: String): Ast.Program = {

    val parser = new Parser(text)

    parser.parse match {
      case Parsed.Success(result, _) => result
      case fail: Parsed.Failure => throw new ParseError(fail)
    }
  }
}