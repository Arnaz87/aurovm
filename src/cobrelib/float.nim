
let fltT*: Type = newType("float")

globalModule("cobre.float"):
  self["float"] = fltT

  let fftof = mksig([fltT, fltT], [fltT])
  let fftob = mksig([fltT, fltT], [boolT])

  self.addfn("ftoi", [fltT], [intT]):
    args.ret Value(kind: intV, i: (int) args[0].f)

  self.addfn("itof", [intT], [fltT]):
    let r = (float) args[0].i
    args.ret Value(kind: fltV, f: r)

  self.addfn("decimal", [intT, intT], [fltT]):
    var r = (float) args[0].i
    var exp = args[1].i
    while exp > 0:
      r = r*10
      exp -= 1
    while exp < 0:
      r = r/10
      exp += 1
    args.ret Value(kind: fltV, f: r)

  self.addfn("add", fftof):
    let r = args[0].f + args[1].f
    args.ret Value(kind: fltV, f: r)

  self.addfn("sub", fftof):
    let r = args[0].f - args[1].f
    args.ret Value(kind: fltV, f: r)

  self.addfn("mul", fftof):
    let r = args[0].f * args[1].f
    args.ret Value(kind: fltV, f: r)

  self.addfn("div", fftof):
    let r = args[0].f / args[1].f
    args.ret Value(kind: fltV, f: r)

  self.addfn("eq", fftob):
    let r = args[0].f == args[1].f
    args.ret Value(kind: boolV, b: r)

  self.addfn("gt", fftob):
    let r = args[0].f > args[1].f
    args.ret Value(kind: boolV, b: r)

  self.addfn("ge", fftob):
    let r = args[0].f >= args[1].f
    args.ret Value(kind: boolV, b: r)

  self.addfn("lt", fftob):
    let r = args[0].f < args[1].f
    args.ret Value(kind: boolV, b: r)

  self.addfn("le", fftob):
    let r = args[0].f <= args[1].f
    args.ret Value(kind: boolV, b: r)

  self.addfn("gtz", [fltT], [boolT]):
    let r = args[0].f > 0
    args.ret Value(kind: boolV, b: r)