
import machine

import hashes
import tables
import options

from times import cpuTime
from strutils import toHex, replace
import osproc

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


let binT*: Type = Type(name: "bin")
let boolT*: Type = Type(name: "bool")

globalModule("cobre.core"):
  self["bool"] = boolT
  self["bin"] = binT

include cobrelib/int
include cobrelib/float
include cobrelib/string
include cobrelib/record
include cobrelib/null
include cobrelib/array
include cobrelib/function
include cobrelib/typeshell
include cobrelib/any

#==========================================================#
#===                    cobre.system                    ===#
#==========================================================#

globalModule("cobre.system"):
  let fileT = Type(name: "file")
  self["file"] = fileT

  self.addfn("quit", [intT], []):
    quit(args[0].i)

  self.addfn("print", mksig([strT], [])):
    echo args[0].s
    args.setLen(0)

  self.addfn("read", mksig([], [strT])):
    var line = stdin.readLine()
    args.ret Value(kind: strV, s: line)

  self.addfn("clock", mksig([], [fltT])):
    args.ret Value(kind: fltV, f: cpuTime())

  self.addfn("exec", mksig([strT], [intT])):
    let cmd = args[0].s
    var p = startProcess(command = cmd, options = {poEvalCommand})
    let code = p.waitForExit()
    args.ret Value(kind: intV, i: code)

  self.addfn("cmd", mksig([strT], [strT])):
    let cmd = args[0].s
    var p = startProcess(command = cmd, options = {poEvalCommand})
    var out_file: File
    discard out_file.open(p.outputHandle, fmRead)
    discard p.waitForExit()
    let out_str = out_file.readAll()

    args.ret Value(kind: strV, s: out_str)

  self.addfn("open", mksig([strT, strT], [fileT])):
    let path = args[0].s
    let mode = case args[1].s
      of "w": fmWrite
      of "a": fmAppend
      else: fmRead
    let file = open(path, mode)
    args.ret(Value(kind: ptrV, pt: file))

  self.addfn("readall", mksig([strT], [strT])):
    let path = args[0].s
    let file = open(path, fmRead)
    let contents = readAll(file)
    args.ret(Value(kind: strV, s: contents))

  self.addfn("write", mksig([fileT, strT], [])):
    let file = cast[File](args[0].pt)
    file.write(args[1].s)

  self.addfn("writebyte", mksig([fileT, intT], [])):
    let file = cast[File](args[0].pt)
    let b = uint8(args[1].i)
    let written = file.writeBytes([b], 0, 1)
    if written != 1:
      raise newException(Exception, "Couldn't write file")

  self.addfn("argc", mksig([], [intT])):
    args.ret Value(kind: intV, i: cobreargs.len)

  self.addfn("args", mksig([intT], [strT])):
    args.ret Value(kind: strV, s: cobreargs[args[0].i])

  self.addfn("error", mksig([strT], [])):
    raise newException(Exception, args[0].s)
