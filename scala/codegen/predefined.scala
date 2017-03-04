package arnaud.myvm.codegen

object Predefined {
  case class Proc (name: String, 
    override val ins: Seq[String], 
    override val outs: Seq[String])
    extends Signature

  case class Module (types: Set[String], _procs: Array[Proc]) {
    object procs extends Traversable[Proc] {
      def foreach[T] (f: Proc => T) = _procs.foreach(f)
      def get(nm: String) = _procs.find(_.name == nm)
      def apply(nm: String) = get(nm).get
      def contains(nm: String) = !get(nm).isEmpty
    }
  }

  val modules = Map[String, Module](
    "Prelude" -> Module(
      Set("Int", "String", "Any", "Bool"),
      Array(
        Proc("print",
          Array("String"),
          Nil
        ),
        Proc("itos",
          Array("Int"),
          Array("String")
        ),
        Proc("iadd",
          Array("Int", "Int"),
          Array("Int")
        ),
        Proc("gtz",
          Array("Int"),
          Array("Bool")
        ),
        Proc("inc",
          Array("Int"),
          Array("Int")
        ),
        Proc("dec",
          Array("Int"),
          Array("Int")
        )
      )
    )
  )

  def apply(nm: String): Module = modules(nm)
}