
import machine
import methods

import modules

import sequtils

type Prototype = object
  ins: seq[int]
  outs: seq[int]

type Parser = ref object of RootObj
  file: File
  types: seq[Type]
  procs: seq[Proc]
  prototypes: seq[Prototype]

  exports: tuple[
    types: seq[tuple[i: int, nm: string]],
    procs: seq[tuple[i: int, nm: string]]
  ]


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

proc parseBasics (parser: Parser) =
  let typeCount = parser.readInt
  let rutCount = parser.readInt
  let constCount = parser.readInt

  let paramCount = parser.readInt
  if paramCount > 0:
    raise newException(Exception, "Module parameters not implemented")

  let typeExports = parser.readInt
  if typeExports > 0:
    raise newException(Exception, "Module Exports not implemented")
  let rutExports = parser.readInt
  if rutExports > 0:
    raise newException(Exception, "Module Exports not implemented")

  parser.prototypes = rutCount.buildSeq do () -> Prototype:
    let inCount = parser.readInt
    let ins = inCount.buildSeq do () -> int: parser.readInt-1

    let outCount = parser.readInt
    let outs = outCount.buildSeq do () -> int: parser.readInt-1

    Prototype(ins: ins, outs: outs)


proc parseImports (parser: Parser) =
  parser.readInt.loop do ():
    let modName = parser.readStr
    let module = modules[modName]

    if parser.readInt > 0:
      raise newException(Exception, "Import parameters not implemented")

    parser.readInt.loop do ():
      let typeName = parser.readStr
      let mytype = module.types[typename]
      parser.types.add(mytype)

    parser.readInt.loop do ():
      let procName = parser.readStr
      let myproc = module.procs[procname]

      let proto = parser.prototypes[parser.procs.len]

      if (myproc.incount != proto.ins.len):
        raise newException(Exception, "Input count mismatch: " & procName)

      if (myproc.outcount != proto.outs.len):
        raise newException(Exception, "Output count mismatch: " & procName)

      parser.procs.add(myproc)

proc parseTypes (parser: Parser): seq[Type] =
  let typeCount = parser.readInt
  if typeCount > 0:
    raise newException(Exception, "Type parser not yet implemented")
  return newSeq[Type](typeCount)

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
        let proto = parser.prototypes[v-16]
        let prc = parser.procs[v-16]

        let outlen = proto.outs.len
        let outs = outlen.buildSeq do () -> int: readVal()

        let inlen = proto.ins.len
        let ins = inlen.buildSeq do () -> int: readVal()

        Inst(kind: icall, prc: prc, outs: outs, ins: ins)

proc parseRutines (parser: Parser): seq[Proc] =
  result = @[]

  let startIndex = parser.procs.len
  let count = parser.readInt

  count.loop do (): parser.procs.add Proc()

  for i in startIndex..<(startIndex+count):

    let proto = parser.prototypes[i]
    let rutine = parser.procs[i]

    let regCount = parser.readInt

    let indexes = proto.ins & proto.outs & (
      regCount.buildSeq do -> int: parser.readInt-1
    )

    rutine.name = ""
    rutine.inregs = toSeq(0 .. proto.ins.high)
    rutine.outregs = toSeq(proto.ins.len .. proto.ins.len+proto.outs.high)
    rutine.regs = indexes.map do (x: int) -> Type: parser.types[x]

    parser.parseCode(rutine)

    result.add rutine

proc parseUses (parser: Parser) =
  let typeCount = parser.readInt
  if typeCount > 0:
    raise newException(Exception, "Type use is not implemented")
  let rutCount = parser.readInt
  if rutCount > 0:
    raise newException(Exception, "Rutine use not implemented")

proc parseConstants (parser: Parser): seq[Value] =

  let IntType = modules["Prelude"].types["Int"]
  let StringType = modules["Prelude"].types["String"]

  let constCount = parser.readInt

  return constCount.buildSeq do -> Value:
    let fmt = parser.readInt

    if fmt < 16:
      let tp = parser.types[parser.readInt - 1]
      if tp == IntType and fmt == 3:
        var length = 8
        var value = 0
        while length>0:
          value = (value shl 8) or cast[int](parser.readByte)
          length.dec
        return intValue(value)
      elif tp == StringType and fmt == 5:
        return strValue(parser.readStr)
      else:
        raise newException(Exception, "Unsuported format " & $fmt & " for " & $tp)
    else:
      raise newException(Exception, "Constant rutine call not implemented")

import strutils
proc parseFile* (filename: string): Module =

  var parser = Parser(
    file: open(filename),
    types: newSeq[Type](),
    procs: newSeq[Proc](),
  )

  result = Module(name: filename)

  try:
    parser.parseBasics()

    parser.parseImports()

    result.types = parser.parseTypes()
    result.procs = parser.parseRutines()

    parser.parseUses()
    result.constants = parser.parseConstants()

  except Exception:

    let e = getCurrentException()

    echo "Error de lectura, archivo \"" & filename & "\", byte " & parser.file.getFilePos.toHex(4)
    echo getCurrentExceptionMsg()
    echo e.getStackTrace()

  for prc in result.procs:
    prc.module = result
