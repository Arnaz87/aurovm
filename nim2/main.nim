import tables
import sequtils

type
  ValueKind = enum nilType, intType, strType, boolType
  Value = object
    case kind: ValueKind
    of nilType: discard
    of intType: num: int
    of strType: str: string
    of boolType: b: bool

  Type = ref object of RootObj
    name: string

  InstKind = enum iend, icpy, icns, icall, ilbl, ijmp, ijif
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
    of nativeProc:
      prc: proc(ins: seq[Value]): seq[Value]

  Module = ref object of RootObj
    name: string
    types: Table[string, Type]
    procs: Table[string, Proc]
    constants: seq[Value]

  State = ref object of RootObj
    pc: int
    regs: seq[Value]
    prc: Proc

var states: seq[State] = @[]

proc addState(prc: Proc) =
  states.add(State(
    pc: 0,
    prc: prc,
    regs: newSeq[Value](prc.regs.len),
  ))

proc run (inst: Inst) =
  var st = states[states.high]
  case inst.kind
  of iend:
    discard states.pop
  of icpy:
    st.regs[inst.a] = st.regs[inst.b]
    st.pc.inc()
  of icns:
    st.regs[inst.a] = st.prc.module.constants[inst.b]
    st.pc.inc()
  of ijmp: st.pc = inst.i
  of ijif: 
    if st.regs[inst.a].b:
      st.pc = inst.i
    else: st.pc.inc()
  of ilbl: discard
  of icall:
    case inst.prc.kind
    of nativeProc:
      var args = inst.ins.map do (i: int) -> Value: st.regs[i]
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

let StringType = Type(name: "String")

let printProc = Proc(
  name: "print",
  kind: nativeProc,
  prc: proc (ins: seq[Value]): seq[Value] =
    echo ins[0].str
    return @[]
)

var mainModule = Module(
  name: "main",
  types: initTable[string, Type](),
  constants: @[
    Value(kind: strType, str: "Hola Mundo!")
  ]
)

mainModule.procs = {"main": Proc(
  name: "main",
  kind: codeProc,
  module: mainModule,
  inregs: @[],
  outregs: @[],
  regs: @[StringType],
  code: @[
    Inst(kind: icns, a: 0, b: 0, c: 0, i: 0),
    Inst(kind: icall, prc: printProc, outs: @[], ins: @[0])
  ]
)}.toTable()

addState(mainModule.procs["main"])

run()
