
let fileT = newType("file")

globalModule("cobre.io"):
  let modeT = newType("mode")

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

  type FileObj = ref object of RootObj
    f: File

  self.addfn("open", [strT, modeT], [fileT]):
    let path = args[0].s
    let mode = case args[1].s
      of "r": fmRead
      of "w": fmWrite
      of "a": fmAppend
      else: fmRead
    let file = open(path, mode)
    args.ret(Value(kind: objV, obj: FileObj(f: file)))

  self.addfn("close", [fileT], []):
    close(FileObj(args[0].obj).f)

  self.addfn("read", [fileT, intT], [bufT]):
    let file = FileObj(args[0].obj)
    let size = args[1].i
    var buf = newSeq[byte](size)
    let redd = file.f.readBytes(buf, 0, size)
    if redd < size: buf = buf[0..<redd]
    args.ret(Value(kind: binV, bytes: buf))

  self.addfn("write", mksig([fileT, bufT], [])):
    let file = FileObj(args[0].obj)
    let buf = args[1].bytes
    let written = file.f.writeBytes(buf, 0, buf.len)
    if written != buf.len:
      raise newException(Exception, "Couldn't write file")

  self.addfn("eof", [fileT], [boolT]):
    let file = FileObj(args[0].obj)
    args.ret Value(kind: boolV, b: file.f.endOfFile)

  self.addfn("pos:get", mksig([fileT], [intT])):
    let file = FileObj(args[0].obj)
    let r = int(file.f.getFilePos)
    args.ret(Value(kind: intV, i: r))

  self.addfn("pos:set", mksig([fileT, intT], [])):
    let file = FileObj(args[0].obj)
    file.f.setFilePos(args[1].i)