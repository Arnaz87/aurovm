# Aquí están los componentes de la máquina como tal, lo que necesita
# para ejecutar código y mantener estado.

# necesita importar tables para funcionar

var states: seq[State] = @[] # Es un Stack. Usar add y pop.
var modules: Table[string, Module] = initTable[string, Module](8)

proc addModule(m: Module) =
  modules[m.name] = m
proc addState*(code: Code) =
  var st = State(run:true, pc: 0, jump: false)
  st.code = code
  st.regs = makeObject(code.regs)
  st.regs["SELF"] = StructValue(code.module.data)
  states.add(st)

proc findLabel(code: Code, str: string): int =
  for i in 0..code.code.high:
    let inst = code.code[i]
    if (inst.kind == ilbl) and (inst.i.s == str):
      return i
  let msg = "Label " & str & " not found in " & code.name
  raise newException(Exception, msg)


proc run(inst: Inst, st: State) =
  case inst.kind
  of iend:
    st.run = false
  of icpy:
    st.regs[inst.a] = st.regs[inst.b]
  of iget:
    var obj = st.regs[inst.b].obj
    var val = obj[inst.c]
    st.regs[inst.a] = val
  of iset:
    var obj = st.regs[inst.a].obj
    var val = st.regs[inst.c]
    obj[inst.b] = val
  of inew:
    let stStruct = st.regs.struct
    let mtype = stStruct.getType(inst.a)
    var mstruct: Struct
    case mtype.kind
    of structType:
      let mstruct = mtype.struct
      let obj = makeObject(mstruct)
      st.regs[inst.a] = StructValue(obj)
    else:
      let msg = "Type at " & stStruct.name & "." & $inst.a & " is not Instantiable"
      raise newException(Exception, msg)
  of icall:
    let code = inst.code
    case code.kind
    of nativeCode:
      let args = makeObject(code.regs)

      for i in (0 .. code.args.ins.high):
        let an = code.args.ins[i]
        let rn = inst.args.ins[i]
        args[an] = st.regs[rn]

      code.prc(args)

      for i in (0 .. code.args.outs.high):
        let an = code.args.outs[i]
        let rn = inst.args.outs[i]
        st.regs[rn] = args[an]
    of machineCode:
      addState(code)
      var nst = states[states.high]
      for i in (0 .. code.args.ins.high):
        let an = code.args.ins[i]
        let rn = inst.args.ins[i]
        nst.regs[an] = st.regs[rn]
  of ijmp:
    st.jump = true
    st.pc = st.code.findLabel(inst.i.s)
  of iif:
    if (st.regs[inst.a].b):
      st.jump = true
      st.pc = st.code.findLabel(inst.i.s)
  of iifn:
    if not (st.regs[inst.a].b):
      st.jump = true
      st.pc = st.code.findLabel(inst.i.s)
  of inop, ilbl:
    discard

proc run() =
  while states.len > 0:
    var st = states[states.high]
    if st.run:
      var inst = st.code.code[st.pc]
      inst.run(st)
      if st.jump:
        st.jump = false
      else:
        st.pc.inc()
    else:
      if states.len > 1:
        var nst = states[states.high-1]

        # Registros en el estado invocado
        var cd_outs = st.code.args.outs

        # Registros en el estado invocador
        var st_outs = st.outs

        for i in (0 .. cd_outs.high):
          let oldnm = cd_outs[i]
          let newnm = st_outs[i]
          nst.regs[newnm] = st.regs[oldnm]

      discard states.pop()

proc start() =
  let mainModule = modules["MAIN"]
  let mainCode = mainModule.data["MAIN"].code
  addState(mainCode)
  try:
    run()
  except Exception:
    let e = getCurrentException()

    echo "ERROR DE LA MÁQUINA VIRTUAL"
    echo()
    echo getCurrentExceptionMsg()
    echo e.getStackTrace()
    echo()

    let st = states[states.high]

    echo "State code: " & st.code.name
    echo "pc: " & $st.pc
    echo "instructions:"
    for i in (0 .. st.code.code.high):
      echo "  " & $i & ": " & $st.code.code[i]
    echo()

    let regs = st.regs
    for i in (0 .. regs.data.high):
      let info = regs.struct.info[i]
      let value = regs.data[i]
      echo info.s & "[" & info.t.dbgRepr & "]: " & value.dbgRepr(true)
