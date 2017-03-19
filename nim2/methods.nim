
# # Métodos de utilidad.
# No son necesarios para que la máquina funcione, pero le hacen más fácil
# a otros módulos trabajar con los tipo de la máquina

# Sólo se usan los tipos, no se usa el intérprete
import machine

proc `[]`* (types: openArray[Type], key: string): Type =
  for t in types:
    if t.name==key:
      return t
  raise newException(KeyError, "key not found: " & $key)
proc `[]`* (procs: openArray[Proc], key: string): Proc =
  for p in procs:
    if p.name==key:
      return p
  raise newException(KeyError, "key not found: " & $key)
proc `[]`* (modules: openArray[Module], key: string): Module =
  for m in modules:
    if m.name==key:
      return m
  raise newException(KeyError, "key not found: " & $key)

proc intValue* (i: int): Value = Value(kind: intType, i: i)
proc boolValue* (b: bool): Value = Value(kind: boolType, b: b)
proc strValue* (s: string): Value = Value(kind: strType, str: s)

proc `$`* (prc: Proc): string =
  result = prc.name & "("
  case prc.kind
  of nativeProc:
    result.add($prc.inCount & " -> " & $prc.outCount)
  of codeProc:
    result.add($prc.inregs.len & " -> " & $prc.outregs.len)
  result.add(")")
proc `$`* (tp: Type): string = return "Type[" & tp.name & "]"
proc `$`* (v: Value): string =
  case v.kind:
  of nilType: return "nil"
  of intType: return $v.i
  of boolType: return $v.b
  of strType: return $v.str


proc `$$`* (prc: Proc): string =
  result = $prc
  case prc.kind
  of nativeProc:
    result.add("[Native]")
  of codeProc:
    result.add("{\n")
    result.add("  ins:"  & $prc.inregs  & "\n")
    result.add("  outs:" & $prc.outregs & "\n")
    result.add("  regs:\n")
    for tp in prc.regs:
      result.add("    " & $tp & "\n")
    result.add("  code:\n")
    for inst in prc.code:
      result.add("    " & $inst & "\n")
    result.add("}")