# Cu

Cu es un lenguaje como C o Java, con las características básicas de la máquina virtual Cobre. Lo estoy haciendo para probar las caracteísticas de la máquina, como subrutinas, sistema de tipos, importación de módulos, etc.

El nombre es un juego de palabras con Cobre y Lenguaje C.

# Modulo

Por ahora no hay mecanismo para módulos, un programa Cu solo puede definir el módulo MAIN, y el único módulo que se puede importar es Prelude, que está definido en el compilador.

## Futura definición de módulo

Un archivo de código Cu define un módulo, el nombre del módulo es el mismo que el del archivo, ignorando la extensión `.cu`. Al compilar un programa Cu, el compilador automáticamente reconoce todos los módulos definidos en la carpeta del programa, pero no los importa, eso es decisión del programador.

# Declaraciones de nivel superior

Las declaraciones de nivel superior son las que definen el contenido de un Módulo y su relación con otros módulos (es decir, sus dependencias).

## Import

Una declaración import indica qué valores de un módulo externo deben ser usables en el módulo actual, y con qué nombre se deben acceder.

`import := "import" externalModuleName "{" {id "=" id ";"} "}"`

## Procedimientos

Los procedimientos son la unidad ejecutable de Cu. Pueden aceptar varios parámetros y devuelven un valor (en el futuro podrán devolver multiples valores, porque Cobre puede hacerlo).

```
proc := "proc" id "(" paramList ")" type procBody
paramList := type id ["," type id]
procBody := "{" {stmt} "}"
type := id
```

## Structs

Aun no voy a implementar Structs, pero los defino igual.

```
struct := "struct" id "{" {type id ";"} "}"
```

# Declaraciones

Son las unidades en las que se divide un procedimiento o un bloque, indican una acción que el programa debe ejecutar. A diferencia de las expresiones, las declaraciones no tienen un resultado, su unico objetivo es ejecutar una acción que cambiará el estado del programa.

## Declaración de variable

Le indica al programa la información de una variable para que pueda ser usada luego. Una sola declaración puede declarar varias variables con el mismo tipo. Se puede asignar un valor a una variable en su propia declaración, en ese caso el resultado se calcula antes de todas las declaraciónes, es decir, en las expresiónes que devuelven el valor de las variables, ninguna de dichas variables se ha declarado. Una declaración oculta cualquier variable declarada anteriormente, incluso si es en el mismo Scope.

`decl := type id ["=" expr {"," id "=" expr}] ";"`

## Asignación de variable

Cambia el valor de una variable por el resultado de una expresion.

`assign := id "=" expr ";"`

## Llamada

Ejecuta un procedimiento pasándole los argumentos indicados, y en caso de tener un resultado lo descarta. Las expresiones de los argumentos se ejecutan en el orden en el que aparecen.

`call := id "(" [expr {"," expr}] ")" ";"`

### Llamada Provisional

Cobre no invoca funciones pasando una lista de argumentos, internamente Cu crea un objeto por medio del cual el invocador y el invocado se pueden comunicar, y ese objeto se usa como los demás objetos, asignando y revisando sus campos. Entonces, la invocación de Cu, para reflejar esa mecánica difiere del modo tradicional, tendré que usar esta mientras ideo una forma de resolverlo.

```
callstmt := call ";"
callexpr := call "." id
call := id "(" [arg {"," arg}] ")"
arg := id "=" expr
```

## Bloque

Un bloque es una secuencia de instrucciones en su propio scope. Las variables declaradas en un bloque no existen fuera de él.

`block := "{" {stmt} "}"`

## If, While

```
if := "if" "(" expr ")" block
while := "while" "(" expr ")" block ["else" block]
```

## Break, Continue

## Return

Si un procedimiento con resultado no termina con return o termina con un return vacío, el resultado es el valor por defecto del tipo que devuelve.

`return := "return" [expr] ";"`

# Expresiones

Las expresiones siempre tienen un valor, incluso si es el valor nulo. A diferencia de las declaraciones, cuyo objetivo es cambiar el estado del programa y se descartan los posibles resultados, las expresiones existen por sus resultados, cambiar el estado del programa es un efecto secundario.

Puede ser una constante (entero, real o texto), una variable o una llamada. La llamada funciona igual que la declaración de llamada, solo que el resultado se usa en vez de descartarse.

```
expr := const | var | call

const := int | real | string
int := digit+ | "0x" hexdigit+ | "0b" ("0"|"1")+
real := digit+ ["." digit+] [("e"|"E") digit+]
string := "\"" {Anye except "\\"| "\\" Any} "\""

var = id

call = id "(" [expr {"," expr}] ")"
```

## Operaciones

Las operaciones solo son azúcar sintáctico para una llamada a algunas funciones especiales. No voy a implementarlas todavía porque esto es una característica del lenguaje, no de la máquina, y es complicado implementarlas por las precedencias.

## Otras

Por ahora, como no existen tipos compuestos como structs o arrays, así que estas son todas las expresiones posibles.