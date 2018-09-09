
let intT*: Type = newType("int")

globalModule("auro.int"):
  self["int"] = intT

  let itoi = mksig([intT], [intT])
  let itob = mksig([intT], [boolT])
  let iitoi = mksig([intT, intT], [intT])
  let iitob = mksig([intT, intT], [boolT])

  self.addfn("max", iitoi):
    args.ret Value(kind: intV, i: high(int))

  self.addfn("min", iitoi):
    args.ret Value(kind: intV, i: low(int))

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
    let a = args[0].i
    let b = args[1].i
    if b == 0: raise newException(UserError, "division by zero")
    args.ret Value(kind: intV, i: a div b)

  self.addfn("mod", iitoi):
    let a = args[0].i
    let b = args[1].i
    if b == 0: raise newException(UserError, "division by zero")
    args.ret Value(kind: intV, i: a mod b)


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


globalModule("auro.int.bit"):

  let iitoi = mksig([intT, intT], [intT])

  self.addfn("not", [intT], [intT]):
    let r = not args[0].i
    args.ret Value(kind: intV, i: r)

  self.addfn("and", iitoi):
    let r = args[0].i and args[1].i
    args.ret Value(kind: intV, i: r)

  self.addfn("or", iitoi):
    let r = args[0].i or args[1].i
    args.ret Value(kind: intV, i: r)

  self.addfn("xor", iitoi):
    let r = args[0].i xor args[1].i
    args.ret Value(kind: intV, i: r)

  self.addfn("eq", iitoi):
    let r = not(args[0].i xor args[1].i)
    args.ret Value(kind: intV, i: r)

  self.addfn("shl", iitoi):
    let a = args[0].i
    let b = args[1].i
    if a < 0 or b < 0:
      raise newException(UserError, "negative operand")
    if b > 31 or a shr (31 - b) > 0:
      raise newException(UserError, "31 bit overflow")
    args.ret Value(kind: intV, i: a shl b)

  self.addfn("shr", iitoi):
    let a = args[0].i
    let b = args[1].i
    if a < 0 or b < 0: raise newException(UserError, "negative operand")
    args.ret Value(kind: intV, i: a shr b)