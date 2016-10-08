package arnaud.culang

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
    val sign =
      P(("+"|"-").!.?.map(_ match {
        case Some("+") => Positive
        case Some("-") => Negative
        case None => Positive
        case _ => ???
      }))
    val intpart =
      P(sign ~ digits).map(_ match {
        case (Positive, digits) => digits.toInt
        case (Negative, digits) => -(digits.toInt)
      })
    val realpart =
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
    ).map(Ast.Num)
  }

  val string = {
    val validChars = P(!("\\" | "\"") ~ AnyChar.!)
    val uescape = P("\\u" ~/ AnyChar.rep(min=4,max=4).!).map( _.toInt.toChar)
    val xescape = P("\\x" ~/ AnyChar.rep(min=2,max=2).!).map( _.toInt.toChar)
    val escape = P("\\" ~ !("u"|"x"|"z") ~ AnyChar.!).map(_ match {
      case "n" => "\n"
      case "t" => "\t"
      case c => c
    })
    P( "\"" ~/ (validChars|uescape|xescape|escape).rep.map(_.mkString) ~/ "\"" ).map(Ast.Str)
  }

  val const = P(
    kw("true").map( _ => Ast.Bool(true)) |
    kw("false").map(_ => Ast.Bool(false)) |
    kw("null").map( _ => Ast.Null)
  )

  val keywords: Set[String] = "true false null if else while return continue break goto proc import".split(' ').toSet

  val namechar = CharIn('a' to 'z', 'A' to 'Z', '0' to '9', "_")
  val firstchar = CharIn('a' to 'z', 'A' to 'Z', "_")
  val name = P(firstchar ~ namechar.rep).!.filter(!keywords.contains(_))

  val ident = name.map(Ast.Id)
  val typename = name.map(Ast.Type)

  def kw (str: String) = P(str ~ !(namechar))

  val lineComment = P("//" ~ CharsWhile(_ != '\n'))
  val multiComment = P("/*" ~ (!("*/") ~ AnyChar).rep ~ "*/")
  //val ws = P(CharsWhile(_.isSpaceChar))
  val ws = P(CharsWhile(" \n\t".toSet))
  val wscomment = P( (ws|lineComment|multiComment).rep )
}

import fastparse.noApi._
object WsApi extends fastparse.WhitespaceApi.Wrapper(Lexical.wscomment)
import WsApi._

import Lexical.{kw => Kw}

object Expressions {
  private val arg = P(Lexical.ident ~ "=" ~ expr) map Ast.Arg.tupled
  private val args = P("(" ~/ arg.rep(sep = ",")  ~ ")")
  val callbase = P(Lexical.ident ~ args)

  val variable = P(Lexical.ident) map Ast.Var
  val const = P(Lexical.number | Lexical.const | Lexical.string)
  val call = P(callbase ~ "." ~ Lexical.ident) map {
    case (func, args, field) => Ast.Call(func, args, Some(field))
  }

  val expr: P[Ast.Expr] = P(const | call | variable | "(" ~ expr ~ ")");
}


object Statements {
  // val decl = P(type ~ (ident ~ ("=" ~ expr).?).rep(sep = ","))
  private val declpart = P(Lexical.ident ~ ("=" ~ Expressions.expr).?) map Ast.DeclPart.tupled

  val decl = P(Lexical.typename ~ declpart.rep(sep=",", min=1) ~ ";") map Ast.Decl.tupled
  val assign = P(Lexical.ident ~ "=" ~/ Expressions.expr ~ ";").map(Ast.Assign.tupled)
  val call = P(Expressions.callbase ~ ";") map {
    case (func, args) => Ast.Call(func, args, None)
  }

  val block = P("{" ~ stmt.rep ~ "}").map(Ast.Block)

  val cond = P("(" ~ Expressions.expr ~ ")")

  val ifstmt = P(Kw("if") ~/ cond ~ block ~ (Kw("else") ~ block).?).map(Ast.If.tupled)
  val whilestmt = P(Kw("while") ~/ cond ~ block).map(Ast.While.tupled)

  val retstmt = P(Kw("return") ~/ Expressions.expr.? ~ ";").map(Ast.Return)
  val breakstmt = P(Kw("break") ~ ";").map(_ => Ast.Break)
  val continuestmt = P(Kw("continue") ~ ";").map(_ => Ast.Continue)

  val stmt: P[Ast.Stmt] =
    P(call | assign | decl |
      block | ifstmt | whilestmt |
      retstmt | continuestmt | breakstmt)
}

object Toplevel {
  val moduleName = P(CharIn('a' to 'z', 'A' to 'Z').rep.!)

  val importfield =
    P(Lexical.ident ~ "=" ~ Lexical.name ~ ";").map(Ast.ImportField.tupled)
  val importstmt = P(Kw("import") ~/ Lexical.name ~
    "{" ~ importfield.rep ~ "}").map(Ast.Import.tupled)

  private val param = P(Lexical.typename ~ Lexical.ident) map Ast.Param.tupled
  private val params = P("(" ~ param.rep(sep = ",")  ~ ")")

  val proc =
    P(Kw("proc") ~/ Lexical.ident ~ params ~ 
      Statements.block).map(Ast.Proc.tupled)

  val toplevel: P[Ast.Toplevel] = P(importstmt | proc)

  val program: P[Ast.Program] = P(toplevel.rep).map(Ast.Program)
}


object Main {

  def parse_text (text: String) = {
    P(Toplevel.program ~ End).parse(text) match {
      case Parsed.Success(succ, _) => succ
      case fail: Parsed.Failure =>
        print(fail.extra.traced.trace)
        System.exit(0)
        ???
    }
  }

  def parse_file (name: String) = {
    parse_text(scala.io.Source.fromFile(name).mkString)
  }

  def manual (): Nothing = {
    println("Usage: (-i <code> | -f <filename>) [-o <output filename>]")
    System.exit(0)
    return ???
  }

  def main (args: Array[String]) {
    import arnaud.myvm.codegen.ProgState
    import arnaud.sexpr.Node

    val parsed = args(0) match {
      case "-f" => parse_file(args(1))
      case "-i" => parse_text(args(1))
      case _ => manual()
    }
    println(parsed)

    println()

    val cgnode = CodeGen.program(parsed)
    println(arnaud.myvm.codegen.Nodes.sexpr(cgnode).prettyRepr)

    val progstate = new ProgState()
    progstate %% cgnode
    val compiled = progstate.compile()
    val output = compiled.prettyRepr
    println(output)

    if (args.length >= 4 && args(2) == "-o") {
      import java.io._
      val outname = args(3)
      val pw = new PrintWriter(new File(outname))
      pw.write(output)
      pw.close
      println(s"File $outname saved")
    }
  }
}