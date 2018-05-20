
var array_modules = initTable[Type, Module](32)

globalFunctor("cobre.array"):
  var argitem = argument["0"]
  if argitem.kind != tItem:
    raise newException(Exception, "argument 0 for cobre.array is not a type")
  var base = argitem.t

  if array_modules.hasKey(base):
    return array_modules[base]

  let basename = "array(" & base.name & ")"
  var tp = Type(name: basename)

  type Array = ref object of RootObj
    items: seq[Value]

  var items = @[ TypeItem("", tp) ]

  items.addfn("new", [base, intT], [tp]):
    var vs = newSeq[Value](args[1].i)
    for i in 0 ..< vs.len:
      vs[i] = args[0]
    args.ret Value(
      kind: objV,
      obj: Array(items: vs)
    )

  items.addfn("get", [tp, intT], [base]):
    let arr = Array(args[0].obj)
    let i = args[1].i
    if i > arr.items.high:
      raise newException(Exception, "index " & $i & " out of bounds (array size: " & $arr.items.len & ")")
    args.ret arr.items[i]

  items.addfn("set", [tp, intT, base], []):
    let arr = Array(args[0].obj)
    let i = args[1].i
    if i > arr.items.high:
      raise newException(Exception, "index " & $i & " out of bounds (array size: " & $arr.items.len & ")")
    arr.items[i] = args[2]

  items.addfn("len", [tp], [intT]):
    let arr = Array(args[0].obj)
    let r = arr.items.len
    args.ret Value(kind: intV, i: r)

  # These two are temporary, until other array types are introduced

  items.addfn("push", [tp, base], []):
    let arr = Array(args[0].obj)
    arr.items.add args[1]

  items.addfn("empty", [], [tp]):
    args.ret Value(
      kind: objV,
      obj: Array(items: @[])
    )


  result = Module(
    name: basename & "_module",
    kind: simpleM,
    items: items,
  )
  array_modules[base] = result