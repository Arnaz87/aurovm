package arnaud.sexpr

class Printer () {
  val spaces = 2 // Spaces per ident

  var identLevel = 0
  var text = ""

  def indent () { identLevel += 1 }
  def undent () { identLevel -= 1 }

  def write (str: String) {
    text += (" " * spaces * identLevel) + str + "\n"
  }
}

object Repr {
  val maxLineSize = 40

  def isValid (ch: Char): Boolean =
    !ch.isSpaceChar && ch != '(' && ch != ')' && ch != ';' && ch != '"'

  def escape(str: String) = {
    var result = ""
    val iter: Iterator[Char] = str.toIterator
    while (iter.hasNext) {
      val cc = iter.next match {
        case '"' => "\\\""
        case '\\' => "\\\\"
        case '\n' => "\\n"
        case '\t' => "\\t"
        case ch => ch
      }
      result += cc
    }
    result
  }
  def quote(str: String) = "\"" + escape(str) + "\""

  def repr (nd: Node): String = nd match {
    case nd:AtomNode =>
      val str = nd.str
      if (str.length > 0 && str.forall(isValid _))
      { str } else { quote(str) }
    case nd:ListNode =>
      "(" + nd.items.map(repr _).mkString(" ") + ")"
  }

  def pretty(nd: Node): String = {
    val printer = new Printer
    pretty(nd, printer)
    printer.text
  }

  def pretty(nd: Node, printer: Printer) {
    nd match {
      case nd:AtomNode => printer.write(repr(nd))
      case nd:ListNode =>
        val rpr = repr(nd)
        if (rpr.length <= maxLineSize) {
          printer.write(rpr)
        } else {
          val (hd, bdy) = nd.headOption match {
            case Some(hd:AtomNode) =>
              ("(" + repr(hd), nd.tail)
            case _ => ("(", nd)
          }
          printer.write(hd)
          printer.indent()
          bdy.foreach(pretty(_, printer))
          printer.undent()
          printer.write(")")
        }
    }
  }
}