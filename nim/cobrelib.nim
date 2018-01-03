
import machine

import hashes
import tables

from times import cpuTime

proc ret (sq: var seq[Value], v: Value) =
  sq.setLen(1)
  sq[0] = v

#==========================================================#
#===                     cobre.core                     ===#
#==========================================================#

let binT: Type = Type(kind: nativeT, name: "bin")
let boolT: Type = Type(kind: nativeT, name: "bool")

discard newModule(
  name = "cobre.core",
  types = @{ "bool": boolT, "bin": binT }
)


#==========================================================#
#===                     cobre.int                     ===#
#==========================================================#

let intT: Type = Type(kind: nativeT, name: "int")

block:
  proc addf (args: var seq[Value]) =
    let r = args[0].i + args[1].i
    args.ret Value(kind: intV, i: r)

  proc subf (args: var seq[Value]) =
    let r = args[0].i - args[1].i
    args.ret Value(kind: intV, i: r)

  proc mulf (args: var seq[Value]) =
    let r = args[0].i * args[1].i
    args.ret Value(kind: intV, i: r)

  proc divf (args: var seq[Value]) =
    let r: int = (int) (args[0].i / args[1].i)
    args.ret Value(kind: intV, i: r)

  proc eqf (args: var seq[Value]) =
    let r = args[0].i == args[1].i
    args.ret Value(kind: boolV, b: r)

  proc gtf (args: var seq[Value]) =
    let r = args[0].i > args[1].i
    args.ret Value(kind: boolV, b: r)

  proc gtef (args: var seq[Value]) =
    let r = args[0].i >= args[1].i
    args.ret Value(kind: boolV, b: r)

  proc ltf (args: var seq[Value]) =
    let r = args[0].i < args[1].i
    args.ret Value(kind: boolV, b: r)

  proc ltef (args: var seq[Value]) =
    let r = args[0].i <= args[1].i
    args.ret Value(kind: boolV, b: r)

  proc gtzf (args: var seq[Value]) =
    let r = args[0].i > 0
    args.ret Value(kind: boolV, b: r)

  proc incf (args: var seq[Value]) =
    let r = args[0].i + 1
    args.ret Value(kind: intV, i: r)

  proc decf (args: var seq[Value]) =
    let r = args[0].i - 1
    args.ret Value(kind: intV, i: r)

  proc negf (args: var seq[Value]) =
    let r = 0 - args[0].i
    args.ret Value(kind: intV, i: r)

  proc signedf (args: var seq[Value]) =
    let i = args[0].i
    let mag = i shr 1
    let r = if (i and 1) == 1: -mag else: mag
    args.ret Value(kind: intV, i: r)

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

  # TODO: Deprecated, use cobre.int instead
  discard newModule(
    name = "cobre.prim", 
    types = @{ "int": intT, },
    funcs = @{
      "add": newFunction("add", iitoi, addf),
      "sub": newFunction("sub", iitoi, subf),
      "mul": newFunction("mul", iitoi, mulf),
      "div": newFunction("div", iitoi, divf),
      "eq" : newFunction("eq" , iitob, eqf),
      "gt" : newFunction("gt" , iitob, gtf),
      "gte": newFunction("gte", iitob, gtef),
      "gtz": newFunction("gtz", itob, gtzf),
      "inc": newFunction("inc", itoi, incf),
      "dec": newFunction("dec", itoi, decf),
    }
  )

  discard newModule(
    name = "cobre.int", 
    types = @{ "int": intT, },
    funcs = @{
      "add": newFunction("add", iitoi, addf),
      "sub": newFunction("sub", iitoi, subf),
      "mul": newFunction("mul", iitoi, mulf),
      "div": newFunction("div", iitoi, divf),
      "eq" : newFunction("eq" , iitob, eqf),
      "gt" : newFunction("gt" , iitob, gtf),
      "gte": newFunction("gte", iitob, gtef),
      "lt" : newFunction("lt" , iitob, ltf),
      "lte": newFunction("lte", iitob, ltef),
      "gtz": newFunction("gtz", itob, gtzf),
      "inc": newFunction("inc", itoi, incf),
      "dec": newFunction("dec", itoi, decf),
      "neg": newFunction("neg", itoi, negf),
      "signed": newFunction("signed", itoi, signedf),
    }
  )


#==========================================================#
#===                     cobre.float                    ===#
#==========================================================#

let fltT: Type = Type(kind: nativeT, name: "float")

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


#==========================================================#
#===                    cobre.string                    ===#
#==========================================================#

let strT: Type = Type(kind: nativeT, name: "string")

proc newstrf (args: var seq[Value]) =
  let bytes = args[0].bytes
  var str = newString(bytes.len)
  for i in 0..bytes.high:
    str[i] = char(bytes[i])
  args.ret Value(kind: strV, s: str)

proc itosf (args: var seq[Value]) =
  let i = args[0].i
  args.ret Value(kind: strV, s: $i)

proc ftosf (args: var seq[Value]) =
  let f = args[0].f
  args.ret Value(kind: strV, s: $f)

proc concatf (args: var seq[Value]) =
  let r = args[0].s & args[1].s
  args.ret Value(kind: strV, s: r)

discard newModule(
  name = "cobre.string",
  types = @{ "string": strT },
  funcs = @{
    "new": newFunction("new", Signature(ins: @[binT], outs: @[strT]), newstrf),
    "itos": newFunction("itos", Signature(ins: @[intT], outs: @[strT]), itosf),
    "ftos": newFunction("ftos", Signature(ins: @[fltT], outs: @[strT]), ftosf),
    "concat": newFunction("concat", Signature(ins: @[strT, strT], outs: @[strT]), concatf),
  }
)


#==========================================================#
#===                    cobre.system                    ===#
#==========================================================#

proc printf (args: var seq[Value]) =
  echo args[0].s
  args.setLen(0)

proc clockf (args: var seq[Value]) =
  args.ret Value(kind: fltV, f: cpuTime())

discard newModule(
  name = "cobre.system",
  funcs = @{
    "print": newFunction("print", Signature(ins: @[strT], outs: @[]), printf),
    "clock": newFunction("clock", Signature(ins: @[], outs: @[fltT]), clockf),
  }
)


#==========================================================#
#===                    cobre.tuple                     ===#
#==========================================================#

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
    proc prc (args: var seq[Value]) =
      let v = args[0]
      case v.kind
      of productV:
        let field = v.p.fields[index]
        args.ret(field)
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

  proc newProc (args: var seq[Value]) =

    if args.len != types.len:
      let msg = "Expected " & $types.len & " arguments"
      raise newException(Exception, msg)

    var vs = newSeq[Value](types.len)
    for i in 0..<types.len:
      vs[i] = args[i]

    args.ret Value(
      kind: productV,
      p: Product(
        tp: tp,
        fields: vs
      )
    )

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


#==========================================================#
#===                     cobre.null                     ===#
#==========================================================#

proc nullFn (argument: Module): Module =
  var argitem = argument["0"]
  if argitem.kind != tItem:
    raise newException(Exception, "argument 0 for cobre.null is not a type")
  var base = argitem.t
  #let basename = "null(" & base.name & ")"
  let basename = "nullable"
  var tp = Type(name: basename, kind: nullableT, t: base)

  var items = @[ Item(kind: tItem, name: "", t: tp) ]

  return Module(
    name: basename & "_module",
    kind: simpleM,
    items: items,
  )

machine_modules.add(Module(name: "cobre.null", kind: functorM, fn: nullFn))


#==========================================================#
#===                   cobre.function                   ===#
#==========================================================#

proc hash(t: Type): Hash = t.name.hash
proc hash(sig: Signature): Hash = !$(sig.ins.hash !& sig.outs.hash)
var function_modules = initTable[Signature, Module](32)

proc functionFn (argument: Module): Module =
  var ins:  seq[Type] = @[]
  var outs: seq[Type] = @[]
  var n = 0
  var nitem = argument["in" & $n]
  while nitem.kind == tItem:
    ins.add(nitem.t)
    n += 1
    nitem = argument["in" & $n]
  n = 0
  nitem = argument["out" & $n]
  while nitem.kind == tItem:
    outs.add(nitem.t)
    n += 1
    nitem = argument["out" & $n]

  var sig = Signature(ins: ins, outs: outs)
  if function_modules.hasKey(sig):
    return function_modules[sig]

  let basename = sig.name

  var tp = Type(name: basename, kind: functionT, sig: sig)
  var items = @[ Item(name: "", kind: tItem, t: tp) ]

  var applyIns = @[tp]
  applyIns.add(ins)

  let applySig = Signature(ins: applyIns, outs: outs)

  # apply Functions get treated specially by the machine,
  # to keep the stack organized

  items.add(Item(
    name: "apply",
    kind: fItem,
    f: Function(
      name: basename & ".apply",
      sig: applySig,
      kind: applyF,
    )
  ))

  result = Module(
    name: basename & "_module",
    kind: simpleM,
    items: items,
  )
  function_modules[sig] = result

machine_modules.add(Module(name: "cobre.function", kind: functorM, fn: functionFn))
