
import machine

import hashes
import tables
import options

from times import cpuTime

import osproc

proc retn* (sq: var seq[Value], vs: openarray[Value]) =
  for i in 0 .. vs.high:
    sq[i] = vs[i]

template ret* (sq: var seq[Value], v: Value) = retn(sq, [v])

proc mksig* (ins: openarray[Type], outs: openarray[Type]): Signature =
  Signature(ins: @ins, outs: @outs)

template addfn* (items: var seq[Item], myname: string, mysig: Signature, body: untyped) =
  items.add(Item(
    name: myname,
    kind: fItem,
    f: Function(
      name: myname,
      sig: mysig,
      kind: procF,
      prc: proc (myargs: var seq[Value]) =
        var args {.inject.}: seq[Value]
        args.shallowCopy(myargs)
        body
    )
  ))

template addfn* (
  items: var seq[Item],
  myname: string,
  myins: openArray[Type],
  myouts: openArray[Type],
  body: untyped
) = addfn(items, myname, mksig(myins, myouts), body)


#==========================================================#
#===                     cobre.core                     ===#
#==========================================================#

let binT*: Type = Type(kind: nativeT, name: "bin")
let boolT*: Type = Type(kind: nativeT, name: "bool")

discard newModule(
  name = "cobre.core",
  types = @{ "bool": boolT, "bin": binT }
)


#==========================================================#
#===                     cobre.int                     ===#
#==========================================================#

let intT*: Type = Type(kind: nativeT, name: "int")

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

  var prim = newModule(
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
  prim.deprecated = true


#==========================================================#
#===                     cobre.float                    ===#
#==========================================================#

let fltT*: Type = Type(kind: nativeT, name: "float")

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

let strT*: Type = Type(kind: nativeT, name: "string")
let charT*: Type = Type(kind: nativeT, name: "string")

block:
  var items = @[
    Item(name: "string", kind: tItem, t: strT),
    Item(name: "char", kind: tItem, t: charT)
  ]

  items.addfn("new", [binT], [strT]):
    let bytes = args[0].bytes
    var str = newString(bytes.len)
    for i in 0..bytes.high:
      str[i] = char(bytes[i])
    args.ret Value(kind: strV, s: str)

  items.addfn("itos", [intT], [strT]):
    let i = args[0].i
    args.ret Value(kind: strV, s: $i)

  items.addfn("ftos", [fltT], [strT]):
    let f = args[0].f
    args.ret Value(kind: strV, s: $f)

  items.addfn("add", [strT, charT], [strT]):
    let r = args[0].s & args[1].s
    args.ret Value(kind: strV, s: r)

  items.addfn("concat", [strT, strT], [strT]):
    let r = args[0].s & args[1].s
    args.ret Value(kind: strV, s: r)

  items.addfn("eq", [strT, strT], [boolT]):
    let r = args[0].s == args[1].s
    args.ret Value(kind: boolV, b: r)

  items.addfn("charat", [strT, intT], [charT, intT]):
    let i = args[1].i
    let str = $args[0].s[i]
    args.retn([
      Value(kind: strV, s: str),
      Value(kind: intV, i: i+1)
    ])

  items.addfn("codeof", [charT], [intT]):
    let code = cast[int](args[0].s[0])
    args.ret Value(kind: intV, i: code)

  items.addfn("length", [strT], [intT]):
    args.ret Value(kind: intV, i: args[0].s.len)
  
  machine_modules.add Module(
    name: "cobre.string",
    kind: simpleM,
    items: items,
  )


#==========================================================#
#===                    cobre.system                    ===#
#==========================================================#

block:
  let fileT = Type(kind: nativeT, name: "file")
  var items = @[ Item(name: "file", kind: tItem, t: fileT) ]

  items.addfn("quit", [intT], []):
    quit(args[0].i)

  items.addfn("print", mksig([strT], [])):
    echo args[0].s
    args.setLen(0)

  items.addfn("read", mksig([], [strT])):
    var line = stdin.readLine()
    args.ret Value(kind: strV, s: line)

  items.addfn("clock", mksig([], [fltT])):
    args.ret Value(kind: fltV, f: cpuTime())

  items.addfn("exec", mksig([strT], [intT])):
    let cmd = args[0].s
    var p = startProcess(command = cmd, options = {poEvalCommand})
    let code = p.waitForExit()
    args.ret Value(kind: intV, i: code)

  items.addfn("cmd", mksig([strT], [strT])):
    let cmd = args[0].s
    var p = startProcess(command = cmd, options = {poEvalCommand})
    var out_file: File
    discard out_file.open(p.outputHandle, fmRead)
    discard p.waitForExit()
    let out_str = out_file.readAll()

    args.ret Value(kind: strV, s: out_str)

  items.addfn("open", mksig([strT, strT], [fileT])):
    let path = args[0].s
    let mode = case args[1].s
      of "w": fmWrite
      of "a": fmAppend
      else: fmRead
    let file = open(path, mode)
    args.ret(Value(kind: ptrV, pt: file))

  items.addfn("readall", mksig([strT], [strT])):
    let path = args[0].s
    let file = open(path, fmRead)
    let contents = readAll(file)
    args.ret(Value(kind: strV, s: contents))

  items.addfn("write", mksig([fileT, strT], [])):
    let file = cast[File](args[0].pt)
    file.write(args[1].s)

  items.addfn("writebyte", mksig([fileT, intT], [])):
    let file = cast[File](args[0].pt)
    let b = uint8(args[1].i)
    let written = file.writeBytes([b], 0, 1)
    if written != 1:
      raise newException(Exception, "Couldn't write file")

  machine_modules.add Module(
    name: "cobre.system",
    kind: simpleM,
    items: items,
  )


#==========================================================#
#===                    cobre.record                     ===#
#==========================================================#

proc hash(t: Type): Hash = t.name.hash
var record_modules = initTable[seq[Type], Module](32)

proc tplFn (argument: Module): Module =
  var types: seq[Type] = @[]
  var n = 0
  var nitem = argument[$n]
  while nitem.kind == tItem:
    types.add(nitem.t)
    n += 1
    nitem = argument[$n]

  if record_modules.hasKey(types):
    return record_modules[types]

  let basename = "record" & $n

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

  proc create_setter (index: int): Function =
    proc prc (args: var seq[Value]) =
      let p = args[0]
      let v = args[1]
      case p.kind
      of productV:
        p.p.fields[index] = v
      else:
        let msg = "Runtime type mismatch, expected " & tp.name
        raise newException(Exception, msg)
    let sig = Signature(ins: @[tp, types[index]], outs: @[])
    return Function(
      name: basename & ".set" & $index,
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
    items.add(Item(
      name: "set" & $i,
      kind: fItem,
      f: create_setter(i)
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

  result = Module(
    name: basename & "_module",
    kind: simpleM,
    items: items,
  )
  record_modules[types] = result

machine_modules.add(Module(name: "cobre.record", kind: functorM, fn: tplFn))

# Deprecated
machine_modules.add(Module(name: "cobre.tuple", kind: functorM, fn: tplFn, deprecated: true))


#==========================================================#
#===                     cobre.null                     ===#
#==========================================================#

proc nullFn (argument: Module): Module =
  var argitem = argument["0"]
  if argitem.kind != tItem:
    raise newException(Exception, "argument 0 for cobre.null is not a type")
  var base = argitem.t
  let basename = "null(" & base.name & ")"
  var tp = Type(name: basename, kind: nullableT, t: base)

  var items = @[ Item(kind: tItem, name: "", t: tp) ]

  items.addfn("null", mksig(@[], @[tp])):
    args.ret Value(kind: nilV)

  items.addfn("new", mksig(@[base], @[tp])):
    args.ret args[0]

  items.addfn("get", mksig(@[tp], @[base])):
    if args[0].kind == nilV:
      raise newException(Exception, "Value is null")
    args.ret args[0]

  items.addfn("isnull", mksig(@[tp], @[boolT])):
    let r = args[0].kind == nilV
    args.ret Value(kind: boolV, b: r)

  return Module(
    name: basename & "_module",
    kind: simpleM,
    items: items,
  )

machine_modules.add(Module(name: "cobre.null", kind: functorM, fn: nullFn))


#==========================================================#
#===                    cobre.array                     ===#
#==========================================================#

var array_modules = initTable[Type, Module](32)

proc arrayFn (argument: Module): Module =
  var argitem = argument["0"]
  if argitem.kind != tItem:
    raise newException(Exception, "argument 0 for cobre.array is not a type")
  var base = argitem.t

  if array_modules.hasKey(base):
    return array_modules[base]

  let basename = "array(" & base.name & ")"
  var tp = Type(name: basename, kind: arrayT, t: base)

  proc newProc (args: var seq[Value]) =
    var vs = newSeq[Value](args[1].i)
    for i in 0 ..< vs.len:
      vs[i] = args[0]

    args.ret Value(
      kind: arrayV,
      arr: Array(
        tp: tp,
        items: vs
      )
    )

  proc getProc (args: var seq[Value]) =
    args.ret args[0].arr.items[args[1].i]

  proc setProc (args: var seq[Value]) =
    args[0].arr.items[args[1].i] = args[2]

  var items = @[
    Item(kind: tItem, name: "", t: tp),
    Item(
      name: "new",
      kind: fItem,
      f: Function(
        name: basename & ".new",
        sig: Signature(ins: @[base, intT], outs: @[tp]),
        kind: procF,
        prc: newProc
      )
    ),
    Item(
      name: "get",
      kind: fItem,
      f: Function(
        name: basename & ".get",
        sig: Signature(ins: @[tp, intT], outs: @[base]),
        kind: procF,
        prc: getProc
      )
    ),
    Item(
      name: "set",
      kind: fItem,
      f: Function(
        name: basename & ".set",
        sig: Signature(ins: @[tp, intT, base], outs: @[]),
        kind: procF,
        prc: setProc
      )
    )
  ]

  items.addfn("len", mksig(@[tp], @[intT])):
    let r = args[0].arr.items.len
    args.ret Value(kind: intV, i: r)

  # These two are temporary, until other array types are introduced

  items.addfn("push", mksig(@[tp, base], @[])):
    args[0].arr.items.add args[1]

  items.addfn("empty", mksig(@[], @[tp])):
    args.ret Value(
      kind: arrayV,
      arr: Array(
        tp: tp,
        items: @[]
      )
    )


  result = Module(
    name: basename & "_module",
    kind: simpleM,
    items: items,
  )
  array_modules[base] = result

machine_modules.add(Module(name: "cobre.array", kind: functorM, fn: arrayFn))


#==========================================================#
#===                   cobre.function                   ===#
#==========================================================#

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


#==========================================================#
#===                   cobre.typeshell                  ===#
#==========================================================#

proc shellFn (argument: Module): Module =

  #[ This is a problem, I cannot check right away if the argument is a type
  # because I would need to evaluate it, nor can I get the type name
  var argitem = argument["0"]
  if argitem.kind != tItem:
    raise newException(Exception, "argument 0 for cobre.typeshell is not a type")
  var base = argitem.t
  let basename = "shell(" & base.name & ")"
  ]#

  let basename = "typeshell"

  proc getbase (): Type =
    let argitem = argument["0"]
    if argitem.kind != tItem:
      raise newException(Exception, "argument 0 for cobre.typeshell is not a type")
    return argitem.t

  let tp = Type(name: basename, kind: nativeT)
  let tpitem = Item(kind: tItem, name: "", t: tp)

  # Just returns the argument as is, as this type is just a box
  proc idProc (args: var seq[Value]) = args.ret args[0]

  # These items cannot be created yet because I need their signatures,
  # and the signatures need the type, which cannot be evaluated yet
  var newitem = none(Item)
  var getitem = none(Item)

  proc getter (key: string): Item =
    case key
    of "": tpitem
    of "new":
      if newitem.isNone:
        newitem = some(Item(
          name: "new",
          kind: fItem,
          f: Function(
            name: basename & ".new",
            sig: mksig(@[getbase()], @[tp]),
            kind: procF,
            prc: idProc
          )
        ))
      newitem.get
    of "get":
      if getitem.isNone:
        getitem = some(Item(
          name: "get",
          kind: fItem,
          f: Function(
            name: basename & ".get",
            sig: mksig(@[tp], @[getbase()]),
            kind: procF,
            prc: idProc
          )
        ))
      getitem.get
    else: Item(kind: nilItem)

  return Module(
    name: basename & "_module",
    kind: lazyM,
    getter: getter,
  )

machine_modules.add(Module(name: "cobre.typeshell", kind: functorM, fn: shellFn))