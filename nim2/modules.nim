
import machine
import methods

var modules* = newSeq[Module]()

let IntType = Type(name: "Int")
let StringType = Type(name: "String")
let AnyType = Type(name: "Any")
let BoolType = Type(name: "Bool")

modules.add Module(
  name: "Prelude",

  types: @[IntType, StringType, AnyType, BoolType],

  constants: @[
    Value(kind: strType, str: "Hola Mundo!")
  ],

  procs: @[
    Proc(
      name: "print",
      kind: nativeProc,
      incount: 1,
      outcount: 0,
      prc: proc (ins: seq[Value]): seq[Value] =
        echo ins[0].str
        return @[]
    ),
    Proc(
      name: "itos",
      kind: nativeProc,
      incount: 1,
      outcount: 1,
      prc: proc (ins: seq[Value]): seq[Value] =
        let i = ins[0].i
        return @[ strValue($i) ]
    ),
    Proc(
      name: "iadd",
      kind: nativeProc,
      incount: 2,
      outcount: 1,
      prc: proc (ins: seq[Value]): seq[Value] =
        let a = ins[0].i
        let b = ins[1].i
        return @[ intValue(a+b) ]
    ),
    Proc(
      name: "eq",
      kind: nativeProc,
      incount: 2,
      outcount: 1,
      prc: proc (ins: seq[Value]): seq[Value] =
        let a = ins[0].i
        let b = ins[1].i
        return @[ boolValue(a==b) ]
    ),
    Proc(
      name: "gtz",
      kind: nativeProc,
      incount: 1,
      outcount: 1,
      prc: proc (ins: seq[Value]): seq[Value] =
        let i = ins[0].i
        return @[ boolValue(i>0) ]
    ),
    Proc(
      name: "inc",
      kind: nativeProc,
      incount: 1,
      outcount: 1,
      prc: proc (ins: seq[Value]): seq[Value] =
        let a = ins[0].i
        return @[ intValue(a+1) ]
    ),
    Proc(
      name: "dec",
      kind: nativeProc,
      incount: 1,
      outcount: 1,
      prc: proc (ins: seq[Value]): seq[Value] =
        let a = ins[0].i
        return @[ intValue(a-1) ]
    ),
    Proc(
      name: "concat",
      kind: nativeProc,
      incount: 2,
      outcount: 1,
      prc: proc (ins: seq[Value]): seq[Value] =
        let a = ins[0].str
        let b = ins[1].str
        return @[ strValue(a & b) ]
    ),
  ]
)