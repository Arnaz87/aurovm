# Aquí incluyo todos los tipos y sus constructores.

# Los tipos se pueden agrupar en diferentes secciones, por ejemplo el tipo
# State también podría ir en machine.nim, pero la relacion entre todos los
# tipos es algo compleja, muchos tipos dependen de muchos otros tipos, por
# lo tanto debo agruparlos todos en la misma declaración type.

type
  #=== Tipos Básicos ===#
  RegInfo = tuple[s: string, t: Type]
  Struct = ref object of RootObj
    name: string
    info: seq[RegInfo]
  Object = ref object of RootObj
    struct: Struct
    data: seq[Value]

  TypeKind = enum
    nilType = 0, numberType, codeType, structType, stringType, typeType
  Type = object
    case kind: TypeKind
    of structType: struct: Struct
    of codeType: code: Code
    else: discard
  Value = object
    case kind: TypeKind
    of nilType: discard
    of numberType: num: float
    of stringType: str: string
    of structType, codeType:
      obj: Object
    of typeType: tp: Type

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

  #=== Tipos de la Máquina ===#
  State = ref object of RootObj
    run: bool
    pc: int
    code: Code
    regs: Object
    jump: tuple[b: bool, i: int]
  Module = ref object of RootObj
    name: string
    struct: Struct
    data: Object


  KeyKind = enum intKey, strKey
  Key = object
    case kind: KeyKind
    of intKey: i: int
    of strKey: s: string
  Addr = distinct Key

  InstKind = enum
    inop, iget, iset, icall, inew, iend, ijmp, iif, iifn, ilbl
  Inst = object
    kind: InstKind
    a: Key
    b: Key
    c: Key
    i: Addr


#=== Constructores ===#

proc newStruct(name: string, info: seq[RegInfo]): Struct =
  return Struct(name: name, info: info)
proc newNativeCode(args: Struct, prc: CodeProc): Code =
  return Code(args: args, kind: nativeCode, prc: prc)
proc newMachineCode(args: Struct, regs: Struct, code: seq[Inst]): Code =
  return Code(args: args, kind: machineCode, regs: regs, code: code)

const NilType = Type(kind: nilType)
const NumberType = Type(kind: numberType)
const StringType = Type(kind: stringType)
const TypeType = Type(kind: typeType)
proc CodeType(code: Code): Type = Type(kind: codeType, code: code)
proc StructType(struct: Struct): Type = Type(kind: structType, struct: struct)

proc NumberValue(n: float): Value = return Value(kind: numberType, num: n)
proc StructValue(o: Object): Value = return Value(kind: structType, obj: o)
proc CodeValue(o: Object): Value = return Value(kind: codeType, obj: o)
proc TypeValue(t: Type): Value = return Value(kind: typeType, tp: t)

proc StrKey (str: string): Key = return Key(kind: strKey, s: str)

const IEnd = Inst(kind: iend)
const INop = Inst(kind: inop)
proc IGet(a: string, b: string, c: string): Inst =
  return Inst(kind: iget, a: StrKey(a), b: StrKey(b), c: StrKey(c))
proc ISet(a: string, b: string, c: string): Inst =
  return Inst(kind: iset, a: StrKey(a), b: StrKey(b), c: StrKey(c))
proc INew(a: string): Inst =
  return Inst(kind: inew, a: StrKey(a))
proc ICall(a: string): Inst =
  return Inst(kind: icall, a: StrKey(a))
#proc ILbl(str: string): Inst =
#  return Inst(kind: ilbl, i: Key(kind: strKey, s: str))