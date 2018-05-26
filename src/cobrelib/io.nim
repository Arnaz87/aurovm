
let fileT = Type(name: "file")

globalModule("cobre.io"):
  let modeT = Type(name: "mode")

  self["file"] = fileT
  self["mode"] = modeT

  proc modeCns (name: string): Function = Function(
    name: name,
    kind: constF,
    sig: mksig([], [modeT]),
    value: Value(kind: strV, s: name)
  )

  self["r"] = modeCns("r")
  self["w"] = modeCns("w")
  self["a"] = modeCns("a")

  self.addfn("open", [strT, modeT], [fileT]):
    let path = args[0].s
    let mode = case args[1].s
      of "r": fmRead
      of "w": fmWrite
      of "a": fmAppend
      else: fmRead
    let file = open(path, mode)
    args.ret(Value(kind: ptrV, pt: file))

  self.addfn("close", [fileT], []):
    let file = cast[File](args[0].pt)
    close(file)

  self.addfn("read", [fileT, intT], [bufT]):
    let file = cast[File](args[0].pt)
    let size = args[1].i
    var buf = newSeq[byte](size)
    let redd = file.readBytes(buf, 0, size)
    if redd < size: buf = buf[0..<redd]
    args.ret(Value(kind: binV, bytes: buf))

  self.addfn("write", mksig([fileT, bufT], [])):
    let file = cast[File](args[0].pt)
    let buf = args[1].bytes
    let written = file.writeBytes(buf, 0, buf.len)
    if written != buf.len:
      raise newException(Exception, "Couldn't write file")

  self.addfn("pos:get", mksig([fileT], [intT])):
    let file = cast[File](args[0].pt)
    let r = int(file.getFilePos)
    args.ret(Value(kind: intV, i: r))

  self.addfn("pos:set", mksig([fileT, intT], [])):
    let file = cast[File](args[0].pt)
    file.setFilePos(args[1].i)