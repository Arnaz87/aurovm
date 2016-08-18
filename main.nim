import tables
#import typetraits

include types

type State = ref object of RootObj
  run: bool
  pc: int
  code: Code
  regs: Object
  jump: tuple[b: bool, i: int]

proc makeObject*(struct: Struct): Object =
  result = Object(struct: struct)
  newSeq(result.data, struct.info.len)

proc getIndex (struct: Struct, k: string): int =
  for i in (0 .. struct.info.high):
    if struct.info[i].s == k:
      return i
  let msg = "Key " & k & " not found in struct " & struct.name
  raise newException(Exception, msg)

proc getType (struct: Struct, i: int): Type =
  return struct.info[i].t
proc getType (struct: Struct, k: string): Type =
  return struct.getType(struct.getIndex(k))

proc `[]`(obj: Object, i: int): Value   = return obj.data[i]
proc `[]=`(obj: Object, i: int, v: Value) = obj.data[i] = v

proc `[]`(obj: Object, k: string): Value =
  let i = obj.struct.getIndex(k)
  return obj.data[i]
proc `[]=`(obj: Object, k: string, v: Value) =
  let i = obj.struct.getIndex(k)
  obj.data[i] = v



type
  # Una llave puede ser el nombre de un registro o el indice, pero en la
  # versión final solo debe ser un indice.
  KeyKind = enum intKey, strKey
  Key = object
    case kind: KeyKind
    of intKey: i: int
    of strKey: s: string
  # Addr puede ser el nombre de un label o el índice de la instrucción,
  # pero en la versión final solo debe ser el índice.
  Addr = distinct Key

proc `$`(k: Key): string =
  case k.kind
  of intKey: return $k.i
  of strKey: return k.s
proc StrKey (str: string): Key = return Key(kind: strKey, s: str)



type
  Mov = ref object of Inst # a = b
    a: Key
    b: Key
  Get = ref object of Inst # a = b.c
    a: Key
    b: Key
    c: Key
  Set = ref object of Inst # a.b = c
    a: Key
    b: Key
    c: Key
  New = ref object of Inst # a = new(A)
    a: Key
  Call = ref object of Inst # a = b(c)
    a: Key
  End = ref object of Inst
let IEnd = End()

proc IGet(a: string, b: string, c: string): Get =
  return Get(a: StrKey(a), b: StrKey(b), c: StrKey(c))
proc ISet(a: string, b: string, c: string): Set =
  return Set(a: StrKey(a), b: StrKey(b), c: StrKey(c))




proc `[]`(obj: Object, k: Key): Value =
  case k.kind
  of intKey: return obj[k.i]
  of strKey: return obj[k.s]
proc `[]=`(obj: Object, k: Key, v: Value) =
  case k.kind
  of intKey: obj[k.i] = v
  of strKey: obj[k.s] = v
proc getType (struct: Struct, k: Key): Type =
  case k.kind
  of intKey: return struct.getType(k.i)
  of strKey: return struct.getType(k.s)

method run(inst: Inst, st: State) {.base.}=
  let msg = "Unimplemented Instruction for " & inst.repr
  raise newException(Exception, msg)

method run(inst: End, st: State) =
  st.run = false
method run(inst: Get, st: State) =
  var obj = st.regs[inst.b].obj
  var val = obj[inst.c]
  st.regs[inst.a] = val
method run(inst: Set, st: State) =
  var obj = st.regs[inst.a].obj
  var val = st.regs[inst.c]
  obj[inst.b] = val
method run(inst: New, st: State) =
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
method run(inst: Call, st: State) =
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
    raise newException(Exception, "Not yet implemented, Call machine code")






var states: seq[State] = @[] # Es un Stack. Usar add y pop.
var modules: Table[string, Module] = initTable[string, Module](8)

proc addModule*(m: Module) =
  modules[m.name] = m
proc addState*(code: Code) =
  var st = State(run:true, pc: 0, jump: (false, 0))
  st.code = code
  st.regs = makeObject(code.regs)
  st.regs["SELF"] = StructValue(code.module.data)
  states.add(st)

proc run*() =
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

    echo "State code: " & st.code.repr
    echo "instruction[" & $st.pc & "]:" & st.code.code[st.pc].repr

    let regs = st.regs
    for i in (0 .. regs.data.high):
      let info = regs.struct.info[i]
      let value = regs.data[i]
      echo info.s & "[" & info.t.typeRepr & "]:" & value.repr




when isMainModule:
  proc printProc(obj: Object) =
    let val = obj["a"]
    echo val.str
  let printArgs = newStruct("print-args", @[("a", StringType)])
  let printCode = newNativeCode(printArgs, printProc)
  let printType = CodeType(printCode)

  proc addProc(obj: Object) =
    let a = obj["a"]
    let b = obj["b"]
    let r = a.num + b.num
    obj["r"] = Value(kind: numberType, num: r)
  let addArgs = newStruct("add-args", @[
    ("a", NumberType),
    ("b", NumberType),
    ("r", NumberType)])
  let addCode = newNativeCode(addArgs, addProc)
  let addType = CodeType(addCode)

  proc itosProc(obj: Object) =
    let n = obj["a"]
    let s = $n.num
    obj["r"] = Value(kind: stringType, str: s)
  let itosArgs = newStruct("itos-args", @[
    ("a", NumberType),
    ("r", StringType)])
  let itosCode = newNativeCode(itosArgs, itosProc)
  let itosType = CodeType(itosCode)

  let mainArgs = newStruct("main-args", @[])
  let mainRegs = newStruct("main-regs", @[
    ("ARGS", StructType(mainArgs)),
    ("SELF", Type()),

    ("a", NumberType),
    ("b", NumberType),
    ("r", NumberType),
    ("rs", StringType),

    ("add", addType),
    ("print", printType),
    ("itos", itosType) ])
  let mainInst = @[
    IGet("a", "SELF", "a"),
    IGet("b", "SELF", "b"),
    New(a: StrKey("add")),
    ISet("add", "a", "a"),
    ISet("add", "b", "b"),
    Call(a: StrKey("add")),
    IGet("r", "add", "r"),
    New(a: StrKey("itos")),
    ISet("itos", "a", "r"),
    Call(a: StrKey("itos")),
    IGet("rs", "itos", "r"),
    New(a: StrKey("print")),
    ISet("print", "a", "rs"),
    Call(a: StrKey("print")),
    IEnd ]
  let mainCode = newMachineCode(mainArgs, mainRegs, mainInst)
  let mainType = CodeType(mainCode)

  let moduleStruct = Struct(name: "MAIN", info: @[
    ("a", NumberType),
    ("b", NumberType),
    ("MAIN", mainType)
  ])
  let moduleType = StructType(moduleStruct)
  let moduleData = makeObject(moduleStruct)
  moduleData["a"] = NumberValue(4)
  moduleData["b"] = NumberValue(5)

  var module = Module(name: "MAIN", struct: moduleStruct, data: moduleData)

  mainRegs.info[1].t = moduleType
  mainCode.module = module

  addModule(module)
  start()