package arnaud.myvm.lua

object Lexical {
  import fastparse.all._
  val number = {
    sealed abstract class Sign
    case object Positive extends Sign
    case object Negative extends Sign
    def divideTens (n: Double, i: Int): Double =
      if (i < 1) {n} else { divideTens(n/10, i-1) }
    def multiplyTens (n: Double, i: Int): Double =
      if (i < 1) {n} else { multiplyTens(n*10, i-1) }
    val digits = P( CharIn('0' to '9').rep(1).! )
    val sign =
      P(("+"|"-").!.?.map(_ match {
        case Some("+") => Positive
        case Some("-") => Negative
        case None => Positive
        case _ => ???
      }))
    val intpart =
      P(sign ~ digits).map(_ match {
        case (Positive, digits) => digits.toInt
        case (Negative, digits) => -(digits.toInt)
      })
    val realpart =
      P(intpart ~ ("." ~ digits).?).map(_ match {
        case (intpart, None) => intpart.toDouble
        case (intpart, Some(fracpart)) =>
          intpart.toDouble + divideTens(fracpart.toDouble, fracpart.length)
      })
    P( realpart ~ (("e"|"E") ~ sign ~ digits ).?).map(
      _ match {
        case (realpart, None) => realpart
        case (realpart, Some((Positive, expdigits))) =>
          multiplyTens(realpart, expdigits.toInt)
        case (realpart, Some((Negative, expdigits))) =>
          divideTens(realpart, expdigits.toInt)
      }
    ).map(Ast.Num)
  }

  val string = {
    // Esta definición de strings me gusta, pero no es la que usa Lua.
    val validChars = P(!("\\" | "\"") ~ AnyChar.!)
    val uescape = P("\\u" ~/ AnyChar.rep(min=4,max=4).!).map( _.toInt.toChar)
    val xescape = P("\\x" ~/ AnyChar.rep(min=2,max=2).!).map( _.toInt.toChar)
    val escape = P("\\" ~ !("u"|"x"|"z") ~ AnyChar.!).map(_ match {
      case "n" => "\n"
      case "t" => "\t"
      case c => c
    })
    P( "\"" ~/ (validChars|uescape|xescape|escape).rep.map(_.mkString) ~/ "\"" ).map(Ast.Str)
  }

  val const = P(
    kw("true").map( _ => Ast.Bool(true)) |
    kw("false").map(_ => Ast.Bool(false)) |
    kw("nil").map( _ => Ast.Nil)
  )

  val varargs = P("...").map(_ => Ast.Varargs)

  /* Lista de palabras claves:
     operadores: and or not
     constantes: true false nil
     reservadas: do elseif else end for function if in repeat then until while local break return
     añadidas en lua 5.3: goto
     Si se cambia esta lista, cambiar el string de abajo también
  */
  val keywords: Set[String] = "and or not true false nil do elseif else end for function if in repeat then until while local break return goto".split(' ').toSet

  val namechar = CharIn('a' to 'z', 'A' to 'Z', '0' to '9')
  val name = P(CharIn('a' to 'z') ~ namechar.rep).!.filter(!keywords.contains(_))

  def kw (str: String) = P(str ~ !(namechar))

  val comment = P("--" ~ CharsWhile(_ != '\n'))
  val ws = P(CharsWhile(" \n\t".toSet))
  val wscomment = P( (ws|comment).rep )

  //val ops = P("+"|"-"|"*"|"/"|"%"|"^"|"=="|"<="|">="|"<"|">"|"~="|"and"|"or"|"not"|".."|"#")
  /* Tokens especiales:
    +     -     *     /     %     ^     #
    ==    ~=    <=    >=    <     >     =
    (     )     {     }     [     ]
    ;     :     ,     .     ..    ...
    añadidos en lua 5.3:
    &     ~     |     <<    >>    //    ::
  */
  /* Precedencias de operadores:
    1: or
    2: and
    3: < > <= >= ~= == (Lua usa ~= en vez de !=)
    4: .. (asocia a la derecha)
    5: + -
    6: * / %
    7: not # - (todos los unarios)
    8: ^ (asocia a la derecha)

    Añadidos en Lua 5.3:
    3.1: |
    3.2: ~
    3.3: &
    3.4: << >>
    6: //
    7: ~ (unario)
  */
}