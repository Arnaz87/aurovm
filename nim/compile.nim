
import parse as P
import machine

type
  Module = machine.Module
  Type = machine.Type
  Function = machine.Function

type

  State = ref object of RootObj
    parser: P.Parser
    modules: seq[Module]
    types: seq[Type]
    funcs: seq[Function]
    statics: seq[Value]

  CompileError* = object of Exception
  UnsupportedError* = object of CompileError

proc getModule (self: State, index: int): Module =
  if index > self.modules.high:
    raise newException(CompileError, "Module index out of bounds")

  if not self.modules[index].isNil: return self.modules[index]

  let data = self.parser.modules[index-1]
  case data.kind
  of P.mImport, P.mImportF:
    result = findModule(data.name)
    if result.isNil:
      raise newException(CompileError, "Module " & data.name & " not found")
  of P.mDefine:
    result = newModule("<anonymous>")
    for item in data.items:
      case item.kind
      of P.tItem: result[item.name] = self.types[item.index]
      of P.fItem: result[item.name] = self.funcs[item.index]
      else: raise newException(UnsupportedError, "Non function/type items not supported")
  of P.mBuild:
    var base = self.getModule(data.module)
    if base.kind != functorM:
      raise newException(CompileError, "Module " & base.name & " is not a functor")
    var argument = self.getModule(data.argument)
    result = base.fn(argument)
  else:
    raise newException(UnsupportedError, "Module kind " & $data.kind & " not yet supported")

  self.modules[index] = result


proc getType (self: State, i: int): Type =
  if not self.types[i].isNil: return self.types[i]

  let data = self.parser.types[i]
  let module = self.getModule(data.module)
  result = module.get_type(data.name)

  if result.isNil: raise newException(CompileError, "Type " & data.name & " not found in " & module.name)
  self.types[i] = result

proc compileCode (self: State, fn: Function, fdata: P.Function) =
  var reg_count = fdata.ins.len

  fn.code = newSeq[machine.Inst](fdata.code.len)
  for i in 0 .. fn.code.high:
    let data = fdata.code[i]

    var inst = machine.Inst(kind: data.kind)
    case inst.kind
    of varI:
      reg_count += 1
    of dupI, sgtI:
      inst.src = data.a
      inst.dest = reg_count
      reg_count += 1
    of setI, sstI:
      inst.dest = data.a
      inst.src = data.b
    of jmpI:
      inst.inst = data.a
    of jifI, nifI, anyI:
      inst.inst = data.a
      inst.src = data.b
      if inst.kind == anyI:
        inst.dest = reg_count
        reg_count += 1
    of endI:
      inst.args = data.args
    of callI:
      let fd = self.parser.functions[data.a]
      let result_count = fd.outs.len

      inst.f = self.funcs[data.a]
      inst.args = data.args
      inst.ret = reg_count
      reg_count += result_count

    fn.code[i] = inst

  fn.reg_count = reg_count

proc compile* (parser: P.Parser): Module =

  var self = State(parser: parser)
  let p = self.parser

  # modules[0] is the argument. For now it doesn't exist
  self.modules = newSeq[Module](p.modules.len+1)
  #for i in 0 .. p.modules.high:
  #self.modules[i+1] = ModProm(data: p.modules[i], m: nil)


  self.types = newSeq[Type](p.types.len)
  for i in 0 .. self.types.high:
    let data = p.types[i]
    let module = self.getModule(data.module)
    let tp = module.get_type(data.name)

    if tp.isNil: raise newException(CompileError, "Type " & data.name & " not found in " & module.name)
    else: self.types[i] = tp

  # First create the statics so that functions can use them
  self.statics = newSeq[Value](p.statics.len)
  shallow(self.statics) # Makes the seq pass by reference instead of by value

  # First iteration to have all the functions available
  self.funcs = newSeq[Function](p.functions.len)
  for i in 0 .. self.funcs.high:
    let data = p.functions[i]

    if data.internal:
      self.funcs[i] = Function(name: "<anonymous>", kind: codeF, statics: self.statics)
    else:
      let module = self.getModule(data.module)
      let fn = module.get_function(data.name)
      if fn.isNil: raise newException(CompileError, "Type " & data.name & " not found in " & module.name)
      else: self.funcs[i] = fn

  # Second iteration to create the code, having all the functions
  for i in 0 .. self.funcs.high:
    let data = p.functions[i]
    if not data.internal: continue
    self.compileCode(self.funcs[i], p.functions[i])


  # Now create all the statics
  for i in 0 .. p.statics.high:
    let data = p.statics[i]
    case data.kind
    of intStatic:
      self.statics[i] = Value(kind: intV, i: data.value)
    else:
      raise newException(UnsupportedError, "Unsupported static kind " & $data.kind)

  # Main Module
  result = self.getModule(1)



