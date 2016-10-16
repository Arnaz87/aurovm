# Definición del módulo Prelude.

let abrArgs = nArgs(@["a", "b"], @["r"])
let arArgs = nArgs(@["a"], @["r"])

proc printProc(obj: Object) =
  let val = obj["a"]
  echo val.str
let printRegs = newStruct("print-regs", @[("a", StringType)])
let printCode = newNativeCode("print", nArgs(@["a"]), printRegs, printProc)

proc addProc(obj: Object) =
  let a = obj["a"]
  let b = obj["b"]
  let r = a.num + b.num
  obj["r"] = NumberValue(r)
let addRegs = newStruct("add-regs", @[
  ("a", NumberType),
  ("b", NumberType),
  ("r", NumberType)])
let addCode = newNativeCode("add", abrArgs, addRegs, addProc)

proc subProc(obj: Object) =
  let a = obj["a"]
  let b = obj["b"]
  let r = a.num - b.num
  obj["r"] = NumberValue(r)
let subRegs = newStruct("sub-regs", @[
  ("a", NumberType),
  ("b", NumberType),
  ("r", NumberType)])
let subCode = newNativeCode("sub", abrArgs, subRegs, subProc)

proc itosProc(obj: Object) =
  let n = obj["a"]
  let s = $n.num
  obj["r"] = Value(kind: stringType, str: s)
let itosRegs = newStruct("itos-regs", @[
  ("a", NumberType),
  ("r", StringType)])
let itosCode = newNativeCode("itos", arArgs, itosRegs, itosProc)

proc incProc(obj: Object) =
  let n = obj["a"]
  let r = n.num + 1
  obj["r"] = NumberValue(r)
let incRegs = newStruct("inc-regs", @[
  ("a", NumberType),
  ("r", NumberType)])
let incCode = newNativeCode("inc", arArgs, incRegs, incProc)

proc decProc(obj: Object) =
  let n = obj["a"]
  let r = n.num - 1
  obj["r"] = NumberValue(r)
let decRegs = newStruct("dec-regs", @[
  ("a", NumberType),
  ("r", NumberType)])
let decCode = newNativeCode("dec", arArgs, decRegs, decProc)

proc ltProc(obj: Object) =
  let a = obj["a"]
  let b = obj["b"]
  let r = a.num < b.num
  obj["r"] = BoolValue(r)
let ltRegs = newStruct("lt-regs", @[
  ("a", NumberType),
  ("b", NumberType),
  ("r", BoolType)])
let ltCode = newNativeCode("lt", abrArgs, ltRegs, ltProc)


proc gtzProc(obj: Object) =
  let n = obj["a"]
  let r = n.num > 0
  obj["r"] = BoolValue(r)
let gtzRegs = newStruct("gtz-regs", @[
  ("a", NumberType),
  ("r", BoolType)])
let gtzCode = newNativeCode("gtz", arArgs, gtzRegs, gtzProc)

let emptyStruct = newStruct("empty-struct", @[])
let emptyStructType = StructType(emptyStruct)

proc eqProc(obj: Object) =
  let a = obj["a"]
  let b = obj["b"]
  let r = a.num == b.num
  obj["r"] = BoolValue(r)
let eqRegs = newStruct("eq-regs", @[
  ("a", NumberType),
  ("b", NumberType),
  ("r", BoolType)])
let eqCode = newNativeCode("eq", abrArgs, eqRegs, eqProc)

proc strcatProc(obj: Object) =
  let a = obj["a"]
  let b = obj["b"]
  obj["r"] = StringValue(a.str & b.str)
let strcatRegs = newStruct("strcat-regs", @[
  ("a", StringType),
  ("b", StringType),
  ("r", StringType)])
let strcatCode = newNativeCode("strcat", abrArgs, strcatRegs, strcatProc)

proc readProc(obj: Object) =
  let s = readLine(stdin)
  obj["r"] = StringValue(s)
let readRegs = newStruct("read-regs", @[("r", StringType)])
let readCode = newNativeCode("read", nArgs(@[], @["r"]), readRegs, readProc)

var preludeData = initTable[string, Value]()

preludeData["Bool"] = TypeValue(BoolType)
preludeData["Num"] = TypeValue(NumberType)
preludeData["String"] = TypeValue(StringType)

preludeData["Code"] = TypeValue(CodeType)
preludeData["Type"] = TypeValue(TypeType)
preludeData["Any"] = TypeValue(NilType)

preludeData["print"] = CodeValue(printCode)
preludeData["add"] = CodeValue(addCode)
preludeData["itos"] = CodeValue(itosCode)
preludeData["inc"] = CodeValue(incCode)
preludeData["dec"] = CodeValue(decCode)
preludeData["gtz"] = CodeValue(gtzCode)
preludeData["strcat"] = CodeValue(strcatCode)
preludeData["read"] = CodeValue(readCode)


var prelude = Module(name: "Prelude", data: preludeData)
addModule(prelude)