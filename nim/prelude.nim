# Definición del módulo Prelude.

proc printProc(obj: Object) =
  let val = obj["a"]
  echo val.str
let printArgs = newStruct("print-args", @[("a", StringType)])
let printCode = newNativeCode("print", printArgs, printProc)
let printType = CodeType(printCode)

proc addProc(obj: Object) =
  let a = obj["a"]
  let b = obj["b"]
  let r = a.num + b.num
  obj["r"] = NumberValue(r)
let addArgs = newStruct("add-args", @[
  ("a", NumberType),
  ("b", NumberType),
  ("r", NumberType)])
let addCode = newNativeCode("add", addArgs, addProc)
let addType = CodeType(addCode)

proc subProc(obj: Object) =
  let a = obj["a"]
  let b = obj["b"]
  let r = a.num - b.num
  obj["r"] = NumberValue(r)
let subArgs = newStruct("sub-args", @[
  ("a", NumberType),
  ("b", NumberType),
  ("r", NumberType)])
let subCode = newNativeCode("sub", subArgs, subProc)
let subType = CodeType(subCode)

proc itosProc(obj: Object) =
  let n = obj["a"]
  let s = $n.num
  obj["r"] = Value(kind: stringType, str: s)
let itosArgs = newStruct("itos-args", @[
  ("a", NumberType),
  ("r", StringType)])
let itosCode = newNativeCode("itos", itosArgs, itosProc)
let itosType = CodeType(itosCode)

proc incProc(obj: Object) =
  let n = obj["a"]
  let r = n.num + 1
  obj["r"] = NumberValue(r)
let incArgs = newStruct("inc-args", @[
  ("a", NumberType),
  ("r", NumberType)])
let incCode = newNativeCode("inc", incArgs, incProc)
let incType = CodeType(incCode)

proc decProc(obj: Object) =
  let n = obj["a"]
  let r = n.num - 1
  obj["r"] = NumberValue(r)
let decArgs = newStruct("dec-args", @[
  ("a", NumberType),
  ("r", NumberType)])
let decCode = newNativeCode("dec", decArgs, decProc)
let decType = CodeType(decCode)

proc ltProc(obj: Object) =
  let a = obj["a"]
  let b = obj["b"]
  let r = a.num < b.num
  obj["r"] = BoolValue(r)
let ltArgs = newStruct("lt-args", @[
  ("a", NumberType),
  ("b", NumberType),
  ("r", NumberType)])
let ltCode = newNativeCode("lt", ltArgs, ltProc)
let ltType = CodeType(ltCode)


proc gtzProc(obj: Object) =
  let n = obj["a"]
  let r = n.num > 0
  obj["r"] = BoolValue(r)
let gtzArgs = newStruct("gtz-args", @[
  ("a", NumberType),
  ("r", BoolType)])
let gtzCode = newNativeCode("gtz", gtzArgs, gtzProc)
let gtzType = CodeType(gtzCode)

let emptyStruct = newStruct("empty-struct", @[])
let emptyStructType = StructType(emptyStruct)

proc eqProc(obj: Object) =
  let a = obj["a"]
  let b = obj["b"]
  let r = a.num == b.num
  obj["r"] = BoolValue(r)
let eqArgs = newStruct("eq-args", @[
  ("a", NumberType),
  ("b", NumberType),
  ("r", NumberType)])
let eqCode = newNativeCode("eq", eqArgs, eqProc)
let eqType = CodeType(eqCode)

proc strcatProc(obj: Object) =
  let a = obj["a"]
  let b = obj["b"]
  let r = a.num == b.num
  obj["r"] = BoolValue(r)
let strcatArgs = newStruct("strcat-args", @[
  ("a", NumberType),
  ("b", NumberType),
  ("r", NumberType)])
let strcatCode = newNativeCode("strcat", strcatArgs, strcatProc)
let strcatType = CodeType(strcatCode)


let preludeStruct = Struct(name: "Prelude", info: @[
  # Basic Types
  ("Num", TypeType),
  ("Bool", TypeType),
  ("String", TypeType),
  ("Any", TypeType),

  # Functions
  ("print", TypeType),
  ("add", TypeType),
  ("itos", TypeType),
  ("inc", TypeType),
  ("dec", TypeType),
  ("gtz", TypeType),
  ("strcat", TypeType),

  # Structs
  ("CmdArgs", TypeType),
  ("emptyStruct", TypeType),
  ("Empty", TypeType),
  ])
let preludeType = StructType(preludeStruct)
let preludeData = makeObject(preludeStruct)

preludeData["Bool"] = TypeValue(BoolType)
preludeData["Num"] = TypeValue(NumberType)
preludeData["String"] = TypeValue(StringType)
preludeData["Any"] = TypeValue(NilType)

preludeData["print"] = TypeValue(printType)
preludeData["add"] = TypeValue(addType)
preludeData["itos"] = TypeValue(itosType)
preludeData["inc"] = TypeValue(incType)
preludeData["dec"] = TypeValue(decType)
preludeData["gtz"] = TypeValue(gtzType)
preludeData["strcat"] = TypeValue(strcatType)

preludeData["CmdArgs"] = TypeValue(NilType)
preludeData["emptyStruct"] = TypeValue(emptyStructType)
preludeData["Empty"] = TypeValue(emptyStructType)


var prelude = Module(name: "Prelude", struct: preludeStruct, data: preludeData)
addModule(prelude)