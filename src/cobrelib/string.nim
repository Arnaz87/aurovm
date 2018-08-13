
let strT*: Type = newType("string")
let charT*: Type = newType("char")

globalModule("cobre.string"):
  self["string"] = strT
  self["char"] = charT

  self.addfn("new", [bufT], [strT]):
    let bytes = args[0].bytes
    var str = newString(bytes.len)
    for i in 0..bytes.high:
      str[i] = char(bytes[i])
    args.ret Value(kind: strV, s: str)

  self.addfn("tobuffer", [strT], [bufT]):
    let str = args[0].s
    var buf = newSeq[byte](str.len)
    for i in 0..str.high:
      buf[i] = byte(str[i])
    args.ret Value(kind: binV, bytes: buf)

  self.addfn("itos", [intT], [strT]):
    let i = args[0].i
    args.ret Value(kind: strV, s: $i)

  self.addfn("ftos", [fltT], [strT]):
    let f = args[0].f
    args.ret Value(kind: strV, s: $f)

  self.addfn("add", [strT, charT], [strT]):
    let r = args[0].s & args[1].s
    args.ret Value(kind: strV, s: r)

  self.addfn("concat", [strT, strT], [strT]):
    let r = args[0].s & args[1].s
    args.ret Value(kind: strV, s: r)

  self.addfn("slice", [strT, intT, intT], [strT]):
    let a = args[1].i
    let b = args[2].i
    let r = args[0].s.substr(a, b-1)
    args.ret Value(kind: strV, s: r)

  self.addfn("eq", [strT, strT], [boolT]):
    let r = args[0].s == args[1].s
    args.ret Value(kind: boolV, b: r)

  self.addfn("newchar", [intT], [charT]):
    let ch = cast[char](args[0].i)
    args.ret Value(kind: strV, s: $ch)

  self.addfn("charat", [strT, intT], [charT, intT]):
    let i = args[1].i
    let str = $args[0].s[i]
    args.retn([
      Value(kind: strV, s: str),
      Value(kind: intV, i: i+1)
    ])

  self.addfn("codeof", [charT], [intT]):
    let code = cast[int](args[0].s[0])
    args.ret Value(kind: intV, i: code)

  self.addfn("length", [strT], [intT]):
    args.ret Value(kind: intV, i: args[0].s.len)
