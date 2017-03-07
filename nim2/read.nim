
import machine
import methods

import modules

import sequtils

type Parser = ref object of RootObj
  file: File
  types: seq[Type]
  procs: seq[Proc]

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

#=== Parsers ===#

proc parseImports (parser: Parser) =
  parser.readInt.loop do ():
    let modName = parser.readStr
    let module = modules[modName]

    parser.readInt.loop do ():
      let typeName = parser.readStr
      let mytype = module.types[typename]
      parser.types.add(mytype)

      let fieldCount = parser.readInt
      if fieldCount > 0:
        raise newException(Exception, "Imported type field parser not yet implemented")

    parser.readInt.loop do ():
      let procName = parser.readStr
      let myproc = module.procs[procname]

      if (parser.readInt != myproc.incount):
        raise newException(Exception, "Input count mismatch: " & procName)

      if (parser.readInt != myproc.outcount):
        raise newException(Exception, "Output count mismatch: " & procName)

      parser.procs.add(myproc)

proc parseTypes (parser: Parser): seq[Type] =
  let typeCount = parser.readInt
  if typeCount > 0:
    raise newException(Exception, "Type parser not yet implemented")
  return newSeq[Type](typeCount)

proc parseProcs (parser: Parser): seq[Proc] =
  return parser.readInt.buildSeq do -> Proc:
    let name = parser.readStr

    let inCount = parser.readInt
    let ins = inCount.buildSeq do -> int:
      parser.readInt - 1

    let outCount = parser.readInt
    let outs = outCount.buildSeq do -> int:
      parser.readInt - 1

    let regCount = parser.readInt
    let regs = regCount.buildSeq do -> Type:
      parser.types[parser.readInt - 1]

    Proc(name: name, inregs: ins, outregs: outs, regs: regs)

proc parseCode (parser: Parser, procs: seq[Proc]) = 
  for rut in procs:

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
          let prc = parser.procs[v-16]

          let outlen = case prc.kind
            of nativeProc: prc.outCount
            of codeProc: prc.outregs.len
          let outs = outlen.buildSeq do () -> int: readVal()

          let inlen = case prc.kind
            of nativeProc: prc.inCount
            of codeProc: prc.inregs.len
          let ins = inlen.buildSeq do () -> int: readVal()

          Inst(kind: icall, prc: prc, outs: outs, ins: ins)

proc parseConstants (parser: Parser): seq[Value] =

  let IntType = modules["Prelude"].types["Int"]
  let StringType = modules["Prelude"].types["String"]

  let constCount = parser.readInt

  return constCount.buildSeq do -> Value:
    let tp = parser.types[parser.readInt - 1]

    if tp == IntType:
      var length = parser.readInt
      var value = 0
      while length>0:
        value = (value shl 8) or cast[int](parser.readByte)
        length.dec
      return intValue(value)
    elif tp == StringType:
      return strValue(parser.readStr)
    else:
      raise newException(Exception, "Unrecognized constructor for " & $tp)

proc parseFile* (filename: string): Module =

  var parser = Parser(
    file: open(filename),
    types: newSeq[Type](),
    procs: newSeq[Proc](),
  )

  result = Module(name: filename)

  parser.parseImports()
  result.types = parser.parseTypes()
  result.procs = parser.parseProcs()
  parser.parseCode(result.procs)
  result.constants = parser.parseConstants()

  for prc in result.procs:
    prc.module = result
