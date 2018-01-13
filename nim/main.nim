import os

import machine
import parse
import compile

import cobrelib

type Module = machine.Module

proc compile_file (file: File, name: string): Module =
  proc read_byte(): uint8 =
    let L = file.readBuffer(result.addr, 1)
    if L != 1: raise newException(IOError, "cannot read byte")
  let parsed = parse(read_byte)
  try:
    return compile(parsed)
  except CompileError:
    echo "Error in module " & name
    echo getCurrentExceptionMsg()
    quit(QuitFailure)

proc module_loader (name: string): Module =
  if fileExists(name):
    let file = open(name)
    return compile_file(file, name)

set_module_loader(module_loader)

if paramCount() != 1:
  # getAppFilename() me da el nombre completo,
  # paramStr(0) solo me da el comando usado (en linux al menos).
  echo "Usage: " & paramStr(0) & " <file>"
  quit()

let main_module_name = paramStr(1)

let main_module = module_loader(main_module_name)
if main_module.isNil:
  echo "Module " & main_module_name & " not found"
  quit(QuitFailure)
machine_modules.add(main_module)

let main_item = main_module["main"]
if main_item.kind != machine.fItem:
  echo "main function not found in " & main_module_name
  quit(QuitFailure)

# TODO: Surround with try/except and print stack
discard main_item.f.run(@[])


