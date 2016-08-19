# Aquí incluyo todo lo que considero métodos de los tipos
#   (Aunque técnicamente casi todos son procedures, no métodos, pero método
#   en el sentido de que le pertenecen a un tipo)

# Este método es muy importante. Podría considerarse también un Constructor.
# Pero lo incluyo aquí porque siempre lo siento más como un método
# (de Object, no de Struct).
proc makeObject(struct: Struct): Object =
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
proc getType (struct: Struct, k: Key): Type =
  case k.kind
  of intKey: return struct.getType(k.i)
  of strKey: return struct.getType(k.s)

proc `[]`(obj: Object, i: int): Value   = return obj.data[i]
proc `[]=`(obj: Object, i: int, v: Value) = obj.data[i] = v

proc `[]`(obj: Object, k: string): Value =
  let i = obj.struct.getIndex(k)
  return obj.data[i]
proc `[]=`(obj: Object, k: string, v: Value) =
  let i = obj.struct.getIndex(k)
  obj.data[i] = v

proc `[]`(obj: Object, k: Key): Value =
  case k.kind
  of intKey: return obj[k.i]
  of strKey: return obj[k.s]
proc `[]=`(obj: Object, k: Key, v: Value) =
  case k.kind
  of intKey: obj[k.i] = v
  of strKey: obj[k.s] = v


proc `$`(k: Key): string =
  case k.kind
  of intKey: return $k.i
  of strKey: return k.s
proc `$`(inst: Inst): string =
  return $inst.kind & "{a:" & $inst.a & " b:" & $inst.b & " c:" & $inst.c & " i:" & $inst.i.Key & "}"


#=== Representación para Depuración ===#
proc dbgRepr(struct: Struct, deep: bool = false): string
proc dbgRepr(t: Type, deep: bool = false): string =
  case t.kind:
  of nilType: return "NilType"
  of numberType: return "Number"
  of stringType: return "String"
  of structType: return "Struct[" & t.struct.dbgRepr(deep) & "]"
  of codeType:
    let args = "[" & t.code.args.dbgRepr(deep) & "]"
    case t.code.kind
    of nativeCode: return "NativeCode" & args
    of machineCode: return "MachineCode" & args
proc dbgRepr(struct: Struct, deep: bool = false): string =
  if not deep: return struct.name
  result = ""
  for i in (0 .. struct.info.high):
    let info = struct.info[i]
    result.add(info.s & ": " & info.t.dbgRepr(false) & "\n")

proc dbgRepr(obj: Object, deep: bool = false): string
proc dbgRepr(v: Value, deep: bool = false): string =
  case v.kind:
  of nilType: return "nil"
  of numberType: return $v.num
  of stringType: return $v.str
  of structType, codeType: return v.obj.dbgRepr(deep)
proc dbgRepr(obj: Object, deep: bool = false): string =
  if not deep: return "Object[" & obj.struct.name & "]"
  result = "{\n"
  for i in (0 .. obj.data.high):
    let info = obj.struct.info[i]
    let line = info.s & ": " & obj.data[i].dbgRepr(false)
    result.add(line & "\n")
  result.add("}")