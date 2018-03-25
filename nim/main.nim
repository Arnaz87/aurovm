import os

import machine
import parse
import compile

import cobrelib

type Module = machine.Module

proc help () =
  # getAppFilename() me da el nombre completo del ejecutable,
  # paramStr(0) solo me da el comando usado (en linux al menos).
  echo "Usage: " & paramStr(0) & " [options] module {args}"
  echo()
  echo "  Runs the specified cobre module. The module is searched in the current"
  echo "  directory as a file that matches the module name, failing that it's searched"
  echo "  in the module installation path: $HOME/.cobre/modules"
  echo()
  echo "Options:"
  echo "  -h  --help    prints this help"
  echo "  -v --version  prints the version information"
  echo "  --install     install the file module on the system"
  echo "  --remove      removes a module from system"
  quit(QuitSuccess)

if paramCount() == 0: help()

type Mode = enum run_mode, install_mode, remove_mode

var mode = run_mode
var main_module_name: string = nil
for p in commandLineParams():
  if cobreargs.len < 1:
    if p == "--help" or p == "-h": help()
    if p == "--version" or p == "-v":
      echo "Cobre 0.5"
      quit(QuitSuccess)
    elif p == "--install": mode = install_mode
    elif p == "--remove": mode = remove_mode
    elif p[0] == '-':
      echo "Unknown option " & p
      quit(QuitFailure)
    else:
      main_module_name = p
      cobreargs.add(paramStr(0) & " " & p)
  else: cobreargs.add(p)

let mod_path = getEnv("HOME") & "/.cobre/modules"

if mode != run_mode:
  let target = mod_path & "/" & main_module_name

  case mode
  of install_mode:
    createDir(mod_path)
    copyFile(main_module_name, target)
    echo "Installed module at " & target
  of remove_mode:
    removeFile(target)
    echo "Removed module at " & target
  else: discard

  quit(QuitSuccess)

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
  var filename: string = name
  if not fileExists(filename):
    filename = mod_path & "/" & name
    if not fileExists(filename):
      return nil
  let file = open(filename)
  return compile_file(file, name)

set_module_loader(module_loader)

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


