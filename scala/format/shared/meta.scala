package arnaud.cobre.format.meta
import scala.util.{Try, Success, Failure}
import scala.collection.mutable.{Buffer, ArrayBuffer}

class InvalidItemException extends Exception
sealed abstract class Item {
  def str: String = throw new InvalidItemException
  def seq: Seq[Item] = throw new InvalidItemException
  def int: Int = throw new InvalidItemException
  def dbl: Double = throw new InvalidItemException
}

case class StrItem (override val str: String) extends Item {
  override def int =
    Try(java.lang.Integer.parseInt(str)) match {
      case Success(n) => n
      case Failure(err) => throw new InvalidItemException
    }
  override def dbl =
    Try(java.lang.Double.parseDouble(str)) match {
      case Success(n) => n
      case Failure(err) => throw new InvalidItemException
    }
  override def toString () = {
    if (str exists ("() \"\n".contains(_))) {
      "\"" + str.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n") + "\""
    } else str
  }
}

class SeqItem (override val seq: Seq[Item]) extends Item {
  override def toString () = "(" + (seq mkString " ") + ")"

  def apply(i: Int) = seq(i)

  def apply(key: String) = seq find {
    case item: SeqItem =>
      seq.headOption match {
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
  //implicit def seqItem (seq: T :< Seq[Item]) = new SeqItem(seq)
  implicit def strItem (str: String) = new StrItem(str)
  implicit def intItem (int: Int) = new StrItem(int.toString)
  implicit def dblItem (dbl: Double) = new StrItem(dbl.toString)
}