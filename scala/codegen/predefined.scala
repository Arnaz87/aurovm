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
      Set("Int", "String", "Any", "Bool", "Binary"),
      Array(
        Proc("print",
          Array("String"),
          Nil
        ),
        Proc("read",
          Nil,
          Array("String")
        ),
        Proc("itos",
          Array("Int"),
          Array("String")
        ),
        Proc("iadd",
          Array("Int", "Int"),
          Array("Int")
        ),
        Proc("isub",
          Array("Int", "Int"),
          Array("Int")
        ),
        Proc("gt",
          Array("Int", "Int"),
          Array("Int")
        ),
        Proc("gte",
          Array("Int", "Int"),
          Array("Int")
        ),
        Proc("eq",
          Array("Int", "Int"),
          Array("Bool")
        ),
        Proc("concat",
          Array("String", "String"),
          Array("String")
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
        ),

        Proc("makeint",
          Array("Binary"),
          Array("Int")
        ),
        Proc("makestr",
          Array("Binary"),
          Array("String")
        )
      )
    )
  )

  def apply(nm: String): Module = modules(nm)
}