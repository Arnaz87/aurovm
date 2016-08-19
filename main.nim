
include types
include methods
include machine

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
  INew("add"),
  ISet("add", "a", "a"),
  ISet("add", "b", "b"),
  ICall("add"),
  IGet("r", "add", "r"),
  INew("itos"),
  ISet("itos", "a", "r"),
  ICall("itos"),
  IGet("rs", "itos", "r"),
  INew("print"),
  ISet("print", "a", "rs"),
  ICall("print"),
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
