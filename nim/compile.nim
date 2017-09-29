
# Refactorizar: este archivo debería ser más pequeño.

## Parse binary data into an in-memory data structure.

import machine2 as mach

#=== Types ===#

type
  Signature* = object
    in_types*:  seq[int]
    out_types*: seq[int]

  FuncSig = tuple[f: mach.Function, s: Signature]

  Parser = ref object of RootObj
    read_proc: proc(r: Parser): uint8
    pos: int

    imports: seq[mach.Module]
    types: seq[mach.Type]
    functions: seq[FuncSig]
    
    module: mach.Module

  SeqParser = ref object of Parser
    data: seq[uint8]

  ParseError* = object of Exception
  InvalidModuleError* = object of ParseError
  EndOfFileError* = object of ParseError
  UnknownKindError* = object of ParseError

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
  var bytes = newSeq[uint8]()
  while true:
    let b = parser.read
    if b == 0: break
    bytes.add(b)

  var redd = newString(bytes.len)
  for i in 0..bytes.high:
    redd[i] = char(bytes[i])

  if redd != "Cobre ~2":
    raise newException(InvalidModuleError, "Expected signature \"Cobre ~2\"")

proc parseSignature (p: Parser): Signature =
  result.in_types.buildSeq(p.readInt) do -> int: p.readInt
  result.out_types.buildSeq(p.readInt) do -> int: p.readInt

proc parseType (p: Parser): mach.Type =
  let k = p.readInt
  case k
  of 0: raise newException(Exception, "Null type")
  of 1:
    let module = p.imports[p.readInt]
    let tp = module.get_type(p.readStr)
    return tp
  else:
    raise newException(Exception, "Unsuported type kind " & $k)
  #[var result: Type = Type()
  result.kind = TypeKind(p.readInt)
  case result.kind
  of nullT: discard
  of importT:
    result.mod_index = p.readInt
    result.name = p.readStr
  of aliasT, nullableT:
    result.type_index = p.readInt
  of productT, sumT:
    result.field_types.buildSeq(p.readInt) do -> int: p.readInt
  of funT:
    result.sig = p.parseSignature
  return mach.Type(name: result.name)]#

proc parseFunction (p: Parser): FuncSig =
  #[ 
    nullF = 0
    importF = 1
    codeF = 2
    unboxF = 4
    boxF = 5
    getF = 6
    setF = 7
    anyunboxF = 8
    anyboxF = 9
    callF = 10
  ]#
  case p.readInt
  of 0: # null
    raise newException(Exception, "Null function")
  of 1: # import
    let module = p.imports[p.readInt - 1]
    let function = module.get_function(p.readStr)
    let sig = p.parseSignature
    return (function, sig)
  of 2: #code
    let function = mach.Function(module: p.module, name: "<anonymous>", kind: mach.codeF)
    let sig = p.parseSignature
    return (function, sig)
  else:
    raise newException(Exception, "Unsuported function kind")
  #[
  of unboxF, boxF, callF, anyboxF, anyunboxF:
    result.index = p.readInt
  of getF, setF:
    result.index = p.readInt
    result.field_index = p.readInt
  ]#

proc parseStatic (p: Parser): mach.Value =
  let k = p.readInt
  case k
  of 2:
    return mach.Value(kind: mach.intV, i: p.readInt)
  else:
    raise newException(Exception, "Unsupported static kind " & $k)
  #[if k < 16:
    result.kind = StaticKind(k)
    case result.kind
    of intS:
      result.value = p.readInt
    of binS:
      result.bytes.buildSeq(p.readInt) do -> uint8: p.read
    of typeS, functionS: result.index = p.readInt
    of nullS: discard
    else: discard
  else:
    result.kind = nullS
    result.type_index = k-16]#

proc parseExport (p: Parser): mach.Item =
  let k = p.readInt
  let index = p.readInt-1
  result.name = p.readStr
  case k
  of 1:
    result.kind = mach.tItem
    result.t = p.types[index ]
  of 2:
    result.kind = mach.fItem
    result.f = p.functions[index].f
    result.f.name = result.name
  else:
    raise newException(Exception, "Unknown item kind " & $k)

proc parseBlocks (p: Parser) =

  const instKinds = [
    mach.endI,
    mach.varI,
    mach.dupI,
    mach.setI,
    mach.sgtI,
    mach.sstI,
    mach.jmpI,
    mach.jifI,
    mach.nifI,
    mach.anyI
  ]

  for tpl in p.functions:
    if tpl.f.module != p.module: continue

    # Los primeros registros son los argumentos de la función
    var reg_count = tpl.s.in_types.len

    tpl.f.code.buildSeq(p.readInt) do -> mach.Inst:
      var inst = mach.Inst()
      let k = p.readInt
      if k < instKinds.len:
        inst.kind = instKinds[k]
      elif k >= 16:
        inst.kind = mach.callI
      else:
        raise newException(Exception, "Unknown instruction " & $k)

      case inst.kind
      of mach.varI: discard
      of mach.dupI, mach.sgtI:
        inst.src = p.readInt - 1
        inst.dest = reg_count
        reg_count += 1
      of mach.setI, mach.sstI:
        inst.dest = p.readInt - 1
        inst.src = p.readInt - 1
      of mach.jmpI:
        inst.inst = p.readInt
      of mach.jifI, mach.nifI, mach.anyI:
        inst.inst = p.readInt
        inst.cond = p.readInt - 1
      of mach.endI:
        let count = tpl.s.out_types.len
        inst.args.buildSeq(count) do -> int:
          p.readInt - 1
      of mach.callI:
        let f = p.functions[k - 16]
        inst.f = f.f
        let arg_count = f.s.in_types.len
        let result_count = f.s.out_types.len
        inst.args.buildSeq(arg_count) do -> int:
          p.readInt - 1
        inst.ret = reg_count
        reg_count += result_count
      return inst
    tpl.f.reg_count = reg_count

proc parseAll (p: Parser) =

  try:
    p.checkFormat

    p.imports.buildSeq(p.readInt) do -> mach.Module:
      let name = p.readStr
      let m = find_module(name)
      if m.isNil: raise newException(Exception, "No module " & name)
      m
    p.types.buildSeq(p.readInt) do -> mach.Type: p.parseType
    p.functions.buildSeq(p.readInt) do -> FuncSig: p.parseFunction

    # Static function added at the end
    p.functions.add( (
      mach.Function(
        module: p.module, name: "<static>", kind: mach.codeF
      ),
      Signature(in_types: @[], out_types: @[])
    ) )

    p.module.statics.buildSeq(p.readInt) do -> mach.Value: p.parseStatic
    p.module.items.buildSeq(p.readInt) do -> mach.Item: p.parseExport

    p.parseBlocks
  finally:
    when defined(test):

      var impList = ""
      for imp in p.imports:
        if imp.isNil:
          impList &= "<nil> "
        else:
          impList &= imp.name & " "
      echo "Imports: ", impList

      echo "Types: ", p.types

      echo "Functions:"
      for f in p.functions:
        if f.f.module != p.module:
          echo "  ", f.f.full_name
        elif f.f.kind == mach.codeF:
          echo "  ", f.f.name, ":"
          for inst in f.f.code:
            echo "    ", inst
        else: echo "  ", f.f[]

      echo "Statics: ", p.module.statics

      var itemStr = ""
      for item in p.module.items:
        case item.kind
        of mach.fItem:
          itemStr &= " Function(" & item.f.full_name & ")"
        of mach.tItem:
          itemStr &= " Type(" & item.t.name & ")"
      echo "Items:", itemStr

#=== Interface ===#

proc compile* (data: seq[uint8]): mach.Module =
  proc read_proc (xp: Parser): uint8 =
    let p = SeqParser(xp)
    if p.pos > p.data.high:
      raise newException(EndOfFileError, "Unexpected end of file")
    result = p.data[p.pos]
  var parser: SeqParser
  new(parser)

  parser.pos = 0
  parser.read_proc = read_proc

  parser.module = mach.Module(name: "<main>", items: @[], statics: @[])

  parser.imports = @[]
  parser.types = @[]
  parser.functions = @[]

  parser.data = data
  parser.parseAll

  parser.module