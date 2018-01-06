package arnaud.cobre.meta
import scala.util.{Try, Success, Failure}
import scala.collection.mutable.{Buffer, ArrayBuffer}

class InvalidNodeException(from: String, to: String)
  extends Exception(s"$to from $from")
sealed abstract class Node {
  protected def invalid(to: String) = new InvalidNodeException(this.toString, to)
  def str: String = throw invalid("String")
  def seq: Seq[Node] = throw invalid("Seq[Node]")
  def int: Int = throw invalid("Int")
}

case class IntNode(override val int: Int) extends Node {
  override def toString () = int.toString
}

case class StrNode (override val str: String) extends Node {
  override def toString () = {
    if (str.exists("() \"\n".contains(_)) || (str == "")) {
      "\"" + str.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n") + "\""
    } else str
  }
}

class SeqNode (override val seq: Seq[Node]) extends Node {
  override def toString () = "(" + (seq mkString " ") + ")"

  def apply(i: Int) = seq(i)

  def apply(key: String): Option[Node] = seq find {
    case item: SeqNode =>
      item.seq.headOption match {
        case Some(head: StrNode) =>
          head.str == key
        case _ => false
      }
    case _ => false
  }
}

object SeqNode {
  def apply (seq: Node*) = new SeqNode(seq)
  def unapply (item: Node) = item match {
    case item: SeqNode => Some(item.seq)
    case _ => None
  }
}

object implicits {
  implicit class OptNodeOps (opt: Option[Node]) {
    def apply(key: String): Option[Node] =
      opt flatMap {
        case item: SeqNode => item(key)
        case _ => None
      }
  }

  //implicit def seqNode (seq: T :< Seq[Node]) = new SeqNode(seq)
  implicit def strNode (str: String) = StrNode(str)
  implicit def intNode (int: Int) = IntNode(int)
}