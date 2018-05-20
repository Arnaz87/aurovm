
var record_modules = initTable[seq[Type], Module](32)

globalFunctor("cobre.record"):
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

  var tp = Type(name: basename)
  var items = @[ TypeItem("", tp) ]

  type Product = ref object of RootObj
    fields: seq[Value]

  proc create_getter (index: int): Function =
    proc prc (args: var seq[Value]) =
      let p = Product(args[0].obj)
      let field = p.fields[index]
      args.ret(field)
    let sig = Signature(ins: @[tp], outs: @[types[index]])
    return Function(
      name: basename & ".get" & $index,
      sig: sig,
      kind: procF,
      prc: prc
    )

  proc create_setter (index: int): Function =
    proc prc (args: var seq[Value]) =
      let p = Product(args[0].obj)
      p.fields[index] = args[1]
    let sig = Signature(ins: @[tp, types[index]], outs: @[])
    return Function(
      name: basename & ".set" & $index,
      sig: sig,
      kind: procF,
      prc: prc
    )

  for i in 0..<n:
    items.add(FunctionItem("get" & $i, create_getter(i)))
    items.add(FunctionItem("set" & $i, create_setter(i)))

  proc newProc (args: var seq[Value]) =
    var vs = newSeq[Value](types.len)
    for i in 0..<types.len:
      vs[i] = args[i]

    args.ret Value(
      kind: objV,
      obj: Product(fields: vs)
    )

  let sig = Signature(ins: types, outs: @[tp])
  items.add(FunctionItem("new", Function(
    name: basename & ".new",
    sig: sig,
    kind: procF,
    prc: newProc
  )))

  result = Module(
    name: basename & "_module",
    kind: simpleM,
    items: items,
  )
  record_modules[types] = result