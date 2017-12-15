
type
  Signature* = object
    ins*: seq[Type]
    outs*: seq[Type]

  Product* = ref object of RootObj
    tp: Type
    fields: seq[Value]

  ValueKind* = enum nilV, boolV, intV, productV, functionV
  Value* = object
    case kind*: ValueKind
    of nilV: discard
    of boolV: b*: bool
    of intV: i*: int
    of productV: p*: Product
    of functionV: f*: Function

  FunctionKind* = enum procF, codeF
  Function* = ref object of RootObj
    module*: Module
    name*: string
    sig*: Signature
    case kind*: FunctionKind
    of procF:
      prc*: proc(ins: seq[Value]): seq[Value]
    of codeF:
      code*: seq[Inst]
      regcount*: int

  InstKind* = enum endI, varI, dupI, setI, sgtI, sstI, jmpI, jifI, nifI, anyI, callI
  Inst* = object
    case kind*: InstKind
    of varI: discard
    of endI, callI:
      f*: Function
      args*: seq[int]
      ret*: int
    of setI, sgtI, sstI, dupI, jmpI, jifI, nifI, anyI:
      src*: int
      dest*: int
      inst*: int

  State = ref object
    f: Function
    pc: int
    regs: seq[Value]
    retpos: int
    counter: int

  TypeKind* = enum nativeT, aliasT, nullableT, productT, sumT, functionT
  Type* = ref object of RootObj
    module*: Module
    name*: string
    case kind*: TypeKind
    of nativeT: discard
    of aliasT, nullableT:
      t*: Type
    of productT, sumT:
      ts*: seq[Type]
    of functionT:
      sig*: Signature

  ItemKind* = enum fItem, tItem
  Item* = object
    name*: string
    case kind*: ItemKind
    of fItem: f*: Function
    of tItem: t*: Type

  Module* = ref object
    name*: string
    items*: seq[Item]
    statics*: seq[Value]

  RuntimeError* = object of Exception
  StackOverflowError* = object of RuntimeError
  InfiniteLoopError* = object of RuntimeError

var machine_modules* = newSeq[Module]()

proc fullName* (f: Function): string = f.module.name & "." & f.name
proc fullName* (t: Type): string =
  t.module.name & "." & ( if t.name.isNil: "<type>" else: t.name )

proc `$`* (i: Item): string =
  $i.kind & "(" & i.name & ", " & (case i.kind
    of fItem: $i.f[]
    of tItem: $i.t[]
  ) & ")"
proc `$`* (m: Module): string =
  if m.isNil: return "nil"
  else: result = "Module(" & m.name & ", " & $m.items & ", " & $m.statics & ")"
proc `$`* (t: Type): string =
  if t.isNil: return "nil"
  result = "Type_" & $t.kind & "("
  case t.kind
  of nativeT:
    result &= t.name
  of aliasT, nullableT:
    result &= t.t.fullName
  of productT, sumT:
    if t.ts.len > 0:
      result &= t.ts[0].fullName
      for i in 1 .. t.ts.high:
        result &= " " & t.ts[i].fullName
  of functionT:
    for i in 0 .. t.sig.ins.high:
      result &= t.sig.ins[i].fullName & " "
    result &= "->"
    for i in 0 .. t.sig.outs.high:
      result &= " " & t.sig.outs[i].fullName
  result &= ")"

proc nilGet (m: Module, k: string): tuple[fail: bool, item: Item] =
  for item in m.items:
    if item.name == k:
      return (false, item)
  return (true, Item())
template raiseKeyError (m: Module, k: string, nm: string): untyped =
  let msg = "Module " & m.name & " doesn't contain the " & nm & " " & k
  raise newException(KeyError, msg)
proc `[]=`* (m: var Module, k: string, f: Function) =
  m.items.add(Item(name: k, kind: fItem, f: f))
proc `[]=`* (m: var Module, k: string, t: Type) =
  m.items.add(Item(name: k, kind: tItem, t: t))
proc get_function* (m: Module, k: string): Function =
  let (fail, item) = m.nilGet k
  if fail or item.kind != fItem:
    m.raiseKeyError(k, "Function")
  return item.f
proc get_type* (m: Module, k: string): Type =
  let (fail, item) = m.nilGet k
  if fail or item.kind != tItem:
    m.raiseKeyError(k, "Type")
  return item.t
proc hasKey* (m: Module, k: string): bool =
  let (fail, _) = m.nilGet(k)
  return not fail

proc newModule* (
  name: string,
  types: seq[(string, Type)] = @[],
  funcs: seq[(string, Function)] = @[],
  ): Module =
  result = Module(name: name, items: @[], statics: @[])
  for tpl in types:
    let (nm, tp) = tpl
    if tp.name.isNil:
      tp.name = nm
    tp.module = result
    result[nm] = tp
  for tpl in funcs:
    let (nm, f) = tpl
    if f.name.isNil:
      f.name = nm
    f.module = result
    result[nm] = f
  machine_modules.add(result)

proc findModule* (name: string): Module =
  for module in machine_modules:
    if module.name == name:
      return module
  return nil

var max_instruction_count = 10_000
var max_stack_depth = 16

proc newFunction* (
  name: string = "",
  sig: Signature = Signature(ins: @[], outs: @[]),
  prc: proc(ins: seq[Value]): seq[Value]
): Function = Function(name: name, sig: sig, kind: procF, prc: prc)

proc makeCode* (
  f: Function,
  code: seq[Inst],
  module: Module,
  regcount: int) =
  f.kind = codeF
  f.code = code
  f.module = module
  f.regcount = regcount

proc run* (fn: Function, ins: seq[Value]): seq[Value] =
  if fn.kind == procF: return fn.prc(ins)

  var stack = newSeq[State](0)
  proc pushState (f: Function, ins: seq[Value]) =
    if stack.len > max_stack_depth:
      raise newException(StackOverflowError, "Stack size is greater than " & $max_stack_depth)
    var nst = State( f: f, regs: newSeq[Value](f.regcount) )
    for i, v in ins.pairs: nst.regs[i] = v
    stack.add(nst)

  pushState(fn, ins)

  try:
    while stack.len > 0:
      var st = stack[stack.high]

      if st.counter > max_instruction_count:
        raise newException(InfiniteLoopError, "Function has executed " & $max_instruction_count & " instructions")

      proc getValues (xs: seq[int]): seq[Value] =
        result = newSeq[Value](xs.len)
        for i in 0 .. xs.high:
          result[i] = st.regs[ xs[i] ]

      let inst = st.f.code[st.pc]
      let oldpc = st.pc

      #echo "pc:", st.pc , " inst:", inst

      case inst.kind
      of varI: discard # noop
      of setI, dupI: st.regs[inst.dest] = st.regs[inst.src]
      of sgtI: st.regs[inst.dest] = st.f.module.statics[inst.src]
      of sstI: st.f.module.statics[inst.dest] = st.regs[inst.src]
      of jmpI: st.pc = inst.inst
      of jifI:
        if st.regs[inst.src].b:
          st.pc = inst.inst
      of nifI:
        if not st.regs[inst.src].b:
          st.pc = inst.inst
      of anyI:
        if st.regs[inst.src].kind == nilV:
          st.pc = inst.inst
        else:
          st.regs[inst.dest] = st.regs[inst.src]
      of callI:
        let args = getValues(inst.args)
        case inst.f.kind:
        of procF:
          let rets = inst.f.prc(args)
          for i, r in rets.pairs:
            st.regs[i + inst.ret] = r
        of codeF:
          st.retpos = inst.ret
          pushState(inst.f, args)
      of endI:
        let rets = getValues(inst.args)
        discard stack.pop
        if stack.len == 0: result = rets
        else:
          var prevst = stack[stack.high]
          for i, v in rets:
            prevst.regs[i + prevst.retpos] = v

      if st.pc == oldpc: st.pc.inc()
      st.counter.inc()
  except Exception:
    var e = getCurrentException()
    e.msg &= "\n"
    proc errline (str: string) =
      e.msg &= str & "\n"
    errline("Machine stack (oldest first):")
    for i in 0 ..< stack.high:
      let st = stack[i]
      # (pc - 1) porque pc se incrementa después del call
      errline("  " & st.f.name & " (" & $(st.pc - 1) & ")")

    if stack.len > 0:
      let st = stack[stack.high]
      errline("> " & st.f.name & " (" & $st.pc & ")")
      errline("Code: ")
      for i, inst in st.f.code.pairs:
        errline("  " & $i & ": " & $inst)
      errline("Regs: ")
      for i, reg in st.regs.pairs:
        errline("  " & $i & ": " & $reg)
    raise e

proc `==`* (a: Value, b: Value): bool =
  if a.kind != b.kind: return false
  return case a.kind
  of nilV: true
  of boolV: a.b == b.b
  of intV: a.i == b.i
  of productV: a.p == b.p
  of functionV: a.f == b.f

when defined(test):
  include test_machine