
# cobre.core

## Tipos

- bool
- char
- string
- binary
- type

# cobre.prim

Tipos: byte, int, float

- operaciones con enteros:
  + aritméticas: iadd, isub, idiv, imul, imod
  + co bits: ior, iand, ixor, ishl, ishr
  + unarias: ineg, inot
  + comparacion: igt, igte, ilt, ilte, ieq, ineq
  + constantes: imax, imin
- operaciones con reales:
  + aritméticas: fadd, fsub, fdiv, fmul
  + unarias: fneg
  + comparacion: fgt, fgte, flt, flte, feq, fneq
- operaciones con bytes:
  + byte byte: badd, bsub, band, bor, bxor
  + unarias: bnot
  + con enteros: bshl, bshr
  + comparación: bgt, bgte, blt, blte, beq, bneq
- lógicas: and, or, xor, eq, neq
- conversiones: btoi, itof, ftoi, itob
- constructores: bintoi, bintof, getbyte

Todas las operaciones con bytes son seguras, en overflow dan la vuelta, y los shifts son lógicos. Todas las operaciones con reales también son seguras, como está en el IEEE 754.

Todas las operaciones con enteros son error en overflow (si el resultado teórico es mayor a imax o menor a imin), y es error cuando el denominador es cero en idiv e imod, o cuando cualquier operando es negativo en imod.

Los shifts de bits son aritméticos, y son error con distancias negativas(distancia 0 es válida).

ftoi satura el valor del real al rango de los enteros y redondea hacia cero, es error en Nan. itob es simplemente un módulo 256.

# cobre.core.string

Tipos:

- char: Codepoint Unicode
- string: Secuencia de caracteres.
- iterator: Iterador de caracteres de un string

Operaciones:

- itoc(int -> char): El codepoint con el valor numérico indicado.
- ctoi(char -> int): El valor numérico del codepoint indicado.
- eq(string string -> bool): Compara la igualdad byte por byte de dos strings.
- concat(string string -> string)
- itos(int -> string): Representación decimal de un entero
- ftos(float -> string): Representación decimal o en notación científica de un real.
- bintos(binary -> string): Decodifica un binario con texto en forma utf8
- newiter(string -> iterator)
- next(iterator -> null[char]): Lee el siguiente caracter en el string

Muchas de las plataformas más importantes utilizan un pseudo-utf16 (JVM, CLR y Javascript). Sin una codificación específica la única operación con sentido es la iteración, no se puede extraer bytes o caracteres de posiciónes arbitrarias ni se puede saber el tamaño del string.

# cobre.system

Rutinas básicas del sistema

- platform(-> string)
- print(string ->)
- readln(-> string)
- exit(int ->)
- args(-> array[string]): Argumentos usados para iniciar el programa. Si la implementación es un intérprete, el nombre del intérprete no aparece en args.
- getenv(string -> string)
- environment(-> array[string]): Cada línea tiene la forma "key=value"
- pid(-> int)
- wd(-> string): Directorio absoluto actual
- system(string -> bool): Ejecuta el proceso y devuelve si se ejecutó correctamente
- spawn(string -> int): Ejecuta el proceso y devuelve su pid
- cmd(string -> string): Ejecuta el proceso y devuelve el resultado

# cobre.time

Tipos

- time: Tiempo UNIX
- clock: El tiempo más preciso que la plataforma puede dar

Rutinas

- gettime(-> time)
- timedif(time time -> int): El segundo menos el primero
- timetoi(time -> int): Trata de convertirlo en entero, es error si no cabe
- timetostr(time -> string): Representación decimal
- getclock(-> clock)
- clockdif(clock clock -> float): El segundo menos el primero, convertido en segundos

Los tipos de tiempo no pueden ser primitivos, no hay garantías con el tamaño de los primitivos, por lo tanto no hay garantía de que tengan espacio suficiente para almacenar tiempo. Por ejemplo, para abril del 2017 el tiempo unix usa 31 bits, y para almacenar tres horas en nanosegundos se necesitan 34.

# cobre.core.int

Operaciones adicionales para enteros.

- Constantes: imax, imin, izero, ione

## Operaciones con check

Tienen un prefijo "chk", devuelven un boolean adicional que indica si habría error, en cuyo caso el resultado principal es 0.

add, sub, div, mul, mod, neg.

## Operaciones con wrap

Tienen el prefijo "wrp". Si el resultado teórico es mayor a imax, repetidamente evalúan `imin+(n-imax)` hasta que el resultado sea menor o igual a imax, y si es menor a imin, lo mismo con `imax-(n-imin)`.

add, sub, mul

## Bitshifts

En *cobre.prim* los shifts son shift logicos, excepto que son errores con distancias negativas, overflows y cuando el bit del signo cambia. Aquí hay diferentes definiciones de bitshift sin errores:

- lógicos: shl, shr
- aritméticos: sal, sar
- wrap: swl, swr

No sé si esto debería incluirse, porque es difícil adivinar el comportamiento de los shifts si no se sabe el tamaño de los números.

