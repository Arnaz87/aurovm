import machine2
import compile

import unittest
import macros

import cobrelib

# JS Compatibility
proc `$` (x: uint8): string = $int(x)

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