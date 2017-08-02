import unittest
import macros

import parse

macro bin (xs: varargs[untyped]): untyped =
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
        else: items.add(x)
      else: items.add(x)
    else: items.add(x)

  return if items.len > 0: prefix(items, "@")
    else: parseExpr("newSeq[uint8](0)")


suite "binary":

  test "basics":
    check bin() == newSeq[uint8](0)
    check bin(0) == @[0u8]
    check bin(1) == @[1u8]

  test "ints":
    check bin(10) == @[10u8]
    check bin(210) == @[210u8]
    check bin($210) != bin(210)
    check bin($127) == @[127u8]
    check bin($128) == @[0x81u8, 0u8]
    check bin($129) == @[0x81u8, 1u8]
    check bin($0x0808) == bin(0x90, 0x08)

  test "chars":
    check bin('a') == bin(97)
    check bin('A') == bin(65)
    check bin('A', 'B') == bin(65, 66)

  test "strings":
    check bin("") == bin()
    check bin($"") == bin(0)
    check bin(3, "ab") == bin(3, 'a', 'b')
    check bin("ab A.") == bin('a', 'b', ' ', 'A', '.')
    check bin($"ab A.") == bin(5, "ab A.")

  test "composite":
    let a: seq[uint8] = bin(2, 3, "ab", 'c', $"A")
    let b: seq[uint8] = @[2u8, 3u8, 97u8, 98u8, 99u8, 1u8, 65u8]
    check a == b


#[suite "parser":

  test "truth":
    let alias = Type(kind: aliasT, type_index: 3)
    check alias == Type(kind: nullT)]#