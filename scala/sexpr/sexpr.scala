package arnaud.sexpr

sealed abstract class Node {
  def getString (): Option[String] = None
  def asList (): Option[ListNode] = None
  def lispRepr (): String

  override def toString() = "<S-Expresion " + lispRepr + ">"
}
final class AtomNode (_str: String) extends Node {
  val str: String = _str

  override def getString () = Some(str)

  private def escaped (): String = {
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

  override def lispRepr() =
    if (escaped.length > str.length)
    { "\"" + escaped + "\"" } else { str }
}
final class ListNode(_items: Seq[Node]) extends Node with Seq[Node] {
  val items: Seq[Node] =
    if (_items.isInstanceOf[ListNode]) {
      _items.asInstanceOf[ListNode].items
    } else { _items }

  override def asList () = Some(this)

  override def foreach[T] (f: Node => T) = items.foreach(f)
  override def apply(i: Int) = items(i)
  override def iterator = items.iterator
  override def length = items.length

  override def lispRepr() = "(" + items.map(_.lispRepr).mkString(" ") + ")"

  // Sin esto, scala usaría la definición de Seq
  override def toString () = super[Node].toString
}
object AtomNode {
  def apply (str: String) = new AtomNode(str)
}
object ListNode {
  def apply (lst: Node*) = new ListNode(lst)
}
object Implicits {
  implicit def atomNode(str: String) = new AtomNode(str)
  implicit def listNode(sq: Seq[Node]) = new ListNode(sq)
}

final class Parser (_iter: Iterator[Char]) {
  var iter = _iter
  var head: Option[Char] =
    if (iter.hasNext) { Some(iter.next) } else { None }

  def consume (): Char = {
    val prev = head.get
    head = if (iter.hasNext)
    { Some(iter.next) } else { None }
    prev
  }

  def consumeOnly (ch: Char): Unit = {
    head match {
      case Some(cc) =>
        if (cc != ch) {
          throw new Exception(s"Expected '$ch', got '$cc'")
        } else { consume() }
      case None => throw new Exception(s"Expected '$ch', got EOF")
    }
  }

  def eof (): Boolean = head.isEmpty

  def consumeWhitespace () = {
    while (!eof && head.get.isSpaceChar) { consume() }
  }

  def parseString (): Option[AtomNode] = {
    def helper(str: String): String = {
      head match {
        case None => str
        case Some('"') => str
        case Some('\\') =>
          consume
          head match {
            case None => throw new Exception("Expecting escaped character, got EOF")
            case Some(ch) =>
              consume()
              val cc = ch match {
                case 'n' => '\n'
                case 't' => '\t'
                case _ => ch
              }
              helper(str + cc)
          }
        case Some(ch) =>
          consume
          helper(str + ch)
      }
    }

    head match {
      case Some('"') =>
        consume()
        val str = helper("")
        consumeOnly('"')
        Some(new AtomNode(str))
      case _ => None
    }
  }

  def parseAtom (): Option[AtomNode] = {
    var result = ""
    def isValid (ch: Char): Boolean =
      !ch.isSpaceChar && ch != '(' && ch != ')' && ch != ';' && ch != '"'
    while (!eof && isValid(head.get)) {
      result = result + consume()
    }
    if (result == "") { None } else { Some(new AtomNode(result)) }
  }

  def parseList (): Option[ListNode] = {

    def helper(ls: List[Node]): List[Node] = {
      consumeWhitespace()
      parseNode match {
        case None => ls
        case Some(nd) => helper(nd :: ls)
      }
    }

    head match {
      case Some('(') =>
        consume()
        consumeWhitespace()
        val ls = helper(Nil)
        consumeOnly(')')
        Some(new ListNode(ls.reverse))
      case _ => None
    }
  }

  def parseNode (): Option[Node] = {
    var nd: Option[Node] = parseAtom
    if (nd.isEmpty) { nd = parseString }
    if (nd.isEmpty) { nd = parseList }
    nd
  }
}

object Node {
  def main(args: Array[String]) {
    val text = if (args.length > 0) { args(0) } else { "Abc'd fgh" }
    val parser = new Parser(text.toIterator)
    println(text)
    println(parser.parseNode)
  }
}