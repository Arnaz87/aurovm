import machine

import parse
import compile

import unittest
import macros

import cobrelib

# JS Compatibility
proc `$` (x: uint8): string = $int(x)

# Posible ejemplo para structs:
# http://rosettacode.org/wiki/Tree_traversal#C

macro bin* (xs: varargs[untyped]): untyped =
  var items = newNimNode(nnkBracket)

  for x in xs:

    proc addByte (n: BiggestInt) =
      var node = newNimNode(nnkUInt8Lit, x)
      node.intVal = n
      items.add(node)

    proc addStr (str: string) =
      for i in 0..str.high:
        addByte( BiggestInt(str[i]) )

    proc addInt (n: BiggestInt) =
      proc helper (n: BiggestInt) =
        if n > 0:
          helper(n shr 7)
          addByte(n and 0x7f or 0x80)
      helper(n shr 7)
      addByte(n and 0x7f)

    proc otherwise = items.add(newCall(newIdentNode("uint8"), x))

    case x.kind
    of nnkCharLit..nnkUInt64Lit:
      addByte(x.intVal)
    of nnkStrLit:
      addStr(x.strVal)
    of nnkPrefix:
      if x[0].eqIdent("$"):
        case x[1].kind
        of nnkCharLit..nnkUInt64Lit:
          addInt( x[1].intVal )
        of nnkStrLit:
          addInt( x[1].strVal.len )
          addStr( x[1].strVal )
        else: otherwise()
      else: otherwise()
    else: otherwise()

  return if items.len > 0: prefix(items, "@")
    else: parseExpr("newSeq[uint8](0)")

suite "binary":
  test "basics":
    check bin() == newSeq[uint8](0)
    check bin(0) == @[0u8]
    check bin(1) == @[1u8]
    check bin(127, 128, 129) == @[127u8, 128u8, 129u8]
    check bin('A', 'B', 32) == @[65u8, 66u8, 32u8]
    check bin(2+3) == bin(5)
  test "ints":
    check bin($127) == bin(127)
    check bin($128) == bin(0x81, 0)
    check bin($129) == bin(0x81, 1)
    check bin($0x0808) == bin(0x90, 0x08)
  test "strings":
    check bin("") == bin()
    check bin($"") == bin(0)
    check bin(7, "ab") == bin(7, 'a', 'b')
    check bin($"abcde") == bin(5, "abcde")

suite "Full Tests":

  test "Simple add":
    #[ Features
      type/function import
      function definition
      function call
      static ints
    ]#
    let code = bin(
      "Cobre ~4", 0,
      2, # Modules
        # module #0 is the argument
        1, 1, #1 Define (exports)
          2, 1, $"myadd",
        0, $"cobre.prim", #2 Import
      1, # Types
        1, 2, $"int", #0 import "int" from module 2
      2, # Functions
        1, 2, $"add", #0 import "add" from module 2
          2, 0, 0, 1, 0,
        2, #1 Defined Function (myadd)
          0, # 0 ins
          1, 0, # 1 outs: int
      2, # Statics
        2, $4, #0 int 4
        2, $5, #1 int 5
      4, # Block for #1 (myadd)
        4, 0, #0 = const_0 (4)
        4, 1, #1 = const_1 (5)
        (16 + 0), 0, 1, #2 c = add(#0, #1)
        0, 2, #return #2
      0, # Static Block
    )

    let parsed = parseData(code)
    let compiled = compile(parsed)
    let function = compiled.get_function("myadd")

    let result = function.run(@[])
    check(result == @[Value(kind: intV, i: 9)])

  test "Factorial":
    #[ Features
      recursive function call
    ]#
    let data = bin(
      "Cobre ~4", 0,
      3,
        #0 is the argument module
        1, 1, #1 Define (exports)
          2, 1, $"factorial",
        0, $"cobre.prim", #2 Import cobre.prim
        0, $"cobre.core", #3 import cobre.core
      2, # Types
        1, 2, $"int",
        1, 3, $"bool",
      5, # Functions
        1, 2, $"add", #0 import module[0].add
          2, 0, 0, # 2 ins: int int
          1, 0, # 1 outs: int
        2, #1 Defined Function (factorial)
          1, 0, # 1 ins: int
          1, 0, # 1 outs: int
        1, 2, $"gt", #2
          2, 0, 0, # 2 ins: int int
          1, 1, # 1 outs: bool
        1, 2, $"dec", #3
          1, 0, 1, 0,
        1, 2, $"mul", #4
          2, 0, 0, 1, 0,
      2, # Statics
        2, $0, # int 0
        2, $1, # int 1
      9, # Block for #2
        #0 = ins[0]
        4, 0, #1 = const_0 (0)
        4, 1, #2 = const_1 (1)
        (16 + 2), 0, 1, #3 = gt(#0, #1)
        7, 5, 3, # goto 5 if #3
        0, 2, # return #2 (1)
        (16 + 3), 0, #4 = dec(#0)
        (16 + 1), 4, #5 = factorial(#4)
        (16 + 4), 0, 5, #6 = #0 * #5
        0, 6, # return #6
      0, # Static Block
    )

    let parsed = parseData(data)
    let compiled = compile(parsed)
    let function = compiled.get_function("factorial")
    let result = function.run(@[Value(kind: intV, i: 5)])
    check(result == @[Value(kind: intV, i: 120)])

  test "Simple Pair":

    #[ Features
      Product type and operations
    ]#

    let data = bin(
      "Cobre ~4", 0,
      5,
        #0 is the argument module
        1, 1, #1 Define (exports)
          2, 0, $"main",
        0, $"cobre.prim", #2 Import

        1, 2, #3 Define (arguments for cobre.tuple)
          1, 0, $"0", # type_0 (int)
          1, 0, $"1", # type_2 (int)
        2, $"cobre.tuple", #4 Import functor
        4, 4, 3, #5 Build cobre.tuple
      2, # Types
        1, 2, $"int", #0
        1, 5, $"", #1 tuple(int, #2)
      3, # Functions
        2, #0 Defined Function (main)
          0,
          1, 1,
        1, 5, $"get1", #1 cobre.tuple.get1
          1, 1,
          1, 2,
        1, 5, $"new",  #2 cobre.tuple.new
          2, 0, 2,
          1, 1,
      2, # Statics
        2, $4, #0 int 4
        2, $5, #1 int 5
      5, # Block for #1 (main)
        4, 0, #0 = const_0 (4)
        4, 1, #1 = const_1 (5)
        (16 + 2), 2, 1, #2 = tuple.new(#0, #1)
        (16 + 1), 2, #3 = tuple.get1(#2)
        0, 3, #return #3
      0, # Static Block
    )

    let parsed = parseData(data)
    let compiled = compile(parsed)
    let function = compiled.get_function("main")

    let result = function.run(@[])
    check(result == @[Value(kind: intV, i: 5)])

  test "Int Linked List":

    #[ Features
      Product type and operations
      Nullable type
      Shell type
      Recursive types
    ]#

    let data = bin(
      "Cobre ~4", 0,
      8,
        #0 is the argument module
        1, 1, #1 Define (exports)
          2, 1, $"main",
        0, $"cobre.prim", #2 Import

        1, 2, #3 Define (arguments for cobre.tuple)
          1, 0, $"0", # type_0 (int)
          1, 2, $"1", # type_2 (nullable tuple)
        2, $"cobre.tuple", #4 Import functor
        4, 4, 3, #5 Build cobre.tuple

        1, 1, #6 Define(arguments for cobre.null)
          1, 2, $"0", # type_1 (tuple)
        2, $"cobre.null", #7 Import functor
        4, 7, 6, #8 Build cobre.null
      3, # Types
        1, 2, $"int", #0
        1, 5, $"", #1 tuple(int, #2)
        1, 8, $"", #2 nullable(#1)
      5, # Functions
        2, #0 Defined Function (second)
          1, 2, # 1 ins: type_2
          1, 0, # 1 outs: int
        2, #1 Defined Function (main)
          0,
          1, 1,
        1, 5, $"get0",
          1, 1,
          1, 0,
        1, 5, $"get1",
          1, 1,
          1, 2,
        1, 5, $"new",
          2, 0, 2,
          1, 1,
      4, # Statics
        2, $4, # int 4
        2, $5, # int 5
        2, $6, # int 6
        2, $0,
      7, # Block for #0 (second)
        #0 = arg_0
        9, 5, 0, #1 = #0 or goto 5
        (16 + 3), 1, #2 = get_1(#1)
        9, 5, 2, #3 = #2 or goto 5
        (16 + 2), 3, #4 = get_0(#3)
        0, 4, #return #4
        4, 3, #5 = const_3 (0)
        0, 5, #return #5
      9, # Block for #1 (main)
        1, #0 = null
        4, 2, #1 = const_2 (6)
        (16 + 4), 1, 0, #2 = type_1(#1, #0)
        4, 1, #3 = const_1 (5)
        (16 + 4), 3, 2, #4 = type_1(#3, #2)
        4, 0, #5 = const_0 (4)
        (16 + 4), 5, 4, #6 = type_1(#5, #4)
        (16 + 0), 6, #7 = second(#6)
        0, 7, #return #7
      0, # Static Block
    )

    let parsed = parseData(data)
    let compiled = compile(parsed)
    let function = compiled.get_function("main")

    let result = function.run(@[])
    check(result == @[Value(kind: intV, i: 5)])


  test "Function Object":

    #[ Features
      Function objects
      Function object application function
    ]#

    let data = bin(
      "Cobre ~4", 0,
      5,
        #0 is the argument module
        1, 1, #1 Define (exports)
          2, 4, $"main",
        0, $"cobre.prim", #2

        2, $"cobre.function", #3 Import functor
        1, 2, #4 Define (argument)
          1, 0, $"in0",
          1, 0, $"out0",
        4, 3, 4, #5 Build cobre.function with #4 (int -> int)
      2, # Types
        1, 2, $"int", #0 import cobre.prim.int
        1, 5, $"", #1 type of function(int -> int)
      5, # Functions
        1, 2, $"add", #0
          2, 0, 0, 1, 0,
        2, #1 Defined add4
          1, 0, # 1 ins: int
          1, 0, # 1 out: int
        2, #2 Defined apply5
          1, 1, # 1 in:  (int -> int)
          1, 0, # 1 out: int
        1, 5, $"apply", #3 Apply to ( int -> int )
          2, 1, 0, # 2 ins: (int->int) int
          1, 0, # 1 out: int
        2, #4 Defined main
          0, # 0 ins
          1, 1, # 1 outs: int
      3, # Statics
        2, $4, # int 4
        2, $5, # int 5
        5, 1, # function_1 (add4)
      3, # Block for #1 (add4)
        #0 = arg_0
        4, 0, #1 = const_0 (4)
        (16 + 0), 0, 1, #2 c = add(#0, #1)
        0, 2, #return #2
      3, # Block for #2 (apply5)
        #0 = arg_0
        4, 1, #1 = const_1 (5)
        (16 + 3), 0, 1, #2 = apply(#0, #1)
        0, 2,
      3, # Block for #4 (main)
        4, 2, #0 = const_2 (add4)
        (16 + 2), 0, #1 = apply5(#0)
        0, 1,
      0, # Static Block
    )

    let parsed = parseData(data)
    let compiled = compile(parsed)
    let function = compiled.get_function("main")

    let result = function.run(@[])
    check(result == @[Value(kind: intV, i: 9)])
