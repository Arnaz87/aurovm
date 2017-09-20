
## Compiles the data structures resulting of parse to the structures
## the machine uses.

import parse as parse
import machine2 as mach
import cobrelib

type Definition = object

proc compile (module: parse.Module): mach.Module =
  result = newModule(name = "")

  var mods = newSeq[mach.Module](module.imports.len)
  for i, m in module.imports.pairs:
    mods[i] = mach.findModule(m)

  var types = newSeq[mach.Type](module.types.len)
  for i, tp in module.types.pairs:
    case tp.kind
    of parse.importT:
      let m = mods[tp.mod_index - 1]
      types[i] = m.get_type(tp.name)
    else: raise newException(Exception, "Kind " & $tp.kind & " not supported")

  type CodeDef = tuple[sig: parse.Signature, fn: mach.Function]
  var codes = newSeq[CodeDef]()

  var funcs = newSeq[mach.Function](module.functions.len)
  for i, fn in module.functions.pairs:
    case fn.kind
    of parse.importF:
      let m = mods[fn.index - 1]
      funcs[i] = m.get_function(fn.name)
    of parse.codeF:
      var fun = mach.Function(
        name: "f#" & $(i+1),
        module: result,
        kind: mach.codeF
      )
      funcs[i] = fun
      codes.add( (fn.sig, fun) )
    else: raise newException(Exception, "Kind " & $fn.kind & " not supported")

  for item in module.exports:
    case item.kind
    of parse.type_item:
      result[item.name] = types[item.index - 1]
    of parse.function_item:
      result[item.name] = funcs[item.index - 1]

when defined(test):
  include test_compile