
var shellid = 1

globalFunctor("cobre.typeshell"):

  #[ This is a problem, I cannot check right away if the argument is a type
  # because I would need to evaluate it, nor can I get the type name
  var argitem = argument["0"]
  if argitem.kind != tItem:
    raise newException(Exception, "argument 0 for cobre.typeshell is not a type")
  var base = argitem.t
  let basename = "shell(" & base.name & ")"
  ]#

  let basename = "type_" & shellid.toHex(2)
  shellid += 1

  proc getbase (): Type =
    let argitem = argument["0"]
    if argitem.kind != tItem:
      raise newException(Exception, "argument 0 for cobre.typeshell is not a type")
    return argitem.t

  let tp = Type(name: basename)
  let tpitem = TypeItem("", tp)

  # Just returns the argument as is, as this type is just a box
  proc idProc (args: var seq[Value]) = args.ret args[0]

  # These items cannot be created yet because I need their signatures,
  # and the signatures need the type, which cannot be evaluated yet
  var newitem = none(Item)
  var getitem = none(Item)

  proc getter (key: Name): Item =
    if key.parts.len > 0: return Item(kind: nilItem)
    case key.main
    of "": tpitem
    of "new":
      if newitem.isNone:
        newitem = some(FunctionItem("new", Function(
          name: basename & ".new",
          sig: mksig(@[getbase()], @[tp]),
          kind: procF,
          prc: idProc
        )))
      newitem.get
    of "get":
      if getitem.isNone:
        getitem = some(FunctionItem("get", Function(
          name: basename & ".get",
          sig: mksig(@[tp], @[getbase()]),
          kind: procF,
          prc: idProc
        )))
      getitem.get
    else: Item(kind: nilItem)

  CustomModule(basename & "_module", getter)