
import machine2

proc addf (ins: seq[Value]): seq[Value] =
  let r = ins[0].i + ins[1].i
  @[Value(kind: intV, i: r)]

proc mulf (ins: seq[Value]): seq[Value] =
  let r = ins[0].i * ins[1].i
  @[Value(kind: intV, i: r)]

discard newModule(
  name = "cobre.prim", 
  types = @{
    "int": Type(name: "int"),
  },
  funcs = @{
    "add": newFunction("add", addf),
    "mul": newFunction("add", mulf)
  }
)