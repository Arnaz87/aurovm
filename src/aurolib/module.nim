
block:
  let item_type: Type = newType("item")

  type ItemObj = ref object of RootObj
    item: Item

  globalModule("auro.module"):
    let mod_type: Type = newType("module")
    self[""] = mod_type

    self.addfn("get", [mod_type, strT], [item_type]):
      let m = Module(args[0].obj)
      let it = m[args[1].s]
      args.ret Value(kind: objV, obj: ItemObj(item: it))


    let creator = createFunctor("new"):

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
          ItemObj(r[0].obj).item

        CustomModule("", getter)
        

      proc getter (name: Name): Item =
        if base_mod.isNil:
          base_mod = builder(SimpleModule("", []))
        base_mod[name]


      CustomModule("", getter, builder)

    self.items.add(ModuleItem("new", creator))

  globalModule("auro.module.item"):
    self[""] = item_type

    self.addfn("null", [], [item_type]):
      let obj = ItemObj(item: Item(kind: nilItem))
      args.ret Value(kind: objV, obj: obj)

    self.addfn("type", [], [typeT]):
      let t = Type(args[0].obj)
      let obj = ItemObj(item: TypeItem("", t))
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
