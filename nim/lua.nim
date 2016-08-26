
proc appendProc(obj: Object) =
  proc getString(val: Value): string =
    return case val.kind
      of nilType: "nil"
      of boolType: $val.b
      of numberType: $val.num
      of stringType: val.str
      else: "$object$"
  let a = obj["a"].getString
  let b = obj["b"].getString
  obj["r"] = StringValue(a & b)
let appendArgs = newStruct("append-args", @[
  ("a", NumberType),
  ("b", NumberType),
  ("r", NumberType)])
let appendCode = newNativeCode("append", appendArgs, appendProc)
let appendType = CodeType(appendCode)

proc luaprintProc(obj: Object) =
  let val = obj["a"]
  echo val.str
  obj["r"] = NilValue
let luaprintArgs = newStruct("luaprint-args", @[
  ("a", StringType),
  ("r", NilType)])
let luaprintCode = newNativeCode("luaprint", luaprintArgs, luaprintProc)
let luaprintType = CodeType(luaprintCode)

let luaStruct = Struct(name: "Lua", info: @[
  ("print", TypeType),
  ("add", TypeType),
  ("sub", TypeType),
  ("lt", TypeType),
  ("eq", TypeType),
  ("append", TypeType),
  ])
let luaType = StructType(luaStruct)
let luaData = makeObject(luaStruct)

# Definidos en Prelude
luaData["print"] = TypeValue(luaprintType)
luaData["add"] = TypeValue(addType)
luaData["sub"] = TypeValue(subType)
luaData["eq"] = TypeValue(eqType)
luaData["lt"] = TypeValue(ltType)

# Definidos aquí
luaData["append"] = TypeValue(appendType)

# Las funciones de Lua son de tipado dinámico, y las de Prelude,
# supuestamente, son de tipado estático, pero por ahora toda la máquina es
# dinámicamente tipada, y mientras no está lista, me puedo ahorrar un
# poco de tiempo en no implementar lás funciones de Lua.


var luaModule = Module(name: "Lua", struct: luaStruct, data: luaData)
addModule(luaModule)