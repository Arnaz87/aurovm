
# Refactorizar: este archivo debería ser más pequeño.

## Parse binary data into an in-memory data structure.

#=== Types ===#

type
  Signature* = object
    in_types*:  seq[int]
    out_types*: seq[int]

  TypeKind* = enum
    nullT = 0
    importT = 1
    aliasT = 2
    nullableT = 3
    productT = 4
    sumT = 5
    funT = 6
  Type* = object
    case kind*: TypeKind
    of nullT: discard
    of importT:
      mod_index*: int
      name*: string
    of aliasT, nullableT:
      type_index*: int
    of productT, sumT:
      field_types*: seq[int]
    of funT:
      sig*: Signature

  FunctionKind* = enum
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
  Function* = object
    sig*: Signature # Solo para importF y codeF
    index*: int # No para codeF
    case kind*: FunctionKind
    of importF:
      name*: string
    of getF, setF:
      field_index*: int
    else: discard

  StaticKind* = enum
    nullS = 0
    intS = 2
    binS = 3
    typeS = 4
    functionS = 5
  Static* = object
    case kind*: StaticKind
    of intS: value*: int
    of binS: bytes*: seq[uint8]
    of typeS, functionS: index*: int
    of nullS: type_index*: int
    else: discard

  InstKind* = enum endI=0, varI, dupI, setI, sgtI, sstI, jmpI, jifI, nifI, anyI, callI=16
  Inst* = object
    case kind*: InstKind
    of varI: discard
    of callI, endI:
      function_index*: int
      arg_indexes*: seq[int]
    else:
      a*: int
      b*: int

  Module* = object of RootObj
    imports*: seq[string]
    types*: seq[Type]
    functions*: seq[Function]
    statics*: seq[Static]
    blocks*: seq[seq[Inst]]

  Parser = ref object of RootObj
    read_proc: proc(r: Parser): uint8
    pos: int
    module: Module
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

proc parseType (p: Parser): Type =
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

proc parseFunction (p: Parser): Function =
  result.kind = FunctionKind(p.readInt)
  case result.kind
  of nullF: discard
  of importF:
    result.index = p.readInt
    result.name = p.readStr
    result.sig = p.parseSignature
  of codeF:
    result.sig = p.parseSignature
  of unboxF, boxF, callF, anyboxF, anyunboxF:
    result.index = p.readInt
  of getF, setF:
    result.index = p.readInt
    result.field_index = p.readInt

proc parseStatic (p: Parser): Static =
  let k = p.readInt
  if k < 16:
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
    result.type_index = k-16

proc parseBlocks (p: Parser) =
  type Sig = object
    ins: int
    outs: int

  # Todas las funciones definidas en el módulo
  var sigs = newSeq[Sig]()

  # Solo las funciones que necesitan bloque
  var self_sigs = newSeq[Sig]()

  # Recolectar las Figuras de cada funcion
  for f in p.module.functions:
    let sig = case f.kind
      of nullF: Sig(ins: 0, outs: 0)
      of getF, setF, unboxF, anyboxF, anyunboxF:
        Sig(ins: 1, outs: 1)
      of importF, codeF: Sig(
        ins:  f.sig.in_types.len,
        outs: f.sig.out_types.len
      )
      of boxF:
        let t = p.module.types[f.index]
        if t.kind == productT:
          Sig(ins: t.field_types.len, outs: 1)
        else: Sig(ins: 1, outs: 1)
      of callF:
        let t = p.module.types[f.index]
        Sig(
          ins:  t.sig.in_types.len,
          outs: t.sig.out_types.len
        )
    if f.kind == codeF: self_sigs.add(sig)
    sigs.add(sig)

  self_sigs.add( Sig(ins: 0, outs: 0) ) # El bloque static

  p.module.blocks = newSeq[seq[Inst]](self_sigs.len)

  for i, blk in p.module.blocks.mpairs:
    let self_sig = self_sigs[i]
    blk.buildSeq(p.readInt) do -> Inst:
      let kind = p.readInt
      if kind < 16:
        result.kind = InstKind(kind)
        case result.kind
        of endI:
          result.arg_indexes.buildSeq(self_sig.outs) do -> int: p.readInt
        of callI: discard
        of varI: discard
        of dupI, sgtI, jmpI:
          result.a = p.readInt
        else:
          result.a = p.readInt
          result.b = p.readInt
      else:
        result.kind = callI
        result.function_index = kind - 16
        let argc = sigs[result.function_index].ins
        result.arg_indexes.buildSeq(argc) do -> int: p.readInt

proc parseAll (p: Parser) =
  try:
    p.checkFormat

    p.module.imports.buildSeq(p.readInt) do -> string: p.readStr
    p.module.types.buildSeq(p.readInt) do -> Type: p.parseType
    p.module.functions.buildSeq(p.readInt) do -> Function: p.parseFunction
    p.module.statics.buildSeq(p.readInt) do -> Static: p.parseStatic

    p.parseBlocks
  except Exception:
    var e = getCurrentException()
    e.msg &= ". At byte " & $p.pos & ". Parsed so far:\n"

    template printAll(name: string, field: untyped): untyped =
      e.msg &= name & ":\n"
      for x in p.module.field:
        e.msg &= "  " & $x & "\n"

    printAll("imports", imports)
    printAll("types", types)
    printAll("functions", functions)
    printAll("statics", statics)
    printAll("blocks", blocks)
    echo e.getStackTrace()
    raise e

#=== Interface ===#

proc initParser (parser: Parser, read_proc: proc(p: Parser): uint8) =
  parser.pos = 0
  parser.read_proc = read_proc
  parser.module = Module(
    imports: @[],
    types: @[],
    functions: @[],
    statics: @[],
    blocks: @[]
  )

proc parse* (data: seq[uint8]): Module =
  proc read_proc (xp: Parser): uint8 =
    let p = SeqParser(xp)
    if p.pos > p.data.high:
      raise newException(EndOfFileError, "Unexpected end of file")
    result = p.data[p.pos]
  var parser: SeqParser
  new(parser)
  parser.initParser(read_proc)
  parser.data = data
  parser.parseAll
  result = parser.module
