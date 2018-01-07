# Tipos Básicos de Diferentes Lenguajes

# C/C++

Primitivos:

- enteros (u8 s8 u32 s32 u64 s64)
- flotantes (f32 f64)

Complejos:

- puntero (+ array función)
- struct

# Java/C#

Primitivos:

- enteros (u8 s8 s16 s32 s64) (C# + u16 u32 u64)
- flotantes (f32 f64)
- booleano

Complejos:

- array
- clase

# D

Primitivos:

- enteros ({u s}{8 16 32 64 128})
- flotantes (f32 f64)
- imaginarios (f32 f64)
- complejos (c{f32 f32} c{f64 f64})
- caracteres (u8 u16 u32)

Derivados:

- puntero
- array (estático y dinámico) (+ string)
- asociativo
- funcion
- delegada (union de instancia y miembro, o de funcion y closura)

Usuario:

- enum
- struct
- union
- clase

# Míos

- Sum (Union, ADT, Trait)
- Product (Struct, Tuple)
- Top, Bottom, Unit, Void

- ADT (Sum of Products)
- Enum (Sum of Units)
- Values (Product of Enums)

Ejemplo:
~~~
Zero = Unit
One = Unit
Bit = Sum {One | Zero}
Digit = Sum {Zero | One | ... | Nine}
Int8 = Product {Bit, Bit, Bit, ... *8}

Float32 = Product {
  Bit,
  Product {Bit, Bit ... *8},
  Product {Bit, Bit, ... *23}
}

Number = Sum {
  Zero,
  Product {Digit, Number},
}

BitAdd :: (Bit, Bit) -> (Bit, Bit)
BitAdd (Zero, Zero) = (Zero, Zero)
BitAdd (Zero, One) = (Zero, One)
BitAdd (One, Zero) = (Zero, One)
BitAdd (One, One) = (One, Zero)

BitAdd3 :: (Bit, Bit, Bit) -> (Bit, Bit)
BitAdd3 (a, b, c) = ...

Int8Add :: Int8 -> Int8 -> Int8
Int8Add Int8{a1, a2, ...} Int8{b1, b2, ...} =
  let (d1, c1) = BitAdd3(a1, b1, Zero)
  let (d2, c2) = BitAdd3(a2, b2, d1)
  ...
  let (_, c8) = BitAdd3(a8, b8, d7)
  Int8{c1, c2, c3, ...  c8}
~~~




- Struct Ref
  - Array
  - String
  - Any
- Struct Val
  - bool
  - u8
  - i32
  - i64
  - f32
  - f64
- Union
- Option
- Bottom
- Top
- Void
