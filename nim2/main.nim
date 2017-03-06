import tables
import sequtils

include machine
include modules

include read

#[
var mainModule = Module(
  name: "main",
  types: @[],
  constants: @[
    Value(kind: strType, str: "Hola Mundo!")
  ]
)

mainModule.procs = @[Proc(
  name: "main",
  kind: codeProc,
  module: mainModule,
  inregs: @[],
  outregs: @[],
  regs: @[modules["Prelude"].types["String"]],
  code: @[
    Inst(kind: icns, a: 0, b: 0),
    Inst(kind: icall, outs: @[], ins: @[0],
      prc: modules["Prelude"].procs["print"])
  ]
)]

addState(mainModule.procs["main"])
]#

let parsed = parse("../out")

#echo $$parsed.procs["main"]

for v in parsed.constants:
  discard "echo $v"

addState(parsed.procs["main"])
run()

