
let bufT*: Type = Type(name: "buffer")

globalModule("cobre.buffer"):
  self["buffer"] = bufT

  self.addfn("new", [intT], [bufT]):
    var bytes = newSeq[byte](args[0].i)
    shallow(bytes)
    args.ret Value(kind: binV, bytes: bytes)

  self.addfn("get", [bufT, intT], [intT]):
    let v = args[0].bytes[args[1].i]
    args.ret Value(kind: intV, i: int(v))

  self.addfn("set", [bufT, intT, intT], []):
    args[0].bytes[args[1].i] = byte(args[2].i)

  self.addfn("size", [bufT], [intT]):
    args.ret Value(kind: intV, i: args[0].bytes.len)

  self.addfn("readonly", [bufT], [boolT]):
    args.ret Value(kind: boolV, b: false)

  self.addfn("resize", [bufT, intT], []):
    template orig: seq[byte] = args[0].bytes
    let size = args[1].i
    var nbuf = newSeq[byte](size)
    let last = min(nbuf.high, orig.high)
    for i in 0..last:
      nbuf[i] = orig[i]
    args[0].bytes = nbuf
    
