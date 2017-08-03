
# Refactorizar: este archivo es muy grande.

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
    callF = 8
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
  #seq[Inst]* = seq[Inst]

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

#=== Equality ===#

# Equality operations for the types, mostly for testing

proc `==`* (a, b: Type): bool =
  if a.kind == b.kind: return case a.kind
    of nullT: true
    of importT:
      a.mod_index == b.mod_index and a.name == b.name
    of aliasT, nullableT:
      a.type_index == b.type_index
    of productT, sumT:
      a.field_types == b.field_types
    of funT:
      a.sig == b.sig
  return false

proc `==`* (a, b: Function): bool =
  if a.kind != b.kind: return false
  if a.kind == nullF: return true
  if a.kind != codeF and a.index != b.index: return false
  return case a.kind
    of importF: a.sig == b.sig and a.name == b.name
    of codeF: a.sig == b.sig
    of getF, setF: a.field_index == b.field_index
    else: true

proc `==`* (a, b: Static): bool =
  if a.kind == b.kind: return case a.kind
    of intS: a.value == b.value
    of binS: a.bytes == b.bytes
    of typeS, functionS: a.index == b.index
    of nullS: a.type_index == b.type_index
    else: true
  return false

proc `==`* (a, b: Inst): bool =
  if a.kind == b.kind: return case a.kind
    of varI: true
    of endI: a.arg_indexes == b.arg_indexes
    of callI: a.function_index == b.function_index and a.arg_indexes == b.arg_indexes
    of dupI, sgtI, jmpI: a.a == b.a
    else: a.a == b.a and a.b == b.b
  return false

#=== Primitives ===#

proc buildSeq[T](n: int, prc: proc(): T): seq[T] =
  result = newSeq[T](n)
  for i in 0..result.high:
    result[i] = prc()

proc read (p: Parser): uint8 =
  result = p.read_proc(p)
  p.pos += 1

proc readInt (parser: Parser): int =
  var n = 0
  var b = cast[int](parser.read)
  while (b and 0x80) > 0:
    n = (n shl 7) or (b and 0x7f)
    b = cast[int](parser.read)
  return (n shl 7) or (b and 0x7f)

proc readStr (parser: Parser): string =
  var bytes = parser.readInt.buildSeq do -> uint8:
    parser.read
  result = ""
  if bytes.len > 0:
    result = newString(bytes.len)
    copyMem(addr(result[0]), addr(bytes[0]), bytes.len)

#=== Parsing ===#

proc checkFormat (parser: Parser) =
  var bytes = newSeq[uint8]()
  while true:
    let b = parser.read
    if b == 0: break
    bytes.add(b)

  var redd = ""
  if bytes.len > 0:
    var str = newString(bytes.len)
    copyMem(addr(str[0]), addr(bytes[0]), bytes.len)
    redd = str

  if redd != "Cobre ~2":
    raise newException(InvalidModuleError, "Expected signature \"Cobre ~2\"")

proc parseSignature (p: Parser): Signature =
  result.in_types  = p.readInt.buildSeq do -> int: p.readInt
  result.out_types = p.readInt.buildSeq do -> int: p.readInt

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
    result.field_types =
      p.readInt.buildSeq do -> int:
        p.readInt
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
  of unboxF, boxF, callF:
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
      result.bytes =
        p.readInt.buildSeq do -> uint8:
          p.read
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

  for f in p.module.functions:
    let sig = case f.kind
      of nullF: Sig(ins: 0, outs: 0)
      of getF, setF, unboxF: Sig(ins: 1, outs: 1)
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
    blk = @[]
    let self_sig = self_sigs[i]
    let count = p.readInt
    for i in 0..<count:
      var inst = Inst()
      let kind = p.readInt
      if kind < 16:
        inst.kind = InstKind(kind)
        case inst.kind
        of endI:
          inst.arg_indexes =
            self_sig.outs.buildSeq do -> int:
              p.readInt
        of callI: discard
        of varI: discard
        of dupI, sgtI, jmpI:
          inst.a = p.readInt
        else:
          inst.a = p.readInt
          inst.b = p.readInt
      else:
        inst.kind = callI
        inst.function_index = kind - 16
        inst.arg_indexes =
          sigs[inst.function_index].ins.buildSeq do -> int:
            p.readInt
      blk.add(inst)

proc parseAll (p: Parser) =
  try:
    p.checkFormat

    p.module.imports =
      p.readInt.buildSeq do -> string:
        p.readStr

    p.module.types =
      p.readInt.buildSeq do -> Type:
        p.parseType

    p.module.functions =
      p.readInt.buildSeq do -> Function:
        p.parseFunction

    p.module.statics =
      p.readInt.buildSeq do -> Static:
        p.parseStatic

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
