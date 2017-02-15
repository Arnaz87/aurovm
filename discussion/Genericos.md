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

