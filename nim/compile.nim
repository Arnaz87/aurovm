
import parse as P
import machine

type
  Module = machine.Module
  Type = machine.Type
  Function = machine.Function

type
  ModProm = object
    data: P.Module
    m: Module

  State = ref object of RootObj
    parser: P.Parser
    modules: seq[ModProm]
    types: seq[Type]
    funcs: seq[Function]
    statics: seq[Value]

  CompileError* = object of Exception
  UnsupportedError* = object of CompileError

proc getModule (self: State, index: int): Module =
  if index > self.modules.high:
    raise newException(CompileError, "Module index out of bounds")

  var promise = self.modules[index]
  if not promise.m.isNil: return promise.m

  let data = promise.data
  case data.kind
  of P.mImport:
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
  else:
    raise newException(UnsupportedError, "Module kind " & $data.kind & " not yet supported")


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
  self.modules = newSeq[ModProm](p.modules.len+1)
  for i in 0 .. p.modules.high:
    self.modules[i+1] = ModProm(data: p.modules[i], m: nil)


  self.types = newSeq[Type](p.types.len)
  for i in 0 .. self.types.high:
    let data = p.types[i]
    let module = self.getModule(data.module)
    let tp = module.get_type(data.name)

    if tp.isNil: raise newException(CompileError, "Type " & data.name & " not found in " & module.name)
    else: self.types[i] = tp


  # First iteration to have all the functions available
  self.funcs = newSeq[Function](p.functions.len)
  for i in 0 .. self.funcs.high:
    let data = p.functions[i]

    if data.internal:
      self.funcs[i] = Function(name: "<anonymous>", kind: codeF)
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


  self.statics = newSeq[Value](p.statics.len)
  for i in 0 .. p.statics.high:
    let data = p.statics[i]
    case data.kind
    of intStatic:
      self.statics[i] = Value(kind: intV, i: data.value)
    else:
      raise newException(UnsupportedError, "Unsupported static kind " & $data.kind)

  # Main Module
  result = self.getModule(1)
  result.statics = self.statics

  # One last iteration to set the modules
  for fn in self.funcs: fn.module = result



