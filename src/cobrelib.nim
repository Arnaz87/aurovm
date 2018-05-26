
import machine

import hashes
import tables
import options

from times import cpuTime
from strutils import toHex, replace
import osproc
from ospaths import getEnv

import sequtils

proc retn* (sq: var seq[Value], vs: openarray[Value]) =
  for i in 0 .. vs.high:
    sq[i] = vs[i]

template ret* (sq: var seq[Value], v: Value) = retn(sq, [v])

proc mksig* (ins: openarray[Type], outs: openarray[Type]): Signature =
  Signature(ins: @ins, outs: @outs)

template addfn* (items: var seq[Item], myname: string, mysig: Signature, body: untyped) =
  items.add(FunctionItem(myname, Function(
    name: myname,
    sig: mysig,
    kind: procF,
    prc: proc (myargs: var seq[Value]) =
      var args {.inject.}: seq[Value]
      args.shallowCopy(myargs)
      body
  )))

template addfn* (
  items: var seq[Item],
  myname: string,
  myins: openArray[Type],
  myouts: openArray[Type],
  body: untyped
) = addfn(items, myname, mksig(myins, myouts), body)

template addfn* (
  self: var Module,
  name: string,
  sig: Signature,
  body: untyped
) = addfn(self.items, name, sig, body)

template addfn* (
  self: var Module,
  name: string,
  myins: openArray[Type],
  myouts: openArray[Type],
  body: untyped
) = addfn(self, name, mksig(myins, myouts), body)


proc newModule* (
  name: string,
  types: seq[(string, Type)] = @[],
  funcs: seq[(string, Function)] = @[],
  ): Module =
  result = Module(kind: simpleM, name: name, items: @[])
  for tpl in types:
    let (nm, tp) = tpl
    if tp.name.isNil:
      tp.name = nm
    result[nm] = tp
  for tpl in funcs:
    let (nm, f) = tpl
    if f.name.isNil:
      f.name = nm
    result[nm] = f
  machine_modules.add(result)

template createModule (name: string, body: untyped): Module =
  block:
    var self {.inject.} = SimpleModule(name, [])
    body
    self

template globalModule (name: string, body: untyped) =
  machine_modules.add(createModule(name.replace('.', '\x1f'), body))

template createFunctor (name: string, body: untyped): Module =
  block:
    proc builder (myarg: Module): Module =
      var argument {.inject.} = myarg
      body
    CustomModule(name, nil, builder)

template globalFunctor (name: string, body: untyped) =
  machine_modules.add(createFunctor(name.replace('.', '\x1f'), body))

proc hash(t: Type): Hash = t.name.hash
proc hash(sig: Signature): Hash = !$(sig.ins.hash !& sig.outs.hash)

let boolT*: Type = Type(name: "bool")
globalModule("cobre.bool"):
  self["bool"] = boolT

include cobrelib/int
include cobrelib/float
include cobrelib/buffer
include cobrelib/string

include cobrelib/io
include cobrelib/system

include cobrelib/record
include cobrelib/null
include cobrelib/array
include cobrelib/function
include cobrelib/typeshell
include cobrelib/any

#==========================================================#
#===                    cobre.system                    ===#
#==========================================================#
