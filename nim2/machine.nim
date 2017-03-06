
#=== Types ===#

type
  ValueKind = enum nilType, intType, strType, boolType
  Value = object
    case kind: ValueKind
    of nilType: discard
    of intType: i: int
    of strType: str: string
    of boolType: b: bool

  Type = ref object of RootObj
    name: string

  InstKind = enum iend, icpy, icns, icall, ilbl, ijmp, ijif, inif
  Inst = object
    case kind: InstKind
    of icall:
      prc: Proc
      outs: seq[int]
      ins: seq[int]
    else:
      i: int
      a: int
      b: int
      c: int

  ProcKind = enum codeProc, nativeProc
  Proc = ref object of RootObj
    name: string
    module: Module
    case kind: ProcKind
    of codeProc:
      inregs: seq[int]
      outregs: seq[int]
      regs: seq[Type]
      code: seq[Inst]
      labels: seq[int]
    of nativeProc:
      incount: int
      outcount: int
      prc: proc(ins: seq[Value]): seq[Value]

  Module = ref object of RootObj
    name: string
    types: seq[Type]
    procs: seq[Proc]
    constants: seq[Value]

  State = ref object of RootObj
    pc: int
    regs: seq[Value]
    prc: Proc

#=== Util Methods ===#

proc `[]` (types: openArray[Type], key: string): Type =
  for t in types:
    if t.name==key:
      return t
  raise newException(KeyError, "key not found: " & $key)
proc `[]` (procs: openArray[Proc], key: string): Proc =
  for p in procs:
    if p.name==key:
      return p
  raise newException(KeyError, "key not found: " & $key)
proc `[]` (modules: openArray[Module], key: string): Module =
  for m in modules:
    if m.name==key:
      return m
  raise newException(KeyError, "key not found: " & $key)

proc intValue (i: int): Value = Value(kind: intType, i: i)
proc boolValue (b: bool): Value = Value(kind: boolType, b: b)
proc strValue (s: string): Value = Value(kind: strType, str: s)

proc `$` (prc: Proc): string =
  result = prc.name & "("
  case prc.kind
  of nativeProc:
    result.add($prc.inCount & " -> " & $prc.outCount)
  of codeProc:
    result.add($prc.inregs.len & " -> " & $prc.outregs.len)
  result.add(")")
proc `$` (tp: Type): string = return "Type[" & tp.name & "]"
proc `$` (v: Value): string =
  case v.kind:
  of nilType: return "nil"
  of intType: return $v.i
  of boolType: return $v.b
  of strType: return $v.str


proc `$$` (prc: Proc): string =
  result = $prc
  case prc.kind
  of nativeProc:
    result.add("[Native]")
  of codeProc:
    result.add("{\n")
    result.add("  regs:\n")
    for tp in prc.regs:
      result.add("    " & $tp & "\n")
    result.add("  code:\n")
    for inst in prc.code:
      result.add("    " & $inst & "\n")
    result.add("}")


#=== Interpreter ===#

var states: seq[State] = @[]

proc addState(prc: Proc) =
  states.add(State(
    pc: 0,
    prc: prc,
    regs: newSeq[Value](prc.regs.len),
  ))

proc run (inst: Inst) =
  var st = states[states.high]
  #echo "pc: " & $st.pc
  case inst.kind
  of iend:
    discard states.pop
  of icpy:
    st.regs[inst.a] = st.regs[inst.b]
    st.pc.inc()
  of icns:
    let v = st.prc.module.constants[inst.b]
    st.regs[inst.a] = v
    st.pc.inc()
  of ijmp:
    st.pc = st.prc.labels[inst.i]
  of ijif: 
    if st.regs[inst.a].b:
      st.pc = st.prc.labels[inst.i]
    else: st.pc.inc()
  of inif: 
    if not st.regs[inst.a].b:
      st.pc = st.prc.labels[inst.i]
    else: st.pc.inc()
  of ilbl: st.pc.inc()
  of icall:
    case inst.prc.kind
    of nativeProc:
      var args = inst.ins.map do (i: int) -> Value: st.regs[i]
      #echo inst.prc.name & "(" & $args & ")"
      var rets = inst.prc.prc(args)
      for pair in zip(inst.outs, rets):
          st.regs[pair.a] = pair.b
    of codeProc: discard
    st.pc.inc()

proc run () =
  while states.len > 0:
    var st = states[states.high]
    let inst = st.prc.code[st.pc]
    inst.run()