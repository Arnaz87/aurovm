
block:
  let mod_type: Type = newType("module")
  let item_type: Type = newType("item")
  let code_type: Type = newType("code")

  type
    ItemObj = ref object of RootObj
      item: Item
      code: CodeObj

    RawInst = object
      fn: ItemObj
      n: int

    CodeObj = ref object of RootObj
      ins: seq[Type]
      outs: seq[Type]
      code: seq[RawInst]
      fn: Function

  proc compile (self: CodeObj)

  proc get_item (obj: ItemObj): Item =
    if obj.code.isNil:
      return obj.item
    if obj.code.fn.isNil:
      obj.code.compile()
    return FunctionItem("", obj.code.fn)

  globalModule("auro.module"):
    self[""] = mod_type

    self.addfn("get", [mod_type, strT], [item_type]):
      let m = Module(args[0].obj)
      let it = m[args[1].s]
      args.ret Value(kind: objV, obj: ItemObj(item: it))

    self.addfn("build", [mod_type, mod_type], [mod_type]):
      let base = Module(args[0].obj)
      let argument = Module(args[1].obj)
      let result = base.build(argument)
      args.ret Value(kind: objV, obj: result)

    let newfct = createFunctor("new"):
      let fn = Function(
        name: "",
        sig: mksig([], [mod_type]),
        kind: constF,
        value: Value(kind: objV, obj: argument)
      )
      SimpleModule("module.new", [FunctionItem("", fn)])

    self.items.add(ModuleItem("new", newfct))


    let creator = createFunctor("create"):

      let ctx_item = argument["ctx"]
      if ctx_item.kind != tItem:
        raise newException(Exception, "`ctx` is not a type")
      let ctx_t = ctx_item.t


      let get_item = argument["get"]

      if get_item.kind != fItem:
        raise newException(Exception, "`get` is not a function")

      let get_f = get_item.f
      if get_f.sig != mksig([ctx_t, strT], [item_type]):
        raise newException(Exception, "Invalid getter signature")



      let build_item = argument["build"]

      if build_item.kind != fItem:
        raise newException(Exception, "`build` is not a function")

      let build_f = build_item.f
      if build_f.sig != mksig([mod_type], [ctx_t]):
        raise newException(Exception, "Invalid builder signature")


      var base_mod: Module = nil

      proc builder (arg: Module): Module =
        let arg_val = Value(kind: objV, obj: arg)
        let r = build_f.run(@[arg_val])

        let ctx = r[0]

        proc getter (name: Name): Item =
          let name_val = Value(kind: strV, s: name.main)
          let r = get_f.run(@[ctx, name_val])
          ItemObj(r[0].obj).get_item

        CustomModule("", getter)
        

      proc getter (name: Name): Item =
        if base_mod.isNil:
          base_mod = builder(SimpleModule("", []))
        var item = base_mod[name]
        item.name = name
        return item


      CustomModule("", getter, builder)

    self.items.add(ModuleItem("create", creator))

  globalModule("auro.module.item"):
    self[""] = item_type

    self.addfn("null", [], [item_type]):
      let obj = ItemObj(item: Item(kind: nilItem))
      args.ret Value(kind: objV, obj: obj)

    self.addfn("type", [type_t], [item_type]):
      let t = Type(args[0].obj)
      let obj = ItemObj(item: TypeItem("", t))
      args.ret Value(kind: objV, obj: obj)

    self.addfn("code", [code_type], [item_type]):
      let code = CodeObj(args[0].obj)
      let obj = ItemObj(code: code)
      args.ret Value(kind: objV, obj: obj)

    self.addfn("module", [mod_type], [item_type]):
      let m = Module(args[0].obj)
      let obj = ItemObj(item: ModuleItem("", m))
      args.ret Value(kind: objV, obj: obj)

    self.addfn("isnull", [item_type], []):
      let r = ItemObj(args[0].obj).item.kind == nilItem
      args.ret Value(kind: boolV, b: r)

    let fn_mod = createFunctor("item.function"):

      let fn_t = findModule("auro\x1ffunction").build(argument)[""].t

      let fn = Function(
        name: "",
        sig: mksig([fn_t], [item_type]),
        kind: procF,
        prc: proc (args: var seq[Value]) =
          let obj = ItemObj(item: FunctionItem("", args[0].fn))
          args.ret Value(kind: objV, obj: obj)
      )

      SimpleModule("item.function", [FunctionItem("", fn)])

    self.items.add(ModuleItem("function", fn_mod))

  include code