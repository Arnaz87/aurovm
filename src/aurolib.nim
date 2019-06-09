
import machine

import hashes
import tables
import options

from times import cpuTime
from strutils import toHex, replace, join
import osproc
from ospaths import getEnv

import sequtils

import math

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
    if tp.name == "":
      tp.name = nm
    result[nm] = tp
  for tpl in funcs:
    let (nm, f) = tpl
    if f.name == "":
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

proc hash(t: Type): Hash = t.id.hash
proc hash(sig: Signature): Hash = !$(sig.ins.hash !& sig.outs.hash)

let boolT*: Type = newType("bool")
globalModule("auro.bool"):
  self["bool"] = boolT
  self["true"] = Function(
    name: "true",
    kind: constF,
    sig: mksig([], [boolT]),
    value: Value(kind: boolV, b: true)
  )
  self["false"] = Function(
    name: "false",
    kind: constF,
    sig: mksig([], [boolT]),
    value: Value(kind: boolV, b: false)
  )
  self.addfn("not", [boolT], [boolT]):
    args.ret Value(kind: boolV, b: not args[0].b)
  self.addfn("or", [boolT, boolT], [boolT]):
    args.ret Value(kind: boolV, b: args[0].b or args[1].b)
  self.addfn("and", [boolT, boolT], [boolT]):
    args.ret Value(kind: boolV, b: args[0].b and args[1].b)
  self.addfn("xor", [boolT, boolT], [boolT]):
    args.ret Value(kind: boolV, b: args[0].b xor args[1].b)
  self.addfn("eq", [boolT, boolT], [boolT]):
    args.ret Value(kind: boolV, b: args[0].b == args[1].b)

include aurolib/int
include aurolib/float
include aurolib/buffer
include aurolib/string

include aurolib/io
include aurolib/system

include aurolib/record
include aurolib/null
include aurolib/array
include aurolib/function
include aurolib/typeshell
include aurolib/any

include aurolib/utils
include aurolib/math
