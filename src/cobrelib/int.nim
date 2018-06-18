
let intT*: Type = newType("int")

globalModule("cobre.int"):
  self["int"] = intT

  let itoi = mksig([intT], [intT])
  let itob = mksig([intT], [boolT])
  let iitoi = mksig([intT, intT], [intT])
  let iitob = mksig([intT, intT], [boolT])

  self.addfn("add", iitoi):
    let r = args[0].i + args[1].i
    args.ret Value(kind: intV, i: r)

  self.addfn("sub", iitoi):
    let r = args[0].i - args[1].i
    args.ret Value(kind: intV, i: r)

  self.addfn("mul", iitoi):
    let r = args[0].i * args[1].i
    args.ret Value(kind: intV, i: r)

  self.addfn("div", iitoi):
    let r = int(args[0].i / args[1].i)
    args.ret Value(kind: intV, i: r)

  self.addfn("eq", iitob):
    let r = args[0].i == args[1].i
    args.ret Value(kind: boolV, b: r)

  self.addfn("gt", iitob):
    let r = args[0].i > args[1].i
    args.ret Value(kind: boolV, b: r)

  self.addfn("ge", iitob):
    let r = args[0].i >= args[1].i
    args.ret Value(kind: boolV, b: r)

  self.addfn("lt", iitob):
    let r = args[0].i < args[1].i
    args.ret Value(kind: boolV, b: r)

  self.addfn("le", iitob):
    let r = args[0].i <= args[1].i
    args.ret Value(kind: boolV, b: r)

  self.addfn("gtz", itob):
    let r = args[0].i > 0
    args.ret Value(kind: boolV, b: r)

  self.addfn("inc", itoi):
    let r = args[0].i + 1
    args.ret Value(kind: intV, i: r)

  self.addfn("dec", itoi):
    let r = args[0].i - 1
    args.ret Value(kind: intV, i: r)

  self.addfn("neg", itoi):
    let r = 0 - args[0].i
    args.ret Value(kind: intV, i: r)