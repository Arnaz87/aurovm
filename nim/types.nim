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
    nilType = 0,
    numberType, stringType, boolType,
    structType, codeType, typeType
  Type = object
    case kind: TypeKind
    of structType: struct: Struct
    else: discard
  Value = object
    case kind: TypeKind
    of nilType: discard
    of boolType: b: bool
    of numberType: num: float
    of stringType: str: string
    of structType: obj: Object
    of typeType: tp: Type
    of codeType: code: Code

  Args = object
    ins: seq[string]
    outs: seq[string]

  CodeProc = proc(args: Object)
  CodeKind = enum nativeCode, machineCode
  Code = ref object of RootObj
    name: string
    args: Args
    regs: Struct # significa algo diferente para machine y para native
    case kind: CodeKind
    of machineCode:
      code: seq[Inst]
      module: Module
    of nativeCode:
      prc: CodeProc

  #=== Tipos de la Máquina ===#
  State = ref object of RootObj
    run: bool
    pc: int
    code: Code
    regs: Object
    jump: bool
    outs: seq[string]
    # Los outs se guardan en el estado invocado.
    # Esto es importante porque el estado padre puede invocar muchas funciones
    # con diferentes salidas, pero un estado esta amarrado a un código fijo,
    # que tiene una estructura fija de salidas.
  Module = ref object of RootObj
    name: string
    data: Table[string, Value]


  KeyKind = enum intKey, strKey
  Key = object
    case kind: KeyKind
    of intKey: i: int
    of strKey: s: string
  Addr = object
    case kind: KeyKind
    of intKey: i: int
    of strKey: s: string

  InstKind = enum
    inop, icpy, iget, iset, icall, inew, iend, ijmp, iif, iifn, ilbl, icns
  Inst = object
    case kind: InstKind
    of icall:
      code: Code
      args: Args
    else:
      a: Key
      b: Key
      c: Key
      i: Addr


#=== Constructores ===#

proc nArgs (ins: seq[string] = @[], outs: seq[string] = @[]): Args =
  return Args(ins: ins, outs: outs)

proc newStruct(name: string, info: seq[RegInfo]): Struct =
  return Struct(name: name, info: info)
proc newNativeCode(name: string, args: Args, regs: Struct, prc: CodeProc): Code =
  return Code(name: name, kind: nativeCode, args: args, regs: regs, prc: prc)
proc newMachineCode(name: string, args: Args, regs: Struct, code: seq[Inst]): Code =
  return Code(name: name, kind: machineCode, args: args, regs: regs, code: code)

# Estos deberían ser const, pero Type tiene el campo struct, que es de tipo
# ref object (Struct), por lo que no me deja hacer constantes con Type.
let NilType = Type(kind: nilType)
let NumberType = Type(kind: numberType)
let StringType = Type(kind: stringType)
let BoolType = Type(kind: boolType)
let TypeType = Type(kind: typeType)
let CodeType = Type(kind: codeType)
proc StructType(struct: Struct): Type = Type(kind: structType, struct: struct)

proc BoolValue(b: bool): Value = return Value(kind: boolType, b: b)
proc NumberValue(n: float): Value = return Value(kind: numberType, num: n)
proc StringValue(s: string): Value = return Value(kind: stringType, str: s)
proc StructValue(o: Object): Value = return Value(kind: structType, obj: o)
proc TypeValue(t: Type): Value = return Value(kind: typeType, tp: t)
proc CodeValue(c: Code): Value = return Value(kind: codeType, code: c)
let NilValue = Value(kind: nilType)

proc StrKey (str: string): Key = return Key(kind: strKey, s: str)
proc StrAddr (str: string): Addr = return Addr(kind: strKey, s: str)

# Estos también deberían ser const, pero el campo code no me deja proque
# Code es ref
let IEnd = Inst(kind: iend)
let INop = Inst(kind: inop)
proc ICpy(a: string, b: string): Inst =
  return Inst(kind: icpy, a: StrKey(a), b: StrKey(b))
proc IGet(a: string, b: string, c: string): Inst =
  return Inst(kind: iget, a: StrKey(a), b: StrKey(b), c: StrKey(c))
proc ISet(a: string, b: string, c: string): Inst =
  return Inst(kind: iset, a: StrKey(a), b: StrKey(b), c: StrKey(c))
proc ICns(a: string, b: string): Inst =
  return Inst(kind: icns, a: StrKey(a), b: StrKey(b))
proc INew(a: string): Inst =
  return Inst(kind: inew, a: StrKey(a))
proc IJmp(str: string): Inst =
  return Inst(kind: ijmp, i: StrAddr(str))
proc ILbl(str: string): Inst =
  return Inst(kind: ilbl, i: StrAddr(str))
proc IIf (str: string): Inst =
  return Inst(kind: iif , i: StrAddr(str))
proc IIfn(i: string, a: string): Inst =
  return Inst(kind: iifn, i: StrAddr(i), a: StrKey(a))
proc ICall(code: Code, outs: seq[string], ins: seq[string]): Inst =
  return Inst(kind: icall, code: code, args: nArgs(ins, outs))