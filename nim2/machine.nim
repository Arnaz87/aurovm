
# # Máquina virtual
# Toda la definición y el funcionamiento de la máquina virtual está aquí.
# Para usar este módulo, hay que crear un Module y un Proc de ese Module,
# luego usar addState() con ese Proc y luego usar run()

#=== Types ===#

type
  ValueKind* = enum nilType, intType, strType, boolType
  Value* = object
    case kind*: ValueKind
    of nilType: discard
    of intType: i*: int
    of strType: str*: string
    of boolType: b*: bool

  Type* = ref object of RootObj
    name*: string

  InstKind* = enum iend, icpy, icns, icall, ilbl, ijmp, ijif, inif
  Inst* = object
    case kind*: InstKind
    of icall:
      prc*: Proc
      outs*: seq[int]
      ins*: seq[int]
    else:
      i*: int
      a*: int
      b*: int
      c*: int

  ProcKind* = enum codeProc, nativeProc
  Proc* = ref object of RootObj
    name*: string
    module*: Module
    case kind*: ProcKind
    of codeProc:
      inregs*: seq[int]
      outregs*: seq[int]
      regs*: seq[Type]
      code*: seq[Inst]
      labels*: seq[int]
    of nativeProc:
      incount*: int
      outcount*: int
      prc*: proc(ins: seq[Value]): seq[Value]

  Module* = ref object of RootObj
    name*: string
    types*: seq[Type]
    procs*: seq[Proc]
    constants*: seq[Value]

  State* = ref object of RootObj
    pc*: int
    regs*: seq[Value]
    prc*: Proc
    rets: seq[int]

#=== Interpreter ===#

import sequtils

# methods solo usa los tipos, no usa nada de lo que está abajo,
# por lo tanto es seguro importarlo en este punto
import methods

var states: seq[State] = @[]

proc addState*(prc: Proc) =
  states.add(State(
    pc: 0,
    prc: prc,
    regs: newSeq[Value](prc.regs.len),
  ))

proc run* (inst: Inst) =
  var st = states[states.high]
  #echo "pc: " & $st.pc
  case inst.kind
  of iend:
    discard states.pop
    if states.len > 0:
      let ost = states[states.high]
      for pair in zip(st.rets, st.prc.outregs):
        ost.regs[pair.a] = st.regs[pair.b]
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
      var rets = inst.prc.prc(args)
      for pair in zip(inst.outs, rets):
          st.regs[pair.a] = pair.b
    of codeProc:
      addState(inst.prc)
      let nst = states[states.high]
      for pair in zip(inst.prc.inregs, inst.ins):
        nst.regs[pair.a] = st.regs[pair.b]
      nst.rets = inst.outs
    st.pc.inc()

proc run* () =
  try:
    while states.len > 0:
      var st = states[states.high]
      let inst = st.prc.code[st.pc]
      inst.run()
  except Exception:
    let e = getCurrentException()

    echo "Error de ejecución"
    echo getCurrentExceptionMsg()
    echo e.getStackTrace()

    let st = states[states.high]

    echo "pc: " & $st.pc

    echo $$st.prc

    for r in st.regs: echo "  " & $r