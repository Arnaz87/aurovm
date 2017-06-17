import scala.scalajs.js
import scala.scalajs.js.annotation._
import scala.scalajs.js.typedarray.Uint8Array

import scala.util.{Try, Success, Failure}

import arnaud.cobre.format
import arnaud.culang

@JSExportTopLevel("Culang.Result")
class Result(value: Try[Uint8Array]) {
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
      val buffer = new collection.mutable.ArrayBuffer[Int]()
      val writer = new arnaud.cobre.format.Writer(buffer)
      writer.write(program)

      val arr = new Uint8Array(buffer.size)
      for(i <- 0 until buffer.size) arr(i) = buffer(i).asInstanceOf[Short]

      arr
      //arnaud.cobre.backend.js.Compiler.compile(program)
    }))
  }
}