package arnaud.cobre.format.meta
import scala.util.{Try, Success, Failure}
import scala.collection.mutable.{Buffer, ArrayBuffer}

class InvalidItemException(from: String, to: String)
  extends Exception(s"$to from $from")
sealed abstract class Item {
  protected def invalid(to: String) = new InvalidItemException(this.toString, to)
  def str: String = throw invalid("String")
  def seq: Seq[Item] = throw invalid("Seq[Item]")
  def int: Int = throw invalid("Int")
  def dbl: Double = throw invalid("Double")
}

case class StrItem (override val str: String) extends Item {
  override def int =
    Try(java.lang.Integer.parseInt(str)) match {
      case Success(n) => n
      case Failure(err) => throw invalid("Int")
    }
  override def dbl =
    Try(java.lang.Double.parseDouble(str)) match {
      case Success(n) => n
      case Failure(err) => throw invalid("Double")
    }
  override def toString () = {
    if (str.exists("() \"\n".contains(_)) || (str == "")) {
      "\"" + str.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n") + "\""
    } else str
  }
}

class SeqItem (override val seq: Seq[Item]) extends Item {
  override def toString () = "(" + (seq mkString " ") + ")"

  def apply(i: Int) = seq(i)

  def apply(key: String): Option[Item] = seq find {
    case item: SeqItem =>
      item.seq.headOption match {
        case Some(head: StrItem) =>
          head.str == key
        case _ => false
      }
    case _ => false
  }
}

object SeqItem {
  def apply (seq: Item*) = new SeqItem(seq)
  def unapply (item: Item) = item match {
    case item: SeqItem => Some(item.seq)
    case _ => None
  }
}

object implicits {
  implicit class OptItemOps (opt: Option[Item]) {
    def apply(key: String): Option[Item] =
      opt flatMap {
        case item: SeqItem => item(key)
        case _ => None
      }
  }

  //implicit def seqItem (seq: T :< Seq[Item]) = new SeqItem(seq)
  implicit def strItem (str: String) = new StrItem(str)
  implicit def intItem (int: Int) = new StrItem(int.toString)
  implicit def dblItem (dbl: Double) = new StrItem(dbl.toString)
}