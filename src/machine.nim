
import sequtils
import strutils
import options

from os import sleep

import sourcemap

const do_debug = false

template debug (body: untyped) =
  when (do_debug): body

type
  SrcPos* = object of RootObj
    file*: Option[string]
    line*: Option[int]
    column*: Option[int]

  Signature* = object
    ins*: seq[Type]
    outs*: seq[Type]

  Product* = ref object of RootObj
    tp*: Type
    fields*: seq[Value]

  Array* = ref object of RootObj
    tp*: Type
    items*: seq[Value]

  ValueKind* = enum
    nilV, boolV, intV, fltV, strV, binV, productV, functionV, arrayV, objV, ptrV
  Value* = object
    case kind*: ValueKind
    of nilV: discard
    of boolV: b*: bool
    of intV: i*: int
    of fltV: f*: float
    of strV: s*: string
    of binV: bytes*: seq[uint8]
    of productV: p*: Product
    of functionV: fn*: Function
    of arrayV: arr*: Array
    of objV: obj*: ref RootObj
    of ptrV: pt*: pointer

  FunctionKind* = enum procF, codeF, applyF, constF, closureF
  Function* = ref object of RootObj
    name*: string
    sig*: Signature
    codeinfo*: CodeInfo
    case kind*: FunctionKind
    of procF:
      prc*: proc(args: var seq[Value])
    of codeF:
      code*: seq[Inst]
      regcount*: int
    of constF:
      value*: Value
    of closureF:
      fn*: Function
      bound*: Value
    of applyF: discard

  InstKind* = enum endI, hltI, varI, dupI, setI, jmpI, jifI, nifI, callI
  Inst* = object
    case kind*: InstKind
    of varI, hltI: discard
    of endI, callI:
      f*: Function
      args*: seq[int]
      ret*: int
    of setI, dupI, jmpI, jifI, nifI:
      src*: int
      dest*: int
      inst*: int

  State = object
    f: Function
    pc: int
    regs: seq[Value]
    retpos: int
    counter: int

  TypeKind* = enum nativeT, aliasT, nullableT, arrayT, productT, sumT, functionT
  Type* = ref object of RootObj
    module*: Module
    name*: string
    case kind*: TypeKind
    of nativeT: discard
    of aliasT, nullableT, arrayT:
      t*: Type
    of productT, sumT:
      ts*: seq[Type]
    of functionT:
      sig*: Signature

  ItemKind* = enum nilItem, fItem, tItem, mItem
  Item* = object
    name*: string
    case kind*: ItemKind
    of fItem: f*: Function
    of tItem: t*: Type
    of mItem: m*: Module
    of nilItem: discard

  ModuleKind* = enum functorM, simpleM, lazyM
  Module* = ref object
    name*: string
    deprecated*: bool
    case kind*: ModuleKind
    of simpleM:
      items*: seq[Item]
    of functorM:
      fn*: proc(arg: Module): Module
    of lazyM:
      getter*: proc(key: string): Item
      builder*: proc(arg: Module): Module

  CobreError* = object of Exception
    srcpos*: SrcPos

  RuntimeError* = object of CobreError
  StackOverflowError* = object of RuntimeError
  InfiniteLoopError* = object of RuntimeError

proc cobreRaise*[T](msg: string, srcpos: Srcpos = SrcPos()) =
  var e = newException(T, msg)
  e.srcpos = srcpos
  raise e

var machine_modules* = newSeq[Module]()

var cobreargs* = newSeq[string]()

type ModLoader = proc(name: string): Module
proc default_loader (name: string): Module = nil
var module_loader: ModLoader = default_loader
proc set_module_loader*(loader: ModLoader) =
  module_loader = loader

proc `$`* (f: Function): string = f.name
proc `$`* (i: Item): string =
  if i.kind == nilItem: return "NoItem"
  $i.kind & "(" & i.name & ", " & (case i.kind
    of fItem: $i.f[]
    of tItem: $i.t[]
    of mItem: i.m.name
    else: ""
  ) & ")"
proc `$`* (m: Module): string =
  if m.isNil: return "nil"
  else: result = "Module(" & m.name & ", " & $m.items & ")"
proc `$`* (t: Type): string =
  if t.isNil: return "nil"
  result = "Type_" & $t.kind & "("
  case t.kind
  of nativeT:
    result &= t.name
  of aliasT, nullableT, arrayT:
    result &= t.t.name
  of productT, sumT:
    if t.ts.len > 0:
      result &= t.ts[0].name
      for i in 1 .. t.ts.high:
        result &= " " & t.ts[i].name
  of functionT:
    for i in 0 .. t.sig.ins.high:
      result &= t.sig.ins[i].name & " "
    result &= "->"
    for i in 0 .. t.sig.outs.high:
      result &= " " & t.sig.outs[i].name
  result &= ")"
proc `[]=`* (m: var Module, k: string, f: Function) =
  m.items.add(Item(name: k, kind: fItem, f: f))
proc `[]=`* (m: var Module, k: string, t: Type) =
  m.items.add(Item(name: k, kind: tItem, t: t))
proc `[]`* (m: Module, key: string): Item =
  case m.kind
  of simpleM:
    for item in m.items:
      if item.name == key:
        return item
    return Item(kind: nilItem)
  of lazyM:
    return m.getter(key)
  else:
    return Item(kind: nilItem)

proc build* (self: Module, argument: Module): Module =
  if self.kind == functorM:
    return self.fn(argument)
  if self.kind == lazyM and not self.builder.isNil:
    return self.builder(argument)
  raise newException(CobreError, "Module " & self.name & " is not a functor")

proc name* (sig: Signature): string =
  let ins = sig.ins.map(proc (t: Type): string = t.name)
  let outs = sig.outs.map(proc (t: Type): string = t.name)
  "(" & ins.join(" ") & " -> " & outs.join(" ") & ")"

proc newModule* (
  name: string,
  types: seq[(string, Type)] = @[],
  funcs: seq[(string, Function)] = @[],
  ): Module =
  result = Module(kind: simpleM, name: name, items: @[])
  for tpl in types:
    let (nm, tp) = tpl
    if tp.name.isNil:
      tp.name = nm
    result[nm] = tp
  for tpl in funcs:
    let (nm, f) = tpl
    if f.name.isNil:
      f.name = nm
    result[nm] = f
  machine_modules.add(result)

proc findModule* (name: string): Module =
  for module in machine_modules:
    if module.name == name:
      result = module
      break
  if result.isNil:
    result = module_loader(name)
    if not result.isNil:
      result.name = name
      machine_modules.add(result)
  if not result.isNil and result.deprecated:
    echo "DEPRECATED: " & name

var max_instruction_count = 10_000
var max_stack_depth = 64

proc newFunction* (
  name: string = "",
  sig: Signature = Signature(ins: @[], outs: @[]),
  prc: proc(args: var seq[Value])
): Function = Function(name: name, sig: sig, kind: procF, prc: prc)

proc makeCode* (
  f: Function,
  code: seq[Inst],
  statics: seq[Value],
  regcount: int) =
  f.kind = codeF
  f.code = code
  f.regcount = regcount

proc run* (fn: Function, ins: seq[Value]): seq[Value] =
  var args = ins

  if fn.kind == procF:
    fn.prc(args)
    return args
  if fn.kind == constF:
    return @[fn.value]

  # I tried making one single stack for everything, but it's slower.
  # First i made a type View that holds a pointer to it's first item
  # and gets the rest with pointer arithmetic, it degraded the performance
  # from 2s to 2.6s
  # Then I modified the type to hold a shallow copy of that seq and just adds
  # an offset on every access, it got to 2.5s, still slower than the original
  # 2s, so none of these optimizations works, the naive approach of to just
  # allocate a seq for every state is the best so far

  var stack = newSeq[State](0)
  var top: State

  proc buildTop (fn: Function) =
    top.pc = 0
    top.f = fn
    top.regs = newSeq[Value](fn.regcount)
    top.regs.shallow()
    for i, v in args.pairs: top.regs[i] = v

  template pushFn (fn: Function) =
    if stack.len > max_stack_depth:
      raise newException(StackOverflowError, "Stack size is greater than " & $max_stack_depth)
    stack.add(top)
    buildTop(fn)

  buildTop(fn)

  #echo "Statics: ", fn.statics

  try:
    while true:

      # Just an alias to not modify everything below
      template st: untyped = top

      var advance = true

      #if st.counter > max_instruction_count:
      #  raise newException(InfiniteLoopError, "Function has executed " & $max_instruction_count & " instructions")

      proc fill (args: var seq[Value], xs: var seq[int], outlen: int = 0) =
        args.setLen max(xs.len, outlen)
        for i in 0 .. xs.high:
          args[i] = st.regs[ xs[i] ]

      proc call (f: Function, ret: int) =
        let outlen = f.sig.outs.len
        case f.kind:
        of procF:
          f.prc(args)
          for i in 0 ..< outlen:
            st.regs[i + ret] = args[i]
        of codeF:
          st.retpos = ret
          pushFn(f)
          # avoid advancing to 2nd instruction of child state,
          # at the end of that state this one will advance
          advance = false
        of applyF:
          let fn = args[0].fn
          st.retpos = ret
          args.delete(0) # Remove the function off the arguments
          call(fn, ret)
        of closureF:
          let fn = f.fn
          st.retpos = ret
          args.add(f.bound) # Add bound closure argument at the end
          call(fn, ret)
        of constF:
          st.regs[ret] = f.value

      if st.pc >= st.f.code.len:
        raise newException(RuntimeError, "Function does not return")
      let inst_ptr = st.f.code[st.pc].addr
      template inst: untyped = inst_ptr[]

      debug:
        sleep(100)
        echo st.f.name, ":", st.pc , " inst:", inst

      case inst.kind
      of varI: discard # noop
      of hltI: raise newException(RuntimeError, "Function halted")
      of setI, dupI:
        st.regs[inst.dest] = st.regs[inst.src]
        debug: echo "  [", inst.dest, "]:", st.regs[inst.dest]
      of jmpI:
        st.pc = inst.inst
        advance = false
      of jifI:
        if st.regs[inst.src].b:
          st.pc = inst.inst
          advance = false
      of nifI:
        if not st.regs[inst.src].b:
          st.pc = inst.inst
          advance = false
      of callI:
        let f = inst.f
        args.fill(inst.args, f.sig.outs.len)
        call(f, inst.ret)
      of endI:
        args.fill(inst.args)

        if stack.len > 0:
          top = stack.pop
          for i, v in args:
            let ni = i + top.retpos
            top.regs[ni] = v
        else:
          return args

        # from here on, top is the previous state

      if advance: top.pc.inc()
  except Exception:
    var e = getCurrentException()
    e.msg &= "\n"
    proc errline (str: string) =
      e.msg &= str & "\n"
    errline("Machine stack (oldest first):")
    for i in 0 .. stack.high:
      # (pc - 1) porque pc se incrementa después del call
      let instinfo = stack[i].f.codeinfo.getInst(stack[i].pc - 1)
      errline("  " & $instinfo)

    if stack.len > 0:
      let instinfo = top.f.codeinfo.getInst(top.pc)
      errline("> " & $instinfo)
      errline("Code [pc: " & $top.pc & "]:")
      for i, inst in top.f.code.pairs:
        errline("  " & $i & ": " & $inst)
      errline("Registers: ")
      for i, reg in top.regs.pairs:
        errline("  " & $i & ": " & $reg)
    raise e

proc `==`* (a: Value, b: Value): bool =
  if a.kind != b.kind: return false
  return case a.kind
  of nilV: true
  of boolV: a.b == b.b
  of intV: a.i == b.i
  of fltV: a.f == b.f
  of strV: a.s == b.s
  of binV: a.bytes == b.bytes
  of productV: a.p == b.p
  of functionV: a.fn == b.fn
  of arrayV: a.arr == b.arr
  of objV: a.obj == b.obj
  of ptrV: a.pt == b.pt