package arnaud.myvm

object Main {  
  def main (args: Array[String]) {
    import Instruction._
    val module_struct = new Struct(
      Array(
        RegInfo("main", Structs.Code),
        RegInfo("test", Structs.String),
        RegInfo("append", Structs.Runnable),
        RegInfo("holamundo", Structs.String),
        RegInfo("_hola", Structs.String),
        RegInfo("_mundo", Structs.String)
      ),
      "Main Module Struct"
    )
    val module: Module = new Module(
      "Main",
      module_struct,
      Map(
        "test" -> "Hola Mundo!",
        "_hola" -> "Hola",
        "_mundo" -> "Mundo",
        "append" -> Runnable{ (_arg) => 
          val args = _arg.asInstanceOf[Dict]
          val a = args("0").toString
          val b = args("1").toString
          a + b
        }
      )
    )
    val holamundo = new Code(
      Array(
        Load(7, "Main", "append"),

        Load(5, "Main", "_hola"),
        Load(6, "Main", "_mundo"),

        DynObj(4),
        DynSet(4, "0", 5),
        DynSet(4, "1", 6),

        Call(8, 7, 4),

        Print(8),
        End
      ),
      new Struct(
        Array(
          RegInfo("null", Structs.Null), // 0
          RegInfo("module", module_struct),
          RegInfo("args", Structs.Any),
          RegInfo("return", Structs.Any),
          RegInfo("params", Structs.Any), // 4

          RegInfo("_hola", Structs.String), // 5
          RegInfo("_mundo", Structs.String), // 6
          RegInfo("append", Structs.Runnable), // 7
          RegInfo("_holamundo", Structs.String) // 8
        ),
        "Main Code Struct"
      ),
      module
    )
    val code = new Code(
      Array(
        Load(5, "Main", "test"),
        Load(6, "Main", "holamundo"),
        Print(5),
        Call(0, 6, 0),
        End
      ),
      new Struct(
        Array(
          RegInfo("null", Structs.Null), // 0
          RegInfo("module", module_struct),
          RegInfo("args", Structs.Any),
          RegInfo("return", Structs.Any),
          RegInfo("params", Structs.Any), // 4
          RegInfo("test_string", Structs.String), // 5
          RegInfo("holamundo", Structs.String) // 6
        ),
        "Main Code Struct"
      ),
      module
    )
    module.data.dyn("holamundo") = holamundo
    module.data.dyn("main") = code
    Machine.modules("Main") = module

    Machine.start()
  }
}