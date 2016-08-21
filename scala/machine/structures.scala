package arnaud.myvm

//import arnaud.myvm.Machine._

//def makeStruct (xs: Seq[String]) = new Struct(xs.toArray.map{RegInfo(_)})

case class RegInfo (s: String, t: Struct)

class Struct (
    val info: Array[RegInfo], 
    val name: String = "Unnamed Struct") {
  val size = info.length
  def apply (i: Int) = info(i)
  def findIndex (k: String) =
    info.indexWhere{_.s == k} match {case -1 => None; case n => Some(n)}
  def instantiate () = new Object(this)
  override def toString () = name
}

class Object (val struct: Struct) {
  val arr = new Array[Any](struct.size)
  def apply(k: Key): Value = arr(k)
  def update(k: Key, v: Value) = {
    Machine.debug(struct.name + "[" + struct(k).s + "] = " + v, 2)
    arr(k) = v
  }

  def checkType (k: Key, t: Struct) =
    if (struct(k).t != t) { throw new Exception(
      "Myvm Type mismatch, in struct '" + struct.name +
      "' at register '" + struct(k).s +
      "': Expected " + t.toString +
      ", found " + struct(k).t.toString
    ) }

  object dyn { // Para acceder dinámicamente a los registros.
    def findIndex(k: String) = struct.findIndex(k) match {
      case Some(n) => n
      case None => throw new Error(s"Field $k not found in struct " + struct.name)
    }
    def apply(k: String) = arr(findIndex(k))
    def update(k: String, v: Any) = arr(findIndex(k)) = v
  }
  def printValues () {
    println("Values of a " + struct.name + " instance.")
    for (i <- 0 until struct.size) {
      println(struct(i).s + ": " + arr(i))
    }
  }
}

class Module ( 
    val name: String, 
    val struct: Struct,
    _map: collection.Map[String, Any] = null) {
  val data = struct.instantiate()
  if (_map != null) {
    _map foreach {case (k,v) => data.dyn(k) = v}
  }
  override def toString () = "Module_" + name
}

class Code (
    val code: Array[Instruction], 
    val struct: Struct, 
    val module: Module) {
  override def toString () = "Code"
  def apply = code.apply _
  def update = code.update _
  val length = code.length
  def printValues () {
    code.foreach{println _}
  }
}

// Utilidades

class Dict {
  private val map = collection.mutable.Map[String, Value]()
  def apply (k: String): Value = map.getOrElse(k, null)
  def update (k: String, v: Value) = {
    Machine.debug("<Dict>[" + k + "] = " + v, 2)
    map(k) = v
  }
  override def toString () = map.toString
}

case class Runnable (f: (Value) => Value)

object Structs {
  object Int extends Struct(new Array(0), "Int")
  object Float extends Struct(new Array(0), "Float")
  object String extends Struct(new Array(0), "String")

  object Null extends Struct(new Array(0), "Null")
  object Any extends Struct(new Array(0), "Any")
  object Code extends Struct(new Array(0), "Code")

  object Runnable extends Struct(new Array(0), "Runnable")
  object Dict extends Struct(new Array(0), "Dict")
  object Type extends Struct(new Array(0), "Type")
}