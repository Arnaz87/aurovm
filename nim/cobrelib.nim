
import machine

proc addf (ins: seq[Value]): seq[Value] =
  let r = ins[0].i + ins[1].i
  @[Value(kind: intV, i: r)]

proc mulf (ins: seq[Value]): seq[Value] =
  let r = ins[0].i * ins[1].i
  @[Value(kind: intV, i: r)]

proc gtf (ins: seq[Value]): seq[Value] =
  let r = ins[0].i > ins[1].i
  @[Value(kind: boolV, b: r)]

proc gtzf (ins: seq[Value]): seq[Value] =
  let r = ins[0].i > 0
  @[Value(kind: boolV, b: r)]

proc incf (ins: seq[Value]): seq[Value] =
  let r = ins[0].i + 1
  @[Value(kind: intV, i: r)]

proc decf (ins: seq[Value]): seq[Value] =
  let r = ins[0].i - 1
  @[Value(kind: intV, i: r)]

let intT: Type = Type(kind: nativeT, name: "int")
let boolT: Type = Type(kind: nativeT, name: "bool")

let iitoi = Signature(
  ins: @[intT, intT],
  outs: @[intT]
)
let iitob = Signature(
  ins: @[intT, intT],
  outs: @[boolT]
)
let itoi = Signature(ins: @[intT], outs: @[intT])
let itob = Signature(ins: @[intT], outs: @[boolT])

discard newModule(
  name = "cobre.core",
  types = @{ "bool": boolT, }
)

discard newModule(
  name = "cobre.prim", 
  types = @{ "int": intT, },
  funcs = @{
    "add": newFunction("add", iitoi, addf),
    "mul": newFunction("mul", iitoi, mulf),
    "gt": newFunction("gt", iitob, gtf),
    "gtz": newFunction("gtz", itob, gtzf),
    "inc": newFunction("inc", itoi, incf),
    "dec": newFunction("dec", itoi, decf),
  }
)