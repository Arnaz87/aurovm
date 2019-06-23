
let typeT*: Type = newType("type")

globalModule("auro.type"):
  self[""] = typeT

  self.addfn("eq", [typeT, typeT], [boolT]):
    let r = Type(args[0].obj) == Type(args[0].obj)
    args.ret Value(kind: boolV, b: r)

  let newFunctor = createFunctor("type.new"):
    let item = argument[""]
    if item.kind != tItem:
      raise newException(Exception, "Argument `` is not a type")

    let value = Value(kind: objV, obj: item.t)

    let cnsf = Function(
      name: "type.new",
      sig: Signature(ins: @[], outs: @[typeT]),
      kind: constF,
      value: value
    )

    SimpleModule("type.new", [FunctionItem("", cnsf)])
  self.items.add(ModuleItem("new", newFunctor))
