
import machine

import dynlib
import libffi

import tables

var ffi_modules = initTable[string, Module](32)

var self = SimpleModule("auro\x1fffi", [])

type Type = machine.Type

template addfn* (
  mymod: Module,
  myname: string,
  myins: openArray[Type],
  myouts: openArray[Type],
  body: untyped
) = 
  mymod.items.add(FunctionItem(myname, Function(
    name: myname,
    sig: Signature(ins: @myins, outs: @myouts),
    kind: procF,
    prc: proc (myargs: var seq[Value]) =
      var args {.inject.}: seq[Value]
      args.shallowCopy(myargs)
      body
  )))

let strT = findModule("auro\x1fstring")["string"].t
let fltT = findModule("auro\x1ffloat")["float"].t
let intT = findModule("auro\x1fint")["int"].t

let ptrT = newType("pointer")

self["pointer"] = ptrT

proc make_type (name: string, base_type: Type) =
  let tp = newType(name)
  self[name] = tp

  self.addfn(name & "\x1dnew", [base_type], [tp]):
    discard
  
  self.addfn(name & "\x1dget", [tp], [base_type]):
    discard

for name in ["u8", "u16", "u32", "u64", "i8", "i16", "i32", "i64"]:
  make_type(name, intT)

make_type("f32", fltT)
make_type("f64", fltT)



proc import_proc (argument: Module): Module =
  var argitem = argument["0"]

  if argitem.kind != fItem:
    raise newException(Exception, "argument 0 for auro.ffi is not a function")

  let arg_f = argitem.f
  if arg_f.sig != Signature(ins: @[], outs: @[strT]):
    raise newException(Exception, "function argument 0 of auro.ffi must accept nothing and return a string")

  let lib_name = arg_f.run(@[])[0].s

  if ffi_modules.hasKey(lib_name):
    return ffi_modules[lib_name]

  let dll = loadLib(lib_name, false)
  if dll == nil:
    raise newException(Exception, "cannot load library " & lib_name)

  let basename = "ffi(" & lib_name & ")"

  result = SimpleModule(basename, [])

  proc get_type_ptr (item: Item): ptr libffi.Type =
    if item.kind != tItem:
      raise newException(Exception, "module argument " & item.name.main & " is not a type")
    raise newException(Exception, "get_type_ptr not yet implemented")

  proc get_builder (argument: Module): Module =
    let fnameitem = argument["name"]

    if fnameitem.kind != fItem:
      raise newException(Exception, "argument 0 for auro.ffi is not a function")

    let arg_f = fnameitem.f
    if arg_f.sig != Signature(ins: @[], outs: @[strT]):
      raise newException(Exception, "function argument 0 of auro.ffi must accept nothing and return a string")

    let fname = arg_f.run(@[])[0].s

    let proc_sym = dll.symAddr(fname)
    if proc_sym == nil:
      raise newException(Exception, "function " & fname & " not found in " & lib_name)

    var cif: Tcif
    var params: ParamList
    var param_count: cuint = 0

    var out_type: ptr libffi.Type

    let out_item = argument["out"]
    if out_item.kind == nilItem:
      out_type = type_void.addr
    else:
      out_type = get_type_ptr(out_item)

    var in_item = argument["in" & $param_count]
    while in_item.kind != nilItem:
      params[param_count] = get_type_ptr(in_item)
      param_count += 1
      in_item = argument["in" & $param_count]

    if cif.prep_cif(DEFAULT_ABI, param_count, out_type, params) != Ok:
      raise newException(Exception, "could not prepare function " & libname & "." & fname)


    # To call:
    # cif.call(proc_sym, out_var.addr, args)

    result = SimpleModule(libname & "." & fname, [])
    result.addfn("", [], []):
      var out_var = 0
      var some_args: ArgList
      cif.call(proc_sym, out_var.addr, some_args)

  let get_functor = CustomModule(libname & ".get", nil, get_builder)
  result.items.add(ModuleItem("get", get_functor))
      
  ffi_modules[lib_name] = result


self.items.add(ModuleItem("import", CustomModule("import", nil, import_proc)))

machine_modules.add(self)
