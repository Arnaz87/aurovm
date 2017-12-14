
# Refactorizar: este archivo debería ser más pequeño.

## Parse binary data into an in-memory data structure.

#=== Types ===#

type
  ItemKind = enum mItem, tItem, fItem, vItem
  Item = object of RootObj
    kind: ItemKind
    name: string
    index: int

  ModuleKind = enum mImport, mDefine, mImportF, mUse, mBuild
  Module = object of RootObj
    kind: ModuleKind
    name: string
    items: seq[Item]
    module: int
    argument: int

  Type = object of RootObj
    module: int
    name: string

  InstKind = enum endI, varI, dupI, setI, sgtI, sstI, jmpI, jifI, nifI, anyI, callI
  Inst = object of RootObj
    kind: InstKind
    a: int
    b: int
    args: seq[int]

  Function = object of RootObj
    internal: bool
    module: int
    name: string
    ins:  seq[int]
    outs: seq[int]
    code: seq[Inst]

  StaticKind = enum intStatic, binStatic, typeStatic, funStatic, nullStatic
  Static = object of RootObj
    kind: StaticKind
    bytes: seq[uint8]
    value: int

  Parser = ref object of RootObj
    read_proc: proc(r: Parser): uint8
    pos: int

    modules: seq[Module]

    types: seq[Type]
    functions: seq[Function]
    statics: seq[Static]
    static_code: seq[Inst]

  ReadError* = object of Exception
  InvalidModuleError* = object of ReadError
  EndOfFileError* = object of ReadError
  InvalidKindError* = object of ReadError
  NullKindError* = object of ReadError

  UnsupportedError* = object of Exception


#=== Primitives ===#

proc buildSeq[T](sq: var seq[T], n: int, prc: proc(): T) =
  sq = newSeq[T](n)
  for i in 0 ..< n:
    sq[i] = prc()

proc read (p: Parser): uint8 =
  result = p.read_proc(p)
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

  if not printable:
    raise newException(InvalidModuleError, "Expected a printable ASCII signature")
  elif sig != "Cobre ~4":
    let msg = "Expected signature \"Cobre ~4\" but found \"" & sig & "\""
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
    raise newException(InvalidKindError, "Invalid module kind " & $k)

proc parseType (p: Parser): Type =
  let k = p.readInt
  case k
  of 0: raise newException(NullKindError, "Null type")
  of 1:
    result.module = p.readInt
    result.name = p.readStr
  else:
    raise newException(InvalidKindError, "Invalid type kind " & $k)

proc parseFunction (p: Parser): Function =
  let k = p.readInt
  case k
  of 0: raise newException(NullKindError, "Null function")
  of 1: # import
    result.internal = false
    result.module = p.readInt
    result.name = p.readStr
  of 2: # code
    result.internal = true
  else: raise newException(InvalidKindError, "Invalid function kind " & $k)

  result.ins.buildSeq(p.readInt) do -> int: p.readInt
  result.outs.buildSeq(p.readInt) do -> int: p.readInt

proc parseStatic (p: Parser): Static =
  let k = p.readInt
  case k
  of 0: raise newException(NullKindError, "Null static")
  of 1: raise newException(UnsupportedError, "Unsupported import kind")
  of 2:
    result.kind = intStatic
    result.value = p.readInt
  of 3:
    result.kind = binStatic
    result.bytes.buildSeq(p.readInt) do -> uint8: p.read
  of 4:
    result.kind = typeStatic
    result.value = p.readInt
  of 5:
    result.kind = funStatic
    result.value = p.readInt
  else:
    if k < 16:
      raise newException(InvalidKindError, "Invalid static kind " & $k)
    result.kind = nullStatic
    result.value = k-16

proc parseCode (p: Parser, sq: var seq[Inst], out_count: int) =

  const instKinds = [
    endI, varI, dupI, setI, sgtI, sstI, jmpI, jifI, nifI, anyI
  ]

  sq.buildSeq(p.readInt) do -> Inst:
    let k = p.readInt
    if k < instKinds.len:
      result.kind = instKinds[k]
      case result.kind
      of varI, callI: discard
      of dupI, sgtI, jmpI:
        result.a = p.readInt
      of setI, sstI, jifI, nifI, anyI:
        result.a = p.readInt
        result.b = p.readInt
      of endI:
        result.args.buildSeq(out_count) do -> int: p.readInt
    elif k >= 16:
      result.kind = callI
      let index = k-16
      result.a = index
      let f = p.functions[index]
      let arg_count = f.ins.len
      result.args.buildSeq(arg_count) do -> int: p.readInt
    else:
      raise newException(InvalidKindError, "Unknown instruction " & $k)


proc parseAll (p: Parser) =

  try:
    p.checkFormat

    p.modules.buildSeq(p.readInt) do -> Module: p.parseModule
    p.types.buildSeq(p.readInt) do -> Type: p.parseType
    p.functions.buildSeq(p.readInt) do -> Function: p.parseFunction
    p.statics.buildSeq(p.readInt) do -> Static: p.parseStatic

    for i in 0 .. p.functions.high:
      var f = p.functions[i]
      if f.internal:
        p.parseCode(p.functions[i].code, f.outs.len)

    p.static_code = @[]
    p.parseCode(p.static_code, 0)

  finally:
    when defined(test):

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

      echo "Statics:"
      for st in p.statics:
        echo "  ", st

      echo "Static Code: "
      for inst in p.static_code:
        echo "  ", inst

#=== Interface ===#

proc compile* (data: seq[uint8]): Parser =
  proc read_proc (p: Parser): uint8 =
    if p.pos > data.high:
      raise newException(EndOfFileError, "Unexpected end of file")
    result = data[p.pos]

  var parser = Parser(
    pos: 0,
    read_proc: read_proc,
  )

  parser.parseAll
  parser
