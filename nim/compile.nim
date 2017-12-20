
import parse as P
import machine

import options

type
  Module = machine.Module
  Type = machine.Type
  Function = machine.Function

type
  Data[T] = object
    value: Option[T]
    srcpos: SrcPos
    pending: bool

  State = ref object of RootObj
    parser: P.Parser
    modules: seq[Module]
    types: seq[Data[Type]]
    #types: seq[Type]
    funcs: seq[Function]
    statics: seq[Value]

  CompileError* = object of CobreError
  UnsupportedError* = object of CompileError

proc getType(self: State, i: int): Type

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
      of P.tItem: result[item.name] = self.getType(item.index) #self.types[item.index]
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
  if i > self.types.high:
    raise newException(CompileError, "Type index out of bounds")
  if self.types[i].pending:
    cobreRaise[CompileError]("Recursive type", self.types[i].srcpos)

  if self.types[i].value.isSome:
    return self.types[i].value.get

  self.types[i].pending = true
  let data = self.parser.types[i]
  let module = self.getModule(data.module)
  let item = module[data.name]

  if item.kind != machine.tItem:
    let msg = "Type " & data.name & " not found in " & module.name
    cobreRaise[CompileError](msg, self.types[i].srcpos)
  self.types[i].value = some(item.t)
  self.types[i].pending = false
  return item.t

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
      if data.a > self.funcs.high:
        raise newException(CompileError, "Function index out of bounds")
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
  #  self.modules[i+1] = ModProm(data: p.modules[i], m: nil)

  self.types = newSeq[Data[Type]](p.types.len)

  # Source mapping
  if self.parser.metadata.children.len > 0:
    for topnode in self.parser.metadata.children:
      if topnode.isNamed("source map"):
        let components = topnode["components"]
        if components.isSome:
          for component in components.get.tail:
            if component.isNamed("type"):
              let index = component[1].get.n
              if component[2].isSome:
                self.types[index].srcpos.line = some(component[2].get.n)
              if component[3].isSome:
                self.types[index].srcpos.column = some(component[3].get.n)


  # First create the statics so that functions can use them
  self.statics = newSeq[Value](p.statics.len)
  shallow(self.statics) # Makes the seq be passed by reference instead of by value

  # First iteration to have all the functions available
  self.funcs = newSeq[Function](p.functions.len)
  for i in 0 .. self.funcs.high:
    let data = p.functions[i]

    if data.internal:
      let name = "<function#" & $i & ">"
      self.funcs[i] = Function(name: name, kind: codeF, statics: self.statics)
    else:
      let module = self.getModule(data.module)
      let item = module[data.name]
      if item.kind != machine.fItem: raise newException(CompileError, "Function " & data.name & " not found in " & module.name)
      else: self.funcs[i] = item.f

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
    of funStatic:
      self.statics[i] = Value(kind: functionV, f: self.funcs[data.value])
    else:
      raise newException(UnsupportedError, "Unsupported static kind " & $data.kind)

  # Force all types to trigger full module validation
  for i in 0 .. self.types.high:
    discard self.getType(i)

  # Main Module
  result = self.getModule(1)



