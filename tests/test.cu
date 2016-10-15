import Prelude {
  Void = Nil;
  print = print;
}

proc MAIN () {
  // print("Hola"); // forma idónea
  print(a = "Hola");
}

/*
(Imports Prelude)
(Types
  (Void Prelude Nil)
  (String Prelude String)
  (Empty Prelude Empty)
  (print Prelude print)
)
(Structs
  (main-regs
    (SELF SELF)
    (print print)
    ($const$1 String)
  )
)
(Functions
  (MAIN
    Empty ;args
    main-regs ;regs
    (
      (get $const$1 SELF $const$1)
      (set print a $const$1)
      (call print)
      (end)
    )
  )
)
(Constants
  ($const$1 string Hola)
)
*/