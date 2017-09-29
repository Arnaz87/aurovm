
import machine2

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

discard newModule(
  name = "cobre.prim", 
  types = @{
    "int": Type(name: "int"),
  },
  funcs = @{
    "add": newFunction("add", addf),
    "mul": newFunction("mul", mulf),
    "gt": newFunction("gt", gtf),
    "gtz": newFunction("gtz", gtzf),
    "inc": newFunction("inc", incf),
    "dec": newFunction("dec", decf),
  }
)

discard newModule(
  name = "cobre.core",
  types = @{
    "bool": Type(name: "bool"),
  }
)