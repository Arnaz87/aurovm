# Cálculo de tipos

En los snippets de cuasm, las líneas que empiezan con `->` son las que no sé cómo representar en el formato.

### Módulos paramétricos

La solución actual son los módulos paramétricos, pero no es la ideal:

1. Algunos elementos genéricos son parte de un módulo más grande que agrupa más funcionalidad, pero con el modelo actual es necesario moverlos a un módulo separado, ya que los que reciben los parámetros no son los elementos sino los módulos en sí. Esto se puede solucionar nombrando al módulo del elemento genérico con el nombre del módulo principal, un separador de grupo ascii y el nombre del elemento, y que el lenguaje se encargue de abstraer esta información cuando use un elemento genérico. ej: *"Prelude`\x1d`Array"*.
2. No es capaz de recibir un número variable de tipos, por lo tanto no puedo representar tuplos o uniones arbitrarios.
3. No es capaz de recibir valores que no sean tipos, por lo tanto no puedo representar arreglos de tamaño fijo.
4. Tampoco sé cómo representar Enums, ADTs, Path Dependent Types, Arrays multidimensionales.
5. No sé cómo recibir un trait como parámetro, es decir, recibir implementaciones de algunas rutinas relacionadas con los tipos recibidos.

### Cálculo de constantes

Se usa en el ejemplo de Macros.

Ventajas:

1. Ya no hace falta separar los elementos genéricos a un módulo separado.
2. Puedo usar rutinas completas para calcular elementos, lo que da muchísima flexibilidad al sistema de módulos.
3. Por lo anterior, ahora sí puedo representar todos los tipos complicados que nombre antes: Tuplos, Uniones, Tipos dependientes, Arrays de tamaño fijo, Arrays multidimensionales, Traits.

Desventajas:

1. Es considerablemente más complicado, específicamente las dependencias complejas entre instancias de genéricos, constantes, tipos definidos, valores.
2. Es más difícil hacer un simple elemento genérico, hay que hacer una rutina que cree el elemento desde cero.
3. Hace falta muchos operadores primitivos para las constantes. Esta es la lista que tengo en mente: Varint, Int64, Float64, Binary, Fixed List, Dynamic List, Local Type, Local Proc
4. No hay un modo obvio de resolver la igualdad de tipos genéricos.

## Uso de genéricos

~~~ cu
int head (int[] arr) {
  return Array_get<int>(arr, 0);
}
~~~

~~~ cuasm
; Igual que abajo
~~~

## Función genérica

~~~ cu
T head<T> (T[] arr) {
  return Array_get<T>(arr, 0);
}
~~~

~~~ cuasm
1 params .T
2 imports
  Prelude
    0 params
    1 type Int
    0 procs
  Array
    1 params .T
    1 types Array.T
    1 procs get.T
0 types
1 procs
  head
    1 ins $arr
    1 out $r
    2 regs
      Array.T $arr
      .T      $r
      Int     $cons_0
    code:
      cns $cons_0 [0]
      get.T $r <- $arr $cons_0
      end
~~~

## Tipo genérico

~~~ cu
struct Box<T> {
  T val;
}
~~~

~~~ cuasm
1 params .T
0 imports
1 types
  Box
    1 regs
      .T  $val
~~~

*Combinación entre módulo paramétrico y cálculo de constantes*

~~~ cuasm
; Todo esto se agrega a la lista de constantes
1 params
  Type $.T
; Los módulos dependencias. Lo que se importa de un módulo
; es tipo o rutina, no constantes
2 imports
  Prelude
    3 types
      Int
      String
      Type
    0 procs
; Las constantes que son tipos
1 usetypes
  ; .T es un parámetro, así que es una constante.
  ; Hay que convertirlo en un tipo usable
  .T
; Definiciones de tipos
1 types
  Box
    1 fields
      ; Cada miembro se añade como rutina
      .T  Box.val
; Convertir constantes en rutinas usables
0 useprocs
; Definiciones de rutinas
1 procs
  $Box.get
    1 ins Box
    1 outs .T
    0 regs
    code:
      Box.val $_out1 <- $_in1
      end
0 consts
  ; Cada constante en la lista tiene un tipo, un formato
  ; y datos que dependen del formato. Si el formato es menor que 16,
  ; es alguno de los especiales, si es igual o mayor a 16, indica el
  ; índice base 16 de una rutina, los datos son las entradas de la
  ; rutina, cada entrada es un índice a otra constante, y cada
  ; salida se añade como constante.
  ; Los formatos disponibles son: varint, byte, int64, float64, binary,
~~~

## Tipo genérico indexado

~~~ cu
void main () {
  Vector<Int, 3> vec = Vector_new<Int, 3>(0);
}
~~~

~~~ cuasm

~~~

## Macros (?)

*Propuesta no terminada*

~~~ cu
Type Box!(Type a) {
  Type r = Type();
  type_add_field("val", a);
  return r;
}

void main () {
  Box!(int) b;
  b.val = 3;
  return b.val;
}
~~~

~~~ cuasm
2 imports
  Prelude
    2 types
      Int
      String
    0 procs
  Module
    1 types
      Type
    2 procs
      type_add_field
      new_type
1 typeconst
  Box<Int>
    1 fields
      val
2 procs
  Box!
    2 ins $a
    1 outs $_out
    4 regs
      Type $a
      Type $_out
      String $const_str
    code:
      new_type $_out
      cns $const_str $_name
      type_add_field $_out $a $const_str
      end
  main
    0 ins
    0 outs
    3 regs
      Box<Int> $b
      Int   $const_3
      Int   $r
    code:
      $b get
3 consts
  $Int: %local_type Int
  $Box<Int>: Box! $Int
  $_name: %binary "val"
~~~

## Tuple

~~~ cu
void main () {
  Tuple<String, Bool> r = read();
}
~~~

~~~ cuasm
2 imports
  Prelude
    0 params
    3 types
      String
      Bool
      Type
    1 rutines
      read [-> Tuple<String, Bool>]
  Array
    1 params
      cns_type
    1 types
      Array
  Tuple
    1 params
      cns_tpl_arr
    1 type
      Tuple
    1 rutines
      create [String Bool -> Tuple]
1 rutines
  1 regs
    Tuple<String, Bool>
  code:
    Prelude.read reg[1] <-
4 consts
  Type cns_type = type(Type)
  Type str_type = type(String)
  Type bool_type = type(Bool)
  Array<Type> cns_tpl_arr = arr(str_type, bool_type)
~~~

~~~ cuasm
2 imports
  Prelude
    0 params
    3 types
      String
      Bool
      Type
    1 rutines
      read [-> Tuple<String, Bool>]
  Array
    1 params
      cns_type
    1 types
      Array
  Tuple
    1 params
      cns_tpl_arr
    1 type
      Tuple
    1 rutines
      create [String Bool -> Tuple]
1 rutines
  1 regs
    Tuple<String, Bool>
  code:
    Prelude.read reg[1] <-
4 consts
  Type cns_type = type(Type)
  Type str_type = type(String)
  Type bool_type = type(Bool)
  Array<Type> cns_tpl_arr = arr(str_type, bool_type)
~~~

## Traits

~~~ cu

~~~

## Abstract Data Types

~~~ haskell
data MaybeInt = Just Int | Nothing

getOrElse :: MaybeInt -> Int -> Int
getOrElse (Just i) _ = i
getOrElse Nothing  i = i
~~~

## GADTs

~~~ haskell
data Singleton a where
  ST :: Int -> Singleton TrueType
  SF :: [Int] -> Singleton FalseType

-- Esto representa a una función de tipos algo así:
-- data Singleton where
--   Singleton True = a
--   Singleton False = [a]

make :: Int -> Singleton TrueType
make n = ST n
-- No compila porque devuelve Singleton FalseType:
-- makeSing n = SF (n :: [])
~~~

## Path Dependent Types

~~~ scala
class A {
  class B
  var b: Option[B] = None
}
val a1 = new A
val a2 = new A
val b1 = new a1.B
val b2 = new a2.B
a1.b = Some(b1)
a2.b = Some(b1) // No compila
~~~

Internamente a1.B y a2.B son de hecho el mismo tipo, pero superficialmente, el typechecker simplemente se asegura de que tengan la misma ruta.

### Segundo Ejemplo

Inspirado en http://danielwestheide.com/blog/2013/02/13/the-neophytes-guide-to-scala-part-13-path-dependent-types.html

~~~ scala
class Franchise(name: String) {
  case class Character(name: String)
  def newFanFic (lover: Character, desire: Character):
    (Character, Character) = (lover, desire)
}

val starTrek = new Franchise("Star Trek")
val starWars = new Franchise("Star Wars")

val kirk = starTrek.Character("James T. Kirk")
val spock = starTrek.Character("Spock")

val luke = starWars.Character("Luke Skywalker")
val yoda = starWars.Character("Yoda")

starWars.makeFanFic(lover=luke, desire=yoda)
starTrek.makeFanFic(lover=spock, desire=luke) // No compila
~~~

### Tercer Ejemplo

Inspirado en http://bytes.codes/2016/04/11/path-dependent-types-in-scala/

~~~ scala
case class Passenger(firstName: String)

class Airplane(flightNumber: Long) {
  case class Seat(row: Int, seat: Char)

  def seatPassenger(passenger: Passenger, seat: Seat): Unit = ()
}

val flt102 = new Airplane(102)
val flt506 = new Airplane(506)

val alice = Passenger("Alice")
val bob = Passenger("Bob")

val flt102_1A = new flt102.Seat(1, 'A')
val flt506_20F = new flt506.Seat(20, 'F')

flt506.seatPassenger(alice, flt506_20F)
flt506.seatPassenger(bob  , flt102_1A) // No compila
~~~


