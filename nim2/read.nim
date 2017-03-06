
#=== Primitives ===#

type Reader = ref object of RootObj
  file: File

proc newReader (filename: string): Reader =
  return Reader(file: open(filename))

proc readByte (reader: Reader): uint8 =
  let L = reader.file.readBuffer(result.addr, 1)
  if L != 1: raise newException(IOError, "cannot read byte")

proc readInt (reader: Reader): int =
  var n = 0
  var b = cast[int](reader.readByte)
  while (b and 0x80) > 0:
    n = (n shl 7) or (b and 0x7f)
    b = cast[int](reader.readByte)
  return (n shl 7) or (b and 0x7f)

proc readStr (reader: Reader): string =
  # No sé si el string nativo de nim es utf8
  var length = cast[int](reader.readByte)
  result = newString(length)
  let L = reader.file.readBuffer(addr(result[0]), length)
  if L != length: raise newException(IOError, "cannot read full string")

#=== Module Parsers ===#

proc parse (filename: string): Module =
  var types = newSeq[Type]()
  var procs = newSeq[Proc]()

  result = Module(name: filename)
  var reader = newReader(filename)

  #=== Imports ===#
  let importCount = reader.readInt

  for i in 0..<importCount:
    let modName = reader.readStr
    let module = modules[modName]

    let typeCount = reader.readInt
    for i in 0..<typeCount:
      let typeName = reader.readStr
      let mytype = module.types[typename]
      types.add(mytype)

      let fieldCount = reader.readInt
      if fieldCount > 0:
        raise newException(Exception, "Imported type field parser not yet implemented")

    let procCount = reader.readInt
    for i in 0..<procCount:
      let procName = reader.readStr
      let myproc = module.procs[procname]
      procs.add(myproc)

      let inCount = reader.readInt
      if (inCount != myproc.incount):
        raise newException(Exception, "Input count mismatch: " & procName)

      let outCount = reader.readInt
      if (outCount != myproc.outcount):
        raise newException(Exception, "Output count mismatch: " & procName)

  #=== Types ===#

  let typeCount = reader.readInt
  result.types = newSeq[Type](typeCount)
  if typeCount > 0:
    raise newException(Exception, "Type parser not yet implemented")

  #=== Prototypes ===#

  let procCount = reader.readInt
  result.procs = newSeq[Proc](procCount)

  for i in 0..<procCount:
    let procName = reader.readStr

    let rut = Proc(name: procName, module: result)

    let inCount = reader.readInt
    rut.inregs = newSeq[int](inCount)
    for i in 0..<inCount:
      let reg = reader.readInt - 1
      rut.inregs[i] = reg

    let outCount = reader.readInt
    rut.outregs = newSeq[int](outCount)
    for i in 0..<outCount:
      let reg = reader.readInt - 1
      rut.outregs[i] = reg

    let regCount = reader.readInt
    rut.regs = newSeq[Type](regCount)
    for i in 0..<regCount:
      let v = reader.readInt
      rut.regs[i] = types[v-1]

    procs.add(rut)
    result.procs[i] = rut

  #=== Code ===#

  for i in 0..<procCount:
    var rut = result.procs[i]

    let codeLength = reader.readInt
    rut.code = newSeq[Inst](codeLength)
    rut.labels = newSeq[int]()

    proc readVal (): int = reader.readInt - 1

    for i in 0..<codeLength:
      let v = reader.readInt
      rut.code[i] = case v
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
          let prc = procs[v-16]

          var outs = newSeq[int](case prc.kind
            of nativeProc: prc.outCount
            of codeProc: prc.outregs.len
          )
          outs.apply do (i: int) -> int: readVal()

          var ins = newSeq[int](case prc.kind
            of nativeProc: prc.inCount
            of codeProc: prc.inregs.len
          )
          ins.apply do (i: int) -> int: readVal()

          Inst(kind: icall,
            prc: prc,
            ins: ins,
            outs: outs
          )

  #=== Constants ===#

  let constCount = reader.readInt
  result.constants = newSeq[Value](constCount)

  for i in 0..<constCount:
    let tp = types[reader.readInt - 1]

    if tp == IntType:
      var length = reader.readInt
      var value = 0
      while length>0:
        value = (value shl 8) or cast[int](reader.readByte)
        length.dec
      result.constants[i] = intValue(value)
    elif tp == StringType:
      result.constants[i] = strValue(reader.readStr)
    else:
      raise newException(Exception, "Unrecognized constructor for " & $tp)

