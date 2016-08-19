# Aquí están los componentes de la máquina como tal, lo que necesita
# para ejecutar código y mantener estado.

# necesita importar tables para funcionar

var states: seq[State] = @[] # Es un Stack. Usar add y pop.
var modules: Table[string, Module] = initTable[string, Module](8)

proc addModule(m: Module) =
  modules[m.name] = m
proc addState*(code: Code) =
  var st = State(run:true, pc: 0, jump: (false, 0))
  st.code = code
  st.regs = makeObject(code.regs)
  st.regs["SELF"] = StructValue(code.module.data)
  states.add(st)

proc run(inst: Inst, st: State) =
  case inst.kind
  of iend:
    st.run = false
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
    of codeType:
      let mstruct = mtype.code.args
      let obj = makeObject(mstruct)
      st.regs[inst.a] = CodeValue(obj)
    else:
      let msg = "Type at " & stStruct.name & "." & $inst.a & " is not Instantiable"
      raise newException(Exception, msg)
  of icall:
    let stStruct = st.regs.struct
    let mtype = stStruct.getType(inst.a)
    if mtype.kind != codeType:
      let msg = "Type at " & stStruct.name & "." & $inst.a & " is not Callable"
      raise newException(Exception, msg)
    let code = mtype.code
    let args = st.regs[inst.a].obj
    case code.kind
    of nativeCode:
      code.prc(args)
    of machineCode:
      addState(code)
      var nst = states[states.high]
      nst.regs["ARGS"] = StructValue(args)
      #raise newException(Exception, "Not yet implemented, Call machine code")
  else:
    let msg = "Unimplemented Instruction for " & $inst
    raise newException(Exception, msg)

proc run() =
  while states.len > 0:
    var st = states[states.high]
    if st.run:
      var inst = st.code.code[st.pc]
      inst.run(st)
      if st.jump.b:
        st.pc = st.jump.i
        st.jump.b = false
      else:
        st.pc.inc()
    else:
      discard states.pop()

proc start() =
  let mainModule = modules["MAIN"]
  let mainType = mainModule.struct.getType("MAIN")
  let mainCode = mainType.code
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

    echo "State code:"
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
