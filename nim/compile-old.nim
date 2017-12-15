
# Refactorizar: este archivo debería ser más pequeño.

## Parse binary data into an in-memory data structure.

import machine

#=== Types ===#

type
  Signature* = object
    in_types*:  seq[int]
    out_types*: seq[int]

  FuncSig = tuple[f: Function, s: Signature]

  TypePromise = ref object of RootObj
    t: Type
    data: seq[int]

  ModulePromise = ref object of RootObj
    module: Module
    items: seq[ItemData]

  ItemData = object of RootObj
    name: string
    index: int
    k: int

  Parser = ref object of RootObj
    read_proc: proc(r: Parser): uint8
    pos: int

    imports: seq[Module]
    types: seq[Type]
    functions: seq[FuncSig]

    type_promises: seq[TypePromise]
    module_promises: seq[ModulePromise]
    
    module: Module
    argument: Module

  SeqParser = ref object of Parser
    data: seq[uint8]

  ParseError* = object of Exception
  InvalidModuleError* = object of ParseError
  EndOfFileError* = object of ParseError
  InvalidKindError* = object of ParseError
  NullKindError* = object of ParseError

  CompileError* = object of Exception
  ItemNotFoundError* = object of CompileError
  UnsupportedError* = object of CompileError


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
    let msg = "Expected signature \"Cobre ~2\" but found \"" & sig & "\""
    raise newException(InvalidModuleError, msg)

proc parseSignature (p: Parser): Signature =
  result.in_types.buildSeq(p.readInt) do -> int: p.readInt
  result.out_types.buildSeq(p.readInt) do -> int: p.readInt

proc parseItem (p: Parser): ItemData =
  result.k = p.readInt
  result.index = p.readInt-1
  result.name = p.readStr
  #[
  case k
  of 0: raise newException(UnsupportedError, "Module items are unsupported")
  of 1:
    result.kind = tItem
    result.t = p.types[index]
  of 2:
    result.kind = fItem
    result.f = p.functions[index].f
    result.f.name = result.name
  of 3: raise newException(UnsupportedError, "Value items are unsupported")
  else:
    raise newException(InvalidKindError, "Invalid item kind " & $k)
  ]#

proc parseModule (p: Parser): Module =
  let k = p.readInt
  case k
  of 0: # Import
    let name = p.readStr
    result = find_module(name)
    if result.isNil:
      raise newException(ItemNotFoundError, "module " & name & " not found")
  of 1, 2, 3:
    raise newException(UnsupportedError, "Unsupported module kind " & $k)
  of 4: # Define
    result = Module(name: "<anonymous>", items: @[], statics: @[])
    let promise = ModulePromise()
    p.module_promises.add(promise)
    promise.items.buildSeq(p.readInt) do -> ItemData: p.parseItem
  else:
    raise newException(InvalidKindError, "Invalid module kind " & $k)

proc parseType (p: Parser): Type =
  let k = p.readInt
  case k
  of 0: raise newException(NullKindError, "Null type")
  of 1:
    let module = p.imports[p.readInt]
    let tp = module.get_type(p.readStr)
    return tp
  of 2, 3:
    let kk = case k
      of 2: aliasT
      of 3: nullableT
      else: TypeKind(0)
    let data = @[p.readInt-1]
    result = Type(kind: kk, module: p.module, name: "<type>")
    p.type_promises.add(TypePromise(t: result, data: data))
    return result
  of 4, 5:
    let kk = case k
      of 4: productT
      of 5: sumT
      else: TypeKind(0)
    var data: seq[int] = @[]
    data.buildSeq(p.readInt) do -> int: p.readInt-1
    result = Type(kind: kk, module: p.module, name: "<type>")
    p.type_promises.add(TypePromise(t: result, data: data))
    return result
  of 6:
    result  = Type(kind: functionT)
    let sig = p.parseSignature()

    var data = @[sig.in_types.len]
    data.add(sig.in_types)
    data.add(sig.out_types)

    p.type_promises.add(TypePromise(t: result, data: data))
    return result
  else:
    raise newException(UnsupportedError, "Unsupported type kind " & $k)

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
  return Type(name: result.name)]#

proc solvePromises (parser: Parser) =
  for p in parser.type_promises:
    var str = ""
    var t = p.t
    case t.kind
    of sumT, productT:
      t.ts = newSeq[Type](p.data.len)
      for i in 0 .. p.data.high:
        t.ts[i] = parser.types[p.data[i]]
        str &= " " &  t.ts[i].full_name
    of aliasT, nullableT:
      t.t = parser.types[p.data[0]]
      str = " " & t.t.full_name
    of functionT:
      let inlen = p.data[0]

      t.sig = machine.Signature(
        ins:  newSeq[Type](0),
        outs: newSeq[Type](0)
      )

      for i in 1 .. inlen:
        t.sig.ins.add(parser.types[p.data[i] - 1])
      for i in (inlen + 1) ..< p.data.len:
        t.sig.outs.add(parser.types[p.data[i] - 1])

    else: raise newException(Exception, "???")

    t.name = "<" & $t.kind & str & ">"

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
  let k = p.readInt
  case k
  of 0: # null
    raise newException(NullKindError, "Null function")
  of 1: # import
    let module = p.imports[p.readInt]
    let function = module.get_function(p.readStr)
    let sig = p.parseSignature
    return (function, sig)
  of 2: # code
    let function = Function(module: p.module, name: "<anonymous>", kind: codeF)
    let sig = p.parseSignature
    return (function, sig)
  of 5: # box
    let ti = p.readInt;
    let t = p.types[ti-1]

    let function = builtin_build(t)
    let in_ts = newSeq[int](t.ts.len)
    let sig = Signature(in_types: in_ts, out_types: @[ti]) # !!
    return (function, sig)
  of 6: # get
    let ti = p.readInt;
    let t = p.types[ti-1]
    let i = p.readInt

    let function = builtin_get(t, i)
    let sig = Signature(in_types: @[ti], out_types: @[0]) # !!
    return (function, sig)
  of 10: # call
    let ti = p.readInt;
    let t = p.types[ti-1]

    let function = builtin_call(t)
    let in_ts = newSeq[int](t.sig.ins.len + 1)
    let out_ts = newSeq[int](t.sig.outs.len)
    let sig = Signature(in_types: in_ts, out_types: out_ts) # !!
    return (function, sig)
  else:
    raise newException(UnsupportedError, "Unsuported function kind " & $k)
  #[
  of unboxF, boxF, callF, anyboxF, anyunboxF:
    result.index = p.readInt
  of getF, setF:
    result.index = p.readInt
    result.field_index = p.readInt
  ]#

proc parseStatic (p: Parser): Value =
  let k = p.readInt
  case k
  of 2:
    return Value(kind: intV, i: p.readInt)
  of 5:
    let index = p.readInt-1
    let f = p.functions[index].f
    return Value(kind: functionV, f: f)
  else:
    raise newException(UnsupportedError, "Unsupported static kind " & $k)
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

proc parseBlocks (p: Parser) =

  const instKinds = [
    endI, varI, dupI, setI, sgtI, sstI, jmpI, jifI, nifI, anyI
  ]

  for tpl in p.functions:
    if tpl.f.module != p.module: continue

    # Los primeros registros son los argumentos de la función
    var reg_count = tpl.s.in_types.len

    tpl.f.code.buildSeq(p.readInt) do -> Inst:
      var inst = Inst()
      let k = p.readInt
      if k < instKinds.len:
        inst.kind = instKinds[k]
      elif k >= 16:
        inst.kind = callI
      else:
        raise newException(InvalidKindError, "Unknown instruction " & $k)

      case inst.kind
      of varI:
        reg_count += 1
      of dupI, sgtI:
        inst.src = p.readInt - 1
        inst.dest = reg_count
        reg_count += 1
      of setI, sstI:
        inst.dest = p.readInt - 1
        inst.src = p.readInt - 1
      of jmpI:
        inst.inst = p.readInt
      of jifI, nifI, anyI:
        inst.inst = p.readInt
        inst.src = p.readInt - 1
        if inst.kind == anyI:
          inst.dest = reg_count
          reg_count += 1
      of endI:
        let count = tpl.s.out_types.len
        inst.args.buildSeq(count) do -> int:
          p.readInt - 1
      of callI:
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

    let modlen = p.readInt
    p.imports = newSeq[Module](modlen+1)
    p.imports[0] = p.argument
    for i in 1 .. modlen:
      p.imports[i] = p.parseModule

    #p.imports.buildSeq(p.readInt) do -> Module: p.parseModule

    p.types.buildSeq(p.readInt) do -> Type: p.parseType
    p.functions.buildSeq(p.readInt) do -> FuncSig: p.parseFunction

    #[
    p.imports.buildSeq(p.readInt) do -> Module:
      let name = p.readStr
      let m = find_module(name)
      if m.isNil:
        raise newException(ItemNotFoundError, "module " & name & " not found")
      m

    p.types.buildSeq(p.readInt) do -> Type: p.parseType
    p.solvePromises

    p.functions.buildSeq(p.readInt) do -> FuncSig: p.parseFunction

    # Static function added at the end
    p.functions.add( (
      Function(
        module: p.module, name: "<static>", kind: codeF
      ),
      Signature(in_types: @[], out_types: @[])
    ) )

    p.module.statics.buildSeq(p.readInt) do -> Value: p.parseStatic
    p.module.items.buildSeq(p.readInt) do -> Item: p.parseExport

    p.parseBlocks
    ]#
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

      echo "Functions:" & $p.functions.len
      for f in p.functions:
        if f.f.isNil:
          echo "  ", "<Incomplete>"
        elif f.f.module != p.module:
          echo "  ", f.f.full_name
        elif f.f.kind == codeF:
          echo "  ", f.f.name, ":"
          for inst in f.f.code:
            echo "    ", inst
        else: echo "  ", f.f[]

      echo "Statics: ", p.module.statics

      var itemStr = ""
      for item in p.module.items:
        case item.kind
        of fItem:
          itemStr &= " Function(" & item.f.full_name & ")"
        of tItem:
          itemStr &= " Type(" & item.t.name & ")"
      echo "Items:", itemStr

#=== Interface ===#

proc compile* (data: seq[uint8]): Module =
  proc read_proc (xp: Parser): uint8 =
    let p = SeqParser(xp)
    if p.pos > p.data.high:
      raise newException(EndOfFileError, "Unexpected end of file")
    result = p.data[p.pos]
  var parser: SeqParser
  new(parser)

  parser.pos = 0
  parser.read_proc = read_proc

  parser.module = Module(name: "<main>", items: @[], statics: @[])
  parser.argument = Module(name: "<argument>", items: @[], statics: @[])

  parser.imports = @[]
  parser.types = @[]
  parser.functions = @[]

  parser.type_promises = @[]
  parser.module_promises = @[]

  parser.data = data
  parser.parseAll

  parser.module
