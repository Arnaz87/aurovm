
# included in module.nim

globalModule("auro.module.code"):
  self[""] = code_type

  self.addFn("new", [], [code_type]):
    args.ret Value(kind: objV, obj: CodeObj())

  self.addFn("addinput", [code_type, item_type], []):
    var code = CodeObj(args[0].obj)
    let tp = ItemObj(args[1].obj).item.t
    code.ins.add(tp)

  self.addFn("addoutput", [code_type, item_type], []):
    var code = CodeObj(args[0].obj)
    let tp = ItemObj(args[1].obj).item.t
    code.outs.add(tp)

  self.addFn("addint", [code_type, intT], []):
    var code = CodeObj(args[0].obj)
    code.code.add(RawInst(n: args[1].i))

  self.addFn("addfn", [code_type, item_type], []):
    var code = CodeObj(args[0].obj)
    let fn = ItemObj(args[1].obj)
    code.code.add(RawInst(fn: fn))

proc compile (self: CodeObj) =
  self.fn = Function(
    name: "<generated>",
    kind: codeF,
    sig: Signature(
      ins: self.ins,
      outs: self.outs
    )
  )

  var reg_count = self.ins.len

  const instKinds = [endI, hltI, varI, dupI, setI, jmpI, jifI, nifI]

  var i = 0
  while i < self.code.len:
    if self.code[i].fn.isNil:
      let n = self.code[i].n

      if n >= instKinds.len:
        raise newException(CobreError, "Bad code")

      var inst = Inst(kind: instKinds[n])

      case inst.kind
      of hltI:
        i += 1
      of varI:
        i += 1
        reg_count += 1
      of dupI:
        inst.src = self.code[i+1].n
        i += 2
        reg_count += 1
      of setI:
        inst.dest = self.code[i+1].n
        inst.src = self.code[i+2].n
        i += 3
      of jmpI:
        inst.inst = self.code[i+1].n
        i += 2
      of jifI, nifI:
        inst.inst = self.code[i+1].n
        inst.src = self.code[i+2].n
        i += 3
      of endI:
        for j in 1 .. self.outs.len:
          inst.args.add(self.code[i+j].n)
        i += self.outs.len + 1
      of callI: discard
      self.fn.code.add(inst)
    else:
      let f = self.code[i].fn.get_item.f
      var inst = Inst(kind: callI, f: f, ret: reg_count)
      reg_count += f.sig.outs.len

      for j in 0 ..< f.sig.ins.len:
        inst.args.add self.code[i+j].n
      i += f.sig.ins.len
      self.fn.code.add(inst)

  self.fn.reg_count = reg_count
  self.fn.typeCheck()
