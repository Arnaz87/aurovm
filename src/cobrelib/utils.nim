
block:

  var arr_modules = initTable[Type, Module](16)
  globalFunctor("cobre.utils.arraylist"):
    var argitem = argument["0"]
    if argitem.kind != tItem:
      raise newException(Exception, "argument 0 for cobre.utils.arraylist is not a type")
    var base = argitem.t

    if arr_modules.hasKey(base):
      return arr_modules[base]

    let basename = "arraylist(" & base.name & ")"
    var tp = newType(basename)

    type Array = ref object of RootObj
      items: seq[Value]

    result = createModule(basename):
      self[""] = tp

      self.addfn("new", [], [tp]):
        args.ret Value(
          kind: objV,
          obj: Array(items: @[])
        )

      self.addfn("get", [tp, intT], [base]):
        let arr = Array(args[0].obj)
        let i = args[1].i
        if i > arr.items.high:
          raise newException(UserError, "index " & $i & " out of bounds (array size: " & $arr.items.len & ")")
        args.ret arr.items[i]

      self.addfn("set", [tp, intT, base], []):
        let arr = Array(args[0].obj)
        let i = args[1].i
        if i > arr.items.high:
          raise newException(UserError, "index " & $i & " out of bounds (array size: " & $arr.items.len & ")")
        arr.items[i] = args[2]

      self.addfn("len", [tp], [intT]):
        let arr = Array(args[0].obj)
        let r = arr.items.len
        args.ret Value(kind: intV, i: r)

      self.addfn("push", [tp, base], []):
        let arr = Array(args[0].obj)
        arr.items.add args[1]

      self.addfn("insert", [tp, base, intT], []):
        let arr = Array(args[0].obj)
        let i = args[2].i
        if i > arr.items.high:
          raise newException(UserError, "index " & $i & " out of bounds (array size: " & $arr.items.len & ")")
        arr.items.insert(args[1], i)

      self.addfn("remove", [tp, intT], []):
        let arr = Array(args[0].obj)
        let i = args[1].i
        if i > arr.items.high:
          raise newException(UserError, "index " & $i & " out of bounds (array size: " & $arr.items.len & ")")
        arr.items.delete i
        
    arr_modules[base] = result
  
  var str_modules = initTable[Type, Module](16)
  globalFunctor("cobre.utils.stringmap"):
    var argitem = argument["0"]
    if argitem.kind != tItem:
      raise newException(Exception, "argument 0 for cobre.utils.stringmap is not a type")
    var base = argitem.t

    if str_modules.hasKey(base):
      return str_modules[base]

    let basename = "stringmap(" & base.name & ")"
    var tp = newType(basename)

    type Map = ref object of RootObj
      items: Table[string, Value]

    let nullArg = SimpleModule("", [TypeItem("0", base)])
    let nullT = findModule("cobre\x1fnull").build(nullArg)[""].t

    result = createModule(basename):
      self[""] = tp

      self.addfn("new", [], [tp]):
        args.ret Value(
          kind: objV,
          obj: Map(items: initTable[string, Value](16))
        )

      self.addfn("get", [tp, strT], [nullT]):
        let map = Map(args[0].obj)
        let k = args[1].s
        if map.items.hasKey k:
          args.ret map.items[k]
        else:
          args.ret Value(kind: nilV)

      self.addfn("set", [tp, strT, base], []):
        let map = Map(args[0].obj)
        map.items[args[1].s] = args[2]

      self.addfn("remove", [tp, strT], []):
        let map = Map(args[0].obj)
        map.items.del args[1].s
        
    str_modules[base] = result