
## Transforms the data structures output by parse into machine data structures

import parse as P
import metadata
import sourcemap
import machine
import cobrelib

import options
import sequtils
import strutils

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
    sourcemap: SourceMap
    modules: seq[Module]
    types: seq[Data[Type]]
    funcs: seq[Function]
    statics: seq[Value]
    static_types: seq[Type]
    static_function: Function

  UnsupportedError* = object of Exception

  CompileError* = object of CobreError

  NotFoundError* = object of CompileError

  ModuleNotFoundError* = object of NotFoundError
    moduleinfo*: ModuleInfo
  TypeNotFoundError* = object of NotFoundError
    typeinfo*: TypeInfo
  FunctionNotFoundError* = object of NotFoundError
    codeinfo*: CodeInfo

  IncorrectSignatureError* = object of CompileError
    codeinfo*: CodeInfo

  TypeError* = object of CompileError
    instinfo*: InstInfo

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

  let typeinfo = self.sourcemap.getType(i)

  if item.kind != machine.tItem:
    let msg = "Type " & data.name & " not found in " & module.name
    var e = newException(TypeNotFoundError, msg)
    e.typeinfo = typeinfo
    raise e

  self.types[i].value = some(item.t)
  self.types[i].pending = false
  return item.t

proc typeCheck(self: State, fn: Function) =

  proc check(t1: Type, t2: Type, index: int) =
    if t1 != t2:
      let n1 = if not t1.isNil: t1.name else: "<nil>"
      let n2 = if not t2.isNil: t2.name else: "<nil>"
      let instinfo = fn.codeinfo.getInst(index)
      let msg = "Type Mismatch. Expected " & n2 & ", got " & n1 & ", at: " & $instinfo
      var e = newException(TypeError, msg)
      e.instinfo = instinfo
      raise e

  var regs = newSeq[Type](fn.reg_count)
  var code = newSeq[machine.Inst](0)
  var next_code = fn.code

  for i in 0..fn.sig.ins.high:
    regs[i] = fn.sig.ins[i]

  #echo "Typechecking ", fn.name
  #echo "  statics ", self.static_types

  # Repeat until the next code is equal to the current code
  # in which case no progress was made
  while next_code.len != code.len:
    code = next_code
    next_code = @[]

    for index in 0..code.high:
      let inst = code[index]
      # Wether to cancel this instruction transfer
      var cancel = false
      case inst.kind
      of varI: discard # Nothing to do
      of dupI, anyI:
        if regs[inst.src].isNil:
          regs[inst.dest] = regs[inst.src]
        else: cancel = true
      of setI:
        if not regs[inst.src].isNil:
          # If dest has no type, assign it
          if regs[inst.dest].isNil:
            regs[inst.dest] = regs[inst.src]
          else:
            check(regs[inst.src], regs[inst.dest], index)
        else: cancel = true
      of sgtI:
        regs[inst.dest] = self.static_types[inst.src]
      of sstI:
        if not regs[inst.src].isNil:
          check(regs[inst.src], self.static_types[inst.dest], index)
        else: cancel = true
      of jmpI: discard
      of jifI, nifI:
        if not regs[inst.src].isNil:
          let boolT = findModule("cobre.core")["bool"].t
          check(regs[inst.src], boolT, index)
        else: cancel = true
      of endI:
        for i in 0 .. inst.args.high:
          let xi = inst.args[i]
          if regs[xi].isNil:
            cancel = true
            break
          check(regs[xi], fn.sig.outs[i], index)
      of callI:
        for i in 0 .. inst.args.high:
          let xi = inst.args[i]
          if regs[xi].isNil:
            cancel = true
            break
          check(regs[xi], inst.f.sig.ins[i], index)
        if not cancel:
          for i in 0 .. inst.f.sig.outs.high:
            regs[i + inst.ret] = inst.f.sig.outs[i]

      #echo "  ", regs, " ", inst, " ", cancel
      if cancel:
        next_code.add(inst)

  if next_code.len > 0:
    raise newException(EXception, "Could not typecheck " & $next_code & " in " & fn.name)


proc compileCode (self: State, fn: Function, ins: int, code: seq[P.Inst]) =
  var reg_count = ins

  fn.code = newSeq[machine.Inst](code.len)
  for i in 0 .. fn.code.high:
    let data = code[i]

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

  self.typeCheck(fn)

proc compile* (parser: P.Parser): Module =

  var self = State(parser: parser)
  let p = self.parser


  if parser.metadata.children.len > 0:
    for topnode in parser.metadata.children:
      if topnode.isNamed("source map"):
        self.sourcemap = newSourceMap(topnode)
  if self.sourcemap.isNil:
    self.sourcemap = newSourceMap()

  # modules[0] is the argument. For now it doesn't exist
  self.modules = newSeq[Module](p.modules.len+1)
  #for i in 0 .. p.modules.high:
  #  self.modules[i+1] = ModProm(data: p.modules[i], m: nil)

  self.types = newSeq[Data[Type]](p.types.len)


  # First create the statics so that functions can use them
  # This must always be assigned with shallowCopy
  self.statics = newSeq[Value](p.statics.len)

  # This is to be used only here
  self.static_types = newSeq[Type](p.statics.len)

  # First iteration to have all the functions available
  self.funcs = newSeq[Function](p.functions.len)
  for index in 0 .. self.funcs.high:
    let data = p.functions[index]

    let sig = Signature(
      ins:  data.ins.map(proc (x: int): Type = self.getType(x)),
      outs: data.outs.map(proc (x: int): Type = self.getType(x))
    )

    let codeinfo = self.sourcemap.getFunction(index)

    if data.internal:
      let name = "<function#" & $index & ">"
      self.funcs[index] = Function(name: name, kind: codeF, sig: sig)
      self.funcs[index].statics.shallowCopy(self.statics)
      self.funcs[index].codeinfo = codeinfo
    else:
      let module = self.getModule(data.module)
      let item = module[data.name]
      if item.kind != machine.fItem:
        raise newException(CompileError, "Function " & data.name & " not found in " & module.name)

      if item.f.sig != sig:
        let msg = item.f.name & " is " & item.f.sig.name & ", but expected " & sig.name
        var e = newException(IncorrectSignatureError, msg)
        e.codeinfo = codeinfo
        raise e
      self.funcs[index] = item.f

  self.static_function = Function(name: "<static>", kind: codeF)
  self.static_function.statics.shallowCopy(self.statics)

  # Ceate all the statics
  for i in 0 .. p.statics.high:
    let data = p.statics[i]
    case data.kind
    of intStatic:
      self.statics[i] = Value(kind: intV, i: data.value)
      self.static_types[i] = findModule("cobre.int")["int"].t
    of binStatic:
      self.statics[i] = Value(kind: binV, bytes: data.bytes)
      self.static_types[i] = findModule("cobre.core")["bin"].t
    of funStatic:
      let f = self.funcs[data.value]
      self.statics[i] = Value(kind: functionV, fn: f)
      let functor = findModule("cobre.function")
      var items = newSeq[machine.Item](0)

      for i in 0 .. f.sig.ins.high:
        items.add(machine.Item(name: "in" & $i, kind: machine.tItem, t: f.sig.ins[i]))
      for i in 0 .. f.sig.outs.high:
        items.add(machine.Item(name: "out" & $i, kind: machine.tItem, t: f.sig.outs[i]))

      let argument = Module(kind: simpleM, items: items)
      let module = functor.fn(argument)
      self.static_types[i] = module[""].t
    of nullStatic:
      self.statics[i] = Value(kind: nilV)
      self.static_types[i] = self.getType(data.value)
    else:
      raise newException(UnsupportedError, "Unsupported static kind " & $data.kind)

  # Static must be created before the code,
  # because typechecking needs the statics' types

  # Second iteration to create the code, having all the functions
  for i in 0 .. self.funcs.high:
    let data = p.functions[i]
    if not data.internal: continue
    self.compileCode(self.funcs[i], data.ins.len, data.code)
  self.compileCode(self.static_function, 0, p.static_code)

  # Force all unused types, to trigger full module validation
  for i in 0 .. self.types.high:
    discard self.getType(i)

  # Run static code
  discard self.static_function.run(@[])

  # Main Module
  result = self.getModule(1)
