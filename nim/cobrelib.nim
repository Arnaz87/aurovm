
import machine

import hashes
import tables

#=== cobre.core ===#

let intT: Type = Type(kind: nativeT, name: "int")
let binT: Type = Type(kind: nativeT, name: "bin")
let boolT: Type = Type(kind: nativeT, name: "bool")
let strT: Type = Type(kind: nativeT, name: "string")

discard newModule(
  name = "cobre.core",
  types = @{ "bool": boolT, "bin": binT }
)



#=== cobre.prim ===#

proc addf (ins: seq[Value]): seq[Value] =
  let r = ins[0].i + ins[1].i
  @[Value(kind: intV, i: r)]

proc subf (ins: seq[Value]): seq[Value] =
  let r = ins[0].i - ins[1].i
  @[Value(kind: intV, i: r)]

proc mulf (ins: seq[Value]): seq[Value] =
  let r = ins[0].i * ins[1].i
  @[Value(kind: intV, i: r)]

proc divf (ins: seq[Value]): seq[Value] =
  let r: int = (int) (ins[0].i / ins[1].i)
  @[Value(kind: intV, i: r)]

proc eqf (ins: seq[Value]): seq[Value] =
  let r = ins[0].i == ins[1].i
  @[Value(kind: boolV, b: r)]

proc gtf (ins: seq[Value]): seq[Value] =
  let r = ins[0].i > ins[1].i
  @[Value(kind: boolV, b: r)]

proc gtef (ins: seq[Value]): seq[Value] =
  let r = ins[0].i >= ins[1].i
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



#=== cobre.string ===#

proc newstrf (ins: seq[Value]): seq[Value] =
  let bytes = ins[0].bytes
  var str = newString(bytes.len)
  for i in 0..bytes.high:
    str[i] = char(bytes[i])
  @[Value(kind: strV, s: str)]

proc itosf (ins: seq[Value]): seq[Value] =
  let i = ins[0].i
  @[Value(kind: strV, s: $i)]

proc concatf (ins: seq[Value]): seq[Value] =
  let r = ins[0].s & ins[1].s
  @[Value(kind: strV, s: r)]

discard newModule(
  name = "cobre.string",
  types = @{ "string": strT },
  funcs = @{
    "new": newFunction("new", Signature(ins: @[binT], outs: @[strT]), newstrf),
    "itos": newFunction("itos", Signature(ins: @[intT], outs: @[strT]), itosf),
    "concat": newFunction("concat", Signature(ins: @[strT, strT], outs: @[strT]), concatf),
  }
)


#=== cobre.system ===#

proc printf (ins: seq[Value]): seq[Value] =
  echo ins[0].s
  @[]

discard newModule(
  name = "cobre.system",
  funcs = @{
    "print": newFunction("print", Signature(ins: @[strT], outs: @[]), printf)
  }
)



#=== cobre.tuple ===#

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



#=== cobre.null ===#

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



#=== cobre.function ===#

#proc hash(t: Type): Hash = t.unsafeAddr.hash
#proc hash(sig: Signature): Hash = !$(sig.ins.hash !& sig.outs.hash)

# Error: cannot instantiate: 'A'
#var function_modules: Table[Signature,  Module] = initTable()

type FunTable = seq[tuple[sig: Signature, m: Module]]
var function_modules: FunTable = @[]
proc hasKey(table: FunTable, sig: Signature): bool =
  for item in table:
    if item.sig == sig:
      return true
  return false
proc `[]`(table: FunTable, sig: Signature): Module =
  for item in table:
    if item.sig == sig:
      return item.m
proc `[]=`(table: var FunTable, sig: Signature, m: Module) =
  table.add((sig, m))

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