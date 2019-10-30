
import machine

import dynlib
import libffi

import tables

var ffi_modules = initTable[string, Module](32)

var self = SimpleModule("auro\x1fffi", [])

type Type = machine.Type
type FfiType = libffi.Type

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

var ffi_type_table = initTable[Type, ptr libffi.Type](16)
var base_types_table = initTable[Type, Type](16)

proc make_type (name: string, base_type: Type, ffi_type: ptr FfiType) =
  let tp = newType(name)
  self[name] = tp

  self.addfn(name & "\x1dnew", [base_type], [tp]):
    discard
  
  self.addfn(name & "\x1dget", [tp], [base_type]):
    discard

  ffi_type_table[tp] = ffi_type
  base_types_table[tp] = base_type

let tpps = {
  "u8": type_uint8.addr,
  "u16": type_uint16.addr,
  "u32": type_uint32.addr,
  "u64": type_uint64.addr,
  "i8": type_sint8.addr,
  "i16": type_sint16.addr,
  "i32": type_sint32.addr,
  "i64": type_sint64.addr,
}

for pair in tpps:
  let (name, tpp) = pair
  make_type(name, intT, tpp)

make_type("f32", fltT, type_float.addr)
make_type("f64", fltT, type_double.addr)



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

  proc get_type_ptr (item: Item): ptr FfiType =
    if item.kind != tItem:
      raise newException(Exception, "module argument " & item.name.main & " is not a type")
    if not ffi_type_table.has_key(item.t):
      raise newException(Exception, "module argument " & item.name.main & " is not a valid ffi type")
    ffi_type_table[item.t]
      

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

    # params has to be allocated manually.
    # If handled by the gc, the compiler doesn't know the value is not used
    # again after this function, so it gets freed before it's used

    let params: ptr ParamList = cast[ptr ParamList](alloc0(sizeof(ParamList)))

    var param_count: cuint = 0

    var out_type: ptr libffi.Type

    var sig_in = newSeq[Type]()
    var sig_out = newSeq[Type]()

    let out_item = argument["out"]
    if out_item.kind == nilItem:
      out_type = type_void.addr
    else:
      out_type = get_type_ptr(out_item)
      sig_out.add(out_item.t)


    var in_item = argument["in" & $param_count]
    while in_item.kind != nilItem:
      params[][param_count] = get_type_ptr(in_item)

      sig_in.add(in_item.t)

      param_count += 1
      in_item = argument["in" & $param_count]

    if cif.prep_cif(DEFAULT_ABI, param_count, out_type, params[]) != Ok:
      raise newException(Exception, "could not prepare function " & libname & "." & fname)

    result = SimpleModule(libname & "." & fname, [])
    result.addfn("", sig_in, sig_out):
      var out_value: Value = Value(kind: intV)
      var out_addr: pointer

      if sig_out.len > 0:
        let base_type = base_types_table[sig_out[0]]
        if base_type == intT:
          out_value = Value(kind: intV)
          out_addr = out_value.i.addr
        elif base_type == fltT:
          out_value = Value(kind: fltV)
          out_addr = out_value.f.addr
        else:
          raise newException(Exception, "Unsupported base type: " & $base_type)

      var raw_vals: array[0..20, uint64]
      var raw_val: uint64

      var ffi_args: ArgList

      for i in 0 .. sig_in.high:

        template assign (m_t: untyped, m_v: untyped):untyped =
          (cast[ptr m_t](raw_val.addr))[] = cast[m_t](m_v)

        var val = args[i]
        let ffi_type = ffi_type_table[sig_in[i]]

        if ffi_type == type_sint8.addr:
          assign(int8, val.i)
        elif ffi_type == type_sint16.addr:
          assign(int16, val.i)
        elif ffi_type == type_sint32.addr:
          assign(int32, val.i)
        elif ffi_type == type_sint64.addr:
          assign(int64, val.i)
        else:
          raise newException(Exception, "Unsupported type: " & $sig_in[i])

        ffi_args[i] = raw_val.addr

      cif.call(proc_sym, out_addr, ffi_args)
      args[0] = out_value

  let get_functor = CustomModule(libname & ".get", nil, get_builder)
  result.items.add(ModuleItem("get", get_functor))
      
  ffi_modules[lib_name] = result


self.items.add(ModuleItem("import", CustomModule("import", nil, import_proc)))

machine_modules.add(self)
