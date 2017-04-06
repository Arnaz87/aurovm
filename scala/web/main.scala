import scala.scalajs.js.JSApp
import arnaud.culang

object TutorialApp extends JSApp {
  def main(): Unit = {
    println("Hello world!")
    val src = "void main () {}"
    culang.Parser.parse(src) match {
      case Right(ast) => println(ast)
      case Left(err) => println(err)
    }
  }
}