
## Parse binary data into an in-memory data structure.

from machine import InstKind
import metadata
import options
from strutils import toHex

## Wether to print the resulting module after parsing
const print_parsed = false

#=== Types ===#

type
  ItemKind* = enum mItem, tItem, fItem
  Item* = object of RootObj
    kind*: ItemKind
    name*: string
    index*: int

  ModuleKind* = enum mImport, mDefine, mImportF, mUse, mBuild
  Module* = object of RootObj
    kind*: ModuleKind
    name*: string
    items*: seq[Item]
    module*: int
    argument*: int

  Type* = object of RootObj
    module*: int
    name*: string

  #InstKind* = enum endI, varI, dupI, setI, sgtI, sstI, jmpI, jifI, nifI, anyI, callI
  Inst* = object of RootObj
    kind*: InstKind
    a*: int
    b*: int
    args*: seq[int]

  Function* = object of RootObj
    internal*: bool
    module*: int
    name*: string
    ins*:  seq[int]
    outs*: seq[int]
    code*: seq[Inst]

  ConstantKind* = enum intConst, binConst, callConst
  Constant* = object of RootObj
    kind*: ConstantKind
    bytes*: seq[uint8]
    value*: int
    args*: seq[int]

  Parser* = ref object of RootObj
    read_proc: proc(): uint8
    pos: int

    modules*: seq[Module]
    types*: seq[Type]
    functions*: seq[Function]
    constants*: seq[Constant]

    metadata*: Node

  ReadError* = object of Exception
    pos: int
  InvalidModuleError* = object of ReadError
  EndOfFileError* = object of ReadError
  InvalidKindError* = object of ReadError
  NullKindError* = object of ReadError

  UnsupportedError* = object of Exception

proc parseRaise*[T](p: Parser, xmsg: string) =
  let msg = xmsg & ", at byte " & p.pos.toHex(4)
  var e = newException(T, msg)
  e.pos = p.pos
  raise e

#=== Primitives ===#

proc buildSeq[T](sq: var seq[T], n: int, prc: proc(): T) =
  sq = newSeq[T](n)
  for i in 0 ..< n:
    sq[i] = prc()

proc read (p: Parser): uint8 =
  result = p.read_proc()
  p.pos += 1

proc readInt (parser: Parser): int =
  var n = 0
  var b = int(parser.read)
  while (b and 0x80) > 0:
    n = (n shl 7) or (b and 0x7f)
    b = int(parser.read)
  return (n shl 7) or (b and 0x7f)

proc readStr (parser: Parser): string =
  var bytes: seq[uint8]
  bytes.buildSeq(parser.readInt) do -> uint8:
    parser.read
  result = newString(bytes.len)
  for i in 0..bytes.high:
    result[i] = char(bytes[i])

#=== Parsing ===#

proc checkFormat (parser: Parser) =
  var sig = ""
  var printable = false
  while true:
    let b = parser.read
    if b == 0: break
    if b >= 0x20u8 and b <= 0x7Eu8:
      printable = true
      sig &= char(b)
    else:
      printable = false
      break

  if sig != "Cobre 0.5":
    var msg = "Expected signature \"Cobre 0.5\""
    if printable: msg &= ", but found \"" & sig & "\""
    raise newException(InvalidModuleError, msg)

proc parseItem (p: Parser): Item =
  result.kind = ItemKind(p.readInt)
  result.index = p.readInt
  result.name = p.readStr

proc parseModule (p: Parser): Module =
  let k = p.readInt
  result.kind = ModuleKind(k)
  case result.kind
  of mImport, mImportF:
    result.name = p.readStr
  of mUse:
    result.module = p.readInt
    result.name = p.readStr
  of mBuild:
    result.module = p.readInt
    result.argument = p.readInt
  of mDefine:
    result.items.buildSeq(p.readInt) do -> Item: p.parseItem
  else:
    parseRaise[InvalidKindError](p, "Invalid module kind " & $k)

proc parseType (p: Parser): Type =
  let k = p.readInt
  if k == 0: raise newException(NullKindError, "Null type")
  result.module = k-1
  result.name = p.readStr

proc parseFunction (p: Parser): Function =
  let k = p.readInt
  result.ins.buildSeq(p.readInt) do -> int: p.readInt
  result.outs.buildSeq(p.readInt) do -> int: p.readInt
  if k == 0: raise newException(NullKindError, "Null function")
  if k == 1: result.internal = true
  else:
    result.internal = false
    result.module = k-2
    result.name = p.readStr

proc parseConstant (p: Parser): Constant =
  let k = p.readInt
  case k
  of 1:
    result.kind = intConst
    result.value = p.readInt
  of 2:
    result.kind = binConst
    result.bytes.buildSeq(p.readInt) do -> uint8: p.read
  else:
    if k < 16: parseRaise[InvalidKindError](p, "Invalid constant kind " & $k)
    result.kind = callConst
    let index = k-16
    result.value = index
    let f = p.functions[index]
    let arg_count = f.ins.len
    result.args.buildSeq(arg_count) do -> int: p.readInt

proc parseCode (p: Parser, sq: var seq[Inst], out_count: int) =

  const instKinds = [endI, hltI, varI, dupI, setI, jmpI, jifI, nifI]

  sq.buildSeq(p.readInt) do -> Inst:
    let k = p.readInt
    if k < instKinds.len:
      result.kind = instKinds[k]
      case result.kind
      of hltI, varI: discard
      of dupI, jmpI:
        result.a = p.readInt
      of setI, jifI, nifI:
        result.a = p.readInt
        result.b = p.readInt
      of endI:
        result.args.buildSeq(out_count) do -> int: p.readInt
      else: discard
    elif k >= 16:
      result.kind = callI
      let index = k-16
      result.a = index
      let arg_count = if index < p.functions.len:
        let f = p.functions[index]
        f.ins.len
      else:
        let c_index = index - p.functions.len
        if c_index >= p.constants.len:
          parseRaise[ReadError](p, "Function index " & $index & " out of bounds (" & $(p.functions.len + p.constants.len) & " total functions)")
        0
      result.args.buildSeq(arg_count) do -> int: p.readInt
    else:
      parseRaise[InvalidKindError](p, "Unknown instruction " & $k)

proc parseNode (p: Parser): Node =
  let n = p.readInt
  if (n and 1) == 1:
    return Node(kind: intNode, n: n shr 1)
  elif (n and 2) == 2:
    var bytes: seq[uint8]
    bytes.buildSeq(n shr 2) do -> uint8: p.read
    var str = newString(bytes.len)
    for i in 0..bytes.high: str[i] = char(bytes[i])
    return Node(kind: strNode, s: str)
  else:
    var nodes: seq[Node]
    nodes.buildSeq(n shr 2) do -> Node: p.parseNode
    return Node(kind: listNode, children: nodes)


proc parse* (read_proc: proc(): uint8): Parser =

  var p = Parser(
    pos: 0,
    read_proc: read_proc,
  )
  result = p

  try:
    p.checkFormat

    p.modules.buildSeq(p.readInt) do -> Module: p.parseModule
    p.types.buildSeq(p.readInt) do -> Type: p.parseType
    p.functions.buildSeq(p.readInt) do -> Function: p.parseFunction
    p.constants.buildSeq(p.readInt) do -> Constant: p.parseConstant

    for i in 0 .. p.functions.high:
      var f = p.functions[i]
      if f.internal:
        p.parseCode(p.functions[i].code, f.outs.len)

    p.metadata = p.parseNode

  finally:
    when defined(test) and print_parsed:

      echo "Modules:"
      for module in p.modules:
        if module.items.isNil:
          echo "  ", module
        else:
          echo "  ", module.items

      echo "Types:"
      for tp in p.types:
        echo "  ", tp

      echo "Functions:"
      for f in p.functions:
        if f.internal:
          echo "  Internal"
        elif not f.name.isNil:
          echo "  module: " & $f.module & ", name: " & f.name
        else:
          echo "  <incomplete>"

        echo "    ins: ", f.ins
        echo "    outs: ", f.outs
        if f.internal:
          echo "    code: ", f.code.len
          for inst in f.code:
            echo "      ", inst

      echo "Constants:"
      for st in p.constants:
        echo "  ", st

#=== Interface ===#

proc parseData* (data: seq[uint8]): Parser =
  var pos: int = 0
  proc read_proc (): uint8 =
    if pos > data.high:
      raise newException(EndOfFileError, "Unexpected end of file")
    result = data[pos]
    pos = pos+1

  parse(read_proc)
