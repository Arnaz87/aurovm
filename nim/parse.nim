
# http://andreaferretti.github.io/patty/
# import patty

type

  Signature* = object
    in_types: seq[uint]
    out_tupes: seq[uint]

  TypeKind* = enum nullT, importT, aliasT, nullableT, productT, sumT, funT
  Type* = object
    case kind*: TypeKind
    of nullT: discard
    of importT:
      mod_index*: uint
      name*: string
    of aliasT, nullableT:
      type_index*: uint
    of productT, sumT:
      field_types*: seq[uint]
    of funT:
      sig*: Signature

  FunctionKind* = enum nullF, importF, codeF, unboxF, boxF, getF, setF
  Function* = object
    sig*: Signature # Solo para importF y codeF
    index*: uint # No para codeF
    case kind*: FunctionKind
    of importF:
      name*: string
    of getF, setF:
      field_index*: uint
    else: discard

  StaticKind* = enum intS, binS, typeS, functionS, nullS
  Static* = object
    case kind*: StaticKind
    of intS: value*: uint
    of binS: bytes*: seq[uint8]
    of typeS, functionS: index*: uint
    of nullS: type_index*: uint

  InstKind* = enum nulI, dupI, setI, sgtI, sstI, jmpI, jifI, nifI, varI, callI
  Inst* = object
    case kind*: InstKind
    of nulI, varI: discard
    of callI:
      function_index: uint
      arg_indexes: seq[uint]
    else:
      a: uint
      b: uint
  Code* = seq[Inst]

  Module* = ref object
    imports: seq[string]
    types: seq[Type]
    functions: seq[Function]
    blocks: seq[Code]

#=== Esta sección es prácticamente solo para las pruebas ===#
# Pinche nim, no sabe inferir igualdad en variants...
# Honestamente, nim es muy pobre en variants

proc `==`* (a, b: Type): bool =
  if a.kind == b.kind: return case a.kind
    of nullT: true
    of importT:
      a.mod_index == b.mod_index and a.name == b.name
    of aliasT, nullableT:
      a.type_index == b.type_index
    of productT, sumT:
      a.field_types == b.field_types
    of funT:
      a.sig == b.sig
  return false

proc `==`* (a, b: Function): bool =
  if a.kind != b.kind: return false
  if a.kind == nullF: return true
  if a.kind != codeF and a.index != b.index: return false
  return case a.kind
    of importF: a.sig == b.sig and a.name == b.name
    of codeF: a.sig == b.sig
    of getF, setF: a.field_index == b.field_index
    else: true

proc `==`* (a, b: Static): bool =
  if a.kind == b.kind: return case a.kind
    of intS: a.value == b.value
    of binS: a.bytes == b.bytes
    of typeS, functionS: a.index == b.index
    of nullS: a.type_index == b.type_index
  return false

proc `==`* (a, b: Inst): bool =
  if a.kind == b.kind: return case a.kind
    of nulI, varI: true
    of callI: a.function_index == b.function_index and a.arg_indexes == b.arg_indexes
    of dupI, sgtI, jmpI: a.a == b.a
    else: a.a == b.a and a.b == b.b
  return false