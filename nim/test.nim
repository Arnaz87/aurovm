import machine
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
    let data = bin(
      "Cobre ~2", 0,
      1, $"cobre.prim", # Imports
      1, # Types
        1, 0, $"int",
      2, # Functions
        1, 1, $"add",
          2, 0, 0, 1, 0,
        2, # Defined Function
          0, # 0 ins
          1, 1, # 1 ins: int
      2, # Statics
        2, $4, # int 4
        2, $5,
      1, # Exports
        2, 2, $"myadd",
      4, # Block for #2
        4, 1, #0 = const_0 (4)
        4, 2, #1 = const_1 (5)
        (16 + 0), 1, 2, #2 c = add(#1, #2)
        0, 3, #return #2
      0, # Static Block
    )

    let compiled = compile(data)
    let function = compiled.get_function("myadd")

    let result = function.run(@[])
    check(result == @[Value(kind: intV, i: 9)])

  test "Factorial":
    let data = bin(
      "Cobre ~2", 0,
      2, $"cobre.prim", $"cobre.core", # Imports
      2, # Types
        1, 0, $"int",
        1, 1, $"bool",
      5, # Functions
        # import module[0].add
        1, 1, $"add",
          2, 0, 0, # 2 ins: int int
          1, 0, # 1 outs: int
        2, # Defined Function
          1, 1, # 1 ins: int
          1, 1, # 1 outs: int
        1, 1, $"gt",
          2, 0, 0, # 2 ins: int int
          1, 1, # 1 outs: bool
        1, 1, $"dec",
          1, 0, 1, 0,
        1, 1, $"mul",
          2, 0, 0, 1, 0,
      2, # Statics
        2, $0, # int 0
        2, $1, # int 1
      1, # Exports
        # function 2 as factorial
        2, 2, $"factorial",
      9, # Block for #2
        #0 = ins[0]
        4, 1, #1 = const_0 (0)
        4, 2, #2 = const_1 (1)
        (16 + 2), 1, 2, #3 = gt(#0, #1)
        7, 5, 4, # goto 5 if #3
        0, 3, # return #2 (1)
        (16 + 3), 1, #4 = dec(#0)
        (16 + 1), 5, #5 = factorial(#4)
        (16 + 4), 1, 6, #6 = #0 * #5
        0, 7, # return #6
      0, # Static Block
    )

    let compiled = compile(data)
    let function = compiled.get_function("factorial")

    let result = function.run(@[Value(kind: intV, i: 5)])
    check(result == @[Value(kind: intV, i: 120)])

  test "Int Linked List":

    let data = bin(
      "Cobre ~2", 0,
      1, $"cobre.prim", # Imports
      3, # Types
        1, 0, $"int",
        4, 2, 1, 3, # Product(type_0, type_2)
        3, 2, # Nullable(type_1)
      5, # Functions
        2, # Defined Function, second
          1, 3, # 1 ins: type_2
          1, 1, # 1 ins: int
        2, # Defined Function, main
          0, 1, 1,
        6, 2, 0, # Get type_1[0]
        6, 2, 1, # Get type_1[1]
        5, 2, # Build type_1 (int, type_2)
      4, # Statics
        2, $4, # int 4
        2, $5, # int 5
        2, $6, # int 6
        2, $0,
      1, # Exports
        2, 2, $"main",
      7, # Block for #0 (second)
        #0 = arg_0
        9, 5, 1, #1 = #0 or goto 5
        (16 + 3), 2, #2 = get_1(#1)
        9, 5, 3, #3 = #2 or goto 5
        (16 + 2), 4, #4 = get_0(#3)
        0, 5, #return #4
        4, 4, #5 = const_3 (0)
        0, 6, #return #5
      9, # Block for #1 (main)
        1, #0 = null
        4, 3, #1 = const_2 (6)
        (16 + 4), 2, 1, #2 = type_1(#1, #0)
        4, 2, #3 = const_1 (5)
        (16 + 4), 4, 3, #4 = type_1(#3, #2)
        4, 1, #5 = const_0 (4)
        (16 + 4), 6, 5, #6 = type_1(#5, #4)
        (16 + 0), 7, #7 = second(#6)
        0, 8, #return #7
      0, # Static Block
    )

    let compiled = compile(data)
    let function = compiled.get_function("main")

    let result = function.run(@[])
    check(result == @[Value(kind: intV, i: 5)])


  test "Function Object":

    let data = bin(
      "Cobre ~2", 0,
      1, $"cobre.prim", # Imports
      2, # Types
        1, 0, $"int", # import cobre.prim.int
        6, # function
          1, 1, # 1 in:  int
          1, 1, # 1 out: int
      5, # Functions
        1, 1, $"add",
          2, 0, 0, 1, 0,
        2, # Defined Function 1, add4
          1, 1, # 1 ins: int
          1, 1, # 1 out: int
        2, # Defined Function 2, apply5
          1, 2, # 1 in:  int(int)
          1, 1, # 1 out: int
        10, 2, # Apply type_1 ( int(int) )
        2, # Defined Function 4, main
          0, # 0 ins
          1, 1, # 1 outs: int
      3, # Statics
        2, $4, # int 4
        2, $5, # int 5
        5, 2, # function_1 (add4)
      1, # Exports
        2, 5, $"main",
      3, # Block for #1 (add4)
        #0 = arg_0
        4, 1, #1 = const_0 (4)
        (16 + 0), 1, 2, #2 c = add(#0, #1)
        0, 3, #return #2
      3, # Block for #2 (apply5)
        #0 = arg_0
        4, 2, #1 = const_1 (5)
        (16 + 3), 1, 2, #2 = apply(#0, #1)
        0, 3,
      3, # Block for #4 (main)
        4, 3, #0 = const_2 (add4)
        (16 + 2), 1, #1 = apply5(#0)
        0, 2,
      0, # Static Block
    )

    let compiled = compile(data)
    let function = compiled.get_function("main")

    let result = function.run(@[])
    check(result == @[Value(kind: intV, i: 9)])