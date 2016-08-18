type # Tipos Básicos
  RegInfo = tuple[s: string, t: Type]
  Struct = ref object of RootObj
    name: string
    info: seq[RegInfo]
  Object = ref object of RootObj
    struct: Struct
    data: seq[Value]

  TypeKind = enum
    numberType, codeType, structType, stringType
  Type = object
    case kind: TypeKind
    of structType: struct: Struct
    of codeType: code: Code
    else: discard
  Value = object
    case kind: TypeKind
    of numberType: num: float
    of stringType: str: string
    of structType, codeType:
      obj: Object

  CodeProc = proc(args: Object)
  CodeKind = enum nativeCode, machineCode
  Code = ref object of RootObj
    args: Struct
    case kind: CodeKind
    of machineCode:
      code: seq[Inst]
      regs: Struct
      module: Module
    of nativeCode: prc: CodeProc

  Module = ref object of RootObj
    name: string
    struct: Struct
    data: Object

  Inst = ref object of RootObj


proc newStruct(name: string, info: seq[RegInfo]): Struct =
  return Struct(name: name, info: info)
proc newNativeCode(args: Struct, prc: CodeProc): Code =
  return Code(args: args, kind: nativeCode, prc: prc)
proc newMachineCode(args: Struct, regs: Struct, code: seq[Inst]): Code =
  return Code(args: args, kind: machineCode, regs: regs, code: code)

const NumberType = Type(kind: numberType)
const StringType = Type(kind: stringType)
proc CodeType(code: Code): Type = Type(kind: codeType, code: code)
proc StructType(struct: Struct): Type = Type(kind: structType, struct: struct)

proc NumberValue(n: float): Value = return Value(kind: numberType, num: n)
proc StructValue(o: Object): Value = return Value(kind: structType, obj: o)
proc CodeValue(o: Object): Value = return Value(kind: codeType, obj: o)

proc typeRepr(t: Type): string =
  case t.kind:
  of numberType: return "Number"
  of stringType: return "String"
  of structType: return "Struct[" & t.struct.name & "]"
  of codeType:
    let args = "[" & t.code.args.name & "]"
    case t.code.kind
    of nativeCode: return "NativeCode" & args
    of machineCode: return "MachineCode" & args


