
import sequtils
import strutils
import options
from algorithm import sort

from os import sleep

import sourcemap

const do_debug = false

template debug (body: untyped) =
  when (do_debug): body

type
  Signature* = object
    ins*: seq[Type]
    outs*: seq[Type]

  ValueKind* = enum
    nilV, boolV, intV, fltV, strV, binV, functionV, objV, ptrV
  Value* = object
    case kind*: ValueKind
    of nilV: discard
    of boolV: b*: bool
    of intV: i*: int
    of fltV: f*: float
    of strV: s*: string
    of binV: bytes*: seq[uint8]
    of functionV: fn*: Function
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

  Type* = ref object of RootObj
    id*: int
    name*: string

  Name* = object
    main*: string
    parts*: seq[string]

  ItemKind* = enum nilItem, fItem, tItem, mItem
  Item* = object
    name*: Name
    case kind*: ItemKind
    of fItem: f*: Function
    of tItem: t*: Type
    of mItem: m*: Module
    of nilItem: discard

  GetterFn = proc(key: Name): Item
  BuilderFn = proc(arg: Module): Module

  ModuleKind* = enum simpleM, customM
  Module* = ref object
    name*: string
    deprecated*: bool
    case kind*: ModuleKind
    of simpleM:
      items*: seq[Item]
    of customM:
      getter*: GetterFn
      builder*: BuilderFn

  CobreError* = object of Exception
  RuntimeError* = object of CobreError
  StackOverflowError* = object of RuntimeError
  InfiniteLoopError* = object of RuntimeError
  UserError* = object of RuntimeError

var machine_modules* = newSeq[Module]()

var auroargs* = newSeq[string]()
var auroexec* = ""

var trace_stack: seq[State]

proc print_trace* () =
  if not trace_stack.isNil:
    # TODO: Unfamiliar reverse for syntax
    for i in 1 .. trace_stack.len:
      let instinfo = trace_stack[^i].f.codeinfo.getInst(trace_stack[^i].pc)
      if i == 1: echo "> ", instinfo
      else: echo "  ", instinfo


proc print_lowlevel* () =
  if not trace_stack.isNil:
    if trace_stack.len > 0:
      let top = trace_stack.pop

      echo "Instructions [pc: ", top.pc, "]:"
      for i, inst in top.f.code.pairs:
        echo "  ", i, ": ", inst
      echo "Registers: "
      for i, reg in top.regs.pairs:
        echo "  ", i, ": ", reg
    else: discard

type ModLoader = proc(name: string): Module
proc default_loader (name: string): Module = nil
var module_loader: ModLoader = default_loader
proc set_module_loader*(loader: ModLoader) =
  module_loader = loader

# TODO: This fails with, for example: "a:b:b:c" "a:b:c:c"
# both ways should be false, but both return true
proc `$`* (self: Name): string =
  if self.parts.len == 0: self.main
  else: self.main & ":" & self.parts.join(":")
proc parseName* (str: string): Name =
  result.parts = str.split("\x1d")
  result.main = result.parts[0]
  result.parts.del(0)
  result.parts.sort(system.cmp)
proc contains* (a: Name, b: Name): bool =
  if a.main != b.main: return false
  if a.parts.len < b.parts.len: return false
  var ia, ib: int
  while ia < a.parts.len and ib < b.parts.len:
    if a.parts[ia] == b.parts[ib]:
      inc(ib)
    inc(ia)
  return ib == b.parts.len

proc findWithName*[T] (a: openarray[T], key: Name, f: proc (x: T): Name): int {.inline} =
  ## Returns the best index of the best match in `a` or -1 if no match.
  var matches = 0
  var i = 0
  for item in items(a):
    let name = f(item)
    if name.contains(key):
      if name.parts.len == key.parts.len:
        return i # exact match
      else:
        inc(matches)
        result = i
    inc(i)
  if matches != 1: return -1

var type_id = 0
proc newType* (name: string): Type =
  result = Type(name: name, id: type_id)
  type_id = type_id + 1

proc TypeItem* (name: string, tp: Type): Item =
  Item(name: parseName(name), kind: tItem, t: tp)
proc FunctionItem* (name: string, fn: Function): Item =
  Item(name: parseName(name), kind: fItem, f: fn)
proc ModuleItem* (name: string, m: Module): Item =
  Item(name: parseName(name), kind: mItem, m: m)

proc SimpleModule* (name: string, items: openarray[Item]): Module =
  Module(kind: simpleM, name: name, items: @items)
proc CustomModule* (name: string, getter: GetterFn, builder: BuilderFn = nil): Module =
  Module(kind: customM, name: name, getter: getter, builder: builder)

proc `$`* (f: Function): string = f.name
proc `$`* (i: Item): string =
  if i.kind == nilItem: return "NoItem"
  $i.kind & "(" & $i.name & ", " & (case i.kind
    of fItem: $i.f[]
    of tItem: $i.t[]
    of mItem: i.m.name
    else: ""
  ) & ")"
proc `$`* (m: Module): string =
  if m.isNil: "nil"
  elif not m.name.isNil: m.name 
  else: "<anonymous module>"
proc `$`* (t: Type): string =
  if t.isNil: "nil"
  else: t.name
proc `[]=`* (m: var Module, k: string, f: Function) =
  m.items.add(FunctionItem(k, f))
proc `[]=`* (m: var Module, k: string, t: Type) =
  m.items.add(TypeItem(k, t))
proc `[]`* (m: Module, key: Name): Item =
  case m.kind
  of simpleM:
    proc get (it: Item): Name = it.name
    let i = findWithName(m.items, key, get)
    if i >= 0: return m.items[i]
  of customM:
    if not m.getter.isNil:
      return m.getter(key)
  else: discard
  return Item(kind: nilItem)
proc `[]`* (m: Module, key: string): Item = m[parseName(key)]

proc build* (self: Module, argument: Module): Module =
  if self.kind == customM and not self.builder.isNil:
    return self.builder(argument)
  raise newException(CobreError, "Module " & self.name & " is not a functor")

proc name* (sig: Signature): string =
  let ins = sig.ins.map(proc (t: Type): string = t.name)
  let outs = sig.outs.map(proc (t: Type): string = t.name)
  "(" & ins.join(" ") & " -> " & outs.join(" ") & ")"

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
var max_stack_depth = 1024 # arbitrary power of two
# max stack depth:
# node: 15387
# firefox: 55851
# python: 999
# lua: 999990 (whoa)

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

  try:
    while true:

      # Just an alias to not modify everything below
      template st: untyped = top

      var advance = true

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
    stack.add(top)
    trace_stack = stack
    raise getCurrentException()

proc `==`* (a: Value, b: Value): bool =
  if a.kind != b.kind: return false
  return case a.kind
  of nilV: true
  of boolV: a.b == b.b
  of intV: a.i == b.i
  of fltV: a.f == b.f
  of strV: a.s == b.s
  of binV: a.bytes == b.bytes
  of functionV: a.fn == b.fn
  of objV: a.obj == b.obj
  of ptrV: a.pt == b.pt