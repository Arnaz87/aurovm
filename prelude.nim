# Definición del módulo Prelude.

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


let preludeStruct = Struct(name: "Prelude", info: @[
  ("Int", TypeType),
  ("String", TypeType),
  ("print", TypeType),
  ("add", TypeType),
  ("itos", TypeType),
  ("CmdArgs", TypeType)
  ])
let preludeType = StructType(preludeStruct)
let preludeData = makeObject(preludeStruct)

preludeData["Int"] = TypeValue(NumberType)
preludeData["String"] = TypeValue(StringType)
preludeData["print"] = TypeValue(printType)
preludeData["add"] = TypeValue(addType)
preludeData["itos"] = TypeValue(itosType)
preludeData["CmdArgs"] = TypeValue(NilType)

var prelude = Module(name: "Prelude", struct: preludeStruct, data: preludeData)
addModule(prelude)