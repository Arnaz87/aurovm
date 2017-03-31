
import machine
import methods

var modules* = newSeq[Module]()

let IntType = Type(name: "Int")
let StringType = Type(name: "String")
let AnyType = Type(name: "Any")
let BoolType = Type(name: "Bool")
let BinaryType = Type(name: "Binary")

modules.add Module(
  name: "Prelude",

  types: @[IntType, StringType, AnyType, BoolType, BinaryType],

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
      name: "isub",
      kind: nativeProc,
      incount: 2,
      outcount: 1,
      prc: proc (ins: seq[Value]): seq[Value] =
        let a = ins[0].i
        let b = ins[1].i
        return @[ intValue(a-b) ]
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
      name: "gt",
      kind: nativeProc,
      incount: 2,
      outcount: 1,
      prc: proc (ins: seq[Value]): seq[Value] =
        let a = ins[0].i
        let b = ins[1].i
        return @[ boolValue(a>b) ]
    ),
    Proc(
      name: "gte",
      kind: nativeProc,
      incount: 2,
      outcount: 1,
      prc: proc (ins: seq[Value]): seq[Value] =
        let a = ins[0].i
        let b = ins[1].i
        return @[ boolValue(a>=b) ]
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
      name: "makeint",
      kind: nativeProc,
      incount: 1,
      outcount: 1,
      prc: proc (ins: seq[Value]): seq[Value] =
        let data = ins[0].data
        var n = 0
        for b in data:
          n = (n shl 8) + cast[int](b)
        return @[ intValue(n) ]
    ),
    Proc(
      name: "makestr",
      kind: nativeProc,
      incount: 1,
      outcount: 1,
      prc: proc (ins: seq[Value]): seq[Value] =
        var data = ins[0].data
        var str = newString(data.len)
        if data.len > 0:
          copyMem(addr(str[0]), addr(data[0]), data.len)
        return @[ strValue(str) ]
    )
  ]
)