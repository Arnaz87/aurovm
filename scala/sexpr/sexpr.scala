package arnaud.sexpr

// TODO: Soporte para comentarios.

sealed abstract class Node {
  def getString (): Option[String] = None
  def asList (): Option[ListNode] = None

  final def prettyRepr(): String = Repr.pretty(this)
  final def lispRepr(): String = Repr.repr(this)
  override def toString() = "<S-Expresion " + lispRepr + ">"
}

final class AtomNode (_str: String) extends Node {
  val str: String = _str

  override def getString () = Some(str)
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

object Main {
  def main(args: Array[String]) {
    val demostr = """
      (a b
        (c d) e ;(comentario ((de) parentesis)) f
        g "h \" i" j ;comentario de línea
        (k
          ;(comentario
            (abarcando muchas
              (lineas)))
          (l m (n))
        )
      )
    """
    val text = if (args.length > 0) { args(0) } else { demostr.trim }
    val parser = new Parser(text.toIterator)
    println(text)
    println(parser.parseNode)
  }
}