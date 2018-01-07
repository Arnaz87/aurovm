# Cantidad de comandos

*[2016-10-22 15:22]*

Cada función o tipo puede ser una de las variaciones:

* externo
* externo genérico
* interno definición
* interno genérico definición
* interno genérico instancia

En total, hay 10 distintas variaciones. Son demasiadas.

Una posible reducción es que los estrictos sean genéricos de 0 argumentos,
entonces se reduce a: externo, interno definición, interno instancia.
El problema es que aunque no se permite en la práctica, en teoría los
estrictos se pueden instanciar.

# Módulos paramétricos

No tiene variaciones, e importar módulos usa parámetros, pero ahora no se pueden importar todos los módulos al principio, si no que hay que mezclarlos con las definiciones de tipos, y la forma binaria ya no es fija sino variable, porque un módulo puede recibir un número arbitrario de parámetros. Una desventaja es que al compilar un programa, cada función polimórfica necesitaría un módulo independiente, lo cual es algo inconveniente.

Total de comandos para esta versión:

* Modulo
* Tipo parámetro
* Tipo externo
* Tipo interno
* Función externa
* Función interna
* Constante
* Metadatos

~~~
typeref H1 = HL[Int, HNil];
typeref H2 = HL[Int, H1];
typeref H3 = HL[Int, H2];
typeref Func = Prelude.Function[HNil, H3];
typeref Tupl = Prelude.Tuple[HNil, H3];
procref call = Prelude.call[HNil, H3];

typeref Tuple3 = Prelude.Tuple3[Int, Int, Int];

proc callFunc () (Func f, Int a, Int b, Int c) {
  H1 h1 = H1(c, HNil);
  H2 h2 = H2(b, h1);
  H3 h3 = H3(a, h2);
  Tupl args = Tupl(h3)
  call(f, args);
}

typeref UFunc = Unsafe.Function;
typeref URegs = Unsafe.Regs;
procref UCall = Unsafe.Call;

proc passArg[T] (UFunc f, T t) () {

}

proc callix[T] (Function[Int, T] f, T args) (Int r) {
  UFunc uf = UFunc(f);
  URegs fr = f.regs.new();
}
~~~

# Restricciones de tipo

*[2016-10-23 11:34]*

Los genéricos sin restricciones de tipos son muy restrictivos. Esto se demuestra en el ejemplo de arriba, tratando de definir las rutinas para las funciones genéricas.

~~~

type HCons [E, L] {
  E e;
  L l;
}

type HNil {};

proc head [E, L] (HList[E, L] hl) (E r) {
  r = hl.e;
}

proc tail [E, L] (HList[E, L] hl) (L r) {
  r = hl.l;
}

proc count

proc count [E, L] (Int r) (HList[E, L]) {
  r = 1 + count(L);
}

proc reduce [R, E, L] (R result) (R acc, Func[R][R, E, L] fun, HList[E, L]) {
  result = fun(acc,)
}

~~~


## Iterator

~~~ cu

type mutIter Mutex<MapIter< T, HashTableIterator<String,T>,
  Function<Tuple2<String,T>,T> >>

typeParam T
type tupl = Tuple2<String, T>
type iner = HashTableIterator<tupl>
type func = Function<tupl, T>
type mapiter = MapIter<T, iner, func>
type mutiter = Mutex<mapiter>

~~~

## Simple with ASM

~~~ cu
Array<T> makeArr<T>(T x, int n) {
  Array<T> arr = Array.new<T>(n);
  Array.set<T>(arr, 0, x);
  return arr;
}
~~~

~~~ cuasm
;;; Sin genéricos
1 procs
  "MakeArray"
  2 ins $x $n
  1 outs $arr
  3 regs
    Object $x
    Int    $n
    Array  $arr
    Int    $const_0
  4 code
    cns $const_0 ...
    Array.new $arr <- $n
    Array.set <- $arr $const_0 $x
    end

;;; Con genéricos
1 procs
  "MakeArray"
  1 tins $.T
  1 tout $.Array.T
  2 tregs $.T $.Array.T
  2 tcode
    ???
  2 ins $x $n
  1 outs $arr
  3 regs
    Object $x
    Int    $n
    Array  $arr
    Int    $const_0
  4 code
    cns $const_0 ...
    Array.new $arr <- $n
    Array.set <- $arr $const_0 $x
    end
~~~

## ADTs

~~~ haskell
data Expr =
    I Int
  | B Bool
  | Add Expr Expr
  | Eq  Expr Expr

eval :: Expr -> Maybe (Either Int Bool)
eval (I i) = Just(Left i)
eval (B b) = Just(Right b)
eval (Add a b) =
  case (eval a, eval b) of
  (Just(Left i), Just(Left j)) -> Just(Left(i+j)
  (_, _) -> Nothing
eval (Eq a b) =
  case (eval a, eval b) of
  (Just(Left  i), Just(Left  j)) -> Just(Left (i==j)
  (Just(Right i), Just(Right j)) -> Just(Right(i==j)
  (_, _) -> Nothing
~~~

En este ejemplo, Cu no soprta ADTS porque no hay herencia, solo tiene structs (y tipos paramétricos). Los ADTS se codifican como Object porque de todos modos habría que averiguar la variante en ejecución. Either es un ADT.

~~~ cu
struct I {i: int}
struct B {b: bool}
struct Add {a: Object, b: Object}
struct Eq  {a: Object, b: Object}

// Either[A, B]
struct Left[A, B] {l: A}
struct Right[A, B] {r: B}

Object eval (o: Object) {
  if (o isa I) { return Left(o as I).i; }
  if (o isa B) { return (o as B).i; }
  if (o isa Add) {
    Add add = o as Add;
    Object a = eval(a), b = eval(b);
    if (a isa Left && b isa Left) {
      return Left{l: (a as Left).l + (b as Left).l};
    } else { return null; }
  }
  if (o isa Eq) {
    Eq add = o as Eq;
    Object a = eval(a), b = eval(b);
    if (a isa Left && b isa Left) {
      return Right{l: (a as Left).l == (b as Left).l};
    } else if (a isa Right && b isa Right) {
      return Right{l: (a as Right).l == (b as Right).l};
    } { return null; }
  }
  if (o isa I) { return (o as I).i; }
}
~~~


## Gadts Simple

~~~ haskell
data Singleton a where
  ST :: Int -> Singleton TrueType
  SF :: [Int] -> Singleton FalseType

make :: Int -> Singleton TrueType
make n = ST n
-- no compila, devuelve Singleton FalseType
-- makeSing n = SF (n :: [])
~~~

~~~ cu
Type Singleton (bool b) {
  if (b) {return Int;}
  else {return List(Int);}
}

Singleton<True> makeSing (int n) { return n; }
~~~

~~~ cuasm
types
  

proc Singleton
  1 ins $b
  1 outs $t
  2 regs
    Boolean $b
    Type    $t
    Type    $i
  x code
    cns $i $$const_Int
    jif $b :true
    List $t <- $i
    end
    lbl :false
    lbl :true
    cpy $t $i
    end

proc makeSing
  1 ins 
~~~

## Gadts

Haskell

~~~
data Expr a where
  I   :: Int  -> Expr Int
  B   :: Bool -> Expr Bool
  Add :: Expr Int -> Expr Int -> Expr Int
  Mul :: Expr Int -> Expr Int -> Expr Int
  Eq  :: Expr Int -> Expr Int -> Expr Bool

eval :: Expr a -> a
eval (I n) = n
eval (B b) = b
eval (Add e1 e2) = eval e1 + eval e2
eval (Mul e1 e2) = eval e1 * eval e2
eval (Eq  e1 e2) = eval e1 == eval e2
~~~

~~~ cu

~~~
