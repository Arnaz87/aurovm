
let bufT*: Type = Type(name: "buffer")

globalModule("cobre.buffer"):
  self["buffer"] = bufT

  self.addfn("new", [intT], [bufT]):
    args.ret Value(kind: binV, bytes: newSeq[byte](args[0].i))

  self.addfn("get", [bufT, intT], [intT]):
    let v = args[0].bytes[args[1].i]
    args.ret Value(kind: intV, i: cast[int](v))

  self.addfn("set", [bufT, intT, intT], []):
    args[0].bytes[args[1].i] = cast[byte](args[2].i)

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
    
