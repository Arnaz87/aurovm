
import machine
import sourcemap

type TypeError* = object of CompileError
  instinfo*: InstInfo

proc typeCheck*(fn: Function) =

  proc check(t1: Type, t2: Type, index: int) =
    if t1 != t2:
      let n1 = if not t1.isNil: t1.name else: "<nil>"
      let n2 = if not t2.isNil: t2.name else: "<nil>"
      let instinfo = fn.codeinfo.getInst(index)
      let msg = "Type Mismatch. Expected " & n2 & ", got " & n1 & ", at: " & $instinfo
      var e = newException(TypeError, msg)
      e.instinfo = instinfo
      raise e

  var regs = newSeq[Type](fn.reg_count)
  var code = newSeq[machine.Inst](0)
  var next_code = fn.code

  for i in 0..fn.sig.ins.high:
    regs[i] = fn.sig.ins[i]

  # Repeat until the next code is equal to the current code
  # in which case no progress was made
  while next_code.len != code.len:
    code = next_code
    next_code = @[]

    for index in 0..code.high:
      let inst = code[index]
      # Wether to cancel this instruction transfer
      var cancel = false
      case inst.kind
      of varI, hltI: discard # Nothing to do
      of dupI:
        if not regs[inst.src].isNil:
          regs[inst.dest] = regs[inst.src]
        else: cancel = true
      of setI:
        if not regs[inst.src].isNil:
          if regs[inst.dest].isNil:
            regs[inst.dest] = regs[inst.src]
          else:
            check(regs[inst.src], regs[inst.dest], index)
        else: cancel = true
      of jmpI: discard
      of jifI, nifI:
        if not regs[inst.src].isNil:
          let boolT = findModule("auro\x1fbool")["bool"].t
          check(regs[inst.src], boolT, index)
        else: cancel = true
      of endI:
        for i in 0 .. inst.args.high:
          let xi = inst.args[i]
          if regs[xi].isNil:
            cancel = true
            break
          check(regs[xi], fn.sig.outs[i], index)
      of callI:
        for i in 0 .. inst.args.high:
          let xi = inst.args[i]
          if regs[xi].isNil:
            cancel = true
            break
          check(regs[xi], inst.f.sig.ins[i], index)
        if not cancel:
          for i in 0 .. inst.f.sig.outs.high:
            regs[i + inst.ret] = inst.f.sig.outs[i]

      #echo "  ", regs, " ", inst, " ", cancel
      if cancel:
        next_code.add(inst)

  if next_code.len > 0:
    raise newException(Exception, "Could not typecheck " & $next_code & " in " & fn.name)