
var function_modules = initTable[Signature, Module](32)

globalFunctor("auro.function"):
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

  var tp = newType(basename)

  var applyIns = @[tp]
  applyIns.add(ins)

  let applySig = Signature(ins: applyIns, outs: outs)

  result = createModule(basename):
    self[""] = tp


    # applyF functions get treated specially by the machine,
    # to keep the stack organized
    self.items.add(FunctionItem("apply", Function(
      name: basename & ".apply",
      sig: applySig,
      kind: applyF,
    )))

    let newFunctor = createFunctor(basename & ".new"):
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

      SimpleModule(basename & ".new", [FunctionItem("", cnsf)])
    self.items.add(ModuleItem("new", newFunctor))

    # A closure is like a normal function, but the base function has an
    # additional parameter, which is bound to the function value
    let closureFunctor = createFunctor(basename & ".closure"):
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
      createModule(closurename):
        self.addfn("new", mksig(@[boundT], @[tp])):
          args.ret Value(kind: functionV, fn: Function(
            kind: closureF,
            name: closurename,
            sig: f.sig,
            fn: f,
            bound: args[0]
          ))
    self.items.add(ModuleItem("closure", closureFunctor))

  function_modules[sig] = result