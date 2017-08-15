
type
  ValueKind* = enum nilV, boolV, intV
  Value* = object
    case kind*: ValueKind
    of nilV: discard
    of boolV: b*: bool
    of intV: i*: int

  Statics* = ref object
    sq: seq[Value]

  FunctionKind* = enum procF, codeF
  Function* = ref object
    name*: string
    case kind*: FunctionKind
    of procF:
      prc*: proc(ins: seq[Value]): seq[Value]
    of codeF:
      code*: seq[Inst]
      statics*: Statics
      regcount*: int

  InstKind* = enum endI, setI, sgtI, sstI, jmpI, jifI, nifI, anyI, callI
  Inst* = object
    case kind*: InstKind
    of endI, callI:
      f*: Function
      args*: seq[int]
      ret*: int
    of setI, sgtI, sstI:
      src*: int
      dest*: int
    of jmpI, jifI, nifI, anyI:
      inst*: int
      cond*: int

  State = ref object
    f: Function
    pc: int
    regs: seq[Value]
    retpos: int
    counter: int

  RuntimeError* = object of Exception
  StackOverflowError* = object of RuntimeError
  InfiniteLoopError* = object of RuntimeError

var max_instruction_count = 10_000
var max_stack_depth = 16

proc `[]`* (st: Statics, i: int): Value = st.sq[i]
proc `[]=`* (st: Statics, i: int, v: Value) = st.sq[i] = v
proc newStatics* (sq: varargs[Value]): Statics =
  new(result)
  result.sq = @sq

proc newFunction* (
  name: string, prc: proc(ins: seq[Value]): seq[Value]
): Function = Function(name: name, kind: procF, prc: prc)

proc makeCode* (
  f: Function,
  code: seq[Inst],
  statics: Statics,
  regcount: int) =
  f.kind = codeF
  f.code = code
  f.statics = statics
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
      of setI: st.regs[inst.dest] = st.regs[inst.src]
      of sgtI: st.regs[inst.dest] = st.f.statics[inst.src]
      of sstI: st.f.statics[inst.dest] = st.regs[inst.src]
      of jmpI: st.pc = inst.inst
      of jifI:
        if st.regs[inst.cond].b:
          st.pc = inst.inst
      of nifI:
        if not st.regs[inst.cond].b:
          st.pc = inst.inst
      of anyI:
        if st.regs[inst.cond].kind == nilV:
          st.pc = inst.inst
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
