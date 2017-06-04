import scala.scalajs.js
import scala.scalajs.js.annotation._

import scala.util.{Try, Success, Failure}

import arnaud.cobre.format
import arnaud.culang

@JSExportTopLevel("Culang.Result")
class Result(value: Try[String]) {
  @JSExport
  def success = value.isSuccess

  @JSExport
  def result = value.get

  @JSExport
  def msg: js.UndefOr[String] = value match {
    case Failure(err: culang.ParseError) => err.getMessage
    case Failure(err: culang.CompileError) => err.getMessage
    case _ => js.undefined
  }

  @JSExport
  def err: js.UndefOr[Throwable] = value match {
    case Failure(err) => err
    case Success(_) => js.undefined
  }
}

@JSExportTopLevel("Culang")
object Culang {
  type ModuleMap = js.Dictionary[js.Dictionary[js.Any]]

  @JSExport
  def compile (src: String): Result = {
    new Result(Try({
      val ast = culang.Parser.parse(src)
      val program = culang.compiler.compile(ast)

      arnaud.cobre.backend.js.Compiler.compile(program)
    }))
  }
}