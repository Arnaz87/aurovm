
var null_modules = initTable[Type, Module](32)

globalFunctor("auro.null"):
  var argitem = argument["0"]
  if argitem.kind != tItem:
    raise newException(Exception, "argument 0 for auro.null is not a type")
  var base = argitem.t

  if null_modules.hasKey(base):
    return null_modules[base]

  let basename = "null(" & base.name & ")"
  var tp = newType(basename)

  result = createModule(basename & "_module"):
    self[""] = tp

    self.addfn("null", mksig(@[], @[tp])):
      args.ret Value(kind: nilV)

    self.addfn("new", mksig(@[base], @[tp])):
      args.ret args[0]

    self.addfn("get", mksig(@[tp], @[base])):
      if args[0].kind == nilV:
        raise newException(UserError, "Value is null")
      args.ret args[0]

    self.addfn("isnull", mksig(@[tp], @[boolT])):
      let r = args[0].kind == nilV
      args.ret Value(kind: boolV, b: r)
      
  null_modules[base] = result