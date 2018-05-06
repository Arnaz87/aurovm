
import machine
import cobrelib

import dynlib
#import libffi

# TODO: Finish

#==========================================================#
#===                     cobre.ffi                      ===#
#==========================================================#

# Look at libffi and dyncall

let ptrT = Type(kind: nativeT, name: "ptr")

var items = @[ Item(name: "ptr", kind: tItem, t: ptrT) ]

proc libFn (argument: Module): Module =
  var argitem = argument["0"]
  if argitem.kind != vItem or argitem.vt != strT:
    raise newException(Exception, "argument 0 for cobre.ffi.lib is not a string")
  var path = argitem.v.s
  let lib = loadLib(path)
  if lib.isNil:
    raise newException(Exception, "Couldn't load library " & path)

  var items = newSeq[Item](0)

  return Module(
    name: path,
    kind: simpleM,
    items: items,
  )

machine_modules.add(Module(name: "cobre.ffi.lib", kind: functorM, fn: libFn))



