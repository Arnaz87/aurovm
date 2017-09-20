
import unittest

proc `==` (a: mach.Item, b: mach.Item): bool =
  if a.name != b.name or a.kind != b.kind: return false
  return case a.kind
    of mach.fItem: a.f == b.f
    of mach.tItem: a.t == b.t
proc `==` (a: mach.Module, b: mach.Module): bool =
  if a.isNil or b.isNil: return false
  a.name == b.name and a.items == b.items and a.statics == b.statics

suite "Compile":
  test "Simple Reexport":
    let parsed = parse.Module(
      imports: @["cobre.prim"],
      types: @[
        parse.Type(kind: parse.importT, mod_index: 1, name: "int")
      ],
      functions: @[
        parse.Function(kind: parse.importF,
          index: 1,
          name: "add",
          sig: parse.Signature(
            in_types: @[0, 0],
            out_types: @[0]
          )
        ),
      ],
      statics: @[],
      exports: @[
        parse.Item(kind: parse.type_item, index: 1, name: "Int"),
        parse.Item(kind: parse.function_item, index: 1, name: "add")
      ],
      blocks: @[ newSeq[parse.Inst]() ],
    )
    let compiled = compile(parsed)
    let expected = mach.Module( name: "", statics: @[], items: @[
      mach.Item(name: "Int", kind: mach.tItem,
        t: mach.findModule("cobre.prim").get_type("int")
      ),
      mach.Item(name: "add", kind: mach.fItem,
        f: mach.findModule("cobre.prim").get_function("add")
      )
    ])
    check(compiled == expected)

  test "Times Two":
    let parsed = parse.Module(
      imports: @["cobre.prim"],
      types: @[
        parse.Type(kind: parse.importT, mod_index: 1, name: "int")
      ],
      functions: @[
        parse.Function(kind: parse.importF,
          index: 1,
          name: "add",
          sig: parse.Signature(
            in_types: @[0, 0],
            out_types: @[0]
          )
        ),
        parse.Function(kind: parse.codeF, sig: parse.Signature( #timestwo
          in_types: @[1], out_types: @[1]
        )),
        parse.Function(kind: parse.codeF, sig: parse.Signature( #main
          in_types: @[], out_types: @[]
        )),
      ],
      statics: @[
        parse.Static(kind: intS, value: 2),
      ],
      exports: @[
        parse.Item(kind: parse.function_item, index: 2, name: "timestwo"),
        parse.Item(kind: parse.function_item, index: 3, name: "main")
      ],
      blocks: @[
        @[ #timestwo
          parse.Inst(kind: parse.callI, function_index: 1, arg_indexes: @[0, 0]),
          parse.Inst(kind: parse.endI, arg_indexes: @[1]),
        ],
        @[ #main
          parse.Inst(kind: parse.sgtI, a: 0),
          parse.Inst(kind: parse.callI, function_index: 2, arg_indexes: @[0, 0]),
          parse.Inst(kind: parse.endI, arg_indexes: @[]),
        ],
        newSeq[parse.Inst]()
      ],
    )
    let timestwo = mach.Function(name: "timestwo")
    mach.newCode
    let compiled = compile(parsed)
    let expected = mach.Module( name: "", statics: @[], items: @[
      mach.Item(name: "timestwo", kind: mach.tItem,
        t: mach.newCode()
      ),
      mach.Item(name: "add", kind: mach.fItem,
        f: mach.findModule("cobre.prim").get_function("add")
      )
    ])
    check(compiled == expected)

