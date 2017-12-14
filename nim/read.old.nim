
import machine
import methods

import modules

import sequtils
import strutils

type Prototype = object
  ins: seq[int]
  outs: seq[int]

type CallPromise = object
  rutine: Proc
  inst: int
  target: int

type Parser = ref object of RootObj
  file: File
  modules: seq[Module]
  types: seq[Type]
  procs: seq[Proc]
  prototypes: seq[Prototype]

  call_promises: seq[CallPromise]

  exports: tuple[
    types: seq[tuple[i: int, nm: string]],
    procs: seq[tuple[i: int, nm: string]]
  ]

proc hexPosition(parser: Parser): string =
  parser.file.getFilePos.toHex(4)

proc buildSeq[T](n: int, prc: proc(): T): seq[T] =
  result = newSeq[T](n)
  for i in 0..result.high:
    result[i] = prc()

proc loop(n: int, prc: proc()) =
  for i in 1..n: prc()

#=== Primitives ===#

proc readByte (parser: Parser): uint8 =
  let L = parser.file.readBuffer(result.addr, 1)
  if L != 1: raise newException(IOError, "cannot read byte")

proc readInt (parser: Parser): int =
  var n = 0
  var b = cast[int](parser.readByte)
  while (b and 0x80) > 0:
    n = (n shl 7) or (b and 0x7f)
    b = cast[int](parser.readByte)
  return (n shl 7) or (b and 0x7f)

proc readStr (parser: Parser): string =
  # No sé si el string nativo de nim es utf8
  var length = cast[int](parser.readByte)
  result = newString(length)
  let L = parser.file.readBuffer(addr(result[0]), length)
  if L != length: raise newException(IOError, "cannot read full string")

proc readBytes (parser: Parser, size: int): seq[uint8] =
  if size<0: raise newException(Exception, "Negative size")
  if size==0: return @[]
  result = newSeq[uint8](size)
  let L = parser.file.readBuffer(addr(result[0]), size)
  if L != size: raise newException(IOError, "cannot read full byte data")


#=== Parsers ===#

proc parseImports (parser: Parser) =
  parser.modules = parser.readInt.buildSeq do () -> Module:
    let modName = parser.readStr
    let module = modules[modName]
    if parser.readInt > 0:
      raise newException(Exception, "Import parameters not implemented")
    return module

proc parseTypes (parser: Parser): seq[Type] =
  result = @[]

  let typeCount = parser.readInt

  typeCount.loop do ():
    let kind = parser.readInt
    case kind
    of 0: raise newException(Exception, "Null type kind")
    of 1: raise newException(Exception, "Internal type kind not implemented")
    of 2:
      let modi = parser.readInt
      let module = parser.modules[modi-1]
      let name = parser.readStr
      let tp = module.types[name]
      parser.types.add(tp)
    of 3: raise newException(Exception, "Use type kind not implemented")
    else: raise newException(Exception, "Unknown type kind " & $kind)


proc parseCode (parser: Parser, rut: Proc) = 
  proc readVal (): int = parser.readInt - 1

  let codeLength = parser.readInt

  rut.labels = newSeq[int]()

  # indice necesario para ilbl, en la parte "of 5:"
  var i = -1
  rut.code = codeLength.buildSeq do () -> Inst:
    i.inc()
    let v = parser.readInt
    return case v
      of 0: Inst(kind: iend)
      of 1: Inst(kind: icpy, a: readVal(), b: readVal())
      of 2: Inst(kind: icns, a: readVal(), b: readVal())
      of 5:
        rut.labels.add(i)
        Inst(kind: ilbl, i: readVal())
      of 6: Inst(kind: ijmp, i: readVal())
      of 7: Inst(kind: ijif, i: readVal(), a: readVal())
      of 8: Inst(kind: inif, i: readVal(), a: readVal())
      else:
        if v<16: raise newException(Exception, "Unknown instruction: " & $v)

        let n = v-16
        if n > parser.prototypes.high:
          raise newException(Exception, "Rutine does not exists")

        let proto = parser.prototypes[n]
        let prc = if n > parser.procs.high: nil else: parser.procs[n]

        let outlen = proto.outs.len
        let outs = outlen.buildSeq do () -> int: readVal()

        let inlen = proto.ins.len
        let ins = inlen.buildSeq do () -> int: readVal()

        if n > parser.procs.high:
          parser.call_promises.add(CallPromise(
            rutine: rut,
            inst: i,
            target: n
          ))

        Inst(kind: icall, prc: prc, outs: outs, ins: ins)

proc parseRutines (parser: Parser): seq[Proc] =
  result = @[]

  let count = parser.readInt

  parser.prototypes = count.buildSeq do () -> Prototype:
    let ins  = parser.readInt.buildSeq do () -> int: parser.readInt-1
    let outs = parser.readInt.buildSeq do () -> int: parser.readInt-1
    Prototype(ins: ins, outs: outs)

  for proto in parser.prototypes:
    let kind = parser.readInt
    case kind
    of 0: raise newException(Exception, "Null type kind")
    of 1:
      var rutine = Proc()

      rutine.name = parser.readStr

      let regCount = parser.readInt

      let indexes = proto.ins & proto.outs & (
        regCount.buildSeq do -> int: parser.readInt-1
      )

      rutine.inregs = toSeq(0 .. proto.ins.high)
      rutine.outregs = toSeq(proto.ins.len .. proto.ins.len+proto.outs.high)
      rutine.regs = indexes.map do (x: int) -> Type: parser.types[x]

      parser.parseCode(rutine)

      result.add(rutine)
      parser.procs.add(rutine)
    of 2:
      let modi = parser.readInt
      let module = parser.modules[modi-1]
      let name = parser.readStr
      let rutine = module.procs[name]
      parser.procs.add(rutine)
    of 3: raise newException(Exception, "Use rutine kind not implemented")
    else: raise newException(Exception, "Unknown rutine kind " & $kind)

proc parseConstants (parser: Parser): seq[Value] =

  let IntType = modules["cobre\x1fprim"].types["int"]
  let StringType = modules["cobre\x1fstring"].types["string"]

  let count = parser.readInt

  result = @[]

  while result.len < count:
    let kind = parser.readInt
    case kind
    of 0:
      result.add( Value(kind: nilType) )
    of 1:
      let size = parser.readInt
      var data = parser.readBytes(size)
      result.add( Value(kind: binType, data: data) )
    else:
      if kind < 16: raise newException(Exception, "Unknown constant kind " & $kind)
      else:

        let rutine = parser.procs[kind-16]

        let inCount = case rutine.kind
          of nativeProc: rutine.inCount
          of codeProc: rutine.inregs.len

        let outCount = case rutine.kind
          of nativeProc: rutine.outCount
          of codeProc: rutine.outregs.len

        let constants = result
        let args = inCount.buildSeq do -> Value:
          let index = parser.readInt-1
          if index > constants.high:
            if index < count:
              raise newException(Exception, "Constant lookahead not yet implemented")
            else:
              raise newException(Exception, "Constant does not exists")
          return constants[index]

        #echo "invoking " & $rutine & " with " & $args
        let eval_result = invoke(rutine, args)

        for result_value in eval_result:
          result.add(eval_result)

proc readMagic (parser: Parser) =
  var bytes = newSeq[uint8]()
  while true:
    let b = parser.readByte
    if b == 0: break
    bytes.add(b)

  var redd = ""
  if bytes.len > 0:
    var str = newString(bytes.len)
    copyMem(addr(str[0]), addr(bytes[0]), bytes.len)
    redd = str

  if redd != "Cobre ~1":
    raise newException(Exception, "Invalid magic number: " & redd)


proc parseFile* (filename: string): Module =

  var parser = Parser(
    file: open(filename),
    types: newSeq[Type](),
    procs: newSeq[Proc](),
    call_promises: @[]
  )

  result = Module(name: filename)

  try:
    parser.readMagic()

    parser.parseImports()
    result.types = parser.parseTypes()
    result.procs = parser.parseRutines()

    for prc in result.procs:
      prc.module = result

    for promise in parser.call_promises:
      promise.rutine.code[promise.inst].prc = parser.procs[promise.target]

    result.constants = parser.parseConstants()

  except Exception:

    let e = getCurrentException()

    echo "Error de lectura, archivo \"" & filename & "\", byte " & parser.hexPosition
    echo getCurrentExceptionMsg()
    writeStackTrace()

    quit(QuitFailure)
