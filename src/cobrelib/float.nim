
let fltT*: Type = Type(name: "float")

block:
  proc itoff (args: var seq[Value]) =
    let r = (float) args[0].i
    args.ret Value(kind: fltV, f: r)

  proc decimalf (args: var seq[Value]) =
    var r = (float) args[0].i
    var exp = args[1].i

    while exp > 0:
      r = r*10
      exp -= 1

    while exp < 0:
      r = r/10
      exp += 1
    args.ret Value(kind: fltV, f: r)

  proc addf (args: var seq[Value]) =
    let r = args[0].f + args[1].f
    args.ret Value(kind: fltV, f: r)

  proc subf (args: var seq[Value]) =
    let r = args[0].f - args[1].f
    args.ret Value(kind: fltV, f: r)

  proc mulf (args: var seq[Value]) =
    let r = args[0].f * args[1].f
    args.ret Value(kind: fltV, f: r)

  proc divf (args: var seq[Value]) =
    let r = args[0].f / args[1].f
    args.ret Value(kind: fltV, f: r)

  proc eqf (args: var seq[Value]) =
    let r = args[0].f == args[1].f
    args.ret Value(kind: boolV, b: r)

  proc gtf (args: var seq[Value]) =
    let r = args[0].f > args[1].f
    args.ret Value(kind: boolV, b: r)

  proc gtef (args: var seq[Value]) =
    let r = args[0].f >= args[1].f
    args.ret Value(kind: boolV, b: r)

  proc ltf (args: var seq[Value]) =
    let r = args[0].f < args[1].f
    args.ret Value(kind: boolV, b: r)

  proc ltef (args: var seq[Value]) =
    let r = args[0].f <= args[1].f
    args.ret Value(kind: boolV, b: r)

  proc gtzf (args: var seq[Value]) =
    let r = args[0].f > 0
    args.ret Value(kind: boolV, b: r)

  let fftof = Signature(
    ins: @[fltT, fltT],
    outs: @[fltT]
  )
  let fftob = Signature(
    ins: @[fltT, fltT],
    outs: @[boolT]
  )
  let ftof = Signature(ins: @[fltT], outs: @[fltT])
  let ftob = Signature(ins: @[fltT], outs: @[boolT])
  let itofsig = Signature(ins: @[intT], outs: @[fltT])
  let iitofsig = Signature(ins: @[intT, intT], outs: @[fltT])

  discard newModule(
    name = "cobre.float", 
    types = @{ "float": fltT, },
    funcs = @{
      "add": newFunction("add", fftof, addf),
      "sub": newFunction("sub", fftof, subf),
      "mul": newFunction("mul", fftof, mulf),
      "div": newFunction("div", fftof, divf),
      "eq" : newFunction("eq" , fftob, eqf),
      "gt" : newFunction("gt" , fftob, gtf),
      "gte": newFunction("gte", fftob, gtef),
      "lt" : newFunction("lt" , fftob, ltf),
      "lte": newFunction("lte", fftob, ltef),
      "gtz": newFunction("gtz", ftob, gtzf),
      "itof": newFunction("itof", itofsig, itoff),
      "decimal": newFunction("decimal", iitofsig, decimalf),
    }
  )