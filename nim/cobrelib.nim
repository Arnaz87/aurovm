
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

proc tplFn (argument: Module): Module =
  var types: seq[Type] = @[]
  var n = 0
  var nitem = argument[$n]
  while nitem.kind == tItem:
    types.add(nitem.t)
    n += 1
    nitem = argument[$n]

  let basename = "tuple" & $n

  var tp = Type(name: basename, kind: productT, ts: types)
  var items = @[ Item(name: "", kind: tItem, t: tp) ]

  proc create_getter (index: int): Function =
    proc prc (ins: seq[Value]): seq[Value] =
      let v = ins[0]
      case v.kind
      of productV:
        let field = v.p.fields[index]
        return @[field]
      else:
        let msg = "Runtime type mismatch, expected " & tp.name
        raise newException(Exception, msg)
    let sig = Signature(ins: @[tp], outs: @[types[index]])
    return Function(
      name: basename & ".get" & $index,
      sig: sig,
      kind: procF,
      prc: prc
    )

  for i in 0..<n:
    items.add(Item(
      name: "get" & $i,
      kind: fItem,
      f: create_getter(i)
    ))

  proc newProc (ins: seq[Value]): seq[Value] =

    if ins.len != types.len:
      let msg = "Expected " & $types.len & " arguments"
      raise newException(Exception, msg)

    var vs = newSeq[Value](types.len)
    for i in 0..<types.len:
      vs[i] = ins[i]

    return @[Value(
      kind: productV,
      p: Product(
        tp: tp,
        fields: vs
      )
    )]

  let sig = Signature(ins: types, outs: @[tp])
  items.add(Item(
    name: "new",
    kind: fItem,
    f: Function(
      name: basename & ".new",
      sig: sig,
      kind: procF,
      prc: newProc
    )
  ))

  return Module(
    name: basename & "_module",
    kind: simpleM,
    items: items,
  )

machine_modules.add(Module(name: "cobre.tuple", kind: functorM, fn: tplFn))

