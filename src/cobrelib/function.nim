
var function_modules = initTable[Signature, Module](32)

globalFunctor("cobre.function"):
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

  var tp = Type(name: basename)
  var items = @[ TypeItem("", tp) ]

  var applyIns = @[tp]
  applyIns.add(ins)

  let applySig = Signature(ins: applyIns, outs: outs)

  # apply Functions get treated specially by the machine,
  # to keep the stack organized

  items.add(FunctionItem("apply", Function(
    name: basename & ".apply",
    sig: applySig,
    kind: applyF,
  )))

  proc newFunctorFn (argument: Module): Module =
    let item = argument["0"]
    if item.kind != fItem:
      raise newException(Exception, "Argument `0` is not a function")
    let f = item.f
    if f.sig != sig:
      raise newException(Exception, "Incorrect function signature")

    let value = Value(kind: functionV, fn: f)

    let cnsf = Function(
      name: basename,
      sig: Signature(ins: @[], outs: @[tp]),
      kind: constF,
      value: value
    )

    return Module(
      name: basename & ".new",
      kind: simpleM,
      items: @[FunctionItem("", cnsf)]
    )

  let newFunctor = Module(name: basename & ".new", kind: customM, builder: newFunctorFn)
  items.add(ModuleItem("new", newFunctor))

  # A closure is like a normal function, but the base function has an
  # additional parameter, which is bound to the function value
  proc closureFunctorFn (argument: Module): Module =
    let item = argument["0"]
    if item.kind != fItem:
      raise newException(Exception, "Argument `0` is not a function")
    let f = item.f
    if f.sig.outs != sig.outs or f.sig.ins.len != (sig.ins.len + 1):
      raise newException(Exception, "Incorrect closure signature")

    for p in zip(f.sig.ins, sig.ins):
      if p.a != p.b:
        raise newException(Exception, "Incorrect closure signature")

    # Type of the bound value
    let boundT = f.sig.ins[f.sig.ins.high]
    let closurename = basename & ".closure(" & boundT.name & ")"
    var items = newSeq[Item]()

    items.addfn("new", mksig(@[boundT], @[tp])):
      args.ret Value(kind: functionV, fn: Function(
        kind: closureF,
        name: closurename,
        sig: f.sig,
        fn: f,
        bound: args[0]
      ))

    return Module(name: closurename, kind: simpleM, items: items)

  let closureFunctor = Module(name: basename & ".closure", kind: customM, builder: closureFunctorFn)
  items.add(ModuleItem("closure", closureFunctor))

  result = Module(
    name: basename & "_module",
    kind: simpleM,
    items: items,
  )
  function_modules[sig] = result