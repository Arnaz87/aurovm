import unittest

suite "Machine":

  proc addf (ins: seq[Value]): seq[Value] =
    let r = ins[0].i + ins[1].i
    @[Value(kind: intV, i: r)]

  proc decf (ins: seq[Value]): seq[Value] =
    @[Value(kind: intV, i: ins[0].i - 1)]

  proc gtzf (ins: seq[Value]): seq[Value] =
    @[Value(kind: boolV, b: ins[0].i > 0)]

  let add = newFunction(name = "add", prc = addf)
  let dec = newFunction(name = "dec", prc = decf)
  let gtz = newFunction(name = "gtz", prc = gtzf)

  var emptyModule = Module(
    name: "test",
    statics: newSeq[Value](0)
  )

  test "Basics":
    var myfunc = Function(name: "myfunc")
    myfunc.makeCode(
      code = @[
        Inst(kind: setI, src: 0, dest: 2),
        Inst(kind: callI, f: add, args: @[1, 2], ret: 3),
        Inst(kind: endI, args: @[3]),
      ],
      module = emptyModule,
      regcount = 4,
    )

    let args = @[
      Value(kind: intV, i: 2),
      Value(kind: intV, i: 3)
    ]

    let expected = @[Value(kind: intV, i: 5)]

    check( myfunc.run(args) == expected )

  test "Control Flow":
    var myfunc = Function(name: "myfunc")
    myfunc.makeCode(
      code = @[
        # while (a > 0) {
        Inst(kind: callI, f: gtz, args: @[0], ret: 2),
        Inst(kind: nifI, src: 2, inst: 10),
        #   a = dec(a);
        Inst(kind: callI, f: dec, args: @[0], ret: 3),
        Inst(kind: setI, src: 3, dest: 0),
        #   b = dec(b);
        Inst(kind: callI, f: dec, args: @[1], ret: 3),
        Inst(kind: setI, src: 3, dest: 1),
        #   if (!gtz(b)) {
        Inst(kind: callI, f: gtz, args: @[1], ret: 2),
        Inst(kind: jifI, src: 2, inst: 9),
        #      return a;
        Inst(kind: endI, args: @[0]),
        #    } }
        Inst(kind: jmpI, inst: 0),
        # return b;
        Inst(kind: endI, args: @[1])
      ],
      module = emptyModule,
      regcount = 4,
    )

    let expected = @[Value(kind: intV, i: 3)]
    let result1 = myfunc.run(@[
      Value(kind: intV, i: 3),
      Value(kind: intV, i: 6)
    ])
    check(result1 == expected)
    let result2 = myfunc.run(@[
      Value(kind: intV, i: 6),
      Value(kind: intV, i: 3)
    ])
    check(result2 == expected)

  test "Safety Checkers":
    var myfunc = Function(name: "myfunc")
    myfunc.makeCode(
      code = @[
        # while (a > 0) {
        Inst(kind: callI, f: gtz, args: @[0], ret: 2),
        Inst(kind: nifI, src: 2, inst: 5),
        Inst(kind: setI, src: 0, dest: 1), # x = a
        Inst(kind: setI, src: 1, dest: 0), # a = x
        # }
        Inst(kind: jmpI, inst: 0),
        Inst(kind: endI, args: @[])
      ],
      module = emptyModule,
      regcount = 3,
    )

    check( myfunc.run(@[Value(kind: intV, i: 0)]) == newSeq[Value](0) )
    expect InfiniteLoopError:
      discard myfunc.run(@[Value(kind: intV, i: 1)])

  test "Recursion":
    var myfunc = Function(name: "myfunc")
    myfunc.makeCode(
      code = @[
        # while (a > 0)
        Inst(kind: callI, f: gtz, args: @[0], ret: 1),
        Inst(kind: nifI, src: 1, inst: 3),
        #   x = myfunc(a);
        Inst(kind: callI, f: myfunc, args: @[0], ret: 0),
        # return x;
        Inst(kind: endI, args: @[])
      ],
      module = emptyModule,
      regcount = 2
    )

    check( myfunc.run(@[Value(kind: intV, i: 0)]) == newSeq[Value](0) )
    expect machine.StackOverflowError:
      discard myfunc.run(@[Value(kind: intV, i: 1)])

  test "Statics":
    var module = Module(
      name: "test-statics",
      statics: @[Value(kind: intV, i: 3)]
    )

    var myfunc = Function(name: "myfunc")
    myfunc.makeCode(
      code = @[
        Inst(kind: sgtI, src: 0, dest: 0),
        Inst(kind: callI, f: dec, args: @[0], ret: 1),
        Inst(kind: sstI, src: 1, dest: 0),
        Inst(kind: endI, args: @[]),
      ],
      module = module,
      regcount = 2,
    )
    discard myfunc.run(@[])
    let result = module.statics[0]
    check( result == Value(kind: intV, i: 2) )


