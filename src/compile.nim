
## Transforms the data structures output by parse into machine data structures

import parse as P
import machine
import metadata
import sourcemap
import typecheck
import aurolib


import options
import sequtils
import strutils

type
  Module = machine.Module
  Type = machine.Type
  Function = machine.Function
  Item = machine.Item

type
  Data[T] = object
    value: Option[T]
    pending: bool

  FnKind = enum readyFn, cnsFn, codeFn
  FnData = object
    case kind: FnKind
    of readyFn:
      f: Function
    of cnsFn, codeFn:
      index: int

  State = ref object of RootObj
    name: string
    parser: P.Parser
    sourcemap: SourceMap
    modules: seq[Module]
    types: seq[Data[Type]]
    funcs: seq[FnData]
    statics: seq[Value]
    static_types: seq[Type]

  UnsupportedError* = object of Exception
  NotFoundError* = object of CompileError
  ModuleNotFoundError* = object of NotFoundError
    moduleinfo*: ModuleInfo
  TypeNotFoundError* = object of NotFoundError
    typeinfo*: TypeInfo
  FunctionNotFoundError* = object of NotFoundError
    codeinfo*: CodeInfo
  IncorrectSignatureError* = object of CompileError
    codeinfo*: CodeInfo

proc getType(self: State, i: int): Type
proc getFunction(self: State, i: int): Function
proc compileCode (self: State, fn: Function, ins: int, code: seq[P.Inst])

proc getModule (self: State, index: int): Module =
  if index > self.modules.high:
    raise newException(CompileError, "Module index out of bounds")

  if not self.modules[index].isNil: return self.modules[index]

  let data = self.parser.modules[index-1]
  case data.kind
  of P.mImport:
    result = findModule(data.name)
    if result.isNil:
      raise newException(CompileError, "Module " & data.name & " not found")
  of P.mDefine:
    var promises = repeat(none(Item), data.items.len)

    proc getter(key: Name): Item =
      proc getname (item: P.Item): Name = machine.parseName(item.name)
      let i = machine.findWithName(data.items, key, getname)
      if i >= 0:
        let item = data.items[i]
        if promises[i].isSome:
          return promises[i].get
        case item.kind
        of P.tItem: result = Item(
          name: key,
          kind: machine.tItem,
          t: self.getType(item.index)
        )
        of P.fItem: result = Item(
          name: key,
          kind: machine.fItem,
          f: self.getFunction(item.index)
        )
        of P.mItem: result = Item(
          name: key,
          kind: machine.mItem,
          m: self.getModule(item.index)
        )
        #else: raise newException(UnsupportedError, "Non function/type items not supported")
        promises[i] = some(result)
        return result
      return Item(kind: machine.nilItem)

    result = CustomModule("", getter)
  of P.mBuild:
    let base = self.getModule(data.module)
    let argument = self.getModule(data.argument)
    result = base.build(argument)
  of P.mUse:
    let base = self.getModule(data.module)
    let item = base[data.name]
    if item.kind != machine.mItem:
      let msg = "Module " & data.name & " not found in " & base.name
      raise newException(ModuleNotFoundError, msg)
    result = item.m

  self.modules[index] = result

proc getType (self: State, i: int): Type =
  if i > self.types.high:
    raise newException(CompileError, "Type index out of bounds")
  if self.types[i].pending:
    raise newException(CompileError, "Recursive Type")

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

proc getFunction(self: State, i: int): Function =
  if i >= self.funcs.len:
    raise newException(CompileError, "Function index out of bounds")

  template fndata: untyped = self.funcs[i]
  case fndata.kind
  of readyFn: return fndata.f
  of cnsFn:
    let data = self.parser.constants[fndata.index]
    case data.kind
    of intConst:
      let n = data.value
      let v = Value(kind: intV, i: n)
      let sig = Signature(ins:  @[], outs: @[aurolib.intT])
      result = Function(name: $n, kind: constF, sig: sig, value: v)
      fndata = FnData(kind: readyFn, f: result)
    of binConst:
      let v = Value(kind: binV, bytes: data.bytes)
      let sig = Signature(ins:  @[], outs: @[aurolib.bufT])
      result = Function(name: "buffer", kind: constF, sig: sig, value: v)
      fndata = FnData(kind: readyFn, f: result)
    of callConst:
      let f = self.getFunction(data.value)
      if f.sig.outs.len != 1:
        raise newException(CompileError, "Constant function calls must have exactly 1 return value")
      assert(data.args.len == f.sig.ins.len)

      var args = newSeq[Value](data.args.len)
      for j in 0 .. args.high:
        let x = data.args[j]
        let af = self.getFunction(x)
        if af.sig.ins.len != 0 or af.sig.outs.len != 1:
          let msg = "Constant arguments must have exactly 0 arguments and 1 return value"
          raise newException(CompileError, msg)
        if af.sig.outs[0] != f.sig.ins[j]:
          raise newException(CompileError, "Type mismatch in call constant")
        args[j] = af.run(@[])[0]

      let v = f.run(args)[0]
      let sig = Signature(ins: @[], outs: @[f.sig.outs[0]])
      result = Function(name: "", kind: constF, sig: sig, value: v)
      fndata = FnData(kind: readyFn, f: result)
  of codeFn:
    let index = i
    let data = self.parser.functions[index]
    let sig = Signature(
      ins:  data.ins.map(proc (x: int): Type = self.getType(x)),
      outs: data.outs.map(proc (x: int): Type = self.getType(x))
    )
    let codeinfo = self.sourcemap.getFunction(index)

    if data.internal:
      let name = $codeinfo
      result = Function(name: name, kind: codeF, sig: sig, codeinfo: codeinfo)
      fndata = FnData(kind: readyFn, f: result)
      self.compileCode(result, data.ins.len, data.code)
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
      result = item.f
      fndata = FnData(kind: readyFn, f: result)


proc compileCode (self: State, fn: Function, ins: int, code: seq[P.Inst]) =
  var reg_count = ins

  fn.code = newSeq[machine.Inst](code.len)
  for i in 0 .. fn.code.high:
    let data = code[i]

    var inst = machine.Inst(kind: data.kind)
    case inst.kind
    of hltI: discard
    of varI:
      reg_count += 1
    of dupI:
      inst.src = data.a
      inst.dest = reg_count
      reg_count += 1
    of setI:
      inst.dest = data.a
      inst.src = data.b
    of jmpI:
      inst.inst = data.a
    of jifI, nifI:
      inst.inst = data.a
      inst.src = data.b
    of endI:
      inst.args = data.args
    of callI:
      if data.a > self.funcs.high:
        raise newException(CompileError, "Function index out of bounds")
      inst.f = self.getFunction(data.a)
      inst.args = data.args
      inst.ret = reg_count
      reg_count += inst.f.sig.outs.len

    fn.code[i] = inst

  fn.reg_count = reg_count

  fn.typeCheck()

proc compile* (parser: P.Parser, name: string): Module =

  var sourcemap: SourceMap = nil
  if parser.metadata.children.len > 0:
    for topnode in parser.metadata.children:
      if topnode.isNamed("source map"):
        sourcemap = newSourceMap(topnode)
  if sourcemap.isNil:
    sourcemap = newSourceMap()

  proc buildModule (argument: Module): Module =
    var self = State(parser: parser, sourcemap: sourcemap, name: name)
    let p = parser

    self.modules = newSeq[Module](p.modules.len+1)
    self.modules[0] = argument

    self.types = newSeq[Data[Type]](p.types.len)

    let fcount = p.functions.len

    self.funcs = newSeq[FnData](fcount + p.constants.len)
    for i in 0 .. self.funcs.high:
      self.funcs[i] = FnData(kind: codeFn, index: i)

    for i in 0 .. p.constants.high:
      self.funcs[fcount + i] = FnData(kind: cnsFn, index: i)

    self.getModule(1)

  var simpleArg = true

  for m in parser.modules.items:
    case m.kind
    of mBuild, mUse:
      if m.module == 0:
        # argument is used as functor
        simpleArg = false
    of mDefine:
      for item in m.items.items:
        if item.kind == P.mItem and item.index == 0:
          # argument contains a module item
          simpleArg = false
    else: discard

  for f in parser.functions.items:
    if not f.internal and f.module == 0:
      # argument contains a function item
      simpleArg = false

  var typeKeys = newSeq[string]()
  for t in parser.types.items:
    if t.module == 0:
      typeKeys.add(t.name)

  type Pair = tuple[key: Module, val: Module]
  var table: seq[Pair] = @[]

  proc `==` (a: Module, b: Module): bool =
    if not simpleArg: return false
    for key in typeKeys.items:
      let ta = a[key]
      let tb = b[key]
      if ta.kind == machine.tItem and tb.kind == machine.tItem:
        if ta.t != tb.t: return false
      else: return false
    return true

  proc getModule (argument: Module): Module =
    for tpl in table:
      if argument == tpl.key:
        return tpl.val
    let m = buildModule(argument)
    table.add( (key: argument, val: m) )
    return m

  let emptyArg = SimpleModule("argument", [])

  proc getter (key: Name): Item = getModule(emptyArg)[key]

  # Main Module
  result = CustomModule(name, getter, getModule)
